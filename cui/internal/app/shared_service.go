package app

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/higedamc/meiso/cui/internal/model"
	nostrclient "github.com/higedamc/meiso/cui/internal/nostr"
	"github.com/higedamc/meiso/cui/internal/storage"
)

// sharedContext bundles the live session, signer, and relay client used by
// every shared-list operation that touches the network.
type sharedContext struct {
	session *model.Session
	signer  nostrclient.Signer
	client  *nostrclient.Client
	selfHex string
}

func (s *Service) sharedContext(ctx context.Context) (*sharedContext, error) {
	session, ok, err := s.SessionStatus()
	if err != nil {
		return nil, err
	}
	if !ok || session == nil {
		return nil, errors.New("not logged in or session expired")
	}
	signer, err := s.buildSigner(session)
	if err != nil {
		return nil, err
	}
	relays := session.RelayList(s.cfg.DefaultRelayURLs)
	return &sharedContext{
		session: session,
		signer:  signer,
		client:  nostrclient.NewClient(relays),
		selfHex: session.PubKey,
	}, nil
}

// CreateSharedGroup generates a fresh group key, stores the credentials, and
// best-effort publishes the kind:35001 metadata event so other members can
// resolve the list name.
func (s *Service) CreateSharedGroup(ctx context.Context, name string) (*model.SharedGroup, error) {
	name = storage.NormalizeGroupName(name)
	if name == "" {
		return nil, errors.New("group name is required")
	}
	key, err := nostrclient.GenerateGroupKey()
	if err != nil {
		return nil, err
	}
	group := model.SharedGroup{
		GroupID:      uuid.NewString(),
		GroupNsecHex: key.NsecHex,
		GroupNpubHex: key.NpubHex,
		Name:         name,
		KeyEpoch:     1,
		CreatedAt:    time.Now(),
	}
	if err := s.sharedGroupStore.Upsert(group); err != nil {
		return nil, err
	}

	// Publish metadata (non-fatal: the list is usable even if relays are down).
	if sc, scErr := s.sharedContext(ctx); scErr == nil {
		if metaEv, mErr := nostrclient.BuildSignedMetaEvent(group, nil); mErr == nil {
			_ = sc.client.PublishEvent(ctx, metaEv)
		}
	}
	return &group, nil
}

// ListSharedGroups returns all joined shared groups.
func (s *Service) ListSharedGroups() ([]model.SharedGroup, error) {
	return s.sharedGroupStore.Load()
}

// findSharedGroup resolves a group by id or (case-insensitive) name.
func (s *Service) findSharedGroup(ref string) (*model.SharedGroup, error) {
	ref = strings.TrimSpace(ref)
	if ref == "" {
		return nil, errors.New("group id or name is required")
	}
	groups, err := s.sharedGroupStore.Load()
	if err != nil {
		return nil, err
	}
	for i := range groups {
		if groups[i].GroupID == ref {
			return &groups[i], nil
		}
	}
	lower := strings.ToLower(ref)
	for i := range groups {
		if strings.ToLower(groups[i].Name) == lower {
			return &groups[i], nil
		}
	}
	return nil, fmt.Errorf("shared group not found: %s", ref)
}

// SendSharedInvitation seals the group key for the recipient and publishes a
// kind:30078 invitation. Requires a signer capable of NIP-44 encryption
// (local secret-key mode; NIP-07 also works for encryption).
func (s *Service) SendSharedInvitation(ctx context.Context, groupRef, recipient string) (string, error) {
	group, err := s.findSharedGroup(groupRef)
	if err != nil {
		return "", err
	}
	recipientHex, err := nostrclient.NpubToHex(recipient)
	if err != nil {
		return "", err
	}
	sc, err := s.sharedContext(ctx)
	if err != nil {
		return "", err
	}

	payload, err := nostrclient.BuildInvitationPayloadJSON(*group)
	if err != nil {
		return "", err
	}
	encrypted, err := sc.signer.EncryptNIP44(ctx, recipientHex, payload)
	if err != nil {
		return "", fmt.Errorf("failed to seal invitation (need local or NIP-07 signer): %w", err)
	}

	ev := nostrclient.BuildUnsignedInvitationEvent(sc.selfHex, recipientHex, group.GroupID, group.Name, "", encrypted)
	if err := sc.signer.Sign(ctx, &ev); err != nil {
		return "", err
	}
	if err := sc.client.PublishEvent(ctx, ev); err != nil {
		return "", err
	}
	return ev.ID, nil
}

// ListSharedInvitations fetches pending kind:30078 invitations for the user.
func (s *Service) ListSharedInvitations(ctx context.Context) ([]nostrclient.ReceivedInvitation, error) {
	sc, err := s.sharedContext(ctx)
	if err != nil {
		return nil, err
	}
	return sc.client.FetchSharedInvitations(ctx, sc.selfHex)
}

// AcceptSharedInvitations fetches invitations, decrypts them, and stores the
// resulting group credentials. If groupRef is non-empty only that group is
// accepted. Already-joined groups are skipped. Returns the newly joined groups.
func (s *Service) AcceptSharedInvitations(ctx context.Context, groupRef string) ([]model.SharedGroup, error) {
	sc, err := s.sharedContext(ctx)
	if err != nil {
		return nil, err
	}
	invitations, err := sc.client.FetchSharedInvitations(ctx, sc.selfHex)
	if err != nil {
		return nil, err
	}
	existing, err := s.sharedGroupStore.Load()
	if err != nil {
		return nil, err
	}
	joined := make(map[string]bool, len(existing))
	for _, g := range existing {
		joined[g.GroupID] = true
	}

	groupRef = strings.TrimSpace(groupRef)
	var accepted []model.SharedGroup
	var lastErr error
	for _, inv := range invitations {
		if groupRef != "" && inv.GroupID != groupRef {
			continue
		}
		if joined[inv.GroupID] {
			continue
		}
		plain, decErr := sc.signer.DecryptNIP44(ctx, inv.InviterPubkey, inv.EncryptedContent)
		if decErr != nil {
			lastErr = fmt.Errorf("decrypt invitation for %s: %w", short(inv.GroupID), decErr)
			continue
		}
		group, pErr := nostrclient.ParseInvitationPayloadJSON(plain)
		if pErr != nil {
			lastErr = pErr
			continue
		}
		if strings.TrimSpace(group.Name) == "" {
			group.Name = inv.GroupName
		}
		if err := s.sharedGroupStore.Upsert(group); err != nil {
			return accepted, err
		}
		joined[group.GroupID] = true
		accepted = append(accepted, group)
	}
	if len(accepted) == 0 && lastErr != nil {
		return nil, lastErr
	}
	return accepted, nil
}

// AddSharedTask creates a task in a shared group and publishes it immediately.
func (s *Service) AddSharedTask(ctx context.Context, groupRef, title string, date *string) (*model.SharedTask, error) {
	title = strings.TrimSpace(title)
	if title == "" {
		return nil, errors.New("title is required")
	}
	group, err := s.findSharedGroup(groupRef)
	if err != nil {
		return nil, err
	}
	all, err := s.sharedTaskStore.Load()
	if err != nil {
		return nil, err
	}
	now := time.Now()
	task := model.SharedTask{
		ID:        uuid.NewString(),
		GroupID:   group.GroupID,
		Title:     title,
		Completed: false,
		Date:      date,
		Order:     nextSharedOrder(all, group.GroupID),
		CreatedAt: now,
		UpdatedAt: now,
		Dirty:     true,
	}
	all = append(all, task)
	if err := s.sharedTaskStore.Save(all); err != nil {
		return nil, err
	}
	if err := s.publishSharedTask(ctx, *group, &task); err == nil {
		s.markSharedTaskClean(task.ID)
	}
	return &task, nil
}

// DoneSharedTask marks a shared task complete and publishes the update.
func (s *Service) DoneSharedTask(ctx context.Context, groupRef, taskID string) (*model.SharedTask, error) {
	return s.mutateSharedTask(ctx, groupRef, taskID, func(t *model.SharedTask) {
		t.Completed = true
	})
}

// ReopenSharedTask marks a shared task open again and publishes the update.
func (s *Service) ReopenSharedTask(ctx context.Context, groupRef, taskID string) (*model.SharedTask, error) {
	return s.mutateSharedTask(ctx, groupRef, taskID, func(t *model.SharedTask) {
		t.Completed = false
	})
}

// DeleteSharedTask publishes a tombstone (deleted:true) for a shared task.
func (s *Service) DeleteSharedTask(ctx context.Context, groupRef, taskID string) (*model.SharedTask, error) {
	return s.mutateSharedTask(ctx, groupRef, taskID, func(t *model.SharedTask) {
		t.Deleted = true
	})
}

func (s *Service) mutateSharedTask(ctx context.Context, groupRef, taskID string, mutate func(*model.SharedTask)) (*model.SharedTask, error) {
	group, err := s.findSharedGroup(groupRef)
	if err != nil {
		return nil, err
	}
	all, err := s.sharedTaskStore.Load()
	if err != nil {
		return nil, err
	}
	idx := -1
	for i := range all {
		if all[i].ID == taskID && all[i].GroupID == group.GroupID {
			idx = i
			break
		}
	}
	if idx < 0 {
		return nil, fmt.Errorf("shared task not found: %s", taskID)
	}
	mutate(&all[idx])
	all[idx].UpdatedAt = monotonicNext(all[idx].UpdatedAt)
	all[idx].Dirty = true
	if err := s.sharedTaskStore.Save(all); err != nil {
		return nil, err
	}
	task := all[idx]
	if err := s.publishSharedTask(ctx, *group, &task); err == nil {
		s.markSharedTaskClean(task.ID)
	}
	return &task, nil
}

// ListSharedTasks returns the local (non-deleted) tasks of a shared group.
func (s *Service) ListSharedTasks(groupRef string) (*model.SharedGroup, []model.SharedTask, error) {
	group, err := s.findSharedGroup(groupRef)
	if err != nil {
		return nil, nil, err
	}
	tasks, err := s.sharedTaskStore.LoadByGroup(group.GroupID)
	if err != nil {
		return nil, nil, err
	}
	return group, tasks, nil
}

// SyncSharedGroup pulls the latest group task events, merges them by
// Last-Write-Wins on updated_at, and pushes any locally-dirty tasks.
func (s *Service) SyncSharedGroup(ctx context.Context, groupRef string) (*SyncResult, error) {
	group, err := s.findSharedGroup(groupRef)
	if err != nil {
		return nil, err
	}
	sc, err := s.sharedContext(ctx)
	if err != nil {
		return nil, err
	}
	return s.syncOneSharedGroup(ctx, sc, *group)
}

// SyncAllSharedGroups syncs every joined shared group.
func (s *Service) SyncAllSharedGroups(ctx context.Context) (*SyncResult, error) {
	groups, err := s.sharedGroupStore.Load()
	if err != nil {
		return nil, err
	}
	if len(groups) == 0 {
		return &SyncResult{}, nil
	}
	sc, err := s.sharedContext(ctx)
	if err != nil {
		return nil, err
	}
	total := &SyncResult{}
	var lastErr error
	for _, g := range groups {
		res, err := s.syncOneSharedGroup(ctx, sc, g)
		if err != nil {
			lastErr = err
			continue
		}
		total.Pulled += res.Pulled
		total.Pushed += res.Pushed
	}
	if lastErr != nil && total.Pulled == 0 && total.Pushed == 0 {
		return total, lastErr
	}
	return total, nil
}

func (s *Service) syncOneSharedGroup(ctx context.Context, sc *sharedContext, group model.SharedGroup) (*SyncResult, error) {
	// Full fetch (since=0): addressable LWW events are robust to clock skew.
	events, err := sc.client.FetchSharedTaskEvents(ctx, group.GroupNpubHex, 0)
	if err != nil {
		return nil, fmt.Errorf("pull failed: %w", err)
	}

	all, err := s.sharedTaskStore.Load()
	if err != nil {
		return nil, err
	}

	// Index local tasks for this group by id.
	localIdx := make(map[string]int)
	for i := range all {
		if all[i].GroupID == group.GroupID {
			localIdx[all[i].ID] = i
		}
	}

	pulled := 0
	for _, ev := range events {
		remote, perr := nostrclient.ParseSharedTaskEvent(group, ev)
		if perr != nil {
			continue
		}
		if i, ok := localIdx[remote.ID]; ok {
			local := all[i]
			// Local dirty edits win only if strictly newer than remote.
			if local.Dirty && !remote.UpdatedAt.After(local.UpdatedAt) {
				continue
			}
			if remote.UpdatedAt.After(local.UpdatedAt) || (local.Dirty == false && remote.UpdatedAt.Equal(local.UpdatedAt)) {
				remote.Dirty = false
				all[i] = remote
				pulled++
			}
		} else {
			remote.Dirty = false
			all = append(all, remote)
			localIdx[remote.ID] = len(all) - 1
			pulled++
		}
	}

	// Push dirty tasks (including tombstones).
	pushed := 0
	for i := range all {
		if all[i].GroupID != group.GroupID || !all[i].Dirty {
			continue
		}
		task := all[i]
		if err := s.publishSharedTask(ctx, group, &task); err != nil {
			continue
		}
		all[i].Dirty = false
		pushed++
	}

	if err := s.sharedTaskStore.Save(all); err != nil {
		return &SyncResult{Pulled: pulled, Pushed: pushed}, err
	}
	return &SyncResult{Pulled: pulled, Pushed: pushed}, nil
}

// publishSharedTask signs and publishes a single kind:35000 task event.
func (s *Service) publishSharedTask(ctx context.Context, group model.SharedGroup, task *model.SharedTask) error {
	sc, err := s.sharedContext(ctx)
	if err != nil {
		return err
	}
	ev, err := nostrclient.BuildSignedTaskEvent(group, *task, sc.selfHex)
	if err != nil {
		return err
	}
	return sc.client.PublishEvent(ctx, ev)
}

func (s *Service) markSharedTaskClean(taskID string) {
	all, err := s.sharedTaskStore.Load()
	if err != nil {
		return
	}
	changed := false
	for i := range all {
		if all[i].ID == taskID && all[i].Dirty {
			all[i].Dirty = false
			changed = true
		}
	}
	if changed {
		_ = s.sharedTaskStore.Save(all)
	}
}

func nextSharedOrder(tasks []model.SharedTask, groupID string) int {
	max := -1
	for _, t := range tasks {
		if t.GroupID == groupID && t.Order > max {
			max = t.Order
		}
	}
	return max + 1
}

// monotonicNext guarantees updated_at advances even if another device's clock
// is ahead, so this edit cannot permanently lose the LWW race (issue #138 R3).
func monotonicNext(prev time.Time) time.Time {
	now := time.Now()
	if !now.After(prev) {
		return prev.Add(time.Second)
	}
	return now
}

func short(v string) string {
	if len(v) <= 12 {
		return v
	}
	return v[:8] + "…"
}
