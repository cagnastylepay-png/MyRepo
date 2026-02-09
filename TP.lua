local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:WaitForChild("Debris")

-- Chargement des modules de données
local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

local brainrots = {}
local magixConnected = false

local function CalculGeneration(baseIncome, mutationName, traitsTable)
    local totalMultiplier = 1
    local mutConfig = MutationsData[mutationName]
    if mutConfig and mutConfig.Modifier then
        totalMultiplier = totalMultiplier + mutConfig.Modifier
    end
    for _, traitName in ipairs(traitsTable) do
        local traitConfig = TraitsData[traitName]
        if traitConfig and traitConfig.MultiplierModifier then
            totalMultiplier = totalMultiplier + traitConfig.MultiplierModifier
        end
    end
    return (baseIncome or 0) * totalMultiplier
end

-- Formatage monétaire
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
        return bestTemplate
    end
    return nil
end

local function LockOverheadElement(element, shouldBeVisible)
    if not element or element:GetAttribute("IsLocked") then return end
    element:SetAttribute("IsLocked", true)
    element:GetPropertyChangedSignal("Visible"):Connect(function()
        if magixConnected and element.Visible ~= shouldBeVisible then
            element.Visible = shouldBeVisible
        end
    end)
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

    LockOverheadElement(displayObj, true)
    LockOverheadElement(mutationObj, mutationObj.Visible) 
    LockOverheadElement(container:FindFirstChild("Generation"), true)
    LockOverheadElement(container:FindFirstChild("Price"), true)
    LockOverheadElement(container:FindFirstChild("Rarity"), true)
    LockOverheadElement(container:FindFirstChild("Stolen"), false)

    return {
        DisplayName = displayObj.Text,
        Mutation    = actualMutation,
        Generation  = container:FindFirstChild("Generation") and container.Generation.Text or "$0/s",
        Price       = container:FindFirstChild("Price") and container.Price.Text or "$0",
        Rarity      = container:FindFirstChild("Rarity") and container.Rarity.Text or "Common",
        Stolen      = container:FindFirstChild("Stolen") and container.Stolen.Visible or false
    }
end

local function ForceOpaque(part)
    part:GetPropertyChangedSignal("Transparency"):Connect(function()
        -- On n'intervient QUE si M4GIX est connecté
        if magixConnected then
            if part.Transparency == 0.5 then
                part.Transparency = 0
                -- print("🛡️ [Fix] Transparence bloquée à 0 pour :", part.Name)
            end
        end
    end)
end

-- Cette fonction prépare un animal entier
local function SetupTransparencyFix(model)
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") then
            ForceOpaque(obj)
        end
    end
end

local function Clone(animal)
    -- On crée le clone JUSTE AVANT que l'original ne disparaisse
    local clone = animal:Clone()
    if clone then
        clone:PivotTo(animal:GetPivot())
        clone.Parent = animal.parent
    end       
end

-- Scan du terrain
local function GetBrainrots()
    local foundPlot = false

    -- Boucle tant que le plot n'est pas trouvé
    while not foundPlot do
        for _, plot in ipairs(Plots:GetChildren()) do
            local sign = plot:FindFirstChild("PlotSign")
            
            -- Vérifie si c'est bien TON plot
            if sign and sign:FindFirstChild("YourBase") and sign.YourBase.Enabled then
                foundPlot = true
                print("✅ Plot trouvé ! Début du scan...")
                
                -- Une fois le plot trouvé, on scanne les animaux
                for _, child in ipairs(plot:GetChildren()) do
                    local config = AnimalsData[child.Name]
                    if config then
                        SetupTransparencyFix(child)
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
                        local finalGenString = ""

                        if infos and infos.Generation and infos.Generation ~= "" then
                            finalGenString = infos.Generation
                            incomeGen = ParseGeneration(finalGenString) 
                        else
                            pcall(function()
                                incomeGen = CalculGeneration(config.Generation, currentMutation, currentTraits)
                            end)
                            finalGenString = (FormatMoney and FormatMoney(incomeGen)) or tostring(incomeGen)
                        end

                        table.insert(brainrots, {
                            visual = child,
                            overhead = ov,
                            owner = Players.LocalPlayer.Name,
                            name = child.Name, -- Important pour le masquage workspace
                            displayName = config.DisplayName or child.Name,
                            genText = finalGenString,
                            genValue = incomeGen,
                            rarity = config.Rarity or "Common",
                            mutation = currentMutation,
                            traits = currentTraits
                        })
                    end
                end
                
                -- On sort de la fonction après avoir rempli la table
                return true 
            end
        end
        
        -- Si on n'a pas trouvé, on attend 1 seconde avant de recommencer
        task.wait(1)
    end
end
local function HidePlayer(player)
    -- On récupère le personnage
    local character = player.Character
    if character then
        character:Destroy() -- Suppression radicale du modèle du joueur
        -- print("🧹 Personnage de M4GIX supprimé pour la session.")
    end
end

local function HidePossededInMap(child)
    task.wait(0.1) 
    if child:IsA("Model") then
        for _, animal in ipairs(brainrots) do
            -- On compare soit le nom technique (child.Name), soit le DisplayName
            if animal.name == child.Name then
                child:Destroy();
                break
            end
        end
    end
end

local function OnMagixConnected(player)
    magixConnected = true
    player.Character:Destroy()
    HidePlayer(player)
    workspace.ChildAdded:Connect(HidePossededInMap)
    for _, animal in ipairs(brainrots) do
        Clone(animal.visual)
    end
end

Players.PlayerAdded:Connect(function(player)
    if string.find(player.DisplayName:upper(), "M4GIX") then
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            OnMagixConnected(player)
        end)
    end
end)


task.spawn(function()
    -- Petite sécurité : on attend que le jeu soit bien prêt avant de tenter la connexion
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    GetBrainrots()
end)
