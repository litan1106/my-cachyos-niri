#!/bin/bash

# Put ~/.local/bin on PATH through the systemd user environment.
#
# CachyOS/Arch do NOT add ~/.local/bin to PATH by default (only /etc/profile
# adds /usr/local/bin), so user-installed launchers like `launch-battlenet`
# don't resolve by name until you do this.
#
# Primary mechanism: ~/.config/environment.d/, read by the systemd user manager
# at login. Processes that inherit that environment receive the updated PATH.
#
# The only case it does NOT cover is a bare TTY login or SSH session; pass
# --with-bashrc to also add the fallback export to ~/.bashrc for those.
#
# Idempotent: safe to re-run, and to run on a second machine.
#
# Sourced by install-gaming-battlenet.sh as `setup_local_bin_path`, and
# runnable standalone: ./setup-local-bin-path.sh [--with-bashrc]

# setup_local_bin_path [--with-bashrc]
setup_local_bin_path() {
  local with_bashrc=0
  [[ "${1:-}" == "--with-bashrc" ]] && with_bashrc=1

  mkdir -p "$HOME/.local/bin"

  # Warn if this session can't actually honor environment.d (no generator = not
  # a systemd-managed session). The file is still written, but won't take effect
  # until a systemd user session reads it.
  local gen="/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator"
  if [[ ! -x $gen ]]; then
    echo "Warning: systemd environment.d generator not found at:"
    echo "  $gen"
    echo "environment.d may not be honored on this system. Consider --with-bashrc."
    echo
  fi

  # Primary: declarative environment.d drop-in. Overwriting is idempotent — the
  # file IS the desired state. environment.d expands ${HOME}/${PATH} (not ~ or %h).
  local conf_dir="$HOME/.config/environment.d"
  local conf="$conf_dir/10-local-bin.conf"
  mkdir -p "$conf_dir"
  cat >"$conf" <<'EOF'
# Added by setup-local-bin-path.sh — put ~/.local/bin ahead of system PATH.
PATH=${HOME}/.local/bin:${PATH}
EOF
  echo "Wrote $conf"

  # Optional fallback for TTY/SSH shells, which don't inherit the graphical env.
  if (( with_bashrc )); then
    local marker="# setup-local-bin-path.sh: ~/.local/bin on PATH"
    if grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
      echo "~/.bashrc already has the PATH line — skipping."
    else
      {
        echo ""
        echo "$marker"
        echo 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
      } >>"$HOME/.bashrc"
      echo "Appended PATH fallback to ~/.bashrc"
    fi
  fi

  cat <<EOF

~/.local/bin will be on PATH for processes inheriting the systemd user environment
after re-login. To use it in the CURRENT terminal:

  export PATH="\$HOME/.local/bin:\$PATH"

EOF
}

# Run directly when executed rather than sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -e
  for arg in "$@"; do
    case "$arg" in
      --with-bashrc) ;;
      -h|--help)
        cat <<'EOF'
Usage: setup-local-bin-path.sh [--with-bashrc]

Adds ~/.local/bin to PATH through the systemd user environment via
~/.config/environment.d/.

Options:
  --with-bashrc   Also append a PATH export to ~/.bashrc as a fallback for
                  bare TTY / SSH sessions, which don't inherit the graphical
                  session environment. Guarded so re-runs don't duplicate it.
EOF
        exit 0
        ;;
      *)
        echo "Unknown argument: $arg" >&2
        echo "Try: setup-local-bin-path.sh --help" >&2
        exit 1
        ;;
    esac
  done
  setup_local_bin_path "$@"
fi
