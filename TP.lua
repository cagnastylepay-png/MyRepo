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
    MinGenValue = 1000000,
    ActiveMutation = "Default",
    Matrix = {},
    Visible = true
}

local FILE_NAME = "CRD_AutoBuy_V2.json"

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

-- Icône de réduction
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

-- Bordure Principale
local Bg = Instance.new("Frame", MainContainer)
Bg.Size = UDim2.new(1, -80, 1, -40)
Bg.Position = UDim2.new(0, 40, 0, 20)
Bg.BackgroundColor3 = Color3.fromHex("#2E2E2E")
Instance.new("UICorner", Bg).CornerRadius = UDim.new(0, 10)

-- HEADER
local Title = Instance.new("TextLabel", Bg)
Title.Text = "CRD Auto Buy"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 20
Title.Position = UDim2.new(0, 15, 0, 15)
Title.Size = UDim2.new(0, 120, 0, 30)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1
-- Label pour l'Income
local IncomeLabel = Instance.new("TextLabel", Bg)
IncomeLabel.Text = "Minimum Income:"
IncomeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
IncomeLabel.Font = Enum.Font.SourceSans
IncomeLabel.TextSize = 14
IncomeLabel.Position = UDim2.new(0, 140, 0, 15)
IncomeLabel.Size = UDim2.new(0, 100, 0, 30)
IncomeLabel.TextXAlignment = Enum.TextXAlignment.Right
IncomeLabel.BackgroundTransparency = 1
-- TextBox pour le prix (Income)
local IncomeBox = Instance.new("TextBox", Bg)
IncomeBox.Size = UDim2.new(0, 80, 0, 25)
IncomeBox.Position = UDim2.new(0, 245, 0, 17)
IncomeBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
IncomeBox.Text = Config.MinGenText
IncomeBox.TextColor3 = Color3.fromRGB(0, 255, 0) -- Vert pour le chiffre
IncomeBox.Font = Enum.Font.Code
IncomeBox.TextSize = 16
local BoxCorner = Instance.new("UICorner", IncomeBox)
BoxCorner.CornerRadius = UDim.new(0, 4)

IncomeBox.FocusLost:Connect(function(enter)
    UpdateMinGen(IncomeBox.Text)
    IncomeBox.Text = Config.MinGenText
end)

-- Bouton START / STOP
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

-- Bouton Réduire (X)
local CloseBtn = Instance.new("TextButton", Bg)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -40, 0, 15)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 20

CloseBtn.MouseButton1Click:Connect(function()
    MainContainer.Visible = false
    MiniIcon.Visible = true
end)
MiniIcon.MouseButton1Click:Connect(function()
    MainContainer.Visible = true
    MiniIcon.Visible = false
end)
-- Barre de séparation (Grise)
local Divider = Instance.new("Frame", Bg)
Divider.Size = UDim2.new(1, -30, 0, 1)
Divider.Position = UDim2.new(0, 15, 0, 55)
Divider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
Divider.BorderSizePixel = 0
-- SECTIONS (2 colonnes pour les mutations)
local MutGrid = Instance.new("Frame", Bg)
MutGrid.Size = UDim2.new(0, 300, 1, -80)
MutGrid.Position = UDim2.new(0, 20, 0, 70)
MutGrid.BackgroundTransparency = 1

local UIGrid = Instance.new("UIGridLayout", MutGrid)
UIGrid.CellSize = UDim2.new(0, 140, 0, 30)
UIGrid.CellPadding = UDim2.new(0, 10, 0, 5)

local mutationsList = {
    {n="Default", c="#FFFFFF"}, {n="Gold", c="#FFDE59"}, {n="Diamond", c="#25C4FE"}, 
    {n="Bloodrot", c="#8A3B3C"}, {n="Rainbow", c="#ff00fb"}, {n="Candy", c="#ff46f6"}, 
    {n="Lava", c="#ff7700"}, {n="Galaxy", c="#aa3cff"}, {n="YinYang", c="#FFDE59"}, 
    {n="Radioactive", c="#68f500"}, {n="Cursed", c="#f53838"}
}

local RefreshMatrixGUI 

for _, m in pairs(mutationsList) do
    local btn = Instance.new("TextButton", MutGrid)
    btn.Text = m.n
    btn.TextColor3 = Color3.fromHex(m.c)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 16
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.MouseButton1Click:Connect(function()
        Config.ActiveMutation = m.n
        RefreshMatrixGUI()
    end)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
end

-- Colonnes de droite (Raretés / Lucky)
local RightPanel = Instance.new("Frame", Bg)
RightPanel.Size = UDim2.new(1, -340, 1, -80)
RightPanel.Position = UDim2.new(0, 330, 0, 70)
RightPanel.BackgroundTransparency = 1

local LeftCol = Instance.new("Frame", RightPanel)
LeftCol.Size = UDim2.new(0.5, -5, 1, 0)
Instance.new("UIListLayout", LeftCol).Padding = UDim.new(0, 2)
LeftCol.BackgroundTransparency = 1

local RightCol = Instance.new("Frame", RightPanel)
RightCol.Size = UDim2.new(0.5, -5, 1, 0)
RightCol.Position = UDim2.new(0.5, 5, 0, 0)
Instance.new("UIListLayout", RightCol).Padding = UDim.new(0, 2)
RightCol.BackgroundTransparency = 1

local rarities = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God", "Secret", "OG"}
local luckies = {"Mythic Lucky Block","Brainrot God Lucky Block", "Secret Lucky Block", "Admin Lucky Block", "Taco Lucky Block", "Los Lucky Blocks", "Los Taco Blocks"}

local allButtons = {}
local function CreateToggle(name, parent)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 25)
    btn.BackgroundTransparency = 1
    btn.Text = "○ " .. name
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 16
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.MouseButton1Click:Connect(function()
        local m = Config.ActiveMutation
        if not Config.Matrix[m] then Config.Matrix[m] = {} end
        Config.Matrix[m][name] = not Config.Matrix[m][name]
        Save()
        RefreshMatrixGUI()
    end)
    allButtons[name] = btn
end

for _, r in pairs(rarities) do CreateToggle(r, LeftCol) end
for _, l in pairs(luckies) do CreateToggle(l, RightCol) end

RefreshMatrixGUI = function()
    Title.Text = "CRD [" .. Config.ActiveMutation .. "]"
    local m = Config.ActiveMutation
    for name, btn in pairs(allButtons) do
        local active = Config.Matrix[m] and Config.Matrix[m][name]
        btn.Text = (active and "● " or "○ ") .. name
        btn.TextColor3 = active and Color3.new(0, 1, 0) or Color3.new(1, 1, 1)
    end
end
-- --- LOGIQUE DE JEU ---

local function ShouldIBuy(brainrot)
    if not Config.AutoBuyEnabled then return false end
    local mut = brainrot.Mutation or "Default"
    
    -- Vérification Matrix (Mutation spécifique + Rareté OU Nom Lucky Block)
    if Config.Matrix[mut] then
        if Config.Matrix[mut][brainrot.Rarity] or Config.Matrix[mut][brainrot.DisplayName] then
            return true
        end
    end
    
    -- Backup MinGen
    if ParseGeneration(brainrot.Generation) >= Config.MinGen then
        return true
    end
    return false
end

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

    -- On remet ta vitesse de base ou on s'assure qu'elle est à 60
    humanoid.WalkSpeed = 60 

    while targetInstance and targetInstance.Parent and Config.AutoBuyEnabled and not hasBeenTriggered do
        local targetPos = targetInstance:GetPivot().Position
        local path = PathfindingService:CreatePath({
            AgentRadius = 3, 
            AgentHeight = 5, 
            AgentCanJump = true,
            WaypointSpacing = 8 -- On espace les points car on va vite
        })
        
        local success, _ = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)

        if success and path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            
            -- À 60 de vitesse, on vise le point +2 pour anticiper le virage
            for i = 2, #waypoints do
                if hasBeenTriggered or not Config.AutoBuyEnabled then break end
                
                -- On saute si le waypoint actuel OU le suivant demande un saut
                if waypoints[i].Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end

                -- On cible le point i (ou i+1 si disponible pour plus de fluidité)
                local lookAheadIndex = math.min(i + 1, #waypoints)
                humanoid:MoveTo(waypoints[lookAheadIndex].Position)
                
                -- Zone de tolérance large (6 studs) car à 60 speed, 3 studs se traversent en 0.05s
                repeat
                    task.wait()
                    local dist = (rootPart.Position - waypoints[i].Position).Magnitude
                until dist < 8 or (targetInstance:GetPivot().Position - targetPos).Magnitude > 5 or hasBeenTriggered
                
                if (targetInstance:GetPivot().Position - targetPos).Magnitude > 5 then
                    break 
                end
            end
        else
            humanoid:MoveTo(targetInstance:GetPivot().Position)
            task.wait(0.05)
        end
        task.wait() -- Refresh ultra rapide
    end
end


local function ParseGeneration(str)
    local clean = str:gsub("[%$%s/s]", ""):upper() -- Enlève $, espaces et /s
    local multiplier = 1
    local numStr = clean
    
    if clean:find("K") then
        multiplier = 10^3
        numStr = clean:gsub("K", "")
    elseif clean:find("M") then
        multiplier = 10^6
        numStr = clean:gsub("M", "")
    elseif clean:find("B") then
        multiplier = 10^9
        numStr = clean:gsub("B", "")
    elseif clean:find("T") then
        multiplier = 10^12
        numStr = clean:gsub("T", "")
    end
    
    local val = tonumber(numStr)
    return val and (val * multiplier) or 0
end

local function FindOverhead(animalModel)
    local animalName = animalModel.Name
    local bestTemplate = nil
    local minDistance = math.huge

    for _, item in ipairs(Debris:GetChildren()) do
        if item.Name == "FastOverheadTemplate" and item:IsA("BasePart") then
            -- On plonge dans AnimalOverhead pour vérifier le texte
            local container = item:FindFirstChild("AnimalOverhead")
            local displayNameLabel = container and container:FindFirstChild("DisplayName")
            
            if displayNameLabel and displayNameLabel.Text == animalName then
                local animalPos = animalModel:GetPivot().Position
				        local horizontalPos = Vector3.new(animalPos.X, item.Position.Y, animalPos.Z)
				        local dist = (item.Position - horizontalPos).Magnitude            
                if dist < minDistance then
                    minDistance = dist
                    bestTemplate = item
                end
            end
        end
    end

    if bestTemplate and minDistance < 3 then
		    return bestTemplate
    end
    return nil
end
  
local function FindPrompt(animalModel)
    local animalName = animalModel.Name
    local bestPrompt = nil
    local minDistance = math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.ActionText == "Purchase" then
            if string.find(obj.ObjectText, animalName) then
                local attachment = obj.Parent
                if attachment:IsA("Attachment") and attachment.Name == "PromptAttachment" then
                    local dist = (attachment.WorldCFrame.Position - animalModel:GetPivot().Position).Magnitude
                    if dist < minDistance then
                        minDistance = dist
                        bestPrompt = obj
                    end
                end
            end
        end
    end
    return (bestPrompt and minDistance < 15) and bestPrompt or nil
end

local function OnBrainrotSpawn(brainrot) 
    if ShouldIBuy(brainrot) then         
        if brainrot.Prompt then
            local connection
            connection = brainrot.Prompt.PromptShown:Connect(function()
                fireproximityprompt(brainrot.Prompt)
                connection:Disconnect()
            end)
            task.spawn(function()
                MoveTo(brainrot.Instance, brainrot.Prompt)
                if connection.Connected then
                    connection:Disconnect()
                end
            end)
        end
    end
end

RenderedAnimals.ChildAdded:Connect(function(animal)
    if Config.AutoBuyEnabled then
        task.wait(1.5) 
    
        local template = FindOverhead(animal)
        local prompt = FindPrompt(animal)

        if not template then return end
    
        local container = template:FindFirstChild("AnimalOverhead")
        if not container then return end
        local displayObj = container:FindFirstChild("DisplayName")
        local priceObj = container:FindFirstChild("Price")
        local mutationObj = container:FindFirstChild("Mutation")
    
        local start = tick()
        while (tick() - start) < 5 do
            if displayObj and displayObj.Text ~= "" then
                break
            end
            task.wait(0.2)
        end

        if not displayObj or displayObj.Text == "" then 
            return 
        end

        local actualMutation = "Default"
        if mutationObj and mutationObj.Visible and mutationObj.Text ~= "" then
            actualMutation = mutationObj.Text
        end

        local animalData = {
            Instance = animal,
            DisplayName = displayObj.Text,
            Mutation = actualMutation,
            Generation = container:FindFirstChild("Generation") and container.Generation.Text or "1/s",
            Price = priceObj.Text,
            Rarity = container:FindFirstChild("Rarity") and container.Rarity.Text or "Common",
            Prompt = prompt
        }
        OnBrainrotSpawn(animalData)
    end
end)

Load()
RefreshMatrixGUI()
