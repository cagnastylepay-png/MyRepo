local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:WaitForChild("Debris")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local RenderedAnimals = workspace:WaitForChild("RenderedMovingAnimals")

-- [VARIABLES INITIALES MANQUANTES]
local BrainrotsToBuy = {} -- Table pour stocker les IDs

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

local function OnBrainrotSpawn(brainrot) 
    print(GetFormattedName(brainrot))
end

RenderedAnimals.ChildAdded:Connect(function(animal)
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
        Prompt = prompt
    }
    OnBrainrotSpawn(animalData)
end)
