# Noctalia v5 overlay

`zz-shared.toml` is an optional overlay loaded after CachyOS's `config.toml`. It
provides a top status bar with a CachyOS launcher icon, spaced workspaces, and
active window in the center and the clock/date on the right. A bottom auto-hide
window dock uses Noctalia's taskbar so each open window gets its own icon; it
also has an Apps button. The overlay includes a grid launcher and the Kanagawa
dark theme. Install it with
`./install.sh --with-layout`; the default installer keeps the CachyOS layout.
A taskbar capsule provides the window dock because Noctalia's native dock
groups windows by app.
A later run without the flag leaves an existing overlay in place. Move
`~/.config/noctalia/zz-shared.toml` aside to return to the CachyOS layout.

Set per-user choices in Noctalia Settings (Super+Z), such as pinned apps,
wallpapers, widgets, and an avatar. The launcher and session menu use Noctalia
v5's built-in UI.

Export the resulting settings with `noctalia config export`, review them for
private values, and keep machine-specific values outside this shared file. Use
`noctalia config validate` after edits. GUI changes are stored separately and
can override values in `zz-shared.toml`.
