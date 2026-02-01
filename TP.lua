local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Plots = workspace:WaitForChild("Plots")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local s = humanoid.WalkSpeed*1.5
local jh = humanoid.JumpHeight*1.5
local jp =  humanoid.JumpPower*1.5

local savedPosition = nil

local function Notify(title, text)
    StarterGui:SetCore("SendNotification", {
        Title = title;
        Text = text;
        Duration = 3; -- Durée de 3 secondes
    })
end

-- Détection de l'appui sur la touche P
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.P then
        savedPosition = rootPart.Position
        Notify("Position Sauvegardée", "Ta base a été définie ici !")
    end
end)

local function MoveTo(targetPos)
    local path = PathfindingService:CreatePath({AgentRadius = 8, AgentHeight = 8, AgentCanJump = true})
	local success, _ = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)
	if success and path.Status == Enum.PathStatus.Success then
	    for _, waypoint in ipairs(path:GetWaypoints()) do
            humanoid.WalkSpeed = s
            humanoid.UseJumpPower = true
            humanoid.JumpHeight = jh
            humanoid.JumpPower = jp

	        if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
	        humanoid:MoveTo(waypoint.Position)
	        humanoid.MoveToFinished:Wait() 
	    end
	else
	    humanoid:MoveTo(targetPos)
	end
end

local function Init()
    savedPosition = rootPart.Position

    -- Optionnel : Activer automatiquement les prompts "Steal" à proximité
    ProximityPromptService.PromptShown:Connect(function(prompt)
        if prompt.ActionText == "Steal" then
            -- fireproximityprompt(prompt) -- Décommenter pour automatiser le vol
        end
    end)

    ProximityPromptService.PromptTriggered:Connect(function(prompt)
        if prompt.ActionText == "Steal" then
            MoveTo(savedPosition)
        end
    end)
end

Init()
