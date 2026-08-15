local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Cleanup old GUI if re-executed
local existingGui = localPlayer:WaitForChild("PlayerGui"):FindFirstChild("DevControlMenu")
if existingGui then existingGui:Destroy() end

-- ==================== STATE & SETTINGS ====================
local state = {
    bring = false,
    farm = false,
    aim = false,
    autoBringSolo = false,
    noSpeedPenalty = false,
    noAimRequired = false,
    infiniteLemonade = false,
    noAttackCooldown = false,
    fakeBlock = false,             -- Fake Block state
    permanentSabreBuff = false,    -- Auto Charge Loop state
    sabreSpamAttack = false,       -- Auto Sabre Attack state
    removeSabreEffects = false,    -- Mute Sabre sounds & visual effects
    noChargeLimit = false,         -- Remove Charge Cooldown state
}

local settings = {
    bringDistance = 4,
    farmPosition = Vector3.new(0, -400, 0),
    lemonadeSpeed = 25,
    sabreBuffInterval = 0.05,      -- Interval for Auto Charge Loop
    sabreSpamInterval = 0.01,      -- Interval for Sabre attack spam
}

local binds = {
    bring = Enum.KeyCode.Unknown,
    farm = Enum.KeyCode.Unknown,
    aim = Enum.KeyCode.Unknown,
    autoBringSolo = Enum.KeyCode.Unknown,
    noSpeedPenalty = Enum.KeyCode.Unknown,
    noAimRequired = Enum.KeyCode.Unknown,
    infiniteLemonade = Enum.KeyCode.Unknown,
    noAttackCooldown = Enum.KeyCode.Unknown,
    fakeBlock = Enum.KeyCode.Unknown,
    permanentSabreBuff = Enum.KeyCode.Unknown,
    sabreSpamAttack = Enum.KeyCode.Unknown,
    removeSabreEffects = Enum.KeyCode.Unknown,
    noChargeLimit = Enum.KeyCode.Unknown,
}

local connections = {}
local bindingTarget = nil
local farmBoxModel = nil
local isMouseDown = false
local lastMeleeSwitchAttempt = 0

local farmStructureParts = {
    { name = "Part",       position = Vector3.new(-14, 22, -5),  size = Vector3.new(42, 42, 6),  canCollide = true  },
    { name = "Player pos", position = Vector3.new(-13, 26, 13), size = Vector3.new(2, 2, 2),   canCollide = false },
    { name = "Part",       position = Vector3.new(-14, 4, 13),  size = Vector3.new(30, 6, 30), canCollide = true  },
    { name = "Part",       position = Vector3.new(-32, 22, 13), size = Vector3.new(6, 42, 30), canCollide = true  },
    { name = "Part",       position = Vector3.new(4, 22, 13),   size = Vector3.new(6, 42, 30), canCollide = true  },
    { name = "Part",       position = Vector3.new(-14, 40, 13), size = Vector3.new(30, 6, 30), canCollide = true  },
    { name = "Part",       position = Vector3.new(-14, 22, 31), size = Vector3.new(42, 42, 6), canCollide = true  },
}

-- Reset remote cache automatically when character respawns
local cachedSabreRemote = nil
localPlayer.CharacterAdded:Connect(function()
    cachedSabreRemote = nil
end)

-- ==================== HELPER FUNCTIONS ====================

local function checkForCuirassiers()
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return false end

    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        local humanoid = enemy:FindFirstChildOfClass("Humanoid")
        local isAlive = not humanoid or humanoid.Health > 0
        if isAlive and string.find(enemy.Name:lower(), "cuirassier") then
            return true
        end
    end
    return false
end

-- 1. FAKE BLOCK FUNCTION
local lastFakeBlockFired = 0
local function applyFakeBlock()
    if not state.fakeBlock then return end
    local char = localPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    local remote = tool:FindFirstChild("RemoteEvent")
    if remote and (tick() - lastFakeBlockFired >= 0.1) then
        lastFakeBlockFired = tick()
        remote:FireServer(nil, "Block")
    end
end

-- 2. SABRE REMOTE RESOLVER
local function getSabreRemote()
    local char = localPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and child:FindFirstChild("RemoteEvent") then
                cachedSabreRemote = child.RemoteEvent
                return cachedSabreRemote
            end
        end
    end

    local backpack = localPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") and child:FindFirstChild("RemoteEvent") then
                cachedSabreRemote = child.RemoteEvent
                return cachedSabreRemote
            end
        end
    end

    if cachedSabreRemote and cachedSabreRemote.Parent and cachedSabreRemote:IsDescendantOf(game) then
        return cachedSabreRemote
    end

    cachedSabreRemote = nil

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and (obj.Name == "RemoteEvent" or obj.Name:lower():find("sabre") or obj.Name:lower():find("charge")) then
            cachedSabreRemote = obj
            return cachedSabreRemote
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "RemoteEvent" then
            cachedSabreRemote = obj
            return cachedSabreRemote
        end
    end

    return nil
end

-- 3. AUTO CHARGE LOOP
local lastSabreBuffFired = 0
local function applySabreBuffLoop()
    if not state.permanentSabreBuff then return end
    
    if (tick() - lastSabreBuffFired >= settings.sabreBuffInterval) then
        if not checkForCuirassiers() then
            local remote = getSabreRemote()
            if remote then
                lastSabreBuffFired = tick()
                pcall(function() remote:FireServer(nil, "Charge") end)
            end
        end
    end
end

-- 4. AUTO SABRE ATTACK
local lastSabreSpamFired = 0
local function applySabreSpamAttack()
    if not state.sabreSpamAttack then return end
    
    local char = localPlayer.Character
    if not char then return end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local remote = tool:FindFirstChild("RemoteEvent")
        if remote and (tick() - lastSabreSpamFired >= settings.sabreSpamInterval) then
            lastSabreSpamFired = tick()
            remote:FireServer(nil, "Stab")
        end
    end
end

-- 5. MUTE SABRE AUDIO/FX
local function applyRemoveSabreEffects()
    if not state.removeSabreEffects then return end
    
    local char = localPlayer.Character
    if not char then return end

    local targets = {char, localPlayer:FindFirstChild("Backpack")}
    for _, container in ipairs(targets) do
        if container then
            for _, obj in ipairs(container:GetDescendants()) do
                if obj:IsA("Sound") then
                    local sName = obj.Name:lower()
                    if sName:find("charge") or sName:find("bugle") or sName:find("whistle") or sName:find("yell") or obj.SoundId:find("93016499788529") then
                        obj:Stop()
                        obj.Volume = 0
                    end
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
                    local pName = obj.Name:lower()
                    if pName:find("charge") or pName:find("buff") or pName:find("aura") or pName:find("effect") then
                        obj.Enabled = false
                    end
                elseif obj:IsA("Highlight") or obj:IsA("Light") then
                    local pName = obj.Name:lower()
                    if pName:find("charge") or pName:find("buff") then
                        obj.Enabled = false
                    end
                end
            end
        end
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if track.Animation then
                    local animId = tostring(track.Animation.AnimationId)
                    local trackName = track.Name:lower()
                    if animId:find("93016499788529") or trackName:find("charge") then
                        track:Stop()
                    end
                end
            end
        end
    end
end

-- 6. REMOVE CHARGE COOLDOWN (Hides UI Cooldown Timer & allows manual charge without 30s delay)
local function applyNoChargeLimit()
    if not state.noChargeLimit then return end
    
    local pGui = localPlayer:FindFirstChild("PlayerGui")
    if pGui then
        local carbineGui = pGui:FindFirstChild("CarbineInputGui")
        if carbineGui then
            for _, desc in ipairs(carbineGui:GetDescendants()) do
                if desc:IsA("TextLabel") then
                    desc.Visible = false
                end
            end
        end
    end
end

-- SMART WEAPON ROUTINE (Heavy Sabre Priority vs. Carbine Melee Override)
local function handleWeaponAndAttack()
    local char = localPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    local backpack = localPlayer:FindFirstChild("Backpack")

    local cuirassierPresent = checkForCuirassiers()

    if cuirassierPresent then
        local carbine = char:FindFirstChild("Carbine") or (backpack and backpack:FindFirstChild("Carbine"))
        if carbine then
            if carbine.Parent == backpack then
                humanoid:EquipTool(carbine)
            end

            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                local isMeleeActive = false
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    if track.Animation then
                        local animId = tostring(track.Animation.AnimationId)
                        if animId:find("136754430023345") or animId:find("128892162720625") then
                            isMeleeActive = true
                            break
                        end
                    end
                end

                if not isMeleeActive and (tick() - lastMeleeSwitchAttempt >= 0.5) then
                    lastMeleeSwitchAttempt = tick()
                    pcall(function()
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                        task.wait(0.02)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                    end)
                end
            end

            local remote = carbine:FindFirstChild("RemoteEvent")
            if remote then
                remote:FireServer(nil, "Stab")
            end
        end
    else
        local sabreTool = char:FindFirstChild("Heavy Sabre") 
            or char:FindFirstChild("Sabre") 
            or char:FindFirstChild("Officer Sabre")

        if not sabreTool and backpack then
            sabreTool = backpack:FindFirstChild("Heavy Sabre") 
                or backpack:FindFirstChild("Sabre") 
                or backpack:FindFirstChild("Officer Sabre")
            if sabreTool then
                humanoid:EquipTool(sabreTool)
            end
        end

        if not sabreTool then
            sabreTool = char:FindFirstChildOfClass("Tool")
        end

        if sabreTool then
            local remote = sabreTool:FindFirstChild("RemoteEvent") or getSabreRemote()
            if remote then
                pcall(function()
                    remote:FireServer(nil, "Charge")
                    remote:FireServer(nil, "Stab")
                end)
            end
        end
    end
end

-- ==================== WEAPON & BUFF LOOPS ====================

local function applySpeedModifiers()
    local char = localPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    if state.infiniteLemonade or char:FindFirstChild("LemonadeBuffScript") then
        humanoid.WalkSpeed = settings.lemonadeSpeed
    elseif state.noSpeedPenalty then
        humanoid.WalkSpeed = 16
    end
end

local function applyFastAttack()
    if not (state.farm or state.noAttackCooldown or state.sabreSpamAttack) then return end
    local char = localPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local tracks = animator:GetPlayingAnimationTracks()
    for _, track in ipairs(tracks) do
        if track.Animation then
            local animId = tostring(track.Animation.AnimationId)
            local trackName = track.Name:lower()
            if animId:find("100682940298160") or animId:find("129685277572999") 
               or animId:find("90461985574355") or animId:find("126840747533828") 
               or animId:find("120459288888895") or animId:find("109299741802024") 
               or trackName:find("stab") or trackName:find("attack") then
                track:Stop()
            end
        end
    end
end

local lastLemonadeDrink = 0
local function applyInfiniteLemonade()
    if not state.infiniteLemonade then return end
    
    local char = localPlayer.Character
    if char then
        if not char:FindFirstChild("LemonadeBuffScript") then
            local dummyBuff = Instance.new("Folder")
            dummyBuff.Name = "LemonadeBuffScript"
            dummyBuff.Parent = char
        end

        if not char:FindFirstChild("BackpackScript") then
            local dummyBackpack = Instance.new("Folder")
            dummyBackpack.Name = "BackpackScript"
            dummyBackpack.Parent = char
        end
    end

    if tick() - lastLemonadeDrink >= 0.5 then
        lastLemonadeDrink = tick()
        local backpack = localPlayer:FindFirstChild("Backpack")
        
        local lemonade = (char and char:FindFirstChild("Lemonade")) or (backpack and backpack:FindFirstChild("Lemonade"))
        if lemonade then
            local remote = lemonade:FindFirstChild("RemoteEvent")
            if remote then remote:FireServer() end
        end
    end
end

local function applyHoldStab()
    if not isMouseDown then return end
    local char = localPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local remote = tool:FindFirstChild("RemoteEvent")
        if remote then remote:FireServer(nil, "Stab") end
    end
end

RunService.RenderStepped:Connect(function()
    applySpeedModifiers()
    applyInfiniteLemonade()
    applyFastAttack()
    applyHoldStab()
    applyFakeBlock()
    applySabreBuffLoop()
    applySabreSpamAttack()
    applyRemoveSabreEffects()
    applyNoChargeLimit()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = false
    end
end)

local function handleNoAimShooting(input, gameProcessed)
    if gameProcessed or not state.noAimRequired then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local char = localPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            local remote = tool:FindFirstChild("RemoteEvent")
            local ammo = tool:FindFirstChild("Ammo")
            if remote and ammo and ammo.Value >= 1 then
                local camCF = camera.CFrame
                remote:FireServer(Ray.new(camCF.Position, camCF.LookVector * 250, RaycastParams.new()), "Shoot")
            end
        end
    end
end

UserInputService.InputBegan:Connect(handleNoAimShooting)

-- ==================== BOX CREATOR & CORE FUNCTIONS ====================

local function createFarmBox(basePosition)
    if farmBoxModel then farmBoxModel:Destroy() end

    farmBoxModel = Instance.new("Model")
    farmBoxModel.Name = "FarmBoxStructure"

    local playerTargetPos = basePosition + Vector3.new(-13, 26, 13)

    for _, wall in ipairs(farmStructureParts) do
        local part = Instance.new("Part")
        part.Name = wall.name
        part.Size = wall.size
        part.CFrame = CFrame.new(basePosition + wall.position)
        part.Anchored = true
        part.CanCollide = wall.canCollide
        part.Color = Color3.fromRGB(45, 45, 55)
        part.Transparency = (wall.name == "Player pos") and 1 or 0.3
        part.Material = Enum.Material.SmoothPlastic
        part.Parent = farmBoxModel

        if wall.name == "Player pos" then playerTargetPos = part.Position end
    end

    farmBoxModel.Parent = workspace
    return playerTargetPos
end

local function removeFarmBox()
    if farmBoxModel then
        farmBoxModel:Destroy()
        farmBoxModel = nil
    end
end

local function disableCollision(enemy)
    if enemy:IsA("BasePart") then
        enemy.CanCollide = false
    elseif enemy:IsA("Model") then
        for _, part in ipairs(enemy:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end

local function getAliveTeamCount()
    local aliveTeam = Teams:FindFirstChild("Alive")
    if aliveTeam then return #aliveTeam:GetPlayers() end

    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Team and string.lower(player.Team.Name) == "alive" then
            count = count + 1
        end
    end
    return count
end

local function updateEnemiesPosition()
    local character = localPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = character.HumanoidRootPart
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return end

    local targetCFrame = hrp.CFrame * CFrame.new(0, 0, -settings.bringDistance)
    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        disableCollision(enemy)
        if enemy:IsA("Model") then
            enemy:PivotTo(targetCFrame)
        elseif enemy:IsA("BasePart") then
            enemy.CFrame = targetCFrame
        end
    end
end

local function getClosestEnemyToMouse()
    local mousePos = UserInputService:GetMouseLocation()
    local closestTarget = nil
    local shortestDistance = math.huge
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        local targetPart = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart") or (enemy:IsA("BasePart") and enemy)
        local humanoid = enemy:FindFirstChildOfClass("Humanoid")
        
        if targetPart and (not humanoid or humanoid.Health > 0) then
            local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    closestTarget = targetPart
                end
            end
        end
    end
    return closestTarget
end

local function updateAimAssist()
    local target = getClosestEnemyToMouse()
    if target then camera.CFrame = CFrame.lookAt(camera.CFrame.Position, target.Position) end
end

local function farmLoop()
    handleWeaponAndAttack()

    VirtualUser:Button1Down(Vector2.new(0, 0))
    task.wait(0.01)
    VirtualUser:Button1Up(Vector2.new(0, 0))
end

local function updateAutoBringSolo()
    if getAliveTeamCount() == 1 then updateEnemiesPosition() end
end

-- ==================== TOGGLE HANDLERS ====================

local updateUIButtons

local function toggleBring(forceState)
    state.bring = (forceState ~= nil) and forceState or not state.bring
    if connections.bring then connections.bring:Disconnect() connections.bring = nil end
    if state.bring then connections.bring = RunService.RenderStepped:Connect(updateEnemiesPosition) end
    if updateUIButtons then updateUIButtons() end
end

local function toggleFarm(forceState)
    state.farm = (forceState ~= nil) and forceState or not state.farm
    if connections.farmLoop then connections.farmLoop:Disconnect() connections.farmLoop = nil end

    if state.farm then
        local targetPos = createFarmBox(settings.farmPosition)
        local char = localPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(targetPos) end
        toggleBring(true)
        connections.farmLoop = RunService.RenderStepped:Connect(farmLoop)
    else
        removeFarmBox()
        toggleBring(false)
    end
    if updateUIButtons then updateUIButtons() end
end

local function toggleAim(forceState)
    state.aim = (forceState ~= nil) and forceState or not state.aim
    if connections.aim then connections.aim:Disconnect() connections.aim = nil end
    if state.aim then connections.aim = RunService.RenderStepped:Connect(updateAimAssist) end
    if updateUIButtons then updateUIButtons() end
end

local function toggleAutoBringSolo(forceState)
    state.autoBringSolo = (forceState ~= nil) and forceState or not state.autoBringSolo
    if connections.autoBringSolo then connections.autoBringSolo:Disconnect() connections.autoBringSolo = nil end
    if state.autoBringSolo then connections.autoBringSolo = RunService.RenderStepped:Connect(updateAutoBringSolo) end
    if updateUIButtons then updateUIButtons() end
end

local function toggleNoSpeedPenalty(forceState)
    state.noSpeedPenalty = (forceState ~= nil) and forceState or not state.noSpeedPenalty
    if updateUIButtons then updateUIButtons() end
end

local function toggleNoAimRequired(forceState)
    state.noAimRequired = (forceState ~= nil) and forceState or not state.noAimRequired
    if updateUIButtons then updateUIButtons() end
end

local function toggleInfiniteLemonade(forceState)
    state.infiniteLemonade = (forceState ~= nil) and forceState or not state.infiniteLemonade
    if not state.infiniteLemonade then
        local char = localPlayer.Character
        if char then
            local buffScript = char:FindFirstChild("LemonadeBuffScript")
            if buffScript then buffScript:Destroy() end
            local backpackScript = char:FindFirstChild("BackpackScript")
            if backpackScript then backpackScript:Destroy() end
        end
    end
    if updateUIButtons then updateUIButtons() end
end

local function toggleNoAttackCooldown(forceState)
    state.noAttackCooldown = (forceState ~= nil) and forceState or not state.noAttackCooldown
    if updateUIButtons then updateUIButtons() end
end

local function toggleFakeBlock(forceState)
    state.fakeBlock = (forceState ~= nil) and forceState or not state.fakeBlock
    if not state.fakeBlock then
        local char = localPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        local remote = tool and tool:FindFirstChild("RemoteEvent")
        if remote then remote:FireServer(nil, "Unblock") end
    end
    if updateUIButtons then updateUIButtons() end
end

local function togglePermanentSabreBuff(forceState)
    state.permanentSabreBuff = (forceState ~= nil) and forceState or not state.permanentSabreBuff
    if updateUIButtons then updateUIButtons() end
end

local function toggleSabreSpamAttack(forceState)
    state.sabreSpamAttack = (forceState ~= nil) and forceState or not state.sabreSpamAttack
    if updateUIButtons then updateUIButtons() end
end

local function toggleRemoveSabreEffects(forceState)
    state.removeSabreEffects = (forceState ~= nil) and forceState or not state.removeSabreEffects
    if updateUIButtons then updateUIButtons() end
end

local function toggleNoChargeLimit(forceState)
    state.noChargeLimit = (forceState ~= nil) and forceState or not state.noChargeLimit
    if updateUIButtons then updateUIButtons() end
end

-- ==================== GUI BUILDING ====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DevControlMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local loadingFrame = Instance.new("Frame")
loadingFrame.Name = "LoadingFrame"
loadingFrame.Size = UDim2.new(0, 250, 0, 110)
loadingFrame.Position = UDim2.new(0.5, -125, 0.4, 0)
loadingFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
loadingFrame.BorderSizePixel = 0
loadingFrame.Parent = screenGui

local loadingCorner = Instance.new("UICorner")
loadingCorner.CornerRadius = UDim.new(0, 8)
loadingCorner.Parent = loadingFrame

local loadingTitle = Instance.new("TextLabel")
loadingTitle.Text = "Loading Bots and Muskets..."
loadingTitle.Size = UDim2.new(1, 0, 0, 40)
loadingTitle.Position = UDim2.new(0, 0, 0, 10)
loadingTitle.BackgroundTransparency = 1
loadingTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
loadingTitle.Font = Enum.Font.SourceSansBold
loadingTitle.TextSize = 16
loadingTitle.Parent = loadingFrame

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(0.85, 0, 0, 8)
barBg.Position = UDim2.new(0.075, 0, 0.65, 0)
barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
barBg.BorderSizePixel = 0
barBg.Parent = loadingFrame

local barBgCorner = Instance.new("UICorner")
barBgCorner.CornerRadius = UDim.new(0, 4)
barBgCorner.Parent = barBg

local progressBar = Instance.new("Frame")
progressBar.Size = UDim2.new(0, 0, 1, 0)
progressBar.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
progressBar.BorderSizePixel = 0
progressBar.Parent = barBg

local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(0, 4)
progressCorner.Parent = progressBar

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 310, 0, 480)
mainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Visible = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 35)
header.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 8)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Text = "  Bots and Muskets Menu"
title.Size = UDim2.new(1, -40, 1, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.Parent = header

local collapseBtn = Instance.new("TextButton")
collapseBtn.Text = "-"
collapseBtn.Size = UDim2.new(0, 30, 0, 25)
collapseBtn.Position = UDim2.new(1, -33, 0, 5)
collapseBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
collapseBtn.Font = Enum.Font.SourceSansBold
collapseBtn.TextSize = 18
collapseBtn.Parent = header

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 4)
btnCorner.Parent = collapseBtn

local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, 0, 0, 30)
tabBar.Position = UDim2.new(0, 0, 0, 35)
tabBar.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local tabCombatBtn = Instance.new("TextButton")
tabCombatBtn.Size = UDim2.new(0.25, 0, 1, 0)
tabCombatBtn.BackgroundTransparency = 1
tabCombatBtn.Text = "Combat"
tabCombatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tabCombatBtn.Font = Enum.Font.SourceSansBold
tabCombatBtn.TextSize = 12
tabCombatBtn.Parent = tabBar

local tabFarmingBtn = Instance.new("TextButton")
tabFarmingBtn.Size = UDim2.new(0.25, 0, 1, 0)
tabFarmingBtn.Position = UDim2.new(0.25, 0, 0, 0)
tabFarmingBtn.BackgroundTransparency = 1
tabFarmingBtn.Text = "Farming"
tabFarmingBtn.TextColor3 = Color3.fromRGB(140, 140, 150)
tabFarmingBtn.Font = Enum.Font.SourceSansBold
tabFarmingBtn.TextSize = 12
tabFarmingBtn.Parent = tabBar

local tabWeaponsBtn = Instance.new("TextButton")
tabWeaponsBtn.Size = UDim2.new(0.25, 0, 1, 0)
tabWeaponsBtn.Position = UDim2.new(0.5, 0, 0, 0)
tabWeaponsBtn.BackgroundTransparency = 1
tabWeaponsBtn.Text = "Weapons"
tabWeaponsBtn.TextColor3 = Color3.fromRGB(140, 140, 150)
tabWeaponsBtn.Font = Enum.Font.SourceSansBold
tabWeaponsBtn.TextSize = 12
tabWeaponsBtn.Parent = tabBar

local tabSettingsBtn = Instance.new("TextButton")
tabSettingsBtn.Size = UDim2.new(0.25, 0, 1, 0)
tabSettingsBtn.Position = UDim2.new(0.75, 0, 0, 0)
tabSettingsBtn.BackgroundTransparency = 1
tabSettingsBtn.Text = "Settings"
tabSettingsBtn.TextColor3 = Color3.fromRGB(140, 140, 150)
tabSettingsBtn.Font = Enum.Font.SourceSansBold
tabSettingsBtn.TextSize = 12
tabSettingsBtn.Parent = tabBar

local tabIndicator = Instance.new("Frame")
tabIndicator.Size = UDim2.new(0.25, 0, 0, 2)
tabIndicator.Position = UDim2.new(0, 0, 1, -2)
tabIndicator.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
tabIndicator.BorderSizePixel = 0
tabIndicator.Parent = tabBar

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(1, 0, 1, -65)
container.Position = UDim2.new(0, 0, 0, 65)
container.BackgroundTransparency = 1
container.Parent = mainFrame

local tabs = {
    Combat = Instance.new("Frame"),
    Farming = Instance.new("Frame"),
    Weapons = Instance.new("Frame"),
    Settings = Instance.new("Frame")
}

for name, frame in pairs(tabs) do
    frame.Name = name .. "Tab"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = (name == "Combat")
    frame.Parent = container

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.Parent = frame
end

local function switchTab(tabName)
    local tabBtns = {
        Combat = tabCombatBtn, 
        Farming = tabFarmingBtn, 
        Weapons = tabWeaponsBtn, 
        Settings = tabSettingsBtn
    }
    local tabPositions = {Combat = 0, Farming = 0.25, Weapons = 0.5, Settings = 0.75}

    for name, frame in pairs(tabs) do
        frame.Visible = (name == tabName)
        tabBtns[name].TextColor3 = (name == tabName) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 150)
    end

    TweenService:Create(tabIndicator, TweenInfo.new(0.2), {Position = UDim2.new(tabPositions[tabName], 0, 1, -2)}):Play()
end

tabCombatBtn.MouseButton1Click:Connect(function() switchTab("Combat") end)
tabFarmingBtn.MouseButton1Click:Connect(function() switchTab("Farming") end)
tabWeaponsBtn.MouseButton1Click:Connect(function() switchTab("Weapons") end)
tabSettingsBtn.MouseButton1Click:Connect(function() switchTab("Settings") end)

local function createRow(parent, name, key, layoutOrder, toggleFunc)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(0.92, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    row.BorderSizePixel = 0
    row.LayoutOrder = layoutOrder
    row.Parent = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.65, 0, 1, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text = name .. ": OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(200, 80, 80)
    toggleBtn.Font = Enum.Font.SourceSansSemibold
    toggleBtn.TextSize = 13
    toggleBtn.Parent = row

    local bindBtn = Instance.new("TextButton")
    bindBtn.Size = UDim2.new(0.3, 0, 0.7, 0)
    bindBtn.Position = UDim2.new(0.67, 0, 0.15, 0)
    bindBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
    bindBtn.Text = "[" .. ((binds[key] and binds[key] ~= Enum.KeyCode.Unknown) and binds[key].Name or "None") .. "]"
    bindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    bindBtn.Font = Enum.Font.SourceSans
    bindBtn.TextSize = 12
    bindBtn.Parent = row

    local bindCorner = Instance.new("UICorner")
    bindCorner.CornerRadius = UDim.new(0, 4)
    bindCorner.Parent = bindBtn

    toggleBtn.MouseButton1Click:Connect(toggleFunc)
    
    bindBtn.MouseButton1Click:Connect(function()
        bindingTarget = key
        bindBtn.Text = "[...]"
    end)
    
    bindBtn.MouseButton2Click:Connect(function()
        binds[key] = Enum.KeyCode.Unknown
        bindingTarget = nil
        if updateUIButtons then updateUIButtons() end
    end)

    return {Row = row, ToggleBtn = toggleBtn, BindBtn = bindBtn, BaseName = name}
end

local function createInputRow(parent, labelText, defaultVal, layoutOrder, onBlur)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(0.92, 0, 0, 32)
    row.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    row.BorderSizePixel = 0
    row.LayoutOrder = layoutOrder
    row.Parent = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "  " .. labelText
    lbl.TextColor3 = Color3.fromRGB(180, 180, 190)
    lbl.Font = Enum.Font.SourceSans
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.45, 0, 0.7, 0)
    box.Position = UDim2.new(0.52, 0, 0.15, 0)
    box.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    box.Text = tostring(defaultVal)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 11
    box.ClearTextOnFocus = false
    box.Parent = row

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box

    box.FocusLost:Connect(function()
        onBlur(box.Text)
    end)
end

-- ==================== UI ROW CREATION ====================

local rows = {
    bring = createRow(tabs.Combat, "Bring Enemies", "bring", 1, toggleBring),
    aim = createRow(tabs.Combat, "Aimbot / Aim Assist", "aim", 2, toggleAim),
    fakeBlock = createRow(tabs.Combat, "Fake Block", "fakeBlock", 3, toggleFakeBlock)
}

rows.farm = createRow(tabs.Farming, "Auto Farm Box", "farm", 1, toggleFarm)

rows.noAttackCooldown = createRow(tabs.Weapons, "Fast Attack / No Cooldown", "noAttackCooldown", 1, toggleNoAttackCooldown)
rows.noSpeedPenalty = createRow(tabs.Weapons, "Remove Speed Penalty", "noSpeedPenalty", 2, toggleNoSpeedPenalty)
rows.noAimRequired = createRow(tabs.Weapons, "Silent Aim (No Aim)", "noAimRequired", 3, toggleNoAimRequired)
rows.infiniteLemonade = createRow(tabs.Weapons, "Infinite Lemonade Buff", "infiniteLemonade", 4, toggleInfiniteLemonade)
rows.permanentSabreBuff = createRow(tabs.Weapons, "Auto Charge Loop", "permanentSabreBuff", 5, togglePermanentSabreBuff)
rows.sabreSpamAttack = createRow(tabs.Weapons, "Auto Sabre Attack", "sabreSpamAttack", 6, toggleSabreSpamAttack)
rows.removeSabreEffects = createRow(tabs.Weapons, "Mute Sabre Audio/FX", "removeSabreEffects", 7, toggleRemoveSabreEffects)
rows.noChargeLimit = createRow(tabs.Weapons, "Remove Charge Cooldown", "noChargeLimit", 8, toggleNoChargeLimit)

createInputRow(tabs.Weapons, "Lemonade Speed:", settings.lemonadeSpeed, 9, function(text)
    local num = tonumber(text)
    if num then settings.lemonadeSpeed = num end
end)

-- Settings Tab
createInputRow(tabs.Settings, "Bring Distance:", settings.bringDistance, 1, function(text)
    local num = tonumber(text)
    if num then settings.bringDistance = num end
end)

createInputRow(tabs.Settings, "Farm Pos (X,Y,Z):", "0, -400, 0", 2, function(text)
    local coords = {}
    for num in string.gmatch(text, "[%d%.%-]+") do
        table.insert(coords, tonumber(num))
    end
    if #coords >= 3 then
        settings.farmPosition = Vector3.new(coords[1], coords[2], coords[3])
        if state.farm then
            local targetPos = createFarmBox(settings.farmPosition)
            local char = localPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = CFrame.new(targetPos) end
        end
    end
end)

rows.autoBringSoloSettings = createRow(tabs.Settings, "Auto-Bring (Solo Alive)", "autoBringSolo", 3, toggleAutoBringSolo)

createInputRow(tabs.Settings, "Auto Charge Speed:", settings.sabreBuffInterval, 4, function(text)
    local num = tonumber(text)
    if num then settings.sabreBuffInterval = num end
end)

updateUIButtons = function()
    for key, rowData in pairs(rows) do
        local stateKey = (key == "autoBringSoloSettings") and "autoBringSolo" or key
        local isActive = state[stateKey]
        
        rowData.ToggleBtn.Text = rowData.BaseName .. ": " .. (isActive and "ON" or "OFF")
        rowData.ToggleBtn.TextColor3 = isActive and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(200, 80, 80)
        
        local currentBind = binds[stateKey]
        local bindName = "None"
        if currentBind and currentBind ~= Enum.KeyCode.Unknown then
            bindName = currentBind.Name
        end
        rowData.BindBtn.Text = "[" .. bindName .. "]"
    end
end

-- Dragging & UI Collapse logic
local dragging, dragInput, dragStart, startPos

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local collapsed = false
collapseBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    container.Visible = not collapsed
    tabBar.Visible = not collapsed
    mainFrame.Size = collapsed and UDim2.new(0, 310, 0, 35) or UDim2.new(0, 310, 0, 480)
    collapseBtn.Text = collapsed and "+" or "-"
end)

-- Keybind Listener
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if bindingTarget then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
                binds[bindingTarget] = Enum.KeyCode.Unknown
            else
                binds[bindingTarget] = input.KeyCode
            end
            bindingTarget = nil
            updateUIButtons()
        end
        return
    end

    -- Trigger manual charge whenever Charge key is pressed if "Remove Charge Cooldown" is active
    if state.noChargeLimit and (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonY) then
        local remote = getSabreRemote()
        if remote then
            pcall(function() remote:FireServer(nil, "Charge") end)
        end
    end

    if input.UserInputType == Enum.UserInputType.Keyboard then
        local kc = input.KeyCode
        if kc ~= Enum.KeyCode.Unknown then
            if kc == binds.bring then toggleBring()
            elseif kc == binds.farm then toggleFarm()
            elseif kc == binds.aim then toggleAim()
            elseif kc == binds.autoBringSolo then toggleAutoBringSolo()
            elseif kc == binds.noSpeedPenalty then toggleNoSpeedPenalty()
            elseif kc == binds.noAimRequired then toggleNoAimRequired()
            elseif kc == binds.infiniteLemonade then toggleInfiniteLemonade()
            elseif kc == binds.noAttackCooldown then toggleNoAttackCooldown()
            elseif kc == binds.fakeBlock then toggleFakeBlock()
            elseif kc == binds.permanentSabreBuff then togglePermanentSabreBuff()
            elseif kc == binds.sabreSpamAttack then toggleSabreSpamAttack()
            elseif kc == binds.removeSabreEffects then toggleRemoveSabreEffects()
            elseif kc == binds.noChargeLimit then toggleNoChargeLimit()
            end
        end
    end
end)

task.spawn(function()
    local steps = 20
    for i = 1, steps do
        progressBar.Size = UDim2.new(i / steps, 0, 1, 0)
        task.wait(0.02)
    end
    task.wait(0.15)
    loadingFrame:Destroy()
    mainFrame.Visible = true
end)
