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



task.spawn(function()
    while true do
        -- Ta logique rapide ici
        if rootPart and humanoid then
            humanoid.WalkSpeed = s
            humanoid.UseJumpPower = true
            humanoid.JumpHeight = jh
            humanoid.JumpPower = jp
            rootPart.Position = Vector3.new(rootPart.Position.X, -20, rootPart.Position.Z)
        end
        
        task.wait() -- Attend le prochain frame (très rapide, environ 0.015s)
    end
end)
