-- // ░██████╗░██████╗░░█████╗░███╗░░██╗███████╗
-- // ██╔════╝░██╔══██╗██╔══██╗████╗░██║╚════██║
-- // ██║░░██╗░██████╔╝███████║██╔██╗██║░░███╔═╝
-- // ██║░░╚██╗██╔══██╗██╔══██║██║╚██╗██║██╔══╝░
-- // ╚██████╔╝██║░░██║██║░░██║██║░╚████║███████╗
-- // ░╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░╚═══╝╚══════╝
-- // v12.0 PHANTOM GHOST — SAB 2026

local _S = Random.new(tick() * os.clock() + math.random(1, 99999))
local function _gid(l)
    l = l or _S:NextInteger(10, 18)
    local b = {}
    for i = 1, l do
        local r = _S:NextInteger(1, 3)
        if r == 1 then b[i] = string.char(_S:NextInteger(97, 122))
        elseif r == 2 then b[i] = string.char(_S:NextInteger(65, 90))
        else b[i] = string.char(_S:NextInteger(48, 57))
        end
    end
    return table.concat(b)
end
local function _rd() return _S:NextNumber(0.002, 0.009) end
local function _rm(a, b) return _S:NextNumber(a, b) end
local function _ri(a, b) return _S:NextInteger(a, b) end

local _g = game
local _sv = setmetatable({}, {__index = function(s, k) local v = _g:GetService(k) rawset(s, k, v) return v end})

local _P = _sv.Players
local _UIS = _sv.UserInputService
local _RS = _sv.RunService
local _TS = _sv.TweenService
local _D = _sv.Debris

local _lp = _P.LocalPlayer
local _pg = _lp:WaitForChild("PlayerGui")

local _CFG = {
    _j = false,
    _ar = false,
    _na = false,
    _jp = 50,
    _cd = 0.12,
    _mfs = -60,
}

local _lastJ = 0
local _char, _hum, _root, _anim
local _rc = {}
local _ac = {}
local _hbc = nil
local _tt = {}
local _motorSnap = {}
local _fakeMotors = {}
local _lastEsc = 0

-- Ghost Anti-Ragdoll state
local _ghostMode = false
local _ghostPart = nil
local _ghostHum = nil
local _savedRootCF = nil
local _ragdollActive = false
local _bodyMovers = {}

local function _sf(o, n)
    local ok, r = pcall(function() return o:FindFirstChild(n) end)
    return ok and r or nil
end
local function _sfc(o, c)
    local ok, r = pcall(function() return o:FindFirstChildOfClass(c) end)
    return ok and r or nil
end
local function _w(fn) return function(...) local ok = pcall(fn, ...) return ok end end
local function _wr(fn) return function(...) local ok, r = pcall(fn, ...) return ok and r or nil end end

local function _ref()
    _char = _lp.Character
    if not _char then return false end
    _hum = _sfc(_char, "Humanoid")
    _root = _sf(_char, "HumanoidRootPart")
    _anim = _hum and _sfc(_hum, "Animator")
    return _hum ~= nil and _root ~= nil
end
_ref()

-- ===================== INFINITE JUMP =====================
local function _doJump()
    if not _CFG._j then return end
    local jumpRoot = _root
    if _ghostMode and _ghostPart then
        jumpRoot = _ghostPart
    end
    if not jumpRoot then return end
    if _hum and _hum.Health <= 0 then return end
    local n = tick()
    if n - _lastJ < _CFG._cd then return end
    _lastJ = n
    local cv = jumpRoot.AssemblyLinearVelocity
    local ny = _CFG._jp
    if cv.Y < _CFG._mfs then
        ny = _CFG._jp + math.abs(cv.Y) * 0.3
    end
    local jx = _rm(-0.2, 0.2)
    local jz = _rm(-0.2, 0.2)
    jumpRoot.AssemblyLinearVelocity = Vector3.new(
        cv.X * _rm(0.88, 0.92) + jx,
        ny + _rm(-0.3, 0.3),
        cv.Z * _rm(0.88, 0.92) + jz
    )
    task.delay(0.04 + _rd(), function()
        if jumpRoot and jumpRoot.Parent and _CFG._j then
            local v = jumpRoot.AssemblyLinearVelocity
            if v.Y < _CFG._jp * 0.78 then
                jumpRoot.AssemblyLinearVelocity = Vector3.new(v.X, _CFG._jp * _rm(0.87, 0.93), v.Z)
            end
        end
    end)
end

_UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.Space then
        if not _hum then return end
        if _ghostMode then
            _doJump()
            return
        end
        if not _root then return end
        local st = _hum:GetState()
        if st == Enum.HumanoidStateType.Freefall
            or st == Enum.HumanoidStateType.Jumping
            or st == Enum.HumanoidStateType.FallingDown then
            _doJump()
        end
    end
end)

-- ===================== GHOST ANTI-RAGDOLL v4.0 =====================
--[[
    КОНЦЕПЦИЯ "ПРИЗРАКА":
    
    Когда игра активирует рагдолл:
    1. Тело ПРОДОЛЖАЕТ лететь в рагдолле (выглядит натурально!)
    2. Мы создаём НЕВИДИМУЮ ЧАСТЬ (призрак) в позиции игрока
    3. К призраку прикрепляем управление (BodyVelocity/BodyGyro)
    4. Камера следит за призраком, а НЕ за рагдолл-телом
    5. Игрок может ХОДИТЬ через призрака
    6. Когда рагдолл заканчивается — телепортируем тело к призраку
    7. Уничтожаем призрака — всё как будто ничего не было
    
    Результат: тело красиво отлетает, но игрок продолжает управлять!
]]

local _ragStates = {
    [Enum.HumanoidStateType.Ragdoll] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics] = true,
}
local function _isRag(st) return _ragStates[st] == true end

local function _saveMotorSnapshot()
    _motorSnap = {}
    if not _char then return end
    for _, v in ipairs(_char:GetDescendants()) do
        if v:IsA("Motor6D") then
            _motorSnap[#_motorSnap + 1] = {
                _ref = v, _n = v.Name, _p = v.Parent,
                _p0 = v.Part0, _p1 = v.Part1,
                _c0 = v.C0, _c1 = v.C1,
            }
        end
    end
end

-- Создаём невидимого призрака
local function _createGhost()
    if _ghostPart then return end
    if not (_root and _char) then return end

    _savedRootCF = _root.CFrame

    -- Создаём невидимую часть
    local ghost = Instance.new("Part")
    ghost.Name = _gid(8)
    ghost.Size = Vector3.new(2, 2, 1)
    ghost.Transparency = 1
    ghost.CanCollide = true
    ghost.Anchored = false
    ghost.CFrame = _savedRootCF
    ghost.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
    ghost.Parent = workspace

    _ghostPart = ghost

    -- BodyVelocity для управления движением
    local bv = Instance.new("BodyVelocity")
    bv.Name = _gid(5)
    bv.MaxForce = Vector3.new(10000, 0, 10000)
    bv.Velocity = Vector3.zero
    bv.P = 1250
    bv.Parent = ghost
    _bodyMovers.bv = bv

    -- BodyGyro для поворота
    local bg = Instance.new("BodyGyro")
    bg.Name = _gid(5)
    bg.MaxTorque = Vector3.new(0, 10000, 0)
    bg.P = 3000
    bg.D = 100
    bg.Parent = ghost
    _bodyMovers.bg = bg

    -- Анти-гравитация (чтобы призрак не падал сквозь землю, но и не летал)
    local bf = Instance.new("BodyForce")
    bf.Name = _gid(5)
    bf.Force = Vector3.new(0, ghost:GetMass() * workspace.Gravity * 0.15, 0)
    bf.Parent = ghost
    _bodyMovers.bf = bf

    _ghostMode = true
end

-- Управление призраком (вызывается каждый кадр)
local function _controlGhost()
    if not _ghostMode then return end
    if not (_ghostPart and _ghostPart.Parent) then
        _ghostMode = false
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    -- Получаем ввод
    local moveDir = Vector3.zero
    local camCF = cam.CFrame
    local camLook = camCF.LookVector
    local camRight = camCF.RightVector

    -- Проецируем на горизонтальную плоскость
    local forward = Vector3.new(camLook.X, 0, camLook.Z).Unit
    local right = Vector3.new(camRight.X, 0, camRight.Z).Unit

    if _UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
    if _UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
    if _UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
    if _UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end

    local speed = 16
    if _hum then
        speed = _hum.WalkSpeed
    end

    if moveDir.Magnitude > 0 then
        moveDir = moveDir.Unit * speed
        if _bodyMovers.bg then
            _bodyMovers.bg.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(moveDir.X, 0, moveDir.Z))
        end
    end

    if _bodyMovers.bv then
        _bodyMovers.bv.Velocity = Vector3.new(moveDir.X, 0, moveDir.Z)
    end

    -- Камера следит за призраком
    pcall(function()
        cam.CameraSubject = _ghostPart
    end)
end

-- Уничтожаем призрака и возвращаем тело
local function _destroyGhost()
    if not _ghostMode then return end

    local ghostCF = nil
    if _ghostPart and _ghostPart.Parent then
        ghostCF = _ghostPart.CFrame
    end

    -- Восстанавливаем тело
    if _char and _root and _root.Parent and ghostCF then
        pcall(function()
            -- Телепортируем HumanoidRootPart к призраку
            _root.CFrame = ghostCF
            _root.AssemblyLinearVelocity = Vector3.zero
            _root.AssemblyAngularVelocity = Vector3.zero

            -- Обнуляем velocity всех частей
            for _, v in ipairs(_char:GetDescendants()) do
                if v:IsA("BasePart") then
                    pcall(function()
                        v.AssemblyLinearVelocity = Vector3.zero
                        v.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
        end)
    end

    -- Убираем body movers
    for k, v in pairs(_bodyMovers) do
        pcall(function() v:Destroy() end)
    end
    _bodyMovers = {}

    -- Убираем призрака
    if _ghostPart then
        pcall(function() _ghostPart:Destroy() end)
        _ghostPart = nil
    end

    -- Восстанавливаем камеру
    pcall(function()
        if _hum then
            workspace.CurrentCamera.CameraSubject = _hum
        end
    end)

    _ghostMode = false
end

-- Восстанавливаем Motor6D после рагдолла
local function _restoreMotors()
    if not _char then return end
    for _, data in ipairs(_motorSnap) do
        pcall(function()
            if data._ref and data._ref.Parent then
                data._ref.Enabled = true
                return
            end
            if not (data._p and data._p.Parent) then return end
            if not (data._p0 and data._p0.Parent) then return end
            if not (data._p1 and data._p1.Parent) then return end
            local ex = data._p:FindFirstChild(data._n)
            if ex and ex:IsA("Motor6D") then
                ex.Enabled = true
                data._ref = ex
                return
            end
            local m = Instance.new("Motor6D")
            m.Name = data._n
            m.Part0 = data._p0
            m.Part1 = data._p1
            m.C0 = data._c0
            m.C1 = data._c1
            m.Parent = data._p
            data._ref = m
            _fakeMotors[#_fakeMotors + 1] = m
        end)
    end
end

-- Убиваем рагдолл-констрейнты
local function _nukeConstraints()
    if not _char then return end
    for _, v in ipairs(_char:GetDescendants()) do
        pcall(function()
            if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint")
                or v:IsA("NoCollisionConstraint") or v:IsA("RopeConstraint")
                or v:IsA("SpringConstraint") or v:IsA("CylindricalConstraint")
                or v:IsA("PrismaticConstraint") then
                v:Destroy()
            end
        end)
    end
end

-- Полный выход из рагдолла
local function _exitRagdoll()
    if not (_hum and _char and _root) then return end
    if _hum.Health <= 0 then return end

    _ragdollActive = false

    -- Шаг 1: PlatformStand off
    _w(function() _hum.PlatformStand = false end)()

    -- Шаг 2: Уничтожаем констрейнты
    _nukeConstraints()

    -- Шаг 3: Восстанавливаем моторы
    _restoreMotors()

    -- Шаг 4: Размораживаем
    for _, v in ipairs(_char:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function() v.Anchored = false end)
        end
    end

    -- Шаг 5: Телепортируем к призраку и уничтожаем его
    _destroyGhost()

    -- Шаг 6: Форсим состояние
    _w(function() _hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)()

    task.delay(0.06 + _rd(), function()
        if not _CFG._ar then return end
        pcall(function()
            if _hum and _hum.Health > 0 then
                _hum.PlatformStand = false
                _nukeConstraints()
                _restoreMotors()
                _hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end)

    task.delay(0.2 + _rd(), function()
        if not _CFG._ar then return end
        pcall(function()
            if _hum and _hum.Health > 0 then
                _hum.PlatformStand = false
                local st = _hum:GetState()
                if _isRag(st) or st == Enum.HumanoidStateType.PlatformStanding then
                    _nukeConstraints()
                    _restoreMotors()
                    _hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    task.delay(0.05, function()
                        pcall(function() _hum:ChangeState(Enum.HumanoidStateType.Running) end)
                    end)
                end
                -- Гарантируем что камера на персонаже
                if not _ghostMode then
                    workspace.CurrentCamera.CameraSubject = _hum
                end
            end
        end)
    end)
end

-- Обнаружение начала рагдолла
local function _onRagdollStart()
    if _ragdollActive then return end
    _ragdollActive = true

    -- Создаём призрака в текущей позиции
    _createGhost()
end

-- Обнаружение конца рагдолла (вызывается из heartbeat)
local function _checkRagdollEnd()
    if not _ragdollActive then return end
    if not (_hum and _char) then return end

    local st = _hum:GetState()

    -- Рагдолл закончился?
    if not _isRag(st) and st ~= Enum.HumanoidStateType.PlatformStanding then
        if not _hum.PlatformStand then
            _exitRagdoll()
        end
    end
end

local function _startAR()
    if not (_char and _hum) then return end
    _saveMotorSnapshot()

    local c1 = _hum.StateChanged:Connect(function(_, new)
        if not _CFG._ar then return end
        if _isRag(new) or new == Enum.HumanoidStateType.PlatformStanding then
            task.delay(_rd(), _onRagdollStart)
        elseif new == Enum.HumanoidStateType.GettingUp or new == Enum.HumanoidStateType.Running then
            if _ragdollActive then
                task.delay(0.05 + _rd(), _exitRagdoll)
            end
        end
    end)
    _rc[#_rc + 1] = c1

    local c2 = _hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not _CFG._ar then return end
        if _hum.PlatformStand and not _ragdollActive then
            task.delay(_rd(), _onRagdollStart)
        end
    end)
    _rc[#_rc + 1] = c2

    local c3 = _char.DescendantAdded:Connect(function(v)
        if not _CFG._ar then return end
        task.delay(_rd(), function()
            pcall(function()
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint")
                    or v:IsA("NoCollisionConstraint") or v:IsA("RopeConstraint")
                    or v:IsA("SpringConstraint") then
                    if not _ragdollActive then
                        _onRagdollStart()
                    end
                end
            end)
        end)
    end)
    _rc[#_rc + 1] = c3

    local c4 = _char.DescendantRemoving:Connect(function(v)
        if not _CFG._ar then return end
        if v:IsA("Motor6D") then
            local data = {
                _n = v.Name, _p = v.Parent,
                _p0 = v.Part0, _p1 = v.Part1,
                _c0 = v.C0, _c1 = v.C1,
            }
            -- Обновляем snapshot
            local found = false
            for _, snap in ipairs(_motorSnap) do
                if snap._n == data._n and snap._p == data._p then
                    snap._c0 = data._c0
                    snap._c1 = data._c1
                    found = true
                    break
                end
            end
            if not found then
                _motorSnap[#_motorSnap + 1] = data
            end
        end
    end)
    _rc[#_rc + 1] = c4
end

local function _stopAR()
    for _, c in ipairs(_rc) do pcall(function() c:Disconnect() end) end
    _rc = {}
    _destroyGhost()
    _ragdollActive = false
    for _, m in ipairs(_fakeMotors) do pcall(function() if m and m.Parent then m:Destroy() end end) end
    _fakeMotors = {}
    _motorSnap = {}
end

-- ===================== NO ANIMATIONS =====================
local function _hookTrack(track)
    if not track or _tt[track] then return end
    _tt[track] = true
    local conn = track:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if not _CFG._na then return end
        if track.IsPlaying then
            task.delay(_rd(), function()
                pcall(function() track:AdjustSpeed(0) track:AdjustWeight(0, 0) end)
            end)
        end
    end)
    _ac[#_ac + 1] = conn
    if _CFG._na and track.IsPlaying then
        pcall(function() track:AdjustSpeed(0) track:AdjustWeight(0, 0) end)
    end
end

local function _suppTracks()
    if not _anim then return end
    pcall(function()
        for _, t in ipairs(_anim:GetPlayingAnimationTracks()) do
            pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
        end
    end)
end

local function _hookAnim()
    if not _anim then return end
    pcall(function()
        local c = _anim.AnimationPlayed:Connect(function(t)
            _hookTrack(t)
            if _CFG._na then
                task.delay(_rd(), function()
                    pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
                end)
            end
        end)
        _ac[#_ac + 1] = c
    end)
    if _hum then
        for _, e in ipairs({"Running","Jumping","Climbing","Swimming","FreeFalling"}) do
            pcall(function()
                local c = _hum[e]:Connect(function()
                    if _CFG._na then task.defer(_suppTracks) end
                end)
                _ac[#_ac + 1] = c
            end)
        end
        local c = _hum.StateChanged:Connect(function()
            if _CFG._na then task.defer(_suppTracks) end
        end)
        _ac[#_ac + 1] = c
    end
    pcall(function()
        for _, t in ipairs(_anim:GetPlayingAnimationTracks()) do _hookTrack(t) end
    end)
end
local function _startNA() _hookAnim() end
local function _stopNA()
    for _, c in ipairs(_ac) do pcall(function() c:Disconnect() end) end
    _ac = {}
    for t in pairs(_tt) do
        pcall(function() if t and t.IsPlaying then t:AdjustSpeed(1) t:AdjustWeight(1, 0.1) end end)
    end
    _tt = {}
end

-- ===================== HEARTBEAT =====================
local _frameCount = 0
_hbc = _RS.Heartbeat:Connect(function(dt)
    _frameCount = _frameCount + 1
    if not (_char and _char.Parent) then _ref() return end
    if not (_hum and _hum.Health > 0) then return end

    -- Ghost контроль каждый кадр
    if _CFG._ar and _ghostMode then
        _controlGhost()
    end

    -- Anti-ragdoll проверки (каждые 3 кадра для производительности)
    if _CFG._ar and _frameCount % 3 == 0 then
        _checkRagdollEnd()

        -- Резервная проверка: если рагдолл активен но призрака нет
        if _ragdollActive and not (_ghostPart and _ghostPart.Parent) then
            _ghostMode = false
            _ragdollActive = false
        end

        -- Таймаут: если рагдолл длится > 5 сек, форсим выход
        if _ragdollActive then
            local st = _hum:GetState()
            if not _isRag(st) and st ~= Enum.HumanoidStateType.PlatformStanding
                and not _hum.PlatformStand then
                _exitRagdoll()
            end
        end
    end

    if _CFG._na and _frameCount % 2 == 0 then
        _suppTracks()
    end
end)

-- ===================== РЕСПАВН =====================
_lp.CharacterAdded:Connect(function()
    task.wait(_rm(0.35, 0.55))
    _destroyGhost()
    _ragdollActive = false
    _ref()
    task.wait(_rm(0.15, 0.3))
    if _CFG._ar then _stopAR() _startAR() end
    if _CFG._na then _stopNA() task.wait(0.15) _startNA() end
end)

-- ===================== GUI v12.0 =====================
local _gn = _gid(14)
for _, g in ipairs(_pg:GetChildren()) do
    if g:IsA("ScreenGui") and (g.Name == "GranzHubGUI" or g.Name == _gn) then
        g:Destroy()
    end
end

local SG = Instance.new("ScreenGui")
SG.Name = _gn
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = _ri(1, 8)
SG.Parent = _pg

-- ============ ЦВЕТА v12 ============
local K = {
    bg = Color3.fromRGB(8, 8, 14),
    bg2 = Color3.fromRGB(14, 14, 22),
    panel = Color3.fromRGB(18, 18, 28),
    panelH = Color3.fromRGB(24, 24, 36),
    hdr = Color3.fromRGB(12, 12, 20),

    a1 = Color3.fromRGB(155, 90, 255),
    a2 = Color3.fromRGB(60, 200, 255),
    a3 = Color3.fromRGB(255, 85, 85),
    a4 = Color3.fromRGB(255, 195, 50),
    a5 = Color3.fromRGB(80, 255, 160),

    tw = Color3.fromRGB(235, 235, 245),
    td = Color3.fromRGB(90, 90, 110),
    tg = Color3.fromRGB(80, 255, 140),
    tr = Color3.fromRGB(255, 75, 75),

    tOff = Color3.fromRGB(35, 35, 50),
    tKOff = Color3.fromRGB(120, 120, 140),

    brd = Color3.fromRGB(40, 40, 58),
}

-- ============ UTILITY FUNCTIONS ============
local function mkCorner(p, r) local c = Instance.new("UICorner", p) c.CornerRadius = UDim.new(0, r or 12) return c end
local function mkStroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or K.brd
    s.Thickness = th or 1
    s.Transparency = tr or 0.5
    s.Parent = p
    return s
end
local function mkPad(p, t, b, l, r)
    local pd = Instance.new("UIPadding", p)
    pd.PaddingTop = UDim.new(0, t or 0)
    pd.PaddingBottom = UDim.new(0, b or 0)
    pd.PaddingLeft = UDim.new(0, l or 0)
    pd.PaddingRight = UDim.new(0, r or 0)
    return pd
end

local function _ti(d, s, dir)
    return TweenInfo.new(d or 0.3, s or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
end

-- ============ ГЛАВНЫЙ ФРЕЙМ ============
local MF = Instance.new("Frame")
MF.Name = _gid(6)
MF.Size = UDim2.new(0, 360, 0, 470)
MF.Position = UDim2.new(0.5, -180, 0.5, -235)
MF.BackgroundColor3 = K.bg
MF.BackgroundTransparency = 0.02
MF.BorderSizePixel = 0
MF.Active = true
MF.Draggable = true
MF.ClipsDescendants = true
MF.Parent = SG
mkCorner(MF, 22)

local MFS = mkStroke(MF, K.a1, 1.5, 0.5)

-- Тень
local Sh = Instance.new("ImageLabel")
Sh.Name = _gid(3)
Sh.Size = UDim2.new(1, 50, 1, 50)
Sh.Position = UDim2.new(0, -25, 0, -25)
Sh.BackgroundTransparency = 1
Sh.Image = "rbxassetid://6015897843"
Sh.ImageColor3 = Color3.new(0, 0, 0)
Sh.ImageTransparency = 0.35
Sh.ScaleType = Enum.ScaleType.Slice
Sh.SliceCenter = Rect.new(49, 49, 450, 450)
Sh.ZIndex = -1
Sh.Parent = MF

-- Декоративные glow-сферы (больше и красивее)
local function mkGlow(pos, col, sz, tr)
    local g = Instance.new("Frame")
    g.Name = _gid(3)
    g.Size = UDim2.new(0, sz, 0, sz)
    g.Position = pos
    g.BackgroundColor3 = col
    g.BackgroundTransparency = tr or 0.92
    g.BorderSizePixel = 0
    g.ZIndex = 0
    g.Parent = MF
    mkCorner(g, sz)
    return g
end

local gl1 = mkGlow(UDim2.new(0, -40, 0, -40), K.a1, 150, 0.93)
local gl2 = mkGlow(UDim2.new(1, -70, 1, -90), K.a2, 130, 0.94)
local gl3 = mkGlow(UDim2.new(0.3, 0, 0, 30), K.a3, 90, 0.95)
local gl4 = mkGlow(UDim2.new(0.7, -20, 0.5, 0), K.a5, 70, 0.96)

-- Паттерн на фоне (сетка точек)
for row = 0, 8 do
    for col = 0, 6 do
        local dot = Instance.new("Frame")
        dot.Name = _gid(2)
        dot.Size = UDim2.new(0, 2, 0, 2)
        dot.Position = UDim2.new(0, 20 + col * 50, 0, 70 + row * 45)
        dot.BackgroundColor3 = K.tw
        dot.BackgroundTransparency = 0.94
        dot.BorderSizePixel = 0
        dot.ZIndex = 0
        dot.Parent = MF
        mkCorner(dot, 2)
    end
end

-- ============ HEADER ============
local HD = Instance.new("Frame")
HD.Name = _gid(4)
HD.Size = UDim2.new(1, 0, 0, 60)
HD.BackgroundColor3 = K.hdr
HD.BackgroundTransparency = 0.15
HD.BorderSizePixel = 0
HD.ZIndex = 5
HD.Parent = MF
mkCorner(HD, 22)

local HDF = Instance.new("Frame")
HDF.Name = _gid(2)
HDF.Size = UDim2.new(1, 0, 0, 22)
HDF.Position = UDim2.new(0, 0, 1, -22)
HDF.BackgroundColor3 = K.hdr
HDF.BackgroundTransparency = 0.15
HDF.BorderSizePixel = 0
HDF.ZIndex = 5
HDF.Parent = HD

-- Градиентная линия под хедером
local HLine = Instance.new("Frame")
HLine.Name = _gid(3)
HLine.Size = UDim2.new(0.85, 0, 0, 2.5)
HLine.Position = UDim2.new(0.075, 0, 1, 0)
HLine.BackgroundColor3 = K.tw
HLine.BackgroundTransparency = 0.3
HLine.BorderSizePixel = 0
HLine.ZIndex = 6
HLine.Parent = HD
mkCorner(HLine, 3)

local HLG = Instance.new("UIGradient")
HLG.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, K.a1),
    ColorSequenceKeypoint.new(0.25, K.a2),
    ColorSequenceKeypoint.new(0.5, K.a5),
    ColorSequenceKeypoint.new(0.75, K.a4),
    ColorSequenceKeypoint.new(1, K.a3),
}
HLG.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0.6),
    NumberSequenceKeypoint.new(0.3, 0),
    NumberSequenceKeypoint.new(0.7, 0),
    NumberSequenceKeypoint.new(1, 0.6),
}
HLG.Parent = HLine

-- Лого
local LogoFrame = Instance.new("Frame")
LogoFrame.Name = _gid(3)
LogoFrame.Size = UDim2.new(0, 34, 0, 34)
LogoFrame.Position = UDim2.new(0, 16, 0.5, -17)
LogoFrame.BackgroundColor3 = K.a1
LogoFrame.BackgroundTransparency = 0.75
LogoFrame.BorderSizePixel = 0
LogoFrame.ZIndex = 6
LogoFrame.Parent = HD
mkCorner(LogoFrame, 10)
mkStroke(LogoFrame, K.a1, 1, 0.4)

local LogoIcon = Instance.new("TextLabel")
LogoIcon.Size = UDim2.new(1, 0, 1, 0)
LogoIcon.BackgroundTransparency = 1
LogoIcon.Text = "⚡"
LogoIcon.TextSize = 16
LogoIcon.Font = Enum.Font.GothamBold
LogoIcon.ZIndex = 7
LogoIcon.Parent = LogoFrame

local Title = Instance.new("TextLabel")
Title.Name = _gid(3)
Title.Size = UDim2.new(0, 120, 0, 20)
Title.Position = UDim2.new(0, 58, 0, 12)
Title.BackgroundTransparency = 1
Title.Text = "GRANZ HUB"
Title.TextColor3 = K.tw
Title.TextSize = 16
Title.Font = Enum.Font.GothamBlack
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 6
Title.Parent = HD

local SubTitle = Instance.new("TextLabel")
SubTitle.Name = _gid(3)
SubTitle.Size = UDim2.new(0, 150, 0, 14)
SubTitle.Position = UDim2.new(0, 58, 0, 33)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "phantom ghost · v12.0"
SubTitle.TextColor3 = K.td
SubTitle.TextSize = 10
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.ZIndex = 6
SubTitle.Parent = HD

-- Бейдж версии
local Badge = Instance.new("Frame")
Badge.Name = _gid(3)
Badge.Size = UDim2.new(0, 52, 0, 20)
Badge.Position = UDim2.new(0, 178, 0, 32)
Badge.BackgroundColor3 = K.a5
Badge.BackgroundTransparency = 0.85
Badge.BorderSizePixel = 0
Badge.ZIndex = 6
Badge.Parent = HD
mkCorner(Badge, 6)
mkStroke(Badge, K.a5, 1, 0.5)

local BadgeTxt = Instance.new("TextLabel")
BadgeTxt.Size = UDim2.new(1, 0, 1, 0)
BadgeTxt.BackgroundTransparency = 1
BadgeTxt.Text = "GHOST"
BadgeTxt.TextColor3 = K.a5
BadgeTxt.TextSize = 8
BadgeTxt.Font = Enum.Font.GothamBlack
BadgeTxt.ZIndex = 7
BadgeTxt.Parent = Badge

-- Кнопки хедера
local function mkHdrBtn(pos, txt, bgCol, txtCol)
    local b = Instance.new("TextButton")
    b.Name = _gid(3)
    b.Size = UDim2.new(0, 34, 0, 34)
    b.Position = pos
    b.BackgroundColor3 = bgCol
    b.BackgroundTransparency = 0.4
    b.Text = txt
    b.TextColor3 = txtCol or K.tw
    b.TextSize = 14
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.ZIndex = 6
    b.Parent = HD
    mkCorner(b, 10)

    b.MouseEnter:Connect(function()
        _TS:Create(b, _ti(0.2), {BackgroundTransparency = 0.15, Size = UDim2.new(0, 36, 0, 36)}):Play()
    end)
    b.MouseLeave:Connect(function()
        _TS:Create(b, _ti(0.2), {BackgroundTransparency = 0.4, Size = UDim2.new(0, 34, 0, 34)}):Play()
    end)

    return b
end

local MinB = mkHdrBtn(UDim2.new(1, -82, 0, 13), "━", Color3.fromRGB(50, 50, 65))
local ClsB = mkHdrBtn(UDim2.new(1, -44, 0, 13), "✕", Color3.fromRGB(180, 40, 40))

-- ============ КОНТЕНТ ============
local CT = Instance.new("ScrollingFrame")
CT.Name = _gid(4)
CT.Size = UDim2.new(1, -20, 1, -76)
CT.Position = UDim2.new(0, 10, 0, 66)
CT.BackgroundTransparency = 1
CT.BorderSizePixel = 0
CT.ScrollBarThickness = 2
CT.ScrollBarImageColor3 = K.a1
CT.ScrollBarImageTransparency = 0.6
CT.CanvasSize = UDim2.new(0, 0, 0, 0)
CT.AutomaticCanvasSize = Enum.AutomaticSize.Y
CT.ZIndex = 3
CT.Parent = MF

local CTL = Instance.new("UIListLayout", CT)
CTL.SortOrder = Enum.SortOrder.LayoutOrder
CTL.Padding = UDim.new(0, 8)

mkPad(CT, 2, 10, 0, 0)

-- ============ МОДУЛИ v12 ============
local function createModule(icon, name, desc, order, acCol, features)
    local Mod = Instance.new("Frame")
    Mod.Name = _gid(5)
    Mod.Size = UDim2.new(1, 0, 0, 84)
    Mod.BackgroundColor3 = K.panel
    Mod.BackgroundTransparency = 0.15
    Mod.BorderSizePixel = 0
    Mod.LayoutOrder = order
    Mod.ZIndex = 3
    Mod.ClipsDescendants = true
    Mod.Parent = CT
    mkCorner(Mod, 14)

    local ModS = mkStroke(Mod, K.brd, 1, 0.6)

    -- Градиентная полоска слева
    local LeftBar = Instance.new("Frame")
    LeftBar.Name = _gid(2)
    LeftBar.Size = UDim2.new(0, 3, 0.6, 0)
    LeftBar.Position = UDim2.new(0, 0, 0.2, 0)
    LeftBar.BackgroundColor3 = acCol
    LeftBar.BackgroundTransparency = 0.5
    LeftBar.BorderSizePixel = 0
    LeftBar.ZIndex = 4
    LeftBar.Parent = Mod
    mkCorner(LeftBar, 2)

    -- Иконка
    local IconBG = Instance.new("Frame")
    IconBG.Name = _gid(3)
    IconBG.Size = UDim2.new(0, 42, 0, 42)
    IconBG.Position = UDim2.new(0, 14, 0.5, -21)
    IconBG.BackgroundColor3 = acCol
    IconBG.BackgroundTransparency = 0.88
    IconBG.BorderSizePixel = 0
    IconBG.ZIndex = 4
    IconBG.Parent = Mod
    mkCorner(IconBG, 12)

    local IconLbl = Instance.new("TextLabel")
    IconLbl.Size = UDim2.new(1, 0, 1, 0)
    IconLbl.BackgroundTransparency = 1
    IconLbl.Text = icon
    IconLbl.TextSize = 20
    IconLbl.Font = Enum.Font.GothamBold
    IconLbl.ZIndex = 5
    IconLbl.Parent = IconBG

    -- Название
    local NL = Instance.new("TextLabel")
    NL.Size = UDim2.new(1, -140, 0, 20)
    NL.Position = UDim2.new(0, 66, 0, 14)
    NL.BackgroundTransparency = 1
    NL.Text = name
    NL.TextColor3 = K.tw
    NL.TextSize = 14
    NL.Font = Enum.Font.GothamBold
    NL.TextXAlignment = Enum.TextXAlignment.Left
    NL.ZIndex = 4
    NL.Parent = Mod

    -- Описание
    local DL = Instance.new("TextLabel")
    DL.Size = UDim2.new(1, -140, 0, 14)
    DL.Position = UDim2.new(0, 66, 0, 36)
    DL.BackgroundTransparency = 1
    DL.Text = desc
    DL.TextColor3 = K.td
    DL.TextSize = 10
    DL.Font = Enum.Font.Gotham
    DL.TextXAlignment = Enum.TextXAlignment.Left
    DL.ZIndex = 4
    DL.Parent = Mod

    -- Фичи (маленькие теги)
    if features then
        local tagX = 66
        for i, tag in ipairs(features) do
            local tagF = Instance.new("Frame")
            tagF.Name = _gid(2)
            tagF.Size = UDim2.new(0, #tag * 5.5 + 12, 0, 16)
            tagF.Position = UDim2.new(0, tagX, 0, 54)
            tagF.BackgroundColor3 = acCol
            tagF.BackgroundTransparency = 0.9
            tagF.BorderSizePixel = 0
            tagF.ZIndex = 4
            tagF.Parent = Mod
            mkCorner(tagF, 4)

            local tagL = Instance.new("TextLabel")
            tagL.Size = UDim2.new(1, 0, 1, 0)
            tagL.BackgroundTransparency = 1
            tagL.Text = tag
            tagL.TextColor3 = acCol
            tagL.TextSize = 8
            tagL.Font = Enum.Font.GothamMedium
            tagL.ZIndex = 5
            tagL.Parent = tagF

            tagX = tagX + #tag * 5.5 + 16
        end
    end

    -- Toggle
    local TBG = Instance.new("TextButton")
    TBG.Name = _gid(3)
    TBG.Size = UDim2.new(0, 50, 0, 28)
    TBG.Position = UDim2.new(1, -62, 0.5, -14)
    TBG.BackgroundColor3 = K.tOff
    TBG.Text = ""
    TBG.BorderSizePixel = 0
    TBG.AutoButtonColor = false
    TBG.ZIndex = 4
    TBG.Parent = Mod
    mkCorner(TBG, 14)

    local TKnob = Instance.new("Frame")
    TKnob.Name = _gid(2)
    TKnob.Size = UDim2.new(0, 22, 0, 22)
    TKnob.Position = UDim2.new(0, 3, 0.5, -11)
    TKnob.BackgroundColor3 = K.tKOff
    TKnob.BorderSizePixel = 0
    TKnob.ZIndex = 5
    TKnob.Parent = TBG
    mkCorner(TKnob, 11)

    local KGlow = mkStroke(TKnob, acCol, 0, 0.7)

    -- Статус точка
    local SDot = Instance.new("Frame")
    SDot.Name = _gid(2)
    SDot.Size = UDim2.new(0, 7, 0, 7)
    SDot.Position = UDim2.new(1, -18, 0, 8)
    SDot.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    SDot.BorderSizePixel = 0
    SDot.ZIndex = 5
    SDot.Parent = Mod
    mkCorner(SDot, 4)

    -- Hover
    local hovBtn = Instance.new("TextButton")
    hovBtn.Size = UDim2.new(1, 0, 1, 0)
    hovBtn.BackgroundTransparency = 1
    hovBtn.Text = ""
    hovBtn.ZIndex = 3
    hovBtn.Parent = Mod

    hovBtn.MouseEnter:Connect(function()
        _TS:Create(Mod, _ti(0.25), {BackgroundTransparency = 0.05}):Play()
        _TS:Create(ModS, _ti(0.25), {Transparency = 0.3}):Play()
        _TS:Create(LeftBar, _ti(0.25), {BackgroundTransparency = 0.2, Size = UDim2.new(0, 4, 0.7, 0)}):Play()
    end)
    hovBtn.MouseLeave:Connect(function()
        _TS:Create(Mod, _ti(0.25), {BackgroundTransparency = 0.15}):Play()
        _TS:Create(ModS, _ti(0.25), {Transparency = 0.6}):Play()
        _TS:Create(LeftBar, _ti(0.25), {BackgroundTransparency = 0.5, Size = UDim2.new(0, 3, 0.6, 0)}):Play()
    end)

    local function updVis(state)
        local ti = _ti(0.35)
        if state then
            _TS:Create(TBG, ti, {BackgroundColor3 = acCol}):Play()
            _TS:Create(TKnob, ti, {
                Position = UDim2.new(1, -25, 0.5, -11),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            }):Play()
            _TS:Create(KGlow, ti, {Thickness = 2.5, Transparency = 0.2}):Play()
            _TS:Create(ModS, ti, {Color = acCol, Transparency = 0.35}):Play()
            _TS:Create(IconBG, ti, {BackgroundTransparency = 0.75}):Play()
            _TS:Create(LeftBar, ti, {BackgroundTransparency = 0.15}):Play()
            _TS:Create(SDot, ti, {BackgroundColor3 = K.tg}):Play()
            -- Pulse animation on toggle
            local pulse = _TS:Create(TBG, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
                Size = UDim2.new(0, 54, 0, 32)
            })
            pulse:Play()
        else
            _TS:Create(TBG, ti, {BackgroundColor3 = K.tOff}):Play()
            _TS:Create(TKnob, ti, {
                Position = UDim2.new(0, 3, 0.5, -11),
                BackgroundColor3 = K.tKOff
            }):Play()
            _TS:Create(KGlow, ti, {Thickness = 0, Transparency = 0.8}):Play()
            _TS:Create(ModS, ti, {Color = K.brd, Transparency = 0.6}):Play()
            _TS:Create(IconBG, ti, {BackgroundTransparency = 0.88}):Play()
            _TS:Create(LeftBar, ti, {BackgroundTransparency = 0.5}):Play()
            _TS:Create(SDot, ti, {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
        end
    end

    return TBG, updVis
end

local JT, JV = createModule("⚡", "Infinite Jump", "Бесконечные прыжки в воздухе", 1, K.a1, {"AIR","MULTI"})
local RT, RV = createModule("👻", "Ghost Anti-Ragdoll", "Призрак: тело летит, ты ходишь", 2, K.a2, {"GHOST","SAB"})
local AT, AV = createModule("🎭", "No Animations", "Полное отключение анимаций", 3, K.a3, {"FREEZE"})

-- ============ РАЗДЕЛИТЕЛЬ ============
local Sep = Instance.new("Frame")
Sep.Name = _gid(3)
Sep.Size = UDim2.new(0.9, 0, 0, 1)
Sep.BackgroundColor3 = K.tw
Sep.BackgroundTransparency = 0.9
Sep.BorderSizePixel = 0
Sep.LayoutOrder = 5
Sep.ZIndex = 3
Sep.Parent = CT
local SepGrad = Instance.new("UIGradient", Sep)
SepGrad.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.3, 0),
    NumberSequenceKeypoint.new(0.7, 0),
    NumberSequenceKeypoint.new(1, 1),
}

-- ============ СТАТУС-БАР v12 ============
local SB = Instance.new("Frame")
SB.Name = _gid(4)
SB.Size = UDim2.new(1, 0, 0, 44)
SB.BackgroundColor3 = K.bg2
SB.BackgroundTransparency = 0.3
SB.BorderSizePixel = 0
SB.LayoutOrder = 10
SB.ZIndex = 3
SB.Parent = CT
mkCorner(SB, 12)
mkStroke(SB, K.brd, 1, 0.7)

-- Индикаторы
local dots = {}
local dotColors = {K.a1, K.a2, K.a3}
for i = 1, 3 do
    local d = Instance.new("Frame")
    d.Name = _gid(2)
    d.Size = UDim2.new(0, 8, 0, 8)
    d.Position = UDim2.new(0, 10 + (i - 1) * 14, 0.5, -4)
    d.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    d.BorderSizePixel = 0
    d.ZIndex = 4
    d.Parent = SB
    mkCorner(d, 4)
    dots[i] = d
end

local SL = Instance.new("TextLabel")
SL.Name = _gid(3)
SL.Size = UDim2.new(1, -60, 0, 16)
SL.Position = UDim2.new(0, 52, 0, 6)
SL.BackgroundTransparency = 1
SL.Text = "Ready"
SL.TextColor3 = K.td
SL.TextSize = 10
SL.Font = Enum.Font.GothamMedium
SL.TextXAlignment = Enum.TextXAlignment.Left
SL.ZIndex = 4
SL.Parent = SB

-- Ghost mode индикатор
local GhostInd = Instance.new("TextLabel")
GhostInd.Name = _gid(3)
GhostInd.Size = UDim2.new(1, -60, 0, 12)
GhostInd.Position = UDim2.new(0, 52, 0, 24)
GhostInd.BackgroundTransparency = 1
GhostInd.Text = ""
GhostInd.TextColor3 = K.a2
GhostInd.TextSize = 9
GhostInd.Font = Enum.Font.Gotham
GhostInd.TextXAlignment = Enum.TextXAlignment.Left
GhostInd.ZIndex = 4
GhostInd.Parent = SB

local function updateStat()
    local cnt = 0
    local states = {_CFG._j, _CFG._ar, _CFG._na}
    for i, s in ipairs(states) do
        if s then
            cnt += 1
            _TS:Create(dots[i], _ti(0.3), {BackgroundColor3 = dotColors[i]}):Play()
        else
            _TS:Create(dots[i], _ti(0.3), {BackgroundColor3 = Color3.fromRGB(40, 40, 55)}):Play()
        end
    end
    if cnt == 0 then
        SL.Text = "Все модули неактивны"
        _TS:Create(SL, _ti(0.3), {TextColor3 = K.td}):Play()
    else
        SL.Text = cnt .. "/3 активно  ·  PHANTOM GHOST"
        _TS:Create(SL, _ti(0.3), {TextColor3 = K.tg}):Play()
    end
end

-- Ghost mode status updater
task.spawn(function()
    while SG and SG.Parent do
        if _ghostMode then
            GhostInd.Text = "👻 GHOST MODE ACTIVE — body in ragdoll"
            GhostInd.TextColor3 = K.a2
        else
            GhostInd.Text = ""
        end
        task.wait(0.1)
    end
end)

-- ============ ОБРАБОТЧИКИ ============
JT.MouseButton1Click:Connect(function()
    _CFG._j = not _CFG._j
    JV(_CFG._j)
    if _CFG._j then _ref() end
    updateStat()
end)

RT.MouseButton1Click:Connect(function()
    _CFG._ar = not _CFG._ar
    RV(_CFG._ar)
    if _CFG._ar then
        _ref()
        _startAR()
    else
        _stopAR()
    end
    updateStat()
end)

AT.MouseButton1Click:Connect(function()
    _CFG._na = not _CFG._na
    AV(_CFG._na)
    if _CFG._na then _ref() _startNA()
    else _stopNA() end
    updateStat()
end)

-- ============ MINIMIZE / CLOSE ============
local _fullSz = MF.Size
local _fullPos = MF.Position

MinB.MouseButton1Click:Connect(function()
    _minimized = not _minimized
    local ti = _ti(0.4, Enum.EasingStyle.Back)
    if _minimized then
        _TS:Create(MF, _ti(0.35), {Size = UDim2.new(0, 360, 0, 60)}):Play()
        task.delay(0.05, function() CT.Visible = false HLine.Visible = false end)
        MinB.Text = "▪"
    else
        _TS:Create(MF, ti, {Size = _fullSz}):Play()
        task.delay(0.25, function() CT.Visible = true HLine.Visible = true end)
        MinB.Text = "━"
    end
end)

ClsB.MouseButton1Click:Connect(function()
    _CFG._j = false
    _CFG._ar = false
    _CFG._na = false
    _stopAR()
    _stopNA()
    if _hbc then _hbc:Disconnect() end

    -- Красивая анимация закрытия
    local ti = _ti(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    _TS:Create(MF, ti, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 1
    }):Play()
    _TS:Create(MFS, _ti(0.4), {Transparency = 1}):Play()
    _TS:Create(Sh, _ti(0.3), {ImageTransparency = 1}):Play()
    task.delay(0.55, function() SG:Destroy() end)
end)

-- ============ ЖИВЫЕ АНИМАЦИИ ============
-- 1. Обводка переливается
task.spawn(function()
    local h = _rm(0, 1)
    while SG and SG.Parent do
        h = (h + 0.0015) % 1
        local ac = 0
        if _CFG._j then ac += 1 end
        if _CFG._ar then ac += 1 end
        if _CFG._na then ac += 1 end

        if ac > 0 then
            local sat = 0.6 + ac * 0.1
            local val = 0.85 + ac * 0.05
            MFS.Color = Color3.fromHSV(h, sat, val)
            MFS.Transparency = 0.1 + math.sin(tick() * 2) * 0.08
            MFS.Thickness = 1.5 + math.sin(tick() * 3) * 0.4
        else
            MFS.Color = K.brd
            MFS.Transparency = 0.65
            MFS.Thickness = 1
        end
        task.wait(0.02)
    end
end)

-- 2. Glow-сферы дышат
task.spawn(function()
    while SG and SG.Parent do
        local t = tick()
        pcall(function()
            gl1.BackgroundTransparency = 0.9 + math.sin(t * 1.2) * 0.04
            gl2.BackgroundTransparency = 0.91 + math.cos(t * 1.5) * 0.035
            gl3.BackgroundTransparency = 0.92 + math.sin(t * 1.8) * 0.03
            gl4.BackgroundTransparency = 0.93 + math.cos(t * 2.1) * 0.025

            gl1.Position = UDim2.new(0, -40 + math.sin(t * 0.5) * 5, 0, -40 + math.cos(t * 0.7) * 5)
            gl2.Position = UDim2.new(1, -70 + math.cos(t * 0.4) * 4, 1, -90 + math.sin(t * 0.6) * 4)
            gl3.Position = UDim2.new(0.3, math.sin(t * 0.8) * 6, 0, 30 + math.cos(t * 0.5) * 3)
            gl4.Position = UDim2.new(0.7, -20 + math.cos(t * 0.6) * 5, 0.5, math.sin(t * 0.9) * 4)
        end)
        task.wait(0.03)
    end
end)

-- 3. Градиент линии ползёт
task.spawn(function()
    local off = 0
    while SG and SG.Parent do
        off = (off + 0.003) % 1
        pcall(function()
            HLG.Offset = Vector2.new(math.sin(off * math.pi * 2) * 0.4, 0)
        end)
        task.wait(0.025)
    end
end)

-- 4. Лого пульсирует
task.spawn(function()
    while SG and SG.Parent do
        local ac = 0
        if _CFG._j then ac += 1 end
        if _CFG._ar then ac += 1 end
        if _CFG._na then ac += 1 end

        if ac > 0 then
            _TS:Create(LogoFrame, _ti(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.65,
                Size = UDim2.new(0, 36, 0, 36)
            }):Play()
            task.wait(1.2)
            if not (SG and SG.Parent) then return end
            _TS:Create(LogoFrame, _ti(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.8,
                Size = UDim2.new(0, 34, 0, 34)
            }):Play()
            task.wait(1.2)
        else
            task.wait(0.5)
        end
    end
end)

-- 5. Точки-индикаторы пульсируют когда активны
task.spawn(function()
    while SG and SG.Parent do
        local states = {_CFG._j, _CFG._ar, _CFG._na}
        for i, s in ipairs(states) do
            if s then
                pcall(function()
                    _TS:Create(dots[i], _ti(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        Size = UDim2.new(0, 10, 0, 10),
                        Position = UDim2.new(0, 9 + (i-1)*14, 0.5, -5)
                    }):Play()
                end)
            end
        end
        task.wait(0.6)
        if not (SG and SG.Parent) then return end
        for i, s in ipairs(states) do
            if s then
                pcall(function()
                    _TS:Create(dots[i], _ti(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        Size = UDim2.new(0, 8, 0, 8),
                        Position = UDim2.new(0, 10 + (i-1)*14, 0.5, -4)
                    }):Play()
                end)
            end
        end
        task.wait(0.6)
    end
end)

-- ============ ОТКРЫВАЮЩАЯ АНИМАЦИЯ ============
MF.Size = UDim2.new(0, 360, 0, 0)
MF.Position = UDim2.new(0.5, -180, 0.5, 0)
MF.BackgroundTransparency = 1
CT.Visible = false
HLine.Visible = false

task.delay(0.05, function()
    -- Фаза 1: появление
    _TS:Create(MF, _ti(0.15), {BackgroundTransparency = 0.02}):Play()
    _TS:Create(MFS, _ti(0.3), {Transparency = 0.4}):Play()
    task.wait(0.1)

    -- Фаза 2: раскрытие
    _TS:Create(MF, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 360, 0, 470),
        Position = UDim2.new(0.5, -180, 0.5, -235)
    }):Play()
    task.wait(0.35)

    -- Фаза 3: контент
    CT.Visible = true
    HLine.Visible = true

    -- Фаза 4: модули появляются один за другим
    for _, child in ipairs(CT:GetChildren()) do
        if child:IsA("Frame") and child ~= Sep then
            child.BackgroundTransparency = 1
        end
    end
    task.wait(0.1)
    for _, child in ipairs(CT:GetChildren()) do
        if child:IsA("Frame") and child ~= Sep then
            _TS:Create(child, _ti(0.4), {BackgroundTransparency = child == SB and 0.3 or 0.15}):Play()
            task.wait(0.08)
        end
    end
end)

updateStat()
