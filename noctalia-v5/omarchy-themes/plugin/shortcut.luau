--!nonstrict

shortcut.setLabel("Omarchy themes")
shortcut.setIcon("palette")

function onClick()
    noctalia.togglePanel("my-cachyos-niri/omarchy-themes:picker")
end

function onIpc()
    noctalia.togglePanel("my-cachyos-niri/omarchy-themes:picker")
end
