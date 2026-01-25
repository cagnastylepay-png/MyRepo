local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

local socketURL = "wss://m4gix-ws.onrender.com/?token=M4GIX_SECURE_2026"
local myName = Players.LocalPlayer.Name
local reconnectDelay = 5
local ws = nil
local brainrotsDict = {}
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")


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

local function formatMoney(value)
    if value >= 1e12 then return string.format("$%.1fT/s", value / 1e12)
    elseif value >= 1e9 then return string.format("$%.1fB/s", value / 1e9)
    elseif value >= 1e6 then return string.format("$%.1fM/s", value / 1e6)
    elseif value >= 1e3 then return string.format("$%.1fK/s", value / 1e3)
    else return string.format("$%.1f/s", value) end
end

local function generateSmallID()
    -- On génère un nombre entre 0 et 0xFFFFFFFF (le max pour 8 caractères hex)
    return string.format("%08x", math.random(0, 0xFFFFFFFF))
end

-- Récupère la liste des noms des joueurs sur le serveur
local function GetPlayers()
    local displayNames = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(displayNames, player.DisplayName)
    end
    return displayNames
end

-- Trouve le terrain appartenant à un joueur
local function FindPlot(playerName)
    for _, plot in ipairs(Plots:GetChildren()) do
        local plotSign = plot:FindFirstChild("PlotSign")
        local surfaceGui = plotSign and plotSign:FindFirstChild("SurfaceGui")
        local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
        local textLabel = frame and frame:FindFirstChild("TextLabel")

        if textLabel then
            if string.find(string.lower(textLabel.Text), string.lower(playerName)) then
                return plot
            end
        end
    end
    return nil
end

local function GetPlayerPos(playerName)
    -- On cherche le joueur
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName == playerName or p.Name == playerName then
            local char = p.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
        
            if root then
                local pos = root.Position
                local look = root.CFrame.LookVector
                
                return { 
                    X = pos.X, Y = pos.Y, Z = pos.Z, 
                    LookX = look.X, LookY = look.Y, LookZ = look.Z 
                }
            end
        end
    end
    -- Retourne des zéros si le joueur n'est pas trouvé ou n'a pas de corps
    return { X = 0, Y = 0, Z = 0, LookX = 0, LookY = 0, LookZ = 0 }
end

-- Liste les entités sur le plot d'un joueur précis
local function GetBase(playerName)
    local plot = FindPlot(playerName)
    if not plot then return { Error = "Plot non trouvé" } end

    local plotData = { Player = playerName, Brainrots = {} }
    
    for _, child in ipairs(plot:GetChildren()) do
        -- On identifie un Brainrot par la présence d'un Controller d'animation
        local config = AnimalsData[child.Name]
        
        if config then
            -- On récupère les attributs du modèle
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
            local uniqueId = generateSmallID()
            brainrotsDict[uniqueId] = {
                Id = uniqueId,
                Name = config.DisplayName or child.Name,
                Rarity = config.Rarity or "Common",
                Generation = incomeGen,
                GenString = formatMoney(incomeGen),
                Mutation = currentMutation,
                Traits = currentTraits
            }

            table.insert(plotData.Brainrots, brainrotsDict[uniqueId])
        end
    end
    return plotData
end

local function MoveTo(targetPos)
    local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
    local success, _ = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)
    if success and path.Status == Enum.PathStatus.Success then
        for _, waypoint in ipairs(path:GetWaypoints()) do
            if not isRunning or BuyCount >= MaxBuyCount then break end
            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
            humanoid:MoveTo(waypoint.Position)
            humanoid.MoveToFinished:Wait() 
        end
    else
        humanoid:MoveTo(targetPos)
    end
end

function Identify()
    if ws then
        ws:Send(HttpService:JSONEncode({
            Method = "Identify",
            From = myName,
            To = "Server",
            Data = ""
        }))
    end
end

function connectWS()
    local success, result = pcall(function()
        return (WebSocket and WebSocket.connect) and WebSocket.connect(socketURL) or WebSocket.new(socketURL)
    end)

    if success then
        ws = result
        Identify()

        local messageEvent = ws.OnMessage or ws.Message
        messageEvent:Connect(function(rawMsg)
            local ok, msg = pcall(function() return HttpService:JSONDecode(rawMsg) end)
            if not ok then return end

            -- COMMANDE : Liste des joueurs
            if msg.Method == "GetPlayers" then
                ws:Send(HttpService:JSONEncode({
                    Method = "Result",
                    From = myName,
                    To = msg.From,
                    RequestId = msg.RequestId,
                    Data = GetPlayers()
                }))
            -- COMMANDE : Scan d'un Plot (Data doit contenir le nom du joueur)
            elseif msg.Method == "GetBase" then
                local target = msg.Data or myName
                ws:Send(HttpService:JSONEncode({
                    Method = "Result",
                    From = myName,
                    To = msg.From,
                    RequestId = msg.RequestId,
                    Data = GetBase(target)
                }))
            -- COMMANDE : Scan d'un Plot (Data doit contenir le nom du joueur)
            elseif msg.Method == "MoveTo" then
                -- On utilise task.spawn pour ne pas bloquer le WebSocket pendant le trajet
                task.spawn(function()                  
                    MoveTo(Vector3.new(msg.Data.X, msg.Data.Y, msg.Data.Z))
                    ws:Send(HttpService:JSONEncode({
                        Method = "Result",
                        From = myName,
                        To = msg.From,
                        RequestId = msg.RequestId,
                        Data = "Arrived at destination"
                    }))
                end)
            elseif msg.Method == "GetPlayerPos" then
                local target = msg.Data or myName
                ws:Send(HttpService:JSONEncode({
                    Method = "Result",
                    From = myName,
                    To = msg.From,
                    RequestId = msg.RequestId,
                    Data = GetPlayerPos(target)
                }))
            end
        end)

        ws.OnClose:Connect(function()
            task.wait(reconnectDelay)
            connectWS()
        end)
    else
        task.wait(reconnectDelay)
        connectWS()
    end
end

task.spawn(connectWS)
