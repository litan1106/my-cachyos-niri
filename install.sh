#!/usr/bin/env bash

# ════════════════════════════════════════════════════════════════
#  CachyOS Dotfiles — Niri + Omarchy Style Desktop
#  Deploys: Niri WM config, GTK3/4 decorations & theming
# ════════════════════════════════════════════════════════════════

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

header() {
    echo -e "\n${CYAN}${BOLD}── $* ──${NC}"
}

ok()   { echo -e "${GREEN}[✔] $*${NC}"; }
info() { echo -e "${BLUE}[*] $*${NC}"; }
warn() { echo -e "${YELLOW}[!] $*${NC}"; }
err()  { echo -e "${RED}[✘] $*${NC}"; exit 1; }

# ── Backup + link/copy helper ──────────────────────────────────
deploy_file() {
    local src="$1"
    local dest="$2"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    mkdir -p "$dest_dir"

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        local backup="${dest}.bak.$(date +%F_%H-%M-%S)"
        warn "Backing up existing $(basename "$dest") → $(basename "$backup")"
        mv "$dest" "$backup"
    fi

    cp "$src" "$dest"
}

deploy_dir() {
    local src="$1"
    local dest="$2"

    mkdir -p "$dest"

    for f in "$src"/*; do
        deploy_file "$f" "$dest/$(basename "$f")"
    done
}

deploy_niri_cfg() {
    local src="$1"
    local dest="$2"

    mkdir -p "$dest"

    for f in "$src"/*; do
        if [ "$(basename "$f")" = "display.kdl" ]; then
            warn "Skipping display.kdl; monitor/output config is machine-specific."
            continue
        fi

        deploy_file "$f" "$dest/$(basename "$f")"
    done

    if [ ! -e "$dest/display.kdl" ]; then
        info "Creating empty display.kdl placeholder for local monitor settings."
        cat > "$dest/display.kdl" <<'EOF'
// Local monitor/output configuration.
// This file is intentionally not overwritten by install.sh.
// Run `niri msg outputs` and add machine-specific output rules here if needed.
EOF
    fi
}

# ──────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}   CachyOS Dotfiles Installer — Niri + Omarchy Ecosystem     ${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── 1. Pre-flight ──────────────────────────────────────────────
header "Pre-flight Check"
[ -f /etc/arch-release ] || err "This installer is for CachyOS / Arch Linux only."
ok "Arch-based system detected."
warn "It does not overwrite ~/.config/niri/cfg/display.kdl; monitor/output rules stay local to this machine."

# Warn if existing configuration directories are detected
if [ -d "$HOME/.config/niri" ] || [ -d "$HOME/.config/noctalia" ] || [ -d "$HOME/.config/quickshell/noctalia-shell" ]; then
    warn "Existing configuration directories detected:"
    [ -d "$HOME/.config/niri" ] && echo "  - ~/.config/niri"
    [ -d "$HOME/.config/noctalia" ] && echo "  - ~/.config/noctalia"
    [ -d "$HOME/.config/quickshell/noctalia-shell" ] && echo "  - ~/.config/quickshell/noctalia-shell"
    warn "This installer will deploy new configurations and back up modified files."
fi

read -p "Continue with package sync and config deployment? [Y/n] " -n 1 -r; echo ""
[[ $REPLY =~ ^[Nn]$ ]] && err "Installation cancelled."

# ── 2. AUR Helper ─────────────────────────────────────────────
header "AUR Helper"
AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
else
    warn "Neither yay nor paru found."
    read -p "Install yay automatically? [Y/n] " -n 1 -r; echo ""
    [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ] || err "AUR helper required."
    info "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    TEMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$TEMP_DIR"
    (cd "$TEMP_DIR" && makepkg -si --noconfirm)
    rm -rf "$TEMP_DIR"
    AUR_HELPER="yay"
    ok "yay installed."
fi
ok "Using: ${AUR_HELPER}"

# ── 3. Official & CachyOS Packages ───────────────────────────
header "Official / CachyOS Packages"
OFFICIAL_PACKAGES=(
    alacritty
    btop
    cliphist
    fastfetch
    github-desktop
    handbrake
    jdownloader2
    pavucontrol
    qbittorrent
    tmux
    udiskie
    vlc
    wl-clipboard
)
sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"
ok "Official packages synchronized."

# ── 4. Custom AUR Packages ────────────────────────────────────
header "AUR Packages"
CUSTOM_AUR_PACKAGES=(
    typora
    google-chrome
    antigravity
    antigravity-cli
    antigravity-ide
    claude-desktop-bin
    espanso-wayland-git
    openai-codex-desktop
    visual-studio-code-bin
)
$AUR_HELPER -S --needed --noconfirm "${CUSTOM_AUR_PACKAGES[@]}"
ok "AUR packages synchronized."

# ── 5. Set Default Shell to Bash ────────────────────────────
header "Setting Default Shell → bash"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/bin/bash" ]; then
    info "Switching default shell to bash (replacing current: $(getent passwd "$USER" | cut -d: -f7))..."
    chsh -s /bin/bash
    ok "Default shell set to bash. Re-login to apply."
else
    ok "Default shell is already bash — nothing to do."
fi

# ── 6. Deploy Niri Config ─────────────────────────────────────
header "Deploying Niri Config → ~/.config/niri"
deploy_file "${DOTFILES_DIR}/niri/config.kdl"    "$HOME/.config/niri/config.kdl"
deploy_niri_cfg "${DOTFILES_DIR}/niri/cfg"        "$HOME/.config/niri/cfg"
ok "Niri configuration deployed."

# ── 7. Deploy GTK Theming ─────────────────────────────────────
header "Deploying GTK3/4 Decoration Settings"
deploy_file "${DOTFILES_DIR}/gtk-3.0/settings.ini"  "$HOME/.config/gtk-3.0/settings.ini"
deploy_file "${DOTFILES_DIR}/gtk-4.0/settings.ini"  "$HOME/.config/gtk-4.0/settings.ini"
ok "GTK decoration layout applied (minimize, maximize, close)."

# ── 8. Deploy Noctalia Shell Config ───────────────────────────
header "Deploying Noctalia Shell Config → ~/.config/noctalia"
deploy_file "${DOTFILES_DIR}/noctalia/settings.json"  "$HOME/.config/noctalia/settings.json"
deploy_file "${DOTFILES_DIR}/noctalia/plugins.json"   "$HOME/.config/noctalia/plugins.json"
ok "Noctalia shell configuration deployed."

# ── 9. Deploy Custom Quickshell Layouts ────────────────────────
header "Deploying Custom Quickshell Layouts → ~/.config/quickshell"
if [ ! -d "$HOME/.config/quickshell/noctalia-shell" ]; then
    info "Copying system noctalia-shell config to local home..."
    mkdir -p "$HOME/.config/quickshell"
    cp -r /etc/xdg/quickshell/noctalia-shell "$HOME/.config/quickshell/noctalia-shell"
fi
deploy_file "${DOTFILES_DIR}/quickshell/noctalia-shell/Modules/Panels/Launcher/LauncherCore.qml" \
            "$HOME/.config/quickshell/noctalia-shell/Modules/Panels/Launcher/LauncherCore.qml"
ok "Custom quickshell layouts deployed."

# ── 10. System skel (optional) ────────────────────────────────
echo ""
read -p "Copy setup to /etc/skel for new users? [y/N] " -n 1 -r; echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    header "Deploying to /etc/skel"
    sudo mkdir -p /etc/skel/.config/niri/cfg
    sudo cp -r "$HOME/.config/niri/config.kdl"  /etc/skel/.config/niri/
    for f in "$HOME/.config/niri/cfg/"*; do
        if [ "$(basename "$f")" = "display.kdl" ]; then
            warn "Skipping /etc/skel display.kdl; monitor/output config is machine-specific."
            continue
        fi

        sudo cp "$f" /etc/skel/.config/niri/cfg/
    done
    sudo tee /etc/skel/.config/niri/cfg/display.kdl >/dev/null <<'EOF'
// Local monitor/output configuration.
// This file is intentionally not overwritten by install.sh.
// Run `niri msg outputs` and add machine-specific output rules here if needed.
EOF
    sudo mkdir -p /etc/skel/.config/gtk-3.0 /etc/skel/.config/gtk-4.0
    sudo cp "$HOME/.config/gtk-3.0/settings.ini" /etc/skel/.config/gtk-3.0/
    sudo cp "$HOME/.config/gtk-4.0/settings.ini" /etc/skel/.config/gtk-4.0/
    sudo mkdir -p /etc/skel/.config/noctalia
    sudo cp "$HOME/.config/noctalia/settings.json" /etc/skel/.config/noctalia/
    sudo cp "$HOME/.config/noctalia/plugins.json"  /etc/skel/.config/noctalia/
    sudo mkdir -p /etc/skel/.config/quickshell
    sudo cp -r "$HOME/.config/quickshell/noctalia-shell" /etc/skel/.config/quickshell/
    ok "Copied to /etc/skel."
fi

# ── 11. Live Reload Configs ────────────────────────────────────
if [ -n "${NIRI_SOCKET:-}" ] || pgrep -x niri &>/dev/null; then
    header "Reloading Niri"
    niri msg action load-config-file || true
    ok "Niri configuration reloaded."
fi

if pgrep -x quickshell &>/dev/null; then
    header "Reloading Noctalia Shell"
    qs -c noctalia-shell ipc call core restart || true
    ok "Noctalia shell configuration reloaded."
fi

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}       All done! Push to git to share or reinstall:          ${NC}"
echo -e "${GREEN}${BOLD}       git add . && git commit -m 'update' && git push       ${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
