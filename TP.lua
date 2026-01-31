local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:WaitForChild("Debris")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")

local serverURL = "wss://m4gix-ws.onrender.com/?user=" .. HttpService:UrlEncode(Players.LocalPlayer.Name)
local server = nil
local reconnectDelay = 5

local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

--- Functions Utils ---
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

local function GetActiveOverheads()
    local allOverheads = {}
    for _, item in ipairs(Debris:GetChildren()) do
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            table.insert(allOverheads, item)
        end
    end
    return allOverheads
end

local function FindOverheadForAnimal(animalModel)
    local animalName = animalModel.Name
    local bestTemplate = nil
    local minDistance = math.huge

    for _, item in ipairs(Debris:GetChildren()) do
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            -- On plonge dans AnimalOverhead pour vérifier le texte
            local container = item:FindFirstChild("AnimalOverhead")
            local displayNameLabel = container and container:FindFirstChild("DisplayName")
            
            if displayNameLabel and displayNameLabel.Text == animalName then
                local animalPos = animalModel:GetPivot().Position
				local horizontalPos = Vector3.new(animalPos.X, item.Position.Y, animalPos.Z)
				local dist = (item.Position - horizontalPos).Magnitude            
                if dist < minDistance then
                    minDistance = dist
                    bestTemplate = item
                end
            end
        end
    end

    if bestTemplate and minDistance < 3 then
		print(string.format("🔍 [CIBLE RETENUE] à %.2f studs", minDistance))
        return bestTemplate
    end
    return nil
end

local function GetOverheadInfos(overhead)
    if not overhead then return nil end
    local container = overhead:FindFirstChild("AnimalOverhead")
    if not container then return nil end

    -- On récupère les textes sans attendre trop longtemps 
    -- pour ne pas bloquer tout le script de sauvegarde.
    local displayObj = container:FindFirstChild("DisplayName")
    if not displayObj or displayObj.Text == "" then return nil end

    local mutationObj = container:FindFirstChild("Mutation")
    local actualMutation = "Default"
    if mutationObj and mutationObj.Visible and mutationObj.Text ~= "" then
        actualMutation = mutationObj.Text
    end

    return {
        DisplayName = displayObj.Text,
        Mutation    = actualMutation,
        Generation  = container:FindFirstChild("Generation") and container.Generation.Text or "$0/s",
        Price       = container:FindFirstChild("Price") and container.Price.Text or "$0",
        Rarity      = container:FindFirstChild("Rarity") and container.Rarity.Text or "Common",
        Stolen      = container:FindFirstChild("Stolen") and container.Stolen.Visible or false
    }
end

local function GetPlot(player, timeout)
    local startTime = tick()
    local duration = timeout or 15
    local searchName = string.lower(player.DisplayName)
        
    while tick() - startTime < duration do
        for _, p in ipairs(Plots:GetChildren()) do
            local plotSign = p:FindFirstChild("PlotSign")
            local surfaceGui = plotSign and plotSign:FindFirstChild("SurfaceGui")
            local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
            local textLabel = frame and frame:FindFirstChild("TextLabel")

            if textLabel and textLabel.Text ~= "" then
                if string.find(string.lower(textLabel.Text), searchName) then
                    return p
                end
            end
        end
        task.wait(1)
    end
    
    return nil
end

local function GetBrainrots(playerInfos, completeData)
    local brainrots = {}
    
    if not playerInfos.Plot then 
        return brainrots 
    end

    local children = playerInfos.Plot:GetChildren()

    for _, child in ipairs(children) do
        local config = AnimalsData[child.Name]
        if config then
            -- print("🐾 [DEBUG] Animal détecté : " .. child.Name)
            local ov = FindOverheadForAnimal(child)
            local infos = GetOverheadInfos(ov)

            local currentMutation = child:GetAttribute("Mutation") or "Default"
            local currentTraits = {}
            local rawTraits = child:GetAttribute("Traits")

            if type(rawTraits) == "string" then
                for t in string.gmatch(rawTraits, '([^,]+)') do 
                    table.insert(currentTraits, t:match("^%s*(.-)%s*$")) 
                end
            elseif type(rawTraits) == "table" then
                currentTraits = rawTraits
            end

            local incomeGen = 0
            pcall(function()
                -- On utilise pcall au cas où CalculGeneration ferait une erreur
                incomeGen = CalculGeneration(config.Generation, currentMutation, currentTraits)
            end)

            local finalGenString = ""
            if infos and infos.Generation and infos.Generation ~= "" then
                finalGenString = infos.Generation -- On prend le texte exact : ex: "$1.5M/s"
            else
                finalGenString = (FormatMoney and FormatMoney(incomeGen)) or tostring(incomeGen)
            end

            if(completeData) then
                table.insert(brainrots, {
                    Part = child,
				    Player = playerInfos.DisplayName or playerInfos.Name,
                    playerInfos = playerInfos,
                    Name = config.DisplayName or child.Name,
                    Rarity = config.Rarity or "Common",
                    Generation = incomeGen,
                    GenString = finalGenString or tostring(incomeGen),
                    Mutation = currentMutation,
                    Traits = currentTraits,
                    Stolen = infos and infos.Stolen or false
                })
            else
                table.insert(brainrots, {
				    Player = playerInfos.DisplayName or playerInfos.Name,
                    Name = config.DisplayName or child.Name,
                    Rarity = config.Rarity or "Common",
                    Generation = incomeGen,
                    GenString = finalGenString or tostring(incomeGen),
                    Mutation = currentMutation,
                    Traits = currentTraits,
                })
            end
        end
    end
    return brainrots
end

local function GetPlayerInfos(player)
    if not player then return nil end
    
    local stats = player:WaitForChild("leaderstats", 5)
    if not stats then 
        return nil 
    end

    local plot = GetPlot(player)

    return {
        DisplayName = player.DisplayName,
        Name = player.Name,
        Cash = (stats:FindFirstChild("Cash") and stats.Cash.Value) or 0,
        Rebirths = (stats:FindFirstChild("Rebirths") and stats.Rebirths.Value) or 0,
        Steals = (stats:FindFirstChild("Steals") and stats.Steals.Value) or 0,
        Plot = plot
    }
end

local function FindBrainrotByName(name)
    local searchName = string.lower(name) -- On normalise le nom pour la recherche

    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        local infos = GetPlayerInfos(player)
        if infos then
            local brainrots = GetBrainrots(infos, true)
            for _, brainrot in ipairs(brainrots) do
                if string.lower(brainrot.Name) == searchName and not brainrot.Stolen then
                    print(string.format("✅ [TROUVÉ] %s chez %s (Non-volé)", brainrot.Name, player.Name))
                    return brainrot
                end
            end
        end
    end
    warn("❌ [FindBrainrot] Aucun '" .. name .. "' légitime (non-stolen) n'a été trouvé sur le serveur.")
    return nil
end

local function UpdateDatabase()
    for _, player in ipairs(Players:GetPlayers()) do
        local infos = GetPlayerInfos(player)
        if not infos then return end

        SendToServer("UpdateDatabase", {
            ServerId = game.JobId,
            DisplayName = infos.DisplayName,
            Name = infos.Name,
            Cash = infos.Cash,
            Rebirths = infos.Rebirths,
            Steals = infos.Steals,
            Brainrots = GetBrainrots(infos, false)
        })
    end
end

local function MoveTo(targetPos)
    local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
    local success, _ = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)
    
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for _, waypoint in ipairs(waypoints) do
            if waypoint.Action == Enum.PathWaypointAction.Jump then 
                humanoid.Jump = true 
            end
            humanoid:MoveTo(waypoint.Position)
            -- Timeout de sécurité pour éviter de rester bloqué si un obstacle surgit
            local finished = humanoid.MoveToFinished:Wait(5) 
            if not finished then break end
        end
    else
        humanoid:MoveTo(targetPos)
        humanoid.MoveToFinished:Wait()
    end
end

local function OnServerConnect()
    SendToServer("ClientInfos", { Player = Players.LocalPlayer.DisplayName, ServerId = game.JobId })
end

local function OnServerMessage(rawMsg)
	local success, data = pcall(function()
        return HttpService:JSONDecode(rawMsg)
    end)

    if not success or not data then 
        warn("⚠️ Erreur de décodage JSON :", rawMsg)
        return 
    end

    if data.Method == "UpdateDatabase" then
        task.spawn(function()
            UpdateDatabase()
        end)
    end

    if data.Method == "ExecuteRitual" then
	    if data.Param.RitualName == "La Vacca Saturno Saturnita" then
	        print("✨ Phase : " .. tostring(data.Param.ClientNumber))
	        
	        local br = FindBrainrotByName("La Vacca Saturno Saturnita")
            local character = Players.LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")

            if br and br.Part and hrp then
                local targetPos = br.Part:GetPivot().Position
                print("🚀 Déplacement vers Saturno...")
            
                -- Calcul de la position d'arrêt pour faire face à la vache
                local offset = Vector3.new(4, 0, 4) -- Ajuste selon l'angle voulu
                MoveTo(targetPos + offset) 

                -- 1. Orientation précise vers la Vache
                -- On garde le Y du joueur pour éviter qu'il ne bascule en arrière
                hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
                task.wait(1)
                print("✅ Arrivé. Passage de relais.")
            else
                warn("❌ Cible 'La Vacca Saturno Saturnita' introuvable sur ce serveur.")
            end

	        -- On calcule l'index suivant
	        local nextIndex = data.Param.ClientNumber + 1
	        local totalClients = #data.Param.Clients
	        
	        -- Si l'index suivant est toujours dans la liste (Attention: JSON index 0)
	        -- Si tu as 3 clients, les index sont 0, 1, 2. Donc nextIndex doit être < 3.
	        if nextIndex < totalClients then
	            SendToServer("ExecuteRitualNextClient", {
	                RitualName = data.Param.RitualName,
	                ClientNumber = nextIndex,
	                Clients = data.Param.Clients
	            })
	            print("📦 Relais envoyé pour le client index : " .. nextIndex)
	        else
	            print("👑 Fin du rituel, tous les participants ont terminé !")
	        end
	    end
	end
end

function connectWS()
    local success, result = pcall(function()
        return (WebSocket and WebSocket.connect) and WebSocket.connect(serverURL) or WebSocket.new(serverURL)
    end)

    if success then
        server = result
        OnServerConnect()

        local messageEvent = server.OnMessage or server.Message
        messageEvent:Connect(function(rawMsg)
            OnServerMessage(rawMsg)
        end)

        server.OnClose:Connect(function()
            task.wait(reconnectDelay)
            connectWS()
        end)
    else
        task.wait(reconnectDelay)
        connectWS()
    end
end

connectWS()
