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
├── install.sh          ← One-shot interactive installer
└── README.md
```

---

## 🛠️ Install (fresh machine)

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

The installer will:
1. Verify Arch/CachyOS system
2. Detect or install `yay` (AUR helper)
3. Sync **official CachyOS** packages via `pacman`
4. Sync **custom AUR** packages via `yay`
5. Deploy `niri/` configs to `~/.config/niri/` (with timestamped backup)
6. Deploy `gtk-3.0/` and `gtk-4.0/` to `~/.config/` (with backup)
7. Optionally copy everything to `/etc/skel/` for new system users
8. Live-reload Niri if it is running

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

## 💾 Saving Your Changes

After modifying any config:

```bash
cd ~/dotfiles

# Pull in live changes you made to configs
cp ~/.config/niri/config.kdl          niri/
cp ~/.config/niri/cfg/*               niri/cfg/
cp ~/.config/gtk-3.0/settings.ini     gtk-3.0/
cp ~/.config/gtk-4.0/settings.ini     gtk-4.0/

# Commit and push
git add .
git commit -m "feat: describe your changes here"
git push origin main
```
