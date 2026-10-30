# SYNUI

Project UAI UI LIB, built from its original source with black-and-white rendering.

This release uses UI LIB 1.4.0 from [ProjectUAI revision `d5060d3`](https://github.com/Project-Ptolemy/ProjectUAI/tree/d5060d3c4868cf6676ac191a1aa7708b78fa6b6d/ui-lib). Its window layout, fonts, controls, sizing, animations, profile panel, appearance settings and `Project UAI | UI LIB.` footer are retained. The demo is UAI's original **Fieldwork** showcase.

## Run the demo

Paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/boswashere/synui/refs/heads/main/demo.lua"))()
```

`demo.lua` contains the library and showcase in one file. It does not fetch another script after it starts. `example.lua` is the readable showcase source.

## Use the library

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/boswashere/synui/refs/heads/main/synui.lua"))()

local window = UI:CreateWindow({
	Id = "my-workspace",
	Title = "My workspace",
	Subtitle = "Settings for this session",
	Search = true,
})

local tab = window:Tab({ Title = "Settings" })
local section = tab:Section({
	Title = "General",
	Description = "Choose how this workspace behaves.",
})

local enabled = section:Toggle({
	Id = "enabled",
	Text = "Enabled",
	Default = true,
	Callback = function(value)
		print("Enabled:", value)
	end,
})

section:Button({
	Text = "Read current value",
	ActionText = "Read",
	Style = "Primary",
	Callback = function()
		window:Notify({
			Title = "Current value",
			Content = tostring(enabled:Get()),
		})
	end,
})
```

Loading `synui.lua` returns the library. Call `UI:CreateWindow` to show a window, or run the demo above.

### Upgrading from SYNUI 1.x

Version 2 replaces the previous custom SYNUI engine with the actual UAI library. Use UAI's capitalized options and methods, as in the example above. The old lowercase configuration and control API are not a compatibility layer in this release.

`UI.Version` is the upstream version, `1.4.0`. `UI.SynUIVersion` is `2.0.0`, and `UI.UpstreamRevision` identifies the pinned source.

## Black and white

The default dark theme uses black surfaces and white text, strokes and controls. Opacity distinguishes secondary text, borders and interaction states. Light mode reverses the palette.

Rendered color values are black or white, including custom theme colors and color-picker swatches. The color picker still returns and saves the original RGB data; only its display is monochrome. Profile and player-choice images use UAI's existing initials fallback in the same avatar frame.

The original Appearance tab remains available, including text scale, corner radius, reduced motion and theme controls.

## Window options

```lua
local window = UI:CreateWindow({
	Id = "my-workspace",
	Title = "My workspace",
	Subtitle = "Settings for this session",
	Width = 780,
	Height = 580,
	Search = true,
	Theme = "Dark",
	ThemeToggle = true,
	ToggleKey = Enum.KeyCode.RightShift,
	TextScale = 1,
	CornerRadius = 10,
	ReducedMotion = false,
})
```

- `Id` identifies the window. Creating another window with the same ID replaces that window within this library's registry.
- `Width` and `Height` are preferred dimensions. UAI fits the window to the available screen and keyboard space.
- `Search` enables the control search field.
- `Theme` accepts `"Dark"` or `"Light"`. `ThemeToggle` controls the header theme button.
- `ToggleKey = false` disables the keyboard shortcut.
- `TextScale` accepts `0.85` to `1.5`; `CornerRadius` accepts `0` to `16`.
- `Parent`, `DisplayOrder`, `GameName` and `OnDestroy` are also supported by the native UAI API.

The close button destroys the window. Minimize creates UAI's draggable restore pill. The bottom-right handle resizes the window.

```lua
window:Show()
window:Hide()
window:Minimize()
window:Toggle()
window:SetSize(900, 600)
local width, height = window:GetSize()
window:ResetSize()
window:SetTheme("Dark")
window:SetTextScale(1.1)
window:SetReducedMotion(true)
window:Destroy()
```

Size preferences are bounded to `280–1600` by `240–1200`, then fitted to the screen. Hiding the window also hides its restore pill.

## Tabs, sections and controls

```lua
local tab = window:Tab({ Id = "settings", Title = "Settings" })
local section = tab:Section({
	Title = "General",
	Description = "Settings for this session.",
	Collapsible = true,
})
```

Native controls include:

| Control | Common options |
| --- | --- |
| `Button` | `Text`, `Description`, `ActionText`, `Style`, `Callback` |
| `Toggle`, `Checkbox` | `Id`, `Text`, `Default`, `Callback` |
| `Slider` | `Min`, `Max`, `Step`, `Default`, `Suffix`, `OnCommit` |
| `Input` | `Placeholder`, `Default`, `Numeric`, `MultiLine`, `Live`, `MaxLength` |
| `Dropdown` | `Options`, `Default`, `Multi`, `Searchable` |
| `Segmented` | `Options`, `Default` |
| `Keybind` | `Default`, `Mode`, `ActiveWhenHidden`, `Callback` |
| `ColorPicker` | `Default`, `Alpha`, `Callback` |
| `Label`, `Paragraph`, `Divider` | Text and section content |
| `Badge`, `Progress` | Read-only status or progress values |

Value controls expose `Get()`, `Set(value, silent)` and `Reset()`. Use `Set(value, true)` to update without firing the callback. Controls also support visibility, disabled state, text updates and destruction through UAI's native methods.

Dropdown options may be strings or records:

```lua
section:Dropdown({
	Id = "mode",
	Text = "Selection mode",
	Default = "nearest",
	Options = {
		{ Label = "Nearest first", Value = "nearest" },
		{ Label = "All available", Value = "all" },
	},
})
```

See the [pinned UAI API guide](https://github.com/Project-Ptolemy/ProjectUAI/blob/d5060d3c4868cf6676ac191a1aa7708b78fa6b6d/docs/UI_LIBRARY.md) for complete method signatures and control options. The loadstring URL for this monochrome build is the one at the top of this README.

## Feedback and saved values

```lua
window:Notify({
	Title = "Saved",
	Content = "Your settings have been stored.",
	Kind = "Success",
})

window:Confirm({
	Title = "Reset this session?",
	Content = "Return the controls to their defaults.",
	ConfirmText = "Reset",
	Callback = function()
		enabled:Reset()
	end,
})
```

Configuration saving is explicit:

```lua
local json = window:ExportConfig()
local ok, result = window:ImportConfig(json)

-- These two methods use the executor's file functions when available.
local saved, saveResult = window:SaveConfig("default")
local loaded, loadResult = window:LoadConfig("default")
```

Give persistent controls stable IDs. Native UAI config files use `ProjectUAI/UI/`. This library has a separate window registry from the original UAI library, so destroying its windows does not destroy original UAI windows.

## Verification

The shipped bundle passes:

- 158 upstream UAI checks, with only the expected hosting URL changed for this fork.
- 46 differential layout and monochrome checks against the pinned original library.
- 31 showcase, registry-isolation and standalone-loader checks across desktop, portrait and landscape sizes.

These suites run under Lua 5.4 and native Luau 0.744 with mocked Roblox services. The widget-tree comparisons check hierarchy, dimensions, positioning, fonts and control states against UAI. Source-derived previews were also compared side by side. Actual rendering inside Delta or Roblox has not been verified here.

## Files

```text
synui.lua    Library, including the original UAI engine and monochrome adapter
demo.lua     Self-contained original UAI showcase
example.lua  Readable showcase that loads synui.lua
README.md    Usage and attribution
```

## License and attribution

Based on Project UAI UI LIB by CarlDV, pinned at revision `d5060d3c4868cf6676ac191a1aa7708b78fa6b6d`. The original attribution remains in the interface and the bundled source. The monochrome adaptation is distributed under the same MIT license.

```text
MIT License

Copyright (c) 2026 CarlDV

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
