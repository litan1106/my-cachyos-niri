--!nonstrict

local catalog = require("./catalog.luau")
local apply = require("./apply.luau")
local busy = false
local isOpen = false
local render

local function card(theme)
    local active = noctalia.state.get("activeTheme") == theme.id
    local label = active and "Active · " .. theme.mode or theme.mode
    return ui.column({
        key = theme.id,
        width = 210,
        height = 200,
        padding = 8,
        gap = 6,
        radius = 12,
        borderWidth = active and 2 or 0,
        onClick = function()
            if busy then
                return
            end
            busy = true
            render()
            apply.apply(theme, function(ok)
                busy = false
                if not ok then
                    noctalia.notifyError("Theme failed", "Could not apply " .. theme.title .. ".")
                end
                render()
            end)
        end,
    }, {
        ui.image({
            path = noctalia.pluginDir() .. "/previews/" .. theme.id .. ".png",
            width = 194,
            height = 112,
            radius = 8,
            fit = "cover",
        }),
        ui.label({ text = theme.title, fontSize = 14, fontWeight = "bold", maxLines = 1 }),
        ui.label({ text = label, fontSize = 11, color = "on_surface_variant" }),
    })
end

render = function()
    if not isOpen then
        return
    end
    local rows = {}
    local row = {}
    for _, theme in ipairs(catalog.list) do
        table.insert(row, card(theme))
        if #row == 4 then
            table.insert(rows, ui.row({ gap = 10, align = "start" }, row))
            row = {}
        end
    end
    panel.render(ui.column({ gap = 10, padding = 12, flexGrow = 1 }, {
        ui.row({ align = "center", justify = "space_between" }, {
            ui.label({ text = "Omarchy themes", fontSize = 18, fontWeight = "bold" }),
            ui.button({ glyph = "close", variant = "ghost", onClick = function() panel.close() end }),
        }),
        ui.label({ text = busy and "Applying theme…" or "Select a palette. Your wallpaper stays in place.", color = "on_surface_variant" }),
        ui.separator({}),
        ui.scroll({ flexGrow = 1, gap = 10, padding = 4 }, {
            ui.column({ gap = 10 }, rows),
        }),
    }))
end

function onOpen()
    isOpen = true
    noctalia.runAsync({ "noctalia", "msg", "color-scheme-get" }, function(result)
        if result ~= nil and result.exitCode == 0 then
            local id = tostring(result.stdout or ""):match("^custom%s+omarchy%-([%w%-]+)")
            noctalia.state.set("activeTheme", id or "")
        end
    end)
    render()
end

function onClose()
    isOpen = false
end

noctalia.state.watch("activeTheme", render)
