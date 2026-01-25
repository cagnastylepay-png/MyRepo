local DebrisFolder = workspace:WaitForChild("Debris")
local Wanted = {} -- Liste des animaux à suivre

local function formatCF(p)
    return string.format("X: %.2f, Y: %.2f, Z: %.2f", p.X, p.Y, p.Z)
end

local function OnBrainrotSpawn(br)
    print(string.format("🐾 [DEBUG] %s (%s) %s", br.Name, br.Mutation, br.Generation))
    
    if br.Mutation == "Gold" then
        print("🌟 CIBLE GOLD DÉTECTÉE : " .. br.Name)
        Wanted[br.Child] = br
        
        -- NETTOYAGE : Supprime de la liste quand l'animal disparaît
        br.Child.AncestryChanged:Connect(function(_, parent)
            if not parent then
                Wanted[br.Child] = nil
                print("❌ Cible Gold disparue : " .. br.Name)
            end
        end)
    end
end

DebrisFolder.ChildAdded:Connect(function(child)
    if child.Name == "FastOverheadTemplate" then
        local overhead = child:WaitForChild("AnimalOverhead", 3)
        if not overhead then return end

        local displayObj = overhead:WaitForChild("DisplayName", 3)
        local mutationObj = overhead:FindFirstChild("Mutation") 
        local generationObj = overhead:FindFirstChild("Generation")
        local priceObj = overhead:FindFirstChild("Price")        
        local rarityObj = overhead:FindFirstChild("Rarity")

        local timeout = 0
        while (displayObj and displayObj.Text == "") and timeout < 10 do
            task.wait(0.1) 
            timeout = timeout + 1
        end

        if displayObj and displayObj.Text ~= "" then
            local actualMutation = "Default"
            -- On vérifie si le texte est "Gold" ET si l'étiquette est visible
            if mutationObj and mutationObj.Visible == true and mutationObj.Text ~= "" then
                actualMutation = mutationObj.Text
            end

            local data = {
                Name = displayObj.Text,
                Mutation = actualMutation,
                Generation = generationObj and generationObj.Text or "1",
                Price = priceObj and priceObj.Text or "0",
                Rarity = rarityObj and rarityObj.Text or "Common",
                Child = child
            }
            OnBrainrotSpawn(data)
        end
    end
end)

-- Boucle de Tracking
task.spawn(function()
    while true do
        -- On utilise 'pairs' pour itérer proprement sur notre dictionnaire d'objets
        for object, br in pairs(Wanted) do
            -- On vérifie que l'objet est toujours dans le workspace
            if object and object.Parent then
                local pos = object.Position
                -- Si la position est encore à 0, on attend la prochaine boucle
                if pos.Magnitude > 1 then
                    print(string.format("📡 [TRACKING] %s | %s", br.Name, formatCF(pos)))
                end
            else
                -- Sécurité : si l'objet n'a plus de parent, on le dégage
                Wanted[object] = nil
            end
        end
        task.wait(0.5)
    end
end)
