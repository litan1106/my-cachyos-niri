# Migrate CachyOS Niri to Hyprland and Noctalia v5

This guide moves an existing account using this repository's CachyOS Niri and Noctalia v4 setup to the CachyOS Hyprland profile with Noctalia v5. The migration keeps the CachyOS appearance and adds this repository's shortcuts. Use the optional layout flag only if you want the ported dock and launcher layout.

The migration has two stages. **Prepare** backs up the old configuration, releases the known Qt 6.11 package hold, installs the Hyprland profile, and stages the new user configuration. **Finish** runs only after you have logged into a working Hyprland session; it then retires Niri and the old shell packages.

## 1. Get the current repository on the Niri machine

Open a terminal as the desktop user. Do not run the migration script itself with `sudo`. Use a copy of this repository that contains `scripts/migrate-niri-to-hypr.sh` and `hypr/config/my_desktop.lua`. Once these changes have been published, you can clone it with:

```bash
git clone https://github.com/litan1106/my-cachyos-niri.git
cd my-cachyos-niri
```

If you already have the repository, update your local copy through your normal Git workflow, then run the commands below from its root. Save work in other applications before the package update.

## 2. Preview preparation

```bash
./scripts/migrate-niri-to-hypr.sh prepare --dry-run
```

Read the proposed backup path and package operation. The script recognizes the exact Qt 6.11 `IgnorePkg` line used by the old setup. If it finds a different active Qt hold or mixed Noctalia v4/v5 files, it stops for inspection instead of guessing how to change them. A dry run makes no changes.

The default keeps CachyOS's Noctalia layout. To request the optional bottom taskbar, top dock, and grid launcher, use `prepare --dry-run --with-layout` here and `prepare --with-layout` in the next step.

## 3. Prepare the migration

```bash
./scripts/migrate-niri-to-hypr.sh prepare
```

Enter your sudo password when prompted and review any `pacman` transaction before accepting it. Preparation performs these actions in order:

1. Copies the existing Niri, Noctalia, Quickshell, and Hyprland user configuration, when present, into a timestamped backup. It also backs up `/etc/pacman.conf`.
2. Comments out the recognized Qt 6.11 `IgnorePkg` line, if it is active.
3. Runs `sudo pacman -Syu --needed cachyos-hypr-noctalia`, allowing Qt and the rest of the system to update together.
4. Moves the old Noctalia v4 config aside and applies this repository's Hyprland shortcuts. If the known qBittorrent 5.2.4 desktop launcher override exists, it moves that aside too; it leaves the old binary alone.

The script prints the backup location. The same command can be rerun after an interrupted package transaction. Do not run `finish` yet.

## 4. Handle an existing SDDM autologin

If `prepare` reports SDDM autologin, inspect the file it names **before logging out**. An assignment such as `Session=niri.desktop` can bypass the session chooser and return you to Niri. Edit that file with `sudoedit` and either set `Session=hyprland-uwsm.desktop` or temporarily disable its autologin settings. Keep a backup of the file before editing it.

If there is no existing autologin, simply select **Hyprland (UWSM)** at the login screen in the next step. The migration script does not enable autologin during preparation.

## 5. Log into and check Hyprland

Reboot or log out, then select **Hyprland (UWSM)** in the display manager. Open a terminal in the new session and run:

```bash
printf '%s\n' "$XDG_CURRENT_DESKTOP"
hyprctl configerrors
noctalia config validate
noctalia msg status
```

The desktop name should include `Hyprland`, `hyprctl configerrors` should print no errors, Noctalia validation should succeed, and the shell should respond to `msg status`. Test the app launcher (Super+Space), session menu (Super+Escape), file manager, browser, lock screen, notifications, and any applications you depend on. For qBittorrent, launch the system application and check that it opens.

If the session does not work, leave Niri installed. Return to the login screen or a TTY, inspect the printed backup path, and correct the Hyprland or Noctalia problem before continuing. The Niri package and its config remain available until `finish` succeeds.

## 6. Preview and finish removal

From the working Hyprland session, return to the repository root and run:

```bash
./scripts/migrate-niri-to-hypr.sh finish --dry-run
./scripts/migrate-niri-to-hypr.sh finish
```

`finish` checks the live Hyprland session, Hyprland config, and Noctalia. It refuses to remove Niri while active SDDM autologin still selects a Niri session. It moves the old Niri and Quickshell config into the backup, then runs `sudo pacman -R` for installed `niri`, `noctalia-shell`, and `noctalia-qs` packages. It does not use recursive orphan removal.

To enable SDDM autologin for this user **after Hyprland passes these checks**, preview and run the optional form instead:

```bash
./scripts/migrate-niri-to-hypr.sh finish --dry-run --enable-autologin
./scripts/migrate-niri-to-hypr.sh finish --enable-autologin
```

The autologin option requires an active SDDM service and a Hyprland UWSM session entry. It stops if another SDDM file has conflicting autologin settings. `finish` is safe to rerun after an interruption.

## 7. Verify the result

```bash
pacman -Q cachyos-hypr-noctalia hyprland noctalia
for package in niri noctalia-shell noctalia-qs; do
    if pacman -Qq "$package" >/dev/null 2>&1; then
        printf 'Still installed: %s\n' "$package"
    else
        printf 'Removed: %s\n' "$package"
    fi
done
hyprctl configerrors
noctalia config validate
```

Each old package should print `Removed`. If you changed SDDM autologin, reboot once more and confirm it opens the Hyprland session.

Set monitor assignments in `~/.config/hypr/config/variables.lua`, monitor modes and scale in `monitors.lua`, and keyboard/pointer settings in `inputs.lua`. Open Noctalia settings with Super+Z for local app pins, wallpaper, and widgets. See the [README](../README.md#customize-the-setup) for the shortcut table and configuration workflow.

## Find or restore a backup

The migration keeps a timestamped run directory under `${XDG_STATE_HOME:-$HOME/.local/state}/cachyos-hypr-migration/`. The `active` file contains the path used for the current migration:

```bash
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/cachyos-hypr-migration"
backup_dir="$(<"$state_root/active")"
printf '%s\n' "$backup_dir"
```

It contains `user-config/` copies of files that existed before preparation, `system/pacman.conf`, and `retired/` directories moved aside during migration. To restore one user config, first move any current version out of the way, then copy the corresponding backup. For example, only if `~/.config/niri` is absent:

```bash
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
test ! -e "$config_dir/niri" && cp -a "$backup_dir/user-config/niri" "$config_dir/niri"
```

Inspect saved files before restoring them. Compare the saved `system/pacman.conf` with the current `/etc/pacman.conf`; do not replace the whole current file just to reinstate an old Qt hold. After `finish`, returning to Niri also requires reinstalling its packages and choosing its session again.
