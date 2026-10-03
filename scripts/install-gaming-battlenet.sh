#!/bin/bash

# Install Battle.net standalone via umu-launcher + GE-Proton (no Steam, no Lutris, no Heroic).
# Requires sudo (package + lib32 driver install via pacman).

set -e

# Resolve this script's own dir so the shared helpers are found no matter
# where the script is invoked from.
script_dir="$(dirname "$(realpath "$0")")"
source "$script_dir/install-gpu-lib32.sh"
source "$script_dir/setup-local-bin-path.sh"

PREFIX="$HOME/Games/battlenet"
LAUNCHER="$PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
INSTALLER_URL="https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"

echo "Installing Battle.net..."

# All packages live in the CachyOS/Arch sync repos (umu-launcher is in the
# 'cachyos' repo), so use pacman directly — no AUR helper needed.
sudo pacman -S --needed --noconfirm umu-launcher

# Auto-detect the GPU vendor(s) and install the matching lib32 drivers.
install_gpu_lib32

# Detect a half-finished prefix from a closed/crashed previous run and offer
# to wipe it before trying again. Battle.net's installer isn't idempotent.
if [[ -d $PREFIX && ! -f $LAUNCHER ]]; then
  echo
  echo "Found a partial Battle.net install at $PREFIX (no Launcher.exe)."
  echo "Battle.net's installer can't resume from this state."
  read -r -p "Wipe the partial prefix and start fresh? [y/N] " ans
  [[ $ans == [Yy]* ]] || { echo "Aborting. Re-run when ready to wipe."; exit 1; }
  pkill -f "$PREFIX" 2>/dev/null || true
  sleep 1
  rm -rf "$PREFIX"
fi

mkdir -p "$PREFIX"

export WINEPREFIX="$PREFIX"
export PROTONPATH=GE-Proton
export GAMEID=umu-battlenet
export PROTON_VERB=run

if [[ -f $LAUNCHER ]]; then
  echo "Battle.net is already installed at $PREFIX."
  launched_installer=0
else
  cache_dir="$HOME/.cache/cachyos-gaming"
  mkdir -p "$cache_dir"
  installer="$cache_dir/Battle.net-Setup.exe"

  echo
  echo "Downloading Battle.net installer..."
  curl --fail --location --retry 3 "$INSTALLER_URL" --output "$installer"

  cat <<'EOF'

Launching the Battle.net setup wizard. Click through it normally — the
default install path is fine. When it finishes, Battle.net will be in your
app launcher.

EOF

  log="/tmp/battlenet-installer.log"
  setsid -f sh -c "umu-run '$installer' >'$log' 2>&1" </dev/null >/dev/null 2>&1
  echo "Installer log: $log"
  launched_installer=1
fi

# Install the launcher script and desktop entry from this repo.
install -Dm755 "$script_dir/launch-battlenet.sh" "$HOME/.local/bin/launch-battlenet"
install -Dm644 "$script_dir/../applications/battlenet.desktop" \
  "$HOME/.local/share/applications/battlenet.desktop"
# Pin Exec to the absolute launcher path so the menu entry works regardless of
# whether ~/.local/bin is on PATH (it isn't on a default CachyOS session).
sed -i "s|^Exec=.*|Exec=$HOME/.local/bin/launch-battlenet|" \
  "$HOME/.local/share/applications/battlenet.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# Make sure ~/.local/bin is on PATH so the `launch-battlenet` command resolves
# (CachyOS doesn't add it by default). The app-menu entry works regardless via
# its absolute Exec above; this is for running the command by name.
setup_local_bin_path

if (( launched_installer )); then
  cat <<EOF

The Battle.net installer is running in the background. After it finishes,
find Battle.net in your app launcher, or run:

  launch-battlenet

(Re-login once so the app launcher and new terminals see ~/.local/bin.)

EOF
else
  cat <<EOF

Battle.net is installed. Find it in your app launcher, or run:

  launch-battlenet

(Re-login once so the app launcher and new terminals see ~/.local/bin.)

EOF
fi
