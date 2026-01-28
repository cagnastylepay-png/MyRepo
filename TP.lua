local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Plots = workspace:WaitForChild("Plots")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RenderedAnimals = workspace:WaitForChild("RenderedMovingAnimals")
local Debris = workspace:WaitForChild("Debris")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

-- === CONFIGURATION ===
local currentMinGen = 10
local maxGen = 3000000000
local scriptActive = false -- État du script

-- === FONCTIONS LOGIQUES ===

local function getDynamicStep(val, isDecrement)
    local checkVal = isDecrement and (val - 1) or val
    if checkVal < 100 then return 10
    elseif checkVal < 1000 then return 100
    elseif checkVal < 10000 then return 1000
    elseif checkVal < 1000000 then return 10000
    elseif checkVal < 1000000000 then return 1000000
    else return 100000000 end
end

local function formatGen(val)
    if val >= 10^9 then return string.format("$%.2fB/s", val / 10^9) end
    if val >= 10^6 then return string.format("$%.1fM/s", val / 10^6) end
    if val >= 10^3 then return string.format("$%.1fK/s", val / 10^3) end
    return "$" .. math.floor(val) .. "/s"
end

-- === CRÉATION DU GUI ===

local sg = Instance.new("ScreenGui", playerGui)
sg.Name = "M4GIX_AutoBuy_UI"

local bar = Instance.new("Frame", sg)
bar.Size = UDim2.new(0, 500, 0, 45) -- Un peu plus large pour le toggle
bar.Position = UDim2.new(0.5, -250, 0.9, -50)
bar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
bar.BorderSizePixel = 0
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)

-- Bouton TOGGLE (ON/OFF)
local toggleBtn = Instance.new("TextButton", bar)
toggleBtn.Size = UDim2.new(0, 60, 0, 25)
toggleBtn.Position = UDim2.new(0.02, 0, 0.5, -12)
toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Rouge par défaut
toggleBtn.Text = "OFF"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 12
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 5)

-- Titre (Décalé pour laisser place au toggle)
local title = Instance.new("TextLabel", bar)
title.Size = UDim2.new(0.3, 0, 1, 0)
title.Position = UDim2.new(0.16, 0, 0, 0)
title.Text = "CRD AUTO-BUY"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

-- Conteneur Contrôles
local ctrl = Instance.new("Frame", bar)
ctrl.Size = UDim2.new(0, 220, 0, 30)
ctrl.Position = UDim2.new(0.52, 0, 0.5, -15)
ctrl.BackgroundTransparency = 1

local btnMinus = Instance.new("TextButton", ctrl)
btnMinus.Size = UDim2.new(0, 30, 1, 0)
btnMinus.Text = "-"
btnMinus.TextColor3 = Color3.new(1, 1, 1)
btnMinus.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btnMinus.Font = Enum.Font.GothamBold
btnMinus.TextSize = 18
Instance.new("UICorner", btnMinus).CornerRadius = UDim.new(0, 5)

local valLabel = Instance.new("TextLabel", ctrl)
valLabel.Size = UDim2.new(0, 140, 1, 0)
valLabel.Position = UDim2.new(0, 40, 0, 0)
valLabel.Text = formatGen(currentMinGen)
valLabel.TextColor3 = Color3.new(1, 1, 1)
valLabel.BackgroundTransparency = 1
valLabel.Font = Enum.Font.Code
valLabel.TextSize = 18

local btnPlus = Instance.new("TextButton", ctrl)
btnPlus.Size = UDim2.new(0, 30, 1, 0)
btnPlus.Position = UDim2.new(0, 190, 0, 0)
btnPlus.Text = "+"
btnPlus.TextColor3 = Color3.new(1, 1, 1)
btnPlus.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btnPlus.Font = Enum.Font.GothamBold
btnPlus.TextSize = 18
Instance.new("UICorner", btnPlus).CornerRadius = UDim.new(0, 5)

-- === LOGIQUE D'INTERACTION ===

-- Toggle ON/OFF
toggleBtn.MouseButton1Click:Connect(function()
    scriptActive = not scriptActive
    if scriptActive then
        toggleBtn.Text = "ON"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50) -- Vert
    else
        toggleBtn.Text = "OFF"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Rouge
    end
end)

local function update(delta)
    local step = getDynamicStep(currentMinGen, delta < 0)
    currentMinGen = math.clamp(currentMinGen + (step * (delta > 0 and 1 or -1)), 1, maxGen)
    valLabel.Text = formatGen(currentMinGen)
end

btnPlus.MouseButton1Down:Connect(function() update(1) end)
btnMinus.MouseButton1Down:Connect(function() update(-1) end)


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

local function OnBrainrotSpawn(brainrot)
    if not scriptActive then return end 
    local genValue = ParseGeneration(brainrot.GenString)
    local targetValue = currentMinGen -- Utilise la valeur globale à jour
    
    if genValue >= targetValue then
        if brainrot.Prompt then
            local connection
            connection = brainrot.Prompt.PromptShown:Connect(function()
                fireproximityprompt(brainrot.Prompt)
                connection:Disconnect()
            end)
        end
    end
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
                local dist = (item.Position - animalModel:GetPivot().Position).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    bestTemplate = item
                end
            end
        end
    end

    if bestTemplate and minDistance < 12 then
        return bestTemplate
    end
    return nil
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

RenderedAnimals.ChildAdded:Connect(function(animal)
    task.wait(1.5) 
    
    local template = FindOverheadForAnimal(animal)
    local prompt = FindPromptForAnimal(animal)

    if not template then return end
    
    local container = template:FindFirstChild("AnimalOverhead")
    if not container then return end

    -- ATTENTE ACTIVE DES DONNÉES (Max 5 secondes)
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

    -- Si après 5s on n'a toujours pas de nom, on abandonne
    if not displayObj or displayObj.Text == "" then 
        return 
    end

    -- On détermine la mutation réelle (Check visibilité)
    local actualMutation = "Default"
    if mutationObj and mutationObj.Visible and mutationObj.Text ~= "" then
        actualMutation = mutationObj.Text
    end

    -- Création du pack de données pour OnBrainrotSpawn
    local animalData = {
        Instance = animal,
        DisplayName = displayObj.Text,
        Mutation = actualMutation,
        GenString = container:FindFirstChild("Generation") and container.Generation.Text or "1",
        Price = priceObj.Text,
        Rarity = container:FindFirstChild("Rarity") and container.Rarity.Text or "Common",
        Prompt = prompt
    }
    
    OnBrainrotSpawn(animalData)
end)
