package nostrclient

import (
	"net"
	"net/http"
	"testing"
	"time"
)

// TestSocksProxyRoutesDefaultTransport proves that ConfigureSocksProxy makes
// http.DefaultTransport (the client go-nostr uses for every relay dial) connect
// to the proxy and speak SOCKS5 — i.e. relay traffic really is tunneled.
func TestSocksProxyRoutesDefaultTransport(t *testing.T) {
	// Restore the global transport afterwards so other tests are unaffected.
	if tr, ok := http.DefaultTransport.(*http.Transport); ok {
		prev := tr.Proxy
		t.Cleanup(func() { tr.Proxy = prev })
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer ln.Close()

	if _, err := ConfigureSocksProxy(ln.Addr().String()); err != nil {
		t.Fatalf("ConfigureSocksProxy: %v", err)
	}

	greeting := make(chan byte, 1)
	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		buf := make([]byte, 1)
		if _, err := conn.Read(buf); err == nil {
			greeting <- buf[0]
		}
	}()

	// Fire a request through the (now proxied) default transport. It will block
	// on the SOCKS handshake we never complete — we only need the first byte.
	client := &http.Client{Transport: http.DefaultTransport, Timeout: 3 * time.Second}
	go func() {
		resp, err := client.Get("http://relay.example.invalid/")
		if err == nil {
			_ = resp.Body.Close()
		}
	}()

	select {
	case b := <-greeting:
		if b != 0x05 {
			t.Fatalf("first byte to proxy = 0x%02x, want 0x05 (SOCKS5)", b)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("default transport did not connect to the SOCKS proxy")
	}
}
