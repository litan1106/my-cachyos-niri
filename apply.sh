#!/usr/bin/env bash

# ────────────── CachyOS Niri · Config Sync Helper ──────────────
# Applies repo config changes to the live system without
# re-running the full install.sh.
#
# Usage:
#   ./apply.sh              → sync everything
#   ./apply.sh niri         → sync only niri configs
#   ./apply.sh gtk          → sync only GTK settings
#   ./apply.sh qs           → sync only quickshell/noctalia-shell
#   ./apply.sh noctalia     → sync only noctalia settings.json
#   ./apply.sh --dry        → show what would be copied, don't copy
#   ./apply.sh --help       → show this help

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=false
TARGETS=()

# ── Argument parsing ─────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --dry)   DRY=true ;;
        --help|-h)
            echo "Usage: ./apply.sh [niri|gtk|qs|noctalia] [--dry]"
            echo ""
            echo "  (no args)   Sync all config areas"
            echo "  niri        Sync ~/.config/niri (config.kdl + cfg/)"
            echo "  gtk         Sync ~/.config/gtk-3.0 and gtk-4.0 settings"
            echo "  qs          Sync ~/.config/quickshell/noctalia-shell"
            echo "  noctalia    Sync ~/.config/noctalia/settings.json"
            echo "  --dry       Preview changes without applying"
            exit 0
            ;;
        niri|gtk|qs|noctalia) TARGETS+=("$arg") ;;
        *)
            echo -e "${RED}[ERROR] Unknown argument: $arg${NC}"
            echo "Run './apply.sh --help' for usage."
            exit 1
            ;;
    esac
done

# Default: sync everything
if [ ${#TARGETS[@]} -eq 0 ]; then
    TARGETS=(niri gtk qs noctalia)
fi

# ── Helpers ──────────────────────────────────────────────────────
sync_file() {
    local src="$1" dst="$2"
    if $DRY; then
        echo -e "  ${YELLOW}[dry]${NC} $src → $dst"
    else
        mkdir -p "$(dirname "$dst")"
        cp -r "$src" "$dst"
        echo -e "  ${GREEN}[✔]${NC} $src → $dst"
    fi
}

sync_dir() {
    local src="$1" dst="$2"
    if $DRY; then
        echo -e "  ${YELLOW}[dry]${NC} $src/ → $dst/"
    else
        mkdir -p "$dst"
        cp -r "$src/." "$dst/"
        echo -e "  ${GREEN}[✔]${NC} $src/ → $dst/"
    fi
}

# ── Header ───────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}          CachyOS Niri · Config Sync Helper                  ${NC}"
if $DRY; then
    echo -e "${CYAN}${BOLD}                   [ DRY RUN ]                               ${NC}"
fi
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── Sync: niri ───────────────────────────────────────────────────
if [[ " ${TARGETS[*]} " == *" niri "* ]]; then
    echo -e "${BLUE}[*] Syncing niri config...${NC}"
    sync_file "${REPO_DIR}/niri/config.kdl" "$HOME/.config/niri/config.kdl"
    sync_dir  "${REPO_DIR}/niri/cfg"        "$HOME/.config/niri/cfg"
    echo ""
fi

# ── Sync: GTK ────────────────────────────────────────────────────
if [[ " ${TARGETS[*]} " == *" gtk "* ]]; then
    echo -e "${BLUE}[*] Syncing GTK settings...${NC}"
    sync_file "${REPO_DIR}/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
    sync_file "${REPO_DIR}/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
    [ -f "${REPO_DIR}/gtk-3.0/gtk.css" ] && sync_file "${REPO_DIR}/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
    [ -f "${REPO_DIR}/gtk-4.0/gtk.css" ] && sync_file "${REPO_DIR}/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
    echo ""
fi

# ── Sync: Quickshell / Noctalia-shell ───────────────────────────
if [[ " ${TARGETS[*]} " == *" qs "* ]]; then
    if [ -d "${REPO_DIR}/quickshell/noctalia-shell" ]; then
        echo -e "${BLUE}[*] Syncing quickshell/noctalia-shell config...${NC}"
        sync_dir "${REPO_DIR}/quickshell/noctalia-shell" \
                 "$HOME/.config/quickshell/noctalia-shell"
        echo ""
    else
        echo -e "${YELLOW}[!] No quickshell config found in repo, skipping.${NC}"
        echo ""
    fi
fi

# ── Sync: Noctalia settings.json ─────────────────────────────────
if [[ " ${TARGETS[*]} " == *" noctalia "* ]]; then
    if [ -f "${REPO_DIR}/noctalia/settings.json" ]; then
        echo -e "${BLUE}[*] Syncing noctalia settings...${NC}"
        sync_file "${REPO_DIR}/noctalia/settings.json" \
                  "$HOME/.config/noctalia/settings.json"
        echo ""
    else
        echo -e "${YELLOW}[!] No noctalia/settings.json found in repo, skipping.${NC}"
        echo ""
    fi
fi

# ── Reload niri live ─────────────────────────────────────────────
if ! $DRY; then
    if [[ " ${TARGETS[*]} " == *" niri "* ]]; then
        if [ -n "${NIRI_SOCKET:-}" ] || pgrep -x niri &> /dev/null; then
            echo -e "${BLUE}[*] Live reloading niri...${NC}"
            niri msg action load-config-file && \
                echo -e "${GREEN}[✔] Niri config reloaded!${NC}" || \
                echo -e "${YELLOW}[!] Reload failed — try logging out and back in.${NC}"
            echo ""
        fi
    fi
fi

# ── Done ─────────────────────────────────────────────────────────
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if $DRY; then
    echo -e "${GREEN}${BOLD}   Dry run complete. Run without --dry to apply changes.     ${NC}"
else
    echo -e "${GREEN}${BOLD}   All changes applied successfully!                        ${NC}"
fi
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
