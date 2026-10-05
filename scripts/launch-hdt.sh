#!/bin/bash

# Launch Hearthstone Deck Tracker via umu-launcher + GE-Proton, in the same
# prefix as Battle.net/Hearthstone so it can see the running game.
# Usage: launch-hdt [--with-mangohud]

set -e

PREFIX="$HOME/Games/battlenet"
HDT_EXE="$PREFIX/drive_c/Hearthstone Deck Tracker/Hearthstone Deck Tracker.exe"

with_mangohud=0
for arg in "$@"; do
  case "$arg" in
    --with-mangohud) with_mangohud=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: launch-hdt [--with-mangohud]

Launches Hearthstone Deck Tracker in the Battle.net Proton prefix. Start
Hearthstone (via launch-battlenet) first so HDT can attach to it.

Options:
  --with-mangohud   Enable the MangoHud FPS overlay for HDT's window.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Try: launch-hdt --help" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f $HDT_EXE ]]; then
  echo "Hearthstone Deck Tracker is not installed. Run install-gaming-hdt.sh first." >&2
  exit 1
fi

env_args=(
  WINEPREFIX="$PREFIX"
  PROTONPATH=GE-Proton
  GAMEID=umu-battlenet
  PROTON_VERB=run
)
(( with_mangohud )) && env_args+=(MANGOHUD=1)

env "${env_args[@]}" umu-run "$HDT_EXE"
