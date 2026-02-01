local Players = game:GetService("Players")
local Debris = workspace:WaitForChild("Debris")
local PathfindingService = game:GetService("PathfindingService")
local RenderedAnimals = workspace:WaitForChild("RenderedMovingAnimals")
local HttpService = game:GetService("HttpService")

local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))
local RarityData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Rarities"))

-- Configuration par défaut
local Config = {
    AutoBuyEnabled = false,
    MinGen = 1000000,
    WhitelistedRarities = {},
    WhitelistedAnimals = {},
    WhitelistedMutations = {}
}

local FILE_NAME = "AutoBuy_Config.json"

-- --- SYSTÈME DE FICHIER ---
local function SaveConfig()
    if writefile then
        writefile(FILE_NAME, HttpService:JSONEncode(Config))
    end
end

local function LoadConfig()
    if isfile and isfile(FILE_NAME) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(FILE_NAME)) end)
        if success then Config = data end
    end
end

-- --- CRÉATION DE L'INTERFACE (Résumé) ---
local ScreenGui = Instance.new("ScreenGui", Players.LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "AutoBuyGui"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 450, 0, 500)
MainFrame.Position = UDim2.new(0.5, -225, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.Active = true
MainFrame.Draggable = true -- Pour déplacer le menu

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = "AUTO-BUY MANAGER PRO"
Title.TextColor3 = Color3.new(1,1,1)
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 50)

local ToggleBtn = Instance.new("TextButton", MainFrame)
ToggleBtn.Size = UDim2.new(0, 200, 0, 40)
ToggleBtn.Position = UDim2.new(0, 10, 1, -50) -- En bas à gauche
ToggleBtn.Text = Config.AutoBuyEnabled and "AUTO-BUY: ON" or "AUTO-BUY: OFF"
ToggleBtn.BackgroundColor3 = Config.AutoBuyEnabled and Color3.new(0, 0.7, 0) or Color3.new(0.7, 0, 0)

ToggleBtn.MouseButton1Click:Connect(function()
    Config.AutoBuyEnabled = not Config.AutoBuyEnabled
    ToggleBtn.Text = Config.AutoBuyEnabled and "AUTO-BUY: ON" or "AUTO-BUY: OFF"
    ToggleBtn.BackgroundColor3 = Config.AutoBuyEnabled and Color3.new(0, 0.7, 0) or Color3.new(0.7, 0, 0)
    SaveConfig()
end)
-- --- SECTION 1 : GÉNÉRAL (MIN GEN) ---
local MinGenInput = Instance.new("TextBox", MainFrame)
MinGenInput.Size = UDim2.new(0, 200, 0, 30)
MinGenInput.Position = UDim2.new(0, 10, 0, 50)
MinGenInput.PlaceholderText = "Min Gen (ex: 1M)"
MinGenInput.Text = tostring(Config.MinGen)

MinGenInput.FocusLost:Connect(function()
    -- On utilise ta fonction ParseGeneration pour transformer "1M" en 1000000
    local val = ParseGeneration(MinGenInput.Text)
    if val and val > 0 then
        Config.MinGen = val
        print("✅ Nouveau seuil : " .. Config.MinGen)
    else
        Config.MinGen = 1000000 -- Valeur par défaut si erreur
    end
    SaveConfig()
end)

-- --- SECTION 2 : RARETÉS (DYNAMIQUE) ---
local RarityFrame = Instance.new("ScrollingFrame", MainFrame)
RarityFrame.Size = UDim2.new(0, 200, 0, 150)
RarityFrame.Position = UDim2.new(0, 10, 0, 90)
RarityFrame.CanvasSize = UDim2.new(0, 0, 2, 0)

local UIList = Instance.new("UIListLayout", RarityFrame)

for name, data in pairs(RarityData) do
    local btn = Instance.new("TextButton", RarityFrame)
    btn.Size = UDim2.new(1, -10, 0, 25)
    btn.Text = name
    btn.BackgroundColor3 = data.Color or Color3.new(0.5,0.5,0.5)
    
    local function updateVisual()
        btn.BorderMode = Enum.BorderMode.Inset
        btn.BorderSizePixel = Config.WhitelistedRarities[name] and 3 or 0
    end
    
    btn.MouseButton1Click:Connect(function()
        Config.WhitelistedRarities[name] = not Config.WhitelistedRarities[name]
        updateVisual()
        SaveConfig()
    end)
    updateVisual()
end

local FavFrame = Instance.new("ScrollingFrame", MainFrame)
FavFrame.Size = UDim2.new(0, 210, 0, 80)
FavFrame.Position = UDim2.new(0.5, 5, 1, -90)
FavFrame.CanvasSize = UDim2.new(0, 0, 5, 0)
FavFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)

local function UpdateFavList()
    for _, c in pairs(FavFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local count = 0
    for name, _ in pairs(Config.WhitelistedAnimals) do
        count = count + 1
        local b = Instance.new("TextButton", FavFrame)
        b.Size = UDim2.new(1, -5, 0, 20)
        b.Position = UDim2.new(0, 0, 0, (count-1)*20)
        b.Text = "❌ " .. name
        b.TextXAlignment = Enum.TextXAlignment.Left
        
        b.MouseButton1Click:Connect(function()
            Config.WhitelistedAnimals[name] = nil
            SaveConfig()
            UpdateFavList()
        end)
    end
end
-- --- SECTION 3 : RECHERCHE ANIMAUX (300+) ---
local SearchBox = Instance.new("TextBox", MainFrame)
SearchBox.Size = UDim2.new(0, 210, 0, 30)
SearchBox.Position = UDim2.new(0.5, 5, 0, 50)
SearchBox.PlaceholderText = "🔍 Chercher Animal..."

local ResultsFrame = Instance.new("ScrollingFrame", MainFrame)
ResultsFrame.Size = UDim2.new(0, 210, 0, 350)
ResultsFrame.Position = UDim2.new(0.5, 5, 0, 90)

local function RefreshSearch(txt)
    for _, c in pairs(ResultsFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    if txt == "" then return end
    
    local i = 0
    for id, data in pairs(AnimalsData) do
        if i > 15 then break end
        local dName = data.DisplayName or id
        if dName:lower():find(txt:lower()) then
            i = i + 1
            local b = Instance.new("TextButton", ResultsFrame)
            b.Size = UDim2.new(1, -10, 0, 25)
            b.Position = UDim2.new(0, 0, 0, (i-1)*25)
            b.Text = dName
            
            b.MouseButton1Click:Connect(function()
                Config.WhitelistedAnimals[dName] = true
                print("Ajouté : "..dName)
                SaveConfig()
                UpdateFavList()
            end)
        end
    end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    RefreshSearch(SearchBox.Text)
end)

-- --- INITIALISATION ---
LoadConfig()
UpdateFavList()
print("GUI Chargé avec succès !")

local function MoveTo(targetInstance, prompt)
    local character = Players.LocalPlayer.Character
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local hasBeenTriggered = false
    local connection -- On prépare la variable pour la déconnecter plus tard

    -- On écoute l'événement Triggered du prompt
    connection = prompt.Triggered:Connect(function()
        hasBeenTriggered = true
        if connection then connection:Disconnect() end
    end)
  
    -- Tant que l'animal existe et que l'autoBuy est ON
    while targetInstance and targetInstance.Parent and Config.AutoBuyEnabled and not hasBeenTriggered do
        local distance = (rootPart.Position - targetInstance:GetPivot().Position).Magnitude
        local lastTargetPos = targetInstance:GetPivot().Position
        local path = PathfindingService:CreatePath({
            AgentRadius = 3, 
            AgentHeight = 5, 
            AgentCanJump = true
        })

        local success, _ = pcall(function() 
            path:ComputeAsync(rootPart.Position, targetInstance:GetPivot().Position) 
        end)

        if success and path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            
            -- On ne parcourt que les 2 ou 3 premiers waypoints 
            -- puis on recalcule pour s'ajuster au mouvement de l'animal
            for i = 1, math.min(3, #waypoints) do
                local waypoint = waypoints[i]
                
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end
                
                humanoid:MoveTo(waypoint.Position)
                
                -- On attend un tout petit peu ou que le waypoint soit atteint
                local reached = humanoid.MoveToFinished:Wait(0.2) 
                
                -- Si l'animal a trop bougé pendant qu'on marchait, on casse la boucle interne
                -- pour recalculer un nouveau path immédiatement
                if (targetInstance:GetPivot().Position - lastTargetPos).Magnitude > 5 then
                    break
                end
            end
        else
            -- Si le pathfinding échoue (trop près ou obstacle complexe), MoveTo direct
            humanoid:MoveTo(targetInstance:GetPivot().Position)
            task.wait(0.2)
        end
        
        task.wait(0.05) -- Petite pause pour éviter de crash le script avec trop de calculs
    end
end

local function ParseGeneration(str)
    local clean = str:gsub("[%$%s/s]", ""):upper() -- Enlève $, espaces et /s
    local multiplier = 1
    local numStr = clean
    
    if clean:find("K") then
        multiplier = 10^3
        numStr = clean:gsub("K", "")
    elseif clean:find("M") then
        multiplier = 10^6
        numStr = clean:gsub("M", "")
    elseif clean:find("B") then
        multiplier = 10^9
        numStr = clean:gsub("B", "")
    elseif clean:find("T") then
        multiplier = 10^12
        numStr = clean:gsub("T", "")
    end
    
    local val = tonumber(numStr)
    return val and (val * multiplier) or 0
end

local function FindOverhead(animalModel)
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
		    return bestTemplate
    end
    return nil
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
  
local function ShouldIBuy(brainrot)
    local genValue = ParseGeneration(brainrot.Generation)
    if Config.WhitelistedRarities[brainrot.Rarity] then return true end
    if Config.WhitelistedAnimals[brainrot.DisplayName] then return true end
    if Config.WhitelistedMutations[brainrot.Mutation] then return true end
    if Config.MinGen >= minGen then return true end
    return false
end

local function OnBrainrotSpawn(brainrot) 
    if ShouldIBuy(brainrot) then         
        if brainrot.Prompt then
            local connection
            connection = brainrot.Prompt.PromptShown:Connect(function()
                fireproximityprompt(brainrot.Prompt)
                connection:Disconnect()
            end)
            task.spawn(function()
                MoveTo(brainrot.Instance, brainrot.Prompt)
                if connection.Connected then
                    connection:Disconnect()
                end
            end)
        end
    end
end

RenderedAnimals.ChildAdded:Connect(function(animal)
    if Config.AutoBuyEnabled then
        task.wait(1.5) 
    
        local template = FindOverhead(animal)
        local prompt = FindPrompt(animal)

        if not template then return end
    
        local container = template:FindFirstChild("AnimalOverhead")
        if not container then return end
        local displayObj = container:FindFirstChild("DisplayName")
        local priceObj = container:FindFirstChild("Price")
        local mutationObj = container:FindFirstChild("Mutation")
    
        local start = tick()
        while (tick() - start) < 5 do
            if displayObj and displayObj.Text ~= "" then
                break
            end
            task.wait(0.2)
        end

        if not displayObj or displayObj.Text == "" then 
            return 
        end

        local actualMutation = "Default"
        if mutationObj and mutationObj.Visible and mutationObj.Text ~= "" then
            actualMutation = mutationObj.Text
        end

        local animalData = {
            Instance = animal,
            DisplayName = displayObj.Text,
            Mutation = actualMutation,
            Generation = container:FindFirstChild("Generation") and container.Generation.Text or "1/s",
            Price = priceObj.Text,
            Rarity = container:FindFirstChild("Rarity") and container.Rarity.Text or "Common",
            Prompt = prompt
        }
        OnBrainrotSpawn(animalData)
    end
end)
