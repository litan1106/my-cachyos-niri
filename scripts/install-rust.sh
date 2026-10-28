#!/bin/bash

# Install Rust + Cargo (via rustup) on CachyOS + niri. Requires sudo for the
# pacman step.
#
# Notes for this machine (verified):
#   - rustup comes from the sync repos, NOT the curl | sh installer. The pacman
#     package drops rustc/cargo proxies into /usr/bin, so no PATH edit is needed
#     for the toolchain itself. It conflicts with the 'rust' package, which is
#     what we want — one toolchain manager, not two.
#   - Rust >= 1.90 links x86_64-linux-gnu with its bundled lld by default, so
#     there is no global linker config here.

set -e

echo "Installing rustup..."

# --needed makes a re-run a no-op if rustup is already installed.
sudo pacman -S --needed --noconfirm rustup

# rustup reuses an existing ~/.rustup, so a leftover stable toolchain is just
# updated in place instead of re-downloaded. The default profile includes
# rustc, cargo, rustfmt and clippy.
echo "Setting the default toolchain to stable..."
rustup default stable
rustup update stable

# Tools installed with `cargo install` land in ~/.cargo/bin. Put it on PATH for
# the niri session the same way setup-local-bin-path.sh handles ~/.local/bin.
conf_dir="$HOME/.config/environment.d"
conf="$conf_dir/20-cargo-bin.conf"
mkdir -p "$conf_dir"
cat >"$conf" <<'EOF'
# Added by install-rust.sh — put ~/.cargo/bin (cargo install) on PATH.
PATH=${HOME}/.cargo/bin:${PATH}
EOF
echo "Wrote $conf"

cat <<EOF

Rust is installed:

  $(rustc --version)
  $(cargo --version)

Start a project with:

  cargo new hello && cd hello
  cargo run

(Re-login once so new terminals see ~/.cargo/bin on PATH.)

To uninstall: sudo pacman -Rns rustup && rm -rf ~/.rustup ~/.cargo \\
              && rm -f $conf

EOF
