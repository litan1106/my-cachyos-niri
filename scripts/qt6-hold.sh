#!/usr/bin/env bash
#
# qt6-hold.sh — pin / unpin qt6 at 6.11.2
#
# Why: qt6 6.12 shadows noctalia/quickshell's `Color` theme singleton with Qt's
# built-in color value-type, so accent colors resolve to `undefined` and the whole
# shell (bar, dock, launcher) renders grey. Until noctalia ships a 6.12-compatible
# release, we pin qt6 at 6.11.2.
#
# Usage:
#   ./qt6-hold.sh hold      # downgrade qt6 -> 6.11.2 and add to IgnorePkg, restart shell
#   ./qt6-hold.sh release   # remove from IgnorePkg and upgrade qt6 back to latest
#   ./qt6-hold.sh status    # show current qt6 versions and hold state
#
# `hold` looks for the 6.11.2 .pkg.tar.zst files first next to this script
# (the bundled qt6-611-fix/ dir), then in /var/cache/pacman/pkg. Copy the bundle
# next to this script if the target machine's cache no longer has them.
#
set -eu

PKG_NAMES=(qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg qt6-svg qt6-translations qt6-wayland)
PKG_FILES=(
  qt6-base-6.11.2-3-x86_64.pkg.tar.zst
  qt6-declarative-6.11.2-2.1-x86_64_v4.pkg.tar.zst
  qt6-multimedia-6.11.2-1.1-x86_64_v4.pkg.tar.zst
  qt6-multimedia-ffmpeg-6.11.2-1.1-x86_64_v4.pkg.tar.zst
  qt6-svg-6.11.2-1.1-x86_64_v4.pkg.tar.zst
  qt6-translations-6.11.2-1-any.pkg.tar.zst
  qt6-wayland-6.11.2-1.1-x86_64_v4.pkg.tar.zst
)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE=/var/cache/pacman/pkg
PACCONF=/etc/pacman.conf

restart_shell() {
  if pgrep -f 'qs -c noctalia-shell' >/dev/null 2>&1; then
    echo "Restarting noctalia shell..."
    pkill -f 'qs -c noctalia-shell' || true
    sleep 1
    setsid qs -c noctalia-shell >/dev/null 2>&1 < /dev/null & disown || true
  fi
}

# current value (tokens) of an active IgnorePkg line, empty if none
current_ignore() {
  grep -E '^[[:space:]]*IgnorePkg' "$PACCONF" 2>/dev/null \
    | sed -E 's|^[[:space:]]*IgnorePkg[[:space:]]*=[[:space:]]*||' || true
}

add_hold() {
  local cur merged
  cur="$(current_ignore)"
  # merge existing + ours, dedup, preserve order (existing first)
  merged="$(awk -v cur="$cur" -v add="${PKG_NAMES[*]}" 'BEGIN{
      n=split(cur,c," "); for(i=1;i<=n;i++) if(!(c[i] in s)){s[c[i]]=1; o[++k]=c[i]}
      m=split(add,a," "); for(i=1;i<=m;i++) if(!(a[i] in s)){s[a[i]]=1; o[++k]=a[i]}
      out=""; for(i=1;i<=k;i++) out=(out==""?o[i]:out" "o[i]); print out }')"
  if grep -qE '^[[:space:]]*IgnorePkg' "$PACCONF"; then
    sudo sed -i -E "s|^[[:space:]]*IgnorePkg[[:space:]]*=.*|IgnorePkg = ${merged}|" "$PACCONF"
  else
    sudo sed -i -E "s|^#[[:space:]]*IgnorePkg.*|IgnorePkg = ${merged}|" "$PACCONF"
  fi
}

remove_hold() {
  local cur kept
  cur="$(current_ignore)"
  [ -z "$cur" ] && return 0
  # keep only tokens that are NOT ours (exact match — safe for qt6-multimedia vs -ffmpeg)
  kept="$(awk -v cur="$cur" -v drop="${PKG_NAMES[*]}" 'BEGIN{
      m=split(drop,d," "); for(i=1;i<=m;i++) rm[d[i]]=1
      n=split(cur,c," "); out="";
      for(i=1;i<=n;i++) if(!(c[i] in rm)) out=(out==""?c[i]:out" "c[i]); print out }')"
  if [ -z "$kept" ]; then
    sudo sed -i -E 's|^[[:space:]]*IgnorePkg[[:space:]]*=.*|#IgnorePkg   =|' "$PACCONF"
  else
    sudo sed -i -E "s|^[[:space:]]*IgnorePkg[[:space:]]*=.*|IgnorePkg = ${kept}|" "$PACCONF"
  fi
}

case "${1:-}" in
  hold)
    files=(); missing=()
    for f in "${PKG_FILES[@]}"; do
      if   [ -f "$SCRIPT_DIR/qt6-611-fix/$f" ]; then files+=("$SCRIPT_DIR/qt6-611-fix/$f")
      elif [ -f "$SCRIPT_DIR/$f" ];            then files+=("$SCRIPT_DIR/$f")
      elif [ -f "$CACHE/$f" ];                 then files+=("$CACHE/$f")
      else missing+=("$f"); fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
      echo "ERROR: these 6.11.2 packages were not found next to the script or in $CACHE:" >&2
      printf '  %s\n' "${missing[@]}" >&2
      echo "Copy the qt6-611-fix/ bundle next to this script and retry." >&2
      exit 1
    fi
    echo "Downgrading qt6 -> 6.11.2 ..."
    sudo pacman -U "${files[@]}"
    add_hold
    echo "Held: $(grep -E '^[[:space:]]*IgnorePkg' "$PACCONF")"
    restart_shell
    echo "Done. qt6 is pinned at 6.11.2."
    ;;
  release)
    echo "WARNING: this un-pins qt6 and upgrades it (likely to 6.12+)."
    echo "Only run this once noctalia supports Qt 6.12, or the grey-shell bug returns."
    read -r -p "Continue? [y/N] " a; [ "${a:-N}" = y ] || [ "${a:-N}" = Y ] || { echo "Aborted."; exit 0; }
    remove_hold
    echo "Un-held: $(grep -E '^[[:space:]]*IgnorePkg' "$PACCONF" || echo '(IgnorePkg now commented out)')"
    echo "Upgrading system (qt6 will move to the repo version) ..."
    sudo pacman -Syu
    restart_shell
    echo "Done. qt6 released to the repo version."
    ;;
  status)
    echo "== qt6 versions =="
    pacman -Q "${PKG_NAMES[@]}"
    echo "== hold state =="
    grep -E '^[[:space:]]*IgnorePkg' "$PACCONF" 2>/dev/null || echo "(no active IgnorePkg line)"
    ;;
  *)
    echo "Usage: $0 {hold|release|status}"; exit 2 ;;
esac
