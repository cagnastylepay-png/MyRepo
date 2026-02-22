local Debris = workspace:WaitForChild("Debris")

local function FindOverhead(prompt)
    if not prompt or not prompt.Parent then return nil end
    
    local bestOverhead = nil
    local minDistance = math.huge
    local promptPart = prompt.Parent
    
    -- Sécurité pour récupérer la position
    local success, promptPos = pcall(function() return promptPart.Position end)
    if not success then return nil end

    print(string.format("--- 🛰️ Scan autour du prompt: %s ---", promptPart.Name))

    for _, item in ipairs(Debris:GetChildren()) do
        -- On vérifie si c'est un overhead potentiel
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            local container = item:FindFirstChild("AnimalOverhead")
            if container then
                local displayNameLabel = container:FindFirstChild("DisplayName")
                local animalName = displayNameLabel and displayNameLabel.Text or "Inconnu"
                
                -- Calcul de la distance (X et Z uniquement pour la précision horizontale)
                local itemPos = item.Position
                local dist = (Vector2.new(itemPos.X, itemPos.Z) - Vector2.new(promptPos.X, promptPos.Z)).Magnitude
                
                -- DEBUG PRINT: Affiche chaque overhead trouvé dans Debris
                print(string.format("   📍 [Candidat]: %s | Distance: %.2f studs", animalName, dist))
                
                if dist < minDistance then
                    minDistance = dist
                    bestOverhead = container
                end
            end
        end
    end

    -- Seuil de validation (Actuellement à 3)
    local SEUIL = 3 

    if bestOverhead then
        if minDistance <= SEUIL then
            print(string.format("✅ [LIAISON]: Plus proche trouvé -> Distance: %.2f (Inférieur à %d)", minDistance, SEUIL))
            return bestOverhead
        else
            print(string.format("⚠️ [DISTANCE]: Plus proche à %.2f studs, mais c'est TROP LOIN (Seuil: %d)", minDistance, SEUIL))
        end
    else
        print("❌ [VIDE]: Aucun 'FastOverheadTemplate' trouvé dans Debris.")
    end
    
    return nil
end

local function InitPurchasePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    
    -- On évite de l'initialiser plusieurs fois
    if prompt:GetAttribute("IsReady") then return end
    prompt:SetAttribute("IsReady", true)

    local overhead = FindOverhead(prompt)
    
    prompt.MaxActivationDistance = 30
    
    -- Garder la distance à 30 quoi qu'il arrive
    prompt:GetPropertyChangedSignal("MaxActivationDistance"):Connect(function()
        if prompt.MaxActivationDistance ~= 30 then
            prompt.MaxActivationDistance = 30
        end
    end)

    if overhead then
        print("✨ [OK]: Prompt lié avec succès.")
    end
end

-- Connexions
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
        task.wait(0.5) -- Un peu de délai pour laisser le temps au jeu de placer les objets
        InitPurchasePrompt(descendant)
    end
end)

for _, descendant in ipairs(workspace:GetDescendants()) do
    if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
        task.spawn(InitPurchasePrompt, descendant)
    end
end
