local ok, err = xpcall(function()
local SynUI = (function()
-- SYNUI / theme
-- One monochrome palette, one radius scale, one motion vocabulary.

local Theme = {
	version = "1.1.1",

	colors = {
		bg = Color3.fromRGB(8, 8, 10),
		surface = Color3.fromRGB(14, 14, 17),
		raised = Color3.fromRGB(19, 19, 23),
		hover = Color3.fromRGB(26, 26, 31),
		line = Color3.fromRGB(40, 40, 46),
		text = Color3.fromRGB(246, 246, 248),
		muted = Color3.fromRGB(154, 154, 163),
		dim = Color3.fromRGB(104, 104, 113),
		faint = Color3.fromRGB(72, 72, 80),
		white = Color3.fromRGB(255, 255, 255),
		black = Color3.fromRGB(5, 5, 6),
	},

	fonts = {
		regular = Enum.Font.Gotham,
		medium = Enum.Font.GothamMedium,
		bold = Enum.Font.GothamBold,
		mono = Enum.Font.Code,
	},

	radius = { sm = 6, md = 9, lg = 12, xl = 16 },

	motion = { fast = 0.12, normal = 0.18, slow = 0.28 },
}

-- Hairline stroke transparency and the base spacing unit used by every part.
Theme.stroke = 0.82
Theme.pad = 14

-- Small shared helper. Kept on Theme so later parts can soften a surface
-- without inventing ad-hoc colors.
function Theme.mix(a, b, t)
	t = math.max(0, math.min(1, t or 0))
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end


--[[
    02_util.lua — shared helpers.
    Every function tolerates nil inputs; nothing here assigns a global.
]]

local Util = {}

-- Executor compatibility: modern Roblox always has `task`, but older
-- loadstring environments only expose spawn/delay. Shadow the global with a
-- local shim so every later part uses the same scheduler.
local task = task
if type(task) ~= "table" then
    local function pack(...)
        return { n = select("#", ...), ... }
    end
    local function run(fn, args)
        if type(fn) == "function" then
            fn(table.unpack(args, 1, args.n or #args))
        end
    end
    task = {
        defer = function(fn, ...)
            local args = pack(...)
            local wrapped = function()
                run(fn, args)
            end
            if type(spawn) == "function" then
                spawn(wrapped)
            else
                coroutine.wrap(wrapped)()
            end
        end,
        delay = function(seconds, fn, ...)
            local args = pack(...)
            local wrapped = function()
                run(fn, args)
            end
            if type(delay) == "function" then
                delay(seconds, wrapped)
            else
                coroutine.wrap(function()
                    wait(seconds)
                    wrapped()
                end)()
            end
        end,
        spawn = function(fn, ...)
            local args = pack(...)
            local wrapped = function()
                run(fn, args)
            end
            if type(spawn) == "function" then
                spawn(wrapped)
            else
                coroutine.wrap(wrapped)()
            end
        end,
    }
end

local function service(name)
    local ok, svc = pcall(function()
        return game:GetService(name)
    end)
    if ok then
        return svc
    end
    return nil
end

local Players = service("Players")
local TweenService = service("TweenService")
local UserInputService = service("UserInputService")

local function setProps(inst, props)
    if not inst or type(props) ~= "table" then
        return inst
    end
    for key, value in pairs(props) do
        if key ~= "Parent" and value ~= nil then
            local ok = pcall(function()
                inst[key] = value
            end)
            if not ok then
                local kind = type(value)
                -- Read-only / unknown properties fall back to a primitive attribute.
                if kind == "string" or kind == "number" or kind == "boolean" then
                    pcall(function()
                        inst:SetAttribute(key, value)
                    end)
                end
            end
        end
    end
    if props.Parent ~= nil then
        pcall(function()
            inst.Parent = props.Parent
        end)
    end
    return inst
end

function Util.Create(className, props)
    if className == nil then
        className = "Frame"
    end
    local ok, inst = pcall(Instance.new, className)
    if not ok or not inst then
        warn("[SYNUI] Instance.new failed for " .. tostring(className) .. "; using Frame")
        inst = Instance.new("Frame")
    end
    setProps(inst, props)
    return inst
end

function Util.Tween(obj, props, time, style, direction)
    if not obj or type(props) ~= "table" then
        return nil
    end
    if not TweenService then
        setProps(obj, props)
        return nil
    end
    local length = time
    if length == nil then
        length = 0.18
        if Theme and Theme.motion and Theme.motion.normal then
            length = Theme.motion.normal
        end
    end
    local easingStyle = style or Enum.EasingStyle.Quint
    local easingDirection = direction or Enum.EasingDirection.Out
    local ok, tween = pcall(function()
        return TweenService:Create(obj, TweenInfo.new(length, easingStyle, easingDirection), props)
    end)
    if not ok or not tween then
        setProps(obj, props)
        return nil
    end
    pcall(function()
        tween:Play()
    end)
    return tween
end

function Util.Corner(obj, radius)
    if not obj then
        return nil
    end
    local px = radius
    if px == nil then
        px = (Theme and Theme.radius and Theme.radius.md) or 9
    end
    local corner = nil
    pcall(function()
        corner = obj:FindFirstChildOfClass("UICorner")
    end)
    if not corner then
        local ok, made = pcall(function()
            return Instance.new("UICorner")
        end)
        if not ok or not made then
            return nil
        end
        corner = made
        pcall(function()
            corner.Parent = obj
        end)
    end
    local udim
    if type(px) == "number" then
        udim = UDim.new(0, px)
    else
        udim = px
    end
    pcall(function()
        corner.CornerRadius = udim
    end)
    return corner
end

function Util.Stroke(obj, color, thickness, transparency)
    if not obj then
        return nil
    end
    local stroke = nil
    pcall(function()
        stroke = obj:FindFirstChildOfClass("UIStroke")
    end)
    if not stroke then
        local ok, made = pcall(function()
            return Instance.new("UIStroke")
        end)
        if not ok or not made then
            return nil
        end
        stroke = made
        pcall(function()
            stroke.Parent = obj
        end)
    end
    pcall(function()
        stroke.Color = color or Theme.colors.line
    end)
    pcall(function()
        stroke.Thickness = thickness or 1
    end)
    local alpha = transparency
    if alpha == nil and Theme then
        alpha = Theme.stroke
    end
    pcall(function()
        stroke.Transparency = alpha or 0.82
    end)
    pcall(function()
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    end)
    return stroke
end

function Util.Padding(obj, x, y)
    if not obj then
        return nil
    end
    local px = tonumber(x) or 0
    local py = tonumber(y)
    if py == nil then
        py = px
    end
    local padding = nil
    pcall(function()
        padding = obj:FindFirstChildOfClass("UIPadding")
    end)
    if not padding then
        local ok, made = pcall(function()
            return Instance.new("UIPadding")
        end)
        if not ok or not made then
            return nil
        end
        padding = made
        pcall(function()
            padding.Parent = obj
        end)
    end
    pcall(function()
        padding.PaddingLeft = UDim.new(0, px)
        padding.PaddingRight = UDim.new(0, px)
        padding.PaddingTop = UDim.new(0, py)
        padding.PaddingBottom = UDim.new(0, py)
    end)
    return padding
end

function Util.Text(parent, props)
    local base = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = (Theme and Theme.fonts and Theme.fonts.regular) or Enum.Font.Gotham,
        Text = "",
        TextSize = 11,
        TextColor3 = (Theme and Theme.colors and Theme.colors.text) or Color3.fromRGB(246, 246, 248),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, 14),
        RichText = false,
    }
    if type(props) == "table" then
        for key, value in pairs(props) do
            if value ~= nil then
                base[key] = value
            end
        end
    end
    if base.Parent == nil and parent ~= nil then
        base.Parent = parent
    end
    return Util.Create("TextLabel", base)
end

function Util.Label(parent, text, size, color, font)
    local px = tonumber(size) or 11
    return Util.Text(parent, {
        Text = tostring(text == nil and "" or text),
        TextSize = px,
        TextColor3 = color or ((Theme and Theme.colors and Theme.colors.text) or Color3.fromRGB(246, 246, 248)),
        Font = font or ((Theme and Theme.fonts and Theme.fonts.regular) or Enum.Font.Gotham),
        Size = UDim2.new(1, 0, 0, math.max(14, px + 4)),
    })
end

function Util.Clamp(n, lo, hi)
    local value = tonumber(n) or 0
    local low = tonumber(lo)
    local high = tonumber(hi)
    if low ~= nil and high ~= nil and low > high then
        low, high = high, low
    end
    if low ~= nil and value < low then
        value = low
    end
    if high ~= nil and value > high then
        value = high
    end
    return value
end

function Util.Round(n)
    local value = tonumber(n)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return 0
    end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function Util.FormatNumber(n)
    local value = tonumber(n)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return "0"
    end
    local negative = value < 0
    value = math.abs(value)
    local rounded = math.floor(value * 100 + 0.5) / 100
    local whole = math.floor(rounded)
    local fraction = rounded - whole
    local text = tostring(whole)
    local reversed = text:reverse():gsub("(%d%d%d)", "%1,")
    text = reversed:reverse()
    text = text:gsub("^,", "")
    if fraction > 0 then
        local tail = string.format("%.2f", fraction):sub(3)
        tail = tail:gsub("0+$", "")
        if tail ~= "" then
            text = text .. "." .. tail
        end
    end
    if negative and text ~= "0" then
        text = "-" .. text
    end
    return text
end

function Util.SafeCallback(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local function handler(err)
        local message = tostring(err)
        if debug and debug.traceback then
            local ok, trace = pcall(debug.traceback, message, 2)
            if ok and trace then
                return trace
            end
        end
        return message
    end
    local total = select("#", ...)
    local args = { ... }
    local ok, result = xpcall(function()
        return fn(table.unpack(args, 1, total))
    end, handler)
    if not ok then
        warn("[SYNUI] callback error: " .. tostring(result))
        return false
    end
    return true, result
end

function Util.Viewport()
    local ok, camera = pcall(function()
        return workspace.CurrentCamera
    end)
    if ok and camera then
        local viewOk, size = pcall(function()
            return camera.ViewportSize
        end)
        if viewOk and size and size.X and size.X > 0 and size.Y > 0 then
            return size
        end
    end
    return Vector2.new(1280, 720)
end

function Util.IsMobile()
    local touchFirst = false
    if UserInputService then
        local touchOk, touch = pcall(function()
            return UserInputService.TouchEnabled
        end)
        local mouseOk, mouse = pcall(function()
            return UserInputService.MouseEnabled
        end)
        touchFirst = touchOk and touch == true and (not mouseOk or mouse == false)
    end
    return touchFirst or Util.Viewport().X < 700
end

function Util.ParentOf(obj)
    if not obj then
        return nil
    end
    local ok, parent = pcall(function()
        return obj.Parent
    end)
    if ok then
        return parent
    end
    return nil
end

function Util.GetParent(cfg)
    if type(cfg) == "table" and cfg.parent ~= nil then
        return cfg.parent
    end
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end
    if Players then
        local player = nil
        pcall(function()
            player = Players.LocalPlayer
        end)
        if player then
            local gui = nil
            pcall(function()
                gui = player:FindFirstChildOfClass("PlayerGui")
            end)
            if not gui then
                pcall(function()
                    gui = player:WaitForChild("PlayerGui", 5)
                end)
            end
            if gui then
                return gui
            end
        end
    end
    return nil
end

function Util.MakeDraggable(frame, handle, gui)
    if not frame then
        return function() end
    end
    handle = handle or frame
    gui = gui or Util.ParentOf(frame)
    pcall(function()
        handle.Active = true
    end)

    local dragging = false
    local dragInput = nil
    local dragStart = Vector2.new(0, 0)
    local startAbs = Vector2.new(0, 0)
    local connections = {}

    local function track(conn)
        if conn then
            table.insert(connections, conn)
        end
        return conn
    end

    local function begin(input)
        if not input then
            return
        end
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        dragInput = input
        dragStart = Vector2.new(input.Position.X, input.Position.Y)
        local ok, abs = pcall(function()
            return frame.AbsolutePosition
        end)
        startAbs = ok and abs and Vector2.new(abs.X, abs.Y) or Vector2.new(0, 0)
    end

    local function move(input)
        if not dragging or not input then
            return
        end
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseMovement
            and kind ~= Enum.UserInputType.Touch then
            return
        end
        local viewport = Util.Viewport()
        local sizeX, sizeY = 0, 0
        pcall(function()
            sizeX = frame.AbsoluteSize.X
            sizeY = frame.AbsoluteSize.Y
        end)
        local dx = input.Position.X - dragStart.X
        local dy = input.Position.Y - dragStart.Y
        local targetX = startAbs.X + dx
        local targetY = startAbs.Y + dy
        local maxX = math.max(8, viewport.X - sizeX - 8)
        local maxY = math.max(8, viewport.Y - sizeY - 8)
        targetX = Util.Clamp(targetX, 8, maxX)
        targetY = Util.Clamp(targetY, 8, maxY)

        local originX, originY = 0, 0
        local parent = Util.ParentOf(frame)
        if parent then
            pcall(function()
                if parent.AbsolutePosition then
                    originX = parent.AbsolutePosition.X
                    originY = parent.AbsolutePosition.Y
                end
            end)
        end
        local anchorX, anchorY = 0, 0
        pcall(function()
            anchorX = frame.AnchorPoint.X
            anchorY = frame.AnchorPoint.Y
        end)
        local offsetX = targetX - originX + sizeX * anchorX
        local offsetY = targetY - originY + sizeY * anchorY
        pcall(function()
            frame.Position = UDim2.fromOffset(offsetX, offsetY)
        end)
    end

    local function finish(input)
        if not input then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = false
        dragInput = nil
    end

    pcall(function()
        track(handle.InputBegan:Connect(begin))
    end)
    if UserInputService then
        pcall(function()
            track(UserInputService.InputChanged:Connect(move))
        end)
        pcall(function()
            track(UserInputService.InputEnded:Connect(finish))
        end)
    end

    return function()
        for _, conn in ipairs(connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        connections = {}
    end
end

function Util.OnViewportChanged(gui, fn)
    if type(fn) ~= "function" then
        return function() end
    end
    local connections = {}
    local pending = false
    local version = 0

    local function schedule()
        if pending then
            return
        end
        local mine = version
        pending = true
        task.defer(function()
            pending = false
            if mine ~= version then
                return
            end
            Util.SafeCallback(fn)
        end)
    end

    local function track(conn)
        if conn then
            table.insert(connections, conn)
        end
        return conn
    end

    local function bindCamera()
        local ok, camera = pcall(function()
            return workspace.CurrentCamera
        end)
        if ok and camera then
            pcall(function()
                track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(schedule))
            end)
        end
    end

    bindCamera()
    if gui then
        pcall(function()
            track(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule))
        end)
    end
    pcall(function()
        track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            bindCamera()
            schedule()
        end))
    end)

    return function()
        version = version + 1
        for _, conn in ipairs(connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        connections = {}
    end
end

function Util.Hover(button, normalColor, hoverColor)
    if not button then
        return function() end
    end
    local touchOnly = false
    if UserInputService then
        local touchOk, touch = pcall(function()
            return UserInputService.TouchEnabled
        end)
        local mouseOk, mouse = pcall(function()
            return UserInputService.MouseEnabled
        end)
        touchOnly = touchOk and touch == true and (not mouseOk or mouse == false)
    end
    if touchOnly then
        return function() end
    end
    local normal = normalColor or button.BackgroundColor3
    local hover = hoverColor or ((Theme and Theme.colors and Theme.colors.hover) or Color3.fromRGB(26, 26, 31))
    local connections = {}
    pcall(function()
        table.insert(connections, button.MouseEnter:Connect(function()
            if normal then
                button.BackgroundColor3 = normal
            end
            Util.Tween(button, { BackgroundColor3 = hover }, (Theme and Theme.motion and Theme.motion.fast) or 0.12)
        end))
    end)
    pcall(function()
        table.insert(connections, button.MouseLeave:Connect(function()
            if normal then
                Util.Tween(button, { BackgroundColor3 = normal }, (Theme and Theme.motion and Theme.motion.fast) or 0.12)
            end
        end))
    end)
    return function()
        for _, conn in ipairs(connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        connections = {}
    end
end

function Util.Press(button)
    if not button then
        return function() end
    end
    local scale = nil
    pcall(function()
        scale = button:FindFirstChild("SynUIPressScale")
    end)
    if not scale then
        scale = Util.Create("UIScale", {
            Name = "SynUIPressScale",
            Scale = 1,
            Parent = button,
        })
    end
    local down = false
    local function press()
        if down then
            return
        end
        down = true
        Util.Tween(scale, { Scale = 0.985 }, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
    local function release()
        if not down then
            return
        end
        down = false
        Util.Tween(scale, { Scale = 1 }, 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end
    local connections = {}
    pcall(function()
        table.insert(connections, button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                press()
            end
        end))
    end)
    pcall(function()
        table.insert(connections, button.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                release()
            end
        end))
    end)
    if UserInputService then
        pcall(function()
            table.insert(connections, UserInputService.InputEnded:Connect(release))
        end)
    end
    return function()
        for _, conn in ipairs(connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        connections = {}
    end
end

function Util.AutoScroll(scrollFrame)
    if not scrollFrame then
        return nil
    end
    pcall(function()
        scrollFrame.ClipsDescendants = true
        scrollFrame.ScrollBarThickness = 2
        scrollFrame.ScrollBarImageColor3 = (Theme and Theme.colors and Theme.colors.faint) or Color3.fromRGB(72, 72, 80)
        scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    end)
    local automatic = false
    pcall(function()
        scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        automatic = true
    end)
    if automatic then
        pcall(function()
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        end)
    end

    local function update()
        if automatic then
            return
        end
        local content = 0
        local layout = nil
        pcall(function()
            layout = scrollFrame:FindFirstChildOfClass("UIListLayout")
        end)
        if layout then
            pcall(function()
                content = layout.AbsoluteContentSize.Y
            end)
        else
            pcall(function()
                for _, child in ipairs(scrollFrame:GetChildren()) do
                    if child:IsA("GuiObject") then
                        content = math.max(content, child.AbsolutePosition.Y - scrollFrame.AbsolutePosition.Y + child.AbsoluteSize.Y)
                    end
                end
            end)
        end
        pcall(function()
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(0, content + 8))
        end)
    end

    if not automatic then
        update()
        pcall(function()
            scrollFrame.ChildAdded:Connect(function()
                task.defer(update)
            end)
            scrollFrame.ChildRemoved:Connect(function()
                task.defer(update)
            end)
        end)
    end
    return update
end

function Util.Divider(parent)
    local line = Util.Create("Frame", {
        Name = "Divider",
        BackgroundColor3 = (Theme and Theme.colors and Theme.colors.line) or Color3.fromRGB(40, 40, 46),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Parent = parent,
    })
    return line
end

function Util.Debounce(fn, seconds)
    if type(fn) ~= "function" then
        return function() end
    end
    local wait = tonumber(seconds) or 0.15
    local version = 0
    return function(...)
        version = version + 1
        local mine = version
        local total = select("#", ...)
        local args = { ... }
        task.delay(wait, function()
            if mine ~= version then
                return
            end
            Util.SafeCallback(fn, table.unpack(args, 1, total))
        end)
    end
end


-- SYNUI / icons
-- 24x24 Lucide-style stroke geometry. defs are the source of truth; SVG is
-- generated from them for docs. The Roblox renderer below never uses images.

local Icons = { defs = {}, SVG = {} }
local defs = Icons.defs

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

defs.grid = {
	{ "rect", 3, 3, 7, 7, 1.5 },
	{ "rect", 14, 3, 7, 7, 1.5 },
	{ "rect", 3, 14, 7, 7, 1.5 },
	{ "rect", 14, 14, 7, 7, 1.5 },
}

defs.home = {
	{ "polyline", 3, 10, 12, 3, 21, 10 },
	{ "path", "M3 10V19C3 20.1 3.9 21 5 21H19C20.1 21 21 20.1 21 19V10" },
	{ "path", "M9.5 21V15.5H14.5V21" },
}

defs.bolt = {
	{ "polygon", 13, 2, 5, 13, 11, 13, 10, 22, 19, 11, 13, 11 },
}

defs.settings = {
	{ "circle", 12, 12, 6.4 },
	{ "circle", 12, 12, 2.6 },
	{ "line", 17.54, 15.2, 19.71, 16.45 },
	{ "line", 12, 18.4, 12, 20.9 },
	{ "line", 6.46, 15.2, 4.29, 16.45 },
	{ "line", 6.46, 8.8, 4.29, 7.55 },
	{ "line", 12, 5.6, 12, 3.1 },
	{ "line", 17.54, 8.8, 19.71, 7.55 },
}

defs.user = {
	{ "circle", 12, 7.5, 4 },
	{ "path", "M4 21V19.5C4 16.9 7.6 15 12 15C16.4 15 20 16.9 20 19.5V21" },
}

defs.shield = {
	{ "path", "M12 2L20 5.5V11C20 15.5 16.6 19.4 12 22C7.4 19.4 4 15.5 4 11V5.5Z" },
}

defs.key = {
	{ "circle", 7.5, 15.5, 3.8 },
	{ "line", 10.2, 12.8, 20.2, 2.8 },
	{ "line", 16.1, 6.9, 18.3, 9.1 },
	{ "line", 13.3, 9.7, 15.5, 11.9 },
}

defs.terminal = {
	{ "rect", 3, 4, 18, 16, 2 },
	{ "polyline", 7, 9, 10, 12, 7, 15 },
	{ "line", 13, 15.5, 17, 15.5 },
}

defs.activity = {
	{ "polyline", 2, 12, 6, 12, 9, 4, 15, 20, 18, 12, 22, 12 },
}

defs.layers = {
	{ "polygon", 12, 3, 21, 8, 12, 13, 3, 8 },
	{ "polyline", 3, 12, 12, 17, 21, 12 },
	{ "polyline", 3, 16, 12, 21, 21, 16 },
}

defs.code = {
	{ "polyline", 7, 6, 3, 12, 7, 18 },
	{ "polyline", 17, 6, 21, 12, 17, 18 },
}

defs.search = {
	{ "circle", 11, 11, 7 },
	{ "line", 16, 16, 21, 21 },
}

defs.close = {
	{ "line", 6, 6, 18, 18 },
	{ "line", 18, 6, 6, 18 },
}

defs.minus = {
	{ "line", 5, 12, 19, 12 },
}

defs["chevron-down"] = {
	{ "polyline", 6, 9, 12, 15, 18, 9 },
}

defs["chevron-right"] = {
	{ "polyline", 9, 6, 15, 12, 9, 18 },
}

defs.check = {
	{ "polyline", 4, 12.5, 9.5, 17.5, 20, 6.5 },
}

defs.plus = {
	{ "line", 12, 5, 12, 19 },
	{ "line", 5, 12, 19, 12 },
}

defs["arrow-right"] = {
	{ "line", 4, 12, 20, 12 },
	{ "polyline", 14.5, 6.5, 20, 12, 14.5, 17.5 },
}

defs.copy = {
	{ "path", "M8 3H5C3.9 3 3 3.9 3 5V16" },
	{ "rect", 8, 8, 12, 12, 2 },
}

defs.trash = {
	{ "line", 3, 6, 21, 6 },
	{ "path", "M19 6V19C19 20.1 18.1 21 17 21H7C5.9 21 5 20.1 5 19V6" },
	{ "path", "M9 6V4.5C9 3.7 9.7 3 10.5 3H13.5C14.3 3 15 3.7 15 4.5V6" },
	{ "line", 10, 10.5, 10, 17 },
	{ "line", 14, 10.5, 14, 17 },
}

defs.moon = {
	{ "path", "M21 12C21 16.971 16.971 21 12 21C7.029 21 3 16.971 3 12C3 7.029 7.029 3 12 3C9.516 5.484 9.516 9.516 12 12C14.484 14.484 18.516 14.484 21 12Z" },
}

defs.sun = {
	{ "circle", 12, 12, 4 },
	{ "line", 12, 3.1, 12, 6.1 },
	{ "line", 16.17, 7.83, 18.29, 5.71 },
	{ "line", 17.9, 12, 20.9, 12 },
	{ "line", 16.17, 16.17, 18.29, 18.29 },
	{ "line", 12, 17.9, 12, 20.9 },
	{ "line", 7.83, 16.17, 5.71, 18.29 },
	{ "line", 6.1, 12, 3.1, 12 },
	{ "line", 7.83, 7.83, 5.71, 5.71 },
}

defs.menu = {
	{ "line", 4, 6, 20, 6 },
	{ "line", 4, 12, 20, 12 },
	{ "line", 4, 18, 20, 18 },
}

defs.lock = {
	{ "rect", 4, 10, 16, 11, 2.5 },
	{ "path", "M8 10V7C8 4.8 9.8 3 12 3C14.2 3 16 4.8 16 7V10" },
}

defs.cpu = {
	{ "rect", 5, 5, 14, 14, 2 },
	{ "rect", 9, 9, 6, 6, 1 },
	{ "line", 9, 2.6, 9, 5 },
	{ "line", 15, 2.6, 15, 5 },
	{ "line", 9, 19, 9, 21.4 },
	{ "line", 15, 19, 15, 21.4 },
	{ "line", 2.6, 9, 5, 9 },
	{ "line", 2.6, 15, 5, 15 },
	{ "line", 19, 9, 21.4, 9 },
	{ "line", 19, 15, 21.4, 15 },
}

defs.spark = {
	{ "path", "M12 2C12 7.5 16.5 12 22 12C16.5 12 12 16.5 12 22C12 16.5 7.5 12 2 12C7.5 12 12 7.5 12 2Z" },
}

defs.sliders = {
	{ "line", 6, 4, 6, 12.4 },
	{ "circle", 6, 14.6, 2.2 },
	{ "line", 6, 16.8, 6, 20 },
	{ "line", 12, 4, 12, 6.4 },
	{ "circle", 12, 8.6, 2.2 },
	{ "line", 12, 10.8, 12, 20 },
	{ "line", 18, 4, 18, 13.5 },
	{ "circle", 18, 15.7, 2.2 },
	{ "line", 18, 17.9, 18, 20 },
}

defs.play = {
	{ "polygon", 7, 4.5, 20, 12, 7, 19.5 },
}

defs.dot = {
	{ "circle", 12, 12, 3.2 },
}

--------------------------------------------------------------------------------
-- Docs markup (generated so defs and SVG can never drift apart)
--------------------------------------------------------------------------------

local function svgNum(n)
	if n == math.floor(n) then
		return string.format("%d", n)
	end
	local s = string.format("%.2f", n)
	s = s:gsub("0+$", "")
	s = s:gsub("%.$", "")
	return s
end

local function svgPoints(list, first)
	local out = {}
	for i = first, #list, 2 do
		out[#out + 1] = svgNum(list[i]) .. "," .. svgNum(list[i + 1])
	end
	return table.concat(out, " ")
end

local function buildSVG(shape)
	local out = {}
	for _, p in ipairs(shape) do
		local kind = p[1]
		if kind == "path" then
			out[#out + 1] = '<path d="' .. p[2] .. '"/>'
		elseif kind == "circle" then
			out[#out + 1] = '<circle cx="' .. svgNum(p[2]) .. '" cy="' .. svgNum(p[3]) .. '" r="' .. svgNum(p[4]) .. '"/>'
		elseif kind == "rect" then
			out[#out + 1] = '<rect x="' .. svgNum(p[2]) .. '" y="' .. svgNum(p[3])
				.. '" width="' .. svgNum(p[4]) .. '" height="' .. svgNum(p[5])
				.. '" rx="' .. svgNum(p[6]) .. '"/>'
		elseif kind == "line" then
			out[#out + 1] = '<line x1="' .. svgNum(p[2]) .. '" y1="' .. svgNum(p[3])
				.. '" x2="' .. svgNum(p[4]) .. '" y2="' .. svgNum(p[5]) .. '"/>'
		elseif kind == "polyline" or kind == "polygon" then
			out[#out + 1] = "<" .. kind .. ' points="' .. svgPoints(p, 2) .. '"/>'
		end
	end
	return table.concat(out)
end

for name, shape in pairs(Icons.defs) do
	Icons.SVG[name] = buildSVG(shape)
end

--------------------------------------------------------------------------------
-- Path flattening (M L H V C Q Z, absolute + relative)
--------------------------------------------------------------------------------

local pathCache = {}

local function distance(x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	return math.sqrt(dx * dx + dy * dy)
end

local function tokenizePath(d)
	local tokens = {}
	local i = 1
	while i <= #d do
		local ch = string.sub(d, i, i)
		if string.match(ch, "%a") then
			tokens[#tokens + 1] = ch
			i = i + 1
		else
			local num = string.match(string.sub(d, i), "^[-+]?%d*%.?%d+")
			if num then
				tokens[#tokens + 1] = num
				i = i + #num
			else
				i = i + 1
			end
		end
	end
	return tokens
end

local function flattenPath(d)
	local cached = pathCache[d]
	if cached then
		return cached
	end

	local tokens = tokenizePath(d)
	local polys = {}
	local poly = nil
	local cx, cy, sx, sy = 0, 0, 0, 0
	local cmd = nil
	local i = 1

	local function addPoint(x, y)
		if not poly then
			poly = { cx, cy }
			polys[#polys + 1] = poly
		end
		poly[#poly + 1] = x
		poly[#poly + 1] = y
	end

	local function take()
		local raw = tokens[i]
		if raw == nil then
			return nil
		end
		local n = tonumber(raw)
		if n == nil then
			return nil
		end
		i = i + 1
		return n
	end

	local function steps(len)
		local n = math.ceil(len / 2.2)
		if n < 3 then
			return 3
		elseif n > 12 then
			return 12
		end
		return n
	end

	local function cubicTo(x2, y2, x3, y3, x4, y4)
		local x1, y1 = cx, cy
		local n = steps(distance(x1, y1, x2, y2) + distance(x2, y2, x3, y3) + distance(x3, y3, x4, y4))
		for k = 1, n do
			local t = k / n
			local mt = 1 - t
			local a = mt * mt * mt
			local b = 3 * mt * mt * t
			local c = 3 * mt * t * t
			local e = t * t * t
			addPoint(a * x1 + b * x2 + c * x3 + e * x4, a * y1 + b * y2 + c * y3 + e * y4)
		end
	end

	local function quadTo(x2, y2, x3, y3)
		local x1, y1 = cx, cy
		local n = steps(distance(x1, y1, x2, y2) + distance(x2, y2, x3, y3))
		for k = 1, n do
			local t = k / n
			local mt = 1 - t
			addPoint(mt * mt * x1 + 2 * mt * t * x2 + t * t * x3, mt * mt * y1 + 2 * mt * t * y2 + t * t * y3)
		end
	end

	while i <= #tokens do
		local token = tokens[i]
		if string.match(token, "%a") then
			cmd = token
			i = i + 1
			if cmd == "Z" or cmd == "z" then
				if poly then
					addPoint(sx, sy)
					poly = nil
				end
				cx, cy = sx, sy
			elseif cmd == "M" or cmd == "m" then
				local x, y = take(), take()
				if x == nil or y == nil then
					break
				end
				if cmd == "m" then
					x, y = cx + x, cy + y
				end
				cx, cy = x, y
				sx, sy = x, y
				poly = { x, y }
				polys[#polys + 1] = poly
				cmd = (cmd == "m") and "l" or "L"
			end
		else
			if cmd == "L" or cmd == "l" then
				local x, y = take(), take()
				if x == nil or y == nil then
					break
				end
				if cmd == "l" then
					x, y = cx + x, cy + y
				end
				addPoint(x, y)
				cx, cy = x, y
			elseif cmd == "H" or cmd == "h" then
				local x = take()
				if x == nil then
					break
				end
				if cmd == "h" then
					x = cx + x
				end
				addPoint(x, cy)
				cx = x
			elseif cmd == "V" or cmd == "v" then
				local y = take()
				if y == nil then
					break
				end
				if cmd == "v" then
					y = cy + y
				end
				addPoint(cx, y)
				cy = y
			elseif cmd == "C" or cmd == "c" then
				local x2, y2, x3, y3, x4, y4 = take(), take(), take(), take(), take(), take()
				if x2 == nil or y2 == nil or x3 == nil or y3 == nil or x4 == nil or y4 == nil then
					break
				end
				if cmd == "c" then
					x2, y2 = cx + x2, cy + y2
					x3, y3 = cx + x3, cy + y3
					x4, y4 = cx + x4, cy + y4
				end
				cubicTo(x2, y2, x3, y3, x4, y4)
				cx, cy = x4, y4
			elseif cmd == "Q" or cmd == "q" then
				local x2, y2, x3, y3 = take(), take(), take(), take()
				if x2 == nil or y2 == nil or x3 == nil or y3 == nil then
					break
				end
				if cmd == "q" then
					x2, y2 = cx + x2, cy + y2
					x3, y3 = cx + x3, cy + y3
				end
				quadTo(x2, y2, x3, y3)
				cx, cy = x3, y3
			else
				i = i + 1
			end
		end
	end

	pathCache[d] = polys
	return polys
end

--------------------------------------------------------------------------------
-- Roblox renderer: every primitive becomes a vector Frame.
--------------------------------------------------------------------------------

-- Icons.Draw(parent, name, size, color, thickness) -> Frame
function Icons.Draw(parent, name, size, color, thickness)
	if not parent then
		return nil
	end

	if not Icons.defs[name] then
		name = "dot"
	end

	size = tonumber(size) or 18
	if size < 8 then
		size = 8
	end

	local scale = size / 24
	local sw = math.max(1.3, (tonumber(thickness) or 2) * scale)
	color = color or Theme.colors.text

	local root = Util.Create("Frame", {
		Name = "Icon_" .. tostring(name),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = false,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})

	local function segment(x1, y1, x2, y2)
		local dx, dy = (x2 - x1) * scale, (y2 - y1) * scale
		local len = math.sqrt(dx * dx + dy * dy)
		if len < 0.05 then
			return
		end
		local line = Util.Create("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((x1 + x2) * 0.5 * scale, (y1 + y2) * 0.5 * scale),
			Size = UDim2.fromOffset(len + sw, sw),
			Rotation = math.deg(math.atan2(dy, dx)),
			Parent = root,
		})
		Util.Corner(line, sw * 0.5)
	end

	local function points(list, first, closed)
		local last = #list
		for k = first, last - 2, 2 do
			segment(list[k], list[k + 1], list[k + 2], list[k + 3])
		end
		if closed and last >= 4 then
			segment(list[last - 1], list[last], list[first], list[first + 1])
		end
	end

	local function ring(cx, cy, r)
		local diameter = r * 2 * scale + sw
		local f = Util.Create("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx * scale, cy * scale),
			Size = UDim2.fromOffset(diameter, diameter),
			Parent = root,
		})
		Util.Corner(f, diameter * 0.5)
		Util.Stroke(f, color, sw, 0)
	end

	local function box(x, y, w, h, rx)
		local f = Util.Create("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x * scale - sw * 0.5, y * scale - sw * 0.5),
			Size = UDim2.fromOffset(w * scale + sw, h * scale + sw),
			Parent = root,
		})
		Util.Corner(f, rx * scale + sw * 0.5)
		Util.Stroke(f, color, sw, 0)
	end

	for _, shape in ipairs(Icons.defs[name]) do
		local kind = shape[1]
		if kind == "path" then
			for _, poly in ipairs(flattenPath(shape[2])) do
				points(poly, 1, false)
			end
		elseif kind == "line" then
			segment(shape[2], shape[3], shape[4], shape[5])
		elseif kind == "circle" then
			ring(shape[2], shape[3], shape[4])
		elseif kind == "rect" then
			box(shape[2], shape[3], shape[4], shape[5], shape[6] or 0)
		elseif kind == "polyline" then
			points(shape, 2, false)
		elseif kind == "polygon" then
			points(shape, 2, true)
		end
	end

	return root
end



--[[
    SYNUI — controls
    Row-based primitives built into a section's content frame.
    Contract:
      section.content, section.window, section.tab
      section:AddRow(row), section:AddBlock(block), section:Refresh()

    Every row is a transparent full-width frame whose bottom child is a
    one-pixel Frame named "Divider". Layout hides the last divider.
]]

local Controls = {}

local UserInputService = game:GetService("UserInputService")

local TEXT = Theme.colors.text
local MUTED = Theme.colors.muted
local DIM = Theme.colors.dim
local LINE = Theme.colors.line
local RAISED = Theme.colors.raised
local HOVER = Theme.colors.hover
local SURFACE = Theme.colors.surface
local BG = Theme.colors.bg
local WHITE = Theme.colors.white

local function refreshSection(section)
    if section and section.Refresh then
        section:Refresh()
    end
end

local function addHover(gui, normal, hovered)
    if not Util.IsMobile() then
        Util.Hover(gui, normal, hovered)
    end
end

local function addDivider(row)
    local line = Util.Create("Frame", {
        Name = "Divider",
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = LINE,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    line.Parent = row
    return line
end

local function newRow(section, height)
    local row = Util.Create("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })
    addDivider(row)
    section:AddRow(row)
    return row
end

-- A label + optional description stacked over a full-width field. Shared by
-- Input and Dropdown so the two controls line up exactly.
local function fieldRow(section, cfg, fieldHeight)
    local labelH = 15
    local descH = 12
    local gap = 4
    local hasDesc = cfg.description ~= nil and cfg.description ~= ""
    local fieldY = labelH + (hasDesc and descH or 0) + gap
    local row = newRow(section, fieldY + fieldHeight + 2)

    local label = Util.Text(row, {
        Text = cfg.text or "",
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, labelH),
        Font = Theme.fonts.medium,
        TextSize = 11,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    if hasDesc then
        Util.Text(row, {
            Text = cfg.description,
            Position = UDim2.new(0, 0, 0, labelH),
            Size = UDim2.new(1, 0, 0, descH),
            Font = Theme.fonts.regular,
            TextSize = 9,
            TextColor3 = DIM,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2,
        })
    end

    return row, fieldY, label
end

local function formatValue(value)
    local rounded = math.floor(value * 1000 + 0.5) / 1000
    if math.abs(rounded - math.floor(rounded + 0.5)) < 0.0001 then
        return tostring(math.floor(rounded + 0.5))
    end
    local text = string.format("%.3f", rounded)
    text = string.gsub(text, "0+$", "")
    text = string.gsub(text, "%.$", "")
    return text
end

-- ---------------------------------------------------------------------------
-- Button
-- ---------------------------------------------------------------------------

function Controls.Button(section, cfg)
    cfg = cfg or {}
    local mobile = Util.IsMobile()
    local buttonH = mobile and 46 or 40
    local row = newRow(section, buttonH + 4)

    local variant = cfg.variant or "default"
    local primary = variant == "primary"
    local ghost = variant == "ghost"
    local base = primary and WHITE or (ghost and SURFACE or RAISED)
    local hovered = primary and Color3.fromRGB(228, 228, 228) or HOVER

    local button = Util.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, buttonH),
        BackgroundColor3 = base,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        ZIndex = 1,
    })
    button.Parent = row
    Util.Corner(button, 8)
    Util.Stroke(button, LINE, 1, primary and 1 or 0.4)

    local left = 14
    if cfg.icon then
        left = 37
        local iconColor = primary and Theme.colors.black or TEXT
        local iconFrame = Icons.Draw(button, cfg.icon, 16, iconColor)
        if iconFrame then
            iconFrame.Position = UDim2.new(0, 13, 0.5, 0)
            iconFrame.AnchorPoint = Vector2.new(0, 0.5)
            iconFrame.ZIndex = 2
        end
    end

    local right = 14
    if cfg.chevron then
        right = 34
        local chevron = Icons.Draw(button, "chevron-right", 14, primary and Theme.colors.black or MUTED)
        if chevron then
            chevron.Position = UDim2.new(1, -13, 0.5, 0)
            chevron.AnchorPoint = Vector2.new(1, 0.5)
            chevron.ZIndex = 2
        end
    end

    local hasDesc = cfg.description ~= nil and cfg.description ~= ""
    local top = 0
    local labelH = buttonH
    if hasDesc then
        labelH = 14
        top = math.floor((buttonH - 27) / 2)
    end

    local label = Util.Text(button, {
        Text = cfg.text or "",
        Position = UDim2.new(0, left, 0, top),
        Size = UDim2.new(1, -(left + right), 0, labelH),
        Font = Theme.fonts.medium,
        TextSize = 11,
        TextColor3 = primary and Theme.colors.black or TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    local descLabel = nil
    if hasDesc then
        descLabel = Util.Text(button, {
            Text = cfg.description,
            Position = UDim2.new(0, left, 0, top + 16),
            Size = UDim2.new(1, -(left + right), 0, 11),
            Font = Theme.fonts.regular,
            TextSize = 9,
            TextColor3 = primary and Theme.colors.black or DIM,
            TextTransparency = primary and 0.35 or 0,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2,
        })
    end

    local enabled = true
    local api = {}

    local function paintEnabled()
        local fade = enabled and 0 or 0.45
        button.BackgroundTransparency = fade
        label.TextTransparency = enabled and 0 or 0.45
        if descLabel then
            descLabel.TextTransparency = enabled and (primary and 0.35 or 0) or 0.6
        end
    end

    button.Activated:Connect(function()
        if not enabled then
            return
        end
        Util.SafeCallback(cfg.callback, true, api)
    end)

    function api:SetText(text)
        label.Text = tostring(text or "")
        return api
    end

    function api:SetEnabled(state)
        enabled = state and true or false
        paintEnabled()
        return api
    end

    function api:GetEnabled()
        return enabled
    end

    addHover(button, base, hovered)
    Util.Press(button)

    refreshSection(section)
    return api
end

-- ---------------------------------------------------------------------------
-- Toggle
-- ---------------------------------------------------------------------------

function Controls.Toggle(section, cfg)
    cfg = cfg or {}
    local mobile = Util.IsMobile()
    local rowH = mobile and 50 or 46
    local trackW = mobile and 44 or 38
    local trackH = mobile and 24 or 20
    local row = newRow(section, rowH)

    local hit = Util.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, rowH),
        BackgroundTransparency = 1,
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 1,
    })
    hit.Parent = row

    local hasDesc = cfg.description ~= nil and cfg.description ~= ""
    local labelH = 14
    local descH = 12
    local contentH = hasDesc and (labelH + 2 + descH) or labelH
    local top = math.floor((rowH - contentH) / 2)
    local labelW = trackW + 20

    Util.Text(row, {
        Text = cfg.text or "",
        Position = UDim2.new(0, 0, 0, top),
        Size = UDim2.new(1, -labelW, 0, labelH),
        Font = Theme.fonts.medium,
        TextSize = 11,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    if hasDesc then
        Util.Text(row, {
            Text = cfg.description,
            Position = UDim2.new(0, 0, 0, top + labelH + 2),
            Size = UDim2.new(1, -labelW, 0, descH),
            Font = Theme.fonts.regular,
            TextSize = 9,
            TextColor3 = DIM,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2,
        })
    end

    local track = Util.Create("Frame", {
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.new(0, trackW, 0, trackH),
        BackgroundColor3 = RAISED,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    track.Parent = row
    Util.Corner(track, trackH / 2)
    Util.Stroke(track, LINE, 1, 0.4)

    local knob = Util.Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 9, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = DIM,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    knob.Parent = track
    Util.Corner(knob, 100)

    local knobScale = Util.Create("UIScale", { Scale = 1 })
    knobScale.Parent = knob

    local state = cfg.value == true
    local api = {}

    local function knobX(on)
        local size = on and 14 or 12
        if on then
            return trackW - 3 - size / 2
        end
        return 3 + size / 2
    end

    local function paint(on, animate)
        local knobSize = on and 14 or 12
        local targetSize = UDim2.new(0, knobSize, 0, knobSize)
        local targetPos = UDim2.new(0, knobX(on), 0.5, 0)
        local targetColor = on and WHITE or DIM
        local trackColor = on and LINE or RAISED

        if animate then
            Util.Tween(track, { BackgroundColor3 = trackColor }, Theme.motion.normal)
            Util.Tween(knob, {
                Size = targetSize,
                Position = targetPos,
                BackgroundColor3 = targetColor,
            }, Theme.motion.normal)
        else
            track.BackgroundColor3 = trackColor
            knob.Size = targetSize
            knob.Position = targetPos
            knob.BackgroundColor3 = targetColor
        end
    end

    paint(state, false)

    function api:Set(value, silent)
        local nextState = value == true
        if nextState == state then
            return api
        end
        state = nextState
        paint(state, true)
        if not silent then
            Util.SafeCallback(cfg.callback, state, api)
        end
        return api
    end

    function api:Get()
        return state
    end

    hit.Activated:Connect(function()
        knobScale.Scale = 0.82
        Util.Tween(knobScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        api:Set(not state)
    end)

    refreshSection(section)
    return api
end

-- ---------------------------------------------------------------------------
-- Slider
-- ---------------------------------------------------------------------------

function Controls.Slider(section, cfg)
    cfg = cfg or {}
    local mobile = Util.IsMobile()
    local row = newRow(section, 52)

    local minV = tonumber(cfg.min) or 0
    local maxV = tonumber(cfg.max) or 100
    if maxV <= minV then
        maxV = minV + 1
    end

    local step = tonumber(cfg.step)
    if step and step <= 0 then
        step = nil
    end

    local suffix = cfg.suffix and tostring(cfg.suffix) or ""
    local knobSize = mobile and 16 or 12
    local inset = mobile and 8 or 6

    local hit = Util.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 1,
    })
    hit.Parent = row

    Util.Text(row, {
        Text = cfg.text or "",
        Position = UDim2.new(0, 0, 0, 2),
        Size = UDim2.new(1, -118, 0, 15),
        Font = Theme.fonts.medium,
        TextSize = 11,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    local valueLabel = Util.Text(row, {
        Text = "",
        Position = UDim2.new(1, -110, 0, 2),
        Size = UDim2.new(0, 110, 0, 15),
        Font = Theme.fonts.mono,
        TextSize = 9,
        TextColor3 = MUTED,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 2,
    })

    local track = Util.Create("Frame", {
        Position = UDim2.new(0, inset, 0, 36),
        Size = UDim2.new(1, -(inset * 2), 0, 4),
        BackgroundColor3 = RAISED,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    track.Parent = row
    Util.Corner(track, 2)

    local fill = Util.Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    fill.Parent = track
    Util.Corner(fill, 2)

    local knob = Util.Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, knobSize, 0, knobSize),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    knob.Parent = track
    Util.Corner(knob, 100)
    Util.Stroke(knob, BG, 1, 0.35)

    local knobScale = Util.Create("UIScale", { Scale = 1 })
    knobScale.Parent = knob

    local current = minV
    local api = {}

    local function normalize(value)
        local n = tonumber(value)
        if n == nil then
            n = minV
        end
        n = Util.Clamp(n, minV, maxV)
        if step then
            n = minV + math.floor((n - minV) / step + 0.5) * step
        end
        n = Util.Clamp(n, minV, maxV)
        return tonumber(string.format("%.6f", n)) or n
    end

    local function ratioOf(value)
        return Util.Clamp((value - minV) / (maxV - minV), 0, 1)
    end

    local dragging = false

    local function paint(value, animate)
        local ratio = ratioOf(value)
        valueLabel.Text = formatValue(value) .. suffix
        if animate and not dragging then
            Util.Tween(fill, { Size = UDim2.new(ratio, 0, 1, 0) }, Theme.motion.fast)
            Util.Tween(knob, { Position = UDim2.new(ratio, 0, 0.5, 0) }, Theme.motion.fast)
        else
            fill.Size = UDim2.new(ratio, 0, 1, 0)
            knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        end
    end

    local function apply(value, silent, animate)
        local nextValue = normalize(value)
        if math.abs(nextValue - current) < 0.0001 then
            return
        end
        current = nextValue
        paint(current, animate)
        if not silent then
            Util.SafeCallback(cfg.callback, current, api)
        end
    end

    function api:Set(value, silent)
        local nextValue = normalize(value)
        if math.abs(nextValue - current) < 0.0001 then
            return api
        end
        current = nextValue
        paint(current, true)
        if not silent then
            Util.SafeCallback(cfg.callback, current, api)
        end
        return api
    end

    function api:Get()
        return current
    end

    local changedConn = nil
    local endedConn = nil

    local function stopDrag()
        if not dragging then
            return
        end
        dragging = false
        if changedConn then
            changedConn:Disconnect()
            changedConn = nil
        end
        if endedConn then
            endedConn:Disconnect()
            endedConn = nil
        end
        Util.Tween(knobScale, { Scale = 1 }, Theme.motion.fast)
    end

    local function seekAt(x)
        local width = track.AbsoluteSize.X
        if width <= 0 then
            return
        end
        local ratio = Util.Clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        local raw = minV + (maxV - minV) * ratio
        if step then
            raw = minV + math.floor((raw - minV) / step + 0.5) * step
        end
        raw = Util.Clamp(raw, minV, maxV)
        apply(raw, false, false)
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if dragging then
            stopDrag()
        end

        seekAt(input.Position.X)
        dragging = true
        knobScale.Scale = 1.25

        changedConn = UserInputService.InputChanged:Connect(function(changed)
            if not dragging then
                return
            end
            if changed.UserInputType == Enum.UserInputType.MouseMovement
                or changed.UserInputType == Enum.UserInputType.Touch then
                seekAt(changed.Position.X)
            end
        end)

        endedConn = UserInputService.InputEnded:Connect(function(ended)
            if ended.UserInputType == Enum.UserInputType.MouseButton1
                or ended.UserInputType == Enum.UserInputType.Touch then
                stopDrag()
            end
        end)
    end)

    current = normalize(cfg.value ~= nil and cfg.value or minV)
    paint(current, false)

    refreshSection(section)
    return api
end

-- ---------------------------------------------------------------------------
-- Dropdown
-- ---------------------------------------------------------------------------

function Controls.Dropdown(section, cfg)
    cfg = cfg or {}
    local mobile = Util.IsMobile()
    local multi = cfg.multi == true
    local fieldH = mobile and 42 or 36
    local itemH = mobile and 40 or 32
    local row, fieldY = fieldRow(section, cfg, fieldH)

    local field = Util.Create("TextButton", {
        Position = UDim2.new(0, 0, 0, fieldY),
        Size = UDim2.new(1, 0, 0, fieldH),
        BackgroundColor3 = RAISED,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        ZIndex = 1,
    })
    field.Parent = row
    Util.Corner(field, 8)

    local fieldStroke = Util.Create("UIStroke", {
        Color = LINE,
        Thickness = 1,
        Transparency = 0.45,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    fieldStroke.Parent = field

    local fieldLabel = Util.Text(field, {
        Text = "",
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -42, 1, 0),
        Font = Theme.fonts.medium,
        TextSize = 10,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    local chevron = Icons.Draw(field, "chevron-down", 14, MUTED)
    if chevron then
        chevron.AnchorPoint = Vector2.new(1, 0.5)
        chevron.Position = UDim2.new(1, -12, 0.5, 0)
        chevron.ZIndex = 2
    end

    addHover(field, RAISED, HOVER)

    local options = {}
    if type(cfg.options) == "table" then
        for _, option in ipairs(cfg.options) do
            options[#options + 1] = tostring(option)
        end
    end

    local block = Util.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 1,
    })

    local list = Util.Create("Frame", {
        Position = UDim2.new(0, 0, 0, 4),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = SURFACE,
        BorderSizePixel = 0,
        ZIndex = 1,
    })
    list.Parent = block
    Util.Corner(list, 8)
    Util.Stroke(list, LINE, 1, 0.4)

    local listLayout = Util.Create("UIListLayout", {
        Padding = UDim.new(0, 2),
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    listLayout.Parent = list
    Util.Padding(list, 4, 4)

    local selected = {}
    local items = {}
    local isOpen = false
    local listTween = nil
    local api = {}

    local function selectedArray()
        local out = {}
        for _, option in ipairs(options) do
            if selected[option] then
                out[#out + 1] = option
            end
        end
        if #out == 0 then
            for option in pairs(selected) do
                out[#out + 1] = option
            end
        end
        return out
    end

    local function getValue()
        local out = selectedArray()
        if multi then
            return out
        end
        return out[1]
    end

    local function paintSelection()
        for _, entry in ipairs(items) do
            local on = selected[entry.option] == true
            entry.label.TextColor3 = on and TEXT or MUTED
            entry.label.Font = on and Theme.fonts.medium or Theme.fonts.regular
            if entry.check then
                entry.check.Visible = on
            end
        end

        local picked = selectedArray()
        if #picked == 0 then
            if #options == 0 then
                fieldLabel.Text = cfg.placeholder or "No options"
            else
                fieldLabel.Text = cfg.placeholder or "Select an option"
            end
            fieldLabel.TextColor3 = DIM
        else
            fieldLabel.Text = table.concat(picked, ", ")
            fieldLabel.TextColor3 = TEXT
        end
    end

    local function listHeight()
        local count = #options
        if count == 0 then
            return 0
        end
        return 8 + count * itemH + (count - 1) * 2
    end

    local closeList

    local function pick(option)
        if multi then
            if selected[option] then
                selected[option] = nil
            else
                selected[option] = true
            end
            paintSelection()
            Util.SafeCallback(cfg.callback, getValue(), api)
        else
            selected = { [option] = true }
            paintSelection()
            Util.SafeCallback(cfg.callback, option, api)
            closeList()
        end
    end

    local function rebuild()
        for _, entry in ipairs(items) do
            if entry.frame then
                entry.frame:Destroy()
            end
        end
        items = {}

        for index, option in ipairs(options) do
            local choice = option
            local item = Util.Create("TextButton", {
                Size = UDim2.new(1, 0, 0, itemH),
                BackgroundColor3 = SURFACE,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = index,
                ZIndex = 1,
            })
            item.Parent = list
            Util.Corner(item, 6)
            addHover(item, SURFACE, HOVER)

            local itemLabel = Util.Text(item, {
                Text = option,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -36, 1, 0),
                Font = Theme.fonts.regular,
                TextSize = 10,
                TextColor3 = MUTED,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 2,
            })

            local check = Icons.Draw(item, "check", 12, WHITE)
            if check then
                check.AnchorPoint = Vector2.new(1, 0.5)
                check.Position = UDim2.new(1, -10, 0.5, 0)
                check.Visible = false
                check.ZIndex = 2
            end

            item.Activated:Connect(function()
                pick(choice)
            end)

            items[#items + 1] = {
                frame = item,
                label = itemLabel,
                check = check,
                option = choice,
            }
        end
    end

    local function targetHeight()
        local height = listHeight()
        if height > 0 then
            return height + 4
        end
        return 0
    end

    local function setChevron(degrees)
        if chevron then
            Util.Tween(chevron, { Rotation = degrees }, Theme.motion.normal,
                Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
    end

    local function setFieldStroke(open)
        Util.Tween(fieldStroke, {
            Color = open and WHITE or LINE,
            Transparency = open and 0.35 or 0.45,
        }, Theme.motion.fast)
    end

    local function openList()
        if isOpen or #options == 0 then
            return
        end
        isOpen = true
        block.Visible = true
        if listTween then
            listTween:Cancel()
        end
        listTween = Util.Tween(block, {
            Size = UDim2.new(1, 0, 0, targetHeight()),
        }, Theme.motion.normal, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        setChevron(180)
        setFieldStroke(true)
        refreshSection(section)
    end

    closeList = function()
        if not isOpen then
            return
        end
        isOpen = false
        if listTween then
            listTween:Cancel()
        end
        listTween = Util.Tween(block, {
            Size = UDim2.new(1, 0, 0, 0),
        }, Theme.motion.normal, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local thisTween = listTween
        thisTween.Completed:Connect(function()
            if not isOpen and thisTween == listTween then
                block.Visible = false
            end
        end)
        setChevron(0)
        setFieldStroke(false)
        refreshSection(section)
    end

    rebuild()
    paintSelection()

    list.Size = UDim2.new(1, 0, 0, listHeight())
    block.Size = UDim2.new(1, 0, 0, 0)
    section:AddBlock(block)

    field.Activated:Connect(function()
        if isOpen then
            closeList()
        else
            openList()
        end
    end)

    function api:Open()
        openList()
        return api
    end

    function api:Close()
        closeList()
        return api
    end

    function api:Get()
        return getValue()
    end

    function api:Set(value, silent)
        selected = {}
        if multi then
            if type(value) == "table" then
                for key, entry in pairs(value) do
                    if type(key) == "number" then
                        selected[tostring(entry)] = true
                    elseif entry then
                        selected[tostring(key)] = true
                    end
                end
            elseif value ~= nil then
                selected[tostring(value)] = true
            end
        else
            if type(value) == "table" then
                value = value[1]
            end
            if value ~= nil then
                selected[tostring(value)] = true
            end
        end
        paintSelection()
        if not silent then
            Util.SafeCallback(cfg.callback, getValue(), api)
        end
        return api
    end

    function api:Refresh(newOptions)
        if newOptions ~= nil then
            options = {}
            if type(newOptions) == "table" then
                for _, option in ipairs(newOptions) do
                    options[#options + 1] = tostring(option)
                end
            end

            local kept = {}
            for _, option in ipairs(options) do
                if selected[option] then
                    kept[option] = true
                end
            end
            selected = kept
        end

        rebuild()
        paintSelection()
        list.Size = UDim2.new(1, 0, 0, listHeight())
        if isOpen and #options == 0 then
            closeList()
        elseif isOpen then
            if listTween then
                listTween:Cancel()
            end
            listTween = Util.Tween(block, {
                Size = UDim2.new(1, 0, 0, targetHeight()),
            }, Theme.motion.normal, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
        refreshSection(section)
        return api
    end

    if cfg.value ~= nil then
        selected = {}
        if multi and type(cfg.value) == "table" then
            for key, entry in pairs(cfg.value) do
                if type(key) == "number" then
                    selected[tostring(entry)] = true
                elseif entry then
                    selected[tostring(key)] = true
                end
            end
        elseif type(cfg.value) == "table" then
            if cfg.value[1] ~= nil then
                selected[tostring(cfg.value[1])] = true
            end
        else
            selected[tostring(cfg.value)] = true
        end
        paintSelection()
    end

    refreshSection(section)
    return api
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function Controls.Input(section, cfg)
    cfg = cfg or {}
    local mobile = Util.IsMobile()
    local fieldH = mobile and 42 or 36
    local row, fieldY = fieldRow(section, cfg, fieldH)

    local box = Util.Create("TextBox", {
        Position = UDim2.new(0, 0, 0, fieldY),
        Size = UDim2.new(1, 0, 0, fieldH),
        BackgroundColor3 = BG,
        BorderSizePixel = 0,
        Text = cfg.value ~= nil and tostring(cfg.value) or "",
        TextColor3 = TEXT,
        Font = Theme.fonts.regular,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        PlaceholderText = cfg.placeholder or "",
        PlaceholderColor3 = DIM,
        ClearTextOnFocus = false,
        MultiLine = false,
        TextWrapped = false,
        ClipsDescendants = true,
        ZIndex = 1,
    })
    box.Parent = row
    Util.Corner(box, 8)
    Util.Padding(box, 12, 0)

    local boxStroke = Util.Create("UIStroke", {
        Color = LINE,
        Thickness = 1,
        Transparency = 0.45,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    boxStroke.Parent = box

    local submitted = false
    local api = {}

    local function notify()
        Util.SafeCallback(cfg.callback, box.Text, api)
    end

    local function focusStroke(focused)
        Util.Tween(boxStroke, {
            Color = focused and WHITE or LINE,
            Transparency = focused and 0 or 0.45,
        }, Theme.motion.fast)
    end

    box.Focused:Connect(function()
        submitted = false
        focusStroke(true)
    end)

    -- TextBox has no standalone ReturnPressed event; FocusLost's enterPressed
    -- argument is the desktop return path. Mobile returns through the on-screen
    -- keyboard event, and the flag prevents a second callback on blur.
    box.FocusLost:Connect(function()
        focusStroke(false)
        if submitted then
            submitted = false
            return
        end
        notify()
    end)

    if box.ReturnPressedFromOnScreenKeyboard then
        box.ReturnPressedFromOnScreenKeyboard:Connect(function()
            if not submitted then
                submitted = true
                notify()
            end
        end)
    end

    function api:Set(value, silent)
        box.Text = value ~= nil and tostring(value) or ""
        if not silent then
            Util.SafeCallback(cfg.callback, box.Text, api)
        end
        return api
    end

    function api:Get()
        return box.Text
    end

    function api:Focus()
        box:CaptureFocus()
        local cursor = string.len(box.Text) + 1
        box.CursorPosition = cursor
        return api
    end

    refreshSection(section)
    return api
end

-- ---------------------------------------------------------------------------
-- Keybind
-- ---------------------------------------------------------------------------

local activeKeybindCancel = nil

local function keyName(value)
    if value == nil then
        return nil
    end
    local ok, name = pcall(function()
        return value.Name
    end)
    if ok and type(name) == "string" then
        return name
    end
    return tostring(value)
end

function Controls.Keybind(section, cfg)
    cfg = cfg or {}
    local mobile = Util.IsMobile()
    local rowH = mobile and 50 or 46
    local row = newRow(section, rowH)

    local hasDesc = cfg.description ~= nil and cfg.description ~= ""
    local labelH = 14
    local descH = 12
    local contentH = hasDesc and (labelH + 2 + descH) or labelH
    local top = math.floor((rowH - contentH) / 2)
    local reserve = mobile and 118 or 104

    Util.Text(row, {
        Text = cfg.text or "",
        Position = UDim2.new(0, 0, 0, top),
        Size = UDim2.new(1, -reserve, 0, labelH),
        Font = Theme.fonts.medium,
        TextSize = 11,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    if hasDesc then
        Util.Text(row, {
            Text = cfg.description,
            Position = UDim2.new(0, 0, 0, top + labelH + 2),
            Size = UDim2.new(1, -reserve, 0, descH),
            Font = Theme.fonts.regular,
            TextSize = 9,
            TextColor3 = DIM,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2,
        })
    end

    local hitW = mobile and 104 or 96
    local hitH = mobile and 46 or 44
    local pillW = mobile and 84 or 76
    local pillH = mobile and 30 or 26

    local hit = Util.Create("TextButton", {
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.new(0, hitW, 0, hitH),
        BackgroundTransparency = 1,
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 1,
    })
    hit.Parent = row

    local pill = Util.Create("Frame", {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, pillW, 0, pillH),
        BackgroundColor3 = RAISED,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    pill.Parent = hit
    Util.Corner(pill, 6)
    local pillStroke = Util.Create("UIStroke", {
        Color = LINE,
        Thickness = 1,
        Transparency = 0.4,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    pillStroke.Parent = pill

    local pillLabel = Util.Text(pill, {
        Text = "",
        Size = UDim2.new(1, 0, 1, 0),
        Font = Theme.fonts.mono,
        TextSize = 9,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    })

    addHover(pill, RAISED, HOVER)

    local value = cfg.value
    local listening = false
    local captureConn = nil
    local api = {}

    local function paintValue()
        if listening then
            pillLabel.Text = "PRESS A KEY"
            pillLabel.TextColor3 = WHITE
            pill.BackgroundColor3 = HOVER
            pillStroke.Color = WHITE
            pillStroke.Transparency = 0.2
            return
        end
        local name = keyName(value)
        if name then
            pillLabel.Text = name
            pillLabel.TextColor3 = TEXT
        else
            pillLabel.Text = "—"
            pillLabel.TextColor3 = DIM
        end
        pill.BackgroundColor3 = RAISED
        pillStroke.Color = LINE
        pillStroke.Transparency = 0.4
    end

    local function cancelCapture()
        if captureConn then
            captureConn:Disconnect()
            captureConn = nil
        end
        listening = false
        if activeKeybindCancel == cancelCapture then
            activeKeybindCancel = nil
        end
        paintValue()
    end

    local function startCapture()
        if listening then
            cancelCapture()
            return
        end
        if activeKeybindCancel and activeKeybindCancel ~= cancelCapture then
            activeKeybindCancel()
        end

        listening = true
        activeKeybindCancel = cancelCapture
        paintValue()

        captureConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end
            if input.KeyCode == Enum.KeyCode.Escape then
                cancelCapture()
                return
            end
            if gameProcessed then
                return
            end

            local key = input.KeyCode
            local changed = key ~= value
            value = key
            cancelCapture()
            paintValue()
            if changed then
                Util.SafeCallback(cfg.callback, key, api)
            end
        end)
    end

    function api:Set(key, silent)
        local changed = key ~= value
        value = key
        if listening then
            cancelCapture()
        end
        paintValue()
        if changed and not silent then
            Util.SafeCallback(cfg.callback, value, api)
        end
        return api
    end

    function api:Get()
        return value
    end

    hit.Activated:Connect(function()
        startCapture()
    end)

    paintValue()
    refreshSection(section)
    return api
end

-- ---------------------------------------------------------------------------
-- Progress
-- ---------------------------------------------------------------------------

function Controls.Progress(section, cfg)
    cfg = cfg or {}
    local row = newRow(section, 46)
    local value = Util.Clamp(tonumber(cfg.value) or 0, 0, 1)

    Util.Text(row, {
        Text = cfg.text or "",
        Position = UDim2.new(0, 0, 0, 2),
        Size = UDim2.new(1, -72, 0, 15),
        Font = Theme.fonts.medium,
        TextSize = 11,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    local valueLabel = Util.Text(row, {
        Text = "",
        Position = UDim2.new(1, -66, 0, 2),
        Size = UDim2.new(0, 66, 0, 15),
        Font = Theme.fonts.mono,
        TextSize = 9,
        TextColor3 = MUTED,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 2,
    })

    local track = Util.Create("Frame", {
        Position = UDim2.new(0, 0, 0, 31),
        Size = UDim2.new(1, 0, 0, 4),
        BackgroundColor3 = RAISED,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    track.Parent = row
    Util.Corner(track, 2)

    local fill = Util.Create("Frame", {
        Size = UDim2.new(value, 0, 1, 0),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    fill.Parent = track
    Util.Corner(fill, 2)

    local function paint(animate)
        valueLabel.Text = tostring(math.floor(value * 100 + 0.5)) .. "%"
        if animate then
            Util.Tween(fill, { Size = UDim2.new(value, 0, 1, 0) }, Theme.motion.normal,
                Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        else
            fill.Size = UDim2.new(value, 0, 1, 0)
        end
    end

    local api = {}

    function api:Set(nextValue, silent)
        value = Util.Clamp(tonumber(nextValue) or 0, 0, 1)
        paint(true)
        return api
    end

    paint(false)
    refreshSection(section)
    return api
end


--[[
    05_layout.lua
    Section cards, labels, paragraphs, dividers, standalone cards and spacers.
    Layout is intentionally height-agnostic: every container uses AutomaticSize
    so dropdown blocks and wrapped copy can grow without clipping.
]]

local Layout = {}

local LayoutPad = 14
local LayoutMobilePad = 12
local LayoutStrokeTransparency = 0.82

local function LayoutStroke(obj, transparency)
    Util.Stroke(obj, Theme.colors.line, 1, transparency or Theme.stroke or LayoutStrokeTransparency)
end

local function LayoutCreate(className, parent, props)
    local object = Util.Create(className, props or {})
    if parent then
        object.Parent = parent
    end
    return object
end

local function LayoutIsInstance(value)
    if value == nil then
        return false
    end
    if type(value) == "userdata" then
        return true
    end
    if type(value) == "table" then
        -- Some lightweight Roblox mocks represent instances as tables.
        return value.ClassName ~= nil or value.Name ~= nil
    end
    return false
end

local function LayoutTarget(value)
    if type(value) == "table" then
        if LayoutIsInstance(value.content) then
            return value.content
        end
        if LayoutIsInstance(value.frame) then
            return value.frame
        end
    end
    if LayoutIsInstance(value) then
        return value
    end
    return nil
end

local function LayoutResolve(a, b)
    local target = LayoutTarget(a)
    if target then
        return target, b
    end
    target = LayoutTarget(b)
    if target then
        return target, a
    end
    return nil, a
end

local function LayoutText(parent, props)
    local options = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Theme.fonts.regular,
        Text = "",
        TextColor3 = Theme.colors.muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        RichText = false,
    }
    if props then
        for key, value in pairs(props) do
            options[key] = value
        end
    end
    local label = Util.Create("TextLabel", options)
    if parent then
        label.Parent = parent
    end
    return label
end

local function LayoutSetLineHeight(label, height)
    pcall(function()
        label.LineHeight = height
    end)
end

local function LayoutPaddingValue()
    if Util.IsMobile() then
        return LayoutMobilePad
    end
    return Theme.pad or LayoutPad
end

-- Standalone atoms -----------------------------------------------------------

function Layout.Label(a, b)
    local parent, cfg = LayoutResolve(a, b)
    if type(cfg) == "string" then
        cfg = { text = cfg }
    end
    cfg = cfg or {}

    local label = LayoutText(parent, {
        Name = "Label",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = tostring(cfg.text or ""),
        TextSize = 10,
        TextColor3 = cfg.color or Theme.colors.muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    LayoutCreate("UIPadding", label, {
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
    })
    return label
end

function Layout.Paragraph(a, b)
    local parent, cfg = LayoutResolve(a, b)
    if type(cfg) == "string" then
        cfg = { text = cfg }
    end
    cfg = cfg or {}

    local paragraph = LayoutText(parent, {
        Name = "Paragraph",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = tostring(cfg.text or ""),
        TextSize = 10,
        TextColor3 = cfg.color or Theme.colors.muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    LayoutSetLineHeight(paragraph, 1.65)
    LayoutCreate("UIPadding", paragraph, {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 8),
    })
    return paragraph
end

function Layout.Divider(parent)
    parent = LayoutTarget(parent)
    local wrap = LayoutCreate("Frame", parent, {
        Name = "Divider",
        Size = UDim2.new(1, 0, 0, 21),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    LayoutCreate("Frame", wrap, {
        Name = "Line",
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 10),
        BackgroundColor3 = Theme.colors.line,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
    })
    return wrap
end

function Layout.Spacer(a, b)
    local parent = nil
    local size = 8

    if type(a) == "number" then
        size = a
        parent = LayoutTarget(b)
    elseif LayoutIsInstance(a) or (type(a) == "table" and a.content) then
        parent = LayoutTarget(a)
        size = tonumber(b) or 8
    elseif a == nil then
        parent = LayoutTarget(b)
    end

    return LayoutCreate("Frame", parent, {
        Name = "Spacer",
        Size = UDim2.new(1, 0, 0, math.max(0, math.floor(size + 0.5))),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
end

function Layout.Card(a, b)
    local parent, cfg = LayoutResolve(a, b)
    if type(cfg) == "string" then
        cfg = { title = cfg }
    end
    cfg = cfg or {}

    local pad = LayoutPaddingValue()
    local card = LayoutCreate("Frame", parent, {
        Name = "Card",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.colors.raised,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })
    Util.Corner(card, Theme.radius.lg)
    LayoutStroke(card)

    LayoutCreate("UIPadding", card, {
        PaddingLeft = UDim.new(0, pad),
        PaddingRight = UDim.new(0, pad),
        PaddingTop = UDim.new(0, pad),
        PaddingBottom = UDim.new(0, pad),
    })
    LayoutCreate("UIListLayout", card, {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local actionCfg = cfg.action
    if type(actionCfg) == "function" then
        actionCfg = { callback = actionCfg }
    elseif type(actionCfg) == "string" then
        actionCfg = { text = actionCfg }
    end
    if not actionCfg and cfg.actionText then
        actionCfg = { text = cfg.actionText, callback = cfg.actionCallback }
    end

    local hasIcon = cfg.icon ~= nil and cfg.icon ~= ""
    local topHeight = hasIcon and 26 or 18

    local top = LayoutCreate("Frame", card, {
        Name = "Heading",
        Size = UDim2.new(1, 0, 0, topHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    })

    local textX = 0
    if hasIcon then
        local tile = LayoutCreate("Frame", top, {
            Name = "IconTile",
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Theme.colors.hover,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
        })
        Util.Corner(tile, 7)
        LayoutStroke(tile, 0.55)
        Icons.Draw(tile, cfg.icon, 14, Theme.colors.text, 2)
        textX = 34
    end

    local titleRight = 0
    if actionCfg then
        titleRight = 82
    end

    LayoutText(top, {
        Name = "CardTitle",
        Size = UDim2.new(1, -(textX + titleRight), 0, topHeight),
        Position = UDim2.new(0, textX, 0, 0),
        Text = tostring(cfg.title or ""),
        TextSize = 12,
        Font = Theme.fonts.bold,
        TextColor3 = Theme.colors.text,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    if actionCfg then
        local action = LayoutCreate("TextButton", top, {
            Name = "CardAction",
            Size = UDim2.fromOffset(74, 24),
            Position = UDim2.new(1, 0, 0.5, 0),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.colors.raised,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Text = tostring(actionCfg.text or "Open"),
            Font = Theme.fonts.medium,
            TextSize = 9,
            TextColor3 = Theme.colors.muted,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AutoButtonColor = false,
        })
        Util.Corner(action, 7)
        LayoutStroke(action, 0.55)
        Util.Hover(action, Theme.colors.raised, Theme.colors.hover)
        Util.Press(action)
        action.Activated:Connect(function()
            Util.SafeCallback(actionCfg.callback)
        end)
    end

    local bodyText = cfg.text or cfg.body
    if bodyText and tostring(bodyText) ~= "" then
        local bodyWrap = LayoutCreate("Frame", card, {
            Name = "Body",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        })
        LayoutCreate("UIPadding", bodyWrap, {
            PaddingTop = UDim.new(0, 8),
        })
        local body = LayoutText(bodyWrap, {
            Name = "CardBody",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = tostring(bodyText),
            TextSize = 10,
            TextColor3 = Theme.colors.muted,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        LayoutSetLineHeight(body, 1.55)
    end

    return card
end

-- Section cards --------------------------------------------------------------

local Section = {}
Section.__index = Section

function Layout.Section(tab, cfg)
    tab = tab or {}
    cfg = cfg or {}

    local parent = tab.content
    if not parent then
        parent = tab.frame
    end

    local card = LayoutCreate("Frame", parent, {
        Name = "Section",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.colors.raised,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })
    Util.Corner(card, Theme.radius.lg)
    LayoutStroke(card)

    local cardLayout = LayoutCreate("UIListLayout", card, {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local pad = LayoutPaddingValue()

    local header = LayoutCreate("Frame", card, {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    })

    local iconTile = nil
    if cfg.icon and cfg.icon ~= "" then
        iconTile = LayoutCreate("Frame", header, {
            Name = "IconTile",
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(0, pad, 0, 9),
            BackgroundColor3 = Theme.colors.hover,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
        })
        Util.Corner(iconTile, 7)
        LayoutStroke(iconTile, 0.55)
        Icons.Draw(iconTile, cfg.icon, 14, Theme.colors.text, 2)
    end

    local subtitleText = cfg.subtitle
    if subtitleText == nil then
        subtitleText = cfg.description
    end
    if subtitleText ~= nil and tostring(subtitleText) == "" then
        subtitleText = nil
    end

    local badgeCfg = cfg.badge
    local badgeText = nil
    if type(badgeCfg) == "string" then
        badgeText = badgeCfg
    elseif type(badgeCfg) == "number" then
        badgeText = tostring(badgeCfg)
    elseif type(badgeCfg) == "table" then
        badgeText = badgeCfg.text or badgeCfg.label
    end
    if badgeText ~= nil and tostring(badgeText) == "" then
        badgeText = nil
    end

    local textX = pad + (iconTile and 36 or 0)
    local badgeReserve = (badgeText and 96 or pad)

    local title = LayoutText(header, {
        Name = "Title",
        Size = UDim2.new(1, -(textX + badgeReserve), 0, 14),
        Position = UDim2.new(0, textX, 0, subtitleText and 8 or 15),
        Text = tostring(cfg.title or "Section"),
        TextSize = 12,
        Font = Theme.fonts.bold,
        TextColor3 = Theme.colors.text,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    local subtitle = nil
    if subtitleText then
        subtitle = LayoutText(header, {
            Name = "Subtitle",
            Size = UDim2.new(1, -(textX + badgeReserve), 0, 11),
            Position = UDim2.new(0, textX, 0, 24),
            Text = tostring(subtitleText),
            TextSize = 9,
            Font = Theme.fonts.mono,
            TextColor3 = Theme.colors.dim,
            TextWrapped = false,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextYAlignment = Enum.TextYAlignment.Center,
        })
    end

    local badge = nil
    if badgeText then
        badge = LayoutText(header, {
            Name = "Badge",
            Size = UDim2.new(0, 0, 0, 18),
            AutomaticSize = Enum.AutomaticSize.X,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -pad, 0.5, 0),
            BackgroundColor3 = Theme.colors.hover,
            BackgroundTransparency = 0,
            Text = tostring(badgeText),
            TextSize = 8,
            Font = Theme.fonts.mono,
            TextColor3 = Theme.colors.muted,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
        })
        Util.Corner(badge, 9)
        LayoutStroke(badge, 0.55)
        LayoutCreate("UIPadding", badge, {
            PaddingLeft = UDim.new(0, 7),
            PaddingRight = UDim.new(0, 7),
        })
    end

    LayoutCreate("Frame", header, {
        Name = "Hairline",
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.colors.line,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
    })

    local content = LayoutCreate("Frame", card, {
        Name = "Content",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        LayoutOrder = 2,
    })

    local contentPadding = LayoutCreate("UIPadding", content, {
        PaddingLeft = UDim.new(0, pad),
        PaddingRight = UDim.new(0, pad),
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 10),
    })

    local contentLayout = LayoutCreate("UIListLayout", content, {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local section = setmetatable({
        frame = card,
        content = content,
        window = tab.window or tab._window,
        tab = tab,
        _rows = {},
        _blocks = {},
        _order = 0,
        _header = header,
        _iconTile = iconTile,
        _title = title,
        _subtitle = subtitle,
        _badge = badge,
        _layout = contentLayout,
        _cardLayout = cardLayout,
        _padding = contentPadding,
        _refreshQueued = false,
        _destroyed = false,
        _viewportConnection = nil,
    }, Section)

    local function updateChrome()
        local currentPad = LayoutPaddingValue()
        contentPadding.PaddingLeft = UDim.new(0, currentPad)
        contentPadding.PaddingRight = UDim.new(0, currentPad)

        if iconTile then
            iconTile.Position = UDim2.new(0, currentPad, 0, 9)
        end

        local currentX = currentPad + (iconTile and 36 or 0)
        local currentReserve = badge and 96 or currentPad

        title.Position = UDim2.new(0, currentX, 0, subtitle and 8 or 15)
        title.Size = UDim2.new(1, -(currentX + currentReserve), 0, 14)
        if subtitle then
            subtitle.Position = UDim2.new(0, currentX, 0, 24)
            subtitle.Size = UDim2.new(1, -(currentX + currentReserve), 0, 11)
        end
        if badge then
            badge.Position = UDim2.new(1, -currentPad, 0.5, 0)
        end
    end

    updateChrome()

    if Util.OnViewportChanged then
        local gui = nil
        pcall(function()
            gui = card:FindFirstAncestorOfClass("ScreenGui")
        end)
        if gui then
            section._viewportConnection = Util.OnViewportChanged(gui, updateChrome)
        end
    end

    function section:AddRow(row)
        if not row or self._destroyed then
            return row
        end
        self._order = self._order + 1
        row.LayoutOrder = self._order
        row.Parent = self.content
        table.insert(self._rows, row)
        self:Refresh()
        return row
    end

    function section:AddBlock(block)
        if not block or self._destroyed then
            return block
        end
        self._order = self._order + 1
        block.LayoutOrder = self._order
        block.Parent = self.content
        table.insert(self._blocks, block)
        self:Refresh()
        return block
    end

    function section:Refresh()
        if self._destroyed then
            return
        end

        local lastIndex = 0
        for index = #self._rows, 1, -1 do
            local row = self._rows[index]
            if row and row.Parent then
                lastIndex = index
                break
            end
        end

        for index = 1, #self._rows do
            local row = self._rows[index]
            if row and row.Parent then
                local divider = row:FindFirstChild("Divider")
                if divider then
                    divider.Visible = index ~= lastIndex
                end
            end
        end

        -- Reasserting AutomaticSize is a cheap way to force a fresh content
        -- measurement after controls append rows or expand a dropdown block.
        self.content.AutomaticSize = Enum.AutomaticSize.Y
        self.frame.AutomaticSize = Enum.AutomaticSize.Y
        self._layout.SortOrder = Enum.SortOrder.LayoutOrder

        if not self._refreshQueued then
            self._refreshQueued = true
            local selfRef = self
            task.defer(function()
                selfRef._refreshQueued = false
                if selfRef._destroyed then
                    return
                end
                if selfRef.frame.Parent == nil then
                    return
                end
                selfRef.frame.AutomaticSize = Enum.AutomaticSize.Y
                selfRef.content.AutomaticSize = Enum.AutomaticSize.Y
            end)
        end
    end

    function section:Label(labelCfg)
        local label = Layout.Label(self.content, labelCfg)
        self:AddBlock(label)
        return label
    end

    function section:Paragraph(paragraphCfg)
        local paragraph = Layout.Paragraph(self.content, paragraphCfg)
        self:AddBlock(paragraph)
        return paragraph
    end

    function section:Divider()
        local divider = Layout.Divider(self.content)
        self:AddBlock(divider)
        return divider
    end

    function section:Card(cardCfg)
        local cardBlock = Layout.Card(self.content, cardCfg)
        self:AddBlock(cardBlock)
        return cardBlock
    end

    function section:Spacer(px)
        local spacer = Layout.Spacer(self.content, px or 8)
        self:AddBlock(spacer)
        return spacer
    end

    function section:Button(buttonCfg)
        local control = Controls.Button(self, buttonCfg)
        self:Refresh()
        return control
    end

    function section:Toggle(toggleCfg)
        local control = Controls.Toggle(self, toggleCfg)
        self:Refresh()
        return control
    end

    function section:Slider(sliderCfg)
        local control = Controls.Slider(self, sliderCfg)
        self:Refresh()
        return control
    end

    function section:Dropdown(dropdownCfg)
        local control = Controls.Dropdown(self, dropdownCfg)
        self:Refresh()
        return control
    end

    function section:Input(inputCfg)
        local control = Controls.Input(self, inputCfg)
        self:Refresh()
        return control
    end

    function section:Keybind(keybindCfg)
        local control = Controls.Keybind(self, keybindCfg)
        self:Refresh()
        return control
    end

    function section:Progress(progressCfg)
        local control = Controls.Progress(self, progressCfg)
        self:Refresh()
        return control
    end

    function section:Destroy()
        if self._destroyed then
            return
        end
        self._destroyed = true
        if self._viewportConnection then
            pcall(function()
                if type(self._viewportConnection) == "function" then
                    self._viewportConnection()
                else
                    self._viewportConnection:Disconnect()
                end
            end)
            self._viewportConnection = nil
        end
        if self.frame then
            self.frame:Destroy()
        end
    end

    return section
end


--[[
    06_feedback.lua
    Notifications and confirmation dialogs. Both are built from plain Frames,
    TextLabels and embedded icon paths so nothing external is required.
]]

local Feedback = {}

local FeedbackStacks = {}
local FeedbackOverlays = {}

local function FeedbackStroke(obj, transparency)
    Util.Stroke(obj, Theme.colors.line, 1, transparency or Theme.stroke or 0.82)
end

local function FeedbackCreate(className, parent, props)
    local object = Util.Create(className, props or {})
    if parent then
        object.Parent = parent
    end
    return object
end

local function FeedbackText(parent, props)
    local options = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Theme.fonts.regular,
        Text = "",
        TextColor3 = Theme.colors.muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        RichText = false,
    }
    if props then
        for key, value in pairs(props) do
            options[key] = value
        end
    end
    local label = Util.Create("TextLabel", options)
    if parent then
        label.Parent = parent
    end
    return label
end

local function FeedbackSetLineHeight(label, height)
    pcall(function()
        label.LineHeight = height
    end)
end

local function FeedbackConnect(state, signal, callback)
    local connection = signal:Connect(callback)
    if state and state.connections then
        table.insert(state.connections, connection)
    end
    return connection
end

local function FeedbackDisconnectAll(state)
    if not state or not state.connections then
        return
    end
    for _, connection in ipairs(state.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    state.connections = {}
end

-- Transparency fade helpers. A CanvasGroup would be cheaper, but this keeps
-- notifications compatible with both CanvasGroup and plain Frame mocks.
local function FeedbackCollectFades(root)
    local entries = {}

    local function visit(object)
        if object:IsA("GuiObject") then
            local background = object.BackgroundTransparency
            if background < 1 then
                table.insert(entries, {
                    object = object,
                    property = "BackgroundTransparency",
                    target = background,
                })
            end

            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                local text = object.TextTransparency
                if text < 1 then
                    table.insert(entries, {
                        object = object,
                        property = "TextTransparency",
                        target = text,
                    })
                end
            elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
                local image = object.ImageTransparency
                if image < 1 then
                    table.insert(entries, {
                        object = object,
                        property = "ImageTransparency",
                        target = image,
                    })
                end
            end
        elseif object:IsA("UIStroke") then
            local stroke = object.Transparency
            if stroke < 1 then
                table.insert(entries, {
                    object = object,
                    property = "Transparency",
                    target = stroke,
                })
            end
        end

        for _, child in ipairs(object:GetChildren()) do
            visit(child)
        end
    end

    visit(root)
    return entries
end

local function FeedbackFadeIn(entries, duration)
    for _, entry in ipairs(entries) do
        entry.object[entry.property] = 1
    end
    for _, entry in ipairs(entries) do
        Util.Tween(entry.object, {
            [entry.property] = entry.target,
        }, duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
end

local function FeedbackFadeOut(entries, duration)
    for _, entry in ipairs(entries) do
        Util.Tween(entry.object, {
            [entry.property] = 1,
        }, duration or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
end

local FeedbackDismiss

-- Notifications --------------------------------------------------------------

function Feedback.Notify(window, cfg)
    cfg = cfg or {}

    local layer = window and window._notifyLayer
    if not layer then
        return nil
    end

    local stack = FeedbackStacks[layer]
    if not stack then
        local existingLayout = nil
        for _, child in ipairs(layer:GetChildren()) do
            if child:IsA("UIListLayout") then
                existingLayout = child
                break
            end
        end

        if not existingLayout then
            existingLayout = Util.Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                VerticalAlignment = Enum.VerticalAlignment.Top,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 8),
            })
            existingLayout.Parent = layer
        end

        stack = {
            items = {},
            order = 0,
            layout = existingLayout,
        }
        FeedbackStacks[layer] = stack
    end

    while #stack.items >= 4 do
        local oldest = stack.items[1]
        if not oldest then
            break
        end
        FeedbackDismiss(oldest, true)
        -- Defensive: never spin if a pre-closed state was somehow retained.
        if stack.items[1] == oldest then
            table.remove(stack.items, 1)
        end
    end

    local viewport = Util.Viewport()
    local width = 300
    if Util.IsMobile() then
        width = math.min(300, math.max(160, viewport.X - 32))
    end
    local layerWidth = layer.AbsoluteSize.X
    if layerWidth > 0 and layerWidth < width then
        width = layerWidth
    end
    width = math.max(160, math.floor(width))

    stack.order = stack.order + 1
    local order = stack.order

    local state = {
        closed = false,
        connections = {},
        entry = stack,
    }

    local root = FeedbackCreate("Frame", layer, {
        Name = string.format("Notification_%03d", order),
        Size = UDim2.new(0, width, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        LayoutOrder = order,
    })

    local card = FeedbackCreate("Frame", root, {
        Name = "Card",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.colors.raised,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Position = UDim2.new(0, 12, 0, 0),
    })
    Util.Corner(card, 10)
    FeedbackStroke(card)
    FeedbackCreate("UIPadding", card, {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
    })
    FeedbackCreate("UIListLayout", card, {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local header = FeedbackCreate("Frame", card, {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    })

    local tile = FeedbackCreate("Frame", header, {
        Name = "IconTile",
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.colors.hover,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
    })
    Util.Corner(tile, 7)
    FeedbackStroke(tile, 0.55)
    Icons.Draw(tile, cfg.icon or "dot", 14, Theme.colors.text, 2)

    FeedbackText(header, {
        Name = "Title",
        Size = UDim2.new(1, -62, 0, 26),
        Position = UDim2.new(0, 36, 0, 0),
        Text = tostring(cfg.title or "Notification"),
        TextSize = 11,
        Font = Theme.fonts.bold,
        TextColor3 = Theme.colors.text,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    local closeButton = FeedbackCreate("TextButton", header, {
        Name = "Close",
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.new(1, -24, 0, 1),
        BackgroundColor3 = Theme.colors.hover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    Util.Corner(closeButton, 6)
    Icons.Draw(closeButton, "close", 12, Theme.colors.muted, 2)

    local closeHover = 0
    FeedbackConnect(state, closeButton.MouseEnter, function()
        closeHover = closeHover + 1
        Util.Tween(closeButton, {
            BackgroundTransparency = 0,
        }, Theme.motion.fast, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
    FeedbackConnect(state, closeButton.MouseLeave, function()
        closeHover = closeHover - 1
        if closeHover < 0 then
            closeHover = 0
        end
        if closeHover == 0 then
            Util.Tween(closeButton, {
                BackgroundTransparency = 1,
            }, Theme.motion.fast, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    end)

    local bodyText = cfg.text
    if bodyText == nil then
        bodyText = cfg.body
    end
    if bodyText == nil then
        bodyText = cfg.message
    end

    if bodyText ~= nil and tostring(bodyText) ~= "" then
        local bodyWrap = FeedbackCreate("Frame", card, {
            Name = "Body",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        })
        FeedbackCreate("UIPadding", bodyWrap, {
            PaddingTop = UDim.new(0, 6),
        })
        local body = FeedbackText(bodyWrap, {
            Name = "Text",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = tostring(bodyText),
            TextSize = 9,
            TextColor3 = Theme.colors.muted,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        FeedbackSetLineHeight(body, 1.5)
    end

    FeedbackCreate("Frame", card, {
        Name = "ProgressGap",
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 3,
    })

    local track = FeedbackCreate("Frame", card, {
        Name = "ProgressTrack",
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.colors.line,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = 4,
    })
    Util.Corner(track, 1)

    local fill = FeedbackCreate("Frame", track, {
        Name = "ProgressFill",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.colors.text,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
    })
    Util.Corner(fill, 1)

    local duration = tonumber(cfg.duration)
    if duration == nil then
        duration = 4
    end
    duration = math.max(0.1, duration)

    state.root = root
    state.card = card
    state.fades = FeedbackCollectFades(card)
    state.drain = Util.Tween(fill, {
        Size = UDim2.new(0, 0, 1, 0),
    }, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

    FeedbackConnect(state, closeButton.Activated, function()
        FeedbackDismiss(state)
    end)
    Util.Press(closeButton)

    table.insert(stack.items, state)

    FeedbackFadeIn(state.fades, 0.18)
    Util.Tween(card, {
        Position = UDim2.new(0, 0, 0, 0),
    }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    task.delay(duration + 0.05, function()
        if state.closed then
            return
        end
        FeedbackDismiss(state)
    end)

    state.Close = function()
        FeedbackDismiss(state)
    end

    return state
end

function FeedbackDismiss(state, instant)
    if not state or state.closed then
        return
    end
    state.closed = true

    FeedbackDisconnectAll(state)

    if state.drain then
        pcall(function()
            state.drain:Cancel()
        end)
        state.drain = nil
    end

    if state.entry and state.entry.items then
        local items = state.entry.items
        for index = #items, 1, -1 do
            if items[index] == state then
                table.remove(items, index)
                break
            end
        end
    end

    local root = state.root
    local card = state.card

    if instant or not root or not root.Parent then
        if root then
            root:Destroy()
        end
        state.root = nil
        state.card = nil
        state.fades = nil
        return
    end

    if state.fades then
        FeedbackFadeOut(state.fades, 0.16)
    end
    if card and card.Parent then
        Util.Tween(card, {
            Position = UDim2.new(0, 12, 0, 0),
        }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end

    task.delay(0.2, function()
        if root then
            root:Destroy()
        end
        state.root = nil
        state.card = nil
        state.fades = nil
    end)
end

-- Dialogs --------------------------------------------------------------------

function Feedback.Dialog(window, cfg)
    cfg = cfg or {}

    local overlay = window and window._overlay
    if not overlay then
        return nil
    end

    local record = FeedbackOverlays[overlay]
    if not record then
        record = {
            count = 0,
            wasVisible = overlay.Visible,
        }
        FeedbackOverlays[overlay] = record
    end
    record.count = record.count + 1
    overlay.Visible = true

    local viewport = Util.Viewport()
    local width = 400
    if Util.IsMobile() then
        width = math.min(400, math.floor(viewport.X * 0.9))
    else
        width = math.min(400, viewport.X - 32)
    end
    local maxWidth = math.max(160, viewport.X - 24)
    width = math.max(160, math.min(width, maxWidth))
    width = math.floor(width)

    local overlayZ = overlay.ZIndex or 100
    -- Each deeper dialog gets its own backdrop above the previous card, so
    -- stacked dialogs cannot be clicked through.
    local baseZ = overlayZ + record.count * 2

    local function dialogGui(className, parent, props)
        local options = props or {}
        if options.ZIndex == nil then
            options.ZIndex = baseZ
        end
        return FeedbackCreate(className, parent, options)
    end

    local state = {
        closed = false,
        connections = {},
    }

    local backdrop = FeedbackCreate("TextButton", overlay, {
        Name = "DialogBackdrop",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.colors.black,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = overlayZ,
    })

    local card = dialogGui("Frame", overlay, {
        Name = "Dialog",
        Size = UDim2.new(0, width, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0.5, 0, 0.5, 6),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.colors.raised,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Active = true,
    })
    Util.Corner(card, Theme.radius.xl)
    FeedbackStroke(card, 0.68)

    local scale = FeedbackCreate("UIScale", card, {
        Scale = 0.97,
    })

    FeedbackCreate("UIPadding", card, {
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),
        PaddingTop = UDim.new(0, 20),
        PaddingBottom = UDim.new(0, 20),
    })
    FeedbackCreate("UIListLayout", card, {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local header = dialogGui("Frame", card, {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    })

    FeedbackText(header, {
        Name = "Title",
        Size = UDim2.new(1, -30, 0, 22),
        Text = tostring(cfg.title or "Confirm"),
        TextSize = 16,
        Font = Theme.fonts.bold,
        TextColor3 = Theme.colors.text,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    local closeButton = dialogGui("TextButton", header, {
        Name = "Close",
        Size = UDim2.fromOffset(22, 22),
        Position = UDim2.new(1, -22, 0, 0),
        BackgroundColor3 = Theme.colors.hover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    Util.Corner(closeButton, 6)
    Icons.Draw(closeButton, "close", 12, Theme.colors.muted, 2)

    local bodyText = cfg.text
    if bodyText == nil then
        bodyText = cfg.body
    end
    if bodyText ~= nil and tostring(bodyText) ~= "" then
        local bodyWrap = dialogGui("Frame", card, {
            Name = "Body",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        })
        FeedbackCreate("UIPadding", bodyWrap, {
            PaddingTop = UDim.new(0, 10),
        })
        local body = FeedbackText(bodyWrap, {
            Name = "Text",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = tostring(bodyText),
            TextSize = 10,
            TextColor3 = Theme.colors.muted,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        FeedbackSetLineHeight(body, 1.65)
    end

    FeedbackCreate("Frame", card, {
        Name = "ActionGap",
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 3,
    })

    local buttonHeight = Util.IsMobile() and 42 or 34
    local actions = dialogGui("Frame", card, {
        Name = "Actions",
        Size = UDim2.new(1, 0, 0, buttonHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 4,
    })

    local confirm = dialogGui("TextButton", actions, {
        Name = "Confirm",
        Size = UDim2.new(0, 92, 0, buttonHeight),
        Position = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.colors.white,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = tostring(cfg.confirmText or "Confirm"),
        Font = Theme.fonts.medium,
        TextSize = 10,
        TextColor3 = Theme.colors.black,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
    })
    Util.Corner(confirm, 8)

    local cancel = dialogGui("TextButton", actions, {
        Name = "Cancel",
        Size = UDim2.new(0, 78, 0, buttonHeight),
        Position = UDim2.new(1, -100, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.colors.raised,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = tostring(cfg.cancelText or "Cancel"),
        Font = Theme.fonts.medium,
        TextSize = 10,
        TextColor3 = Theme.colors.muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
    })
    Util.Corner(cancel, 8)
    FeedbackStroke(cancel, 0.55)

    local function finish(confirmed)
        if state.closed then
            return
        end
        state.closed = true

        FeedbackDisconnectAll(state)

        confirm.Active = false
        cancel.Active = false
        closeButton.Active = false

        if backdrop and backdrop.Parent then
            Util.Tween(backdrop, {
                BackgroundTransparency = 1,
            }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if card and card.Parent then
            Util.Tween(card, {
                Position = UDim2.new(0.5, 0, 0.5, 6),
            }, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
        if scale then
            Util.Tween(scale, {
                Scale = 0.97,
            }, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end

        Util.SafeCallback(cfg.callback, confirmed == true)

        task.delay(0.2, function()
            if backdrop then
                backdrop:Destroy()
            end
            if card then
                card:Destroy()
            end

            local current = FeedbackOverlays[overlay]
            if current then
                current.count = current.count - 1
                if current.count <= 0 then
                    FeedbackOverlays[overlay] = nil
                    if not current.wasVisible then
                        pcall(function()
                            if overlay.Parent ~= nil then
                                overlay.Visible = false
                            end
                        end)
                    end
                end
            end

            state.backdrop = nil
            state.card = nil
        end)
    end

    FeedbackConnect(state, closeButton.MouseEnter, function()
        Util.Tween(closeButton, {
            BackgroundTransparency = 0,
        }, Theme.motion.fast, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
    FeedbackConnect(state, closeButton.MouseLeave, function()
        Util.Tween(closeButton, {
            BackgroundTransparency = 1,
        }, Theme.motion.fast, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)

    FeedbackConnect(state, confirm.MouseEnter, function()
        Util.Tween(confirm, {
            BackgroundColor3 = Color3.fromRGB(226, 226, 230),
        }, Theme.motion.fast, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
    FeedbackConnect(state, confirm.MouseLeave, function()
        Util.Tween(confirm, {
            BackgroundColor3 = Theme.colors.white,
        }, Theme.motion.fast, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
    FeedbackConnect(state, cancel.MouseEnter, function()
        Util.Tween(cancel, {
            BackgroundColor3 = Theme.colors.hover,
            TextColor3 = Theme.colors.text,
        }, Theme.motion.fast, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
    FeedbackConnect(state, cancel.MouseLeave, function()
        Util.Tween(cancel, {
            BackgroundColor3 = Theme.colors.raised,
            TextColor3 = Theme.colors.muted,
        }, Theme.motion.fast, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)

    FeedbackConnect(state, closeButton.Activated, function()
        finish(false)
    end)
    FeedbackConnect(state, cancel.Activated, function()
        finish(false)
    end)
    FeedbackConnect(state, confirm.Activated, function()
        finish(true)
    end)
    FeedbackConnect(state, backdrop.Activated, function()
        finish(false)
    end)

    Util.Press(closeButton)
    Util.Press(cancel)
    Util.Press(confirm)

    pcall(function()
        local userInput = game:GetService("UserInputService")
        FeedbackConnect(state, userInput.InputBegan, function(input, gameProcessed)
            if state.closed then
                return
            end
            if input.KeyCode == Enum.KeyCode.Escape and not gameProcessed then
                finish(false)
            end
        end)
    end)

    Util.Tween(backdrop, {
        BackgroundTransparency = 0.45,
    }, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    Util.Tween(card, {
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    Util.Tween(scale, {
        Scale = 1,
    }, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    state.frame = card
    state.Close = function(confirmed)
        finish(confirmed == true)
    end

    return state
end


--[[
    07_core.lua — window shell, navigation, viewport layout, lifecycle.
    Consumes Theme / Util / Icons / Layout / Feedback; assigns no globals.
]]

local Core = {}

local function coreService(name)
    local ok, svc = pcall(function()
        return game:GetService(name)
    end)
    if ok then
        return svc
    end
    return nil
end

local CorePlayers = coreService("Players")
local CoreUIS = coreService("UserInputService")
local CoreTween = coreService("TweenService")

local CoreTones = {
    ok = Theme.colors.white,
    warn = Theme.colors.dim,
    off = Theme.colors.faint,
}

local function coreSetIconColor(holder, color)
    if not holder then
        return
    end
    pcall(function()
        for _, item in ipairs(holder:GetDescendants()) do
            if item:IsA("GuiObject") and item.BackgroundTransparency < 1 then
                item.BackgroundColor3 = color
            elseif item:IsA("UIStroke") then
                item.Color = color
            end
        end
    end)
end

local function coreHairline(parent, name, position, size)
    return Util.Create("Frame", {
        Name = name or "Hairline",
        BackgroundColor3 = Theme.colors.line,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Position = position or UDim2.new(0, 0, 0, 0),
        Size = size or UDim2.new(1, 0, 0, 1),
        Parent = parent,
    })
end

local function coreLength(value, base, fallback)
    if value == nil then
        return fallback
    end
    local ok, px = pcall(function()
        return value.Scale * base + value.Offset
    end)
    if ok and type(px) == "number" then
        return px
    end
    local number = tonumber(value)
    if number ~= nil then
        return number
    end
    return fallback
end

function Core.CreateWindow(cfg)
    if type(cfg) ~= "table" then
        cfg = {}
    end

    local C = Theme.colors
    local F = Theme.fonts
    local R = Theme.radius or { sm = 6, md = 9, lg = 12, xl = 16 }
    local version = Theme.version or "1.0.0"
    local viewport = Util.Viewport()
    local mobile = Util.IsMobile()
    local headerHeight = mobile and 54 or 62
    local desktopW = math.min(coreLength(cfg.size and cfg.size.X, viewport.X, 760), math.max(1, viewport.X - 16))
    local desktopH = math.min(coreLength(cfg.size and cfg.size.Y, viewport.Y, 500), math.max(1, viewport.Y - 12))

    local window
    local frame
    local connections = {}
    local cleanups = {}
    local activeTweens = {}
    local motionToken = 0
    local lastViewport = viewport
    local laidOut = false
    local targetW = desktopW
    local targetH = desktopH
    local targetX = viewport.X / 2
    local targetY = viewport.Y / 2
    local onCloseCallback = nil

    local function track(conn)
        if conn then
            table.insert(connections, conn)
        end
        return conn
    end

    local function addCleanup(fn)
        if type(fn) == "function" then
            table.insert(cleanups, fn)
        end
    end

    local function connect(signal, fn)
        if not signal then
            return nil
        end
        local ok, conn = pcall(function()
            return signal:Connect(fn)
        end)
        if ok and conn then
            table.insert(connections, conn)
        end
        return conn
    end

    local function stopTweens()
        for _, tween in ipairs(activeTweens) do
            pcall(function()
                tween:Cancel()
            end)
        end
        activeTweens = {}
    end

    local function moveWindow(size, position, length, style)
        stopTweens()
        local sizeTween = Util.Tween(frame, { Size = size }, length, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local posTween = Util.Tween(frame, { Position = position }, length, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        if sizeTween then
            table.insert(activeTweens, sizeTween)
        end
        if posTween then
            table.insert(activeTweens, posTween)
        end
        return sizeTween, posTween
    end

    local screenGui = Util.Create("ScreenGui", {
        Name = "SynUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    -- Optional executor protection must run before parenting the ScreenGui.
    pcall(function()
        local env = nil
        if type(getgenv) == "function" then
            env = getgenv()
        end
        local syn = env and env.syn or nil
        if not syn and type(_G) == "table" then
            syn = rawget(_G, "syn")
        end
        local protect = syn and syn.protect_gui or nil
        if type(protect) ~= "function" and env then
            protect = env.protect_gui
        end
        if type(protect) ~= "function" and type(_G) == "table" then
            protect = rawget(_G, "protect_gui")
        end
        if type(protect) == "function" then
            protect(screenGui)
        end
    end)

    local function mount(parent)
        assert(parent ~= nil, "no GUI parent is available")
        screenGui.Parent = parent
    end
    local mounted, mountError = pcall(mount, Util.GetParent(cfg))
    if not mounted and cfg.parent == nil and CorePlayers then
        mounted, mountError = pcall(function()
            local player = CorePlayers.LocalPlayer
            local parent = player and (player:FindFirstChildOfClass("PlayerGui")
                or player:WaitForChild("PlayerGui", 5))
            mount(parent)
        end)
    end
    if not mounted then
        screenGui:Destroy()
        error("[SYNUI] Could not parent the window: " .. tostring(mountError), 2)
    end

    local shadow = Util.Create("Frame", {
        Name = "SynUIShadow",
        BackgroundColor3 = C.black,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(desktopW, desktopH),
        ZIndex = 9,
        Parent = screenGui,
    })
    Util.Corner(shadow, 22)

    frame = Util.Create("Frame", {
        Name = "SynUIWindow",
        BackgroundColor3 = C.surface,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(targetW, targetH),
        ClipsDescendants = true,
        Active = true,
        ZIndex = 10,
        Parent = screenGui,
    })
    Util.Corner(frame, 16)
    Util.Stroke(frame, C.line, 1, 0.45)

    local header = Util.Create("Frame", {
        Name = "Header",
        BackgroundColor3 = C.surface,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, headerHeight),
        ZIndex = 4,
        Parent = frame,
    })
    coreHairline(header, "HeaderLine", UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1))

    local dragHandle = Util.Create("Frame", {
        Name = "DragHandle",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -208, 1, 0),
        ZIndex = 5,
        Parent = header,
    })

    local brandTile = Util.Create("Frame", {
        Name = "BrandMark",
        BackgroundColor3 = C.raised,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, -14),
        Size = UDim2.fromOffset(28, 28),
        ZIndex = 5,
        Parent = dragHandle,
    })
    Util.Corner(brandTile, 8)
    Util.Stroke(brandTile, C.line, 1, 0.55)
    local windowIcon = cfg.icon
    if windowIcon == nil or windowIcon == "" or windowIcon == "grid" then
        local brandPositions = {
            { 7, 7, 0.05 },
            { 15, 7, 0.72 },
            { 7, 15, 0.45 },
            { 15, 15, 0.86 },
        }
        for index, spec in ipairs(brandPositions) do
            Util.Create("Frame", {
                Name = "BrandSquare" .. index,
                BackgroundColor3 = C.white,
                BackgroundTransparency = spec[3],
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(spec[1], spec[2]),
                Size = UDim2.fromOffset(6, 6),
                ZIndex = 6,
                Parent = brandTile,
            })
        end
    else
        local brandIcon = Util.Create("Frame", {
            Name = "BrandIcon",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            ZIndex = 6,
            Parent = brandTile,
        })
        Icons.Draw(brandIcon, windowIcon, 18, C.white, 2)
    end

    local titleLabel = Util.Text(dragHandle, {
        Name = "Title",
        Text = string.upper(cfg.title or "SYNUI"),
        Font = F.bold,
        TextSize = 12,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.new(0, 38, 0, 14),
        Size = UDim2.new(1, -38, 0, 15),
        ZIndex = 5,
    })
    local subtitleLabel = Util.Text(dragHandle, {
        Name = "Subtitle",
        Text = cfg.subtitle or "CONTROL PANEL",
        Font = F.mono,
        TextSize = 9,
        TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.new(0, 38, 0, 32),
        Size = UDim2.new(1, -38, 0, 11),
        ZIndex = 5,
    })

    local pill = Util.Create("Frame", {
        Name = "StatusPill",
        BackgroundColor3 = C.raised,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -176, 0.5, 0),
        Size = UDim2.fromOffset(86, 22),
        ZIndex = 5,
        Parent = header,
    })
    Util.Corner(pill, 11)
    Util.Stroke(pill, C.line, 1, 0.55)
    local pillDot = Util.Create("Frame", {
        Name = "Dot",
        BackgroundColor3 = C.white,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0.5, -3),
        Size = UDim2.fromOffset(6, 6),
        ZIndex = 6,
        Parent = pill,
    })
    Util.Corner(pillDot, 3)
    local pillLabel = Util.Text(pill, {
        Name = "Label",
        Text = "ONLINE",
        Font = F.mono,
        TextSize = 8,
        TextColor3 = C.muted,
        Position = UDim2.new(0, 22, 0, 0),
        Size = UDim2.new(1, -26, 1, 0),
        ZIndex = 6,
    })

    local function iconButton(parent, iconName, onActivate)
        local button = Util.Create("TextButton", {
            Name = "IconButton_" .. tostring(iconName),
            BackgroundColor3 = C.hover,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            AnchorPoint = Vector2.new(1, 0.5),
            Size = UDim2.fromOffset(28, 28),
            ZIndex = 6,
            Parent = parent,
        })
        Util.Corner(button, 7)
        local holder = Util.Create("Frame", {
            Name = "Icon",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            ZIndex = 7,
            Parent = button,
        })
        Icons.Draw(holder, iconName, 14, C.muted, 1.8)
        connect(button.MouseEnter, function()
            Util.Tween(button, { BackgroundTransparency = 0 }, 0.12)
            coreSetIconColor(holder, C.text)
        end)
        connect(button.MouseLeave, function()
            Util.Tween(button, { BackgroundTransparency = 1 }, 0.14)
            coreSetIconColor(holder, C.muted)
        end)
        connect(button.Activated, function()
            Util.SafeCallback(onActivate)
        end)
        addCleanup(Util.Press(button))
        return button, holder
    end

    local minimizeButton, minimizeHolder = iconButton(header, "minus", function()
        if window then
            window:_toggleMinimize()
        end
    end)
    local closeButton = iconButton(header, "close", function()
        if window then
            window:_closePressed()
        end
    end)

    local body = Util.Create("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, headerHeight),
        Size = UDim2.new(1, 0, 1, -(headerHeight + 28)),
        ZIndex = 1,
        Parent = frame,
    })

    local sidebar = Util.Create("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 196, 1, 0),
        ClipsDescendants = true,
        Visible = not mobile,
        ZIndex = 2,
        Parent = body,
    })
    coreHairline(sidebar, "SidebarLine", UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0))

    local navLabel = Util.Text(sidebar, {
        Name = "NavLabel",
        Text = "WORKSPACE",
        Font = F.mono,
        TextSize = 8,
        TextColor3 = C.faint,
        Position = UDim2.new(0, 18, 0, 16),
        Size = UDim2.new(1, -36, 0, 10),
    })
    local nav = Util.Create("Frame", {
        Name = "Tabs",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 36),
        Size = UDim2.new(1, -24, 1, -112),
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = sidebar,
    })
    local navList = Util.Create("UIListLayout", {
        Name = "SynUIList",
        Padding = UDim.new(0, 3),
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Parent = nav,
    })

    local connectionPill = Util.Create("Frame", {
        Name = "ConnectionPill",
        BackgroundColor3 = C.raised,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 1, -70),
        Size = UDim2.new(1, -24, 0, 32),
        ZIndex = 3,
        Parent = sidebar,
    })
    Util.Corner(connectionPill, 8)
    Util.Stroke(connectionPill, C.line, 1, 0.6)
    local connectionDot = Util.Create("Frame", {
        Name = "Dot",
        BackgroundColor3 = C.white,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0.5, -3),
        Size = UDim2.fromOffset(6, 6),
        ZIndex = 4,
        Parent = connectionPill,
    })
    Util.Corner(connectionDot, 3)
    Util.Text(connectionPill, {
        Name = "Label",
        Text = "CONNECTED",
        Font = F.mono,
        TextSize = 8,
        TextColor3 = C.muted,
        Position = UDim2.new(0, 22, 0, 0),
        Size = UDim2.new(1, -60, 1, 0),
        ZIndex = 4,
    })
    Util.Text(connectionPill, {
        Name = "Live",
        Text = "LIVE",
        Font = F.mono,
        TextSize = 8,
        TextColor3 = C.faint,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, -10, 1, 0),
        ZIndex = 4,
    })
    Util.Text(sidebar, {
        Name = "Version",
        Text = "SYNUI " .. tostring(version),
        Font = F.mono,
        TextSize = 8,
        TextColor3 = C.faint,
        Position = UDim2.new(0, 14, 1, -32),
        Size = UDim2.new(1, -28, 0, 14),
        ZIndex = 3,
    })

    local content = Util.Create("Frame", {
        Name = "Content",
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 196, 0, 0),
        Size = UDim2.new(1, -196, 1, 0),
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = body,
    })

    local contentHeader = Util.Create("Frame", {
        Name = "ContentHeader",
        BackgroundColor3 = C.bg,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 54),
        ZIndex = 2,
        Parent = content,
    })
    coreHairline(contentHeader, "ContentHeaderLine", UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1))
    local contentTitle = Util.Text(contentHeader, {
        Name = "Title",
        Text = "SYNUI",
        Font = F.bold,
        TextSize = 16,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.new(0, 18, 0, 9),
        Size = UDim2.new(1, -120, 0, 22),
        ZIndex = 3,
    })
    local contentSubtitle = Util.Text(contentHeader, {
        Name = "Subtitle",
        Text = "WORKSPACE",
        Font = F.mono,
        TextSize = 9,
        TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.new(0, 18, 0, 32),
        Size = UDim2.new(1, -120, 0, 12),
        ZIndex = 3,
    })
    local contentMeta = Util.Text(contentHeader, {
        Name = "Meta",
        Text = "00 / 00",
        Font = F.mono,
        TextSize = 8,
        TextColor3 = C.faint,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        Size = UDim2.fromOffset(80, 12),
        ZIndex = 3,
    })

    local tabHost = Util.Create("Frame", {
        Name = "TabHost",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 54),
        Size = UDim2.new(1, 0, 1, -54),
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = content,
    })

    local strip = Util.Create("Frame", {
        Name = "TabStrip",
        BackgroundColor3 = C.surface,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42),
        Visible = mobile,
        ZIndex = 3,
        Parent = body,
    })
    coreHairline(strip, "StripLine", UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1))
    local stripScroll = Util.Create("ScrollingFrame", {
        Name = "Tabs",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 0,
        ClipsDescendants = true,
        ZIndex = 4,
        Parent = strip,
    })
    Util.Padding(stripScroll, 8, 0)
    Util.Create("UIListLayout", {
        Name = "SynUIList",
        Padding = UDim.new(0, 4),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = stripScroll,
    })

    local footer = Util.Create("Frame", {
        Name = "Footer",
        BackgroundColor3 = C.surface,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 28),
        ZIndex = 5,
        Parent = frame,
    })
    coreHairline(footer, "FooterLine", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 1))
    Util.Text(footer, {
        Name = "Brand",
        Text = "SYNUI / " .. tostring(version),
        Font = F.mono,
        TextSize = 8,
        TextColor3 = C.faint,
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0.5, -16, 1, 0),
        ZIndex = 6,
    })
    local footerStatus = Util.Create("Frame", {
        Name = "Status",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 240, 1, 0),
        ZIndex = 6,
        Parent = footer,
    })
    Util.Create("UIListLayout", {
        Name = "StatusList",
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = footerStatus,
    })
    local footerDot = Util.Create("Frame", {
        Name = "Dot",
        BackgroundColor3 = C.white,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(5, 5),
        LayoutOrder = 1,
        ZIndex = 7,
        Parent = footerStatus,
    })
    Util.Corner(footerDot, 3)
    local footerStatusText = Util.Text(footerStatus, {
        Name = "Text",
        Text = "READY",
        Font = F.mono,
        TextSize = 8,
        TextColor3 = C.muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 7,
    })

    local overlay = Util.Create("Frame", {
        Name = "Overlay",
        BackgroundColor3 = C.black,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
        ZIndex = 100,
        Parent = screenGui,
    })
    local notifyLayer = Util.Create("Frame", {
        Name = "NotifyLayer",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.new(0, 300, 1, -32),
        ClipsDescendants = false,
        ZIndex = 200,
        Parent = screenGui,
    })

    local launcher = nil
    local launcherHolder = nil
    if cfg.launcher ~= false then
        launcher = Util.Create("TextButton", {
            Name = "SynUILauncher",
            BackgroundColor3 = C.white,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -16, 0, 16),
            Size = UDim2.fromOffset(44, 44),
            Visible = false,
            ZIndex = 300,
            Parent = screenGui,
        })
        Util.Corner(launcher, 22)
        launcherHolder = Util.Create("Frame", {
            Name = "Icon",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            ZIndex = 301,
            Parent = launcher,
        })
        Icons.Draw(launcherHolder, "grid", 20, C.black, 2)
        connect(launcher.Activated, function()
            if window then
                window:SetVisible(true)
            end
        end)
        connect(launcher.MouseEnter, function()
            Util.Tween(launcher, { BackgroundColor3 = Color3.fromRGB(232, 232, 236) }, 0.12)
        end)
        connect(launcher.MouseLeave, function()
            Util.Tween(launcher, { BackgroundColor3 = C.white }, 0.14)
        end)
    end

    window = {
        frame = frame,
        screenGui = screenGui,
        gui = screenGui,
        header = header,
        body = body,
        sidebar = sidebar,
        content = content,
        footer = footer,
        launcher = launcher,
        _notifyLayer = notifyLayer,
        _overlay = overlay,
        _tabs = {},
        _activeTab = nil,
        _mobile = mobile,
        _visible = cfg.visible ~= false,
        _minimized = false,
        _destroyed = false,
        _connections = connections,
    }
    local function syncShadow()
        if not shadow or not frame then
            return
        end
        pcall(function()
            local size = frame.Size
            local position = frame.Position
            shadow.Size = UDim2.new(size.X.Scale, size.X.Offset + 16, size.Y.Scale, size.Y.Offset + 16)
            shadow.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + 7)
            shadow.AnchorPoint = frame.AnchorPoint
            shadow.Visible = frame.Visible
        end)
    end
    connect(frame:GetPropertyChangedSignal("Size"), syncShadow)
    connect(frame:GetPropertyChangedSignal("Position"), syncShadow)
    connect(frame:GetPropertyChangedSignal("AnchorPoint"), syncShadow)
    connect(frame:GetPropertyChangedSignal("Visible"), syncShadow)
    syncShadow()

    local function updateLauncher()
        if launcher then
            launcher.Visible = (not window._destroyed) and (not window._visible)
        end
    end

    local function updateTabPadding(tab)
        if not tab or not tab.content then
            return
        end
        local pad = nil
        pcall(function()
            pad = tab.content:FindFirstChildOfClass("UIPadding")
        end)
        if pad then
            pcall(function()
                pad.PaddingLeft = UDim.new(0, mobile and 10 or 16)
                pad.PaddingRight = UDim.new(0, mobile and 10 or 16)
                pad.PaddingTop = UDim.new(0, mobile and 10 or 12)
                pad.PaddingBottom = UDim.new(0, mobile and 14 or 18)
            end)
        end
        local list = nil
        pcall(function()
            list = tab.content:FindFirstChild("SynUIList")
        end)
        if list then
            pcall(function()
                list.Padding = UDim.new(0, mobile and 10 or 12)
            end)
        end
    end

    local function applyLayout()
        if window._destroyed then
            return
        end
        local vp = Util.Viewport()
        if not vp or vp.X <= 0 or vp.Y <= 0 then
            vp = Vector2.new(1280, 720)
        end
        local isMobile = Util.IsMobile()
        local centerX, centerY = 0.5, 0.5
        if laidOut and window._visible then
            local ok, absPos, absSize = pcall(function()
                return frame.AbsolutePosition, frame.AbsoluteSize
            end)
            if ok and absPos and absSize then
                centerX = (absPos.X + absSize.X / 2) / math.max(lastViewport.X, 1)
                centerY = (absPos.Y + absSize.Y / 2) / math.max(lastViewport.Y, 1)
            end
        elseif laidOut then
            centerX = targetX / math.max(lastViewport.X, 1)
            centerY = targetY / math.max(lastViewport.Y, 1)
        end
        centerX = Util.Clamp(centerX, 0, 1)
        centerY = Util.Clamp(centerY, 0, 1)

        local w, h
        if isMobile then
            w = vp.X * 0.94
            h = vp.Y * 0.92
        else
            w = coreLength(cfg.size and cfg.size.X, vp.X, 760)
            h = coreLength(cfg.size and cfg.size.Y, vp.Y, 500)
        end
        local maxW = math.max(1, vp.X - 16)
        local maxH = math.max(1, vp.Y - 12)
        w = math.min(w, maxW)
        h = math.min(h, maxH)
        if maxW >= 280 then
            w = math.max(280, w)
        end
        if maxH >= 200 then
            h = math.max(200, h)
        end
        headerHeight = isMobile and 54 or 62
        if window._minimized then
            h = headerHeight
        end
        targetW = w
        targetH = h
        local centerPxX = Util.Clamp(centerX * vp.X, w / 2 + 8, vp.X - w / 2 - 8)
        local centerPxY = Util.Clamp(centerY * vp.Y, h / 2 + 8, vp.Y - h / 2 - 8)
        targetX = centerPxX
        targetY = centerPxY

        frame.Size = UDim2.fromOffset(w, h)
        frame.Position = UDim2.fromOffset(centerPxX, centerPxY)
        mobile = isMobile
        window._mobile = isMobile

        sidebar.Visible = not isMobile
        strip.Visible = isMobile
        body.Position = UDim2.new(0, 0, 0, headerHeight)
        body.Size = UDim2.new(1, 0, 1, -(headerHeight + 28))
        header.Size = UDim2.new(1, 0, 0, headerHeight)
        content.Position = isMobile and UDim2.new(0, 0, 0, 42) or UDim2.new(0, 196, 0, 0)
        content.Size = isMobile and UDim2.new(1, 0, 1, -42) or UDim2.new(1, -196, 1, 0)

        local brandSize = isMobile and 26 or 28
        brandTile.Size = UDim2.fromOffset(brandSize, brandSize)
        brandTile.Position = UDim2.new(0, 0, 0.5, -brandSize / 2)
        local titleX = brandSize + (isMobile and 8 or 10)
        titleLabel.Position = UDim2.new(0, titleX, 0, isMobile and 10 or 14)
        titleLabel.Size = UDim2.new(1, -titleX, 0, 15)
        subtitleLabel.Position = UDim2.new(0, titleX, 0, isMobile and 27 or 32)
        subtitleLabel.Size = UDim2.new(1, -titleX, 0, 11)
        titleLabel.TextSize = isMobile and 11 or 12

        local buttonSize = isMobile and 42 or 28
        local sidePad = isMobile and 10 or 14
        local gap = isMobile and 6 or 8
        local pillW = isMobile and 22 or 86
        closeButton.Size = UDim2.fromOffset(buttonSize, buttonSize)
        minimizeButton.Size = UDim2.fromOffset(buttonSize, buttonSize)
        closeButton.Position = UDim2.new(1, -sidePad, 0.5, 0)
        minimizeButton.Position = UDim2.new(1, -(sidePad + buttonSize + gap), 0.5, 0)
        pill.Size = UDim2.fromOffset(pillW, 22)
        pill.Position = UDim2.new(1, -(sidePad + buttonSize * 2 + gap + (isMobile and 6 or 10) + pillW), 0.5, 0)
        pillLabel.Visible = not isMobile
        if isMobile then
            pillDot.Position = UDim2.new(0.5, -3, 0.5, -3)
        else
            pillDot.Position = UDim2.new(0, 10, 0.5, -3)
        end

        local leftPad = isMobile and 12 or 16
        local occupied = sidePad + buttonSize * 2 + gap + (isMobile and 6 or 10) + pillW
        local handleW = math.max(60, w - occupied - leftPad - 8)
        dragHandle.Position = UDim2.new(0, leftPad, 0, 0)
        dragHandle.Size = UDim2.new(0, handleW, 1, 0)

        contentTitle.Position = UDim2.new(0, isMobile and 12 or 18, 0, 9)
        contentTitle.Size = UDim2.new(1, isMobile and -24 or -120, 0, 22)
        contentTitle.TextSize = isMobile and 14 or 16
        contentSubtitle.Position = UDim2.new(0, isMobile and 12 or 18, 0, 32)
        contentSubtitle.Size = UDim2.new(1, isMobile and -24 or -120, 0, 12)
        contentMeta.Visible = not isMobile

        footerStatus.Size = UDim2.new(0, isMobile and 150 or 240, 1, 0)
        notifyLayer.Size = UDim2.new(0, math.min(300, math.max(140, vp.X - 32)), 1, -32)
        if launcher then
            launcher.Position = UDim2.new(1, -16, 0, 16)
        end

        for _, tab in ipairs(window._tabs) do
            updateTabPadding(tab)
        end

        syncShadow()
        laidOut = true
        lastViewport = vp
    end

    local Tab = {}
    Tab.__index = Tab

    local function tabIndexOf(tab)
        for index, item in ipairs(window._tabs) do
            if item == tab then
                return index
            end
        end
        return nil
    end

    local selectTab

    local function createDesktopTabButton(tab, index)
        local button = Util.Create("TextButton", {
            Name = "Tab_" .. index,
            BackgroundColor3 = C.bg,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 34),
            ClipsDescendants = true,
            LayoutOrder = index,
            ZIndex = 3,
            Parent = nav,
        })
        Util.Corner(button, 8)
        local activeBar = Util.Create("Frame", {
            Name = "ActiveBar",
            BackgroundColor3 = C.white,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(2, 16),
            Visible = false,
            ZIndex = 5,
            Parent = button,
        })
        local iconHolder = Util.Create("Frame", {
            Name = "Icon",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 11, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            ZIndex = 4,
            Parent = button,
        })
        Icons.Draw(iconHolder, tab.icon, 16, C.muted, 1.8)
        local label = Util.Text(button, {
            Name = "Label",
            Text = tab.name,
            Font = F.medium,
            TextSize = 11,
            TextColor3 = C.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.new(0, 35, 0, 0),
            Size = UDim2.new(1, -43, 1, 0),
            ZIndex = 4,
        })
        local badge = nil
        local badgeLabel = nil
        if tab.badge ~= nil and tab.badge ~= false then
            badge = Util.Create("Frame", {
                Name = "Badge",
                BackgroundColor3 = C.raised,
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.fromOffset(0, 14),
                ZIndex = 5,
                Parent = button,
            })
            Util.Corner(badge, 4)
            badgeLabel = Util.Text(badge, {
                Name = "Text",
                Text = tostring(tab.badge),
                Font = F.mono,
                TextSize = 8,
                TextColor3 = C.dim,
                TextXAlignment = Enum.TextXAlignment.Center,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 6,
            })
            local width = math.max(18, math.min(46, 8 + #tostring(tab.badge) * 5))
            badge.Size = UDim2.fromOffset(width, 14)
            label.Size = UDim2.new(1, -(43 + width + 8), 1, 0)
        end

        local function applyStyle(active)
            button.BackgroundColor3 = active and C.raised or C.bg
            activeBar.Visible = active
            label.TextColor3 = active and C.text or C.muted
            coreSetIconColor(iconHolder, active and C.text or C.muted)
            if badgeLabel then
                badgeLabel.TextColor3 = active and C.muted or C.dim
            end
        end
        tab._applyStyle = applyStyle
        applyStyle(false)

        connect(button.Activated, function()
            selectTab(tab)
        end)
        connect(button.MouseEnter, function()
            if window._activeTab ~= tab then
                Util.Tween(button, { BackgroundColor3 = C.hover }, 0.12)
            end
        end)
        connect(button.MouseLeave, function()
            if window._activeTab ~= tab then
                Util.Tween(button, { BackgroundColor3 = C.bg }, 0.14)
            else
                applyStyle(true)
            end
        end)
        addCleanup(Util.Press(button))
        return button
    end

    local function createMobileTabButton(tab, index)
        local estimated = 44 + #tostring(tab.name) * 6
        local width = math.max(88, math.min(150, estimated))
        local button = Util.Create("TextButton", {
            Name = "MTab_" .. index,
            BackgroundColor3 = C.surface,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.new(0, width, 1, 0),
            LayoutOrder = index,
            ZIndex = 4,
            Parent = stripScroll,
        })
        local iconHolder = Util.Create("Frame", {
            Name = "Icon",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, -1),
            Size = UDim2.fromOffset(14, 14),
            ZIndex = 5,
            Parent = button,
        })
        Icons.Draw(iconHolder, tab.icon, 14, C.muted, 1.8)
        local label = Util.Text(button, {
            Name = "Label",
            Text = tab.name,
            Font = F.medium,
            TextSize = 10,
            TextColor3 = C.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.new(0, 31, 0, -1),
            Size = UDim2.new(1, -38, 1, 0),
            ZIndex = 5,
        })
        local underline = Util.Create("Frame", {
            Name = "Underline",
            BackgroundColor3 = C.white,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 9, 1, -1),
            Size = UDim2.new(1, -18, 0, 2),
            Visible = false,
            ZIndex = 5,
            Parent = button,
        })
        local function applyStyle(active)
            underline.Visible = active
            label.TextColor3 = active and C.text or C.muted
            coreSetIconColor(iconHolder, active and C.text or C.muted)
        end
        tab._applyMobileStyle = applyStyle
        applyStyle(false)
        connect(button.Activated, function()
            selectTab(tab)
        end)
        return button
    end

    function Tab:Section(sectionCfg)
        local section = Layout.Section(self, sectionCfg)
        if section then
            local exists = false
            for _, item in ipairs(self.sections) do
                if item == section then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(self.sections, section)
            end
        end
        return section
    end

    function Tab:Label(labelCfg)
        if type(labelCfg) == "string" then
            labelCfg = { text = labelCfg }
        elseif type(labelCfg) ~= "table" then
            labelCfg = {}
        end
        return Layout.Label(self, labelCfg)
    end

    function Tab:Paragraph(paragraphCfg)
        if type(paragraphCfg) == "string" then
            paragraphCfg = { text = paragraphCfg }
        elseif type(paragraphCfg) ~= "table" then
            paragraphCfg = {}
        end
        return Layout.Paragraph(self, paragraphCfg)
    end

    function Tab:Divider()
        return Layout.Divider(self)
    end

    function Tab:Card(cardCfg)
        if type(cardCfg) ~= "table" then
            cardCfg = {}
        end
        return Layout.Card(self, cardCfg)
    end

    function Tab:Spacer(px)
        local amount = px
        if type(amount) == "table" then
            amount = amount.size or amount.height or amount.px or 12
        end
        if type(amount) ~= "number" then
            amount = 12
        end
        return Layout.Spacer(self, amount)
    end

    function Tab:Select()
        return window:SelectTab(self)
    end

    selectTab = function(tab)
        if not tab or window._destroyed or tab.window ~= window then
            return
        end
        if window._activeTab == tab then
            return
        end
        local previous = window._activeTab
        if previous then
            if previous.content then
                previous.content.Visible = false
            end
            if previous._applyStyle then
                previous._applyStyle(false)
            end
            if previous._applyMobileStyle then
                previous._applyMobileStyle(false)
            end
        end
        window._activeTab = tab
        if tab.content then
            tab.content.Visible = true
            tab.content.Position = UDim2.new(0, 0, 0, 6)
            Util.Tween(tab.content, { Position = UDim2.new(0, 0, 0, 0) }, 0.16)
        end
        if tab._applyStyle then
            tab._applyStyle(true)
        end
        if tab._applyMobileStyle then
            tab._applyMobileStyle(true)
        end
        local index = tabIndexOf(tab) or 1
        contentTitle.Text = tostring(tab.name or "TAB")
        contentSubtitle.Text = tostring(tab.subtitle or "WORKSPACE")
        contentMeta.Text = string.format("%02d / %02d", index, #window._tabs)
        if tab.mobileButton and stripScroll and mobile then
            local target = 0
            pcall(function()
                target = tab.mobileButton.AbsolutePosition.X - stripScroll.AbsolutePosition.X
                    + stripScroll.CanvasPosition.X - 8
            end)
            Util.Tween(stripScroll, { CanvasPosition = Vector2.new(math.max(0, target), 0) }, 0.18)
        end
    end

    function window:Tab(tabCfg)
        if window._destroyed then
            return nil
        end
        if type(tabCfg) ~= "table" then
            tabCfg = { name = tostring(tabCfg or "") }
        end
        local index = #window._tabs + 1
        local name = tabCfg.name
        if name == nil or name == "" then
            name = "TAB " .. tostring(index)
        end
        local tab = setmetatable({
            name = tostring(name),
            icon = tabCfg.icon or "grid",
            subtitle = tabCfg.subtitle,
            badge = tabCfg.badge,
            window = window,
            sections = {},
        }, Tab)

        local scroll = Util.Create("ScrollingFrame", {
            Name = "TabContent_" .. index,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = C.faint,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = 1,
            Parent = tabHost,
        })
        Util.Padding(scroll, 16, 0)
        local pad = nil
        pcall(function()
            pad = scroll:FindFirstChildOfClass("UIPadding")
        end)
        if pad then
            pad.PaddingTop = UDim.new(0, 12)
            pad.PaddingBottom = UDim.new(0, 18)
        end
        Util.Create("UIListLayout", {
            Name = "SynUIList",
            Padding = UDim.new(0, 12),
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            Parent = scroll,
        })
        Util.AutoScroll(scroll)
        tab.content = scroll
        tab.frame = scroll

        table.insert(window._tabs, tab)
        tab.button = createDesktopTabButton(tab, index)
        tab.mobileButton = createMobileTabButton(tab, index)
        updateTabPadding(tab)
        if window._activeTab == nil then
            selectTab(tab)
        end
        return tab
    end

    function window:SelectTab(tab)
        if type(tab) == "number" then
            tab = window._tabs[tab]
        elseif type(tab) == "string" then
            for _, candidate in ipairs(window._tabs) do
                if candidate.name == tab then
                    tab = candidate
                    break
                end
            end
        end
        selectTab(tab)
    end

    local function setMinimizeIcon(iconName)
        if not minimizeHolder then
            return
        end
        for _, child in ipairs(minimizeHolder:GetChildren()) do
            child:Destroy()
        end
        Icons.Draw(minimizeHolder, iconName, 14, C.muted, 1.8)
    end

    local function animateOpen()
        if window._destroyed or not window._visible then
            return
        end
        motionToken = motionToken + 1
        frame.Visible = true
        shadow.Visible = true
        frame.Size = UDim2.fromOffset(math.max(1, targetW * 0.96), math.max(1, targetH * 0.96))
        frame.Position = UDim2.fromOffset(targetX, targetY + 6)
        moveWindow(
            UDim2.fromOffset(targetW, targetH),
            UDim2.fromOffset(targetX, targetY),
            0.22,
            Enum.EasingStyle.Quint
        )
    end

    local function animateClose()
        if window._destroyed then
            return
        end
        motionToken = motionToken + 1
        local token = motionToken
        local w, h = 0, 0
        local ax, ay = 0, 0
        pcall(function()
            w = frame.AbsoluteSize.X
            h = frame.AbsoluteSize.Y
            ax = frame.AbsolutePosition.X
            ay = frame.AbsolutePosition.Y
        end)
        local cx = ax + w / 2
        local cy = ay + h / 2
        targetW = w
        targetH = h
        targetX = cx
        targetY = cy
        moveWindow(
            UDim2.fromOffset(math.max(1, w * 0.96), math.max(1, h * 0.96)),
            UDim2.fromOffset(cx, cy + 6),
            0.18,
            Enum.EasingStyle.Quint
        )
        task.delay(0.2, function()
            if window._destroyed or token ~= motionToken or window._visible then
                return
            end
            frame.Visible = false
            shadow.Visible = false
            updateLauncher()
        end)
    end

    local setVisible

    local function minimizeWindow()
        if window._minimized then
            return
        end
        window._minimized = true
        body.Visible = false
        footer.Visible = false
        setMinimizeIcon("plus")
        local vp = Util.Viewport()
        local top = frame.AbsolutePosition.Y
        local w = frame.AbsoluteSize.X
        local h = headerHeight
        targetW = w
        targetH = h
        targetX = Util.Clamp(frame.AbsolutePosition.X + w / 2, w / 2 + 8, vp.X - w / 2 - 8)
        targetY = Util.Clamp(top + h / 2, h / 2 + 8, vp.Y - h / 2 - 8)
        moveWindow(UDim2.fromOffset(w, h), UDim2.fromOffset(targetX, targetY), 0.2)
    end

    local function restoreWindow()
        if not window._minimized then
            return
        end
        window._minimized = false
        setMinimizeIcon("minus")
        body.Visible = true
        footer.Visible = false
        local vp = Util.Viewport()
        local top = frame.AbsolutePosition.Y
        local w, h
        if vp.X < 700 then
            w = vp.X * 0.94
            h = vp.Y * 0.92
        else
            w = coreLength(cfg.size and cfg.size.X, vp.X, 760)
            h = coreLength(cfg.size and cfg.size.Y, vp.Y, 500)
        end
        w = math.min(w, math.max(1, vp.X - 16))
        h = math.min(h, math.max(1, vp.Y - 12))
        if vp.X - 16 >= 280 then
            w = math.max(280, w)
        end
        if vp.Y - 12 >= 200 then
            h = math.max(200, h)
        end
        targetW = w
        targetH = h
        targetX = Util.Clamp(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2, w / 2 + 8, vp.X - w / 2 - 8)
        targetY = Util.Clamp(top + h / 2, h / 2 + 8, vp.Y - h / 2 - 8)
        moveWindow(UDim2.fromOffset(w, h), UDim2.fromOffset(targetX, targetY), 0.2)
        task.delay(0.21, function()
            if window._destroyed or window._minimized or not window._visible then
                return
            end
            footer.Visible = true
        end)
    end

    local function toggleMinimize()
        if mobile then
            setVisible(false)
            return
        end
        if window._minimized then
            restoreWindow()
        else
            minimizeWindow()
        end
    end

    local function closePressed()
        if onCloseCallback then
            Util.SafeCallback(onCloseCallback)
        end
        setVisible(false)
    end

    setVisible = function(show)
        if window._destroyed then
            return
        end
        show = show and true or false
        if show == window._visible then
            updateLauncher()
            return
        end
        window._visible = show
        if show then
            if window._minimized then
                window._minimized = false
                body.Visible = true
                footer.Visible = true
                setMinimizeIcon("minus")
            end
            frame.Size = UDim2.fromOffset(targetW, targetH)
            frame.Position = UDim2.fromOffset(targetX, targetY)
            applyLayout()
            animateOpen()
            updateLauncher()
        else
            animateClose()
        end
    end

    function window:_toggleMinimize()
        if window._destroyed then
            return
        end
        toggleMinimize()
    end

    function window:_closePressed()
        if window._destroyed then
            return
        end
        closePressed()
    end

    function window:SetVisible(show)
        setVisible(show)
    end

    function window:Toggle()
        if window._destroyed then
            return
        end
        setVisible(not window._visible)
    end

    function window:IsMobile()
        return window._mobile == true
    end

    function window:Notify(notifyCfg)
        if window._destroyed then
            return nil
        end
        if Feedback and type(Feedback.Notify) == "function" then
            return Feedback.Notify(window, notifyCfg)
        end
        return nil
    end

    function window:Dialog(dialogCfg)
        if window._destroyed then
            return nil
        end
        if Feedback and type(Feedback.Dialog) == "function" then
            return Feedback.Dialog(window, dialogCfg)
        end
        return nil
    end

    function window:SetStatus(text, tone)
        if window._destroyed then
            return
        end
        local value = tostring(text == nil and "" or text)
        footerStatusText.Text = value
        if tone == "off" then
            footerStatusText.TextColor3 = C.faint
        elseif tone == "warn" then
            footerStatusText.TextColor3 = C.dim
        else
            footerStatusText.TextColor3 = C.muted
        end
        local dotColor = CoreTones[tone or "ok"] or C.white
        footerDot.BackgroundColor3 = dotColor
        pillDot.BackgroundColor3 = dotColor
        window._status = value
        window._statusTone = tone or "ok"
    end

    function window:SetTitle(title, subtitle)
        if window._destroyed then
            return
        end
        if title ~= nil then
            titleLabel.Text = string.upper(tostring(title))
            window._title = titleLabel.Text
        end
        if subtitle ~= nil then
            subtitleLabel.Text = tostring(subtitle)
            window._subtitle = subtitleLabel.Text
        end
    end

    function window:OnClose(fn)
        if type(fn) == "function" then
            onCloseCallback = fn
        elseif fn == nil then
            onCloseCallback = nil
        end
        return window
    end

    function window:GetActiveTab()
        return window._activeTab
    end

    function window:Destroy()
        if window._destroyed then
            return
        end
        window._destroyed = true
        window._visible = false
        motionToken = motionToken + 1
        for _, conn in ipairs(connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        connections = {}
        window._connections = connections
        for _, cleanup in ipairs(cleanups) do
            pcall(cleanup)
        end
        cleanups = {}
        stopTweens()
        if launcher then
            launcher.Visible = false
        end
        for _, tab in ipairs(window._tabs) do
            for _, section in ipairs(tab.sections or {}) do
                if type(section.Destroy) == "function" then
                    pcall(section.Destroy, section)
                end
            end
        end
        pcall(function()
            screenGui:Destroy()
        end)
        window._activeTab = nil
    end

    addCleanup(Util.MakeDraggable(frame, dragHandle, screenGui))
    connect(dragHandle.InputBegan, function()
        stopTweens()
        frame.Size = UDim2.fromOffset(targetW, targetH)
    end)
    connect(dragHandle.InputEnded, function()
        local ok, absPos, absSize = pcall(function()
            return frame.AbsolutePosition, frame.AbsoluteSize
        end)
        if ok and absPos and absSize then
            targetW = absSize.X
            targetH = absSize.Y
            targetX = absPos.X + absSize.X / 2
            targetY = absPos.Y + absSize.Y / 2
        end
    end)
    addCleanup(Util.OnViewportChanged(screenGui, applyLayout))

    local toggleKey = cfg.toggleKey
    if toggleKey == nil then
        toggleKey = Enum.KeyCode.RightShift
    end
    if toggleKey and CoreUIS then
        connect(CoreUIS.InputBegan, function(input, gameProcessed)
            if gameProcessed or window._destroyed then
                return
            end
            if input and input.KeyCode == toggleKey then
                window:Toggle()
            end
        end)
    end

    window._title = titleLabel.Text
    window._subtitle = subtitleLabel.Text
    window._status = "READY"
    window._statusTone = "ok"

    applyLayout()
    if cfg.visible == false then
        window._visible = false
        frame.Visible = false
        shadow.Visible = false
        updateLauncher()
    else
        animateOpen()
        updateLauncher()
    end
    return window
end


--[[
    SYNUI 1.1.1
    A single-file, dependency-free monochrome interface library for Roblox.
    Embedded SVG path icons, desktop + mobile, keyboard + touch.

    Built by boswashere. MIT licensed.
]]

local SynUI = {
    _VERSION = "1.1.1",
    Theme = Theme,
    Icons = Icons,
    Util = Util,
}

-- Supports both SynUI.CreateWindow(cfg) and SynUI:CreateWindow(cfg).
function SynUI.CreateWindow(a, b)
    local cfg = a
    if a == SynUI then
        cfg = b
    end
    if type(cfg) ~= "table" then
        cfg = {}
    end
    return Core.CreateWindow(cfg)
end

SynUI.new = SynUI.CreateWindow
SynUI.DrawIcon = Icons.Draw

return SynUI

end)()

-- SYNUI tries gethui(), then falls back to PlayerGui if parenting fails.
local window = SynUI:CreateWindow({
    title = "SYNUI DEMO",
    subtitle = "EXAMPLE SCRIPT",
    icon = "grid",
    size = UDim2.fromOffset(720, 480),
    toggleKey = Enum.KeyCode.RightShift,
    launcher = true,
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

end, function(message)
    if type(debug) == "table" and type(debug.traceback) == "function" then
        return debug.traceback(tostring(message), 2)
    end
    return tostring(message)
end)

if not ok then
    warn("[SYNUI] " .. tostring(err))
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local parent = player and player:FindFirstChildOfClass("PlayerGui")
    if parent then
        local gui = Instance.new("ScreenGui")
        gui.Name = "SynUIError"
        gui.DisplayOrder = 1000
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.Parent = parent

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -32, 0, 320)
        label.Position = UDim2.fromOffset(16, 16)
        label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        label.BorderSizePixel = 0
        label.TextColor3 = Color3.fromRGB(10, 10, 12)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.Text = "SYNUI ERROR\n\n" .. tostring(err)
        label.Parent = gui
    end
end
