#!/usr/bin/env bash
# ============================================================================
# backup-zed.sh — Backup & Restore Zed Editor Configuration
# ============================================================================
#
# OVERVIEW
#   Syncs your Zed editor configuration (settings, keybindings, themes,
#   extensions, snippets) across machines via zip archives or GitHub Gists.
#
# USAGE
#   ./backup-zed.sh                    # Create zip backup (default)
#   ./backup-zed.sh --zip    | -z      # Create zip in ~/backups/zed/
#   ./backup-zed.sh --gist   | -g      # Upload to a secret GitHub Gist
#   ./backup-zed.sh --both   | -b      # Create zip AND upload to Gist
#   ./backup-zed.sh --restore| -r <zip># Restore from a zip backup
#   ./backup-zed.sh --list   | -l      # List existing backups
#   ./backup-zed.sh --help   | -h      # Show help
#
# WHAT GETS BACKED UP
#   settings.json     Editor preferences: font, theme, LSP, formatting, etc.
#   keymap.json       Custom keybindings and key remappings
#   tasks.json        Task runner definitions (build, test, lint commands)
#   debug.json        Debug adapter configurations (DAP)
#   themes/           Custom color themes (.json theme files)
#   extensions/       Installed extension manifests and state
#   snippets/         User-defined code snippets per language
#
# WHAT IS NOT BACKED UP
#   db/               Internal database (auto-rebuilt)
#   copilot/          Copilot auth tokens (machine-specific)
#   node/             Bundled Node.js runtime
#   logs/             Runtime logs
#   languages/        Downloaded language server binaries
#   *_server/         LSP server state directories
#
# CROSS-MACHINE SYNC WORKFLOW
#   Machine A (backup):
#     ./backup-zed.sh --gist             # uploads to GitHub Gist
#
#   Machine B (restore):
#     gh gist clone <gist-url> /tmp/zed-restore
#     # Unflatten files back into ~/.config/zed/
#
#   Or via zip + scp/Drive:
#     # Machine A
#     ./backup-zed.sh --zip
#     scp ~/backups/zed/zed-backup-*.zip machineB:~/
#     # Machine B
#     ./backup-zed.sh --restore ~/zed-backup-*.zip
#
# SAFETY
#   - --restore creates a pre-restore safety backup (zed-pre-restore-*.zip)
#     before overwriting, so you can always roll back
#   - Asks for explicit [y/N] confirmation before restoring
#   - Shows zip contents before extraction
#
# REQUIREMENTS
#   zip     Required for --zip, --both, --restore
#   unzip   Required for --restore
#   gh      Required for --gist, --both (https://cli.github.com)
#
# ENVIRONMENT VARIABLES
#   ZED_CONFIG_DIR    Override config path (default: ~/.config/zed)
#   BACKUP_DIR        Override backup path (default: ~/backups/zed)
#
# ============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
# ZED_CONFIG_DIR: Where Zed stores its configuration files.
#   Linux:   ~/.config/zed
#   macOS:   ~/Library/Application Support/Zed
# BACKUP_DIR:    Where zip backups are written to.
# TIMESTAMP:     Used in backup filenames for uniqueness and chronological sorting.
ZED_CONFIG_DIR="${ZED_CONFIG_DIR:-${HOME}/.config/zed}"
BACKUP_DIR="${BACKUP_DIR:-${HOME}/backups/zed}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ZIP_NAME="zed-backup-${TIMESTAMP}.zip"

# ─── Backup Targets ──────────────────────────────────────────────────────────
# Files and directories to include in backups. Each entry is relative to
# ZED_CONFIG_DIR. Missing targets are silently skipped (e.g., if a user
# hasn't created snippets/ yet).
BACKUP_TARGETS=(
  "settings.json"   # Core editor settings: font, theme, LSP config, formatting
  "keymap.json"     # Custom keybindings (overrides default keymap)
  "tasks.json"      # Task definitions: build, test, lint, custom commands
  "debug.json"      # Debug adapter protocol (DAP) launch configurations
  "themes"          # Custom themes directory (user-created .json theme files)
  "extensions"      # Installed extension metadata and state
  "snippets"        # Per-language code snippet definitions
)

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}❌${NC} $*" >&2; }

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Verify the Zed config directory exists before any operation.
# Exits with an error if Zed hasn't been configured on this machine.
check_zed_config() {
  if [[ ! -d "${ZED_CONFIG_DIR}" ]]; then
    error "Zed config directory not found: ${ZED_CONFIG_DIR}"
    error "Is Zed installed? Config is created on first launch."
    exit 1
  fi
}

# Scan BACKUP_TARGETS and return only the ones that actually exist on disk.
# This makes the script safe to run on fresh installs where optional files
# (e.g., snippets/, debug.json) haven't been created yet.
collect_files() {
  local found=()
  for target in "${BACKUP_TARGETS[@]}"; do
    local path="${ZED_CONFIG_DIR}/${target}"
    if [[ -e "${path}" ]]; then
      found+=("${target}")
    fi
  done
  echo "${found[@]}"
}

# Print a visual summary of what will be backed up.
# Shows file sizes for individual files and file counts for directories.
print_backup_summary() {
  local files=("$@")
  echo ""
  echo -e "${BOLD}📦 Zed Backup Summary${NC}"
  echo "─────────────────────────────────────"
  echo -e "  Source:  ${ZED_CONFIG_DIR}"
  echo ""
  for f in "${files[@]}"; do
    local path="${ZED_CONFIG_DIR}/${f}"
    if [[ -d "${path}" ]]; then
      local count
      count=$(find "${path}" -type f 2>/dev/null | wc -l)
      echo -e "  ${GREEN}✓${NC} ${f}/  (${count} files)"
    else
      local size
      size=$(du -h "${path}" 2>/dev/null | cut -f1)
      echo -e "  ${GREEN}✓${NC} ${f}  (${size})"
    fi
  done
  echo "─────────────────────────────────────"
  echo ""
}

# ─── Zip Backup ───────────────────────────────────────────────────────────────
# Creates a timestamped zip archive in ~/backups/zed/.
# The zip preserves directory structure so --restore can unzip directly
# into the config dir.
#
# Example output:
#   ~/backups/zed/zed-backup-20260626_084200.zip
#     ├── settings.json
#     ├── keymap.json
#     ├── themes/
#     │   └── my-dark-theme.json
#     └── snippets/
#         └── python.json
#
# Excludes: .DS_Store, hidden dotfiles

do_zip() {
  check_zed_config

  if ! command -v zip &>/dev/null; then
    error "'zip' is not installed. Install it with: sudo apt install zip"
    exit 1
  fi

  local files
  read -ra files <<< "$(collect_files)"

  if [[ ${#files[@]} -eq 0 ]]; then
    error "No Zed config files found to back up."
    exit 1
  fi

  print_backup_summary "${files[@]}"

  mkdir -p "${BACKUP_DIR}"
  local zip_path="${BACKUP_DIR}/${ZIP_NAME}"

  # Zip from within the config directory so paths inside the archive
  # are relative (settings.json, not ~/.config/zed/settings.json)
  (
    cd "${ZED_CONFIG_DIR}"
    zip -r "${zip_path}" "${files[@]}" -x '*.DS_Store' '*/.*'
  )

  echo ""
  success "Zip backup created: ${zip_path}"
  echo -e "  Size: $(du -h "${zip_path}" | cut -f1)"
  echo ""

  # Show recent backups if more than one exists, so the user can track history
  local backup_count
  backup_count=$(find "${BACKUP_DIR}" -name "zed-backup-*.zip" -type f | wc -l)
  if [[ "${backup_count}" -gt 1 ]]; then
    info "You have ${backup_count} backups in ${BACKUP_DIR}"
    echo "  Latest 5:"
    find "${BACKUP_DIR}" -name "zed-backup-*.zip" -type f -printf '    %T@ %p\n' \
      | sort -rn | head -5 | while read -r _ path; do
        echo -e "    ${path}  ($(du -h "${path}" | cut -f1))"
      done
    echo ""
  fi
}

# ─── Gist Backup ─────────────────────────────────────────────────────────────
# Uploads config to a secret GitHub Gist for cross-machine sync.
#
# Gist limitations:
#   - No directory support — files are flattened with __ separators
#     e.g. themes/my-dark.json → themes__my-dark.json
#   - Gists have a soft size limit (~10MB) — fine for config, not for large
#     extension binaries
#
# Requires:
#   - gh CLI installed and authenticated (gh auth login)
#
# To restore from a Gist:
#   gh gist clone <url> /tmp/zed-restore
#   # Manually unflatten the __ separator files back into directories
#   # Or use --restore with a zip backup instead (recommended)

do_gist() {
  check_zed_config

  if ! command -v gh &>/dev/null; then
    error "'gh' CLI is not installed."
    echo "  Install: https://cli.github.com"
    echo "  Then run: gh auth login"
    exit 1
  fi

  # Verify GitHub authentication before proceeding
  if ! gh auth status &>/dev/null 2>&1; then
    error "Not authenticated with GitHub. Run: gh auth login"
    exit 1
  fi

  local files
  read -ra files <<< "$(collect_files)"

  if [[ ${#files[@]} -eq 0 ]]; then
    error "No Zed config files found to back up."
    exit 1
  fi

  print_backup_summary "${files[@]}"

  # Flatten directory structure for Gist compatibility.
  # Gists are flat file lists — no subdirectories allowed.
  # Convention: path separators become __ (double underscore)
  #   themes/foo.json → themes__foo.json
  #   snippets/python.json → snippets__python.json
  local gist_args=()
  local temp_dir
  temp_dir=$(mktemp -d)
  trap 'rm -rf "${temp_dir}"' EXIT

  for f in "${files[@]}"; do
    local path="${ZED_CONFIG_DIR}/${f}"
    if [[ -d "${path}" ]]; then
      find "${path}" -type f | while read -r file; do
        local relative="${file#"${ZED_CONFIG_DIR}/"}"
        local flat_name="${relative//\//__}"
        cp "${file}" "${temp_dir}/${flat_name}"
      done
    else
      cp "${path}" "${temp_dir}/${f}"
    fi
  done

  info "Uploading to GitHub Gist..."
  echo ""

  local gist_files=()
  for file in "${temp_dir}"/*; do
    [[ -f "${file}" ]] && gist_files+=("${file}")
  done

  if [[ ${#gist_files[@]} -eq 0 ]]; then
    error "No files to upload."
    exit 1
  fi

  local gist_url
  gist_url=$(gh gist create \
    --desc "Zed Editor Backup — ${TIMESTAMP}" \
    "${gist_files[@]}" 2>&1)

  echo ""
  success "Gist created: ${gist_url}"
  echo ""
  echo -e "  ${BOLD}To restore from this gist later:${NC}"
  echo "  gh gist clone ${gist_url} /tmp/zed-restore"
  echo "  # Then copy files back to ~/.config/zed/"
  echo ""
}

# ─── Restore ──────────────────────────────────────────────────────────────────
# Restores config from a zip backup file.
#
# Safety features:
#   1. Shows zip contents before extracting (so you can verify)
#   2. Asks for explicit [y/N] confirmation
#   3. Creates a pre-restore safety backup (zed-pre-restore-*.zip)
#      so you can always roll back if something goes wrong
#   4. Extracts with -o (overwrite) into the config directory
#
# Usage:
#   ./backup-zed.sh --restore ~/backups/zed/zed-backup-20260626.zip
#   ./backup-zed.sh -r /tmp/transferred-backup.zip
#
# After restore:
#   Restart Zed to pick up the restored configuration.

do_restore() {
  local zip_file="$1"

  if [[ ! -f "${zip_file}" ]]; then
    error "Zip file not found: ${zip_file}"
    exit 1
  fi

  echo ""
  echo -e "${BOLD}🔄 Restore Zed Config${NC}"
  echo "─────────────────────────────────────"
  echo -e "  Source: ${zip_file}"
  echo -e "  Target: ${ZED_CONFIG_DIR}"
  echo ""

  # Preview: show what's inside the zip before extracting
  info "Contents of backup:"
  unzip -l "${zip_file}" | tail -n +4 | head -n -2 | while read -r line; do
    echo "    ${line}"
  done
  echo ""

  # Require explicit confirmation before overwriting
  echo -e "${YELLOW}This will overwrite existing Zed config files.${NC}"
  read -rp "Continue? [y/N] " confirm
  if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
    info "Restore cancelled."
    exit 0
  fi

  # Safety: back up current config before overwriting.
  # This means you can always roll back with:
  #   ./backup-zed.sh --restore ~/backups/zed/zed-pre-restore-*.zip
  if [[ -d "${ZED_CONFIG_DIR}" ]]; then
    local pre_restore_backup="${BACKUP_DIR}/zed-pre-restore-${TIMESTAMP}.zip"
    mkdir -p "${BACKUP_DIR}"
    info "Backing up current config first → ${pre_restore_backup}"
    (
      cd "${ZED_CONFIG_DIR}"
      local current_files
      read -ra current_files <<< "$(collect_files)"
      if [[ ${#current_files[@]} -gt 0 ]]; then
        zip -r "${pre_restore_backup}" "${current_files[@]}" -x '*.DS_Store' 2>/dev/null || true
      fi
    )
  fi

  # Extract into the config directory (overwrite existing files)
  mkdir -p "${ZED_CONFIG_DIR}"
  unzip -o "${zip_file}" -d "${ZED_CONFIG_DIR}"

  echo ""
  success "Restore complete! Restart Zed to apply changes."
  echo ""
}

# ─── List Backups ─────────────────────────────────────────────────────────────
# Show all existing backups in ~/backups/zed/, sorted newest first.
# Includes both regular backups (zed-backup-*) and pre-restore safety
# backups (zed-pre-restore-*).
#
# Usage:
#   ./backup-zed.sh --list

do_list() {
  if [[ ! -d "${BACKUP_DIR}" ]]; then
    info "No backups found. Run './backup-zed.sh --zip' to create one."
    exit 0
  fi

  local backups
  backups=$(find "${BACKUP_DIR}" -name "zed-*.zip" -type f 2>/dev/null | sort -r)

  if [[ -z "${backups}" ]]; then
    info "No backups found in ${BACKUP_DIR}"
    exit 0
  fi

  echo ""
  echo -e "${BOLD}📋 Zed Backups${NC}"
  echo "─────────────────────────────────────"
  while IFS= read -r path; do
    local size
    size=$(du -h "${path}" | cut -f1)
    local basename
    basename=$(basename "${path}")
    echo -e "  ${basename}  (${size})"
  done <<< "${backups}"
  echo "─────────────────────────────────────"
  echo ""
  echo "  Restore with: ./backup-zed.sh --restore <path>"
  echo ""
}

# ─── Usage ────────────────────────────────────────────────────────────────────

usage() {
  echo ""
  echo -e "${BOLD}backup-zed.sh${NC} — Backup & restore Zed editor configuration"
  echo ""
  echo "Usage:"
  echo "  ./backup-zed.sh              Create a zip backup (default)"
  echo "  ./backup-zed.sh --zip   -z   Create a zip backup in ~/backups/zed/"
  echo "  ./backup-zed.sh --gist  -g   Upload to a secret GitHub Gist"
  echo "  ./backup-zed.sh --both  -b   Create zip AND upload to Gist"
  echo "  ./backup-zed.sh --restore -r <zip>  Restore from a zip backup"
  echo "  ./backup-zed.sh --list  -l   List existing backups"
  echo "  ./backup-zed.sh --help  -h   Show this help"
  echo ""
  echo "Backed up:"
  echo "  settings.json, keymap.json, tasks.json, debug.json,"
  echo "  themes/, extensions/, snippets/"
  echo ""
  echo "Environment:"
  echo "  ZED_CONFIG_DIR   Override config dir  (default: ~/.config/zed)"
  echo "  BACKUP_DIR       Override backup dir  (default: ~/backups/zed)"
  echo ""
  echo "Examples:"
  echo "  ./backup-zed.sh --zip                              # Local backup"
  echo "  ./backup-zed.sh --gist                             # Sync via GitHub"
  echo "  ./backup-zed.sh --restore ~/backups/zed/zed-backup-20260626.zip"
  echo "  ZED_CONFIG_DIR=~/Library/Application\\ Support/Zed ./backup-zed.sh  # macOS"
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  local mode="${1:---zip}"

  case "${mode}" in
    --zip|-z)
      do_zip
      ;;
    --gist|-g)
      do_gist
      ;;
    --both|-b)
      do_zip
      do_gist
      ;;
    --restore|-r)
      if [[ -z "${2:-}" ]]; then
        error "Please provide a zip file path."
        echo "  Usage: ./backup-zed.sh --restore <path-to-zip>"
        exit 1
      fi
      do_restore "$2"
      ;;
    --list|-l)
      do_list
      ;;
    --help|-h)
      usage
      ;;
    *)
      error "Unknown option: ${mode}"
      usage
      exit 1
      ;;
  esac
}

main "$@"
