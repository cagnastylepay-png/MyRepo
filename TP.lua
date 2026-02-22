local Debris = workspace:WaitForChild("Debris")

-- 1. Conversion des chaînes (ex: "$1.5M/s") en nombres réels
local function ParseGeneration(str)
    local clean = str:gsub("[%$%s/s]", ""):upper()
    local multipliers = {K = 1e3, M = 1e6, B = 1e9, T = 1e12}
    
    local numStr = clean:gsub("[%a]", "")
    local suffix = clean:gsub("[%d%.]", "")
    
    local val = tonumber(numStr)
    if not val then return 0 end
    
    return val * (multipliers[suffix] or 1)
end


-- 2. Recherche de l'overhead le plus proche
local function FindOverhead(prompt)
    if not prompt or not prompt.Parent then return nil end
    
    local bestOverhead = nil
    local minDistance = math.huge
    
    for _, item in ipairs(Debris:GetChildren()) do
        -- On vérifie si c'est un overhead potentiel
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            local container = item:FindFirstChild("AnimalOverhead")
            if container then
                local promptpos = prompt.Parent.WorldCFrame.Position
                local horizontalPos = Vector3.new(promptpos.X, item.Position.Y, promptpos.Z)
                local dist = (item.Position - horizontalPos).Magnitude            
                if dist < minDistance then
                    minDistance = dist
                    bestOverhead = container
                end
            end
        end
    end

    return (bestOverhead and minDistance < 3) and bestOverhead or nil
end

-- 3. Logique de décision d'achat
local function ShouldBuy(name, mutation, gen, rarity)
    print(string.format("%s %s %s %s", mutation, name, rarity, gen))
    -- Priorité : Raretés spéciales
    if rarity == "secret" or rarity == "og" then return true end
    
    -- Seuil de génération (1M+)
    if ParseGeneration(gen) >= 1000000 then return true end
    
    -- Filtre spécifique "block" (excluant mythic/god selon ta logique)
    if name:find("block") and not (name:find("mythic") or name:find("god")) then
        return true
    end
    
    return false
end

local function InitPurchasePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    
    -- On évite de l'initialiser plusieurs fois
    if prompt:GetAttribute("IsReady") then return end
    prompt:SetAttribute("IsReady", true)

    local overhead = FindOverhead(prompt)

    if overhead then
        local displayObj = overhead:FindFirstChild("DisplayName")
        if not displayObj or displayObj.Text == "" then return nil end
        local mutationObj = overhead:FindFirstChild("Mutation")
    
        local name = displayObj.Text:lower()
        local mutation = (mutationObj and mutationObj.Visible and mutationObj.Text ~= "") and mutationObj.Text:lower() or "default"
        local gen = overhead:FindFirstChild("Generation") and overhead.Generation.Text or "$0/s"
        local rarity = overhead:FindFirstChild("Rarity") and overhead.Rarity.Text:lower() or "common"
        
        if ShouldBuy(name, mutation, gen, rarity) then
            prompt.PromptShown:Connect(function()
                fireproximityprompt(prompt)
            end)
        end
    end
end

-- Connexions
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
        task.wait(0.5) -- Un peu de délai pour laisser le temps au jeu de placer les objets
        InitPurchasePrompt(descendant)
    end
end)
