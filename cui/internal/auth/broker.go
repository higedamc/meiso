package auth

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os/exec"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/higedamc/meiso/cui/internal/model"
)

type Broker struct {
	CallbackTimeout time.Duration
	HTTPClient      *http.Client
}

func NewBroker() *Broker {
	return &Broker{
		CallbackTimeout: 2 * time.Minute,
		HTTPClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

func (b *Broker) Login(ctx context.Context, loginURL string, defaultRelays []string) (model.Session, error) {
	if loginURL == "" || strings.EqualFold(loginURL, "auto") {
		return b.loginWithNIP07(ctx, defaultRelays)
	}
	if err := b.preflightAuthEndpoint(ctx, loginURL); err != nil {
		return model.Session{}, err
	}

	state, err := randomHex(16)
	if err != nil {
		return model.Session{}, err
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return model.Session{}, err
	}
	defer ln.Close()

	type callbackResult struct {
		session model.Session
		err     error
	}
	resultCh := make(chan callbackResult, 1)

	mux := http.NewServeMux()
	srv := &http.Server{Handler: mux}

	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		if q.Get("state") != state {
			resultCh <- callbackResult{err: errors.New("state mismatch")}
			http.Error(w, "state mismatch", http.StatusBadRequest)
			return
		}

		expiresIn, _ := strconv.Atoi(q.Get("expires_in"))
		if expiresIn <= 0 {
			expiresIn = 86400
		}
		session := model.Session{
			AccessToken:   q.Get("token"),
			PubKey:        q.Get("pubkey"),
			SignerName:    "browser",
			SignEndpoint:  q.Get("sign_endpoint"),
			RefreshHint:   q.Get("refresh_hint"),
			RelayURLs:     normalizeRelayList(parseRelayCSV(q.Get("relays"), defaultRelays)),
			ExpiresAt:     time.Now().Add(time.Duration(expiresIn) * time.Second),
			LastSuccessAt: time.Now(),
		}
		if len(session.RelayURLs) > 0 {
			session.RelayURL = session.RelayURLs[0]
		}
		if session.AccessToken == "" || session.PubKey == "" {
			resultCh <- callbackResult{err: errors.New("missing token/pubkey in callback")}
			http.Error(w, "missing token/pubkey", http.StatusBadRequest)
			return
		}

		_, _ = w.Write([]byte("Meiso CUI login completed. You can return to the terminal."))
		resultCh <- callbackResult{session: session}
	})

	go func() {
		_ = srv.Serve(ln)
	}()

	callbackURL := fmt.Sprintf("http://%s/callback", ln.Addr().String())
	authURL, err := appendAuthParams(loginURL, callbackURL, state)
	if err != nil {
		_ = srv.Shutdown(ctx)
		return model.Session{}, err
	}

	if err := openBrowser(authURL); err != nil {
		_ = srv.Shutdown(ctx)
		return model.Session{}, err
	}

	waitCtx, cancel := context.WithTimeout(ctx, b.CallbackTimeout)
	defer cancel()

	select {
	case res := <-resultCh:
		_ = srv.Shutdown(context.Background())
		return res.session, res.err
	case <-waitCtx.Done():
		_ = srv.Shutdown(context.Background())
		return model.Session{}, errors.New("login callback timeout")
	}
}

func (b *Broker) loginWithNIP07(ctx context.Context, defaultRelays []string) (model.Session, error) {
	state, err := randomHex(16)
	if err != nil {
		return model.Session{}, err
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return model.Session{}, err
	}
	defer ln.Close()

	type callbackResult struct {
		session model.Session
		err     error
	}
	resultCh := make(chan callbackResult, 1)
	mux := http.NewServeMux()
	srv := &http.Server{Handler: mux}

	mux.HandleFunc("/auth", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("state") != state {
			http.Error(w, "state mismatch", http.StatusBadRequest)
			return
		}
		_, _ = w.Write([]byte(nip07AuthHTML))
	})

	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		if q.Get("state") != state {
			resultCh <- callbackResult{err: errors.New("state mismatch")}
			http.Error(w, "state mismatch", http.StatusBadRequest)
			return
		}
		pubkey := strings.TrimSpace(q.Get("pubkey"))
		if pubkey == "" {
			resultCh <- callbackResult{err: errors.New("missing pubkey from NIP-07")}
			http.Error(w, "missing pubkey", http.StatusBadRequest)
			return
		}
		relayList := normalizeRelayList(parseRelayCSV(q.Get("relays"), defaultRelays))
		session := model.Session{
			AccessToken:   "nip07-local",
			PubKey:        pubkey,
			SignerName:    "nip07",
			SignEndpoint:  "",
			RefreshHint:   "",
			RelayURLs:     relayList,
			ExpiresAt:     time.Now().Add(30 * 24 * time.Hour),
			LastSuccessAt: time.Now(),
		}
		if len(session.RelayURLs) > 0 {
			session.RelayURL = session.RelayURLs[0]
		}
		_, _ = w.Write([]byte("Meiso CUI NIP-07 login completed. You can return to the terminal."))
		resultCh <- callbackResult{session: session}
	})

	go func() {
		_ = srv.Serve(ln)
	}()

	authURL := fmt.Sprintf("http://%s/auth?state=%s", ln.Addr().String(), state)
	if err := openBrowser(authURL); err != nil {
		_ = srv.Shutdown(ctx)
		return model.Session{}, err
	}

	waitCtx, cancel := context.WithTimeout(ctx, b.CallbackTimeout)
	defer cancel()

	select {
	case res := <-resultCh:
		_ = srv.Shutdown(context.Background())
		return res.session, res.err
	case <-waitCtx.Done():
		_ = srv.Shutdown(context.Background())
		return model.Session{}, errors.New("nip-07 login callback timeout")
	}
}

func appendAuthParams(loginURL string, callbackURL string, state string) (string, error) {
	u, err := url.Parse(loginURL)
	if err != nil {
		return "", err
	}
	q := u.Query()
	q.Set("callback", callbackURL)
	q.Set("state", state)
	u.RawQuery = q.Encode()
	return u.String(), nil
}

func openBrowser(u string) error {
	cmd := exec.Command("open", u)
	return cmd.Run()
}

func randomHex(size int) (string, error) {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

const nip07AuthHTML = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Meiso CUI NIP-07 Login</title>
    <style>
      body { font-family: -apple-system, system-ui, sans-serif; margin: 2rem; }
      code { background: #f2f2f2; padding: 2px 6px; border-radius: 4px; }
    </style>
  </head>
  <body>
    <h2>Meiso CUI Login (NIP-07)</h2>
    <p id="msg">Waiting for browser extension...</p>
    <script>
      (async function () {
        const msg = document.getElementById('msg');
        const params = new URLSearchParams(window.location.search);
        const state = params.get('state');
        try {
          if (!window.nostr || typeof window.nostr.getPublicKey !== 'function') {
            throw new Error('NIP-07 extension not detected in this browser');
          }
          const pubkey = await window.nostr.getPublicKey();
          let relaysCsv = '';
          if (typeof window.nostr.getRelays === 'function') {
            try {
              const relayObj = await window.nostr.getRelays();
              const entries = Object.entries(relayObj || {});
              const writeRelays = entries
                .filter(([, perms]) => !perms || perms.write !== false)
                .map(([url]) => url);
              const allRelays = entries.map(([url]) => url);
              const relays = writeRelays.length > 0 ? writeRelays : allRelays;
              relaysCsv = relays.join(',');
            } catch (_) {}
          }
          let callback = '/callback?state=' + encodeURIComponent(state) + '&pubkey=' + encodeURIComponent(pubkey);
          if (relaysCsv) {
            callback += '&relays=' + encodeURIComponent(relaysCsv);
          }
          msg.textContent = 'Extension approved. Finishing login...';
          window.location.href = callback;
        } catch (e) {
          msg.textContent = 'Login failed: ' + (e && e.message ? e.message : String(e));
        }
      })();
    </script>
  </body>
</html>`

func parseRelayCSV(raw string, defaults []string) []string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return defaults
	}
	return strings.Split(raw, ",")
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

func (b *Broker) preflightAuthEndpoint(ctx context.Context, loginURL string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, loginURL, nil)
	if err != nil {
		return fmt.Errorf("invalid auth url %q: %w", loginURL, err)
	}
	resp, err := b.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("auth endpoint unreachable (%s): %w\nhint: set MEISO_CUI_AUTH_URL to a running signer login endpoint", loginURL, err)
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	if resp.StatusCode >= 500 {
		return fmt.Errorf("auth endpoint responded with %s (%s)", resp.Status, loginURL)
	}
	return nil
}

type refreshRequest struct {
	Token string `json:"token"`
}

type refreshResponse struct {
	Token        string `json:"token"`
	ExpiresInSec int    `json:"expires_in"`
	SignEndpoint string `json:"sign_endpoint"`
}

func (b *Broker) Refresh(ctx context.Context, session model.Session) (model.Session, error) {
	if session.RefreshHint == "" {
		return session, errors.New("refresh_hint is empty")
	}

	reqBody, err := json.Marshal(refreshRequest{Token: session.AccessToken})
	if err != nil {
		return session, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, session.RefreshHint, bytes.NewReader(reqBody))
	if err != nil {
		return session, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := b.HTTPClient.Do(req)
	if err != nil {
		return session, err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return session, fmt.Errorf("refresh failed: %s", resp.Status)
	}
	var parsed refreshResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return session, err
	}
	if parsed.Token != "" {
		session.AccessToken = parsed.Token
	}
	if parsed.SignEndpoint != "" {
		session.SignEndpoint = parsed.SignEndpoint
	}
	if parsed.ExpiresInSec <= 0 {
		parsed.ExpiresInSec = 86400
	}
	session.ExpiresAt = time.Now().Add(time.Duration(parsed.ExpiresInSec) * time.Second)
	session.FailureCount = 0
	return session, nil
}
