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
local isDebugMode = false
local LOG_FILE = "Gemini_Bot_Logs.txt"

-- Initialisation du fichier (optionnel : écrase le log précédent au lancement)
pcall(function()
    writefile(LOG_FILE, "-- DÉBUT DE SESSION : " .. os.date("%X") .. " --\n")
end)

local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local BuyBtn = Instance.new("TextButton")
local MinimizeBtn = Instance.new("TextButton")
local StatusLabel = Instance.new("TextLabel")
local UIListLayout = Instance.new("UIListLayout")
local UICorner = Instance.new("UICorner")
local StopBtn = Instance.new("TextButton")
local DebugToggleBtn = Instance.new("TextButton")

-- Configuration du ScreenGui
ScreenGui.Name = "GeminiManager"
ScreenGui.Parent = localPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Cadre Principal
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.Size = UDim2.new(0, 200, 0, 380)
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
Title.Text = "M4GIX HUB"
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

BuyBtn.Parent = BtnContainer
BuyBtn.Text = "START SIMPLE BUY"
StyleButton(BuyBtn, Color3.fromRGB(183, 28, 28))

-- Bouton STOP (Rouge vif)
StopBtn.Name = "StopBtn"
StopBtn.Parent = BtnContainer
StopBtn.Text = "STOP ALL"
StyleButton(StopBtn, Color3.fromRGB(200, 0, 0))

-- Bouton TOGGLE DEBUG (Type Checkbox)
DebugToggleBtn.Name = "DebugToggleBtn"
DebugToggleBtn.Parent = BtnContainer
DebugToggleBtn.Text = "DEBUG MODE: OFF"
StyleButton(DebugToggleBtn, Color3.fromRGB(80, 80, 80))

StatusLabel.Parent = BtnContainer
StatusLabel.BackgroundTransparency = 1
StatusLabel.Size = UDim2.new(1, 0, 0, 25)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusLabel.TextSize = 12

-- [LOGIQUE]

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    if not isMinimized then
        MainFrame:TweenSize(UDim2.new(0, 200, 0, 40), "Out", "Quart", 0.3, true)
        BtnContainer.Visible = false
        MinimizeBtn.Text = "+"
    else
        MainFrame:TweenSize(UDim2.new(0, 200, 0, 380), "Out", "Quart", 0.3, true)
        BtnContainer.Visible = true
        MinimizeBtn.Text = "—"
    end
    isMinimized = not isMinimized
end)

local function Debug(msg)
    local timestamp = os.date("[%H:%M:%S]")
    local formattedMsg = timestamp .. " " .. tostring(msg)

    if isDebugMode then 
        print(formattedMsg) 
    end

    local success, err = pcall(function()
        appendfile(LOG_FILE, formattedMsg .. "\n")
    end)
    if not success and isDebugMode then
        warn("Impossible d'écrire dans le log : " .. tostring(err))
    end
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
    if isMoving then return end 
    isMoving = true
    
    local path = PathfindingService:CreatePath({AgentRadius = 3, AgentHeight = 6, AgentCanJump = true})
    local success, _ = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)
    
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i, waypoint in ipairs(waypoints) do
            if not isStarted then break end 
            
            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
            humanoid:MoveTo(waypoint.Position)
            
            -- Sécurité : Si après 1.5 seconde on n'est pas au waypoint, on annule pour recalculer
            local arrived = humanoid.MoveToFinished:Wait(1.5) 
            if not arrived then 
                Debug("⚠️ Coincé ou trop lent, recalcul du chemin...")
                break 
            end
        end
    else
        -- Si le pathfinding galère, on force une ligne droite
        humanoid:MoveTo(targetPos)
        humanoid.MoveToFinished:Wait(2)
    end
    
    isMoving = false
end

local function buyConditionValidation(price, name, income, rarity, mutation)

    if rarity == "Secret" or rarity == "OG" or income > 1000000 then
        Debug("✅ [ACHAT]: Valeur élevée détectée (Secret/OG/1M+)")
        return true
    end
    
    return false
end

RenderedAnimals.ChildAdded:Connect(function(animal)
    if isStarted then
        task.wait(1.5)
        --Debug(string.format("🧐 [ADDED]: %s ", animal.Name))

        local shouldBuy = false
        local lowerName = string.lower(animal.Name)

        if string.find(lowerName, "block") then
            if not string.find(lowerName, "mythic") and not string.find(lowerName, "god") then
                Debug("✅ [ACHAT]: Lucky Block détecté")
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


-- [Boucle de Routine]

task.spawn(function()
    while true do
        if isStarted and not isMoving then
            local dist = (rootPart.Position - purchasePosition).Magnitude
            if dist > 4 then -- Si on est à plus de 6 studs du point de garde
                Debug("🔄 Retour au point de garde via Pathfinding...")
                task.spawn(MoveTo, purchasePosition) -- On lance le mouvement sans bloquer
            end
        end
        task.wait(1) -- Vérification chaque seconde
    end
end)

BuyBtn.MouseButton1Click:Connect(function()
    purchasePosition = rootPart.Position
    StatusLabel.Text = "Status: Auto Buy active"
    isStarted = true
end)

StopBtn.MouseButton1Click:Connect(function()
    isStarted = false
    StatusLabel.Text = "Status: Stopped"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
end)

DebugToggleBtn.MouseButton1Click:Connect(function()
    isDebugMode = not isDebugMode
    
    if isDebugMode then
        DebugToggleBtn.Text = "DEBUG MODE: ON"
        DebugToggleBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 0) 
    else
        DebugToggleBtn.Text = "DEBUG MODE: OFF"
        DebugToggleBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80) 
    end
end)

-- [LANCEUR]
MoveTo(purchasePosition)
StatusLabel.Text = "Status: Auto Buy active"
isStarted = true
