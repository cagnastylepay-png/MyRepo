local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- CONFIGURATION
local serverURL = "wss://m4gix-ws.onrender.com/?username=" .. HttpService:UrlEncode(Players.LocalPlayer.Name)
local reconnectDelay = 5
local server = nil

-- Fonction de log stylisée pour la console Roblox
local function log(msg, color)
    print("🌐 [M4GIX-TEST] " .. tostring(msg))
end

function connectWS(url)
    log("Tentative de connexion à : " .. url)

    -- Détection automatique de la librairie WebSocket selon l'exécuteur
    local ws_lib = (syn and syn.websocket) or WebSocket or (http and http.websocket)
    
    if not ws_lib then
        warn("❌ TON EXÉCUTEUR NE SUPPORTE PAS LES WEBSOCKETS.")
        return
    end

    local success, result = pcall(function()
        return ws_lib.connect(url)
    end)

    if success then
        server = result
        log("✅ CONNECTÉ AU SERVEUR !", Color3.fromRGB(0, 255, 0))

        -- Gestion des messages entrants (Ordres de trade)
        local messageEvent = server.OnMessage or server.Message
        if messageEvent then
            messageEvent:Connect(function(msg)
                log("📩 Message reçu du serveur : " .. msg)
                
                -- Petit test de réponse au serveur
                local data = {Type = "Status", Message = "Bot is alive!"}
                server:Send(HttpService:JSONEncode(data))
            end)
        end

        -- Gestion de la déconnexion
        server.OnClose:Connect(function()
            warn("🔌 Connexion perdue. Reconnexion dans " .. reconnectDelay .. "s...")
            task.wait(reconnectDelay)
            connectWS(url)
        end)
    else
        warn("⚠️ Erreur de connexion : " .. tostring(result))
        log("Nouvelle tentative dans " .. reconnectDelay .. "s...")
        task.wait(reconnectDelay)
        connectWS(url)
    end
end

-- Lancement
task.spawn(function()
    connectWS(serverURL)
end)

-- Boucle de Ping optionnelle (Maintien de vie côté Roblox)
task.spawn(function()
    while task.wait(30) do
        if server then
            pcall(function()
                server:Send(HttpService:JSONEncode({Type = "Ping", User = Players.LocalPlayer.Name}))
                log("📡 Ping envoyé au serveur.")
            end)
        end
    end
end)
