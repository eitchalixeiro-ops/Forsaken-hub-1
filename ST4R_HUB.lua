--[[
    ST4R HUB | Forsaken
    Version: 0.1.0 (foundation)
    Author: ST4R HUB project

    This build provides the complete UI shell, tab navigation, settings,
    keybind, notifications and cleanup. Game-specific stamina and generator
    automation are intentionally not represented as working until their
    current client/server interfaces are verified. A client-side number
    change is not proof that the server accepted it.

    Load in a Roblox client environment that permits LocalPlayer GUI creation.
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

-- Avoid duplicate copies.
local GUI_NAME = "ST4R_HUB"
local old = (gethui and gethui() or CoreGui):FindFirstChild(GUI_NAME)
if old then old:Destroy() end

local Settings = {
    ToggleKey = Enum.KeyCode.RightShift,
    Accent = Color3.fromRGB(151, 110, 255),
    Background = Color3.fromRGB(15, 16, 25),
    Panel = Color3.fromRGB(23, 24, 36),
    Card = Color3.fromRGB(31, 32, 47),
    Text = Color3.fromRGB(244, 242, 255),
    Muted = Color3.fromRGB(155, 155, 178),
}

local State = {
    AutoGenerator = false,
    StaminaMode = "Original",
    StaminaTarget = 100,
    GeneratorCooldown = 4,
    ShowStatus = true,
}

local function tween(object, properties, duration)
    TweenService:Create(object, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties):Play()
end

local function corner(object, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = object
    return c
end

local function stroke(object, color, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(75, 72, 103)
    s.Transparency = transparency or 0.45
    s.Thickness = 1
    s.Parent = object
    return s
end

local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local parent = (gethui and gethui()) or CoreGui
local Screen = make("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parent)

local Main = make("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(590, 390),
    Position = UDim2.new(0.5, -295, 0.5, -195),
    BackgroundColor3 = Settings.Background,
    BorderSizePixel = 0,
}, Screen)
corner(Main, 15)
stroke(Main, Settings.Accent, 0.25)

local Top = make("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = Settings.Panel,
    BorderSizePixel = 0,
}, Main)
corner(Top, 15)

make("Frame", {
    Position = UDim2.new(0, 0, 1, -15),
    Size = UDim2.new(1, 0, 0, 15),
    BackgroundColor3 = Settings.Panel,
    BorderSizePixel = 0,
}, Top)

local Logo = make("TextLabel", {
    Position = UDim2.fromOffset(18, 8),
    Size = UDim2.fromOffset(220, 25),
    BackgroundTransparency = 1,
    Text = "✦  ST4R HUB",
    TextColor3 = Settings.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Top)

make("TextLabel", {
    Position = UDim2.fromOffset(20, 33),
    Size = UDim2.fromOffset(240, 16),
    BackgroundTransparency = 1,
    Text = "FORSAKEN  •  FOUNDATION 0.1.0",
    TextColor3 = Settings.Muted,
    Font = Enum.Font.GothamMedium,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Top)

local Close = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = Color3.fromRGB(75, 42, 61),
    Text = "×",
    TextColor3 = Settings.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    AutoButtonColor = true,
}, Top)
corner(Close, 9)

local Minimize = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -52, 0.5, 0),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = Settings.Card,
    Text = "—",
    TextColor3 = Settings.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 17,
}, Top)
corner(Minimize, 9)

local Sidebar = make("Frame", {
    Position = UDim2.fromOffset(12, 70),
    Size = UDim2.fromOffset(142, 308),
    BackgroundColor3 = Settings.Panel,
    BorderSizePixel = 0,
}, Main)
corner(Sidebar, 12)

local Content = make("Frame", {
    Position = UDim2.fromOffset(166, 70),
    Size = UDim2.new(1, -178, 1, -82),
    BackgroundTransparency = 1,
}, Main)

local Pages = {}
local TabButtons = {}
local CurrentPage

local function createPage(name)
    local page = make("ScrollingFrame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Settings.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, Content)
    make("UIListLayout", {
        Padding = UDim.new(0, 9),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 8),
    }, page)
    Pages[name] = page
    return page
end

local function setPage(name)
    for pageName, page in pairs(Pages) do
        page.Visible = pageName == name
    end
    for tabName, button in pairs(TabButtons) do
        tween(button, {
            BackgroundColor3 = tabName == name and Settings.Accent or Settings.Card,
            TextColor3 = tabName == name and Color3.new(1,1,1) or Settings.Muted,
        })
    end
    CurrentPage = name
end

local function addTab(name, icon)
    local button = make("TextButton", {
        Size = UDim2.new(1, -14, 0, 38),
        Position = UDim2.fromOffset(7, 0),
        BackgroundColor3 = Settings.Card,
        BackgroundTransparency = 0,
        Text = icon .. "  " .. name,
        TextColor3 = Settings.Muted,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        AutoButtonColor = false,
    }, Sidebar)
    corner(button, 9)
    button.MouseButton1Click:Connect(function() setPage(name) end)
    TabButtons[name] = button
    return createPage(name)
end

local function section(page, title, subtitle)
    local holder = make("Frame", {
        Size = UDim2.new(1, -2, 0, subtitle and 58 or 38),
        BackgroundTransparency = 1,
    }, page)
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 23),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Settings.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    if subtitle then
        make("TextLabel", {
            Position = UDim2.fromOffset(0, 25),
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = subtitle,
            TextWrapped = true,
            TextColor3 = Settings.Muted,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, holder)
    end
end

local function row(page, height)
    local f = make("Frame", {
        Size = UDim2.new(1, -2, 0, height or 48),
        BackgroundColor3 = Settings.Card,
        BorderSizePixel = 0,
    }, page)
    corner(f, 10)
    return f
end

local function label(parentObject, title, detail)
    make("TextLabel", {
        Position = UDim2.fromOffset(12, detail and 5 or 0),
        Size = UDim2.new(1, -100, detail and 0.55 or 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Settings.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = detail and Enum.TextYAlignment.Bottom or Enum.TextYAlignment.Center,
    }, parentObject)
    if detail then
        make("TextLabel", {
            Position = UDim2.fromOffset(12, 26),
            Size = UDim2.new(1, -110, 0, 15),
            BackgroundTransparency = 1,
            Text = detail,
            TextColor3 = Settings.Muted,
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, parentObject)
    end
end

local function toggle(page, title, detail, initial, callback)
    local f = row(page, detail and 54 or 46)
    label(f, title, detail)
    local b = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(42, 22),
        BackgroundColor3 = initial and Settings.Accent or Color3.fromRGB(65, 65, 82),
        Text = "",
        AutoButtonColor = false,
    }, f)
    corner(b, 11)
    local knob = make("Frame", {
        Position = initial and UDim2.fromOffset(22, 3) or UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Color3.new(1,1,1),
        BorderSizePixel = 0,
    }, b)
    corner(knob, 8)
    local value = initial
    b.MouseButton1Click:Connect(function()
        value = not value
        tween(b, {BackgroundColor3 = value and Settings.Accent or Color3.fromRGB(65,65,82)})
        tween(knob, {Position = value and UDim2.fromOffset(22,3) or UDim2.fromOffset(3,3)})
        if callback then callback(value) end
    end)
    return function() return value end
end

local function choice(page, title, detail, options, initial, callback)
    local f = row(page, 58)
    label(f, title, detail)
    local b = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(132, 30),
        BackgroundColor3 = Settings.Panel,
        Text = initial,
        TextColor3 = Settings.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 10,
    }, f)
    corner(b, 8)
    local index = table.find(options, initial) or 1
    b.MouseButton1Click:Connect(function()
        index = index % #options + 1
        b.Text = options[index]
        if callback then callback(options[index]) end
    end)
end

local function numberInput(page, title, detail, initial, minValue, maxValue, callback)
    local f = row(page, 58)
    label(f, title, detail)
    local box = make("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(112, 30),
        BackgroundColor3 = Settings.Panel,
        Text = tostring(initial),
        PlaceholderText = "Número",
        TextColor3 = Settings.Text,
        PlaceholderColor3 = Settings.Muted,
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        ClearTextOnFocus = false,
    }, f)
    corner(box, 8)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if not n then
            box.Text = tostring(initial)
            return
        end
        n = math.clamp(n, minValue, maxValue)
        n = math.floor(n * 100 + 0.5) / 100
        box.Text = tostring(n)
        initial = n
        if callback then callback(n) end
    end)
end

local Home = addTab("Home", "✦")
local Stamina = addTab("Stamina", "⚡")
local Generators = addTab("Generators", "⌘")
local SettingsPage = addTab("Settings", "⚙")

section(Home, "Welcome to ST4R HUB", "A lightweight control panel. Modules are marked clearly while game-specific integration is being validated.")
local status = row(Home, 70)
label(status, "Build status", "Interface and settings are active. Game hooks are not connected in this foundation.")
local statusText = make("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(92, 24),
    BackgroundColor3 = Color3.fromRGB(68, 54, 104),
    Text = "FOUNDATION",
    TextColor3 = Settings.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 9,
}, status)
corner(statusText, 7)
section(Home, "Quick information")
local info = row(Home, 54)
label(info, "Toggle menu", "Press RightShift to show or hide the panel.")

section(Stamina, "Stamina controls", "The controls below store your preferences only. They do not claim to change server-authoritative stamina.")
choice(Stamina, "Stamina preset", "Preference saved for the next integration step.", {"Original", "Realistic", "Semi-Realistic", "Infinite"}, State.StaminaMode, function(v)
    State.StaminaMode = v
end)
numberInput(Stamina, "Desired value", "Saved target value (not applied to the game).", State.StaminaTarget, 0, 1000000000000, function(v)
    State.StaminaTarget = v
end)
local staminaNote = row(Stamina, 62)
label(staminaNote, "Integration status", "Waiting for a verified stamina interface. Client-only edits may be rejected or overwritten by the server.")

section(Generators, "Generator automation", "The reference source contains Flow, Connect, Lock and Gear solvers. This standalone build does not silently copy or execute those hooks.")
toggle(Generators, "Auto Generator", "Preference toggle only; solver is not connected yet.", State.AutoGenerator, function(v)
    State.AutoGenerator = v
end)
numberInput(Generators, "Cooldown (seconds)", "Stored preference; range 0.25–12 seconds.", State.GeneratorCooldown, 0.25, 12, function(v)
    State.GeneratorCooldown = v
end)
local genNote = row(Generators, 62)
label(genNote, "Solver status", "Flow / Connect / Lock / Gear: pending verified integration and in-game testing.")

section(SettingsPage, "Interface settings")
toggle(SettingsPage, "Show status notes", "Keep module integration notices visible.", State.ShowStatus, function(v)
    State.ShowStatus = v
    status.Visible = v
    staminaNote.Visible = v
    genNote.Visible = v
end)
local keyRow = row(SettingsPage, 48)
label(keyRow, "Menu key", "RightShift")
local keyButton = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.fromOffset(112, 29),
    BackgroundColor3 = Settings.Panel,
    Text = "RightShift",
    TextColor3 = Settings.Text,
    Font = Enum.Font.GothamSemibold,
    TextSize = 10,
}, keyRow)
corner(keyButton, 8)
local listening = false
keyButton.MouseButton1Click:Connect(function()
    listening = true
    keyButton.Text = "Press a key..."
end)

-- Sidebar layout is explicit so it remains stable across screen sizes.
local sidebarLayout = make("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Sidebar)
make("UIPadding", {
    PaddingTop = UDim.new(0, 9),
}, Sidebar)

setPage("Home")

-- Drag support.
local dragging, dragStart, startPos
Top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local minimized = false
Minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    Sidebar.Visible = not minimized
    Content.Visible = not minimized
    tween(Main, {Size = minimized and UDim2.fromOffset(590, 58) or UDim2.fromOffset(590, 390)}, 0.2)
    Minimize.Text = minimized and "+" or "—"
end)

Close.MouseButton1Click:Connect(function()
    Screen:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if listening then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            Settings.ToggleKey = input.KeyCode
            keyButton.Text = input.KeyCode.Name
        end
        listening = false
        return
    end
    if processed then return end
    if input.KeyCode == Settings.ToggleKey then
        Main.Visible = not Main.Visible
    end
end)

print("[ST4R HUB] Interface loaded. Game-specific modules are not connected in this foundation.")
