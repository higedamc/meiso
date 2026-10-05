package nostrclient

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/higedamc/meiso/cui/internal/model"
	"github.com/nbd-wtf/go-nostr/nip19"
)

func testGroup(t *testing.T) model.SharedGroup {
	t.Helper()
	key, err := GenerateGroupKey()
	if err != nil {
		t.Fatalf("GenerateGroupKey: %v", err)
	}
	if len(key.NsecHex) != 64 || len(key.NpubHex) != 64 {
		t.Fatalf("unexpected key lengths: nsec=%d npub=%d", len(key.NsecHex), len(key.NpubHex))
	}
	return model.SharedGroup{
		GroupID:      "group-123",
		GroupNsecHex: key.NsecHex,
		GroupNpubHex: key.NpubHex,
		Name:         "GROCERIES",
		KeyEpoch:     1,
		CreatedAt:    time.Now(),
	}
}

func TestTaskEventSignedAddressableEncrypted(t *testing.T) {
	g := testGroup(t)
	task := model.SharedTask{
		ID:        "task-1",
		GroupID:   g.GroupID,
		Title:     "Buy groceries",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	ev, err := BuildSignedTaskEvent(g, task, "editor-hex")
	if err != nil {
		t.Fatalf("BuildSignedTaskEvent: %v", err)
	}
	if ev.Kind != SharedTaskKind {
		t.Fatalf("kind = %d, want %d", ev.Kind, SharedTaskKind)
	}
	if ev.PubKey != g.GroupNpubHex {
		t.Fatalf("pubkey = %s, want %s", ev.PubKey, g.GroupNpubHex)
	}
	if d := extractTagValue(ev.Tags, "d"); d != "task-1" {
		t.Fatalf("d tag = %q, want task-1", d)
	}
	ok, err := ev.CheckSignature()
	if err != nil || !ok {
		t.Fatalf("signature invalid: ok=%v err=%v", ok, err)
	}
	if contains(ev.Content, "Buy groceries") {
		t.Fatalf("content is not encrypted: %s", ev.Content)
	}
}

func TestTaskEventRoundTrip(t *testing.T) {
	g := testGroup(t)
	due := "2026-06-10T00:00:00"
	task := model.SharedTask{
		ID:        "task-1",
		GroupID:   g.GroupID,
		Title:     "Milk",
		Completed: true,
		Date:      &due,
		Order:     3,
		CreatedAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		UpdatedAt: time.Date(2026, 1, 2, 0, 0, 0, 0, time.UTC),
	}
	ev, err := BuildSignedTaskEvent(g, task, "editor-hex")
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	got, err := ParseSharedTaskEvent(g, ev)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if got.ID != "task-1" || got.Title != "Milk" || !got.Completed || got.Order != 3 {
		t.Fatalf("roundtrip mismatch: %+v", got)
	}
	if got.Date == nil || *got.Date != due {
		t.Fatalf("date mismatch: %v", got.Date)
	}
	if got.EditorPubkey != "editor-hex" {
		t.Fatalf("editor mismatch: %q", got.EditorPubkey)
	}
	if !got.UpdatedAt.Equal(task.UpdatedAt) {
		t.Fatalf("updatedAt mismatch: %v vs %v", got.UpdatedAt, task.UpdatedAt)
	}
}

func TestOtherGroupKeyCannotDecrypt(t *testing.T) {
	g := testGroup(t)
	other := testGroup(t)
	task := model.SharedTask{ID: "task-1", Title: "Secret", CreatedAt: time.Now(), UpdatedAt: time.Now()}
	ev, err := BuildSignedTaskEvent(g, task, "")
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if _, err := ParseSharedTaskEvent(other, ev); err == nil {
		t.Fatalf("expected decryption failure with wrong group key")
	}
}

func TestPayloadWireFieldNames(t *testing.T) {
	g := testGroup(t)
	task := model.SharedTask{
		ID:        "t1",
		Title:     "x",
		Completed: true,
		Order:     1,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
		Deleted:   false,
	}
	ev, err := BuildSignedTaskEvent(g, task, "ed")
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	plain, err := decryptForGroup(g.GroupNsecHex, ev.Content)
	if err != nil {
		t.Fatalf("decrypt: %v", err)
	}
	var m map[string]any
	if err := json.Unmarshal([]byte(plain), &m); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	for _, k := range []string{"id", "title", "completed", "status", "order", "created_at", "updated_at", "list_id", "custom_list_id", "deleted", "editor_pubkey"} {
		if _, ok := m[k]; !ok {
			t.Fatalf("payload missing field %q: %v", k, m)
		}
	}
	if m["status"] != "done" {
		t.Fatalf("status = %v, want done", m["status"])
	}
	if m["list_id"] != g.GroupID {
		t.Fatalf("list_id = %v, want %s", m["list_id"], g.GroupID)
	}
}

func TestInvitationPayloadRoundTrip(t *testing.T) {
	g := testGroup(t)
	payload, err := BuildInvitationPayloadJSON(g)
	if err != nil {
		t.Fatalf("build payload: %v", err)
	}
	got, err := ParseInvitationPayloadJSON(payload)
	if err != nil {
		t.Fatalf("parse payload: %v", err)
	}
	if got.GroupID != g.GroupID || got.GroupNsecHex != g.GroupNsecHex || got.GroupNpubHex != g.GroupNpubHex {
		t.Fatalf("payload mismatch: %+v", got)
	}
	if got.KeyEpoch != 1 {
		t.Fatalf("epoch = %d, want 1", got.KeyEpoch)
	}
}

func TestInvitationPayloadDerivesNpub(t *testing.T) {
	g := testGroup(t)
	payload := `{"group_id":"g","group_nsec":"` + g.GroupNsecHex + `","group_name":"N","key_epoch":2}`
	got, err := ParseInvitationPayloadJSON(payload)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if got.GroupNpubHex != g.GroupNpubHex {
		t.Fatalf("derived npub = %s, want %s", got.GroupNpubHex, g.GroupNpubHex)
	}
	if got.KeyEpoch != 2 {
		t.Fatalf("epoch = %d, want 2", got.KeyEpoch)
	}
}

func TestGroupIDFromInviteDTag(t *testing.T) {
	recipient := "1122334455667788990011223344556677889900112233445566778899001122"
	groupID := "a1b2c3d4-5678-90ab-cdef-1234567890ab"
	d := groupID + "-" + recipient
	if got := groupIDFromInviteDTag(d); got != groupID {
		t.Fatalf("groupIDFromInviteDTag = %q, want %q", got, groupID)
	}
}

func TestNpubToHexRoundTrip(t *testing.T) {
	g := testGroup(t)
	npub, err := nip19.EncodePublicKey(g.GroupNpubHex)
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	hex, err := NpubToHex(npub)
	if err != nil {
		t.Fatalf("NpubToHex(npub): %v", err)
	}
	if hex != g.GroupNpubHex {
		t.Fatalf("npub roundtrip = %s, want %s", hex, g.GroupNpubHex)
	}
	hex2, err := NpubToHex(g.GroupNpubHex)
	if err != nil || hex2 != g.GroupNpubHex {
		t.Fatalf("NpubToHex(hex) = %s err=%v", hex2, err)
	}
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (indexOf(s, sub) >= 0)
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}
