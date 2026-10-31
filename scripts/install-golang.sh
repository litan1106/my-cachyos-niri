#!/bin/bash

# Install Go and its standard dev tools on CachyOS + Hyprland. Requires sudo for
# the pacman step.
#
# Notes for this machine (verified):
#   - go, gopls, delve and golangci-lint all come from the sync repos (CachyOS
#     ships znver4 rebuilds), so updates ride along with `pacman -Syu` instead
#     of drifting like a tarball install in /usr/local/go would.
#   - GOPATH is left at its default (~/go). A ~/go/pkg/mod module cache may
#     already exist from earlier builds; it is reused as-is.
#   - `go install` drops binaries in ~/go/bin, which is not on PATH by default,
#     so we add it the same way setup-local-bin-path.sh handles ~/.local/bin.

set -e

echo "Installing Go and dev tools..."

# gopls: language server (Zed/VS Code). delve: debugger (dlv). golangci-lint:
# linter runner that bundles staticcheck, govet, errcheck, etc. --needed makes
# a re-run a no-op for anything already installed.
sudo pacman -S --needed --noconfirm \
  go gopls delve golangci-lint

# Tools installed with `go install` land in $(go env GOPATH)/bin. Put it on
# PATH for the systemd user environment. environment.d expands ${HOME}/${PATH} (not ~).
conf_dir="$HOME/.config/environment.d"
conf="$conf_dir/30-go-bin.conf"
mkdir -p "$conf_dir"
cat >"$conf" <<'EOF'
# Added by install-golang.sh — put ~/go/bin (go install) on PATH.
PATH=${HOME}/go/bin:${PATH}
EOF
echo "Wrote $conf"

cat <<EOF

Go is installed:

  $(go version)
  GOPATH=$(go env GOPATH)
  $(gopls version | head -n1)
  $(dlv version | sed -n 2p)
  $(golangci-lint --version)

Start a project with:

  mkdir hello && cd hello
  go mod init example.com/hello
  go run .

Common commands: go test ./...  ·  go vet ./...  ·  golangci-lint run
Debug with:      dlv debug  (or dlv test)

(Re-login once so new terminals see ~/go/bin on PATH.)

To uninstall: sudo pacman -Rns go gopls delve golangci-lint && rm -rf ~/go ~/.cache/go-build \\
              && rm -f $conf

EOF
