BIN     := meiso
PKG     := ./cmd/meiso

.PHONY: build install uninstall clean

build:
	go build -o $(BIN) $(PKG)

install:
	go install $(PKG)

uninstall:
	rm -f $(shell go env GOPATH)/bin/$(BIN)
	rm -rf $(HOME)/Library/Application\ Support/meiso-cui
	@echo "uninstalled $(BIN)"

clean:
	rm -f $(BIN)
