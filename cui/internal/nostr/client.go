package nostrclient

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/higedamc/meiso/cui/internal/model"
	"github.com/nbd-wtf/go-nostr"
)

type Client struct {
	relayURLs []string
	pool      *nostr.SimplePool
}

func NewClient(relayURLs []string) *Client {
	return &Client{
		relayURLs: normalizeRelayURLs(relayURLs),
		pool:      nostr.NewSimplePool(context.Background()),
	}
}

type todoPayload struct {
	ID            string  `json:"id"`
	Title         string  `json:"title"`
	Completed     bool    `json:"completed"`
	Date          *string `json:"date"`
	Order         int     `json:"order"`
	CreatedAt     string  `json:"created_at"`
	UpdatedAt     string  `json:"updated_at"`
	EventID       *string `json:"event_id"`
	CustomListID  *string `json:"custom_list_id,omitempty"`
	ParentTaskID  *string `json:"parent_task_id,omitempty"`
	Depth         int     `json:"depth,omitempty"`
	ParentRecurID *string `json:"parent_recurring_id,omitempty"`
	Recurrence    *string `json:"recurrence,omitempty"`
	LinkPreview   *string `json:"link_preview,omitempty"`
}

// FetchResult holds fetched todos together with the list name resolved from the event title tag.
type FetchResult struct {
	Todos    []todoPayload
	ListName map[string]string // d-tag -> title
}

// FetchTodoList queries Kind 30001 events from relays, deduplicates by d-tag,
// decrypts NIP-44 content, and returns all todos across all lists.
func (c *Client) FetchTodoList(ctx context.Context, signer Signer) (*FetchResult, error) {
	if len(c.relayURLs) == 0 {
		return nil, errors.New("relay urls are empty")
	}

	pubkey, err := signer.PublicKey(ctx)
	if err != nil {
		return nil, err
	}

	filter := nostr.Filter{
		Authors: []string{pubkey},
		Kinds:   []int{30001},
	}

	fetchCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	type taggedEvent struct {
		event nostr.Event
		dTag  string
		title string
	}

	latest := make(map[string]taggedEvent)

	for ie := range c.pool.FetchMany(fetchCtx, c.relayURLs, filter) {
		if ie.Event == nil {
			continue
		}
		dTag := extractTagValue(ie.Event.Tags, "d")
		if dTag == "" {
			continue
		}
		if !strings.HasPrefix(dTag, "meiso-todos") && !strings.HasPrefix(dTag, "meiso-list-") {
			continue
		}
		title := extractTagValue(ie.Event.Tags, "title")

		if existing, ok := latest[dTag]; ok {
			if ie.Event.CreatedAt > existing.event.CreatedAt {
				latest[dTag] = taggedEvent{event: *ie.Event, dTag: dTag, title: title}
			}
		} else {
			latest[dTag] = taggedEvent{event: *ie.Event, dTag: dTag, title: title}
		}
	}

	result := &FetchResult{
		ListName: make(map[string]string),
	}

	for dTag, te := range latest {
		if te.title != "" {
			result.ListName[dTag] = te.title
		}

		decrypted, err := signer.DecryptNIP44(ctx, pubkey, te.event.Content)
		if err != nil {
			fmt.Printf("warning: failed to decrypt list %q: %v\n", dTag, err)
			continue
		}

		var todos []todoPayload
		if err := json.Unmarshal([]byte(decrypted), &todos); err != nil {
			fmt.Printf("warning: failed to parse list %q: %v\n", dTag, err)
			continue
		}

		listID := listIDFromDTag(dTag)
		for i := range todos {
			if listID != nil {
				todos[i].CustomListID = listID
			}
		}

		result.Todos = append(result.Todos, todos...)
	}

	return result, nil
}

// SyncDirtyTasks publishes all tasks to relays if any are dirty, grouped by custom list.
func (c *Client) SyncDirtyTasks(ctx context.Context, signer Signer, tasks []model.Task) error {
	if len(c.relayURLs) == 0 {
		return errors.New("relay urls are empty")
	}
	hasDirty := false
	for _, task := range tasks {
		if task.Dirty {
			hasDirty = true
			break
		}
	}
	if !hasDirty {
		return nil
	}
	return c.publishTodoLists(ctx, signer, tasks)
}

type listBucket struct {
	key   string
	name  string
	tasks []model.Task
}

// publishTodoLists groups tasks by CustomListID and publishes one event per list.
func (c *Client) publishTodoLists(ctx context.Context, signer Signer, tasks []model.Task) error {
	pubkey, err := signer.PublicKey(ctx)
	if err != nil {
		return err
	}

	buckets := groupTasksByList(tasks)

	var lastErr error
	totalSuccess := 0

	for _, bucket := range buckets {
		payload := buildTodoListPayloadFromTasks(bucket.tasks)

		plainJSON, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		encrypted, err := signer.EncryptNIP44(ctx, pubkey, string(plainJSON))
		if err != nil {
			return err
		}

		dTag, titleTag := dTagAndTitle(bucket.key, bucket.name)

		ev := nostr.Event{
			CreatedAt: nostr.Timestamp(time.Now().Unix()),
			Kind:      30001,
			Tags: nostr.Tags{
				nostr.Tag{"d", dTag},
				nostr.Tag{"title", titleTag},
			},
			Content: encrypted,
			PubKey:  pubkey,
		}
		if err := signer.Sign(ctx, &ev); err != nil {
			return err
		}

		success := 0
		for _, relayURL := range c.relayURLs {
			pubCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
			relay, err := c.pool.EnsureRelay(relayURL)
			if err != nil {
				cancel()
				lastErr = err
				continue
			}
			if err := relay.Publish(pubCtx, ev); err != nil {
				cancel()
				lastErr = err
				continue
			}
			cancel()
			success++
		}
		if success > 0 {
			totalSuccess++
		}
	}

	if totalSuccess == 0 {
		if lastErr != nil {
			return lastErr
		}
		return errors.New("failed to publish event to any relay")
	}
	return nil
}

func groupTasksByList(tasks []model.Task) []listBucket {
	m := make(map[string]*listBucket)
	var order []string
	for _, t := range tasks {
		key := t.ListKey()
		if _, ok := m[key]; !ok {
			m[key] = &listBucket{key: key, name: t.DisplayListName()}
			order = append(order, key)
		}
		m[key].tasks = append(m[key].tasks, t)
	}
	out := make([]listBucket, 0, len(order))
	for _, k := range order {
		out = append(out, *m[k])
	}
	return out
}

func dTagAndTitle(listKey, listName string) (string, string) {
	if listKey == "default" {
		return "meiso-todos", "My TODO List"
	}
	title := listName
	if title == "" || title == listKey {
		title = "Custom List " + listKey
	}
	return "meiso-list-" + listKey, title
}

func buildTodoListPayloadFromTasks(tasks []model.Task) []todoPayload {
	now := time.Now()
	out := make([]todoPayload, 0, len(tasks))
	for i, task := range tasks {
		var date *string
		if task.Date != nil {
			date = task.Date
		} else {
			date, _ = dueToDate(task.Due, now)
		}

		t := todoPayload{
			ID:           task.ID,
			Title:        task.Title,
			Completed:    task.Status == model.TaskStatusDone,
			Date:         date,
			Order:        i,
			CreatedAt:    task.CreatedAt.Format(time.RFC3339),
			UpdatedAt:    task.UpdatedAt.Format(time.RFC3339),
			EventID:      task.EventID,
			CustomListID: task.CustomListID,
			ParentTaskID: task.ParentTaskID,
			Depth:        task.Depth,
		}
		out = append(out, t)
	}
	return out
}

func dueToDate(due model.DueBucket, now time.Time) (*string, error) {
	base := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	switch due {
	case model.DueToday:
		v := base.Format("2006-01-02T15:04:05")
		return &v, nil
	case model.DueTomorrow:
		v := base.Add(24 * time.Hour).Format("2006-01-02T15:04:05")
		return &v, nil
	case model.DueSomeday:
		return nil, nil
	default:
		return nil, fmt.Errorf("unknown due bucket: %s", due)
	}
}

func extractTagValue(tags nostr.Tags, key string) string {
	for _, tag := range tags {
		if len(tag) >= 2 && tag[0] == key {
			return tag[1]
		}
	}
	return ""
}

func listIDFromDTag(dTag string) *string {
	if dTag == "meiso-todos" {
		return nil
	}
	if v, ok := strings.CutPrefix(dTag, "meiso-list-"); ok {
		return &v
	}
	return nil
}

func normalizeRelayURLs(in []string) []string {
	out := make([]string, 0, len(in))
	for _, v := range in {
		v = strings.TrimSpace(v)
		if v == "" {
			continue
		}
		if !slices.Contains(out, v) {
			out = append(out, v)
		}
	}
	return out
}
