local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:WaitForChild("Debris")

-- Chargement des modules de données
local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits"))
local MutationsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Mutations"))

local reconnectDelay = 10
local ws = nil


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

-- Scan du terrain
local function sendPlotInfos()
    for _, plot in ipairs(Plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign and sign:FindFirstChild("YourBase") and sign.YourBase.Enabled then
            local brainrots = {}
            -- On itère sur les enfants du plot (les animaux posés)
            for _, child in ipairs(plot:GetChildren()) do
                local config = AnimalsData[child.Name]
                if config then
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

                    local incomeGen = CalculGeneration(config.Generation, currentMutation, currentTraits)
                    local finalGenString = FormatMoney(incomeGen)

                    table.insert(brainrots, {
                        owner = Players.LocalPlayer.Name,
                        name = config.DisplayName or child.Name,
                        genText = finalGenString,
                        genValue = incomeGen,
                        rarity = config.Rarity or "Common",
                        mutation = currentMutation,
                        traits = currentTraits
                    })
                end
            end
            
            if ws then
                local payload = HttpService:JSONEncode({ type = "plot_update", animals = brainrots })
                pcall(function() ws:Send(payload) end)
            end

        end
    end
end

local function c()
    local socketURL = string.format("wss://m4gix-ws.onrender.com/?user=%s&type=Client", Players.LocalPlayer.Name)

    local success, result = pcall(function()
        return (WebSocket and WebSocket.connect) and WebSocket.connect(socketURL) or WebSocket.new(socketURL)
    end)

    if success then
        ws = result
        
        sendPlotInfos()

        local messageEvent = ws.OnMessage or ws.Message
        messageEvent:Connect(function(rawMsg)
        end)

        ws.OnClose:Connect(function()
            task.wait(reconnectDelay)
            c()
        end)

    else
        task.wait(reconnectDelay)
        c()
    end
end

task.spawn(function()
    -- Petite sécurité : on attend que le jeu soit bien prêt avant de tenter la connexion
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    c()
end)
