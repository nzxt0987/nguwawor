local getgenv = (typeof(getgenv) == "function" and getgenv) or function() return _G end
local gethui = (typeof(gethui) == "function" and gethui) or nil

local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local function getTrainTarget(index)
    local success, result = pcall(function()
        local scene = workspace:FindFirstChild("Scene")
        if not scene then return nil end
        local children = scene:GetChildren()
        if children[9] and children[9]:GetChildren()[4] then
            return children[9]:GetChildren()[4]:GetChildren()[index]
        end
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

-- Target Container UI (Kompatibel Semua Executor: Xeno, Solara, Mobile, Modern)
local TargetGuiParent = nil
if gethui then
    pcall(function() TargetGuiParent = gethui() end)
end
if not TargetGuiParent then
    pcall(function() TargetGuiParent = CoreGui:FindFirstChild("RobloxGui") end)
end
if not TargetGuiParent then
    pcall(function() TargetGuiParent = CoreGui end)
end
if not TargetGuiParent then
    pcall(function() TargetGuiParent = LocalPlayer:WaitForChild("PlayerGui") end)
end

-- Bersihkan GUI Lama dan Unload
pcall(function()
    if _G.GymStarUnload then pcall(_G.GymStarUnload) end
    if TargetGuiParent and TargetGuiParent:FindFirstChild("GymStarMinGui") then
        TargetGuiParent.GymStarMinGui:Destroy()
    end
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui and playerGui:FindFirstChild("GymStarMinGui") then
        playerGui.GymStarMinGui:Destroy()
    end
end)

-- Global State & Loop Token Tracking
local env = getgenv()
env.GymStarToggles = env.GymStarToggles or {}
env.AutoFarmAllActive = false
local antiAFKConnection = nil
local autoCompConnection = nil
local autoCompCachedSettlement = nil
local activeLoopTokens = {}
local scriptRunning = true

local lowEndEnabled = false
local lowEndOriginals = {}

-- ==========================================
-- COLOR PALETTE & DESIGN TOKENS
-- ==========================================
local Colors = {
    BgPrimary = Color3.fromRGB(15, 15, 22),
    BgSecondary = Color3.fromRGB(22, 22, 35),
    BgCard = Color3.fromRGB(28, 28, 42),
    BgCardHover = Color3.fromRGB(35, 35, 52),
    AccentPrimary = Color3.fromRGB(99, 102, 241),   -- Indigo
    AccentGlow = Color3.fromRGB(129, 140, 248),
    AccentGreen = Color3.fromRGB(52, 211, 153),      -- Emerald
    AccentRed = Color3.fromRGB(248, 113, 113),        -- Rose
    AccentOrange = Color3.fromRGB(251, 146, 60),
    TextPrimary = Color3.fromRGB(237, 237, 245),
    TextSecondary = Color3.fromRGB(148, 148, 170),
    TextMuted = Color3.fromRGB(100, 100, 125),
    Divider = Color3.fromRGB(45, 45, 65),
    ToggleOff = Color3.fromRGB(55, 55, 75),
    ToggleOn = Color3.fromRGB(52, 211, 153),
    DangerBg = Color3.fromRGB(60, 25, 30),
    DangerAccent = Color3.fromRGB(220, 60, 60),
}

-- Helper untuk token loop (mencegah loop ganda saat rapid toggle)
local function getNextToken(varName)
    local nextTok = (activeLoopTokens[varName] or 0) + 1
    activeLoopTokens[varName] = nextTok
    return nextTok
end

-- ==========================================
-- LOW END GRAPHICS
-- ==========================================
local function saveOriginal(obj, key, value)
    if not lowEndOriginals[obj] then
        lowEndOriginals[obj] = {}
    end
    if lowEndOriginals[obj][key] == nil then
        lowEndOriginals[obj][key] = value
    end
end

local function setLowEndObject(obj)
    pcall(function()
        if not obj or not obj.Parent then return end
        -- Skip character local player
        if LocalPlayer.Character and obj:IsDescendantOf(LocalPlayer.Character) then return end

        if obj:IsA("ParticleEmitter")
        or obj:IsA("Trail")
        or obj:IsA("Beam")
        or obj:IsA("Smoke")
        or obj:IsA("Fire")
        or obj:IsA("Sparkles")
        or obj:IsA("Highlight") then
            saveOriginal(obj, "Enabled", obj.Enabled)
            obj.Enabled = false

        elseif obj:IsA("BasePart") then
            saveOriginal(obj, "Material", obj.Material)
            saveOriginal(obj, "Reflectance", obj.Reflectance)
            saveOriginal(obj, "CastShadow", obj.CastShadow)
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false

            if obj:IsA("MeshPart") then
                saveOriginal(obj, "TextureID", obj.TextureID)
                obj.TextureID = ""
            end

        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            saveOriginal(obj, "Transparency", obj.Transparency)
            obj.Transparency = 1

        elseif obj:IsA("PostEffect")
        or obj:IsA("BlurEffect")
        or obj:IsA("BloomEffect")
        or obj:IsA("SunRaysEffect")
        or obj:IsA("DepthOfFieldEffect")
        or obj:IsA("ColorCorrectionEffect") then
            saveOriginal(obj, "Enabled", obj.Enabled)
            obj.Enabled = false
        end
    end)
end

local function enableLowEnd()
    if lowEndEnabled then return end
    lowEndEnabled = true

    task.spawn(function()
        pcall(function()
            local lighting = game:GetService("Lighting")
            saveOriginal(lighting, "GlobalShadows", lighting.GlobalShadows)
            saveOriginal(lighting, "FogEnd", lighting.FogEnd)
            lighting.GlobalShadows = false
            lighting.FogEnd = 9e9

            local terrain = workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                saveOriginal(terrain, "WaterWaveSize", terrain.WaterWaveSize)
                saveOriginal(terrain, "WaterWaveSpeed", terrain.WaterWaveSpeed)
                saveOriginal(terrain, "WaterReflectance", terrain.WaterReflectance)
                saveOriginal(terrain, "WaterTransparency", terrain.WaterTransparency)
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 1
            end
        end)

        local descendants = workspace:GetDescendants()
        local count = 0
        for _, obj in ipairs(descendants) do
            if not lowEndEnabled or not scriptRunning then break end
            setLowEndObject(obj)
            count = count + 1
            if count % 200 == 0 then
                task.wait()
            end
        end

        if lowEndEnabled and scriptRunning then
            pcall(function()
                local lighting = game:GetService("Lighting")
                for _, obj in ipairs(lighting:GetChildren()) do
                    setLowEndObject(obj)
                end
            end)
        end
    end)
end

local function disableLowEnd()
    if not lowEndEnabled then return end
    lowEndEnabled = false

    for obj, props in pairs(lowEndOriginals) do
        pcall(function()
            if not obj or not obj.Parent then return end
            for key, value in pairs(props) do
                obj[key] = value
            end
        end)
    end

    if typeof(table.clear) == "function" then
        table.clear(lowEndOriginals)
    else
        lowEndOriginals = {}
    end
end

local lowEndDescendantConnection = nil

local function watchLowEndObjects()
    if lowEndDescendantConnection then return end
    lowEndDescendantConnection = workspace.DescendantAdded:Connect(function(obj)
        if lowEndEnabled then
            setLowEndObject(obj)
        end
    end)
end

local function stopLowEndWatcher()
    if lowEndDescendantConnection then
        lowEndDescendantConnection:Disconnect()
        lowEndDescendantConnection = nil
    end
end

-- ==========================================
-- MODERN UI DESIGN
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GymStarMinGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

pcall(function()
    if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
        syn.protect_gui(ScreenGui)
    elseif typeof(protectgui) == "function" then
        protectgui(ScreenGui)
    end
end)

ScreenGui.Parent = TargetGuiParent

-- Main Container
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 420)
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -210)
MainFrame.BackgroundColor3 = Colors.BgPrimary
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = MainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(60, 60, 90)
mainStroke.Thickness = 1
mainStroke.Transparency = 0.5
mainStroke.Parent = MainFrame

local Shadow = Instance.new("ImageLabel")
Shadow.Name = "Shadow"
Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow.Position = UDim2.new(0.5, 0, 0.5, 4)
Shadow.Size = UDim2.new(1, 30, 1, 30)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6015897843"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.ZIndex = 0
Shadow.Parent = MainFrame

-- ==========================================
-- TITLE BAR (Gradient)
-- ==========================================
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Colors.BgSecondary
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 5
TitleBar.Parent = MainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = TitleBar

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 14)
titleFix.Position = UDim2.new(0, 0, 1, -14)
titleFix.BackgroundColor3 = Colors.BgSecondary
titleFix.BorderSizePixel = 0
titleFix.ZIndex = 5
titleFix.Parent = TitleBar

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(99, 102, 241)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(139, 92, 246)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 72, 153))
})
titleGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.82),
    NumberSequenceKeypoint.new(1, 0.95)
})
titleGradient.Parent = TitleBar

local AccentLine = Instance.new("Frame")
AccentLine.Size = UDim2.new(1, 0, 0, 1)
AccentLine.Position = UDim2.new(0, 0, 1, 0)
AccentLine.BackgroundColor3 = Colors.AccentPrimary
AccentLine.BackgroundTransparency = 0.6
AccentLine.BorderSizePixel = 0
AccentLine.ZIndex = 6
AccentLine.Parent = TitleBar

local IconDot = Instance.new("Frame")
IconDot.Size = UDim2.new(0, 8, 0, 8)
IconDot.Position = UDim2.new(0, 14, 0.5, -4)
IconDot.BackgroundColor3 = Colors.AccentGreen
IconDot.BorderSizePixel = 0
IconDot.ZIndex = 6
IconDot.Parent = TitleBar
local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(1, 0)
iconCorner.Parent = IconDot

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.new(0, 30, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "GYM STAR HUB"
Title.TextColor3 = Colors.TextPrimary
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 6
Title.Parent = TitleBar

local VerBadge = Instance.new("TextLabel")
VerBadge.Size = UDim2.new(0, 28, 0, 16)
VerBadge.Position = UDim2.new(0, 128, 0.5, -8)
VerBadge.BackgroundColor3 = Colors.AccentPrimary
VerBadge.BackgroundTransparency = 0.7
VerBadge.Text = "v2"
VerBadge.TextColor3 = Colors.AccentGlow
VerBadge.Font = Enum.Font.GothamBold
VerBadge.TextSize = 9
VerBadge.ZIndex = 6
VerBadge.Parent = TitleBar
local verCorner = Instance.new("UICorner")
verCorner.CornerRadius = UDim.new(0, 4)
verCorner.Parent = VerBadge

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -66, 0.5, -15)
MinBtn.BackgroundColor3 = Colors.BgCard
MinBtn.BackgroundTransparency = 0.5
MinBtn.Text = "—"
MinBtn.TextColor3 = Colors.TextSecondary
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.ZIndex = 6
MinBtn.Parent = TitleBar
local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = MinBtn

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -15)
CloseBtn.BackgroundColor3 = Colors.DangerBg
CloseBtn.BackgroundTransparency = 0.3
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Colors.AccentRed
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.ZIndex = 6
CloseBtn.Parent = TitleBar
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = CloseBtn

-- ==========================================
-- SCROLL CONTENT AREA
-- ==========================================
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "ContentScroll"
ScrollFrame.Size = UDim2.new(1, -8, 1, -52)
ScrollFrame.Position = UDim2.new(0, 4, 0, 48)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.ScrollBarThickness = 3
ScrollFrame.ScrollBarImageColor3 = Colors.AccentPrimary
ScrollFrame.ScrollBarImageTransparency = 0.5
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.BorderSizePixel = 0
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ScrollFrame
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingTop = UDim.new(0, 4)
scrollPadding.PaddingBottom = UDim.new(0, 8)
scrollPadding.Parent = ScrollFrame

-- ==========================================
-- UI HELPER FUNCTIONS
-- ==========================================

local function tween(obj, props, duration)
    duration = duration or 0.25
    TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

local function createSectionTitle(text, order)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -16, 0, 28)
    container.BackgroundTransparency = 1
    container.LayoutOrder = order
    container.Parent = ScrollFrame

    local lineL = Instance.new("Frame")
    lineL.Size = UDim2.new(0.2, 0, 0, 1)
    lineL.Position = UDim2.new(0, 0, 0.5, 0)
    lineL.BackgroundColor3 = Colors.Divider
    lineL.BorderSizePixel = 0
    lineL.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.Position = UDim2.new(0.2, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.upper(text)
    lbl.TextColor3 = Colors.TextMuted
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.Parent = container

    local lineR = Instance.new("Frame")
    lineR.Size = UDim2.new(0.2, 0, 0, 1)
    lineR.Position = UDim2.new(0.8, 0, 0.5, 0)
    lineR.BackgroundColor3 = Colors.Divider
    lineR.BorderSizePixel = 0
    lineR.Parent = container
end

local function createToggleButton(name, text, order, icon)
    icon = icon or "●"
    
    local btnFrame = Instance.new("Frame")
    btnFrame.Name = name
    btnFrame.Size = UDim2.new(1, -16, 0, 38)
    btnFrame.BackgroundColor3 = Colors.BgCard
    btnFrame.BorderSizePixel = 0
    btnFrame.LayoutOrder = order
    btnFrame.Parent = ScrollFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btnFrame

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Colors.Divider
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.6
    btnStroke.Parent = btnFrame

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 24, 1, 0)
    iconLabel.Position = UDim2.new(0, 10, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Colors.TextMuted
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 10
    iconLabel.Parent = btnFrame

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -90, 1, 0)
    label.Position = UDim2.new(0, 34, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.TextPrimary
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btnFrame

    local toggleTrack = Instance.new("Frame")
    toggleTrack.Name = "ToggleTrack"
    toggleTrack.Size = UDim2.new(0, 38, 0, 20)
    toggleTrack.Position = UDim2.new(1, -50, 0.5, -10)
    toggleTrack.BackgroundColor3 = Colors.ToggleOff
    toggleTrack.BorderSizePixel = 0
    toggleTrack.Parent = btnFrame
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = toggleTrack

    local toggleKnob = Instance.new("Frame")
    toggleKnob.Name = "ToggleKnob"
    toggleKnob.Size = UDim2.new(0, 16, 0, 16)
    toggleKnob.Position = UDim2.new(0, 2, 0.5, -8)
    toggleKnob.BackgroundColor3 = Colors.TextSecondary
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Parent = toggleTrack
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = toggleKnob

    local clickBtn = Instance.new("TextButton")
    clickBtn.Name = "ClickBtn"
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.ZIndex = 3
    clickBtn.Parent = btnFrame

    clickBtn.MouseEnter:Connect(function()
        tween(btnFrame, {BackgroundColor3 = Colors.BgCardHover}, 0.15)
    end)
    clickBtn.MouseLeave:Connect(function()
        tween(btnFrame, {BackgroundColor3 = Colors.BgCard}, 0.15)
    end)

    return clickBtn, toggleTrack, toggleKnob, iconLabel, btnFrame
end

local function createActionButton(name, text, order, icon)
    icon = icon or "⚡"

    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, -16, 0, 38)
    btn.BackgroundColor3 = Colors.DangerBg
    btn.Text = ""
    btn.LayoutOrder = order
    btn.BorderSizePixel = 0
    btn.Parent = ScrollFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Colors.DangerAccent
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.7
    btnStroke.Parent = btn

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 24, 1, 0)
    iconLabel.Position = UDim2.new(0, 10, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Colors.AccentRed
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 12
    iconLabel.Parent = btn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -44, 1, 0)
    label.Position = UDim2.new(0, 34, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.AccentRed
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    btn.MouseEnter:Connect(function()
        tween(btn, {BackgroundColor3 = Color3.fromRGB(75, 30, 35)}, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, {BackgroundColor3 = Colors.DangerBg}, 0.15)
    end)

    return btn
end

local function setToggleVisual(isOn, toggleTrack, toggleKnob, iconLabel)
    if isOn then
        tween(toggleTrack, {BackgroundColor3 = Colors.ToggleOn}, 0.2)
        tween(toggleKnob, {Position = UDim2.new(1, -18, 0.5, -8), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
        tween(iconLabel, {TextColor3 = Colors.AccentGreen}, 0.2)
    else
        tween(toggleTrack, {BackgroundColor3 = Colors.ToggleOff}, 0.2)
        tween(toggleKnob, {Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = Colors.TextSecondary}, 0.2)
        tween(iconLabel, {TextColor3 = Colors.TextMuted}, 0.2)
    end
end

-- ==========================================
-- MINIMIZE LOGIC
-- ==========================================
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        tween(MainFrame, {Size = UDim2.new(0, 280, 0, 44)}, 0.3)
        ScrollFrame.Visible = false
        MinBtn.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, 280, 0, 420)
        ScrollFrame.Visible = true
        MinBtn.Text = "—"
    end
end)

-- ==========================================
-- CREATE BUTTONS
-- ==========================================
createSectionTitle("⚙ General", 0)

local AntiAFKClick, AntiAFKTrack, AntiAFKKnob, AntiAFKIcon = createToggleButton("AntiAFK", "Anti-AFK", 1, "🛡")
local AutoClickClick, AutoClickTrack, AutoClickKnob, AutoClickIcon = createToggleButton("AutoClick", "Auto Click", 2, "👆")
local AutoCompClick, AutoCompTrack, AutoCompKnob, AutoCompIcon = createToggleButton("AutoComp", "Auto Competition", 3, "🏆")
local AutoRollClick, AutoRollTrack, AutoRollKnob, AutoRollIcon = createToggleButton("AutoRoll", "Auto Roll", 4, "🎲")
local AutoClaimPetClick, AutoClaimPetTrack, AutoClaimPetKnob, AutoClaimPetIcon = createToggleButton("AutoClaimPet", "Auto Claim Pet", 5, "🐾")
local LowEndClick, LowEndTrack, LowEndKnob, LowEndIcon = createToggleButton("LowEndMode", "Low End Graphics", 6, "⚡")

createSectionTitle("🏃 Treadmill", 9)

local AutoTreadmillClick, AutoTreadmillTrack, AutoTreadmillKnob, AutoTreadmillIcon = createToggleButton("AutoTreadmill", "Auto Treadmill", 10, "🏃")
local AutoWTreadmillClick, AutoWTreadmillTrack, AutoWTreadmillKnob, AutoWTreadmillIcon = createToggleButton("AutoW_Treadmill", "Max Weight Treadmill", 11, "🏋")

createSectionTitle("⚠ Actions", 19)

local CancelTrainBtn = createActionButton("CancelTrain", "Stop / Cancel Training", 20, "⛔")

-- ==========================================
-- LOGIC / FITUR
-- ==========================================

local function doCancelTrain()
    pcall(function()
        ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\233\128\128\229\135\186\232\174\173\231\187\131")
        ReplicatedStorage:WaitForChild("ServerMsg"):WaitForChild("Setting"):InvokeServer("isAutoClick", 0)
    end)
end

local function equipWeightDirect(toolName)
    local data = ToolsData[toolName]
    if toolName == "Leg" then
        pcall(function() ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\232\174\190\231\189\174\230\140\161\228\189\141", {Index = 1, Count = -1}) end)
        task.wait(0.2)
        for i = 1, 10 do
            pcall(function() ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\232\174\190\231\189\174\230\140\161\228\189\141", {Index = 6, Count = 1}) end)
            task.wait(0.05)
        end
    else
        pcall(function() ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\232\174\190\231\189\174\230\140\161\228\189\141", {Index = data.WeightIndex, Count = 1}) end)
    end
end

local function toggleNativeAutoClick(state)
    local val = state and 1 or 0
    pcall(function()
        local args = {
            "isAutoClick",
            val
        }
        ReplicatedStorage:WaitForChild("ServerMsg"):WaitForChild("Setting"):InvokeServer(unpack(args))
    end)
end

local function doTrainLoop(toolName)
    if toolName == "Treadmill" then
        pcall(function()
            local treadmillTarget = workspace:FindFirstChild("Scene")
                and workspace.Scene:FindFirstChild("11")
                and workspace.Scene["11"]:FindFirstChild("Training equipment")
                and workspace.Scene["11"]["Training equipment"]:FindFirstChild("Conveyor2")
            if not treadmillTarget then
                treadmillTarget = workspace:WaitForChild("Scene"):WaitForChild("11"):WaitForChild("Training equipment"):WaitForChild("Conveyor2")
            end
            if treadmillTarget then
                ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("StartTrain", treadmillTarget)
            end
        end)
    else
        local target = getTrainTarget(ToolsData[toolName].TargetIndex)
        if target then
            pcall(function()
                ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("StartTrain", target)
            end)
        end
    end
end

-- ==========================================
-- AUTO CLAIM PET
-- ==========================================
local function doClaimPetQuest()
    -- 1. Direct Server Remotes (Paket Remote Gym Star)
    pcall(function()
        local rep = ReplicatedStorage
        local msg = rep:FindFirstChild("Msg")
        if not msg then return end
        local remoteEvent = msg:FindFirstChild("RemoteEvent")
        local remoteFunc = msg:FindFirstChild("RemoteFunction")

        local claimCommands = {
            "\233\162\134\229\143\150\228\187\188\228\188\161\229\165\150\229\138\177", -- 领取任务奖励 (Claim Task Reward)
            "\233\162\134\229\143\150\230\137\136\230\156\137\228\187\188\228\188\161\229\165\150\229\138\177", -- 领取所有任务奖励 (Claim All Task Rewards)
            "\233\162\134\229\143\150\231\175\174\231\155\135\229\165\150\229\138\177", -- 领取目标奖励 (Claim Target Reward)
            "\233\162\134\229\143\150\230\136\144\229\176\178\229\165\150\229\138\177", -- 领取成就奖励 (Claim Achievement Reward)
            "\233\162\134\229\143\150\230\137\136\230\156\137\229\165\150\229\138\177", -- 领取所有奖励 (Claim All Rewards)
            "\233\162\134\229\143\150\229\176\145\231\131\169\229\165\150\229\138\177", -- 领取宠物奖励 (Claim Pet Reward)
            "ClaimQuest",
            "ClaimPetQuest",
            "ClaimPet",
            "ClaimReward",
            "ClaimAllReward",
            "ClaimPetReward"
        }

        if remoteEvent then
            for _, cmd in ipairs(claimCommands) do
                pcall(function() remoteEvent:FireServer(cmd) end)
            end
        end

        if remoteFunc then
            for _, cmd in ipairs(claimCommands) do
                task.spawn(function()
                    pcall(function() remoteFunc:InvokeServer(cmd) end)
                end)
            end
        end
    end)

    -- 2. UI Clicker (Fallback)
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end

        local targetGuis = {}
        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "GymStarMinGui" and gui.Name ~= "Chat" then
                table.insert(targetGuis, gui)
            end
        end

        local VIM = pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager")
        local GuiService = game:GetService("GuiService")

        local function clickBtn(v)
            if typeof(firesignal) == "function" then
                pcall(function() firesignal(v.MouseButton1Click) end)
                pcall(function() firesignal(v.Activated) end)
            end

            if typeof(getconnections) == "function" then
                pcall(function()
                    for _, conn in ipairs(getconnections(v.MouseButton1Click)) do
                        if type(conn) == "table" or typeof(conn) == "RBXScriptConnection" or typeof(conn) == "UserData" then
                            if conn.Fire then pcall(function() conn:Fire() end) end
                            if conn.Function then pcall(function() conn.Function() end) end
                        end
                    end
                end)
            end

            pcall(function()
                if VIM and v.Visible then
                    local oldSelected = GuiService.SelectedObject
                    GuiService.SelectedObject = v
                    VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                    task.wait(0.02)
                    VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                    GuiService.SelectedObject = oldSelected
                end
            end)

            pcall(function() if v.Activate then v:Activate() end end)
        end

        for _, gui in ipairs(targetGuis) do
            for _, v in ipairs(gui:GetDescendants()) do
                if (v:IsA("TextButton") or v:IsA("ImageButton")) and v.Visible then
                    local name = string.lower(v.Name)
                    local text = (v:IsA("TextButton") and string.lower(v.Text)) or ""
                    if name:find("claim") or name:find("reward") or text:find("claim") or text:find("\233\162\134\229\143\150") then
                        clickBtn(v)
                    end
                end
            end
        end
    end)
end

-- ==========================================
-- TOGGLE HANDLER (Universal with Loop Tokens)
-- ==========================================
local function handleToggle(clickBtn, varName, toolName, isWeightBtn, customCallback, toggleTrack, toggleKnob, iconLabel)
    env.GymStarToggles[varName] = false
    clickBtn.MouseButton1Click:Connect(function()
        if not scriptRunning then return end

        env.GymStarToggles[varName] = not env.GymStarToggles[varName]
        local isActive = env.GymStarToggles[varName]
        local currentToken = getNextToken(varName)

        setToggleVisual(isActive, toggleTrack, toggleKnob, iconLabel)

        if isActive then
            if customCallback then
                task.spawn(function() customCallback(true, currentToken) end)
            elseif isWeightBtn then
                task.spawn(function()
                    while env.GymStarToggles[varName] and scriptRunning and activeLoopTokens[varName] == currentToken do
                        equipWeightDirect(toolName)
                        task.wait(5)
                    end
                end)
            else
                if toolName then
                    task.spawn(function() doTrainLoop(toolName) end)
                    toggleNativeAutoClick(true)
                end
                task.spawn(function()
                    while env.GymStarToggles[varName] and scriptRunning and activeLoopTokens[varName] == currentToken do
                        if toolName then
                            doTrainLoop(toolName)
                        end
                        task.wait(2)
                    end
                end)
            end
        else
            if customCallback then
                task.spawn(function() customCallback(false, currentToken) end)
            elseif not isWeightBtn and toolName then
                toggleNativeAutoClick(false)
            end
        end
    end)
end

-- ==========================================
-- APPLY TOGGLE LOGIC
-- ==========================================
handleToggle(AutoTreadmillClick, "AutoTreadmill", "Treadmill", false, nil, AutoTreadmillTrack, AutoTreadmillKnob, AutoTreadmillIcon)
handleToggle(AutoWTreadmillClick, "AutoW_Treadmill", "Treadmill", true, nil, AutoWTreadmillTrack, AutoWTreadmillKnob, AutoWTreadmillIcon)

-- Low End Graphics
handleToggle(LowEndClick, "LowEndMode", nil, false, function(state)
    if state then
        enableLowEnd()
        watchLowEndObjects()
    else
        disableLowEnd()
        stopLowEndWatcher()
    end
end, LowEndTrack, LowEndKnob, LowEndIcon)

-- Auto Click (Native)
handleToggle(AutoClickClick, "AutoClick", nil, false, function(state)
    toggleNativeAutoClick(state)
end, AutoClickTrack, AutoClickKnob, AutoClickIcon)

-- Auto Roll (Safe 1.2s delay to prevent InvokeServer disconnect)
handleToggle(AutoRollClick, "AutoRoll", nil, false, function(state, token)
    if state then
        local currentToken = token or getNextToken("AutoRoll")
        task.spawn(function()
            while env.GymStarToggles["AutoRoll"] and scriptRunning and activeLoopTokens["AutoRoll"] == currentToken do
                pcall(function()
                    game:GetService("ReplicatedStorage").Msg.RemoteFunction:InvokeServer("\230\138\189\229\143\150\229\133\137\231\142\175")
                end)
                task.wait(1.2)
            end
        end)
    end
end, AutoRollTrack, AutoRollKnob, AutoRollIcon)

-- Auto Claim Pet (Safe 5s delay)
handleToggle(AutoClaimPetClick, "AutoClaimPet", nil, false, function(state, token)
    if state then
        local currentToken = token or getNextToken("AutoClaimPet")
        task.spawn(function()
            while env.GymStarToggles["AutoClaimPet"] and scriptRunning and activeLoopTokens["AutoClaimPet"] == currentToken do
                doClaimPetQuest()
                task.wait(5)
            end
        end)
    end
end, AutoClaimPetTrack, AutoClaimPetKnob, AutoClaimPetIcon)

-- Auto Competition (Optimized)
local function stopAutoCompetition()
    if autoCompConnection then
        autoCompConnection:Disconnect()
        autoCompConnection = nil
    end
    pcall(function()
        if autoCompCachedSettlement and autoCompCachedSettlement.Parent then
            if autoCompCachedSettlement:IsA("GuiObject") then
                autoCompCachedSettlement.Visible = true
            elseif autoCompCachedSettlement:IsA("ScreenGui") then
                autoCompCachedSettlement.Enabled = true
            end
        end
    end)
    autoCompCachedSettlement = nil
end

handleToggle(AutoCompClick, "AutoCompetition", nil, false, function(state, token)
    if state then
        stopAutoCompetition()
        local currentToken = token or getNextToken("AutoCompetition")

        task.spawn(function()
            while env.GymStarToggles["AutoCompetition"] and scriptRunning and activeLoopTokens["AutoCompetition"] == currentToken do
                pcall(function()
                    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                    if playerGui then
                        local settlementGui = playerGui:FindFirstChild("Competition clearance settlement", true)
                        if settlementGui then
                            if settlementGui:IsA("GuiObject") then
                                settlementGui.Visible = false
                            elseif settlementGui:IsA("ScreenGui") then
                                settlementGui.Enabled = false
                            end
                        end
                    end

                    local rep = ReplicatedStorage
                    rep:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\229\143\130\229\138\160\230\175\148\232\181\155")
                    task.wait(0.6)
                    if not env.GymStarToggles["AutoCompetition"] or activeLoopTokens["AutoCompetition"] ~= currentToken then return end
                    rep:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\232\183\179\232\191\135\230\175\148\232\181\155")
                    task.wait(0.6)
                    if not env.GymStarToggles["AutoCompetition"] or activeLoopTokens["AutoCompetition"] ~= currentToken then return end
                    rep:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("\229\187\182\232\191\159\233\162\134\229\143\150\229\165\150\229\138\177")
                end)
                task.wait(0.8)
            end
        end)
    else
        stopAutoCompetition()
    end
end, AutoCompTrack, AutoCompKnob, AutoCompIcon)

-- Anti-AFK
local function enableAntiAFK()
    if not antiAFKConnection then
        local VIM = pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager")
        antiAFKConnection = LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
            pcall(function()
                if VIM then
                    VIM:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
                end
            end)
        end)
    end
end

handleToggle(AntiAFKClick, "AntiAFK", nil, false, function(state)
    if state then
        enableAntiAFK()
    else
        if antiAFKConnection then
            antiAFKConnection:Disconnect()
            antiAFKConnection = nil
        end
    end
end, AntiAFKTrack, AntiAFKKnob, AntiAFKIcon)

-- Cancel Button
CancelTrainBtn.MouseButton1Click:Connect(doCancelTrain)

-- ==========================================
-- AUTO START FEATURES (Staggered Execution)
-- ==========================================
local function startFeature(varName, toggleTrack, toggleKnob, iconLabel, startFn)
    if not env.GymStarToggles[varName] then
        env.GymStarToggles[varName] = true
        local token = getNextToken(varName)
        setToggleVisual(true, toggleTrack, toggleKnob, iconLabel)
        task.spawn(function()
            startFn(token)
        end)
    end
end

task.spawn(function()
    task.wait(0.5)

    -- 1. Low End Graphics
    startFeature("LowEndMode", LowEndTrack, LowEndKnob, LowEndIcon, function()
        enableLowEnd()
        watchLowEndObjects()
    end)
    task.wait(0.3)

    -- 2. Anti-AFK
    startFeature("AntiAFK", AntiAFKTrack, AntiAFKKnob, AntiAFKIcon, function()
        enableAntiAFK()
    end)
    task.wait(0.3)

    -- 3. Auto Click
    startFeature("AutoClick", AutoClickTrack, AutoClickKnob, AutoClickIcon, function()
        toggleNativeAutoClick(true)
    end)
    task.wait(0.3)

    -- 4. Auto Claim Pet
    startFeature("AutoClaimPet", AutoClaimPetTrack, AutoClaimPetKnob, AutoClaimPetIcon, function(token)
        while env.GymStarToggles["AutoClaimPet"] and scriptRunning and activeLoopTokens["AutoClaimPet"] == token do
            doClaimPetQuest()
            task.wait(5)
        end
    end)
    task.wait(0.3)

    -- 5. Auto Treadmill
    startFeature("AutoTreadmill", AutoTreadmillTrack, AutoTreadmillKnob, AutoTreadmillIcon, function(token)
        pcall(function()
            local scene = workspace:FindFirstChild("Scene")
            local folder11 = scene and scene:FindFirstChild("11")
            local eq = folder11 and folder11:FindFirstChild("Training equipment")
            local treadmillTarget = eq and eq:FindFirstChild("Conveyor2")
            if not treadmillTarget then
                treadmillTarget = workspace:WaitForChild("Scene"):WaitForChild("11"):WaitForChild("Training equipment"):WaitForChild("Conveyor2")
            end
            if treadmillTarget then
                ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):FireServer("StartTrain", treadmillTarget)
            end
        end)
        toggleNativeAutoClick(true)

        while env.GymStarToggles["AutoTreadmill"] and scriptRunning and activeLoopTokens["AutoTreadmill"] == token do
            doTrainLoop("Treadmill")
            task.wait(8)
        end
    end)
    task.wait(0.3)

    -- 6. Auto Roll
    startFeature("AutoRoll", AutoRollTrack, AutoRollKnob, AutoRollIcon, function(token)
        while env.GymStarToggles["AutoRoll"] and scriptRunning and activeLoopTokens["AutoRoll"] == token do
            pcall(function()
                game:GetService("ReplicatedStorage").Msg.RemoteFunction:InvokeServer("\230\138\189\229\143\150\229\133\137\231\142\175")
            end)
            task.wait(1.2)
        end
    end)
end)

-- ==========================================
-- CLOSE / UNLOAD SCRIPT
-- ==========================================
_G.GymStarUnload = function()
    scriptRunning = false

    for k, _ in pairs(env.GymStarToggles) do
        env.GymStarToggles[k] = false
        getNextToken(k) -- invalidate any active loops
    end
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end
    stopAutoCompetition()
    stopLowEndWatcher()
    disableLowEnd()
    doCancelTrain()
end

CloseBtn.MouseButton1Click:Connect(function()
    _G.GymStarUnload()
    if ScreenGui then
        ScreenGui:Destroy()
    end
end)
