package nostrclient

import (
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strings"
)

// ConfigureSocksProxy routes all outbound HTTP/WebSocket traffic (relay
// connections, NIP-65 resolution, remote signer calls) through a SOCKS5 proxy
// such as Tor or Orbot.
//
// go-nostr v0.52 exposes no per-connection dialer hook: when it dials a relay
// without a custom tls.Config it falls back to http.DefaultClient, which uses
// http.DefaultTransport. Setting that transport's Proxy is therefore the
// single lever that reaches every relay socket.
//
// The proxy scheme is forced to socks5h so hostnames are resolved by the proxy
// (the Tor exit), never locally — preventing DNS leaks. Go's net/http resolves
// remotely for both socks5 and socks5h, but socks5h makes the intent explicit.
//
// raw accepts "host:port", "127.0.0.1:9050", or a full "socks5://host:port"
// (or socks5h://). Returns the normalized proxy URL that was applied.
func ConfigureSocksProxy(raw string) (string, error) {
	proxyURL, err := normalizeSocksURL(raw)
	if err != nil {
		return "", err
	}

	transport, ok := http.DefaultTransport.(*http.Transport)
	if !ok {
		return "", fmt.Errorf("http.DefaultTransport is not *http.Transport; cannot apply SOCKS proxy")
	}
	transport.Proxy = http.ProxyURL(proxyURL)

	return proxyURL.String(), nil
}

func normalizeSocksURL(raw string) (*url.URL, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, fmt.Errorf("empty SOCKS proxy address")
	}
	if !strings.Contains(raw, "://") {
		raw = "socks5h://" + raw
	}
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("invalid SOCKS proxy %q: %w", raw, err)
	}
	switch u.Scheme {
	case "socks5", "socks5h":
		// ok
	default:
		return nil, fmt.Errorf("unsupported SOCKS proxy scheme %q (use socks5:// or socks5h://)", u.Scheme)
	}
	// Force remote DNS resolution.
	u.Scheme = "socks5h"
	if u.Host == "" {
		return nil, fmt.Errorf("SOCKS proxy is missing host:port")
	}
	if _, _, err := net.SplitHostPort(u.Host); err != nil {
		return nil, fmt.Errorf("SOCKS proxy host must be host:port: %w", err)
	}
	return u, nil
}
