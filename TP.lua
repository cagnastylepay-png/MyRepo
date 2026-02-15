local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:WaitForChild("Debris")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local RenderedAnimals = workspace:WaitForChild("RenderedMovingAnimals")
local RunService = game:GetService("RunService")

local ScreenGui = Instance.new("ScreenGui")
local Frame = Instance.new("Frame")
local StartBtn = Instance.new("TextButton")
local BotSelector = Instance.new("TextButton")
local AxeBot2 = -60
local AxeBot1 = -355

local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Setup du GUI
ScreenGui.Parent = game.CoreGui
Frame.Size = UDim2.new(0, 160, 0, 110)
Frame.Position = UDim2.new(0, 10, 0, 10)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.Active = true
Frame.Draggable = true 
Frame.Parent = ScreenGui

Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)

-- Sélecteur de Mode
local currentBot = 1
BotSelector.Size = UDim2.new(1, -20, 0, 35)
BotSelector.Position = UDim2.new(0, 10, 0, 15)
BotSelector.Text = "BOT 1 (Z > 130 | Axe -355)"
BotSelector.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
BotSelector.TextColor3 = Color3.new(1, 1, 1)
BotSelector.Font = Enum.Font.SourceSansBold
BotSelector.TextSize = 12
BotSelector.Parent = Frame
Instance.new("UICorner", BotSelector)

BotSelector.MouseButton1Click:Connect(function()
    if currentBot == 1 then
        currentBot = 2
        BotSelector.Text = "BOT 2 (Z < 130 | Axe -60)"
    else
        currentBot = 1
        BotSelector.Text = "BOT 1 (Z > 130 | Axe -355)"
    end
end)

-- Bouton Start/Stop
local botStarted = false
StartBtn.Size = UDim2.new(1, -20, 0, 35)
StartBtn.Position = UDim2.new(0, 10, 0, 60)
StartBtn.Text = "START"
StartBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
StartBtn.TextColor3 = Color3.new(1, 1, 1)
StartBtn.Font = Enum.Font.SourceSansBold
StartBtn.TextSize = 16
StartBtn.Parent = Frame
Instance.new("UICorner", StartBtn)


StartBtn.MouseButton1Click:Connect(function()
    botStarted = not botStarted
    
    if botStarted then
        if rootPart then
            local currentZ = rootPart.Position.Z
            if currentBot == 1 then
                AxeBot1 = currentZ
                print("📍 Axe BOT 1 enregistré sur Z : " .. AxeBot1)
            else
                AxeBot2 = currentZ
                print("📍 Axe BOT 2 enregistré sur Z : " .. AxeBot2)
            end
        end

        StartBtn.Text = "STOP"
        StartBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    else
        StartBtn.Text = "START"
        StartBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
    end
end)
-- [VARIABLES INITIALES MANQUANTES]
local BrainrotsToBuy = {}
local isProcessing = false

-- Chargement des modules de données
local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

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
                    bestTemplate = item
                end
            end
        end
    end
    if bestTemplate and minDistance < 3 then return bestTemplate end
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

local function GetFormattedName(brainrot)
    local components = {}
    
    if brainrot.Mutation and brainrot.Mutation ~= "Default" then
        table.insert(components, brainrot.Mutation)
    end

    -- 2. On ajoute les traits
    --for _, trait in ipairs(brainrot.Traits) do
    --    table.insert(components, trait)
    --end

    -- 3. Construction de la partie entre crochets
    local prefix = ""
    if #components > 0 then
        prefix = "[" .. table.concat(components, ", ") .. "] "
    end

    -- 4. Assemblage final
    return prefix .. brainrot.DisplayName .. " -> " .. brainrot.Rarity .. " " .. brainrot.GenerationStr
end

local function ShouldIBuy(brainrot)
    local luckies = {"Heart Lucky Block", "Secret Lucky Block", "Admin Lucky Block", "Taco Lucky Block", "Los Lucky Blocks", "Los Taco Blocks"}

    -- 1. Si c'est un Secret, on achète direct
    if brainrot.Rarity == "Secret" then 
        return true 
    end

    -- 2. Si le nom est dans la liste des Lucky Blocks
    for _, name in ipairs(luckies) do
        if brainrot.DisplayName == name then
            return true
        end
    end

    -- 3. Si la génération est supérieure à 5 Millions (5,000,000)
    -- Rappel : brainrot.Generation est déjà un nombre grâce à ParseGeneration
    if brainrot.Generation and brainrot.Generation >= 5000000 then
        return true
    end

    return false
end

local function OnBrainrotSpawn(brainrot) 
    print(GetFormattedName(brainrot))
    if ShouldIBuy(brainrot) then
        table.insert(BrainrotsToBuy, brainrot)
        brainrot.Prompt.PromptShown:Connect(function()
            fireproximityprompt(brainrot.Prompt)
        end)
        brainrot.Prompt.Triggered:Connect(function()
            brainrot.BuyStatus = "Buyed"
            isProcessing = false
        end)
    end
end

RenderedAnimals.ChildAdded:Connect(function(animal)
    if botStarted then
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
            if displayObj and displayObj.Text ~= "" then break end
            task.wait(0.2)
        end
        if not displayObj or displayObj.Text == "" then return end
        local actualMutation = "Default"
        if mutationObj and mutationObj.Visible and mutationObj.Text ~= "" then
            actualMutation = mutationObj.Text
        end
        local animalData = {
            Animal = animal,
            AnimalOverhead = container,
            DisplayName = displayObj.Text,
            Mutation = actualMutation,
            GenerationStr = container:FindFirstChild("Generation") and container.Generation.Text or "1/s",
            Generation = ParseGeneration(container:FindFirstChild("Generation") and container.Generation.Text or "1/s"),
            Price = priceObj.Text,
            Rarity = container:FindFirstChild("Rarity") and container.Rarity.Text or "Common",
            Traits = {},
            Prompt = prompt,
            BuyStatus = (currentBot == 1) and "Wait" or "Buyed"
        }
        OnBrainrotSpawn(animalData)
    end
end)

local function MoveTo(targetPos)
    local path = PathfindingService:CreatePath({AgentRadius = 5, AgentHeight = 6, AgentCanJump = true})
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

task.spawn(function()
    while true do
        task.wait(0.2)
        if not botStarted then continue end

        if rootPart and humanoid and #BrainrotsToBuy > 0 then
            local targetAnimal = nil
            local bestPriority = (currentBot == 1) and -math.huge or math.huge
            -- Définition de la profondeur fixe selon le bot choisi
            local fixedZ = (currentBot == 1) and AxeBot1 or AxeBot2

            for i = #BrainrotsToBuy, 1, -1 do
                local brainrot = BrainrotsToBuy[i]
                
                if not brainrot.Animal or not brainrot.Animal.Parent then
                    table.remove(BrainrotsToBuy, i)
                    continue
                end

                local animalPos = brainrot.Animal:GetPivot().Position

                -- LOGIQUE DE FILTRAGE
                if currentBot == 1 then
                    -- BOT 1 : Z > 130
                    if animalPos.Z < 130 and brainrot.BuyStatus == "Buyed" then 
                        brainrot.BuyStatus = "Wait" 
                    end
                    if brainrot.BuyStatus == "Wait" and animalPos.Z > 130 then
                        if animalPos.Z > bestPriority then 
                            bestPriority = animalPos.Z
                            targetAnimal = brainrot
                        end
                    end
                else
                    -- BOT 2 : Z < 130
                    if animalPos.Z > 130 and brainrot.BuyStatus == "Buyed" then 
                        brainrot.BuyStatus = "Wait" 
                    end
                    if brainrot.BuyStatus == "Wait" and animalPos.Z < 130 then
                        if animalPos.Z < bestPriority then 
                            bestPriority = animalPos.Z
                            targetAnimal = brainrot
                        end
                    end
                end
            end

            -- EXÉCUTION DU MOUVEMENT
            if targetAnimal then
                local animalX = targetAnimal.Animal:GetPivot().Position.X
                local myX = rootPart.Position.X
                local distanceX = math.abs(myX - animalX)
                
                -- Position cible avec le Z spécifique au bot
                local targetPos = Vector3.new(animalX, rootPart.Position.Y, fixedZ)
                
                if not isProcessing then
                    MoveTo(targetPos)

                    -- Alignement X précis
                    if distanceX < 1.5 then
                        isProcessing = true
                        print("📍 Bot " .. currentBot .. " aligné. Achat de : " .. targetAnimal.DisplayName)
                        
                        task.delay(4, function()
                            if isProcessing and targetAnimal.BuyStatus == "Wait" then
                                isProcessing = false
                            end
                        end)
                    end
                else
                    -- Ajustement continu du X pendant l'achat
                    if distanceX > 0.5 then
                        MoveTo(targetPos)
                    end
                end
            else
                MoveTo(Vector3.new(-413,-7,783))
            end
        end
    end
end)

local function AutoStart()
    MoveTo(Vector3.new(-413,-7,783))
    botStarted = true
    StartBtn.Text = "STOP"
    StartBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
end

AutoStart()
