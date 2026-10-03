#!/bin/bash

set -e

pkgs=(lutris wine-staging wine-mono wine-gecko winetricks python-protobuf umu-launcher)
to_remove=()
for p in "${pkgs[@]}"; do pacman -Q "$p" &>/dev/null && to_remove+=("$p"); done
(( ${#to_remove[@]} )) && sudo pacman -Rns --noconfirm "${to_remove[@]}"

rm -rf \
  "$HOME/.config/lutris" \
  "$HOME/.local/share/lutris" \
  "$HOME/.cache/lutris" \
  "$HOME/.local/share/umu" \
  "$HOME/.cache/umu" \
  "$HOME/.wine" \
  "$HOME/.cache/wine" \
  "$HOME/.cache/winetricks"

echo ""
echo "Lutris, Wine, umu-launcher, and their configs have been removed."
