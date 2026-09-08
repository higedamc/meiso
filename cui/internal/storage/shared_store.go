package storage

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/higedamc/meiso/cui/internal/model"
)

// SharedGroupStore persists `shared-v1` group credentials. Because each record
// holds the group secret key (the shared secret for the whole list), the file
// is encrypted at rest with the same AES-GCM master key used for sessions.
type SharedGroupStore struct {
	path string
}

func NewSharedGroupStore(baseDir string) *SharedGroupStore {
	return &SharedGroupStore{path: filepath.Join(baseDir, "shared_groups.enc")}
}

func (s *SharedGroupStore) Load() ([]model.SharedGroup, error) {
	b, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return []model.SharedGroup{}, nil
	}
	if err != nil {
		return nil, err
	}
	if len(b) == 0 {
		return []model.SharedGroup{}, nil
	}
	key, err := loadOrCreateMasterKey()
	if err != nil {
		return nil, err
	}
	raw, err := decrypt(b, key)
	if err != nil {
		return nil, err
	}
	var groups []model.SharedGroup
	if err := json.Unmarshal(raw, &groups); err != nil {
		return nil, err
	}
	return groups, nil
}

func (s *SharedGroupStore) Save(groups []model.SharedGroup) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return err
	}
	key, err := loadOrCreateMasterKey()
	if err != nil {
		return err
	}
	raw, err := json.Marshal(groups)
	if err != nil {
		return err
	}
	enc, err := encrypt(raw, key)
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, enc, 0o600)
}

// Upsert inserts or replaces a group by GroupID.
func (s *SharedGroupStore) Upsert(group model.SharedGroup) error {
	groups, err := s.Load()
	if err != nil {
		return err
	}
	replaced := false
	for i := range groups {
		if groups[i].GroupID == group.GroupID {
			groups[i] = group
			replaced = true
			break
		}
	}
	if !replaced {
		groups = append(groups, group)
	}
	return s.Save(groups)
}

// Find returns the group with the given id, or nil if not present.
func (s *SharedGroupStore) Find(groupID string) (*model.SharedGroup, error) {
	groups, err := s.Load()
	if err != nil {
		return nil, err
	}
	for i := range groups {
		if groups[i].GroupID == groupID {
			return &groups[i], nil
		}
	}
	return nil, nil
}

// SharedTaskStore persists shared-group task state locally (separate from
// personal tasks so group content is never published to the personal list).
type SharedTaskStore struct {
	path string
}

func NewSharedTaskStore(baseDir string) *SharedTaskStore {
	return &SharedTaskStore{path: filepath.Join(baseDir, "shared_tasks.json")}
}

func (s *SharedTaskStore) Load() ([]model.SharedTask, error) {
	b, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return []model.SharedTask{}, nil
	}
	if err != nil {
		return nil, err
	}
	if len(b) == 0 {
		return []model.SharedTask{}, nil
	}
	var tasks []model.SharedTask
	if err := json.Unmarshal(b, &tasks); err != nil {
		return nil, err
	}
	sort.SliceStable(tasks, func(i, j int) bool {
		if tasks[i].GroupID != tasks[j].GroupID {
			return tasks[i].GroupID < tasks[j].GroupID
		}
		if tasks[i].Order != tasks[j].Order {
			return tasks[i].Order < tasks[j].Order
		}
		return tasks[i].CreatedAt.Before(tasks[j].CreatedAt)
	})
	return tasks, nil
}

func (s *SharedTaskStore) Save(tasks []model.SharedTask) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(tasks, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, b, 0o600)
}

// LoadByGroup returns the non-deleted tasks for a single group.
func (s *SharedTaskStore) LoadByGroup(groupID string) ([]model.SharedTask, error) {
	all, err := s.Load()
	if err != nil {
		return nil, err
	}
	var out []model.SharedTask
	for _, t := range all {
		if t.GroupID == groupID && !t.Deleted {
			out = append(out, t)
		}
	}
	return out, nil
}

// Clear removes all shared-group state (used on logout).
func (s *SharedGroupStore) Clear() error {
	if err := os.Remove(s.path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

func (s *SharedTaskStore) Clear() error {
	if err := os.Remove(s.path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

// NormalizeGroupName mirrors the Flutter create flow which upper-cases names.
func NormalizeGroupName(name string) string {
	return strings.ToUpper(strings.TrimSpace(name))
}
