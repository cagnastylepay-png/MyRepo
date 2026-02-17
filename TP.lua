local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:WaitForChild("Debris")
local RenderedAnimals = workspace:WaitForChild("RenderedMovingAnimals")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")

local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local RebirthData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Rebirth"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local leaderstats = localPlayer:WaitForChild("leaderstats")
local playerCash = leaderstats:WaitForChild("Cash")
local playerRebirths = leaderstats:WaitForChild("Rebirths")

local collectionMatrix = {}
local myplot = nil
local lastCollectTick = tick()
local fileName = localPlayer.Name .. "_Index.json"
local isStarted = false
local mode = "IndexAndRebirth" -- Modes: "IndexAndRebirth" or "PingPong"
local purchasePosition = Vector3.new(-413, -7, 208)

local server = nil
local reconnectDelay = 5
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local IndexBtn = Instance.new("TextButton")
local PingPongBtn = Instance.new("TextButton")
local SendInfoBtn = Instance.new("TextButton")
local StopBtn = Instance.new("TextButton")
local MinimizeBtn = Instance.new("TextButton")
local StatusLabel = Instance.new("TextLabel")
local UIListLayout = Instance.new("UIListLayout")
local UICorner = Instance.new("UICorner")
local UserInputService = game:GetService("UserInputService")

-- Configuration du ScreenGui
ScreenGui.Name = "GeminiManager"
ScreenGui.Parent = localPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Cadre Principal
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.Size = UDim2.new(0, 200, 0, 300) -- Taille augmentée pour le bouton Stop
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true -- Utile pour la réduction

UICorner.Parent = MainFrame

-- Titre
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(0.8, 0, 0, 40)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "BRAINROT BOSS"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Bouton Réduire (Trait)
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Parent = MainFrame
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.Position = UDim2.new(0.8, 0, 0, 0)
MinimizeBtn.Size = UDim2.new(0, 40, 0, 40)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.TextSize = 20

-- Container pour les boutons (pour la réduction)
local BtnContainer = Instance.new("Frame")
BtnContainer.Name = "BtnContainer"
BtnContainer.Parent = MainFrame
BtnContainer.BackgroundTransparency = 1
BtnContainer.Position = UDim2.new(0, 0, 0, 45)
BtnContainer.Size = UDim2.new(1, 0, 1, -45)

UIListLayout.Parent = BtnContainer
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.Padding = UDim.new(0, 8)

local function StyleButton(btn, color)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.BackgroundColor3 = color
    btn.Font = Enum.Font.GothamSemibold
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
end

-- Création des Boutons
IndexBtn.Parent = BtnContainer
IndexBtn.Text = "START INDEX / REBIRTH"
StyleButton(IndexBtn, Color3.fromRGB(46, 125, 50))

PingPongBtn.Parent = BtnContainer
PingPongBtn.Text = "START PING PONG"
StyleButton(PingPongBtn, Color3.fromRGB(21, 101, 192))

SendInfoBtn.Parent = BtnContainer
SendInfoBtn.Text = "SEND PLAYER INFOS"
StyleButton(SendInfoBtn, Color3.fromRGB(158, 105, 0))

StopBtn.Parent = BtnContainer
StopBtn.Text = "STOP BOT"
StyleButton(StopBtn, Color3.fromRGB(183, 28, 28))

StatusLabel.Parent = BtnContainer
StatusLabel.BackgroundTransparency = 1
StatusLabel.Size = UDim2.new(1, 0, 0, 25)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusLabel.TextSize = 12

local WSStatus = Instance.new("Frame")
local WSCorner = Instance.new("UICorner")

WSStatus.Name = "WSStatus"
WSStatus.Parent = MainFrame
WSStatus.Position = UDim2.new(1, -25, 0, 12) -- En haut à droite à côté du titre
WSStatus.Size = UDim2.new(0, 10, 0, 10)
WSStatus.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- Rouge par défaut

WSCorner.CornerRadius = UDim.new(1, 0)
WSCorner.Parent = WSStatus
-- [LOGIQUE]

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    if not isMinimized then
        MainFrame:TweenSize(UDim2.new(0, 200, 0, 40), "Out", "Quart", 0.3, true)
        BtnContainer.Visible = false
        MinimizeBtn.Text = "+"
    else
        MainFrame:TweenSize(UDim2.new(0, 200, 0, 300), "Out", "Quart", 0.3, true)
        BtnContainer.Visible = true
        MinimizeBtn.Text = "—"
    end
    isMinimized = not isMinimized
end)

local function Debug(msg)
    print(msg)
end

local function SetWSState(state)
    if state == "Connected" then
        WSStatus.BackgroundColor3 = Color3.fromRGB(50, 255, 50) -- Vert
    elseif state == "Sending" then
        WSStatus.BackgroundColor3 = Color3.fromRGB(50, 150, 255) -- Bleu
        task.delay(0.5, function() SetWSState("Connected") end)
    else
        WSStatus.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- Rouge
    end
end
-- [SYSTÈME DE COMMUNICATION]
local function SendToServer(method, data)
    if server then
        local success, payload = pcall(function() return HttpService:JSONEncode({Method = method, Data = data}) end)
        if success then 
            SetWSState("Sending") -- Allume en Bleu pendant l'envoi
            server:Send(payload) 
        end
    end
end
-- [Gestion de la Persistance JSON]

local function saveMatrix()
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(collectionMatrix)
    end)
    if success then
        writefile(fileName, encoded)
    end
end

local function loadMatrix()
    if isfile(fileName) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(fileName))
        end)
        if success then
            collectionMatrix = decoded
            print("Matrix chargée depuis le fichier JSON.")
            return
        end
    end
    collectionMatrix = {}
    print("Nouvelle Matrix initialisée.")
end

-- [Fonctions utilitaires]

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

local function FindOverhead(animalModel)
    local animalName = animalModel.Name
    local bestOverhead = nil
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
                    bestOverhead = container
                end
            end
        end
    end
    return (bestOverhead and minDistance < 3) and bestOverhead or nil
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

local function FindPrompt(animalModel)
    local animalName = animalModel.Name
    local bestPrompt = nil
    local minDistance = math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.ActionText == "Purchase" then
            if string.find(obj.ObjectText, animalName) then
                local attachment = obj.Parent
                if attachment:IsA("Attachment") and attachment.Name == "PromptAttachment" then
                    local dist = (attachment.WorldCFrame.Position - animalModel:GetPivot().Position).Magnitude
                    if dist < minDistance then
                        minDistance = dist
                        bestPrompt = obj
                    end
                end
            end
        end
    end
    return (bestPrompt and minDistance < 15) and bestPrompt or nil
end

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
    if myplot then
        for _, child in ipairs(myplot:GetChildren()) do
            local config = AnimalsData[child.Name]
            if config then
                local brainrot = ParseBrainrot(child, config)
                table.insert(brainrots, brainrot)
            end
        end
    end
    return brainrots
end

local function getNextRebirthRequirements()
    local targetLevel = playerRebirths.Value + 1
    for _, data in ipairs(RebirthData) do
        if data.RebirthNumber == targetLevel then
            return data.Requirements
        end
    end
    return nil
end

local function getMissingCharacters()
    local reqs = getNextRebirthRequirements()
    if not reqs or not reqs.RequiredCharacters then return {} end
    local missing = {}
    local ownedNames = {}
    if myplot then
        for _, child in ipairs(myplot:GetChildren()) do
            ownedNames[child.Name] = true
        end
    end
    for _, reqChar in ipairs(reqs.RequiredCharacters) do
        if not ownedNames[reqChar] then table.insert(missing, reqChar) end
    end
    return missing
end

local function getPlotSpaceInfo()
    if not myplot then return 0, 8, 10 end
    local animalCount = 0
    for _, child in ipairs(myplot:GetChildren()) do
        if AnimalsData[child.Name] then animalCount = animalCount + 1 end
    end
    local podiumsFolder = myplot:FindFirstChild("AnimalPodiums")
    local totalSlots = podiumsFolder and #podiumsFolder:GetChildren() or 10
    local maxInvestSlots = math.max(0, totalSlots - 2) 
    return animalCount, maxInvestSlots, totalSlots
end

local function MoveTo(targetPos)
    local path = PathfindingService:CreatePath({AgentRadius = 3, AgentHeight = 6, AgentCanJump = true})
    local success, _ = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)
    if success and path.Status == Enum.PathStatus.Success then
        for _, waypoint in ipairs(path:GetWaypoints()) do
            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
            humanoid:MoveTo(waypoint.Position)
            humanoid.MoveToFinished:Wait() 
        end
    else
        humanoid:MoveTo(targetPos)
        humanoid.MoveToFinished:Wait()
    end
end

-- [Logique de Récolte]

local function CollectCash()
    if not myplot then 
        Debug("❌ Erreur: myplot est nil") 
        return 
    end
    
    local podiums = myplot:FindFirstChild("AnimalPodiums")
    if not podiums then 
        Debug("❌ Erreur: AnimalPodiums introuvable dans le plot") 
        return 
    end

    local targets = {"1", "5", "10", "6"}
    Debug("🚀 Début du cycle de récolte...")

    for _, id in ipairs(targets) do
        local p = podiums:FindFirstChild(id)
        if p then
            -- Recherche récursive ou chemin précis selon ton explorer :
            -- Podium -> Base -> Claim -> Hitbox
            local hitbox = p:FindFirstChild("Hitbox", true) 

            if hitbox and hitbox:IsA("BasePart") then
                Debug("🏃 Déplacement vers le podium " .. id .. " à la position : " .. tostring(hitbox.Position))
                
                -- On utilise le CFrame ou la Position
                MoveTo(hitbox.Position) 
                
                -- Petite attente pour être sûr que le serveur valide la récolte
                task.wait(0.7) 
            else
                Debug("⚠️ Hitbox introuvable pour le podium " .. id)
            end
        else
            Debug("⚠️ Podium " .. id .. " introuvable")
        end
    end
    
    Debug("✅ Récolte terminée, retour à la zone d'achat.")
    MoveTo(purchasePosition)
end
-- [Logique d'Achat]

local function buyConditionValidation(name, income, rarity, mutation)
    local missingForRebirth = getMissingCharacters()
    local isRequiredForRebirth = table.find(missingForRebirth, name)
    local isNewForCollection = not (collectionMatrix[mutation] and collectionMatrix[mutation][name])
    local currentCount, maxInvestSlots, totalSlots = getPlotSpaceInfo()

    if name == "Tim Cheese" then return true end

    local lowerName = string.lower(name)
    if string.find(lowerName, "block") then
        if not string.find(lowerName, "mythic") and not string.find(lowerName, "god") then
            if currentCount < totalSlots then
                return true
            end
        end
    end

    if (rarity == "Secret" or rarity == "OG" or income > 1000000) and currentCount < maxInvestSlots then
        return true
    end
    
    if mode == "IndexAndRebirth" then
        if isRequiredForRebirth and currentCount < totalSlots then
            return true
        end
    
        if isNewForCollection and currentCount < maxInvestSlots then
            return true
        end
    end

    return false
end

RenderedAnimals.ChildAdded:Connect(function(animal)
    if isStarted then
        task.wait(1.5) 

        local name = animal.Name
        local animalData = AnimalsData[name]
        if not animalData then return end

        local overHead = FindOverhead(animal)
        local prompt = FindPrompt(animal)
        if not overHead or not prompt then return end
        
        local mutationObj = overHead:FindFirstChild("Mutation")
        local mutation = (mutationObj and mutationObj.Visible and mutationObj.Text ~= "") and mutationObj.Text or "Default"

        local incomeStr = overHead:FindFirstChild("Generation") and overHead.Generation.Text or "1/s"
        local income = ParseGeneration(incomeStr)
        local rarity = overHead:FindFirstChild("Rarity") and overHead.Rarity.Text or "Common"

        if playerCash.Value >= animalData.Price then
            if buyConditionValidation(name, income, rarity, mutation) then
                prompt.PromptShown:Connect(function()
                    fireproximityprompt(prompt)
                end)
            end
        end
    end
end)

-- [Initialisation]

loadMatrix()
repeat myplot = FindPlot(localPlayer) task.wait(1) until myplot
print("Base détectée : " .. myplot.Name)

-- Scan initial pour synchroniser le JSON avec le terrain actuel
for _, child in ipairs(myplot:GetChildren()) do
    if AnimalsData[child.Name] then
        local mutation = child:GetAttribute("Mutation") or "Default"
        if not collectionMatrix[mutation] then collectionMatrix[mutation] = {} end
        if not collectionMatrix[mutation][child.Name] then
            collectionMatrix[mutation][child.Name] = true
            saveMatrix()
        end
    end
end

-- Écouteur pour les futurs achats
myplot.ChildAdded:Connect(function(child)
    task.wait(1)
    if AnimalsData[child.Name] then
        local mutation = child:GetAttribute("Mutation") or "Default"    
        if not collectionMatrix[mutation] then collectionMatrix[mutation] = {} end
        if not collectionMatrix[mutation][child.Name] then
            collectionMatrix[mutation][child.Name] = true
            saveMatrix()
            print("Nouveau Brainrot indexé et sauvegardé : " .. child.Name)
        end
    end
end)

-- [Boucle de Routine]

task.spawn(function()
    while true do
        if isStarted then
            local now = tick()

            if mode == "IndexAndRebirth" then
                local animalCount, _, _ = getPlotSpaceInfo()

                -- 1. Récolte (toutes les 5 minutes)
                if (now - lastCollectTick) >= 120 then
                    if animalCount > 0 then
                        CollectCash()
                    end
                    lastCollectTick = tick()
                end
            end

            -- 2. Anti-pousse (retour à la zone d'achat)
            local dist = (rootPart.Position - purchasePosition).Magnitude
            if dist > 5 then
                MoveTo(purchasePosition)
            end
        end
        task.wait(1)
    end
end)

local function StartIndexAndRebirthMode()
    purchasePosition = Vector3.new(-410, -7, 208)
    MoveTo(purchasePosition)
    mode = "IndexAndRebirth"
    isStarted = true
end

local function StartPingPongMode()
    if not myplot then return end
    local target = myplot:FindFirstChild("AnimalTarget")
    if not target then return end
    local pos = target.Position
    
    -- Comparaison des positions approximatives (environ 5 studs de marge)
    if (pos - Vector3.new(-347, -7, 7)).Magnitude < 20 then
        purchasePosition = Vector3.new(-411, -7, 114)
        
    elseif (pos - Vector3.new(-472, 7, 113)).Magnitude < 20 then
        purchasePosition = Vector3.new(-352, -7, 7)
        
    elseif (pos - Vector3.new(-347, -7, 114)).Magnitude < 20 then
        purchasePosition = Vector3.new(-469, -7, 114)
    end

    MoveTo(purchasePosition)
    mode = "PingPong"
    isStarted = true
end

local function OnServerMessage(rawMsg)
    local success, data = pcall(function() return HttpService:JSONDecode(rawMsg) end)
end

local function SendPlayerInfos(player)
    local playerAnimals = GetBrainrots(myplot)
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

local function SendAllPlayersInfos()
    for _, player in ipairs(Players:GetPlayers()) do
        SendPlayerInfos(player)
    end
end

-- [INITIALISATION]
local function OnServerConnect()
    SendAllPlayersInfos()

    Players.PlayerAdded:Connect(function(player)
        task.wait(1)
        SendPlayerInfos(player)
    end)
end

function connectWS(url)
    SetWSState("Disconnected") -- Rouge pendant la tentative
    local success, result = pcall(function()
        return (WebSocket and WebSocket.connect) and WebSocket.connect(url) or WebSocket.new(url)
    end)
    if success then
        server = result
        SetWSState("Connected")
        OnServerConnect()
        local messageEvent = server.OnMessage or server.Message
        messageEvent:Connect(OnServerMessage)
        server.OnClose:Connect(function()
            task.wait(reconnectDelay)
            connectWS(url)
        end)
    else
        SetWSState("Disconnected")
        task.wait(reconnectDelay)
        connectWS(url)
    end
end



IndexBtn.MouseButton1Click:Connect(function()
    StatusLabel.Text = "Status: Indexing..."
    StartIndexAndRebirthMode()
end)

PingPongBtn.MouseButton1Click:Connect(function()
    StatusLabel.Text = "Status: PingPong active"
    StartPingPongMode()
end)

StopBtn.MouseButton1Click:Connect(function()
    isStarted = false
    mode = "Idle"
    StatusLabel.Text = "Status: STOPPED"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
end)

SendInfoBtn.MouseButton1Click:Connect(function()
    SendAllPlayersInfos()
    local oldText = StatusLabel.Text
    StatusLabel.Text = "Data Sent!"
    task.wait(1.5)
    StatusLabel.Text = oldText
end)

-- [LANCEUR]
local serverURL = "wss://m4gix-ws.onrender.com/?role=Admin&user=" .. HttpService:UrlEncode(Players.LocalPlayer.Name)
task.spawn(function() connectWS(serverURL) end)
