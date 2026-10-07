#!/bin/bash

# Install Waydroid — Android apps as native Wayland windows on CachyOS + niri.
# Requires sudo (package install, container service, first-time image init).
#
# Notes for this machine (verified):
#   - The CachyOS kernel ships binder BUILT IN (it's in /proc/filesystems), so
#     there is NO modprobe and NO binder-dkms step here.
#   - Waydroid renders through the host's 64-bit mesa, so lib32 drivers are
#     irrelevant (that's a Proton concern) and install-gpu-lib32.sh is NOT used.

set -e

# Resolve this script's own dir so the shared helper is found no matter where
# the script is invoked from.
script_dir="$(dirname "$(realpath "$0")")"
source "$script_dir/setup-local-bin-path.sh"

echo "Installing Waydroid..."

# waydroid lives in the 'extra' sync repo, so use pacman directly — no AUR
# helper needed. --needed makes a re-run a no-op if it's already installed.
sudo pacman -S --needed --noconfirm waydroid

# Enable + start the LXC container service, but only if it isn't already up —
# a re-run shouldn't bounce a healthy running container.
if systemctl is-active --quiet waydroid-container.service; then
  echo "waydroid-container.service is already active."
else
  echo "Enabling and starting waydroid-container.service..."
  sudo systemctl enable --now waydroid-container.service
fi

# First-time init only. The system image is multiple GB, so we must NOT
# re-download it on a re-run. Treat the presence of the config as proof of a
# prior init (fall back to the per-user data dir if the system path is absent).
if [[ -f /var/lib/waydroid/waydroid.cfg || -d "$HOME/.local/share/waydroid" ]]; then
  echo "Waydroid is already initialized — skipping image download."
  gapps=0
else
  echo
  echo "Waydroid needs a one-time system image download (several GB)."
  echo "VANILLA is a Google-free LineageOS image (recommended default)."
  echo "GAPPS bundles Google Play but needs a one-time device registration"
  echo "before Play will run."
  read -r -p "Use the GAPPS (Google Play) image instead of VANILLA? [y/N] " ans
  if [[ $ans == [Yy]* ]]; then
    gapps=1
    image="GAPPS"
  else
    gapps=0
    image="VANILLA"
  fi

  echo
  echo "Initializing Waydroid with the $image image (this downloads the image)..."
  sudo waydroid init -s "$image"
fi

# Install the launcher script and desktop entry from this repo.
install -Dm755 "$script_dir/launch-waydroid.sh" "$HOME/.local/bin/launch-waydroid"
install -Dm644 "$script_dir/../applications/waydroid.desktop" \
  "$HOME/.local/share/applications/waydroid.desktop"
# Pin Exec to the absolute launcher path so the menu entry works regardless of
# whether ~/.local/bin is on PATH (it isn't on a default CachyOS session).
sed -i "s|^Exec=.*|Exec=$HOME/.local/bin/launch-waydroid|" \
  "$HOME/.local/share/applications/waydroid.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# Make sure ~/.local/bin is on PATH so the `launch-waydroid` command resolves
# (CachyOS doesn't add it by default). The app-menu entry works regardless via
# its absolute Exec above; this is for running the command by name.
setup_local_bin_path

cat <<EOF

Waydroid is installed. Start an Android session with:

  launch-waydroid

The first session can take a moment to boot the container. Once you install
Android apps, Waydroid auto-generates a per-app shortcut in your app menu for
each one (alongside the "Android apps via Waydroid" entry installed here).

(Re-login once so the app launcher and new terminals see ~/.local/bin.)

NETWORK note: if Android boots but has no internet, this machine's firewall
(ufw) is dropping the container's forwarded traffic. Fix it with:

  $script_dir/fix-waydroid-firewall.sh

It trusts the waydroid0 interface and restarts the container.

GPU note (AMD): if apps show a black screen or fall back to software
rendering, try hardware GL via:

  waydroid prop set persist.waydroid.gralloc minigbm_gbm_mesa

then stop and restart the Waydroid session for it to take effect. Software
rendering is the safe fallback if hardware GL still won't come up.

EOF

if (( gapps )); then
  cat <<EOF
GAPPS (Google Play) one-time setup: Google Play won't run until this device is
registered as a Google device. After the first boot, read the GSF / Android ID:

  sudo waydroid shell -- sqlite3 \
    /data/data/com.google.android.gsf/databases/gservices.db \
    "select * from main where name = \"android_id\";"

then register that ID at:

  https://www.google.com/android/uncertified

Paste the ID there, wait a few minutes, and restart the Waydroid session.
Until you do, Play will refuse to run.

EOF
fi
