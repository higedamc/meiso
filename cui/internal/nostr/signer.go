package nostrclient

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os/exec"
	"time"

	"github.com/higedamc/meiso/cui/internal/model"
	"github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
)

type Signer interface {
	PublicKey(ctx context.Context) (string, error)
	Sign(ctx context.Context, ev *nostr.Event) error
	EncryptNIP44(ctx context.Context, recipientPubkey string, plaintext string) (string, error)
	DecryptNIP44(ctx context.Context, senderPubkey string, ciphertext string) (string, error)
	Name() string
}

type LocalSigner struct {
	secret string
	pubkey string
}

func NewLocalSigner(secret string) (*LocalSigner, error) {
	if secret == "" {
		return nil, errors.New("secret key is required")
	}
	pub, err := nostr.GetPublicKey(secret)
	if err != nil {
		return nil, err
	}
	return &LocalSigner{
		secret: secret,
		pubkey: pub,
	}, nil
}

func (s *LocalSigner) PublicKey(_ context.Context) (string, error) {
	return s.pubkey, nil
}

func (s *LocalSigner) Name() string {
	return "local"
}

func (s *LocalSigner) Sign(_ context.Context, ev *nostr.Event) error {
	ev.PubKey = s.pubkey
	return ev.Sign(s.secret)
}

func (s *LocalSigner) EncryptNIP44(_ context.Context, recipientPubkey string, plaintext string) (string, error) {
	ck, err := nip44.GenerateConversationKey(recipientPubkey, s.secret)
	if err != nil {
		return "", err
	}
	return nip44.Encrypt(plaintext, ck)
}

func (s *LocalSigner) DecryptNIP44(_ context.Context, senderPubkey string, ciphertext string) (string, error) {
	ck, err := nip44.GenerateConversationKey(senderPubkey, s.secret)
	if err != nil {
		return "", err
	}
	return nip44.Decrypt(ciphertext, ck)
}

type BrowserSigner struct {
	session model.Session
	client  *http.Client
}

func NewBrowserSigner(session model.Session) *BrowserSigner {
	return &BrowserSigner{
		session: session,
		client: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

func (s *BrowserSigner) PublicKey(_ context.Context) (string, error) {
	if s.session.PubKey == "" {
		return "", errors.New("session has no pubkey")
	}
	return s.session.PubKey, nil
}

func (s *BrowserSigner) Name() string {
	return "browser"
}

type signRequest struct {
	Token string      `json:"token"`
	Event nostr.Event `json:"event"`
}

type signResponse struct {
	Event nostr.Event `json:"event"`
}

func (s *BrowserSigner) Sign(ctx context.Context, ev *nostr.Event) error {
	if s.session.SignEndpoint == "" {
		return errors.New("browser signer has empty sign endpoint")
	}
	reqBody, err := json.Marshal(signRequest{
		Token: s.session.AccessToken,
		Event: *ev,
	})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.session.SignEndpoint, bytes.NewReader(reqBody))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return fmt.Errorf("sign endpoint error: %s", resp.Status)
	}
	var parsed signResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return err
	}
	*ev = parsed.Event
	if ev.Sig == "" {
		return errors.New("sign endpoint returned empty signature")
	}
	return nil
}

func (s *BrowserSigner) EncryptNIP44(_ context.Context, _ string, _ string) (string, error) {
	return "", errors.New("remote browser signer mode does not expose NIP-44 encryption")
}

func (s *BrowserSigner) DecryptNIP44(_ context.Context, _ string, _ string) (string, error) {
	return "", errors.New("remote browser signer mode does not expose NIP-44 decryption")
}

type NIP07Signer struct {
	pubkey string
}

func NewNIP07Signer(pubkey string) *NIP07Signer {
	return &NIP07Signer{pubkey: pubkey}
}

func (s *NIP07Signer) Name() string {
	return "nip07"
}

func (s *NIP07Signer) PublicKey(_ context.Context) (string, error) {
	if s.pubkey == "" {
		return "", errors.New("nip07 pubkey is empty")
	}
	return s.pubkey, nil
}

func (s *NIP07Signer) Sign(ctx context.Context, ev *nostr.Event) error {
	state, err := randomState()
	if err != nil {
		return err
	}
	unsigned, err := json.Marshal(ev)
	if err != nil {
		return err
	}
	eventB64 := base64.StdEncoding.EncodeToString(unsigned)

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return err
	}
	defer ln.Close()

	type signedResult struct {
		ev  nostr.Event
		err error
	}
	resultCh := make(chan signedResult, 1)
	mux := http.NewServeMux()
	srv := &http.Server{Handler: mux}

	mux.HandleFunc("/sign", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("state") != state {
			http.Error(w, "state mismatch", http.StatusBadRequest)
			return
		}
		html := fmt.Sprintf(nip07SignHTMLTemplate, eventB64)
		_, _ = w.Write([]byte(html))
	})

	mux.HandleFunc("/signed", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("state") != state {
			http.Error(w, "state mismatch", http.StatusBadRequest)
			resultCh <- signedResult{err: errors.New("state mismatch")}
			return
		}
		defer r.Body.Close()
		var signed nostr.Event
		if err := json.NewDecoder(r.Body).Decode(&signed); err != nil {
			http.Error(w, "invalid signed event", http.StatusBadRequest)
			resultCh <- signedResult{err: err}
			return
		}
		if signed.Sig == "" {
			http.Error(w, "missing signature", http.StatusBadRequest)
			resultCh <- signedResult{err: errors.New("nip07 returned empty signature")}
			return
		}
		_, _ = w.Write([]byte("Signed. Return to terminal."))
		resultCh <- signedResult{ev: signed}
	})

	go func() {
		_ = srv.Serve(ln)
	}()

	signURL := fmt.Sprintf("http://%s/sign?state=%s", ln.Addr().String(), state)
	if err := exec.Command("open", signURL).Run(); err != nil {
		_ = srv.Shutdown(ctx)
		return err
	}

	waitCtx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()
	select {
	case res := <-resultCh:
		_ = srv.Shutdown(context.Background())
		if res.err != nil {
			return res.err
		}
		*ev = res.ev
		return nil
	case <-waitCtx.Done():
		_ = srv.Shutdown(context.Background())
		return errors.New("nip07 sign timeout")
	}
}

func (s *NIP07Signer) DecryptNIP44(_ context.Context, _ string, _ string) (string, error) {
	return "", errors.New("nip07 signer does not support NIP-44 decryption in CUI; use login-local instead")
}

func (s *NIP07Signer) EncryptNIP44(ctx context.Context, recipientPubkey string, plaintext string) (string, error) {
	state, err := randomState()
	if err != nil {
		return "", err
	}
	plaintextB64 := base64.StdEncoding.EncodeToString([]byte(plaintext))

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return "", err
	}
	defer ln.Close()

	type encResult struct {
		content string
		err     error
	}
	resultCh := make(chan encResult, 1)
	mux := http.NewServeMux()
	srv := &http.Server{Handler: mux}

	mux.HandleFunc("/encrypt", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("state") != state {
			http.Error(w, "state mismatch", http.StatusBadRequest)
			return
		}
		html := fmt.Sprintf(nip07EncryptHTMLTemplate, recipientPubkey, plaintextB64)
		_, _ = w.Write([]byte(html))
	})

	mux.HandleFunc("/encrypted", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("state") != state {
			http.Error(w, "state mismatch", http.StatusBadRequest)
			resultCh <- encResult{err: errors.New("state mismatch")}
			return
		}
		defer r.Body.Close()
		var payload struct {
			Content string `json:"content"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			http.Error(w, "invalid payload", http.StatusBadRequest)
			resultCh <- encResult{err: err}
			return
		}
		if payload.Content == "" {
			http.Error(w, "missing encrypted content", http.StatusBadRequest)
			resultCh <- encResult{err: errors.New("nip07 returned empty encrypted content")}
			return
		}
		_, _ = w.Write([]byte("Encrypted. Return to terminal."))
		resultCh <- encResult{content: payload.Content}
	})

	go func() {
		_ = srv.Serve(ln)
	}()

	encryptURL := fmt.Sprintf("http://%s/encrypt?state=%s", ln.Addr().String(), state)
	if err := exec.Command("open", encryptURL).Run(); err != nil {
		_ = srv.Shutdown(ctx)
		return "", err
	}

	waitCtx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()
	select {
	case res := <-resultCh:
		_ = srv.Shutdown(context.Background())
		return res.content, res.err
	case <-waitCtx.Done():
		_ = srv.Shutdown(context.Background())
		return "", errors.New("nip07 encrypt timeout")
	}
}

func randomState() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

const nip07SignHTMLTemplate = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Meiso CUI NIP-07 Sign</title>
    <style>body{font-family:-apple-system,system-ui,sans-serif;margin:2rem;}</style>
  </head>
  <body>
    <h3>Sign event with NIP-07</h3>
    <p id="msg">Waiting for extension approval...</p>
    <script>
      (async function () {
        const msg = document.getElementById('msg');
        try {
          if (!window.nostr || typeof window.nostr.signEvent !== 'function') {
            throw new Error('NIP-07 extension not detected');
          }
          const encoded = "%s";
          const unsignedEvent = JSON.parse(atob(encoded));
          const signed = await window.nostr.signEvent(unsignedEvent);
          await fetch(window.location.origin + '/signed' + window.location.search, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify(signed)
          });
          msg.textContent = 'Signed. You can return to terminal.';
        } catch (e) {
          msg.textContent = 'Sign failed: ' + (e && e.message ? e.message : String(e));
        }
      })();
    </script>
  </body>
</html>`

const nip07EncryptHTMLTemplate = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Meiso CUI NIP-07 Encrypt</title>
    <style>body{font-family:-apple-system,system-ui,sans-serif;margin:2rem;}</style>
  </head>
  <body>
    <h3>Encrypt with NIP-44</h3>
    <p id="msg">Waiting for extension approval...</p>
    <script>
      (async function () {
        const msg = document.getElementById('msg');
        try {
          if (!window.nostr || !window.nostr.nip44 || typeof window.nostr.nip44.encrypt !== 'function') {
            throw new Error('NIP-44 encrypt is not available in this NIP-07 extension');
          }
          const pubkey = "%s";
          const plaintext = atob("%s");
          const encrypted = await window.nostr.nip44.encrypt(pubkey, plaintext);
          await fetch(window.location.origin + '/encrypted' + window.location.search, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ content: encrypted })
          });
          msg.textContent = 'Encrypted. You can return to terminal.';
        } catch (e) {
          msg.textContent = 'Encrypt failed: ' + (e && e.message ? e.message : String(e));
        }
      })();
    </script>
  </body>
</html>`
