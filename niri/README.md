# CachyOS Niri + Omarchy Tiling Desktop Configuration

This repository contains a highly optimized, developer-centric **Niri Window Manager** configuration built on top of the **CachyOS Niri Settings** template and customized to adopt **Omarchy (Omakase Arch)**-style hotkeys and terminal-centric tools.

---

## 🚀 Key Features

* **Tiling & Grouping**: Niri's scrollable infinite layout meets Omarchy-style keyboard window stacking and tabbed display controls.
* **Unified Controls**: Supercharged window navigation, resizing, and swapping via Vim keys and Arrows.
* **App Ecosystem**: Integration with terminal-centric apps (Tmux, Antigravity IDE, Lazydocker) and standard modern developer tools (Google Chrome, Nautilus, Obsidian, Typora, Claude Desktop, Codex Desktop, Antigravity App).
* **System Shell**: Tailored to run natively with `noctalia-shell` and CachyOS defaults.

---

## 📦 Package Management Setup

The setup automatically splits package syncs between the core **Arch/CachyOS official repositories** and **custom AUR (Arch User Repository) packages** using `yay` (or `paru`).

### 1. Official & CachyOS Repository Packages
These packages are installed natively via `pacman -S`:
* **`niri`** / **`cachyos-niri-noctalia`** (Compositor & CachyOS configs)
* **`noctalia-shell`** / **`noctalia-qs`** (Wayland Desktop Shell & Quickshell fork)
* **`alacritty`** & **`tmux`** (Terminal & Terminal Multiplexer)
* **`nautilus`** (File Manager)
* **`obsidian`** (Local markdown knowledge base)

### 2. Custom AUR Packages
These custom packages are installed from the AUR via your AUR helper (`yay` / `paru`):
* **`google-chrome`** (Web Browser)
* **`antigravity-ide`** (Default developer editor IDE)
* **`antigravity`** (Antigravity application)
* **`claude-desktop-bin`** (Claude desktop client application)
* **`openai-codex-desktop`** (Codex desktop app)
* **`typora`** (Markdown editor)

---

## 🛠️ Installation & Deployment

You can deploy this configuration to your local user directory or install it system-wide so new users automatically receive it.

### Step 1: Clone the repository
```bash
git clone <your-repository-url> ~/.config/niri-omarchy
cd ~/.config/niri-omarchy
```

### Step 2: Run the interactive installer
```bash
./install.sh
```

### Step 3: Network File Sharing (Optional)
If you need to share files over the local network via Samba (SMB), you can run the included helper script to automatically configure Avahi (mDNS), WSDD (Windows discovery), and UFW firewall rules:
```bash
sudo ./setup_smb_discovery.sh
```

---

## ⌨️ Hotkey Survival Guide

### Window & Workspace Navigation
| Hotkey | Action |
| --- | --- |
| `Super + W` or `Super + Q` | Close focused window |
| `Super + T` | Toggle window between tiling/floating |
| `Super + F` | Toggle Fullscreen |
| `Super + Alt + F` | Go full width (maximize column width) |
| `Super + Ctrl + F` | Go full screen inside window (true maximize to edges) |
| `Super + Up` | Maximize focused column height/width |
| `Super + Arrow / Vim` | Move focus in given direction |
| `Super + Shift + Arrow / Vim` | Swap/move window in given direction |
| `Super + Equal / Minus` | Grow / shrink window width |
| `Super + Tab` | Jump to next workspace |
| `Super + Shift + Tab` | Jump to previous workspace |
| `Super + [1-9]` | Focus specific workspace |
| `Super + Shift + [1-9]` | Move window to specific workspace |

### Tabbed Columns / Grouping
| Hotkey | Action |
| --- | --- |
| `Super + G` | Toggle column tabbed display (group windows in stack) |
| `Super + Alt + G` | Expel window from column (ungroup) |
| `Super + Alt + Tab` | Cycle between windows in the grouping |
| `Super + Alt + Left/Right` | Consume adjacent windows into the group |

### App Launchers
| Hotkey | Action |
| --- | --- |
| `Super + Return` | Open Terminal (Alacritty) |
| `Super + Alt + Return` | Open Terminal with Tmux |
| `Super + Shift + Return` / `Super + B` | Open Browser (Google Chrome) |
| `Super + Shift + Alt + B` | Open Browser in Incognito Mode (Google Chrome) |
| `Super + Shift + F` / `Super + E` | Open File Manager (Nautilus) |
| `Super + Shift + N` | Open **Antigravity IDE** |
| `Super + Shift + A` | Open **Claude Desktop** |
| `Super + Shift + Alt + A` | Open **Codex Desktop** |
| `Super + Shift + G` | Open **Antigravity App** |
| `Super + Shift + O` | Open **Obsidian** |
| `Super + Shift + W` | Open **Typora** (Writing) |
| `Super + Shift + Y` | Open **YouTube** (via Google Chrome) |

---

## 🌐 Customizing & Sharing Later

If you make modifications to your keybinds or settings in `~/.config/niri/cfg/`:

1. Copy your files back into this repository directory:
   ```bash
   cp -r ~/.config/niri/* .
   ```
2. Commit and push your changes to your Git remote:
   ```bash
   git add .
   git commit -m "Update custom keybinds and settings"
   git push origin main
   ```
3. To replicate the exact same setup on any other Arch Linux / CachyOS machine, simply clone it and run `./install.sh` again!

---

## ⚠️ Known Issues & Quirks

### GitHub Desktop (Wayland + AMD GPU)
If you are using an AMD GPU, **GitHub Desktop** (and some other Electron apps) may crash or hang invisibly when trying to negotiate OpenGL contexts natively on Wayland. To fix this, force native Wayland and disable GPU acceleration. 

Update the `.desktop` shortcut (e.g., in `~/.local/share/applications/github-desktop.desktop`) to include the following flags in the Exec line:
```ini
Exec=/usr/bin/github-desktop --ozone-platform-hint=auto --disable-gpu %U
```
