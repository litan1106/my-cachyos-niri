#!/usr/bin/env bash

set -euo pipefail

DRY_RUN=false
case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
        echo "Usage: ./scripts/setup-lg-ultrawide.sh [--dry-run]"
        exit 0 ;;
    *) echo "Usage: ./scripts/setup-lg-ultrawide.sh [--dry-run]" >&2; exit 2 ;;
esac
if (( $# > 1 )); then
    echo "Usage: ./scripts/setup-lg-ultrawide.sh [--dry-run]" >&2
    exit 2
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
MONITORS_FILE="$CONFIG_DIR/hypr/config/monitors.lua"
NOCTALIA_DIR="$CONFIG_DIR/noctalia"
NOCTALIA_FILE="$NOCTALIA_DIR/zzzz-lg-ultrawide.toml"

[[ -f "$MONITORS_FILE" ]] || { echo "Missing $MONITORS_FILE; install the Hyprland profile first." >&2; exit 1; }
[[ -f "$NOCTALIA_DIR/config.toml" ]] || { echo "Missing $NOCTALIA_DIR/config.toml; install the Noctalia profile first." >&2; exit 1; }
for command in hyprctl noctalia luac python3; do
    command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }
done

MONITOR_NAME="$(hyprctl monitors -j | python3 -c '
import json, sys
monitors = json.load(sys.stdin)
for monitor in monitors:
    if monitor.get("description", "").startswith("LG Electronics LG HDR WQHD"):
        print(monitor["name"])
        break
')"
[[ -n "$MONITOR_NAME" ]] || { echo "LG HDR WQHD ultrawide is not connected; no files changed." >&2; exit 1; }

python3 - "$MONITORS_FILE" "$NOCTALIA_FILE" "$MONITOR_NAME" "$DRY_RUN" <<'PY'
from pathlib import Path
import os
import re
import shutil
import sys
import tempfile
from datetime import datetime

monitors_file = Path(sys.argv[1])
noctalia_file = Path(sys.argv[2])
monitor_name = sys.argv[3]
dry_run = sys.argv[4] == "true"

start = "-- BEGIN LG ultrawide setup"
end = "-- END LG ultrawide setup"
rule = f'''{start}
hl.monitor({{
    output = "desc:LG Electronics LG HDR WQHD",
    mode = "preferred",
    position = "auto",
    scale = 1.25,
}})
{end}'''

original = monitors_file.read_text()
if (start in original) != (end in original):
    sys.exit(f"Incomplete LG setup block in {monitors_file}; inspect it first.")
if start in original:
    begin = original.index(start)
    finish = original.index(end, begin) + len(end)
    updated = original[:begin] + rule + original[finish:]
else:
    legacy = re.compile(
        r'\n*hl\.monitor\(\{\s*output\s*=\s*"' + re.escape(monitor_name) +
        r'",\s*mode\s*=\s*"preferred",\s*position\s*=\s*"auto",'
        r'\s*scale\s*=\s*(?:1|1\.25),\s*\}\)\s*'
    )
    updated = legacy.sub("\n", original, count=1)
    if re.search(r'output\s*=\s*"' + re.escape(monitor_name) + r'"', updated):
        sys.exit(f"An existing rule for {monitor_name} remains in {monitors_file}; inspect it first.")
    updated = updated.rstrip() + "\n\n" + rule + "\n"

noctalia = "[accessibility]\nui_scale = 1.25\n"
changes = [(monitors_file, original, updated),
           (noctalia_file, noctalia_file.read_text() if noctalia_file.exists() else None, noctalia)]
for path, before, after in changes:
    if before == after:
        print(f"Unchanged: {path}")
        continue
    if dry_run:
        print(f"Would update: {path}")
        continue
    if before is not None:
        backup = path.with_name(path.name + ".bak." + datetime.now().strftime("%Y%m%d-%H%M%S") + f".{os.getpid()}")
        shutil.copy2(path, backup)
        print(f"Backed up: {path} -> {backup}")
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=path.name + ".tmp.", delete=False) as temp:
        temp.write(after)
        temp_path = Path(temp.name)
    os.chmod(temp_path, path.stat().st_mode & 0o777 if before is not None else 0o644)
    os.replace(temp_path, path)
    print(f"Updated: {path}")
PY

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run complete. No files changed."
else
    luac -p "$MONITORS_FILE"
    noctalia config validate "$NOCTALIA_DIR"
    hyprctl reload
    errors="$(hyprctl configerrors)"
    [[ -z "$errors" ]] || { printf 'Hyprland config errors:\n%s\n' "$errors" >&2; exit 1; }
    echo "LG ultrawide scale configured. Verify with: hyprctl monitors"
fi
