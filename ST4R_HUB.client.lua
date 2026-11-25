--[[
    ST4R HUB | VIOLET CROWN EDITION
    Studio Edition - LocalScript
    Install: StarterPlayer > StarterPlayerScripts
    This edition is designed for your own Roblox Studio experience.
    It does not use executor APIs, remote spoofing, getgc, hookmetamethod,
    server bypasses, or manipulation of another game's private modules.

    Included:
      * Responsive dark/violet interface
      * Drag, minimize, mobile toggle, tabs, notifications
      * Dashboard with local character diagnostics
      * Read-only stamina attribute monitor
      * Generator Practice Lab (offline puzzle/timing sandbox)
      * Accessibility, themes, UI scale and settings
      * Local diagnostic log and safe cleanup
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Settings = {
    Accent = Color3.fromRGB(153, 65, 255),
    AccentSoft = Color3.fromRGB(91, 36, 166),
    Background = Color3.fromRGB(9, 7, 15),
    Panel = Color3.fromRGB(20, 15, 30),
    Card = Color3.fromRGB(29, 21, 43),
    CardHover = Color3.fromRGB(40, 28, 59),
    Text = Color3.fromRGB(245, 239, 255),
    Muted = Color3.fromRGB(168, 153, 190),
    Success = Color3.fromRGB(103, 235, 164),
    Warning = Color3.fromRGB(255, 197, 91),
    Danger = Color3.fromRGB(255, 99, 128),
    Scale = 1,
    ReduceMotion = false,
    HighContrast = false,
    ShowDiagnostics = true,
    Notifications = true,
}

local State = {
    Destroyed = false,
    Minimized = false,
    CurrentPage = "Home",
    Connections = {},
    Logs = {},
    Toggles = {},
    Character = nil,
    Humanoid = nil,
    RootPart = nil,
    LastHealth = nil,
    Practice = {
        Running = false,
        Score = 0,
        Best = 0,
        Round = 0,
        Difficulty = "Normal",
        CurrentPrompt = nil,
    },
}

local function track(connection)
    table.insert(State.Connections, connection)
    return connection
end

local function log(level, message)
    local entry = {
        Time = os.date("%H:%M:%S"),
        Level = tostring(level or "INFO"),
        Message = tostring(message),
    }
    table.insert(State.Logs, 1, entry)
    while #State.Logs > 80 do
        table.remove(State.Logs)
    end
    print(("[ST4R HUB][%s] %s"):format(entry.Level, entry.Message))
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, "Callback inválido"
    end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return callback(table.unpack(args, 1, args.n))
    end)
    if not ok then
        log("ERROR", result)
        return false, result
    end
    return true, result
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        local ok, err = pcall(function()
            object[key] = value
        end)
        if not ok then
            warn("[ST4R HUB] Property error:", key, err)
        end
    end
    object.Parent = parent
    return object
end

local function corner(object, radius)
    return make("UICorner", {
        CornerRadius = UDim.new(0, radius or 10),
    }, object)
end

local function outline(object, color, thickness, transparency)
    return make("UIStroke", {
        Color = color or Settings.Accent,
        Thickness = thickness or 1,
        Transparency = transparency or 0.35,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, object)
end

local function padding(object, left, right, top, bottom)
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, object)
end

local function tween(object, duration, properties)
    if Settings.ReduceMotion then
        for key, value in pairs(properties) do
            object[key] = value
        end
        return nil
    end
    local animation = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        properties
    )
    animation:Play()
    return animation
end

local function text(parent, value, size, position, fontSize, color, font)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(value or ""),
        Size = size or UDim2.new(1, 0, 0, 20),
        Position = position or UDim2.new(),
        Font = font or Enum.Font.Gotham,
        TextSize = fontSize or 13,
        TextColor3 = color or Settings.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
        RichText = false,
    }, parent)
end

local function button(parent, caption, size, position, callback)
    local item = make("TextButton", {
        AutoButtonColor = false,
        Text = caption,
        Size = size or UDim2.fromOffset(100, 34),
        Position = position or UDim2.new(),
        BackgroundColor3 = Settings.AccentSoft,
        TextColor3 = Settings.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        BorderSizePixel = 0,
    }, parent)
    corner(item, 8)
    outline(item, Settings.Accent, 1, 0.55)
    track(item.MouseEnter:Connect(function()
        tween(item, 0.12, {BackgroundColor3 = Settings.Accent})
    end))
    track(item.MouseLeave:Connect(function()
        tween(item, 0.12, {BackgroundColor3 = Settings.AccentSoft})
    end))
    track(item.Activated:Connect(function()
        if callback then
            safeCall(callback)
        end
    end))
    return item
end

local function card(parent, height)
    local frame = make("Frame", {
        BackgroundColor3 = Settings.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or 72),
    }, parent)
    corner(frame, 10)
    outline(frame, Settings.Accent, 1, 0.88)
    return frame
end

local function listLayout(parent, gap)
    return make("UIListLayout", {
        Padding = UDim.new(0, gap or 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, parent)
end

local function section(parent, titleText, subtitle)
    local wrapper = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, subtitle and 54 or 34),
    }, parent)
    text(wrapper, titleText, UDim2.new(1, 0, 0, 24), UDim2.new(), 16, Settings.Text, Enum.Font.GothamBold)
    if subtitle then
        text(wrapper, subtitle, UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 26), 10, Settings.Muted)
    end
    return wrapper
end

local function makeScroll(parent, name)
    local scroll = make("ScrollingFrame", {
        Name = name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.fromOffset(10, 10),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Settings.Accent,
    }, parent)
    padding(scroll, 1, 7, 1, 8)
    listLayout(scroll, 9)
    return scroll
end

local gui = make("ScreenGui", {
    Name = "ST4R_HUB_Studio",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 80,
}, playerGui)

local scale = make("UIScale", {
    Scale = Settings.Scale,
}, gui)

local root = make("Frame", {
    Name = "Root",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(700, 470),
    BackgroundColor3 = Settings.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(root, 14)
outline(root, Settings.Accent, 1.5, 0.12)

local rootGradient = make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 10, 29)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(10, 8, 17)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 10, 35)),
    }),
    Rotation = 25,
}, root)

local header = make("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 66),
    BackgroundColor3 = Settings.Panel,
    BorderSizePixel = 0,
}, root)
corner(header, 14)

local crownMark = make("TextLabel", {
    BackgroundTransparency = 1,
    Text = "♛",
    Font = Enum.Font.GothamBlack,
    TextSize = 34,
    TextColor3 = Settings.Accent,
    Size = UDim2.fromOffset(48, 48),
    Position = UDim2.fromOffset(14, 8),
}, header)
text(header, "ST4R HUB", UDim2.fromOffset(210, 28), UDim2.fromOffset(66, 8), 21, Settings.Text, Enum.Font.GothamBlack)
text(header, "VIOLET CROWN  /  STUDIO EDITION", UDim2.fromOffset(250, 17), UDim2.fromOffset(68, 36), 9, Settings.Muted, Enum.Font.GothamBold)

local statusPill = make("Frame", {
    Size = UDim2.fromOffset(94, 24),
    Position = UDim2.new(1, -184, 0, 21),
    BackgroundColor3 = Color3.fromRGB(29, 65, 48),
    BorderSizePixel = 0,
}, header)
corner(statusPill, 12)
local statusDot = make("Frame", {
    Size = UDim2.fromOffset(7, 7),
    Position = UDim2.fromOffset(10, 8),
    BackgroundColor3 = Settings.Success,
    BorderSizePixel = 0,
}, statusPill)
corner(statusDot, 5)
text(statusPill, "LOCAL MODE", UDim2.fromOffset(68, 20), UDim2.fromOffset(22, 2), 8, Settings.Success, Enum.Font.GothamBold)

local minimizeButton
minimizeButton = button(header, "—", UDim2.fromOffset(30, 28), UDim2.new(1, -76, 0, 18), function()
    State.Minimized = not State.Minimized
    root.Size = State.Minimized and UDim2.fromOffset(700, 66) or UDim2.fromOffset(700, 470)
    minimizeButton.Text = State.Minimized and "+" or "—"
end)
minimizeButton.BackgroundColor3 = Settings.Card

local closeButton = button(header, "×", UDim2.fromOffset(30, 28), UDim2.new(1, -38, 0, 18), function()
    State.Destroyed = true
    gui:Destroy()
end)
closeButton.BackgroundColor3 = Color3.fromRGB(95, 30, 54)

local dragActive = false
local dragStart
local startPosition
track(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragActive = true
        dragStart = input.Position
        startPosition = root.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragActive = false
            end
        end)
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if dragActive and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        root.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end))

local sidebar = make("Frame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(10, 76),
    Size = UDim2.new(0, 150, 1, -86),
    BackgroundColor3 = Settings.Panel,
    BorderSizePixel = 0,
}, root)
corner(sidebar, 10)
padding(sidebar, 8, 8, 10, 10)
local sideList = listLayout(sidebar, 7)

local content = make("Frame", {
    Name = "Content",
    Position = UDim2.fromOffset(170, 76),
    Size = UDim2.new(1, -180, 1, -86),
    BackgroundColor3 = Settings.Panel,
    BorderSizePixel = 0,
}, root)
corner(content, 10)

local pages = {}
local navButtons = {}
local function createPage(pageName)
    local scroll = makeScroll(content, pageName)
    scroll.Visible = false
    pages[pageName] = scroll
    return scroll
end

local homePage = createPage("Home")
local labPage = createPage("Practice Lab")
local playerPage = createPage("Player")
local settingsPage = createPage("Settings")
local diagnosticsPage = createPage("Diagnostics")

local function showPage(pageName)
    if not pages[pageName] then
        return
    end
    State.CurrentPage = pageName
    for name, pageObject in pairs(pages) do
        pageObject.Visible = name == pageName
    end
    for name, navButton in pairs(navButtons) do
        navButton.BackgroundColor3 = name == pageName and Settings.AccentSoft or Settings.Card
        navButton.TextColor3 = name == pageName and Settings.Text or Settings.Muted
    end
end

local function addNav(name, glyph)
    local navButton = make("TextButton", {
        Name = name .. "Button",
        AutoButtonColor = false,
        Text = glyph .. "   " .. name,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Settings.Muted,
        BackgroundColor3 = Settings.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 36),
    }, sidebar)
    corner(navButton, 8)
    padding(navButton, 10, 4, 0, 0)
    navButtons[name] = navButton
    track(navButton.Activated:Connect(function()
        showPage(name)
    end))
    return navButton
end

addNav("Home", "⌂")
addNav("Practice Lab", "◇")
addNav("Player", "♙")
addNav("Settings", "⚙")
addNav("Diagnostics", "≡")

local mobileButton = button(gui, "ST4R", UDim2.fromOffset(58, 36), UDim2.new(1, -72, 1, -54), function()
    root.Visible = not root.Visible
end)
mobileButton.Visible = UserInputService.TouchEnabled
corner(mobileButton, 10)

local toastLayer = make("Frame", {
    Name = "ToastLayer",
    BackgroundTransparency = 1,
    Size = UDim2.fromOffset(300, 180),
    Position = UDim2.new(1, -315, 0, 18),
}, gui)
local toastLayout = make("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top,
}, toastLayer)

local function notify(titleText, bodyText, kind)
    if not Settings.Notifications then
        return
    end
    local tint = kind == "success" and Settings.Success
        or kind == "warning" and Settings.Warning
        or kind == "error" and Settings.Danger
        or Settings.Accent
    local toast = make("Frame", {
        BackgroundColor3 = Settings.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 66),
    }, toastLayer)
    corner(toast, 9)
    outline(toast, tint, 1.2, 0.25)
    make("Frame", {
        BackgroundColor3 = tint,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -14),
        Position = UDim2.fromOffset(7, 7),
    }, toast)
    text(toast, titleText, UDim2.new(1, -28, 0, 22), UDim2.fromOffset(18, 7), 12, Settings.Text, Enum.Font.GothamBold)
    text(toast, bodyText, UDim2.new(1, -28, 0, 29), UDim2.fromOffset(18, 30), 9, Settings.Muted)
    task.delay(3.5, function()
        if toast.Parent then
            tween(toast, 0.18, {BackgroundTransparency = 1})
            task.wait(0.2)
            toast:Destroy()
        end
    end)
end

local function makeToggle(parent, titleText, description, initial, callback)
    local item = card(parent, 66)
    text(item, titleText, UDim2.new(1, -92, 0, 23), UDim2.fromOffset(12, 7), 12, Settings.Text, Enum.Font.GothamBold)
    text(item, description, UDim2.new(1, -100, 0, 24), UDim2.fromOffset(12, 32), 9, Settings.Muted)
    local enabled = initial == true
    local control = button(item, enabled and "ON" or "OFF", UDim2.fromOffset(54, 28), UDim2.new(1, -66, 0.5, -14), nil)
    local function set(value, silent)
        enabled = value == true
        control.Text = enabled and "ON" or "OFF"
        control.BackgroundColor3 = enabled and Settings.Accent or Color3.fromRGB(65, 55, 78)
        if callback then
            safeCall(callback, enabled)
        end
        if not silent then
            log("SETTING", titleText .. " = " .. tostring(enabled))
        end
    end
    track(control.Activated:Connect(function()
        set(not enabled)
    end))
    set(enabled, true)
    State.Toggles[titleText] = set
    return set
end

local function makeInput(parent, titleText, description, defaultValue, callback, placeholder)
    local item = card(parent, 76)
    text(item, titleText, UDim2.new(1, -150, 0, 22), UDim2.fromOffset(12, 7), 12, Settings.Text, Enum.Font.GothamBold)
    text(item, description, UDim2.new(1, -150, 0, 28), UDim2.fromOffset(12, 34), 9, Settings.Muted)
    local input = make("TextBox", {
        Text = tostring(defaultValue or ""),
        PlaceholderText = placeholder or "Digite aqui",
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Settings.Text,
        PlaceholderColor3 = Settings.Muted,
        BackgroundColor3 = Settings.Panel,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(122, 32),
        Position = UDim2.new(1, -134, 0.5, -16),
    }, item)
    corner(input, 7)
    outline(input, Settings.Accent, 1, 0.6)
    track(input.FocusLost:Connect(function(enterPressed)
        if callback then
            safeCall(callback, input.Text, enterPressed)
        end
    end))
    return input
end

local function makeSlider(parent, titleText, description, minValue, maxValue, initial, callback)
    local item = card(parent, 86)
    text(item, titleText, UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 5), 12, Settings.Text, Enum.Font.GothamBold)
    local valueLabel = text(item, tostring(initial), UDim2.fromOffset(70, 18), UDim2.new(1, -82, 0, 6), 10, Settings.Accent, Enum.Font.GothamBold)
    text(item, description, UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 26), 9, Settings.Muted)
    local bar = make("Frame", {
        BackgroundColor3 = Settings.Panel,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -26, 0, 8),
        Position = UDim2.fromOffset(13, 62),
    }, item)
    corner(bar, 5)
    local fill = make("Frame", {
        BackgroundColor3 = Settings.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new((initial - minValue) / (maxValue - minValue), 0, 1, 0),
    }, bar)
    corner(fill, 5)
    local knob = make("Frame", {
        BackgroundColor3 = Settings.Text,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, 0),
    }, bar)
    corner(knob, 8)
    local dragging = false
    local value = initial
    local function updateFromX(x)
        local width = math.max(bar.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
        value = minValue + (maxValue - minValue) * alpha
        value = math.floor(value * 100 + 0.5) / 100
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(value)
        if callback then
            safeCall(callback, value)
        end
    end
    track(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    return function(newValue)
        value = math.clamp(newValue, minValue, maxValue)
        local alpha = (value - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(value)
        if callback then safeCall(callback, value) end
    end
end

local function makeAction(parent, titleText, description, actionText, callback)
    local item = card(parent, 68)
    text(item, titleText, UDim2.new(1, -140, 0, 22), UDim2.fromOffset(12, 7), 12, Settings.Text, Enum.Font.GothamBold)
    text(item, description, UDim2.new(1, -140, 0, 25), UDim2.fromOffset(12, 34), 9, Settings.Muted)
    button(item, actionText, UDim2.fromOffset(112, 30), UDim2.new(1, -124, 0.5, -15), callback)
    return item
end

local function refreshCharacter()
    local character = player.Character
    State.Character = character
    State.Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
    State.RootPart = character and character:FindFirstChild("HumanoidRootPart") or nil
    State.LastHealth = State.Humanoid and State.Humanoid.Health or nil
end

refreshCharacter()
track(player.CharacterAdded:Connect(function()
    task.wait(0.25)
    refreshCharacter()
    notify("Personagem atualizado", "O monitor local encontrou o novo personagem.", "success")
end))

-- HOME PAGE
section(homePage, "CROWN CONTROL", "Painel principal do ST4R HUB — ferramentas locais e de desenvolvimento.")
local welcomeCard = card(homePage, 90)
text(welcomeCard, "Bem-vindo ao ST4R HUB", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(14, 12), 17, Settings.Text, Enum.Font.GothamBlack)
text(welcomeCard, "Violet Crown Edition • Studio build • interface independente", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(14, 45), 10, Settings.Muted)
local quickRow = make("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 78),
}, homePage)
local quickLayout = make("UIGridLayout", {
    CellSize = UDim2.new(0.32, -5, 1, 0),
    CellPadding = UDim2.fromOffset(8, 0),
    FillDirectionMaxCells = 3,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, quickRow)

local function metricCard(parent, titleText, initialValue)
    local item = card(parent, 78)
    text(item, titleText, UDim2.new(1, -16, 0, 18), UDim2.fromOffset(10, 8), 9, Settings.Muted, Enum.Font.GothamBold)
    local valueLabel = text(item, initialValue, UDim2.new(1, -16, 0, 31), UDim2.fromOffset(10, 31), 19, Settings.Text, Enum.Font.GothamBlack)
    return valueLabel
end

local healthMetric = metricCard(quickRow, "HEALTH", "--")
local speedMetric = metricCard(quickRow, "WALK SPEED", "--")
local fpsMetric = metricCard(quickRow, "CLIENT FPS", "--")

section(homePage, "QUICK ACTIONS", "Atalhos seguros para diagnóstico e prática.")
makeAction(homePage, "Open Practice Lab", "Treine padrões em um minigame isolado.", "OPEN LAB", function()
    showPage("Practice Lab")
end)
makeAction(homePage, "Refresh character", "Atualiza as referências do seu personagem local.", "REFRESH", function()
    refreshCharacter()
    notify("Atualizado", "Referências locais do personagem renovadas.", "success")
end)
makeAction(homePage, "Read-only stamina monitor", "Lê atributos públicos do seu próprio personagem; não altera valores.", "CHECK", function()
    local character = player.Character
    local stamina = character and character:GetAttribute("Stamina")
    local maxStamina = character and character:GetAttribute("MaxStamina")
    notify("Stamina local", ("Stamina: %s | Máximo: %s"):format(tostring(stamina or "sem atributo"), tostring(maxStamina or "sem atributo")), "warning")
end)

-- PRACTICE LAB PAGE
section(labPage, "GENERATOR PRACTICE LAB", "Simulador independente. Não se conecta aos geradores de partidas públicas.")
local labStatus = card(labPage, 74)
local labStatusText = text(labStatus, "LAB STATUS: READY", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 8), 13, Settings.Success, Enum.Font.GothamBold)
local labScoreText = text(labStatus, "Score: 0  •  Best: 0  •  Round: 0", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 37), 10, Settings.Muted)

local promptCard = card(labPage, 130)
text(promptCard, "PRACTICE PROMPT", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 8), 10, Settings.Muted, Enum.Font.GothamBold)
local promptText = text(promptCard, "Press START to generate a practice sequence.", UDim2.new(1, -24, 0, 58), UDim2.fromOffset(12, 34), 18, Settings.Text, Enum.Font.GothamBlack)
local answerBox = make("TextBox", {
    PlaceholderText = "Digite a resposta ou sequência",
    Text = "",
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Settings.Text,
    PlaceholderColor3 = Settings.Muted,
    BackgroundColor3 = Settings.Panel,
    BorderSizePixel = 0,
    Size = UDim2.new(1, -24, 0, 30),
    Position = UDim2.fromOffset(12, 91),
}, promptCard)
corner(answerBox, 7)
outline(answerBox, Settings.Accent, 1, 0.6)

local function updateLabLabels()
    labScoreText.Text = ("Score: %d  •  Best: %d  •  Round: %d"):format(
        State.Practice.Score, State.Practice.Best, State.Practice.Round
    )
end

local function makePrompt()
    local difficulty = State.Practice.Difficulty
    local count = difficulty == "Easy" and 3 or difficulty == "Hard" and 7 or 5
    local sequence = {}
    for index = 1, count do
        sequence[index] = tostring(math.random(1, 4))
    end
    State.Practice.CurrentPrompt = table.concat(sequence, "")
    State.Practice.Round += 1
    promptText.Text = ("Memorize: %s"):format(table.concat(sequence, "  •  "))
    answerBox.Text = ""
    labStatusText.Text = "LAB STATUS: SEQUENCE READY"
    labStatusText.TextColor3 = Settings.Warning
    updateLabLabels()
end

local function submitPrompt()
    if not State.Practice.CurrentPrompt then
        notify("Practice Lab", "Clique em NEXT ROUND primeiro.", "warning")
        return
    end
    local answer = answerBox.Text:gsub("%s+", "")
    if answer == State.Practice.CurrentPrompt then
        State.Practice.Score += 10
        State.Practice.Best = math.max(State.Practice.Best, State.Practice.Score)
        labStatusText.Text = "LAB STATUS: CORRECT"
        labStatusText.TextColor3 = Settings.Success
        notify("Boa!", "+10 pontos no treino local.", "success")
    else
        State.Practice.Score = math.max(0, State.Practice.Score - 2)
        labStatusText.Text = "LAB STATUS: TRY AGAIN"
        labStatusText.TextColor3 = Settings.Danger
        notify("Não foi dessa vez", "Confira a sequência e tente novamente.", "error")
    end
    State.Practice.CurrentPrompt = nil
    updateLabLabels()
end

local labActions = make("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 38),
}, labPage)
local labGrid = make("UIGridLayout", {
    CellSize = UDim2.new(0.32, -4, 1, 0),
    CellPadding = UDim2.fromOffset(8, 0),
    FillDirectionMaxCells = 3,
}, labActions)
button(labActions, "NEXT ROUND", UDim2.new(), UDim2.new(), makePrompt)
button(labActions, "SUBMIT", UDim2.new(), UDim2.new(), submitPrompt)
button(labActions, "RESET", UDim2.new(), UDim2.new(), function()
    State.Practice.Score = 0
    State.Practice.Round = 0
    State.Practice.CurrentPrompt = nil
    promptText.Text = "Press NEXT ROUND to begin."
    answerBox.Text = ""
    labStatusText.Text = "LAB STATUS: READY"
    labStatusText.TextColor3 = Settings.Success
    updateLabLabels()
end)

makeInput(labPage, "Difficulty", "Digite Easy, Normal ou Hard e pressione Enter.", "Normal", function(value)
    local normalized = value:lower()
    if normalized == "easy" then
        State.Practice.Difficulty = "Easy"
    elseif normalized == "normal" then
        State.Practice.Difficulty = "Normal"
    elseif normalized == "hard" then
        State.Practice.Difficulty = "Hard"
    else
        notify("Dificuldade inválida", "Use Easy, Normal ou Hard.", "warning")
        return
    end
    notify("Dificuldade alterada", State.Practice.Difficulty, "success")
end)

-- PLAYER PAGE
section(playerPage, "PLAYER MONITOR", "Leitura local do seu personagem. Os valores não são modificados.")
local playerInfo = card(playerPage, 110)
local playerInfoText = text(playerInfo, "Carregando personagem...", UDim2.new(1, -24, 1, -18), UDim2.fromOffset(12, 9), 11, Settings.Text)
playerInfoText.TextYAlignment = Enum.TextYAlignment.Top

local staminaInfo = card(playerPage, 78)
text(staminaInfo, "STAMINA ATTRIBUTES", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 7), 11, Settings.Text, Enum.Font.GothamBold)
local staminaInfoText = text(staminaInfo, "Stamina: —   |   MaxStamina: —", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 36), 10, Settings.Muted)

makeAction(playerPage, "Refresh player data", "Atualiza posição, vida, velocidade e atributos.", "REFRESH", function()
    refreshCharacter()
    notify("Player monitor", "Dados locais atualizados.", "success")
end)

makeAction(playerPage, "Copy local coordinates", "Copia a posição do seu personagem para o Output.", "PRINT", function()
    local rootPart = State.RootPart
    if rootPart then
        local p = rootPart.Position
        log("POSITION", ("X %.2f | Y %.2f | Z %.2f"):format(p.X, p.Y, p.Z))
        notify("Coordinates", "Posição registrada no Output do Studio.", "success")
    else
        notify("Sem personagem", "Não foi possível encontrar HumanoidRootPart.", "warning")
    end
end)

-- SETTINGS PAGE
section(settingsPage, "SETTINGS", "Ajuste a aparência e o comportamento da interface.")
makeSlider(settingsPage, "UI Scale", "Tamanho geral da interface.", 0.75, 1.2, Settings.Scale, function(value)
    Settings.Scale = value
    scale.Scale = value
end)

makeToggle(settingsPage, "Reduce motion", "Desativa transições animadas.", Settings.ReduceMotion, function(value)
    Settings.ReduceMotion = value
end)

makeToggle(settingsPage, "Notifications", "Mostra avisos no canto superior direito.", Settings.Notifications, function(value)
    Settings.Notifications = value
end)

makeToggle(settingsPage, "High contrast", "Aumenta contraste de textos e painéis.", Settings.HighContrast, function(value)
    Settings.HighContrast = value
    Settings.Text = value and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(245, 239, 255)
    Settings.Muted = value and Color3.fromRGB(210, 202, 225) or Color3.fromRGB(168, 153, 190)
    root.BackgroundColor3 = value and Color3.fromRGB(0, 0, 0) or Settings.Background
end)

makeAction(settingsPage, "Restore default layout", "Reabre e centraliza a janela.", "RESTORE", function()
    State.Minimized = false
    root.Visible = true
    root.Size = UDim2.fromOffset(700, 470)
    root.Position = UDim2.fromScale(0.5, 0.5)
    scale.Scale = 1
    Settings.Scale = 1
    notify("Layout restaurado", "Interface centralizada.", "success")
end)

makeAction(settingsPage, "Reset local session", "Limpa pontuação do laboratório e o log.", "RESET", function()
    State.Practice.Score = 0
    State.Practice.Round = 0
    State.Practice.CurrentPrompt = nil
    table.clear(State.Logs)
    updateLabLabels()
    log("INFO", "Sessão local reiniciada.")
    notify("Sessão limpa", "Pontuação e log reiniciados.", "success")
end)

-- DIAGNOSTICS PAGE
section(diagnosticsPage, "DIAGNOSTICS", "Informações úteis para desenvolvimento e depuração.")
local diagnosticsCard = card(diagnosticsPage, 115)
local diagnosticsText = text(diagnosticsCard, "Aguardando diagnóstico...", UDim2.new(1, -24, 1, -16), UDim2.fromOffset(12, 8), 10, Settings.Muted)
diagnosticsText.TextYAlignment = Enum.TextYAlignment.Top

local logCard = card(diagnosticsPage, 210)
text(logCard, "RECENT LOG", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 6), 11, Settings.Text, Enum.Font.GothamBold)
local logText = text(logCard, "Nenhum evento registrado.", UDim2.new(1, -24, 1, -34), UDim2.fromOffset(12, 29), 9, Settings.Muted)
logText.TextYAlignment = Enum.TextYAlignment.Top

makeAction(diagnosticsPage, "Write diagnostic snapshot", "Registra informações básicas no Output do Studio.", "SNAPSHOT", function()
    refreshCharacter()
    log("SNAPSHOT", "Player=" .. player.Name)
    log("SNAPSHOT", "Character=" .. tostring(State.Character ~= nil))
    log("SNAPSHOT", "Humanoid=" .. tostring(State.Humanoid ~= nil))
    log("SNAPSHOT", "RootPart=" .. tostring(State.RootPart ~= nil))
    notify("Snapshot", "Diagnóstico registrado no Output.", "success")
end)

makeAction(diagnosticsPage, "Clear log", "Remove as mensagens do painel.", "CLEAR", function()
    table.clear(State.Logs)
    logText.Text = "Log limpo."
end)

-- LIVE REFRESH
local frameCounter = 0
local elapsed = 0
local currentFps = 0

track(RunService.RenderStepped:Connect(function(deltaTime)
    if State.Destroyed then
        return
    end
    frameCounter += 1
    elapsed += deltaTime
    if elapsed >= 0.5 then
        currentFps = math.floor(frameCounter / elapsed + 0.5)
        frameCounter = 0
        elapsed = 0
        fpsMetric.Text = tostring(currentFps)
        local humanoid = State.Humanoid
        if humanoid then
            healthMetric.Text = ("%d/%d"):format(math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
            speedMetric.Text = tostring(math.floor(humanoid.WalkSpeed + 0.5))
        else
            healthMetric.Text = "--"
            speedMetric.Text = "--"
        end
    end
end))

local refreshAccumulator = 0
track(RunService.Heartbeat:Connect(function(deltaTime)
    refreshAccumulator += deltaTime
    if refreshAccumulator < 0.75 or State.Destroyed then
        return
    end
    refreshAccumulator = 0
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid then
        State.Humanoid = humanoid
        State.RootPart = rootPart
        local healthPercent = humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 0
        playerInfoText.Text = ("Name: %s\nHealth: %.1f / %.1f (%.0f%%)\nWalkSpeed: %.1f\nJumpPower: %.1f\nCharacter: %s\nRootPart: %s"):format(
            player.Name,
            humanoid.Health,
            humanoid.MaxHealth,
            healthPercent * 100,
            humanoid.WalkSpeed,
            humanoid.JumpPower,
            tostring(character ~= nil),
            tostring(rootPart ~= nil)
        )
    else
        playerInfoText.Text = "Humanoid não encontrado."
    end
    local stamina = character and character:GetAttribute("Stamina")
    local maximum = character and character:GetAttribute("MaxStamina")
    staminaInfoText.Text = ("Stamina: %s   |   MaxStamina: %s"):format(
        tostring(stamina or "—"),
        tostring(maximum or "—")
    )
    if Settings.ShowDiagnostics then
        diagnosticsText.Text = ("Client FPS: %d\nPlatform: %s\nTouch enabled: %s\nCharacter loaded: %s\nHumanoid loaded: %s\nRootPart loaded: %s\nCurrent page: %s\nUI scale: %.2f"):format(
            currentFps,
            GuiService:IsTenFootInterface() and "Ten-foot" or (UserInputService.TouchEnabled and "Touch" or "Desktop"),
            tostring(UserInputService.TouchEnabled),
            tostring(character ~= nil),
            tostring(humanoid ~= nil),
            tostring(rootPart ~= nil),
            State.CurrentPage,
            Settings.Scale
        )
    end
    local lines = {}
    for index = 1, math.min(#State.Logs, 9) do
        local entry = State.Logs[index]
        table.insert(lines, ("[%s][%s] %s"):format(entry.Time, entry.Level, entry.Message))
    end
    logText.Text = #lines > 0 and table.concat(lines, "\n") or "Nenhum evento registrado."
end))

-- SAFE KEYBOARD SHORTCUTS
track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or State.Destroyed then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        root.Visible = not root.Visible
    elseif input.KeyCode == Enum.KeyCode.Escape and root.Visible then
        root.Visible = false
    end
end))

-- RESPONSIVE SIZE
local function applyResponsive()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local viewport = camera.ViewportSize
    if viewport.X < 760 or viewport.Y < 540 then
        root.Size = UDim2.new(0.94, 0, 0.78, 0)
        root.Position = UDim2.fromScale(0.5, 0.5)
    else
        root.Size = UDim2.fromOffset(700, 470)
    end
end

if workspace.CurrentCamera then
    track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsive))
end
applyResponsive()

-- CLEANUP
local function cleanup()
    if State.Destroyed then
        return
    end
    State.Destroyed = true
    for _, connection in ipairs(State.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(State.Connections)
    if gui and gui.Parent then
        gui:Destroy()
    end
end

track(gui.Destroying:Connect(function()
    State.Destroyed = true
    for _, connection in ipairs(State.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(State.Connections)
end))

showPage("Home")
log("READY", "ST4R HUB Studio Edition carregado.")
notify("ST4R HUB", "Violet Crown Edition inicializada.", "success")

-- End of ST4R HUB Studio Edition.
