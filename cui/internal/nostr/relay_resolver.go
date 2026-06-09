package nostrclient

import (
	"context"
	"errors"
	"slices"
	"strings"
	"time"

	"github.com/nbd-wtf/go-nostr"
)

// ResolveWriteRelays tries to discover relays from NIP-65 (kind 10002).
// If discovery fails or returns empty, callers should keep their existing relays.
func ResolveWriteRelays(ctx context.Context, pubkey string, seedRelays []string) ([]string, error) {
	pubkey = strings.TrimSpace(pubkey)
	if pubkey == "" {
		return nil, errors.New("pubkey is empty")
	}
	seeds := normalizeRelays(seedRelays)
	if len(seeds) == 0 {
		return nil, errors.New("no seed relays provided")
	}

	pool := nostr.NewSimplePool(context.Background())
	f := nostr.Filter{
		Authors: []string{pubkey},
		Kinds:   []int{10002},
		Limit:   1,
	}
	qctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()

	var latest *nostr.Event
	for ie := range pool.FetchMany(qctx, seeds, f) {
		if ie.Event == nil {
			continue
		}
		if latest == nil || ie.Event.CreatedAt > latest.CreatedAt {
			evCopy := *ie.Event
			latest = &evCopy
		}
	}
	if latest == nil {
		return nil, errors.New("nip-65 relay list not found")
	}

	var out []string
	for _, tag := range latest.Tags {
		// NIP-65: ["r","wss://...","write|read|..."]
		if len(tag) < 2 || tag[0] != "r" {
			continue
		}
		u := strings.TrimSpace(tag[1])
		if u == "" {
			continue
		}
		marker := ""
		if len(tag) >= 3 {
			marker = strings.ToLower(strings.TrimSpace(tag[2]))
		}
		// For sync publish, keep "write" and unspecified entries.
		if marker == "read" {
			continue
		}
		if !slices.Contains(out, u) {
			out = append(out, u)
		}
	}
	if len(out) == 0 {
		return nil, errors.New("nip-65 has no write relays")
	}
	return out, nil
}

func normalizeRelays(in []string) []string {
	out := make([]string, 0, len(in))
	for _, v := range in {
		v = strings.TrimSpace(v)
		if v == "" {
			continue
		}
		if !slices.Contains(out, v) {
			out = append(out, v)
		}
	}
	return out
}
