package nostrclient

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/higedamc/meiso/cui/internal/model"
	"github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip19"
	"github.com/nbd-wtf/go-nostr/nip44"
)

// Shared-Key Collaborative Lists (`shared-v1`).
//
// This mirrors rust/src/group_tasks_shared.rs so events are byte-compatible
// with the Flutter/Android client:
//   - A dedicated Nostr key G is generated per list and shared between members.
//   - Tasks are addressable events (kind:35000, d=task-id) signed by G with
//     NIP-44 v2 self-encrypted content, giving relay-level Last-Write-Wins.
//   - List metadata is a kind:35001 event with the fixed d-tag "meta".
//   - Invitations distribute nsec_G via a NIP-44 envelope inside a kind:30078
//     event addressed to the recipient (#p) — wire-compatible with the
//     Rust create_unsigned_shared_invitation_event / sync_shared_invitations.
const (
	SharedTaskKind   = 35000
	SharedMetaKind   = 35001
	SharedMetaDTag   = "meta"
	SharedInviteKind = 30078
	sharedInvitePfx  = "shared-invite-"
)

// GroupKey is a freshly generated group key (the shared secret + its pubkey).
type GroupKey struct {
	NsecHex string
	NpubHex string
}

// GenerateGroupKey creates a new random group key G.
func GenerateGroupKey() (GroupKey, error) {
	sk := nostr.GeneratePrivateKey()
	pk, err := nostr.GetPublicKey(sk)
	if err != nil {
		return GroupKey{}, err
	}
	return GroupKey{NsecHex: sk, NpubHex: pk}, nil
}

// NpubFromNsec derives the group public key (hex) from its secret key (hex).
func NpubFromNsec(groupNsecHex string) (string, error) {
	return nostr.GetPublicKey(strings.TrimSpace(groupNsecHex))
}

// selfConversationKey computes the NIP-44 conversation key of G with itself,
// matching nip44::encrypt(sk_G, pk_G, ...) on the Rust side.
func selfConversationKey(groupNsecHex string) ([32]byte, error) {
	groupNsecHex = strings.TrimSpace(groupNsecHex)
	pub, err := nostr.GetPublicKey(groupNsecHex)
	if err != nil {
		return [32]byte{}, fmt.Errorf("invalid group secret key: %w", err)
	}
	return nip44.GenerateConversationKey(pub, groupNsecHex)
}

func encryptForGroup(groupNsecHex, plaintext string) (string, error) {
	ck, err := selfConversationKey(groupNsecHex)
	if err != nil {
		return "", err
	}
	return nip44.Encrypt(plaintext, ck)
}

func decryptForGroup(groupNsecHex, ciphertext string) (string, error) {
	ck, err := selfConversationKey(groupNsecHex)
	if err != nil {
		return "", err
	}
	return nip44.Decrypt(ciphertext, ck)
}

// sharedTaskPayload is the decrypted plaintext carried inside a kind:35000
// event. Field names match what the Flutter client writes/reads so tasks
// created on either side round-trip cleanly.
type sharedTaskPayload struct {
	ID           string  `json:"id"`
	Title        string  `json:"title"`
	Completed    bool    `json:"completed"`
	Status       string  `json:"status"`
	Date         *string `json:"date,omitempty"`
	Order        int     `json:"order"`
	CreatedAt    string  `json:"created_at"`
	UpdatedAt    string  `json:"updated_at"`
	CustomListID string  `json:"custom_list_id"`
	ListID       string  `json:"list_id"`
	Deleted      bool    `json:"deleted"`
	EditorPubkey string  `json:"editor_pubkey,omitempty"`
}

// BuildSignedTaskEvent serializes a SharedTask to the shared-v1 wire payload,
// NIP-44 self-encrypts it, and returns a signed addressable kind:35000 event
// (d = task id) authored by the group key.
func BuildSignedTaskEvent(group model.SharedGroup, task model.SharedTask, editorPubkey string) (nostr.Event, error) {
	if strings.TrimSpace(task.ID) == "" {
		return nostr.Event{}, errors.New("shared task must have a non-empty id")
	}
	status := "open"
	if task.Completed {
		status = "done"
	}
	payload := sharedTaskPayload{
		ID:           task.ID,
		Title:        task.Title,
		Completed:    task.Completed,
		Status:       status,
		Date:         task.Date,
		Order:        task.Order,
		CreatedAt:    task.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:    task.UpdatedAt.UTC().Format(time.RFC3339),
		CustomListID: group.GroupID,
		ListID:       group.GroupID,
		Deleted:      task.Deleted,
		EditorPubkey: editorPubkey,
	}
	plain, err := json.Marshal(payload)
	if err != nil {
		return nostr.Event{}, err
	}
	ciphertext, err := encryptForGroup(group.GroupNsecHex, string(plain))
	if err != nil {
		return nostr.Event{}, err
	}
	ev := nostr.Event{
		PubKey:    group.GroupNpubHex,
		CreatedAt: nostr.Now(),
		Kind:      SharedTaskKind,
		Tags:      nostr.Tags{nostr.Tag{"d", task.ID}},
		Content:   ciphertext,
	}
	if err := ev.Sign(group.GroupNsecHex); err != nil {
		return nostr.Event{}, err
	}
	return ev, nil
}

// ParseSharedTaskEvent decrypts a kind:35000 event with the group key and maps
// it to a SharedTask. The list id always comes from the group (the payload's
// own list_id is advisory only).
func ParseSharedTaskEvent(group model.SharedGroup, ev nostr.Event) (model.SharedTask, error) {
	plain, err := decryptForGroup(group.GroupNsecHex, ev.Content)
	if err != nil {
		return model.SharedTask{}, err
	}
	var p sharedTaskPayload
	if err := json.Unmarshal([]byte(plain), &p); err != nil {
		return model.SharedTask{}, err
	}
	if strings.TrimSpace(p.ID) == "" {
		return model.SharedTask{}, errors.New("decrypted shared task has empty id")
	}
	completed := p.Completed || p.Status == "done"
	return model.SharedTask{
		ID:           p.ID,
		GroupID:      group.GroupID,
		Title:        p.Title,
		Completed:    completed,
		Date:         p.Date,
		Order:        p.Order,
		CreatedAt:    parseSharedTime(p.CreatedAt),
		UpdatedAt:    parseSharedTime(p.UpdatedAt),
		Deleted:      p.Deleted,
		EditorPubkey: strings.TrimSpace(p.EditorPubkey),
		Dirty:        false,
	}, nil
}

// BuildSignedMetaEvent builds a signed kind:35001 (d="meta") metadata event
// holding the list name, key epoch, and (optional) member list.
func BuildSignedMetaEvent(group model.SharedGroup, members []string) (nostr.Event, error) {
	if members == nil {
		members = []string{}
	}
	meta := map[string]any{
		"name":       group.Name,
		"key_epoch":  group.KeyEpoch,
		"members":    members,
		"updated_at": time.Now().UTC().Format(time.RFC3339),
	}
	plain, err := json.Marshal(meta)
	if err != nil {
		return nostr.Event{}, err
	}
	ciphertext, err := encryptForGroup(group.GroupNsecHex, string(plain))
	if err != nil {
		return nostr.Event{}, err
	}
	ev := nostr.Event{
		PubKey:    group.GroupNpubHex,
		CreatedAt: nostr.Now(),
		Kind:      SharedMetaKind,
		Tags:      nostr.Tags{nostr.Tag{"d", SharedMetaDTag}},
		Content:   ciphertext,
	}
	if err := ev.Sign(group.GroupNsecHex); err != nil {
		return nostr.Event{}, err
	}
	return ev, nil
}

// invitationPayload is the plaintext sealed inside an invitation envelope.
type invitationPayload struct {
	GroupID   string `json:"group_id"`
	GroupNsec string `json:"group_nsec"`
	GroupNpub string `json:"group_npub"`
	GroupName string `json:"group_name"`
	KeyEpoch  uint64 `json:"key_epoch"`
}

// BuildInvitationPayloadJSON serializes the invitation payload as Rust does.
func BuildInvitationPayloadJSON(group model.SharedGroup) (string, error) {
	p := invitationPayload{
		GroupID:   group.GroupID,
		GroupNsec: group.GroupNsecHex,
		GroupNpub: group.GroupNpubHex,
		GroupName: group.Name,
		KeyEpoch:  uint64(group.KeyEpoch),
	}
	b, err := json.Marshal(p)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// ParseInvitationPayloadJSON parses an invitation payload into a SharedGroup.
// group_npub is derived from the secret key if absent.
func ParseInvitationPayloadJSON(payloadJSON string) (model.SharedGroup, error) {
	var p invitationPayload
	if err := json.Unmarshal([]byte(payloadJSON), &p); err != nil {
		return model.SharedGroup{}, fmt.Errorf("failed to parse invitation payload: %w", err)
	}
	if strings.TrimSpace(p.GroupID) == "" || strings.TrimSpace(p.GroupNsec) == "" {
		return model.SharedGroup{}, errors.New("invitation payload missing group_id or group_nsec")
	}
	npub := strings.TrimSpace(p.GroupNpub)
	if npub == "" {
		derived, err := NpubFromNsec(p.GroupNsec)
		if err != nil {
			return model.SharedGroup{}, err
		}
		npub = derived
	}
	epoch := int(p.KeyEpoch)
	if epoch < 1 {
		epoch = 1
	}
	return model.SharedGroup{
		GroupID:      p.GroupID,
		GroupNsecHex: p.GroupNsec,
		GroupNpubHex: npub,
		Name:         p.GroupName,
		KeyEpoch:     epoch,
		CreatedAt:    time.Now(),
	}, nil
}

// BuildUnsignedInvitationEvent constructs the kind:30078 invitation event
// (without signature) carrying the already-encrypted payload. Tags match
// the Rust create_unsigned_shared_invitation_event so the Android client
// discovers and parses it correctly.
func BuildUnsignedInvitationEvent(senderHex, recipientHex, groupID, groupName, inviterName, encryptedContent string) nostr.Event {
	dTag := sharedInvitePfx + groupID + "-" + recipientHex
	tags := nostr.Tags{
		nostr.Tag{"d", dTag},
		nostr.Tag{"p", recipientHex},
		nostr.Tag{"protocol", "shared-v1"},
		nostr.Tag{"name", groupName},
	}
	if strings.TrimSpace(inviterName) != "" {
		tags = append(tags, nostr.Tag{"inviter_name", inviterName})
	}
	tags = append(tags, nostr.Tag{"client", "meiso"})
	return nostr.Event{
		PubKey:    senderHex,
		CreatedAt: nostr.Now(),
		Kind:      SharedInviteKind,
		Tags:      tags,
		Content:   encryptedContent,
	}
}

// ReceivedInvitation is a kind:30078 invitation discovered on a relay,
// still encrypted (decryption requires the recipient's NIP-44 key).
type ReceivedInvitation struct {
	EventID          string
	InviterPubkey    string
	GroupID          string
	GroupName        string
	InviterName      string
	EncryptedContent string
	CreatedAt        time.Time
}

// PublishEvent broadcasts a signed event to all configured relays and returns
// nil if at least one relay accepted it.
func (c *Client) PublishEvent(ctx context.Context, ev nostr.Event) error {
	if len(c.relayURLs) == 0 {
		return errors.New("relay urls are empty")
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

// FetchSharedTaskEvents fetches kind:35000 events authored by the group key.
// since<=0 performs a full fetch (robust for addressable LWW events).
func (c *Client) FetchSharedTaskEvents(ctx context.Context, groupNpubHex string, since int64) ([]nostr.Event, error) {
	if len(c.relayURLs) == 0 {
		return nil, errors.New("relay urls are empty")
	}
	filter := nostr.Filter{
		Authors: []string{groupNpubHex},
		Kinds:   []int{SharedTaskKind},
	}
	if since > 0 {
		ts := nostr.Timestamp(since)
		filter.Since = &ts
	}

	fetchCtx, cancel := context.WithTimeout(ctx, 12*time.Second)
	defer cancel()

	// Keep only the newest event per d-tag (LWW), tie-break by event id.
	latest := make(map[string]nostr.Event)
	for ie := range c.pool.FetchMany(fetchCtx, c.relayURLs, filter) {
		if ie.Event == nil {
			continue
		}
		d := extractTagValue(ie.Event.Tags, "d")
		if d == "" {
			continue
		}
		cur, ok := latest[d]
		if !ok || ie.Event.CreatedAt > cur.CreatedAt ||
			(ie.Event.CreatedAt == cur.CreatedAt && ie.Event.ID > cur.ID) {
			latest[d] = *ie.Event
		}
	}

	out := make([]nostr.Event, 0, len(latest))
	for _, ev := range latest {
		out = append(out, ev)
	}
	return out, nil
}

// FetchSharedInvitations fetches kind:30078 invitations addressed to the
// recipient (#p) whose d-tag marks them as shared-v1 invites.
func (c *Client) FetchSharedInvitations(ctx context.Context, recipientHex string) ([]ReceivedInvitation, error) {
	if len(c.relayURLs) == 0 {
		return nil, errors.New("relay urls are empty")
	}
	limit := 50
	filter := nostr.Filter{
		Kinds: []int{SharedInviteKind},
		Tags:  nostr.TagMap{"p": []string{recipientHex}},
		Limit: limit,
	}

	fetchCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	seen := make(map[string]bool)
	var out []ReceivedInvitation
	for ie := range c.pool.FetchMany(fetchCtx, c.relayURLs, filter) {
		if ie.Event == nil {
			continue
		}
		ev := ie.Event
		d := extractTagValue(ev.Tags, "d")
		rest, ok := strings.CutPrefix(d, sharedInvitePfx)
		if !ok {
			continue
		}
		if strings.TrimSpace(ev.Content) == "" {
			continue
		}
		if seen[ev.ID] {
			continue
		}
		seen[ev.ID] = true

		groupID := groupIDFromInviteDTag(rest)
		name := extractTagValue(ev.Tags, "name")
		if name == "" {
			name = "Shared List"
		}
		out = append(out, ReceivedInvitation{
			EventID:          ev.ID,
			InviterPubkey:    ev.PubKey,
			GroupID:          groupID,
			GroupName:        name,
			InviterName:      extractTagValue(ev.Tags, "inviter_name"),
			EncryptedContent: ev.Content,
			CreatedAt:        ev.CreatedAt.Time(),
		})
	}
	return out, nil
}

// groupIDFromInviteDTag extracts the group id from the remainder of a
// "shared-invite-{group_id}-{recipient_hex}" d-tag. The recipient hex is a
// trailing 64-char hex string; group ids are UUIDs that contain hyphens, so we
// strip the trailing "-<64 hex>" suffix. Falls back to the first segment for
// legacy formats — identical to the Rust parser.
func groupIDFromInviteDTag(rest string) string {
	if len(rest) >= 65 {
		pivot := len(rest) - 65
		if rest[pivot] == '-' && isHex(rest[pivot+1:]) {
			return rest[:pivot]
		}
	}
	if idx := strings.IndexByte(rest, '-'); idx >= 0 {
		return rest[:idx]
	}
	return rest
}

func isHex(s string) bool {
	if s == "" {
		return false
	}
	for _, c := range s {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}

// NpubToHex accepts an npub (bech32) or a 64-char hex pubkey and returns hex.
func NpubToHex(input string) (string, error) {
	input = strings.TrimSpace(input)
	if input == "" {
		return "", errors.New("empty pubkey")
	}
	if strings.HasPrefix(input, "npub1") {
		prefix, value, err := nip19.Decode(input)
		if err != nil {
			return "", err
		}
		if prefix != "npub" {
			return "", fmt.Errorf("expected npub, got %s", prefix)
		}
		hex, ok := value.(string)
		if !ok {
			return "", errors.New("unexpected npub payload")
		}
		return hex, nil
	}
	if len(input) == 64 && isHex(input) {
		return strings.ToLower(input), nil
	}
	return "", fmt.Errorf("not a valid npub or hex pubkey: %s", input)
}

func parseSharedTime(v string) time.Time {
	v = strings.TrimSpace(v)
	if v == "" {
		return time.Now()
	}
	for _, layout := range []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02T15:04:05.999999999",
		"2006-01-02T15:04:05",
		"2006-01-02",
	} {
		if t, err := time.Parse(layout, v); err == nil {
			return t
		}
	}
	return time.Now()
}
