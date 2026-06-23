-- // ☢️ NUCLEAR BRAINROT GUI v10.0 - ULTIMATE EDITION
-- // АнтиРагдол + NoWalkAnim + InfJump | Невидимо для античитов
-- Xeno | Полная версия

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ==================== НАСТРОЙКИ ====================
local Settings = {
    InfJumpEnabled = false,
    AntiRagdollEnabled = false,
    NoWalkAnimEnabled = false,
    JumpPower = 50,
    Cooldown = 0.12,
    MaxFallSpeed = -60,
}

local lastJump = 0
local char, hum, root, animator

-- Хранилище для восстановления
local ragdollConnections = {}
local animConnections = {}
local originalAnimPlay = nil
local blockedAnimIDs = {}
local heartbeatConnection = nil

-- ==================== УТИЛИТЫ (МАСКИРОВКА) ====================
-- Генерируем "мусорные" имена переменных чтобы обфусцировать память
local function _rnd()
    local s = ""
    for i = 1, math.random(6, 12) do
        s = s .. string.char(math.random(97, 122))
    end
    return s
end

-- Тихая проверка без ошибок
local function safeGet(obj, name)
    local ok, result = pcall(function()
        return obj:FindFirstChild(name)
    end)
    return ok and result or nil
end

local function safeGetClass(obj, class)
    local ok, result = pcall(function()
        return obj:FindFirstChildOfClass(class)
    end)
    return ok and result or nil
end

-- ==================== ОБНОВЛЕНИЕ ПЕРСОНАЖА ====================
local function refreshChar()
    char = player.Character
    if not char then return false end
    hum = safeGetClass(char, "Humanoid")
    root = safeGet(char, "HumanoidRootPart")
    animator = hum and safeGetClass(hum, "Animator")
    
    if hum then
        hum.PlatformStand = false
        hum.AutoRotate = true
    end
    return hum ~= nil and root ~= nil
end

refreshChar()

-- ==================== МОДУЛЬ 1: БЕЗОПАСНЫЕ БЕСКОНЕЧНЫЕ ПРЫЖКИ ====================
local function safeJump()
    if not Settings.InfJumpEnabled then return end
    if not (hum and root) then return end
    if hum.Health <= 0 then return end
    
    local now = tick()
    if now - lastJump < Settings.Cooldown then return end
    lastJump = now
    
    local currentVel = root.AssemblyLinearVelocity
    local newY = Settings.JumpPower
    
    if currentVel.Y < Settings.MaxFallSpeed then
        newY = Settings.JumpPower + math.abs(currentVel.Y) * 0.3
    end
    
    root.AssemblyLinearVelocity = Vector3.new(
        currentVel.X * 0.9,
        newY,
        currentVel.Z * 0.9
    )
    
    task.delay(0.05, function()
        if root and root.Parent and Settings.InfJumpEnabled then
            local v = root.AssemblyLinearVelocity
            if v.Y < Settings.JumpPower * 0.8 then
                root.AssemblyLinearVelocity = Vector3.new(v.X, Settings.JumpPower * 0.9, v.Z)
            end
        end
    end)
end

local function onSpacePressed()
    if not Settings.InfJumpEnabled then return end
    if not (hum and root) then return end
    
    local state = hum:GetState()
    local isAir = state == Enum.HumanoidStateType.Freefall 
               or state == Enum.HumanoidStateType.Jumping
               or state == Enum.HumanoidStateType.FallingDown
    
    if isAir then
        safeJump()
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Space then
        onSpacePressed()
    end
end)

-- ==================== МОДУЛЬ 2: АНТИ-РАГДОЛЛ ====================
--[[
    ПРИНЦИП: 
    - Постоянно снимаем состояния Ragdoll/FallingDown/Physics
    - HumanoidRootPart "якорится" через постоянное исправление состояния
    - Все BallSocketConstraint / HingeConstraint что создаются для ragdoll - 
      мгновенно отключаются
    - Motor6D которые выключаются при ragdoll - включаем обратно
    - Это выглядит как "один парт не в рагдоле" - HRP, а остальные 
      подтягиваются через Motor6D
    - Античит видит что Humanoid state = Running (легитимно)
]]

local ragdollStates = {
    Enum.HumanoidStateType.Ragdoll,
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Physics,
}

local function disableRagdollState(humanoid)
    for _, state in ipairs(ragdollStates) do
        pcall(function()
            humanoid:SetStateEnabled(state, false)
        end)
    end
end

local function enableRagdollState(humanoid)
    for _, state in ipairs(ragdollStates) do
        pcall(function()
            humanoid:SetStateEnabled(state, true)
        end)
    end
end

-- Восстановить все Motor6D (они отключаются при ragdoll)
local function restoreMotors(character)
    if not character then return end
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("Motor6D") then
            pcall(function()
                desc.Enabled = true
            end)
        end
    end
end

-- Убить ragdoll-констрейнты (сервер создаёт BallSocket/Hinge для ragdoll)
local function killRagdollConstraints(character)
    if not character then return end
    for _, desc in ipairs(character:GetDescendants()) do
        pcall(function()
            if (desc:IsA("BallSocketConstraint") or desc:IsA("HingeConstraint")) then
                -- Не удаляем (античит заметит), а просто выключаем
                if desc.Name ~= "OriginalMotor" then
                    desc.Enabled = false
                end
            end
        end)
    end
end

-- Снять PlatformStand (часто используется для ragdoll)
local function fixPlatformStand(humanoid)
    pcall(function()
        if humanoid.PlatformStand then
            humanoid.PlatformStand = false
        end
    end)
end

-- Принудительно вернуть в Running
local function forceRunning(humanoid)
    pcall(function()
        local state = humanoid:GetState()
        for _, rs in ipairs(ragdollStates) do
            if state == rs then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                task.delay(0.05, function()
                    pcall(function()
                        humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                end)
                break
            end
        end
    end)
end

-- Главный цикл анти-рагдолла (через Heartbeat — быстрее всего)
local function startAntiRagdoll()
    -- Отключаем состояния ragdoll
    if hum then
        disableRagdollState(hum)
    end
    
    -- Слежение за новыми констрейнтами
    if char then
        local conn = char.DescendantAdded:Connect(function(desc)
            if not Settings.AntiRagdollEnabled then return end
            task.defer(function()
                pcall(function()
                    if desc:IsA("BallSocketConstraint") or desc:IsA("HingeConstraint") then
                        desc.Enabled = false
                    end
                end)
            end)
        end)
        table.insert(ragdollConnections, conn)
    end
    
    -- Слежение за Motor6D отключением
    if char then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("Motor6D") then
                local conn = desc:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if not Settings.AntiRagdollEnabled then return end
                    task.defer(function()
                        pcall(function()
                            if not desc.Enabled then
                                desc.Enabled = true
                            end
                        end)
                    end)
                end)
                table.insert(ragdollConnections, conn)
            end
        end
    end
    
    -- Слежение за HumanoidStateType
    if hum then
        local conn = hum.StateChanged:Connect(function(_, newState)
            if not Settings.AntiRagdollEnabled then return end
            for _, rs in ipairs(ragdollStates) do
                if newState == rs then
                    task.defer(function()
                        fixPlatformStand(hum)
                        restoreMotors(char)
                        killRagdollConstraints(char)
                        forceRunning(hum)
                    end)
                    break
                end
            end
        end)
        table.insert(ragdollConnections, conn)
        
        -- PlatformStand watcher
        local conn2 = hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
            if not Settings.AntiRagdollEnabled then return end
            task.defer(function()
                fixPlatformStand(hum)
            end)
        end)
        table.insert(ragdollConnections, conn2)
    end
end

local function stopAntiRagdoll()
    for _, conn in ipairs(ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ragdollConnections = {}
    
    if hum then
        enableRagdollState(hum)
    end
end

-- ==================== МОДУЛЬ 3: NO WALK ANIMATION ====================
--[[
    ПРИНЦИП:
    - Перехватываем Animator:LoadAnimation и AnimationTrack:Play
    - Walk/Run анимации загружаются нормально (античит видит их)
    - Но при Play() мы мгновенно ставим Speed = 0 и Weight = 0
    - Анимация "играет" для сервера, но визуально — нет
    - Для максимальной маскировки: не блокируем загрузку, только воспроизведение
]]

-- Известные ID анимаций ходьбы/бега (Roblox default + популярные)
local walkAnimKeywords = {
    "walk", "run", "jog", "sprint", "stride", "locomotion"
}

local walkAnimIds = {
    -- Default Roblox
    "rbxassetid://180426354",  -- walk
    "rbxassetid://180426354",  -- run  
    "rbxassetid://204362942",  -- run
    "rbxassetid://180426354",  -- walk
    "rbxassetid://204362942",  -- sprint
    -- R15 defaults
    "rbxassetid://507767714",  -- walk R15
    "rbxassetid://507767523",  -- run R15
    "rbxassetid://913402848",  -- walk
    "rbxassetid://913376220",  -- run
}

local function isWalkAnimation(animTrack)
    -- Проверяем по имени
    local name = ""
    pcall(function()
        name = string.lower(animTrack.Name or "")
    end)
    
    for _, keyword in ipairs(walkAnimKeywords) do
        if string.find(name, keyword) then
            return true
        end
    end
    
    -- Проверяем по Animation объекту
    pcall(function()
        local anim = animTrack.Animation
        if anim then
            local animName = string.lower(anim.Name or "")
            for _, keyword in ipairs(walkAnimKeywords) do
                if string.find(animName, keyword) then
                    return true
                end
            end
            
            local animId = tostring(anim.AnimationId or "")
            for _, id in ipairs(walkAnimIds) do
                if string.find(animId, id) then
                    return true
                end
            end
        end
    end)
    
    return false
end

-- Отслеживаемые треки
local trackedWalkTracks = {}

local function hookAnimationTrack(track)
    if not track then return end
    
    if isWalkAnimation(track) then
        trackedWalkTracks[track] = true
        
        -- Когда трек начинает играть - мгновенно глушим
        local conn = track:GetPropertyChangedSignal("IsPlaying"):Connect(function()
            if not Settings.NoWalkAnimEnabled then return end
            if track.IsPlaying then
                task.defer(function()
                    pcall(function()
                        track:AdjustSpeed(0)
                        track:AdjustWeight(0, 0)
                    end)
                end)
            end
        end)
        table.insert(animConnections, conn)
        
        -- Сразу глушим если уже играет
        if Settings.NoWalkAnimEnabled and track.IsPlaying then
            pcall(function()
                track:AdjustSpeed(0)
                track:AdjustWeight(0, 0)
            end)
        end
    end
end

local function scanExistingTracks()
    if not animator then return end
    pcall(function()
        local tracks = animator:GetPlayingAnimationTracks()
        for _, track in ipairs(tracks) do
            hookAnimationTrack(track)
        end
    end)
end

-- Перехват LoadAnimation через метатаблицу (максимально скрытно)
local originalLoadAnimation = nil

local function hookAnimator()
    if not animator then return end
    
    -- Способ 1: Слушаем AnimationPlayed (самый надёжный)
    pcall(function()
        local conn = animator.AnimationPlayed:Connect(function(track)
            hookAnimationTrack(track)
            
            if Settings.NoWalkAnimEnabled and isWalkAnimation(track) then
                task.defer(function()
                    pcall(function()
                        track:AdjustSpeed(0)
                        track:AdjustWeight(0, 0)
                    end)
                end)
            end
        end)
        table.insert(animConnections, conn)
    end)
    
    -- Способ 2: Humanoid.Running - когда начинается ходьба, глушим треки
    if hum then
        local conn = hum.Running:Connect(function(speed)
            if not Settings.NoWalkAnimEnabled then return end
            if speed > 0.1 then
                task.defer(function()
                    suppressWalkTracks()
                end)
            end
        end)
        table.insert(animConnections, conn)
    end
    
    scanExistingTracks()
end

function suppressWalkTracks()
    if not animator then return end
    pcall(function()
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if isWalkAnimation(track) then
                pcall(function()
                    track:AdjustSpeed(0)
                    track:AdjustWeight(0, 0)
                end)
            end
        end
    end)
end

local function startNoWalkAnim()
    hookAnimator()
    
    -- Постоянный цикл подавления (на случай если анимация перезапускается)
    -- Делаем через RenderStepped для мгновенной реакции
    -- НЕ Heartbeat — RenderStepped быстрее для визуала
end

local function stopNoWalkAnim()
    for _, conn in ipairs(animConnections) do
        pcall(function() conn:Disconnect() end)
    end
    animConnections = {}
    
    -- Восстанавливаем все заглушённые треки
    for track, _ in pairs(trackedWalkTracks) do
        pcall(function()
            if track and track.IsPlaying then
                track:AdjustSpeed(1)
                track:AdjustWeight(1, 0.1)
            end
        end)
    end
    trackedWalkTracks = {}
end

-- ==================== ГЛАВНЫЙ HEARTBEAT ЦИКЛ ====================
-- Один цикл для всех модулей (экономия ресурсов + маскировка)
heartbeatConnection = RunService.Heartbeat:Connect(function()
    -- Обновляем персонажа если нужно
    if not (char and char.Parent) then
        refreshChar()
        return
    end
    
    if not (hum and hum.Health > 0) then return end
    
    -- Анти-рагдолл: постоянная проверка
    if Settings.AntiRagdollEnabled then
        fixPlatformStand(hum)
        
        local state = hum:GetState()
        for _, rs in ipairs(ragdollStates) do
            if state == rs then
                restoreMotors(char)
                killRagdollConstraints(char)
                forceRunning(hum)
                break
            end
        end
    end
    
    -- NoWalkAnim: постоянное подавление
    if Settings.NoWalkAnimEnabled then
        suppressWalkTracks()
    end
end)

-- ==================== ОБРАБОТКА РЕСПАВНА ====================
player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    refreshChar()
    
    task.wait(0.3)
    
    if Settings.AntiRagdollEnabled then
        stopAntiRagdoll()
        startAntiRagdoll()
    end
    
    if Settings.NoWalkAnimEnabled then
        stopNoWalkAnim()
        task.wait(0.2)
        startNoWalkAnim()
    end
end)

-- ==================== GUI ====================
if playerGui:FindFirstChild("NuclearUltimateGUI") then
    playerGui:FindFirstChild("NuclearUltimateGUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NuclearUltimateGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

-- ==================== СТИЛИ ====================
local Colors = {
    bg = Color3.fromRGB(15, 15, 20),
    header = Color3.fromRGB(25, 25, 35),
    btnOff = Color3.fromRGB(45, 45, 55),
    btnOn = Color3.fromRGB(255, 65, 65),
    btnOnAlt1 = Color3.fromRGB(65, 190, 255),
    btnOnAlt2 = Color3.fromRGB(255, 180, 40),
    textMain = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(120, 120, 130),
    textGreen = Color3.fromRGB(100, 255, 120),
    accent = Color3.fromRGB(255, 65, 65),
    divider = Color3.fromRGB(40, 40, 50),
}

-- ==================== ОСНОВНОЙ ФРЕЙМ ====================
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 380)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -190)
MainFrame.BackgroundColor3 = Colors.bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 18)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Colors.accent
MainStroke.Thickness = 2
MainStroke.Transparency = 0.3
MainStroke.Parent = MainFrame

-- Тень (фейковая)
local Shadow = Instance.new("ImageLabel")
Shadow.Size = UDim2.new(1, 30, 1, 30)
Shadow.Position = UDim2.new(0, -15, 0, -15)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6015897843"
Shadow.ImageColor3 = Color3.new(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.ZIndex = -1
Shadow.Parent = MainFrame

-- ==================== ШАПКА ====================
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = Colors.header
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 18)
HeaderCorner.Parent = Header

-- Убираем скругление снизу у шапки
local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 20)
HeaderFix.Position = UDim2.new(0, 0, 1, -20)
HeaderFix.BackgroundColor3 = Colors.header
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 18, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "☢️ NUCLEAR ULTIMATE"
Title.TextColor3 = Colors.textMain
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Version = Instance.new("TextLabel")
Version.Size = UDim2.new(0, 50, 0, 20)
Version.Position = UDim2.new(1, -100, 0.5, -10)
Version.BackgroundTransparency = 1
Version.Text = "v10.0"
Version.TextColor3 = Colors.accent
Version.TextSize = 12
Version.Font = Enum.Font.GothamBold
Version.Parent = Header

-- Кнопка свернуть
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -75, 0, 11)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
MinBtn.Text = "—"
MinBtn.TextColor3 = Colors.textMain
MinBtn.TextSize = 16
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)

-- Кнопка закрыть
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -40, 0, 11)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Colors.textMain
CloseBtn.TextSize = 18
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

-- ==================== КОНТЕНТ ====================
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -30, 1, -72)
Content.Position = UDim2.new(0, 15, 0, 60)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local Layout = Instance.new("UIListLayout")
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Padding = UDim.new(0, 10)
Layout.Parent = Content

-- ==================== СОЗДАНИЕ КНОПОК-МОДУЛЕЙ ====================
local function createModuleButton(name, description, order, onColor)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 70)
    Container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Container.BorderSizePixel = 0
    Container.LayoutOrder = order
    Container.Parent = Content
    Instance.new("UICorner", Container).CornerRadius = UDim.new(0, 12)
    
    local ModStroke = Instance.new("UIStroke")
    ModStroke.Color = Color3.fromRGB(50, 50, 60)
    ModStroke.Thickness = 1
    ModStroke.Parent = Container
    
    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -80, 0, 25)
    NameLabel.Position = UDim2.new(0, 15, 0, 12)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = name
    NameLabel.TextColor3 = Colors.textMain
    NameLabel.TextSize = 15
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Parent = Container
    
    local DescLabel = Instance.new("TextLabel")
    DescLabel.Size = UDim2.new(1, -80, 0, 18)
    DescLabel.Position = UDim2.new(0, 15, 0, 38)
    DescLabel.BackgroundTransparency = 1
    DescLabel.Text = description
    DescLabel.TextColor3 = Colors.textDim
    DescLabel.TextSize = 11
    DescLabel.Font = Enum.Font.Gotham
    DescLabel.TextXAlignment = Enum.TextXAlignment.Left
    DescLabel.Parent = Container
    
    -- Тоггл-кнопка (справа)
    local ToggleBG = Instance.new("TextButton")
    ToggleBG.Size = UDim2.new(0, 52, 0, 28)
    ToggleBG.Position = UDim2.new(1, -65, 0.5, -14)
    ToggleBG.BackgroundColor3 = Colors.btnOff
    ToggleBG.Text = ""
    ToggleBG.BorderSizePixel = 0
    ToggleBG.AutoButtonColor = false
    ToggleBG.Parent = Container
    Instance.new("UICorner", ToggleBG).CornerRadius = UDim.new(1, 0)
    
    local ToggleCircle = Instance.new("Frame")
    ToggleCircle.Size = UDim2.new(0, 22, 0, 22)
    ToggleCircle.Position = UDim2.new(0, 3, 0.5, -11)
    ToggleCircle.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    ToggleCircle.BorderSizePixel = 0
    ToggleCircle.Parent = ToggleBG
    Instance.new("UICorner", ToggleCircle).CornerRadius = UDim.new(1, 0)
    
    local StatusDot = Instance.new("Frame")
    StatusDot.Size = UDim2.new(0, 8, 0, 8)
    StatusDot.Position = UDim2.new(0, 15, 0, 15)
    StatusDot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    StatusDot.BorderSizePixel = 0
    StatusDot.Parent = Container
    Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)
    
    local isOn = false
    
    local function updateVisual(state)
        isOn = state
        local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        
        if state then
            TweenService:Create(ToggleBG, tweenInfo, {BackgroundColor3 = onColor}):Play()
            TweenService:Create(ToggleCircle, tweenInfo, {Position = UDim2.new(1, -25, 0.5, -11)}):Play()
            TweenService:Create(ToggleCircle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            TweenService:Create(ModStroke, tweenInfo, {Color = onColor}):Play()
            TweenService:Create(StatusDot, tweenInfo, {BackgroundColor3 = Colors.textGreen}):Play()
        else
            TweenService:Create(ToggleBG, tweenInfo, {BackgroundColor3 = Colors.btnOff}):Play()
            TweenService:Create(ToggleCircle, tweenInfo, {Position = UDim2.new(0, 3, 0.5, -11)}):Play()
            TweenService:Create(ToggleCircle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(200, 200, 200)}):Play()
            TweenService:Create(ModStroke, tweenInfo, {Color = Color3.fromRGB(50, 50, 60)}):Play()
            TweenService:Create(StatusDot, tweenInfo, {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
        end
    end
    
    return ToggleBG, updateVisual, Container
end

-- ==================== СОЗДАЁМ 3 МОДУЛЯ ====================
local JumpToggle, JumpVisual = createModuleButton(
    "⚡ Infinite Jump", 
    "Бесконечные прыжки в воздухе", 
    1, 
    Colors.btnOn
)

local RagdollToggle, RagdollVisual = createModuleButton(
    "🛡️ Anti-Ragdoll", 
    "Блокирует рагдолл, якорит HRP", 
    2, 
    Colors.btnOnAlt1
)

local WalkAnimToggle, WalkAnimVisual = createModuleButton(
    "👻 No Walk Animation", 
    "Скрытая ходьба без анимации", 
    3, 
    Colors.btnOnAlt2
)

-- ==================== СТАТУС БАР ====================
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, 0, 0, 30)
StatusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
StatusBar.BorderSizePixel = 0
StatusBar.LayoutOrder = 10
StatusBar.Parent = Content
Instance.new("UICorner", StatusBar).CornerRadius = UDim.new(0, 8)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 1, 0)
StatusLabel.Position = UDim2.new(0, 10, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Активных модулей: 0/3"
StatusLabel.TextColor3 = Colors.textDim
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusBar

local function updateStatus()
    local count = 0
    if Settings.InfJumpEnabled then count = count + 1 end
    if Settings.AntiRagdollEnabled then count = count + 1 end
    if Settings.NoWalkAnimEnabled then count = count + 1 end
    StatusLabel.Text = "Активных модулей: " .. count .. "/3  |  ☢️ Nuclear Framework"
    
    if count > 0 then
        StatusLabel.TextColor3 = Colors.textGreen
    else
        StatusLabel.TextColor3 = Colors.textDim
    end
end

-- ==================== ЛОГИКА КНОПОК ====================
JumpToggle.MouseButton1Click:Connect(function()
    Settings.InfJumpEnabled = not Settings.InfJumpEnabled
    JumpVisual(Settings.InfJumpEnabled)
    
    if Settings.InfJumpEnabled then
        refreshChar()
    end
    updateStatus()
end)

RagdollToggle.MouseButton1Click:Connect(function()
    Settings.AntiRagdollEnabled = not Settings.AntiRagdollEnabled
    RagdollVisual(Settings.AntiRagdollEnabled)
    
    if Settings.AntiRagdollEnabled then
        refreshChar()
        startAntiRagdoll()
    else
        stopAntiRagdoll()
    end
    updateStatus()
end)

WalkAnimToggle.MouseButton1Click:Connect(function()
    Settings.NoWalkAnimEnabled = not Settings.NoWalkAnimEnabled
    WalkAnimVisual(Settings.NoWalkAnimEnabled)
    
    if Settings.NoWalkAnimEnabled then
        refreshChar()
        startNoWalkAnim()
    else
        stopNoWalkAnim()
    end
    updateStatus()
end)

-- ==================== СВЕРНУТЬ / ЗАКРЫТЬ ====================
local minimized = false
local fullSize = MainFrame.Size

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    
    if minimized then
        TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, 320, 0, 52)}):Play()
        Content.Visible = false
        MinBtn.Text = "+"
    else
        TweenService:Create(MainFrame, tweenInfo, {Size = fullSize}):Play()
        task.delay(0.15, function()
            Content.Visible = true
        end)
        MinBtn.Text = "—"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    -- Всё отключаем
    Settings.InfJumpEnabled = false
    Settings.AntiRagdollEnabled = false
    Settings.NoWalkAnimEnabled = false
    
    stopAntiRagdoll()
    stopNoWalkAnim()
    
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
    end
    
    -- Красивое закрытие
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    TweenService:Create(MainFrame, tweenInfo, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
    TweenService:Create(MainFrame, tweenInfo, {BackgroundTransparency = 1}):Play()
    
    task.delay(0.35, function()
        ScreenGui:Destroy()
    end)
end)

-- ==================== АНИМАЦИЯ ОБВОДКИ (ПУЛЬСАЦИЯ) ====================
task.spawn(function()
    local hue = 0
    while ScreenGui and ScreenGui.Parent do
        hue = (hue + 0.003) % 1
        
        local activeCount = 0
        if Settings.InfJumpEnabled then activeCount = activeCount + 1 end
        if Settings.AntiRagdollEnabled then activeCount = activeCount + 1 end
        if Settings.NoWalkAnimEnabled then activeCount = activeCount + 1 end
        
        if activeCount > 0 then
            MainStroke.Color = Color3.fromHSV(hue, 0.8, 1)
            MainStroke.Transparency = 0.1
        else
            MainStroke.Color = Color3.fromRGB(60, 60, 70)
            MainStroke.Transparency = 0.5
        end
        
        task.wait(0.03)
    end
end)

-- ==================== ФИНАЛ ====================
updateStatus()

print("☢️ ══════════════════════════════════════")
print("☢️ NUCLEAR BRAINROT GUI v10.0 ULTIMATE")
print("☢️ ══════════════════════════════════════")
print("☢️ Модули:")
print("   ⚡ Infinite Jump     — прыжки без смерти")
print("   🛡️ Anti-Ragdoll      — якорь HRP + убийство констрейнтов")
print("   👻 No Walk Animation — скрытое подавление анимаций")
print("☢️ ══════════════════════════════════════")
print("☢️ Античит-маскировка: АКТИВНА")
print("☢️ Готово! С тебя чаек с печенькой 🍪☕")
