local function InitPurchasePrompt(prompt)
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
