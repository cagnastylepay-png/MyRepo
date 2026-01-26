local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RenderedAnimals = workspace:WaitForChild("RenderedMovingAnimals")
local Debris = workspace:WaitForChild("Debris")

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

local function WaitPlot(playerName, timeout)
    local startTime = tick()
    local duration = timeout or 15 -- On attend max 15 secondes
    
    while tick() - startTime < duration do
        local plot = FindPlot(playerName) -- Ta fonction existante qui cherche le texte sur le panneau
        if plot then
            return plot
        end
        task.wait(0.5) -- On vérifie toutes les demi-secondes
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
    local plot = WaitPlot(playerName)
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
            local br = {
                Id = uniqueId,
                Name = config.DisplayName or child.Name,
                Rarity = config.Rarity or "Common",
                Generation = incomeGen,
                GenString = formatMoney(incomeGen),
                Mutation = currentMutation,
                Traits = currentTraits
            }
            brainrotsDict[uniqueId] = child
            table.insert(plotData.Brainrots, br)
        end
    end
    return plotData
end

local function MoveTo(targetPos)
    local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
    local success, _ = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)
    if success and path.Status == Enum.PathStatus.Success then
        for _, waypoint in ipairs(path:GetWaypoints()) do
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

local function FindOverheadForAnimal(animalModel)
    local animalName = animalModel.Name
    local bestItem = nil
    local minDistance = math.huge

    for _, item in ipairs(Debris:GetChildren()) do
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            local overheadGui = item:FindFirstChild("AnimalOverhead")
            local displayNameLabel = overheadGui and overheadGui:FindFirstChild("DisplayName")
            
            if displayNameLabel and displayNameLabel.Text == animalName then
                local animalPos = animalModel:GetPivot().Position 
                local overheadPos = item.Position
                local dist = (Vector2.new(overheadPos.X, overheadPos.Z) - Vector2.new(animalPos.X, animalPos.Z)).Magnitude
                
                -- On cherche celui qui est vraiment sur l'animal (le plus proche)
                if dist < minDistance then
                    minDistance = dist
                    bestItem = item
                end
            end
        end
    end
    
    if bestItem and minDistance < 10 then -- Tolérance augmentée à 10 pour plus de souplesse
        print(string.format("✅ [Overhead] Match trouvé pour %s (Dist: %.2f)", animalName, minDistance))
        return bestItem
    else
        print(string.format("❌ [Overhead] Aucun match proche pour %s (Plus proche: %.2f)", animalName, minDistance))
        return nil
    end
end

local function FindPromptForAnimal(animalModel)
    local animalName = animalModel.Name
    local bestPrompt = nil
    local minDistance = math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.ActionText == "Purchase" then
            if string.find(obj.ObjectText, animalName) then
                local attachment = obj.Parent
                if attachment:IsA("Attachment") and attachment.Name == "PromptAttachment" then
                    local promptPos = attachment.WorldCFrame.Position
                    local animalPos = animalModel:GetPivot().Position
                    local dist = (Vector2.new(promptPos.X, promptPos.Z) - Vector2.new(animalPos.X, animalPos.Z)).Magnitude
                    
                    if dist < minDistance then
                        minDistance = dist
                        bestPrompt = obj
                    end
                end
            end
        end
    end

    if bestPrompt and minDistance < 15 then
        print(string.format("✅ [Prompt] %s trouvé ! (Dist: %.2f)", animalName, minDistance))
        return bestPrompt
    else
        print(string.format("❌ [Prompt] Aucun prompt à portée pour %s", animalName))
        return nil
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
                    local targetPos = Vector3.new(msg.Data.X, msg.Data.Y, msg.Data.Z)
                    MoveTo(targetPos)
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

local function OnBrainrotSpawn(animal)
    print(string.format("🐾 [DEBUG] %s | Mut: %s | Gen: %s", animal.DisplayName, animal.Mutation, animal.Generation))
    
    -- Condition de sniping
    if animal.Mutation == "Gold" then
        print("🌟 CIBLE VERROUILLÉE : " .. animal.DisplayName)
        if animal.Prompt then
            local connection
            connection = animal.Prompt.PromptShown:Connect(function()
                fireproximityprompt(animal.Prompt)
                print("✅ Prompt affiché et activé pour " .. animal.DisplayName)
                connection:Disconnect()
            end)
        end
    end
end

game.Players.PlayerAdded:Connect(function(player)
    -- On utilise spawn pour que l'attente du plot ne bloque pas le reste du script
    task.spawn(function()
        local baseData = GetBase(player.DisplayName)
        if ws and baseData then
            ws:Send(HttpService:JSONEncode({
                Method = "OnPlayerJoined",
                From = myName,
                To = "System",
                Data = baseData
            }))
        end
    end)
end)
-- Détection des sorties
game.Players.PlayerRemoving:Connect(function(player)
    if ws then
        ws:Send(HttpService:JSONEncode({
            Method = "OnPlayerLeft",
            From = myName,
            To = "System",
            Data = { Name = player.DisplayName}
        }))
    end
end)

RenderedAnimals.ChildAdded:Connect(function(animal)
    print("🔍 [DEBUG] Nouvel animal détecté dans le dossier : " .. animal.Name)
    task.wait(1.5) -- On augmente un peu le temps pour être sûr que l'UI est là
    
    local overhead = FindOverheadForAnimal(animal)
    local prompt = FindPromptForAnimal(animal)

    if not overhead then 
        print("🛑 [ERREUR] Abandon : Pas d'overhead trouvé pour " .. animal.Name)
        return 
    end
    
    -- On vérifie que DisplayName existe bien avant de boucler
    local displayObj = overhead:FindFirstChild("DisplayName", true) -- Le 'true' cherche en profondeur
    if not displayObj then
        print("🛑 [ERREUR] Abandon : 'DisplayName' introuvable dans l'overhead de " .. animal.Name)
        return
    end

    local timeout = 0
    while displayObj.Text == "" and timeout < 20 do
        task.wait(0.1) 
        timeout = timeout + 1
    end

    if displayObj.Text == "" then
        print("🛑 [ERREUR] Abandon : Texte de l'overhead resté vide pour " .. animal.Name)
        return
    end

    print("✅ [OK] Infos chargées pour " .. displayObj.Text .. ", appel de OnBrainrotSpawn...")

    local animalData = {
        Instance = animal,
        DisplayName = displayObj.Text,
        Mutation = (overhead:FindFirstChild("Mutation") and overhead.Mutation.Visible) and overhead.Mutation.Text or "Default",
        Generation = overhead:FindFirstChild("Generation") and overhead.Generation.Text or "1",
        Price = overhead:FindFirstChild("Price") and overhead.Price.Text or "0",
        Rarity = overhead:FindFirstChild("Rarity") and overhead.Rarity.Text or "Common",
        Prompt = prompt
    }
    
    OnBrainrotSpawn(animalData)
end)

task.spawn(connectWS)
