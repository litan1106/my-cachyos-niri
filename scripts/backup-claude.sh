#!/usr/bin/env bash
# ============================================================================
# backup-claude.sh — Backup & Restore Claude Code Configuration
# ============================================================================
#
# OVERVIEW
#   Syncs your Claude Code configuration (instructions, agents, skills,
#   rules, hooks, MCP configs) across machines via zip archives or
#   GitHub Gists.
#
# USAGE
#   ./backup-claude.sh                    # Create zip backup (default)
#   ./backup-claude.sh --zip    | -z      # Create zip in ~/backups/claude/
#   ./backup-claude.sh --gist   | -g      # Upload to a secret GitHub Gist
#   ./backup-claude.sh --both   | -b      # Create zip AND upload to Gist
#   ./backup-claude.sh --restore| -r <zip># Restore from a zip backup
#   ./backup-claude.sh --list   | -l      # List existing backups
#   ./backup-claude.sh --help   | -h      # Show help
#
# WHAT GETS BACKED UP
#   CLAUDE.md         Global instructions applied to all projects
#   RTK.md            Token-optimization CLI proxy reference
#   settings.json     Hooks, effort level, theme, default agent model
#   keybindings.json  Custom keyboard shortcut bindings
#   agents/           Custom subagent definitions
#   skills/           Custom skill definitions
#   rules/            Rule packs (e.g. the ecc/ ruleset)
#   hooks/            PreToolUse/PostToolUse/Stop hook scripts
#   mcp-configs/      MCP server configuration
#
# WHAT IS NOT BACKED UP
#   .credentials.json     OAuth tokens / secrets (machine-specific, sensitive)
#   projects/, sessions/   Conversation transcripts (large, private)
#   history.jsonl          Command history log
#   cache/, telemetry/     Regenerable caches and usage stats
#   plugins/                Marketplace/plugin cache (regenerate via marketplace.json)
#   downloads/, paste-cache/, file-history/, shell-snapshots/, session-env/
#   backups/                This script's own output directory
#
# CROSS-MACHINE SYNC WORKFLOW
#   Machine A (backup):
#     ./backup-claude.sh --gist          # uploads to GitHub Gist
#
#   Machine B (restore):
#     gh gist clone <gist-url> /tmp/claude-restore
#     # Unflatten files back into ~/.claude/
#
#   Or via zip + scp/Drive:
#     # Machine A
#     ./backup-claude.sh --zip
#     scp ~/backups/claude/claude-backup-*.zip machineB:~/
#     # Machine B
#     ./backup-claude.sh --restore ~/claude-backup-*.zip
#
# SAFETY
#   - --restore creates a pre-restore safety backup (claude-pre-restore-*.zip)
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
#   CLAUDE_CONFIG_DIR    Override config path (default: ~/.claude)
#   BACKUP_DIR           Override backup path (default: ~/backups/claude)
#
# ============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
# CLAUDE_CONFIG_DIR: Where Claude Code stores its configuration.
# BACKUP_DIR:        Where zip backups are written to.
# TIMESTAMP:         Used in backup filenames for uniqueness and chronological sorting.
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
BACKUP_DIR="${BACKUP_DIR:-${HOME}/backups/claude}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ZIP_NAME="claude-backup-${TIMESTAMP}.zip"

# ─── Backup Targets ──────────────────────────────────────────────────────────
# Files and directories to include in backups. Each entry is relative to
# CLAUDE_CONFIG_DIR. Missing targets are silently skipped (e.g., if a user
# hasn't set up keybindings.json or mcp-configs/ yet).
BACKUP_TARGETS=(
  "CLAUDE.md"        # Global instructions applied to all projects
  "RTK.md"           # Token-optimization CLI proxy reference
  "settings.json"    # Hooks, effort level, theme, default agent model
  "keybindings.json" # Custom keyboard shortcut bindings
  "agents"           # Custom subagent definitions
  "skills"           # Custom skill definitions
  "rules"            # Rule packs (e.g. the ecc/ ruleset)
  "hooks"            # PreToolUse/PostToolUse/Stop hook scripts
  "mcp-configs"       # MCP server configuration
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

# Verify the Claude config directory exists before any operation.
check_claude_config() {
  if [[ ! -d "${CLAUDE_CONFIG_DIR}" ]]; then
    error "Claude config directory not found: ${CLAUDE_CONFIG_DIR}"
    error "Is Claude Code installed? Config is created on first run."
    exit 1
  fi
}

# Scan BACKUP_TARGETS and return only the ones that actually exist on disk.
collect_files() {
  local found=()
  for target in "${BACKUP_TARGETS[@]}"; do
    local path="${CLAUDE_CONFIG_DIR}/${target}"
    if [[ -e "${path}" ]]; then
      found+=("${target}")
    fi
  done
  echo "${found[@]}"
}

# Print a visual summary of what will be backed up.
print_backup_summary() {
  local files=("$@")
  echo ""
  echo -e "${BOLD}📦 Claude Code Backup Summary${NC}"
  echo "─────────────────────────────────────"
  echo -e "  Source:  ${CLAUDE_CONFIG_DIR}"
  echo ""
  for f in "${files[@]}"; do
    local path="${CLAUDE_CONFIG_DIR}/${f}"
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
# Creates a timestamped zip archive in ~/backups/claude/.
# Excludes: .DS_Store, hidden dotfiles

do_zip() {
  check_claude_config

  if ! command -v zip &>/dev/null; then
    error "'zip' is not installed. Install it with: sudo apt install zip"
    exit 1
  fi

  local files
  read -ra files <<< "$(collect_files)"

  if [[ ${#files[@]} -eq 0 ]]; then
    error "No Claude config files found to back up."
    exit 1
  fi

  print_backup_summary "${files[@]}"

  mkdir -p "${BACKUP_DIR}"
  local zip_path="${BACKUP_DIR}/${ZIP_NAME}"

  # Zip from within the config directory so paths inside the archive
  # are relative (settings.json, not ~/.claude/settings.json)
  (
    cd "${CLAUDE_CONFIG_DIR}"
    zip -r "${zip_path}" "${files[@]}" -x '*.DS_Store' '*/.*'
  )

  echo ""
  success "Zip backup created: ${zip_path}"
  echo -e "  Size: $(du -h "${zip_path}" | cut -f1)"
  echo ""

  # Show recent backups if more than one exists, so the user can track history
  local backup_count
  backup_count=$(find "${BACKUP_DIR}" -name "claude-backup-*.zip" -type f | wc -l)
  if [[ "${backup_count}" -gt 1 ]]; then
    info "You have ${backup_count} backups in ${BACKUP_DIR}"
    echo "  Latest 5:"
    find "${BACKUP_DIR}" -name "claude-backup-*.zip" -type f -printf '    %T@ %p\n' \
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
#     e.g. rules/ecc/common/testing.md → rules__ecc__common__testing.md
#   - Gists have a soft size limit (~10MB) — fine for config
#
# Requires:
#   - gh CLI installed and authenticated (gh auth login)
#
# To restore from a Gist:
#   gh gist clone <url> /tmp/claude-restore
#   # Manually unflatten the __ separator files back into directories
#   # Or use --restore with a zip backup instead (recommended)

do_gist() {
  check_claude_config

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
    error "No Claude config files found to back up."
    exit 1
  fi

  print_backup_summary "${files[@]}"

  # Flatten directory structure for Gist compatibility.
  # Gists are flat file lists — no subdirectories allowed.
  # Convention: path separators become __ (double underscore)
  local temp_dir
  temp_dir=$(mktemp -d)
  trap 'rm -rf "${temp_dir}"' EXIT

  for f in "${files[@]}"; do
    local path="${CLAUDE_CONFIG_DIR}/${f}"
    if [[ -d "${path}" ]]; then
      find "${path}" -type f | while read -r file; do
        local relative="${file#"${CLAUDE_CONFIG_DIR}/"}"
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
    --desc "Claude Code Config Backup — ${TIMESTAMP}" \
    "${gist_files[@]}" 2>&1)

  echo ""
  success "Gist created: ${gist_url}"
  echo ""
  echo -e "  ${BOLD}To restore from this gist later:${NC}"
  echo "  gh gist clone ${gist_url} /tmp/claude-restore"
  echo "  # Then copy files back to ~/.claude/"
  echo ""
}

# ─── Restore ──────────────────────────────────────────────────────────────────
# Restores config from a zip backup file.
#
# Safety features:
#   1. Shows zip contents before extracting (so you can verify)
#   2. Asks for explicit [y/N] confirmation
#   3. Creates a pre-restore safety backup (claude-pre-restore-*.zip)
#      so you can always roll back if something goes wrong
#   4. Extracts with -o (overwrite) into the config directory
#
# Usage:
#   ./backup-claude.sh --restore ~/backups/claude/claude-backup-20260713.zip
#   ./backup-claude.sh -r /tmp/transferred-backup.zip
#
# After restore:
#   Restart Claude Code to pick up the restored configuration.

do_restore() {
  local zip_file="$1"

  if [[ ! -f "${zip_file}" ]]; then
    error "Zip file not found: ${zip_file}"
    exit 1
  fi

  echo ""
  echo -e "${BOLD}🔄 Restore Claude Code Config${NC}"
  echo "─────────────────────────────────────"
  echo -e "  Source: ${zip_file}"
  echo -e "  Target: ${CLAUDE_CONFIG_DIR}"
  echo ""

  # Preview: show what's inside the zip before extracting
  info "Contents of backup:"
  unzip -l "${zip_file}" | tail -n +4 | head -n -2 | while read -r line; do
    echo "    ${line}"
  done
  echo ""

  # Require explicit confirmation before overwriting
  echo -e "${YELLOW}This will overwrite existing Claude Code config files.${NC}"
  read -rp "Continue? [y/N] " confirm
  if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
    info "Restore cancelled."
    exit 0
  fi

  # Safety: back up current config before overwriting.
  # This means you can always roll back with:
  #   ./backup-claude.sh --restore ~/backups/claude/claude-pre-restore-*.zip
  if [[ -d "${CLAUDE_CONFIG_DIR}" ]]; then
    local pre_restore_backup="${BACKUP_DIR}/claude-pre-restore-${TIMESTAMP}.zip"
    mkdir -p "${BACKUP_DIR}"
    info "Backing up current config first → ${pre_restore_backup}"
    (
      cd "${CLAUDE_CONFIG_DIR}"
      local current_files
      read -ra current_files <<< "$(collect_files)"
      if [[ ${#current_files[@]} -gt 0 ]]; then
        zip -r "${pre_restore_backup}" "${current_files[@]}" -x '*.DS_Store' 2>/dev/null || true
      fi
    )
  fi

  # Extract into the config directory (overwrite existing files)
  mkdir -p "${CLAUDE_CONFIG_DIR}"
  unzip -o "${zip_file}" -d "${CLAUDE_CONFIG_DIR}"

  echo ""
  success "Restore complete! Restart Claude Code to apply changes."
  echo ""
}

# ─── List Backups ─────────────────────────────────────────────────────────────
# Show all existing backups in ~/backups/claude/, sorted newest first.
#
# Usage:
#   ./backup-claude.sh --list

do_list() {
  if [[ ! -d "${BACKUP_DIR}" ]]; then
    info "No backups found. Run './backup-claude.sh --zip' to create one."
    exit 0
  fi

  local backups
  backups=$(find "${BACKUP_DIR}" -name "claude-*.zip" -type f 2>/dev/null | sort -r)

  if [[ -z "${backups}" ]]; then
    info "No backups found in ${BACKUP_DIR}"
    exit 0
  fi

  echo ""
  echo -e "${BOLD}📋 Claude Code Backups${NC}"
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
  echo "  Restore with: ./backup-claude.sh --restore <path>"
  echo ""
}

# ─── Usage ────────────────────────────────────────────────────────────────────

usage() {
  echo ""
  echo -e "${BOLD}backup-claude.sh${NC} — Backup & restore Claude Code configuration"
  echo ""
  echo "Usage:"
  echo "  ./backup-claude.sh              Create a zip backup (default)"
  echo "  ./backup-claude.sh --zip   -z   Create a zip backup in ~/backups/claude/"
  echo "  ./backup-claude.sh --gist  -g   Upload to a secret GitHub Gist"
  echo "  ./backup-claude.sh --both  -b   Create zip AND upload to Gist"
  echo "  ./backup-claude.sh --restore -r <zip>  Restore from a zip backup"
  echo "  ./backup-claude.sh --list  -l   List existing backups"
  echo "  ./backup-claude.sh --help  -h   Show this help"
  echo ""
  echo "Backed up:"
  echo "  CLAUDE.md, RTK.md, settings.json, keybindings.json,"
  echo "  agents/, skills/, rules/, hooks/, mcp-configs/"
  echo ""
  echo "NOT backed up (secrets, caches, transcripts):"
  echo "  .credentials.json, projects/, sessions/, history.jsonl, cache/,"
  echo "  telemetry/, plugins/, downloads/, paste-cache/, shell-snapshots/"
  echo ""
  echo "Environment:"
  echo "  CLAUDE_CONFIG_DIR   Override config dir  (default: ~/.claude)"
  echo "  BACKUP_DIR          Override backup dir  (default: ~/backups/claude)"
  echo ""
  echo "Examples:"
  echo "  ./backup-claude.sh --zip                              # Local backup"
  echo "  ./backup-claude.sh --gist                             # Sync via GitHub"
  echo "  ./backup-claude.sh --restore ~/backups/claude/claude-backup-20260713.zip"
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
        echo "  Usage: ./backup-claude.sh --restore <path-to-zip>"
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
