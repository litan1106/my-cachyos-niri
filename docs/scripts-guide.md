# Scripts Guide

Reference for every script in [`scripts/`](../scripts/) — one-shot utilities for backing up dev-tool configs (Antigravity CLI, Claude Code, Zed), recovering the Antigravity IDE launcher, fixing an AMD GPU monitor-wake bug, and setting up SMB/mDNS network discovery. These are standalone; none are wired into `install.sh` or `apply.sh`, so run them directly when needed.

## Table of Contents

1. [antigravity-restore.sh](#antigravity-restoresh)
2. [backup-antigravity.sh](#backup-antigravitysh)
3. [backup-claude.sh](#backup-claudesh)
4. [backup-zed.sh](#backup-zedsh)
5. [fix-monitor-wake.sh](#fix-monitor-wakesh)
6. [setup_smb_discovery.sh](#setup_smb_discoverysh)

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
