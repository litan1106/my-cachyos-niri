#!/bin/bash

# Remove Hearthstone Deck Tracker: its files inside the Battle.net prefix, the
# launcher, and the desktop entry. Leaves the Battle.net prefix and the .NET
# runtime in place (both are shared with Battle.net/Hearthstone).

set -e

PREFIX="$HOME/Games/battlenet"
HDT_DIR="$PREFIX/drive_c/Hearthstone Deck Tracker"

# Stop HDT if it's running out of this prefix.
pkill -f "Hearthstone Deck Tracker.exe" 2>/dev/null || true
sleep 1

rm -rf "$HDT_DIR"
rm -f "$HOME/.local/bin/launch-hdt"
rm -f "$HOME/.local/share/applications/hdt.desktop"
rm -f "$HOME/.cache/cachyos-gaming/Hearthstone.Deck.Tracker-"*.zip
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo
echo "Hearthstone Deck Tracker has been removed."
echo "The Battle.net prefix and its .NET runtime were left untouched."
