local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverURL = "wss://m4gix-ws.onrender.com/?user=" .. HttpService:UrlEncode(Players.LocalPlayer.Name)
local server = nil
local reconnectDelay = 5

local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

--- Functions Utils ---
local function SendToServer(method, data)
    if server then
        server:Send(HttpService:JSONEncode({Method = method, Data = data}))
    else
        warn("⚠️ Impossible d'envoyer : Serveur non connecté.")
    end
end

local function GetPlayerBase(player, timeout)
    local startTime = tick()
    local duration = timeout or 15
    local searchName = string.lower(player.DisplayName)
    
    print("🔍 [DEBUG] Recherche du Plot pour : " .. player.DisplayName)
    
    while tick() - startTime < duration do
        for _, p in ipairs(Plots:GetChildren()) do
            local plotSign = p:FindFirstChild("PlotSign")
            local surfaceGui = plotSign and plotSign:FindFirstChild("SurfaceGui")
            local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
            local textLabel = frame and frame:FindFirstChild("TextLabel")

            if textLabel and textLabel.Text ~= "" then
                -- print("👀 [DEBUG] Plot trouvé appartenant à : " .. textLabel.Text) -- Optionnel si trop de spam
                if string.find(string.lower(textLabel.Text), searchName) then
                    print("✅ [DEBUG] Plot identifié pour " .. player.Name)
                    return p
                end
            end
        end
        task.wait(1)
    end
    
    warn("❌ [DEBUG] Timeout : Aucun Plot trouvé pour " .. player.Name .. " après " .. duration .. "s")
    return nil
end

local function GetPlayerBrainrots(player)
    local brainrots = {}
    local plot = GetPlayerBase(player)
    
    if not plot then 
        warn("🚫 [DEBUG] Annulation GetPlayerBrainrots : Plot est nil.")
        return brainrots 
    end

    local children = plot:GetChildren()
    print("📦 [DEBUG] Objets trouvés dans le plot : " .. #children)

    for _, child in ipairs(children) do
        local config = AnimalsData[child.Name]
        if config then
            -- print("🐾 [DEBUG] Animal détecté : " .. child.Name)
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
            pcall(function()
                -- On utilise pcall au cas où CalculGeneration ferait une erreur
                incomeGen = CalculGeneration(config.Generation, currentMutation, currentTraits)
            end)

            table.insert(brainrots, {
                Name = config.DisplayName or child.Name,
                Rarity = config.Rarity or "Common",
                Generation = incomeGen,
                GenString = (FormatMoney and FormatMoney(incomeGen)) or tostring(incomeGen),
                Mutation = currentMutation,
                Traits = currentTraits
            })
        end
    end
    
    print("📊 [DEBUG] Total Brainrots pour " .. player.Name .. " : " .. #brainrots)
    return brainrots
end

local function GetPlayerInfos(player)
    if not player then return nil end
    print("👤 [DEBUG] Récupération infos pour : " .. player.Name)
    
    local stats = player:WaitForChild("leaderstats", 5)
    if not stats then 
        warn("❌ [DEBUG] Leaderstats non trouvés pour " .. player.Name)
        return nil 
    end

    return {
        DisplayName = player.DisplayName,
        Name = player.Name,
        Cash = (stats:FindFirstChild("Cash") and stats.Cash.Value) or 0,
        Rebirths = (stats:FindFirstChild("Rebirths") and stats.Rebirths.Value) or 0,
        Steals = (stats:FindFirstChild("Steals") and stats.Steals.Value) or 0,
        Brainrots = GetPlayerBrainrots(player)
    }
end

-- ... (Le reste de tes fonctions connectWS, ServerInfos, etc. restent identiques)

Players.PlayerAdded:Connect(function(player)
    print("📥 [EVENT] PlayerAdded: " .. player.Name)
    task.wait(5) -- On laisse au jeu le temps de charger le Plot
    task.spawn(function()
        local info = GetPlayerInfos(player)
        if info then
            print("🚀 [DEBUG] Envoi PlayerAdded vers le serveur...")
            SendToServer("PlayerAdded", info)
        end
    end)
end)

-- N'oublie pas d'appeler ta fonction de démarrage
connectWS()
