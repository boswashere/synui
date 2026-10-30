# SYNUI

A single-file, dependency-free, monochrome Roblox UI library with embedded vector icons, built for executor loadstrings on desktop and mobile.

SYNUI uses a settings-panel layout: labeled navigation, a pinned profile, an inset workspace and controls beside their labels. The window is draggable and resizable. Search filters the current page, and a small launcher restores the window after you hide it. The library stays in one Lua file with no external images or runtime downloads.

## One-line demo

Run this and nothing else. It contains the library and the demo in one file, so it does not use a second `loadstring`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/boswashere/synui/refs/heads/main/demo.lua"))()
```

If GitHub raw is blocked, use the CDN copy:

```lua
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/boswashere/synui@main/demo.lua"))()
```

For the library on its own:

```lua
local SynUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/boswashere/synui/refs/heads/main/synui.lua"))()
```

---

## Features

- **One file.** The whole library is `synui.lua`; no packages, asset IDs, or image uploads.
- **Black and white.** Every default color is `#000000` or `#FFFFFF`. Text and border opacity provide hierarchy; surfaces stay black.
- **Desktop and mobile.** Labeled sidebar on roomy windows; horizontal tabs on narrow or short windows. Touch actions have 44 px hit targets.
- **Embedded icons.** 31 Lucide-style icons defined as 24×24 SVG path data and drawn as crisp vector Frames.
- **Keyboard aware.** Global toggle key, Escape-to-cancel keybind capture, and dialogs that close on Escape.
- **Predictable callbacks.** Every user callback goes through one protected callback path.
- **Clean teardown.** `window:Destroy()` disconnects connections and removes the `ScreenGui`.

---

## Install

Use the hosted file when `game:HttpGet` and `loadstring` are available:

```lua
local SynUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/boswashere/synui/refs/heads/main/synui.lua"))()
```

The URL above is the published location for this repository's `synui.lua`. The chunk returns the library table directly, so the trailing `()` is all you need. Load it once and reuse the table.

That line returns the library table. Use the one-line demo at the top to open a complete window, or call `CreateWindow` as shown below to build your own.

SYNUI is executor-friendly:

- It uses `gethui()` only when it returns a renderable `PlayerGui` or `CoreGui`; otherwise it falls back to `PlayerGui`. You can pass `parent` to choose the container yourself.
- It calls `syn.protect_gui` or `protect_gui` if the executor exposes one.
- It uses Roblox's native `task` scheduler, with a `spawn` / `delay` fallback when `task` is unavailable.
- Each `CreateWindow` call creates a separate GUI. Keep the returned window to update or destroy it.

If the demo hits a startup error, it prints the error and shows it in an on-screen panel when `PlayerGui` is available. Download or compilation failures happen before that panel can run.

---

## Quick start

```lua
local SynUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/boswashere/synui/refs/heads/main/synui.lua"))()

local window = SynUI:CreateWindow({
    title = "VIBECODE",
    subtitle = "CONTROL PANEL",
    icon = "grid",
    -- Default size is 780 × 580, adjusted to fit the available screen.
    toggleKey = Enum.KeyCode.RightShift,
    parent = nil,            -- nil = renderable gethui() root, else PlayerGui
    launcher = true,         -- floating reopen button
    footer = "Example workspace", -- context under the sidebar profile
})

local tab = window:Tab({ name = "Overview", icon = "grid", subtitle = "Live session" })
local section = tab:Section({ title = "Session", subtitle = "Runtime controls", icon = "bolt" })

section:Button({
    text = "Execute",
    description = "Run the current build",
    icon = "play",
    actionText = "Run",
    variant = "primary",
    callback = function() end,
})

section:Toggle({
    text = "Enabled",
    description = "Master switch",
    value = true,
    callback = function(v) end,
})

section:Slider({
    text = "Volume",
    min = 0,
    max = 100,
    value = 50,
    step = 1,
    suffix = "%",
    callback = function(v) end,
})

section:Dropdown({
    text = "Mode",
    options = { "Balanced", "Aggressive", "Silent" },
    value = "Balanced",
    callback = function(v) end,
})

section:Input({
    text = "Webhook",
    placeholder = "https://...",
    callback = function(v) end,
})

section:Keybind({
    text = "Toggle menu",
    value = Enum.KeyCode.RightShift,
    callback = function(k) end,
})

section:Progress({ text = "Loading", value = 0.64 })
section:Label({ text = "Monochrome by design." })

window:Notify({ title = "Connected", text = "Session is live.", icon = "check", duration = 4 })
window:Dialog({
    title = "Confirm",
    text = "Run this action?",
    confirmText = "Run",
    callback = function(ok) end,
})

window:SetStatus("SYNCED", "ok")
```

---

## Example

[`demo.lua`](demo.lua) is the self-contained demo used by the one-line loader above. It opens a responsive window with four tabs of working controls. There is no second download or nested `loadstring`.

[`example.lua`](example.lua) is the readable source for that demo. The comments explain each block. Copy it, run it, then change the pieces you need. It downloads the library itself, so it needs `loadstring` and `game:HttpGet` to work.

---

## API reference

### Window

```lua
local window = SynUI:CreateWindow({
    title = "VIBECODE",
    subtitle = "CONTROL PANEL",
    icon = "grid",
    -- size = UDim2.fromOffset(900, 600), -- optional preferred size
    toggleKey = Enum.KeyCode.RightShift,
    parent = nil,
    launcher = true,
    footer = "Example workspace",
    reducedMotion = false,
})
```

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `title` | string | `"SYNUI"` | Header title. |
| `subtitle` | string | `"Interface library"` | Smaller line under the window title. |
| `icon` | string | `"grid"` | Icon name from the icon set. |
| `size` | `UDim2` | `780 × 580` | Preferred size in native GUI coordinates, clamped to the available screen. |
| `toggleKey` | `Enum.KeyCode` or `false` | `RightShift` | Global show/hide key; `false` disables it. |
| `parent` | `Instance?` | `nil` | `nil` resolves to a renderable `gethui()` root when available, otherwise `PlayerGui`. |
| `launcher` | boolean | `true` | Show a floating reopen button while the window is hidden. |
| `footer` | string | `"Roblox client"` | Context line below the sidebar profile. |
| `reducedMotion` | boolean | `false` | Skip window, notification and dialog fades. |

Window methods:

| Method | Description |
| --- | --- |
| `window:Tab(cfg)` | Create a tab. The first tab is selected automatically. |
| `window:SelectTab(tab)` | Select a tab object, index or exact name. |
| `window:Search(query)` | Case-insensitively find a tab by name or subtitle, select it, and return the tab; returns `false` for no match. |
| `window:Filter(query)` | Filter the active page's control labels, descriptions and section headings. Pass `""` to clear. |
| `window:Maximize([bool])` | Toggle maximize/restore, or set the state explicitly. |
| `window:SetSize(width, height)` | Set a preferred size; also accepts a `Vector2`. Bounds are 280–1600 wide and 240–1200 high, further clamped to the screen. |
| `window:GetSize()` | Return the currently fitted size as a `Vector2`. |
| `window:ResetSize()` | Return to the responsive 780 × 580 default. |
| `window:SetTitle(title[, subtitle])` | Change the window heading. |
| `window:GetActiveTab()` | Return the selected tab. |
| `window:IsMobile()` | Return whether the window currently uses the compact layout. |
| `window:SetStatus(text, tone)` | Update the footer status. `tone` is `"ok"`, `"warn"`, or `"off"`; all are monochrome. |
| `window:SetVisible(bool)` | Show or hide the window. The launcher appears while hidden. |
| `window:Toggle()` | Flip the current visibility. |
| `window:OnClose(callback)` | Register a callback for the header close action. |
| `window:Notify(cfg)` | Show a notification. |
| `window:Dialog(cfg)` | Open a modal confirmation dialog. |
| `window:Destroy()` | Disconnect everything and destroy the `ScreenGui`. |

Drag the header to move the window or the bottom-right handle to resize it. Closing and minimizing both hide the window; the launcher restores it. The square button maximizes/restores on the roomy layout. Resizing and rotation keep your preferred dimensions so the window can return to them when there is enough space.

The visible search field filters controls on the active tab as you type. Filtering keeps the same controls, values and callbacks. A query with no matches shows an empty state; clearing it restores the page. `window:Search()` remains a separate API for selecting tabs.

The sidebar profile uses your display name, username and a monochrome initial. The footer shows the library version and a status you can update with `SetStatus`. `Destroy` removes the window, pending input captures and dialogs without firing their callbacks.

### Tab

```lua
local tab = window:Tab({
    name = "Overview",
    icon = "grid",
    subtitle = "Live session",
})
```

Tab methods:

| Method | Description |
| --- | --- |
| `tab:Section(cfg)` | Create a section card. |
| `tab:Columns()` | Create a responsive pair of containers and return `left, right`. |
| `tab:Label(cfg)` | Add a small wrapped label. |
| `tab:Paragraph(cfg)` | Add a wrapped paragraph. |
| `tab:Divider()` | Add a 1 px separator with vertical padding. |
| `tab:Card(cfg)` | Add a standalone card with icon, title, body, and optional action. |
| `tab:Spacer(px)` | Add vertical space. |

A tab object exposes `name`, `icon`, `content`, `button`, and `sections`. Content is a `ScrollingFrame`; custom UI can be parented under it.

For a dashboard-style layout, `tab:Columns()` returns `left, right` content containers. Each container supports `Section`, `Card`, `Label`, `Paragraph`, `Divider`, and `Spacer`. The columns share a row when there is room and stack on portrait or in a narrow custom window; the same sections and control state are retained during rotation.

```lua
local left, right = tab:Columns()
local settings = left:Section({ title = "Settings" })
settings:Toggle({ text = "Enabled", value = true })
right:Section({ title = "Session" }):Button({
    text = "Show status",
    callback = function() window:Notify({ title = "Ready" }) end,
})
```

### Section

```lua
local section = tab:Section({
    title = "Session",
    subtitle = "Runtime controls",
    icon = "bolt",
    badge = "LIVE",       -- optional
})
```

A section has a heading above an auto-sizing, outlined group of settings rows. Descriptions wrap, and actions or value fields sit to the right when they fit. Narrow fields stack below their labels without losing their values. It exposes:

- `section.frame` — the card `Frame`.
- `section.content` — the content `Frame`.
- `section:AddRow(row)` — append a control row.
- `section:AddBlock(block)` — append a block such as an expanded dropdown list.
- `section:Refresh()` — re-run divider visibility and sizing.
- Control constructors: `Button`, `Toggle`, `Slider`, `Dropdown`, `Input`, `Keybind`, `Progress`, `Label`.

Control rows are separated by a hairline divider; the last divider is hidden automatically.

### Controls

#### Button

```lua
local button = section:Button({
    text = "Execute",
    description = "Run the current build",
    icon = "play",
    actionText = "Run",    -- text on the right-side button; defaults to "Run"
    variant = "primary",   -- black text on a white surface
    callback = function() end,
})
```

- `button:SetText(text)`
- `button:SetEnabled(bool)`
- `button:GetEnabled()`

`text` is the setting label. `actionText` is the text inside the action button. `SetText` changes the setting label and its search entry.

#### Toggle

```lua
local toggle = section:Toggle({
    text = "Enabled",
    description = "Master switch",
    value = true,
    callback = function(v) end,   -- boolean
})
```

- `toggle:Set(value[, silent])`
- `toggle:Get()`

Pass `silent = true` to update the visual state without invoking the callback.

#### Slider

```lua
local slider = section:Slider({
    text = "Volume",
    min = 0,
    max = 100,
    value = 50,
    step = 1,
    suffix = "%",
    callback = function(v) end,
})
```

Drag with mouse or touch, or click the track to seek. Values snap to `step`.

- `slider:Set(value[, silent])`
- `slider:Get()`

#### Dropdown

```lua
local dropdown = section:Dropdown({
    text = "Mode",
    options = { "Balanced", "Aggressive", "Silent" },
    value = "Balanced",
    callback = function(v) end,
})

local multi = section:Dropdown({
    text = "Channels",
    options = { "Alpha", "Beta", "Gamma" },
    value = { "Alpha" },
    multi = true,
    callback = function(values) end,   -- array of selected strings
})
```

- `dropdown:Set(value[, silent])`
- `dropdown:Get()`
- `dropdown:Refresh(options)`
- `dropdown:Open()`
- `dropdown:Close()`

Single dropdowns return a string. Multi dropdowns return an array of strings and keep the list open while selecting.

#### Input

```lua
local input = section:Input({
    text = "Webhook",
    placeholder = "https://...",
    callback = function(v) end,
})
```

The callback runs when the field loses focus and when Return is pressed.

- `input:Set(value)`
- `input:Get()`
- `input:Focus()`

#### Keybind

```lua
local keybind = section:Keybind({
    text = "Toggle menu",
    value = Enum.KeyCode.RightShift,
    callback = function(keyCode) end,
})
```

Click the key pill, then press a key. `Escape` cancels capture.

- `keybind:Set(keyCode[, silent])`
- `keybind:Get()`

#### Progress

```lua
local progress = section:Progress({ text = "Loading", value = 0.64 })
progress:Set(0.9)   -- 0..1
```

#### Label and layout helpers

```lua
section:Label({ text = "Monochrome by design." })

tab:Paragraph({ text = "Longer explanatory copy that wraps." })
tab:Divider()
tab:Card({
    icon = "spark",
    title = "Note",
    body = "Cards group secondary information.",
})
tab:Spacer(12)
```

### Notify

```lua
window:Notify({
    title = "Connected",
    text = "Session is live.",
    icon = "check",
    duration = 4,
})
```

Notifications stack in the top-right, fade in at their final position, and drain a 2 px progress line. `duration` is in seconds (default `4`). Up to four are visible; older notifications are closed first.

### Dialog

```lua
window:Dialog({
    title = "Confirm",
    text = "Run this action?",
    confirmText = "Run",
    callback = function(confirmed) end,
})
```

A dimmed overlay with a centered card. Cancel is a secondary button; Confirm is the white primary button. Escape closes the top dialog. The close button or clicking outside also cancels. The callback receives `true` for confirm and `false` for cancel/close, exactly once. Window destruction disposes of dialogs without calling their callbacks.

### Status tones

`window:SetStatus(text, tone)` updates the right side of the footer:

- `"ok"` and `"warn"` use white text at normal status opacity.
- `"off"` uses lower-opacity white text.

---

## Theming

`SynUI.Theme` is a plain table. Change values before creating the window:

```lua
local SynUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/boswashere/synui/refs/heads/main/synui.lua"))()

SynUI.Theme.colors.bg = Color3.fromRGB(0, 0, 0)
SynUI.Theme.colors.text = Color3.fromRGB(255, 255, 255)
SynUI.Theme.radius.lg = 8

local window = SynUI:CreateWindow({ title = "THEMED" })
```

Theme fields:

| Field | Contents |
| --- | --- |
| `colors` | `bg`, `surface`, `raised`, `hover`, `line`, `text`, `muted`, `dim`, `faint`, `field`, `panel`, `white`, `black` |
| `fonts` | `regular`, `medium`, `bold` use BuilderSans with Gotham fallbacks; `mono` uses Code. |
| `radius` | `sm = 6`, `md = 6`, `lg = 8`, `xl = 10` |
| `motion` | `fast = 0.10`, `normal = 0.14`, `slow = 0.16` |
| `stroke` | Default stroke transparency, `0.84` |
| `pad` | Base padding, `16` |

Surface tokens are black. Text, outline and icon tokens are white. Opacity, text weight and spacing provide the hierarchy. The sidebar profile uses an initial so it does not introduce a colored avatar.

---

## Icons

Thirty-one icons are embedded:

```text
grid, home, bolt, settings, user, shield, key, terminal, activity, layers,
code, search, close, minus, chevron-down, chevron-right, check, plus,
arrow-right, copy, trash, moon, sun, menu, lock, cpu, spark, sliders,
play, maximize, dot
```

Use an icon by name anywhere the API accepts `icon`:

```lua
section:Button({ text = "Run", icon = "play", callback = function() end })
```

Or draw one directly:

```lua
local icon = SynUI.DrawIcon(section.content, "bolt", 18, SynUI.Theme.colors.text, 2)
```

`SynUI.DrawIcon` maps to `Icons.Draw(parent, name, size, color, thickness)`:

- `size` defaults to `18`
- `thickness` defaults to `2`
- returns a `Frame`
- unknown names fall back to `dot` instead of throwing

### Why vector Frames instead of SVG files

Roblox does not render SVG images directly, and SYNUI avoids external image assets entirely. Each icon is stored as 24×24 SVG path data (`M/L/H/V/C/Q/Z`, plus circles, rects, lines, polylines, and polygons) and converted to stroke-only Frames with rounded caps. Curves are flattened into short segments. This keeps icons crisp at any size, keeps the library self-contained, and avoids asset uploads or `rbxassetid://` dependencies.

The equivalent inner SVG markup is also available for docs, web previews, or tooling:

```lua
print(SynUI.Icons.SVG["bolt"])
print(SynUI.Icons.defs["bolt"])
```

---

## Responsive behavior

No separate mobile API is required. SYNUI chooses its composition from the fitted window size:

- Windows narrower than 640 px, or shorter than 440 px on touch / 380 px on desktop, use horizontal tabs and hide the sidebar profile.
- The default desktop size is 780 × 580. Touch defaults fit within 90% of the available width and 76% of its height; short landscape screens use more of the height to leave room for controls.
- GUI coordinates stay at 1×. The library does not double-scale high-resolution phone interfaces.
- Page titles scroll with the controls. Short landscape windows use a compact title so the first setting remains visible. The search field stays above the scroll area.
- Touch action targets are at least 44 px high. Inputs and actions stack when their row gets too narrow.
- The GUI safe area and on-screen keyboard constrain the window; the preferred size and control values survive rotation and keyboard changes.
- Scroll areas use a thin 2 px scrollbar and automatic canvas sizing. Optional columns stack when their available width is too small.

Buttons use `Activated`, which Roblox fires for both mouse and touch. Sliders and dragging track pointer input; keybind capture still requires a keyboard.

---

## Performance notes

- No per-frame animation loop. Opening fades at the final size and position; page switching does not zoom or shift the scroll area.
- Input is event-driven; dragging updates only while a pointer is down.
- Sections and content use `AutomaticSize` plus `UIListLayout`, so layout work happens when content changes, not every frame.
- Notifications are capped at four visible cards.
- `Destroy` disconnects connections, clears tweens, and destroys the `ScreenGui`.
- The library does not use `HttpService` at runtime. The install one-liner uses `game:HttpGet` outside the library; the library itself only builds UI.

---

## File layout

The shipped library is one file:

```text
synui.lua
demo.lua      -- self-contained one-line demo (library + example)
example.lua   -- readable demo source, not part of the library
```

Everything — theme, utilities, icons, controls, layout, feedback, and the public API — lives in `synui.lua`. It targets Roblox Luau and also parses as Lua 5.4 for local syntax checks. No external packages, asset IDs, or services are required beyond Roblox itself.

## Verification

Version 1.5.0 is checked with control, startup, layout and demo suites in Lua 5.4 and Luau 0.744 using a mocked Roblox API, plus source-derived previews at desktop, portrait and short-landscape sizes. Those previews approximate fonts and Roblox layout; rendering inside Roblox or Delta has not been verified on a device.

## License

MIT © boswashere
