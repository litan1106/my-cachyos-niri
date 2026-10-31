--!nonstrict

local M = {}

M.list = {
    { id = "catppuccin", title = "Catppuccin", mode = "dark" },
    { id = "catppuccin-latte", title = "Catppuccin Latte", mode = "light" },
    { id = "everforest", title = "Everforest", mode = "dark" },
    { id = "flexoki-light", title = "Flexoki Light", mode = "light" },
    { id = "gruvbox", title = "Gruvbox", mode = "dark" },
    { id = "kanagawa", title = "Kanagawa", mode = "dark" },
    { id = "matte-black", title = "Matte Black", mode = "dark" },
    { id = "nord", title = "Nord", mode = "dark" },
    { id = "ristretto", title = "Ristretto", mode = "dark" },
    { id = "rose-pine", title = "Rose Pine", mode = "light" },
    { id = "solarized", title = "Solarized", mode = "dark" },
    { id = "tokyo-night", title = "Tokyo Night", mode = "dark" },
}

function M.find(query)
    local key = tostring(query or ""):lower()
    for _, theme in ipairs(M.list) do
        if theme.id == key or theme.title:lower() == key then
            return theme
        end
    end
    return nil
end

function M.palette(theme)
    return "omarchy-" .. theme.id
end

return M
