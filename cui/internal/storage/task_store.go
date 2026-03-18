package storage

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"

	"github.com/higedamc/meiso/cui/internal/model"
)

type TaskStore struct {
	path string
}

func NewTaskStore(baseDir string) *TaskStore {
	return &TaskStore{path: filepath.Join(baseDir, "tasks.json")}
}

func (s *TaskStore) Load() ([]model.Task, error) {
	b, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return []model.Task{}, nil
	}
	if err != nil {
		return nil, err
	}
	if len(b) == 0 {
		return []model.Task{}, nil
	}
	var tasks []model.Task
	if err := json.Unmarshal(b, &tasks); err != nil {
		return nil, err
	}
	sort.Slice(tasks, func(i, j int) bool {
		return tasks[i].CreatedAt.Before(tasks[j].CreatedAt)
	})
	return tasks, nil
}

func (s *TaskStore) Save(tasks []model.Task) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(tasks, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, b, 0o600)
}
