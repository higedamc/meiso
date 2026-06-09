package model

import (
	"slices"
	"strings"
	"time"
)

type Session struct {
	AccessToken   string    `json:"access_token"`
	PubKey        string    `json:"pubkey"`
	SignerName    string    `json:"signer_name"`
	SignEndpoint  string    `json:"sign_endpoint"`
	RefreshHint   string    `json:"refresh_hint,omitempty"`
	RelayURL      string    `json:"relay_url,omitempty"` // legacy single-relay field
	RelayURLs     []string  `json:"relay_urls,omitempty"`
	ExpiresAt     time.Time `json:"expires_at"`
	LastSuccessAt time.Time `json:"last_success_at"`
	FailureCount  int       `json:"failure_count"`
}

func (s Session) IsExpired(now time.Time) bool {
	return now.After(s.ExpiresAt)
}

func (s Session) RelayList(defaults []string) []string {
	var out []string
	if len(s.RelayURLs) > 0 {
		out = append(out, s.RelayURLs...)
	}
	if strings.TrimSpace(s.RelayURL) != "" {
		out = append(out, s.RelayURL)
	}
	if len(out) == 0 {
		out = append(out, defaults...)
	}
	return normalizeRelayList(out)
}

func normalizeRelayList(in []string) []string {
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
