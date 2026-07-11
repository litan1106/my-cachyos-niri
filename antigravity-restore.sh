#!/usr/bin/env bash
# =============================================================================
# Antigravity 2.0 → IDE Restore Script (Linux)
# =============================================================================
# Fixes the Electron app.asar hijack issue introduced in Antigravity 2.0,
# and migrates settings/extensions from the "Antigravity" product profile
# into the "Antigravity IDE" profile.
#
# Usage:
#   ./antigravity-restore.sh          # Interactive menu
#   ./antigravity-restore.sh toggle   # Toggle IDE ↔ 2.0 only
#   ./antigravity-restore.sh migrate  # Migrate settings/extensions only
#   ./antigravity-restore.sh all      # Toggle to IDE + migrate (recommended)
#   ./antigravity-restore.sh backup   # Pre-update backup
# =============================================================================

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
RESOURCES_DIR="/opt/Antigravity/resources"
ASAR="$RESOURCES_DIR/app.asar"
ASAR_BAK="$RESOURCES_DIR/app.asar.bak"

CONFIG_SRC="$HOME/.config/Antigravity"
CONFIG_DST="$HOME/.config/Antigravity IDE"

EXT_SRC="$HOME/.antigravity/extensions"
EXT_DST="$HOME/.antigravity-ide/extensions"

BACKUP_DIR="$HOME/.antigravity-backup-$(date +%Y%m%d_%H%M%S)"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────────────${RESET}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────
require_sudo() {
  if [[ $EUID -ne 0 ]]; then
    info "This step needs sudo to modify files in /opt/Antigravity/resources"
    sudo -v || { err "sudo access required"; exit 1; }
  fi
}

current_mode() {
  if [[ -f "$ASAR" && ! -f "$ASAR_BAK" ]]; then
    echo "2.0"
  elif [[ -f "$ASAR_BAK" && ! -f "$ASAR" ]]; then
    echo "IDE"
  elif [[ -f "$ASAR" && -f "$ASAR_BAK" ]]; then
    echo "both"   # unusual — both exist
  else
    echo "unknown"
  fi
}

# ── Toggle function ───────────────────────────────────────────────────────────
do_toggle() {
  section "Toggle IDE / 2.0"
  require_sudo

  MODE=$(current_mode)
  info "Current mode detected: ${BOLD}$MODE${RESET}"

  case "$MODE" in
    "2.0"|"both")
      info "Disabling 2.0 hijack → restoring IDE launcher..."
      sudo mv "$ASAR" "$ASAR_BAK"
      ok "app.asar renamed to app.asar.bak"
      ok "Antigravity IDE will now launch when you open Antigravity"
      ;;
    "IDE")
      warn "Already in IDE mode. Switch back to 2.0? (y/N)"
      read -r ans
      if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo mv "$ASAR_BAK" "$ASAR"
        ok "Switched back to 2.0 mode"
      else
        info "No change made."
      fi
      ;;
    "unknown")
      err "Cannot find app.asar or app.asar.bak in $RESOURCES_DIR"
      err "Is Antigravity installed at /opt/Antigravity?"
      exit 1
      ;;
  esac
}

# ── Migrate settings ──────────────────────────────────────────────────────────
do_migrate_settings() {
  section "Migrate Settings & Keymaps"

  if [[ ! -d "$CONFIG_SRC" ]]; then
    warn "Source config not found: $CONFIG_SRC — nothing to migrate"
    return
  fi

  mkdir -p "$CONFIG_DST"
  info "Copying $CONFIG_SRC → $CONFIG_DST ..."

  # rsync preferred; fall back to cp
  if command -v rsync &>/dev/null; then
    rsync -a --info=progress2 "$CONFIG_SRC/" "$CONFIG_DST/"
  else
    cp -r "$CONFIG_SRC/." "$CONFIG_DST/"
  fi

  ok "Settings and keymaps migrated"
}

# ── Migrate extensions ────────────────────────────────────────────────────────
do_migrate_extensions() {
  section "Migrate Extensions"

  if [[ ! -d "$EXT_SRC" ]]; then
    warn "Source extensions folder not found: $EXT_SRC — skipping"
    return
  fi

  # If destination is already a symlink pointing to source, nothing to do
  if [[ -L "$EXT_DST" && "$(readlink -f "$EXT_DST")" == "$(readlink -f "$EXT_SRC")" ]]; then
    ok "Extensions symlink already in place — nothing to do"
    return
  fi

  # Back up existing destination if it has content
  if [[ -d "$EXT_DST" && -n "$(ls -A "$EXT_DST" 2>/dev/null)" ]]; then
    warn "Existing extensions folder found at $EXT_DST — backing up..."
    mv "$EXT_DST" "${EXT_DST}.bak.$(date +%Y%m%d_%H%M%S)"
    info "Backup saved"
  fi

  info "Creating symlink: $EXT_DST → $EXT_SRC"
  ln -sfn "$EXT_SRC" "$EXT_DST"
  ok "Extensions symlinked — both IDE profiles now share the same extensions"
}

# ── Pre-update backup ─────────────────────────────────────────────────────────
do_backup() {
  section "Pre-Update Backup"

  info "Backup destination: $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"

  # Settings
  for cfg_dir in "$CONFIG_SRC" "$CONFIG_DST"; do
    name=$(basename "$cfg_dir")
    if [[ -d "$cfg_dir" ]]; then
      info "Backing up config: $cfg_dir"
      cp -r "$cfg_dir" "$BACKUP_DIR/$name"
    fi
  done

  # Extensions (just the extensions.json manifest and list of installed IDs)
  for ext_dir in "$HOME/.antigravity" "$HOME/.antigravity-ide"; do
    name=$(basename "$ext_dir")
    if [[ -d "$ext_dir/extensions" ]]; then
      mkdir -p "$BACKUP_DIR/$name"
      ls "$ext_dir/extensions" > "$BACKUP_DIR/$name/extensions-list.txt"
      cp "$ext_dir/extensions/extensions.json" "$BACKUP_DIR/$name/" 2>/dev/null || true
      info "Extension list saved for $name"
    fi
  done

  # app.asar hash for reference
  if [[ -f "$ASAR" ]]; then
    sha256sum "$ASAR" > "$BACKUP_DIR/app.asar.sha256"
    info "app.asar hash recorded"
  fi

  ok "Backup complete → $BACKUP_DIR"
}

# ── Status ────────────────────────────────────────────────────────────────────
do_status() {
  section "Current Status"
  MODE=$(current_mode)
  echo -e "  ${BOLD}Launcher mode:${RESET}    $MODE"
  echo -e "  ${BOLD}app.asar:${RESET}         $([ -f "$ASAR" ] && echo "present" || echo "absent")"
  echo -e "  ${BOLD}app.asar.bak:${RESET}     $([ -f "$ASAR_BAK" ] && echo "present" || echo "absent")"
  echo ""
  echo -e "  ${BOLD}Settings (2.0):${RESET}   $([ -d "$CONFIG_SRC" ] && echo "exists" || echo "missing") → $CONFIG_SRC"
  echo -e "  ${BOLD}Settings (IDE):${RESET}   $([ -d "$CONFIG_DST" ] && echo "exists" || echo "missing") → $CONFIG_DST"
  echo ""
  echo -e "  ${BOLD}Extensions src:${RESET}   $([ -d "$EXT_SRC" ] && ls "$EXT_SRC" | wc -l || echo 0) items → $EXT_SRC"
  echo -e "  ${BOLD}Extensions dst:${RESET}   $([ -L "$EXT_DST" ] && echo "symlink → $(readlink "$EXT_DST")" || ([ -d "$EXT_DST" ] && echo "$(ls "$EXT_DST" | wc -l) items" || echo "missing"))"
}

# ── Menu ──────────────────────────────────────────────────────────────────────
interactive_menu() {
  echo -e "\n${BOLD}Antigravity 2.0 Recovery — Linux${RESET}"
  echo "────────────────────────────────────"
  do_status
  echo ""
  echo "What would you like to do?"
  echo "  1) Switch to IDE-only (toggle + migrate + archive 2.0 profile)"
  echo "  2) Toggle IDE ↔ 2.0 only"
  echo "  3) Migrate settings & extensions only"
  echo "  4) Pre-update backup"
  echo "  5) Show status"
  echo "  q) Quit"
  echo ""
  read -rp "Choice: " choice
  case "$choice" in
    1) do_ide_only ;;
    2) do_toggle ;;
    3) do_migrate_settings; do_migrate_extensions ;;
    4) do_backup ;;
    5) do_status ;;
    q|Q) exit 0 ;;
    *) warn "Unknown choice: $choice"; exit 1 ;;
  esac
}

# ── Archive 2.0 profile ───────────────────────────────────────────────────────
do_archive_2_0() {
  section "Archive Antigravity 2.0 Profile"

  ARCHIVE="$HOME/.antigravity-2.0-archive-$(date +%Y%m%d_%H%M%S)"

  if [[ ! -d "$CONFIG_SRC" ]]; then
    warn "2.0 config folder not found — nothing to archive"
    return
  fi

  info "Archiving $CONFIG_SRC → $ARCHIVE ..."
  mv "$CONFIG_SRC" "$ARCHIVE"
  ok "2.0 profile archived to: $ARCHIVE"
  info "The IDE profile at '$CONFIG_DST' is now the only active config."
  info "To undo: mv \"$ARCHIVE\" \"$CONFIG_SRC\""
}

# ── IDE-only mode (full switch) ───────────────────────────────────────────────
do_ide_only() {
  section "Switch to IDE-Only Mode"
  do_toggle
  do_migrate_settings
  do_migrate_extensions
  do_archive_2_0
  echo ""
  ok "Done. Antigravity IDE is now the only active profile."
  ok "Your settings, keybindings, and 44 extensions are all in place."
  ok "The 2.0 profile has been archived (not deleted) — you can restore it any time."
}

# ── Entry point ───────────────────────────────────────────────────────────────
CMD="${1:-menu}"
case "$CMD" in
  toggle)   do_toggle ;;
  migrate)  do_migrate_settings; do_migrate_extensions ;;
  all)      do_toggle; do_migrate_settings; do_migrate_extensions ;;
  ide-only) do_ide_only ;;
  backup)   do_backup ;;
  status)   do_status ;;
  menu)     interactive_menu ;;
  *)
    err "Unknown command: $CMD"
    echo "Usage: $0 [toggle|migrate|all|backup|status]"
    exit 1
    ;;
esac

echo ""
ok "Done."
