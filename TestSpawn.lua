local BrainrotsSpawned = workspace:WaitForChild("RenderedMovingAnimals")
local DebrisFolder = workspace:WaitForChild("Debris")

local pendingAnimals = {}

local function getFlatPos(cf)
    return Vector3.new(cf.Position.X, 0, cf.Position.Z)
end

-- 1. Gestion des Overheads avec attente de CFrame valide
DebrisFolder.ChildAdded:Connect(function(child)
    if child.Name == "FastOverheadTemplate" then
        -- BOUCLE D'ATTENTE : On attend que le CFrame ne soit plus à 0,0,0
        local timeout = 0
        while child.Position.Magnitude == 0 and timeout < 10 do
            task.wait() -- On attend la frame suivante
            timeout = timeout + 1
        end

        local overheadPos = getFlatPos(child.CFrame)
        
        -- Recherche du match dans les animaux en attente
        for i, data in ipairs(pendingAnimals) do
            local dist = (data.Pos - overheadPos).Magnitude
            if dist < 1 then -- Seuil de tolérance
                local overhead = child:WaitForChild("AnimalOverhead", 1)
                local displayName = overhead and overhead:FindFirstChild("DisplayName")                
                print(string.format("✅ Match! Dist: %.2f | Name: %s", dist, displayName and displayName.Text or "???"))                
                table.remove(pendingAnimals, i)
                return
            end
        end
    end
end)

-- 2. Gestion des Animaux
BrainrotsSpawned.ChildAdded:Connect(function(child)
    local root = child:WaitForChild("RootPart", 5)
    if root then
        -- Même logique d'attente pour l'animal si besoin
        if root.Position.Magnitude == 0 then
            task.wait()
        end

        table.insert(pendingAnimals, {
            ModelName = child.Name,
            Pos = getFlatPos(root.CFrame),
            FullPos = root.Position
        })
    end
end)
