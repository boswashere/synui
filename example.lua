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

-- parent = nil means: use gethui() if the executor has it, otherwise PlayerGui.
-- This example asks for PlayerGui directly. On Delta and some other mobile
-- executors that is the reliable choice when gethui() returns a hidden folder.
local window = SynUI:CreateWindow({
    title = "SYNUI DEMO",
    subtitle = "EXAMPLE SCRIPT",
    icon = "grid",
    size = UDim2.fromOffset(720, 480),
    toggleKey = Enum.KeyCode.RightShift,
    launcher = true,
    parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),
})

local home = window:Tab({
    name = "Home",
    icon = "home",
    subtitle = "Basic controls",
})

local main = home:Section({
    title = "Main",
    subtitle = "Click something",
    icon = "bolt",
})

-- Buttons run whatever function you pass in. This one opens a notification
-- and changes the footer text.
main:Button({
    text = "Say hello",
    description = "Shows a notification",
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

-- Toggles keep their own state. Get() reads it later.
local enabled = main:Toggle({
    text = "Enabled",
    description = "Turn the demo feature on or off",
    value = true,
    callback = function(value)
        window:SetStatus(value and "ON" or "OFF", value and "ok" or "off")
    end,
})

-- Sliders clamp to min/max and snap to step. The callback receives a number.
local speed = main:Slider({
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
local mode = main:Dropdown({
    text = "Mode",
    options = { "Balanced", "Fast", "Quiet" },
    value = "Balanced",
    callback = function(value)
        window:SetStatus(string.upper(value), "ok")
    end,
})

-- Text inputs fire when the field loses focus or when Return is pressed.
local name = main:Input({
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
local bind = main:Keybind({
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

-- Get() works on every control above. This button reads them all at once.
main:Button({
    text = "Read values",
    description = "Shows the current control state",
    icon = "activity",
    callback = function()
        window:Notify({
            title = "Current values",
            text = string.format(
                "enabled=%s  speed=%s  mode=%s  name=%s  key=%s",
                tostring(enabled:Get()),
                tostring(speed:Get()),
                tostring(mode:Get()),
                name:Get() ~= "" and name:Get() or "(empty)",
                tostring(bind:Get())
            ),
            icon = "terminal",
            duration = 5,
        })
    end,
})

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
