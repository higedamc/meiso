package model

import (
	"strings"
	"time"
)

type TaskStatus string

const (
	TaskStatusOpen TaskStatus = "open"
	TaskStatusDone TaskStatus = "done"
)

type DueBucket string

const (
	DueToday    DueBucket = "today"
	DueTomorrow DueBucket = "tomorrow"
	DueSomeday  DueBucket = "someday"
)

type Task struct {
	ID             string     `json:"id"`
	Title          string     `json:"title"`
	Status         TaskStatus `json:"status"`
	Due            DueBucket  `json:"due"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
	SyncedAt       *time.Time `json:"synced_at,omitempty"`
	Dirty          bool       `json:"dirty"`
	CustomListID   *string    `json:"custom_list_id,omitempty"`
	CustomListName string     `json:"custom_list_name,omitempty"`
	ParentTaskID   *string    `json:"parent_task_id,omitempty"`
	Depth          int        `json:"depth,omitempty"`
	EventID        *string    `json:"event_id,omitempty"`
	Date           *string    `json:"date_raw,omitempty"`
}

func (t Task) ListKey() string {
	if t.CustomListID != nil && *t.CustomListID != "" {
		return *t.CustomListID
	}
	return "default"
}

func (t Task) DisplayListName() string {
	if t.CustomListName != "" {
		return t.CustomListName
	}
	if t.CustomListID != nil && *t.CustomListID != "" {
		return *t.CustomListID
	}
	return "TODO"
}

func DateToDueBucket(date *string) DueBucket {
	if date == nil {
		return DueSomeday
	}
	d := strings.TrimSpace(*date)
	if d == "" {
		return DueSomeday
	}
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	tomorrow := today.Add(24 * time.Hour)

	var parsed time.Time
	for _, layout := range []string{
		"2006-01-02T15:04:05",
		"2006-01-02T15:04:05Z07:00",
		time.RFC3339,
		"2006-01-02",
	} {
		if t, err := time.Parse(layout, d); err == nil {
			parsed = t
			break
		}
	}
	if parsed.IsZero() {
		return DueSomeday
	}

	pDay := time.Date(parsed.Year(), parsed.Month(), parsed.Day(), 0, 0, 0, 0, now.Location())
	switch {
	case pDay.Equal(today):
		return DueToday
	case pDay.Equal(tomorrow):
		return DueTomorrow
	default:
		return DueSomeday
	}
}
