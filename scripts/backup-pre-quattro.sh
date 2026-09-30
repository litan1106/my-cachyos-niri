#!/usr/bin/env bash
# ============================================================================
# backup-pre-quattro.sh — Backup before the one-way Omarchy 4 (quattro) upgrade
# ============================================================================
#
# OVERVIEW
#   Backup before the one-way Omarchy 4 upgrade. Saves the package lists and
#   copies of ~/Work and ~/Downloads, plus a repo-aware backup of ~/Projects,
#   so you can restore them on the new system. Run it as your normal user; it never needs sudo.
#
# USAGE
#   ./backup-pre-quattro.sh                    # Full backup (default)
#   ./backup-pre-quattro.sh --backup | -b      # Same as above
#   ./backup-pre-quattro.sh --dest   | -d <dir># Copy the run dir to <dir>
#                                              #   (after a backup, or alone
#                                              #   for the latest run)
#   ./backup-pre-quattro.sh --list   | -l      # List runs and sizes
#   ./backup-pre-quattro.sh --help   | -h      # Show help
#
# WHAT GETS BACKED UP
#   pkgs-pacman.txt     Explicitly installed official-repo packages (pacman -Qqen)
#   pkgs-aur.txt        Explicitly installed AUR/foreign packages (pacman -Qqem)
#   dotfiles/           Shell, git and tool dotfiles, plus ~/.ssh and ~/.gnupg
#                       (see DOTFILES)
#   Work/               ~/Work copy that honors every .gitignore, except a
#                       keep-list of ignored-but-irreplaceable files (*.tfvars,
#                       *.tfstate, .env files, notebooks, pipelines, notes)
#   Downloads/          ~/Downloads copy, same filters (*.iso files skipped)
#   Projects/           ~/Projects, repo-aware: repos.txt (name, url, branch,
#                       commit) plus per-repo local work (unpushed commits as
#                       local.bundle, stash-N.patch + stashes.txt, working.patch,
#                       untracked.tgz). Non-git dirs and repos without an
#                       origin get a full filtered copy
#   claude/             ~/.claude config zip, made by backup-claude.sh --zip
#   codex/              ~/.codex config zip, made by backup-codex.sh --zip
#   README.txt          Manifest plus the restore steps
#
# WHAT IS NOT BACKED UP
#   Omarchy configs (hypr, waybar, walker, ...) and the macOS VM script.
#   In Work/ and Downloads/ (and Projects/ entries that are copied in full),
#   gitignored files are skipped unless on the keep-list, and regenerable dirs
#   (node_modules, .venv, .terraform, caches) and *.iso images are always
#   skipped. Cloned Projects repos are restored by git clone, not copied.
#
# SAFETY
#   - Refuses to run as root (it needs $HOME)
#   - Run dir is created with umask 077
#   - Work/ holds tfvars, .env files and keys: use an encrypted drive for --dest
#
# REQUIREMENTS
#   rsync   Required for the copy step; --dest uses it when present (falls
#           back to cp -a)
#   git     Required for the Projects repo backup
#   yay     Only for restoring the AUR list
#   zip     For the ~/.claude and ~/.codex steps (via backup-claude.sh and
#           backup-codex.sh, next to this script)
#
# ENVIRONMENT VARIABLES
#   BACKUP_DIR          Override backup path (default: ~/backups/pre-quattro)
#   COPY_DIRS           Space-separated dirs to copy
#                       (default: "~/Work ~/Downloads")
#   REPO_DIRS           Space-separated dirs of repos to back up repo-aware
#                       (default: "~/Projects")
#
# ============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-${HOME}/backups/pre-quattro}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d_%H%M%S)}"
RUN_DIR="${RUN_DIR:-${BACKUP_DIR}/${TIMESTAMP}}"
if [[ -n ${COPY_DIRS:-} ]]; then
  read -ra COPY_DIRS <<< "${COPY_DIRS}"
else
  COPY_DIRS=("${HOME}/Work" "${HOME}/Downloads")
fi
if [[ -n ${REPO_DIRS:-} ]]; then
  read -ra REPO_DIRS <<< "${REPO_DIRS}"
else
  REPO_DIRS=("${HOME}/Projects")
fi

OMARCHY_VERSION_FILE="${HOME}/.local/share/omarchy/version"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Relative to ~. .databrickscfg, .ssh and .gnupg hold tokens and private keys.
DOTFILES=(
  .bash_profile
  .profile
  .zshrc
  .myshrc
  .gitconfig
  .gitignore_global
  .gitattributes_global
  .editorconfig
  .databrickscfg
  .ssh      # needed to re-clone Projects over SSH
  .gnupg
)
CLAUDE_BACKUP_SCRIPT="${SCRIPT_DIR}/backup-claude.sh"
CODEX_BACKUP_SCRIPT="${SCRIPT_DIR}/backup-codex.sh"

# ─── Copy Filters ────────────────────────────────────────────────────────────
# Secrets, local tf state and untracked work that gitignore hides but that
# can't be regenerated. rsync include patterns; they win over .gitignore.
COPY_KEEP=(
  '*.tfvars' '*.tfstate' '*.tfstate.backup'
  '.env' '*.env' '*.settings.env' '*.settings.json' '*-key.json'
  'databricks_notebooks/***' 'pipelines/***'
  '*ession*.md' '*ecommend*.md'
)

# Always excluded, for repos without a .gitignore.
# *.iso images can be downloaded again.
COPY_SKIP=(
  'node_modules/' '.venv/' '__pycache__/' '.terraform/'
  '.mypy_cache/' '.ruff_cache/' '.pytest_cache/'
  '*.iso'
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

latest_run() {
  find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*_*' 2>/dev/null | sort | tail -1
}

# ─── Preflight ────────────────────────────────────────────────────────────────

preflight() {
  if (( EUID == 0 )); then
    error "Do not run as root (it uses \$HOME). Run as your normal user."
    exit 1
  fi

  echo ""
  echo -e "${BOLD}Pre-quattro backup${NC}"
  echo "─────────────────────────────────────"
  echo "  Run dir:        ${RUN_DIR}"
  echo "  Package lists:  pkgs-pacman.txt, pkgs-aur.txt"
  echo "  Dotfiles:       dotfiles/ (${#DOTFILES[@]} files from ~)"
  echo "  Copy dirs:      ${COPY_DIRS[*]}"
  echo "                  (gitignore honored, keep-list wins, *.iso skipped)"
  echo "  Repo dirs:      ${REPO_DIRS[*]}"
  echo "                  (repos.txt + unpushed commits, stashes, dirty and untracked files)"
  echo "  Claude config:  claude/ (backup-claude.sh --zip)"
  echo "  Codex config:   codex/ (backup-codex.sh --zip)"
  echo "─────────────────────────────────────"
  echo ""
}

# ─── Backup Steps ─────────────────────────────────────────────────────────────

do_lists() {
  info "Saving package lists..."
  pacman -Qqen > "${RUN_DIR}/pkgs-pacman.txt"
  pacman -Qqem > "${RUN_DIR}/pkgs-aur.txt" || true  # exits 1 when none
  success "Lists saved."
}

do_dotfiles() {
  info "Copying dotfiles..."
  local f n=0
  mkdir -p "${RUN_DIR}/dotfiles"
  for f in "${DOTFILES[@]}"; do
    if [[ -e ${HOME}/${f} ]]; then
      cp -a "${HOME}/${f}" "${RUN_DIR}/dotfiles/"
      n=$((n + 1))
    else
      warn "Missing, skipped: ~/${f}"
    fi
  done
  success "Dotfiles copied (${n}/${#DOTFILES[@]})."
}

# One rsync --filter per line.
# rsync applies the first matching rule: skips go first so they also apply
# inside kept dirs, and keeps must beat the .gitignore dir-merge.
copy_filters() {
  local p
  for p in "${COPY_SKIP[@]}"; do
    echo "--filter=- ${p}"
  done
  for p in "${COPY_KEEP[@]}"; do
    echo "--filter=+ ${p}"
  done
  echo "--filter=:- .gitignore"
}

# Local-only work of a repo into $2; echoes a status line.
repo_work() {
  local repo="$1" w="$2" parts=() n i

  if [[ -n $(git -C "${repo}" log --branches --not --remotes --oneline) ]]; then
    mkdir -p "${w}"
    git -C "${repo}" bundle create -q "${w}/local.bundle" --branches --not --remotes 2>/dev/null
    parts+=("bundle")
  fi

  n=$(git -C "${repo}" stash list | wc -l)
  for (( i = 0; i < n; i++ )); do
    mkdir -p "${w}"
    git -C "${repo}" stash show -p --include-untracked --binary "stash@{${i}}" > "${w}/stash-${i}.patch"
    # A stash patch only applies cleanly on the commit it was taken from.
    printf 'stash-%s.patch\t%s\t%s\n' "${i}" \
      "$(git -C "${repo}" rev-parse "stash@{${i}}^1")" \
      "$(git -C "${repo}" log -g -1 --format=%gs "stash@{${i}}")" >> "${w}/stashes.txt"
  done
  if (( n > 0 )); then
    parts+=("${n} stash$( (( n > 1 )) && echo es )")
  fi

  mkdir -p "${w}"
  git -C "${repo}" -c core.safecrlf=false diff HEAD --binary > "${w}/working.patch" || true
  if [[ -s ${w}/working.patch ]]; then
    parts+=("working")
  else
    rm -f "${w}/working.patch"
  fi

  if [[ -n $(git -C "${repo}" ls-files -o --exclude-standard | head -1) ]]; then
    mkdir -p "${w}"
    (cd "${repo}" && git ls-files -z -o --exclude-standard | tar --null -T - -czf "${w}/untracked.tgz")
    parts+=("untracked")
  fi

  rmdir "${w}" 2>/dev/null || true
  if (( ${#parts[@]} == 0 )); then
    echo "clean (clone only)"
  else
    printf '%s' "${parts[0]}"
    if (( ${#parts[@]} > 1 )); then
      printf ', %s' "${parts[@]:1}"
    fi
    echo
  fi
}

do_copy() {
  if ! command -v rsync >/dev/null 2>&1; then
    error "rsync is required for the copy step."
    exit 1
  fi

  local filters dir name
  mapfile -t filters < <(copy_filters)

  for dir in "${COPY_DIRS[@]}"; do
    if [[ ! -d ${dir} ]]; then
      warn "Dir not found, skipped: ${dir}"
      continue
    fi

    name=$(basename "${dir}")
    info "Copying ${dir}..."
    rsync -a --delete-excluded "${filters[@]}" "${dir}/" "${RUN_DIR}/${name}/"
    success "${name} copied ($(du -sh "${RUN_DIR}/${name}" | cut -f1))."
  done
}

# Repos: clone info + local work. Anything else: full filtered copy.
do_repos() {
  local filters dir out e name url branch commit
  mapfile -t filters < <(copy_filters)

  for dir in "${REPO_DIRS[@]}"; do
    if [[ ! -d ${dir} ]]; then
      warn "Dir not found, skipped: ${dir}"
      continue
    fi

    out="${RUN_DIR}/$(basename "${dir}")"
    mkdir -p "${out}"
    : > "${out}/repos.txt"
    info "Backing up repos in ${dir}..."

    while IFS= read -r -d '' e; do
      name=$(basename "${e}")
      url=""
      if [[ -e ${e}/.git ]]; then
        url=$(git -C "${e}" remote get-url origin 2>/dev/null || true)
      fi

      if [[ -n ${url} ]]; then
        branch=$(git -C "${e}" symbolic-ref --short -q HEAD || true)
        commit=$(git -C "${e}" rev-parse HEAD 2>/dev/null || true)
        printf '%s\t%s\t%s\t%s\n' "${name}" "${url}" "${branch}" "${commit}" >> "${out}/repos.txt"
        info "${name}: $(repo_work "${e}" "${out}/${name}")"
      elif [[ -d ${e} ]]; then
        rsync -a --delete-excluded "${filters[@]}" "${e}/" "${out}/${name}/"
        info "${name}: copied in full (no origin)"
      else
        rsync -a "${e}" "${out}/${name}"
        info "${name}: file copied"
      fi
    done < <(find "${dir}" -mindepth 1 -maxdepth 1 -print0 | sort -z)

    success "$(basename "${dir}") backed up ($(du -sh "${out}" | cut -f1))."
  done
}

write_manifest() {
  local omarchy_version="n/a" dir name out repos work n
  if [[ -f ${OMARCHY_VERSION_FILE} ]]; then
    omarchy_version=$(cat "${OMARCHY_VERSION_FILE}")
  fi

  {
    echo "Pre-quattro backup"
    echo "Date:            $(date)"
    echo "Host:            $(hostname)"
    echo "Kernel:          $(uname -r)"
    echo "Omarchy version: ${omarchy_version}"
    echo "Pacman packages: $(wc -l < "${RUN_DIR}/pkgs-pacman.txt")"
    echo "AUR packages:    $(wc -l < "${RUN_DIR}/pkgs-aur.txt")"
    echo "Dotfiles:        $(ls -A "${RUN_DIR}/dotfiles" | wc -l) (restore: cp -a dotfiles/. ~/)"
    for dir in "${COPY_DIRS[@]}"; do
      name=$(basename "${dir}")
      if [[ -d ${RUN_DIR}/${name} ]]; then
        printf '%-16s %s\n' "${name} size:" "$(du -sh "${RUN_DIR}/${name}" | cut -f1)"
      fi
    done
    for dir in "${REPO_DIRS[@]}"; do
      name=$(basename "${dir}")
      out="${RUN_DIR}/${name}"
      if [[ -f ${out}/repos.txt ]]; then
        repos=$(wc -l < "${out}/repos.txt")
        work=0
        while IFS=$'\t' read -r n _; do
          if [[ -d ${out}/${n} ]]; then
            work=$((work + 1))
          fi
        done < "${out}/repos.txt"
        printf '%-16s %s\n' "${name}:" "${repos} repos, ${work} with local work, $(du -sh "${out}" | cut -f1)"
      fi
    done
    echo "Skipped:         *.iso files"
    echo ""
    echo "RESTORE ON THE NEW SYSTEM"
    echo ""
    echo "From the run directory:"
    echo "  sudo pacman -S --needed - < pkgs-pacman.txt"
    echo "  yay -S --needed - < pkgs-aur.txt"
    for dir in "${COPY_DIRS[@]}"; do
      name=$(basename "${dir}")
      if [[ -d ${RUN_DIR}/${name} ]]; then
        echo "  rsync -a ${name}/ ~/${name}/"
      fi
    done
    for dir in "${REPO_DIRS[@]}"; do
      name=$(basename "${dir}")
      if [[ -f ${RUN_DIR}/${name}/repos.txt ]]; then
        echo ""
        echo "${name} (repos listed in ${name}/repos.txt: name, url, branch, commit):"
        echo "  1. git clone <url> <name>, then git checkout <branch or commit>"
        echo "     (for each line of repos.txt)"
        echo "  2. If <name>/local.bundle exists, inside the repo:"
        echo "       git fetch <path>/local.bundle 'refs/heads/*:refs/remotes/local/*'"
        echo "  3. git apply --binary working.patch"
        echo "  4. tar -xzf untracked.tgz"
        echo "  5. For each stash-N.patch, as needed: git checkout <base> (from"
        echo "     stashes.txt: patch, base commit, message), git apply --binary"
        echo "     stash-N.patch, then git stash to park it again"
        echo "  (Non-git dirs and repos without an origin are plain copies:"
        echo "   rsync -a ${name}/<name>/ ~/${name}/<name>/)"
      fi
    done
    if compgen -G "${RUN_DIR}/claude/claude-backup-*.zip" >/dev/null; then
      echo ""
      echo "Claude config:   $(basename "${RUN_DIR}"/claude/claude-backup-*.zip)"
      echo "  backup-claude.sh --restore claude/claude-backup-*.zip"
    fi
    if compgen -G "${RUN_DIR}/codex/codex-backup-*.zip" >/dev/null; then
      echo ""
      echo "Codex config:    $(basename "${RUN_DIR}"/codex/codex-backup-*.zip)"
      echo "  backup-codex.sh --restore codex/codex-backup-*.zip"
    fi
  } > "${RUN_DIR}/README.txt"
  success "Manifest written."
}

# Delegates to backup-<name>.sh so its include/exclude list stays the single source.
run_config_backup() {
  local name="$1" script="$2"
  if [[ ! -f ${script} ]]; then
    warn "$(basename "${script}") not found, skipped: ${script}"
    return
  fi
  info "Backing up ~/.${name}..."
  # zip lists every file it adds; keep only the summary lines.
  BACKUP_DIR="${RUN_DIR}/${name}" bash "${script}" --zip | grep -v '^  adding:'
}

# ─── Backup ───────────────────────────────────────────────────────────────────

do_backup() {
  preflight

  umask 077
  mkdir -p "${RUN_DIR}"

  do_lists
  do_dotfiles
  do_copy
  do_repos
  run_config_backup claude "${CLAUDE_BACKUP_SCRIPT}"
  run_config_backup codex "${CODEX_BACKUP_SCRIPT}"
  write_manifest

  echo ""
  success "Backup complete: ${RUN_DIR}"
  echo ""
  echo -e "${BOLD}Next steps${NC}"
  echo "  1. Copy to an external drive:  $0 --dest <dir>"
  echo "     Use an encrypted drive: Work/ contains tfvars, .env files and keys."
  echo "  2. Write down your Wi-Fi passwords."
  echo "  3. Upgrade:                    omarchy upgrade to quattro"
  echo "  4. After upgrading, re-pick Ghostty as the terminal, rejoin Wi-Fi in"
  echo "     NetworkManager, and reinstall packages from the lists as needed."
  echo ""
}

# ─── Copy to External Dir ─────────────────────────────────────────────────────

do_dest() {
  local dest="$1" src="${RUN_DIR}"

  if [[ ! -d ${dest} ]]; then
    error "Destination directory not found: ${dest}"
    exit 1
  fi

  # Standalone --dest uses the newest existing run.
  if [[ ! -d ${src} ]]; then
    src=$(latest_run)
    if [[ -z ${src} ]]; then
      error "No runs found in ${BACKUP_DIR}"
      exit 1
    fi
  fi

  info "Copying ${src} → ${dest}/"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "${src}" "${dest}/"
  else
    cp -a "${src}" "${dest}/"
  fi
  success "Copied to ${dest}/$(basename "${src}")"
}

# ─── List ─────────────────────────────────────────────────────────────────────

do_list() {
  echo ""
  echo -e "${BOLD}Runs in ${BACKUP_DIR}${NC}"
  echo "─────────────────────────────────────"
  local runs
  runs=$(find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*_*' 2>/dev/null | sort -r || true)
  if [[ -z ${runs} ]]; then
    echo "  (none)"
  else
    local path
    while IFS= read -r path; do
      echo "  $(basename "${path}")  ($(du -sh "${path}" | cut -f1))"
    done <<< "${runs}"
  fi
  echo ""
}

# ─── Usage ────────────────────────────────────────────────────────────────────

usage() {
  echo ""
  echo -e "${BOLD}backup-pre-quattro.sh${NC} — Backup before the one-way Omarchy 4 upgrade"
  echo ""
  echo "Usage:"
  echo "  ./backup-pre-quattro.sh                 Full backup (default)"
  echo "  ./backup-pre-quattro.sh --backup -b     Full backup"
  echo "  ./backup-pre-quattro.sh --dest -d <dir> Copy run dir to <dir> (after a"
  echo "                                          backup, or alone for the latest run)"
  echo "  ./backup-pre-quattro.sh --list -l       List runs and sizes"
  echo "  ./backup-pre-quattro.sh --help -h       Show this help"
  echo ""
  echo "Backed up:"
  echo "  Package lists (pacman and AUR), dotfiles (shell, git, databricks),"
  echo "  ~/Work and ~/Downloads (gitignore honored,"
  echo "  secrets/tf state/notebooks kept, *.iso skipped), and ~/Projects repo-aware"
  echo "  (repos.txt + unpushed commits, stashes, dirty and untracked files),"
  echo "  and ~/.claude and ~/.codex via backup-claude.sh / backup-codex.sh --zip."
  echo "  No sudo needed."
  echo ""
  echo "Environment:"
  echo "  BACKUP_DIR          Backup dir       (default: ~/backups/pre-quattro)"
  echo "  COPY_DIRS           Dirs to copy     (default: \"~/Work ~/Downloads\")"
  echo "  REPO_DIRS           Repo dirs        (default: \"~/Projects\")"
  echo ""
  echo "Examples:"
  echo "  ./backup-pre-quattro.sh -b -d /run/media/\$USER/usb # backup, then copy"
  echo "  ./backup-pre-quattro.sh -d /run/media/\$USER/usb   # copy latest run"
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  local mode="" dest=""

  while (( $# > 0 )); do
    case "$1" in
      --backup|-b)
        mode="backup"
        ;;
      --dest|-d)
        if [[ -z ${2:-} ]]; then
          error "Please provide a destination directory."
          echo "  Usage: ./backup-pre-quattro.sh --dest <dir>"
          exit 1
        fi
        dest="$2"
        shift
        ;;
      --list|-l)
        mode="list"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done

  # Bare --dest copies the latest run; anything else defaults to a backup.
  if [[ -z ${mode} && -z ${dest} ]]; then
    mode="backup"
  fi

  if [[ -n ${dest} && ! -d ${dest} ]]; then
    error "Destination directory not found: ${dest}"
    exit 1
  fi

  case "${mode}" in
    backup)
      do_backup
      if [[ -n ${dest} ]]; then
        do_dest "${dest}"
      fi
      ;;
    list)
      do_list
      ;;
    *)
      do_dest "${dest}"
      ;;
  esac
}

main "$@"
