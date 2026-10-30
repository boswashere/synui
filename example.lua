-- Load the library once, then create your window and controls.
local SOURCE = "https://raw.githubusercontent.com/boswashere/synui/refs/heads/main/synui.lua"
local SynUI = loadstring(game:HttpGet(SOURCE))()

-- Demo body.
local window = SynUI:CreateWindow({
    title = "SYNUI",
    subtitle = "Black & white",
    footer = "Example workspace",
    icon = "grid",
    toggleKey = Enum.KeyCode.RightShift,
})

local settings = window:Tab({name = "Settings", icon = "sliders", subtitle = "Preferences for this session."})
local general = settings:Section({title = "General", subtitle = "These values only affect this example."})

local enabled = general:Toggle({
    text = "Enabled",
    description = "Enable the example feature.",
    value = true,
    callback = function(value) window:SetStatus(value and "Enabled" or "Disabled") end,
})
local mode = general:Dropdown({
    text = "Mode",
    description = "Choose how the feature runs.",
    options = {"Balanced", "Fast", "Quiet"},
    value = "Balanced",
    callback = function(value) window:SetStatus(value) end,
})
local speed = general:Slider({text = "Speed", min = 1, max = 20, value = 8, step = 1, suffix = "x"})

local actions = window:Tab({name = "Actions", icon = "play", subtitle = "Buttons, messages and confirmations."})
local feedback = actions:Section({title = "Feedback"})
feedback:Button({
    text = "Send notification",
    description = "Show a short message above the window.",
    actionText = "Send",
    variant = "primary",
    callback = function()
        window:Notify({title = "Hello", text = "The button callback ran.", icon = "check", duration = 3})
    end,
})
feedback:Button({
    text = "Open dialog",
    description = "Try a confirmation with two choices.",
    actionText = "Open",
    callback = function()
        window:Dialog({title = "Keep these settings?", text = "Your choice appears in the footer.",
            callback = function(accepted) window:SetStatus(accepted and "Confirmed" or "Cancelled") end})
    end,
})
feedback:Button({
    text = "Read values",
    description = "Get() reads the current control state.",
    actionText = "Read",
    callback = function()
        window:Notify({title = "Current values", text = string.format("Enabled: %s\nMode: %s\nSpeed: %sx",
            tostring(enabled:Get()), tostring(mode:Get()), tostring(speed:Get())), icon = "terminal"})
    end,
})

local input = window:Tab({name = "Input", icon = "terminal", subtitle = "Text fields and keyboard shortcuts."})
local identity = input:Section({title = "Identity"})
identity:Input({
    text = "Display name",
    description = "Text is saved when the field loses focus.",
    placeholder = "Your name",
    callback = function(value) window:SetStatus(value == "" and "Ready" or "Saved: " .. value) end,
})
identity:Keybind({
    text = "Example key",
    description = "Select the field and press a key. Escape cancels.",
    value = Enum.KeyCode.E,
    callback = function(key) window:SetStatus("Selected " .. key.Name) end,
})

local about = window:Tab({name = "About", icon = "layers", subtitle = "A single-file Roblox interface library."})
about:Paragraph({text = "Search filters controls on the current page. Drag the header to move the window, or the bottom-right corner to resize it. The restore button brings back a hidden window."})
local management = about:Section({title = "Window"})
management:Button({text = "Default size", description = "Restore the window's original dimensions.", actionText = "Reset",
    callback = function() window:ResetSize() end})
management:Button({text = "Hide window", description = "Keep the controls and their values.", actionText = "Hide",
    callback = function() window:Toggle() end})
management:Button({text = "Close demo", description = "Remove this window and its controls.", actionText = "Close",
    callback = function()
        window:Dialog({title = "Close demo?", text = "This removes the window and stops the example.", confirmText = "Close",
            callback = function(confirmed) if confirmed then window:Destroy() end end})
    end})
