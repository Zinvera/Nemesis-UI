-- Nemesis example: every element and feature.
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Zinvera/Nemesis-UI/main/Nemesis.lua"))()

local Toggles, Options = Library.Toggles, Library.Options

-- Loading screen while the script sets up
local Loading = Library:CreateLoading({ Title = "Nemesis", TotalSteps = 3 })
Loading:SetMessage("Building menu")
Loading:SetCurrentStep(1)

local Window = Library:CreateWindow({
    Title = "Nemesis",
    Footer = "v1.0 · Universal",
    Icon = "skull", -- any Lucide icon name, or an rbxassetid
    ToggleKeybind = Enum.KeyCode.RightControl,
    StreamerMode = true, -- hide avatar + name in the menu by default
})

local Tabs = {
    Combat = Window:AddTab("Combat", "crosshair", "Aim and triggers"),
    Movement = Window:AddTab("Movement", "footprints"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Players = Window:AddTab({ Name = "Players", Icon = "users", SubTabs = true }),
    Settings = Window:AddTab("Settings", "settings"),
}

-- Combat
local Aimbot = Tabs.Combat:AddLeftGroupbox("Aimbot", "target")
Aimbot:AddToggle("AimEnabled", {
    Text = "Enabled",
    Default = true,
    Tooltip = "Lock onto the nearest target",
    Callback = function(Value)
        print("Aimbot:", Value)
    end,
}):AddKeyPicker("AimKey", { Default = "MB2", Mode = "Hold", Text = "Aimbot", SyncToggleState = false })

Aimbot:AddSlider("AimFov", { Text = "Field of view", Default = 120, Min = 10, Max = 360, Suffix = "°" })
Aimbot:AddSlider("AimSmooth", { Text = "Smoothness", Default = 0.35, Min = 0, Max = 1, Rounding = 2 })
Aimbot:AddDropdown("AimPart", { Text = "Target part", Values = { "Head", "Torso", "Closest part", "Random" }, Default = "Head" })
Aimbot:AddDivider()
Aimbot:AddCheckbox("TeamCheck", { Text = "Team check", Default = true })
Aimbot:AddCheckbox("WallCheck", { Text = "Wall check" })

-- Only shown while "Target part" is "Random"
local RandomBox = Aimbot:AddDependencyBox()
RandomBox:AddSlider("RandomChance", { Text = "Head chance", Default = 50, Min = 0, Max = 100, Suffix = "%" })
RandomBox:SetupDependencies({ { Options.AimPart, "Random" } })

local Silent = Tabs.Combat:AddRightGroupbox("Silent aim", "zap")
Silent:AddToggle("SilentEnabled", { Text = "Enabled", Risky = true })
Silent:AddSlider("HitChance", { Text = "Hit chance", Default = 85, Min = 0, Max = 100, Suffix = "%" })
Silent:AddDropdown("SilentTarget", { Text = "Target", Values = { "Closest", "Mouse", "Lowest health" }, Default = 1 })
Silent:AddDropdown("IgnorePlayers", { Text = "Ignore players", SpecialType = "Player", ExcludeLocalPlayer = true, Multi = true, Searchable = true })

local Trigger = Tabs.Combat:AddRightGroupbox("Triggerbot", "mouse-pointer-2")
Trigger:AddToggle("TriggerEnabled", { Text = "Enabled" }):AddKeyPicker("TriggerKey", { Default = "T", Mode = "Toggle", SyncToggleState = true })
Trigger:AddSlider("TriggerDelay", { Text = "Delay", Default = 80, Min = 0, Max = 500, Suffix = "ms" })

-- Movement (tabbox example)
local MoveBox = Tabs.Movement:AddLeftTabbox()
local Speed = MoveBox:AddTab("Speed")
Speed:AddToggle("SpeedEnabled", { Text = "Walk speed" })
Speed:AddSlider("SpeedValue", { Text = "Speed", Default = 32, Min = 16, Max = 200 })
local Fly = MoveBox:AddTab("Fly")
Fly:AddToggle("FlyEnabled", { Text = "Fly" }):AddKeyPicker("FlyKey", { Default = "F", SyncToggleState = true })
Fly:AddSlider("FlySpeed", { Text = "Fly speed", Default = 60, Min = 10, Max = 300 })

-- Visuals
local Esp = Tabs.Visuals:AddLeftGroupbox("ESP", "scan-eye")
Esp:AddToggle("EspBoxes", { Text = "Boxes", Default = true }):AddColorPicker("EspBoxColor", { Default = Color3.fromRGB(124, 58, 237), Title = "Box color" })
Esp:AddToggle("EspNames", { Text = "Names" }):AddColorPicker("EspNameColor", { Default = Color3.new(1, 1, 1) })

-- Gear button with extra options for the boxes toggle
local BoxSettings = Toggles.EspBoxes:AddSettings()
BoxSettings:AddDropdown("EspBoxStyle", { Text = "Box style", Values = { "2D", "Corners", "3D" }, Default = "2D" })
BoxSettings:AddSlider("EspBoxThickness", { Text = "Thickness", Default = 1, Min = 1, Max = 4 })
Esp:AddDropdown("EspParts", { Text = "Show", Values = { "Health", "Distance", "Weapon", "Tracer" }, Multi = true, Default = { "Health", "Distance" } })

local World = Tabs.Visuals:AddRightGroupbox("World", "sun")
World:AddLabel("Ambient"):AddColorPicker("AmbientColor", { Default = Color3.fromRGB(40, 30, 60) })
World:AddLabel("Settings here change lighting on your client only.", true)

-- Separate card that only appears while ESP boxes are on
local BoxPreview = Esp:AddDependencyGroupbox("Box preview", "image")
BoxPreview:AddImage("BoxPreviewImage", { Image = "scan-eye", Height = 90, Color = Color3.fromRGB(139, 92, 246) })
BoxPreview:SetupDependencies({ { Toggles.EspBoxes, true } })

-- Players tab with sub tabs
local Everyone = Tabs.Players:AddSubTab("Everyone")
Everyone:AddLeftGroupbox("Target", "user"):AddDropdown("TargetPlayer", { Text = "Player", SpecialType = "Player", ExcludeLocalPlayer = true, Searchable = true })
local Friends = Tabs.Players:AddSubTab("Friends")
Friends:AddLeftGroupbox("Friends", "heart"):AddToggle("IgnoreFriends", { Text = "Ignore friends", Default = true })

Loading:SetMessage("Loading configs")
Loading:SetCurrentStep(2)

-- Settings
local Menu = Tabs.Settings:AddLeftGroupbox("Menu", "panel-left")
Menu:AddToggle("StreamerMode", {
    Text = "Streamer mode",
    Default = Library.StreamerMode,
    Tooltip = "Hides your avatar and name in the menu",
    Callback = function(Value)
        Library:SetStreamerMode(Value)
    end,
})
Menu:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind
Menu:AddToggle("ShowKeybinds", { Text = "Keybind list", Callback = function(Value)
    Library:SetKeybindListVisible(Value)
end })
Menu:AddToggle("ShowWatermark", { Text = "Watermark", Callback = function(Value)
    Library:SetWatermarkVisibility(Value)
end })
Library:SetWatermark("Nemesis")

Menu:AddButton({ Text = "Unload", Icon = "power", Variant = "Destructive", Func = function()
    Window:AddDialog("ConfirmUnload", {
        Title = "Unload Nemesis?",
        Description = "Everything turns off and the menu closes.",
        Icon = "power",
        FooterButtons = {
            Cancel = { Title = "Cancel", Variant = "Secondary", Order = 1 },
            Unload = { Title = "Unload", Variant = "Destructive", Order = 2, Callback = function()
                Library:Unload()
            end },
        },
    })
end })

-- Configs + themes (built in, same calls as Obsidian's SaveManager / ThemeManager)
local SaveManager, ThemeManager = Library.SaveManager, Library.ThemeManager
SaveManager:SetFolder("Nemesis")
SaveManager:SetSubFolder(tostring(game.PlaceId)) -- configs per game
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("Nemesis")
ThemeManager:ApplyToTab(Tabs.Settings, "Left")
SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(Tabs.Settings, "Right")
SaveManager:LoadAutoloadConfig()

Toggles.AimEnabled:OnChanged(function(Value)
    print("AimEnabled changed:", Value)
end)

Library:OnUnload(function()
    print("Nemesis unloaded")
end)

Loading:SetMessage("Done")
Loading:SetCurrentStep(3)
task.wait(0.4)
Loading:Destroy()

Library:Notify({ Title = "Nemesis loaded", Icon = "circle-check", Description = "Press Right Ctrl to show or hide the menu.", Time = 5 })
