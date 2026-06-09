package storage

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/higedamc/meiso/cui/internal/model"
)

type SessionStore struct {
	path string
}

func NewSessionStore(baseDir string) *SessionStore {
	return &SessionStore{path: filepath.Join(baseDir, "session.enc")}
}

func (s *SessionStore) Save(session model.Session) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return err
	}
	key, err := loadOrCreateMasterKey()
	if err != nil {
		return err
	}
	raw, err := json.Marshal(session)
	if err != nil {
		return err
	}
	enc, err := encrypt(raw, key)
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, enc, 0o600)
}

func (s *SessionStore) Load() (*model.Session, error) {
	b, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	key, err := loadOrCreateMasterKey()
	if err != nil {
		return nil, err
	}
	raw, err := decrypt(b, key)
	if err != nil {
		return nil, err
	}
	var session model.Session
	if err := json.Unmarshal(raw, &session); err != nil {
		return nil, err
	}
	return &session, nil
}

func (s *SessionStore) Clear() error {
	if err := os.Remove(s.path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

func loadOrCreateMasterKey() ([]byte, error) {
	if env := os.Getenv("MEISO_CUI_MASTER_KEY"); env != "" {
		hash := sha256.Sum256([]byte(env))
		return hash[:], nil
	}
	if runtime.GOOS != "darwin" {
		return nil, errors.New("set MEISO_CUI_MASTER_KEY on non-macOS platforms")
	}

	service := "meiso-cui-master-key"
	account := "meiso-cui"

	cmd := exec.Command("security", "find-generic-password", "-a", account, "-s", service, "-w")
	out, err := cmd.Output()
	if err == nil {
		decoded, decErr := base64.StdEncoding.DecodeString(strings.TrimSpace(string(out)))
		if decErr != nil {
			return nil, fmt.Errorf("decode keychain key: %w", decErr)
		}
		if len(decoded) != 32 {
			return nil, fmt.Errorf("invalid key length: %d", len(decoded))
		}
		return decoded, nil
	}

	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return nil, err
	}
	encoded := base64.StdEncoding.EncodeToString(key)
	add := exec.Command("security", "add-generic-password", "-a", account, "-s", service, "-w", encoded, "-U")
	if addErr := add.Run(); addErr != nil {
		return nil, fmt.Errorf("store master key in keychain (or set MEISO_CUI_MASTER_KEY): %w", addErr)
	}
	return key, nil
}

func encrypt(plain []byte, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}
	cipherText := gcm.Seal(nil, nonce, plain, nil)
	out := append(nonce, cipherText...)
	return out, nil
}

func decrypt(enc []byte, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonceSize := gcm.NonceSize()
	if len(enc) < nonceSize {
		return nil, errors.New("invalid encrypted payload")
	}
	nonce := enc[:nonceSize]
	cipherText := enc[nonceSize:]
	return gcm.Open(nil, nonce, cipherText, nil)
}
