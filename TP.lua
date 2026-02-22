local Debris = workspace:WaitForChild("Debris")

local function FindOverhead(prompt)
    local bestOverhead = nil
    local minDistance = math.huge
    for _, item in ipairs(Debris:GetChildren()) do
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            local container = item:WaitForChild("AnimalOverhead")
            local displayNameLabel = container and container:WaitForChild("DisplayName")
            local promptpos = prompt.Parent.WorldCFrame.Position
            local horizontalPos = Vector3.new(promptpos.X, item.Position.Y, promptpos.Z)
            local dist = (item.Position - horizontalPos).Magnitude            
            print(string.format("🔍 [Scan]: %s trouvé à %.2f studs", displayNameLabel.Text, dist))
            
            if dist < minDistance then
               minDistance = dist
               bestOverhead = container
            end
        end
    end
    if bestOverhead then
        if minDistance < 3 then
            print(string.format("✅ [Succès]: Overhead lié (Distance: %.2f studs)", minDistance))
        else
            print(string.format("❌ [Refusé]: Trop loin (%.2f studs). Seuil requis: < 3", minDistance))
        end
    else
        print("❌ [Echec]: Aucun Overhead 'FastOverheadTemplate' trouvé à proximité.")
    end
    return (bestOverhead and minDistance < 3) and bestOverhead or nil
end

local function InitPurchasePrompt(prompt)
    print("🆕 [Prompt]: Init d'un prompt d'achat")
    
    local overhead = FindOverhead(prompt)
    
    prompt.MaxActivationDistance = 30
    prompt:GetPropertyChangedSignal("MaxActivationDistance"):Connect(function()
        if prompt.MaxActivationDistance ~= 30 then
            prompt.MaxActivationDistance = 30
        end
    end)

    if overhead then
        print("✨ [Link]: Connecté à l'overhead.")
        -- Ici tu peux ajouter ta logique : ParseOverhead(overhead) etc.
    end
end

-- 3. Les connexions et boucles à la fin
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
        task.wait(0.2)
        InitPurchasePrompt(descendant)
    end
end)

-- Boucle de départ (on utilise task.spawn pour ne pas bloquer le script)
for _, descendant in ipairs(workspace:GetDescendants()) do
    if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
        task.spawn(function()
            InitPurchasePrompt(descendant)
        end)
    end
end
