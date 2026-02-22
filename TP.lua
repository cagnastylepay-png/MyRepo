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

local myplot = nil
local isStarted = false
local purchasePosition = Vector3.new(-413, -7, 208)
local LOG_FILE = "debug_logs.json"
local LogCache = {}

-- 2. Chargement initial au démarrage
local function LoadLogs()
    if isfile(LOG_FILE) then
        local success, content = pcall(function() return readfile(LOG_FILE) end)
        if success then
            local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(content) end)
            if decodeSuccess and type(decoded) == "table" then
                LogCache = decoded
            else
                LogCache = {} -- Fichier corrompu ou vide
            end
        end
    else
        -- Si le fichier n'existe pas, on le crée vide
        writefile(LOG_FILE, HttpService:JSONEncode({}))
        LogCache = {}
    end
end

-- 3. Fonction Debug mise à jour
local function Debug(msg)
    local timestamp = os.date("%H:%M:%S")
    local date = os.date("%d/%m/%Y")
    
    -- Création de l'entrée
    local newEntry = {
        date = date,
        time = timestamp,
        message = tostring(msg)
    }
    
    if #LogCache > 500 then table.remove(LogCache, 1) end
    table.insert(LogCache, newEntry)

    -- Sauvegarde immédiate dans le fichier
    local success, err = pcall(function()
        local jsonContent = HttpService:JSONEncode(LogCache)
        writefile(LOG_FILE, jsonContent)
    end)
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
    local lowerName = string.lower(animalModel.Name)
    if string.find(lowerName, "block") then lowerName = "block" end
    local bestPrompt = nil
    local minDistance = math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.ActionText == "Purchase" then
            Debug(string.format("🧐 [PROMPT]: %s pour %s", obj.ObjectText, animalModel.Name))
            if string.find(string.lower(obj.ObjectText), lowerName) then
                local attachment = obj.Parent
                if attachment:IsA("Attachment") and attachment.Name == "PromptAttachment" then
                    local animalPos = animalModel:GetPivot().Position
                    local horizontalPos = Vector3.new(animalPos.X, attachment.WorldCFrame.Position.Y, animalPos.Z)
                    local dist = (attachment.WorldCFrame.Position - horizontalPos).Magnitude
                    if dist < minDistance then
                        Debug(string.format("🧐 [PROMPT]: %s pour %s a %d studs", obj.ObjectText, animalModel.Name, dist))
                        minDistance = dist
                        bestPrompt = obj
                    end
                end
            end
        end
    end
    return (bestPrompt and minDistance < 15) and bestPrompt or nil
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

local function buyConditionValidation(price, name, income, rarity, mutation)

    if (rarity == "Secret" or rarity == "OG" or income > 1000000) and currentCount < totalSlots then
        return true
    end
    
    return false
end

RenderedAnimals.ChildAdded:Connect(function(animal)
    if isStarted then
        task.wait(1.5)

        local shouldBuy = false
        local lowerName = string.lower(animal.Name)

        if string.find(lowerName, "block") then
            if not string.find(lowerName, "mythic") and not string.find(lowerName, "god") then
                shouldBuy = true
            end
        else
            local overHead = FindOverhead(animal)
            local infos = ParseOverhead(overHead)
            -- Securisation si le parsing rate
            if infos then
                shouldBuy = buyConditionValidation(ParseGeneration(infos.Price or "$0"), infos.DisplayName or "Unknown", ParseGeneration(infos.Generation or "$0/s"), infos.Rarity or "Common", infos.Mutation or "Default")
            end
        end
        
        if shouldBuy then
            local prompt = FindPrompt(animal)
            prompt.PromptShown:Connect(function()
                fireproximityprompt(prompt)
            end)
        end
    end
end)

-- [Initialisation]

repeat myplot = FindPlot(localPlayer) task.wait(1) until myplot
Debug("Base détectée : " .. myplot.Name)

local function SetPosition()
    purchasePosition = rootPart.Position
end

local function StartAnchor()
    isAnchorStarted = true
end

local function StopAnchor()
    isAnchorStarted = false
end

local function Start()
    MoveTo(purchasePosition)
    isStarted = true
end

local function Stop()
    isStarted = false
end

local ScreenGui = Instance.new("ScreenGui", localPlayer.PlayerGui) -- Corrigé : localPlayer au lieu de player
ScreenGui.Name = "GeminiControl"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.Size = UDim2.new(0, 160, 0, 150) -- Taille augmentée pour 3 boutons
MainFrame.Active = true
MainFrame.Draggable = true

local UIListLayout = Instance.new("UIListLayout", MainFrame)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center


-- Fonction pour les boutons ON/OFF (AutoBuy, Anchor)
local function CreateSwitch(name, startFunc, stopFunc, status)
    local Button = Instance.new("TextButton")
    local isOn = status

    Button.Name = name
    Button.Parent = MainFrame
    Button.Size = UDim2.new(0, 140, 0, 35)
    Button.Font = Enum.Font.GothamBold
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextSize = 13

    if isOn then
        Button.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        Button.Text = name .. " Started"
    else
        Button.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        Button.Text = name .. " Stopped"
    end

    local UICorner = Instance.new("UICorner", Button)
    UICorner.CornerRadius = UDim.new(0, 8)

    Button.MouseButton1Click:Connect(function()
        isOn = not isOn
        if isOn then
            Button.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            Button.Text = name .. " Started"
            startFunc()
        else
            Button.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            Button.Text = name .. " Stopped"
            stopFunc()
        end
    end)
    return Button
end

-- Fonction pour le bouton d'action unique (Set Position)
local function CreateActionButton(name, actionFunc)
    local Button = Instance.new("TextButton")
    Button.Name = name
    Button.Parent = MainFrame
    Button.BackgroundColor3 = Color3.fromRGB(80, 80, 250) -- Bleu
    Button.Size = UDim2.new(0, 140, 0, 35)
    Button.Font = Enum.Font.GothamBold
    Button.Text = name
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextSize = 13
    
    local UICorner = Instance.new("UICorner", Button)
    UICorner.CornerRadius = UDim.new(0, 8)

    Button.MouseButton1Click:Connect(function()
        actionFunc()
        -- Petit feedback visuel rapide
        local oldText = Button.Text
        Button.Text = "Position Set!"
        task.wait(1)
        Button.Text = oldText
    end)
end

Start()
StartAnchor()

-- Création des boutons dans l'ordre
CreateSwitch("AutoBuy", Start, Stop, isStarted)
CreateSwitch("Anchor", StartAnchor, StopAnchor, isAnchorStarted)
CreateActionButton("Set Position", SetPosition)

-- [Boucle de Routine]

task.spawn(function()
    while true do
        if isAnchorStarted then
            local dist = (rootPart.Position - purchasePosition).Magnitude
            if dist > 5 then
                local velocity = rootPart.AssemblyLinearVelocity.Magnitude
                if velocity < 1 then 
                    Debug("🏠 [RETOUR]: Repositionnement zone d'achat.")
                    MoveTo(purchasePosition)
                end
            end
        end
        task.wait(0.5) 
    end
end)
