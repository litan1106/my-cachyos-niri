# CachyOS Dotfiles — Niri + Omarchy Desktop

> **Base**: [cachyos-niri-settings](https://github.com/CachyOS/cachyos-niri-settings)  
> **Style**: [Omarchy keybindings](https://omarchy.com)  
> **Shell**: [noctalia-shell](https://docs.noctalia.dev)

A personal desktop configuration for **CachyOS + Niri** — batteries-included with Omarchy-style keybindings, GTK window decorations, and a curated developer app stack. Clone once, run `./install.sh` on any Arch/CachyOS machine.

---

## 📁 Repository Structure

```
dotfiles/
├── niri/               ← Niri WM config (keybinds, layout, rules …)
│   ├── config.kdl      ← Entry point, includes all cfg/ files
│   └── cfg/
│       ├── animation.kdl
│       ├── autostart.kdl
│       ├── display.kdl
│       ├── input.kdl
│       ├── keybinds.kdl    ← Omarchy-style hotkeys
│       ├── layout.kdl
│       ├── misc.kdl
│       └── rules.kdl
├── gtk-3.0/
│   └── settings.ini    ← Dark theme, cursor, min/max/close buttons
├── gtk-4.0/
│   └── settings.ini    ← Same settings for GTK4 apps
├── noctalia/
│   ├── settings.json   ← Classic Windows 10 style taskbar layout settings
│   └── plugins.json    ← Enabled quickshell desktop plugins
├── quickshell/
│   └── noctalia-shell/
│       └── Modules/Panels/Launcher/
│           └── LauncherCore.qml  ← Custom Windows-style Start Menu power options layout
├── install.sh          ← One-shot interactive installer
└── README.md
```

---

## 🛠️ Installation & Syncing (Fresh Machine)

To deploy these customizations to a fresh CachyOS installation running Niri:

```bash
# 1. Clone your personal dotfiles repository
git clone https://github.com/litan1106/my-cachyos-niri.git ~/dotfiles

# 2. Navigate into the dotfiles directory
cd ~/dotfiles

# 3. Make the installer executable and run it
chmod +x install.sh
./install.sh
```

### What the installer does automatically:
1. **Verifies system compatibility** (expects Arch Linux / CachyOS).
2. **Detects or installs `yay`** as the AUR helper.
3. **Synchronizes core packages** via `pacman` (Niri, Noctalia Shell, Alacritty, Tmux, etc.).
4. **Synchronizes customized helper packages** via `yay` (Google Chrome, Typora, Antigravity, Antigravity IDE, Claude Desktop, and Codex Desktop).
5. **Safely deploys Niri configurations** from `dotfiles/niri/` to `~/.config/niri/` (creating a timestamped backup of any existing configuration first).
6. **Deploys GTK window buttons** (`gtk-3.0` and `gtk-4.0` settings) so you instantly get **Minimize, Maximize, and Close** buttons on all your window titlebars.
7. **Optionally updates `/etc/skel/`** (requires sudo) so any new users created on the system automatically inherit this setup.
8. **Live-reloads Niri** if it is currently running, applying your settings instantly.

---

## 🔄 Keeping in Sync with CachyOS Upstream

Add the upstream CachyOS Niri repo as a remote to pull future changes cleanly:

```bash
cd ~/dotfiles
git remote add upstream https://github.com/CachyOS/cachyos-niri-settings.git
```

To apply upstream updates without losing your custom changes:

```bash
git fetch upstream
git rebase upstream/master   # replays your commits on top of upstream changes
```

Resolve any conflicts in `niri/cfg/keybinds.kdl` if a key you customised was also changed upstream. Everything else (GTK, AUR packages) is untouched by upstream.

---

## 📦 Package Groups

### Official / CachyOS Repos (`pacman`)
| Package | Purpose |
|---|---|
| `niri` | Scrollable tiling Wayland compositor |
| `cachyos-niri-noctalia` | CachyOS Niri + Noctalia defaults |
| `noctalia-shell` | Wayland desktop shell |
| `noctalia-qs` | Quickshell fork powering Noctalia |
| `alacritty` | GPU-accelerated terminal |
| `tmux` | Terminal multiplexer |
| `nautilus` | File manager |
| `obsidian` | Local markdown knowledge base |

### AUR Packages (`yay`)
| Package | Purpose |
|---|---|
| `google-chrome` | Web browser (replaces Firefox) |
| `antigravity-ide` | Default code editor |
| `antigravity` | Antigravity application |
| `claude-desktop-bin` | Claude AI desktop client |
| `openai-codex-desktop` | Codex AI desktop client |
| `typora` | WYSIWYG markdown editor |

---

## ⌨️ Key Hotkeys (Omarchy-style)

### System
| Hotkey | Action |
|---|---|
| `Super + Space` | App launcher |
| `Super + Alt + Space` | System / session menu |
| `Super + Escape` | System menu |
| `Super + Ctrl + L` | Lock screen |
| `Super + W` / `Super + Q` | Close window |
| `Super + Shift + Escape` | Show hotkey overlay |

### Window & Workspaces
| Hotkey | Action |
|---|---|
| `Super + F` | Fullscreen |
| `Super + Alt + F` | Full width (maximize column) |
| `Super + Ctrl + F` | True maximize to screen edges |
| `Super + Up` | Maximize focused column |
| `Super + T` | Toggle tiling / floating |
| `Super + G` | Toggle tabbed column (grouping) |
| `Super + Alt + G` | Expel window from group |
| `Super + Arrow / H J K L` | Move focus |
| `Super + Shift + Arrow / H J K L` | Move window |
| `Super + [1-9]` | Switch workspace |
| `Super + Shift + [1-9]` | Move window to workspace |
| `Super + Tab / Shift+Tab` | Next / previous workspace |

### App Launchers
| Hotkey | App |
|---|---|
| `Super + Return` | Terminal (Alacritty) |
| `Super + Alt + Return` | Terminal + Tmux |
| `Super + Shift + Return` / `Super + B` | Google Chrome |
| `Super + Shift + Alt + B` | Chrome (Incognito) |
| `Super + Shift + N` | Antigravity IDE |
| `Super + Shift + A` | Claude Desktop |
| `Super + Shift + Alt + A` | Codex Desktop |
| `Super + Shift + G` | Antigravity App |
| `Super + E` / `Super + Shift + F` | Nautilus (File Manager) |
| `Super + Shift + O` | Obsidian |
| `Super + Shift + W` | Typora |
| `Super + Shift + Y` | YouTube (Chrome) |

---

## 🪟 GTK Window Buttons

`gtk-3.0/` and `gtk-4.0/` include `gtk-decoration-layout=menu:minimize,maximize,close` which enables **Minimize, Maximize, and Close** buttons on the right side of the titlebar for all GTK and Electron apps.

> **Google Chrome**: additionally go to *Settings → Appearance → Use system title bar and borders → ON* to show native chrome buttons.

---

## 🔄 Syncing Customizations Across Machines

When you are using Niri and make changes (e.g., updating custom keybindings in `~/.config/niri/cfg/keybinds.kdl` or changing display setups), you can easily sync them back to your repository and distribute them across all your CachyOS machines.

### 1. Push live changes to your GitHub repository:
Whenever you customize something on your current active machine, sync it back to your personal repository:

```bash
cd ~/dotfiles

# Copy the latest live settings into the repository folder
cp ~/.config/niri/config.kdl          niri/
cp -r ~/.config/niri/cfg/*            niri/cfg/
cp ~/.config/gtk-3.0/settings.ini     gtk-3.0/
cp ~/.config/gtk-4.0/settings.ini     gtk-4.0/
cp ~/.config/noctalia/settings.json   noctalia/
cp ~/.config/noctalia/plugins.json    noctalia/
cp ~/.config/quickshell/noctalia-shell/Modules/Panels/Launcher/LauncherCore.qml \
   quickshell/noctalia-shell/Modules/Panels/Launcher/LauncherCore.qml

# Commit your changes
git add .
git commit -m "feat: update keybindings and display layouts"

# Push to your remote repository
git push origin main
```

### 2. Pull and apply updates on another machine:
On your other CachyOS machines, run this simple sequence to fetch and apply the updated configurations live:

```bash
cd ~/dotfiles

# Fetch the latest updates from GitHub
git pull origin main

# Deploy the updated configurations live (will automatically backup existing ones and reload Niri)
./install.sh
```
