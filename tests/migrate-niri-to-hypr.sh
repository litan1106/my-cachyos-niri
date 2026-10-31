#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
MOCK_BIN="$FIXTURE/bin"
mkdir -p "$MOCK_BIN" "$FIXTURE/home/.config/niri" "$FIXTURE/home/.config/noctalia"
mkdir -p "$FIXTURE/home/.config/quickshell/noctalia-shell"
mkdir -p "$FIXTURE/home/.local/share/applications" "$FIXTURE/sessions"
printf 'niri\nnoctalia-shell\nnoctalia-qs\n' > "$FIXTURE/packages"
printf 'old config\n' > "$FIXTURE/home/.config/niri/config.kdl"
printf '{}\n' > "$FIXTURE/home/.config/noctalia/settings.json"
printf 'old qml\n' > "$FIXTURE/home/.config/quickshell/noctalia-shell/Launcher.qml"
printf '[Desktop Entry]\nExec=%s/.local/opt/qbittorrent-5.2.4/qbittorrent %%U\n' \
    "$FIXTURE/home" > "$FIXTURE/home/.local/share/applications/org.qbittorrent.qBittorrent.desktop"
printf 'IgnorePkg = qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg qt6-svg qt6-translations qt6-wayland\n' > "$FIXTURE/pacman.conf"
touch "$FIXTURE/sessions/hyprland-uwsm.desktop"

cat > "$MOCK_BIN/pacman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    -Qq) grep -Fxq "$2" "$MIGRATION_TEST_PACKAGES" ;;
    -Syu) test "${MIGRATION_TEST_FAIL_INSTALL:-}" != 1 || exit 1
        grep -Fxq cachyos-hypr-noctalia "$MIGRATION_TEST_PACKAGES" ||
        printf 'cachyos-hypr-noctalia\n' >> "$MIGRATION_TEST_PACKAGES" ;;
    -R)
        shift
        for package in "$@"; do
            awk -v package="$package" '$0 != package' "$MIGRATION_TEST_PACKAGES" > "$MIGRATION_TEST_PACKAGES.tmp"
            mv "$MIGRATION_TEST_PACKAGES.tmp" "$MIGRATION_TEST_PACKAGES"
        done ;;
    *) exit 2 ;;
esac
EOF
cat > "$MOCK_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
cat > "$MOCK_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    activeworkspace) echo 'workspace: 1' ;;
    configerrors) printf '%s' "${MIGRATION_TEST_CONFIG_ERRORS:-}" ;;
    *) exit 2 ;;
esac
EOF
cat > "$MOCK_BIN/noctalia" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    'config validate') test -e "$3" ;;
    'msg status') echo 'running' ;;
    *) exit 2 ;;
esac
EOF
cat > "$MOCK_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
test "$1 $2" = 'is-active --quiet'
EOF
chmod +x "$MOCK_BIN"/*

export HOME="$FIXTURE/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export PATH="$MOCK_BIN:$PATH"
export MIGRATION_TEST_MODE=1
export MIGRATION_PACMAN_CONF="$FIXTURE/pacman.conf"
export MIGRATION_TEST_PACKAGES="$FIXTURE/packages"
export MIGRATION_SDDM_DROPIN="$FIXTURE/sddm/90-hyprland-autologin.conf"
export MIGRATION_SDDM_CONF_MAIN="$FIXTURE/sddm.conf"
export MIGRATION_HYPR_SESSION_FILE="$FIXTURE/sessions/hyprland-uwsm.desktop"
MIGRATE="$REPO_DIR/scripts/migrate-niri-to-hypr.sh"

"$MIGRATE" prepare --dry-run > "$FIXTURE/dry-run.log"
test ! -e "$XDG_STATE_HOME/cachyos-hypr-migration/active"
grep -Fq 'IgnorePkg = qt6-base' "$FIXTURE/pacman.conf"

if MIGRATION_TEST_FAIL_INSTALL=1 "$MIGRATE" prepare > "$FIXTURE/interrupted.log" 2>&1; then
    echo 'prepare continued after package installation failed' >&2
    exit 1
fi
test -f "$XDG_CONFIG_HOME/noctalia/settings.json"
test -f "$XDG_STATE_HOME/cachyos-hypr-migration/active"
grep -Fq '#IgnorePkg = qt6-base' "$FIXTURE/pacman.conf"

"$MIGRATE" prepare > "$FIXTURE/prepare.log"
RUN_DIR="$(<"$XDG_STATE_HOME/cachyos-hypr-migration/active")"
test -f "$RUN_DIR/user-config/niri/config.kdl"
test -f "$RUN_DIR/user-config/noctalia/settings.json"
test -f "$RUN_DIR/system/pacman.conf"
test -f "$RUN_DIR/retired/noctalia-v4/settings.json"
test -f "$RUN_DIR/retired/org.qbittorrent.qBittorrent.desktop"
test -f "$XDG_CONFIG_HOME/hypr/config/my_desktop.lua"
test -f "$XDG_CONFIG_HOME/noctalia/config.toml"
test ! -e "$XDG_CONFIG_HOME/noctalia/zz-shared.toml"
grep -Fq '#IgnorePkg = qt6-base' "$FIXTURE/pacman.conf"
grep -Fxq cachyos-hypr-noctalia "$FIXTURE/packages"
"$MIGRATE" prepare > "$FIXTURE/prepare-again.log"

if env -u XDG_CURRENT_DESKTOP "$MIGRATE" finish > "$FIXTURE/wrong-session.log" 2>&1; then
    echo 'finish accepted a non-Hyprland session' >&2
    exit 1
fi
test -f "$XDG_CONFIG_HOME/niri/config.kdl"
export XDG_CURRENT_DESKTOP=Hyprland
if MIGRATION_TEST_CONFIG_ERRORS='invalid bind' "$MIGRATE" finish > "$FIXTURE/config-error.log" 2>&1; then
    echo 'finish accepted Hyprland configuration errors' >&2
    exit 1
fi
test -f "$XDG_CONFIG_HOME/niri/config.kdl"
mkdir -p "$FIXTURE/sddm"
printf '[Autologin]\nUser=someone-else\nSession=niri.desktop\n' > "$FIXTURE/sddm/other.conf"
if "$MIGRATE" finish > "$FIXTURE/retired-session-autologin.log" 2>&1; then
    echo 'finish removed Niri while SDDM still selected its session' >&2
    exit 1
fi
test -f "$XDG_CONFIG_HOME/niri/config.kdl"
grep -Fq 'SDDM still selects the Niri session' "$FIXTURE/retired-session-autologin.log"
if "$MIGRATE" finish --enable-autologin > "$FIXTURE/conflicting-autologin.log" 2>&1; then
    echo 'finish accepted conflicting SDDM autologin settings' >&2
    exit 1
fi
test -f "$XDG_CONFIG_HOME/niri/config.kdl"
rm "$FIXTURE/sddm/other.conf"
"$MIGRATE" finish --dry-run --enable-autologin > "$FIXTURE/finish-dry-run.log"
test -f "$XDG_CONFIG_HOME/niri/config.kdl"
grep -Fxq niri "$FIXTURE/packages"
"$MIGRATE" finish --enable-autologin > "$FIXTURE/finish.log"
test -f "$RUN_DIR/retired/niri/config.kdl"
test -f "$RUN_DIR/retired/quickshell-noctalia-shell/Launcher.qml"
test ! -e "$XDG_CONFIG_HOME/niri"
test ! -e "$XDG_CONFIG_HOME/quickshell/noctalia-shell"
test ! -e "$HOME/.local/share/applications/org.qbittorrent.qBittorrent.desktop"
test ! -e "$XDG_CONFIG_HOME/noctalia/settings.json"
test ! -e "$XDG_CONFIG_HOME/noctalia/plugins.json"
test ! -e "$MIGRATION_TEST_PACKAGES.tmp"
if grep -Eq '^(niri|noctalia-shell|noctalia-qs)$' "$FIXTURE/packages"; then
    echo 'old desktop package remained installed' >&2
    exit 1
fi
grep -Fxq "User=$(id -un)" "$MIGRATION_SDDM_DROPIN"
grep -Fxq 'Session=hyprland-uwsm.desktop' "$MIGRATION_SDDM_DROPIN"
"$MIGRATE" finish --enable-autologin > "$FIXTURE/finish-again.log"

printf 'IgnorePkg = qt6-base other-package\n' > "$FIXTURE/unfamiliar.conf"
export MIGRATION_PACMAN_CONF="$FIXTURE/unfamiliar.conf"
export XDG_STATE_HOME="$FIXTURE/other-state"
if "$MIGRATE" prepare > "$FIXTURE/unfamiliar.log" 2>&1; then
    echo 'prepare accepted an unfamiliar Qt pin' >&2
    exit 1
fi
test ! -e "$XDG_STATE_HOME/cachyos-hypr-migration/active"
grep -Fq 'unfamiliar active Qt IgnorePkg' "$FIXTURE/unfamiliar.log"

echo 'Migration fixture checks passed.'
