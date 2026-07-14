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
├── bash/                ← .bashrc / .inputrc synced by apply.sh
├── llm/                 ← Local LLM setup notes (llama.cpp, ROCm, …)
├── package-inventory/   ← inventory.md + pkg-export.sh package audit tooling
├── scripts/             ← Standalone utility scripts (backups, fixes, SMB setup)
├── docs/                ← Standalone reference guides (recovery, migration, hotkeys)
├── install.sh           ← One-shot interactive installer
├── apply.sh             ← Fast config re-sync without a full reinstall
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
3. **Synchronizes user packages** via `pacman` (Alacritty, udiskie automounting, Wayland clipboard history, etc.).
4. **Synchronizes customized helper packages** via `yay` (Google Chrome, Typora, Antigravity, Antigravity IDE, Claude Desktop, and Codex Desktop).
5. **Safely deploys Niri configurations** from `dotfiles/niri/` to `~/.config/niri/` (creating a timestamped backup of any existing configuration first), while leaving monitor/output config local to each machine.
6. **Deploys GTK window buttons** (`gtk-3.0` and `gtk-4.0` settings) so you instantly get **Minimize, Maximize, and Close** buttons on all your window titlebars.
7. **Optionally updates `/etc/skel/`** (requires sudo) so any new users created on the system automatically inherit this setup.
8. **Live-reloads Niri** if it is currently running, applying your settings instantly.

> **Monitor note**: `niri/cfg/display.kdl` is intentionally not installed or overwritten by `install.sh`, because display names, refresh rates, scaling, and positions are machine-specific. After install, run `niri msg outputs` on each machine and edit `~/.config/niri/cfg/display.kdl` locally if you need explicit monitor rules.

> **Input note**: `niri/cfg/input.kdl` is gitignored — it contains device-specific settings (keyboard layout, mouse/touchpad sensitivity) that differ per machine. After install, apply these recommended tweaks manually in `~/.config/niri/cfg/input.kdl`:
> - **Disable `focus-follows-mouse`** — comment it out so windows don't resize/refocus as you hover; focus only changes on click. Without this, moving the mouse over any window instantly shifts focus and causes the active column to resize.
>   ```kdl
>   // focus-follows-mouse
>   ```

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
| `alacritty` | GPU-accelerated terminal |
| `cliphist` | Wayland clipboard history backend |
| `obsidian` | Local markdown knowledge base |
| `udiskie` | User-session removable drive automounting |
| `wl-clipboard` | Wayland clipboard command-line tools |

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
| `Super + V` | Clipboard history |
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

## 🛠️ How to Customize Things

You can customize every part of this tiling desktop ecosystem. The system is split into three layers:

### 1. Compositor & Keybindings (Niri)
All window management, layout rules, animations, and hotkeys are configured via Niri KDL files.
* **Configuration Path**: `~/.config/niri/cfg/`
  * Edit `keybinds.kdl` to change shortcut triggers, launch new applications, or bind scripts.
  * Edit `layout.kdl` to customize window gaps, borders, layout modes, and dimensions.
  * Edit `autostart.kdl` to add/remove services launching on startup.
* **Applying Changes**: Niri automatically live-reloads configurations as soon as you save any `.kdl` file. To force a reload manually:
  ```bash
  niri msg action load-config-file
  ```

### 2. Status Bar, Taskbar & Start Menu (Noctalia Shell)
The bottom bar, widgets, and the Start Menu launcher are powered by Quickshell.
* **Settings JSON Path**: `~/.config/noctalia/settings.json`
  * Rearrange bar widget order in `bar.widgets` (`left`, `center`, `right`). Available widgets include `Launcher`, `Taskbar`, `Workspace`, `Clock`, `Tray`, `Volume`, `Battery`, `Brightness`, `NotificationHistory`, and `ControlCenter`.
  * Adjust bar position, spacing, opacity, margins, and corner radii.
* **Custom QML Layouts Path**: `~/.config/quickshell/noctalia-shell/`
  * Customize advanced shell interfaces (like the Start Menu profile and power button footer) in QML files (e.g. `Modules/Panels/Launcher/LauncherCore.qml`).
* **Applying Changes**: Restart the shell to reload settings and QML components:
  ```bash
  qs -c noctalia-shell kill && qs -c noctalia-shell --daemonize
  ```

### 3. Window Control Buttons (GTK)
Controls window decorations (Minimize, Maximize, Close buttons) for GTK and Electron applications.
* **Configuration Path**: `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini`
  * Change button layout using `gtk-decoration-layout=menu:minimize,maximize,close`.

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

---

## 🐛 Troubleshooting

### GitHub Desktop won't open (AMD GPU + Wayland / Niri)

**Symptoms**: Running `github-desktop` prints only Fontconfig warnings and a radv notice — no window ever appears.

**Root cause**: GitHub Desktop (Electron/Chromium) tries to use hardware-accelerated EGL via ANGLE for its GPU subprocess. On AMD + Wayland this fails immediately:

```
eglCreateImage failed with 0x00003009
OzoneImageBacking::ProduceSkiaGanesh failed to create GL representation
GPU process exited unexpectedly: exit_code=8704
```

Chromium retries the GPU process a few times then gives up, and the app exits silently before creating any Wayland surface.

There are two things that can cause the app to not open:

1. **Stale `SingletonLock`** — A previous crashed session leaves lock files that block new launches. New invocations silently signal the dead process and exit immediately.
2. **EGL/ANGLE crash loop** — Even after the lock is cleared, the GPU process crashes on every start until a workaround is applied.

**Fix (one-time setup)**:

```bash
# 1. Kill any orphaned github-desktop processes
pkill -9 -f github-desktop 2>/dev/null

# 2. Remove stale singleton lock files
rm -f "$HOME/.config/GitHub Desktop/SingletonLock" \
      "$HOME/.config/GitHub Desktop/SingletonSocket" \
      "$HOME/.config/GitHub Desktop/SingletonCookie"

# 3. Clear corrupted GPU shader caches
rm -rf "$HOME/.config/GitHub Desktop/GPUCache" \
       "$HOME/.config/GitHub Desktop/DawnGraphiteCache" \
       "$HOME/.config/GitHub Desktop/DawnWebGPUCache" \
       "$HOME/.config/GitHub Desktop/Code Cache"

# 4. Patch the system launch wrapper to use SwiftShader (software GL)
#    This bypasses the broken hardware EGL path permanently
pkexec tee /usr/bin/github-desktop > /dev/null << 'EOF'
#!/bin/sh

/opt/github-desktop/github-desktop --use-gl=swiftshader "$@"
EOF
```

> **Why `--use-gl=swiftshader`?** SwiftShader is ANGLE's CPU-based OpenGL ES renderer bundled inside GitHub Desktop itself (`/opt/github-desktop/libvk_swiftshader.so`). It bypasses the system's EGL/DRM stack entirely, so it is unaffected by AMD driver or Wayland compositor version. Rendering performance is still perfectly adequate for a Git UI.

> **Note**: The patch to `/usr/bin/github-desktop` will be overwritten when the `github-desktop` package is updated via `pacman` / `yay`. Re-run step 4 after each package upgrade if the issue returns.
