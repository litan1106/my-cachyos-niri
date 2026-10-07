#!/bin/bash

# Install Hearthstone Deck Tracker (HDT) INTO the existing Battle.net Proton
# prefix (~/Games/battlenet). HDT only tracks a Hearthstone install that lives in
# the same Wine prefix — that's how it reads Hearthstone's log files and overlays
# the game — so this deliberately reuses the Battle.net prefix rather than making
# a new one (no Lutris, no separate wine prefix).
#
# Prerequisite: Battle.net must already be installed (install-gaming-battlenet.sh)
# AND Hearthstone installed through it. HDT will install and launch without
# Hearthstone present, but it can't track anything until the game is there.

set -e

# Resolve this script's own dir so the shared helper is found no matter where the
# script is invoked from.
script_dir="$(dirname "$(realpath "$0")")"
source "$script_dir/setup-local-bin-path.sh"

PREFIX="$HOME/Games/battlenet"
BN_LAUNCHER="$PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
HDT_DIR="$PREFIX/drive_c/Hearthstone Deck Tracker"
HDT_EXE="$HDT_DIR/Hearthstone Deck Tracker.exe"
RELEASES_API="https://api.github.com/repos/HearthSim/Hearthstone-Deck-Tracker/releases/latest"

echo "Installing Hearthstone Deck Tracker..."

# HDT shares the Battle.net prefix. Bail early if that prefix was never created —
# installing into a non-existent prefix would silently make a blank one.
if [[ ! -f $BN_LAUNCHER ]]; then
  echo "Battle.net prefix not found at $PREFIX." >&2
  echo "Run install-gaming-battlenet.sh first, then install Hearthstone through it." >&2
  exit 1
fi

# Warn (don't block) if Hearthstone isn't in the prefix yet — HDT is useless
# until it is, but installing HDT ahead of time is harmless.
if ! find "$PREFIX/drive_c" -maxdepth 4 -iname "Hearthstone.exe" 2>/dev/null | grep -q .; then
  echo
  echo "Note: Hearthstone doesn't appear to be installed in this prefix yet."
  echo "HDT will install, but it can't track games until you install Hearthstone"
  echo "via Battle.net (launch-battlenet)."
  echo
fi

# Tools needed: winetricks (+ cabextract) for the .NET install, unzip + curl for
# the HDT download. umu-launcher comes from the Battle.net install.
sudo pacman -S --needed --noconfirm winetricks cabextract unzip curl

# HDT is a .NET Framework app, which the bare Proton prefix doesn't provide, so
# install .NET 4.8 into the prefix with winetricks.
#
# Which wine drives the install matters: the dotnet40/dotnet48 installers hit a
# cabinet-extraction bug (err:msi:extract_cabinet FDICopy failed /
# "netfx_core.mzz") on BOTH wine 10 and wine 11 — observed failing under
# UMU-Proton 10.0-4 and GE-Proton 11. The install only succeeds on wine 9.x, after
# which .NET runs fine under any later wine (it lands in the prefix as plain files
# + registry, so the installer's wine build doesn't matter afterward). So drive the
# install with the newest available Proton build whose wine is <= 9, independent of
# the GE-Proton the game launches with. If no wine 9 build is present, fetch a
# known-good GE-Proton 9 into the Steam compat-tools dir and use it just for this
# step (the game keeps launching under whatever GE-Proton launch-hdt selects).
compat_dir="$HOME/.local/share/Steam/compatibilitytools.d"
mkdir -p "$compat_dir"

# Echo the path of the newest wine <= 9 under compat_dir (empty if none).
find_dotnet_wine() {
  local best="" best_major=-1 w major
  for w in "$compat_dir"/*/files/bin/wine; do
    [[ -x $w ]] || continue
    major="$("$w" --version 2>/dev/null | sed -nE 's/^wine-([0-9]+).*/\1/p')"
    [[ $major =~ ^[0-9]+$ ]] || continue
    if (( major <= 9 && major > best_major )); then best_major=$major; best="$w"; fi
  done
  printf '%s' "$best"
}

install_wine="$(find_dotnet_wine)"
if [[ -z $install_wine ]]; then
  # No wine 9 build available, and wine 10/11 fail the .NET install — fetch the
  # known-good GE-Proton 9 build and use it only for this step.
  ge_tag="GE-Proton9-27"
  ge_url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$ge_tag/$ge_tag.tar.gz"
  cache_dir="$HOME/.cache/cachyos-gaming"
  mkdir -p "$cache_dir"
  ge_tar="$cache_dir/$ge_tag.tar.gz"
  echo
  echo "No Proton build with wine 9 found — the .NET 4.8 installer fails on wine 10/11,"
  echo "so fetching $ge_tag (~466 MB) to drive just this install step..."
  if [[ ! -s $ge_tar ]]; then
    curl --fail --location --retry 3 "$ge_url" --output "$ge_tar"
  fi
  echo "Extracting $ge_tag into $compat_dir..."
  tar -xf "$ge_tar" -C "$compat_dir"
  install_wine="$(find_dotnet_wine)"
  if [[ -z $install_wine ]]; then
    echo "Failed to set up a wine 9 Proton build for the .NET install." >&2
    exit 1
  fi
fi
install_major="$("$install_wine" --version 2>/dev/null | sed -nE 's/^wine-([0-9]+).*/\1/p')"
install_bin="$(dirname "$install_wine")"
# Proton directory for this wine build (…/GE-Proton9-27), passed to umu-run as
# PROTONPATH so the install runs inside the Steam Linux Runtime (see below).
install_proton="${install_wine%/files/bin/wine}"

# A wineserver from a DIFFERENT Proton build may already be attached to this
# prefix — e.g. the GE-Proton that launch-battlenet/launch-hdt run the game
# under leaves one running after you've started Hearthstone. winetricks' wine
# (from the chosen install Proton) would then talk to that mismatched server and
# fail with "wine client error:0: version mismatch NNN/NNN ... wrong wineserver
# is still running". Shut any server down first, with both the install build's
# wineserver and any other wineserver found under the compat tools, so winetricks
# starts its own clean one. -w waits for the server to fully exit.
echo "Stopping any wineserver attached to the prefix..."
for ws in "$install_bin/wineserver" "$compat_dir"/*/files/bin/wineserver; do
  [[ -x $ws ]] || continue
  WINEPREFIX="$PREFIX" "$ws" -k 2>/dev/null || true
done
WINEPREFIX="$PREFIX" "$install_bin/wineserver" -w 2>/dev/null || true

# Idempotent: winetricks records applied verbs in the prefix's winetricks.log.
if grep -qx "dotnet48" "$PREFIX/winetricks.log" 2>/dev/null; then
  echo ".NET Framework 4.8 already present in the prefix — skipping."
else
  echo
  echo "Installing .NET Framework 4.8 into $PREFIX using wine $install_major (several"
  echo "minutes; a few Wine dialogs may flash by — let it run)..."
  # Drive winetricks THROUGH umu-run, not the bare Proton wine binary. umu sets up
  # the Steam Linux Runtime container the rest of the prefix already uses (the same
  # way install-gaming-battlenet.sh runs its installer), so wine's GUI subsystem —
  # FreeType, display — is actually present. Running the raw wine binary directly
  # leaves it degraded ("Wine cannot find the FreeType font library") and the
  # installer's winecfg/dialog steps then stall for minutes, looking hung.
  # PROTONPATH pins the wine-9 build (dodging the dotnet cabextract bug on wine
  # 10/11); GAMEID reuses the Battle.net umu config; mscoree/mshtml=d suppresses the
  # wine-mono/gecko install prompts; -q is unattended.
  WINEPREFIX="$PREFIX" \
  PROTONPATH="$install_proton" \
  GAMEID=umu-battlenet \
  WINEDLLOVERRIDES="mscoree=d;mshtml=d" \
    umu-run winetricks -q dotnet48
fi

# winetricks dotnet40 flips the prefix into Windows XP mode (visible as "winxp64"
# during the install). Battle.net, Hearthstone and HDT all expect a modern
# Windows, so force the prefix back to Windows 11. Run this unconditionally — even
# on the skip path above — so a prefix left at winxp by an earlier/partial run is
# always corrected. Also via umu-run, for the same reason as the install above —
# a bare-wine winecfg stalls on the missing FreeType library.
echo "Setting the prefix Windows version to Windows 11..."
WINEPREFIX="$PREFIX" \
PROTONPATH="$install_proton" \
GAMEID=umu-battlenet \
  umu-run winecfg -v win11

# Download the latest HDT portable zip (the project ships a zip, not an installer).
asset_url="$(curl -fsSL "$RELEASES_API" \
  | grep -oE '"browser_download_url": *"[^"]*\.zip"' | head -1 | cut -d'"' -f4)"
if [[ -z $asset_url ]]; then
  echo "Could not resolve the latest HDT release asset from GitHub." >&2
  exit 1
fi

cache_dir="$HOME/.cache/cachyos-gaming"
mkdir -p "$cache_dir"
zip="$cache_dir/$(basename "$asset_url")"
echo
echo "Downloading HDT: $(basename "$asset_url")"
curl --fail --location --retry 3 "$asset_url" --output "$zip"

# Extract into the prefix's C: drive. The zip's top-level folder is
# "Hearthstone Deck Tracker/", so this lands exactly at $HDT_DIR.
echo "Extracting HDT into the prefix..."
rm -rf "$HDT_DIR"
unzip -q "$zip" -d "$PREFIX/drive_c"

if [[ ! -f $HDT_EXE ]]; then
  echo "Extraction finished but HDT executable not found at:" >&2
  echo "  $HDT_EXE" >&2
  exit 1
fi

# Install the launcher script and desktop entry from this repo.
install -Dm755 "$script_dir/launch-hdt.sh" "$HOME/.local/bin/launch-hdt"
install -Dm644 "$script_dir/../applications/hdt.desktop" \
  "$HOME/.local/share/applications/hdt.desktop"
# Pin Exec to the absolute launcher path so the menu entry works regardless of
# whether ~/.local/bin is on PATH (it isn't on a default CachyOS session).
sed -i "s|^Exec=.*|Exec=$HOME/.local/bin/launch-hdt|" \
  "$HOME/.local/share/applications/hdt.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# Make sure ~/.local/bin is on PATH so the `launch-hdt` command resolves.
setup_local_bin_path

cat <<EOF

Hearthstone Deck Tracker is installed. Find it in your app launcher, or run:

  launch-hdt

Usage:
  1. Start Hearthstone via Battle.net (launch-battlenet).
  2. Start HDT (launch-hdt). It auto-detects the running Hearthstone in the
     same prefix and writes the log.config it needs.
  3. If HDT asks for the Hearthstone directory, point it at (inside the prefix):
     C:\\Program Files (x86)\\Hearthstone   (or wherever Battle.net installed it)

(Re-login once so the app launcher and new terminals see ~/.local/bin.)

EOF
