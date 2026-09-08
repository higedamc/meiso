package main

import (
	"context"
	"fmt"
	"os"

	"github.com/higedamc/meiso/cui/internal/app"
	"github.com/higedamc/meiso/cui/internal/cli"
	nostrclient "github.com/higedamc/meiso/cui/internal/nostr"
)

func main() {
	cfg, err := app.LoadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "config error: %v\n", err)
		os.Exit(1)
	}
	if cfg.SocksProxy != "" {
		applied, err := nostrclient.ConfigureSocksProxy(cfg.SocksProxy)
		if err != nil {
			fmt.Fprintf(os.Stderr, "socks proxy error: %v\n", err)
			os.Exit(1)
		}
		fmt.Fprintf(os.Stderr, "routing all relay traffic via SOCKS5 proxy %s\n", applied)
	}
	svc := app.NewService(cfg)
	if err := cli.Run(context.Background(), svc, os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}
