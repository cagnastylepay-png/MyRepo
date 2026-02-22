local Debris = workspace:WaitForChild("Debris")

local function FindOverhead(prompt)
    local bestOverhead = nil
    local minDistance = math.huge
    for _, item in ipairs(Debris:GetChildren()) do
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            local container = item:FindFirstChild("AnimalOverhead")
            local displayNameLabel = container and container:FindFirstChild("DisplayName")
            local promptpos = prompt.Parent.WorldCFrame.Position
            local horizontalPos = Vector3.new(promptpos.X, item.Position.Y, promptpos.Z)
            local dist = (item.Position - horizontalPos).Magnitude            
            pcall(function() animalName = container.DisplayName.Text end)
            Debug(string.format("🔍 [Scan]: %s trouvé à %.2f studs", animalName, dist))
            
            if dist < minDistance then
               minDistance = dist
               bestOverhead = container
            end
        end
    end
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
    local overhead = FindOverhead(prompt)
    prompt.MaxActivationDistance = 30
    prompt:GetPropertyChangedSignal("MaxActivationDistance"):Connect(function()
        if prompt.MaxActivationDistance ~= 30 then
            prompt.MaxActivationDistance = 30
        end
    end)
end

for _, descendant in ipairs(workspace:GetDescendants()) do
    if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
        InitPurchasePrompt(descendant)
    end
end

workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
        InitPurchasePrompt(descendant)
    end
end)
