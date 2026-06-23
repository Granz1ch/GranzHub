-- // ☢️ GRANZ HUB v10.1 - ULTIMATE EDITION (FIXED)
-- // АнтиРагдол + NoAnimations + InfJump
-- Xeno | Полная версия | Anti-Ragdoll FIXED

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
    NoAnimationsEnabled = false,
    JumpPower = 50,
    Cooldown = 0.12,
    MaxFallSpeed = -60,
}

local lastJump = 0
local char, hum, root, animator

-- Хранилище
local ragdollConnections = {}
local animConnections = {}
local heartbeatConnection = nil
local trackedAllTracks = {}

-- Сохранённые Motor6D данные для восстановления
local savedMotors = {}

-- ==================== УТИЛИТЫ ====================
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
    return hum ~= nil and root ~= nil
end

refreshChar()

-- ==================== МОДУЛЬ 1: БЕСКОНЕЧНЫЕ ПРЫЖКИ ====================
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

-- ==================== МОДУЛЬ 2: ANTI-RAGDOLL (ПОЛНОСТЬЮ ПЕРЕРАБОТАН) ====================
--[[
    НОВЫЙ ПРИНЦИП:
    - НЕ блокируем состояния заранее (это вызывает застывание)
    - Вместо этого РЕАКТИВНО ловим рагдолл и мгновенно выводим из него
    - Восстанавливаем Motor6D если они были отключены
    - Удаляем/отключаем рагдолл-констрейнты (BallSocket, Hinge)
    - Убираем NoCollisionConstraint которые добавляются при рагдолле
    - Форсим GettingUp -> Running с микрозадержкой
    - Разблокируем все части тела (Anchored = false)
]]

local ragdollStates = {
    Enum.HumanoidStateType.Ragdoll,
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Physics,
}

local function isRagdollState(state)
    for _, rs in ipairs(ragdollStates) do
        if state == rs then return true end
    end
    return false
end

-- Сохраняет все Motor6D при первом запуске
local function saveMotors(character)
    savedMotors = {}
    if not character then return end
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("Motor6D") then
            savedMotors[desc] = {
                Part0 = desc.Part0,
                Part1 = desc.Part1,
                C0 = desc.C0,
                C1 = desc.C1,
                Enabled = desc.Enabled,
                Parent = desc.Parent,
            }
        end
    end
end

-- Восстанавливает Motor6D - включает обратно
local function restoreMotors(character)
    if not character then return end

    -- Сначала пробуем включить существующие
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("Motor6D") then
            pcall(function()
                desc.Enabled = true
            end)
        end
    end

    -- Если Motor6D были удалены - восстанавливаем из сохранения
    for motor, data in pairs(savedMotors) do
        pcall(function()
            if not motor.Parent then
                -- Motor6D был удалён, пересоздаём
                if data.Parent and data.Parent.Parent then
                    local newMotor = Instance.new("Motor6D")
                    newMotor.Name = motor.Name
                    newMotor.Part0 = data.Part0
                    newMotor.Part1 = data.Part1
                    newMotor.C0 = data.C0
                    newMotor.C1 = data.C1
                    newMotor.Parent = data.Parent
                end
            end
        end)
    end
end

-- Убивает рагдолл-констрейнты
local function killRagdollConstraints(character)
    if not character then return end
    for _, desc in ipairs(character:GetDescendants()) do
        pcall(function()
            if desc:IsA("BallSocketConstraint") or desc:IsA("HingeConstraint") then
                desc.Enabled = false
                -- Некоторые игры пересоздают, поэтому пробуем удалить
                task.delay(0.1, function()
                    pcall(function()
                        if desc and desc.Parent then
                            desc:Destroy()
                        end
                    end)
                end)
            end
        end)
    end
end

-- Убирает NoCollisionConstraint (часто добавляются при рагдолле)
local function killNoCollisionConstraints(character)
    if not character then return end
    for _, desc in ipairs(character:GetDescendants()) do
        pcall(function()
            if desc:IsA("NoCollisionConstraint") then
                desc:Destroy()
            end
        end)
    end
end

-- Разанкоривает все части
local function unanchorAll(character)
    if not character then return end
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("BasePart") then
            pcall(function()
                desc.Anchored = false
            end)
        end
    end
end

-- Убирает CanCollide = false который ставят рагдолл-скрипты на конечности
local function fixCollisions(character)
    if not character then return end
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
            pcall(function()
                -- Не трогаем если это аксессуар
                if not desc.Parent:IsA("Accessory") then
                    desc.CanCollide = true
                end
            end)
        end
    end
end

-- Главная функция выхода из рагдолла
local function breakOutOfRagdoll()
    if not (char and hum and root) then return end
    if hum.Health <= 0 then return end

    pcall(function()
        -- 1. Выключаем PlatformStand
        hum.PlatformStand = false

        -- 2. Восстанавливаем моторы
        restoreMotors(char)

        -- 3. Убиваем рагдолл-констрейнты
        killRagdollConstraints(char)

        -- 4. Убиваем NoCollisionConstraint
        killNoCollisionConstraints(char)

        -- 5. Разанкориваем
        unanchorAll(char)

        -- 6. Переключаем состояние
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)

    -- 7. Через микрозадержку форсим Running
    task.delay(0.05, function()
        pcall(function()
            if hum and hum.Health > 0 then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end)

    -- 8. Ещё раз через чуть больше задержку - страховка
    task.delay(0.15, function()
        pcall(function()
            if hum and hum.Health > 0 then
                hum.PlatformStand = false
                restoreMotors(char)
                local state = hum:GetState()
                if isRagdollState(state) then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    task.delay(0.05, function()
                        pcall(function()
                            hum:ChangeState(Enum.HumanoidStateType.Running)
                        end)
                    end)
                end
            end
        end)
    end)
end

local function startAntiRagdoll()
    if not (char and hum) then return end

    -- Сохраняем моторы
    saveMotors(char)

    -- Слушаем StateChanged - РЕАКТИВНО
    local conn1 = hum.StateChanged:Connect(function(_, newState)
        if not Settings.AntiRagdollEnabled then return end
        if isRagdollState(newState) then
            task.defer(function()
                breakOutOfRagdoll()
            end)
        end
    end)
    table.insert(ragdollConnections, conn1)

    -- Слушаем PlatformStand
    local conn2 = hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not Settings.AntiRagdollEnabled then return end
        if hum.PlatformStand then
            task.defer(function()
                pcall(function()
                    hum.PlatformStand = false
                end)
                breakOutOfRagdoll()
            end)
        end
    end)
    table.insert(ragdollConnections, conn2)

    -- Слушаем добавление рагдолл-констрейнтов
    local conn3 = char.DescendantAdded:Connect(function(desc)
        if not Settings.AntiRagdollEnabled then return end
        task.defer(function()
            pcall(function()
                if desc:IsA("BallSocketConstraint") or desc:IsA("HingeConstraint") then
                    desc.Enabled = false
                    task.delay(0.05, function()
                        pcall(function()
                            if desc and desc.Parent then
                                desc:Destroy()
                            end
                        end)
                    end)
                end
                if desc:IsA("NoCollisionConstraint") then
                    desc:Destroy()
                end
            end)
        end)
    end)
    table.insert(ragdollConnections, conn3)

    -- Слушаем удаление Motor6D
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Motor6D") then
            -- Если мотор отключается
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

            -- Если мотор удаляется
            local conn2 = desc.AncestryChanged:Connect(function(_, parent)
                if not Settings.AntiRagdollEnabled then return end
                if parent == nil then
                    -- Motor6D был удалён, восстанавливаем
                    task.defer(function()
                        restoreMotors(char)
                    end)
                end
            end)
            table.insert(ragdollConnections, conn2)
        end
    end

    -- Слушаем изменения Velocity на частях (некоторые рагдолл системы используют)
    local conn4 = char.DescendantRemoving:Connect(function(desc)
        if not Settings.AntiRagdollEnabled then return end
        if desc:IsA("Motor6D") then
            -- Сохраняем данные перед удалением для восстановления
            local data = {
                Name = desc.Name,
                Part0 = desc.Part0,
                Part1 = desc.Part1,
                C0 = desc.C0,
                C1 = desc.C1,
                Parent = desc.Parent,
            }
            task.delay(0.05, function()
                if not Settings.AntiRagdollEnabled then return end
                pcall(function()
                    if data.Parent and data.Parent.Parent and data.Part0 and data.Part1 then
                        -- Проверяем что мотор действительно удалён
                        local existing = data.Parent:FindFirstChild(data.Name)
                        if not existing or not existing:IsA("Motor6D") then
                            local newMotor = Instance.new("Motor6D")
                            newMotor.Name = data.Name
                            newMotor.Part0 = data.Part0
                            newMotor.Part1 = data.Part1
                            newMotor.C0 = data.C0
                            newMotor.C1 = data.C1
                            newMotor.Parent = data.Parent
                        end
                    end
                end)
            end)
        end
    end)
    table.insert(ragdollConnections, conn4)
end

local function stopAntiRagdoll()
    for _, conn in ipairs(ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ragdollConnections = {}
    savedMotors = {}
end

-- ==================== МОДУЛЬ 3: NO ANIMATIONS ====================
local function hookAnimationTrackAll(track)
    if not track then return end
    if trackedAllTracks[track] then return end
    trackedAllTracks[track] = true

    local conn = track:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if not Settings.NoAnimationsEnabled then return end
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

    if Settings.NoAnimationsEnabled and track.IsPlaying then
        pcall(function()
            track:AdjustSpeed(0)
            track:AdjustWeight(0, 0)
        end)
    end
end

local function suppressAllTracks()
    if not animator then return end
    pcall(function()
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function()
                track:AdjustSpeed(0)
                track:AdjustWeight(0, 0)
            end)
        end
    end)
end

local function hookAnimator()
    if not animator then return end

    pcall(function()
        local conn = animator.AnimationPlayed:Connect(function(track)
            hookAnimationTrackAll(track)
            if Settings.NoAnimationsEnabled then
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

    if hum then
        local events = {"Running", "Jumping", "Climbing", "Swimming", "FreeFalling"}
        for _, evName in ipairs(events) do
            pcall(function()
                local conn = hum[evName]:Connect(function()
                    if not Settings.NoAnimationsEnabled then return end
                    task.defer(suppressAllTracks)
                end)
                table.insert(animConnections, conn)
            end)
        end

        local conn = hum.StateChanged:Connect(function()
            if not Settings.NoAnimationsEnabled then return end
            task.defer(suppressAllTracks)
        end)
        table.insert(animConnections, conn)
    end

    pcall(function()
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            hookAnimationTrackAll(track)
        end
    end)
end

local function startNoAnimations()
    hookAnimator()
end

local function stopNoAnimations()
    for _, conn in ipairs(animConnections) do
        pcall(function() conn:Disconnect() end)
    end
    animConnections = {}

    for track, _ in pairs(trackedAllTracks) do
        pcall(function()
            if track and track.IsPlaying then
                track:AdjustSpeed(1)
                track:AdjustWeight(1, 0.1)
            end
        end)
    end
    trackedAllTracks = {}
end

-- ==================== ГЛАВНЫЙ HEARTBEAT ЦИКЛ ====================
heartbeatConnection = RunService.Heartbeat:Connect(function()
    if not (char and char.Parent) then
        refreshChar()
        return
    end

    if not (hum and hum.Health > 0) then return end

    -- Анти-рагдолл - лёгкая проверка каждый кадр
    if Settings.AntiRagdollEnabled then
        -- Проверяем PlatformStand
        pcall(function()
            if hum.PlatformStand then
                hum.PlatformStand = false
            end
        end)

        -- Проверяем состояние
        pcall(function()
            local state = hum:GetState()
            if isRagdollState(state) then
                breakOutOfRagdoll()
            end
        end)

        -- Проверяем что все моторы включены
        pcall(function()
            for _, desc in ipairs(char:GetDescendants()) do
                if desc:IsA("Motor6D") and not desc.Enabled then
                    desc.Enabled = true
                end
            end
        end)
    end

    -- NoAnimations
    if Settings.NoAnimationsEnabled then
        suppressAllTracks()
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

    if Settings.NoAnimationsEnabled then
        stopNoAnimations()
        task.wait(0.2)
        startNoAnimations()
    end
end)

-- ==================== GUI ====================
if playerGui:FindFirstChild("GranzHubGUI") then
    playerGui:FindFirstChild("GranzHubGUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GranzHubGUI"
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
Title.Text = "🔥 Granz Hub"
Title.TextColor3 = Colors.textMain
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Version = Instance.new("TextLabel")
Version.Size = UDim2.new(0, 50, 0, 20)
Version.Position = UDim2.new(1, -100, 0.5, -10)
Version.BackgroundTransparency = 1
Version.Text = "v10.1"
Version.TextColor3 = Colors.accent
Version.TextSize = 12
Version.Font = Enum.Font.GothamBold
Version.Parent = Header

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

    local function updateVisual(state)
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
    "Мгновенный выход из рагдолла",
    2,
    Colors.btnOnAlt1
)

local AnimToggle, AnimVisual = createModuleButton(
    "👻 No Animations",
    "Отключает все анимации персонажа",
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
    if Settings.NoAnimationsEnabled then count = count + 1 end
    StatusLabel.Text = "Активных модулей: " .. count .. "/3  |  🔥 Granz Hub"

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

AnimToggle.MouseButton1Click:Connect(function()
    Settings.NoAnimationsEnabled = not Settings.NoAnimationsEnabled
    AnimVisual(Settings.NoAnimationsEnabled)

    if Settings.NoAnimationsEnabled then
        refreshChar()
        startNoAnimations()
    else
        stopNoAnimations()
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
    Settings.InfJumpEnabled = false
    Settings.AntiRagdollEnabled = false
    Settings.NoAnimationsEnabled = false

    stopAntiRagdoll()
    stopNoAnimations()

    if heartbeatConnection then
        heartbeatConnection:Disconnect()
    end

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

-- ==================== АНИМАЦИЯ ОБВОДКИ ====================
task.spawn(function()
    local hue = 0
    while ScreenGui and ScreenGui.Parent do
        hue = (hue + 0.003) % 1

        local activeCount = 0
        if Settings.InfJumpEnabled then activeCount = activeCount + 1 end
        if Settings.AntiRagdollEnabled then activeCount = activeCount + 1 end
        if Settings.NoAnimationsEnabled then activeCount = activeCount + 1 end

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

print("🔥 ══════════════════════════════════════")
print("🔥 GRANZ HUB v10.1 ULTIMATE (FIXED)")
print("🔥 ══════════════════════════════════════")
print("🔥 Anti-Ragdoll: РЕАКТИВНЫЙ (не блокирует, а выводит)")
print("🔥 + Восстановление Motor6D при удалении")
print("🔥 + Убийство BallSocket/Hinge/NoCollision")
print("🔥 + Многоуровневая страховка (3 попытки выхода)")
print("🔥 ══════════════════════════════════════")
