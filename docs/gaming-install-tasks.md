# Gaming Install Scripts — Task Plan (Battle.net + Lutris)

Port of omarchy's Battle.net (standalone umu-launcher + GE-Proton) and Lutris
gaming installers to this CachyOS + niri machine. **This is a plan for review —
nothing has been built yet.**

## Source of truth

omarchy files researched (`/home/litan/Projects/omarchy`):
- `bin/omarchy-install-gaming-battlenet`
- `bin/omarchy-install-gaming-lutris`
- `bin/omarchy-launch-battlenet`
- `bin/omarchy-remove-gaming-battlenet`
- `bin/omarchy-remove-gaming-lutris`
- `default/applications/battlenet.desktop`
- `default/hypr/apps/battlenet.lua`  (Hyprland — must be reworked for niri)

## Target machine facts (verified)

- CachyOS/Arch, `multilib` **enabled**.
- GPUs: AMD Navi 44 (RX 9060 XT, RDNA 4) + AMD Granite Ridge iGPU. **AMD only** —
  no NVIDIA, no Intel. lib32 drivers reduce to `lib32-vulkan-radeon` + `lib32-mesa`.
- WM: **niri** (window rules live in `niri/cfg/rules.kdl`, KDL syntax).
- Package manager: **`pacman`**. Verification confirmed every required package
  (umu-launcher, lib32-vulkan-radeon, lib32-mesa, lutris, wine-*, winetricks,
  python-protobuf) resolves in the CachyOS/Arch sync repos — none are AUR-only —
  so `sudo pacman -S --needed --noconfirm` for installs and `sudo pacman -Rns`
  for removals. No AUR helper (yay/paru) needed. `gum` available (2.0.2).
- `lutris` **already installed** (0.5.22) — Lutris script must be idempotent.
- `umu-launcher`, `wine-staging` **not** installed.
- Scripts live in `scripts/`, documented in `docs/scripts-guide.md`, and are
  standalone (not wired into `install.sh`/`apply.sh`).

## Decisions (confirmed)

1. **Prompts:** plain `read -r -p "... [y/N]"` — no `gum` dependency.
2. **Scope:** full set — both Battle.net and Lutris, all 9 tasks.
3. **Lutris shebang:** guard it — only patch `/usr/bin/lutris` if its shebang
   currently resolves to mise; no-op otherwise.
4. **Launcher location:** install script copies `launch-battlenet.sh` to
   `~/.local/bin/launch-battlenet`; `.desktop` `Exec=` is the bare command.
   The `.desktop` template is stored at `applications/battlenet.desktop` in-repo
   and copied to `~/.local/share/applications/` by the installer.

GPU confirmed: AMD RX 9060 XT (Navi 44, RDNA 4). lib32 = `lib32-vulkan-radeon`
+ `lib32-mesa`; no NVIDIA/Intel branches.

---

## Tasks

Each task is tagged with the intended executor:
- **[fast-worker]** = mechanical port/copy-edit (→ `Agent` w/ haiku model)
- **[deep-reasoner]** = needs judgment: dependency swaps, niri rule authoring,
  idempotency, GPU logic (→ `Agent` w/ opus model)

> Note: no `fast-worker`/`deep-reasoner` agents are defined in this repo or user
> config. They will be realized as `Agent` calls with model overrides.

### T1 — `scripts/install-gaming-battlenet.sh` [deep-reasoner]
Port `omarchy-install-gaming-battlenet`. Changes:
- Replace `omarchy-pkg-add umu-launcher` → `sudo pacman -S --needed --noconfirm umu-launcher`.
- Replace `omarchy-install-gaming-gpu-lib32` → inline AMD-only lib32 install
  (`lib32-vulkan-radeon lib32-mesa`).
- Keep the partial-prefix detection/wipe logic; use plain `read` confirm.
- Install `launch-battlenet.sh` → `~/.local/bin/launch-battlenet` (chmod +x), and
  copy `applications/battlenet.desktop` → `~/.local/share/applications/`.
- Keep `WINEPREFIX`/`PROTONPATH=GE-Proton`/`GAMEID`/`PROTON_VERB` env + installer
  download/launch flow unchanged.

### T2 — `scripts/launch-battlenet.sh` [fast-worker]
Port `omarchy-launch-battlenet` verbatim except rename (drop `omarchy-` prefix).
No omarchy helpers used — only env vars + `umu-run`. Keep `--with-mangohud` + help.

### T3 — `scripts/remove-gaming-battlenet.sh` [deep-reasoner]
Port `omarchy-remove-gaming-battlenet`. Changes:
- `omarchy-pkg-present umu-launcher` → `pacman -Q umu-launcher`.
- `omarchy-pkg-drop umu-launcher` → `sudo pacman -Rns --noconfirm umu-launcher`.
- Use plain `read` confirm. Keep GE-Proton/umu cleanup prompts.
- Remove `~/.local/bin/launch-battlenet` and
  `~/.local/share/applications/battlenet.desktop` to match T1's install locations.

### T4 — `scripts/install-gaming-lutris.sh` [deep-reasoner]
Port `omarchy-install-gaming-lutris`. Changes:
- `omarchy-pkg-add lutris umu-launcher wine-staging wine-mono wine-gecko winetricks python-protobuf`
  → `sudo pacman -S --needed --noconfirm ...` (same list). `--needed` makes it a no-op
  for the already-installed `lutris`.
- Replace `omarchy-install-gaming-gpu-lib32` → AMD-only lib32 (shared helper/snippet
  with T1 — keep them consistent).
- Guard the mise-python shebang `sed` per Decision 3.

### T5 — `scripts/remove-gaming-lutris.sh` [fast-worker]
Port `omarchy-remove-gaming-lutris`. Changes:
- `omarchy-pkg-drop ...` → `sudo pacman -Rns --noconfirm ...` (same package list).
- Keep the config/cache `rm -rf` list unchanged.

### T6 — `applications/battlenet.desktop` [fast-worker]
Copy omarchy's `battlenet.desktop` verbatim, but set `Exec=launch-battlenet`
(bare command; resolves via `~/.local/bin` installed by T1). Keep
`StartupWMClass=battle.net.exe`, `Icon=battle-net`.

### T7 — niri window rules for Battle.net [deep-reasoner]
Translate `default/hypr/apps/battlenet.lua` → niri KDL, appended to
`niri/cfg/rules.kdl`. omarchy matches Hyprland class `steam_app_battlenet`;
under niri/umu the `app-id` differs — must verify actual `app-id`/`title`
(via `niri msg windows` at runtime) before finalizing. Intended behavior:
float + center the launcher (~1280×800); drop decorations/blur/shadow on the
installer window. Flag that matcher strings need live verification.

### T8 — `docs/scripts-guide.md` entries [fast-worker]
Add sections for each new script following the existing doc format (Purpose,
Usage, What it does, Prerequisites, Warnings) and update the Table of Contents.

### T9 — verification pass [deep-reasoner]
`bash -n` syntax-check all new scripts; `shellcheck` if available; dry-review that
no `omarchy-*` helper references remain; confirm niri config still parses
(`niri validate` / `niri msg`). Do **not** run the installers unattended.

---

## Suggested execution order

T2, T5, T6 (mechanical, parallel) → T1, T3, T4 (depend on the AMD-lib32 snippet &
`.desktop` path decisions) → T7 (needs runtime app-id) → T8 → T9.
