# Explicitly Installed Package Inventory

This document categorizes all explicitly installed packages on this CachyOS/Arch Linux system (181 repo packages and 8 AUR/foreign packages) as of June 2026, detailing which ones are synced via the installer and which are excluded.

## 1. Desktop Essentials
Core window manager settings, desktop shell components, fonts, networking, audio, and basic GUI helpers.

| Package | Source | Sync Status | Note / Purpose |
|---|---|---|---|
| `cachyos-niri-noctalia` | Repo | Excluded | Synced separately via CachyOS settings packages. |
| `alacritty` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Standard GPU-accelerated terminal emulator. |
| `cliphist` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Wayland clipboard history manager. |
| `wl-clipboard` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Wayland clipboard utilities (needed by Noctalia clipboard provider). |
| `pavucontrol` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | PulseAudio Volume Control (widget integration). |
| `udiskie` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Automounter for removable drives. |
| `firefox` | Repo | Excluded | Web browser (system default, let user configure manually). |
| `github-desktop` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Git desktop client. |
| `networkmanager` | Repo | Excluded | System service. |
| `networkmanager-openvpn` | Repo | Excluded | System VPN plugin. |
| `bluez` | Repo | Excluded | System Bluetooth service. |
| `bluez-utils` | Repo | Excluded | Bluetooth control CLI. |
| `upower` | Repo | Excluded | Power management service. |
| `power-profiles-daemon` | Repo | Excluded | Power profiles integration. |
| `sddm` | Repo | Excluded | Display/login manager. |
| `awesome-terminal-fonts` | Repo | Excluded | Font. |
| `cantarell-fonts` | Repo | Excluded | Font. |
| `noto-fonts` | Repo | Excluded | Font. |
| `noto-fonts-cjk` | Repo | Excluded | Chinese/Japanese/Korean font. |
| `noto-fonts-emoji` | Repo | Excluded | Emoji font. |
| `ttf-bitstream-vera` | Repo | Excluded | Font. |
| `ttf-dejavu` | Repo | Excluded | Font. |
| `ttf-liberation` | Repo | Excluded | Font. |
| `ttf-meslo-nerd` | Repo | Excluded | Nerd fonts for terminal icons. |
| `ttf-opensans` | Repo | Excluded | Font. |

---

## 2. Developer Tools
Compilers, interpreters, CLI utilities, text editors, and IDEs.

| Package | Source | Sync Status | Note / Purpose |
|---|---|---|---|
| `base-devel` | Repo | Excluded | Meta-package for compiling tools. |
| `git` | Repo | Excluded | Version control system. |
| `python` | Repo | Excluded | Language interpreter. |
| `python-packaging` | Repo | Excluded | Python packaging library. |
| `ripgrep` | Repo | Excluded | CLI search tool. |
| `wget` | Repo | Excluded | CLI downloader. |
| `which` | Repo | Excluded | Path utility. |
| `btop` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Interactive resource monitor. |
| `tmux` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Terminal multiplexer. |
| `meld` | Repo | Excluded | Visual diff tool. |
| `micro` | Repo | Excluded | Modern terminal editor. |
| `nano` | Repo | Excluded | Basic text editor. |
| `vim` | Repo | Excluded | Advanced terminal text editor. |
| `yay` / `paru` | Repo | **Handled** | AUR helper scripts. |
| `antigravity` | AUR | **Synced** (`CUSTOM_AUR_PACKAGES`) | Antigravity AI companion. |
| `antigravity-cli` | AUR | **Synced** (`CUSTOM_AUR_PACKAGES`) | Antigravity CLI interface. |
| `antigravity-ide` | AUR | **Synced** (`CUSTOM_AUR_PACKAGES`) | Antigravity IDE application. |
| `visual-studio-code-bin` | AUR | **Synced** (`CUSTOM_AUR_PACKAGES`) | VS Code IDE package. |
| `espanso-wayland-git` | AUR | **Synced** (`CUSTOM_AUR_PACKAGES`) | Wayland text expander. |

---

## 3. Personal Apps
Specialized media tools, document editors, downloaders, and personal software.

| Package | Source | Sync Status | Note / Purpose |
|---|---|---|---|
| `google-chrome` | AUR | **Synced** (`CUSTOM_AUR_PACKAGES`) | Google Chrome browser. |
| `claude-desktop-bin` | AUR | **Synced** (`CUSTOM_AUR_PACKAGES`) | Claude AI Desktop Client. |
| `openai-codex-desktop` | AUR | **Synced** (`CUSTOM_AUR_PACKAGES`) | OpenAI Codex Desktop. |
| `typora` | AUR | **Synced** (`CUSTOM_AUR_PACKAGES`) | Markdown editor. |
| `handbrake` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Video transcoder. |
| `jdownloader2` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Download manager. |
| `qbittorrent` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Torrent downloader client. |
| `vlc` / `vlc-plugins-all` | Repo | **Synced** (`OFFICIAL_PACKAGES`) | Video player. |

---

## 4. Hardware / System Utilities
Kernels, hardware drivers, system layers, backup tools, and filesystem helpers.

> [!NOTE]
> **All hardware/system utilities are intentionally excluded** from the automatic sync in `install.sh` to prevent issues when deploying on different hardware setups.

- **Kernels**: `linux-cachyos`, `linux-cachyos-headers`, `linux-cachyos-lts`, `linux-cachyos-lts-headers`
- **Firmware / Drivers**: `linux-firmware`, `sof-firmware`, `amd-ucode`, `alsa-firmware`, `xf86-video-amdgpu`, `vulkan-radeon`, `lib32-vulkan-radeon`
- **Filesystem Tools**: `btrfs-progs`, `cryptsetup`, `device-mapper`, `dmraid`, `dosfstools`, `e2fsprogs`, `exfatprogs`, `f2fs-tools`, `fsarchiver`, `jfsutils`, `lvm2`, `mdadm`, `mtools`, `nilfs-utils`, `xfsprogs`
- **Backup & Snapshots**: `snapper`, `btrfs-assistant`
- **General Hardware Utils**: `hdparm`, `hwdetect`, `hwinfo`, `smartmontools`, `sysfsutils`, `usbutils`, `usb_modeswitch`

---

## 5. CachyOS Settings & Specifics
System-level CachyOS customization packages, hooks, mirror listings, and visual branding.

> [!WARNING]
> **CachyOS specifics are excluded** from `install.sh` as they are pre-configured by the installer and system profile. Overwriting these on non-CachyOS installations could break system packages.

- **Branding & Shell Configs**: `cachyos-wallpapers`, `cachyos-hello`, `cachyos-fish-config`, `cachyos-zsh-config`
- **System Settings & Hooks**: `cachyos-settings`, `cachyos-hooks`, `cachyos-micro-settings`, `cachyos-rate-mirrors`, `chwd`
- **Package Manager Lists**: `cachyos-keyring`, `cachyos-mirrorlist`, `cachyos-v3-mirrorlist`, `cachyos-v4-mirrorlist`
- **Installer & Snapper**: `cachyos-packageinstaller`, `cachyos-snapper-support`
