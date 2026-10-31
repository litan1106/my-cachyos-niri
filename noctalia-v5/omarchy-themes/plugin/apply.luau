--!nonstrict

local catalog = require("./catalog.luau")
local M = {}

local function run(args, callback)
    local started = noctalia.runAsync(args, function(result)
        if result == nil or result.exitCode ~= 0 then
            callback(false)
        else
            callback(true)
        end
    end, 30000)
    if not started then
        callback(false)
    end
end

function M.apply(theme, callback)
    if theme == nil then
        callback(false)
        return
    end
    run({ "noctalia", "msg", "color-scheme-set", "custom", catalog.palette(theme) }, function(ok)
        if not ok then
            callback(false)
            return
        end
        run({ "noctalia", "msg", "theme-mode-set", theme.mode }, function(modeOk)
            if not modeOk then
                callback(false)
                return
            end
            run({ "noctalia", "msg", "templates-apply" }, function(templatesOk)
                if templatesOk then
                    noctalia.state.set("activeTheme", theme.id)
                end
                callback(templatesOk)
            end)
        end)
    end)
end

return M
