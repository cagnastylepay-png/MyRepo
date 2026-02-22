local Debris = workspace:WaitForChild("Debris")

local function FindOverhead(prompt)
    local bestOverhead = nil
    local minDistance = math.huge
    
    -- Sécurité : On attend un tout petit peu que l'overhead soit créé dans Debris
    task.wait(0.1)

    if not prompt or not prompt.Parent then 
        Debug("⚠️ [FindOverhead]: Prompt ou Parent invalide.")
        return nil 
    end

    -- Récupération de la position du prompt
    local success, promptPos = pcall(function() 
        return prompt.Parent.WorldPosition or prompt.Parent.Position 
    end)
    
    if not success then
        Debug("⚠️ [FindOverhead]: Impossible d'obtenir la position du prompt.")
        return nil
    end

    local itemsInDebris = Debris:GetChildren()
    -- Log pour savoir si Debris est vide
    if #itemsInDebris == 0 then
        Debug("⚠️ [FindOverhead]: Debris est vide, aucun Overhead à scanner.")
    end

    for _, item in ipairs(itemsInDebris) do
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            local container = item:FindFirstChild("AnimalOverhead")
            
            -- Calcul de la distance horizontale (ignorant la hauteur Y pour plus de précision)
            local horizontalPos = Vector3.new(promptPos.X, item.Position.Y, promptPos.Z)
            local dist = (item.Position - horizontalPos).Magnitude
            
            -- Debug individuel pour chaque overhead trouvé
            if isDebugMode then
                local animalName = "Inconnu"
                pcall(function() animalName = container.DisplayName.Text end)
                Debug(string.format("🔍 [Scan]: %s trouvé à %.2f studs", animalName, dist))
            end

            if dist < minDistance then
                minDistance = dist
                bestOverhead = container
            end
        end
    end

    -- Résultat final du scan
    if bestOverhead then
        if minDistance < 3 then
            Debug(string.format("✅ [Succès]: Overhead lié (Distance: %.2f studs)", minDistance))
        else
            Debug(string.format("❌ [Refusé]: Trop loin (%.2f studs). Seuil requis: < 3", minDistance))
        end
    else
        Debug("❌ [Echec]: Aucun Overhead 'FastOverheadTemplate' trouvé à proximité.")
    end

    return (bestOverhead and minDistance < 3) and bestOverhead or nil
end

local function InitPurchasePrompt(prompt)
    Debug("🆕 [Prompt]: Initialisation d'un nouveau prompt d'achat")
    
    -- On cherche l'overhead correspondant
    local overhead = FindOverhead(prompt)
    
    -- Verrouillage de la distance
    prompt.MaxActivationDistance = 30
    prompt:GetPropertyChangedSignal("MaxActivationDistance"):Connect(function()
        if prompt.MaxActivationDistance ~= 30 then
            prompt.MaxActivationDistance = 30
            -- Debug("🔒 [Verrou]: Distance remise à 30 studs")
        end
    end)

    -- Si on a trouvé l'overhead, on pourrait lancer la logique d'achat ici
    if overhead then
        -- C'est ici que tu peux appeler ta fonction de validation d'achat
        Debug("✨ [Link]: Overhead attaché avec succès au prompt.")
    end
end

-- Scan initial
for _, descendant in ipairs(workspace:GetDescendants()) do
    if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
        task.spawn(InitPurchasePrompt, descendant)
    end
end

-- Scan en temps réel
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
        task.wait(0.2) -- On laisse le temps au modèle de se charger
        InitPurchasePrompt(descendant)
    end
end)
