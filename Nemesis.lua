--[[
    Nemesis UI  ·  Void
    A black + violet, shadcn-style UI library for Roblox executors.

    The API follows Obsidian / Linoria so existing scripts port over:
        local Library = loadstring(...)()
        local Window  = Library:CreateWindow({ Title = "Nemesis", Footer = "v1.0" })
        local Tab     = Window:AddTab("Combat", "crosshair")
        local Box     = Tab:AddLeftGroupbox("Aimbot", "target")
        Box:AddToggle("AimEnabled", { Text = "Enabled", Default = false, Callback = function(v) end })
        Toggles.AimEnabled.Value / Options.SomeSlider.Value

    Mobile keeps the desktop layout (sidebar + two columns). The window is scaled
    to fit the screen, rows are taller, and whole rows are tappable.
]]

local cloneref = cloneref or clonereference or function(Instance)
    return Instance
end

local function GetService(Name)
    return cloneref(game:GetService(Name))
end

local Players = GetService("Players")
local UserInputService = GetService("UserInputService")
local TweenService = GetService("TweenService")
local RunService = GetService("RunService")
local GuiService = GetService("GuiService")
local CoreGui = GetService("CoreGui")
local HttpService = GetService("HttpService")
local Teams = GetService("Teams")
local TextService = GetService("TextService")

local LocalPlayer = Players.LocalPlayer

local genv = (getgenv and getgenv()) or _G
local Toggles, Options = {}, {}
genv.Toggles = Toggles
genv.Options = Options

--// Theme (Void) \\--
local Scheme = {
    Background = Color3.fromRGB(9, 9, 11),
    Card = Color3.fromRGB(12, 12, 15),
    Muted = Color3.fromRGB(24, 24, 27),
    Hover = Color3.fromRGB(39, 39, 42),
    Border = Color3.fromRGB(39, 39, 42),
    Input = Color3.fromRGB(39, 39, 42),
    Foreground = Color3.fromRGB(250, 250, 250),
    MutedForeground = Color3.fromRGB(161, 161, 170),
    Subtle = Color3.fromRGB(113, 113, 122),
    Primary = Color3.fromRGB(124, 58, 237),
    PrimaryHover = Color3.fromRGB(139, 92, 246),
    PrimaryForeground = Color3.fromRGB(255, 255, 255),
    Destructive = Color3.fromRGB(239, 68, 68),
    DestructiveBg = Color3.fromRGB(127, 29, 29),
    DestructiveHover = Color3.fromRGB(153, 27, 27),
    DestructiveForeground = Color3.fromRGB(254, 226, 226),
}

local Library = {
    Version = "1.0.0",
    Scheme = Scheme,
    Toggles = Toggles,
    Options = Options,
    Signals = {},
    UnloadCallbacks = {},
    Scales = {},
    KeyPickers = {},
    PlayerDropdowns = {},
    Scale = 1,
    Unloaded = false,
    Toggled = false,
    IsMobile = false,
    ForceCheckbox = false,
    StreamerMode = false,
    ToggleKeybind = Enum.KeyCode.RightControl,
    ActivePopup = nil,
    Picking = nil,
    Window = nil,
}

do
    local Ok, Platform = pcall(function()
        return UserInputService:GetPlatform()
    end)
    if Ok and (Platform == Enum.Platform.Android or Platform == Enum.Platform.IOS) then
        Library.IsMobile = true
    else
        Library.IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
    end
    -- For previewing on PC: set getgenv().NemesisForceMobile = true before loading.
    if genv.NemesisForceMobile ~= nil then
        Library.IsMobile = genv.NemesisForceMobile == true
    end
end

-- Sizes. Mobile has the same layout with taller rows and bigger controls.
local M = Library.IsMobile
        and {
            Row = 38,
            Tab = 38,
            Sidebar = 168,
            Width = 660,
            Height = 390,
            Switch = Vector2.new(42, 24),
            Knob = 20,
            Box = 20,
            Option = 38,
            Chip = 26,
            Knob2 = 20,
        }
    or {
        Row = 34,
        Tab = 36,
        Sidebar = 210,
        Width = 800,
        Height = 520,
        Switch = Vector2.new(36, 20),
        Knob = 16,
        Box = 16,
        Option = 32,
        Chip = 22,
        Knob2 = 16,
    }
Library.Metrics = M

local FontFamily = "rbxasset://fonts/families/BuilderSans.json"
local Fonts = {
    Regular = Font.new(FontFamily, Enum.FontWeight.Regular),
    Medium = Font.new(FontFamily, Enum.FontWeight.Medium),
    SemiBold = Font.new(FontFamily, Enum.FontWeight.SemiBold),
    Bold = Font.new(FontFamily, Enum.FontWeight.Bold),
    Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular),
}

Library.Fonts = Fonts

--// Helpers \\--
-- Theme registry. Colours and fonts can be given as theme keys ("Card", "Primary",
-- "Medium"...) instead of values. Create() resolves them and remembers which key each
-- property uses, so the whole UI can be recoloured / re-fonted later with
-- Library:SetTheme and Library:SetFont.
local ColorProps = {
    BackgroundColor3 = true,
    TextColor3 = true,
    ImageColor3 = true,
    PlaceholderColor3 = true,
    ScrollBarImageColor3 = true,
    Color = true,
}
-- Strong keys on purpose: Roblox can collect the Lua wrapper of a live Instance, which
-- silently empties weak-keyed tables. Destroyed instances are pruned in RefreshAll.
local Registry = {} -- [Instance] = { [Property] = Key }
local Refreshers = {} -- re-run after a theme change to restore element visual state
Library.Registry = Registry

local function Register(Inst, Property, Key)
    local Entry = Registry[Inst]
    if not Entry then
        Entry = {}
        Registry[Inst] = Entry
    end
    Entry[Property] = Key
end

local function AddRefresher(Fn)
    table.insert(Refreshers, Fn)
end

local function Create(Class, Props, Children)
    local Inst = Instance.new(Class)
    if Inst:IsA("GuiObject") then
        Inst.BorderSizePixel = 0
    end
    local Parent
    for Key, Value in pairs(Props or {}) do
        if Key == "Parent" then
            Parent = Value
        elseif type(Value) == "string" and ColorProps[Key] and Scheme[Value] then
            Inst[Key] = Scheme[Value]
            Register(Inst, Key, Value)
        elseif type(Value) == "string" and Key == "FontFace" and Fonts[Value] then
            Inst[Key] = Fonts[Value]
            Register(Inst, Key, Value)
        else
            Inst[Key] = Value
        end
    end
    for _, Child in ipairs(Children or {}) do
        Child.Parent = Inst
    end
    if Parent then
        Inst.Parent = Parent
    end
    return Inst
end

local function Corner(Radius)
    return Create("UICorner", { CornerRadius = UDim.new(0, Radius) })
end

local function Stroke(Color, Transparency, Thickness)
    return Create("UIStroke", {
        Color = Color or "Border",
        Transparency = Transparency or 0,
        Thickness = Thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function Pad(T, R, B, L)
    return Create("UIPadding", {
        PaddingTop = UDim.new(0, T or 0),
        PaddingRight = UDim.new(0, R or 0),
        PaddingBottom = UDim.new(0, B or 0),
        PaddingLeft = UDim.new(0, L or 0),
    })
end

local function List(Direction, Padding, HAlign, VAlign)
    return Create("UIListLayout", {
        FillDirection = Direction or Enum.FillDirection.Vertical,
        Padding = UDim.new(0, Padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = HAlign or Enum.HorizontalAlignment.Left,
        VerticalAlignment = VAlign or Enum.VerticalAlignment.Top,
    })
end

local function Text(Props)
    local Defaults = {
        BackgroundTransparency = 1,
        FontFace = "Regular",
        TextSize = 14,
        TextColor3 = "Foreground",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Text = "",
    }
    for Key, Value in pairs(Props) do
        Defaults[Key] = Value
    end
    return Create("TextLabel", Defaults)
end

local function Tween(Inst, Props, Time)
    local T = TweenService:Create(
        Inst,
        TweenInfo.new(Time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        Props
    )
    T:Play()
    return T
end

local function Connect(Signal, Fn)
    local Conn = Signal:Connect(Fn)
    table.insert(Library.Signals, Conn)
    return Conn
end
Library.GiveSignal = function(_, Conn)
    table.insert(Library.Signals, Conn)
    return Conn
end

local function SafeCallback(Fn, ...)
    if type(Fn) ~= "function" then
        return
    end
    local Ok, Err = pcall(Fn, ...)
    if not Ok then
        warn("[Nemesis] callback error: " .. tostring(Err))
    end
end
Library.SafeCallback = function(_, Fn, ...)
    SafeCallback(Fn, ...)
end

-- InputObject.Position and GuiObject.AbsolutePosition share the same space
-- (both exclude the top bar inset), so they can be compared directly.
local function PointerPos(Input)
    return Vector2.new(Input.Position.X, Input.Position.Y)
end

local function IsClick(Input)
    return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(Input)
    return Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch
end

local function IsOver(Gui, Pos)
    local P, S = Gui.AbsolutePosition, Gui.AbsoluteSize
    return Pos.X >= P.X and Pos.X <= P.X + S.X and Pos.Y >= P.Y and Pos.Y <= P.Y + S.Y
end

local function IsTyping()
    return UserInputService:GetFocusedTextBox() ~= nil
end

--// Icons (Lucide) \\--
local IconModule
do
    local Ok, Mod = pcall(function()
        return loadstring(
            game:HttpGet("https://raw.githubusercontent.com/notpoiu/lucide-roblox-direct/refs/heads/main/source.lua")
        )()
    end)
    if Ok and type(Mod) == "table" then
        IconModule = Mod
    end
end

function Library:SetIconModule(Module)
    IconModule = Module
end

function Library:GetIcon(Name)
    if Name == nil or Name == "" then
        return nil
    end
    if type(Name) == "number" or tonumber(Name) then
        return { Url = "rbxassetid://" .. tostring(Name) }
    end
    if type(Name) == "string" and Name:find("^rbxasset") then
        return { Url = Name }
    end
    if not IconModule then
        return nil
    end
    local Ok, Data = pcall(IconModule.GetAsset, Name)
    if Ok and Data then
        return Data
    end
    return nil
end

local function Icon(Name, Size, Color, Props)
    local Data = Library:GetIcon(Name)
    local Img = Create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(Size, Size),
        ImageColor3 = Color or Scheme.MutedForeground,
        Image = Data and Data.Url or "",
        ImageRectOffset = Data and Data.ImageRectOffset or Vector2.zero,
        ImageRectSize = Data and Data.ImageRectSize or Vector2.zero,
        ScaleType = Enum.ScaleType.Fit,
    })
    for Key, Value in pairs(Props or {}) do
        if Key ~= "Parent" then
            Img[Key] = Value
        end
    end
    if Props and Props.Parent then
        Img.Parent = Props.Parent
    end
    return Img, Data ~= nil
end

-- A check mark that falls back to a text glyph when icons fail to load.
-- Returns the gui and the property to tween for show/hide.
local function CheckMark(Size, Color, Props)
    local Img, Ok = Icon("check", Size, Color, Props)
    if Ok then
        return Img, "ImageTransparency"
    end
    Img:Destroy()
    local Label = Text({
        Text = "✓",
        TextSize = Size,
        FontFace = "Bold",
        TextColor3 = Color,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromOffset(Size, Size),
    })
    for Key, Value in pairs(Props or {}) do
        if Key ~= "Parent" then
            Label[Key == "ImageTransparency" and "TextTransparency" or Key] = Value
        end
    end
    if Props and Props.Parent then
        Label.Parent = Props.Parent
    end
    return Label, "TextTransparency"
end

--// ScreenGui \\--
local ScreenGui = Create("ScreenGui", {
    Name = HttpService:GenerateGUID(false),
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
})
do
    local Parented = pcall(function()
        ScreenGui.Parent = gethui()
    end)
    if not Parented then
        Parented = pcall(function()
            if protectgui then
                protectgui(ScreenGui)
            elseif syn and syn.protect_gui then
                syn.protect_gui(ScreenGui)
            end
            ScreenGui.Parent = CoreGui
        end)
    end
    if not Parented then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end
Library.ScreenGui = ScreenGui

local function NewScale(Parent)
    local S = Create("UIScale", { Scale = Library.Scale, Parent = Parent })
    table.insert(Library.Scales, S)
    return S
end

function Library:SetScale(Value)
    Library.Scale = Value
    for _, S in ipairs(Library.Scales) do
        if S.Parent then
            S.Scale = Value
        end
    end
end

--// Popups (dropdowns, color pickers, mode menus, settings panels)
-- Popups form a stack so one can open inside another (a dropdown inside a settings
-- panel). Library.ActivePopup is always the top one.
local PopupStack = {}

local function IsPopupOpen(Popup)
    return table.find(PopupStack, Popup) ~= nil
end

-- Closes the top popup, or a specific popup and everything above it.
local function ClosePopup(Target)
    while #PopupStack > 0 do
        local Popup = table.remove(PopupStack)
        if Popup.Follow then
            Popup.Follow:Disconnect()
            Popup.Follow = nil
        end
        Popup.Close()
        if not Target or Popup == Target then
            break
        end
    end
    Library.ActivePopup = PopupStack[#PopupStack]
end

local function CloseAllPopups()
    while #PopupStack > 0 do
        ClosePopup()
    end
end
Library.ClosePopup = ClosePopup
Library.CloseAllPopups = CloseAllPopups

local function PlacePopup(Frame, Owner, Align)
    local S = Library.Scale
    -- Work in ScreenGui-local coordinates so this is right whatever the gui is parented to.
    local Origin = ScreenGui.AbsolutePosition
    local Pos, Size = Owner.AbsolutePosition - Origin, Owner.AbsoluteSize
    local View = ScreenGui.AbsoluteSize
    local W, H = Frame.AbsoluteSize.X, Frame.AbsoluteSize.Y
    local X = Align == "Right" and (Pos.X + Size.X - W) or Pos.X
    X = math.clamp(X, 8, math.max(8, View.X - W - 8))
    local Y = Pos.Y + Size.Y + 6 * S
    if Y + H > View.Y - 8 then
        Y = Pos.Y - H - 6 * S
    end
    -- Whole pixels only: half-pixel positions make text render blurry.
    Frame.Position = UDim2.fromOffset(math.floor(X), math.floor(math.max(8, Y)))
end

local function OpenPopup(Popup, Align)
    if IsPopupOpen(Popup) then
        ClosePopup(Popup)
    end
    -- Close popups that this one is not nested inside.
    while #PopupStack > 0 and not Popup.Owner:IsDescendantOf(PopupStack[#PopupStack].Frame) do
        ClosePopup()
    end
    table.insert(PopupStack, Popup)
    Library.ActivePopup = Popup
    Popup.Frame.Visible = true
    PlacePopup(Popup.Frame, Popup.Owner, Align)
    Popup.Follow = RunService.RenderStepped:Connect(function()
        if not Popup.Owner.Visible or not Popup.Owner:IsDescendantOf(ScreenGui) then
            ClosePopup(Popup)
            return
        end
        PlacePopup(Popup.Frame, Popup.Owner, Align)
    end)
end

-- A click outside closes popups from the top down until one contains the click.
Connect(UserInputService.InputBegan, function(Input)
    if #PopupStack == 0 then
        return
    end
    if not (IsClick(Input) or Input.UserInputType == Enum.UserInputType.MouseButton2) then
        return
    end
    local Pos = PointerPos(Input)
    while #PopupStack > 0 do
        local Top = PopupStack[#PopupStack]
        if IsOver(Top.Frame, Pos) or IsOver(Top.Owner, Pos) then
            return
        end
        ClosePopup()
    end
end)

--// Tooltip \\--
local Tooltip = Create("TextLabel", {
    BackgroundColor3 = "Muted",
    FontFace = "Regular",
    TextSize = 13,
    TextColor3 = "Foreground",
    AutomaticSize = Enum.AutomaticSize.XY,
    Size = UDim2.fromOffset(0, 0),
    Visible = false,
    ZIndex = 200,
    Parent = ScreenGui,
}, { Corner(6), Stroke(), Pad(5, 8, 5, 8) })
NewScale(Tooltip)

local function AddTooltip(Gui, Content)
    if not Content or Content == "" or Library.IsMobile then
        return
    end
    Connect(Gui.MouseEnter, function()
        Tooltip.Text = Content
        Tooltip.Visible = true
    end)
    Connect(Gui.MouseLeave, function()
        Tooltip.Visible = false
    end)
end

Connect(UserInputService.InputChanged, function(Input)
    if Tooltip.Visible and Input.UserInputType == Enum.UserInputType.MouseMovement then
        local P = Vector2.new(Input.Position.X, Input.Position.Y) - ScreenGui.AbsolutePosition
        Tooltip.Position = UDim2.fromOffset(P.X + 14, P.Y + 16)
    end
end)

--// Dragging \\--
local function MakeDraggable(Handle, Target)
    local State = { Dragging = false, Moved = 0 }
    local StartPointer, StartPos

    Connect(Handle.InputBegan, function(Input)
        if not IsClick(Input) or Library.DragLocked then
            return
        end
        State.Dragging = true
        State.Moved = 0
        StartPointer = PointerPos(Input)
        StartPos = Target.Position
        -- Also end the drag from the input itself, in case the global InputEnded is missed.
        local Conn
        Conn = Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                State.Dragging = false
                Conn:Disconnect()
            end
        end)
    end)

    Connect(UserInputService.InputChanged, function(Input)
        if not State.Dragging or not IsMove(Input) then
            return
        end
        -- Only follow the mouse while button 1 is actually held.
        if Input.UserInputType == Enum.UserInputType.MouseMovement
            and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            State.Dragging = false
            return
        end
        local Delta = PointerPos(Input) - StartPointer
        State.Moved = math.max(State.Moved, Delta.Magnitude)
        Target.Position = UDim2.new(
            StartPos.X.Scale,
            math.floor(StartPos.X.Offset + Delta.X),
            StartPos.Y.Scale,
            math.floor(StartPos.Y.Offset + Delta.Y)
        )
    end)

    Connect(UserInputService.InputEnded, function(Input)
        if IsClick(Input) then
            State.Dragging = false
        end
    end)

    return State
end

--// Notifications \\--
local NotifyHolder = Create("Frame", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -16, 1, -16),
    Size = UDim2.new(0, 300, 1, -32),
    ZIndex = 150,
    Parent = ScreenGui,
}, { List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom) })
NewScale(NotifyHolder)
Library.NotifySide = "BottomRight"

-- "Left", "Right", "TopLeft", "TopRight", "BottomLeft", "BottomRight".
function Library:SetNotifySide(Side)
    Side = tostring(Side or "BottomRight"):lower()
    local Left = Side:find("left") ~= nil
    local Top = Side:find("top") ~= nil
    Library.NotifySide = (Top and "Top" or "Bottom") .. (Left and "Left" or "Right")
    NotifyHolder.AnchorPoint = Vector2.new(Left and 0 or 1, Top and 0 or 1)
    NotifyHolder.Position = UDim2.new(Left and 0 or 1, Left and 16 or -16, Top and 0 or 1, Top and (GuiService:GetGuiInset().Y + 16) or -16)
    local Layout = NotifyHolder:FindFirstChildOfClass("UIListLayout")
    Layout.HorizontalAlignment = Left and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
    Layout.VerticalAlignment = Top and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
end

-- Library:Notify("Text", Time?) or Library:Notify({
--     Title, Description, Time = 4 (seconds, or an Instance: closes when it is destroyed),
--     Icon, IconColor, TitleColor, DescriptionColor,
--     Steps (shows a progress bar you drive with :ChangeStep(n)),
--     Persist (never auto-close), Closable (X button), SoundId, Volume,
--     Callback = function(Reason) end  -- "timer", "user" or "script"
-- })
-- Returns an object with :ChangeTitle, :ChangeDescription, :ChangeStep, :Destroy.
function Library:Notify(...)
    local Args = { ... }
    local Info
    if type(Args[1]) == "table" then
        Info = Args[1]
    else
        Info = { Description = tostring(Args[1]), Time = Args[2], SoundId = Args[3], Volume = Args[4] }
    end
    local Time = Info.Time
    if Time == nil then
        Time = 4
    end
    local FromLeft = Library.NotifySide:find("Left") ~= nil
    local Offscreen = FromLeft and -340 or 340

    local Wrapper = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = NotifyHolder,
    })
    local Card = Create("Frame", {
        BackgroundColor3 = "Card",
        Position = UDim2.fromOffset(Offscreen, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = Wrapper,
    }, { Corner(10), Stroke() })
    local Body = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = Card,
    }, { Pad(12, Info.Closable and 34 or 14, 14, 14), List(Enum.FillDirection.Vertical, 3) })

    local TitleLabel
    if Info.Title then
        local Row = Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            LayoutOrder = 1,
            Parent = Body,
        }, { List(Enum.FillDirection.Horizontal, 7, nil, Enum.VerticalAlignment.Center) })
        if Info.Icon then
            local Img, Ok = Icon(Info.Icon, 15, Info.IconColor or "PrimaryHover", { LayoutOrder = 1, Parent = Row })
            if not Ok then
                Img:Destroy()
            end
        end
        TitleLabel = Text({
            Text = tostring(Info.Title),
            FontFace = "Medium",
            TextSize = 15,
            TextColor3 = Info.TitleColor or "Foreground",
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = 2,
            Parent = Row,
        })
    end
    local DescLabel = Text({
        Text = tostring(Info.Description or ""),
        TextColor3 = Info.DescriptionColor or (Info.Title and "MutedForeground" or "Foreground"),
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        Visible = (Info.Description or "") ~= "",
        Parent = Body,
    })

    local Bar = Create("Frame", {
        BackgroundColor3 = "Primary",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 14, 1, -6),
        Size = UDim2.new(1, -28, 0, 2),
        Parent = Card,
    }, { Corner(99) })

    local Data = { Destroyed = false, Holder = Wrapper, Steps = Info.Steps }

    function Data:ChangeTitle(Value)
        if TitleLabel then
            TitleLabel.Text = tostring(Value)
        end
    end
    function Data:ChangeDescription(Value)
        DescLabel.Text = tostring(Value)
        DescLabel.Visible = tostring(Value) ~= ""
    end
    function Data:ChangeStep(Step)
        if Data.Steps then
            local Pct = math.clamp((tonumber(Step) or 0) / Data.Steps, 0, 1)
            Tween(Bar, { Size = UDim2.new(Pct, -28 * Pct, 0, 2) }, 0.2)
        end
    end
    function Data:Destroy(Reason)
        if Data.Destroyed then
            return
        end
        Data.Destroyed = true
        SafeCallback(Info.Callback, Reason or "script")
        Tween(Card, { Position = UDim2.fromOffset(Offscreen, 0) }, 0.2).Completed:Connect(function()
            Wrapper:Destroy()
        end)
    end

    if Info.Closable then
        local Close = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 8),
            Size = UDim2.fromOffset(22, 22),
            Parent = Card,
        })
        Icon("x", 14, "MutedForeground", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = Close })
        Connect(Close.Activated, function()
            Data:Destroy("user")
        end)
    end

    if Info.SoundId then
        local Sound = Create("Sound", {
            SoundId = type(Info.SoundId) == "number" and ("rbxassetid://" .. Info.SoundId) or tostring(Info.SoundId),
            Volume = Info.Volume or 3,
            PlayOnRemove = true,
            Parent = ScreenGui,
        })
        Sound:Destroy()
    end

    Tween(Card, { Position = UDim2.fromOffset(0, 0) }, 0.25)
    if Data.Steps then
        Bar.Size = UDim2.new(0, 0, 0, 2)
    elseif Info.Persist then
        Bar.Visible = false
    elseif typeof(Time) == "Instance" then
        Bar.Visible = false
        Time.Destroying:Once(function()
            Data:Destroy("script")
        end)
    elseif type(Time) == "number" and Time > 0 then
        Tween(Bar, { Size = UDim2.new(0, 0, 0, 2) }, Time)
        task.delay(Time, function()
            Data:Destroy("timer")
        end)
    else
        Bar.Visible = false
    end
    return Data
end

--// Shared element pieces \\--
local Funcs = {}
local BaseAddons = {}

local function MakeAddonHolder(Row, RightOffset)
    return Create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -RightOffset, 0.5, 0),
        Size = UDim2.fromOffset(0, M.Chip),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = Row,
    }, { List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
end

-- Shrinks a label so it never runs under the addon chips on the right.
local function FitLabel(Label, Holder, Reserved)
    local function Update()
        local W = Holder.AbsoluteSize.X / math.max(Library.Scale, 0.01)
        Label.Size = UDim2.new(1, -(Reserved + (W > 0 and W + 8 or 0)), Label.Size.Y.Scale, Label.Size.Y.Offset)
    end
    Connect(Holder:GetPropertyChangedSignal("AbsoluteSize"), Update)
    Update()
end

function Funcs:NextOrder()
    self.Order = self.Order + 1
    return self.Order
end

function Funcs:Register(Holder, Element)
    table.insert(self.Elements, { Holder = Holder, Element = Element })
end

--// Label \\--
function Funcs:AddLabel(...)
    local Args = { ... }
    local Idx, Info
    if type(Args[1]) == "table" then
        Info = Args[1]
    elseif type(Args[2]) == "table" then
        Idx, Info = Args[1], Args[2]
    else
        Info = { Text = Args[1], DoesWrap = Args[2] }
        Idx = Args[3]
    end
    Info.Text = Info.Text or ""

    local Wrap = Info.DoesWrap == true
    local Holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Wrap and 0 or M.Row - 4),
        AutomaticSize = Wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        LayoutOrder = self:NextOrder(),
        Parent = self.Container,
    }, Wrap and { Pad(4, 0, 4, 0) } or nil)

    local Label = setmetatable({
        Type = "Label",
        Text = Info.Text,
        Visible = Info.Visible ~= false,
        Addons = {},
        Holder = Holder,
    }, { __index = BaseAddons })

    local TextLabel = Text({
        Text = Info.Text,
        RichText = true,
        TextWrapped = Wrap,
        TextColor3 = Wrap and Scheme.MutedForeground or Scheme.Foreground,
        Size = UDim2.new(1, 0, Wrap and 0 or 1, 0),
        AutomaticSize = Wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        TextTruncate = Wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
        Parent = Holder,
    })
    Label.TextLabel = TextLabel

    if not Wrap then
        Label.AddonHolder = MakeAddonHolder(Holder, 0)
        FitLabel(TextLabel, Label.AddonHolder, 0)
    end

    function Label:SetText(Value)
        Label.Text = Value
        TextLabel.Text = Value
    end
    function Label:SetVisible(Value)
        Label.Visible = Value
        Holder.Visible = Value
    end

    Holder.Visible = Label.Visible
    self:Register(Holder, Label)
    if Idx then
        Options[Idx] = Label
    end
    return Label
end

--// Divider \\--
function Funcs:AddDivider(Label)
    local Holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Label and 26 or 13),
        LayoutOrder = self:NextOrder(),
        Parent = self.Container,
    })
    Create("Frame", {
        BackgroundColor3 = "Border",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Holder,
    })
    if Label then
        -- The label sits on a card-coloured background so the line appears to start after it.
        local DividerLabel = Text({
            Text = string.upper(Label),
            FontFace = "Medium",
            TextSize = 12,
            TextColor3 = "Subtle",
            BackgroundTransparency = 0,
            BackgroundColor3 = "Card",
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            Parent = Holder,
        })
        Pad(0, 8, 0, 0).Parent = DividerLabel
    end
    local Divider = { Type = "Divider", Holder = Holder, Visible = true, Text = Label }
    function Divider:SetVisible(Value)
        Divider.Visible = Value
        Holder.Visible = Value
    end
    self:Register(Holder, Divider)
    return Divider
end

--// Button \\--
local ButtonVariants = {
    -- Values are theme keys, resolved at use so buttons follow theme changes.
    Primary = { Bg = "Primary", Hover = "PrimaryHover", Text = "PrimaryForeground" },
    Secondary = { Bg = "Muted", Hover = "Hover", Text = "Foreground", Stroke = true },
    Outline = { Bg = "Background", Hover = "Muted", Text = "Foreground", Stroke = true },
    Ghost = { Bg = "Muted", Hover = "Muted", Text = "Foreground", Transparent = true },
    Destructive = { Bg = "DestructiveBg", Hover = "DestructiveHover", Text = "DestructiveForeground" },
}

local function ParseButtonArgs(...)
    local Args = { ... }
    if type(Args[1]) == "table" then
        return Args[1]
    end
    return { Text = Args[1], Func = Args[2] }
end

local function MakeButton(Holder, Info)
    local Variant = Info.Variant or (Info.Risky and "Destructive") or "Secondary"
    local Style = ButtonVariants[Variant] or ButtonVariants.Secondary

    local Obj = {
        Type = "Button",
        Text = Info.Text or "Button",
        Func = Info.Func or Info.Callback,
        DoubleClick = Info.DoubleClick,
        Disabled = Info.Disabled,
        Visible = Info.Visible ~= false,
    }

    local Btn = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Style.Bg,
        BackgroundTransparency = Style.Transparent and 1 or 0,
        Size = UDim2.fromScale(1, 1),
        Visible = Obj.Visible,
        Parent = Holder,
    }, { Corner(7) })
    if Style.Stroke then
        Stroke().Parent = Btn
    end

    local Inner = Create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = Btn,
    }, { List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })

    if Info.Icon then
        local Img, Ok = Icon(Info.Icon, 14, Style.Text, { LayoutOrder = 1, Parent = Inner })
        if not Ok then
            Img:Destroy()
        end
    end
    local Label = Text({
        Text = Obj.Text,
        FontFace = "Medium",
        TextColor3 = Style.Text,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        Parent = Inner,
    })

    local function Refresh()
        Inner.Visible = true
        Label.TextTransparency = Obj.Disabled and 0.5 or 0
    end

    Connect(Btn.MouseEnter, function()
        if not Obj.Disabled then
            Tween(Btn, { BackgroundColor3 = Scheme[Style.Hover], BackgroundTransparency = 0 })
        end
    end)
    Connect(Btn.MouseLeave, function()
        Tween(Btn, { BackgroundColor3 = Scheme[Style.Bg], BackgroundTransparency = Style.Transparent and 1 or 0 })
    end)
    Connect(Btn.Activated, function()
        if Obj.Disabled then
            return
        end
        if Obj.DoubleClick and not Obj.Armed then
            Obj.Armed = true
            Label.Text = "Are you sure?"
            task.delay(1.5, function()
                if Obj.Armed then
                    Obj.Armed = false
                    Label.Text = Obj.Text
                end
            end)
            return
        end
        Obj.Armed = false
        Label.Text = Obj.Text
        SafeCallback(Obj.Func)
    end)

    function Obj:SetText(Value)
        Obj.Text = Value
        Label.Text = Value
    end
    function Obj:SetDisabled(Value)
        Obj.Disabled = Value
        Refresh()
    end
    function Obj:SetVisible(Value)
        Obj.Visible = Value
        Btn.Visible = Value
    end

    Obj.Instance = Btn
    AddTooltip(Btn, Info.Tooltip)
    Refresh()
    return Obj
end

function Funcs:AddButton(...)
    local Info = ParseButtonArgs(...)
    local Holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, M.Row + 8),
        LayoutOrder = self:NextOrder(),
        Parent = self.Container,
    }, { Pad(4, 0, 4, 0) })
    local Row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Parent = Holder,
    }, { List(Enum.FillDirection.Horizontal, 8) })

    local Buttons = {}
    local function Layout()
        local N = #Buttons
        for _, B in ipairs(Buttons) do
            B.Instance.Size = UDim2.new(1 / N, -((N - 1) * 8) / N, 1, 0)
        end
    end

    local Button = MakeButton(Row, Info)
    table.insert(Buttons, Button)
    Layout()

    function Button:AddButton(...)
        local Sub = MakeButton(Row, ParseButtonArgs(...))
        Sub.Instance.LayoutOrder = #Buttons + 1
        table.insert(Buttons, Sub)
        Layout()
        return Sub
    end

    Button.Holder = Holder
    self:Register(Holder, Button)
    return Button
end

--// Toggle / Checkbox \\--
local function BuildToggle(Groupbox, Idx, Info, Style)
    Info = Info or {}
    local Toggle = setmetatable({
        Type = "Toggle",
        Value = Info.Default == true,
        Text = Info.Text or tostring(Idx),
        Callback = Info.Callback,
        Changed = Info.Changed,
        Risky = Info.Risky,
        Disabled = Info.Disabled,
        Visible = Info.Visible ~= false,
        Addons = {},
    }, { __index = BaseAddons })

    local Row = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, M.Row),
        LayoutOrder = Groupbox:NextOrder(),
        Visible = Toggle.Visible,
        Parent = Groupbox.Container,
    })

    local Label, Display, Reserved
    if Style == "Switch" then
        local SW = M.Switch
        local Track = Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(SW.X, SW.Y),
            BackgroundColor3 = "Input",
            Parent = Row,
        }, { Corner(99) })
        local Knob = Create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 2, 0.5, 0),
            Size = UDim2.fromOffset(M.Knob, M.Knob),
            BackgroundColor3 = "Foreground",
            Parent = Track,
        }, { Corner(99) })
        Label = Text({ Text = Toggle.Text, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -(SW.X + 8), 1, 0), Parent = Row })
        Reserved = SW.X + 8
        Toggle.AddonHolder = MakeAddonHolder(Row, SW.X + 10)
        Display = function(Instant)
            local On = Toggle.Value
            local T = Instant and 0 or 0.16
            Tween(Track, { BackgroundColor3 = On and (Toggle.Disabled and Scheme.Subtle or Scheme.Primary) or Scheme.Input }, T)
            Tween(Knob, { Position = On and UDim2.new(1, -(M.Knob + 2), 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }, T)
        end
    else
        local Box = Create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(M.Box, M.Box),
            BackgroundColor3 = "Primary",
            BackgroundTransparency = 1,
            Parent = Row,
        }, { Corner(5) })
        local BoxStroke = Stroke("Subtle")
        BoxStroke.Parent = Box
        local Check, Prop = CheckMark(M.Box - 4, "PrimaryForeground", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Parent = Box,
        })
        Label = Text({
            Text = Toggle.Text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(M.Box + 10, 0),
            Size = UDim2.new(1, -(M.Box + 10), 1, 0),
            Parent = Row,
        })
        Reserved = M.Box + 10
        Toggle.AddonHolder = MakeAddonHolder(Row, 0)
        Display = function(Instant)
            local On = Toggle.Value
            local T = Instant and 0 or 0.14
            Tween(Box, { BackgroundTransparency = On and 0 or 1, BackgroundColor3 = Toggle.Disabled and Scheme.Subtle or Scheme.Primary }, T)
            Tween(BoxStroke, { Color = On and (Toggle.Disabled and Scheme.Subtle or Scheme.Primary) or Scheme.Subtle }, T)
            Tween(Check, { [Prop] = On and 0 or 1 }, T)
        end
    end
    FitLabel(Label, Toggle.AddonHolder, Reserved)

    local function Refresh(Instant)
        Display(Instant)
        Label.TextColor3 = Toggle.Disabled and Scheme.Subtle
            or (Toggle.Risky and Scheme.Destructive or Scheme.Foreground)
    end

    function Toggle:Display()
        Refresh()
    end
    function Toggle:OnChanged(Fn)
        Toggle.Changed = Fn
    end
    function Toggle:SetValue(Value)
        Value = not not Value
        if Value == Toggle.Value then
            return
        end
        Toggle.Value = Value
        if Toggle.KeyPicker and Toggle.KeyPicker.SyncToggleState then
            Toggle.KeyPicker.Toggled = Value
        end
        if Toggle.KeyPicker then
            Library:RefreshKeybindList()
        end
        Refresh()
        SafeCallback(Toggle.Callback, Value)
        SafeCallback(Toggle.Changed, Value)
        Library:UpdateDependencyBoxes()
    end
    function Toggle:SetDisabled(Value)
        Toggle.Disabled = Value
        Refresh()
        Library:UpdateDependencyBoxes()
    end
    function Toggle:SetVisible(Value)
        Toggle.Visible = Value
        Row.Visible = Value
    end
    function Toggle:SetText(Value)
        Toggle.Text = Value
        Label.Text = Value
    end

    Connect(Row.Activated, function()
        if not Toggle.Disabled then
            Toggle:SetValue(not Toggle.Value)
        end
    end)

    AddTooltip(Row, Info.Tooltip)
    Refresh(true)
    Toggle.Holder = Row
    Groupbox:Register(Row, Toggle)
    if Idx then
        Toggles[Idx] = Toggle
    end
    return Toggle
end

function Funcs:AddToggle(Idx, Info)
    return BuildToggle(self, Idx, Info, Library.ForceCheckbox and "Checkbox" or "Switch")
end

function Funcs:AddCheckbox(Idx, Info)
    return BuildToggle(self, Idx, Info, "Checkbox")
end

--// Slider \\--
function Funcs:AddSlider(Idx, Info)
    Info = Info or {}
    local Scroller = self.Scroller
    local Slider = {
        Type = "Slider",
        Min = Info.Min or 0,
        Max = Info.Max or 100,
        Rounding = Info.Rounding or 0,
        Value = Info.Default or Info.Min or 0,
        Prefix = Info.Prefix or "",
        Suffix = Info.Suffix or "",
        Text = Info.Text or tostring(Idx),
        Callback = Info.Callback,
        Changed = Info.Changed,
        Disabled = Info.Disabled,
        Visible = Info.Visible ~= false,
    }

    local Holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Library.IsMobile and 52 or 46),
        LayoutOrder = self:NextOrder(),
        Visible = Slider.Visible,
        Parent = self.Container,
    })
    local Label = Text({
        Text = Slider.Text,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, -90, 0, 18),
        Parent = Holder,
    })
    local ValueLabel = Text({
        FontFace = "Mono",
        TextSize = 13,
        TextColor3 = "MutedForeground",
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 4),
        Size = UDim2.fromOffset(90, 18),
        Parent = Holder,
    })
    local Track = Create("Frame", {
        BackgroundColor3 = "Input",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, Library.IsMobile and -13 or -11),
        Size = UDim2.new(1, 0, 0, 6),
        Parent = Holder,
    }, { Corner(99) })
    local Fill = Create("Frame", {
        BackgroundColor3 = "Primary",
        Size = UDim2.fromScale(0, 1),
        Parent = Track,
    }, { Corner(99) })
    local Knob = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(M.Knob2, M.Knob2),
        BackgroundColor3 = "Foreground",
        ZIndex = 2,
        Parent = Track,
    }, { Corner(99), Stroke("Primary", 0, 2) })
    local KnobStroke = Knob:FindFirstChildOfClass("UIStroke")
    -- The hit area covers the whole slider (label included) so it is easy to grab on touch.
    local Hit = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
        Parent = Holder,
    })

    local function Round(Value)
        local Mult = 10 ^ Slider.Rounding
        return math.floor(Value * Mult + 0.5) / Mult
    end

    local function Format(Value)
        local Str
        if Slider.Rounding > 0 then
            Str = string.format("%." .. Slider.Rounding .. "f", Value)
        else
            Str = tostring(math.floor(Value + 0.5))
        end
        return Slider.Prefix .. Str .. Slider.Suffix
    end

    function Slider:Display()
        local Range = Slider.Max - Slider.Min
        local Pct = Range == 0 and 0 or (Slider.Value - Slider.Min) / Range
        Fill.Size = UDim2.fromScale(Pct, 1)
        Knob.Position = UDim2.fromScale(Pct, 0.5)
        ValueLabel.Text = Format(Slider.Value)
        Label.TextColor3 = Slider.Disabled and Scheme.Subtle or Scheme.Foreground
        Fill.BackgroundColor3 = Slider.Disabled and Scheme.Subtle or Scheme.Primary
        KnobStroke.Color = Fill.BackgroundColor3
    end

    function Slider:OnChanged(Fn)
        Slider.Changed = Fn
    end

    function Slider:SetValue(Value)
        Value = tonumber(Value)
        if not Value then
            return
        end
        Value = math.clamp(Round(Value), Slider.Min, Slider.Max)
        if Value == Slider.Value then
            return
        end
        Slider.Value = Value
        Slider:Display()
        SafeCallback(Slider.Callback, Value)
        SafeCallback(Slider.Changed, Value)
        Library:UpdateDependencyBoxes()
    end

    function Slider:SetMin(Value)
        Slider.Min = Value
        Slider.Value = math.clamp(Slider.Value, Slider.Min, Slider.Max)
        Slider:Display()
    end
    function Slider:SetMax(Value)
        Slider.Max = Value
        Slider.Value = math.clamp(Slider.Value, Slider.Min, Slider.Max)
        Slider:Display()
    end
    function Slider:SetPrefix(Value)
        Slider.Prefix = Value
        Slider:Display()
    end
    function Slider:SetSuffix(Value)
        Slider.Suffix = Value
        Slider:Display()
    end
    function Slider:SetText(Value)
        Slider.Text = Value
        Label.Text = Value
    end
    function Slider:SetDisabled(Value)
        Slider.Disabled = Value
        Slider:Display()
    end
    function Slider:SetVisible(Value)
        Slider.Visible = Value
        Holder.Visible = Value
    end

    local Dragging = false
    local function UpdateFrom(Input)
        local Pos = PointerPos(Input)
        local Pct = math.clamp((Pos.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        Slider:SetValue(Slider.Min + (Slider.Max - Slider.Min) * Pct)
    end

    Connect(Hit.InputBegan, function(Input)
        if Slider.Disabled or not IsClick(Input) then
            return
        end
        Dragging = true
        if Scroller then
            Scroller.ScrollingEnabled = false
        end
        Tween(Knob, { Size = UDim2.fromOffset(M.Knob2 + 4, M.Knob2 + 4) }, 0.1)
        UpdateFrom(Input)
    end)
    Connect(UserInputService.InputChanged, function(Input)
        if Dragging and IsMove(Input) then
            UpdateFrom(Input)
        end
    end)
    Connect(UserInputService.InputEnded, function(Input)
        if Dragging and IsClick(Input) then
            Dragging = false
            if Scroller then
                Scroller.ScrollingEnabled = true
            end
            Tween(Knob, { Size = UDim2.fromOffset(M.Knob2, M.Knob2) }, 0.1)
        end
    end)

    Slider.Value = math.clamp(Round(Slider.Value), Slider.Min, Slider.Max)
    Slider:Display()
    AddTooltip(Hit, Info.Tooltip)
    Slider.Holder = Holder
    self:Register(Holder, Slider)
    if Idx then
        Options[Idx] = Slider
    end
    return Slider
end

--// Input \\--
function Funcs:AddInput(Idx, Info)
    Info = Info or {}
    local Input = {
        Type = "Input",
        Value = tostring(Info.Default or ""),
        Numeric = Info.Numeric,
        Finished = Info.Finished,
        Text = Info.Text or "",
        Callback = Info.Callback,
        Changed = Info.Changed,
        Disabled = Info.Disabled,
        Visible = Info.Visible ~= false,
        MaxLength = Info.MaxLength,
    }
    local HasText = Input.Text ~= ""
    local Top = HasText and 22 or 2

    local Holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Top + M.Row + 6),
        LayoutOrder = self:NextOrder(),
        Visible = Input.Visible,
        Parent = self.Container,
    })
    local Label
    if HasText then
        Label = Text({ Text = Input.Text, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 18), Parent = Holder })
    end
    local Box = Create("Frame", {
        BackgroundColor3 = "Background",
        Position = UDim2.fromOffset(0, Top),
        Size = UDim2.new(1, 0, 0, M.Row),
        ClipsDescendants = true,
        Parent = Holder,
    }, { Corner(7) })
    local BoxStroke = Stroke()
    BoxStroke.Parent = Box
    local TextBox = Create("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        FontFace = "Regular",
        TextSize = 14,
        TextColor3 = "Foreground",
        PlaceholderText = Info.Placeholder or "",
        PlaceholderColor3 = "Subtle",
        Text = Input.Value,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = Info.ClearTextOnFocus == true,
        TextEditable = not Input.Disabled,
        Parent = Box,
    })

    Input.TextBox = TextBox

    function Input:OnChanged(Fn)
        Input.Changed = Fn
    end

    function Input:SetValue(Value)
        Value = tostring(Value or "")
        if Input.MaxLength and #Value > Input.MaxLength then
            Value = Value:sub(1, Input.MaxLength)
        end
        if Input.Numeric and Value ~= "" and Value ~= "-" and Value ~= "." and not tonumber(Value) then
            Value = Input.Value
        end
        if TextBox.Text ~= Value then
            TextBox.Text = Value
        end
        if Value == Input.Value then
            return
        end
        Input.Value = Value
        SafeCallback(Input.Callback, Value)
        SafeCallback(Input.Changed, Value)
        Library:UpdateDependencyBoxes()
    end

    function Input:SetText(Value)
        Input.Text = Value
        if Label then
            Label.Text = Value
        end
    end
    function Input:SetDisabled(Value)
        Input.Disabled = Value
        TextBox.TextEditable = not Value
        TextBox.TextColor3 = Value and Scheme.Subtle or Scheme.Foreground
    end
    function Input:SetVisible(Value)
        Input.Visible = Value
        Holder.Visible = Value
    end

    Connect(TextBox.Focused, function()
        Tween(BoxStroke, { Color = Scheme.Primary })
    end)
    Connect(TextBox.FocusLost, function(Enter)
        Tween(BoxStroke, { Color = Scheme.Border })
        if Input.Finished then
            if Enter then
                Input:SetValue(TextBox.Text)
            else
                TextBox.Text = Input.Value
            end
        end
    end)
    Connect(TextBox:GetPropertyChangedSignal("Text"), function()
        if Input.Numeric then
            local T = TextBox.Text
            if T ~= "" and T ~= "-" and T ~= "." and not tonumber(T) then
                TextBox.Text = Input.Value
                return
            end
        end
        if Input.MaxLength and #TextBox.Text > Input.MaxLength then
            TextBox.Text = TextBox.Text:sub(1, Input.MaxLength)
            return
        end
        if not Input.Finished then
            Input:SetValue(TextBox.Text)
        end
    end)

    AddTooltip(Box, Info.Tooltip)
    Input.Holder = Holder
    self:Register(Holder, Input)
    if Idx then
        Options[Idx] = Input
    end
    return Input
end

--// Dropdown \\--
local function GetPlayers(ExcludeLocal)
    local Out = {}
    for _, Player in ipairs(Players:GetPlayers()) do
        if not (ExcludeLocal and Player == LocalPlayer) then
            table.insert(Out, Player.Name)
        end
    end
    table.sort(Out, function(A, B)
        return A:lower() < B:lower()
    end)
    return Out
end

local function GetTeams()
    local Out = {}
    for _, Team in ipairs(Teams:GetTeams()) do
        table.insert(Out, Team.Name)
    end
    table.sort(Out)
    return Out
end

function Funcs:AddDropdown(Idx, Info)
    Info = Info or {}
    local Dropdown = {
        Type = "Dropdown",
        Values = Info.Values or {},
        Multi = Info.Multi == true,
        AllowNull = Info.AllowNull == true,
        Text = Info.Text or "",
        Callback = Info.Callback,
        Changed = Info.Changed,
        Disabled = Info.Disabled,
        Searchable = Info.Searchable == true,
        SpecialType = Info.SpecialType,
        ExcludeLocalPlayer = Info.ExcludeLocalPlayer,
        DisabledValues = {},
        Visible = Info.Visible ~= false,
    }
    if Dropdown.SpecialType == "Player" then
        Dropdown.Values = GetPlayers(Dropdown.ExcludeLocalPlayer)
        Dropdown.AllowNull = true
        table.insert(Library.PlayerDropdowns, Dropdown)
    elseif Dropdown.SpecialType == "Team" then
        Dropdown.Values = GetTeams()
        Dropdown.AllowNull = true
        table.insert(Library.PlayerDropdowns, Dropdown)
    end
    for _, V in ipairs(Info.DisabledValues or {}) do
        Dropdown.DisabledValues[V] = true
    end
    Dropdown.Value = Dropdown.Multi and {} or nil

    local HasText = Dropdown.Text ~= ""
    local Top = HasText and 22 or 2
    local Holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Top + M.Row + 6),
        LayoutOrder = self:NextOrder(),
        Visible = Dropdown.Visible,
        Parent = self.Container,
    })
    local Label
    if HasText then
        Label = Text({ Text = Dropdown.Text, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 18), Parent = Holder })
    end
    local Trigger = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = "Background",
        Position = UDim2.fromOffset(0, Top),
        Size = UDim2.new(1, 0, 0, M.Row),
        Parent = Holder,
    }, { Corner(7) })
    local TriggerStroke = Stroke()
    TriggerStroke.Parent = Trigger
    local ValueText = Text({
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -36, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Trigger,
    })
    local Chevron = Icon("chevron-down", 14, "MutedForeground", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Parent = Trigger,
    })

    -- Popup menu
    local SearchH = Dropdown.Searchable and 38 or 0
    local Menu = Create("Frame", {
        BackgroundColor3 = "Card",
        Size = UDim2.fromOffset(200, 100),
        Visible = false,
        ZIndex = 50,
        Parent = ScreenGui,
    }, { Corner(9), Stroke(), Pad(4, 4, 4, 4) })
    NewScale(Menu)

    local SearchBox
    if Dropdown.Searchable then
        local SearchFrame = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = Menu })
        Icon("search", 14, "MutedForeground", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 8, 0.5, 0),
            Parent = SearchFrame,
        })
        SearchBox = Create("TextBox", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(30, 0),
            Size = UDim2.new(1, -34, 1, 0),
            FontFace = "Regular",
            TextSize = 14,
            TextColor3 = "Foreground",
            PlaceholderText = "Search...",
            PlaceholderColor3 = "Subtle",
            Text = "",
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = SearchFrame,
        })
        Create("Frame", {
            BackgroundColor3 = "Border",
            Position = UDim2.new(0, -4, 0, 34),
            Size = UDim2.new(1, 8, 0, 1),
            Parent = Menu,
        })
    end

    local ListFrame = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, SearchH),
        Size = UDim2.new(1, 0, 1, -SearchH),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = "Border",
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = Menu,
    }, { List(Enum.FillDirection.Vertical, 1) })

    local OptionRows = {}

    local function IsSelected(V)
        if Dropdown.Multi then
            return Dropdown.Value[V] == true
        end
        return Dropdown.Value == V
    end

    function Dropdown:Display()
        local Str
        if Dropdown.Multi then
            local Parts = {}
            for _, V in ipairs(Dropdown.Values) do
                if Dropdown.Value[V] then
                    table.insert(Parts, tostring(V))
                end
            end
            Str = table.concat(Parts, ", ")
        else
            Str = Dropdown.Value ~= nil and tostring(Dropdown.Value) or ""
        end
        if Str == "" then
            ValueText.Text = Info.Placeholder or "Select..."
            ValueText.TextColor3 = Scheme.Subtle
        else
            ValueText.Text = Str
            ValueText.TextColor3 = Dropdown.Disabled and Scheme.Subtle or Scheme.Foreground
        end
        for _, Row in ipairs(OptionRows) do
            Row.Update()
        end
    end

    function Dropdown:GetActiveValues()
        if Dropdown.Multi then
            local Out = {}
            for _, V in ipairs(Dropdown.Values) do
                if Dropdown.Value[V] then
                    table.insert(Out, V)
                end
            end
            return Out
        end
        return Dropdown.Value and 1 or 0
    end

    local function Fire()
        Dropdown:Display()
        SafeCallback(Dropdown.Callback, Dropdown.Value)
        SafeCallback(Dropdown.Changed, Dropdown.Value)
        Library:UpdateDependencyBoxes()
    end

    local Popup = { Frame = Menu, Owner = Trigger }
    function Popup.Close()
        Menu.Visible = false
        Tween(Chevron, { Rotation = 0 })
        Tween(TriggerStroke, { Color = Scheme.Border })
        if SearchBox then
            SearchBox.Text = ""
        end
    end

    function Dropdown:BuildList()
        for _, Row in ipairs(OptionRows) do
            Row.Instance:Destroy()
        end
        table.clear(OptionRows)
        for _, Child in ipairs(ListFrame:GetChildren()) do
            if Child:IsA("TextLabel") then
                Child:Destroy()
            end
        end

        local Query = SearchBox and SearchBox.Text:lower() or ""
        local Count = 0
        for Index, V in ipairs(Dropdown.Values) do
            local Str = tostring(V)
            if Query == "" or Str:lower():find(Query, 1, true) then
                Count += 1
                local Btn = Create("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    BackgroundColor3 = "Muted",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, M.Option),
                    LayoutOrder = Index,
                    Parent = ListFrame,
                }, { Corner(6) })
                local OptLabel = Text({
                    Text = Str,
                    Position = UDim2.fromOffset(8, 0),
                    Size = UDim2.new(1, -36, 1, 0),
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = Btn,
                })
                local Check, Prop = CheckMark(14, "PrimaryHover", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Parent = Btn,
                })
                local Row = { Instance = Btn }
                function Row.Update()
                    local Disabled = Dropdown.DisabledValues[V]
                    OptLabel.TextColor3 = Disabled and Scheme.Subtle or Scheme.Foreground
                    Check[Prop] = IsSelected(V) and 0 or 1
                end
                Row.Update()
                Connect(Btn.MouseEnter, function()
                    Btn.BackgroundTransparency = 0
                end)
                Connect(Btn.MouseLeave, function()
                    Btn.BackgroundTransparency = 1
                end)
                Connect(Btn.Activated, function()
                    if Dropdown.DisabledValues[V] then
                        return
                    end
                    if Dropdown.Multi then
                        if Dropdown.Value[V] then
                            Dropdown.Value[V] = nil
                        else
                            Dropdown.Value[V] = true
                        end
                    else
                        if Dropdown.Value == V and Dropdown.AllowNull then
                            Dropdown.Value = nil
                        else
                            Dropdown.Value = V
                        end
                        ClosePopup(Popup)
                    end
                    Fire()
                end)
                table.insert(OptionRows, Row)
            end
        end

        if Count == 0 then
            Text({
                Text = "No results.",
                TextColor3 = "Subtle",
                TextXAlignment = Enum.TextXAlignment.Center,
                Size = UDim2.new(1, 0, 0, M.Option),
                Parent = ListFrame,
            })
        end

        local Visible = math.clamp(Count, 1, Library.IsMobile and 5 or 8)
        local Width = Trigger.AbsoluteSize.X / math.max(Library.Scale, 0.01)
        Menu.Size = UDim2.fromOffset(math.max(Width, 160), Visible * (M.Option + 1) + 8 + SearchH)
    end

    if SearchBox then
        Connect(SearchBox:GetPropertyChangedSignal("Text"), function()
            if Menu.Visible then
                Dropdown:BuildList()
            end
        end)
    end

    function Dropdown:Open()
        if Dropdown.Disabled then
            return
        end
        Dropdown:BuildList()
        OpenPopup(Popup, "Left")
        Tween(Chevron, { Rotation = 180 })
        Tween(TriggerStroke, { Color = Scheme.Primary })
    end

    function Dropdown:Close()
        if IsPopupOpen(Popup) then
            ClosePopup(Popup)
        end
    end

    Connect(Trigger.Activated, function()
        if IsPopupOpen(Popup) then
            Dropdown:Close()
        else
            Dropdown:Open()
        end
    end)

    function Dropdown:OnChanged(Fn)
        Dropdown.Changed = Fn
    end

    function Dropdown:SetValue(Value)
        if Dropdown.Multi then
            local New = {}
            if type(Value) == "table" then
                for Key, On in pairs(Value) do
                    if type(Key) == "number" and type(On) ~= "boolean" then
                        if table.find(Dropdown.Values, On) then
                            New[On] = true
                        end
                    elseif On and table.find(Dropdown.Values, Key) then
                        New[Key] = true
                    end
                end
            end
            Dropdown.Value = New
        else
            if Value == nil or table.find(Dropdown.Values, Value) then
                Dropdown.Value = Value
            else
                return
            end
        end
        Fire()
    end

    function Dropdown:SetValues(Values)
        Dropdown.Values = Values or {}
        if Dropdown.Multi then
            for V in pairs(Dropdown.Value) do
                if not table.find(Dropdown.Values, V) then
                    Dropdown.Value[V] = nil
                end
            end
        elseif Dropdown.Value ~= nil and not table.find(Dropdown.Values, Dropdown.Value) then
            Dropdown.Value = nil
        end
        if Menu.Visible then
            Dropdown:BuildList()
        end
        Dropdown:Display()
    end

    function Dropdown:AddValues(Values)
        if type(Values) ~= "table" then
            Values = { Values }
        end
        for _, V in ipairs(Values) do
            table.insert(Dropdown.Values, V)
        end
        Dropdown:SetValues(Dropdown.Values)
    end

    function Dropdown:SetDisabledValues(Values)
        table.clear(Dropdown.DisabledValues)
        for _, V in ipairs(Values or {}) do
            Dropdown.DisabledValues[V] = true
        end
        Dropdown:Display()
    end

    function Dropdown:SetText(Value)
        Dropdown.Text = Value
        if Label then
            Label.Text = Value
        end
    end
    function Dropdown:SetDisabled(Value)
        Dropdown.Disabled = Value
        Library:UpdateDependencyBoxes()
        if Value then
            Dropdown:Close()
        end
        Dropdown:Display()
    end
    function Dropdown:SetVisible(Value)
        Dropdown.Visible = Value
        Holder.Visible = Value
    end

    -- Default value: index, value, or (for Multi) a list/dict of values.
    local Default = Info.Default
    if Default ~= nil then
        if Dropdown.Multi then
            local New = {}
            if type(Default) == "table" then
                for Key, On in pairs(Default) do
                    if type(Key) == "number" then
                        New[type(On) == "number" and Dropdown.Values[On] or On] = true
                    elseif On then
                        New[Key] = true
                    end
                end
            end
            Dropdown.Value = New
        elseif type(Default) == "number" and Dropdown.Values[Default] ~= nil and not table.find(Dropdown.Values, Default) then
            Dropdown.Value = Dropdown.Values[Default]
        elseif table.find(Dropdown.Values, Default) then
            Dropdown.Value = Default
        end
    end

    Dropdown:Display()
    AddTooltip(Trigger, Info.Tooltip)
    Dropdown.Holder = Holder
    self:Register(Holder, Dropdown)
    if Idx then
        Options[Idx] = Dropdown
    end
    return Dropdown
end

local function RefreshSpecialDropdowns()
    for _, Dropdown in ipairs(Library.PlayerDropdowns) do
        if Dropdown.SpecialType == "Player" then
            Dropdown:SetValues(GetPlayers(Dropdown.ExcludeLocalPlayer))
        elseif Dropdown.SpecialType == "Team" then
            Dropdown:SetValues(GetTeams())
        end
    end
end
Connect(Players.PlayerAdded, RefreshSpecialDropdowns)
Connect(Players.PlayerRemoving, function()
    task.defer(RefreshSpecialDropdowns)
end)
Connect(Teams.ChildAdded, RefreshSpecialDropdowns)
Connect(Teams.ChildRemoved, RefreshSpecialDropdowns)

--// KeyPicker (addon) \\--
local KeyAliases = {
    MB1 = "LMB",
    MB2 = "RMB",
    MB3 = "MMB",
    LeftShift = "LShift",
    RightShift = "RShift",
    LeftControl = "LCtrl",
    RightControl = "RCtrl",
    LeftAlt = "LAlt",
    RightAlt = "RAlt",
    Backquote = "`",
    Return = "Enter",
}

local function InputToKey(Input)
    if Input.UserInputType == Enum.UserInputType.Keyboard then
        return Input.KeyCode.Name
    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
        return "MB1"
    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
        return "MB2"
    elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then
        return "MB3"
    end
    return nil
end

function BaseAddons:AddKeyPicker(Idx, Info)
    Info = Info or {}
    local Parent = self
    local KeyPicker = {
        Type = "KeyPicker",
        Value = Info.Default or "None",
        Mode = Info.Mode or "Toggle",
        Modes = Info.Modes or { "Always", "Toggle", "Hold" },
        Text = Info.Text or Parent.Text or tostring(Idx),
        SyncToggleState = Info.SyncToggleState == true and Parent.Type == "Toggle",
        Callback = Info.Callback,
        ChangedCallback = Info.ChangedCallback,
        Clicked = Info.Clicked,
        Toggled = false,
        Held = false,
        Picking = false,
        NoUI = Info.NoUI == true,
        MenuVisible = true,
    }
    if KeyPicker.SyncToggleState then
        KeyPicker.Toggled = Parent.Value
        Parent.KeyPicker = KeyPicker
    end

    local Chip = Create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = "Muted",
        Size = UDim2.fromOffset(0, M.Chip),
        AutomaticSize = Enum.AutomaticSize.X,
        FontFace = "Mono",
        TextSize = 12,
        TextColor3 = "MutedForeground",
        Text = "",
        LayoutOrder = 1,
        Parent = Parent.AddonHolder,
    }, {
        Corner(5),
        Pad(0, 7, 0, 7),
        Create("UISizeConstraint", { MinSize = Vector2.new(Library.IsMobile and 40 or 34, 0) }),
    })
    local ChipStroke = Stroke()
    ChipStroke.Parent = Chip

    function KeyPicker:Display()
        if KeyPicker.Picking then
            Chip.Text = "..."
            Chip.TextColor3 = Scheme.Foreground
            ChipStroke.Color = Scheme.Primary
        else
            Chip.Text = KeyAliases[KeyPicker.Value] or KeyPicker.Value
            Chip.TextColor3 = Scheme.MutedForeground
            ChipStroke.Color = Scheme.Border
        end
    end

    function KeyPicker:GetState()
        if KeyPicker.Mode == "Always" then
            return true
        elseif KeyPicker.Mode == "Hold" then
            return KeyPicker.Held
        elseif KeyPicker.Mode == "Press" then
            return false
        end
        return KeyPicker.Toggled
    end

    function KeyPicker:Fire()
        local State = KeyPicker:GetState()
        Library:RefreshKeybindList()
        if KeyPicker.SyncToggleState then
            Parent:SetValue(State)
        end
        SafeCallback(KeyPicker.Callback, State)
        SafeCallback(KeyPicker.Clicked, State)
    end

    function KeyPicker:Press(Down)
        if KeyPicker.Mode == "Toggle" then
            if Down then
                KeyPicker.Toggled = not KeyPicker.Toggled
                KeyPicker:Fire()
            end
        elseif KeyPicker.Mode == "Hold" then
            KeyPicker.Held = Down
            KeyPicker:Fire()
        elseif KeyPicker.Mode == "Press" then
            if Down then
                SafeCallback(KeyPicker.Clicked)
                SafeCallback(KeyPicker.Callback, true)
            end
        end
    end

    function KeyPicker:SetValue(Data)
        local Key, Mode = Data, nil
        if type(Data) == "table" then
            Key, Mode = Data[1], Data[2]
        end
        if Key then
            KeyPicker.Value = Key
        end
        if Mode and table.find({ "Always", "Toggle", "Hold", "Press" }, Mode) then
            KeyPicker.Mode = Mode
        end
        KeyPicker:Display()
        SafeCallback(KeyPicker.ChangedCallback, KeyPicker.Value)
        SafeCallback(KeyPicker.Changed, KeyPicker.Value)
        Library:RefreshKeybindList()
    end

    function KeyPicker:OnChanged(Fn)
        KeyPicker.Changed = Fn
    end
    function KeyPicker:OnClick(Fn)
        KeyPicker.Clicked = Fn
    end

    function KeyPicker:StopPicking(Key)
        KeyPicker.Picking = false
        Library.Picking = nil
        if Key then
            KeyPicker:SetValue(Key)
        else
            KeyPicker:Display()
        end
    end

    -- Mode menu (right click on desktop, long press on mobile)
    local ModeMenu = Create("Frame", {
        BackgroundColor3 = "Card",
        Size = UDim2.fromOffset(130, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 50,
        Parent = ScreenGui,
    }, { Corner(9), Stroke(), Pad(4, 4, 4, 4), List(Enum.FillDirection.Vertical, 1) })
    NewScale(ModeMenu)
    local ModePopup = { Frame = ModeMenu, Owner = Chip, Close = function()
        ModeMenu.Visible = false
    end }
    local ModeRows = {}
    for Index, Mode in ipairs(KeyPicker.Modes) do
        local Btn = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = "Muted",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, M.Option),
            LayoutOrder = Index,
            Parent = ModeMenu,
        }, { Corner(6) })
        Text({ Text = Mode, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -30, 1, 0), Parent = Btn })
        local Check, Prop = CheckMark(14, "PrimaryHover", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Parent = Btn,
        })
        ModeRows[Mode] = function()
            Check[Prop] = KeyPicker.Mode == Mode and 0 or 1
        end
        Connect(Btn.MouseEnter, function()
            Btn.BackgroundTransparency = 0
        end)
        Connect(Btn.MouseLeave, function()
            Btn.BackgroundTransparency = 1
        end)
        Connect(Btn.Activated, function()
            KeyPicker:SetValue({ nil, Mode })
            ClosePopup(ModePopup)
        end)
    end
    local function OpenModeMenu()
        for _, Update in pairs(ModeRows) do
            Update()
        end
        OpenPopup(ModePopup, "Right")
    end

    local LongPressed = false
    Connect(Chip.Activated, function()
        if LongPressed then
            LongPressed = false
            return
        end
        if Library.IsMobile then
            -- No keyboard on mobile: tapping the chip acts as pressing the key.
            KeyPicker:Press(true)
            if KeyPicker.Mode == "Hold" then
                task.delay(0.15, function()
                    KeyPicker:Press(false)
                end)
            end
            return
        end
        if Library.Picking and Library.Picking ~= KeyPicker then
            Library.Picking:StopPicking(nil)
        end
        KeyPicker.Picking = true
        Library.Picking = KeyPicker
        KeyPicker:Display()
    end)
    Connect(Chip.MouseButton2Click, OpenModeMenu)
    Connect(Chip.InputBegan, function(Input)
        if Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local Started = os.clock()
        local Conn
        Conn = Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                Conn:Disconnect()
            end
        end)
        task.delay(0.45, function()
            if Input.UserInputState ~= Enum.UserInputState.End and os.clock() - Started >= 0.44 then
                LongPressed = true
                OpenModeMenu()
            end
        end)
    end)

    KeyPicker:Display()
    AddTooltip(Chip, Library.IsMobile and nil or "Click to rebind, right click for mode")
    function KeyPicker:SetMenuVisibility(Value)
        KeyPicker.MenuVisible = Value
        Library:RefreshKeybindList()
    end

    table.insert(Library.KeyPickers, KeyPicker)
    task.defer(function()
        Library:RefreshKeybindList()
    end)
    table.insert(Parent.Addons, KeyPicker)
    if Idx then
        Options[Idx] = KeyPicker
    end
    return Parent
end

Connect(UserInputService.InputBegan, function(Input)
    if Library.Unloaded then
        return
    end
    local Picking = Library.Picking
    if Picking then
        local Key = InputToKey(Input)
        if not Key then
            return
        end
        if Key == "Escape" then
            Picking:StopPicking(nil)
        elseif Key == "Backspace" or Key == "Delete" then
            Picking:StopPicking("None")
        else
            Picking:StopPicking(Key)
        end
        return
    end
    if IsTyping() then
        return
    end
    local Key = InputToKey(Input)
    if not Key then
        return
    end

    local ToggleKey = Library.ToggleKeybind
    if typeof(ToggleKey) == "EnumItem" then
        if Input.KeyCode == ToggleKey then
            Library:Toggle()
        end
    elseif type(ToggleKey) == "table" and ToggleKey.Value == Key then
        Library:Toggle()
    end

    for _, KeyPicker in ipairs(Library.KeyPickers) do
        if KeyPicker.Value == Key and KeyPicker.Value ~= "None" then
            KeyPicker:Press(true)
        end
    end
end)

Connect(UserInputService.InputEnded, function(Input)
    local Key = InputToKey(Input)
    if not Key then
        return
    end
    for _, KeyPicker in ipairs(Library.KeyPickers) do
        if KeyPicker.Value == Key and KeyPicker.Mode == "Hold" and KeyPicker.Held then
            KeyPicker:Press(false)
        end
    end
end)

--// ColorPicker (addon) \\--
local RainbowSequence
do
    local Points = {}
    for I = 0, 6 do
        table.insert(Points, ColorSequenceKeypoint.new(I / 6, Color3.fromHSV(I / 6 % 1, 1, 1)))
    end
    Points[#Points] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0.999, 1, 1))
    RainbowSequence = ColorSequence.new(Points)
end

function BaseAddons:AddColorPicker(Idx, Info)
    Info = Info or {}
    local Parent = self
    local ColorPicker = {
        Type = "ColorPicker",
        Value = Info.Default or Scheme.Primary,
        Title = Info.Title or Parent.Text,
        Callback = Info.Callback,
        Changed = Info.Changed,
        Transparency = Info.Transparency or 0,
    }
    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = ColorPicker.Value:ToHSV()

    local Swatch = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = ColorPicker.Value,
        Size = UDim2.fromOffset(Library.IsMobile and 30 or 24, Library.IsMobile and 22 or 16),
        LayoutOrder = 2,
        Parent = Parent.AddonHolder,
    }, { Corner(5), Stroke(Color3.new(1, 1, 1), 0.85) })

    local Menu = Create("Frame", {
        BackgroundColor3 = "Card",
        Size = UDim2.fromOffset(232, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 50,
        Parent = ScreenGui,
    }, { Corner(10), Stroke(), Pad(10, 10, 10, 10), List(Enum.FillDirection.Vertical, 8) })
    NewScale(Menu)

    if ColorPicker.Title and ColorPicker.Title ~= "" then
        Text({
            Text = ColorPicker.Title,
            FontFace = "Medium",
            Size = UDim2.new(1, 0, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd,
            LayoutOrder = 1,
            Parent = Menu,
        })
    end

    local Area = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 2, Parent = Menu })
    local SV = Create("Frame", {
        BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1),
        Size = UDim2.new(1, -24, 1, 0),
        Parent = Area,
    }, { Corner(6) })
    Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = SV }, {
        Corner(6),
        Create("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
    })
    Create("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), Parent = SV }, {
        Corner(6),
        Create("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90 }),
    })
    local SVCursor = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(12, 12),
        ZIndex = 3,
        Parent = SV,
    }, { Corner(99), Stroke(Color3.new(1, 1, 1), 0, 2) })
    local SVHit = Create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = SV })

    local HueBar = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 14, 1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Parent = Area,
    }, { Corner(7), Create("UIGradient", { Color = RainbowSequence, Rotation = 90 }) })
    local HueCursor = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(1, 4, 0, 6),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 3,
        Parent = HueBar,
    }, { Corner(3), Stroke(Color3.new(0, 0, 0), 0.6) })
    local HueHit = Create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 8, 1, 0), Position = UDim2.fromOffset(-4, 0), ZIndex = 4, Parent = HueBar })

    local Bottom = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3, Parent = Menu })
    local Preview = Create("Frame", {
        BackgroundColor3 = ColorPicker.Value,
        Size = UDim2.fromOffset(30, 30),
        Parent = Bottom,
    }, { Corner(6), Stroke(Color3.new(1, 1, 1), 0.85) })
    local HexFrame = Create("Frame", {
        BackgroundColor3 = "Background",
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -38, 1, 0),
        Parent = Bottom,
    }, { Corner(6), Stroke() })
    local HexBox = Create("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        FontFace = "Mono",
        TextSize = 13,
        TextColor3 = "Foreground",
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Text = "",
        Parent = HexFrame,
    })

    function ColorPicker:Display()
        ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
        SV.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
        SVCursor.Position = UDim2.fromScale(ColorPicker.Sat, 1 - ColorPicker.Vib)
        HueCursor.Position = UDim2.new(0.5, 0, ColorPicker.Hue, 0)
        Swatch.BackgroundColor3 = ColorPicker.Value
        Preview.BackgroundColor3 = ColorPicker.Value
        if not HexBox:IsFocused() then
            HexBox.Text = "#" .. ColorPicker.Value:ToHex():upper()
        end
    end

    local function Fire()
        ColorPicker:Display()
        SafeCallback(ColorPicker.Callback, ColorPicker.Value)
        SafeCallback(ColorPicker.Changed, ColorPicker.Value)
    end

    function ColorPicker:OnChanged(Fn)
        ColorPicker.Changed = Fn
    end
    function ColorPicker:SetHSVFromRGB(Color)
        ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color:ToHSV()
    end
    function ColorPicker:SetValueRGB(Color, Transparency)
        ColorPicker:SetHSVFromRGB(Color)
        ColorPicker.Transparency = Transparency or ColorPicker.Transparency
        Fire()
    end
    function ColorPicker:SetValue(HSV, Transparency)
        if typeof(HSV) == "Color3" then
            return ColorPicker:SetValueRGB(HSV, Transparency)
        end
        ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = HSV[1], HSV[2], HSV[3]
        ColorPicker.Transparency = Transparency or ColorPicker.Transparency
        Fire()
    end

    local DragMode
    local function UpdateFrom(Input)
        local P = PointerPos(Input)
        if DragMode == "SV" then
            ColorPicker.Sat = math.clamp((P.X - SV.AbsolutePosition.X) / SV.AbsoluteSize.X, 0, 1)
            ColorPicker.Vib = 1 - math.clamp((P.Y - SV.AbsolutePosition.Y) / SV.AbsoluteSize.Y, 0, 1)
        elseif DragMode == "Hue" then
            ColorPicker.Hue = math.clamp((P.Y - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 0.999)
        end
        Fire()
    end
    Connect(SVHit.InputBegan, function(Input)
        if IsClick(Input) then
            DragMode = "SV"
            UpdateFrom(Input)
        end
    end)
    Connect(HueHit.InputBegan, function(Input)
        if IsClick(Input) then
            DragMode = "Hue"
            UpdateFrom(Input)
        end
    end)
    Connect(UserInputService.InputChanged, function(Input)
        if DragMode and IsMove(Input) then
            UpdateFrom(Input)
        end
    end)
    Connect(UserInputService.InputEnded, function(Input)
        if IsClick(Input) then
            DragMode = nil
        end
    end)

    Connect(HexBox.FocusLost, function()
        local Ok, Color = pcall(Color3.fromHex, (HexBox.Text:gsub("#", "")))
        if Ok and Color then
            ColorPicker:SetValueRGB(Color)
        else
            ColorPicker:Display()
        end
    end)

    local Popup = { Frame = Menu, Owner = Swatch, Close = function()
        Menu.Visible = false
    end }
    Connect(Swatch.Activated, function()
        if IsPopupOpen(Popup) then
            ClosePopup(Popup)
        else
            OpenPopup(Popup, "Right")
        end
    end)

    ColorPicker:Display()
    table.insert(Parent.Addons, ColorPicker)
    if Idx then
        Options[Idx] = ColorPicker
    end
    return Parent
end

--// Groupboxes \\--
local function NewContainer(Parent, Order)
    return Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = Order or 1,
        Parent = Parent,
    }, { Pad(2, 14, 12, 14), List(Enum.FillDirection.Vertical, 2) })
end

local function NewGroupbox(Tab, Container, Box, Scroller, Name)
    return setmetatable({
        Tab = Tab,
        Container = Container,
        Box = Box,
        Scroller = Scroller,
        Name = Name or "",
        Order = 0,
        Elements = {},
    }, { __index = Funcs })
end

--// Dependency boxes \\--
-- A box whose elements only show while its dependencies hold.
--   local Box = Groupbox:AddDependencyBox()
--   Box:AddSlider(...)
--   Box:SetupDependencies({ { Toggles.AimEnabled, true }, { Options.AimPart, "Head" } })
-- Each entry is { Element, Expected }. Expected may also be a function(Value) -> boolean.
-- All entries must pass. Toggles compare Value; multi dropdowns check Value[Expected].
Library.DependencyBoxes = {}

local function DependencyPasses(Element, Expected)
    if type(Element) ~= "table" or Element.Disabled then
        return false
    end
    if type(Expected) == "function" then
        local Ok, Result = pcall(Expected, Element.Value)
        return Ok and Result == true
    end
    if Element.Type == "Dropdown" and type(Element.Value) == "table" then
        return Element.Value[Expected] == true
    end
    return Element.Value == Expected
end

function Library:UpdateDependencyBoxes()
    for _, Depbox in ipairs(Library.DependencyBoxes) do
        Depbox:Update()
    end
end

local function SetupDepbox(Depbox, Holder)
    Depbox.Dependencies = {}
    Depbox.Visible = false
    Holder.Visible = false

    function Depbox:Update()
        local Show = true
        for _, Dependency in ipairs(Depbox.Dependencies) do
            if not DependencyPasses(Dependency[1], Dependency[2]) then
                Show = false
                break
            end
        end
        Depbox.Visible = Show
        Holder.Visible = Show
    end

    function Depbox:SetupDependencies(Dependencies)
        for _, Dependency in ipairs(Dependencies or {}) do
            assert(type(Dependency) == "table" and Dependency[1] ~= nil and Dependency[2] ~= nil,
                "SetupDependencies expects { { Element, Expected }, ... }")
        end
        Depbox.Dependencies = Dependencies or {}
        Depbox:Update()
    end

    function Depbox:Destroy()
        local Index = table.find(Library.DependencyBoxes, Depbox)
        if Index then
            table.remove(Library.DependencyBoxes, Index)
        end
        Holder:Destroy()
    end

    table.insert(Library.DependencyBoxes, Depbox)
    return Depbox
end

-- Inline box inside this groupbox.
function Funcs:AddDependencyBox()
    local Container = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:NextOrder(),
        Parent = self.Container,
    }, { List(Enum.FillDirection.Vertical, 2) })
    local Depbox = NewGroupbox(self.Tab, Container, self.Box, self.Scroller, self.Name)
    Depbox.Owner = self.Owner
    Depbox.Holder = Container
    if self.Owner and self.Owner.Groupboxes then
        table.insert(self.Owner.Groupboxes, Depbox)
    elseif self.Tab and self.Tab.Groupboxes then
        table.insert(self.Tab.Groupboxes, Depbox)
    end
    return SetupDepbox(Depbox, Container)
end

-- A separate groupbox card placed right under this one, shown only while dependencies hold.
function Funcs:AddDependencyGroupbox(GroupName, IconName)
    assert(self.Owner and self.Owner.CreateGroupboxCard, "AddDependencyGroupbox only works on tab groupboxes")
    local Depbox = self.Owner:CreateGroupboxCard(self.Scroller, self.Box.LayoutOrder + 1, GroupName, IconName)
    Depbox.Holder = Depbox.Box
    return SetupDepbox(Depbox, Depbox.Box)
end

--// Media + custom elements \\--
local function MediaHolder(Groupbox, Height, Visible)
    return Create("Frame", {
        BackgroundColor3 = "Background",
        Size = UDim2.new(1, 0, 0, Height),
        LayoutOrder = Groupbox:NextOrder(),
        Visible = Visible ~= false,
        ClipsDescendants = true,
        Parent = Groupbox.Container,
    }, { Corner(8), Stroke() })
end

local function MediaBase(Element, Holder)
    function Element:SetHeight(Height)
        assert(type(Height) == "number" and Height > 0, "SetHeight expects a positive number")
        Element.Height = Height
        Holder.Size = UDim2.new(1, 0, 0, Height)
    end
    function Element:SetVisible(Value)
        Element.Visible = Value
        Holder.Visible = Value
    end
    function Element:Destroy()
        Holder:Destroy()
    end
    Element.Holder = Holder
end

-- Groupbox:AddImage(Idx, { Image = "rbxassetid://..." | Lucide name, Height = 200, Color, Transparency, ScaleType })
function Funcs:AddImage(Idx, Info)
    Info = Info or {}
    local Image = { Type = "Image", Height = Info.Height or 200, Visible = Info.Visible ~= false }
    local Holder = MediaHolder(self, Image.Height, Image.Visible)
    if Info.BackgroundTransparency then
        Holder.BackgroundTransparency = Info.BackgroundTransparency
    end
    local Label = Create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ScaleType = Info.ScaleType or Enum.ScaleType.Fit,
        ImageColor3 = Info.Color or Color3.new(1, 1, 1),
        ImageTransparency = Info.Transparency or 0,
        Parent = Holder,
    })
    Image.ImageLabel = Label
    MediaBase(Image, Holder)

    function Image:SetImage(Value)
        local Data = Library:GetIcon(Value)
        Label.Image = Data and Data.Url or tostring(Value or "")
        Label.ImageRectOffset = Data and Data.ImageRectOffset or Info.RectOffset or Vector2.zero
        Label.ImageRectSize = Data and Data.ImageRectSize or Info.RectSize or Vector2.zero
        Image.Image = Value
    end
    function Image:SetColor(Color)
        Label.ImageColor3 = Color
    end
    function Image:SetTransparency(Value)
        Label.ImageTransparency = Value
    end
    function Image:SetScaleType(Value)
        Label.ScaleType = Value
    end
    function Image:SetRectOffset(Value)
        Label.ImageRectOffset = Value
    end
    function Image:SetRectSize(Value)
        Label.ImageRectSize = Value
    end

    Image:SetImage(Info.Image)
    self:Register(Holder, Image)
    if Idx then
        Options[Idx] = Image
    end
    return Image
end

-- Groupbox:AddVideo(Idx, { Video = "rbxassetid://...", Looped, Playing, Volume, Height })
function Funcs:AddVideo(Idx, Info)
    Info = Info or {}
    local Video = { Type = "Video", Height = Info.Height or 200, Visible = Info.Visible ~= false }
    local Holder = MediaHolder(self, Video.Height, Video.Visible)
    local Frame = Create("VideoFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Looped = Info.Looped == true,
        Volume = Info.Volume or 1,
        Parent = Holder,
    })
    Video.VideoFrame = Frame
    MediaBase(Video, Holder)

    function Video:SetVideo(Value)
        Frame.Video = tostring(Value or "")
    end
    function Video:SetLooped(Value)
        Frame.Looped = Value
    end
    function Video:SetVolume(Value)
        Frame.Volume = Value
    end
    function Video:SetPlaying(Value)
        Frame.Playing = Value
    end
    function Video:Play()
        Frame:Play()
    end
    function Video:Pause()
        Frame:Pause()
    end

    Video:SetVideo(Info.Video)
    if Info.Playing then
        Frame.Playing = true
    end
    self:Register(Holder, Video)
    if Idx then
        Options[Idx] = Video
    end
    return Video
end

-- Groupbox:AddViewport(Idx, { Object = Model|BasePart, Clone = true, AutoFocus = true, Interactive = false, Height = 200 })
function Funcs:AddViewport(Idx, Info)
    Info = Info or {}
    local Viewport = {
        Type = "Viewport",
        Height = Info.Height or 200,
        Visible = Info.Visible ~= false,
        Interactive = Info.Interactive == true,
        Yaw = 0,
        Pitch = -0.2,
        Distance = 10,
    }
    local Holder = MediaHolder(self, Viewport.Height, Viewport.Visible)
    local Frame = Create("ViewportFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Ambient = Color3.fromRGB(180, 180, 190),
        LightColor = Color3.fromRGB(255, 255, 255),
        Parent = Holder,
    })
    local Camera = Info.Camera or Instance.new("Camera")
    Camera.FieldOfView = 50
    Camera.Parent = Frame
    Frame.CurrentCamera = Camera
    Viewport.ViewportFrame, Viewport.Camera = Frame, Camera
    MediaBase(Viewport, Holder)

    local function Pivot()
        local Object = Viewport.Object
        if not Object then
            return Vector3.zero
        end
        if Object:IsA("Model") then
            return Object:GetPivot().Position
        end
        return Object.Position
    end

    local function Apply()
        local Rotation = CFrame.Angles(0, Viewport.Yaw, 0) * CFrame.Angles(Viewport.Pitch, 0, 0)
        local Target = Viewport.LookTarget or Pivot()
        Camera.CFrame = CFrame.new(Target + Rotation:VectorToWorldSpace(Vector3.new(0, 0, Viewport.Distance)), Target)
    end

    function Viewport:Focus()
        local Object = Viewport.Object
        if not Object then
            return
        end
        local Size = Object:IsA("Model") and Object:GetExtentsSize() or Object.Size
        Viewport.Distance = math.max(Size.Magnitude * 1.1, 2)
        Viewport.LookTarget = nil
        Apply()
    end
    function Viewport:SetObject(Object, Clone)
        if Viewport.Object then
            Viewport.Object:Destroy()
        end
        if not Object then
            Viewport.Object = nil
            return
        end
        if Clone ~= false then
            local Archivable = Object.Archivable
            Object.Archivable = true
            Object = Object:Clone()
            Object.Archivable = Archivable
        end
        Object.Parent = Frame
        Viewport.Object = Object
        if Info.AutoFocus ~= false then
            Viewport:Focus()
        end
    end
    function Viewport:SetCamera(NewCamera)
        Camera = NewCamera
        Camera.Parent = Frame
        Frame.CurrentCamera = Camera
        Viewport.Camera = Camera
    end
    function Viewport:SetCameraCFrame(CF)
        Camera.CFrame = CF
    end
    function Viewport:GetCameraCFrame()
        return Camera.CFrame
    end
    function Viewport:Rotate(Yaw, Pitch)
        Viewport.Yaw += Yaw or 0
        Viewport.Pitch = math.clamp(Viewport.Pitch + (Pitch or 0), -1.4, 1.4)
        Apply()
    end
    function Viewport:Zoom(Amount)
        Viewport.Distance = math.max(1, Viewport.Distance - Amount)
        Apply()
    end
    function Viewport:SetDistance(Value)
        Viewport.Distance = math.max(1, Value)
        Apply()
    end
    function Viewport:GetDistance()
        return Viewport.Distance
    end
    function Viewport:LookAt(Position)
        Viewport.LookTarget = Position
        Apply()
    end
    function Viewport:SetFieldOfView(Value)
        Camera.FieldOfView = Value
    end
    function Viewport:SetInteractive(Value)
        Viewport.Interactive = Value
    end

    -- Drag to orbit, scroll to zoom.
    local Hit = Create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = Holder })
    local Dragging, Last = false, nil
    Connect(Hit.InputBegan, function(Input)
        if Viewport.Interactive and IsClick(Input) then
            Dragging, Last = true, PointerPos(Input)
            if self.Scroller then
                self.Scroller.ScrollingEnabled = false
            end
        end
    end)
    Connect(UserInputService.InputChanged, function(Input)
        if Dragging and IsMove(Input) then
            local Pos = PointerPos(Input)
            local Delta = Pos - Last
            Last = Pos
            Viewport:Rotate(-Delta.X * 0.01, -Delta.Y * 0.01)
        elseif Viewport.Interactive and Input.UserInputType == Enum.UserInputType.MouseWheel and IsOver(Holder, PointerPos(Input)) then
            Viewport:Zoom(Input.Position.Z * Viewport.Distance * 0.1)
        end
    end)
    Connect(UserInputService.InputEnded, function(Input)
        if Dragging and IsClick(Input) then
            Dragging = false
            if self.Scroller then
                self.Scroller.ScrollingEnabled = true
            end
        end
    end)

    if Info.Object then
        Viewport:SetObject(Info.Object, Info.Clone)
    end
    self:Register(Holder, Viewport)
    if Idx then
        Options[Idx] = Viewport
    end
    return Viewport
end

-- Put your own GuiObject inside a groupbox: Groupbox:AddUIPassthrough(Idx, { Instance = Frame, Height = 40 })
function Funcs:AddUIPassthrough(Idx, Info)
    Info = Info or {}
    assert(typeof(Info.Instance) == "Instance" and Info.Instance:IsA("GuiBase2d"), "AddUIPassthrough needs Info.Instance (a GuiObject)")
    local Passthrough = { Type = "UIPassthrough", Height = Info.Height or 24, Visible = Info.Visible ~= false }
    local Holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Passthrough.Height),
        LayoutOrder = self:NextOrder(),
        Visible = Passthrough.Visible,
        Parent = self.Container,
    })
    MediaBase(Passthrough, Holder)
    function Passthrough:SetInstance(Instance)
        if Passthrough.Instance and Passthrough.Instance ~= Instance then
            Passthrough.Instance.Parent = nil
        end
        Passthrough.Instance = Instance
        Instance.Parent = Holder
    end
    Passthrough:SetInstance(Info.Instance)
    self:Register(Holder, Passthrough)
    if Idx then
        Options[Idx] = Passthrough
    end
    return Passthrough
end

--// Settings addon (gear that opens a small panel of extra options) \\--
-- Toggle:AddSettings() / Label:AddSettings() returns a groupbox-like panel:
--   local S = Toggles.Esp:AddSettings()  S:AddSlider("EspRange", {...})
function BaseAddons:AddSettings(Info)
    if self.Settings then
        return self.Settings
    end
    Info = Info or {}
    local Parent = self
    assert(Parent.AddonHolder, "AddSettings works on toggles and labels")

    local Gear = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = "Muted",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(M.Chip, M.Chip),
        LayoutOrder = 0,
        Parent = Parent.AddonHolder,
    }, { Corner(5) })
    local GearIcon = Icon("settings-2", 14, "MutedForeground", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Parent = Gear,
    })

    local Width = Info.Width or 240
    local Menu = Create("Frame", {
        BackgroundColor3 = "Card",
        Size = UDim2.fromOffset(Width, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 50,
        Parent = ScreenGui,
    }, { Corner(10), Stroke() })
    NewScale(Menu)
    local Container = NewContainer(Menu, 1)
    Container:FindFirstChildOfClass("UIPadding").PaddingTop = UDim.new(0, 10)

    local Settings = NewGroupbox(nil, Container, Menu, nil, Parent.Text)
    Settings.Type = "Settings"
    Settings.Parent = Parent
    Settings.Menu = Menu
    Settings.Gear = Gear
    local Popup = { Frame = Menu, Owner = Gear, Close = function()
        Menu.Visible = false
        GearIcon.ImageColor3 = Scheme.MutedForeground
    end }

    function Settings:Open()
        if Parent.Disabled then
            return
        end
        OpenPopup(Popup, "Right")
        GearIcon.ImageColor3 = Scheme.Foreground
    end
    function Settings:Close()
        if IsPopupOpen(Popup) then
            ClosePopup(Popup)
        end
    end
    function Settings:Toggle()
        if IsPopupOpen(Popup) then
            Settings:Close()
        else
            Settings:Open()
        end
    end
    function Settings:SetWidth(Value)
        Menu.Size = UDim2.fromOffset(Value or 240, 0)
    end
    function Settings:Destroy()
        Settings:Close()
        Gear:Destroy()
        Menu:Destroy()
        Parent.Settings = nil
    end

    Connect(Gear.MouseEnter, function()
        Gear.BackgroundTransparency = 0
    end)
    Connect(Gear.MouseLeave, function()
        Gear.BackgroundTransparency = 1
    end)
    Connect(Gear.Activated, function()
        Settings:Toggle()
    end)

    Parent.Settings = Settings
    return Settings
end

--// Window \\--
function Library:CreateWindow(Info)
    Info = Info or {}
    local Window = {
        Tabs = {},
        ActiveTab = nil,
        Title = Info.Title or "Nemesis",
        Footer = Info.Footer or "",
    }
    Library.Window = Window
    if Info.ToggleKeybind then
        Library.ToggleKeybind = Info.ToggleKeybind
    end
    if Info.ForceCheckbox ~= nil then
        Library.ForceCheckbox = Info.ForceCheckbox
    end
    if Info.StreamerMode ~= nil then
        Library.StreamerMode = Info.StreamerMode == true
    end

    local W, H = M.Width, M.Height
    if not Library.IsMobile and typeof(Info.Size) == "UDim2" then
        W, H = Info.Size.X.Offset, Info.Size.Y.Offset
    elseif Library.IsMobile and typeof(Info.MobileSize) == "UDim2" then
        W, H = Info.MobileSize.X.Offset, Info.MobileSize.Y.Offset
    end
    local SidebarW = Info.SidebarWidth or M.Sidebar

    local Main = Create("Frame", {
        Name = "Main",
        Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = "Background",
        Visible = false,
        Parent = ScreenGui,
    }, { Corner(12), Stroke() })
    local MainScale = NewScale(Main)
    Window.Main = Main

    -- Fit the window on screen. Desktop stays at 1x unless Info.Scale is given.
    local function FitScale()
        local View = ScreenGui.AbsoluteSize
        if View.X <= 0 then
            return
        end
        if genv.NemesisPreviewScale then
            Library:SetScale(genv.NemesisPreviewScale)
        elseif Library.IsMobile then
            local S = math.min(View.X * 0.94 / Main.Size.X.Offset, View.Y * 0.9 / Main.Size.Y.Offset)
            Library:SetScale(math.clamp(S, 0.5, 1.3))
        else
            Library:SetScale(Info.Scale or 1)
        end
    end
    local function Center()
        local S = Library.Scale
        local View = ScreenGui.AbsoluteSize
        if View.X <= 0 then
            View = workspace.CurrentCamera.ViewportSize
        end
        Main.Position = UDim2.fromOffset(
            math.floor((View.X - Main.Size.X.Offset * S) / 2),
            math.floor((View.Y - Main.Size.Y.Offset * S) / 2)
        )
    end
    FitScale()
    Center()
    Connect(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"), function()
        FitScale()
        if Library.IsMobile then
            Center()
        end
    end)

    --// Sidebar
    local Sidebar = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, SidebarW, 1, 0),
        Parent = Main,
    }, { Pad(12, 10, 10, 10) })
    Create("Frame", {
        BackgroundColor3 = "Border",
        Position = UDim2.fromOffset(SidebarW, 0),
        Size = UDim2.new(0, 1, 1, 0),
        Parent = Main,
    })

    local BrandH = 50
    local Brand = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, BrandH), Parent = Sidebar })
    -- Wordmark: bold title with a violet wave sweeping across white text.
    local TitleLabel = Text({
        Text = Window.Title,
        FontFace = "Bold",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 26,
        Position = UDim2.fromOffset(4, 0),
        Size = UDim2.new(1, -4, 0, 28),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Brand,
    })
    local Waves = {}
    local function AddWave(Label)
        local Gradient = Create("UIGradient", {
            Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.42, Color3.fromRGB(196, 181, 253)),
            ColorSequenceKeypoint.new(0.5, Scheme.Primary),
            ColorSequenceKeypoint.new(0.58, Color3.fromRGB(196, 181, 253)),
            ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
            }),
            Rotation = 15,
            Offset = Vector2.new(-1, 0),
            Parent = Label,
        })
        table.insert(Waves, { Gradient = Gradient, Label = Label })
        -- Keep the wave's centre colour in sync with the theme's primary colour.
        AddRefresher(function()
            local Points = Gradient.Color.Keypoints
            Points[4] = ColorSequenceKeypoint.new(0.5, Scheme.Primary)
            Gradient.Color = ColorSequence.new(Points)
        end)
    end
    AddWave(TitleLabel)
    local WaveSpeed = Info.WaveSpeed or 2.6 -- seconds per sweep
    Connect(RunService.RenderStepped, function()
        local T = (os.clock() % WaveSpeed) / WaveSpeed
        for _, Wave in ipairs(Waves) do
            -- Only animate labels that are actually on screen.
            if Wave.Label.Visible and (Wave.Label:IsDescendantOf(Main) and Main.Visible or not Wave.Label:IsDescendantOf(Main)) then
                Wave.Gradient.Offset = Vector2.new(-1 + T * 2, 0)
            end
        end
    end)

    -- Status line: the game Nemesis is running in.
    local FooterLabel = Text({
        Text = Window.Footer ~= "" and Window.Footer or "Universal",
        TextSize = 13,
        TextColor3 = "MutedForeground",
        Position = UDim2.fromOffset(4, 31),
        Size = UDim2.new(1, -4, 0, 16),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Brand,
    })
    if Info.ShowGame ~= false then
        task.spawn(function()
            local Ok, Product = pcall(function()
                return GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
            end)
            if Ok and Product and type(Product.Name) == "string" and Product.Name ~= "" then
                FooterLabel.Text = "Playing: " .. Product.Name
            end
        end)
    end

    local SearchFrame = Create("Frame", {
        BackgroundColor3 = "Card",
        Position = UDim2.fromOffset(0, BrandH + 12),
        Size = UDim2.new(1, 0, 0, Library.IsMobile and 34 or 32),
        Parent = Sidebar,
    }, { Corner(7) })
    local SearchStroke = Stroke()
    SearchStroke.Parent = SearchFrame
    Icon("search", 14, "MutedForeground", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Parent = SearchFrame,
    })
    local SearchBox = Create("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(32, 0),
        Size = UDim2.new(1, -40, 1, 0),
        FontFace = "Regular",
        TextSize = 14,
        TextColor3 = "Foreground",
        PlaceholderText = "Search",
        PlaceholderColor3 = "Subtle",
        Text = "",
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = SearchFrame,
    })
    Connect(SearchBox.Focused, function()
        Tween(SearchStroke, { Color = Scheme.Primary })
    end)
    Connect(SearchBox.FocusLost, function()
        Tween(SearchStroke, { Color = Scheme.Border })
    end)

    local ShowUser = Info.ShowUser ~= false
    local TabTop = BrandH + 12 + (Library.IsMobile and 34 or 32) + 12
    local TabList = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, TabTop),
        Size = UDim2.new(1, 0, 1, -(TabTop + (ShowUser and 66 or 0))),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = Sidebar,
    }, { List(Enum.FillDirection.Vertical, 2) })

    if ShowUser then
        local User = Create("Frame", {
            BackgroundColor3 = "Card",
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 56),
            Parent = Sidebar,
        }, { Corner(10), Stroke() })
        local Avatar = Create("ImageLabel", {
            BackgroundColor3 = "Muted",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.fromOffset(36, 36),
            Parent = User,
        }, { Corner(99) })
        task.spawn(function()
            local Ok, Image = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
            end)
            if Ok then
                Avatar.Image = Image
            end
        end)
        -- Streamer mode hides the avatar image itself (a cover on top would let the
        -- picture's anti-aliased edge peek out) and shows an eye-off icon instead.
        local AvatarCover = Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            ZIndex = 2,
            Parent = Avatar,
        })
        Icon("eye-off", 16, "MutedForeground", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            ZIndex = 3,
            Parent = AvatarCover,
        })
        local NameLabel = Text({
            Text = LocalPlayer.DisplayName,
            FontFace = "Medium",
            TextSize = 15,
            Position = UDim2.fromOffset(56, 9),
            Size = UDim2.new(1, -64, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = User,
        })
        local HandleLabel = Text({
            Text = "@" .. LocalPlayer.Name,
            TextSize = 13,
            TextColor3 = "MutedForeground",
            Position = UDim2.fromOffset(56, 29),
            Size = UDim2.new(1, -64, 0, 16),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = User,
        })

        function Window:UpdateUser()
            local Hidden = Library.StreamerMode
            AvatarCover.Visible = Hidden
            Avatar.ImageTransparency = Hidden and 1 or 0
            Avatar.BackgroundColor3 = Hidden and Scheme.Hover or Scheme.Muted
            NameLabel.Text = Hidden and "Hidden" or LocalPlayer.DisplayName
            NameLabel.TextColor3 = Hidden and Scheme.MutedForeground or Scheme.Foreground
            HandleLabel.Text = Hidden and "Streamer mode" or ("@" .. LocalPlayer.Name)
        end
        Window:UpdateUser()
    end

    --// Content
    local Content = Create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(SidebarW + 1, 0),
        Size = UDim2.new(1, -(SidebarW + 1), 1, 0),
        Parent = Main,
    })
    local Topbar = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = Content })
    local Crumb = Text({
        Text = Window.Title,
        TextSize = 13,
        TextColor3 = "MutedForeground",
        Position = UDim2.fromOffset(18, 9),
        Size = UDim2.new(1, -120, 0, 14),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Topbar,
    })
    local PageTitle = Text({
        FontFace = "SemiBold",
        TextSize = 16,
        Position = UDim2.fromOffset(18, 24),
        Size = UDim2.new(1, -120, 0, 18),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Topbar,
    })
    local TopButtons = Create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(0, 32),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = Topbar,
    }, { List(Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })

    local function TopButton(IconName, Order, Callback)
        local Size = Library.IsMobile and 36 or 30
        local Btn = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = "Muted",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(Size, Size),
            LayoutOrder = Order,
            Parent = TopButtons,
        }, { Corner(7) })
        local Img = Icon(IconName, 16, "MutedForeground", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Parent = Btn,
        })
        Connect(Btn.MouseEnter, function()
            Tween(Btn, { BackgroundTransparency = 0 })
            Tween(Img, { ImageColor3 = Scheme.Foreground })
        end)
        Connect(Btn.MouseLeave, function()
            Tween(Btn, { BackgroundTransparency = 1 })
            Tween(Img, { ImageColor3 = Scheme.MutedForeground })
        end)
        Connect(Btn.Activated, Callback)
        return Btn
    end
    TopButton("minus", 1, function()
        Library:Toggle(false)
    end)

    Create("Frame", {
        BackgroundColor3 = "Border",
        Position = UDim2.fromOffset(0, 52),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Content,
    })
    local Pages = Create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 53),
        Size = UDim2.new(1, 0, 1, -53),
        ClipsDescendants = true,
        Parent = Content,
    })

    MakeDraggable(Topbar, Main)
    MakeDraggable(Brand, Main)

    --// Resize grip (desktop)
    if not Library.IsMobile and Info.Resizable ~= false then
        local Grip = Create("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -2, 1, -2),
            Size = UDim2.fromOffset(16, 16),
            ZIndex = 5,
            Parent = Main,
        })
        Icon("move-diagonal-2", 12, "Subtle", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Parent = Grip,
        })
        local Resizing, StartPointer, StartSize = false, nil, nil
        Connect(Grip.InputBegan, function(Input)
            if IsClick(Input) then
                Resizing = true
                StartPointer = PointerPos(Input)
                StartSize = Main.Size
            end
        end)
        Connect(UserInputService.InputChanged, function(Input)
            if Resizing and IsMove(Input) then
                local Delta = (PointerPos(Input) - StartPointer) / Library.Scale
                Main.Size = UDim2.fromOffset(
                    math.max(560, StartSize.X.Offset + Delta.X),
                    math.max(360, StartSize.Y.Offset + Delta.Y)
                )
            end
        end)
        Connect(UserInputService.InputEnded, function(Input)
            if IsClick(Input) then
                Resizing = false
            end
        end)
    end

    --// Mobile open/close button (draggable)
    if Library.IsMobile and Info.ShowMobileButton ~= false then
        local Inset = GuiService:GetGuiInset()
        -- A pill with the waving wordmark. Tap to open/close, drag to move.
        local Float = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = "Card",
            Position = UDim2.fromOffset(12, Inset.Y + 12),
            Size = UDim2.fromOffset(0, 50),
            AutomaticSize = Enum.AutomaticSize.X,
            ZIndex = 120,
            Parent = ScreenGui,
        }, { Corner(99), Stroke(), Pad(0, 22, 0, 22) })
        local FloatLabel = Text({
            Text = Window.Title,
            FontFace = "Bold",
            TextSize = 22,
            TextColor3 = Color3.new(1, 1, 1),
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            Parent = Float,
        })
        AddWave(FloatLabel)
        NewScale(Float)
        local DragState = MakeDraggable(Float, Float)
        Connect(Float.Activated, function()
            if DragState.Moved < 8 then
                Library:Toggle()
            end
        end)
        Window.MobileButton = Float
    end

    --// Search
    function Library:UpdateSearch(Query)
        Query = (Query or ""):lower():match("^%s*(.-)%s*$")
        for _, Tab in ipairs(Window.Tabs) do
            local BoxVisible = {}
            for _, Groupbox in ipairs(Tab.Groupboxes) do
                local NameMatch = Query == "" or Groupbox.Name:lower():find(Query, 1, true) ~= nil
                local Any = false
                for _, Entry in ipairs(Groupbox.Elements) do
                    local Element = Entry.Element
                    local Allowed = not (Element and Element.Visible == false)
                    local Label = Element and Element.Text or ""
                    local Show = Allowed and (NameMatch or (type(Label) == "string" and Label:lower():find(Query, 1, true) ~= nil))
                    Entry.Holder.Visible = Show and true or false
                    if Show then
                        Any = true
                    end
                end
                BoxVisible[Groupbox.Box] = BoxVisible[Groupbox.Box] or Any or NameMatch
            end
            for Box, Visible in pairs(BoxVisible) do
                Box.Visible = Visible and true or false
            end
        end
    end
    Connect(SearchBox:GetPropertyChangedSignal("Text"), function()
        Library:UpdateSearch(SearchBox.Text)
    end)

    --// Tabs
    Library.Tabs = Library.Tabs or {}

    -- Accepts (Name, Icon, Description) or ({ Name, Icon, Description, Tooltip, Order, SubTabs }).
    local function ParseTabArgs(Name, IconName, Description, Order)
        if type(Name) == "table" then
            return Name
        end
        return { Name = Name, Icon = IconName, Description = Description, Order = Order }
    end

    -- Two scrolling columns inside Page, plus the groupbox/tabbox methods on Owner.
    -- Owner is a tab or a sub tab; Groupboxes is the list search walks.
    local function BuildColumns(Owner, Page, RootTab)
        local function Column(X)
            return Create("ScrollingFrame", {
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(X, 0),
                Size = UDim2.fromScale(0.5, 1),
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = "Border",
                ScrollingDirection = Enum.ScrollingDirection.Y,
                Parent = Page,
            }, {
                Pad(14, X == 0 and 7 or 14, 14, X == 0 and 14 or 7),
                List(Enum.FillDirection.Vertical, 12),
            })
        end
        local Left, Right = Column(0), Column(0.5)
        Owner.Left, Owner.Right = Left, Right
        Owner.BoxCount = 0

        local function NextBoxOrder()
            Owner.BoxCount += 1
            return Owner.BoxCount * 10
        end

        local function NewCard(Parent, Order)
            return Create("Frame", {
                BackgroundColor3 = "Card",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = Order,
                Parent = Parent,
            }, { Corner(10), Stroke(), List(Enum.FillDirection.Vertical, 0) })
        end

        -- Builds a titled groupbox card. Used for normal and dependency groupboxes.
        function Owner:CreateGroupboxCard(Parent, Order, GroupName, IconName)
            local Box = NewCard(Parent, Order)
            local Header = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 0, Parent = Box })
            local HeaderIcon, HasHeaderIcon = Icon(IconName, 15, "PrimaryHover", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 14, 0.5, 0),
                Parent = Header,
            })
            if not HasHeaderIcon then
                HeaderIcon:Destroy()
            end
            local Title = Text({
                Text = GroupName or "",
                FontFace = "Medium",
                TextSize = 15,
                Position = UDim2.fromOffset(HasHeaderIcon and 36 or 14, 0),
                Size = UDim2.new(1, -50, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = Header,
            })
            if (GroupName or "") == "" then
                Header.Visible = false
            end
            local Groupbox = NewGroupbox(RootTab, NewContainer(Box, 1), Box, Parent, GroupName)
            Groupbox.Owner = Owner
            Groupbox.TitleLabel = Title
            function Groupbox:SetTitle(Value)
                Groupbox.Name = Value
                Title.Text = Value
                Header.Visible = Value ~= ""
            end
            function Groupbox:SetVisible(Value)
                Groupbox.Visible = Value
                Box.Visible = Value
            end
            table.insert(Owner.Groupboxes, Groupbox)
            return Groupbox
        end

        function Owner:AddGroupbox(GroupInfo)
            local Parent = (GroupInfo.Side == 2 or GroupInfo.Side == "Right") and Right or Left
            return Owner:CreateGroupboxCard(Parent, NextBoxOrder(), GroupInfo.Name, GroupInfo.IconName or GroupInfo.Icon)
        end
        function Owner:AddLeftGroupbox(GroupName, GroupIcon)
            return Owner:AddGroupbox({ Side = 1, Name = GroupName, IconName = GroupIcon })
        end
        function Owner:AddRightGroupbox(GroupName, GroupIcon)
            return Owner:AddGroupbox({ Side = 2, Name = GroupName, IconName = GroupIcon })
        end

        -- A card with a segmented control on top that switches between sub tabs.
        function Owner:AddTabbox(TabboxInfo)
            TabboxInfo = TabboxInfo or {}
            local Parent = (TabboxInfo.Side == 2 or TabboxInfo.Side == "Right") and Right or Left
            local Box = NewCard(Parent, NextBoxOrder())
            local Header = Create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, Library.IsMobile and 52 or 46),
                LayoutOrder = 0,
                Parent = Box,
            }, { Pad(8, 8, 6, 8) })
            local Segment = Create("Frame", {
                BackgroundColor3 = "Muted",
                Size = UDim2.fromScale(1, 1),
                Parent = Header,
            }, { Corner(8), Stroke(), Pad(3, 3, 3, 3), List(Enum.FillDirection.Horizontal, 0) })

            local Tabbox = { Tabs = {}, Box = Box }
            function Tabbox:AddTab(SubName)
                local SubButton = Create("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    BackgroundColor3 = "Background",
                    BackgroundTransparency = 1,
                    LayoutOrder = #Tabbox.Tabs + 1,
                    Parent = Segment,
                }, { Corner(6) })
                local SubLabel = Text({
                    Text = SubName,
                    FontFace = "Medium",
                    TextSize = 14,
                    TextColor3 = "MutedForeground",
                    TextXAlignment = Enum.TextXAlignment.Center,
                    Size = UDim2.fromScale(1, 1),
                    Parent = SubButton,
                })
                local Container = NewContainer(Box, 1)
                Container.Visible = false
                local Sub = NewGroupbox(RootTab, Container, Box, Parent, SubName)
                Sub.Owner = Owner

                function Sub:Show()
                    for _, Other in ipairs(Tabbox.Tabs) do
                        local On = Other == Sub
                        Other.Container.Visible = On
                        Tween(Other.Button, { BackgroundTransparency = On and 0 or 1 })
                        Tween(Other.Label, { TextColor3 = On and Scheme.Foreground or Scheme.MutedForeground })
                    end
                    Tabbox.ActiveTab = Sub
                end
                Sub.Button, Sub.Label = SubButton, SubLabel
                Connect(SubButton.Activated, function()
                    Sub:Show()
                end)

                table.insert(Tabbox.Tabs, Sub)
                table.insert(Owner.Groupboxes, Sub)
                local N = #Tabbox.Tabs
                for _, Other in ipairs(Tabbox.Tabs) do
                    Other.Button.Size = UDim2.fromScale(1 / N, 1)
                end
                if N == 1 then
                    Sub:Show()
                end
                return Sub
            end
            AddRefresher(function()
                if Tabbox.ActiveTab then
                    Tabbox.ActiveTab:Show()
                end
            end)
            return Tabbox
        end
        function Owner:AddLeftTabbox()
            return Owner:AddTabbox({ Side = 1 })
        end
        function Owner:AddRightTabbox()
            return Owner:AddTabbox({ Side = 2 })
        end
    end

    -- Sidebar button + page + show/hide plumbing shared by every kind of tab.
    local function CreateTabShell(Info)
        local Name = Info.Name or "Tab"
        local Tab = {
            Name = Name,
            Description = Info.Description,
            Groupboxes = {},
            Window = Window,
            Visible = true,
        }

        local Button = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = "Muted",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, M.Tab),
            LayoutOrder = Info.Order or (#Window.Tabs + 1),
            Parent = TabList,
        }, { Corner(7) })
        local TabIcon, HasIcon = Icon(Info.Icon, 16, "MutedForeground", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 10, 0.5, 0),
            Parent = Button,
        })
        if not HasIcon then
            TabIcon.Visible = false
        end
        local TabLabel = Text({
            Text = Name,
            FontFace = "Medium",
            TextColor3 = "MutedForeground",
            Position = UDim2.fromOffset(HasIcon and 34 or 12, 0),
            Size = UDim2.new(1, -(HasIcon and 40 or 18), 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = Button,
        })
        AddTooltip(Button, Info.Tooltip)

        local Page = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = Pages })
        Tab.Button, Tab.Page = Button, Page

        local Hovered = false
        local function Refresh()
            local Active = Window.ActiveTab == Tab
            if Active then
                Tween(Button, { BackgroundColor3 = Scheme.Primary, BackgroundTransparency = 0.86 })
            else
                Tween(Button, { BackgroundColor3 = Scheme.Muted, BackgroundTransparency = Hovered and 0 or 1 })
            end
            Tween(TabLabel, { TextColor3 = (Active or Hovered) and Scheme.Foreground or Scheme.MutedForeground })
            Tween(TabIcon, { ImageColor3 = Active and Scheme.PrimaryHover or (Hovered and Scheme.Foreground or Scheme.MutedForeground) })
        end
        Tab.Refresh = Refresh
        AddRefresher(Refresh)

        function Tab:Show()
            CloseAllPopups()
            local Previous = Window.ActiveTab
            Window.ActiveTab = Tab
            for _, Other in ipairs(Window.Tabs) do
                Other.Page.Visible = Other == Tab
                Other.Refresh()
            end
            PageTitle.Text = Tab.Name
            Crumb.Text = Tab.Description or Window.Title
            if Previous ~= Tab then
                Page.Position = UDim2.fromOffset(0, 8)
                Tween(Page, { Position = UDim2.fromOffset(0, 0) }, 0.2)
            end
        end
        Tab.Select = Tab.Show

        function Tab:Hide()
            if Window.ActiveTab == Tab then
                for _, Other in ipairs(Window.Tabs) do
                    if Other ~= Tab and Other.Visible then
                        return Other:Show()
                    end
                end
            end
        end

        -- Hides the sidebar button (e.g. until a key is entered).
        function Tab:SetVisible(Value)
            Tab.Visible = Value
            Button.Visible = Value
            if not Value then
                Tab:Hide()
            end
        end

        function Tab:SetOrder(Order)
            Button.LayoutOrder = Order
        end

        function Tab:SetTooltip(Content)
            AddTooltip(Button, Content)
        end

        function Tab:SetName(Value)
            Tab.Name = Value
            TabLabel.Text = Value
            if Window.ActiveTab == Tab then
                PageTitle.Text = Value
            end
        end

        function Tab:Destroy()
            Tab:Hide()
            local Index = table.find(Window.Tabs, Tab)
            if Index then
                table.remove(Window.Tabs, Index)
            end
            Library.Tabs[Tab.Name] = nil
            Button:Destroy()
            Page:Destroy()
        end

        Connect(Button.MouseEnter, function()
            Hovered = true
            Refresh()
        end)
        Connect(Button.MouseLeave, function()
            Hovered = false
            Refresh()
        end)
        Connect(Button.Activated, function()
            Tab:Show()
        end)

        table.insert(Window.Tabs, Tab)
        Library.Tabs[Name] = Tab
        return Tab
    end

    local function FinishTab(Tab)
        if not Window.ActiveTab then
            Tab:Show()
        else
            Tab.Refresh()
        end
        return Tab
    end

    -- Window:AddTab("Combat", "crosshair", "Description")
    -- Window:AddTab({ Name = "Combat", Icon = "crosshair", SubTabs = true }) then Tab:AddSubTab("Aim")
    function Window:AddTab(Name, IconName, Description, Order)
        local Info = ParseTabArgs(Name, IconName, Description, Order)
        local Tab = CreateTabShell(Info)

        if Info.SubTabs then
            local BarH = Library.IsMobile and 50 or 46
            local Bar = Create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, BarH),
                Parent = Tab.Page,
            }, { Pad(12, 14, 0, 14) })
            local Segment = Create("Frame", {
                BackgroundColor3 = "Muted",
                Size = UDim2.fromScale(1, 1),
                Parent = Bar,
            }, { Corner(8), Stroke(), Pad(3, 3, 3, 3), List(Enum.FillDirection.Horizontal, 0) })
            Tab.SubTabs = {}

            function Tab:AddSubTab(SubName, SubIcon)
                local SubInfo = ParseTabArgs(SubName, SubIcon)
                local Sub = { Name = SubInfo.Name, Groupboxes = Tab.Groupboxes, Tab = Tab, Window = Window }
                local SubButton = Create("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    BackgroundColor3 = "Background",
                    BackgroundTransparency = 1,
                    LayoutOrder = #Tab.SubTabs + 1,
                    Parent = Segment,
                }, { Corner(6) })
                local SubLabel = Text({
                    Text = SubInfo.Name,
                    FontFace = "Medium",
                    TextColor3 = "MutedForeground",
                    TextXAlignment = Enum.TextXAlignment.Center,
                    Size = UDim2.fromScale(1, 1),
                    Parent = SubButton,
                })
                local SubPage = Create("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, BarH),
                    Size = UDim2.new(1, 0, 1, -BarH),
                    Visible = false,
                    Parent = Tab.Page,
                })
                Sub.Page, Sub.Button, Sub.Label = SubPage, SubButton, SubLabel
                BuildColumns(Sub, SubPage, Tab)

                function Sub:Show()
                    CloseAllPopups()
                    for _, Other in ipairs(Tab.SubTabs) do
                        local On = Other == Sub
                        Other.Page.Visible = On
                        Tween(Other.Button, { BackgroundTransparency = On and 0 or 1 })
                        Tween(Other.Label, { TextColor3 = On and Scheme.Foreground or Scheme.MutedForeground })
                    end
                    Tab.ActiveSubTab = Sub
                end
                Connect(SubButton.Activated, function()
                    Sub:Show()
                end)

                table.insert(Tab.SubTabs, Sub)
                Library.Tabs[Tab.Name .. "/" .. Sub.Name] = Sub
                local N = #Tab.SubTabs
                for _, Other in ipairs(Tab.SubTabs) do
                    Other.Button.Size = UDim2.fromScale(1 / N, 1)
                end
                if N == 1 then
                    Sub:Show()
                end
                return Sub
            end
            AddRefresher(function()
                if Tab.ActiveSubTab then
                    Tab.ActiveSubTab:Show()
                end
            end)
        else
            BuildColumns(Tab, Tab.Page, Tab)
            function Tab:AddSubTab()
                error("[Nemesis] Tab:AddSubTab needs the tab to be created with { SubTabs = true }", 2)
            end
        end

        return FinishTab(Tab)
    end

    -- A tab with one centred card, for key systems. Add elements to it directly, then
    -- Tab:AddKeyBox(function(Key) ... end) for the input + button.
    function Window:AddKeyTab(Name, IconName, Description, Order)
        local Info = ParseTabArgs(Name, IconName, Description, Order)
        Info.Icon = Info.Icon or "key-round"
        local Tab = CreateTabShell(Info)
        Tab.IsKeyTab = true

        local Center = Create("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -40, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = Tab.Page,
        }, { Create("UISizeConstraint", { MaxSize = Vector2.new(380, math.huge) }) })
        local Card = Create("Frame", {
            BackgroundColor3 = "Card",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = Center,
        }, { Corner(12), Stroke(), List(Enum.FillDirection.Vertical, 0) })
        local Head = Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 0,
            Parent = Card,
        }, { Pad(18, 18, 6, 18), List(Enum.FillDirection.Vertical, 4) })
        Text({ Text = Info.Name or "Key", FontFace = "SemiBold", TextSize = 18, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = Head })
        if Info.Description then
            Text({
                Text = Info.Description,
                TextColor3 = "MutedForeground",
                TextWrapped = true,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 2,
                Parent = Head,
            })
        end
        local Container = NewContainer(Card, 1)
        Container:FindFirstChildOfClass("UIPadding").PaddingLeft = UDim.new(0, 18)
        Container:FindFirstChildOfClass("UIPadding").PaddingRight = UDim.new(0, 18)
        Container:FindFirstChildOfClass("UIPadding").PaddingBottom = UDim.new(0, 18)

        local Body = NewGroupbox(Tab, Container, Card, nil, Info.Name)
        for Key, Fn in pairs(Funcs) do
            if Tab[Key] == nil then
                Tab[Key] = function(_, ...)
                    return Fn(Body, ...)
                end
            end
        end
        table.insert(Tab.Groupboxes, Body)

        -- Input + button; Callback(Key) runs when the button is pressed or Enter is hit.
        function Tab:AddKeyBox(Callback, BoxInfo)
            assert(type(Callback) == "function", "Tab:AddKeyBox needs a callback")
            BoxInfo = BoxInfo or {}
            local Input = Body:AddInput(nil, { Placeholder = BoxInfo.Placeholder or "Enter your key" })
            local function Submit()
                SafeCallback(Callback, Input.Value)
            end
            Body:AddButton({ Text = BoxInfo.ButtonText or "Continue", Icon = "arrow-right", Variant = "Primary", Func = Submit })
            Connect(Input.TextBox.FocusLost, function(Enter)
                if Enter then
                    Submit()
                end
            end)
            return Input
        end

        return FinishTab(Tab)
    end

    -- A tab with an empty frame you fill with your own UI. Returns Container, Tab.
    function Window:AddCustomTab(Name, IconName, Description, Order)
        local Info = ParseTabArgs(Name, IconName, Description, Order)
        local Tab = CreateTabShell(Info)
        Tab.IsCustomTab = true
        FinishTab(Tab)
        return Tab.Page, Tab
    end

    --// Dialogs
    -- Window:AddDialog("Confirm", {
    --     Title = "Delete config?", Description = "This can't be undone.", Icon = "trash-2",
    --     FooterButtons = {
    --         Cancel = { Title = "Cancel", Variant = "Secondary", Order = 1 },
    --         Delete = { Title = "Delete", Variant = "Destructive", Order = 2, Callback = function(Dialog) end },
    --     },
    -- })
    -- The dialog also works like a groupbox: Dialog:AddInput(...), Dialog:AddToggle(...).
    Library.Dialogues = Library.Dialogues or {}

    function Window:AddDialog(Idx, DialogInfo)
        if type(Idx) == "table" then
            Idx, DialogInfo = nil, Idx
        end
        DialogInfo = DialogInfo or {}
        Idx = Idx or HttpService:GenerateGUID(false)
        if Library.Dialogues[Idx] then
            Library.Dialogues[Idx]:Dismiss()
        end
        CloseAllPopups()

        local Overlay = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 40,
            Parent = Main,
        }, { Corner(12) })
        -- A TextButton so clicks on the card don't count as "outside".
        local Card = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = "Card",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, math.min(380, Main.Size.X.Offset - 40), 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 41,
            Parent = Overlay,
        }, { Corner(12), Stroke(), List(Enum.FillDirection.Vertical, 0) })
        local CardScale = Create("UIScale", { Scale = 0.96, Parent = Card })

        local Head = Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 0,
            Parent = Card,
        }, { Pad(18, 18, 4, 18), List(Enum.FillDirection.Vertical, 6) })
        local TitleRow = Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
            LayoutOrder = 1,
            Parent = Head,
        }, { List(Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center) })
        if DialogInfo.Icon then
            local Img, Ok = Icon(DialogInfo.Icon, 18, DialogInfo.TitleColor or "PrimaryHover", { LayoutOrder = 1, Parent = TitleRow })
            if not Ok then
                Img:Destroy()
            end
        end
        local DialogTitle = Text({
            Text = DialogInfo.Title or "Dialog",
            FontFace = "SemiBold",
            TextSize = 17,
            TextColor3 = DialogInfo.TitleColor or "Foreground",
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = 2,
            Parent = TitleRow,
        })
        local DialogDescription = Text({
            Text = DialogInfo.Description or "",
            TextColor3 = DialogInfo.DescriptionColor or "MutedForeground",
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = (DialogInfo.Description or "") ~= "",
            LayoutOrder = 2,
            Parent = Head,
        })

        local Container = NewContainer(Card, 1)
        local PadObj = Container:FindFirstChildOfClass("UIPadding")
        PadObj.PaddingLeft, PadObj.PaddingRight, PadObj.PaddingBottom = UDim.new(0, 18), UDim.new(0, 18), UDim.new(0, 4)

        local Footer = Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, M.Row + 30),
            LayoutOrder = 2,
            Parent = Card,
        }, { Pad(12, 18, 18, 18), List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })

        local Dialog = NewGroupbox(nil, Container, Card, nil, DialogInfo.Title)
        Dialog.Idx = Idx
        Dialog.Buttons = {}
        Dialog.OutsideClickDismiss = DialogInfo.OutsideClickDismiss ~= false
        Dialog.AutoDismiss = DialogInfo.AutoDismiss ~= false

        function Dialog:SetTitle(Value)
            DialogTitle.Text = Value
        end
        function Dialog:SetDescription(Value)
            DialogDescription.Text = Value
            DialogDescription.Visible = Value ~= ""
        end

        function Dialog:Dismiss()
            if Dialog.Destroyed then
                return
            end
            Dialog.Destroyed = true
            CloseAllPopups()
            if Library.ActiveDialog == Dialog then
                Library.ActiveDialog = nil
            end
            Library.Dialogues[Idx] = nil
            Tween(Overlay, { BackgroundTransparency = 1 }, 0.12)
            Tween(CardScale, { Scale = 0.96 }, 0.12).Completed:Connect(function()
                Overlay:Destroy()
            end)
        end

        function Dialog:RemoveFooterButton(ButtonIdx)
            local Button = Dialog.Buttons[ButtonIdx]
            if Button then
                Button.Instance:Destroy()
                Dialog.Buttons[ButtonIdx] = nil
            end
        end

        function Dialog:AddFooterButton(ButtonIdx, ButtonInfo)
            ButtonInfo = ButtonInfo or {}
            Dialog:RemoveFooterButton(ButtonIdx)
            local Button = MakeButton(Footer, {
                Text = ButtonInfo.Title or tostring(ButtonIdx),
                Variant = ButtonInfo.Variant or "Primary",
                Icon = ButtonInfo.Icon,
                Func = function()
                    SafeCallback(ButtonInfo.Callback, Dialog)
                    if Dialog.AutoDismiss then
                        Dialog:Dismiss()
                    end
                end,
            })
            local Btn = Button.Instance
            Btn.Size = UDim2.new(0, 0, 0, M.Row)
            Btn.AutomaticSize = Enum.AutomaticSize.X
            Pad(0, 14, 0, 14).Parent = Btn
            Btn.LayoutOrder = ButtonInfo.Order or 0
            Dialog.Buttons[ButtonIdx] = Button

            -- WaitTime: the button stays disabled with a countdown (e.g. "Delete (3)").
            local Wait = tonumber(ButtonInfo.WaitTime) or 0
            if Wait > 0 then
                Button:SetDisabled(true)
                task.spawn(function()
                    local Base = Button.Text
                    for Remaining = math.ceil(Wait), 1, -1 do
                        if Dialog.Destroyed then
                            return
                        end
                        Button:SetText(Base .. " (" .. Remaining .. ")")
                        task.wait(1)
                    end
                    if not Dialog.Destroyed then
                        Button:SetText(Base)
                        Button:SetDisabled(false)
                    end
                end)
            end
            return Button
        end

        function Dialog:SetButtonDisabled(ButtonIdx, Value)
            local Button = Dialog.Buttons[ButtonIdx]
            if Button then
                Button:SetDisabled(Value)
            end
        end
        function Dialog:SetButtonOrder(ButtonIdx, Order)
            local Button = Dialog.Buttons[ButtonIdx]
            if Button then
                Button.Instance.LayoutOrder = Order
            end
        end

        local FooterButtons = DialogInfo.FooterButtons or {}
        if #FooterButtons > 0 then
            for Index, ButtonInfo in ipairs(FooterButtons) do
                Dialog:AddFooterButton(ButtonInfo.Id or Index, ButtonInfo)
            end
        else
            for ButtonIdx, ButtonInfo in pairs(FooterButtons) do
                Dialog:AddFooterButton(ButtonIdx, ButtonInfo)
            end
        end
        if next(Dialog.Buttons) == nil then
            Dialog:AddFooterButton("Close", { Title = "Close", Variant = "Secondary" })
        end

        Connect(Overlay.Activated, function()
            if Dialog.OutsideClickDismiss then
                Dialog:Dismiss()
            end
        end)

        Library.Dialogues[Idx] = Dialog
        Library.ActiveDialog = Dialog
        Tween(Overlay, { BackgroundTransparency = 0.45 }, 0.15)
        Tween(CardScale, { Scale = 1 }, 0.15)
        return Dialog
    end

    -- Escape closes the open dialog.
    Connect(UserInputService.InputBegan, function(Input)
        if Input.KeyCode == Enum.KeyCode.Escape and Library.ActiveDialog and not IsTyping() then
            if Library.ActiveDialog.OutsideClickDismiss then
                Library.ActiveDialog:Dismiss()
            end
        end
    end)

    function Window:Toggle(Value)
        Library:Toggle(Value)
    end

    function Window:SetTitle(Value)
        Window.Title = Value
        TitleLabel.Text = Value
    end
    Window.ChangeTitle = Window.SetTitle
    function Window:SetFooter(Value)
        Window.Footer = Value
        FooterLabel.Text = Value
    end
    function Window:Center()
        Center()
    end

    -- ScreenGui.AbsoluteSize is not reliable until the gui has rendered once, so
    -- centre again on the first frame.
    task.spawn(function()
        RunService.RenderStepped:Wait()
        FitScale()
        Center()
        if Info.AutoShow ~= false then
            Library:Toggle(true)
        end
    end)

    return Window
end

--// Show / hide / unload \\--
function Library:Toggle(Value)
    if Value == nil then
        Value = not Library.Toggled
    end
    Library.Toggled = Value
    local Window = Library.Window
    if not Window then
        return
    end
    CloseAllPopups()
    Tooltip.Visible = false
    if Library.Picking then
        Library.Picking:StopPicking(nil)
    end
    local Main = Window.Main
    if Value then
        local MainScale = Main:FindFirstChildOfClass("UIScale")
        Main.Visible = true
        if MainScale then
            MainScale.Scale = Library.Scale * 0.97
            Tween(MainScale, { Scale = Library.Scale }, 0.18)
        end
    else
        Main.Visible = false
    end
    Library:UpdateCursor()
end

--// Free mouse while the menu is open (PC) \\--
-- Games that lock the mouse (first person, drones, shift lock) re-lock it every
-- frame, so while the menu is open we unlock it after them each frame.
-- Set Library.UnlockMouse = false to turn this off.
Library.UnlockMouse = true
local CursorModal = Create("TextButton", {
    Name = "Modal",
    Text = "",
    BackgroundTransparency = 1,
    Size = UDim2.fromOffset(0, 0),
    Modal = false,
    Parent = ScreenGui,
})
local CursorBound = false
local CursorSaved = nil
local CursorBindName = "Nemesis" .. HttpService:GenerateGUID(false)

function Library:UpdateCursor()
    local Want = Library.Toggled and Library.UnlockMouse and not Library.IsMobile and not Library.Unloaded
    CursorModal.Modal = Want and true or false
    if Want and not CursorBound then
        CursorBound = true
        CursorSaved = { Behavior = UserInputService.MouseBehavior, Icon = UserInputService.MouseIconEnabled }
        RunService:BindToRenderStep(CursorBindName, Enum.RenderPriority.Last.Value + 1, function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
    elseif not Want and CursorBound then
        CursorBound = false
        pcall(function()
            RunService:UnbindFromRenderStep(CursorBindName)
        end)
        if CursorSaved then
            UserInputService.MouseBehavior = CursorSaved.Behavior
            UserInputService.MouseIconEnabled = CursorSaved.Icon
            CursorSaved = nil
        end
    end
end

function Library:SetUnlockMouse(Value)
    Library.UnlockMouse = Value ~= false
    Library:UpdateCursor()
end

-- Streamer mode hides your avatar and name in the menu so they don't show on stream.
function Library:SetStreamerMode(Value)
    Library.StreamerMode = Value == true
    local Window = Library.Window
    if Window and Window.UpdateUser then
        Window:UpdateUser()
    end
end

--// Themes \--
local DefaultScheme = table.clone(Scheme)
Library.DefaultScheme = DefaultScheme

-- Built-in themes. Each only lists what differs from Void; missing keys fall back to Void.
Library.Themes = {
    Void = {},
    Midnight = {
        Background = Color3.fromRGB(8, 10, 16), Card = Color3.fromRGB(11, 14, 22), Muted = Color3.fromRGB(21, 26, 38),
        Hover = Color3.fromRGB(33, 40, 56), Border = Color3.fromRGB(33, 40, 56), Input = Color3.fromRGB(33, 40, 56),
        Primary = Color3.fromRGB(59, 130, 246), PrimaryHover = Color3.fromRGB(96, 165, 250),
    },
    Rose = { Primary = Color3.fromRGB(225, 29, 72), PrimaryHover = Color3.fromRGB(244, 63, 94) },
    Emerald = { Primary = Color3.fromRGB(5, 150, 105), PrimaryHover = Color3.fromRGB(16, 185, 129) },
    Amber = { Primary = Color3.fromRGB(217, 119, 6), PrimaryHover = Color3.fromRGB(245, 158, 11) },
    Mono = {
        Primary = Color3.fromRGB(228, 228, 231), PrimaryHover = Color3.fromRGB(250, 250, 250),
        PrimaryForeground = Color3.fromRGB(9, 9, 11),
    },
}

local function RefreshAll()
    for Inst, Entry in pairs(Registry) do
        if not Inst.Parent then
            Registry[Inst] = nil
        else
            for Property, Key in pairs(Entry) do
                if Property == "FontFace" then
                    Inst.FontFace = Fonts[Key] or Inst.FontFace
                elseif Scheme[Key] then
                    Inst[Property] = Scheme[Key]
                end
            end
        end
    end
    for _, Fn in ipairs(Refreshers) do
        pcall(Fn)
    end
    for _, Group in ipairs({ Toggles, Options }) do
        for _, Element in pairs(Group) do
            if type(Element) == "table" and type(Element.Display) == "function" then
                pcall(Element.Display, Element)
            end
        end
    end
end
Library.RefreshTheme = RefreshAll

-- Library:SetTheme("Midnight") or Library:SetTheme({ Primary = Color3.fromRGB(...) }).
-- A table only needs the keys you want to change. Unknown names are ignored.
function Library:SetTheme(Theme)
    if type(Theme) == "string" then
        Theme = Library.Themes[Theme]
        if not Theme then
            return false
        end
    end
    for Key, Value in pairs(DefaultScheme) do
        Scheme[Key] = Value
    end
    for Key, Value in pairs(Theme or {}) do
        if typeof(Value) == "Color3" then
            Scheme[Key] = Value
        end
    end
    if Theme and Theme.Primary and not Theme.PrimaryHover then
        Scheme.PrimaryHover = Theme.Primary:Lerp(Color3.new(1, 1, 1), 0.15)
    end
    RefreshAll()
    return true
end

-- Change one colour, e.g. Library:SetColor("Primary", Color3.fromRGB(255, 0, 0)).
function Library:SetColor(Key, Color)
    if Scheme[Key] == nil or typeof(Color) ~= "Color3" then
        return false
    end
    Scheme[Key] = Color
    RefreshAll()
    return true
end

-- Swap the UI font family, e.g. Library:SetFont("rbxasset://fonts/families/GothamSSm.json").
-- Accepts a family path, a Font, or an Enum.Font. Works before or after the window is built.
function Library:SetFont(Family)
    if typeof(Family) == "EnumItem" then
        Family = Font.fromEnum(Family).Family
    elseif typeof(Family) == "Font" then
        Family = Family.Family
    end
    Library.FontFamily = Family
    Fonts.Regular = Font.new(Family, Enum.FontWeight.Regular)
    Fonts.Medium = Font.new(Family, Enum.FontWeight.Medium)
    Fonts.SemiBold = Font.new(Family, Enum.FontWeight.SemiBold)
    Fonts.Bold = Font.new(Family, Enum.FontWeight.Bold)
    RefreshAll()
end

function Library:OnUnload(Fn)
    table.insert(Library.UnloadCallbacks, Fn)
end

function Library:Unload()
    if Library.Unloaded then
        return
    end
    Library.Unloaded = true
    Library:UpdateCursor()
    CloseAllPopups()
    for _, Fn in ipairs(Library.UnloadCallbacks) do
        SafeCallback(Fn)
    end
    for _, Conn in ipairs(Library.Signals) do
        pcall(function()
            Conn:Disconnect()
        end)
    end
    ScreenGui:Destroy()
    table.clear(Registry)
    table.clear(Refreshers)
end

--// Public tooltip helper \\--
-- Library:AddTooltip("Shown on hover", nil, SomeGuiObject)
function Library:AddTooltip(Content, _, HoverInstance)
    AddTooltip(HoverInstance, Content)
    return { Destroy = function() end }
end

--// Draggable floating widgets \\--
local function FloatingCard(Props)
    local Card = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = "Card",
        Size = UDim2.fromOffset(0, 34),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 110,
        Parent = ScreenGui,
    }, { Corner(9), Stroke(), Pad(0, 12, 0, 12), List(Enum.FillDirection.Horizontal, 7, nil, Enum.VerticalAlignment.Center) })
    for Key, Value in pairs(Props or {}) do
        Card[Key] = Value
    end
    NewScale(Card)
    return Card
end

local FloatingCount = 0
local function NextFloatingPosition()
    FloatingCount += 1
    local Inset = GuiService:GetGuiInset()
    return UDim2.fromOffset(16, Inset.Y + 16 + (FloatingCount - 1) * 42)
end

-- Library:AddDraggableLabel("Text", Icon?) or ({ Text, Icon, IconPosition = "Left"|"Right" })
function Library:AddDraggableLabel(Value, IconName, IconPosition)
    local Info = type(Value) == "table" and Value or { Text = Value, Icon = IconName, IconPosition = IconPosition }
    local Card = FloatingCard({ Position = Info.Position or NextFloatingPosition() })
    local Img, HasIcon = Icon(Info.Icon, 15, "PrimaryHover", { LayoutOrder = 1, Parent = Card })
    Img.Visible = HasIcon
    local LabelText = Text({
        Text = Info.Text or "",
        FontFace = "Medium",
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        Parent = Card,
    })
    MakeDraggable(Card, Card)

    local Label = { Label = LabelText, Holder = Card }
    function Label:SetText(Value)
        LabelText.Text = tostring(Value)
    end
    function Label:SetIcon(Value)
        local Data = Library:GetIcon(Value)
        Img.Image = Data and Data.Url or ""
        Img.ImageRectOffset = Data and Data.ImageRectOffset or Vector2.zero
        Img.ImageRectSize = Data and Data.ImageRectSize or Vector2.zero
        Img.Visible = Data ~= nil
    end
    function Label:SetIconPosition(Value)
        Img.LayoutOrder = tostring(Value):lower() == "right" and 3 or 1
    end
    function Label:SetVisible(Value)
        Card.Visible = Value
    end
    function Label:Destroy()
        Card:Destroy()
    end
    if Info.IconPosition then
        Label:SetIconPosition(Info.IconPosition)
    end
    return Label
end

-- Library:AddDraggableButton("Text", function(Button) end) or ({ Text, Icon, Callback })
-- A press that drags further than 8px does not count as a click.
function Library:AddDraggableButton(Value, Func, _, ExcludeDragging)
    local Info = type(Value) == "table" and Value or { Text = Value, Callback = Func, ExcludeDragging = ExcludeDragging }
    local Callback = Info.Callback or Info.Func
    local Card = FloatingCard({ Position = Info.Position or NextFloatingPosition() })
    local Img, HasIcon = Icon(Info.Icon, 15, "Foreground", { LayoutOrder = 1, Parent = Card })
    Img.Visible = HasIcon
    local LabelText = Text({
        Text = Info.Text or "",
        FontFace = "Medium",
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        Parent = Card,
    })
    local Drag = Info.ExcludeDragging and { Moved = 0 } or MakeDraggable(Card, Card)

    local Button = { Button = Card }
    Connect(Card.MouseEnter, function()
        Tween(Card, { BackgroundColor3 = Scheme.Muted })
    end)
    Connect(Card.MouseLeave, function()
        Tween(Card, { BackgroundColor3 = Scheme.Card })
    end)
    Connect(Card.Activated, function()
        if Drag.Moved < 8 then
            SafeCallback(Callback, Button)
        end
    end)
    function Button:SetText(Value)
        LabelText.Text = tostring(Value)
    end
    function Button:SetVisible(Value)
        Card.Visible = Value
    end
    function Button:Destroy()
        Card:Destroy()
    end
    return Button
end

-- Watermark: a draggable label in the top-left corner.
-- Library:SetWatermark("Nemesis | 60 fps") and Library:SetWatermarkVisibility(true)
local Watermark
function Library:SetWatermark(Value)
    if not Watermark then
        Watermark = Library:AddDraggableLabel({ Text = Value })
        Watermark:SetVisible(false)
    end
    Watermark:SetText(Value)
end
function Library:SetWatermarkVisibility(Value)
    if not Watermark then
        Library:SetWatermark("")
    end
    Watermark:SetVisible(Value)
end

--// Keybind list \\--
-- A draggable panel listing every keybind and whether it is active.
-- Show it with Library:SetKeybindListVisible(true) (or Library.KeybindFrame.Visible = true).
-- Hide a single keybind from it with KeyPicker:SetMenuVisibility(false) or { NoUI = true }.
local KeybindFrame = Create("Frame", {
    BackgroundColor3 = "Card",
    Position = UDim2.fromOffset(16, 260),
    Size = UDim2.fromOffset(210, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Visible = false,
    ZIndex = 105,
    Parent = ScreenGui,
}, { Corner(10), Stroke(), List(Enum.FillDirection.Vertical, 0) })
NewScale(KeybindFrame)
local KeybindHeader = Create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 36),
    LayoutOrder = 0,
    Parent = KeybindFrame,
})
Icon("keyboard", 15, "PrimaryHover", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Parent = KeybindHeader })
Text({ Text = "Keybinds", FontFace = "Medium", Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), Parent = KeybindHeader })
Create("Frame", { BackgroundColor3 = "Border", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), Parent = KeybindHeader })
local KeybindContainer = Create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = 1,
    Parent = KeybindFrame,
}, { Pad(6, 10, 8, 12), List(Enum.FillDirection.Vertical, 2) })
local KeybindEmpty = Text({
    Text = "No keybinds",
    TextColor3 = "Subtle",
    Size = UDim2.new(1, 0, 0, 24),
    LayoutOrder = 9999,
    Parent = KeybindContainer,
})
MakeDraggable(KeybindHeader, KeybindFrame)
Library.KeybindFrame = KeybindFrame
Library.KeybindContainer = KeybindContainer

function Library:SetKeybindListVisible(Value)
    KeybindFrame.Visible = Value
end

local KeybindRows = {}
function Library:RefreshKeybindList()
    local Shown = 0
    for Index, KeyPicker in ipairs(Library.KeyPickers) do
        local Row = KeybindRows[KeyPicker]
        if not Row then
            local Frame = Create("TextButton", {
                Text = "",
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24),
                LayoutOrder = Index,
                Parent = KeybindContainer,
            })
            local Name = Text({ TextSize = 13, Size = UDim2.new(1, -70, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = Frame })
            local Key = Text({
                FontFace = "Mono",
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.new(0, 66, 1, 0),
                Parent = Frame,
            })
            Connect(Frame.Activated, function()
                if KeyPicker.Mode == "Toggle" then
                    KeyPicker:Press(true)
                end
            end)
            Row = { Frame = Frame, Name = Name, Key = Key }
            KeybindRows[KeyPicker] = Row
        end
        local Visible = not KeyPicker.NoUI and KeyPicker.MenuVisible ~= false and KeyPicker.Value ~= "None"
        Row.Frame.Visible = Visible
        if Visible then
            Shown += 1
            local Active = KeyPicker:GetState()
            Row.Name.Text = KeyPicker.Text
            Row.Name.TextColor3 = Active and Scheme.Foreground or Scheme.MutedForeground
            Row.Key.Text = (KeyAliases[KeyPicker.Value] or KeyPicker.Value) .. " · " .. KeyPicker.Mode:sub(1, 1)
            Row.Key.TextColor3 = Active and Scheme.PrimaryHover or Scheme.Subtle
        end
    end
    KeybindEmpty.Visible = Shown == 0
end
AddRefresher(function()
    Library:RefreshKeybindList()
end)

--// Loading screen \\--
-- local Loading = Library:CreateLoading({ Title = "Nemesis", TotalSteps = 3 })
-- Loading:SetMessage("Loading modules"); Loading:SetCurrentStep(1) ... Loading:Destroy()
-- Errors: Loading:ShowErrorPage(true); Loading:SetErrorMessage("..."); Loading:SetErrorButtons({ Retry = { Title, Variant, Callback } })
function Library:CreateLoading(Info)
    if Library.ActiveLoading then
        return Library.ActiveLoading
    end
    Info = Info or {}
    local Width = Info.WindowWidth or 380

    local Overlay = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 180,
        Parent = ScreenGui,
    })
    local Card = Create("Frame", {
        BackgroundColor3 = "Card",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(Width, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = Overlay,
    }, { Corner(14), Stroke(), Pad(22, 22, 22, 22), List(Enum.FillDirection.Vertical, 10) })
    local CardScale = NewScale(Card)

    local Title = Text({
        Text = Info.Title or (Library.Window and Library.Window.Title) or "Nemesis",
        FontFace = "Bold",
        TextSize = 26,
        TextColor3 = Color3.new(1, 1, 1),
        Size = UDim2.new(1, 0, 0, 30),
        LayoutOrder = 1,
        Parent = Card,
    })
    local Wave = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Scheme.Primary),
            ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
        }),
        Rotation = 15,
        Parent = Title,
    })

    -- Normal page
    local Page = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        Parent = Card,
    }, { List(Enum.FillDirection.Vertical, 8) })
    local MessageRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = Page })
    local Spinner = Icon(Info.LoadingIcon or "loader-circle", 16, Info.LoadingIconColor or "PrimaryHover", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Parent = MessageRow,
    })
    local Message = Text({
        Text = Info.Message or "Loading...",
        FontFace = "Medium",
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -70, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = MessageRow,
    })
    local StepLabel = Text({
        FontFace = "Mono",
        TextSize = 12,
        TextColor3 = "MutedForeground",
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 60, 1, 0),
        Parent = MessageRow,
    })
    local Description = Text({
        Text = Info.Description or "",
        TextColor3 = "MutedForeground",
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = (Info.Description or "") ~= "",
        LayoutOrder = 2,
        Parent = Page,
    })
    local Track = Create("Frame", {
        BackgroundColor3 = "Input",
        Size = UDim2.new(1, 0, 0, 6),
        LayoutOrder = 3,
        Parent = Page,
    }, { Corner(99) })
    local Fill = Create("Frame", { BackgroundColor3 = "Primary", Size = UDim2.fromScale(0, 1), Parent = Track }, { Corner(99) })

    -- Error page
    local ErrorPage = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        LayoutOrder = 3,
        Parent = Card,
    }, { List(Enum.FillDirection.Vertical, 10) })
    local ErrorRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = ErrorPage })
    Icon("circle-alert", 16, "Destructive", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Parent = ErrorRow })
    Text({ Text = "Something went wrong", FontFace = "Medium", Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -24, 1, 0), Parent = ErrorRow })
    local ErrorMessage = Text({
        Text = "",
        TextColor3 = "MutedForeground",
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        Parent = ErrorPage,
    })
    local ErrorButtons = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, M.Row),
        LayoutOrder = 3,
        Parent = ErrorPage,
    }, { List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) })

    local WasToggled = Library.Toggled
    if Library.Window then
        Library.Window.Main.Visible = false
    end

    local Loading = {
        CurrentStep = Info.CurrentStep or 0,
        TotalSteps = Info.TotalSteps or 10,
        IsError = false,
        ScreenGui = ScreenGui,
    }

    local SpinTime = Info.LoadingIconTweenTime or 1
    local Spin = Connect(RunService.RenderStepped, function()
        if SpinTime > 0 then
            Spinner.Rotation = (os.clock() / SpinTime * 360) % 360
        end
        Wave.Offset = Vector2.new(-1 + (os.clock() % 2.6) / 2.6 * 2, 0)
    end)

    local function UpdateStep()
        local Pct = Loading.TotalSteps > 0 and math.clamp(Loading.CurrentStep / Loading.TotalSteps, 0, 1) or 0
        Tween(Fill, { Size = UDim2.fromScale(Pct, 1) }, 0.25)
        StepLabel.Text = Loading.CurrentStep .. "/" .. Loading.TotalSteps
    end

    function Loading:SetMessage(Value)
        Message.Text = tostring(Value)
    end
    function Loading:SetDescription(Value)
        Description.Text = tostring(Value)
        Description.Visible = tostring(Value) ~= ""
    end
    function Loading:SetCurrentStep(Value)
        Loading.CurrentStep = math.clamp(tonumber(Value) or 0, 0, Loading.TotalSteps)
        UpdateStep()
    end
    function Loading:SetTotalSteps(Value)
        Loading.TotalSteps = math.max(1, tonumber(Value) or 1)
        UpdateStep()
    end
    function Loading:SetLoadingIcon(Value)
        local Data = Library:GetIcon(Value)
        Spinner.Image = Data and Data.Url or ""
        Spinner.ImageRectOffset = Data and Data.ImageRectOffset or Vector2.zero
        Spinner.ImageRectSize = Data and Data.ImageRectSize or Vector2.zero
    end
    function Loading:SetLoadingIconTweenTime(Value)
        SpinTime = tonumber(Value) or 0
    end
    function Loading:SetLoadingIconColor(Color)
        Spinner.ImageColor3 = Color
    end
    function Loading:SetWindowWidth(Value)
        Card.Size = UDim2.fromOffset(Value, 0)
    end
    function Loading:ShowErrorPage(Value)
        Loading.IsError = Value
        Page.Visible = not Value
        ErrorPage.Visible = Value
    end
    function Loading:SetErrorMessage(Value)
        ErrorMessage.Text = tostring(Value)
    end
    function Loading:SetErrorButtons(Buttons)
        for _, Child in ipairs(ErrorButtons:GetChildren()) do
            if Child:IsA("GuiButton") then
                Child:Destroy()
            end
        end
        for ButtonIdx, ButtonInfo in pairs(Buttons or {}) do
            local Button = MakeButton(ErrorButtons, {
                Text = ButtonInfo.Title or tostring(ButtonIdx),
                Variant = ButtonInfo.Variant or "Secondary",
                Func = function()
                    SafeCallback(ButtonInfo.Callback, Loading)
                end,
            })
            Button.Instance.Size = UDim2.new(0, 0, 1, 0)
            Button.Instance.AutomaticSize = Enum.AutomaticSize.X
            Pad(0, 14, 0, 14).Parent = Button.Instance
        end
    end
    function Loading:Destroy()
        if Loading.Destroyed then
            return
        end
        Loading.Destroyed = true
        Library.ActiveLoading = nil
        Spin:Disconnect()
        Tween(CardScale, { Scale = Library.Scale * 0.96 }, 0.15).Completed:Connect(function()
            Overlay:Destroy()
        end)
        if Library.Window and (WasToggled or Library.Toggled) then
            Library:Toggle(true)
        end
    end
    Loading.Continue = Loading.Destroy

    UpdateStep()
    Library.ActiveLoading = Loading
    return Loading
end

--// Describe (for AI agents and debugging) \\--
-- Library:Describe() returns the whole menu as plain data:
-- { Tabs = { { Name, Groupboxes = { { Name, Elements = { { Idx, Type, Text, Value } } } } } } }
-- Pair it with Library:GetFlags() / Library:SetFlags() to read and drive the menu.
function Library:Describe()
    local IdxOf = {}
    for _, Group in ipairs({ Toggles, Options }) do
        for Idx, Element in pairs(Group) do
            IdxOf[Element] = Idx
        end
    end
    local Out = { Title = Library.Window and Library.Window.Title, Tabs = {} }
    for _, Tab in ipairs(Library.Window and Library.Window.Tabs or {}) do
        local TabOut = { Name = Tab.Name, Visible = Tab.Visible ~= false, Groupboxes = {} }
        for _, Groupbox in ipairs(Tab.Groupboxes) do
            local BoxOut = { Name = Groupbox.Name, Elements = {} }
            for _, Entry in ipairs(Groupbox.Elements) do
                local Element = Entry.Element
                if type(Element) == "table" and Element.Type then
                    local Value = Element.Value
                    if Element.Type == "Dropdown" and Element.Multi then
                        Value = Element:GetActiveValues()
                    elseif typeof(Value) == "Color3" then
                        Value = "#" .. Value:ToHex()
                    end
                    table.insert(BoxOut.Elements, {
                        Idx = IdxOf[Element],
                        Type = Element.Type,
                        Text = Element.Text,
                        Value = Value,
                        Values = Element.Values,
                        Min = Element.Min,
                        Max = Element.Max,
                    })
                    for _, Addon in ipairs(Element.Addons or {}) do
                        table.insert(BoxOut.Elements, {
                            Idx = IdxOf[Addon],
                            Type = Addon.Type,
                            Text = Addon.Text or Element.Text,
                            Value = typeof(Addon.Value) == "Color3" and ("#" .. Addon.Value:ToHex()) or Addon.Value,
                            Mode = Addon.Mode,
                        })
                    end
                end
            end
            table.insert(TabOut.Groupboxes, BoxOut)
        end
        table.insert(Out.Tabs, TabOut)
    end
    return Out
end

--// Flags (plain values of every Toggle / Option) \\--
-- Serialise one element to a plain JSON-safe value, or nil if it has no saveable state.
local function SerializeElement(Element)
    local Type = Element.Type
    if Type == "Toggle" or Type == "Slider" or Type == "Input" then
        return Element.Value
    elseif Type == "Dropdown" then
        if Element.Multi then
            return Element:GetActiveValues()
        end
        return Element.Value
    elseif Type == "ColorPicker" then
        return { Color = "#" .. Element.Value:ToHex(), Transparency = Element.Transparency or 0 }
    elseif Type == "KeyPicker" then
        return { Key = Element.Value, Mode = Element.Mode }
    end
    return nil
end

local function ApplyElement(Element, Value)
    local Type = Element.Type
    if Type == "Toggle" then
        Element:SetValue(Value == true)
    elseif Type == "Slider" then
        Element:SetValue(tonumber(Value))
    elseif Type == "Input" then
        Element:SetValue(tostring(Value or ""))
    elseif Type == "Dropdown" then
        Element:SetValue(Value)
    elseif Type == "ColorPicker" and type(Value) == "table" then
        local Ok, Color = pcall(Color3.fromHex, tostring(Value.Color or ""):gsub("#", ""))
        if Ok and Color then
            Element:SetValueRGB(Color, Value.Transparency)
        end
    elseif Type == "KeyPicker" and type(Value) == "table" then
        Element:SetValue({ Value.Key, Value.Mode })
    end
end

-- Returns { [Idx] = value } for every saveable element. Ignored indexes are skipped.
function Library:GetFlags(Ignore)
    local Flags = {}
    for _, Group in ipairs({ Toggles, Options }) do
        for Idx, Element in pairs(Group) do
            if not (Ignore and Ignore[Idx]) then
                local Value = SerializeElement(Element)
                if Value ~= nil then
                    Flags[Idx] = Value
                end
            end
        end
    end
    return Flags
end

-- Applies { [Idx] = value } (the shape GetFlags returns). Unknown indexes are skipped.
function Library:SetFlags(Flags, Ignore)
    for Idx, Value in pairs(Flags or {}) do
        if not (Ignore and Ignore[Idx]) then
            local Element = Toggles[Idx] or Options[Idx]
            if Element then
                local Ok, Err = pcall(ApplyElement, Element, Value)
                if not Ok then
                    warn("[Nemesis] could not apply flag " .. tostring(Idx) .. ": " .. tostring(Err))
                end
            end
        end
    end
end

--// File helpers (executor filesystem; every call is guarded) \\--
local FS = {}
function FS.Ensure(Path)
    if isfolder and makefolder and not isfolder(Path) then
        pcall(makefolder, Path)
    end
end
function FS.Write(Path, Content)
    if not writefile then
        return false, "this executor has no writefile"
    end
    return pcall(writefile, Path, Content)
end
function FS.Read(Path)
    if not (readfile and isfile) or not isfile(Path) then
        return nil
    end
    local Ok, Content = pcall(readfile, Path)
    return Ok and Content or nil
end
function FS.Delete(Path)
    if delfile and isfile and isfile(Path) then
        return pcall(delfile, Path)
    end
    return false
end
function FS.List(Path, Extension)
    local Out = {}
    if not (listfiles and isfolder) or not isfolder(Path) then
        return Out
    end
    local Ok, Files = pcall(listfiles, Path)
    if not Ok then
        return Out
    end
    for _, File in ipairs(Files) do
        local Name = File:gsub("\\", "/"):match("([^/]+)%." .. Extension .. "$")
        if Name then
            table.insert(Out, Name)
        end
    end
    table.sort(Out, function(A, B)
        return A:lower() < B:lower()
    end)
    return Out
end

--// SaveManager (configs) \\--
-- Same method names as Obsidian/Linoria's SaveManager, built in so no extra load is needed.
-- Configs are JSON files: <Folder>/configs[/<SubFolder>]/<name>.json
local SaveManager = {
    Folder = "Nemesis",
    SubFolder = "",
    Ignore = {},
}
Library.SaveManager = SaveManager

function SaveManager:SetLibrary()
    -- Kept for Obsidian compatibility; Nemesis's SaveManager is already bound to the library.
end

function SaveManager:SetFolder(Folder)
    SaveManager.Folder = Folder
    SaveManager:BuildFolderTree()
end

-- Per-game configs, e.g. SaveManager:SetSubFolder(tostring(game.PlaceId)).
function SaveManager:SetSubFolder(SubFolder)
    SaveManager.SubFolder = SubFolder or ""
    SaveManager:BuildFolderTree()
end

function SaveManager:SetIgnoreIndexes(List)
    for _, Idx in ipairs(List or {}) do
        SaveManager.Ignore[Idx] = true
    end
end

function SaveManager:IgnoreThemeSettings()
    for Idx in pairs(Options) do
        if type(Idx) == "string" and Idx:find("^ThemeManager_") then
            SaveManager.Ignore[Idx] = true
        end
    end
    SaveManager.IgnoreTheme = true
end

function SaveManager:GetPath()
    local Path = SaveManager.Folder .. "/configs"
    if SaveManager.SubFolder ~= "" then
        Path = Path .. "/" .. SaveManager.SubFolder
    end
    return Path
end

function SaveManager:BuildFolderTree()
    FS.Ensure(SaveManager.Folder)
    FS.Ensure(SaveManager.Folder .. "/configs")
    FS.Ensure(SaveManager.Folder .. "/themes")
    FS.Ensure(SaveManager:GetPath())
end

local function ValidName(Name)
    return type(Name) == "string" and Name:match("^%s*(.-)%s*$") ~= "" and not Name:find("[/\\:*?\"<>|]")
end

-- Returns true, or false + reason.
function SaveManager:Save(Name)
    if not ValidName(Name) then
        return false, "invalid config name"
    end
    SaveManager:BuildFolderTree()
    local Ignore = table.clone(SaveManager.Ignore)
    if SaveManager.IgnoreTheme then
        for Idx in pairs(Options) do
            if type(Idx) == "string" and Idx:find("^ThemeManager_") then
                Ignore[Idx] = true
            end
        end
    end
    local Data = { Version = 1, Flags = Library:GetFlags(Ignore) }
    local Ok, Json = pcall(HttpService.JSONEncode, HttpService, Data)
    if not Ok then
        return false, "could not encode config"
    end
    local Wrote, Err = FS.Write(SaveManager:GetPath() .. "/" .. Name .. ".json", Json)
    if not Wrote then
        return false, tostring(Err or "could not write file")
    end
    return true
end

function SaveManager:Load(Name)
    if not ValidName(Name) then
        return false, "invalid config name"
    end
    local Content = FS.Read(SaveManager:GetPath() .. "/" .. Name .. ".json")
    if not Content then
        return false, "config not found"
    end
    local Ok, Data = pcall(HttpService.JSONDecode, HttpService, Content)
    if not Ok or type(Data) ~= "table" then
        return false, "config file is corrupted"
    end
    -- Also accept Obsidian/Linoria's { objects = { { type, idx, value } } } format.
    local Flags = Data.Flags
    if not Flags and type(Data.objects) == "table" then
        Flags = {}
        for _, Object in ipairs(Data.objects) do
            if Object.idx then
                if Object.type == "ColorPicker" then
                    Flags[Object.idx] = { Color = Object.value, Transparency = Object.transparency }
                elseif Object.type == "KeyPicker" then
                    Flags[Object.idx] = { Key = Object.key, Mode = Object.mode }
                elseif Object.type == "Dropdown" and type(Object.value) == "table" then
                    local List = {}
                    for Value, On in pairs(Object.value) do
                        if On then
                            table.insert(List, Value)
                        end
                    end
                    Flags[Object.idx] = List
                else
                    Flags[Object.idx] = Object.value
                end
            end
        end
    end
    Library:SetFlags(Flags or {}, SaveManager.Ignore)
    return true
end

function SaveManager:Delete(Name)
    if not ValidName(Name) then
        return false, "invalid config name"
    end
    local Ok = FS.Delete(SaveManager:GetPath() .. "/" .. Name .. ".json")
    return Ok and true or false, (not Ok) and "config not found" or nil
end

function SaveManager:RefreshConfigList()
    return FS.List(SaveManager:GetPath(), "json")
end
SaveManager.GetConfigs = SaveManager.RefreshConfigList

local function AutoloadPath()
    return SaveManager:GetPath() .. "/autoload.txt"
end

function SaveManager:GetAutoloadConfig()
    local Name = FS.Read(AutoloadPath())
    return (Name and Name ~= "") and Name or nil
end

function SaveManager:SaveAutoloadConfig(Name)
    if not ValidName(Name) then
        return false, "invalid config name"
    end
    SaveManager:BuildFolderTree()
    return FS.Write(AutoloadPath(), Name)
end

function SaveManager:DeleteAutoLoadConfig()
    return FS.Delete(AutoloadPath())
end
SaveManager.DeleteAutoloadConfig = SaveManager.DeleteAutoLoadConfig

function SaveManager:LoadAutoloadConfig()
    local Name = SaveManager:GetAutoloadConfig()
    if not Name then
        return false
    end
    local Ok, Err = SaveManager:Load(Name)
    if Ok then
        Library:Notify({ Title = "Config loaded", Description = "Autoloaded " .. Name .. ".", Time = 3 })
    else
        Library:Notify({ Title = "Autoload failed", Description = tostring(Err), Time = 4 })
    end
    return Ok
end

-- Adds a ready-made "Configuration" groupbox to a tab (create, load, overwrite, delete, autoload).
function SaveManager:BuildConfigSection(Tab, Side)
    assert(Tab, "SaveManager:BuildConfigSection needs a tab")
    SaveManager:BuildFolderTree()
    local Box = (Side == "Left" and Tab.AddLeftGroupbox or Tab.AddRightGroupbox)(Tab, "Configuration", "save")

    local function Notify(Ok, Done, Err)
        if Ok then
            Library:Notify({ Title = Done, Time = 3 })
        else
            Library:Notify({ Title = "Config error", Description = tostring(Err), Time = 4 })
        end
    end

    Box:AddInput("SaveManager_ConfigName", { Text = "Config name", Placeholder = "my_config" })
    local List
    local AutoloadLabel

    local function Refresh()
        List:SetValues(SaveManager:RefreshConfigList())
        local Auto = SaveManager:GetAutoloadConfig()
        AutoloadLabel:SetText("Autoload: " .. (Auto or "none"))
    end

    Box:AddButton({ Text = "Create config", Icon = "plus", Variant = "Primary", Func = function()
        local Name = Options.SaveManager_ConfigName.Value
        local Ok, Err = SaveManager:Save(Name)
        Notify(Ok, "Created " .. tostring(Name), Err)
        Refresh()
    end })

    Box:AddDivider()
    List = Box:AddDropdown("SaveManager_ConfigList", { Text = "Configs", Values = {}, AllowNull = true, Placeholder = "No config selected" })

    Box:AddButton({ Text = "Load", Icon = "download", Func = function()
        local Name = List.Value
        local Ok, Err = SaveManager:Load(Name)
        Notify(Ok, "Loaded " .. tostring(Name), Err)
    end }):AddButton({ Text = "Overwrite", Icon = "save", Func = function()
        local Name = List.Value
        local Ok, Err = SaveManager:Save(Name)
        Notify(Ok, "Overwrote " .. tostring(Name), Err)
    end })

    Box:AddButton({ Text = "Delete", Icon = "trash-2", Variant = "Destructive", DoubleClick = true, Func = function()
        local Name = List.Value
        local Ok, Err = SaveManager:Delete(Name)
        Notify(Ok, "Deleted " .. tostring(Name), Err)
        Refresh()
    end }):AddButton({ Text = "Refresh", Icon = "refresh-cw", Func = Refresh })

    Box:AddButton({ Text = "Set autoload", Icon = "star", Func = function()
        local Name = List.Value
        local Ok, Err = SaveManager:SaveAutoloadConfig(Name)
        Notify(Ok, tostring(Name) .. " will autoload", Err)
        Refresh()
    end }):AddButton({ Text = "Clear autoload", Icon = "star-off", Func = function()
        SaveManager:DeleteAutoLoadConfig()
        Refresh()
    end })

    AutoloadLabel = Box:AddLabel("Autoload: none", true)

    SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigName", "SaveManager_ConfigList" })
    Refresh()
    return Box
end

--// ThemeManager \\--
-- Same method names as Obsidian/Linoria's ThemeManager. Themes are saved as JSON in
-- <Folder>/themes/<name>.json; "default.txt" holds the theme to apply on load.
local ThemeManager = {
    Folder = "Nemesis",
    EditableKeys = { "Background", "Card", "Muted", "Border", "Foreground", "MutedForeground", "Primary" },
    Fonts = {
        ["Builder Sans"] = "rbxasset://fonts/families/BuilderSans.json",
        ["Gotham"] = "rbxasset://fonts/families/GothamSSm.json",
        ["Montserrat"] = "rbxasset://fonts/families/Montserrat.json",
        ["Roboto"] = "rbxasset://fonts/families/Roboto.json",
        ["Source Sans"] = "rbxasset://fonts/families/SourceSansPro.json",
        ["Nunito"] = "rbxasset://fonts/families/Nunito.json",
        ["Ubuntu"] = "rbxasset://fonts/families/Ubuntu.json",
        ["Code"] = "rbxasset://fonts/families/RobotoMono.json",
    },
}
Library.ThemeManager = ThemeManager

function ThemeManager:SetLibrary()
    -- Kept for Obsidian compatibility.
end

function ThemeManager:SetFolder(Folder)
    ThemeManager.Folder = Folder
    FS.Ensure(Folder)
    FS.Ensure(Folder .. "/themes")
end

local function ThemePath(Name)
    return ThemeManager.Folder .. "/themes/" .. Name .. ".json"
end

function ThemeManager:GetCustomThemes()
    return FS.List(ThemeManager.Folder .. "/themes", "json")
end

-- Current colours + font as a plain table (hex strings), ready for JSON.
function ThemeManager:GetCurrentTheme()
    local Out = {}
    for Key, Value in pairs(Scheme) do
        Out[Key] = "#" .. Value:ToHex()
    end
    Out.FontFamily = Library.FontFamily
    return Out
end

-- Accepts a built-in theme name, a saved custom theme name, or a table of colours.
function ThemeManager:ApplyTheme(Theme)
    if type(Theme) == "string" then
        if Library.Themes[Theme] then
            return Library:SetTheme(Theme)
        end
        local Content = FS.Read(ThemePath(Theme))
        if not Content then
            return false
        end
        local Ok, Data = pcall(HttpService.JSONDecode, HttpService, Content)
        if not Ok then
            return false
        end
        Theme = Data
    end
    if type(Theme) ~= "table" then
        return false
    end
    local Colors = {}
    for Key, Value in pairs(Theme) do
        if typeof(Value) == "Color3" then
            Colors[Key] = Value
        elseif type(Value) == "string" and Value:sub(1, 1) == "#" then
            local Ok, Color = pcall(Color3.fromHex, Value:sub(2))
            if Ok then
                Colors[Key] = Color
            end
        end
    end
    Library:SetTheme(Colors)
    if type(Theme.FontFamily) == "string" then
        Library:SetFont(Theme.FontFamily)
    end
    return true
end

function ThemeManager:SaveCustomTheme(Name)
    if not ValidName(Name) then
        return false, "invalid theme name"
    end
    ThemeManager:SetFolder(ThemeManager.Folder)
    local Ok, Json = pcall(HttpService.JSONEncode, HttpService, ThemeManager:GetCurrentTheme())
    if not Ok then
        return false, "could not encode theme"
    end
    return FS.Write(ThemePath(Name), Json)
end

function ThemeManager:SaveDefault(Name)
    ThemeManager:SetFolder(ThemeManager.Folder)
    return FS.Write(ThemeManager.Folder .. "/themes/default.txt", Name)
end

function ThemeManager:LoadDefault()
    local Name = FS.Read(ThemeManager.Folder .. "/themes/default.txt")
    if Name and Name ~= "" then
        return ThemeManager:ApplyTheme(Name)
    end
    return false
end

-- Adds a "Theme" groupbox: preset picker, colour pickers, font, save/load custom themes.
function ThemeManager:ApplyToTab(Tab, Side)
    assert(Tab, "ThemeManager:ApplyToTab needs a tab")
    ThemeManager:SetFolder(ThemeManager.Folder)
    local Box = (Side == "Right" and Tab.AddRightGroupbox or Tab.AddLeftGroupbox)(Tab, "Theme", "palette")
    local Syncing = false

    local Pickers = {}
    local function SyncPickers()
        Syncing = true
        for Key, Picker in pairs(Pickers) do
            Picker:SetValueRGB(Scheme[Key])
        end
        Syncing = false
    end

    local PresetNames = {}
    for Name in pairs(Library.Themes) do
        table.insert(PresetNames, Name)
    end
    table.sort(PresetNames, function(A, B)
        if A == "Void" then
            return true
        elseif B == "Void" then
            return false
        end
        return A < B
    end)

    Box:AddDropdown("ThemeManager_Preset", { Text = "Preset", Values = PresetNames, Default = "Void", Callback = function(Name)
        if Name and not Syncing then
            Library:SetTheme(Name)
            SyncPickers()
        end
    end })

    local Labels = {
        Background = "Background",
        Card = "Cards",
        Muted = "Controls",
        Border = "Borders",
        Foreground = "Text",
        MutedForeground = "Muted text",
        Primary = "Accent",
    }
    for _, Key in ipairs(ThemeManager.EditableKeys) do
        local Label = Box:AddLabel(Labels[Key] or Key)
        Label:AddColorPicker("ThemeManager_Color_" .. Key, { Default = Scheme[Key], Title = Labels[Key] or Key, Callback = function(Color)
            if not Syncing then
                Library:SetColor(Key, Color)
                if Key == "Primary" then
                    Library:SetColor("PrimaryHover", Color:Lerp(Color3.new(1, 1, 1), 0.15))
                end
            end
        end })
        Pickers[Key] = Options["ThemeManager_Color_" .. Key]
    end

    local FontNames = {}
    for Name in pairs(ThemeManager.Fonts) do
        table.insert(FontNames, Name)
    end
    table.sort(FontNames)
    Box:AddDropdown("ThemeManager_Font", { Text = "Font", Values = FontNames, Default = "Builder Sans", Callback = function(Name)
        if Name and ThemeManager.Fonts[Name] then
            Library:SetFont(ThemeManager.Fonts[Name])
        end
    end })

    Box:AddDivider("Custom themes")
    Box:AddInput("ThemeManager_CustomName", { Placeholder = "Theme name" })
    local CustomList = Box:AddDropdown("ThemeManager_CustomList", { Values = ThemeManager:GetCustomThemes(), AllowNull = true, Placeholder = "Saved themes" })

    local function Refresh()
        CustomList:SetValues(ThemeManager:GetCustomThemes())
    end

    Box:AddButton({ Text = "Save theme", Icon = "save", Variant = "Primary", Func = function()
        local Name = Options.ThemeManager_CustomName.Value
        local Ok, Err = ThemeManager:SaveCustomTheme(Name)
        Library:Notify({ Title = Ok and ("Saved theme " .. Name) or "Theme error", Description = (not Ok) and tostring(Err) or nil, Time = 3 })
        Refresh()
    end }):AddButton({ Text = "Load", Icon = "download", Func = function()
        if CustomList.Value and ThemeManager:ApplyTheme(CustomList.Value) then
            SyncPickers()
        end
    end })
    Box:AddButton({ Text = "Set as default", Icon = "star", Func = function()
        local Name = CustomList.Value or Options.ThemeManager_Preset.Value
        if Name then
            ThemeManager:SaveDefault(Name)
            Library:Notify({ Title = Name .. " is now the default theme", Time = 3 })
        end
    end }):AddButton({ Text = "Refresh", Icon = "refresh-cw", Func = Refresh })

    if ThemeManager:LoadDefault() then
        SyncPickers()
    end
    return Box
end

genv.Library = Library
return Library
