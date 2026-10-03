# Scripts Guide

Reference for every script in [`scripts/`](../scripts/) — one-shot utilities for backing up dev-tool configs (Antigravity CLI, Claude Code, Zed), recovering the Antigravity IDE launcher, fixing an AMD GPU monitor-wake bug, setting up SMB/mDNS network discovery, and installing/managing gaming platforms (Battle.net, Lutris). These are standalone; none are wired into `install.sh` or `apply.sh`, so run them directly when needed.

## Table of Contents

1. [antigravity-restore.sh](#antigravity-restoresh)
2. [backup-antigravity.sh](#backup-antigravitysh)
3. [backup-claude.sh](#backup-claudesh)
4. [backup-zed.sh](#backup-zedsh)
5. [fix-monitor-wake.sh](#fix-monitor-wakesh)
6. [setup_smb_discovery.sh](#setup_smb_discoverysh)
7. [install-gaming-battlenet.sh](#install-gaming-battlenetsh)
8. [launch-battlenet.sh](#launch-battlenetsh)
9. [remove-gaming-battlenet.sh](#remove-gaming-battlenetsh)
10. [install-gaming-lutris.sh](#install-gaming-lutrissh)
11. [remove-gaming-lutris.sh](#remove-gaming-lutrissh)
12. [install-gpu-lib32.sh](#install-gpu-lib32sh)
13. [setup-local-bin-path.sh](#setup-local-bin-pathsh)

---

## antigravity-restore.sh

**Purpose**: Fixes the Antigravity 2.0 `app.asar` launcher hijack and migrates settings/extensions from the old "Antigravity" profile into the "Antigravity IDE" profile.

This script is the tool behind [`antigravity-recovery-guide.md`](antigravity-recovery-guide.md) — see that guide for the full explanation of *why* the hijack happens, manual step-by-step equivalents, and the path reference table. This section only covers invocation.

**Usage**:
```bash
./antigravity-restore.sh            # interactive menu (default)
./antigravity-restore.sh toggle     # toggle IDE ↔ 2.0 launcher only
./antigravity-restore.sh migrate    # migrate settings + extensions only
./antigravity-restore.sh all        # toggle + migrate (recommended)
./antigravity-restore.sh ide-only   # toggle + migrate + archive the 2.0 profile
./antigravity-restore.sh backup     # pre-update snapshot of configs
./antigravity-restore.sh status     # show current launcher/config state
```

**What it does** (per command):
- `toggle` — renames `/opt/Antigravity/resources/app.asar` ↔ `app.asar.bak` (requires `sudo`) to switch which launcher is active. If already in IDE mode, asks `[y/N]` before switching back to 2.0.
- `migrate` — copies `~/.config/Antigravity/` → `~/.config/Antigravity IDE/` (via `rsync` if available, else `cp -r`), then symlinks `~/.antigravity-ide/extensions` → `~/.antigravity/extensions` (backing up any existing non-empty destination first as `extensions.bak.<timestamp>`).
- `ide-only` — runs `toggle` + `migrate`, then **moves** (not copies) `~/.config/Antigravity/` to a timestamped archive dir, making the IDE profile the sole active one.
- `backup` — snapshots both config dirs, the extension lists/manifests of both profiles, and a SHA-256 of `app.asar` into `~/.antigravity-backup-<timestamp>/`.
- `status` — prints launcher mode and the state of all relevant files/dirs; no changes made.

**Prerequisites**: Antigravity installed at `/opt/Antigravity`; `sudo` access for the `toggle` step; `rsync` recommended (falls back to `cp`).

**Warnings**:
- `toggle` and `ide-only` modify files under `/opt/Antigravity/resources` with `sudo` — a bad state (`app.asar` and `app.asar.bak` both present, or neither) is detected but not auto-repaired.
- `ide-only` moves the 2.0 config dir away (not a copy); it prints the `mv` command needed to undo it.
- Unknown commands print usage and exit 1.

---

## backup-antigravity.sh

**Purpose**: Backs up and restores **Antigravity CLI** (`agy`) configuration — settings, status line, plugins, skills, MCP config, hooks — via zip archive or a secret GitHub Gist. This is distinct from `antigravity-restore.sh`: that script fixes the Antigravity IDE app launcher/profile, this one backs up the separate Antigravity CLI tool's config directory. See also [`agy-artifact-custom-command-walkthrough.md`](agy-artifact-custom-command-walkthrough.md) for what the `plugins/` and `skills/` content actually contains.

**Usage**:
```bash
./backup-antigravity.sh                 # create zip backup (default)
./backup-antigravity.sh --zip   | -z    # create zip in ~/backups/antigravity/
./backup-antigravity.sh --gist  | -g    # upload to a secret GitHub Gist
./backup-antigravity.sh --both  | -b    # zip AND gist
./backup-antigravity.sh --restore | -r <zip>   # restore from a zip backup
./backup-antigravity.sh --diff    | -d <zip>   # diff a backup against current config
./backup-antigravity.sh --list    | -l  # list existing backups
./backup-antigravity.sh --help    | -h  # show help
```

**What gets backed up**: `settings.json`, `statusline.sh`, `plugins/`, `mcp_config.json`, `hooks.json` (always checked), plus `skills/` (optional). Missing targets are silently skipped.

**Not backed up**: `brain/`, `cache/`, `log/`, `conversations/`, `builtin/`, `bin/`, `implicit/`, `knowledge/` — machine-specific, transient, or auto-restored on install.

**What it does**:
- `--zip` — collects existing targets, prints a summary (file/plugin counts), and zips them (relative paths) into `~/backups/antigravity/antigravity-backup-<timestamp>.zip`, excluding `.DS_Store`, dotfiles, `.log`, `__pycache__`, `node_modules`. Lists the 5 most recent backups if more than one exists.
- `--gist` — same collection, but flattens directory structure with `__` separators (e.g. `plugins__artifact-manager__plugin.json`) into a temp dir, then uploads via `gh gist create`. Requires `gh auth login` beforehand.
- `--restore <zip>` — previews the zip contents, asks `[y/N]` confirmation, takes a **pre-restore safety zip** (`antigravity-pre-restore-<timestamp>.zip`) of the current config, then `unzip -o`'s into `AGY_CONFIG_DIR` and re-applies `chmod +x` to any `.sh` files.
- `--diff <zip>` — extracts the backup to a temp dir and reports `MISSING` (in backup, not current), `CHANGED` (with a unified diff, first 20 lines), and `NEW` (in current, not backup) — no files are modified.
- `--list` — lists all `antigravity-*.zip` files in the backup dir, newest first.

**Prerequisites**: `zip` (for `--zip`/`--both`/`--restore`/`--diff`), `unzip` (for `--restore`/`--diff`), `gh` CLI authenticated via `gh auth login` (for `--gist`/`--both`). Exits 1 if the Antigravity CLI config dir doesn't exist, or if there's nothing to back up.

**Environment variables**:
| Variable | Default | Purpose |
|---|---|---|
| `AGY_CONFIG_DIR` | `~/.gemini/antigravity-cli` | Source config directory |
| `BACKUP_DIR` | `~/backups/antigravity` | Where zips are written |

**Warnings**:
- `--restore` **overwrites** existing config files in place (after confirmation and an automatic safety backup).
- Gist backups flatten directory structure — restoring from a cloned Gist requires manually un-flattening `__`-separated filenames, or using `--restore` with a zip instead (recommended).

---

## backup-claude.sh

**Purpose**: Backs up and restores Claude Code configuration (`~/.claude`) — instructions, agents, skills, rules, hooks, MCP configs — via zip or GitHub Gist. Same design as `backup-antigravity.sh` and `backup-zed.sh` (see that section above for the shared zip/gist/restore/diff mechanics); this section covers only what's Claude-specific.

**Usage**:
```bash
./backup-claude.sh                    # create zip backup (default)
./backup-claude.sh --zip    | -z      # create zip in ~/backups/claude/
./backup-claude.sh --gist   | -g      # upload to a secret GitHub Gist
./backup-claude.sh --both   | -b      # zip AND gist
./backup-claude.sh --restore| -r <zip>   # restore from a zip backup
./backup-claude.sh --list   | -l      # list existing backups
./backup-claude.sh --help   | -h      # show help
```

**What gets backed up**: `CLAUDE.md`, `RTK.md`, `settings.json`, `keybindings.json`, `agents/`, `skills/`, `rules/`, `hooks/`, `mcp-configs/`. Missing targets are skipped.

**Not backed up**: `.credentials.json` (OAuth tokens/secrets), `projects/`, `sessions/` (conversation transcripts), `history.jsonl`, `cache/`, `telemetry/`, `plugins/` (marketplace cache), `downloads/`, `paste-cache/`, `file-history/`, `shell-snapshots/`, `session-env/`, and its own `backups/` output dir.

**What it does**: Identical flow to `backup-antigravity.sh` — `--zip` creates `~/backups/claude/claude-backup-<timestamp>.zip`; `--gist` flattens with `__` and uploads via `gh gist create`; `--restore <zip>` previews contents, asks `[y/N]`, takes a `claude-pre-restore-<timestamp>.zip` safety backup, then `unzip -o`'s over `CLAUDE_CONFIG_DIR`; `--list` shows existing backups newest-first. (No `--diff` mode is provided for this script, unlike `backup-antigravity.sh`.)

**Prerequisites**: `zip`, `unzip`, `gh` (authenticated) for the Gist path. Exits 1 if `~/.claude` doesn't exist.

**Environment variables**:
| Variable | Default | Purpose |
|---|---|---|
| `CLAUDE_CONFIG_DIR` | `~/.claude` | Source config directory |
| `BACKUP_DIR` | `~/backups/claude` | Where zips are written |

**Warnings**:
- `--restore` overwrites existing files in `~/.claude` after confirmation (safety backup is automatic).
- Restart Claude Code after a restore to pick up the new config.
- Never commit or share zip/Gist output without checking it doesn't include `.credentials.json` — it's excluded by design, but verify if you customize `BACKUP_TARGETS`.

---

## backup-zed.sh

**Purpose**: Backs up and restores Zed editor configuration (`~/.config/zed`) — settings, keymap, tasks, debug config, themes, extensions, snippets — via zip or GitHub Gist. Same shared design as `backup-antigravity.sh` (see above).

**Usage**:
```bash
./backup-zed.sh                    # create zip backup (default)
./backup-zed.sh --zip    | -z      # create zip in ~/backups/zed/
./backup-zed.sh --gist   | -g      # upload to a secret GitHub Gist
./backup-zed.sh --both   | -b      # zip AND gist
./backup-zed.sh --restore| -r <zip>   # restore from a zip backup
./backup-zed.sh --list   | -l      # list existing backups
./backup-zed.sh --help   | -h      # show help
```

**What gets backed up**: `settings.json`, `keymap.json`, `tasks.json`, `debug.json`, `themes/`, `extensions/`, `snippets/`.

**Not backed up**: `db/` (internal database), `copilot/` (auth tokens), `node/` (bundled runtime), `logs/`, `languages/` (downloaded LSP binaries), `*_server/` state dirs.

**What it does**: Same flow as `backup-antigravity.sh` — `--zip` creates `~/backups/zed/zed-backup-<timestamp>.zip`; `--gist` flattens with `__` and uploads via `gh gist create`; `--restore <zip>` previews, confirms `[y/N]`, takes a `zed-pre-restore-<timestamp>.zip` safety backup, then `unzip -o`'s over `ZED_CONFIG_DIR`; `--list` shows backups newest-first. No `--diff` mode.

**Prerequisites**: `zip`, `unzip`, `gh` (authenticated) for Gist. Exits 1 if `~/.config/zed` doesn't exist.

**Environment variables**:
| Variable | Default | Purpose |
|---|---|---|
| `ZED_CONFIG_DIR` | `~/.config/zed` (Linux) | Source config directory — override to `~/Library/Application Support/Zed` on macOS |
| `BACKUP_DIR` | `~/backups/zed` | Where zips are written |

**Warnings**:
- `--restore` overwrites existing files in `~/.config/zed` after confirmation (safety backup is automatic).
- Restart Zed after a restore to pick up the new config.

---

## fix-monitor-wake.sh

**Purpose**: Fixes a black-screen-on-wake bug affecting AMD RX 9060 XT (RDNA 4 / navi48) GPUs over HDMI under niri/Wayland, caused by an `amdgpu` `REG_WAIT` timeout on `optc401_disable_crtc` during DPMS off/on.

**Usage**:
```bash
sudo ./fix-monitor-wake.sh
```
(The script invokes `sudo` internally for the privileged steps, but you'll be prompted for your password regardless of how it's launched.)

**What it does** (runs with `set -e`, so it stops on the first failure):
1. Writes `/etc/modprobe.d/amdgpu.conf` with `options amdgpu psr=0 runpm=0` — disables Panel Self Refresh (`psr=0`, which causes the CRTC-disable hang on HDMI) and GPU runtime power management (`runpm=0`, which prevents the deep-idle state that triggers the timeout).
2. Rebuilds the initramfs with `sudo mkinitcpio -P` so the module parameters apply on next boot.
3. Verifies the parameters are picked up via `modprobe --showconfig` (falls back to grepping the conf file directly).
4. Prints a reminder to reboot, plus the commands to verify post-reboot (`cat /sys/module/amdgpu/parameters/psr` and `.../runpm`, both should read `0`).

**Prerequisites**: `sudo` access; `mkinitcpio`-based system (CachyOS/Arch); AMD `amdgpu` driver in use.

**Warnings**:
- **A reboot is required** — the fix does not take effect until the machine restarts.
- Disabling PSR and GPU runtime PM system-wide may slightly increase idle power draw — this is a deliberate tradeoff to avoid the wake hang, not a general-purpose tuning change.
- Overwrites `/etc/modprobe.d/amdgpu.conf` wholesale (uses a heredoc, not an append) — if you already have custom `amdgpu` module options in that file, back it up first.

---

## setup_smb_discovery.sh

**Purpose**: Configures a CachyOS/Arch machine to mimic Ubuntu's out-of-the-box SMB/network-discovery experience — Samba file sharing, mDNS (`.local` hostname resolution and Bonjour/AFP-style discovery for Apple devices), and WSDD (discovery for Windows 10/11 clients), plus matching firewall rules.

**Usage**:
```bash
sudo ./setup_smb_discovery.sh
```
Exits 1 immediately if not run as root.

**What it does**:
1. Installs `samba`, `avahi`, `nss-mdns`, `wsdd` via `pacman -S --needed --noconfirm`.
2. Edits `/etc/nsswitch.conf`, inserting `mdns_minimal [NOTFOUND=return]` before `resolve`/`dns` in the `hosts:` line (skipped if already present).
3. **Backs up** any existing `/etc/samba/smb.conf` to `/etc/samba/smb.conf.bak`, then writes a new Ubuntu-style `smb.conf` with `[global]`, `[homes]`, `[printers]`, and `[print$]` sections tuned for high-throughput streaming (large SMB2/3 read/write/trans sizes, `TCP_NODELAY`, `use sendfile`), multi-channel SMB3, and macOS/iPad compatibility (`vfs objects = catia fruit streams_xattr`, Apple metadata/AFP settings).
4. Writes `/etc/avahi/services/samba.service` to advertise the `_smb._tcp` service over mDNS.
5. Opens firewall ports via `ufw`: `139/tcp`, `445/tcp` (Samba), `mdns`, `3702/udp` + `5357/tcp` (WSDD), then `ufw reload`.
6. Enables and starts `smb.service`, `nmb.service`, `avahi-daemon.service`, `wsdd.service`, and `ufw.service`.
7. Prints a completion message and suggests running `testparm` to validate the new `smb.conf`.

**Prerequisites**: Root/`sudo`; `pacman`-based system; `ufw` installed (the script assumes it and does not check).

**Warnings**:
- **Overwrites `/etc/samba/smb.conf` and `/etc/avahi/services/samba.service` unconditionally** — the old `smb.conf` is preserved as `.bak`, but the Avahi service file is not backed up.
- Does not check whether `ufw` is installed/enabled before calling `ufw allow`/`ufw reload` — if you don't use `ufw`, adapt the firewall section to your setup (`firewalld`, `nftables`, etc.) before running.
- Sets `security = user` and `map to guest = bad user` — shares fall back to guest access for unrecognized users; review `[homes]`/`[printers]` permissions if this is a multi-user or untrusted-network machine.
- Runs `pacman -S --noconfirm`, so it will install/upgrade packages without prompting.

---

## install-gaming-battlenet.sh

**Purpose**: Installs Battle.net as a standalone Windows application via umu-launcher and GE-Proton, without Steam, Lutris, or Heroic. The script downloads the official Battle.net installer, sets up a Wine prefix at `~/Games/battlenet`, and installs a launch script to `~/.local/bin/launch-battlenet` with a desktop entry.

**Usage**:
```bash
./install-gaming-battlenet.sh
```

**What it does**:
1. Installs `umu-launcher` via `pacman` (it's in the `cachyos` sync repo).
2. Auto-detects the GPU vendor(s) via `lspci` and installs the matching lib32 graphics drivers through the shared [install-gpu-lib32.sh](#install-gpu-lib32sh) helper — `lib32-vulkan-radeon` (AMD), `lib32-vulkan-intel` (Intel), and/or `lib32-nvidia-utils` (NVIDIA), plus `lib32-mesa` always.
3. Checks for a partial/failed Battle.net installation at `~/Games/battlenet` and prompts to wipe it if detected (the installer is not idempotent and cannot resume).
4. Creates the Wine prefix directory if it doesn't exist.
5. Downloads the official Battle.net installer from Blizzard's server into `~/.cache/cachyos-gaming/Battle.net-Setup.exe`.
6. Launches the installer via `umu-run` in the background, which opens the Battle.net setup wizard (standard Windows installer; click through normally).
7. Installs the `launch-battlenet` script to `~/.local/bin/launch-battlenet` (requires `~/.local/bin` on `$PATH`).
8. Installs a desktop entry to `~/.local/share/applications/battlenet.desktop` and updates the desktop database.

**Prerequisites**: `sudo` access (packages install via `pacman` from the CachyOS/Arch sync repos — multilib must be enabled for the lib32 drivers, which is the CachyOS default); any AMD/Intel/NVIDIA GPU (the correct lib32 driver is auto-detected); `~/.local/bin` must be on `$PATH` for the launcher command to resolve — run [setup-local-bin-path.sh](#setup-local-bin-pathsh) once.

**Warnings**:
- The installer runs in the background and logs to `/tmp/battlenet-installer.log` — it does **not** block the script's completion. The script prints instructions for launching Battle.net after installation finishes (which may take several minutes).
- If a partial prefix is detected (directory exists but `Launcher.exe` is missing), the script will ask for confirmation to wipe it before proceeding. This is necessary because Battle.net's installer cannot resume from a partial state.
- GE-Proton is auto-fetched and cached by umu-launcher on first launch; no manual download is needed.
- A niri window rule for Battle.net lives in `niri/cfg/rules.kdl` — its matchers may need verification after the first launch to ensure proper window handling.

---

## launch-battlenet.sh

**Purpose**: Launches the installed Battle.net client via umu-launcher and GE-Proton, with optional MangoHud performance overlay for in-game FPS monitoring and logging.

**Usage**:
```bash
launch-battlenet                 # standard launch
launch-battlenet --with-mangohud # launch with MangoHud overlay
launch-battlenet --help          # show help
```

**What it does**:
1. Verifies that Battle.net is installed at `~/Games/battlenet` (checks for `Launcher.exe`).
2. Sets up Wine/Proton environment variables (`WINEPREFIX`, `PROTONPATH=GE-Proton`, `GAMEID=umu-battlenet`, `PROTON_VERB=run`).
3. If `--with-mangohud` is passed, adds `MANGOHUD=1` to the environment to enable the MangoHud overlay.
4. Invokes `umu-run` with the Battle.net launcher executable.

**Prerequisites**: Battle.net must be installed via `install-gaming-battlenet.sh` first; `umu-launcher` must be installed; `~/.local/bin` must be on `$PATH`.

**Warnings**:
- MangoHud (when enabled) displays an FPS overlay and logs performance metrics to `~/mangohud/` as CSV files. Toggle it in-game with `Shift_L+F2`.
- The launcher script does not validate GE-Proton availability — umu-launcher will fetch it on first use if missing.

---

## remove-gaming-battlenet.sh

**Purpose**: Uninstalls Battle.net, its Wine prefix, all installed games, and associated desktop entries. Optionally removes umu-launcher and cached GE-Proton runtimes if they are not needed.

**Usage**:
```bash
./remove-gaming-battlenet.sh
```

**What it does**:
1. Kills any running processes tied to the Battle.net prefix (`~/Games/battlenet`).
2. Removes the Wine prefix directory at `~/Games/battlenet` (all installed games and Battle.net client).
3. Removes the launcher script at `~/.local/bin/launch-battlenet`.
4. Removes the desktop entry at `~/.local/share/applications/battlenet.desktop` and updates the desktop database.
5. Removes the cached installer at `~/.cache/cachyos-gaming/Battle.net-Setup.exe`.
6. Prompts whether to also remove `umu-launcher` (used only by Battle.net in this setup).
7. Prompts whether to also remove GE-Proton runtimes cached at `~/.local/share/Steam/compatibilitytools.d/GE-Proton*` and `~/.local/share/umu`.

**Prerequisites**: None; the script handles cases where Battle.net or its components are not fully installed.

**Warnings**:
- This script **permanently deletes** the Battle.net prefix and all installed games — there is no undo.
- Prompts are non-interactive `[y/N]` (default is No) for `umu-launcher` and GE-Proton removal; answer `y` or `Y` to proceed.

---

## install-gaming-lutris.sh

**Purpose**: Installs Lutris gaming platform along with Wine and runtime dependencies (wine-staging, wine-mono, wine-gecko, winetricks), AMD lib32 graphics drivers, and umu-launcher. Also patches the Lutris shebang for machines where `python3` is managed by mise (a version manager), ensuring Lutris can import its Python modules correctly.

**Usage**:
```bash
./install-gaming-lutris.sh
```

**What it does**:
1. Installs Lutris and its dependencies via `pacman` (all in the CachyOS/Arch sync repos; `--needed` makes the already-installed `lutris` a no-op): `lutris`, `umu-launcher`, `wine-staging`, `wine-mono`, `wine-gecko`, `winetricks`, `python-protobuf`.
2. Auto-detects the GPU vendor(s) via `lspci` and installs the matching lib32 graphics drivers through the shared [install-gpu-lib32.sh](#install-gpu-lib32sh) helper — `lib32-vulkan-radeon` (AMD), `lib32-vulkan-intel` (Intel), and/or `lib32-nvidia-utils` (NVIDIA), plus `lib32-mesa` always.
3. **Detects mise-managed Python**: Checks if Lutris's shebang line points to `#!/usr/bin/env python3` and if `python3` resolves through a mise shim. If detected, patches the shebang in `/usr/bin/lutris` to `#!/bin/python3` (the system Python) instead, bypassing the mise shim so the lutris module can be imported.
4. Launches Lutris in the background, which begins auto-fetching DXVK and VKD3D runtimes (watch the status bar at the bottom of the Lutris window).
5. Prints instructions to add or install games once the runtimes finish downloading.

**Prerequisites**: `sudo` access (packages install via `pacman`; multilib must be enabled for the lib32 drivers — the CachyOS default); any AMD/Intel/NVIDIA GPU (the correct lib32 driver is auto-detected via the shared [install-gpu-lib32.sh](#install-gpu-lib32sh) helper).

**Environment variables**: None explicitly used, but the script detects the presence of `mise` in the `python3` path.

**Warnings**:
- The shebang patch only runs if `python3` is detected as mise-managed; on systems without mise, this step is skipped.
- Lutris auto-fetches runtimes in the background on first launch — the process runs in parallel with the script's completion, so you may need to wait for the status bar to show 100% before launching games.
- The script opens Lutris immediately after install; you can close it and re-open later if needed.

---

## remove-gaming-lutris.sh

**Purpose**: Uninstalls Lutris and all associated gaming dependencies (Wine, winetricks, umu-launcher) along with configuration and cache directories.

**Usage**:
```bash
./remove-gaming-lutris.sh
```

**What it does**:
1. Checks which of the following packages are installed and removes them via `sudo pacman -Rns --noconfirm`: `lutris`, `wine-staging`, `wine-mono`, `wine-gecko`, `winetricks`, `python-protobuf`, `umu-launcher`.
2. Removes Lutris configuration and cache directories: `~/.config/lutris`, `~/.local/share/lutris`, `~/.cache/lutris`.
3. Removes umu-launcher and Wine directories: `~/.local/share/umu`, `~/.cache/umu`, `~/.wine`, `~/.cache/wine`, `~/.cache/winetricks`.
4. Prints a confirmation message listing what was removed.

**Prerequisites**: `pacman` (Arch/CachyOS); `sudo` access.

**Warnings**:
- This script **permanently deletes** all Lutris configurations, game prefixes, installed games, and Wine caches — there is no undo.
- Runs `pacman -Rns --noconfirm`, so package removal is automatic without prompts.

---

## install-gpu-lib32.sh

**Purpose**: Detects the GPU vendor(s) via `lspci` and installs the matching 32-bit (lib32) graphics drivers needed for Wine/Proton gaming. Shared helper sourced by both gaming installers so the same scripts work on AMD, Intel, and NVIDIA machines — including multi-GPU setups (e.g. an Intel iGPU + NVIDIA dGPU laptop). Can also be run standalone.

**Usage**:
```bash
./install-gpu-lib32.sh        # standalone
# or, from another script:
source ./install-gpu-lib32.sh && install_gpu_lib32
```

**What it does**:
1. Installs `pciutils` if `lspci` is missing.
2. Always queues `lib32-mesa` (shared 32-bit OpenGL/Vulkan loader bits).
3. Adds `lib32-vulkan-radeon` if an AMD GPU is found, `lib32-vulkan-intel` for Intel, and `lib32-nvidia-utils` for NVIDIA (proprietary driver — swap for `lib32-vulkan-nouveau` on a nouveau-only setup).
4. Deduplicates the list and installs it with `sudo pacman -S --needed --noconfirm`.
5. If no AMD/Intel/NVIDIA GPU is identified (e.g. a VM), installs `lib32-mesa` only and prints a warning to install the vendor driver manually.

**Prerequisites**: `sudo` access; `[multilib]` enabled in `/etc/pacman.conf` (CachyOS default). The AMD matcher is anchored (`amd` / `advanced micro devices` / `ati technologies`) so it does not false-match the "ati" substring inside "VGA comp**ati**ble controller".

**Warnings**:
- Assumes the proprietary NVIDIA driver for NVIDIA GPUs; nouveau users should edit the script.

---

## setup-local-bin-path.sh

**Purpose**: Puts `~/.local/bin` on `PATH` the best-practice way for a systemd-managed niri session (the model CachyOS uses: SDDM → `niri-session` → `systemd --user`). Without this, user-installed launchers such as `launch-battlenet` don't resolve by name, because CachyOS/Arch only add `/usr/local/bin` to `PATH` by default.

> `install-gaming-battlenet.sh` **sources and runs this automatically** (it's the only installer that puts a command in `~/.local/bin`), so you normally don't need to run it by hand. Run it standalone only to add the `--with-bashrc` fallback, or on a machine where you want `~/.local/bin` on PATH independent of the gaming scripts.

**Usage**:
```bash
./setup-local-bin-path.sh                # environment.d only (niri + GUI + in-niri terminals)
./setup-local-bin-path.sh --with-bashrc  # also add a ~/.bashrc fallback for TTY/SSH sessions
```

**What it does**:
1. Ensures `~/.local/bin` exists.
2. Warns if `/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator` is missing (meaning the session isn't systemd-managed and `environment.d` won't be honored).
3. Writes `~/.config/environment.d/10-local-bin.conf` with `PATH=${HOME}/.local/bin:${PATH}`. This is read by the systemd user manager at login and reaches niri, every app launched from the menu, and terminals opened inside niri (they inherit the session environment). Overwriting is idempotent — the file *is* the desired state.
4. With `--with-bashrc`, appends a duplicate-guarded `export PATH` to `~/.bashrc` for bare TTY / SSH shells, which don't inherit the graphical session environment.

**Prerequisites**: A systemd-managed Wayland session (niri via `niri-session`, the CachyOS default). `bash` for the optional `--with-bashrc` fallback.

**Warnings**:
- `environment.d` applies on the **next re-login** (the user manager reads it at session start). For the current terminal, run `export PATH="$HOME/.local/bin:$PATH"` once.
- Idempotent and safe to re-run, including on a second machine.
