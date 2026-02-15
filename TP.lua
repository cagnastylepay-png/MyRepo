local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:WaitForChild("Debris")
local TeleportService = game:GetService("TeleportService")

-- Chargement des modules de données
local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

local server = nil
local reconnectDelay = 5

-- [SYSTÈME DE COMMUNICATION]
local function SendToServer(method, data)
    if server then
        local success, payload = pcall(function() return HttpService:JSONEncode({Method = method, Data = data}) end)
        if success then server:Send(payload) end
    end
end

-- [FONCTIONS DE CALCUL ET FORMATAGE]
local function CalculGeneration(baseIncome, mutationName, traitsTable)
    local totalMultiplier = 1
    local mutConfig = MutationsData[mutationName]
    if mutConfig and mutConfig.Modifier then totalMultiplier = totalMultiplier + mutConfig.Modifier end
    for _, traitName in ipairs(traitsTable) do
        local traitConfig = TraitsData[traitName]
        if traitConfig and traitConfig.MultiplierModifier then
            totalMultiplier = totalMultiplier + traitConfig.MultiplierModifier
        end
    end
    return (baseIncome or 0) * totalMultiplier
end

local function FormatMoney(value)
    if value >= 1e12 then return string.format("$%.1fT/s", value / 1e12)
    elseif value >= 1e9 then return string.format("$%.1fB/s", value / 1e9)
    elseif value >= 1e6 then return string.format("$%.1fM/s", value / 1e6)
    elseif value >= 1e3 then return string.format("$%.1fK/s", value / 1e3)
    else return string.format("$%.1f/s", value) end
end

local function ParseGeneration(str)
    local clean = str:gsub("[%$%s/s]", ""):upper()
    local multiplier = 1
    local numStr = clean
    if clean:find("K") then multiplier = 10^3 numStr = clean:gsub("K", "")
    elseif clean:find("M") then multiplier = 10^6 numStr = clean:gsub("M", "")
    elseif clean:find("B") then multiplier = 10^9 numStr = clean:gsub("B", "")
    elseif clean:find("T") then multiplier = 10^12 numStr = clean:gsub("T", "") end
    local val = tonumber(numStr)
    return val and (val * multiplier) or 0
end

-- [LOGIQUE OVERHEAD ET PLOT]
local function FindOverhead(animalModel)
    local animalName = animalModel.Name
    local bestTemplate = nil
    local minDistance = math.huge
    for _, item in ipairs(Debris:GetChildren()) do
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            local container = item:FindFirstChild("AnimalOverhead")
            local displayNameLabel = container and container:FindFirstChild("DisplayName")
            if displayNameLabel and displayNameLabel.Text == animalName then
                local animalPos = animalModel:GetPivot().Position
                local horizontalPos = Vector3.new(animalPos.X, item.Position.Y, animalPos.Z)
                local dist = (item.Position - horizontalPos).Magnitude                
                if dist < minDistance then
                    minDistance = dist
                    bestTemplate = container
                end
            end
        end
    end
    return (bestTemplate and minDistance < 3) and bestTemplate or nil
end

local function ParseOverhead(overhead)
    if not overhead then return nil end
    local displayObj = overhead:FindFirstChild("DisplayName")
    if not displayObj or displayObj.Text == "" then return nil end
    local mutationObj = overhead:FindFirstChild("Mutation")
    local actualMutation = (mutationObj and mutationObj.Visible and mutationObj.Text ~= "") and mutationObj.Text or "Default"
    return {
        DisplayName = displayObj.Text,
        Mutation    = actualMutation,
        Generation  = overhead:FindFirstChild("Generation") and overhead.Generation.Text or "$0/s",
        Price       = overhead:FindFirstChild("Price") and overhead.Price.Text or "$0",
        Rarity      = overhead:FindFirstChild("Rarity") and overhead.Rarity.Text or "Common",
        Stolen      = overhead:FindFirstChild("Stolen") and overhead.Stolen.Visible or false
    }
end

local function FindPlot(player)
    for _, plot in ipairs(Plots:GetChildren()) do
        local label = plot:FindFirstChild("PlotSign") 
            and plot.PlotSign:FindFirstChild("SurfaceGui")
            and plot.PlotSign.SurfaceGui:FindFirstChild("Frame") 
            and plot.PlotSign.SurfaceGui.Frame:FindFirstChild("TextLabel")
        if label then
            local t = (label.ContentText or label.Text or "")
            if t:find(player.DisplayName) and t:find("Base") then
                return plot
            end
        end
    end
    return nil
end

-- [LOGIQUE DE SCAN DES ANIMAUX]
local function ParseTraits(child)
    local currentTraits = {}
    local rawTraits = child:GetAttribute("Traits")
    if type(rawTraits) == "string" then
        for t in string.gmatch(rawTraits, '([^,]+)') do 
            table.insert(currentTraits, t:match("^%s*(.-)%s*$")) 
        end
    elseif type(rawTraits) == "table" then
        currentTraits = rawTraits
    end
    return currentTraits
end

local function ParseIncome(infos, config, mutation, traits)
    local income = 0
    local incomeString = ""
    if infos and infos.Generation and infos.Generation ~= "" then
        incomeString = infos.Generation
        income = ParseGeneration(incomeString) 
    else
        pcall(function() income = CalculGeneration(config.Generation, mutation, traits) end)
        incomeString = FormatMoney(income)
    end
    return income, incomeString
end

local function ParseBrainrot(child, config)
    local overhead = FindOverhead(child)
    local infos = ParseOverhead(overhead)
    local mutation = child:GetAttribute("Mutation") or "Default"
    local traits = ParseTraits(child)
    local income, incomeString = ParseIncome(infos, config, mutation, traits)
    return {
        Overhead = overhead,
        Model = child,
        Name = child.Name,
        IncomeStr = incomeString,
        Income = income,
        Rarity = config.Rarity or "Common",
        Mutation = mutation,
        Traits = traits
    }
end

local function GetBrainrots(plot)
    local brainrots = {}
    if plot then
        for _, child in ipairs(plot:GetChildren()) do
            local config = AnimalsData[child.Name]
            if config then
                local brainrot = ParseBrainrot(child, config)
                table.insert(brainrots, brainrot)
            end
        end
    end
    return brainrots
end

-- [COMMANDES DISTANTES]
local function OnServerMessage(rawMsg)
    local success, data = pcall(function() return HttpService:JSONDecode(rawMsg) end)
end

local function SendPlayerInfos(player)
    local plot = nil
    repeat plot = FindPlot(player) task.wait(1) until plot
    local playerAnimals = GetBrainrots(plot)
    local PlayerInfos = {
        DisplayName = player.DisplayName,
        Name = player.Name,
        UserId = player.UserId,
        AccountAge = player.AccountAge,
        Brainrots = {}
    }
    for _, animal in ipairs(playerAnimals) do
        table.insert(PlayerInfos.Brainrots, {
            Name = animal.Name,
            IncomeStr = animal.IncomeStr,
            Income = animal.Income,
            Rarity = animal.Rarity,
            Mutation = animal.Mutation,
            Traits = animal.Traits
        })
    end
    SendToServer("PlayerInfos", PlayerInfos)
end

local function SendAllInfos()
    for _, player in ipairs(Players:GetPlayers()) do
        SendPlayerInfos(player)
    end
end

-- [INITIALISATION]
local function OnServerConnect()
    SendAllInfos()

    Players.PlayerAdded:Connect(function(player)
        task.wait(1)
        SendPlayerInfos(player)
    end)
end

function connectWS(url)
    local success, result = pcall(function()
        return (WebSocket and WebSocket.connect) and WebSocket.connect(url) or WebSocket.new(url)
    end)
    if success then
        server = result
        OnServerConnect()
        local messageEvent = server.OnMessage or server.Message
        messageEvent:Connect(OnServerMessage)
        server.OnClose:Connect(function()
            task.wait(reconnectDelay)
            connectWS(url)
        end)
    else
        task.wait(reconnectDelay)
        connectWS(url)
    end
end

-- [LANCEUR]
local serverURL = "wss://m4gix-ws.onrender.com/?role=Admin&user=" .. HttpService:UrlEncode(Players.LocalPlayer.Name)
task.spawn(function() connectWS(serverURL) end)

-- [INTERFACE GUI]
local function CreateGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "M4GIX_Control"
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 180, 0, 80)
    frame.Position = UDim2.new(0, 20, 0.5, -40)
    frame.BackgroundColor3 = Color3.fromRGB(22, 30, 45)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(59, 130, 246)
    stroke.Thickness = 1.5
    stroke.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Text = "M4GIX CONTROL"
    title.TextColor3 = Color3.fromRGB(59, 130, 246)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.BackgroundTransparency = 1
    title.Parent = frame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0, 25)
    statusLabel.Text = "STBY"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    statusLabel.Font = Enum.Font.SourceSansItalic
    statusLabel.TextSize = 12
    statusLabel.BackgroundTransparency = 1
    statusLabel.Parent = frame

    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0.8, 0, 0, 25)
    scanBtn.Position = UDim2.new(0.1, 0, 1, -30)
    scanBtn.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
    scanBtn.Text = "FORCE GLOBAL SCAN"
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.Font = Enum.Font.SourceSansBold
    scanBtn.TextSize = 12
    scanBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = scanBtn

    -- Logique du bouton
    scanBtn.MouseButton1Click:Connect(function()
        statusLabel.Text = "SCANNING..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        SendAllInfos()
        task.wait(1)
        statusLabel.Text = "DATA SENT"
        statusLabel.TextColor3 = Color3.fromRGB(34, 197, 94)
        task.wait(2)
        statusLabel.Text = server and "CONNECTED" or "DISCONNECTED"
        statusLabel.TextColor3 = server and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68)
    end)

    return statusLabel
end

local guiStatus = CreateGUI()

-- Mise à jour du statut dans la boucle connectWS
local originalOnConnect = OnServerConnect
OnServerConnect = function()
    guiStatus.Text = "CONNECTED"
    guiStatus.TextColor3 = Color3.fromRGB(34, 197, 94)
    originalOnConnect()
end
