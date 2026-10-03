#!/bin/bash

set -e

# Resolve this script's own dir so the shared GPU helper is found no matter
# where the script is invoked from.
script_dir="$(dirname "$(realpath "$0")")"
source "$script_dir/install-gpu-lib32.sh"

echo "Installing Lutris..."
# All packages live in the CachyOS/Arch sync repos, so use pacman directly
# (--needed makes the already-installed lutris a no-op). No AUR helper needed.
sudo pacman -S --needed --noconfirm lutris umu-launcher wine-staging wine-mono wine-gecko winetricks python-protobuf

# Auto-detect the GPU vendor(s) and install the matching lib32 drivers.
install_gpu_lib32

# Lutris ships with `#!/usr/bin/env python3`. On machines where `python3` resolves
# to a mise-managed shim, that fails to import the lutris module, so pin the
# shebang to the system Python. Skip entirely when python3 is not mise-managed.
if head -1 /usr/bin/lutris 2>/dev/null | grep -q 'env python3' && command -v python3 | grep -q 'mise\|shims'; then
  echo "Pinning /usr/bin/lutris shebang to system python (mise detected)..."
  sudo sed -i '/env python3/ c\#!/bin/python3' /usr/bin/lutris
fi

cat <<'EOF'

Lutris will open and auto-fetch its DXVK and VKD3D runtimes in the background
(watch the bottom status bar). Once that finishes, click the + to add or install games.

EOF

setsid lutris >/dev/null 2>&1 &
