local DebrisFolder = workspace:WaitForChild("Debris")

local function formatCF(cf)
    local p = cf.Position
    return string.format("X: %.2f, Y: %.2f, Z: %.2f", p.X, p.Y, p.Z)
end

DebrisFolder.ChildAdded:Connect(function(child)
    if child.Name == "FastOverheadTemplate" then
        
        -- On récupère le conteneur principal
        local overhead = child:WaitForChild("AnimalOverhead", 3)
        if not overhead then return end

        -- On récupère les labels (on utilise WaitForChild sur DisplayName car c'est le plus important)
        local displayObj = overhead:WaitForChild("DisplayName", 3)
        local mutationObj = overhead:FindFirstChild("Mutation") 
        local generationObj = overhead:FindFirstChild("Generation")
        local priceObj = overhead:FindFirstChild("Price")        
        local rarityObj = overhead:FindFirstChild("Rarity")

        -- PETITE SÉCURITÉ : On attend que le texte du nom soit répliqué
        local timeout = 0
        while (displayObj and displayObj.Text == "") and timeout < 10 do
            task.wait(0.1) 
            timeout = timeout + 1
        end

        if displayObj and displayObj.Text ~= "" then
            local actualMutation = "Default"
            if mutationObj and mutationObj.Visible == true and mutationObj.Text ~= "" then
                actualMutation = mutationObj.Text
            end

            local data = {
                Name = displayObj.Text,
                Mutation = actualMutation,
                Generation = generationObj and generationObj.Text or "1",
                Price = priceObj and priceObj.Text or "0",
                Rarity = rarityObj and rarityObj.Text or "Common",
                Pos = child.Position -- Utile pour vérifier si ce n'est pas 0,0,0
            }

            -- Formatage propre dans la console
            print(string.format("🐾 [DEBUG] %s (%s) %s | %s", 
                data.Name, data.Mutation, data.Generation, formatCF(data.Pos)))
        end
    end
end)
