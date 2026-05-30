#!/usr/bin/env bash

# ────────────── CachyOS Niri + Omarchy Installer ──────────────
# Base: https://github.com/CachyOS/cachyos-niri-settings
# Customization: Omarchy-style Keybindings & Desktop Ecosystem

set -euo pipefail

# Visual styling tokens
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print header
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}    CachyOS Niri + Omarchy Config Deployer & Packager       ${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. System Pre-flight Checks
echo -e "${BLUE}[*] Performing system pre-flight checks...${NC}"
if [ ! -f /etc/arch-release ]; then
    echo -e "${RED}[ERROR] This installer is optimized for CachyOS / Arch Linux only.${NC}"
    exit 1
fi
echo -e "${GREEN}[✔] Arch-based system detected.${NC}"

# 2. Check for AUR helper
echo -e "${BLUE}[*] Detecting AUR/yay helper...${NC}"
AUR_HELPER=""
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
else
    echo -e "${YELLOW}[!] Neither yay nor paru was found.${NC}"
    read -p "Would you like to automatically install 'yay' now? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
        echo -e "${BLUE}[*] Installing yay dependencies...${NC}"
        sudo pacman -S --needed --noconfirm base-devel git
        
        TEMP_DIR=$(mktemp -d)
        git clone https://aur.archlinux.org/yay-bin.git "$TEMP_DIR"
        cd "$TEMP_DIR"
        makepkg -si --noconfirm
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        AUR_HELPER="yay"
        echo -e "${GREEN}[✔] yay installed successfully.${NC}"
    else
        echo -e "${RED}[ERROR] An AUR helper is required to install Omarchy custom packages.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}[✔] Using AUR helper: ${AUR_HELPER}${NC}"

# 3. Package Group Definitions
OFFICIAL_PACKAGES=(
    "niri"
    "cachyos-niri-noctalia"
    "noctalia-shell"
    "noctalia-qs"
    "alacritty"
    "tmux"
    "nautilus"
    "obsidian"
)

CUSTOM_AUR_PACKAGES=(
    "typora"
    "google-chrome"
    "antigravity"
    "antigravity-ide"
    "claude-desktop-bin"
    "openai-codex-desktop"
)

# 4. Install Core System & Apps from Official & CachyOS Repositories
echo -e "\n${BLUE}[*] Installing Core System & Apps from Official / CachyOS Repos...${NC}"
sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"
echo -e "${GREEN}[✔] Official packages synchronized.${NC}"

# 5. Install Custom Packages from AUR using yay/paru
echo -e "\n${BLUE}[*] Syncing Custom AUR Packages using ${AUR_HELPER}...${NC}"
$AUR_HELPER -S --needed --noconfirm "${CUSTOM_AUR_PACKAGES[@]}"
echo -e "${GREEN}[✔] Custom AUR packages synchronized.${NC}"

# 6. Deploy Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CONF="$HOME/.config/niri"

echo -e "\n${BLUE}[*] Deploying configuration to ${TARGET_CONF}...${NC}"

if [ -d "$TARGET_CONF" ]; then
    BACKUP_DIR="${TARGET_CONF}.bak.$(date +%F_%H-%M-%S)"
    echo -e "${YELLOW}[!] Existing configuration detected. Backing up to ${BACKUP_DIR}...${NC}"
    # Use rsync or cp to make a backup before moving
    mkdir -p "$BACKUP_DIR"
    cp -r "$TARGET_CONF/"* "$BACKUP_DIR/"
fi

# Copying files into user configuration
mkdir -p "$TARGET_CONF/cfg"
cp -r "${SCRIPT_DIR}/config.kdl" "$TARGET_CONF/"
cp -r "${SCRIPT_DIR}/cfg/"* "$TARGET_CONF/cfg/"

echo -e "${GREEN}[✔] Configuration files deployed successfully.${NC}"

# 7. Configure GTK Client-Side Decorations (Minimize, Maximize, Close Buttons)
echo -e "\n${BLUE}[*] Configuring GTK Window Button Layout (Minimize, Maximize, Close)...${NC}"
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

for GTK_CONF in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    if [ -f "$GTK_CONF" ]; then
        if ! grep -q "gtk-decoration-layout" "$GTK_CONF"; then
            if grep -q "\[Settings\]" "$GTK_CONF"; then
                sed -i '/\[Settings\]/a gtk-decoration-layout=menu:minimize,maximize,close' "$GTK_CONF"
            else
                echo -e "[Settings]\ngtk-decoration-layout=menu:minimize,maximize,close" >> "$GTK_CONF"
            fi
        else
            sed -i 's/gtk-decoration-layout=.*/gtk-decoration-layout=menu:minimize,maximize,close/' "$GTK_CONF"
        fi
    else
        echo -e "[Settings]\ngtk-application-prefer-dark-theme=true\ngtk-cursor-theme-name=capitaine-cursors\ngtk-font-name=Noto Sans 10\ngtk-theme-name=adw-gtk3\ngtk-decoration-layout=menu:minimize,maximize,close" > "$GTK_CONF"
    fi
done
echo -e "${GREEN}[✔] GTK decoration layout updated successfully.${NC}"

# 8. Package / Share option (writing to system skel)
echo -e ""
read -p "Would you like to copy this setup to /etc/skel so new users automatically inherit it? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}[*] Deploying to system skel (requires sudo)...${NC}"
    sudo mkdir -p /etc/skel/.config/niri/cfg
    sudo cp -r "$TARGET_CONF/config.kdl" /etc/skel/.config/niri/
    sudo cp -r "$TARGET_CONF/cfg/"* /etc/skel/.config/niri/cfg/
    echo -e "${GREEN}[✔] Copied to /etc/skel/.config/niri successfully.${NC}"
fi

# 9. Reload Niri
if [ -n "${NIRI_SOCKET:-}" ] || pgrep -x niri &> /dev/null; then
    echo -e "\n${BLUE}[*] Live reloading Niri configuration...${NC}"
    niri msg action load-config-file || true
    echo -e "${GREEN}[✔] Reloaded!${NC}"
fi

echo -e "\n${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}        Installation completed successfully!                ${NC}"
echo -e "${GREEN}${BOLD}   Push this directory to your git remote to share it!       ${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
