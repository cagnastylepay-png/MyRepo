local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:WaitForChild("Debris")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local RenderedAnimals = workspace:WaitForChild("RenderedMovingAnimals")
local RunService = game:GetService("RunService")

-- Variables Globales
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
    return (bestTemplate and minDistance < 3) and bestTemplate or nil
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
    local prefix = ""
    if #components > 0 then
        prefix = "[" .. table.concat(components, ", ") .. "] "
    end
    return prefix .. brainrot.DisplayName .. " -> " .. brainrot.Rarity .. " " .. brainrot.GenerationStr
end

local function ShouldIBuy(brainrot)
    return brainrot.Mutation ~= "Default"
end

local function OnBrainrotSpawn(brainrot) 
    local name = GetFormattedName(brainrot)
    print("📢 Nouveau Spawn détecté : " .. name)
    
    if ShouldIBuy(brainrot) then
        print("🎯 Cible VALIDE ajoutée à la liste d'achat : " .. brainrot.DisplayName)
        table.insert(BrainrotsToBuy, brainrot)
        
        brainrot.Prompt.PromptShown:Connect(function()
            print("⚡ Prompt affiché pour " .. brainrot.DisplayName .. " ! Tentative d'achat...")
            fireproximityprompt(brainrot.Prompt)
        end)
        
        brainrot.Prompt.Triggered:Connect(function()
            print("💰 ACHAT RÉUSSI (Triggered) : " .. brainrot.DisplayName)
            brainrot.BuyStatus = "Buyed"
            isProcessing = false -- On libère le bot pour la suite
        end)
    else
        print("⏩ Cible ignorée (pas de mutation) : " .. brainrot.DisplayName)
    end
end

RenderedAnimals.ChildAdded:Connect(function(animal)
    task.wait(1.5) 
    print("🔍 Analyse d'un nouvel animal...")
    local template = FindOverhead(animal)
    local prompt = FindPrompt(animal)
    
    if not template then print("❌ Overhead non trouvé pour " .. animal.Name) return end
    if not prompt then print("❌ Prompt non trouvé pour " .. animal.Name) return end
    
    local container = template:FindFirstChild("AnimalOverhead")
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
        BuyStatus = "Wait"
    }
    OnBrainrotSpawn(animalData)
end)

task.spawn(function()
    print("🤖 Boucle de mouvement démarrée.")
    while true do
        local character = Players.LocalPlayer.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        
        if rootPart and #BrainrotsToBuy > 0 then
            local targetAnimal = nil
            local maxZ = -math.huge

            for i = #BrainrotsToBuy, 1, -1 do
                local brainrot = BrainrotsToBuy[i]
                
                if not brainrot.Animal or not brainrot.Animal.Parent then
                    print("🗑️ Animal supprimé du jeu, retrait de la liste : " .. brainrot.DisplayName)
                    table.remove(BrainrotsToBuy, i)
                    continue
                end

                local animalPos = brainrot.Animal:GetPivot().Position

                -- Reset si remonté
                if animalPos.Z < 130 and brainrot.BuyStatus == "Buyed" then
                    brainrot.BuyStatus = "Wait"
                    print("🔄 " .. brainrot.DisplayName .. " est remonté. Prêt pour un nouveau cycle.")
                end

                -- Recherche de la cible la plus proche du bord (Max Z)
                if brainrot.BuyStatus == "Wait" and animalPos.Z > 130 then
                    if animalPos.Z > maxZ then
                        maxZ = animalPos.Z
                        targetAnimal = brainrot
                    end
                end
            end

            -- Mouvement
            if targetAnimal and not isProcessing then
                local animalX = targetAnimal.Animal:GetPivot().Position.X
                local distanceX = math.abs(rootPart.Position.X - animalX)
                
                -- On ne log le mouvement que si on doit vraiment bouger
                if distanceX > 2 then
                    print("🏃 Déplacement vers " .. targetAnimal.DisplayName .. " (X: " .. math.floor(animalX) .. " | Z: " .. math.floor(maxZ) .. ")")
                end
                
                local targetPos = Vector3.new(animalX, rootPart.Position.Y, rootPart.Position.Z)
                humanoid:MoveTo(targetPos)
                
                -- Si on est très proche, on peut considérer qu'on est en train de processer
                if distanceX < 3 then
                    isProcessing = true
                    print("📍 Arrivé sur cible. Verrouillage activé pour l'achat de " .. targetAnimal.DisplayName)
                    
                    -- Sécurité : si le Triggered ne vient jamais, on débloque après 4 secondes
                    task.delay(4, function()
                        if isProcessing then
                            isProcessing = false
                            print("⚠️ Verrouillage libéré par timeout (achat trop long)")
                        end
                    end)
                end
            end
        end
        
        task.wait(0.1) 
    end
end)
