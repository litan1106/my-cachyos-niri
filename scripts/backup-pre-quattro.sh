#!/usr/bin/env bash
# ============================================================================
# backup-pre-quattro.sh — Reversible backup before Omarchy 3.8.5 → 4 (quattro)
# ============================================================================
#
# OVERVIEW
#   Takes a snapper snapshot of the root subvolume, a read-only btrfs snapshot
#   of @home, and a small archive of system files plus package/service lists,
#   so the Omarchy 4 upgrade can be rolled back. Run it as your normal user;
#   it calls sudo itself.
#
# USAGE
#   ./backup-pre-quattro.sh                    # Full backup (default)
#   ./backup-pre-quattro.sh --backup | -b      # Same as above
#   ./backup-pre-quattro.sh --dest   | -d <dir># Copy the run dir to <dir>
#                                              #   (after a backup, or alone
#                                              #   for the latest run)
#   ./backup-pre-quattro.sh --list   | -l      # List runs and snapshots
#   ./backup-pre-quattro.sh --rollback-help | -R  # Print rollback steps
#   ./backup-pre-quattro.sh --yes    | -y      # Skip the confirmation
#   ./backup-pre-quattro.sh --help   | -h      # Show help
#
# WHAT GETS BACKED UP
#   pkgs-explicit.txt   Explicitly installed packages (pacman -Qqe)
#   pkgs-foreign.txt    AUR/foreign packages (pacman -Qqm)
#   units-system.txt    Enabled system unit files
#   units-user.txt      Enabled user unit files
#   sys.tgz             pacman.conf, pacman.d, default/limine, sudoers.d,
#                       systemd/system, iwd (Wi-Fi keys!), limine.conf,
#                       fstab, mkinitcpio.conf
#   snapper snapshot    Root subvolume, description "pre-quattro manual"
#   @home-pre-quattro   Read-only btrfs snapshot of @home (top-level subvol)
#   README.txt          Manifest plus the full rollback steps
#
# WHAT IS NOT BACKED UP
#   Omarchy configs (hypr, waybar, walker, ...) and the macOS VM script are
#   not copied separately; the @home snapshot already covers them.
#
# ROLLBACK
#   System: pick the snapshot in Limine > Snapshots, run
#           limine-snapper-restore, reboot (or: snapper rollback <N>).
#   Home:   from a TTY, swap @home for a writable copy of @home-pre-quattro.
#   Run --rollback-help for the exact commands with your device filled in.
#
# SAFETY
#   - Refuses to run as root (it needs $HOME) and needs a btrfs root
#   - Asks for [y/N] confirmation unless --yes is given
#   - Existing snapshots are never overwritten; they are skipped with a warning
#   - The manual snapper snapshot has no cleanup algorithm, so it is never
#     auto-pruned
#   - Run dir is created with umask 077; sys.tgz is chmod 600 (Wi-Fi keys)
#
# REQUIREMENTS
#   sudo, snapper (with a "root" config), btrfs-progs, tar, findmnt
#   rsync   Optional, used by --dest when present (falls back to cp -a)
#
# ENVIRONMENT VARIABLES
#   BACKUP_DIR          Override backup path (default: ~/backups/pre-quattro)
#   SNAPPER_DESC        Snapper description (default: "pre-quattro manual")
#   HOME_SNAPSHOT_NAME  Home snapshot name (default: @home-pre-quattro)
#
# ============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-${HOME}/backups/pre-quattro}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d_%H%M%S)}"
RUN_DIR="${RUN_DIR:-${BACKUP_DIR}/${TIMESTAMP}}"
SNAPPER_DESC="${SNAPPER_DESC:-pre-quattro manual}"
HOME_SNAPSHOT_NAME="${HOME_SNAPSHOT_NAME:-@home-pre-quattro}"

SNAPPER_CONFIG="/etc/snapper/configs/root"
OMARCHY_VERSION_FILE="${HOME}/.local/share/omarchy/version"

# Filled in by preflight / snapshot steps
HOME_DEV=""
SNAP_NUM="unknown"
ASSUME_YES=0
MNT=""

# ─── Backup Targets ──────────────────────────────────────────────────────────
# Checked with sudo: /var/lib/iwd is not readable by the user.
SYS_TARGETS=(
  /etc/pacman.conf
  /etc/pacman.d
  /etc/default/limine
  /etc/sudoers.d
  /etc/systemd/system
  /var/lib/iwd
  /boot/limine.conf
  /etc/fstab
  /etc/mkinitcpio.conf
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

# Prints the device behind /home, or nothing if it can't be parsed.
detect_home_dev() {
  local src
  src=$(findmnt -no SOURCE /home 2>/dev/null || true)
  if [[ ${src} =~ ^(.+)\[/@home\]$ ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# Same text goes to --rollback-help and README.txt.
rollback_text() {
  local dev="${1:-<btrfs-device>}"
  cat <<TXT
ROLLBACK

1. System
   Reboot, open Limine > Snapshots, pick "${SNAPPER_DESC}", then:
     sudo limine-snapper-restore
   and reboot. Alternatively:
     sudo snapper -c root rollback <N>
   and reboot.

2. Home
   From a TTY with no graphical session logged in, run:
     sudo mount -o subvolid=5 ${dev} /mnt && sudo mv /mnt/@home /mnt/@home-quattro && sudo btrfs subvolume snapshot /mnt/${HOME_SNAPSHOT_NAME} /mnt/@home && sudo umount /mnt && reboot
   This makes a writable snapshot of the read-only one. Changes made to
   home after the snapshot are lost, but can be recovered from @home-quattro.

3. Timing
   Decide soon. The Limine menu shows only the 5 newest snapshots, but the
   manual snapshot is never auto-pruned.

4. Restoring system files
   From the run directory:
     sudo tar -xzf sys.tgz -C /
TXT
}

# Unmount and remove the temp top-level mount. Safe to call twice.
cleanup_mnt() {
  if [[ -n ${MNT} && -d ${MNT} ]]; then
    if mountpoint -q "${MNT}"; then
      sudo umount "${MNT}" || warn "Could not unmount ${MNT}"
    fi
    rmdir "${MNT}" 2>/dev/null || true
  fi
  MNT=""
}

latest_run() {
  find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*_*' 2>/dev/null | sort | tail -1
}

# ─── Preflight ────────────────────────────────────────────────────────────────

preflight() {
  if (( EUID == 0 )); then
    error "Do not run as root (it uses \$HOME). Run as your user; it calls sudo itself."
    exit 1
  fi

  if [[ $(findmnt -no FSTYPE / 2>/dev/null) != "btrfs" ]]; then
    error "/ is not btrfs."
    exit 1
  fi

  if [[ ! -e ${SNAPPER_CONFIG} ]]; then
    error "Snapper root config not found: ${SNAPPER_CONFIG}"
    exit 1
  fi

  HOME_DEV=$(detect_home_dev)
  if [[ -z ${HOME_DEV} ]]; then
    error "Could not parse /home source (expected DEVICE[/@home]): $(findmnt -no SOURCE /home 2>/dev/null || echo 'none')"
    exit 1
  fi

  info "Requesting sudo..."
  if ! sudo -v; then
    error "sudo authentication failed."
    exit 1
  fi

  echo ""
  echo -e "${BOLD}Pre-quattro backup${NC}"
  echo "─────────────────────────────────────"
  echo "  Run dir:        ${RUN_DIR}"
  echo "  Package lists:  pkgs-*.txt, units-*.txt"
  echo "  System files:   sys.tgz (contains Wi-Fi keys)"
  echo "  Root snapshot:  snapper root, \"${SNAPPER_DESC}\""
  echo "  Home snapshot:  ${HOME_SNAPSHOT_NAME} (read-only, on ${HOME_DEV})"
  echo "─────────────────────────────────────"
  echo ""

  if (( ! ASSUME_YES )); then
    local confirm
    read -rp "Continue? [y/N] " confirm
    if [[ ${confirm} != "y" && ${confirm} != "Y" ]]; then
      info "Cancelled."
      exit 0
    fi
  fi
}

# ─── Backup Steps ─────────────────────────────────────────────────────────────

do_lists() {
  info "Saving package and service lists..."
  pacman -Qqe > "${RUN_DIR}/pkgs-explicit.txt"
  pacman -Qqm > "${RUN_DIR}/pkgs-foreign.txt" || true  # exits 1 when none
  systemctl list-unit-files --state=enabled > "${RUN_DIR}/units-system.txt"
  systemctl --user list-unit-files --state=enabled > "${RUN_DIR}/units-user.txt"
  success "Lists saved."
}

do_sys_archive() {
  info "Archiving system files..."
  local targets=() t
  for t in "${SYS_TARGETS[@]}"; do
    if sudo test -e "${t}"; then
      targets+=("${t}")
    else
      warn "Missing, skipped: ${t}"
    fi
  done

  # Redirect as the user so the file isn't root-owned.
  sudo tar -czf - "${targets[@]}" > "${RUN_DIR}/sys.tgz"
  chmod 600 "${RUN_DIR}/sys.tgz"
  success "sys.tgz written (${#targets[@]} paths)."
}

do_root_snapshot() {
  info "Creating root snapshot..."
  local existing
  existing=$(sudo snapper -c root --csvout list --columns number,description \
    | awk -F, -v d="${SNAPPER_DESC}" '{ gsub(/"/, "", $2) } $2 == d { print $1; exit }')

  if [[ -n ${existing} ]]; then
    warn "Snapper snapshot \"${SNAPPER_DESC}\" already exists (#${existing}), skipping."
    SNAP_NUM="${existing}"
    return
  fi

  # No "-c cleanup": the snapshot must never be auto-pruned.
  SNAP_NUM=$(sudo snapper -c root create -d "${SNAPPER_DESC}" --print-number)
  success "Root snapshot #${SNAP_NUM} created."
}

do_home_snapshot() {
  info "Creating home snapshot..."
  MNT=$(mktemp -d)
  trap cleanup_mnt EXIT

  sudo mount -o subvolid=5 "${HOME_DEV}" "${MNT}"

  if [[ -e ${MNT}/${HOME_SNAPSHOT_NAME} ]]; then
    warn "${HOME_SNAPSHOT_NAME} already exists, skipping."
  else
    sudo btrfs subvolume snapshot -r "${MNT}/@home" "${MNT}/${HOME_SNAPSHOT_NAME}"
    success "Home snapshot ${HOME_SNAPSHOT_NAME} created."
  fi

  cleanup_mnt
  trap - EXIT
}

write_manifest() {
  local omarchy_version="n/a"
  if [[ -f ${OMARCHY_VERSION_FILE} ]]; then
    omarchy_version=$(cat "${OMARCHY_VERSION_FILE}")
  fi

  {
    echo "Pre-quattro backup"
    echo "Date:            $(date)"
    echo "Host:            $(hostname)"
    echo "Kernel:          $(uname -r)"
    echo "Omarchy version: ${omarchy_version}"
    echo "Snapper number:  ${SNAP_NUM} (\"${SNAPPER_DESC}\")"
    echo "Home snapshot:   ${HOME_SNAPSHOT_NAME}"
    echo ""
    rollback_text "${HOME_DEV}"
  } > "${RUN_DIR}/README.txt"
  success "Manifest written."
}

# ─── Backup ───────────────────────────────────────────────────────────────────

do_backup() {
  preflight

  umask 077
  mkdir -p "${RUN_DIR}"

  do_lists
  do_sys_archive
  do_root_snapshot
  do_home_snapshot
  write_manifest

  echo ""
  success "Backup complete: ${RUN_DIR}"
  echo ""
  echo -e "${BOLD}Next steps${NC}"
  echo "  1. Copy to an external drive:  $0 --dest <dir>"
  echo "  2. Write down your Wi-Fi passwords (sys.tgz is not a substitute)."
  echo "  3. Upgrade WITHOUT --reboot:   omarchy upgrade to quattro"
  echo "  4. After upgrading, re-pick Ghostty as the terminal and rejoin"
  echo "     Wi-Fi in NetworkManager."
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
  echo -e "${BOLD}Snapper snapshots matching \"${SNAPPER_DESC}\"${NC}"
  echo "─────────────────────────────────────"
  sudo snapper -c root list | grep -F -e "${SNAPPER_DESC}" -e "Description" || echo "  (none)"

  echo ""
  echo -e "${BOLD}Home snapshot${NC}"
  echo "─────────────────────────────────────"
  if sudo btrfs subvolume list / | grep -qE "path ${HOME_SNAPSHOT_NAME}\$"; then
    echo "  ${HOME_SNAPSHOT_NAME}: present"
  else
    echo "  ${HOME_SNAPSHOT_NAME}: not found"
  fi
  echo ""
}

# ─── Rollback Help ────────────────────────────────────────────────────────────

do_rollback_help() {
  local dev
  dev=$(detect_home_dev)
  if [[ -z ${dev} ]]; then
    warn "Could not detect the btrfs device from /home; using a placeholder."
  fi
  echo ""
  rollback_text "${dev:-<btrfs-device>}"
  echo ""
}

# ─── Usage ────────────────────────────────────────────────────────────────────

usage() {
  echo ""
  echo -e "${BOLD}backup-pre-quattro.sh${NC} — Reversible backup before the Omarchy 4 upgrade"
  echo ""
  echo "Usage:"
  echo "  ./backup-pre-quattro.sh                 Full backup (default)"
  echo "  ./backup-pre-quattro.sh --backup -b     Full backup"
  echo "  ./backup-pre-quattro.sh --dest -d <dir> Copy run dir to <dir> (after a"
  echo "                                          backup, or alone for the latest run)"
  echo "  ./backup-pre-quattro.sh --list -l       List runs and snapshots"
  echo "  ./backup-pre-quattro.sh --rollback-help -R  Print rollback steps"
  echo "  ./backup-pre-quattro.sh --yes -y        Skip the confirmation"
  echo "  ./backup-pre-quattro.sh --help -h       Show this help"
  echo ""
  echo "Backed up:"
  echo "  Package/service lists, system files (sys.tgz), a snapper root"
  echo "  snapshot, and a read-only @home snapshot."
  echo ""
  echo "Environment:"
  echo "  BACKUP_DIR          Backup dir       (default: ~/backups/pre-quattro)"
  echo "  SNAPPER_DESC        Snapper desc     (default: pre-quattro manual)"
  echo "  HOME_SNAPSHOT_NAME  Home snapshot    (default: @home-pre-quattro)"
  echo ""
  echo "Examples:"
  echo "  ./backup-pre-quattro.sh -y -d /run/media/\$USER/usb"
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
      --rollback-help|-R)
        mode="rollback"
        ;;
      --yes|-y)
        ASSUME_YES=1
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
    rollback)
      do_rollback_help
      ;;
    *)
      do_dest "${dest}"
      ;;
  esac
}

main "$@"
