# Nemesis API

Nemesis is a Roblox executor UI library (black + violet, shadcn style). Function names match
Obsidian/Linoria, so most Obsidian scripts work unchanged. This file is the full public API.

## Rules that hold everywhere

- Every element is created with `Groupbox:AddX(Idx, Info)`. `Idx` is a unique string id; `Info` is a table.
- Toggles and checkboxes are stored in `Toggles[Idx]`; everything else in `Options[Idx]`.
  Both are globals (`getgenv()`) and also `Library.Toggles` / `Library.Options`.
- Every stateful element has `.Value`, `:SetValue(v)`, `:OnChanged(fn)`, `:SetText(s)`,
  `:SetDisabled(b)`, `:SetVisible(b)`. `Info.Callback(value)` runs on every change.
- Common `Info` fields: `Text`, `Default`, `Callback`, `Tooltip`, `Disabled`, `Visible`, `Risky` (red text).
- Colours can be passed as theme keys (`"Primary"`, `"Card"`...) anywhere the library takes a colour.
- Callbacks never crash the UI: errors are caught and printed with `warn`.

## Quick start

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Zinvera/Nemesis-UI/main/Nemesis.lua"))()
local Toggles, Options = Library.Toggles, Library.Options

local Window = Library:CreateWindow({ Title = "Nemesis", Footer = "v1.0" })
local Tab = Window:AddTab("Combat", "crosshair")
local Box = Tab:AddLeftGroupbox("Aimbot", "target")

Box:AddToggle("AimOn", { Text = "Enabled", Default = false })
    :AddKeyPicker("AimKey", { Default = "MB2", Mode = "Hold", SyncToggleState = true })
Box:AddSlider("Fov", { Text = "FOV", Min = 0, Max = 360, Default = 90, Suffix = "°" })

Toggles.AimOn:OnChanged(function(On) print(On) end)
print(Options.Fov.Value)
```

## Library

| Call | What it does |
|---|---|
| `Library:CreateWindow(Info)` | Builds the window. Returns `Window`. |
| `Library:Toggle(bool?)` | Show / hide the menu. |
| `Library:Unload()` / `Library:OnUnload(fn)` | Destroy everything / run fn on unload. |
| `Library:Notify(Text, Time?)` or `Library:Notify(Info)` | Toast. See Notifications. |
| `Library:SetNotifySide(Side)` | `"TopLeft"`, `"TopRight"`, `"BottomLeft"`, `"BottomRight"`. |
| `Library:SetTheme(NameOrTable)` | `"Void"`, `"Midnight"`, `"Rose"`, `"Emerald"`, `"Amber"`, `"Mono"`, or `{ Primary = Color3 }`. |
| `Library:SetColor(Key, Color3)` | Change one theme colour live. Keys below. |
| `Library:SetFont(Family)` | Font family path, `Font`, or `Enum.Font`. Live. |
| `Library:SetScale(n)` | UI scale (desktop default 1, mobile auto-fits). |
| `Library:SetStreamerMode(bool)` | Hide your avatar + name in the menu. |
| `Library:SetKeybindListVisible(bool)` | Floating list of keybinds and their state. |
| `Library:SetWatermark(Text)` / `Library:SetWatermarkVisibility(bool)` | Draggable watermark label. |
| `Library:AddDraggableLabel(Text, Icon?)` | Floating draggable label. Methods: `SetText`, `SetIcon`, `SetVisible`, `Destroy`. |
| `Library:AddDraggableButton(Text, fn)` | Floating draggable button. Methods: `SetText`, `SetVisible`, `Destroy`. |
| `Library:CreateLoading(Info)` | Loading screen. See Loading. |
| `Library:GetFlags()` | `{ [Idx] = value }` for every saveable element. |
| `Library:SetFlags(Flags)` | Apply a table shaped like `GetFlags()`. |
| `Library:Describe()` | Whole menu as plain data: tabs → groupboxes → elements (Idx, Type, Text, Value). |
| `Library:UpdateDependencyBoxes()` | Re-check all dependency boxes (automatic on changes). |
| `Library:AddTooltip(Text, nil, GuiObject)` | Tooltip on any GuiObject. |
| `Library:GetIcon(Name)` / `Library:SetIconModule(m)` | Lucide icon lookup / swap icon provider. |
| `Library.ToggleKeybind` | `Enum.KeyCode` or a KeyPicker (e.g. `Options.MenuKeybind`). |
| `Library.ForceCheckbox` | `true` makes every toggle render as a checkbox. |
| `Library.IsMobile` | Detected automatically. Preview on PC: `getgenv().NemesisForceMobile = true` before loading. |

Theme keys: `Background`, `Card`, `Muted`, `Hover`, `Border`, `Input`, `Foreground`, `MutedForeground`,
`Subtle`, `Primary`, `PrimaryHover`, `PrimaryForeground`, `Destructive`, `DestructiveBg`,
`DestructiveHover`, `DestructiveForeground`.

## Window

`Library:CreateWindow(Info)`

| Info field | Default | Notes |
|---|---|---|
| `Title` | `"Nemesis"` | Big wordmark top-left with the violet wave. |
| `Footer` | `""` | Line under the title until the game name loads. |
| `ShowGame` | `true` | Show `Playing: <game name>` under the title. |
| `Size` | `UDim2.fromOffset(800, 520)` | Desktop only. |
| `MobileSize` | `UDim2.fromOffset(660, 390)` | Mobile (scaled to fit). |
| `SidebarWidth` | `210` (mobile 168) | |
| `ToggleKeybind` | `Enum.KeyCode.RightControl` | |
| `AutoShow` | `true` | |
| `Resizable` | `true` | Desktop resize grip. |
| `ShowUser` | `true` | Avatar card bottom-left. |
| `StreamerMode` | `false` | |
| `ShowMobileButton` | `true` | Floating "Nemesis" pill on mobile (tap = open/close, drag = move). |
| `WaveSpeed` | `2.6` | Seconds per wave sweep on the title. |
| `Scale` | `1` | Desktop UI scale. |
| `ForceCheckbox` | `false` | |

Window methods:

| Call | Returns |
|---|---|
| `Window:AddTab(Name, Icon?, Description?)` or `Window:AddTab({ Name, Icon, Description, Tooltip, Order, SubTabs })` | `Tab` |
| `Window:AddKeyTab(Name, Icon?, Description?)` | `Tab` (key system, see below) |
| `Window:AddCustomTab(Name, Icon?)` | `Container, Tab` (empty Frame for your own UI) |
| `Window:AddDialog(Idx, Info)` | `Dialog` |
| `Window:SetTitle(s)` / `Window:SetFooter(s)` / `Window:Center()` / `Window:Toggle(b?)` | |

## Tabs

| Call | Notes |
|---|---|
| `Tab:AddLeftGroupbox(Name, Icon?)` / `Tab:AddRightGroupbox(Name, Icon?)` | Returns `Groupbox`. |
| `Tab:AddLeftTabbox()` / `Tab:AddRightTabbox()` | Returns `Tabbox`; `Tabbox:AddTab(Name)` returns a `Groupbox`. |
| `Tab:AddSubTab(Name)` | Only on tabs made with `{ SubTabs = true }`. Returns a tab with the same groupbox methods. |
| `Tab:Show()`, `Tab:SetVisible(b)`, `Tab:SetOrder(n)`, `Tab:SetName(s)`, `Tab:SetTooltip(s)`, `Tab:Destroy()` | |

Every tab is also stored at `Library.Tabs[Name]` (sub tabs at `Library.Tabs["Parent/Sub"]`).

Key system tab:

```lua
local KeyTab = Window:AddKeyTab("Key", "key-round", "Get a key from our Discord.")
for _, T in pairs(Library.Tabs) do if T ~= KeyTab then T:SetVisible(false) end end
KeyTab:AddKeyBox(function(Key)
    if Key == "secret" then
        for _, T in pairs(Library.Tabs) do T:SetVisible(true) end
        KeyTab:SetVisible(false)
    else
        Library:Notify("Wrong key", 3)
    end
end)
```

## Groupbox elements

All are `Groupbox:AddX(Idx, Info)` and return the element. `Idx` may be `nil` for elements you never read.

| Element | Info fields (besides the common ones) | Extra methods |
|---|---|---|
| `AddToggle` | `Default` (bool) | `AddKeyPicker`, `AddColorPicker`, `AddSettings` |
| `AddCheckbox` | `Default` (bool) | same as toggle |
| `AddSlider` | `Min`, `Max`, `Default`, `Rounding` (decimals), `Prefix`, `Suffix` | `SetMin`, `SetMax`, `SetPrefix`, `SetSuffix` |
| `AddInput` | `Default`, `Placeholder`, `Numeric`, `Finished` (fire on Enter only), `MaxLength`, `ClearTextOnFocus` | |
| `AddDropdown` | `Values`, `Default` (value, index, or list for Multi), `Multi`, `AllowNull`, `Searchable`, `Placeholder`, `SpecialType` (`"Player"`/`"Team"`), `ExcludeLocalPlayer`, `DisabledValues` | `SetValues`, `AddValues`, `SetDisabledValues`, `GetActiveValues`, `Open`, `Close` |
| `AddButton` | `Text`, `Func`, `Icon`, `Variant` (`"Primary"`, `"Secondary"`, `"Outline"`, `"Ghost"`, `"Destructive"`), `DoubleClick` | `Button:AddButton(...)` puts another button beside it |
| `AddLabel(Text, Wrap?)` or `AddLabel(Idx, { Text, DoesWrap })` | | `SetText`, `AddKeyPicker`, `AddColorPicker`, `AddSettings` |
| `AddDivider(Text?)` | | |
| `AddImage` | `Image` (asset id, URL or Lucide name), `Height`, `Color`, `Transparency`, `ScaleType` | `SetImage`, `SetColor`, `SetHeight`, ... |
| `AddVideo` | `Video`, `Looped`, `Playing`, `Volume`, `Height` | `Play`, `Pause`, `SetVideo`, ... |
| `AddViewport` | `Object` (Model/BasePart), `Clone` (true), `AutoFocus` (true), `Interactive`, `Height` | `SetObject`, `Focus`, `Rotate`, `Zoom`, `SetDistance`, `LookAt`, ... |
| `AddUIPassthrough` | `Instance` (your GuiObject), `Height` | `SetInstance`, `SetHeight` |
| `AddDependencyBox()` | | See Dependencies |
| `AddDependencyGroupbox(Name?, Icon?)` | | See Dependencies |

Value types: Toggle → `bool`; Slider → `number`; Input → `string`; Dropdown → value or `nil`
(Multi: `{ [value] = true }`, use `:GetActiveValues()` for a list); ColorPicker → `Color3`;
KeyPicker → key name string (`"MB2"`, `"F"`, `"LeftShift"`, `"None"`).

## Addons (on toggles and labels)

```lua
Box:AddToggle("Fly", { Text = "Fly" })
    :AddKeyPicker("FlyKey", { Default = "F", Mode = "Toggle", SyncToggleState = true })
    :AddColorPicker("FlyColor", { Default = Color3.new(1, 0, 0) })
```

- `AddKeyPicker(Idx, Info)`: `Default`, `Mode` (`"Toggle"`, `"Hold"`, `"Always"`, `"Press"`), `Text`,
  `SyncToggleState` (key flips the toggle), `NoUI` (hide from keybind list), `Callback(state)`,
  `ChangedCallback(newKey)`. Methods: `GetState()`, `SetValue({ Key, Mode })`, `OnClick(fn)`,
  `SetMenuVisibility(b)`. Click the chip to rebind (Esc cancels, Backspace clears); right click picks
  the mode. On mobile, tapping the chip presses the key.
- `AddColorPicker(Idx, Info)`: `Default` (Color3), `Title`, `Callback(color)`. Methods: `SetValueRGB(c)`, `SetValue({h,s,v})`.
- `AddSettings(Info?)`: a gear that opens a small panel. The panel has every groupbox method:
  `local S = Toggles.Esp:AddSettings(); S:AddSlider("EspRange", {...})`.

## Dependencies

```lua
local Extra = Box:AddDependencyBox()           -- inline, inside this groupbox
Extra:AddSlider("RandomChance", { Text = "Head chance", Min = 0, Max = 100 })
Extra:SetupDependencies({
    { Toggles.AimOn, true },                    -- toggle must be on
    { Options.AimPart, "Random" },              -- dropdown must equal (multi: must contain)
    { Options.Fov, function(v) return v > 90 end }, -- any element, custom test
})

local Card = Box:AddDependencyGroupbox("Advanced", "sliders")  -- separate card under this one
```

All entries must pass. A disabled element counts as failing. Boxes nest.

## Dialogs

```lua
Window:AddDialog("ConfirmUnload", {
    Title = "Unload Nemesis?", Description = "Everything turns off.", Icon = "power",
    OutsideClickDismiss = true, AutoDismiss = true,
    FooterButtons = {
        Cancel = { Title = "Cancel", Variant = "Secondary", Order = 1 },
        Unload = { Title = "Unload", Variant = "Destructive", Order = 2, WaitTime = 2,
                   Callback = function(Dialog) Library:Unload() end },
    },
})
```

A dialog is also a groupbox (`Dialog:AddInput(...)`). Methods: `SetTitle`, `SetDescription`,
`AddFooterButton(Id, Info)`, `RemoveFooterButton(Id)`, `SetButtonDisabled(Id, b)`, `SetButtonOrder(Id, n)`,
`Dismiss()`. Escape closes it.

## Notifications

`Library:Notify({ Title, Description, Time = 4, Icon, IconColor, TitleColor, DescriptionColor, Steps, Persist, Closable, SoundId, Volume, Callback })`

- `Time`: seconds, `0` = stay, or an Instance (closes when it is destroyed).
- `Steps = n` shows a progress bar you drive with `:ChangeStep(i)`.
- `Callback(Reason)`: `"timer"`, `"user"` or `"script"`.
- Returns an object with `:ChangeTitle`, `:ChangeDescription`, `:ChangeStep`, `:Destroy`.

## Loading screen

```lua
local Loading = Library:CreateLoading({ Title = "Nemesis", TotalSteps = 3 })
Loading:SetMessage("Fetching modules"); Loading:SetCurrentStep(1)
-- on failure:
Loading:ShowErrorPage(true)
Loading:SetErrorMessage("Could not reach the server.")
Loading:SetErrorButtons({ Retry = { Title = "Retry", Variant = "Primary", Callback = function(L) end } })
Loading:Destroy()  -- shows the menu
```

Other methods: `SetDescription`, `SetTotalSteps`, `SetLoadingIcon`, `SetLoadingIconColor`,
`SetLoadingIconTweenTime`, `SetWindowWidth`.

## Configs (SaveManager)

Built in as `Library.SaveManager`; same calls as Obsidian's addon.

```lua
local SaveManager = Library.SaveManager
SaveManager:SetFolder("Nemesis")
SaveManager:SetSubFolder(tostring(game.PlaceId)) -- optional: configs per game
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(Tabs.Settings)    -- ready-made "Configuration" groupbox
SaveManager:LoadAutoloadConfig()
```

Direct use: `Save(name)`, `Load(name)`, `Delete(name)` all return `ok, err`.
`RefreshConfigList()` → list of names. `GetAutoloadConfig()`, `SaveAutoloadConfig(name)`,
`DeleteAutoLoadConfig()`. Files: `<Folder>/configs[/<SubFolder>]/<name>.json`, shaped
`{ "Version": 1, "Flags": { "<Idx>": value } }`. Obsidian/Linoria config files load too.

## Themes (ThemeManager)

Built in as `Library.ThemeManager`.

```lua
Library.ThemeManager:SetFolder("Nemesis")
Library.ThemeManager:ApplyToTab(Tabs.Settings)  -- presets, colour pickers, font, custom themes
```

Direct use: `ApplyTheme(nameOrTable)`, `SaveCustomTheme(name)`, `GetCustomThemes()`,
`SaveDefault(name)`, `LoadDefault()`, `GetCurrentTheme()`. Add a preset with
`Library.Themes.MyTheme = { Primary = Color3.fromRGB(...) }`.

## Driving the menu from code (for agents)

```lua
local Tree = Library:Describe()        -- what exists
local Flags = Library:GetFlags()       -- current values
Library:SetFlags({ AimOn = true, Fov = 120, AimPart = "Torso" })
```
