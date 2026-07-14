# Antigravity 2.0 — IDE Recovery Guide (Linux)

## What Happened

Antigravity 2.0 ships its own `app.asar` into the **same installation directory** as the original IDE (`/opt/Antigravity/resources/`). Because Electron always loads `app.asar` first, the new file completely hijacks the launcher — opening Antigravity now opens 2.0, not the IDE.

On top of that, 2.0 changed its internal product name from **"Antigravity"** to **"Antigravity IDE"**, which causes VS Code (the engine underneath) to generate a brand-new, empty config folder. Your old settings are still on disk, just in the wrong folder.

| What | Old location (2.0 reads) | New location (IDE reads) |
|------|--------------------------|--------------------------|
| Settings & keymaps | `~/.config/Antigravity/` | `~/.config/Antigravity IDE/` |
| Extensions | `~/.antigravity/extensions/` | `~/.antigravity-ide/extensions/` |

---

## Quick Fix (Recommended)

Use the bundled script to do everything in one shot:

```bash
chmod +x ~/antigravity-restore.sh
~/antigravity-restore.sh all
```

This will:
1. Rename `app.asar` → `app.asar.bak` so the IDE launcher takes over again
2. Copy your settings/keymaps from the 2.0 profile into the IDE profile
3. Symlink your extensions folder so both profiles share the same extensions

---

## Manual Steps

### Step 1 — Restore the IDE launcher

The `app.asar.bak` rename disables 2.0 without uninstalling it:

```bash
sudo mv /opt/Antigravity/resources/app.asar \
        /opt/Antigravity/resources/app.asar.bak
```

To switch **back to 2.0** at any time:

```bash
sudo mv /opt/Antigravity/resources/app.asar.bak \
        /opt/Antigravity/resources/app.asar
```

### Step 2 — Migrate settings and keymaps

```bash
rsync -a ~/.config/Antigravity/ ~/.config/"Antigravity IDE"/
```

This copies themes, keybindings, `settings.json`, snippets, etc.

### Step 3 — Restore extensions

The cleanest approach is a symlink so you only maintain one extensions folder:

```bash
# Back up the empty destination first (optional)
mv ~/.antigravity-ide/extensions \
   ~/.antigravity-ide/extensions.bak.$(date +%Y%m%d)

# Create the symlink
ln -sfn ~/.antigravity/extensions \
        ~/.antigravity-ide/extensions
```

Both IDE and 2.0 profiles will now share the same installed extensions.

---

## Script Reference

```
~/antigravity-restore.sh [command]

Commands:
  menu      Interactive menu (default)
  toggle    Rename app.asar / app.asar.bak to switch modes
  migrate   Copy settings + symlink extensions
  all       toggle + migrate (recommended full fix)
  backup    Save a snapshot of configs before an update
  status    Show current state of all relevant files/folders
```

---

## Before the Next Auto-Update

Run a backup **before** updating Antigravity to avoid losing settings again:

```bash
~/antigravity-restore.sh backup
```

This saves:
- A full copy of `~/.config/Antigravity/` and `~/.config/Antigravity IDE/`
- The list of installed extensions from both profiles
- A SHA-256 hash of the current `app.asar` (so you can tell if it changed)

Backups are timestamped and written to `~/.antigravity-backup-YYYYMMDD_HHMMSS/`.

---

## Preventing the Issue on Future Updates

Antigravity auto-updates in the background. To protect yourself going forward:

1. **Pin the app.asar rename** — after any update, recheck:
   ```bash
   ls /opt/Antigravity/resources/app.asar
   ```
   If it reappears, the updater re-dropped a new 2.0 asar. Just rename it again.

2. **Watch for the backup** — if `app.asar.bak` disappears and `app.asar` exists alone again, an update ran. Run `~/antigravity-restore.sh all` to re-apply the fix.

3. **File permissions lock** (optional, aggressive) — prevent the updater from overwriting the file:
   ```bash
   sudo chattr +i /opt/Antigravity/resources/app.asar.bak
   ```
   Undo with `sudo chattr -i ...` when you deliberately want to update.

---

## Path Reference (Linux)

| Resource | Path |
|----------|------|
| Install dir | `/opt/Antigravity/` |
| Launcher binary (IDE) | `/usr/bin/antigravity-ide` |
| Launcher binary (2.0) | `/usr/bin/antigravity` |
| app.asar (2.0 hijack) | `/opt/Antigravity/resources/app.asar` |
| Settings — 2.0 profile | `~/.config/Antigravity/` |
| Settings — IDE profile | `~/.config/Antigravity IDE/` |
| Extensions — 2.0 profile | `~/.antigravity/extensions/` |
| Extensions — IDE profile | `~/.antigravity-ide/extensions/` |
