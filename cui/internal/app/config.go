package app

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
)

type Config struct {
	DataDir          string
	AuthURL          string
	DefaultRelayURLs []string
	SocksProxy       string
}

func LoadConfig() (Config, error) {
	base, err := os.UserConfigDir()
	if err != nil {
		return Config{}, err
	}
	cfg := Config{
		DataDir: filepath.Join(base, "meiso-cui"),
		AuthURL: getEnv("MEISO_CUI_AUTH_URL", "auto"),
		DefaultRelayURLs: parseRelayList(getEnv(
			"MEISO_CUI_RELAY_URL",
			"wss://relay.damus.io",
		)),
		SocksProxy: strings.TrimSpace(os.Getenv("MEISO_CUI_SOCKS_PROXY")),
	}
	if cfg.DataDir == "" {
		return Config{}, errors.New("failed to resolve data directory")
	}
	return cfg, nil
}

func getEnv(key, fallback string) string {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	return v
}

func parseRelayList(raw string) []string {
	var out []string
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		out = append(out, part)
	}
	if len(out) == 0 {
		out = []string{"wss://relay.damus.io"}
	}
	return out
}
