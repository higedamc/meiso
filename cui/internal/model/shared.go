package model

import "time"

// SharedGroup holds the credentials and metadata for a `shared-v1`
// collaborative list. The group secret key (GroupNsecHex) is the shared
// secret that grants read/write access to every task in the list, so it
// MUST be persisted only in encrypted storage and never logged.
//
// Wire-compatible with the Flutter `SharedGroupCredentials` entity and the
// Rust `group_tasks_shared::GroupKey` / `InvitationPayload`.
type SharedGroup struct {
	GroupID      string    `json:"group_id"`
	GroupNsecHex string    `json:"group_nsec"`
	GroupNpubHex string    `json:"group_npub"`
	Name         string    `json:"name"`
	KeyEpoch     int       `json:"key_epoch"`
	CreatedAt    time.Time `json:"created_at"`
}

// SharedTask is the local representation of a task that belongs to a
// `shared-v1` group. It is stored separately from personal tasks so that
// group content is never published to the user's personal kind:30001 list.
type SharedTask struct {
	ID           string    `json:"id"`
	GroupID      string    `json:"group_id"`
	Title        string    `json:"title"`
	Completed    bool      `json:"completed"`
	Date         *string   `json:"date,omitempty"`
	Order        int       `json:"order"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
	Deleted      bool      `json:"deleted"`
	EditorPubkey string    `json:"editor_pubkey,omitempty"`
	Dirty        bool      `json:"dirty"`
}
