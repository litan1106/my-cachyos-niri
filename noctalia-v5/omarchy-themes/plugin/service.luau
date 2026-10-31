--!nonstrict

local catalog = require("./catalog.luau")
local apply = require("./apply.luau")

function onIpc(event, payload)
    if event ~= "set" then
        return
    end
    local theme = catalog.find(payload)
    if theme == nil then
        noctalia.notifyError("Unknown theme", tostring(payload or ""))
        return
    end
    apply.apply(theme, function(ok)
        if not ok then
            noctalia.notifyError("Theme failed", "Could not apply " .. theme.title .. ".")
        end
    end)
end
