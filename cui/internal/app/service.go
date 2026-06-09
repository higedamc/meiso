package app

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/higedamc/meiso/cui/internal/auth"
	"github.com/higedamc/meiso/cui/internal/model"
	nostrclient "github.com/higedamc/meiso/cui/internal/nostr"
	"github.com/higedamc/meiso/cui/internal/storage"
)

type Service struct {
	cfg          Config
	authBroker   *auth.Broker
	sessionStore *storage.SessionStore
	taskStore    *storage.TaskStore
}

func NewService(cfg Config) *Service {
	return &Service{
		cfg:          cfg,
		authBroker:   auth.NewBroker(),
		sessionStore: storage.NewSessionStore(cfg.DataDir),
		taskStore:    storage.NewTaskStore(cfg.DataDir),
	}
}

func (s *Service) Login(ctx context.Context) (*model.Session, error) {
	session, err := s.authBroker.Login(ctx, s.cfg.AuthURL, s.cfg.DefaultRelayURLs)
	if err != nil {
		return nil, err
	}
	baseRelays := session.RelayList(s.cfg.DefaultRelayURLs)
	if resolved, resolveErr := nostrclient.ResolveWriteRelays(ctx, session.PubKey, baseRelays); resolveErr == nil && len(resolved) > 0 {
		session.RelayURLs = resolved
		session.RelayURL = resolved[0]
	} else {
		session.RelayURLs = baseRelays
		if len(baseRelays) > 0 {
			session.RelayURL = baseRelays[0]
		}
	}
	if err := s.sessionStore.Save(session); err != nil {
		return nil, err
	}
	return &session, nil
}

func (s *Service) LoginLocal(secret string) (*model.Session, error) {
	localSigner, err := nostrclient.NewLocalSigner(secret)
	if err != nil {
		return nil, err
	}
	pubkey, err := localSigner.PublicKey(context.Background())
	if err != nil {
		return nil, err
	}
	session := model.Session{
		AccessToken:   "local",
		PubKey:        pubkey,
		SignerName:    "local",
		SignEndpoint:  "",
		RefreshHint:   secret,
		RelayURLs:     s.cfg.DefaultRelayURLs,
		ExpiresAt:     time.Now().Add(10 * 365 * 24 * time.Hour),
		LastSuccessAt: time.Now(),
	}
	if len(session.RelayURLs) > 0 {
		session.RelayURL = session.RelayURLs[0]
	}
	if err := s.sessionStore.Save(session); err != nil {
		return nil, err
	}
	return &session, nil
}

func (s *Service) Logout() error {
	return s.sessionStore.Clear()
}

func (s *Service) SessionStatus() (*model.Session, bool, error) {
	session, err := s.sessionStore.Load()
	if err != nil {
		return nil, false, err
	}
	if session == nil {
		return nil, false, nil
	}
	if !session.IsExpired(time.Now()) {
		relays := session.RelayList(s.cfg.DefaultRelayURLs)
		session.RelayURLs = relays
		if len(relays) > 0 {
			session.RelayURL = relays[0]
		}
		return session, true, nil
	}
	if strings.TrimSpace(session.RefreshHint) == "" || !strings.HasPrefix(session.RefreshHint, "http") {
		return session, false, nil
	}
	refreshed, err := s.authBroker.Refresh(context.Background(), *session)
	if err != nil {
		session.FailureCount++
		_ = s.sessionStore.Save(*session)
		return session, false, nil
	}
	if err := s.sessionStore.Save(refreshed); err != nil {
		return nil, false, err
	}
	refreshedRelays := refreshed.RelayList(s.cfg.DefaultRelayURLs)
	refreshed.RelayURLs = refreshedRelays
	if len(refreshedRelays) > 0 {
		refreshed.RelayURL = refreshedRelays[0]
	}
	return &refreshed, true, nil
}

func (s *Service) AddTask(title string, due model.DueBucket, listName string) (*model.Task, error) {
	title = strings.TrimSpace(title)
	if title == "" {
		return nil, errors.New("title is required")
	}
	listName = strings.TrimSpace(listName)

	now := time.Now()
	task := model.Task{
		ID:        uuid.NewString(),
		Title:     title,
		Status:    model.TaskStatusOpen,
		Due:       due,
		CreatedAt: now,
		UpdatedAt: now,
		Dirty:     true,
	}

	if listName != "" {
		tasks, err := s.taskStore.Load()
		if err != nil {
			return nil, err
		}
		listID := resolveListID(tasks, listName)
		task.CustomListID = &listID
		task.CustomListName = listName
		tasks = append(tasks, task)
		if err := s.taskStore.Save(tasks); err != nil {
			return nil, err
		}
		return &task, nil
	}

	tasks, err := s.taskStore.Load()
	if err != nil {
		return nil, err
	}
	tasks = append(tasks, task)
	if err := s.taskStore.Save(tasks); err != nil {
		return nil, err
	}
	return &task, nil
}

// resolveListID finds the list ID for a given list name from existing tasks.
// If no match is found, generates a new UUID.
func resolveListID(tasks []model.Task, listName string) string {
	lower := strings.ToLower(listName)
	for _, t := range tasks {
		if t.CustomListID != nil && strings.ToLower(t.CustomListName) == lower {
			return *t.CustomListID
		}
	}
	return uuid.NewString()
}

func (s *Service) ListTasks() ([]model.Task, error) {
	return s.taskStore.Load()
}

func (s *Service) DoneTask(taskID string) (*model.Task, error) {
	tasks, err := s.taskStore.Load()
	if err != nil {
		return nil, err
	}
	now := time.Now()
	for i := range tasks {
		if tasks[i].ID == taskID {
			tasks[i].Status = model.TaskStatusDone
			tasks[i].UpdatedAt = now
			tasks[i].Dirty = true
			if err := s.taskStore.Save(tasks); err != nil {
				return nil, err
			}
			return &tasks[i], nil
		}
	}
	return nil, fmt.Errorf("task not found: %s", taskID)
}

// SyncResult holds pull/push counts from a bidirectional sync.
type SyncResult struct {
	Pulled int
	Pushed int
}

func (s *Service) Sync(ctx context.Context) (*SyncResult, error) {
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
	session.RelayURLs = relays
	if len(relays) > 0 {
		session.RelayURL = relays[0]
	}
	client := nostrclient.NewClient(relays)

	localTasks, err := s.taskStore.Load()
	if err != nil {
		return nil, err
	}

	// Phase 1: Pull
	fetchResult, err := client.FetchTodoList(ctx, signer)
	if err != nil {
		session.FailureCount++
		_ = s.sessionStore.Save(*session)
		return nil, fmt.Errorf("pull failed: %w", err)
	}

	remoteTasks := payloadsToTasks(fetchResult)

	// Phase 2: Merge (LWW by UpdatedAt)
	merged, pulled := mergeTasks(localTasks, remoteTasks)

	// Phase 3: Push dirty tasks
	if err := client.SyncDirtyTasks(ctx, signer, merged); err != nil {
		session.FailureCount++
		_ = s.sessionStore.Save(*session)
		return nil, fmt.Errorf("push failed: %w", err)
	}

	now := time.Now()
	pushed := 0
	for i := range merged {
		if merged[i].Dirty {
			merged[i].Dirty = false
			merged[i].SyncedAt = &now
			pushed++
		}
	}

	// Phase 4: Save
	if err := s.taskStore.Save(merged); err != nil {
		return &SyncResult{Pulled: pulled, Pushed: pushed}, err
	}
	session.LastSuccessAt = now
	session.FailureCount = 0
	if err := s.sessionStore.Save(*session); err != nil {
		return &SyncResult{Pulled: pulled, Pushed: pushed}, err
	}

	return &SyncResult{Pulled: pulled, Pushed: pushed}, nil
}

func (s *Service) buildSigner(session *model.Session) (nostrclient.Signer, error) {
	switch session.SignerName {
	case "browser":
		return nostrclient.NewBrowserSigner(*session), nil
	case "nip07":
		return nostrclient.NewNIP07Signer(session.PubKey), nil
	case "local":
		secret := strings.TrimSpace(session.RefreshHint)
		if secret == "" {
			return nil, errors.New("local session missing secret in refresh_hint")
		}
		return nostrclient.NewLocalSigner(secret)
	default:
		return nil, fmt.Errorf("unsupported signer: %s", session.SignerName)
	}
}

func payloadsToTasks(fr *nostrclient.FetchResult) []model.Task {
	out := make([]model.Task, 0, len(fr.Todos))
	for _, p := range fr.Todos {
		status := model.TaskStatusOpen
		if p.Completed {
			status = model.TaskStatusDone
		}

		due := model.DateToDueBucket(p.Date)

		createdAt, _ := time.Parse(time.RFC3339, p.CreatedAt)
		if createdAt.IsZero() {
			createdAt = time.Now()
		}
		updatedAt, _ := time.Parse(time.RFC3339, p.UpdatedAt)
		if updatedAt.IsZero() {
			updatedAt = createdAt
		}

		var listName string
		if p.CustomListID != nil {
			dTag := "meiso-list-" + *p.CustomListID
			if name, ok := fr.ListName[dTag]; ok {
				listName = name
			}
		}

		out = append(out, model.Task{
			ID:             p.ID,
			Title:          p.Title,
			Status:         status,
			Due:            due,
			CreatedAt:      createdAt,
			UpdatedAt:      updatedAt,
			CustomListID:   p.CustomListID,
			CustomListName: listName,
			ParentTaskID:   p.ParentTaskID,
			Depth:          p.Depth,
			EventID:        p.EventID,
			Date:           p.Date,
		})
	}
	return out
}

// mergeTasks merges local and remote using LWW per task ID.
// Returns the merged slice and the count of tasks pulled from remote.
func mergeTasks(local, remote []model.Task) ([]model.Task, int) {
	localMap := make(map[string]model.Task, len(local))
	for _, t := range local {
		localMap[t.ID] = t
	}

	remoteMap := make(map[string]model.Task, len(remote))
	for _, t := range remote {
		remoteMap[t.ID] = t
	}

	seen := make(map[string]bool)
	merged := make([]model.Task, 0, len(local)+len(remote))
	pulled := 0

	// Resolve conflicts for tasks in both sets; keep local-only tasks
	for _, lt := range local {
		seen[lt.ID] = true
		rt, inRemote := remoteMap[lt.ID]
		if !inRemote {
			merged = append(merged, lt)
			continue
		}
		if lt.Dirty {
			if lt.UpdatedAt.After(rt.UpdatedAt) {
				merged = append(merged, lt)
			} else {
				rt.Dirty = false
				rt.SyncedAt = lt.SyncedAt
				merged = append(merged, rt)
				pulled++
			}
		} else {
			if rt.UpdatedAt.After(lt.UpdatedAt) {
				now := time.Now()
				rt.SyncedAt = &now
				merged = append(merged, rt)
				pulled++
			} else {
				merged = append(merged, lt)
			}
		}
	}

	// Remote-only tasks
	for _, rt := range remote {
		if seen[rt.ID] {
			continue
		}
		now := time.Now()
		rt.SyncedAt = &now
		merged = append(merged, rt)
		pulled++
	}

	return merged, pulled
}
