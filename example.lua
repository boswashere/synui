--[[
    example.lua

    Run this in an executor. It downloads SYNUI, opens a demo window, and
    leaves it open so you can click around. Change the names, controls, and
    callbacks to fit your own script.

    The loader is the important part:

        local SynUI = loadstring(game:HttpGet(SOURCE))()

    game:HttpGet gets the file as text. loadstring turns that text into a
    function. The final () runs the function, and the function returns the
    SynUI table. Keep that table and reuse it.
]]

local SOURCE = "https://raw.githubusercontent.com/boswashere/synui/refs/heads/main/synui.lua"
local SynUI = loadstring(game:HttpGet(SOURCE))()

-- Demo body.
-- SYNUI chooses a renderable GUI root automatically.
local window = SynUI:CreateWindow({
    title = "SYNUI",
    footer = "Universal interface",
    icon = "grid",
    toggleKey = Enum.KeyCode.RightShift,
    launcher = true,
})

local home = window:Tab({
    name = "Home",
    icon = "home",
    subtitle = "Your controls in one place.",
})

local homeLeft, homeRight = home:Columns()
local actions = homeLeft:Section({title = "Quick actions"})

-- Buttons run whatever function you pass in. This one opens a notification
-- and changes the footer text.
actions:Button({
    text = "Send notification",
    description = "A small message above the window",
    icon = "play",
    variant = "primary",
    callback = function()
        window:Notify({
            title = "Hello",
            text = "The button callback ran.",
            icon = "check",
            duration = 3,
        })
        window:SetStatus("READY", "ok")
    end,
})

actions:Button({
    text = "Open dialog",
    description = "Try the confirmation panel",
    icon = "layers",
    callback = function()
        window:Dialog({title = "Keep this window?", text = "This is a demo confirmation. Your choice appears in the footer.",
            callback = function(accepted) window:SetStatus(accepted and "Confirmed" or "Cancelled") end})
    end,
})

local windowSection = homeRight:Section({title = "Window"})
windowSection:Button({text = "Hide window", icon = "minus", callback = function() window:Toggle() end})
windowSection:Button({text = "Open controls", icon = "sliders", callback = function() window:Search("Controls") end})

-- Toggles keep their own state. Get() reads it later.
local controls = window:Tab({
    name = "Controls",
    icon = "sliders",
    subtitle = "Switches, sliders and selections.",
})

local leftControls, rightControls = controls:Columns()

local controlSection = leftControls:Section({
    title = "General",
})

local enabled = controlSection:Toggle({
    text = "Enabled",
    description = "Enable the example feature",
    value = true,
    callback = function(value)
        window:SetStatus(value and "ON" or "OFF", value and "ok" or "off")
    end,
})

-- Sliders clamp to min/max and snap to step. The callback receives a number.
local speed = controlSection:Slider({
    text = "Speed",
    min = 1,
    max = 20,
    value = 8,
    step = 1,
    suffix = "x",
    callback = function(value)
        -- Do something with value here. This example reads it later with speed:Get().
    end,
})

-- A single dropdown returns the selected string.
local mode = controlSection:Dropdown({
    text = "Mode",
    options = { "Balanced", "Fast", "Quiet" },
    value = "Balanced",
    callback = function(value)
        window:SetStatus(string.upper(value), "ok")
    end,
})

local statusSection = rightControls:Section({
    title = "Session",
})

statusSection:Button({
    text = "Read values",
    description = "Read values with Get()",
    icon = "activity",
    callback = function()
        window:Notify({
            title = "Current values",
            text = string.format(
                "enabled=%s  speed=%s  mode=%s",
                tostring(enabled:Get()),
                tostring(speed:Get()),
                tostring(mode:Get())
            ),
            icon = "terminal",
            duration = 5,
        })
    end,
})

-- Text inputs fire when the field loses focus or when Return is pressed.
local inputTab = window:Tab({
    name = "Input",
    icon = "terminal",
    subtitle = "Text and keybinds",
})

local inputSection = inputTab:Section({
    title = "Identity",
    subtitle = "Try the fields",
    icon = "user",
})

local name = inputSection:Input({
    text = "Name",
    placeholder = "Type something",
    callback = function(value)
        if value ~= "" then
            window:Notify({
                title = "Name saved",
                text = value,
                icon = "check",
            })
        end
    end,
})

-- Click the key pill, then press a key. Escape cancels capture.
local bind = inputSection:Keybind({
    text = "Toggle key",
    value = Enum.KeyCode.RightShift,
    callback = function(key)
        window:Notify({
            title = "Key changed",
            text = tostring(key),
            icon = "key",
        })
    end,
})

-- Get() works on every control, so the callbacks can read current values later.

local about = window:Tab({
    name = "About",
    icon = "layers",
    subtitle = "What this is",
})

about:Paragraph({
    text = "This is a plain example of the public API. The window, tabs, sections, and controls are all built from tables you pass in.",
})

about:Card({
    icon = "spark",
    title = "One file",
    body = "SYNUI is loaded from GitHub with loadstring. There is no setup step after that.",
})

local aboutSection = about:Section({
    title = "Cleanup",
    subtitle = "When you are done",
    icon = "trash",
})

aboutSection:Button({
    text = "Close demo",
    description = "Removes the window",
    icon = "trash",
    callback = function()
        window:Dialog({
            title = "Close demo?",
            text = "This removes the window and stops the example.",
            confirmText = "Close",
            callback = function(confirmed)
                if confirmed then
                    window:Destroy()
                end
            end,
        })
    end,
})
