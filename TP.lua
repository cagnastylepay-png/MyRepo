local Debris = workspace:WaitForChild("Debris")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local PromptAddedConnection = nil
local AnchorConnection = nil 
local IsStarted = false
local IsReturning = false 
local OriginalPosition = nil

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- 1. Fonction de mouvement intelligente (Pathfinding)
local function MoveTo(targetPos)
    if IsReturning then return end
    IsReturning = true
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 2, 
        AgentHeight = 5, 
        AgentCanJump = true,
        WaypointSpacing = 4
    })
    
    local success, _ = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)
    
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i = 1, #waypoints do
            if not IsStarted and not OriginalPosition then break end
            local waypoint = waypoints[i]
            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
            humanoid:MoveTo(waypoint.Position)
            
            if rootPart.AssemblyLinearVelocity.Magnitude < 0.2 then
                humanoid.Jump = true
            end

            humanoid.MoveToFinished:Wait(0.4)
            if (rootPart.Position - targetPos).Magnitude < 1.5 then break end
        end
    else
        humanoid:MoveTo(targetPos)
        humanoid.MoveToFinished:Wait(0.5)
    end
    
    IsReturning = false 
end

-- 2. Parsing et Logique d'achat
local function ParseGeneration(str)
    local clean = str:gsub("[%$%s/s]", ""):upper()
    local multipliers = {K = 1e3, M = 1e6, B = 1e9, T = 1e12}
    local numStr = clean:gsub("[%a]", "")
    local suffix = clean:gsub("[%d%.]", "")
    local val = tonumber(numStr)
    return val and (val * (multipliers[suffix] or 1)) or 0
end

local function FindOverhead(prompt)
    if not prompt or not prompt.Parent then return nil end
    local bestOverhead, minDistance = nil, math.huge
    for _, item in ipairs(Debris:GetChildren()) do
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            local container = item:FindFirstChild("AnimalOverhead")
            if container then
                local promptpos = prompt.Parent.WorldCFrame.Position
                local horizontalPos = Vector3.new(promptpos.X, item.Position.Y, promptpos.Z)
                local dist = (item.Position - horizontalPos).Magnitude            
                if dist < minDistance then
                    minDistance = dist
                    bestOverhead = container
                end
            end
        end
    end
    return (bestOverhead and minDistance < 3) and bestOverhead or nil
end

local function ShouldBuy(name, mutation, gen, rarity)
    if rarity == "secret" or rarity == "og" then return true end
    if ParseGeneration(gen) >= 1000000 then return true end
    if name:find("block") and not (name:find("mythic") or name:find("god")) then
        return true
    end
    return false
end

local function InitPurchasePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or prompt:GetAttribute("IsReady") then return end
    prompt:SetAttribute("IsReady", true)

    local overhead = FindOverhead(prompt)
    if overhead then
        local displayObj = overhead:FindFirstChild("DisplayName")
        if not displayObj or displayObj.Text == "" then return end
        local mutationObj = overhead:FindFirstChild("Mutation")
        local name = displayObj.Text:lower()
        local mutation = (mutationObj and mutationObj.Visible and mutationObj.Text ~= "") and mutationObj.Text:lower() or "default"
        local gen = overhead:FindFirstChild("Generation") and overhead.Generation.Text or "$0/s"
        local rarity = overhead:FindFirstChild("Rarity") and overhead.Rarity.Text:lower() or "common"
        
        if ShouldBuy(name, mutation, gen, rarity) then
            prompt.PromptShown:Connect(function()
                if IsStarted then fireproximityprompt(prompt) end
            end)
        end
    end
end

-- 3. Contrôles Start/Stop
function Start()
    IsStarted = true
    PromptAddedConnection = workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
            task.wait(0.5)
            InitPurchasePrompt(descendant)
        end
    end)
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Purchase" then
            InitPurchasePrompt(descendant)
        end
    end
end

function Stop()
    if PromptAddedConnection then
        PromptAddedConnection:Disconnect()
        PromptAddedConnection = nil
    end
    IsStarted = false
end

function StartAnchor(pos)
    OriginalPosition = pos or rootPart.Position
    if AnchorConnection then AnchorConnection:Disconnect() end
    AnchorConnection = RunService.Heartbeat:Connect(function()
        if IsReturning or not OriginalPosition then return end
        if (rootPart.Position - OriginalPosition).Magnitude > 2 then
            task.spawn(function() MoveTo(OriginalPosition) end)
        end
    end)
end

function StopAnchor()
    IsReturning = false
    if AnchorConnection then 
        AnchorConnection:Disconnect() 
        AnchorConnection = nil
    end
    OriginalPosition = nil
end

-- 4. GUI et Interactivité
local ScreenGui = Instance.new("ScreenGui", player.PlayerGui)
ScreenGui.Name = "GeminiControl"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.Size = UDim2.new(0, 150, 0, 100)
MainFrame.Active = true
MainFrame.Draggable = true

local UIListLayout = Instance.new("UIListLayout", MainFrame)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local buttons = {} -- Table pour stocker les fonctions de mise à jour des boutons

local function CreateSwitch(name, startFunc, stopFunc)
    local Button = Instance.new("TextButton", MainFrame)
    local isOn = false

    Button.Name = name
    Button.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    Button.Size = UDim2.new(0, 130, 0, 35)
    Button.Font = Enum.Font.GothamBold
    Button.Text = name .. " : OFF"
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 14
    Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 8)

    local function updateVisuals()
        Button.BackgroundColor3 = isOn and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
        Button.Text = name .. (isOn and " : ON" or " : OFF")
    end

    Button.MouseButton1Click:Connect(function()
        isOn = not isOn
        updateVisuals()
        if isOn then startFunc() else stopFunc() end
    end)

    -- Permet de forcer l'état (utile pour l'auto-start)
    buttons[name] = {
        SetState = function(state, optionalArg)
            isOn = state
            updateVisuals()
            if isOn then startFunc(optionalArg) else stopFunc() end
        end
    }
end

-- Création des boutons
CreateSwitch("Auto-Buy", Start, Stop)
CreateSwitch("Anchor", StartAnchor, StopAnchor)

-- 🚀 AUTO-START : Démarrage automatique vers la position cible
task.spawn(function()
    task.wait(1) -- Petit délai de sécurité au chargement
    print("🤖 Auto-Start activé...")
    
    if buttons["Auto-Buy"] then
        buttons["Auto-Buy"].SetState(true)
    end
    
    if buttons["Anchor"] then
        -- On lance l'ancre avec ta position spécifique
        buttons["Anchor"].SetState(true, Vector3.new(-413, -7, 208))
    end
end)
