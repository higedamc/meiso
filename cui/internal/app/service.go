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

func (s *Service) AddTask(title string, due model.DueBucket) (*model.Task, error) {
	title = strings.TrimSpace(title)
	if title == "" {
		return nil, errors.New("title is required")
	}
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

func (s *Service) Sync(ctx context.Context) (int, error) {
	session, ok, err := s.SessionStatus()
	if err != nil {
		return 0, err
	}
	if !ok || session == nil {
		return 0, errors.New("not logged in or session expired")
	}

	tasks, err := s.taskStore.Load()
	if err != nil {
		return 0, err
	}

	var signer nostrclient.Signer
	switch session.SignerName {
	case "browser":
		signer = nostrclient.NewBrowserSigner(*session)
	case "nip07":
		signer = nostrclient.NewNIP07Signer(session.PubKey)
	case "local":
		secret := strings.TrimSpace(session.RefreshHint)
		if secret == "" {
			return 0, errors.New("local session missing secret in refresh_hint")
		}
		localSigner, err := nostrclient.NewLocalSigner(secret)
		if err != nil {
			return 0, err
		}
		signer = localSigner
	default:
		return 0, fmt.Errorf("unsupported signer: %s", session.SignerName)
	}

	relays := session.RelayList(s.cfg.DefaultRelayURLs)
	session.RelayURLs = relays
	if len(relays) > 0 {
		session.RelayURL = relays[0]
	}
	client := nostrclient.NewClient(relays)
	if err := client.SyncDirtyTasks(ctx, signer, tasks); err != nil {
		session.FailureCount++
		_ = s.sessionStore.Save(*session)
		return 0, err
	}

	now := time.Now()
	synced := 0
	for i := range tasks {
		if tasks[i].Dirty {
			tasks[i].Dirty = false
			tasks[i].SyncedAt = &now
			synced++
		}
	}
	if err := s.taskStore.Save(tasks); err != nil {
		return synced, err
	}
	session.LastSuccessAt = now
	session.FailureCount = 0
	if err := s.sessionStore.Save(*session); err != nil {
		return synced, err
	}
	return synced, nil
}
