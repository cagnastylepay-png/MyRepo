local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Plots = workspace:WaitForChild("Plots")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Mise à jour automatique si le personnage réapparaît
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid")
    rootPart = newCharacter:WaitForChild("HumanoidRootPart")
end)

local function GetPlot(targetPlayer, timeout)
    local startTime = tick()
    local duration = timeout or 15
    local searchName = string.lower(targetPlayer.DisplayName)
        
    while tick() - startTime < duration do
        for _, p in ipairs(Plots:GetChildren()) do
            local plotSign = p:FindFirstChild("PlotSign")
            local surfaceGui = plotSign and plotSign:FindFirstChild("SurfaceGui")
            local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
            local textLabel = frame and frame:FindFirstChild("TextLabel")

            if textLabel and textLabel.Text ~= "" then
                if string.find(string.lower(textLabel.Text), searchName) then
                    return p
                end
            end
        end
        task.wait(1)
    end
    return nil
end

local function MoveTo(targetPos)
    local forcedY = -20
    local finalTarget = Vector3.new(targetPos.X, forcedY, targetPos.Z)
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 3, 
        AgentHeight = 6, 
        AgentCanJump = true,
        WaypointSpacing = 4
    })

    local success, _ = pcall(function() 
        path:ComputeAsync(rootPart.Position, finalTarget) 
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        
        for _, waypoint in ipairs(waypoints) do
            -- On force chaque point du chemin à la profondeur voulue
            local adjustedWaypointPos = Vector3.new(waypoint.Position.X, forcedY, waypoint.Position.Z)
            
            humanoid:MoveTo(adjustedWaypointPos)

            local reached = false
            local startTime = tick()
            
            while not reached do
                -- Vérification de distance (X et Z surtout, car Y est sous le sol)
                if (rootPart.Position - adjustedWaypointPos).Magnitude < 4 then
                    reached = true
                end

                -- Système de forcage si bloqué par la grille
                if tick() - startTime > 1.5 then
                    humanoid.Jump = true
                    humanoid:MoveTo(adjustedWaypointPos)
                    startTime = tick()
                end
                
                task.wait(0.1)
            end
        end
    else
        -- Backup : Ligne droite forcée si le calcul de chemin échoue
        while (rootPart.Position - finalTarget).Magnitude > 4 do
            humanoid:MoveTo(finalTarget)
            if not humanoid.MoveToFinished:Wait(1) then
                humanoid.Jump = true
            end
            task.wait(0.1)
        end
    end
end

local function Init()
    local myPlot = GetPlot(player, 20)
    
    if not myPlot then
        warn("Plot introuvable pour " .. player.DisplayName)
        return
    end

    -- Optionnel : Activer automatiquement les prompts "Steal" à proximité
    ProximityPromptService.PromptShown:Connect(function(prompt)
        if prompt.ActionText == "Steal" then
            -- fireproximityprompt(prompt) -- Décommenter pour automatiser le vol
        end
    end)

    ProximityPromptService.PromptTriggered:Connect(function(prompt)
        if prompt.ActionText == "Steal" then
            local targetHitbox = myPlot:FindFirstChild("Hitbox", true)
            
            if targetHitbox then
                humanoid.WalkSpeed = 80
                MoveTo(targetHitbox.Position)
            else
                warn("Hitbox introuvable dans le plot !")
            end
        end
    end)
end

Init()
