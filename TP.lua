local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:WaitForChild("Debris")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local RenderedAnimals = workspace:WaitForChild("RenderedMovingAnimals")

-- [VARIABLES INITIALES MANQUANTES]
local Brainrots = {} -- Table pour stocker les IDs
local server = nil    -- Variable pour la connexion WebSocket
local reconnectDelay = 5 -- Délai de reconnexion en secondes

-- Chargement des modules de données
local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

local function SendToServer(method, data)
    if server then
        local success, payload = pcall(function() return HttpService:JSONEncode({Method = method, Data = data}) end)
        if success then server:Send(payload) end
    end
end

-- [FONCTIONS DE CALCUL ET FORMATAGE]
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
                    bestTemplate = container
                end
            end
        end
    end
    return (bestTemplate and minDistance < 3) and bestTemplate or nil
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

local function ParseBrainrot(child, config)
    local overhead = FindOverhead(child)
    local infos = ParseOverhead(overhead)
    local mutation = child:GetAttribute("Mutation") or "Default"
    local traits = ParseTraits(child)
    local income, incomeString = ParseIncome(infos, config, mutation, traits)
    local prompt = FindPrompt(child)

    return {
        Overhead = overhead,
        Model = child,
        Name = child.Name,
        IncomeStr = incomeString,
        Income = income,
        Rarity = config.Rarity or "Common",
        Mutation = mutation,
        Traits = traits, -- Virgule ajoutée ici
        Prompt = prompt
    }
end

local function GeneratePropertyID(data)
    local traitsKey = ""
    if type(data.Traits) == "table" then
        traitsKey = table.concat(data.Traits, "")
    else
        traitsKey = tostring(data.Traits or "")
    end

    local rawString = data.Name .. data.IncomeStr .. data.Mutation .. traitsKey
    
    local hash = 0
    for i = 1, #rawString do
        hash = (hash * 31 + string.byte(rawString, i)) % 2^31
    end
    return string.format("%x", hash):upper()
end

local function OnBrainrotSpawn(brainrot) 
    local Id = GeneratePropertyID(brainrot)
    Brainrots[Id] = brainrot
    
    if brainrot.Model then
        brainrot.Model.AncestryChanged:Connect(function(_, parent)
            if not parent then
                Brainrots[Id] = nil
                SendToServer("OnBrainrotDespawn", { Id = Id })
            end
        end)
    end

    if brainrot.Prompt then
        brainrot.Prompt.MaxActivationDistance = 30
        brainrot.Prompt.Triggered:Connect(function(player)
            print("💰 Animal acheté par : " .. Players.LocalPlayer.DisplayName)
            SendToServer("OnAnimalPurchased", {
                Id = Id,
                Buyer = Players.LocalPlayer.DisplayName
            })
        end)

        brainrot.Prompt.PromptShown:Connect(function(inputType)
            -- Note: Assurez-vous que fireproximityprompt est défini dans votre exécuteur
            if fireproximityprompt then
                fireproximityprompt(brainrot.Prompt)
            end
        end)
    end

    SendToServer("OnBrainrotSpawn", {
        Id = Id, -- Virgule ajoutée ici
        Name = brainrot.Name,
        IncomeStr = brainrot.IncomeStr,
        Income = brainrot.Income,
        Rarity = brainrot.Rarity,
        Mutation = brainrot.Mutation,
        Traits = brainrot.Traits,
        JobId = game.JobId
    })
end

local function OnServerMessage(rawMsg)
    local success, data = pcall(function() return HttpService:JSONDecode(rawMsg) end)
end

local function OnServerConnect()
    RenderedAnimals.ChildAdded:Connect(function(animal)
        task.wait(0.1) -- Petit délai pour laisser les attributs charger
        local config = AnimalsData[animal.Name]
        if config then
            local brainrot = ParseBrainrot(animal, config)
            OnBrainrotSpawn(brainrot)
        end
    end)
end

function connectWS(url)
    local success, result = pcall(function()
        -- Support pour les différents exécuteurs (WebSocket.connect ou WebSocket.new)
        return (WebSocket and WebSocket.connect) and WebSocket.connect(url) or WebSocket.new(url)
    end)
    if success then
        server = result
        OnServerConnect()
        local messageEvent = server.OnMessage or server.Message
        messageEvent:Connect(OnServerMessage)
        
        -- Gestion de la fermeture
        local closeEvent = server.OnClose or server.Close
        if closeEvent then
            closeEvent:Connect(function()
                task.wait(reconnectDelay)
                connectWS(url)
            end)
        end
    else
        task.wait(reconnectDelay)
        connectWS(url)
    end
end

-- [LANCEUR]
local serverURL = "wss://m4gix-ws.onrender.com/?user=" .. HttpService:UrlEncode(Players.LocalPlayer.Name)
task.spawn(function() connectWS(serverURL) end)
