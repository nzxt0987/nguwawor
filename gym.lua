local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function getTrainTarget(index)
    local success, result = pcall(function()
        return workspace.Scene:GetChildren()[9]:GetChildren()[4]:GetChildren()[index]
    end)
    if success and result then return result end
    return nil
end

-- Data Alat & Beban
local ToolsData = {
    Chest = { TargetIndex = 2, WeightIndex = 8 },
    Leg = { TargetIndex = 8, WeightIndex = 6 }, 
    Abs = { TargetIndex = 21, WeightIndex = 6 },
    Arm = { TargetIndex = 6, WeightIndex = 6 },
    Treadmill = { TargetIndex = 14, WeightIndex = 8 },
    Back = { TargetIndex = 16, WeightIndex = 8 }
}

-- Bersihkan GUI Lama dan Unload
if CoreGui:FindFirstChild("GymStarMinGui") then
    if _G.GymStarUnload then pcall(_G.GymStarUnload) end
    CoreGui.GymStarMinGui:Destroy()
end

-- Global State
getgenv().GymStarToggles = {}
getgenv().AutoFarmAllActive = false
local antiAFKConnection = nil
local scriptRunning = true

-- ==========================================
-- UI DESIGN
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GymStarMinGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 350)
MainFrame.Position = UDim2.new(0.5, -120, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundTransparency = 1
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Gym Star Full Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 35)
MinBtn.Position = UDim2.new(1, -60, 0, 0)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 35)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = TitleBar

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, 0, 1, -40)
ScrollFrame.Position = UDim2.new(0, 0, 0, 35)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.ScrollBarThickness = 6
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 950) 
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ScrollFrame
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Fungsi Minimize
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame.Size = UDim2.new(0, 240, 0, 35)
        ScrollFrame.Visible = false
    else
        MainFrame.Size = UDim2.new(0, 240, 0, 350)
        ScrollFrame.Visible = true
    end
end)

-- Fungsi Helper Pembuat Tombol
local function createButton(name, text, isToggle, order, isRed)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 210, 0, 35)
    btn.BackgroundColor3 = isRed and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(45, 45, 45)
    btn.Text = text .. (isToggle and ": OFF" or "")
    btn.TextColor3 = isToggle and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.LayoutOrder = order
    btn.Parent = ScrollFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    return btn
end

-- ==========================================
-- BUTTON CREATION
-- ==========================================
local AntiAFKBtn = createButton("AntiAFK", "Anti-AFK", true, 1)
local AutoClickBtn = createButton("AutoClick", "Auto Click", true, 2)
local AutoCompBtn = createButton("AutoComp", "Auto Competition", true, 3)
local AutoRollBtn = createButton("AutoRoll", "Auto Roll", true, 4)
local CancelTrainBtn = createButton("CancelTrain", "Stop / Cancel Training", false, 5, true)

local function createTitle(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = "--- " .. text .. " ---"
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.LayoutOrder = order
    lbl.Parent = ScrollFrame
end

createTitle("TREADMILL", 5)
local AutoTreadmillBtn = createButton("AutoTreadmill", "Auto Treadmill", true, 6)
local AutoW_TreadmillBtn = createButton("AutoW_Treadmill", "Max Weight Treadmill", true, 7)

-- ==========================================
-- LOGIC / FITUR
-- ==========================================

local function doCancelTrain()
    pcall(function()
        ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\233\128\128\229\135\186\232\174\173\231\187\131")
        ReplicatedStorage:WaitForChild("ServerMsg"):WaitForChild("Setting"):InvokeServer("isAutoClick", 0)
    end)
end

-- Fungsi Helper Equip Latihan & Beban
local function equipWeightDirect(toolName)
    local data = ToolsData[toolName]
    if toolName == "Leg" then
        -- Untuk Leg: Kurangi beban index 1, lalu tambah index 6 sampai max (10x)
        pcall(function() ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\232\174\190\231\189\174\230\140\161\228\189\141", {Index = 1, Count = -1}) end)
        task.wait(0.2)
        for i = 1, 10 do
            pcall(function() ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\232\174\190\231\189\174\230\140\161\228\189\141", {Index = 6, Count = 1}) end)
            task.wait(0.05)
        end
    else
        -- Untuk alat lain, panggil beban sesuai setting
        pcall(function() ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\232\174\190\231\189\174\230\140\161\228\189\141", {Index = data.WeightIndex, Count = 1}) end)
    end
end

local function toggleNativeAutoClick(state)
    local val = state and 1 or 0
    pcall(function() ReplicatedStorage.ServerMsg.Setting:InvokeServer("isAutoClick", val) end)
end

local function doTrainLoop(toolName)
    if toolName == "Treadmill" then
        local paths = {
            function() return workspace.Scene:GetChildren()[2]:GetChildren()[6]:GetChildren()[11] end,
            function() return workspace.Scene:GetChildren()[8]:GetChildren()[1]:GetChildren()[17] end,
            function() return workspace.Scene:GetChildren()[6]:GetChildren()[4]:GetChildren()[25] end,
            function() return workspace.Scene:GetChildren()[13]:GetChildren()[6]:GetChildren()[6] end,
            function() return workspace.Scene:GetChildren()[4]:GetChildren()[3]:GetChildren()[5] end,
            function() return workspace.Scene:GetChildren()[10]:GetChildren()[4]:GetChildren()[6] end,
            function() return workspace.Scene:GetChildren()[9]:GetChildren()[4]:GetChildren()[21] end,
            function() return workspace.Scene:GetChildren()[11]:GetChildren()[5]:GetChildren()[2] end,
            function() return workspace.Scene:GetChildren()[1]:GetChildren()[2]:GetChildren()[18] end,
            function() return workspace.Scene:GetChildren()[5]:GetChildren()[6]:GetChildren()[18] end
        }
        
        for _, getPath in ipairs(paths) do
            local currentTarget = nil
            pcall(function() currentTarget = getPath() end)
            
            if currentTarget then
                local args = {
                    [1] = "StartTrain",
                    [2] = currentTarget
                }
                game:GetService("ReplicatedStorage").Msg.RemoteEvent:FireServer(unpack(args))
            end
        end
    else
        local target = getTrainTarget(ToolsData[toolName].TargetIndex)
        if target then
            ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("StartTrain", target)
        end
    end
end

-- Fungsi Toggle Universal
local function handleToggle(btn, varName, toolName, isWeightBtn, customCallback)
    getgenv().GymStarToggles[varName] = false
    btn.MouseButton1Click:Connect(function()
        if not scriptRunning then return end
        

        
        getgenv().GymStarToggles[varName] = not getgenv().GymStarToggles[varName]
        local isActive = getgenv().GymStarToggles[varName]
        
        if isActive then
            btn.Text = string.gsub(btn.Text, "OFF", "ON")
            btn.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            if customCallback then
                task.spawn(function() customCallback(true) end)
            elseif isWeightBtn then
                -- Loop max weight agar tidak terlepas
                task.spawn(function()
                    while getgenv().GymStarToggles[varName] and scriptRunning do
                        equipWeightDirect(toolName)
                        task.wait(5)
                    end
                end)
            else
                -- Training: Otomatis Start Train dan Nyalakan Native AutoClick
                if toolName then
                    task.spawn(function() doTrainLoop(toolName) end)
                    if toolName ~= "Treadmill" then
                        toggleNativeAutoClick(true)
                    end
                end
                
                -- Loop StartTrain supaya tidak terlepas jika di-knock
                task.spawn(function()
                    while getgenv().GymStarToggles[varName] and scriptRunning do
                        if toolName then
                            doTrainLoop(toolName)
                        end
                        task.wait(2)
                    end
                end)
            end
        else
            btn.Text = string.gsub(btn.Text, "ON", "OFF")
            btn.TextColor3 = Color3.fromRGB(255, 100, 100)
            
            if customCallback then
                task.spawn(function() customCallback(false) end)
            elseif not isWeightBtn and toolName then
                toggleNativeAutoClick(false)
            end
        end
    end)
end

-- Apply Logic Individual
handleToggle(AutoTreadmillBtn, "AutoTreadmill", "Treadmill", false)
handleToggle(AutoW_TreadmillBtn, "AutoW_Treadmill", "Treadmill", true)



-- Auto Click (Manual)
-- Auto Click (Native)
handleToggle(AutoClickBtn, "AutoClick", nil, false, function(state)
    toggleNativeAutoClick(state)
end)

-- Auto Roll
handleToggle(AutoRollBtn, "AutoRoll", nil, false, function(state)
    if state then
        task.spawn(function()
            while getgenv().GymStarToggles["AutoRoll"] and scriptRunning do
                pcall(function()
                    local args = {
                        [1] = "\230\138\189\229\143\150\229\133\137\231\142\175"
                    }
                    game:GetService("ReplicatedStorage").Msg.RemoteFunction:InvokeServer(unpack(args))
                end)
                task.wait(0.5)
            end
        end)
    end
end)

-- Auto Competition
handleToggle(AutoCompBtn, "AutoCompetition", nil, false, function(state)
    if state then
        -- Loop khusus pembasmi GUI Settlement agar tidak muncul sama sekali (Anti-Flash)
        local rsConnection
        local cachedSettlement = nil
        
        rsConnection = game:GetService("RunService").RenderStepped:Connect(function()
            if not getgenv().GymStarToggles["AutoCompetition"] or not scriptRunning then
                rsConnection:Disconnect()
                return
            end
            pcall(function()
                if cachedSettlement and cachedSettlement.Parent then
                    if cachedSettlement:IsA("GuiObject") and cachedSettlement.Visible then
                        cachedSettlement.Visible = false
                    elseif cachedSettlement:IsA("ScreenGui") and cachedSettlement.Enabled then
                        cachedSettlement.Enabled = false
                    end
                else
                    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                    if playerGui then
                        cachedSettlement = playerGui:FindFirstChild("Competition clearance settlement", true)
                    end
                end
            end)
        end)
        
        -- Gunakan loop khusus yang tidak mengandalkan wait dalam state yang aneh
        task.spawn(function()
            while getgenv().GymStarToggles["AutoCompetition"] and scriptRunning do
                pcall(function()
                    local rep = ReplicatedStorage
                    
                    -- Join kompetisi
                    rep:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\229\143\130\229\138\160\230\175\148\232\181\155")
                    task.wait(0.5)
                    if not getgenv().GymStarToggles["AutoCompetition"] then return end
                    
                    -- Skip kompetisi
                    rep:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\232\183\179\232\191\135\230\175\148\232\181\155")
                    task.wait(0.5)
                    if not getgenv().GymStarToggles["AutoCompetition"] then return end
                    
                    -- Selesai & ambil hadiah
                    rep:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\229\187\182\232\191\159\233\162\134\229\143\150\229\165\150\229\138\177")
                    task.wait(0.5)
                end)
                task.wait(0.5)
            end
        end)
    else
        -- Kembalikan GUI Settlement menjadi terlihat saat Auto dimatikan
        pcall(function()
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui then
                local settlementGui = playerGui:FindFirstChild("Competition clearance settlement", true)
                if settlementGui then
                    if settlementGui:IsA("GuiObject") then
                        settlementGui.Visible = true
                    elseif settlementGui:IsA("ScreenGui") then
                        settlementGui.Enabled = true
                    end
                end
            end
        end)
    end
end)

-- Cancel Button
CancelTrainBtn.MouseButton1Click:Connect(doCancelTrain)

-- Anti-AFK
handleToggle(AntiAFKBtn, "AntiAFK", nil, false, function(state)
    if state then
        if not antiAFKConnection then
            antiAFKConnection = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    else
        if antiAFKConnection then
            antiAFKConnection:Disconnect()
            antiAFKConnection = nil
        end
    end
end)

-- ==========================================
-- AUTO START FEATURES
-- ==========================================
task.spawn(function()
    task.wait(0.5)
    if not getgenv().GymStarToggles["AutoRoll"] then
        getgenv().GymStarToggles["AutoRoll"] = true
        AutoRollBtn.Text = "Auto Roll: ON"
        AutoRollBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        task.spawn(function()
            while getgenv().GymStarToggles["AutoRoll"] and scriptRunning do
                pcall(function()
                    local args = {
                        [1] = "\230\138\189\229\143\150\229\133\137\231\142\175"
                    }
                    game:GetService("ReplicatedStorage").Msg.RemoteFunction:InvokeServer(unpack(args))
                end)
                task.wait(0.5)
            end
        end)
    end

    if not getgenv().GymStarToggles["AntiAFK"] then
        getgenv().GymStarToggles["AntiAFK"] = true
        AntiAFKBtn.Text = "Anti-AFK: ON"
        AntiAFKBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
        if not antiAFKConnection then
            antiAFKConnection = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end

    if not getgenv().GymStarToggles["AutoClick"] then
        getgenv().GymStarToggles["AutoClick"] = true
        AutoClickBtn.Text = "Auto Click: ON"
        AutoClickBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
        toggleNativeAutoClick(true)
    end
end)

-- ==========================================
-- CLOSE / UNLOAD SCRIPT
-- ==========================================
_G.GymStarUnload = function()
    scriptRunning = false

    for k, _ in pairs(getgenv().GymStarToggles) do
        getgenv().GymStarToggles[k] = false
    end
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end
    doCancelTrain()
end

CloseBtn.MouseButton1Click:Connect(function()
    _G.GymStarUnload()
    if ScreenGui then
        ScreenGui:Destroy()
    end
end)