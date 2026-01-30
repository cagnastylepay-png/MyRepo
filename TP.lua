local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverURL = "wss://m4gix-ws.onrender.com/?user=" .. HttpService:UrlEncode(Players.LocalPlayer.Name)
local server = nil
local reconnectDelay = 5

local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

--- Functions Utils ---
-----------------------
local function SendToServer(method, data)
    if server then
        server:Send(HttpService:JSONEncode({Method = method, Data = data}))
    end
end

local function CalculGeneration(generation, mutationName, traitsTable)
    local baseIncome = generation or 0
    local totalMultiplier = 1 -- Multiplicateur de base (100%)

    -- 1. Bonus de Mutation (Ex: Gold = +0.25)
    local mutConfig = MutationsData[mutationName]
    if mutConfig and mutConfig.Modifier then
        totalMultiplier = totalMultiplier + mutConfig.Modifier
    end

    -- 2. Bonus de Traits (Ex: Nyan = +5)
    for _, traitName in ipairs(traitsTable) do
        local traitConfig = TraitsData[traitName]
        if traitConfig and traitConfig.MultiplierModifier then
            totalMultiplier = totalMultiplier + traitConfig.MultiplierModifier
        end
    end

    return baseIncome * totalMultiplier
end

local function FormatMoney(value)
    if value >= 1e12 then return string.format("$%.1fT/s", value / 1e12)
    elseif value >= 1e9 then return string.format("$%.1fB/s", value / 1e9)
    elseif value >= 1e6 then return string.format("$%.1fM/s", value / 1e6)
    elseif value >= 1e3 then return string.format("$%.1fK/s", value / 1e3)
    else return string.format("$%.1f/s", value) end
end

--- Functions Player Infos ---
------------------------------

local function GetPlayersName()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(names, player.Name) -- Correction ici: names au lieu de displayNames
    end
    return names
end

local function GetPlayerByName(playerName)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName == playerName or p.Name == playerName then
            return p
        end
    end
    return nil
end

local function GetPlayerPosition(player)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
        
    if root then return root.Position end
    return nil
end

local function GetPlayerBase(player, timeout)
    local startTime = tick()
    local duration = timeout or 15 -- On attend max 15 secondes
    
    while tick() - startTime < duration do
        local plot = nil
            for _, p in ipairs(Plots:GetChildren()) do
                local plotSign = p:FindFirstChild("PlotSign")
                local surfaceGui = plotSign and plotSign:FindFirstChild("SurfaceGui")
                local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
                local textLabel = frame and frame:FindFirstChild("TextLabel")

                if textLabel and string.find(string.lower(textLabel.Text), string.lower(player.DisplayName)) then
                    return p
                end
            end
        task.wait(0.5) -- On vérifie toutes les demi-secondes
    end
    return nil
end

local function GetPlayerBrainrots(player)
    local brainrots = { }

    local plot = GetPlayerBase(player)
    if not plot then return brainrots end

    
    for _, child in ipairs(plot:GetChildren()) do
        local config = AnimalsData[child.Name]
        
        if config then
            local currentMutation = child:GetAttribute("Mutation") or "Default"
            local currentTraits = {}
            
            -- Extraction des traits
            local rawTraits = child:GetAttribute("Traits")
            if type(rawTraits) == "string" then
                for t in string.gmatch(rawTraits, '([^,]+)') do 
                    table.insert(currentTraits, t:match("^%s*(.-)%s*$")) 
                end
            elseif type(rawTraits) == "table" then
                currentTraits = rawTraits
            end

            -- CALCUL VIA LA MÉTHODE
            local incomeGen = CalculGeneration(config.Generation, currentMutation, currentTraits)
            local br = {
                Name = config.DisplayName or child.Name,
                Rarity = config.Rarity or "Common",
                Generation = incomeGen,
                GenString = FormatMoney(incomeGen),
                Mutation = currentMutation,
                Traits = currentTraits
            }
            table.insert(brainrots, br)
        end
    end
    return brainrots
end

local function GetPlayerInfos(player)
    local p = player or Players.LocalPlayer
    
    local stats = p:FindFirstChild("leaderstats")
    if not stats then return nil end

    return {
        DisplayName = p.DisplayName,
        Name = p.Name,
        Cash = stats.Cash.Value or 0,
        Rebirths = stats.Rebirths.Value or 0,
        Steals = stats.Steals.Value or 0,
        Brainrots = GetPlayerBrainrots(p)
    }
end


local function OnServerConnect()
	print("Connecté au serveur WebSocket à l'URL : " .. socketURL)
    SendToServer("PlayerInfos", GetPlayerInfos())
end

local function OnServerMessage(msg)
	print("Message du serveur : " .. tostring(msg))
end

function connectWS()
    local success, result = pcall(function()
        return WebSocket.connect(socketURL)
    end)

    if success then
        server = result
        OnServerConnect()
        server.OnMessage:Connect(function(rawMsg)
            OnServerMessage(rawMsg)
        end)

        server.OnClose:Connect(function()
            print("Connexion fermée. Tentative de reconnexion dans " .. reconnectDelay .. " secondes...")
            task.wait(reconnectDelay)
            connectWS()
        end)
    else
        print("Échec de la connexion au serveur WebSocket. Nouvelle tentative dans " .. reconnectDelay .. " secondes...")
        server.wait(reconnectDelay)
        connectWS()
    end
end
