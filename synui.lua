-- SYNUI / theme
-- One monochrome palette, one radius scale, one motion vocabulary.

local function themeFont(name, fallback)
	local ok, value = pcall(function() return Enum.Font[name] end)
	return ok and value or fallback
end

local Theme = {
	version = "1.5.0",

	colors = {
		bg = Color3.fromRGB(0, 0, 0),
		surface = Color3.fromRGB(0, 0, 0),
		raised = Color3.fromRGB(0, 0, 0),
		hover = Color3.fromRGB(0, 0, 0),
		line = Color3.fromRGB(255, 255, 255),
		text = Color3.fromRGB(255, 255, 255),
		muted = Color3.fromRGB(255, 255, 255),
		dim = Color3.fromRGB(255, 255, 255),
		faint = Color3.fromRGB(255, 255, 255),
		field = Color3.fromRGB(0, 0, 0),
		panel = Color3.fromRGB(0, 0, 0),
		white = Color3.fromRGB(255, 255, 255),
		black = Color3.fromRGB(0, 0, 0),
	},

	fonts = {
		regular = themeFont("BuilderSans", Enum.Font.Gotham),
		medium = themeFont("BuilderSansMedium", Enum.Font.GothamMedium),
		bold = themeFont("BuilderSansBold", Enum.Font.GothamBold),
		mono = Enum.Font.Code,
	},

	radius = { sm = 6, md = 6, lg = 8, xl = 10 },

	motion = { fast = 0.1, normal = 0.14, slow = 0.16 },
}

-- Hairline stroke transparency and the base spacing unit used by every part.
Theme.stroke = 0.84
Theme.pad = 16

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
		TextSize = 12,
		TextColor3 = (Theme and Theme.colors and Theme.colors.text) or Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
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
	local px = tonumber(size) or 12
    return Util.Text(parent, {
        Text = tostring(text == nil and "" or text),
        TextSize = px,
		TextColor3 = color or ((Theme and Theme.colors and Theme.colors.text) or Color3.fromRGB(255, 255, 255)),
        Font = font or ((Theme and Theme.fonts and Theme.fonts.regular) or Enum.Font.Gotham),
		Size = UDim2.new(1, 0, 0, math.max(16, px + 5)),
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

function Util.DisplayScale()
    -- Roblox already supplies UI coordinates. Keep type and hit targets at
    -- their intended size rather than scaling the entire interface by pixels.
    return 1
end

function Util.IsMobile()
    local viewport = Util.Viewport()
    if not viewport or not viewport.X or not viewport.Y then
        return true
    end
    -- Touch capability alone is not a reliable proxy for available layout
    -- space. A landscape phone/tablet keeps the wide navigation rail.
    return viewport.X < 640 or viewport.Y < 440
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

    local function isRenderableRoot(parent)
        if not parent then
            return false
        end
        local ok, renderable = pcall(function()
            return parent:IsA("PlayerGui") or parent:IsA("CoreGui")
        end)
        return ok and renderable == true
    end

    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and isRenderableRoot(hui) then
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
        local boundsX, boundsY = 0, 0
        pcall(function()
            local size, origin = gui.AbsoluteSize, gui.AbsolutePosition
            if size.X > 0 and size.Y > 0 then
                viewport = size
                boundsX, boundsY = origin.X, origin.Y
            end
        end)
        local sizeX, sizeY = 0, 0
        pcall(function()
            sizeX = frame.AbsoluteSize.X
            sizeY = frame.AbsoluteSize.Y
        end)
        local dx = input.Position.X - dragStart.X
        local dy = input.Position.Y - dragStart.Y
        local targetX = startAbs.X + dx
        local targetY = startAbs.Y + dy
        local minX, minY = boundsX + 8, boundsY + 8
        local maxX = math.max(minX, boundsX + viewport.X - sizeX - 8)
        local maxY = math.max(minY, boundsY + viewport.Y - sizeY - 8)
        targetX = Util.Clamp(targetX, minX, maxX)
        targetY = Util.Clamp(targetY, minY, maxY)

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
    local hover = hoverColor or ((Theme and Theme.colors and Theme.colors.hover) or Color3.fromRGB(0, 0, 0))
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
        scrollFrame.ScrollBarImageColor3 = (Theme and Theme.colors and Theme.colors.faint) or Color3.fromRGB(255, 255, 255)
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
        BackgroundColor3 = (Theme and Theme.colors and Theme.colors.line) or Color3.fromRGB(255, 255, 255),
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

defs.maximize = {
	{ "rect", 5, 5, 14, 14, 1.2 },
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
local TextService = game:GetService("TextService")

local TEXT = Theme.colors.text
local MUTED = Theme.colors.muted
local DIM = Theme.colors.dim
local LINE = Theme.colors.line
local RAISED = Theme.colors.raised
local HOVER = Theme.colors.hover
local SURFACE = Theme.colors.surface
local BG = Theme.colors.bg
local WHITE = Theme.colors.white

local function controlCleanup(section, callback)
    section._controlCleanups = section._controlCleanups or {}
    table.insert(section._controlCleanups, callback)
end

local function refreshSection(section)
    if section and section.Refresh then
        section:Refresh()
        if section.window and section.window._refreshSearch then section.window:_refreshSearch() end
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
        BackgroundTransparency = 0.91,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    line.Parent = row
    return line
end

local function newRow(section, height, cfg)
    local row = Util.Create("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })
    addDivider(row)
    cfg = cfg or {}
    row:SetAttribute("SynUISearch", tostring(cfg.text or "") .. " " .. tostring(cfg.description or ""))
    section:AddRow(row)
    return row
end

local function hitHeight()
    return UserInputService.TouchEnabled and 44 or 40
end

local function measuredHeight(value, font, size, width)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(value, size, font, Vector2.new(math.max(24, width), 10000))
    end)
    return math.max(size + 4, ok and math.ceil(bounds.Y) or math.ceil(#value * size * 0.55 / math.max(24, width)) * (size + 4))
end

-- Reflow existing rows without recreating controls or their state.
local function settingRow(section, cfg, controlWidth, controlHeight, allowStack)
    local row = newRow(section, controlHeight + 28, cfg)
    local label = Util.Text(row, {Name = "Label", Text = tostring(cfg.text or ""), Font = Theme.fonts.medium,
        TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 2})
    local description
    if cfg.description and cfg.description ~= "" then
        description = Util.Text(row, {Name = "Description", Text = tostring(cfg.description), TextSize = 12,
            TextTransparency = 0.38, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 2})
    end
    local control, previousWidth
    local function layout()
        if section._destroyed or not row.Parent then return end
        local width = math.max(40, row.AbsoluteSize.X)
        previousWidth = width
        local stacked = allowStack and width < controlWidth + 140
        local fieldWidth = math.min(controlWidth, width)
        local labelWidth = stacked and width or math.max(24, width - fieldWidth - 20)
        local titleHeight = measuredHeight(label.Text, Theme.fonts.medium, 14, labelWidth)
        local descHeight = description and measuredHeight(description.Text, Theme.fonts.regular, 12, labelWidth) or 0
        local textHeight = titleHeight + (description and descHeight + 4 or 0)
        local height = stacked and (28 + textHeight + 10 + controlHeight) or (28 + math.max(controlHeight, textHeight))
        row.Size = UDim2.new(1, 0, 0, height)
        local top = stacked and 14 or math.floor((height - textHeight) / 2)
        label.Position, label.Size = UDim2.fromOffset(0, top), UDim2.fromOffset(labelWidth, titleHeight)
        if description then
            description.Position = UDim2.fromOffset(0, top + titleHeight + 4)
            description.Size = UDim2.fromOffset(labelWidth, descHeight)
        end
        if control then
            control.AnchorPoint = stacked and Vector2.new(0, 0) or Vector2.new(1, 0.5)
            control.Position = stacked and UDim2.fromOffset(0, top + textHeight + 10) or UDim2.new(1, 0, 0.5, 0)
            control.Size = stacked and UDim2.new(1, 0, 0, controlHeight) or UDim2.fromOffset(fieldWidth, controlHeight)
        end
    end
    section._rowLayouts = section._rowLayouts or {}
    section._rowLayouts[#section._rowLayouts + 1] = layout
    section._rowConnections = section._rowConnections or {}
    section._rowConnections[#section._rowConnections + 1] = row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if row.AbsoluteSize.X ~= previousWidth then layout() end
    end)
    local function bind(object) control = object; layout() end
    return row, bind, label, layout
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
    local row, bind, label, reflow = settingRow(section, cfg, 116, hitHeight(), true)
    local primary = cfg.variant == "primary"
    local button = Util.Create("TextButton", {Name = "Action", Text = "", AutoButtonColor = false,
        BackgroundColor3 = primary and WHITE or BG, BorderSizePixel = 0, ZIndex = 2, Parent = row})
    Util.Corner(button, Theme.radius.sm)
    local stroke = Util.Stroke(button, WHITE, 1, primary and 1 or 0.7)
    local action = Util.Text(button, {Text = tostring(cfg.actionText or "Run"), Font = Theme.fonts.medium,
        TextSize = 14, TextColor3 = primary and BG or WHITE, TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromScale(1, 1), ZIndex = 2})
    if cfg.icon then
        local icon = Icons.Draw(button, cfg.icon, 16, primary and BG or WHITE, 1.7)
        icon.AnchorPoint = Vector2.new(0, 0.5)
        icon.Position = UDim2.new(0, 12, 0.5, 0)
        action.Position = UDim2.fromOffset(28, 0)
        action.Size = UDim2.new(1, -36, 1, 0)
    end
    bind(button)
    local enabled = true
    local api = {}
    button.Activated:Connect(function()
        if enabled then Util.SafeCallback(cfg.callback, true, api) end
    end)
    function api:SetText(text)
        label.Text = tostring(text or "")
        row:SetAttribute("SynUISearch", label.Text .. " " .. tostring(cfg.description or ""))
        reflow()
        refreshSection(section)
        return api
    end
    function api:SetEnabled(state)
        enabled = state and true or false
        label.TextTransparency, action.TextTransparency = enabled and 0 or 0.5, enabled and 0 or 0.5
        button.BackgroundTransparency = enabled and 0 or (primary and 0.65 or 0)
        return api
    end
    function api:GetEnabled() return enabled end
    button.MouseEnter:Connect(function() if enabled and not primary then Util.Tween(stroke, {Transparency = 0.3}, Theme.motion.fast) end end)
    button.MouseLeave:Connect(function() Util.Tween(stroke, {Transparency = primary and 1 or 0.7}, Theme.motion.fast) end)
    refreshSection(section)
    return api
end

-- ---------------------------------------------------------------------------
-- Toggle
-- ---------------------------------------------------------------------------

function Controls.Toggle(section, cfg)
    cfg = cfg or {}
    local trackW, trackH = 46, 26
    local row, bind = settingRow(section, cfg, 48, hitHeight(), false)

    local hit = Util.Create("TextButton", {
        Size = UDim2.fromOffset(48, hitHeight()),
        BackgroundTransparency = 1,
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 1,
    })
    hit.Parent = row
    bind(hit)

    local track = Util.Create("Frame", {
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.new(0, trackW, 0, trackH),
        BackgroundColor3 = Theme.colors.field or RAISED,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    track.Parent = hit
    Util.Corner(track, trackH / 2)
    Util.Stroke(track, LINE, 1, 0.6)

    local knob = Util.Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 11, 0.5, 0),
        Size = UDim2.new(0, trackH - 6, 0, trackH - 6),
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
        local size = trackH - 6
        if on then
            return trackW - 3 - size / 2
        end
        return 3 + size / 2
    end

    local function paint(on, animate)
        local knobSize = trackH - 6
        local targetSize = UDim2.new(0, knobSize, 0, knobSize)
        local targetPos = UDim2.new(0, knobX(on), 0.5, 0)
        local targetColor = on and Theme.colors.black or DIM
        local trackColor = on and WHITE or (Theme.colors.field or RAISED)

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
    local sliderHeight = mobile and 64 or 60
    local row = newRow(section, sliderHeight + 14, cfg)

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
    local knobSize = mobile and 18 or 14
    local inset = mobile and 8 or 6

    local hit = Util.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, sliderHeight),
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
        Position = UDim2.new(0, 0, 0, 12),
        Size = UDim2.new(1, -118, 0, 20),
        Font = Theme.fonts.medium,
        TextSize = 14,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    local valueLabel = Util.Text(row, {
        Text = "",
        Position = UDim2.new(1, -110, 0, 12),
        Size = UDim2.new(0, 110, 0, 20),
        Font = Theme.fonts.regular,
        TextSize = 12,
        TextColor3 = MUTED,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 2,
    })

    local track = Util.Create("Frame", {
        Position = UDim2.new(0, inset, 0, mobile and 46 or 43),
        Size = UDim2.new(1, -(inset * 2), 0, 5),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.86,
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

    controlCleanup(section, stopDrag)

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
    local fieldH = mobile and 48 or 44
    local itemH = mobile and 44 or 36
    local row, bind = settingRow(section, cfg, 180, hitHeight(), true)

    local field = Util.Create("TextButton", {
        Position = UDim2.new(),
        Size = UDim2.new(1, 0, 0, fieldH),
        BackgroundColor3 = Theme.colors.field or RAISED,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        ZIndex = 1,
    })
    field.Parent = row
    bind(field)
    Util.Corner(field, Theme.radius.md)

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
        TextSize = 14,
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

    addHover(field, Theme.colors.field or RAISED, HOVER)

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
    Util.Corner(list, Theme.radius.lg)
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
            Util.Corner(item, Theme.radius.sm)
            addHover(item, SURFACE, HOVER)

            local itemLabel = Util.Text(item, {
                Text = option,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -36, 1, 0),
                Font = Theme.fonts.regular,
                TextSize = 14,
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
        task.delay(Theme.motion.normal, function()
            if not section._destroyed and not isOpen and thisTween == listTween then
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

    row:GetPropertyChangedSignal("Visible"):Connect(function()
        if not row.Visible then
            closeList()
            block.Visible = false
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
    local fieldH = mobile and 48 or 44
    local row, bind = settingRow(section, cfg, 180, hitHeight(), true)

    local box = Util.Create("TextBox", {
        Position = UDim2.new(),
        Size = UDim2.new(1, 0, 0, fieldH),
        BackgroundColor3 = Theme.colors.field or BG,
        BorderSizePixel = 0,
        Text = cfg.value ~= nil and tostring(cfg.value) or "",
        TextColor3 = TEXT,
        Font = Theme.fonts.regular,
        TextSize = 14,
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
    bind(box)
    Util.Corner(box, Theme.radius.md)
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
    local row, bind = settingRow(section, cfg, 116, hitHeight(), true)

    local hitW = mobile and 112 or 104
    local hitH = mobile and 52 or 48
    local pillW = mobile and 100 or 92
    local pillH = mobile and 36 or 32

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
    bind(hit)

    local pill = Util.Create("Frame", {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, pillW, 0, pillH),
        BackgroundColor3 = RAISED,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    pill.Parent = hit
    Util.Corner(pill, Theme.radius.sm)
    local pillStroke = Util.Create("UIStroke", {
        Color = LINE,
        Thickness = 1,
        Transparency = 0.7,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    pillStroke.Parent = pill

    local pillLabel = Util.Text(pill, {
        Text = "",
        Size = UDim2.new(1, 0, 1, 0),
        Font = Theme.fonts.regular,
        TextSize = 12,
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
        pillStroke.Transparency = 0.7
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

    controlCleanup(section, cancelCapture)

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
    local row = newRow(section, 66, cfg)
    local value = Util.Clamp(tonumber(cfg.value) or 0, 0, 1)

    Util.Text(row, {
        Text = cfg.text or "",
        Position = UDim2.new(0, 0, 0, 12),
        Size = UDim2.new(1, -72, 0, 20),
        Font = Theme.fonts.medium,
        TextSize = 14,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    local valueLabel = Util.Text(row, {
        Text = "",
        Position = UDim2.new(1, -66, 0, 12),
        Size = UDim2.new(0, 66, 0, 20),
        Font = Theme.fonts.regular,
        TextSize = 11,
        TextColor3 = MUTED,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 2,
    })

    local track = Util.Create("Frame", {
        Position = UDim2.new(0, 0, 0, 44),
        Size = UDim2.new(1, 0, 0, 5),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.86,
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

local LayoutPad = 16
local LayoutMobilePad = 14
local LayoutStrokeTransparency = 0.62

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
        TextSize = 12,
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
        TextSize = 12,
        TextColor3 = cfg.color or Theme.colors.muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    LayoutCreate("UIPadding", label, {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
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
        TextSize = 12,
        TextColor3 = cfg.color or Theme.colors.muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    LayoutSetLineHeight(paragraph, 1.55)
    LayoutCreate("UIPadding", paragraph, {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 12),
    })
    return paragraph
end

function Layout.Divider(parent)
    parent = LayoutTarget(parent)
    local wrap = LayoutCreate("Frame", parent, {
        Name = "Divider",
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    LayoutCreate("Frame", wrap, {
        Name = "Line",
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 12),
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
    local topHeight = hasIcon and 34 or 20

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
            Size = UDim2.fromOffset(30, 30),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.colors.hover,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
        })
        Util.Corner(tile, Theme.radius.sm)
        LayoutStroke(tile, 0.55)
        local icon = Icons.Draw(tile, cfg.icon, 16, Theme.colors.text, 2)
        if icon then
            icon.AnchorPoint = Vector2.new(0.5, 0.5)
            icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        end
        textX = 34
    end

    local titleRight = 0
    if actionCfg then
        titleRight = 82
    end

    LayoutText(top, {
        Name = "CardTitle",
        Size = UDim2.new(1, -(textX + titleRight), 0, 20),
        Position = UDim2.new(0, textX, 0, hasIcon and 7 or 0),
        Text = tostring(cfg.title or ""),
        TextSize = 13,
        Font = Theme.fonts.bold,
        TextColor3 = Theme.colors.text,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    if actionCfg then
        local action = LayoutCreate("TextButton", top, {
            Name = "CardAction",
            Size = UDim2.fromOffset(84, 28),
            Position = UDim2.new(1, 0, 0.5, 0),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.colors.raised,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Text = tostring(actionCfg.text or "Open"),
            Font = Theme.fonts.medium,
            TextSize = 11,
            TextColor3 = Theme.colors.muted,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AutoButtonColor = false,
        })
        Util.Corner(action, Theme.radius.sm)
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
            PaddingTop = UDim.new(0, 10),
        })
        local body = LayoutText(bodyWrap, {
            Name = "CardBody",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = tostring(bodyText),
            TextSize = 12,
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
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })
    local cardLayout = LayoutCreate("UIListLayout", card, {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local pad = LayoutPaddingValue()

    local header = LayoutCreate("Frame", card, {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, (cfg.subtitle or cfg.description) and 60 or 42),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    })

    local iconTile = nil
    if cfg.icon and cfg.icon ~= "" then
        iconTile = LayoutCreate("Frame", header, {
            Name = "IconTile",
            Size = UDim2.fromOffset(30, 30),
            Position = UDim2.new(0, pad, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.colors.hover,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        })
        Util.Corner(iconTile, Theme.radius.sm)
        local icon = Icons.Draw(iconTile, cfg.icon, 16, Theme.colors.text, 2)
        if icon then
            icon.AnchorPoint = Vector2.new(0.5, 0.5)
            icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        end
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

    local textX = pad + (iconTile and 40 or 0)
    local badgeReserve = (badgeText and 104 or pad)

    local title = LayoutText(header, {
        Name = "Title",
        Size = UDim2.new(1, -(textX + badgeReserve), 0, 18),
        Position = UDim2.new(0, textX, 0, subtitleText and 9 or 20),
        Text = tostring(cfg.title or "Section"),
        TextSize = 15,
        Font = Theme.fonts.medium,
        TextColor3 = Theme.colors.muted,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    local subtitle = nil
    if subtitleText then
        subtitle = LayoutText(header, {
            Name = "Subtitle",
            Size = UDim2.new(1, -(textX + badgeReserve), 0, 15),
            Position = UDim2.new(0, textX, 0, 31),
            Text = tostring(subtitleText),
            TextSize = 12,
            Font = Theme.fonts.regular,
            TextColor3 = Theme.colors.dim,
            TextTransparency = 0.38,
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
            TextSize = 9,
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

    local content = LayoutCreate("Frame", card, {
        Name = "Content",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.colors.raised,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        LayoutOrder = 2,
    })
    Util.Corner(content, Theme.radius.lg)
    LayoutStroke(content, 0.8)

    local contentPadding = LayoutCreate("UIPadding", content, {
        PaddingLeft = UDim.new(0, pad),
        PaddingRight = UDim.new(0, pad),
        PaddingTop = UDim.new(0, 0),
        PaddingBottom = UDim.new(0, 0),
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
            iconTile.Position = UDim2.new(0, currentPad, 0.5, 0)
        end

        local currentX = currentPad + (iconTile and 40 or 0)
        local currentReserve = badge and 104 or currentPad

        title.Position = UDim2.new(0, currentX, 0, subtitle and 7 or 10)
        title.Size = UDim2.new(1, -(currentX + currentReserve), 0, 22)
        if subtitle then
            subtitle.Position = UDim2.new(0, currentX, 0, 31)
            subtitle.Size = UDim2.new(1, -(currentX + currentReserve), 0, 15)
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
            if row and row.Parent and row.Visible then
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
        for _, dispose in ipairs(self._controlCleanups or {}) do dispose() end
        self._controlCleanups = {}
        for _, connection in ipairs(self._rowConnections or {}) do connection:Disconnect() end
        self._rowConnections, self._rowLayouts = {}, {}
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
    Util.Stroke(obj, Theme.colors.line, 1, transparency or Theme.stroke or 0.62)
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
        TextSize = 12,
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

-- Fade individual properties so geometry and text measurements stay stable.
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
        if entry.tween then entry.tween:Cancel() end
        entry.tween = Util.Tween(entry.object, {
            [entry.property] = entry.target,
        }, duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
end

local function FeedbackFadeOut(entries, duration)
    for _, entry in ipairs(entries) do
        if entry.tween then entry.tween:Cancel() end
        entry.tween = Util.Tween(entry.object, {
            [entry.property] = 1,
        }, duration or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
end

local function FeedbackStopFades(entries)
    for _, entry in ipairs(entries or {}) do
        if entry.tween then entry.tween:Cancel(); entry.tween = nil end
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

    stack.order = stack.order + 1
    local order = stack.order

    local state = {
        closed = false,
        connections = {},
        entry = stack,
        reducedMotion = window._reducedMotion,
    }

    local root = FeedbackCreate("Frame", layer, {
        Name = string.format("Notification_%03d", order),
        Size = UDim2.new(1, 0, 0, 0),
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
        BackgroundColor3 = Theme.colors.panel or Theme.colors.raised,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Position = UDim2.new(),
    })
    Util.Corner(card, Theme.radius.lg)
    FeedbackStroke(card)
    FeedbackCreate("UIPadding", card, {
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),
        PaddingTop = UDim.new(0, 16),
        PaddingBottom = UDim.new(0, 16),
    })
    FeedbackCreate("UIListLayout", card, {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local header = FeedbackCreate("Frame", card, {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    })

    local tile = FeedbackCreate("Frame", header, {
        Name = "IconTile",
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.colors.hover,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
    })
    Util.Corner(tile, Theme.radius.sm)
    FeedbackStroke(tile, 0.55)
    local tileIcon = Icons.Draw(tile, cfg.icon or "dot", 16, Theme.colors.text, 2)
    if tileIcon then
        tileIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        tileIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    end

    FeedbackText(header, {
        Name = "Title",
        Size = UDim2.new(1, -70, 0, 30),
        Position = UDim2.new(0, 42, 0, 0),
        Text = tostring(cfg.title or "Notification"),
        TextSize = 13,
        Font = Theme.fonts.bold,
        TextColor3 = Theme.colors.text,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    local closeButton = FeedbackCreate("TextButton", header, {
        Name = "Close",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -28, 0, 1),
        BackgroundColor3 = Theme.colors.hover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    Util.Corner(closeButton, Theme.radius.sm)
    local closeIcon = Icons.Draw(closeButton, "close", 14, Theme.colors.muted, 2)
    if closeIcon then
        closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        closeIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    end

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
            PaddingTop = UDim.new(0, 8),
        })
        local body = FeedbackText(bodyWrap, {
            Name = "Text",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = tostring(bodyText),
            TextSize = 12,
            TextTransparency = 0.3,
            TextColor3 = Theme.colors.muted,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        FeedbackSetLineHeight(body, 1.5)
    end

    FeedbackCreate("Frame", card, {
        Name = "ProgressGap",
        Size = UDim2.new(1, 0, 0, 12),
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

    FeedbackFadeIn(state.fades, state.reducedMotion and 0 or Theme.motion.slow)

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

    if instant or state.reducedMotion or not root or not root.Parent then
        FeedbackStopFades(state.fades)
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
    task.delay(0.2, function()
        FeedbackStopFades(state.fades)
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
            order = 0,
            items = {},
            wasVisible = overlay.Visible,
        }
        FeedbackOverlays[overlay] = record
    end
    record.count = record.count + 1
    record.order = record.order + 1
    overlay.Visible = true

    local function dialogWidth()
        return math.floor(math.max(160, math.min(400, overlay.AbsoluteSize.X - 32)))
    end

    local overlayZ = overlay.ZIndex or 100
    -- Each deeper dialog gets its own backdrop above the previous card, so
    -- stacked dialogs cannot be clicked through.
    local baseZ = overlayZ + record.order * 2

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
        order = record.order,
    }
    record.items[state] = true

    local backdrop = FeedbackCreate("TextButton", overlay, {
        Name = "DialogBackdrop",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.colors.black,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = baseZ - 1,
    })

    local card = dialogGui("Frame", overlay, {
        Name = "Dialog",
        Size = UDim2.new(0, dialogWidth(), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.colors.raised,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Active = true,
    })
    Util.Corner(card, Theme.radius.xl)
    FeedbackStroke(card, 0.68)
    FeedbackConnect(state, overlay:GetPropertyChangedSignal("Size"), function()
        if not state.closed then
            card.Size = UDim2.fromOffset(dialogWidth(), 0)
        end
    end)

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
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    })

    FeedbackText(header, {
        Name = "Title",
        Size = UDim2.new(1, -34, 0, 28),
        Text = tostring(cfg.title or "Confirm"),
        TextSize = 17,
        Font = Theme.fonts.bold,
        TextColor3 = Theme.colors.text,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    local closeButton = dialogGui("TextButton", header, {
        Name = "Close",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -28, 0, 0),
        BackgroundColor3 = Theme.colors.hover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    Util.Corner(closeButton, Theme.radius.sm)
    local dialogCloseIcon = Icons.Draw(closeButton, "close", 14, Theme.colors.muted, 2)
    if dialogCloseIcon then
        dialogCloseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        dialogCloseIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    end

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
            PaddingTop = UDim.new(0, 12),
        })
        local body = FeedbackText(bodyWrap, {
            Name = "Text",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = tostring(bodyText),
            TextSize = 12,
            TextColor3 = Theme.colors.muted,
            TextTransparency = 0.3,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        FeedbackSetLineHeight(body, 1.65)
    end

    FeedbackCreate("Frame", card, {
        Name = "ActionGap",
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 3,
    })

    local buttonHeight = game:GetService("UserInputService").TouchEnabled and 44 or 40
    local actions = dialogGui("Frame", card, {
        Name = "Actions",
        Size = UDim2.new(1, 0, 0, buttonHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 4,
    })

    local confirm = dialogGui("TextButton", actions, {
        Name = "Confirm",
        Size = UDim2.new(0, 96, 0, buttonHeight),
        Position = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.colors.white,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = tostring(cfg.confirmText or "Confirm"),
        Font = Theme.fonts.medium,
        TextSize = 12,
        TextColor3 = Theme.colors.black,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
    })
    Util.Corner(confirm, Theme.radius.md)

    local cancel = dialogGui("TextButton", actions, {
        Name = "Cancel",
        Size = UDim2.new(0, 84, 0, buttonHeight),
        Position = UDim2.new(1, -104, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.colors.raised,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = tostring(cfg.cancelText or "Cancel"),
        Font = Theme.fonts.medium,
        TextSize = 12,
        TextColor3 = Theme.colors.muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
    })
    Util.Corner(cancel, Theme.radius.md)
    FeedbackStroke(cancel, 0.55)

    local function dispose()
        if state.disposed then return end
        state.closed, state.disposed = true, true
        FeedbackDisconnectAll(state)
        FeedbackStopFades(state.fades)
        if state.backdropTween then state.backdropTween:Cancel() end
        backdrop:Destroy()
        card:Destroy()
        record.items[state] = nil
        record.count = record.count - 1
        if record.count <= 0 then
            FeedbackOverlays[overlay] = nil
            if overlay.Parent then overlay.Visible = record.wasVisible end
        end
        state.backdrop, state.card = nil, nil
    end
    state.Dispose = dispose
    state.fades = FeedbackCollectFades(card)

    local function finish(confirmed)
        if state.closed then
            return
        end
        state.closed = true

        FeedbackDisconnectAll(state)

        confirm.Active = false
        cancel.Active = false
        closeButton.Active = false

        if state.backdropTween then state.backdropTween:Cancel() end
        local duration = window._reducedMotion and 0 or Theme.motion.normal
        state.backdropTween = Util.Tween(backdrop, {BackgroundTransparency = 1}, duration)
        FeedbackFadeOut(state.fades, duration)
        Util.SafeCallback(cfg.callback, confirmed == true)
        if duration == 0 then dispose() else task.delay(duration, dispose) end
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
            BackgroundTransparency = 0.12,
        }, Theme.motion.fast, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
    FeedbackConnect(state, confirm.MouseLeave, function()
        Util.Tween(confirm, {
            BackgroundTransparency = 0,
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
            for dialog in pairs(record.items) do
                if dialog.order > state.order then return end
            end
            if input.KeyCode == Enum.KeyCode.Escape and not gameProcessed then
                finish(false)
            end
        end)
    end)

    state.backdropTween = Util.Tween(backdrop, {
        BackgroundTransparency = 0.45,
    }, window._reducedMotion and 0 or Theme.motion.slow)
    FeedbackFadeIn(state.fades, window._reducedMotion and 0 or Theme.motion.slow)

    state.frame = card
    state.Close = function(confirmed)
        finish(confirmed == true)
    end

    return state
end

function Feedback.Destroy(window)
    local stack = FeedbackStacks[window._notifyLayer]
    if stack then
        while #stack.items > 0 do FeedbackDismiss(stack.items[1], true) end
        FeedbackStacks[window._notifyLayer] = nil
    end
    local record = FeedbackOverlays[window._overlay]
    if record then
        while next(record.items) do
            local dialog = next(record.items)
            dialog.Dispose()
        end
    end
end


-- SYNUI window shell: labeled navigation, inset workspace and fixed-size fades.
local Core = {}

local function coreService(name)
    local ok, value = pcall(function() return game:GetService(name) end)
    return ok and value or nil
end

local CorePlayers = coreService("Players")
local CoreUIS = coreService("UserInputService")

local function coreLength(value, base, fallback)
    if value == nil then return fallback end
    local ok, pixels = pcall(function() return value.Scale * base + value.Offset end)
    return ok and pixels or tonumber(value) or fallback
end

local function coreIconColor(root, color)
    for _, node in ipairs(root:GetDescendants()) do
        if node:IsA("UIStroke") then node.Color = color
        elseif node:IsA("GuiObject") and node.BackgroundTransparency < 1 then node.BackgroundColor3 = color end
    end
end

function Core.CreateWindow(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local C, F = Theme.colors, Theme.fonts
    local connections, cleanups = {}, {}
    local viewport = Util.Viewport()
    local preferred = Vector2.new(coreLength(cfg.size and cfg.size.X, viewport.X, 780), coreLength(cfg.size and cfg.size.Y, viewport.Y, 580))
    local targetW, targetH, targetX, targetY = preferred.X, preferred.Y, viewport.X / 2, viewport.Y / 2
    local lastViewport = viewport
    local laidOut, explicitSize = false, cfg.size ~= nil
    local savedGeometry, onCloseCallback, window
    local revealTween, revealToken = nil, 0

    local function connect(signal, callback)
        if not signal then return end
        local ok, connection = pcall(function() return signal:Connect(callback) end)
        if ok and connection then connections[#connections + 1] = connection end
        return connection
    end
    local function cleanup(fn) if type(fn) == "function" then cleanups[#cleanups + 1] = fn end end
    local function text(parent, props) return Util.Text(parent, props) end
    local function panel(parent, name, radius)
        local object = Util.Create("Frame", {Name = name, BackgroundColor3 = C.black, BorderSizePixel = 0, Parent = parent})
        if radius then Util.Corner(object, radius) end
        return object
    end
    local function line(parent, position, size)
        return Util.Create("Frame", {BackgroundColor3 = C.white, BackgroundTransparency = 0.9,
            BorderSizePixel = 0, Position = position, Size = size, Parent = parent})
    end
    local function draw(parent, name, size, color)
        local icon = Icons.Draw(parent, name, size, color or C.white, 1.7)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromScale(0.5, 0.5)
        return icon
    end

    local screen = Util.Create("ScreenGui", {Name = "SynUI", ResetOnSpawn = false, IgnoreGuiInset = false,
        DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    pcall(function() screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
    pcall(function()
        local env = type(getgenv) == "function" and getgenv() or _G
        local syn = env and env.syn
        local protect = syn and syn.protect_gui or env and env.protect_gui
        if type(protect) == "function" then protect(screen) end
    end)
    local function mount(parent)
        assert(parent ~= nil, "no GUI parent is available")
        screen.Parent = parent
    end
    local mounted, mountError = pcall(mount, Util.GetParent(cfg))
    if not mounted and cfg.parent == nil and CorePlayers then
        mounted, mountError = pcall(function()
            local player = CorePlayers.LocalPlayer
            mount(player and (player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)))
        end)
    end
    if not mounted then
        screen:Destroy()
        error("[SYNUI] Could not parent the window: " .. tostring(mountError), 2)
    end

    local shadow = panel(screen, "SynUIShadow", 14)
    shadow.BackgroundTransparency = 0.5
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.ZIndex = 9
    local frame = panel(screen, "SynUIWindow", 10)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.ClipsDescendants = true
    frame.Active = true
    frame.ZIndex = 10
    Util.Stroke(frame, C.white, 1, 0.76)
    Util.Create("UIScale", {Name = "SynUIScale", Scale = 1, Parent = frame})
    local header = panel(frame, "Header")
    header.BackgroundTransparency = 1
    header.ZIndex = 4
    local dragHandle = Util.Create("Frame", {Name = "DragHandle", BackgroundTransparency = 1,
        Active = true, Size = UDim2.new(1, -156, 1, 0), Parent = header})
    local brand = panel(dragHandle, "BrandMark", 6)
    brand.Size = UDim2.fromOffset(28, 28)
    brand.Position = UDim2.new(0, 20, 0.5, -14)
    Util.Stroke(brand, C.white, 1, 0.72)
    draw(brand, cfg.icon or "grid", 16)
    local title = text(dragHandle, {Name = "Title", Text = tostring(cfg.title or "SYNUI"), Font = F.bold,
        TextSize = 20, Position = UDim2.fromOffset(60, 20), Size = UDim2.new(1, -66, 0, 25), TextTruncate = Enum.TextTruncate.AtEnd})
    local subtitle = text(dragHandle, {Name = "Subtitle", Text = tostring(cfg.subtitle or "Interface library"),
        TextSize = 12, TextTransparency = 0.35, Position = UDim2.fromOffset(60, 47), Size = UDim2.new(1, -66, 0, 17), TextTruncate = Enum.TextTruncate.AtEnd})
    line(header, UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1))

    local function action(name, callback)
        local button = Util.Create("TextButton", {Name = "IconButton_" .. name, Text = "", AutoButtonColor = false,
            BackgroundColor3 = C.white, BackgroundTransparency = 1, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(40, 40), Parent = header})
        Util.Corner(button, 6)
        draw(button, name, 18)
        connect(button.MouseEnter, function() Util.Tween(button, {BackgroundTransparency = 0.92}, Theme.motion.fast) end)
        connect(button.MouseLeave, function() Util.Tween(button, {BackgroundTransparency = 1}, Theme.motion.fast) end)
        connect(button.Activated, callback)
        return button
    end
    local maximize = action("maximize", function() window:Maximize() end)
    local minimize = action("minus", function() window:_toggleMinimize() end)
    local close = action("close", function() window:_closePressed() end)

    local body = Util.Create("Frame", {Name = "Body", BackgroundTransparency = 1, Parent = frame})
    local sidebar = panel(body, "Sidebar")
    sidebar.Size = UDim2.new(0, 196, 1, 0)
    line(sidebar, UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0))
    text(sidebar, {Text = "NAVIGATION", TextSize = 10, TextTransparency = 0.45,
        Position = UDim2.fromOffset(20, 15), Size = UDim2.new(1, -40, 0, 16)})
    local nav = Util.Create("ScrollingFrame", {Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 1, -154),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 0, Parent = sidebar})
    Util.Create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = nav})

    local profile = panel(sidebar, "Profile")
    profile.AnchorPoint = Vector2.new(0, 1)
    profile.Position = UDim2.new(0, 12, 1, -10)
    profile.Size = UDim2.new(1, -24, 0, 94)
    line(profile, UDim2.new(), UDim2.new(1, 0, 0, 1))
    local player = CorePlayers and CorePlayers.LocalPlayer
    local displayName = player and player.DisplayName or "Player"
    local username = player and player.Name or "Player"
    local monogram = text(profile, {Name = "Avatar", Text = string.upper(string.sub(displayName, 1, 1)),
        Font = F.medium, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center,
        Position = UDim2.fromOffset(4, 15), Size = UDim2.fromOffset(36, 36)})
    Util.Corner(monogram, 18)
    Util.Stroke(monogram, C.white, 1, 0.65)
    text(profile, {Name = "DisplayName", Text = displayName, Font = F.medium, TextSize = 13,
        Position = UDim2.fromOffset(50, 15), Size = UDim2.new(1, -54, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd})
    text(profile, {Name = "Username", Text = "@" .. username, TextSize = 11, TextTransparency = 0.4,
        Position = UDim2.fromOffset(50, 35), Size = UDim2.new(1, -54, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd})
    text(profile, {Name = "Context", Text = tostring(cfg.footer or "Roblox client"), TextSize = 11, TextTransparency = 0.35,
        Position = UDim2.fromOffset(4, 67), Size = UDim2.new(1, -8, 0, 17), TextTruncate = Enum.TextTruncate.AtEnd})

    local strip = Util.Create("ScrollingFrame", {Name = "TabStrip", BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 0, Parent = body})
    Util.Padding(strip, 12, 4)
    Util.Create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = strip})

    local content = panel(body, "Content", 8)
    content.ClipsDescendants = true
    Util.Stroke(content, C.white, 1, 0.86)
    local searchIcon = draw(content, "search", 16)
    searchIcon.AnchorPoint = Vector2.new(0, 0.5)
    searchIcon.Position = UDim2.fromOffset(24, 34)
    local search = Util.Create("TextBox", {Name = "SearchInput", BackgroundColor3 = C.black, BorderSizePixel = 0,
        Text = "", PlaceholderText = "Search controls…", PlaceholderColor3 = C.white, TextColor3 = C.white,
        TextSize = 14, Font = F.regular, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
        Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 0, 40), Parent = content})
    Util.Padding(search, 36, 0)
    Util.Corner(search, 6)
    Util.Stroke(search, C.white, 1, 0.82)
    searchIcon.ZIndex = 3
    local tabHost = Util.Create("Frame", {Name = "TabHost", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), ClipsDescendants = true, Parent = content})
    local empty = text(content, {Name = "SearchEmpty", Text = "No matching controls\nTry a different search.",
        TextSize = 14, TextTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Center,
        Position = UDim2.fromOffset(16, 116), Size = UDim2.new(1, -32, 0, 60), Visible = false, ZIndex = 4})

    local footer = panel(frame, "Footer")
    footer.BackgroundTransparency = 1
    footer.AnchorPoint = Vector2.new(0, 1)
    footer.Position = UDim2.fromScale(0, 1)
    footer.Size = UDim2.new(1, 0, 0, 30)
    line(footer, UDim2.new(), UDim2.new(1, 0, 0, 1))
    text(footer, {Text = "SYNUI  /  " .. Theme.version, TextSize = 10, TextTransparency = 0.4,
        Position = UDim2.fromOffset(20, 0), Size = UDim2.new(0, 160, 1, 0)})
    local status = text(footer, {Name = "Status", Text = "Ready", TextSize = 11, TextTransparency = 0.3,
        TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.4, 0, 0, 0),
        Size = UDim2.new(0.6, -36, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd})

    local overlay = Util.Create("Frame", {Name = "Overlay", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 100, Parent = screen})
    Util.Create("UIScale", {Scale = 1, Parent = overlay})
    local notifyLayer = Util.Create("Frame", {Name = "NotifyLayer", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.new(0, 320, 1, -32), ZIndex = 200, Parent = screen})
    Util.Create("UIScale", {Scale = 1, Parent = notifyLayer})
    local launcher
    if cfg.launcher ~= false then
        launcher = Util.Create("TextButton", {Name = "SynUILauncher", Text = "", AutoButtonColor = false,
            BackgroundColor3 = C.black, BorderSizePixel = 0, Position = UDim2.fromOffset(20, 20),
            Size = UDim2.fromOffset(240, 56), Visible = false, ZIndex = 300, Parent = screen})
        Util.Corner(launcher, 10)
        Util.Stroke(launcher, C.white, 1, 0.5)
        Util.Create("UIScale", {Scale = 1, Parent = launcher})
        local icon = draw(launcher, "grid", 18)
        icon.Position = UDim2.new(0, 28, 0.5, 0)
        text(launcher, {Text = title.Text, Font = F.medium, TextSize = 14, Position = UDim2.fromOffset(50, 9), Size = UDim2.new(1, -64, 0, 20)})
        text(launcher, {Text = "Tap to restore", TextSize = 11, TextTransparency = 0.35, Position = UDim2.fromOffset(50, 30), Size = UDim2.new(1, -64, 0, 16)})
        connect(launcher.Activated, function() window:SetVisible(true) end)
        cleanup(Util.MakeDraggable(launcher, launcher, screen))
    end
    local reveal = panel(frame, "Reveal", 10)
    reveal.Size = UDim2.fromScale(1, 1)
    reveal.BackgroundTransparency = 1
    reveal.Visible = false
    reveal.ZIndex = 50

    window = {frame = frame, screenGui = screen, gui = screen, header = header, body = body, sidebar = sidebar,
        content = content, footer = footer, launcher = launcher, _notifyLayer = notifyLayer, _overlay = overlay,
        _tabs = {}, _activeTab = nil, _mobile = false, _visible = cfg.visible ~= false, _minimized = false,
        _maximized = false, _destroyed = false, _displayScale = 1, _connections = connections,
        _reducedMotion = cfg.reducedMotion == true}

    local function syncShadow()
        shadow.Size = UDim2.fromOffset(frame.Size.X.Offset + 12, frame.Size.Y.Offset + 12)
        shadow.Position = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset, frame.Position.Y.Scale, frame.Position.Y.Offset + 5)
        shadow.Visible = frame.Visible
    end
    connect(frame:GetPropertyChangedSignal("Position"), syncShadow)
    connect(frame:GetPropertyChangedSignal("Size"), syncShadow)
    connect(frame:GetPropertyChangedSignal("Visible"), syncShadow)

    local function stopReveal()
        revealToken = revealToken + 1
        if revealTween then revealTween:Cancel(); revealTween = nil end
        reveal.Visible = false
        reveal.BackgroundTransparency = 1
    end
    local function showReveal()
        stopReveal()
        if cfg.reducedMotion then return end
        reveal.Visible = true
        reveal.BackgroundTransparency = 0
        local token = revealToken
        revealTween = Util.Tween(reveal, {BackgroundTransparency = 1}, Theme.motion.slow, Enum.EasingStyle.Quad)
        task.delay(Theme.motion.slow, function()
            if not window._destroyed and token == revealToken then reveal.Visible = false end
        end)
    end

    local function updateColumns(tab)
        if not tab._columns then return end
        local columns = tab._columns
        local available = targetW - (window._mobile and 0 or 196) - 64
        local horizontal = available >= 600
        columns.list.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
        for _, column in ipairs({columns.left, columns.right}) do
            column.frame.Size = horizontal and UDim2.new(0.5, -6, 0, 0) or UDim2.new(1, 0, 0, 0)
        end
    end

    local function updateHeading(tab)
        if not tab._heading then return end
        local short = window._shortPage
        tab._heading.Size = UDim2.new(1, 0, 0, short and 28 or (tab.subtitle and 102 or 80))
        tab._eyebrow.Visible, tab._summary.Visible = not short, not short
        if tab._description then tab._description.Visible = not short end
        tab._pageTitle.Position = UDim2.fromOffset(0, short and 0 or 21)
        tab._pageTitle.Size = UDim2.new(1, 0, 0, short and 28 or 32)
        tab._pageTitle.TextSize = short and 22 or 26
        tab._list.Padding = UDim.new(0, short and 8 or 20)
    end

    local function availableViewport()
        local vp = Util.Viewport()
        pcall(function()
            local size = screen.AbsoluteSize
            if size.X > 0 and size.Y > 0 then vp = size end
        end)
        pcall(function()
            if CoreUIS.OnScreenKeyboardVisible and CoreUIS.OnScreenKeyboardSize.Y > 0 then
                vp = Vector2.new(vp.X, math.max(180, vp.Y - CoreUIS.OnScreenKeyboardSize.Y))
            end
        end)
        return vp
    end
    local function applyLayout(geometry)
        if window._destroyed then return end
        stopReveal()
        local vp = availableViewport()
        local touch = CoreUIS and CoreUIS.TouchEnabled
        local w, h = preferred.X, preferred.Y
        if not explicitSize and touch then
            w = math.min(w, vp.X * 0.9)
            h = math.min(h, vp.Y < 500 and vp.Y - 24 or vp.Y * 0.76)
        end
        local cx, cy = targetX / math.max(1, lastViewport.X), targetY / math.max(1, lastViewport.Y)
        if not laidOut then cx, cy = 0.5, 0.5 end
        if geometry then
            w, h = geometry.width, geometry.height
            cx, cy = geometry.x / geometry.viewport.X, geometry.y / geometry.viewport.Y
        elseif window._maximized then w, h, cx, cy = vp.X - 32, vp.Y - 32, 0.5, 0.5 end
        w = math.min(math.max(280, w), math.max(1, vp.X - 16))
        h = math.min(math.max(240, h), math.max(1, vp.Y - 16))
        local compact = w < 640 or h < (touch and 440 or 380)
        targetW, targetH = w, h
        targetX = Util.Clamp(cx * vp.X, w / 2 + 8, vp.X - w / 2 - 8)
        targetY = Util.Clamp(cy * vp.Y, h / 2 + 8, vp.Y - h / 2 - 8)
        window._mobile = compact
        frame.Size, frame.Position = UDim2.fromOffset(w, h), UDim2.fromOffset(targetX, targetY)
        local short = compact and h < 440
        window._shortPage = short
        local headerH, footerH = short and 56 or (compact and 72 or 80), short and 24 or 30
        local stripH = short and 48 or 52
        header.Size = UDim2.new(1, 0, 0, headerH)
        footer.Size = UDim2.new(1, 0, 0, footerH)
        body.Position, body.Size = UDim2.fromOffset(0, headerH), UDim2.new(1, 0, 1, -headerH - footerH)
        sidebar.Visible, strip.Visible = not compact, compact
        strip.Size = UDim2.new(1, 0, 0, stripH)
        local inset = compact and 6 or 10
        content.Position = UDim2.fromOffset((compact and 0 or 196) + inset, compact and stripH + 6 or 6)
        content.Size = UDim2.new(1, -(compact and 0 or 196) - inset * 2, 1, -(compact and stripH + 12 or 12))
        local hit = touch and 44 or 40
        close.Size, minimize.Size, maximize.Size = UDim2.fromOffset(hit, hit), UDim2.fromOffset(hit, hit), UDim2.fromOffset(hit, hit)
        close.Position, minimize.Position, maximize.Position = UDim2.new(1, -12, 0.5, 0), UDim2.new(1, -16 - hit, 0.5, 0), UDim2.new(1, -20 - hit * 2, 0.5, 0)
        maximize.Visible = not compact
        dragHandle.Size = UDim2.new(1, -(compact and (hit * 2 + 24) or (hit * 3 + 28)), 1, 0)
        brand.Position = UDim2.new(0, compact and 12 or 20, 0.5, -14)
        title.Position, title.Size = UDim2.fromOffset(compact and 50 or 60, short and 7 or (compact and 15 or 20)), UDim2.new(1, -(compact and 54 or 66), 0, 25)
        title.TextSize = compact and 18 or 20
        subtitle.Position, subtitle.Size = UDim2.fromOffset(compact and 50 or 60, short and 32 or (compact and 42 or 47)), UDim2.new(1, -(compact and 54 or 66), 0, 17)
        local searchH = touch and 44 or 40
        local searchTop = short and 8 or 14
        search.Position = UDim2.fromOffset(14, searchTop)
        search.Size = UDim2.new(1, -28, 0, searchH)
        searchIcon.Position = UDim2.fromOffset(24, searchTop + searchH / 2)
        local hostTop = searchH + searchTop + (short and 4 or 12)
        tabHost.Position, tabHost.Size = UDim2.fromOffset(0, hostTop), UDim2.new(1, 0, 1, -hostTop)
        empty.Position, empty.Size = UDim2.fromOffset(16, hostTop), UDim2.new(1, -32, 1, -hostTop)
        notifyLayer.Size = UDim2.fromOffset(math.min(320, vp.X - 32), vp.Y - 32)
        overlay.Size = UDim2.fromOffset(vp.X, vp.Y)
        for _, tab in ipairs(window._tabs) do
            local pad = tab.content:FindFirstChildOfClass("UIPadding")
            pad.PaddingLeft, pad.PaddingRight = UDim.new(0, compact and 12 or 20), UDim.new(0, compact and 12 or 20)
            updateHeading(tab)
            updateColumns(tab)
            for _, section in ipairs(tab.sections) do
                for _, layout in ipairs(section._rowLayouts or {}) do layout() end
            end
        end
        laidOut, lastViewport = true, vp
        syncShadow()
    end

    function window:_refreshSearch()
        if self._destroyed or not self._activeTab then return end
        local tab = self._activeTab
        local query = string.lower(search.Text or ""):match("^%s*(.-)%s*$")
        local matches, controls = 0, 0
        for _, section in ipairs(tab.sections) do
            local sectionText = string.lower(section._title.Text .. " " .. (section._subtitle and section._subtitle.Text or ""))
            local wholeSection = query == "" or string.find(sectionText, query, 1, true) ~= nil
            local shown = 0
            for _, row in ipairs(section._rows) do
                controls = controls + 1
                local rowText = row:GetAttribute("SynUISearch") or ""
                row.Visible = wholeSection or string.find(string.lower(rowText), query, 1, true) ~= nil
                if row.Visible then shown = shown + 1 end
            end
            section.frame.Visible = wholeSection or shown > 0
            if section.frame.Visible then matches = matches + shown + (wholeSection and 1 or 0) end
            section:Refresh()
        end
        if tab._summary then tab._summary.Text = tostring(controls) .. " controls  ·  " .. tostring(#tab.sections) .. " sections" end
        empty.Visible = query ~= "" and matches == 0
        tab.content.Visible = not empty.Visible
    end
    connect(search:GetPropertyChangedSignal("Text"), function() window:_refreshSearch() end)

    local Tab, Column = {}, {}
    Tab.__index, Column.__index = Tab, Column
    local function append(container, object)
        container._order = container._order + 1
        object.LayoutOrder = container._order
        return object
    end
    local function addSection(container, options)
        local section = Layout.Section(container, options)
        append(container, section.frame)
        local tab = container._tab or container
        section.tab, section.window = tab, window
        tab.sections[#tab.sections + 1] = section
        task.defer(function() if not window._destroyed then window:_refreshSearch() end end)
        return section
    end
    Tab.Section, Column.Section = addSection, addSection
    for _, name in ipairs({"Card", "Label", "Paragraph", "Divider", "Spacer"}) do
        local method = name
        local fn = function(container, options) return append(container, Layout[method](container, options)) end
        Tab[method], Column[method] = fn, fn
    end
    function Tab:Columns()
        if self._columns then return self._columns.left, self._columns.right end
        local host = Util.Create("Frame", {Name = "Columns", BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.content})
        append(self, host)
        local list = Util.Create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = host})
        local function column(name, order)
            local root = Util.Create("Frame", {Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = host})
            Util.Create("UIListLayout", {Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder, Parent = root})
            return setmetatable({frame = root, content = root, window = window, _window = window, _tab = self, _order = 0}, Column)
        end
        self._columns = {host = host, list = list, left = column("Left", 1), right = column("Right", 2)}
        updateColumns(self)
        return self._columns.left, self._columns.right
    end

    local selectTab
    local function navButton(tab, index, horizontal)
        local button = Util.Create("TextButton", {Name = (horizontal and "MTab_" or "Tab_") .. index,
            Text = "", AutoButtonColor = false, BackgroundColor3 = C.white, BackgroundTransparency = 1,
            BorderSizePixel = 0, Size = horizontal and UDim2.fromOffset(math.max(120, #tab.name * 8 + 60), 44) or UDim2.new(1, 0, 0, 44),
            LayoutOrder = index, Parent = horizontal and strip or nav})
        Util.Corner(button, 6)
        local icon = draw(button, tab.icon, 16)
        icon.Position = UDim2.new(0, 24, 0.5, 0)
        local label = text(button, {Name = "Label", Text = tab.name, TextSize = 14, Font = F.medium,
            Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -54, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd})
        local stroke = Util.Stroke(button, C.white, 1, 1)
        local function paint(active)
            button.BackgroundTransparency = active and 0 or 1
            label.TextColor3 = active and C.black or C.white
            label.TextTransparency = active and 0 or 0.28
            stroke.Transparency = active and 1 or 0.95
            coreIconColor(icon, active and C.black or C.white)
        end
        paint(false)
        connect(button.Activated, function() selectTab(tab) end)
        connect(button.MouseEnter, function() if window._activeTab ~= tab then Util.Tween(stroke, {Transparency = 0.6}, Theme.motion.fast) end end)
        connect(button.MouseLeave, function() paint(window._activeTab == tab) end)
        return button, paint
    end
    selectTab = function(tab)
        if type(tab) ~= "table" or tab.window ~= window or window._destroyed or tab == window._activeTab then return end
        if window._activeTab then
            local previous = window._activeTab
            previous.content.Visible = false
            previous._paint(false); previous._paintMobile(false)
        end
        window._activeTab = tab
        search.Text = ""
        tab.content.Visible = true
        tab._paint(true); tab._paintMobile(true)
        window:_refreshSearch()
    end
    function window:Tab(options)
        if self._destroyed then return nil end
        options = type(options) == "table" and options or {name = tostring(options or "Tab")}
        local tab = setmetatable({name = tostring(options.name or "Tab"), icon = options.icon or "grid", subtitle = options.subtitle,
            badge = options.badge, window = self, sections = {}, _order = 0}, Tab)
        local scroll = Util.Create("ScrollingFrame", {Name = "TabContent_" .. (#self._tabs + 1), BackgroundTransparency = 1,
            BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = C.white,
            ScrollBarImageTransparency = 0.65, Visible = false, Parent = tabHost})
        Util.Padding(scroll, self._mobile and 12 or 20, 12)
        tab._list = Util.Create("UIListLayout", {Name = "SynUIList", Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll})
        Util.AutoScroll(scroll)
        tab.frame, tab.content = scroll, scroll
        local heading = Util.Create("Frame", {Name = "PageHeading", BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, tab.subtitle and 102 or 80), LayoutOrder = -100, Parent = scroll})
        tab._heading = heading
        tab._eyebrow = text(heading, {Text = "WORKSPACE", TextSize = 10, TextTransparency = 0.45, Size = UDim2.new(1, 0, 0, 14)})
        tab._pageTitle = text(heading, {Text = tab.name, Font = F.bold, TextSize = 26, Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 32)})
        if tab.subtitle then tab._description = text(heading, {Text = tab.subtitle, TextSize = 12, TextTransparency = 0.3,
            Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 17), TextTruncate = Enum.TextTruncate.AtEnd}) end
        tab._summary = text(heading, {Text = "0 controls  ·  0 sections", TextSize = 11, TextTransparency = 0.45,
            Position = UDim2.fromOffset(0, tab.subtitle and 81 or 58), Size = UDim2.new(1, 0, 0, 17)})
        updateHeading(tab)
        self._tabs[#self._tabs + 1] = tab
        tab.button, tab._paint = navButton(tab, #self._tabs, false)
        tab.mobileButton, tab._paintMobile = navButton(tab, #self._tabs, true)
        if not self._activeTab then selectTab(tab) end
        return tab
    end
    function Tab:Select() window:SelectTab(self) end
    function window:SelectTab(tab)
        if type(tab) == "number" then tab = self._tabs[tab]
        elseif type(tab) == "string" then
            for _, candidate in ipairs(self._tabs) do if candidate.name == tab then tab = candidate; break end end
        end
        selectTab(tab)
    end
    function window:Search(query)
        if self._destroyed or query == nil or tostring(query) == "" then return false end
        local needle = string.lower(tostring(query))
        for _, tab in ipairs(self._tabs) do
            if string.find(string.lower(tab.name .. " " .. (tab.subtitle or "")), needle, 1, true) then selectTab(tab); return tab end
        end
        return false
    end
    function window:Filter(query) search.Text = tostring(query or ""); self:_refreshSearch() end
    function window:_toggleSearch() pcall(function() search:CaptureFocus() end) end
    function window:GetActiveTab() return self._activeTab end
    function window:IsMobile() return self._mobile end
    function window:GetSize() return Vector2.new(targetW, targetH) end
    function window:SetSize(width, height)
        if self._destroyed then return self end
        if type(width) == "table" or (type(typeof) == "function" and typeof(width) == "Vector2") then height, width = width.Y, width.X end
        preferred = Vector2.new(Util.Clamp(tonumber(width) or preferred.X, 280, 1600), Util.Clamp(tonumber(height) or preferred.Y, 240, 1200))
        explicitSize, self._maximized = true, false
        applyLayout()
        return self
    end
    function window:ResetSize()
        preferred, explicitSize, self._maximized = Vector2.new(780, 580), false, false
        applyLayout()
        return self
    end
    function window:Maximize(value)
        if self._destroyed then return self end
        if not self._visible then self:SetVisible(true) end
        local nextValue = value == nil and not self._maximized or value == true
        if self._maximized == nextValue then return self end
        if nextValue then
            savedGeometry = {width = targetW, height = targetH, x = targetX, y = targetY, viewport = lastViewport}
            self._maximized = true
            applyLayout()
        else self._maximized = false; applyLayout(savedGeometry); savedGeometry = nil end
        return self
    end
    function window:SetVisible(show)
        if self._destroyed then return end
        self._visible, self._minimized = show == true, false
        frame.Visible = self._visible
        if launcher then launcher.Visible = not self._visible end
        if self._visible then applyLayout(); showReveal() else stopReveal() end
        syncShadow()
    end
    function window:Toggle() self:SetVisible(not self._visible) end
    function window:_toggleMinimize() self:SetVisible(false); self._minimized = true end
    function window:_closePressed() Util.SafeCallback(onCloseCallback); self:SetVisible(false) end
    function window:OnClose(callback) onCloseCallback = callback; return self end
    function window:SetTitle(value, sub)
        if value ~= nil then title.Text = tostring(value) end
        if sub ~= nil then subtitle.Text = tostring(sub) end
    end
    function window:SetStatus(value, tone)
        status.Text = tostring(value or "")
        status.TextTransparency = tone == "off" and 0.5 or 0.2
        self._status, self._statusTone = status.Text, tone or "ok"
    end
    function window:Notify(options) if not self._destroyed then return Feedback.Notify(self, options) end end
    function window:Dialog(options) if not self._destroyed then return Feedback.Dialog(self, options) end end
    function window:Destroy()
        if self._destroyed then return end
        self._destroyed, self._visible = true, false
        stopReveal()
        Feedback.Destroy(self)
        for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
        for _, fn in ipairs(cleanups) do pcall(fn) end
        for _, tab in ipairs(self._tabs) do for _, section in ipairs(tab.sections) do section:Destroy() end end
        screen:Destroy()
        self._activeTab = nil
    end

    local resize = Util.Create("TextButton", {Name = "ResizeHandle", Text = "", BackgroundTransparency = 1,
        AutoButtonColor = false, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(24, 24), ZIndex = 20, Parent = frame})
    local resizeIcon = draw(resize, "chevron-right", 12)
    resizeIcon.Rotation = 45
    local resizing
    connect(resize.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        stopReveal()
        resizing = {input = input, x = input.Position.X, y = input.Position.Y, width = targetW, height = targetH,
            left = targetX - targetW / 2, top = targetY - targetH / 2}
    end)
    connect(CoreUIS and CoreUIS.InputChanged, function(input)
        if not resizing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= resizing.input then return end
        local vp = availableViewport()
        local width = Util.Clamp(resizing.width + input.Position.X - resizing.x, 280, math.max(280, vp.X - resizing.left - 8))
        local height = Util.Clamp(resizing.height + input.Position.Y - resizing.y, 240, math.max(240, vp.Y - resizing.top - 8))
        preferred, explicitSize, window._maximized = Vector2.new(width, height), true, false
        targetX, targetY = resizing.left + width / 2, resizing.top + height / 2
        applyLayout()
    end)
    connect(CoreUIS and CoreUIS.InputEnded, function(input)
        if resizing and (input == resizing.input or input.UserInputType == Enum.UserInputType.MouseButton1) then resizing = nil end
    end)
    cleanup(Util.MakeDraggable(frame, dragHandle, screen))
    connect(dragHandle.InputBegan, stopReveal)
    connect(dragHandle.InputEnded, function()
        local origin = screen.AbsolutePosition
        targetX = frame.AbsolutePosition.X - origin.X + targetW / 2
        targetY = frame.AbsolutePosition.Y - origin.Y + targetH / 2
    end)
    cleanup(Util.OnViewportChanged(screen, function() applyLayout() end))
    if CoreUIS then
        pcall(function() connect(CoreUIS:GetPropertyChangedSignal("OnScreenKeyboardVisible"), function() applyLayout() end) end)
        pcall(function() connect(CoreUIS:GetPropertyChangedSignal("OnScreenKeyboardSize"), function() applyLayout() end) end)
        connect(CoreUIS.InputBegan, function(input, processed)
            local toggleKey = cfg.toggleKey == nil and Enum.KeyCode.RightShift or cfg.toggleKey
            if not processed and toggleKey and input.KeyCode == toggleKey then window:Toggle() end
        end)
    end
    applyLayout()
    resize.Size = UDim2.fromOffset(CoreUIS and CoreUIS.TouchEnabled and 44 or 24, CoreUIS and CoreUIS.TouchEnabled and 44 or 24)
    window:SetVisible(cfg.visible ~= false)
    return window
end


--[[
    SYNUI 1.5.0
    A single-file, dependency-free monochrome interface library for Roblox.
    Embedded SVG path icons, desktop + mobile, keyboard + touch.

    Built by boswashere. MIT licensed.
]]

local SynUI = {
    _VERSION = "1.5.0",
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
