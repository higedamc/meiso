package model

import "time"

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
	ID        string     `json:"id"`
	Title     string     `json:"title"`
	Status    TaskStatus `json:"status"`
	Due       DueBucket  `json:"due"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	SyncedAt  *time.Time `json:"synced_at,omitempty"`
	Dirty     bool       `json:"dirty"`
}
