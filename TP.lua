local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")

-- CONFIGURATION
local socketURL = "wss://m4gix-ws.onrender.com/?token=M4GIX_SECURE_2026"
local myName = Players.LocalPlayer.Name
local reconnectDelay = 5
local ws = nil

-- Récupère la liste des noms des joueurs sur le serveur
local function GetPlayersName()
    local displayNames = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(displayNames, player.DisplayName)
    end
    return displayNames
end

-- Trouve le terrain appartenant à un joueur
local function FindPlotByPlayerName(playerName)
    for _, plot in ipairs(Plots:GetChildren()) do
        local plotSign = plot:FindFirstChild("PlotSign")
        local surfaceGui = plotSign and plotSign:FindFirstChild("SurfaceGui")
        local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
        local textLabel = frame and frame:FindFirstChild("TextLabel")

        if textLabel then
            if string.find(string.lower(textLabel.Text), string.lower(playerName)) then
                return plot
            end
        end
    end
    return nil
end

-- Liste les entités sur le plot d'un joueur précis
local function ListBrainrotsByPlayerName(playerName)
    local plot = FindPlotByPlayerName(playerName)
    if not plot then return { Error = "Plot non trouvé" } end

    local plotData = { Owner = playerName, Brainrots = {} }
    
    for _, child in ipairs(plot:GetChildren()) do
        -- On identifie un Brainrot par la présence d'un Controller d'animation
        if child:IsA("Model") and (child:FindFirstChild("AnimationController") or child:FindFirstChild("Humanoid")) then
            
            local brainrotInfo = {
                Name = child.Name,
                Mutation = child:GetAttribute("Mutation") or "Default",
                Traits = {}
            }

            -- Extraction des traits (format string "Trait1, Trait2" ou table)
            local traitsRaw = child:GetAttribute("Traits")
            if traitsRaw then
                if type(traitsRaw) == "string" then
                    for trait in string.gmatch(traitsRaw, '([^,]+)') do
                        table.insert(brainrotInfo.Traits, trait:match("^%s*(.-)%s*$"))
                    end
                elseif type(traitsRaw) == "table" then
                    brainrotInfo.Traits = traitsRaw
                end
            end

            table.insert(plotData.Brainrots, brainrotInfo)
        end
    end
    return plotData
end

function Identify()
    if ws then
        ws:Send(HttpService:JSONEncode({
            Method = "Identify",
            From = myName,
            To = "Server",
            Data = ""
        }))
    end
end

function connectWS()
    local success, result = pcall(function()
        return (WebSocket and WebSocket.connect) and WebSocket.connect(socketURL) or WebSocket.new(socketURL)
    end)

    if success then
        ws = result
        Identify()

        local messageEvent = ws.OnMessage or ws.Message
        messageEvent:Connect(function(rawMsg)
            local ok, msg = pcall(function() return HttpService:JSONDecode(rawMsg) end)
            if not ok then return end

            -- COMMANDE : Liste des joueurs
            if msg.Method == "GetPlayers" then
                ws:Send(HttpService:JSONEncode({
                    Method = "Result",
                    From = myName,
                    To = msg.From,
                    RequestId = msg.RequestId,
                    Data = GetPlayersName()
                }))

            -- COMMANDE : Scan d'un Plot (Data doit contenir le nom du joueur)
            elseif msg.Method == "ListBrainrots" then
                local target = msg.Data or myName
                ws:Send(HttpService:JSONEncode({
                    Method = "Result",
                    From = myName,
                    To = msg.From,
                    RequestId = msg.RequestId,
                    Data = ListBrainrotsByPlayerName(target)
                }))
            end
        end)

        ws.OnClose:Connect(function()
            task.wait(reconnectDelay)
            connectWS()
        end)
    else
        task.wait(reconnectDelay)
        connectWS()
    end
end

task.spawn(connectWS)
