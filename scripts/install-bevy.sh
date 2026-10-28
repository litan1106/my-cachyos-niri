#!/bin/bash

# Install the native libraries Bevy needs to build and run on CachyOS + niri.
# Requires sudo for the pacman step. Rust itself comes from install-rust.sh;
# run that first.
#
# Notes for this machine (verified):
#   - The GPU is AMD, so vulkan-radeon is the Vulkan driver wgpu uses. We only
#     warn if no Vulkan ICD is present rather than guessing a vendor driver.
#   - Rust >= 1.90 links x86_64-linux-gnu with its bundled lld by default, so
#     there is no global linker config here. mold is an optional per-project
#     speedup (see the end-of-script notes).

set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found. Install Rust first:" >&2
  echo "  $script_dir/install-rust.sh" >&2
  exit 1
fi

echo "Installing Bevy's native dependencies..."

# Bevy's Linux deps: alsa-lib (audio), systemd-libs (libudev, for gamepads),
# libxkbcommon + wayland (Wayland window backend), libx11/libxcursor/libxrandr/
# libxi (X11 fallback), vulkan-icd-loader (wgpu), pkgconf + clang (build
# scripts). --needed makes a re-run a no-op for anything already installed.
sudo pacman -S --needed --noconfirm \
  pkgconf clang \
  alsa-lib systemd-libs \
  libxkbcommon wayland \
  libx11 libxcursor libxrandr libxi \
  vulkan-icd-loader

if ! ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1; then
  echo
  echo "Warning: no Vulkan driver (ICD) found in /usr/share/vulkan/icd.d/."
  echo "Bevy renders through Vulkan; install your GPU's driver, e.g.:"
  echo "  sudo pacman -S vulkan-radeon   # AMD"
fi

cat <<EOF

Bevy's dependencies are installed. Start a project with:

  cargo new my_game && cd my_game
  cargo add bevy
  cargo run

The first build compiles all of Bevy and takes a few minutes; later builds are
incremental. For faster iteration, Bevy recommends in Cargo.toml:

  [profile.dev]
  opt-level = 1

  [profile.dev.package."*"]
  opt-level = 3

Optional faster linking with mold (sudo pacman -S mold), per project in
.cargo/config.toml:

  [target.x86_64-unknown-linux-gnu]
  linker = "clang"
  rustflags = ["-C", "link-arg=-fuse-ld=mold"]

To uninstall, remove only what nothing else needs — most of these libraries
are shared with the desktop, so pacman will refuse the ones still in use:

  sudo pacman -Rns pkgconf clang

EOF
