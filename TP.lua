local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Plots = workspace:WaitForChild("Plots")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local y = rootPart.Position.Y

local function Notify(title, text)
    StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = 3,
        Button1 = "OK"
    })
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    
    if input.KeyCode == Enum.KeyCode.P then
        y = y+1
        rootPart.Position = Vector3.new(rootPart.Position.X, y, rootPart.Position.Z)
        Notify("Position", "X:" .. math.round(rootPart.Position.X) .. ", Y:" .. math.round(rootPart.Position.Y) .. ", Z:" .. math.round(rootPart.Position.Z))
    end

    if input.KeyCode == Enum.KeyCode.M then
        y = y-1
        rootPart.Position = Vector3.new(rootPart.Position.X, y, rootPart.Position.Z)
        Notify("Position", "X:" .. math.round(rootPart.Position.X) .. ", Y:" .. math.round(rootPart.Position.Y) .. ", Z:" .. math.round(rootPart.Position.Z))
    end
end)
