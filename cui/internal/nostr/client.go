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
	return c.publishTodoList(ctx, signer, tasks)
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
	ParentRecurID *string `json:"parent_recurring_id,omitempty"`
	Recurrence    *string `json:"recurrence,omitempty"`
	LinkPreview   *string `json:"link_preview,omitempty"`
}

func (c *Client) publishTodoList(ctx context.Context, signer Signer, tasks []model.Task) error {
	pubkey, err := signer.PublicKey(ctx)
	if err != nil {
		return err
	}

	payload, err := buildTodoListPayload(tasks)
	if err != nil {
		return err
	}
	plainJSON, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	encrypted, err := signer.EncryptNIP44(ctx, pubkey, string(plainJSON))
	if err != nil {
		return err
	}

	ev := nostr.Event{
		CreatedAt: nostr.Timestamp(time.Now().Unix()),
		Kind:      30001,
		Tags: nostr.Tags{
			nostr.Tag{"d", "meiso-todos"},
			nostr.Tag{"title", "My TODO List"},
		},
		Content: encrypted,
		PubKey:  pubkey,
	}
	if err := signer.Sign(ctx, &ev); err != nil {
		return err
	}
	var lastErr error
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
	if success == 0 {
		if lastErr != nil {
			return lastErr
		}
		return errors.New("failed to publish event to any relay")
	}
	return nil
}

func buildTodoListPayload(tasks []model.Task) ([]todoPayload, error) {
	now := time.Now()
	out := make([]todoPayload, 0, len(tasks))
	for i, task := range tasks {
		d, err := dueToDate(task.Due, now)
		if err != nil {
			return nil, err
		}
		t := todoPayload{
			ID:        task.ID,
			Title:     task.Title,
			Completed: task.Status == model.TaskStatusDone,
			Date:      d,
			Order:     i,
			CreatedAt: task.CreatedAt.Format(time.RFC3339),
			UpdatedAt: task.UpdatedAt.Format(time.RFC3339),
			EventID:   nil,
		}
		out = append(out, t)
	}
	return out, nil
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
