#!/usr/bin/env bash
# ============================================================================
# backup-antigravity.sh — Backup & Restore Antigravity CLI Configuration
# ============================================================================
#
# OVERVIEW
#   Syncs your Antigravity CLI customizations (plugins, settings, status line,
#   MCP servers, hooks, skills) across machines via zip archives or GitHub Gists.
#
# USAGE
#   ./backup-antigravity.sh                    # Create zip backup (default)
#   ./backup-antigravity.sh --zip    | -z      # Create zip in ~/backups/antigravity/
#   ./backup-antigravity.sh --gist   | -g      # Upload to a secret GitHub Gist
#   ./backup-antigravity.sh --both   | -b      # Create zip AND upload to Gist
#   ./backup-antigravity.sh --restore| -r <zip># Restore from a zip backup
#   ./backup-antigravity.sh --diff   | -d <zip># Diff backup against current config
#   ./backup-antigravity.sh --list   | -l      # List existing backups
#   ./backup-antigravity.sh --help   | -h      # Show help
#
# WHAT GETS BACKED UP
#   settings.json       Model selection, trusted workspaces, color scheme, etc.
#   statusline.sh       Custom status line rendering script
#   plugins/            Plugin bundles (e.g., artifact-manager) with skills,
#                       hooks, MCP configs, and agent definitions
#   skills/             Global skills (markdown SKILL.md files that become
#                       slash commands available in every workspace)
#   mcp_config.json     Global Model Context Protocol server definitions
#   hooks.json          Pre/post tool event hook definitions
#
# WHAT IS NOT BACKED UP (machine-specific or too large)
#   brain/              Conversation artifacts (use artifact-manager plugin
#                       to export specific artifacts instead)
#   cache/              Transient caches (auto-rebuilt)
#   log/                Runtime logs
#   conversations/      Conversation index metadata
#   builtin/            Ships with the CLI binary; auto-restored on install
#   bin/                CLI binary and internal executables
#   implicit/           Auto-generated internal state
#   knowledge/          Indexed knowledge base (auto-rebuilt)
#
# CROSS-MACHINE SYNC WORKFLOW
#   Machine A (backup):
#     ./backup-antigravity.sh --gist           # uploads to GitHub Gist
#
#   Machine B (restore):
#     gh gist clone <gist-url> /tmp/agy-restore
#     # Gist flattens dirs: plugins__artifact-manager__plugin.json
#     # The --restore command handles zip files directly:
#     ./backup-antigravity.sh --restore <zip>
#
#   Or via shared storage / scp:
#     # Machine A
#     ./backup-antigravity.sh --zip
#     scp ~/backups/antigravity/antigravity-backup-*.zip machineB:~/
#     # Machine B
#     ./backup-antigravity.sh --restore ~/antigravity-backup-*.zip
#
# SAFETY
#   - --restore always creates a pre-restore safety backup before overwriting
#   - --diff lets you inspect changes before restoring
#   - Executable permissions (.sh files) are re-applied after restore
#
# REQUIREMENTS
#   zip     Required for --zip, --both, --restore, --diff
#   unzip   Required for --restore, --diff
#   gh      Required for --gist, --both (https://cli.github.com)
#
# ENVIRONMENT VARIABLES
#   AGY_CONFIG_DIR    Override config path (default: ~/.gemini/antigravity-cli)
#   BACKUP_DIR        Override backup path (default: ~/backups/antigravity)
#
# ============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
# AGY_CONFIG_DIR: The root directory where Antigravity CLI stores all config.
# BACKUP_DIR:     Where zip backups are written to.
# TIMESTAMP:      Used in backup filenames for uniqueness and sorting.
AGY_CONFIG_DIR="${AGY_CONFIG_DIR:-${HOME}/.gemini/antigravity-cli}"
BACKUP_DIR="${BACKUP_DIR:-${HOME}/backups/antigravity}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ZIP_NAME="antigravity-backup-${TIMESTAMP}.zip"

# ─── Backup Targets ──────────────────────────────────────────────────────────
# BACKUP_TARGETS: Files/dirs that are always checked. Missing ones are skipped.
# BACKUP_TARGETS_OPTIONAL: Same behavior, separated for clarity.
BACKUP_TARGETS=(
  "settings.json"     # Core settings: model, color scheme, trusted workspaces
  "statusline.sh"     # Custom status line script (renders ANSI in TUI footer)
  "plugins"           # Plugin bundles — each has plugin.json + skills/ + hooks/
  "mcp_config.json"   # Global MCP server definitions (stdio/SSE/websocket)
  "hooks.json"        # Global pre/post tool event hooks
)

BACKUP_TARGETS_OPTIONAL=(
  "skills"            # Global skills outside of plugins (standalone SKILL.md dirs)
)

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}❌${NC} $*" >&2; }

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Verify the Antigravity config directory exists before any operation.
check_config() {
  if [[ ! -d "${AGY_CONFIG_DIR}" ]]; then
    error "Antigravity config directory not found: ${AGY_CONFIG_DIR}"
    error "Is Antigravity CLI installed? Try: agy --version"
    exit 1
  fi
}

# Scan BACKUP_TARGETS and return only the ones that actually exist on disk.
# This makes the script resilient to fresh installs where not everything exists.
collect_files() {
  local found=()
  for target in "${BACKUP_TARGETS[@]}" "${BACKUP_TARGETS_OPTIONAL[@]}"; do
    local path="${AGY_CONFIG_DIR}/${target}"
    if [[ -e "${path}" ]]; then
      found+=("${target}")
    fi
  done
  echo "${found[@]}"
}

# Print a visual summary of what will be backed up, including plugin/skill names
# and file counts for directories.
print_backup_summary() {
  local files=("$@")
  echo ""
  echo -e "${BOLD}📦 Antigravity CLI Backup Summary${NC}"
  echo "─────────────────────────────────────────"
  echo -e "  Source:  ${AGY_CONFIG_DIR}"
  echo ""
  for f in "${files[@]}"; do
    local path="${AGY_CONFIG_DIR}/${f}"
    if [[ -d "${path}" ]]; then
      local count
      count=$(find "${path}" -type f 2>/dev/null | wc -l)
      echo -e "  ${GREEN}✓${NC} ${f}/  (${count} files)"

      # For plugins/ and skills/, show the individual names inside
      if [[ "${f}" == "plugins" || "${f}" == "skills" ]]; then
        for sub in "${path}"/*/; do
          [[ -d "${sub}" ]] || continue
          local name
          name=$(basename "${sub}")
          local sub_count
          sub_count=$(find "${sub}" -type f 2>/dev/null | wc -l)
          echo -e "    ${CYAN}├─${NC} ${name}  (${sub_count} files)"
        done
      fi
    else
      local size
      size=$(du -h "${path}" 2>/dev/null | cut -f1)
      echo -e "  ${GREEN}✓${NC} ${f}  (${size})"
    fi
  done

  echo ""
  echo -e "  ${DIM}Excluded: brain/, cache/, log/, conversations/, builtin/${NC}"
  echo "─────────────────────────────────────────"
  echo ""
}

# ─── Zip Backup ───────────────────────────────────────────────────────────────
# Creates a timestamped zip archive in ~/backups/antigravity/.
# The zip preserves directory structure so --restore can unzip directly into
# the config dir.
#
# Example output:
#   ~/backups/antigravity/antigravity-backup-20260626_084158.zip
#     ├── settings.json
#     ├── statusline.sh
#     └── plugins/
#         └── artifact-manager/
#             ├── plugin.json
#             └── skills/...

do_zip() {
  check_config

  if ! command -v zip &>/dev/null; then
    error "'zip' is not installed. Install it with: sudo apt install zip"
    exit 1
  fi

  local files
  read -ra files <<< "$(collect_files)"

  if [[ ${#files[@]} -eq 0 ]]; then
    error "No Antigravity config files found to back up."
    exit 1
  fi

  print_backup_summary "${files[@]}"

  mkdir -p "${BACKUP_DIR}"
  local zip_path="${BACKUP_DIR}/${ZIP_NAME}"

  # Zip from within the config dir so paths are relative
  (
    cd "${AGY_CONFIG_DIR}"
    zip -r "${zip_path}" "${files[@]}" \
      -x '*.DS_Store' \
      -x '*/.*' \
      -x '*.log' \
      -x '*/__pycache__/*' \
      -x '*/node_modules/*'
  )

  echo ""
  success "Zip backup created: ${zip_path}"
  echo -e "  Size: $(du -h "${zip_path}" | cut -f1)"
  echo ""

  # Show recent backups if more than one exists
  local backup_count
  backup_count=$(find "${BACKUP_DIR}" -name "antigravity-backup-*.zip" -type f | wc -l)
  if [[ "${backup_count}" -gt 1 ]]; then
    info "You have ${backup_count} backups in ${BACKUP_DIR}"
    echo "  Latest 5:"
    find "${BACKUP_DIR}" -name "antigravity-backup-*.zip" -type f -printf '    %T@ %p\n' \
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
#     e.g. plugins/artifact-manager/plugin.json → plugins__artifact-manager__plugin.json
#   - Best for small configs; for large plugin trees, prefer --zip + scp/Drive
#
# Requires:
#   - gh CLI installed and authenticated (gh auth login)

do_gist() {
  check_config

  if ! command -v gh &>/dev/null; then
    error "'gh' CLI is not installed."
    echo "  Install: https://cli.github.com"
    echo "  Then run: gh auth login"
    exit 1
  fi

  if ! gh auth status &>/dev/null 2>&1; then
    error "Not authenticated with GitHub. Run: gh auth login"
    exit 1
  fi

  local files
  read -ra files <<< "$(collect_files)"

  if [[ ${#files[@]} -eq 0 ]]; then
    error "No Antigravity config files found to back up."
    exit 1
  fi

  print_backup_summary "${files[@]}"

  # Flatten directory structure for Gist compatibility
  local temp_dir
  temp_dir=$(mktemp -d)
  trap 'rm -rf "${temp_dir}"' EXIT

  for f in "${files[@]}"; do
    local path="${AGY_CONFIG_DIR}/${f}"
    if [[ -d "${path}" ]]; then
      # Flatten: plugins/artifact-manager/plugin.json → plugins__artifact-manager__plugin.json
      find "${path}" -type f | while read -r file; do
        local relative="${file#"${AGY_CONFIG_DIR}/"}"
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
    --desc "Antigravity CLI Backup — ${TIMESTAMP}" \
    "${gist_files[@]}" 2>&1)

  echo ""
  success "Gist created: ${gist_url}"
  echo ""
  echo -e "  ${BOLD}To restore from this gist later:${NC}"
  echo "  gh gist clone ${gist_url} /tmp/antigravity-restore"
  echo "  # Then copy files back to ~/.gemini/antigravity-cli/"
  echo ""
}

# ─── Restore ──────────────────────────────────────────────────────────────────
# Restores config from a zip backup file.
#
# Safety features:
#   1. Shows zip contents before extracting
#   2. Asks for confirmation
#   3. Creates a pre-restore safety backup (antigravity-pre-restore-*.zip)
#      so you can always roll back if something goes wrong
#   4. Re-applies chmod +x to .sh files (zip may not preserve permissions)
#
# Usage:
#   ./backup-antigravity.sh --restore ~/backups/antigravity/antigravity-backup-20260626.zip
#   ./backup-antigravity.sh -r /tmp/transferred-backup.zip

do_restore() {
  local zip_file="$1"

  if [[ ! -f "${zip_file}" ]]; then
    error "Zip file not found: ${zip_file}"
    exit 1
  fi

  echo ""
  echo -e "${BOLD}🔄 Restore Antigravity CLI Config${NC}"
  echo "─────────────────────────────────────────"
  echo -e "  Source: ${zip_file}"
  echo -e "  Target: ${AGY_CONFIG_DIR}"
  echo ""

  # Preview: show what's inside the zip
  info "Contents of backup:"
  unzip -l "${zip_file}" | tail -n +4 | head -n -2 | while read -r line; do
    echo "    ${line}"
  done
  echo ""

  # Require explicit confirmation before overwriting
  echo -e "${YELLOW}This will overwrite existing Antigravity CLI config files.${NC}"
  read -rp "Continue? [y/N] " confirm
  if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
    info "Restore cancelled."
    exit 0
  fi

  # Safety: back up current config before overwriting, so you can roll back
  if [[ -d "${AGY_CONFIG_DIR}" ]]; then
    local pre_restore_backup="${BACKUP_DIR}/antigravity-pre-restore-${TIMESTAMP}.zip"
    mkdir -p "${BACKUP_DIR}"
    info "Backing up current config first → ${pre_restore_backup}"
    (
      cd "${AGY_CONFIG_DIR}"
      local current_files
      read -ra current_files <<< "$(collect_files)"
      if [[ ${#current_files[@]} -gt 0 ]]; then
        zip -r "${pre_restore_backup}" "${current_files[@]}" -x '*.DS_Store' 2>/dev/null || true
      fi
    )
  fi

  # Extract into the config directory
  mkdir -p "${AGY_CONFIG_DIR}"
  unzip -o "${zip_file}" -d "${AGY_CONFIG_DIR}"

  # Re-apply executable permissions on scripts (zip doesn't always preserve them)
  find "${AGY_CONFIG_DIR}" -name "*.sh" -exec chmod +x {} \;

  echo ""
  success "Restore complete! Restart agy to apply changes."
  echo ""
}

# ─── Diff ─────────────────────────────────────────────────────────────────────
# Compare a backup zip against your current config to see what changed.
#
# Shows three states:
#   MISSING  — file exists in backup but not in current config (was deleted)
#   CHANGED  — file differs between backup and current (shows unified diff)
#   NEW      — file exists in current but not in backup (was added since)
#
# Useful before restoring to understand what will change, or to audit drift
# between machines.
#
# Usage:
#   ./backup-antigravity.sh --diff ~/backups/antigravity/antigravity-backup-20260626.zip

do_diff() {
  local zip_file="$1"

  if [[ ! -f "${zip_file}" ]]; then
    error "Zip file not found: ${zip_file}"
    exit 1
  fi

  # Extract backup to temp dir for comparison
  local temp_dir
  temp_dir=$(mktemp -d)
  trap 'rm -rf "${temp_dir}"' EXIT

  unzip -qo "${zip_file}" -d "${temp_dir}"

  echo ""
  echo -e "${BOLD}🔍 Diff: backup vs current config${NC}"
  echo "─────────────────────────────────────────"
  echo ""

  # Compare: files in backup vs current
  find "${temp_dir}" -type f | while read -r backup_file; do
    local relative="${backup_file#"${temp_dir}/"}"
    local current="${AGY_CONFIG_DIR}/${relative}"

    if [[ ! -e "${current}" ]]; then
      echo -e "  ${RED}MISSING${NC}  ${relative}  (exists in backup, not in current)"
    elif ! diff -q "${backup_file}" "${current}" &>/dev/null; then
      echo -e "  ${YELLOW}CHANGED${NC} ${relative}"
      diff --color=always -u "${backup_file}" "${current}" | head -20 | sed 's/^/    /'
      echo ""
    fi
  done

  # Compare: files in current but not in backup
  local files
  read -ra files <<< "$(collect_files)"
  for f in "${files[@]}"; do
    local path="${AGY_CONFIG_DIR}/${f}"
    if [[ -f "${path}" ]] && [[ ! -f "${temp_dir}/${f}" ]]; then
      echo -e "  ${GREEN}NEW${NC}     ${f}  (exists in current, not in backup)"
    elif [[ -d "${path}" ]]; then
      find "${path}" -type f | while read -r current_file; do
        local relative="${current_file#"${AGY_CONFIG_DIR}/"}"
        if [[ ! -f "${temp_dir}/${relative}" ]]; then
          echo -e "  ${GREEN}NEW${NC}     ${relative}  (exists in current, not in backup)"
        fi
      done
    fi
  done

  echo "─────────────────────────────────────────"
  echo ""
}

# ─── List Backups ─────────────────────────────────────────────────────────────
# Show all existing backups in ~/backups/antigravity/, sorted newest first.
# Includes both regular backups and pre-restore safety backups.
#
# Usage:
#   ./backup-antigravity.sh --list

do_list() {
  if [[ ! -d "${BACKUP_DIR}" ]]; then
    info "No backups found. Run './backup-antigravity.sh --zip' to create one."
    exit 0
  fi

  local backups
  backups=$(find "${BACKUP_DIR}" -name "antigravity-*.zip" -type f 2>/dev/null | sort -r)

  if [[ -z "${backups}" ]]; then
    info "No backups found in ${BACKUP_DIR}"
    exit 0
  fi

  echo ""
  echo -e "${BOLD}📋 Antigravity CLI Backups${NC}"
  echo "─────────────────────────────────────────"
  while IFS= read -r path; do
    local size
    size=$(du -h "${path}" | cut -f1)
    local bname
    bname=$(basename "${path}")
    echo -e "  ${bname}  (${size})"
  done <<< "${backups}"
  echo "─────────────────────────────────────────"
  echo ""
  echo "  Restore:  ./backup-antigravity.sh --restore <path>"
  echo "  Diff:     ./backup-antigravity.sh --diff <path>"
  echo ""
}

# ─── Usage ────────────────────────────────────────────────────────────────────

usage() {
  echo ""
  echo -e "${BOLD}backup-antigravity.sh${NC} — Backup & restore Antigravity CLI configuration"
  echo ""
  echo "Usage:"
  echo "  ./backup-antigravity.sh              Create a zip backup (default)"
  echo "  ./backup-antigravity.sh --zip   -z   Create a zip backup in ~/backups/antigravity/"
  echo "  ./backup-antigravity.sh --gist  -g   Upload to a secret GitHub Gist"
  echo "  ./backup-antigravity.sh --both  -b   Create zip AND upload to Gist"
  echo "  ./backup-antigravity.sh --restore -r <zip>  Restore from a zip backup"
  echo "  ./backup-antigravity.sh --diff  -d <zip>    Compare backup vs current"
  echo "  ./backup-antigravity.sh --list  -l   List existing backups"
  echo "  ./backup-antigravity.sh --help  -h   Show this help"
  echo ""
  echo "Backed up:"
  echo "  settings.json, statusline.sh, plugins/, skills/, mcp_config.json, hooks.json"
  echo ""
  echo "Not backed up (machine-specific):"
  echo "  brain/, cache/, log/, conversations/, builtin/"
  echo ""
  echo "Environment:"
  echo "  AGY_CONFIG_DIR   Override config dir  (default: ~/.gemini/antigravity-cli)"
  echo "  BACKUP_DIR       Override backup dir  (default: ~/backups/antigravity)"
  echo ""
  echo "Examples:"
  echo "  ./backup-antigravity.sh --zip                     # Local backup"
  echo "  ./backup-antigravity.sh --gist                    # Sync via GitHub"
  echo "  ./backup-antigravity.sh --diff ~/backups/antigravity/antigravity-backup-20260626.zip"
  echo "  ./backup-antigravity.sh --restore ~/transferred-backup.zip"
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
        echo "  Usage: ./backup-antigravity.sh --restore <path-to-zip>"
        exit 1
      fi
      do_restore "$2"
      ;;
    --diff|-d)
      if [[ -z "${2:-}" ]]; then
        error "Please provide a zip file path."
        echo "  Usage: ./backup-antigravity.sh --diff <path-to-zip>"
        exit 1
      fi
      do_diff "$2"
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
