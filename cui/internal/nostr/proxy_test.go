package nostrclient

import "testing"

func TestNormalizeSocksURL(t *testing.T) {
	cases := []struct {
		in   string
		want string
		ok   bool
	}{
		{"127.0.0.1:9050", "socks5h://127.0.0.1:9050", true},
		{"socks5://127.0.0.1:9050", "socks5h://127.0.0.1:9050", true}, // forced to socks5h
		{"socks5h://10.0.0.1:9150", "socks5h://10.0.0.1:9150", true},
		{"  localhost:9050  ", "socks5h://localhost:9050", true},
		{"", "", false},
		{"http://127.0.0.1:8080", "", false}, // unsupported scheme
		{"127.0.0.1", "", false},             // missing port
	}
	for _, c := range cases {
		u, err := normalizeSocksURL(c.in)
		if c.ok {
			if err != nil {
				t.Errorf("normalizeSocksURL(%q) unexpected error: %v", c.in, err)
				continue
			}
			if u.String() != c.want {
				t.Errorf("normalizeSocksURL(%q) = %q, want %q", c.in, u.String(), c.want)
			}
		} else if err == nil {
			t.Errorf("normalizeSocksURL(%q) expected error, got %q", c.in, u.String())
		}
	}
}
