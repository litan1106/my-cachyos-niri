local mod = "SUPER"
local noctalia = "noctalia msg "
local launch = "uwsm app -- "

-- CachyOS assigns these keys to other actions before this overlay loads.
for _, key in ipairs({
    mod .. " + Escape",
    mod .. " + ALT + Space",
    mod .. " + W",
    mod .. " + T",
    mod .. " + Tab",
    mod .. " + Print",
}) do
    hl.unbind(key)
end

hl.bind(mod .. " + Escape", hl.dsp.exec_cmd(noctalia .. "panel-toggle session"))
hl.bind(mod .. " + ALT + Space", hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center"))
hl.bind(mod .. " + W", hl.dsp.window.close())
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mod .. " + CONTROL + Tab", hl.dsp.focus({ workspace = "previous_per_monitor" }))
hl.bind(mod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd(noctalia .. "screenshot-window"))
hl.bind("ALT + Print", hl.dsp.exec_cmd(noctalia .. "screenshot-fullscreen"))

for workspace = 1, 4 do
    local keycode = "code:" .. (9 + workspace)
    local focus_key = mod .. " + " .. keycode
    local move_key = mod .. " + SHIFT + " .. keycode
    hl.unbind(focus_key)
    hl.unbind(move_key)
    hl.bind(focus_key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(move_key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mod .. " + CONTROL + L", hl.dsp.exec_cmd(noctalia .. "session lock"))
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd(launch .. BROWSER))
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd(launch .. FILE_MANAGER))
hl.bind(mod .. " + CONTROL + T", hl.dsp.exec_cmd(launch .. TERMINAL .. " -e btop"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(launch .. TERMINAL .. " -e btop"))
hl.bind(mod .. " + CONTROL + V", hl.dsp.exec_cmd(noctalia .. "panel-toggle clipboard"))
hl.bind(mod .. " + CONTROL + E", hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher /emo"))
hl.bind(mod .. " + CONTROL + W", hl.dsp.exec_cmd(noctalia .. "panel-toggle wallpaper"))
hl.bind(mod .. " + comma", hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center notifications"))
hl.bind(mod .. " + SHIFT + comma", hl.dsp.exec_cmd(noctalia .. "notification-clear-active"))
hl.bind(mod .. " + CONTROL + I", hl.dsp.exec_cmd(noctalia .. "caffeine-toggle"))
hl.bind(mod .. " + CONTROL + N", hl.dsp.exec_cmd(noctalia .. "nightlight-toggle"))
hl.bind(mod .. " + CONTROL + comma", hl.dsp.exec_cmd(noctalia .. "notification-dnd-toggle"))
hl.bind(mod .. " + SHIFT + Space", hl.dsp.exec_cmd(noctalia .. "bar-toggle"))
