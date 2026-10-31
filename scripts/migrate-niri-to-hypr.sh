#!/usr/bin/env bash

set -euo pipefail
umask 077

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/cachyos-hypr-migration"
PACMAN_CONF=/etc/pacman.conf
if [[ "${MIGRATION_TEST_MODE:-}" == 1 ]]; then
    PACMAN_CONF="${MIGRATION_PACMAN_CONF:-$PACMAN_CONF}"
fi
ACTIVE_FILE="$STATE_ROOT/active"
QB_DESKTOP="$HOME/.local/share/applications/org.qbittorrent.qBittorrent.desktop"
SDDM_DROPIN=/etc/sddm.conf.d/90-hyprland-autologin.conf
SDDM_CONF_MAIN=/etc/sddm.conf
SDDM_CONF_DIR=/etc/sddm.conf.d
HYPR_SESSION_FILE=/usr/share/wayland-sessions/hyprland-uwsm.desktop
QT_PIN='qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg qt6-svg qt6-translations qt6-wayland'
if [[ "${MIGRATION_TEST_MODE:-}" == 1 ]]; then
    SDDM_DROPIN="${MIGRATION_SDDM_DROPIN:-$SDDM_DROPIN}"
    SDDM_CONF_MAIN="${MIGRATION_SDDM_CONF_MAIN:-$SDDM_CONF_MAIN}"
    SDDM_CONF_DIR="$(dirname "$SDDM_DROPIN")"
    HYPR_SESSION_FILE="${MIGRATION_HYPR_SESSION_FILE:-$HYPR_SESSION_FILE}"
fi
DRY_RUN=false
WITH_LAYOUT=false
ENABLE_AUTOLOGIN=false

usage() {
    cat <<'EOF'
Usage: ./scripts/migrate-niri-to-hypr.sh prepare [--dry-run] [--with-layout]
       ./scripts/migrate-niri-to-hypr.sh finish [--dry-run] [--enable-autologin]

Run prepare in the old desktop session. Log into Hyprland (UWSM), then run finish.
Run as the desktop user; the script invokes sudo only for system changes.
EOF
}

PHASE="${1:-}"
case "$PHASE" in
    prepare|finish) shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --with-layout) WITH_LAYOUT=true ;;
        --enable-autologin) ENABLE_AUTOLOGIN=true ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
if [[ "$PHASE" != prepare && "$WITH_LAYOUT" == true ]] ||
   [[ "$PHASE" != finish && "$ENABLE_AUTOLOGIN" == true ]]; then
    usage >&2
    exit 2
fi
if (( EUID == 0 )); then
    echo "Run as the desktop user, without sudo." >&2
    exit 1
fi
if [[ ! -f /etc/arch-release ]]; then
    echo "This migration requires an Arch-based installation." >&2
    exit 1
fi
for command in pacman sudo cp mv grep sed awk systemctl; do
    command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }
done

read_run() {
    if [[ -e "$ACTIVE_FILE" ]]; then
        RUN_DIR="$(<"$ACTIVE_FILE")"
        if [[ "$RUN_DIR" != "$STATE_ROOT"/* || ! -d "$RUN_DIR" ]]; then
            echo "Invalid migration state in $ACTIVE_FILE; inspect it before continuing." >&2
            exit 1
        fi
    else
        RUN_DIR="$STATE_ROOT/$(date +%Y%m%d-%H%M%S)-$$"
    fi
}

init_run() {
    if [[ -e "$ACTIVE_FILE" ]]; then
        return
    fi
    mkdir -p "$STATE_ROOT" "$RUN_DIR"
    printf '%s\n' "$RUN_DIR" > "$ACTIVE_FILE"
}

backup_user_path() {
    local source="$1" target="$2" temp
    if [[ ! -e "$source" && ! -L "$source" ]]; then
        return
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        return
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would back up: $source -> $target"
        return
    fi
    mkdir -p "$(dirname "$target")"
    temp="${target}.tmp.$$"
    cp -a -- "$source" "$temp"
    mv -- "$temp" "$target"
    echo "Backed up: $source -> $target"
}

retire_path() {
    local source="$1" target="$2"
    if [[ ! -e "$source" && ! -L "$source" ]]; then
        return
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        echo "Retirement target already exists: $target; inspect it before continuing." >&2
        exit 1
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would move aside: $source -> $target"
        return
    fi
    mkdir -p "$(dirname "$target")"
    mv -- "$source" "$target"
    echo "Moved aside: $source -> $target"
}

package_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

autologin_value_present() {
    awk '
        /^[[:space:]]*\[/ { in_autologin = ($0 ~ /^[[:space:]]*\[Autologin\][[:space:]]*$/); next }
        in_autologin && /^[[:space:]]*(User|Session)[[:space:]]*=/ {
            sub(/^[^=]*=/, "")
            gsub(/[[:space:]]/, "")
            if (length($0) > 0) found = 1
        }
        END { exit !found }
    ' "$1"
}

warn_existing_autologin() {
    local file
    for file in "$SDDM_CONF_MAIN" "$SDDM_CONF_DIR"/*.conf; do
        [[ -f "$file" ]] || continue
        if autologin_value_present "$file"; then
            echo "SDDM autologin exists in $file. It may skip the session chooser; review its Session setting before logging out."
        fi
    done
}

autologin_session() {
    awk '
        /^[[:space:]]*\[/ { in_autologin = ($0 ~ /^[[:space:]]*\[Autologin\][[:space:]]*$/); next }
        in_autologin && /^[[:space:]]*Session[[:space:]]*=/ {
            sub(/^[^=]*=/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            session = $0
        }
        END { print session }
    ' "$1"
}

check_retired_session_autologin() {
    systemctl is-active --quiet sddm || return 0
    local file session
    for file in "$SDDM_CONF_MAIN" "$SDDM_CONF_DIR"/*.conf; do
        [[ -f "$file" ]] || continue
        session="$(autologin_session "$file")"
        if [[ "${session,,}" == *niri* ]]; then
            echo "SDDM still selects the Niri session in $file ($session). Set Session=hyprland-uwsm.desktop or disable that autologin before removing Niri." >&2
            exit 1
        fi
    done
}

pin_state() {
    local active_pins
    active_pins="$(grep -E '^[[:space:]]*IgnorePkg[[:space:]]*=' "$PACMAN_CONF" || true)"
    if [[ "$active_pins" == *qt6-* ]]; then
        if [[ "$active_pins" != "IgnorePkg = $QT_PIN" ]]; then
            echo "An unfamiliar active Qt IgnorePkg entry is present in $PACMAN_CONF:" >&2
            printf '%s\n' "$active_pins" >&2
            echo "Review it manually before migration." >&2
            exit 1
        fi
        PIN_ACTIVE=true
    else
        PIN_ACTIVE=false
    fi
}

backup_pacman_conf() {
    local target="$RUN_DIR/system/pacman.conf" temp
    if [[ -f "$target" ]]; then
        return
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would back up: $PACMAN_CONF -> $target"
        return
    fi
    mkdir -p "$(dirname "$target")"
    temp="${target}.tmp.$$"
    sudo cp -a -- "$PACMAN_CONF" "$temp"
    sudo mv -- "$temp" "$target"
    echo "Backed up: $PACMAN_CONF -> $target"
}

unpin_qt() {
    [[ "$PIN_ACTIVE" == true ]] || return 0
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would comment out the recognized Qt 6.11 IgnorePkg line in $PACMAN_CONF"
        return
    fi
    sudo sed -i "\|^IgnorePkg = $QT_PIN$|s|^|#|" "$PACMAN_CONF"
    pin_state
    if [[ "$PIN_ACTIVE" == true ]]; then
        echo "Qt pin remains active after editing $PACMAN_CONF." >&2
        exit 1
    fi
    echo "Removed Qt 6.11 upgrade hold."
}

prepare() {
    [[ -f "$PACMAN_CONF" ]] || { echo "Missing $PACMAN_CONF" >&2; exit 1; }
    pin_state
    if [[ -e "$CONFIG_DIR/noctalia/settings.json" || -e "$CONFIG_DIR/noctalia/plugins.json" ]] &&
       [[ -e "$CONFIG_DIR/noctalia/config.toml" ]]; then
        echo "Both Noctalia v4 and v5 config are present; inspect $CONFIG_DIR/noctalia first." >&2
        exit 1
    fi
    if [[ -e "$CONFIG_DIR/hypr" && ! -f "$CONFIG_DIR/hypr/hyprland.lua" ]]; then
        echo "Existing Hyprland directory lacks hyprland.lua; inspect $CONFIG_DIR/hypr first." >&2
        exit 1
    fi
    read_run
    echo "Migration backup: $RUN_DIR"
    if [[ "$DRY_RUN" != true ]]; then init_run; fi

    backup_user_path "$CONFIG_DIR/niri" "$RUN_DIR/user-config/niri"
    backup_user_path "$CONFIG_DIR/noctalia" "$RUN_DIR/user-config/noctalia"
    backup_user_path "$CONFIG_DIR/quickshell/noctalia-shell" "$RUN_DIR/user-config/quickshell-noctalia-shell"
    backup_user_path "$CONFIG_DIR/hypr" "$RUN_DIR/user-config/hypr"
    backup_user_path "$QB_DESKTOP" "$RUN_DIR/user-config/org.qbittorrent.qBittorrent.desktop"
    backup_pacman_conf
    unpin_qt

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would run: sudo pacman -Syu --needed cachyos-hypr-noctalia"
    else
        sudo pacman -Syu --needed cachyos-hypr-noctalia
    fi

    if [[ -e "$CONFIG_DIR/noctalia/settings.json" || -e "$CONFIG_DIR/noctalia/plugins.json" ]]; then
        retire_path "$CONFIG_DIR/noctalia" "$RUN_DIR/retired/noctalia-v4"
    fi
    if [[ -f "$QB_DESKTOP" ]] && grep -Eq '^Exec=.*[/]qbittorrent-5\.2\.4[/]qbittorrent([[:space:]]|$)' "$QB_DESKTOP"; then
        retire_path "$QB_DESKTOP" "$RUN_DIR/retired/org.qbittorrent.qBittorrent.desktop"
    fi
    warn_existing_autologin

    local install_args=(--dry-run)
    [[ "$WITH_LAYOUT" == true ]] && install_args+=(--with-layout)
    if [[ "$DRY_RUN" == true ]]; then
        if package_installed cachyos-hypr-noctalia; then
            "$REPO_DIR/install.sh" "${install_args[@]}"
        else
            if [[ "$WITH_LAYOUT" == true ]]; then
                echo "Would run: ./install.sh --with-layout after installing the CachyOS profile"
            else
                echo "Would run: ./install.sh after installing the CachyOS profile"
            fi
        fi
        echo "Dry run complete. No files changed."
    else
        install_args=()
        [[ "$WITH_LAYOUT" == true ]] && install_args+=(--with-layout)
        "$REPO_DIR/install.sh" "${install_args[@]}"
        echo "Prepare complete. Log into Hyprland (UWSM), then run: ./scripts/migrate-niri-to-hypr.sh finish --dry-run"
        echo "After reviewing that output, run: ./scripts/migrate-niri-to-hypr.sh finish"
    fi
}

verify_hyprland() {
    local desktop="${XDG_CURRENT_DESKTOP:-}"
    if [[ "${desktop,,}" != *hyprland* ]]; then
        echo "Log into Hyprland (UWSM) before finishing this migration." >&2
        exit 1
    fi
    local errors
    hyprctl activeworkspace >/dev/null
    errors="$(hyprctl configerrors)"
    if [[ -n "$errors" ]]; then
        echo "Hyprland reports configuration errors:" >&2
        printf '%s\n' "$errors" >&2
        exit 1
    fi
    noctalia config validate "$CONFIG_DIR/noctalia"
    noctalia msg status >/dev/null
}

check_autologin() {
    [[ "$ENABLE_AUTOLOGIN" == true ]] || return 0
    if ! systemctl is-active --quiet sddm; then
        echo "SDDM is not active; cannot enable SDDM autologin." >&2
        exit 1
    fi
    if [[ ! -f "$HYPR_SESSION_FILE" ]]; then
        echo "Hyprland UWSM session entry is missing." >&2
        exit 1
    fi
    local file
    for file in "$SDDM_CONF_MAIN" "$SDDM_CONF_DIR"/*.conf; do
        [[ -f "$file" && "$file" != "$SDDM_DROPIN" ]] || continue
        if autologin_value_present "$file"; then
            echo "Possible conflicting SDDM autologin settings in $file; inspect them first." >&2
            exit 1
        fi
    done
    if [[ -f "$SDDM_DROPIN" ]]; then
        if grep -Fxq "User=$(id -un)" "$SDDM_DROPIN" &&
           grep -Fxq 'Session=hyprland-uwsm.desktop' "$SDDM_DROPIN" &&
           grep -Fxq 'Relogin=false' "$SDDM_DROPIN"; then
            AUTOLOGIN_CURRENT=true
        else
            echo "Existing $SDDM_DROPIN differs; inspect it before continuing." >&2
            exit 1
        fi
    else
        AUTOLOGIN_CURRENT=false
    fi
}

enable_autologin() {
    [[ "$ENABLE_AUTOLOGIN" == true && "$AUTOLOGIN_CURRENT" == false ]] || return 0
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install SDDM autologin for $(id -un): $SDDM_DROPIN"
        return
    fi
    local temp
    temp="$(mktemp)"
    printf '[Autologin]\nUser=%s\nSession=hyprland-uwsm.desktop\nRelogin=false\n' "$(id -un)" > "$temp"
    sudo install -d -m 755 "$SDDM_CONF_DIR"
    sudo install -m 644 "$temp" "$SDDM_DROPIN"
    rm -f "$temp"
    echo "Enabled SDDM Hyprland autologin."
}

finish() {
    [[ -f "$ACTIVE_FILE" ]] || {
        echo "No migration state found at $ACTIVE_FILE; run prepare first." >&2
        exit 1
    }
    read_run
    verify_hyprland
    check_retired_session_autologin
    check_autologin
    echo "Migration backup: $RUN_DIR"

    backup_user_path "$CONFIG_DIR/niri" "$RUN_DIR/user-config/niri"
    backup_user_path "$CONFIG_DIR/quickshell/noctalia-shell" "$RUN_DIR/user-config/quickshell-noctalia-shell"
    retire_path "$CONFIG_DIR/niri" "$RUN_DIR/retired/niri"
    retire_path "$CONFIG_DIR/quickshell/noctalia-shell" "$RUN_DIR/retired/quickshell-noctalia-shell"

    local old_packages=() package
    for package in niri noctalia-shell noctalia-qs; do
        package_installed "$package" && old_packages+=("$package")
    done
    if (( ${#old_packages[@]} )); then
        if [[ "$DRY_RUN" == true ]]; then
            echo "Would run: sudo pacman -R ${old_packages[*]}"
        else
            sudo pacman -R "${old_packages[@]}"
        fi
    fi
    enable_autologin
    if [[ "$DRY_RUN" == true ]]; then
        echo "Dry run complete. No files changed."
    else
        for package in niri noctalia-shell noctalia-qs; do
            if package_installed "$package"; then
                echo "Old package remains installed: $package" >&2
                exit 1
            fi
        done
        echo "Migration complete. Backup retained at $RUN_DIR"
    fi
}

"$PHASE"
