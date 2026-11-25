-- FORSAKEN ULTIMATE HUB | Executor single-file build
-- Client-side information, local ESP and UI utilities.
-- No server/backend/key system is bundled.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Modules = {}


-- ===== Config =====
Modules.Config = (function()
local Config = {}

Config.Name = "FORSAKEN ULTIMATE HUB"
Config.Version = "1.1.0-executor"
Config.Theme = {
    Background = Color3.fromRGB(13, 13, 19),
    Panel = Color3.fromRGB(22, 21, 31),
    PanelAlt = Color3.fromRGB(30, 27, 42),
    Accent = Color3.fromRGB(190, 45, 75),
    Accent2 = Color3.fromRGB(132, 70, 190),
    Text = Color3.fromRGB(242, 239, 247),
    Muted = Color3.fromRGB(157, 151, 171),
    Good = Color3.fromRGB(86, 190, 132),
    Bad = Color3.fromRGB(225, 83, 91),
}
Config.KeyPortalUrl = "" -- FILL: URL oficial de obtenção da key; vazio oculta o botão.
Config.WelcomeSoundId = "" -- FILL: asset de áudio original/licenciado, ex.: rbxassetid://123
Config.Defaults = {
    ESP = false,
    ShowDistance = true,
    ShowNames = true,
    FOV = 70,
    ReduceAnimations = false,
    WelcomeSound = true,
    SoundVolume = 0.35,
    UIScale = 1,
    Transparency = 0,
}
Config.DataAttributes = {
    -- Somente atributos publicados pelo servidor da experiência podem ser lidos aqui.
    -- Não preencher com nomes supostos de módulos internos do Forsaken.
    Stamina = "Hub_Stamina",
    StaminaMax = "Hub_StaminaMax",
    Sprinting = "Hub_Sprinting",
    Role = "Hub_Role",
    MatchState = "Hub_MatchState",
    MatchTime = "Hub_MatchTime",
    AliveCount = "Hub_AliveCount",
    ObjectiveProgress = "Hub_ObjectiveProgress",
}
return Config
end)()


-- ===== Diagnostics =====
Modules.Diagnostics = (function()
local Diagnostics = {}
local entries = {}
local MAX_ENTRIES = 80

function Diagnostics.Log(level, message)
    local item = {
        time = os.date("!%H:%M:%S"),
        level = tostring(level),
        message = tostring(message):sub(1, 220),
    }
    table.insert(entries, item)
    if #entries > MAX_ENTRIES then table.remove(entries, 1) end
    if level == "error" then
        warn("[ForsakenHub] " .. item.message)
    end
end

function Diagnostics.GetEntries()
    return table.clone(entries)
end

function Diagnostics.Protect(label, callback, ...)
    local args = table.pack(...)
    local ok, result = pcall(function()
        return callback(table.unpack(args, 1, args.n))
    end)
    if not ok then Diagnostics.Log("error", label .. ": " .. tostring(result)) end
    return ok, result
end
return Diagnostics
end)()


-- ===== Settings =====
Modules.Settings = (function()
local Players = game:GetService("Players")
local Config = Modules.Config

local Settings = {}
local values = table.clone(Config.Defaults)
local player = Players.LocalPlayer

function Settings.Get(key) return values[key] end
function Settings.Set(key, value)
    if values[key] == nil then return false end
    values[key] = value
    if key == "FOV" and workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = math.clamp(tonumber(value) or 70, 50, 100)
    elseif key == "UIScale" then
        local gui = player:FindFirstChildOfClass("PlayerGui")
        local screen = gui and gui:FindFirstChild("ForsakenUltimateHub")
        local scale = screen and screen:FindFirstChild("RootScale", true)
        if scale and scale:IsA("UIScale") then scale.Scale = math.clamp(tonumber(value) or 1, 0.75, 1.25) end
    elseif key == "Transparency" then
        -- Aplicado pelo construtor de UI às superfícies criadas; valor mantido em memória.
        values.Transparency = math.clamp(tonumber(value) or 0, 0, 0.35)
    end
    return true
end
function Settings.Snapshot() return table.clone(values) end
return Settings
end)()


-- ===== Profile =====
Modules.Profile = (function()
local Players = game:GetService("Players")
local Profile = {}

function Profile.Load()
    local player = Players.LocalPlayer
    local result = {
        Username = player.Name,
        DisplayName = player.DisplayName,
        UserId = player.UserId,
        Thumbnail = nil,
        ThumbnailReady = false,
    }
    local ok, image = pcall(function()
        local content, ready = Players:GetUserThumbnailAsync(
            player.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150
        )
        result.ThumbnailReady = ready
        return content
    end)
    if ok then result.Thumbnail = image end
    return result
end
return Profile
end)()


-- ===== PlayerInfo =====
Modules.PlayerInfo = (function()
local Players = game:GetService("Players")
local Config = Modules.Config
local PlayerInfo = {}

function PlayerInfo.ReadLocal()
    local player = Players.LocalPlayer
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local stamina = player:GetAttribute(Config.DataAttributes.Stamina)
    local staminaMax = player:GetAttribute(Config.DataAttributes.StaminaMax)
    local sprinting = player:GetAttribute(Config.DataAttributes.Sprinting)
    return {
        Health = humanoid and humanoid.Health or nil,
        MaxHealth = humanoid and humanoid.MaxHealth or nil,
        MoveSpeed = humanoid and humanoid.WalkSpeed or nil,
        Stamina = typeof(stamina) == "number" and stamina or nil,
        StaminaMax = typeof(staminaMax) == "number" and staminaMax or nil,
        Sprinting = typeof(sprinting) == "boolean" and sprinting or nil,
    }
end
return PlayerInfo
end)()


-- ===== StaminaInfo =====
Modules.StaminaInfo = (function()
-- Forsaken public-stat reference plus safe live-data reader.
-- This module intentionally does not mutate the target game's stamina.
local Players = game:GetService("Players")
local Config = Modules.Config
local StaminaInfo = {}

StaminaInfo.Reference = {
    Survivor = {Max = 100, DrainPerSecond = 10, RegenPerSecond = 20, ExhaustDelay = 2},
    Killer = {Max = 110, DrainPerSecond = 9.5, RegenPerSecond = 21, ExhaustDelay = 2},
}

function StaminaInfo.ReadLive()
    local player = Players.LocalPlayer
    local value = player:GetAttribute(Config.DataAttributes.Stamina)
    local maximum = player:GetAttribute(Config.DataAttributes.StaminaMax)
    local sprinting = player:GetAttribute(Config.DataAttributes.Sprinting)
    if typeof(value) == "number" then
        return {
            Available = true,
            Value = value,
            Max = typeof(maximum) == "number" and maximum or nil,
            Sprinting = typeof(sprinting) == "boolean" and sprinting or nil,
        }
    end
    return {Available = false}
end

function StaminaInfo.GetReference(role)
    if role == "Killer" then return table.clone(StaminaInfo.Reference.Killer) end
    return table.clone(StaminaInfo.Reference.Survivor)
end
return StaminaInfo
end)()


-- ===== GeneratorGuide =====
Modules.GeneratorGuide = (function()
-- Publicly documented puzzle guide. Values reflect the newer 5.1.0/5.3.0
-- descriptions found in current community guides citing Official Wiki rev 91169.
local GeneratorGuide = {}
GeneratorGuide.Summary = {
    GeneratorCount = 5,
    LayersPerGenerator = 5,
    PuzzleTypes = {"Dot Numberlink", "Blob Numberlink", "Gears", "Locks"},
    TimeRemovedPerLayer = 2.4,
    ExpPerLayer = 8,
    MalicePerLayer = 0.25,
    MaxRepairers = 3,
}

GeneratorGuide.Types = {
    ["Dot Numberlink"] = {
        Goal = "Ligue cada par de pontos com o mesmo número/cor numa grade 7x7, sem cruzar fios.",
        Steps = "Identifique todos os pares; planeje primeiro os cantos e bordas; conecte sem bloquear os pares restantes. Não é necessário preencher todas as células.",
        Automation = "O solver recebe uma grade e coordenadas de endpoints. A leitura automática da grade do Forsaken ainda não está integrada.",
    },
    ["Blob Numberlink"] = {
        Goal = "Arraste cada blob numerado até o blob com o mesmo número; os caminhos podem ser mais livres que na grade de fios.",
        Steps = "Agrupe os blobs por número e conecte cada origem ao destino correspondente.",
        Automation = "O pareamento por identificador pode ser resolvido; a captura de posição e o arraste da interface do jogo não estão confirmados.",
    },
    ["Gears"] = {
        Goal = "Encontre engrenagens espalhadas pelo mapa, leve-as ao gerador e gire cada uma na direção correta para encaixar. São cinco engrenagens por objetivo, conforme o guia consultado.",
        Steps = "Procure os itens de engrenagem no mapa, colete-os e retorne ao gerador. Observe a direção indicada pelo próprio minigame.",
        Automation = "Não há regra pública suficiente sobre orientação, rotação e interação para automatizar sem ler o estado real da tela.",
    },
    ["Locks"] = {
        Goal = "Acerte o comando quando o ponteiro giratório estiver sobre a marca branca. Sete acertos concluem uma camada; a janela fica menor e o ponteiro acelera. Um erro reinicia a contagem.",
        Steps = "Observe o arco branco, acompanhe o ponteiro e pressione dentro da janela. Ajuste o timing conforme a velocidade aumenta.",
        Automation = "O cálculo do instante depende de ângulo, velocidade e janela obtidos da interface; esses sinais não estão expostos por API pública confirmada.",
    },
}

GeneratorGuide.FakeGenerator = {
    Trigger = "Noli pode criar geradores falsos com Prankster.",
    Tells = {
        "Fios escurecidos/manchados e ruído de glitch.",
        "Barra de progresso com tom de verde diferente.",
        "Número de par ausente em puzzles numerados.",
        "Mensagem de recompensa usa 'objective' em vez de 'puzzle'.",
        "Contador de objetivos pode oscilar após uma interação falsa.",
    },
}

function GeneratorGuide.GetSummaryText()
    local s = GeneratorGuide.Summary
    return string.format("%d geradores por mapa; %d camadas por gerador; até %d jogadores simultâneos. Cada camada remove %.1fs.",
        s.GeneratorCount, s.LayersPerGenerator, s.MaxRepairers, s.TimeRemovedPerLayer)
end
return GeneratorGuide
end)()


-- ===== GeneratorSolver =====
Modules.GeneratorSolver = (function()
-- Puzzle solvers independent from Forsaken's private UI implementation.
-- They only solve state supplied by a caller; they do not inspect or control another experience.
local GeneratorSolver = {}

local function cellKey(r, c) return tostring(r) .. ":" .. tostring(c) end
local function manhattan(a, b) return math.abs(a.r-b.r) + math.abs(a.c-b.c) end

-- pairs = {{id=1, a={r=1,c=1}, b={r=7,c=7}}, ...}
-- blocked = { ["r:c"] = true }
-- Returns {Solved=true, Paths={ [id]={{r=..,c=..},...} }} or a reason.
function GeneratorSolver.SolveDotNumberlink(size, endpoints, blocked, nodeLimit)
    size = math.floor(tonumber(size) or 7)
    if size < 2 or size > 10 or type(endpoints) ~= "table" or #endpoints == 0 then
        return {Solved=false, Reason="Entrada inválida."}
    end
    blocked = blocked or {}
    nodeLimit = math.clamp(tonumber(nodeLimit) or 12000, 100, 100000)

    local endpointOwner, occupied = {}, {}
    for _, pair in ipairs(endpoints) do
        if not pair.a or not pair.b then return {Solved=false, Reason="Par sem dois endpoints."} end
        local ka, kb = cellKey(pair.a.r, pair.a.c), cellKey(pair.b.r, pair.b.c)
        if endpointOwner[ka] or endpointOwner[kb] or ka == kb then
            return {Solved=false, Reason="Endpoints duplicados."}
        end
        endpointOwner[ka], endpointOwner[kb] = pair.id, pair.id
    end
    for key, value in pairs(blocked) do if value then occupied[key] = true end end

    local ordered = table.clone(endpoints)
    table.sort(ordered, function(a,b) return manhattan(a.a,a.b) < manhattan(b.a,b.b) end)
    local solution, nodes = {}, 0
    local directions = {{1,0},{-1,0},{0,1},{0,-1}}

    local function enumerate(pair, callback)
        local startKey, goalKey = cellKey(pair.a.r,pair.a.c), cellKey(pair.b.r,pair.b.c)
        local path, seen = {{r=pair.a.r,c=pair.a.c}}, {[startKey]=true}
        local function walk(r,c)
            nodes += 1
            if nodes > nodeLimit then return false end
            local key = cellKey(r,c)
            if key == goalKey then
                local copy = {}
                for i,p in ipairs(path) do copy[i] = {r=p.r,c=p.c} end
                return callback(copy)
            end
            local nextCells = {}
            for _,d in ipairs(directions) do
                local nr,nc = r+d[1],c+d[2]
                if nr>=1 and nr<=size and nc>=1 and nc<=size then
                    local nk = cellKey(nr,nc)
                    local owner = endpointOwner[nk]
                    if not seen[nk] and not blocked[nk] and (not occupied[nk] or nk==goalKey)
                        and (not owner or owner==pair.id) then
                        table.insert(nextCells,{r=nr,c=nc,score=math.abs(nr-pair.b.r)+math.abs(nc-pair.b.c)})
                    end
                end
            end
            table.sort(nextCells,function(a,b) return a.score < b.score end)
            for _,p in ipairs(nextCells) do
                local nk=cellKey(p.r,p.c)
                seen[nk]=true; table.insert(path,{r=p.r,c=p.c})
                if walk(p.r,p.c) then return true end
                table.remove(path); seen[nk]=nil
                if nodes > nodeLimit then return false end
            end
            return false
        end
        return walk(pair.a.r,pair.a.c)
    end

    local function solve(index)
        if index > #ordered then return true end
        local pair = ordered[index]
        local found = false
        local success = enumerate(pair,function(path)
            found = true
            local added = {}
            for i=2,#path-1 do
                local k=cellKey(path[i].r,path[i].c)
                occupied[k]=true; table.insert(added,k)
            end
            solution[pair.id]=path
            if solve(index+1) then return true end
            solution[pair.id]=nil
            for _,k in ipairs(added) do occupied[k]=nil end
            return false
        end)
        return success or false
    end

    local solved = solve(1)
    if solved then return {Solved=true, Paths=solution, Nodes=nodes} end
    return {Solved=false, Reason=nodes>nodeLimit and "Limite de busca atingido; puzzle pode exigir outra heurística." or "Não foi encontrada uma solução com os dados fornecidos.", Nodes=nodes}
end

-- Blob Numberlink: match each numbered start to its numbered destination.
function GeneratorSolver.MatchBlobs(blobs)
    local starts, ends = {}, {}
    for _, blob in ipairs(blobs or {}) do
        if blob.kind == "start" then starts[blob.id] = blob.position
        elseif blob.kind == "end" then ends[blob.id] = blob.position end
    end
    local matches = {}
    for id, start in pairs(starts) do
        if ends[id] == nil then return {Solved=false, Reason="Destino ausente para blob " .. tostring(id)} end
        matches[id] = {From=start, To=ends[id]}
    end
    for id in pairs(ends) do
        if starts[id] == nil then return {Solved=false, Reason="Origem ausente para blob " .. tostring(id)} end
    end
    return {Solved=true, Matches=matches}
end

-- Lock timing helper: all angles in degrees, clockwise convention supplied by caller.
function GeneratorSolver.IsNeedleInWindow(pointerAngle, windowStart, windowEnd)
    local function norm(a) return (a % 360 + 360) % 360 end
    local p,s,e=norm(pointerAngle),norm(windowStart),norm(windowEnd)
    if s <= e then return p >= s and p <= e end
    return p >= s or p <= e
end

-- Gear direction is deliberately not guessed. Caller must supply the observed prompt.
function GeneratorSolver.CheckGearInstruction(observed, required)
    if type(observed) ~= "string" or type(required) ~= "string" then
        return {Known=false, Reason="Direção não identificada na interface."}
    end
    return {Known=true, Correct=string.lower(observed)==string.lower(required)}
end
return GeneratorSolver
end)()


-- ===== Objectives =====
Modules.Objectives = (function()
local Config = Modules.Config
local Objectives = {}

function Objectives.Read()
    local player = game:GetService("Players").LocalPlayer
    local progress = player:GetAttribute(Config.DataAttributes.ObjectiveProgress)
    if typeof(progress) == "number" then
        return {Available = true, Progress = math.clamp(progress, 0, 1)}
    end
    return {Available = false, Progress = nil}
end

function Objectives.GetStatus()
    local data = Objectives.Read()
    if not data.Available then return "Dados de objetivos: indisponível" end
    return string.format("Progresso publicado: %d%%", math.floor(data.Progress * 100 + 0.5))
end
return Objectives
end)()


-- ===== MatchInfo =====
Modules.MatchInfo = (function()
local Players = game:GetService("Players")
local Config = Modules.Config
local MatchInfo = {}

function MatchInfo.Read()
    local player = Players.LocalPlayer
    local role = player:GetAttribute(Config.DataAttributes.Role)
    local state = player:GetAttribute(Config.DataAttributes.MatchState)
    local timeLeft = player:GetAttribute(Config.DataAttributes.MatchTime)
    local alive = player:GetAttribute(Config.DataAttributes.AliveCount)
    return {
        Role = typeof(role) == "string" and role or nil,
        State = typeof(state) == "string" and state or nil,
        Time = typeof(timeLeft) == "number" and timeLeft or nil,
        Alive = typeof(alive) == "number" and alive or nil,
        PlayerCount = #Players:GetPlayers(),
    }
end
return MatchInfo
end)()


-- ===== ESP =====
Modules.ESP = (function()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = Modules.Config

local ESP = {}
local enabled = false
local showNames = true
local showDistance = true
local tracked = {}
local connection

local function clearPlayer(player)
    local item = tracked[player]
    if item then
        if item.Highlight then item.Highlight:Destroy() end
        if item.Billboard then item.Billboard:Destroy() end
        tracked[player] = nil
    end
end

local function attach(player)
    if player == Players.LocalPlayer or tracked[player] then return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "FHubPlayerHighlight"
    highlight.FillColor = Config.Theme.Accent2
    highlight.OutlineColor = Config.Theme.Accent
    highlight.FillTransparency = 0.72
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = character
    highlight.Parent = character

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "FHubPlayerLabel"
    billboard.Adornee = root
    billboard.Size = UDim2.fromOffset(180, 34)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = root

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Config.Theme.Text
    label.TextStrokeTransparency = 0.35
    label.Parent = billboard

    tracked[player] = {Highlight = highlight, Billboard = billboard, Label = label}
end

local function refresh()
    local localChar = Players.LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    for player, item in pairs(tracked) do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 or not localRoot then
            clearPlayer(player)
        else
            local parts = {}
            if showNames then table.insert(parts, player.DisplayName) end
            if showDistance then
                table.insert(parts, string.format("%.0f m", (root.Position - localRoot.Position).Magnitude))
            end
            item.Label.Text = table.concat(parts, "  •  ")
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do attach(player) end
end

function ESP.SetEnabled(value)
    enabled = value == true
    if enabled then
        for _, player in ipairs(Players:GetPlayers()) do attach(player) end
        if not connection then
            local elapsed = 0
            connection = RunService.Heartbeat:Connect(function(dt)
                elapsed += dt
                if elapsed >= 0.25 then elapsed = 0; refresh() end
            end)
        end
    else
        if connection then connection:Disconnect(); connection = nil end
        for player in pairs(tracked) do clearPlayer(player) end
    end
end
function ESP.SetNames(value) showNames = value == true; if enabled then refresh() end end
function ESP.SetDistance(value) showDistance = value == true; if enabled then refresh() end end
function ESP.Destroy() ESP.SetEnabled(false) end

Players.PlayerRemoving:Connect(clearPlayer)
return ESP
end)()


-- ===== MovementSettings =====
Modules.MovementSettings = (function()
local Settings = Modules.Settings
local MovementSettings = {}

function MovementSettings.SetFOV(value)
    return Settings.Set("FOV", math.clamp(tonumber(value) or 70, 50, 100))
end

function MovementSettings.SetReduceAnimations(value)
    return Settings.Set("ReduceAnimations", value == true)
end
return MovementSettings
end)()


-- ===== Welcome =====
Modules.Welcome = (function()
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Config = Modules.Config

local Welcome = {}

function Welcome.Show(profile, parent, reduceAnimations)
    local gui = Instance.new("Frame")
    gui.Name = "WelcomeOverlay"
    gui.Size = UDim2.fromScale(1, 1)
    gui.BackgroundColor3 = Config.Theme.Background
    gui.BackgroundTransparency = 0.04
    gui.ZIndex = 50
    gui.Parent = parent

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(340, 310)
    card.BackgroundColor3 = Config.Theme.Panel
    card.Parent = gui
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)

    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.Size = UDim2.fromOffset(92, 92)
    avatar.Position = UDim2.new(0.5, -46, 0, 28)
    avatar.BackgroundColor3 = Config.Theme.PanelAlt
    avatar.Image = profile.Thumbnail or ""
    avatar.Parent = card
    Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12, 132)
    title.Size = UDim2.new(1, -24, 0, 38)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 17
    title.TextColor3 = Config.Theme.Text
    title.Text = "Bem-vindo ao FORSAKEN ULTIMATE HUB, " .. profile.DisplayName .. "!"
    title.TextWrapped = true
    title.Parent = card

    local details = Instance.new("TextLabel")
    details.BackgroundTransparency = 1
    details.Position = UDim2.fromOffset(18, 180)
    details.Size = UDim2.new(1, -36, 0, 64)
    details.Font = Enum.Font.Gotham
    details.TextSize = 13
    details.TextColor3 = Config.Theme.Muted
    details.Text = "Username: @" .. profile.Username .. "\nUser ID: " .. tostring(profile.UserId)
    details.Parent = card

    if Config.WelcomeSoundId ~= "" and Config.Defaults.WelcomeSound then
        local sound = Instance.new("Sound")
        sound.SoundId = Config.WelcomeSoundId
        sound.Volume = Config.Defaults.SoundVolume
        sound.Parent = SoundService
        pcall(function() sound:Play() end)
        sound.Ended:Connect(function() sound:Destroy() end)
        task.delay(8, function() if sound.Parent then sound:Destroy() end end)
    end

    if not reduceAnimations then
        card.Size = UDim2.fromOffset(320, 290)
        local TweenService = game:GetService("TweenService")
        TweenService:Create(card, TweenInfo.new(0.25), {Size = UDim2.fromOffset(340, 310)}):Play()
    end
    task.delay(3.2, function()
        if gui.Parent then gui:Destroy() end
    end)
end
return Welcome
end)()


-- ===== UI =====
Modules.UI = (function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Config = Modules.Config

local UI = {}
local theme = Config.Theme
local function corner(instance, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = instance
end
local function stroke(instance, color, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or theme.Accent2
    s.Transparency = transparency or 0.55
    s.Thickness = 1
    s.Parent = instance
end
local function label(parent, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or theme.Text
    l.Font = font or Enum.Font.Gotham
    l.TextSize = size or 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Parent = parent
    return l
end
local function button(parent, text, callback, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(width or 1, 0, 0, 38)
    b.BackgroundColor3 = theme.PanelAlt
    b.Text = text
    b.TextColor3 = theme.Text
    b.TextSize = 13
    b.Font = Enum.Font.GothamSemibold
    b.AutoButtonColor = true
    b.Parent = parent
    corner(b, 9)
    b.Activated:Connect(callback)
    return b
end

function UI.Notify(root, message, isError)
    local note = Instance.new("TextLabel")
    note.AnchorPoint = Vector2.new(1, 0)
    note.Position = UDim2.new(1, -16, 0, 16)
    note.Size = UDim2.fromOffset(260, 42)
    note.BackgroundColor3 = theme.PanelAlt
    note.TextColor3 = isError and theme.Bad or theme.Text
    note.Text = tostring(message)
    note.TextSize = 12
    note.Font = Enum.Font.GothamSemibold
    note.TextWrapped = true
    note.ZIndex = 100
    note.Parent = root
    corner(note, 9)
    task.delay(2.6, function() if note.Parent then note:Destroy() end end)
end

function UI.CreateMain(onClose)
    local globalConnections = {}
    local function track(connection)
        table.insert(globalConnections, connection)
        return connection
    end
    local playerGui
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok then playerGui = result end
    end
    if not playerGui then
        local ok, result = pcall(function() return game:GetService("CoreGui") end)
        if ok then playerGui = result end
    end
    playerGui = playerGui or Players.LocalPlayer:WaitForChild("PlayerGui")
    local screen = playerGui:FindFirstChild("ForsakenUltimateHub")
    if not screen then
        screen = Instance.new("ScreenGui")
        screen.Name = "ForsakenUltimateHub"
        screen.ResetOnSpawn = false
        screen.IgnoreGuiInset = true
        screen.Parent = playerGui
    else
        screen:ClearAllChildren()
    end

    local rootScale = Instance.new("UIScale")
    rootScale.Name = "RootScale"
    rootScale.Parent = screen

    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.Size = UDim2.new(0, 650, 0, 430)
    main.BackgroundColor3 = theme.Background
    main.Parent = screen
    corner(main, 14); stroke(main, theme.Accent2, 0.35)

    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 48)
    top.BackgroundColor3 = theme.Panel
    top.Parent = main
    corner(top, 14)

    local tabs, body
    local title = label(top, Config.Name, 14, theme.Text, Enum.Font.GothamBold)
    title.Position = UDim2.fromOffset(16, 0)
    title.Size = UDim2.new(1, -120, 1, 0)

    local tabs, body
    local close = button(top, "×", function() onClose() end, 0)
    close.AnchorPoint = Vector2.new(1, 0.5)
    close.Position = UDim2.new(1, -8, 0.5, 0)
    close.Size = UDim2.fromOffset(34, 30)
    local minimize = button(top, "—", function()
        local hidden = main:GetAttribute("Minimized") == true
        main:SetAttribute("Minimized", not hidden)
        main.Size = hidden and UDim2.new(0, 650, 0, 430) or UDim2.new(0, 650, 0, 48)
        body.Visible = hidden
        tabs.Visible = hidden
    end, 0)
    minimize.AnchorPoint = Vector2.new(1, 0.5)
    minimize.Position = UDim2.new(1, -48, 0.5, 0)
    minimize.Size = UDim2.fromOffset(34, 30)

    tabs = Instance.new("ScrollingFrame")
    tabs.Position = UDim2.fromOffset(12, 60)
    tabs.Size = UDim2.new(0, 145, 1, -72)
    tabs.BackgroundColor3 = theme.Panel
    tabs.BorderSizePixel = 0
    tabs.ScrollBarThickness = 3
    tabs.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabs.Parent = main
    corner(tabs, 10)
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabs
    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, 8)
    tabPad.PaddingLeft = UDim.new(0, 7)
    tabPad.PaddingRight = UDim.new(0, 7)
    tabPad.Parent = tabs

    body = Instance.new("ScrollingFrame")
    body.Name = "Content"
    body.Position = UDim2.fromOffset(168, 60)
    body.Size = UDim2.new(1, -180, 1, -72)
    body.BackgroundColor3 = theme.Panel
    body.BorderSizePixel = 0
    body.ScrollBarThickness = 4
    body.CanvasSize = UDim2.new(0, 0, 0, 0)
    body.Parent = main
    corner(body, 10)

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 9)
    contentLayout.Parent = body
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.Parent = body

    local function updateCanvas()
        tabs.CanvasSize = UDim2.new(0, 0, 0, tabLayout.AbsoluteContentSize.Y + 18)
        body.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 28)
    end
    tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
    contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

    local function clearBody()
        for _, child in ipairs(body:GetChildren()) do
            if child:IsA("GuiObject") and child ~= contentLayout then child:Destroy() end
        end
    end
    local function addText(text, height)
        local l = label(body, text, 13, theme.Muted)
        l.Size = UDim2.new(1, -4, 0, height or 42)
        return l
    end
    local function addButton(text, callback)
        local b = button(body, text, callback)
        b.Size = UDim2.new(1, -4, 0, 38)
        return b
    end
    local function addToggle(text, initial, callback)
        local state = initial == true
        local b
        b = addButton(text .. ": " .. (state and "ON" or "OFF"), function()
            state = not state
            b.Text = text .. ": " .. (state and "ON" or "OFF")
            callback(state)
        end)
        return b
    end
    local function addSlider(text, min, max, initial, callback)
        local wrap = Instance.new("Frame")
        wrap.Size = UDim2.new(1, -4, 0, 62)
        wrap.BackgroundTransparency = 1
        wrap.Parent = body
        local l = label(wrap, text .. ": " .. tostring(initial), 12, theme.Text)
        l.Size = UDim2.new(1, 0, 0, 22)
        local bar = Instance.new("Frame")
        bar.Position = UDim2.fromOffset(0, 32)
        bar.Size = UDim2.new(1, 0, 0, 8)
        bar.BackgroundColor3 = theme.PanelAlt
        bar.Parent = wrap
        corner(bar, 6)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((initial-min)/(max-min), 0, 1, 0)
        fill.BackgroundColor3 = theme.Accent
        fill.Parent = bar
        corner(fill, 6)
        local knob = Instance.new("TextButton")
        knob.Size = UDim2.fromOffset(26, 26)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new((initial-min)/(max-min), 0, 0.5, 0)
        knob.Text = ""
        knob.BackgroundColor3 = theme.Text
        knob.Parent = bar
        corner(knob, 13)
        local dragging = false
        local function setFromX(x)
            local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + alpha * (max-min) + 0.5)
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.new(alpha, 0, 0.5, 0)
            l.Text = text .. ": " .. tostring(value)
            callback(value)
        end
        knob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
        end)
        track(UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromX(input.Position.X) end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end))
        return wrap
    end

    local tabsData = {
        "Início", "ESP", "Sobrevivente", "Geradores", "Combate", "Movimento", "Partida", "Configurações"
    }
    local renderers = {}
    local function showTab(name)
        clearBody()
        local renderer = renderers[name]
        if renderer then renderer(addText, addButton, addToggle, addSlider) end
        updateCanvas()
    end
    for _, name in ipairs(tabsData) do
        local tabName = name
        local tabButton = button(tabs, tabName, function() showTab(tabName) end)
        tabButton.Size = UDim2.new(1, 0, 0, 36)
        tabButton.TextXAlignment = Enum.TextXAlignment.Left
        tabButton.Text = "  " .. name
    end

    local function setRenderer(name, callback) renderers[name] = callback end
    local function fit()
        local camera = workspace.CurrentCamera
        if camera then rootScale.Scale = math.clamp(math.min(camera.ViewportSize.X/700, camera.ViewportSize.Y/480), 0.62, 1) end
    end
    fit()
    if workspace.CurrentCamera then track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)) end

    -- Drag da janela pelo cabeçalho; touch e mouse.
    local dragging, dragStart, startPos = false, nil, nil
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))

    return {
        Screen = screen,
        Notify = function(message, isError) UI.Notify(screen, message, isError) end,
        SetRenderer = setRenderer,
        ShowTab = showTab,
        Destroy = function()
            for _, connection in ipairs(globalConnections) do
                if connection.Connected then connection:Disconnect() end
            end
            table.clear(globalConnections)
            screen:Destroy()
        end,
    }
end
return UI
end)()


-- ===== Bootstrap =====
local Config = Modules.Config
local UI = Modules.UI
local Profile = Modules.Profile
local Welcome = Modules.Welcome
local ESP = Modules.ESP
local PlayerInfo = Modules.PlayerInfo
local StaminaInfo = Modules.StaminaInfo
local GeneratorGuide = Modules.GeneratorGuide
local Objectives = Modules.Objectives
local MatchInfo = Modules.MatchInfo
local Settings = Modules.Settings
local MovementSettings = Modules.MovementSettings
local Diagnostics = Modules.Diagnostics

local destroyed = false
local ui
local function shutdown()
    if destroyed then return end
    destroyed = true
    ESP.Destroy()
    if ui then ui.Destroy() end
end

local profile = Profile.Load()
ui = UI.CreateMain(shutdown)
Welcome.Show(profile, ui.Screen, Settings.Get("ReduceAnimations"))

ui.SetRenderer("Início", function(addText)
    addText("Olá, " .. profile.DisplayName .. ". Versão " .. Config.Version .. ".", 36)
    addText("Painel local de informações e indicadores. Dados internos não publicados aparecem como indisponíveis.", 58)
    addText("Jogadores conectados: " .. tostring(#Players:GetPlayers()), 26)
end)
ui.SetRenderer("ESP", function(addText, addButton, addToggle)
    addText("Indicadores locais de personagens presentes no Workspace.", 36)
    addToggle("ESP de jogadores", false, function(v) ESP.SetEnabled(v) end)
    addToggle("Mostrar nomes", true, function(v) ESP.SetNames(v) end)
    addToggle("Mostrar distância", true, function(v) ESP.SetDistance(v) end)
end)
ui.SetRenderer("Sobrevivente", function(addText)
    local info = PlayerInfo.ReadLocal()
    addText("Vida: " .. (info.Health and string.format("%.0f / %.0f", info.Health, info.MaxHealth) or "indisponível"), 28)
    addText("Stamina: " .. (info.Stamina and string.format("%.0f / %.0f", info.Stamina, info.StaminaMax or 0) or "indisponível"), 28)
    addText("Correndo: " .. (info.Sprinting ~= nil and (info.Sprinting and "sim" or "não") or "indisponível"), 28)
    addText("Velocidade observada: " .. (info.MoveSpeed and tostring(info.MoveSpeed) or "indisponível"), 28)
    local staminaRef = StaminaInfo.GetReference("Survivor")
    addText("Referência: máximo " .. staminaRef.Max .. ", consumo " .. staminaRef.DrainPerSecond .. "/s, recuperação " .. staminaRef.RegenPerSecond .. "/s, pausa " .. staminaRef.ExhaustDelay .. "s.", 58)
end)
ui.SetRenderer("Geradores", function(addText)
    addText(GeneratorGuide.GetSummaryText(), 42)
    addText("Dot Numberlink — " .. GeneratorGuide.Types["Dot Numberlink"].Goal, 58)
    addText("Blob Numberlink — " .. GeneratorGuide.Types["Blob Numberlink"].Goal, 58)
    addText("Gears — " .. GeneratorGuide.Types["Gears"].Goal, 66)
    addText("Locks — " .. GeneratorGuide.Types["Locks"].Goal, 66)
    addText("Alerta Noli: " .. table.concat(GeneratorGuide.FakeGenerator.Tells, " • "), 88)
    addText(Objectives.GetStatus(), 30)
    addText("Solver incluído para Numberlink, blobs e janela dos Locks; leitura automática da tela e interação não estão conectadas.", 72)
end)
ui.SetRenderer("Combate", function(addText)
    addText("Avisos de habilidades: indisponível sem dados publicados pelo jogo.", 38)
    addText("Distância de jogadores disponível na aba ESP. Sem automação de combate.", 54)
end)
ui.SetRenderer("Movimento", function(addText, addButton, addToggle, addSlider)
    addText("Configurações visuais locais.", 48)
    addSlider("FOV", 50, 100, Settings.Get("FOV"), function(v) MovementSettings.SetFOV(v) end)
    addToggle("Reduzir animações da interface", Settings.Get("ReduceAnimations"), function(v) MovementSettings.SetReduceAnimations(v) end)
end)
ui.SetRenderer("Partida", function(addText)
    local info = MatchInfo.Read()
    addText("Papel: " .. tostring(info.Role or "indisponível"), 26)
    addText("Estado: " .. tostring(info.State or "indisponível"), 26)
    addText("Cronômetro: " .. tostring(info.Time or "indisponível"), 26)
    addText("Jogadores vivos: " .. tostring(info.Alive or "indisponível"), 26)
    addText("Jogadores conectados: " .. tostring(info.PlayerCount), 26)
end)
ui.SetRenderer("Configurações", function(addText, addButton, addToggle, addSlider)
    addText("Preferências mantidas em memória nesta execução.", 30)
    addSlider("Escala da interface", 75, 125, 100, function(v) Settings.Set("UIScale", v/100) end)
    addSlider("Transparência", 0, 35, 0, function(v) Settings.Set("Transparency", v/100) end)
    addButton("Fechar hub", shutdown)
end)
ui.ShowTab("Início")
Diagnostics.Log("info", "Hub iniciado em modo single-file.")
