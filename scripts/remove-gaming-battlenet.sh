#!/bin/bash

# Remove Battle.net, its Proton prefix, installed games, and desktop entry.

set -e

PREFIX="$HOME/Games/battlenet"

# Stop any running Battle.net / wine processes tied to this prefix.
pkill -f "$PREFIX" 2>/dev/null || true
sleep 1

rm -rf "$PREFIX"
rm -f "$HOME/.local/bin/launch-battlenet"
rm -f "$HOME/.local/share/applications/battlenet.desktop"
rm -f "$HOME/.cache/cachyos-gaming/Battle.net-Setup.exe"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo
echo "Battle.net and its Proton prefix at $PREFIX have been removed."

if pacman -Q umu-launcher &>/dev/null; then
  echo
  read -r -p "Also remove umu-launcher? It's only used by this command. [y/N] " ans
  [[ $ans == [Yy]* ]] && { sudo pacman -Rns --noconfirm umu-launcher; }
fi

PROTON_DIR="$HOME/.local/share/Steam/compatibilitytools.d"
if compgen -G "$PROTON_DIR/GE-Proton*" >/dev/null; then
  echo
  read -r -p "Also remove GE-Proton runtimes downloaded by umu? [y/N] " ans
  [[ $ans == [Yy]* ]] && {
    rm -rf "$PROTON_DIR"/GE-Proton*
    rm -rf "$HOME/.local/share/umu"
  }
fi
