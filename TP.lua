local Players = game:GetService("Players")
local Debris = workspace:WaitForChild("Debris")
local PathfindingService = game:GetService("PathfindingService")
local RenderedAnimals = workspace:WaitForChild("RenderedMovingAnimals")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- --- CONFIGURATION ---
local Config = {
    AutoBuyEnabled = true,
    MinGenText = "12M",
    MinGenValue = 12000000,
    ActiveMutation = "Default",
    Matrix = {},
    Visible = true,
    PlayerRole = 1 -- 1 pour Joueur 1, 2 pour Joueur 2
}

local FILE_NAME = "CRD_AutoBuy_V2.json"
local isBusy = false

-- --- POSITIONS PING-PONG ---
local P1_Home = Vector3.new(-411, -7, 223)
local P2_Home = Vector3.new(-461, -7, -85)

local function GetHomePos()
    return (Config.PlayerRole == 1) and P1_Home or P2_Home
end

local function Save()
    if writefile then writefile(FILE_NAME, HttpService:JSONEncode(Config)) end
end

local function Load()
    if isfile and isfile(FILE_NAME) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(FILE_NAME)) end)
        if success then Config = data end
    end
end

-- --- PARSING INCOME ---
local function UpdateMinGen(text)
    Config.MinGenText = text:upper()
    local clean = text:gsub("[%$%s/s]", ""):upper()
    local multiplier = 1
    if clean:find("K") then multiplier = 10^3 clean = clean:gsub("K", "")
    elseif clean:find("M") then multiplier = 10^6 clean = clean:gsub("M", "")
    elseif clean:find("B") then multiplier = 10^9 clean = clean:gsub("B", "")
    elseif clean:find("T") then multiplier = 10^12 clean = clean:gsub("T", "") end
    Config.MinGenValue = (tonumber(clean) or 0) * multiplier
    Save()
end

-- --- INTERFACE ---
local ScreenGui = Instance.new("ScreenGui", Players.LocalPlayer.PlayerGui)
ScreenGui.Name = "CRD_AutoBuy_V2"
ScreenGui.ResetOnSpawn = false

local MiniIcon = Instance.new("TextButton", ScreenGui)
MiniIcon.Size = UDim2.new(0, 50, 0, 50)
MiniIcon.Position = UDim2.new(0, 20, 0.5, -25)
MiniIcon.BackgroundColor3 = Color3.new(0,0,0)
MiniIcon.Text = "CRD"
MiniIcon.TextColor3 = Color3.new(1,1,1)
MiniIcon.Font = Enum.Font.SourceSansBold
MiniIcon.TextSize = 20
MiniIcon.Visible = false
Instance.new("UICorner", MiniIcon).CornerRadius = UDim.new(1, 0)

local MainContainer = Instance.new("Frame", ScreenGui)
MainContainer.Size = UDim2.new(0, 800, 0, 480)
MainContainer.Position = UDim2.new(0.5, -400, 0.5, -240)
MainContainer.BackgroundTransparency = 1

local Bg = Instance.new("Frame", MainContainer)
Bg.Size = UDim2.new(1, -80, 1, -40)
Bg.Position = UDim2.new(0, 40, 0, 20)
Bg.BackgroundColor3 = Color3.fromHex("#2E2E2E")
Instance.new("UICorner", Bg).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", Bg)
Title.Text = "CRD Auto Buy"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 20
Title.Position = UDim2.new(0, 15, 0, 15)
Title.Size = UDim2.new(0, 120, 0, 30)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1

local RoleBtn = Instance.new("TextButton", Bg)
RoleBtn.Size = UDim2.new(0, 100, 0, 30)
RoleBtn.Position = UDim2.new(1, -245, 0, 15)
RoleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
RoleBtn.Text = "ROLE: PLAYER " .. Config.PlayerRole
RoleBtn.TextColor3 = Color3.new(1, 1, 1)
RoleBtn.Font = Enum.Font.SourceSansBold
RoleBtn.TextSize = 14
Instance.new("UICorner", RoleBtn).CornerRadius = UDim.new(0, 6)

RoleBtn.MouseButton1Click:Connect(function()
    Config.PlayerRole = (Config.PlayerRole == 1) and 2 or 1
    RoleBtn.Text = "ROLE: PLAYER " .. Config.PlayerRole
    Save()
end)

local StatusBtn = Instance.new("TextButton", Bg)
StatusBtn.Size = UDim2.new(0, 80, 0, 30)
StatusBtn.Position = UDim2.new(1, -135, 0, 15)
StatusBtn.BackgroundColor3 = Config.AutoBuyEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
StatusBtn.Text = Config.AutoBuyEnabled and "ON" or "OFF"
StatusBtn.TextColor3 = Color3.new(1, 1, 1)
StatusBtn.Font = Enum.Font.SourceSansBold
StatusBtn.TextSize = 16
Instance.new("UICorner", StatusBtn).CornerRadius = UDim.new(0, 6)

StatusBtn.MouseButton1Click:Connect(function()
    Config.AutoBuyEnabled = not Config.AutoBuyEnabled
    StatusBtn.Text = Config.AutoBuyEnabled and "ON" or "OFF"
    StatusBtn.BackgroundColor3 = Config.AutoBuyEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    Save()
end)

-- (Le reste de l'interface GUI reste identique à ton script original...)

-- --- LOGIQUE DE JEU ---

local function MoveTo(targetInstance, prompt)
    local character = Players.LocalPlayer.Character
    if not character then return end
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local hasBeenTriggered = false
    
    local connection
    connection = prompt.Triggered:Connect(function()
        hasBeenTriggered = true
        if connection then connection:Disconnect() end
    end)

    while targetInstance and targetInstance.Parent and Config.AutoBuyEnabled and not hasBeenTriggered do
        local targetPos = targetInstance:GetPivot().Position
        local path = PathfindingService:CreatePath({AgentRadius = 3, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 8})
        local success, _ = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)

        if success and path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            for i = 2, #waypoints do
                if hasBeenTriggered or not Config.AutoBuyEnabled then break end
                if waypoints[i].Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
                humanoid:MoveTo(waypoints[math.min(i + 1, #waypoints)].Position)
                repeat task.wait() until (rootPart.Position - waypoints[i].Position).Magnitude < 8 or hasBeenTriggered
            end
        else
            humanoid:MoveTo(targetInstance:GetPivot().Position)
            task.wait(0.05)
        end
        task.wait()
    end
end

local function OnBrainrotSpawn(brainrot) 
    if ShouldIBuy(brainrot) then         
        if brainrot.Prompt then
            -- Connexion pour l'achat
            brainrot.PromptShownConnection = brainrot.Prompt.PromptShown:Connect(function()
                fireproximityprompt(brainrot.Prompt)
                task.wait(0.5)
                isBusy = false
                
                -- RETOUR À LA POSITION INITIALE (BASE)
                local home = GetHomePos()
                local char = Players.LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") then
                    char.Humanoid:MoveTo(home)
                end
            end)

            task.spawn(function()
                while task.wait(0.3) do
                    if not brainrot.Instance or not brainrot.Instance.Parent then break end
                    local pos = brainrot.Instance:GetPivot().Position
                    local canBuy = false

                    -- VERIFICATION SELON LE ROLE (PLAYER 1 OU 2)
                    if Config.PlayerRole == 1 then
                        if pos.Z > 160 then canBuy = true end
                    else
                        -- Condition J2 : X < -435 et Z < -30
                        if pos.X < -435 and pos.Z < -30 then canBuy = true end
                    end

                    if not isBusy and canBuy then
                        isBusy = true
                        MoveTo(brainrot.Instance, brainrot.Prompt)
                    end
                end
            end)
        end
    end
end

-- (Le reste du script pour ChildAdded, ParseGeneration, etc. reste identique...)

Load()
RefreshMatrixGUI()
