-- =========================================================
-- NICOS NEXTBOTS PANEL - UNIFIED UTILITY SCRIPT
-- =========================================================

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

local ParentGui = (gethui and gethui()) or (syn and syn.protect_gui and syn.protect_gui(Instance.new("ScreenGui"))) or CoreGui:FindFirstChild("RobloxGui") or LocalPlayer:WaitForChild("PlayerGui")

-- Destroy previous UI instances
if ParentGui:FindFirstChild("PowerUtilityUI") then ParentGui.PowerUtilityUI:Destroy() end
if ParentGui:FindFirstChild("PowerUtilityLoader") then ParentGui.PowerUtilityLoader:Destroy() end

---------------------------------------------------------
-- GLOBAL TOGGLES & MOVEMENT SETTINGS
---------------------------------------------------------
local globalInstantPromptsEnabled = true
local autoPowerBoxSolverEnabled = false

-- Movement Settings
local moveSpeedModifier = 1.0          -- Speed Multiplier (1.0 = normal)
local slidePowerEnabled = false        -- Custom Slide Power toggle
local slidePower = 50                  -- Custom sliding velocity speed
local alwaysColaBoostEnabled = false    -- Persistent Bloxy Cola speed boost

-- Visuals & ESP Settings
local nextbotESPEnabled = false
local playerESPEnabled = false
local fullbrightEnabled = false
local autoFullbrightEnabled = false
local isFullbrightActive = false

local powerBoxEnabled = true
local trackedBoxes = {}
local storedHoldTimes = {}

-- Audio Settings
local muteBotSoundsEnabled = false
local storedBotVolumes = {}

local muteSafeBgmEnabled = false
local storedBgmVolume = nil

local silenceJumpscareEnabled = false

local oldLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd
}

---------------------------------------------------------
-- LOADER SCREEN SETUP
---------------------------------------------------------
local LoaderGui = Instance.new("ScreenGui")
LoaderGui.Name = "PowerUtilityLoader"
LoaderGui.ResetOnSpawn = false
LoaderGui.Parent = ParentGui

local LoaderFrame = Instance.new("Frame")
LoaderFrame.Size = UDim2.new(0, 260, 0, 100)
LoaderFrame.Position = UDim2.new(0.5, -130, 0.4, 0)
LoaderFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
LoaderFrame.BorderSizePixel = 0
LoaderFrame.Parent = LoaderGui

local LoaderCorner = Instance.new("UICorner")
LoaderCorner.CornerRadius = UDim.new(0, 8)
LoaderCorner.Parent = LoaderFrame

local LoaderTitle = Instance.new("TextLabel")
LoaderTitle.Size = UDim2.new(1, 0, 0, 30)
LoaderTitle.Position = UDim2.new(0, 0, 0, 8)
LoaderTitle.BackgroundTransparency = 1
LoaderTitle.Text = "Nicos Nextbots Panel"
LoaderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
LoaderTitle.Font = Enum.Font.SourceSansBold
LoaderTitle.TextSize = 16
LoaderTitle.Parent = LoaderFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 20)
StatusLabel.Position = UDim2.new(0, 10, 0, 38)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Starting up..."
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextSize = 13
StatusLabel.Parent = LoaderFrame

local ProgressBarBackground = Instance.new("Frame")
ProgressBarBackground.Size = UDim2.new(0.9, 0, 0, 8)
ProgressBarBackground.Position = UDim2.new(0.05, 0, 0, 68)
ProgressBarBackground.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
ProgressBarBackground.BorderSizePixel = 0
ProgressBarBackground.Parent = LoaderFrame

local BarCorner = Instance.new("UICorner")
BarCorner.CornerRadius = UDim.new(0, 4)
BarCorner.Parent = ProgressBarBackground

local ProgressBarFill = Instance.new("Frame")
ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
ProgressBarFill.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
ProgressBarFill.BorderSizePixel = 0
ProgressBarFill.Parent = ProgressBarBackground

local FillCorner = Instance.new("UICorner")
FillCorner.CornerRadius = UDim.new(0, 4)
FillCorner.Parent = ProgressBarFill

local function updateLoader(status, progress)
    StatusLabel.Text = status
    TweenService:Create(ProgressBarFill, TweenInfo.new(0.2), {Size = UDim2.new(progress, 0, 1, 0)}):Play()
    task.wait(0.2)
end

---------------------------------------------------------
-- PERSISTENT CHARACTER HELPERS
---------------------------------------------------------
local function getLiveCharacter()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        return char, char.HumanoidRootPart, char.Humanoid
    end
    return nil, nil, nil
end

local function applyColaBoost(char)
    if not char then return end
    if alwaysColaBoostEnabled then
        -- Toggle false -> true to force cst's AttributeChanged event to catch the signal
        task.spawn(function()
            char:SetAttribute("Colad", false)
            task.wait(0.1)
            if alwaysColaBoostEnabled and char and char.Parent then
                char:SetAttribute("Colad", true)
            end
        end)
    else
        char:SetAttribute("Colad", false)
    end
end

-- Re-apply state immediately whenever a new character loads
LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.spawn(function()
        newChar:WaitForChild("HumanoidRootPart")
        -- Wait for character scripts to load so cst is listening
        local scriptsFolder = newChar:WaitForChild("scripts", 5)
        if scriptsFolder then
            scriptsFolder:WaitForChild("cst", 5)
        end
        task.wait(0.5)
        applyColaBoost(newChar)
    end)
end)

---------------------------------------------------------
-- GLOBAL PROXIMITY PROMPT MODIFIER
---------------------------------------------------------
local function applyGlobalPromptMods(prompt)
    if prompt:IsA("ProximityPrompt") then
        if globalInstantPromptsEnabled then
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
        end
    end
end

for _, desc in ipairs(Workspace:GetDescendants()) do
    applyGlobalPromptMods(desc)
end

Workspace.DescendantAdded:Connect(applyGlobalPromptMods)

---------------------------------------------------------
-- LIGHTING & POWERBOX MODULES
---------------------------------------------------------
local function initLightingModule()
    local function applyFullbright()
        if not isFullbrightActive then
            isFullbrightActive = true
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
        end
    end

    local function restoreLighting()
        if isFullbrightActive then
            isFullbrightActive = false
            Lighting.Ambient = oldLighting.Ambient
            Lighting.OutdoorAmbient = oldLighting.OutdoorAmbient
            Lighting.Brightness = oldLighting.Brightness
            Lighting.ClockTime = oldLighting.ClockTime
            Lighting.GlobalShadows = oldLighting.GlobalShadows
            Lighting.FogEnd = oldLighting.FogEnd
        end
    end

    Lighting.Changed:Connect(function()
        if fullbrightEnabled or isFullbrightActive then
            applyFullbright()
        end
    end)

    return applyFullbright, restoreLighting
end

local applyFullbright, restoreLighting = initLightingModule()

local function getActivePrompt(box)
    for _, desc in ipairs(box:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            return desc
        end
    end
    return nil
end

local function evaluateAutoFullbright()
    if not autoFullbrightEnabled then return end
    
    local activePromptCount = 0
    for box, _ in pairs(trackedBoxes) do
        if box and box.Parent and getActivePrompt(box) then
            activePromptCount = activePromptCount + 1
        end
    end

    if activePromptCount > 0 then
        applyFullbright()
    else
        if not fullbrightEnabled then
            restoreLighting()
        end
    end
end

local function initPowerBoxModule()
    local function updatePowerBox(box)
        if not (box and box.Parent) then return end

        local prompt = getActivePrompt(box)
        local highlight = box:FindFirstChild("PowerHighlight")

        if powerBoxEnabled and prompt then
            if not storedHoldTimes[prompt] then
                storedHoldTimes[prompt] = prompt.HoldDuration
            end
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false

            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name = "PowerHighlight"
                highlight.FillColor = Color3.fromRGB(255, 215, 0)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = 0.4
                highlight.OutlineTransparency = 0
                highlight.Adornee = box
                highlight.Parent = box
            end
        else
            if highlight then
                highlight:Destroy()
            end
        end

        evaluateAutoFullbright()
    end

    local function trackPowerBox(box)
        if box.Name ~= "PowerBox" or trackedBoxes[box] then return end
        trackedBoxes[box] = true

        local function connectPrompt(prompt)
            if prompt:IsA("ProximityPrompt") then
                prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                    updatePowerBox(box)
                end)
            end
        end

        for _, desc in ipairs(box:GetDescendants()) do
            connectPrompt(desc)
        end

        box.DescendantAdded:Connect(function(child)
            connectPrompt(child)
            if child:IsA("ProximityPrompt") then
                task.defer(function() updatePowerBox(box) end)
            end
        end)

        box.DescendantRemoving:Connect(function(child)
            if child:IsA("ProximityPrompt") then
                task.defer(function() updatePowerBox(box) end)
            end
        end)

        updatePowerBox(box)
    end

    for _, item in ipairs(Workspace:GetDescendants()) do
        trackPowerBox(item)
    end

    Workspace.DescendantAdded:Connect(function(item)
        task.wait(0.1)
        trackPowerBox(item)
    end)

    return updatePowerBox
end

---------------------------------------------------------
-- WEAPON GIVER FUNCTION
---------------------------------------------------------
local function giveWeapon(weaponName)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return end

    local targetWeapon = ReplicatedStorage:FindFirstChild(weaponName, true)

    if not targetWeapon then
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            if desc.Name:lower() == weaponName:lower() and (desc:IsA("Tool") or desc:IsA("Model")) then
                targetWeapon = desc
                break
            end
        end
    end

    if targetWeapon then
        local clonedWeapon = targetWeapon:Clone()
        clonedWeapon.Parent = bp
    else
        warn("Weapon '" .. tostring(weaponName) .. "' not found in ReplicatedStorage.")
    end
end

---------------------------------------------------------
-- LOADER EXECUTION
---------------------------------------------------------
updateLoader("Loading Lighting Module...", 0.25)
task.wait(0.1)

updateLoader("Loading PowerBox ESP & Prompts...", 0.60)
local updatePowerBox = initPowerBoxModule()

updateLoader("Initializing Audio & Weapon Controls...", 0.85)
task.wait(0.1)

---------------------------------------------------------
-- TABBED UI CONSTRUCTION
---------------------------------------------------------
updateLoader("Rendering Dashboard...", 0.95)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PowerUtilityUI"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 290, 0, 310)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -35, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Nicos Nextbots Panel"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 16
TitleLabel.Parent = TitleBar

-- Minimize Button
local CollapseBtn = Instance.new("TextButton")
CollapseBtn.Size = UDim2.new(0, 24, 0, 24)
CollapseBtn.Position = UDim2.new(1, -28, 0, 4)
CollapseBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
CollapseBtn.Text = "-"
CollapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CollapseBtn.Font = Enum.Font.SourceSansBold
CollapseBtn.TextSize = 16
CollapseBtn.Parent = TitleBar

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 4)
BtnCorner.Parent = CollapseBtn

-- TAB BAR
local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -12, 0, 28)
TabBar.Position = UDim2.new(0, 6, 0, 36)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.Parent = MainFrame

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.Padding = UDim.new(0, 4)
TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabListLayout.Parent = TabBar

-- TAB CONTAINERS
local PagesContainer = Instance.new("Frame")
PagesContainer.Name = "PagesContainer"
PagesContainer.Size = UDim2.new(1, 0, 1, -68)
PagesContainer.Position = UDim2.new(0, 0, 0, 68)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame

local tabs = {}
local tabButtons = {}

local function createTab(name)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0, 70, 1, 0)
    tabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    tabBtn.Text = name
    tabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabBtn.Font = Enum.Font.SourceSansBold
    tabBtn.TextSize = 11
    tabBtn.Parent = TabBar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = tabBtn

    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.Visible = false
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = PagesContainer

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = page

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.Parent = page

    tabs[name] = page
    tabButtons[name] = tabBtn

    tabBtn.MouseButton1Click:Connect(function()
        for tName, tPage in pairs(tabs) do
            tPage.Visible = (tName == name)
            tabButtons[tName].BackgroundColor3 = (tName == name) and Color3.fromRGB(55, 55, 70) or Color3.fromRGB(35, 35, 42)
            tabButtons[tName].TextColor3 = (tName == name) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
        end
    end)

    return page
end

-- Create Pages
local autoPage = createTab("Automation")
local movePage = createTab("Movement")
local visPage = createTab("Visuals")
local espPage = createTab("Entities")
local audioPage = createTab("Audio")
local weaponPage = createTab("Weapons")

-- Default Tab Selection
tabs["Automation"].Visible = true
tabButtons["Automation"].BackgroundColor3 = Color3.fromRGB(55, 55, 70)
tabButtons["Automation"].TextColor3 = Color3.fromRGB(255, 255, 255)

-- Helper UI Creators
local function createToggleButton(parent, text, defaultState, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.92, 0, 0, 28)
    button.BackgroundColor3 = defaultState and Color3.fromRGB(46, 139, 87) or Color3.fromRGB(178, 34, 34)
    button.Text = text .. ": " .. (defaultState and "ON" or "OFF")
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSansSemibold
    button.TextSize = 12
    button.Parent = parent

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = button

    local state = defaultState
    button.MouseButton1Click:Connect(function()
        state = not state
        button.BackgroundColor3 = state and Color3.fromRGB(46, 139, 87) or Color3.fromRGB(178, 34, 34)
        button.Text = text .. ": " .. (state and "ON" or "OFF")
        callback(state)
    end)
    return button
end

local function createActionButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.92, 0, 0, 28)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSansSemibold
    button.TextSize = 12
    button.Parent = parent

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = button

    button.MouseButton1Click:Connect(callback)
    return button
end

local function createSlider(parent, text, min, max, default, unitSuffix, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.92, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
    frame.Parent = parent

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 4)
    fCorner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(default) .. unitSuffix
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 12
    label.Parent = frame

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(0.9, 0, 0, 8)
    sliderBg.Position = UDim2.new(0.05, 0, 0, 24)
    sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    sliderBg.Parent = frame

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
    sliderFill.Parent = sliderBg

    local dragging = false

    local function update(input)
        local pos = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        local val = math.floor((min + (max - min) * pos) * 10) / 10
        sliderFill.Size = UDim2.new(pos, 0, 1, 0)
        label.Text = text .. ": " .. tostring(val) .. unitSuffix
        callback(val)
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input)
        end
    end)
end

-- UI Collapse Logic
local collapsed = false
CollapseBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    PagesContainer.Visible = not collapsed
    TabBar.Visible = not collapsed
    CollapseBtn.Text = collapsed and "+" or "-"
    MainFrame.Size = collapsed and UDim2.new(0, 290, 0, 32) or UDim2.new(0, 290, 0, 310)
end)

---------------------------------------------------------
-- REGISTER UI CONTROLS IN TABS
---------------------------------------------------------

-- 1. AUTOMATION TAB
createToggleButton(autoPage, "Instant Proximity Prompts", true, function(state)
    globalInstantPromptsEnabled = state
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            if state then
                desc.HoldDuration = 0
                desc.RequiresLineOfSight = false
            end
        end
    end
end)

createToggleButton(autoPage, "Auto Solve Power Boxes", false, function(state)
    autoPowerBoxSolverEnabled = state
end)

-- 2. MOVEMENT TAB
createSlider(movePage, "Speed Multiplier", 1, 5, 1, "x", function(val)
    moveSpeedModifier = val
end)

createToggleButton(movePage, "Custom Slide Power", false, function(state)
    slidePowerEnabled = state
end)

createSlider(movePage, "Slide Power", 30, 200, 50, "", function(val)
    slidePower = val
end)

createToggleButton(movePage, "Permanent Cola Boost", false, function(state)
    alwaysColaBoostEnabled = state
    local char = LocalPlayer.Character
    if char then
        applyColaBoost(char)
    end
end)

-- 3. VISUALS TAB
createToggleButton(visPage, "PowerBox ESP", true, function(state)
    powerBoxEnabled = state
    for box, _ in pairs(trackedBoxes) do
        if box and box.Parent then
            updatePowerBox(box)
        end
    end
end)

createToggleButton(visPage, "Fullbright Lighting", false, function(state)
    fullbrightEnabled = state
    if state then
        applyFullbright()
    elseif not autoFullbrightEnabled then
        restoreLighting()
    end
end)

createToggleButton(visPage, "Smart Fullbright (On Box)", false, function(state)
    autoFullbrightEnabled = state
    if state then
        evaluateAutoFullbright()
    elseif not fullbrightEnabled then
        restoreLighting()
    end
end)

-- 4. ENTITIES TAB
createToggleButton(espPage, "Nextbot UI Markers", false, function(state)
    nextbotESPEnabled = state
end)

createToggleButton(espPage, "Player Highlights", false, function(state)
    playerESPEnabled = state
end)

-- 5. AUDIO TAB
createToggleButton(audioPage, "Silence Jumpscare", false, function(state)
    silenceJumpscareEnabled = state
end)

createToggleButton(audioPage, "Mute Bot Sounds", false, function(state)
    muteBotSoundsEnabled = state
    if not state then
        for sound, vol in pairs(storedBotVolumes) do
            if sound and sound.Parent then
                sound.Volume = vol
            end
        end
        storedBotVolumes = {}
    end
end)

createToggleButton(audioPage, "Mute Safe BGM", false, function(state)
    muteSafeBgmEnabled = state
    if not state and storedBgmVolume ~= nil then
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local safe = (pGui and pGui:FindFirstChild("safe")) or StarterGui:FindFirstChild("safe")
        if safe then
            local bgm = safe:FindFirstChild("bgm")
            if bgm then bgm.Volume = storedBgmVolume end
        end
        storedBgmVolume = nil
    end
end)

-- 6. WEAPONS TAB
local weaponsList = {"AK-47", "AssaultRifle", "Handgun", "M4A1", "Minigun"}
for _, gunName in ipairs(weaponsList) do
    createActionButton(weaponPage, "Give " .. gunName, function()
        giveWeapon(gunName)
    end)
end

---------------------------------------------------------
-- FINALIZE & DESTROY LOADER
---------------------------------------------------------
updateLoader("Done!", 1.0)
task.wait(0.2)

ScreenGui.Parent = ParentGui
LoaderGui:Destroy()

---------------------------------------------------------
-- BACKGROUND LOOP WORKER
---------------------------------------------------------
RunService.Heartbeat:Connect(function()
    local char, hrp, hum = getLiveCharacter()
    if not (char and hrp and hum) then return end

    -- Continuously check Bloxy Cola attribute
    if alwaysColaBoostEnabled and not char:GetAttribute("Colad") then
        applyColaBoost(char)
    end

    -- Speed Multiplier Handling
    if moveSpeedModifier > 1.0 then
        local scriptsFolder = char:FindFirstChild("scripts")
        local isRunning = scriptsFolder and scriptsFolder:FindFirstChild("running") and scriptsFolder.running.Value
        local isCrouching = scriptsFolder and scriptsFolder:FindFirstChild("crouching") and scriptsFolder.crouching.Value

        local baseSpeed = 10
        if isRunning then
            baseSpeed = 30
        elseif isCrouching then
            baseSpeed = 5
        end

        if char:GetAttribute("Colad") then
            baseSpeed = baseSpeed * 1.5
        end

        hum.WalkSpeed = baseSpeed * moveSpeedModifier
    end

    -- Custom Slide Power Continuous Velocity Controller
    if slidePowerEnabled then
        local scriptsFolder = char:FindFirstChild("scripts")
        if scriptsFolder then
            local sliding = scriptsFolder:FindFirstChild("sliding")
            if sliding and sliding.Value then
                local moveDir = hum.MoveDirection
                if moveDir.Magnitude == 0 then
                    moveDir = (CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
                else
                    moveDir = moveDir.Unit
                end

                if moveDir.Magnitude > 0 then
                    local currentVel = hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        moveDir.X * slidePower,
                        currentVel.Y,
                        moveDir.Z * slidePower
                    )
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)

        local char, hrp, hum = getLiveCharacter()

        -- NEXTBOT WORLD UI MARKERS
        local botsFolder = Workspace:FindFirstChild("bots")
        if botsFolder then
            for _, bot in ipairs(botsFolder:GetChildren()) do
                local targetHitbox = bot:FindFirstChild("hitbox") or bot:FindFirstChild("Hitbox") or bot.PrimaryPart
                if targetHitbox then
                    local gui = targetHitbox:FindFirstChild("NextbotMarkerUI")
                    if nextbotESPEnabled then
                        if not gui then
                            gui = Instance.new("BillboardGui")
                            gui.Name = "NextbotMarkerUI"
                            gui.AlwaysOnTop = true
                            gui.Size = UDim2.new(0, 120, 0, 45)
                            gui.StudsOffset = Vector3.new(0, 2, 0)
                            gui.Adornee = targetHitbox

                            local frame = Instance.new("Frame")
                            frame.Size = UDim2.new(1, 0, 1, 0)
                            frame.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
                            frame.BackgroundTransparency = 0.3
                            frame.BorderSizePixel = 0
                            frame.Parent = gui

                            local fCorner = Instance.new("UICorner")
                            fCorner.CornerRadius = UDim.new(0, 6)
                            fCorner.Parent = frame

                            local nameLabel = Instance.new("TextLabel")
                            nameLabel.Name = "BotName"
                            nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
                            nameLabel.BackgroundTransparency = 1
                            nameLabel.Text = bot.Name
                            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                            nameLabel.Font = Enum.Font.SourceSansBold
                            nameLabel.TextSize = 13
                            nameLabel.Parent = frame

                            local distLabel = Instance.new("TextLabel")
                            distLabel.Name = "BotDistance"
                            distLabel.Size = UDim2.new(1, 0, 0.5, 0)
                            distLabel.Position = UDim2.new(0, 0, 0.5, 0)
                            distLabel.BackgroundTransparency = 1
                            distLabel.Text = "0m"
                            distLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
                            distLabel.Font = Enum.Font.SourceSans
                            distLabel.TextSize = 12
                            distLabel.Parent = frame

                            gui.Parent = targetHitbox
                        end

                        if hrp then
                            local dist = math.floor((hrp.Position - targetHitbox.Position).Magnitude)
                            local frame = gui:FindFirstChild("Frame")
                            if frame then
                                local distLabel = frame:FindFirstChild("BotDistance")
                                if distLabel then
                                    distLabel.Text = tostring(dist) .. "m"
                                end
                            end
                        end
                    else
                        if gui then gui:Destroy() end
                    end
                end
            end
        end

        -- PLAYER HIGHLIGHTS
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hl = plr.Character:FindFirstChild("PlayerHighlight")
                if playerESPEnabled then
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "PlayerHighlight"
                        hl.FillColor = Color3.fromRGB(30, 255, 100)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.5
                        hl.Adornee = plr.Character
                        hl.Parent = plr.Character
                    end
                else
                    if hl then hl:Destroy() end
                end
            end
        end

        -- Silence Jumpscares
        if silenceJumpscareEnabled then
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            if pGui then
                local jumpscare = pGui:FindFirstChild("jumpscare")
                if jumpscare then
                    for _, desc in ipairs(jumpscare:GetDescendants()) do
                        if (desc.Name == "boom" or desc.Name == "sfx") and desc:IsA("Sound") then
                            desc.Volume = 0
                        end
                    end
                end
            end
        end

        -- Auto PowerBox Solver
        if autoPowerBoxSolverEnabled and hrp and hum and hum.Health > 0 then
            for box, _ in pairs(trackedBoxes) do
                if box and box.Parent then
                    local prompt = getActivePrompt(box)
                    if prompt and prompt.Enabled then
                        prompt.RequiresLineOfSight = false
                        prompt.HoldDuration = 0

                        local targetPart = box:IsA("BasePart") and box or box:FindFirstChildWhichIsA("BasePart") or box.PrimaryPart
                        if targetPart then
                            hrp.CFrame = targetPart.CFrame * CFrame.new(0, 0, 3)
                            task.wait(0.1)

                            CurrentCamera.CFrame = CFrame.new(CurrentCamera.CFrame.Position, targetPart.Position)
                            task.wait(0.1)

                            if fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                prompt:InputHoldBegin()
                                task.wait(0.05)
                                prompt:InputHoldEnd()
                            end
                            task.wait(0.3)
                        end
                    end
                end
            end
        end

        -- Mute Bot Sounds
        if muteBotSoundsEnabled then
            if botsFolder then
                for _, bot in ipairs(botsFolder:GetChildren()) do
                    local botHrp = bot:FindFirstChild("HumanoidRootPart")
                    if botHrp then
                        for _, sound in ipairs(botHrp:GetChildren()) do
                            if sound:IsA("Sound") then
                                if not storedBotVolumes[sound] then
                                    storedBotVolumes[sound] = sound.Volume
                                end
                                sound.Volume = 0
                            end
                        end
                    end
                end
            end
        end

        -- Mute Safe BGM
        if muteSafeBgmEnabled then
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local safe = (pGui and pGui:FindFirstChild("safe")) or StarterGui:FindFirstChild("safe")
            if safe then
                local bgm = safe:FindFirstChild("bgm")
                if bgm and bgm:IsA("Sound") then
                    if storedBgmVolume == nil then
                        storedBgmVolume = bgm.Volume
                    end
                    bgm.Volume = 0
                end
            end
        end
    end
end)