local BrainrotsSpawned = workspace:WaitForChild("RenderedMovingAnimals")
local DebrisFolder = workspace:WaitForChild("Debris")

-- Fonction utilitaire pour formater le CFrame proprement
local function formatCF(cf)
    local p = cf.Position
    return string.format("X: %.2f, Y: %.2f, Z: %.2f", p.X, p.Y, p.Z)
end

-- 1. Gestion des Overheads dans Debris
DebrisFolder.ChildAdded:Connect(function(child)
    if child.Name == "FastOverheadTemplate" then
        -- On cherche le DisplayName à l'intérieur de l'AnimalOverhead (vu dans tes captures)
        local overhead = child:WaitForChild("AnimalOverhead", 2)
        local displayName = overhead and overhead:WaitForChild("DisplayName", 2)
        
        local timeSpan = tick() -- Timestamp précis
        local text = displayName and displayName.Text or "Inconnu"
        local cf = child.CFrame -- On utilise la propriété CFrame de la Part
        
        print(string.format("[DEBRIS] Time: %.3f | Text: %s | CF: %s", timeSpan, text, formatCF(cf)))
    end
end)

-- 2. Gestion des Modèles dans RenderedMovingAnimals
BrainrotsSpawned.ChildAdded:Connect(function(child)
    -- On cherche le RootPart spécifique montré dans tes images
    local root = child:WaitForChild("RootPart", 2)
    
    if root then
        local timeSpan = tick()
        local animalName = child.Name -- Le nom du modèle (ex: Boneca Ambalabu)
        local cf = root.CFrame -- On utilise le CFrame du RootPart
        
        print(string.format("[ANIMAL] Time: %.3f | Model: %s | CF: %s", timeSpan, animalName, formatCF(cf)))
    else
        -- Si RootPart n'est pas encore là, on utilise le Pivot du modèle par sécurité
        local timeSpan = tick()
        print(string.format("[ANIMAL] Time: %.3f | Model: %s | CF: %s (Pivot)", timeSpan, child.Name, formatCF(child:GetPivot())))
    end
end)
