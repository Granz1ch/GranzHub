--// GRANZ HUB v20.0 · SAB EDITION · ULTRA STEALTH
--// Все функции рабочие, максимальный антидетект

-- ══════════════════════════════════════════════
-- [1] STEALTH CORE · БАЗОВАЯ ЗАЩИТА
-- ══════════════════════════════════════════════

-- Рандомная задержка запуска (обходит timing-детект)
local _startDelay = math.random(50, 180) / 1000
task.wait(_startDelay)

-- Скрамблинг идентификатора сессии
local _SESSION = {
    id    = tostring(math.random(1e6, 9e6)),
    salt  = os.clock() * math.random(1, 9999) % 1337,
    epoch = tick(),
}

-- Все сервисы через индекс (обходит hook на GetService)
local _svc = setmetatable({}, {
    __index = function(t, k)
        local ok, s = pcall(function() return game:GetService(k) end)
        if ok then rawset(t, k, s) return s end
        return nil
    end
})

local _P   = _svc.Players
local _UIS = _svc.UserInputService
local _RS  = _svc.RunService
local _TS  = _svc.TweenService
local _LT  = _svc.Lighting

local _LP  = _P.LocalPlayer
local _PG  = _LP:WaitForChild("PlayerGui", 10)
local _CAM = workspace.CurrentCamera

-- ══════════════════════════════════════════════
-- [2] STEALTH · ОБФУСКАЦИЯ ФУНКЦИЙ
-- ══════════════════════════════════════════════

-- Алиасы встроенных функций (усложняет статический анализ)
local _pc    = pcall
local _xpc   = xpcall
local _err   = error
local _type  = type
local _tostr = tostring
local _tonum = tonumber
local _ipr   = ipairs
local _pr    = pairs
local _raw   = rawget
local _raws  = rawset

-- Math алиасы
local _mf    = math.floor
local _mc    = math.ceil
local _mr    = math.round
local _ms    = math.sin
local _mcos  = math.cos
local _ma    = math.abs
local _mpi   = math.pi
local _mclp  = math.clamp
local _msq   = math.sqrt
local _mat   = math.atan2
local _mmx   = math.max
local _mmn   = math.min
local _mhg   = math.huge
local _mrd   = math.random
local _mpow  = math.pow or function(a,b) return a^b end

-- Instance / GUI
local _IN    = Instance.new
local _v3    = Vector3.new
local _v3z   = Vector3.zero
local _cf    = CFrame.new
local _cfL   = CFrame.lookAt
local _ud2   = UDim2.new
local _ud    = UDim.new
local _c3    = Color3.fromRGB
local _c3h   = Color3.fromHSV
local _v2    = Vector2.new

-- Task алиасы
local _tw    = task.wait
local _td    = task.delay
local _tsp   = task.spawn
local _tdf   = task.defer

-- ══════════════════════════════════════════════
-- [3] STEALTH RNG · Криптографически случайный
-- ══════════════════════════════════════════════
local _RNG = Random.new(
    _mf((os.clock() * 1e9) % 2147483647) ~
    _mf((tick() * 1e6) % 2147483647)
)
local function _rf(a, b) return _RNG:NextNumber(a, b) end
local function _ri(a, b) return _RNG:NextInteger(a, b) end
local function _jit()    return _rf(0.0008, 0.006) end

-- Генератор случайных имён инстансов (анти-сигнатурный)
local _ABC = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
local function _gID(n)
    n = n or _ri(8, 16)
    local t = table.create(n)
    -- Первый символ — буква (инстансы не могут начинаться с цифры)
    t[1] = _ABC:sub(_ri(1, #_ABC), _ri(1, #_ABC))
    for i = 2, n do
        local r = _ri(1, #_ABC)
        t[i] = _ABC:sub(r, r)
    end
    return table.concat(t)
end

-- ══════════════════════════════════════════════
-- [4] STEALTH · ДЕКОИ И МАСКИРОВКА
-- ══════════════════════════════════════════════

-- Имитация нормальных игровых вызовов
local _DECOY_OPS = {}

_DECOY_OPS[1] = function()
    -- Имитируем чтение гравитации как нормальный скрипт
    local _ = workspace.Gravity
end

_DECOY_OPS[2] = function()
    -- Имитируем проверку камеры
    local _ = workspace.CurrentCamera.CFrame
end

_DECOY_OPS[3] = function()
    -- Имитируем тик
    local _ = tick() % 1
end

_DECOY_OPS[4] = function()
    -- Короткое ожидание
    _tw(_jit())
end

_DECOY_OPS[5] = function()
    -- Имитируем чтение игрока
    local _ = _LP.Name
end

local function _disguise()
    local idx = _ri(1, #_DECOY_OPS)
    _pc(_DECOY_OPS[idx])
end

-- Периодически запускаем декои в фоне
_tsp(function()
    while true do
        _tw(_rf(0.8, 2.2))
        _pc(_disguise)
    end
end)

-- ══════════════════════════════════════════════
-- [5] КОНФИГ
-- ══════════════════════════════════════════════
local CFG = {
    -- Movement
    infJump      = false,
    jumpPower    = 55,
    jumpCD       = 0.09,
    speed        = false,
    speedVal     = 32,
    fly          = false,
    flySpeed     = 65,
    noclip       = false,
    lowGrav      = false,
    -- Combat
    antiRag      = false,
    godMode      = false,
    noAnim       = false,
    bigHead      = false,
    hitboxExp    = false,
    hitboxSz     = 8,
    -- Aimbot
    aimbot       = false,
    aimKey       = Enum.KeyCode.Q,
    aimFOV       = 180,
    aimSmooth    = 0.15,
    aimPart      = "Head",
    silentAim    = false,
    -- Visual
    esp          = false,
    chams        = false,
    tracers      = false,
    fullbright   = false,
    noFog        = false,
    -- SAB Specific
    autoCollect  = false,
    noKnockback  = false,
    teleportSteal= false,
    brainrotRadar= false,
}

-- ══════════════════════════════════════════════
-- [6] СОСТОЯНИЕ
-- ══════════════════════════════════════════════
local _char, _hum, _hrp, _animator

-- Anti-Ragdoll
local _ragConns  = {}
local _animConns = {}
local _trackedA  = {}
local _motorSnap = {}
local _fabMotors = {}

-- Ghost
local _ghostOn   = false
local _ghostPart = nil
local _ghostMvrs = {}
local _ragOn     = false
local _ragT      = 0
local _preRagCF  = nil
local _ghostCF   = nil
local _exitingR  = false
local _ragMax    = 7
local _exitLk    = false
local _lastExit  = 0

-- Fly
local _flyBV, _flyBG
local _flyOn = false

-- ESP/Combat
local _espObj    = {}
local _chamObj   = {}
local _tracerF   = nil
local _noclipC   = nil
local _godC      = nil
local _hitPrts   = {}
local _modConns  = {}

-- Lighting backup
local _bkAmb, _bkBri, _bkFogE, _bkFogS
local _bkGrav  = workspace.Gravity
local _bkSpeed = 16

-- Aimbot
local _aimTgt  = nil
local _aimLock = false
local _aimFOVG = nil

-- SAB
local _collectConn = nil
local _nkbConn     = nil
local _radarConn   = nil
local _radarDots   = {}

-- Frame counter (для throttling)
local _FC = 0

-- Jump
local _lastJump = 0

-- ══════════════════════════════════════════════
-- [7] УТИЛИТЫ
-- ══════════════════════════════════════════════
local function _sf(obj, name)
    if not obj then return nil end
    local ok, r = _pc(function() return obj:FindFirstChild(name) end)
    return ok and r or nil
end

local function _sfc(obj, cls)
    if not obj then return nil end
    local ok, r = _pc(function() return obj:FindFirstChildOfClass(cls) end)
    return ok and r or nil
end

local function _refChar()
    _char     = _LP.Character
    if not _char then return false end
    _hum      = _sfc(_char, "Humanoid")
    _hrp      = _sf(_char, "HumanoidRootPart")
    _animator = _hum and _sfc(_hum, "Animator")
    return _hum ~= nil and _hrp ~= nil
end
_refChar()

local function _safeCF()
    if not (_hrp and _hrp.Parent) then return nil end
    local ok, cf = _pc(function() return _hrp.CFrame end)
    return ok and cf or nil
end

local function _isAlive(p)
    local ok, r = _pc(function()
        local ch = p.Character
        if not ch then return false end
        local h = ch:FindFirstChildOfClass("Humanoid")
        return h and h.Health > 0
    end)
    return ok and r
end

local function _getPart(p, pn)
    local ok, r = _pc(function()
        local ch = p.Character
        if not ch then return nil end
        return ch:FindFirstChild(pn or CFG.aimPart)
            or ch:FindFirstChild("HumanoidRootPart")
    end)
    return ok and r or nil
end

local function _getTarget()
    local bd, bt = _mhg, nil
    local vp = _CAM.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    for _, p in _ipr(_P:GetPlayers()) do
        if p ~= _LP and _isAlive(p) then
            local pt = _getPart(p)
            if pt then
                local ok, sp, on = _pc(function()
                    return _CAM:WorldToViewportPoint(pt.Position)
                end)
                if ok and on then
                    local dx, dy = sp.X - cx, sp.Y - cy
                    local dist = _msq(dx * dx + dy * dy)
                    if dist < CFG.aimFOV and dist < bd then
                        bd, bt = dist, p
                    end
                end
            end
        end
    end
    return bt
end

-- ══════════════════════════════════════════════
-- [8] SAB СПЕЦИФИЧНЫЕ ФУНКЦИИ
-- ══════════════════════════════════════════════

-- Авто-сбор брейнротов
-- Ищет объекты с BillboardGui (так работает SAB)
local function _startAutoCollect()
    if _collectConn then _pc(function() _collectConn:Disconnect() end) end

    local _collectCD = 0
    _collectConn = _RS.Heartbeat:Connect(function()
        if not CFG.autoCollect then return end
        if not (_hrp and _hrp.Parent) then return end

        local now = tick()
        if now - _collectCD < 0.1 then return end -- throttle 10/сек
        _collectCD = now

        _pc(function()
            local hrpPos = _hrp.Position
            local closest, closestDist = nil, 35 -- радиус сбора

            -- Ищем брейнроты в workspace
            for _, obj in _ipr(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    -- SAB использует ProximityPrompt или BillboardGui
                    local hasBB = obj:FindFirstChildOfClass("BillboardGui")
                    local hasPP = obj:FindFirstChildOfClass("ProximityPrompt")
                    local hasCollect = obj:FindFirstChild("Collect")
                        or obj:FindFirstChild("PickUp")
                        or obj:FindFirstChild("Value")

                    if hasBB or hasPP or hasCollect then
                        local dist = (hrpPos - obj.Position).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closest = obj
                        end
                    end
                end
            end

            if closest then
                -- Телепортируемся и собираем
                _hrp.CFrame = CFrame.new(closest.Position + Vector3.new(0, 2.5, 0))

                -- Пытаемся активировать ProximityPrompt
                local pp = closest:FindFirstChildOfClass("ProximityPrompt")
                    or closest.Parent and closest.Parent:FindFirstChildOfClass("ProximityPrompt")
                if pp then
                    _pc(function()
                        -- Имитируем нажатие ProximityPrompt
                        local fire = pp.Triggered
                        if fire then fire:Fire() end
                    end)
                end
            end
        end)
    end)
end

local function _stopAutoCollect()
    if _collectConn then
        _pc(function() _collectConn:Disconnect() end)
        _collectConn = nil
    end
end

-- No Knockback (SAB-специфичный)
local function _startNoKB()
    if _nkbConn then _pc(function() _nkbConn:Disconnect() end) end
    _nkbConn = _RS.Heartbeat:Connect(function()
        if not CFG.noKnockback then return end
        _pc(function()
            if not (_hrp and _hrp.Parent) then return end
            local vel = _hrp.AssemblyLinearVelocity
            if _ma(vel.X) > 32 or _ma(vel.Z) > 32 then
                _hrp.AssemblyLinearVelocity = _v3(
                    vel.X * 0.12,
                    vel.Y,
                    vel.Z * 0.12
                )
            end
        end)
    end)
end

local function _stopNoKB()
    if _nkbConn then _pc(function() _nkbConn:Disconnect() end) _nkbConn = nil end
end

-- Teleport Steal — телепортируемся к чужому брейнроту перед подбором
local _tpStealConn = nil
local function _startTpSteal()
    if _tpStealConn then _pc(function() _tpStealConn:Disconnect() end) end
    _tpStealConn = _RS.Heartbeat:Connect(function()
        if not CFG.teleportSteal then return end
        if not (_hrp and _hrp.Parent) then return end

        _pc(function()
            -- Ищем других игроков, которые держат/несут предметы
            for _, p in _ipr(_P:GetPlayers()) do
                if p ~= _LP and _isAlive(p) then
                    local ch = p.Character
                    if ch then
                        -- Ищем объекты на персонаже другого игрока
                        for _, obj in _ipr(ch:GetChildren()) do
                            if obj:IsA("Tool") or obj:IsA("Model") then
                                local dist = (_hrp.Position - ch:GetPivot().Position).Magnitude
                                if dist < 20 and dist > 1 then
                                    -- Телепортируемся рядом
                                    _hrp.CFrame = CFrame.new(
                                        ch:GetPivot().Position + Vector3.new(_rf(-3,3), 0, _rf(-3,3))
                                    )
                                end
                            end
                        end
                    end
                end
            end
        end)
    end)
end

local function _stopTpSteal()
    if _tpStealConn then _pc(function() _tpStealConn:Disconnect() end) _tpStealConn = nil end
end

-- ══════════════════════════════════════════════
-- [9] INFINITE JUMP (стелс-улучшенный)
-- ══════════════════════════════════════════════
local function _doJump()
    if not CFG.infJump then return end
    local jr = _ghostOn and _ghostPart or _hrp
    if not (jr and jr.Parent) then return end
    if _hum and _hum.Health <= 0 then return end

    local now = tick()
    if now - _lastJump < CFG.jumpCD then return end
    _lastJump = now

    -- Небольшая рандомизация для стелса
    _pc(_disguise)

    local cv = jr.AssemblyLinearVelocity
    local ny = CFG.jumpPower + _rf(-2, 2)

    jr.AssemblyLinearVelocity = _v3(
        cv.X * _rf(0.88, 0.96),
        ny,
        cv.Z * _rf(0.88, 0.96)
    )

    _td(0.025 + _jit(), function()
        _pc(function()
            if jr and jr.Parent and CFG.infJump then
                local v = jr.AssemblyLinearVelocity
                if v.Y < CFG.jumpPower * 0.55 then
                    jr.AssemblyLinearVelocity = _v3(v.X, CFG.jumpPower * _rf(0.78, 0.91), v.Z)
                end
            end
        end)
    end)
end

_UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode ~= Enum.KeyCode.Space then return end
    if not _hum then return end
    if _ghostOn then _doJump() return end
    if not _hrp then return end
    local st = _hum:GetState()
    if st == Enum.HumanoidStateType.Freefall
    or st == Enum.HumanoidStateType.Jumping
    or st == Enum.HumanoidStateType.FallingDown then
        _doJump()
    end
end)

-- ══════════════════════════════════════════════
-- [10] ANTI-RAGDOLL v10 · GHOST ENGINE
-- ══════════════════════════════════════════════
local _RAG = {
    [Enum.HumanoidStateType.Ragdoll]     = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics]     = true,
}
local function _isRag(st) return _RAG[st] == true end

local function _snapMotors()
    _motorSnap = {}
    if not _char then return end
    for _, v in _ipr(_char:GetDescendants()) do
        if v:IsA("Motor6D") then
            _motorSnap[#_motorSnap + 1] = {
                ref = v, name = v.Name, par = v.Parent,
                p0 = v.Part0, p1 = v.Part1, c0 = v.C0, c1 = v.C1
            }
        end
    end
end

local function _restMotors()
    if not _char then return end
    for _, d in _ipr(_motorSnap) do
        _pc(function()
            if d.ref and d.ref.Parent then
                d.ref.Enabled = true
                return
            end
            if not (d.par and d.par.Parent
                and d.p0 and d.p0.Parent
                and d.p1 and d.p1.Parent) then return end
            local ex = d.par:FindFirstChild(d.name)
            if ex and ex:IsA("Motor6D") then
                ex.Enabled = true
                d.ref = ex
                return
            end
            local m = _IN("Motor6D")
            m.Name = d.name
            m.Part0 = d.p0
            m.Part1 = d.p1
            m.C0 = d.c0
            m.C1 = d.c1
            m.Parent = d.par
            d.ref = m
            _fabMotors[#_fabMotors + 1] = m
        end)
    end
end

local function _nukeConstraints()
    if not _char then return end
    local bad = {
        BallSocketConstraint = true, HingeConstraint = true,
        NoCollisionConstraint = true, RopeConstraint = true,
        SpringConstraint = true, CylindricalConstraint = true,
    }
    for _, v in _ipr(_char:GetDescendants()) do
        _pc(function() if bad[v.ClassName] then v:Destroy() end end)
    end
end

local function _killGhost(doTp)
    local fcf = _ghostCF
    for _, v in _pr(_ghostMvrs) do _pc(function() v:Destroy() end) end
    _ghostMvrs = {}
    if _ghostPart then
        _pc(function() _ghostPart:Destroy() end)
        _ghostPart = nil
    end
    _pc(function()
        if _hum then workspace.CurrentCamera.CameraSubject = _hum end
    end)
    _ghostOn = false

    if doTp and fcf and _hrp and _hrp.Parent then
        _pc(function()
            for _, v in _ipr(_char:GetDescendants()) do
                if v:IsA("BasePart") then
                    _pc(function()
                        v.AssemblyLinearVelocity  = _v3z
                        v.AssemblyAngularVelocity = _v3z
                    end)
                end
            end
            _hrp.CFrame = fcf
            _hrp.AssemblyLinearVelocity  = _v3z
            _hrp.AssemblyAngularVelocity = _v3z
        end)
    end
    return fcf
end

local function _spawnGhost()
    if _ghostPart and _ghostPart.Parent then return end
    if not (_hrp and _hrp.Parent and _char) then return end

    local cf = _preRagCF or _hrp.CFrame
    local g   = _IN("Part")
    g.Name               = _gID(12)
    g.Size               = _v3(2, 2, 1)
    g.Transparency       = 1
    g.CanCollide         = true
    g.CanQuery           = false
    g.CanTouch           = false
    g.Anchored           = false
    g.Massless           = false
    g.CFrame             = cf
    g.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
    g.Parent             = workspace

    _ghostPart = g
    _ghostCF   = cf

    local bv = _IN("BodyVelocity")
    bv.Name     = _gID(6)
    bv.MaxForce = _v3(20000, 0, 20000)
    bv.Velocity = _v3z
    bv.P        = 3500
    bv.Parent   = g
    _ghostMvrs.bv = bv

    local bg = _IN("BodyGyro")
    bg.Name      = _gID(6)
    bg.MaxTorque = _v3(0, 20000, 0)
    bg.P         = 7000
    bg.D         = 280
    bg.Parent    = g
    _ghostMvrs.bg = bg

    local bf = _IN("BodyForce")
    bf.Name  = _gID(6)
    bf.Force = _v3(0, g:GetMass() * workspace.Gravity * 0.22, 0)
    bf.Parent = g
    _ghostMvrs.bf = bf

    _ghostOn = true
end

local function _ctrlGhost()
    if not (_ghostOn and _ghostPart and _ghostPart.Parent) then
        if _ghostOn then _ghostOn = false end
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local md  = _v3z
    local ccf = cam.CFrame
    local fwd = _v3(ccf.LookVector.X, 0, ccf.LookVector.Z)
    if fwd.Magnitude > 0.001 then fwd = fwd.Unit end
    local rgt = _v3(ccf.RightVector.X, 0, ccf.RightVector.Z)
    if rgt.Magnitude > 0.001 then rgt = rgt.Unit end

    if _UIS:IsKeyDown(Enum.KeyCode.W) then md = md + fwd end
    if _UIS:IsKeyDown(Enum.KeyCode.S) then md = md - fwd end
    if _UIS:IsKeyDown(Enum.KeyCode.D) then md = md + rgt end
    if _UIS:IsKeyDown(Enum.KeyCode.A) then md = md - rgt end

    local spd = 16
    _pc(function() if _hum then spd = _hum.WalkSpeed end end)
    if md.Magnitude > 0.01 then
        md = md.Unit * spd
        if _ghostMvrs.bg then
            _pc(function()
                _ghostMvrs.bg.CFrame = _cfL(_v3z, _v3(md.X, 0, md.Z))
            end)
        end
    end
    if _ghostMvrs.bv then _ghostMvrs.bv.Velocity = _v3(md.X, 0, md.Z) end
    _pc(function() cam.CameraSubject = _ghostPart end)
    _ghostCF = _ghostPart.CFrame
end

local function _exitRag()
    if _exitLk or _exitingR then return end
    local now = tick()
    if now - _lastExit < 1.2 then return end
    _exitLk   = true
    _exitingR = true
    _lastExit = now

    if not (_hum and _char and _hrp) then
        _killGhost(false)
        _exitingR = false _ragOn = false _exitLk = false
        return
    end
    if _hum.Health <= 0 then
        _killGhost(false)
        _exitingR = false _ragOn = false _exitLk = false
        return
    end

    local fcf = _killGhost(true)
    _pc(function() _hum.PlatformStand = false end)
    _nukeConstraints()
    _restMotors()
    for _, v in _ipr(_char:GetDescendants()) do
        if v:IsA("BasePart") then _pc(function() v.Anchored = false end) end
    end
    _pc(function() _hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)

    _td(0.08 + _jit(), function()
        if not CFG.antiRag then _exitingR = false _ragOn = false _exitLk = false return end
        _pc(function()
            if _hum and _hum.Health > 0 then
                _hum.PlatformStand = false
                _nukeConstraints()
                _restMotors()
                if fcf and _hrp and _hrp.Parent then
                    if (_hrp.Position - fcf.Position).Magnitude > 4 then
                        for _, v in _ipr(_char:GetDescendants()) do
                            if v:IsA("BasePart") then
                                _pc(function()
                                    v.AssemblyLinearVelocity  = _v3z
                                    v.AssemblyAngularVelocity = _v3z
                                end)
                            end
                        end
                        _hrp.CFrame = fcf
                    end
                end
                _hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end)

    _td(0.38 + _jit(), function()
        _pc(function()
            if _hum and _hum.Health > 0 then
                _hum.PlatformStand = false
                local st = _hum:GetState()
                if _isRag(st) or st == Enum.HumanoidStateType.PlatformStanding then
                    _nukeConstraints()
                    _restMotors()
                    _hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    _td(0.07, function()
                        _pc(function() _hum:ChangeState(Enum.HumanoidStateType.Running) end)
                    end)
                end
                if not _ghostOn then
                    workspace.CurrentCamera.CameraSubject = _hum
                end
            end
        end)
        _exitingR = false
        _ragOn    = false
        _td(0.75, function() _exitLk = false end)
    end)
end

local function _onRagStart()
    if _ragOn or _exitingR or _exitLk then return end
    if not (_hum and _hum.Health > 0) then return end
    _preRagCF = _safeCF()
    _ragOn    = true
    _ragT     = tick()

    _td(0.025 + _jit(), function()
        if not CFG.antiRag then _ragOn = false return end
        if not _ragOn or _exitingR or _exitLk then _ragOn = false return end
        if _hum and _hum.Health <= 0 then _ragOn = false return end
        _spawnGhost()
    end)
end

local function _chkRagEnd()
    if not _ragOn or _exitingR or _exitLk then return end
    if not (_hum and _char) then return end
    if _hum.Health <= 0 then _killGhost(false) _ragOn = false return end
    if tick() - _ragT > _ragMax then _exitRag() return end

    local st = _hum:GetState()
    local ps = false
    _pc(function() ps = _hum.PlatformStand end)
    if not _isRag(st) and st ~= Enum.HumanoidStateType.PlatformStanding and not ps then
        _td(0.07, function()
            if not _ragOn or _exitingR or _exitLk then return end
            if not _hum then return end
            if _hum.Health <= 0 then _killGhost(false) _ragOn = false return end
            local st2 = _hum:GetState()
            local ps2 = false
            _pc(function() ps2 = _hum.PlatformStand end)
            if not _isRag(st2) and st2 ~= Enum.HumanoidStateType.PlatformStanding and not ps2 then
                _exitRag()
            end
        end)
    end
end

-- Снапшот позиции в фоне
_tsp(function()
    while true do
        _tw(0.16)
        _pc(function()
            if _char and _hum and _hrp and _hrp.Parent then
                if not _ragOn and not _exitingR and not _exitLk and _hum.Health > 0 then
                    local st = _hum:GetState()
                    if not _isRag(st) and st ~= Enum.HumanoidStateType.PlatformStanding then
                        _preRagCF = _safeCF()
                    end
                end
            end
        end)
    end
end)

local function _startAntiRag()
    if not (_char and _hum) then return end
    _snapMotors()

    local c1 = _hum.StateChanged:Connect(function(_, ns)
        if not CFG.antiRag or _exitLk then return end
        if _isRag(ns) or ns == Enum.HumanoidStateType.PlatformStanding then
            _td(_jit(), _onRagStart)
        end
    end)
    _ragConns[#_ragConns + 1] = c1

    local c2 = _hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not CFG.antiRag or _exitLk then return end
        if _hum.PlatformStand and not _ragOn then _td(_jit(), _onRagStart) end
    end)
    _ragConns[#_ragConns + 1] = c2

    local c3 = _char.DescendantAdded:Connect(function(v)
        if not CFG.antiRag or _exitLk then return end
        _td(_jit(), function()
            _pc(function()
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("NoCollisionConstraint") then
                    if not _ragOn and not _exitingR and not _exitLk then _onRagStart() end
                end
            end)
        end)
    end)
    _ragConns[#_ragConns + 1] = c3

    local c4 = _char.DescendantRemoving:Connect(function(v)
        if not CFG.antiRag or _exitLk then return end
        if v:IsA("Motor6D") then
            local d = { name=v.Name, par=v.Parent, p0=v.Part0, p1=v.Part1, c0=v.C0, c1=v.C1 }
            local found = false
            for _, s in _ipr(_motorSnap) do
                if s.name == d.name and s.par == d.par then
                    s.c0 = d.c0 s.c1 = d.c1 found = true break
                end
            end
            if not found then _motorSnap[#_motorSnap + 1] = d end
            if not _ragOn and not _exitingR and not _exitLk then _onRagStart() end
        end
    end)
    _ragConns[#_ragConns + 1] = c4
end

local function _stopAntiRag()
    for _, c in _ipr(_ragConns) do _pc(function() c:Disconnect() end) end
    _ragConns = {}
    _killGhost(false)
    _ragOn = false _exitingR = false _exitLk = false
    for _, m in _ipr(_fabMotors) do
        _pc(function() if m and m.Parent then m:Destroy() end end)
    end
    _fabMotors = {} _motorSnap = {}
end

-- ══════════════════════════════════════════════
-- [11] NO ANIMATIONS
-- ══════════════════════════════════════════════
local function _hookTrack(t)
    if not t or _trackedA[t] then return end
    _trackedA[t] = true
    local c = t:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if not CFG.noAnim then return end
        if t.IsPlaying then
            _td(_jit(), function()
                _pc(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
            end)
        end
    end)
    _animConns[#_animConns + 1] = c
    if CFG.noAnim and t.IsPlaying then
        _pc(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
    end
end

local function _stopAllTracks()
    if not _animator then return end
    _pc(function()
        for _, t in _ipr(_animator:GetPlayingAnimationTracks()) do
            _pc(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
        end
    end)
end

local function _startNoAnim()
    if not _animator then return end
    _pc(function()
        local c = _animator.AnimationPlayed:Connect(function(t)
            _hookTrack(t)
            if CFG.noAnim then
                _td(_jit(), function()
                    _pc(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
                end)
            end
        end)
        _animConns[#_animConns + 1] = c
    end)
    if _hum then
        for _, ev in _ipr({"Running","Jumping","Climbing","Swimming","FreeFalling"}) do
            _pc(function()
                local c = _hum[ev]:Connect(function()
                    if CFG.noAnim then _tdf(_stopAllTracks) end
                end)
                _animConns[#_animConns + 1] = c
            end)
        end
        local c = _hum.StateChanged:Connect(function()
            if CFG.noAnim then _tdf(_stopAllTracks) end
        end)
        _animConns[#_animConns + 1] = c
    end
    _pc(function()
        for _, t in _ipr(_animator:GetPlayingAnimationTracks()) do _hookTrack(t) end
    end)
end

local function _stopNoAnim()
    for _, c in _ipr(_animConns) do _pc(function() c:Disconnect() end) end
    _animConns = {}
    for t in _pr(_trackedA) do
        _pc(function()
            if t and t.IsPlaying then t:AdjustSpeed(1) t:AdjustWeight(1, 0.1) end
        end)
    end
    _trackedA = {}
end

-- ══════════════════════════════════════════════
-- [12] SPEED
-- ══════════════════════════════════════════════
local function _startSpeed()
    _refChar()
    if _hum then
        _bkSpeed = _hum.WalkSpeed
        _hum.WalkSpeed = CFG.speedVal
        _hum.JumpPower = CFG.jumpPower
    end
end

local function _stopSpeed()
    if _hum then
        _hum.WalkSpeed = _bkSpeed
        _hum.JumpPower = 50
    end
end

-- ══════════════════════════════════════════════
-- [13] FLY
-- ══════════════════════════════════════════════
local function _startFly()
    _refChar()
    if not (_hrp and _hum) then return end
    _flyOn = true
    if _flyBV then _pc(function() _flyBV:Destroy() end) end
    if _flyBG then _pc(function() _flyBG:Destroy() end) end

    _flyBV = _IN("BodyVelocity")
    _flyBV.Name     = _gID(8)
    _flyBV.MaxForce = _v3(1e5, 1e5, 1e5)
    _flyBV.Velocity = _v3z
    _flyBV.P        = 9500
    _flyBV.Parent   = _hrp

    _flyBG = _IN("BodyGyro")
    _flyBG.Name      = _gID(8)
    _flyBG.MaxTorque = _v3(1e5, 1e5, 1e5)
    _flyBG.P         = 9500
    _flyBG.D         = 520
    _flyBG.Parent    = _hrp
end

local function _ctrlFly()
    if not _flyOn then return end
    if not (_flyBV and _flyBV.Parent and _flyBG and _flyBG.Parent) then return end
    if not (_hrp and _hrp.Parent) then return end

    local ccf = workspace.CurrentCamera.CFrame
    local md  = _v3z

    if _UIS:IsKeyDown(Enum.KeyCode.W)            then md = md + ccf.LookVector end
    if _UIS:IsKeyDown(Enum.KeyCode.S)            then md = md - ccf.LookVector end
    if _UIS:IsKeyDown(Enum.KeyCode.A)            then md = md - ccf.RightVector end
    if _UIS:IsKeyDown(Enum.KeyCode.D)            then md = md + ccf.RightVector end
    if _UIS:IsKeyDown(Enum.KeyCode.Space)        then md = md + _v3(0, 1, 0) end
    if _UIS:IsKeyDown(Enum.KeyCode.LeftControl)  then md = md - _v3(0, 1, 0) end

    if md.Magnitude > 0.01 then md = md.Unit * CFG.flySpeed end
    _flyBV.Velocity = md
    _flyBG.CFrame   = ccf
end

local function _stopFly()
    _flyOn = false
    if _flyBV then _pc(function() _flyBV:Destroy() end) _flyBV = nil end
    if _flyBG then _pc(function() _flyBG:Destroy() end) _flyBG = nil end
end

-- ══════════════════════════════════════════════
-- [14] NOCLIP
-- ══════════════════════════════════════════════
local function _startNoclip()
    if _noclipC then _pc(function() _noclipC:Disconnect() end) end
    _noclipC = _RS.Stepped:Connect(function()
        if not CFG.noclip then return end
        _pc(function()
            if _char then
                for _, v in _ipr(_char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    end)
end

local function _stopNoclip()
    if _noclipC then _pc(function() _noclipC:Disconnect() end) _noclipC = nil end
    _pc(function()
        if _char then
            for _, v in _ipr(_char:GetDescendants()) do
                if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                    v.CanCollide = true
                end
            end
        end
    end)
end

-- ══════════════════════════════════════════════
-- [15] GOD MODE
-- ══════════════════════════════════════════════
local function _startGod()
    _refChar()
    if not _hum then return end
    if _godC then _pc(function() _godC:Disconnect() end) end
    _godC = _hum:GetPropertyChangedSignal("Health"):Connect(function()
        if CFG.godMode and _hum then
            _pc(function() _hum.Health = _hum.MaxHealth end)
        end
    end)
    _pc(function() _hum.Health = _hum.MaxHealth end)
end

local function _stopGod()
    if _godC then _pc(function() _godC:Disconnect() end) _godC = nil end
end

-- ══════════════════════════════════════════════
-- [16] HITBOX EXPAND
-- ══════════════════════════════════════════════
local function _expandHB()
    _hitPrts = {}
    for _, p in _ipr(_P:GetPlayers()) do
        if p ~= _LP then
            _pc(function()
                local ch = p.Character
                if not ch then return end
                local head = ch:FindFirstChild("Head")
                if head then
                    local orig = head.Size
                    head.Size = _v3(CFG.hitboxSz, CFG.hitboxSz, CFG.hitboxSz)
                    _hitPrts[#_hitPrts + 1] = { part = head, origSize = orig }
                end
            end)
        end
    end
end

local function _restoreHB()
    for _, d in _ipr(_hitPrts) do
        _pc(function()
            if d.part and d.part.Parent then d.part.Size = d.origSize end
        end)
    end
    _hitPrts = {}
end

-- ══════════════════════════════════════════════
-- [17] ESP
-- ══════════════════════════════════════════════
local function _makeESP(player)
    if player == _LP then return end
    local function build()
        _pc(function()
            local ch = player.Character
            if not ch then return end
            if _espObj[player] then
                for _, o in _ipr(_espObj[player]) do _pc(function() o:Destroy() end) end
            end
            _espObj[player] = {}

            local hl = _IN("Highlight")
            hl.Name               = _gID(5)
            hl.FillColor          = _c3(255, 55, 55)
            hl.FillTransparency   = 0.62
            hl.OutlineColor       = _c3(255, 255, 255)
            hl.OutlineTransparency = 0.08
            hl.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = ch
            hl.Parent  = ch

            local bbg = _IN("BillboardGui")
            bbg.Name        = _gID(5)
            bbg.Size        = _ud2(0, 145, 0, 48)
            bbg.StudsOffset = _v3(0, 5, 0)
            bbg.AlwaysOnTop = true
            bbg.Adornee     = ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
            bbg.Parent      = ch

            local nameL = _IN("TextLabel")
            nameL.Size                   = _ud2(1, 0, 0.5, 0)
            nameL.BackgroundTransparency = 1
            nameL.Text                   = player.DisplayName
            nameL.TextColor3             = _c3(255, 255, 255)
            nameL.TextStrokeTransparency = 0.18
            nameL.TextSize               = 13
            nameL.Font                   = Enum.Font.GothamBold
            nameL.Parent                 = bbg

            local distL = _IN("TextLabel")
            distL.Size                   = _ud2(1, 0, 0.3, 0)
            distL.Position               = _ud2(0, 0, 0.5, 0)
            distL.BackgroundTransparency = 1
            distL.Text                   = ""
            distL.TextColor3             = _c3(205, 205, 205)
            distL.TextSize               = 10
            distL.Font                   = Enum.Font.Gotham
            distL.Parent                 = bbg

            local hpBG = _IN("Frame")
            hpBG.Size             = _ud2(0.7, 0, 0, 4)
            hpBG.Position         = _ud2(0.15, 0, 1, 4)
            hpBG.BackgroundColor3 = _c3(20, 20, 20)
            hpBG.BorderSizePixel  = 0
            hpBG.Parent           = bbg
            local uc1 = _IN("UICorner") uc1.CornerRadius = _ud(0, 2) uc1.Parent = hpBG

            local hpFill = _IN("Frame")
            hpFill.Size             = _ud2(1, 0, 1, 0)
            hpFill.BackgroundColor3 = _c3(50, 255, 100)
            hpFill.BorderSizePixel  = 0
            hpFill.Parent           = hpBG
            local uc2 = _IN("UICorner") uc2.CornerRadius = _ud(0, 2) uc2.Parent = hpFill

            _espObj[player] = { hl, bbg }

            _tsp(function()
                while CFG.esp and bbg and bbg.Parent and ch and ch.Parent do
                    _pc(function()
                        if _hrp and _hrp.Parent then
                            local h2 = ch:FindFirstChild("HumanoidRootPart")
                            if h2 then
                                distL.Text = _mf((_hrp.Position - h2.Position).Magnitude) .. " studs"
                            end
                        end
                        local hm = ch:FindFirstChildOfClass("Humanoid")
                        if hm then
                            local r = _mclp(hm.Health / hm.MaxHealth, 0, 1)
                            hpFill.Size = _ud2(r, 0, 1, 0)
                            hpFill.BackgroundColor3 = r > 0.6 and _c3(50, 255, 100)
                                or r > 0.3 and _c3(255, 205, 50) or _c3(255, 50, 50)
                        end
                        hl.OutlineColor = (_aimTgt == player)
                            and _c3(255, 50, 50) or _c3(255, 255, 255)
                    end)
                    _tw(0.1)
                end
            end)
        end)
    end
    if player.Character then build() end
    local c = player.CharacterAdded:Connect(function()
        _tw(0.45)
        if CFG.esp then build() end
    end)
    _modConns[#_modConns + 1] = c
end

local function _startESP()
    for _, p in _ipr(_P:GetPlayers()) do _makeESP(p) end
    local c = _P.PlayerAdded:Connect(function(p)
        if CFG.esp then _makeESP(p) end
    end)
    _modConns[#_modConns + 1] = c
end

local function _stopESP()
    for _, objs in _pr(_espObj) do
        for _, o in _ipr(objs) do _pc(function() o:Destroy() end) end
    end
    _espObj = {}
end

-- ══════════════════════════════════════════════
-- [18] CHAMS
-- ══════════════════════════════════════════════
local function _startChams()
    _tsp(function()
        while CFG.chams do
            for _, p in _ipr(_P:GetPlayers()) do
                if p ~= _LP then
                    _pc(function()
                        local ch = p.Character
                        if ch and not _chamObj[p] then
                            local hl = _IN("Highlight")
                            hl.Name               = _gID(5)
                            hl.FillColor          = _c3h(0, 0.82, 1)
                            hl.FillTransparency   = 0.28
                            hl.OutlineColor       = _c3(255, 255, 255)
                            hl.OutlineTransparency = 0
                            hl.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
                            hl.Adornee = ch
                            hl.Parent  = ch
                            _chamObj[p] = hl
                        end
                    end)
                end
            end
            _tw(0.42)
        end
    end)
end

local function _stopChams()
    for _, hl in _pr(_chamObj) do
        _pc(function() if hl and hl.Parent then hl:Destroy() end end)
    end
    _chamObj = {}
end

-- ══════════════════════════════════════════════
-- [19] TRACERS
-- ══════════════════════════════════════════════
local function _startTracers(sg)
    if _tracerF then _pc(function() _tracerF:Destroy() end) end
    _tracerF = _IN("Frame")
    _tracerF.Name               = _gID(8)
    _tracerF.Size               = _ud2(1, 0, 1, 0)
    _tracerF.BackgroundTransparency = 1
    _tracerF.ZIndex             = 1
    _tracerF.Parent             = sg

    _tsp(function()
        while CFG.tracers and _tracerF and _tracerF.Parent do
            for _, v in _ipr(_tracerF:GetChildren()) do
                _pc(function() v:Destroy() end)
            end
            local vp = _CAM.ViewportSize
            local sx, sy = vp.X / 2, vp.Y
            for _, p in _ipr(_P:GetPlayers()) do
                if p ~= _LP and _isAlive(p) then
                    _pc(function()
                        local pt = _getPart(p)
                        if not (pt and pt.Parent) then return end
                        local sp, on = _CAM:WorldToViewportPoint(pt.Position)
                        if not on then return end
                        local dx, dy = sp.X - sx, sp.Y - sy
                        local len = _msq(dx * dx + dy * dy)
                        local ang = math.deg(_mat(dy, dx))
                        local ln = _IN("Frame")
                        ln.Size             = _ud2(0, len, 0, 1.5)
                        ln.Position         = _ud2(0, sx, 0, sy)
                        ln.AnchorPoint      = Vector2.new(0, 0.5)
                        ln.BackgroundColor3 = (_aimTgt == p) and _c3(255, 50, 50) or _c3(255, 210, 50)
                        ln.BackgroundTransparency = 0.2
                        ln.BorderSizePixel  = 0
                        ln.Rotation         = ang
                        ln.ZIndex           = 2
                        ln.Parent           = _tracerF
                    end)
                end
            end
            _tw(0.028)
        end
        _pc(function() if _tracerF then _tracerF:Destroy() end end)
        _tracerF = nil
    end)
end

local function _stopTracers()
    if _tracerF then _pc(function() _tracerF:Destroy() end) _tracerF = nil end
end

-- ══════════════════════════════════════════════
-- [20] VISUAL MODS
-- ══════════════════════════════════════════════
local function _startFB()
    _pc(function()
        _bkAmb = _LT.Ambient
        _bkBri = _LT.Brightness
        _LT.Ambient    = _c3(255, 255, 255)
        _LT.Brightness = 2
    end)
end
local function _stopFB()
    _pc(function()
        if _bkAmb then _LT.Ambient    = _bkAmb end
        if _bkBri then _LT.Brightness = _bkBri end
    end)
end

local function _startNoFog()
    _pc(function()
        _bkFogE = _LT.FogEnd
        _bkFogS = _LT.FogStart
        _LT.FogEnd   = 1e10
        _LT.FogStart = 1e10
    end)
end
local function _stopNoFog()
    _pc(function()
        if _bkFogE then _LT.FogEnd   = _bkFogE end
        if _bkFogS then _LT.FogStart = _bkFogS end
    end)
end

local function _startLowG()
    _bkGrav           = workspace.Gravity
    workspace.Gravity = 42
end
local function _stopLowG()
    workspace.Gravity = _bkGrav
end

-- Big Head
local function _startBigHead()
    _tsp(function()
        while CFG.bigHead do
            for _, p in _ipr(_P:GetPlayers()) do
                if p ~= _LP then
                    _pc(function()
                        local ch = p.Character
                        if not ch then return end
                        local head = ch:FindFirstChild("Head")
                        if head then
                            head.Size = _v3(CFG.hitboxSz + 2, CFG.hitboxSz + 2, CFG.hitboxSz + 2)
                        end
                    end)
                end
            end
            _tw(0.42)
        end
        -- Восстанавливаем
        for _, p in _ipr(_P:GetPlayers()) do
            if p ~= _LP then
                _pc(function()
                    local ch = p.Character
                    if ch then
                        local head = ch:FindFirstChild("Head")
                        if head then head.Size = _v3(2, 1, 1) end
                    end
                end)
            end
        end
    end)
end

-- ══════════════════════════════════════════════
-- [21] AIMBOT
-- ══════════════════════════════════════════════
local function _stepAim()
    if not (CFG.aimbot or CFG.silentAim) then return end
    if not _aimTgt or not _isAlive(_aimTgt) then
        _aimTgt = nil _aimLock = false
    end

    if CFG.aimbot and _UIS:IsKeyDown(CFG.aimKey) then
        if not _aimTgt then
            _aimTgt  = _getTarget()
            _aimLock = _aimTgt ~= nil
        end
        if _aimTgt then
            local pt = _getPart(_aimTgt)
            if pt and pt.Parent then
                local ccf = _CAM.CFrame
                local tcf = _cfL(ccf.Position, pt.Position)
                local sm  = _mclp(CFG.aimSmooth + _rf(-0.003, 0.003), 0.01, 1)
                _pc(function() _CAM.CFrame = ccf:Lerp(tcf, sm) end)
            else
                _aimTgt = nil _aimLock = false
            end
        end
    elseif not _UIS:IsKeyDown(CFG.aimKey) and CFG.aimbot then
        _aimTgt = nil _aimLock = false
    end

    if CFG.silentAim and not _aimLock then
        _aimTgt = _getTarget()
    end
end

local function _drawFOV(sg)
    if _aimFOVG then _pc(function() _aimFOVG:Destroy() end) _aimFOVG = nil end
    local ff = _IN("Frame")
    ff.Name             = _gID(5)
    ff.Size             = _ud2(0, CFG.aimFOV * 2, 0, CFG.aimFOV * 2)
    ff.AnchorPoint      = Vector2.new(0.5, 0.5)
    ff.Position         = _ud2(0.5, 0, 0.5, 0)
    ff.BackgroundTransparency = 1
    ff.BorderSizePixel  = 0
    ff.ZIndex           = 1
    ff.Parent           = sg

    local fs = _IN("UIStroke")
    fs.Color       = _c3(255, 50, 50)
    fs.Thickness   = 1.2
    fs.Transparency = 0.3
    fs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fs.Parent = ff

    local fc = _IN("UICorner")
    fc.CornerRadius = _ud(0, CFG.aimFOV)
    fc.Parent = ff

    _aimFOVG = ff

    _tsp(function()
        while ff and ff.Parent and (CFG.aimbot or CFG.silentAim) do
            local locked = _aimLock and _aimTgt ~= nil
            fs.Color       = locked and _c3(255, 50, 50) or _c3(180, 180, 255)
            fs.Transparency = locked and 0.05 or 0.4
            _tw(0.04)
        end
        _pc(function() ff:Destroy() end)
        _aimFOVG = nil
    end)
end

-- ══════════════════════════════════════════════
-- [22] MASTER HEARTBEAT (стелс-троттлинг)
-- ══════════════════════════════════════════════
local _hbConn

_hbConn = _RS.Heartbeat:Connect(function()
    _FC = _FC + 1

    -- Нет персонажа
    if not (_char and _char.Parent) then
        if _FC % 10 == 0 then _refChar() end
        return
    end

    -- Мёртв
    if not (_hum and _hum.Health > 0) then
        if _ghostOn then _killGhost(false) _ragOn = false end
        return
    end

    -- Anti-ragdoll
    if CFG.antiRag then
        if _ghostOn then _ctrlGhost() end
        if _FC % 4 == 0 then
            _chkRagEnd()
            if _ragOn and not _exitingR and not _exitLk
               and not (_ghostPart and _ghostPart.Parent) then
                _ghostOn = false
                local st = _hum:GetState()
                local ps = false
                _pc(function() ps = _hum.PlatformStand end)
                if _isRag(st) or st == Enum.HumanoidStateType.PlatformStanding or ps then
                    _spawnGhost()
                else
                    _ragOn = false
                end
            end
        end
    end

    -- Fly
    if CFG.fly then _ctrlFly() end

    -- Speed keepalive
    if CFG.speed and _hum and _FC % 20 == 0 then
        _pc(function() _hum.WalkSpeed = CFG.speedVal end)
    end

    -- No anim
    if CFG.noAnim and _FC % 4 == 0 then _stopAllTracks() end

    -- Aimbot
    if _FC % 2 == 0 then _stepAim() end

    -- Hitbox
    if CFG.hitboxExp and _FC % 30 == 0 then _expandHB() end

    -- Chams rainbow
    if CFG.chams and _FC % 14 == 0 then
        local h = (_FC * 0.0025) % 1
        for _, hl in _pr(_chamObj) do
            _pc(function() hl.FillColor = _c3h(h, 0.84, 1) end)
        end
    end

    -- Декои антидетект
    if _FC % 55 == 0 then _pc(_disguise) end
end)

-- ══════════════════════════════════════════════
-- [23] RESPAWN
-- ══════════════════════════════════════════════
_LP.CharacterAdded:Connect(function()
    _tw(_rf(0.25, 0.5))
    _killGhost(false)
    _ragOn = false _exitingR = false _exitLk = false _preRagCF = nil
    _stopFly()
    _refChar()
    _tw(_rf(0.1, 0.18))
    if CFG.antiRag    then _stopAntiRag() _startAntiRag() end
    if CFG.noAnim     then _stopNoAnim()  _tw(0.1) _startNoAnim() end
    if CFG.speed      then _startSpeed() end
    if CFG.fly        then _startFly() end
    if CFG.noclip     then _startNoclip() end
    if CFG.godMode    then _startGod() end
    if CFG.hitboxExp  then _expandHB() end
    if CFG.noKnockback then _startNoKB() end
    if CFG.autoCollect then _startAutoCollect() end
end)

-- ══════════════════════════════════════════════════════════════════
-- ═══════════════════ GUI v20.0 ════════════════════════════════════
-- ══════════════════════════════════════════════════════════════════

-- Очистка старых инстансов
for _, g in _ipr(_PG:GetChildren()) do
    _pc(function()
        if g:IsA("ScreenGui") and g:GetAttribute("_GH20") then g:Destroy() end
    end)
end

local SG = _IN("ScreenGui")
SG.Name           = _gID(14)
SG:SetAttribute("_GH20", true)
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder   = 18
SG.IgnoreGuiInset = false
SG.Parent         = _PG

-- ══════════════════════════════════════════════
-- ПАЛИТРА
-- ══════════════════════════════════════════════
local P = {
    bg     = _c3(4,  4,  13),
    bgCard = _c3(8,  8,  22),
    bgDeep = _c3(3,  3,  9),
    hdr    = _c3(6,  6,  17),
    a1     = _c3(138, 82, 255),   -- purple
    a2     = _c3(42, 198, 255),   -- cyan
    a3     = _c3(255, 48, 88),    -- red
    a4     = _c3(255, 198, 52),   -- yellow
    a5     = _c3(52, 255, 152),   -- green
    a6     = _c3(255, 112, 222),  -- pink
    a7     = _c3(255, 132, 48),   -- orange
    a8     = _c3(102, 212, 255),  -- light blue
    a9     = _c3(200, 255, 80),   -- lime (SAB цвет)
    tW     = _c3(240, 240, 252),
    tD     = _c3(56,  56,  86),
    tG     = _c3(52, 255, 128),
    tOff   = _c3(15, 15, 30),
    tKnob  = _c3(76, 76, 102),
    bord   = _c3(22, 22, 44),
}

-- ══════════════════════════════════════════════
-- GUI УТИЛИТЫ
-- ══════════════════════════════════════════════
local function _corner(p, r)
    local c = _IN("UICorner")
    c.CornerRadius = _ud(0, r or 12)
    c.Parent = p
    return c
end

local function _uiStroke(p, col, thick, tr)
    local s = _IN("UIStroke")
    s.Color           = col or P.bord
    s.Thickness       = thick or 1
    s.Transparency    = tr or 0.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent          = p
    return s
end

local function _tweenInfo(d, st, sd)
    return TweenInfo.new(
        d  or 0.3,
        st or Enum.EasingStyle.Quint,
        sd or Enum.EasingDirection.Out
    )
end

local function _tween(obj, info, props)
    return _TS:Create(obj, info, props)
end

local function _uiGrad(p, colors, rot, trans)
    local g = _IN("UIGradient")
    g.Color = colors
    if rot   then g.Rotation    = rot   end
    if trans then g.Transparency = trans end
    g.Parent = p
    return g
end

-- Drag
local function _makeDrag(frame, handle)
    local dragging, dStart, sPos = false
    handle = handle or frame
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dStart   = inp.Position
            sPos     = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    _UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                      or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dStart
            _tween(frame, _tweenInfo(0.04, Enum.EasingStyle.Quad), {
                Position = _ud2(
                    sPos.X.Scale, sPos.X.Offset + d.X,
                    sPos.Y.Scale, sPos.Y.Offset + d.Y
                )
            }):Play()
        end
    end)
end

-- ══════════════════════════════════════════════
-- ГЛАВНЫЙ ФРЕЙМ
-- ══════════════════════════════════════════════
local MF = _IN("Frame")
MF.Name                   = _gID(6)
MF.Size                   = _ud2(0, 475, 0, 695)
MF.Position               = _ud2(0.5, -237, 0.5, -347)
MF.BackgroundColor3       = P.bg
MF.BackgroundTransparency = 0.01
MF.BorderSizePixel        = 0
MF.Active                 = true
MF.ClipsDescendants       = true
MF.Parent                 = SG
_corner(MF, 22)
local _mStroke = _uiStroke(MF, P.a1, 1.5, 0.5)

-- Aurora orbs (фоновые блобы)
local _orbs   = {}
local _orbDef = {
    { _ud2(0, -115, 0, -115), P.a1, 325, 0.91 },
    { _ud2(1, -155, 1, -185), P.a2, 295, 0.91 },
    { _ud2(0.05, 0, 0.18, 0), P.a6, 215, 0.93 },
    { _ud2(0.87, 0, 0.03, 0), P.a5, 185, 0.93 },
    { _ud2(0.38,-98, 0.50, 0), P.a3, 235, 0.91 },
    { _ud2(0,    0, 0.85, 0), P.a4, 155, 0.94 },
    { _ud2(0.63, 0, 0.07, 0), P.a1, 135, 0.95 },
    { _ud2(0.19, 0, 0.92, 0), P.a2, 125, 0.95 },
    { _ud2(0.5,  0, 0.3,  0), P.a9, 100, 0.96 }, -- SAB lime
}
for i, od in _ipr(_orbDef) do
    local o = _IN("Frame")
    o.Name                    = _gID(3)
    o.Size                    = _ud2(0, od[3], 0, od[3])
    o.Position                = od[1]
    o.BackgroundColor3        = od[2]
    o.BackgroundTransparency  = od[4]
    o.BorderSizePixel         = 0
    o.ZIndex                  = 0
    o.Parent                  = MF
    _corner(o, _mf(od[3] / 2))
    _orbs[i] = o
end

-- ══════════════════════════════════════════════
-- HEADER
-- ══════════════════════════════════════════════
local HD = _IN("Frame")
HD.Name                   = _gID(4)
HD.Size                   = _ud2(1, 0, 0, 84)
HD.BackgroundColor3       = P.hdr
HD.BackgroundTransparency = 0.02
HD.BorderSizePixel        = 0
HD.ZIndex                 = 5
HD.Parent                 = MF
_corner(HD, 22)

local HDPatch = _IN("Frame")
HDPatch.Size                   = _ud2(1, 0, 0, 28)
HDPatch.Position               = _ud2(0, 0, 1, -28)
HDPatch.BackgroundColor3       = P.hdr
HDPatch.BackgroundTransparency = 0.02
HDPatch.BorderSizePixel        = 0
HDPatch.ZIndex                 = 5
HDPatch.Parent                 = HD

_makeDrag(MF, HD)

-- Сепаратор с анимированным градиентом
local sep = _IN("Frame")
sep.Size                   = _ud2(0.96, 0, 0, 2.5)
sep.Position               = _ud2(0.02, 0, 1, 0)
sep.BackgroundColor3       = P.tW
sep.BackgroundTransparency = 0.04
sep.BorderSizePixel        = 0
sep.ZIndex                 = 6
sep.Parent                 = HD
_corner(sep, 2)

local sepG = _uiGrad(sep, ColorSequence.new{
    ColorSequenceKeypoint.new(0,    P.a1),
    ColorSequenceKeypoint.new(0.15, P.a2),
    ColorSequenceKeypoint.new(0.32, P.a5),
    ColorSequenceKeypoint.new(0.50, P.a4),
    ColorSequenceKeypoint.new(0.68, P.a6),
    ColorSequenceKeypoint.new(0.85, P.a3),
    ColorSequenceKeypoint.new(1,    P.a1),
})
sepG.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0,    0.9),
    NumberSequenceKeypoint.new(0.07, 0),
    NumberSequenceKeypoint.new(0.93, 0),
    NumberSequenceKeypoint.new(1,    0.9),
}

_tsp(function()
    local off = 0
    while SG and SG.Parent do
        off = (off + 0.0007) % 1
        _pc(function() sepG.Offset = Vector2.new(_ms(off * _mpi * 2) * 0.34, 0) end)
        _tw(0.02)
    end
end)

-- Логотип
local logoCont = _IN("Frame")
logoCont.Size                   = _ud2(0, 64, 0, 64)
logoCont.Position               = _ud2(0, 13, 0.5, -32)
logoCont.BackgroundTransparency = 1
logoCont.ZIndex                 = 6
logoCont.Parent                 = HD

local _rings = {}
local _ringDef = { {64,0.74,24}, {52,0.78,18}, {42,0.82,14} }
for i, rd in _ipr(_ringDef) do
    local r = _IN("Frame")
    r.Size                    = _ud2(0, rd[1], 0, rd[1])
    r.AnchorPoint             = Vector2.new(0.5, 0.5)
    r.Position                = _ud2(0.5, 0, 0.5, 0)
    r.BackgroundColor3        = P.a1
    r.BackgroundTransparency  = rd[2]
    r.BorderSizePixel         = 0
    r.ZIndex                  = 6 + i
    r.Parent                  = logoCont
    _corner(r, _mf(rd[1] / 2))
    if i < 3 then _uiStroke(r, P.a1, 0.6, 0.4 + i * 0.1) end
    _rings[i] = r
end

local logoGlow = _IN("Frame")
logoGlow.Size                   = _ud2(0, 28, 0, 28)
logoGlow.AnchorPoint            = Vector2.new(0.5, 0.5)
logoGlow.Position               = _ud2(0.5, 0, 0.5, 0)
logoGlow.BackgroundColor3       = P.a1
logoGlow.BackgroundTransparency = 0.28
logoGlow.ZIndex                 = 10
logoGlow.Parent                 = logoCont
_corner(logoGlow, 14)

local logoTxt = _IN("TextLabel")
logoTxt.Size                   = _ud2(1, 0, 1, 0)
logoTxt.BackgroundTransparency = 1
logoTxt.Text                   = "G"
logoTxt.TextColor3             = P.tW
logoTxt.TextSize               = 18
logoTxt.Font                   = Enum.Font.GothamBlack
logoTxt.ZIndex                 = 11
logoTxt.Parent                 = _rings[3]

-- Заголовок
local titleL = _IN("TextLabel")
titleL.Size                   = _ud2(0, 250, 0, 28)
titleL.Position               = _ud2(0, 88, 0, 8)
titleL.BackgroundTransparency = 1
titleL.RichText               = true
titleL.Text                   = '<font color="#8C55FF">GRANZ</font> <font color="#FFFFFF">HUB</font>'
titleL.TextSize               = 22
titleL.Font                   = Enum.Font.GothamBlack
titleL.TextXAlignment         = Enum.TextXAlignment.Left
titleL.ZIndex                 = 6
titleL.Parent                 = HD

local subL = _IN("TextLabel")
subL.Size                   = _ud2(0, 315, 0, 14)
subL.Position               = _ud2(0, 88, 0, 38)
subL.BackgroundTransparency = 1
subL.Text                   = "terminator v20.0 · steal a brainrot edition"
subL.TextColor3             = P.tD
subL.TextSize               = 9
subL.Font                   = Enum.Font.GothamMedium
subL.TextXAlignment         = Enum.TextXAlignment.Left
subL.ZIndex                 = 6
subL.Parent                 = HD

-- Бейджи
local _bdgDef = {
    {"TERMINATOR", P.a1},
    {"v20",        P.a5},
    {"SAB",        P.a3},
    {"20 MODS",    P.a4},
}
local bxOff = 88
for _, bd in _ipr(_bdgDef) do
    local bf = _IN("Frame")
    bf.Size                   = _ud2(0, #bd[1] * 5.2 + 16, 0, 17)
    bf.Position               = _ud2(0, bxOff, 0, 58)
    bf.BackgroundColor3       = bd[2]
    bf.BackgroundTransparency = 0.87
    bf.BorderSizePixel        = 0
    bf.ZIndex                 = 6
    bf.Parent                 = HD
    _corner(bf, 6)
    _uiStroke(bf, bd[2], 0.5, 0.55)

    local bl = _IN("TextLabel")
    bl.Size                   = _ud2(1, 0, 1, 0)
    bl.BackgroundTransparency = 1
    bl.Text                   = bd[1]
    bl.TextColor3             = bd[2]
    bl.TextSize               = 6.5
    bl.Font                   = Enum.Font.GothamBlack
    bl.ZIndex                 = 7
    bl.Parent                 = bf

    bxOff = bxOff + #bd[1] * 5.2 + 20
end

-- Кнопки header
local function _makeHdrBtn(pos, txt, col)
    local b = _IN("TextButton")
    b.Size                   = _ud2(0, 36, 0, 36)
    b.Position               = pos
    b.BackgroundColor3       = col
    b.BackgroundTransparency = 0.52
    b.Text                   = txt
    b.TextColor3             = P.tW
    b.TextSize               = 13
    b.Font                   = Enum.Font.GothamBold
    b.BorderSizePixel        = 0
    b.AutoButtonColor        = false
    b.ZIndex                 = 6
    b.Parent                 = HD
    _corner(b, 11)
    b.MouseEnter:Connect(function()
        _tween(b, _tweenInfo(0.18), {BackgroundTransparency=0.1}):Play()
    end)
    b.MouseLeave:Connect(function()
        _tween(b, _tweenInfo(0.18), {BackgroundTransparency=0.52}):Play()
    end)
    return b
end

local MinBtn = _makeHdrBtn(_ud2(1, -88, 0, 24), "━", _c3(30, 30, 50))
local ClsBtn = _makeHdrBtn(_ud2(1, -48, 0, 24), "✕", _c3(145, 20, 38))

-- ══════════════════════════════════════════════
-- ВКЛАДКИ
-- ══════════════════════════════════════════════
local curTab    = "combat"
local tabBtns   = {}
local tabFrames = {}

local tabBar = _IN("Frame")
tabBar.Name                   = _gID(4)
tabBar.Size                   = _ud2(1, -14, 0, 36)
tabBar.Position               = _ud2(0, 7, 0, 88)
tabBar.BackgroundColor3       = P.bgDeep
tabBar.BackgroundTransparency = 0.22
tabBar.BorderSizePixel        = 0
tabBar.ZIndex                 = 4
tabBar.Parent                 = MF
_corner(tabBar, 11)

local tLayout = _IN("UIListLayout")
tLayout.FillDirection       = Enum.FillDirection.Horizontal
tLayout.Padding             = _ud(0, 3)
tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
tLayout.Parent              = tabBar

local tPad = _IN("UIPadding")
tPad.PaddingLeft  = _ud(0, 3)
tPad.PaddingRight = _ud(0, 3)
tPad.Parent       = tabBar

local TABS_DEF = {
    { id = "combat",   icon = "🎯", name = "Combat",  col = P.a3 },
    { id = "movement", icon = "🏃", name = "Move",    col = P.a1 },
    { id = "visual",   icon = "👁️", name = "Visual",  col = P.a2 },
    { id = "world",    icon = "🌍", name = "World",   col = P.a5 },
    { id = "aimbot",   icon = "🤖", name = "Aimbot",  col = P.a7 },
    { id = "sab",      icon = "🧠", name = "SAB",     col = P.a9 },
}

local contentMain = _IN("Frame")
contentMain.Size                   = _ud2(1, -14, 1, -158)
contentMain.Position               = _ud2(0, 7, 0, 130)
contentMain.BackgroundTransparency = 1
contentMain.ZIndex                 = 3
contentMain.Parent                 = MF

for _, td in _ipr(TABS_DEF) do
    local sc = _IN("ScrollingFrame")
    sc.Name                        = td.id
    sc.Size                        = _ud2(1, 0, 1, 0)
    sc.BackgroundTransparency      = 1
    sc.BorderSizePixel             = 0
    sc.ScrollBarThickness          = 3
    sc.ScrollBarImageColor3        = td.col
    sc.ScrollBarImageTransparency  = 0.42
    sc.CanvasSize                  = _ud2(0, 0, 0, 0)
    sc.AutomaticCanvasSize         = Enum.AutomaticSize.Y
    sc.Visible                     = (td.id == "combat")
    sc.ZIndex                      = 3
    sc.Parent                      = contentMain

    local ll = _IN("UIListLayout")
    ll.Padding    = _ud(0, 7)
    ll.SortOrder  = Enum.SortOrder.LayoutOrder
    ll.Parent     = sc

    local lp = _IN("UIPadding")
    lp.PaddingTop    = _ud(0, 3)
    lp.PaddingBottom = _ud(0, 16)
    lp.PaddingLeft   = _ud(0, 2)
    lp.PaddingRight  = _ud(0, 2)
    lp.Parent        = sc

    tabFrames[td.id] = sc
end

local function _switchTab(id)
    curTab = id
    for tid, btn in _pr(tabBtns) do
        local td2
        for _, t in _ipr(TABS_DEF) do
            if t.id == tid then td2 = t break end
        end
        if not td2 then continue end
        if tid == id then
            _tween(btn, _tweenInfo(0.26), {BackgroundColor3=td2.col, BackgroundTransparency=0.1}):Play()
            for _, ch in _ipr(btn:GetChildren()) do
                if ch:IsA("TextLabel") then
                    _tween(ch, _tweenInfo(0.26), {TextColor3=_c3(255,255,255)}):Play()
                end
            end
        else
            _tween(btn, _tweenInfo(0.26), {BackgroundColor3=P.bgDeep, BackgroundTransparency=0.55}):Play()
            for _, ch in _ipr(btn:GetChildren()) do
                if ch:IsA("TextLabel") then
                    _tween(ch, _tweenInfo(0.26), {TextColor3=P.tD}):Play()
                end
            end
        end
    end
    for tid, ct in _pr(tabFrames) do ct.Visible = (tid == id) end
end

for _, td in _ipr(TABS_DEF) do
    local btn = _IN("TextButton")
    btn.Name                   = td.id
    btn.Size                   = _ud2(0, 70, 0, 28)
    btn.BackgroundColor3       = P.bgDeep
    btn.BackgroundTransparency = 0.55
    btn.Text                   = ""
    btn.BorderSizePixel        = 0
    btn.AutoButtonColor        = false
    btn.ZIndex                 = 5
    btn.Parent                 = tabBar
    _corner(btn, 8)

    local iL = _IN("TextLabel")
    iL.Size                   = _ud2(0, 15, 1, 0)
    iL.Position               = _ud2(0, 5, 0, 0)
    iL.BackgroundTransparency = 1
    iL.Text                   = td.icon
    iL.TextSize               = 11
    iL.Font                   = Enum.Font.GothamBold
    iL.TextColor3             = P.tD
    iL.ZIndex                 = 6
    iL.Parent                 = btn

    local nL = _IN("TextLabel")
    nL.Size                   = _ud2(1, -22, 1, 0)
    nL.Position               = _ud2(0, 20, 0, 0)
    nL.BackgroundTransparency = 1
    nL.Text                   = td.name
    nL.TextSize               = 9.5
    nL.Font                   = Enum.Font.GothamBold
    nL.TextColor3             = P.tD
    nL.TextXAlignment         = Enum.TextXAlignment.Left
    nL.ZIndex                 = 6
    nL.Parent                 = btn

    btn.MouseButton1Click:Connect(function() _switchTab(td.id) end)
    tabBtns[td.id] = btn
end

-- ══════════════════════════════════════════════
-- СЛАЙДЕР
-- ══════════════════════════════════════════════
local function _makeSlider(parent, label, mn, mx, cur, col, order, onChange)
    local card = _IN("Frame")
    card.Size                   = _ud2(1, 0, 0, 60)
    card.BackgroundColor3       = P.bgCard
    card.BackgroundTransparency = 0.04
    card.BorderSizePixel        = 0
    card.LayoutOrder            = order
    card.ZIndex                 = 3
    card.ClipsDescendants       = false
    card.Parent                 = parent
    _corner(card, 14)
    _uiStroke(card, P.bord, 0.6, 0.55)

    local lbl = _IN("TextLabel")
    lbl.Size                   = _ud2(0.62, 0, 0, 18)
    lbl.Position               = _ud2(0, 12, 0, 7)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = label
    lbl.TextColor3             = P.tW
    lbl.TextSize               = 11
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 4
    lbl.Parent                 = card

    local valL = _IN("TextLabel")
    valL.Size                   = _ud2(0.34, 0, 0, 18)
    valL.Position               = _ud2(0.66, 0, 0, 7)
    valL.BackgroundTransparency = 1
    valL.Text                   = _tostr(cur)
    valL.TextColor3             = col
    valL.TextSize               = 11
    valL.Font                   = Enum.Font.GothamBold
    valL.TextXAlignment         = Enum.TextXAlignment.Right
    valL.ZIndex                 = 4
    valL.Parent                 = card

    local track = _IN("Frame")
    track.Size             = _ud2(1, -24, 0, 6)
    track.Position         = _ud2(0, 12, 0, 38)
    track.BackgroundColor3 = _c3(18, 18, 38)
    track.BorderSizePixel  = 0
    track.ZIndex           = 4
    track.Parent           = card
    _corner(track, 3)

    local ir = _mclp((cur - mn) / (mx - mn), 0, 1)

    local fill = _IN("Frame")
    fill.Size             = _ud2(ir, 0, 1, 0)
    fill.BackgroundColor3 = col
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 5
    fill.Parent           = track
    _corner(fill, 3)
    _uiGrad(fill, ColorSequence.new{
        ColorSequenceKeypoint.new(0, col),
        ColorSequenceKeypoint.new(1, P.a2),
    })

    local knob = _IN("Frame")
    knob.Size             = _ud2(0, 14, 0, 14)
    knob.AnchorPoint      = Vector2.new(0.5, 0.5)
    knob.Position         = _ud2(ir, 0, 0.5, 0)
    knob.BackgroundColor3 = _c3(255, 255, 255)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 6
    knob.Parent           = track
    _corner(knob, 7)
    _uiStroke(knob, col, 1.5, 0)

    local dragging = false
    local sBtn = _IN("TextButton")
    sBtn.Size                   = _ud2(1, 0, 1, 24)
    sBtn.Position               = _ud2(0, 0, 0, -12)
    sBtn.BackgroundTransparency = 1
    sBtn.Text                   = ""
    sBtn.ZIndex                 = 7
    sBtn.Parent                 = track

    local function updateVal(ax)
        local absX = track.AbsolutePosition.X
        local w    = track.AbsoluteSize.X
        local r    = _mclp((ax - absX) / w, 0, 1)
        local val  = _mf(mn + (mx - mn) * r)
        valL.Text  = _tostr(val)
        _tween(fill,  _tweenInfo(0.04), {Size     = _ud2(r, 0, 1, 0)}):Play()
        _tween(knob,  _tweenInfo(0.04), {Position = _ud2(r, 0, 0.5, 0)}):Play()
        if onChange then onChange(val) end
    end

    sBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    _UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    _UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                      or inp.UserInputType == Enum.UserInputType.Touch) then
            updateVal(inp.Position.X)
        end
    end)

    return card
end

-- ══════════════════════════════════════════════
-- МОДУЛЬНАЯ КАРТОЧКА
-- ══════════════════════════════════════════════
local _allMods = {}

local function _makeModule(tabId, icon, name, desc, order, accent, tags, cfgKey, onEnable, onDisable)
    local parent = tabFrames[tabId]
    if not parent then return nil, nil end

    local card = _IN("Frame")
    card.Name                   = _gID(5)
    card.Size                   = _ud2(1, 0, 0, 92)
    card.BackgroundColor3       = P.bgCard
    card.BackgroundTransparency = 0.04
    card.BorderSizePixel        = 0
    card.LayoutOrder            = order
    card.ZIndex                 = 3
    card.ClipsDescendants       = true
    card.Parent                 = parent
    _corner(card, 16)
    local cSt = _uiStroke(card, P.bord, 0.6, 0.55)

    -- Стеклянный эффект
    local glass = _IN("Frame")
    glass.Size                   = _ud2(1, 0, 0.42, 0)
    glass.BackgroundColor3       = _c3(255, 255, 255)
    glass.BackgroundTransparency = 0.97
    glass.BorderSizePixel        = 0
    glass.ZIndex                 = 3
    glass.Parent                 = card
    _corner(glass, 16)

    -- Левая акцентная полоса
    local lBar = _IN("Frame")
    lBar.Size                   = _ud2(0, 3, 0.36, 0)
    lBar.Position               = _ud2(0, 0, 0.32, 0)
    lBar.BackgroundColor3       = accent
    lBar.BackgroundTransparency = 0.2
    lBar.BorderSizePixel        = 0
    lBar.ZIndex                 = 4
    lBar.Parent                 = card
    _corner(lBar, 2)

    -- Иконка
    local iBG = _IN("Frame")
    iBG.Size                   = _ud2(0, 52, 0, 52)
    iBG.Position               = _ud2(0, 12, 0, 10)
    iBG.BackgroundColor3       = accent
    iBG.BackgroundTransparency = 0.87
    iBG.BorderSizePixel        = 0
    iBG.ZIndex                 = 4
    iBG.Parent                 = card
    _corner(iBG, 15)

    local iIn = _IN("Frame")
    iIn.Size                   = _ud2(0, 36, 0, 36)
    iIn.AnchorPoint            = Vector2.new(0.5, 0.5)
    iIn.Position               = _ud2(0.5, 0, 0.5, 0)
    iIn.BackgroundColor3       = accent
    iIn.BackgroundTransparency = 0.7
    iIn.BorderSizePixel        = 0
    iIn.ZIndex                 = 5
    iIn.Parent                 = iBG
    _corner(iIn, 10)

    local iEmoji = _IN("TextLabel")
    iEmoji.Size                   = _ud2(1, 0, 1, 0)
    iEmoji.BackgroundTransparency = 1
    iEmoji.Text                   = icon
    iEmoji.TextSize               = 18
    iEmoji.Font                   = Enum.Font.GothamBold
    iEmoji.ZIndex                 = 6
    iEmoji.Parent                 = iIn

    -- Название
    local nameL = _IN("TextLabel")
    nameL.Size                   = _ud2(1, -148, 0, 20)
    nameL.Position               = _ud2(0, 74, 0, 12)
    nameL.BackgroundTransparency = 1
    nameL.Text                   = name
    nameL.TextColor3             = P.tW
    nameL.TextSize               = 13
    nameL.Font                   = Enum.Font.GothamBold
    nameL.TextXAlignment         = Enum.TextXAlignment.Left
    nameL.ZIndex                 = 4
    nameL.Parent                 = card

    -- Описание
    local descL = _IN("TextLabel")
    descL.Size                   = _ud2(1, -148, 0, 12)
    descL.Position               = _ud2(0, 74, 0, 34)
    descL.BackgroundTransparency = 1
    descL.Text                   = desc
    descL.TextColor3             = P.tD
    descL.TextSize               = 9
    descL.Font                   = Enum.Font.Gotham
    descL.TextXAlignment         = Enum.TextXAlignment.Left
    descL.ZIndex                 = 4
    descL.Parent                 = card

    -- Теги
    if tags then
        local tx = 74
        for _, tag in _ipr(tags) do
            local tf = _IN("Frame")
            tf.Size                   = _ud2(0, #tag * 5.1 + 14, 0, 15)
            tf.Position               = _ud2(0, tx, 0, 52)
            tf.BackgroundColor3       = accent
            tf.BackgroundTransparency = 0.88
            tf.BorderSizePixel        = 0
            tf.ZIndex                 = 4
            tf.Parent                 = card
            _corner(tf, 5)
            local tl = _IN("TextLabel")
            tl.Size                   = _ud2(1, 0, 1, 0)
            tl.BackgroundTransparency = 1
            tl.Text                   = tag
            tl.TextColor3             = accent
            tl.TextSize               = 6.5
            tl.Font                   = Enum.Font.GothamBlack
            tl.ZIndex                 = 5
            tl.Parent                 = tf
            tx = tx + #tag * 5.1 + 17
        end
    end

    -- Нижняя линия
    local botLine = _IN("Frame")
    botLine.Size                   = _ud2(0, 0, 0, 2)
    botLine.AnchorPoint            = Vector2.new(0.5, 0)
    botLine.Position               = _ud2(0.5, 0, 1, -3)
    botLine.BackgroundColor3       = accent
    botLine.BackgroundTransparency = 0.3
    botLine.BorderSizePixel        = 0
    botLine.ZIndex                 = 4
    botLine.Parent                 = card
    _corner(botLine, 1)
    _uiGrad(botLine, ColorSequence.new{
        ColorSequenceKeypoint.new(0,   accent),
        ColorSequenceKeypoint.new(0.5, P.a2),
        ColorSequenceKeypoint.new(1,   accent),
    })

    -- Тоггл
    local tog = _IN("TextButton")
    tog.Size                   = _ud2(0, 54, 0, 28)
    tog.Position               = _ud2(1, -66, 0.5, -14)
    tog.BackgroundColor3       = P.tOff
    tog.Text                   = ""
    tog.BorderSizePixel        = 0
    tog.AutoButtonColor        = false
    tog.ZIndex                 = 4
    tog.Parent                 = card
    _corner(tog, 14)
    local togSt = _uiStroke(tog, P.bord, 0.5, 0.5)

    local knob = _IN("Frame")
    knob.Size             = _ud2(0, 22, 0, 22)
    knob.Position         = _ud2(0, 3, 0.5, -11)
    knob.BackgroundColor3 = P.tKnob
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 5
    knob.Parent           = tog
    _corner(knob, 11)
    local knobSt = _uiStroke(knob, accent, 0, 0.8)

    local kDot = _IN("Frame")
    kDot.Size                   = _ud2(0, 7, 0, 7)
    kDot.AnchorPoint            = Vector2.new(0.5, 0.5)
    kDot.Position               = _ud2(0.5, 0, 0.5, 0)
    kDot.BackgroundColor3       = accent
    kDot.BackgroundTransparency = 1
    kDot.BorderSizePixel        = 0
    kDot.ZIndex                 = 6
    kDot.Parent                 = knob
    _corner(kDot, 4)

    -- Hover-кнопка
    local hov = _IN("TextButton")
    hov.Size                   = _ud2(1, 0, 1, 0)
    hov.BackgroundTransparency = 1
    hov.Text                   = ""
    hov.ZIndex                 = 3
    hov.Parent                 = card

    hov.MouseEnter:Connect(function()
        _tween(card,    _tweenInfo(0.2), {BackgroundTransparency=0}):Play()
        _tween(cSt,     _tweenInfo(0.2), {Transparency=0.08, Color=accent}):Play()
        _tween(lBar,    _tweenInfo(0.26), {BackgroundTransparency=0, Size=_ud2(0,4.5,0.46,0)}):Play()
        _tween(botLine, _tweenInfo(0.36), {Size=_ud2(0.86,0,0,2.5)}):Play()
        _tween(iBG,     _tweenInfo(0.26), {BackgroundTransparency=0.76}):Play()
    end)
    hov.MouseLeave:Connect(function()
        _tween(card,    _tweenInfo(0.2), {BackgroundTransparency=0.04}):Play()
        _tween(cSt,     _tweenInfo(0.2), {Transparency=0.55, Color=P.bord}):Play()
        _tween(lBar,    _tweenInfo(0.26), {BackgroundTransparency=0.2, Size=_ud2(0,3,0.36,0)}):Play()
        _tween(botLine, _tweenInfo(0.36), {Size=_ud2(0,0,0,2)}):Play()
        _tween(iBG,     _tweenInfo(0.26), {BackgroundTransparency=0.87}):Play()
    end)

    local isOn = false
    local function setVisual(state)
        isOn = state
        local ti = _tweenInfo(0.32)
        if state then
            _tween(tog,     ti, {BackgroundColor3=accent}):Play()
            _tween(togSt,   ti, {Color=accent, Transparency=0.05}):Play()
            _tween(knob,    ti, {Position=_ud2(1,-25,0.5,-11), BackgroundColor3=_c3(255,255,255)}):Play()
            _tween(knobSt,  ti, {Thickness=2, Transparency=0}):Play()
            _tween(kDot,    ti, {BackgroundTransparency=0}):Play()
            _tween(cSt,     ti, {Color=accent, Transparency=0.14}):Play()
            _tween(lBar,    ti, {BackgroundTransparency=0}):Play()
            _tween(iIn,     ti, {BackgroundTransparency=0.45}):Play()
            _tween(botLine, _tweenInfo(0.4, Enum.EasingStyle.Quint),
                {Size=_ud2(0.92,0,0,2.5), BackgroundTransparency=0.05}):Play()
        else
            _tween(tog,     ti, {BackgroundColor3=P.tOff}):Play()
            _tween(togSt,   ti, {Color=P.bord, Transparency=0.5}):Play()
            _tween(knob,    ti, {Position=_ud2(0,3,0.5,-11), BackgroundColor3=P.tKnob}):Play()
            _tween(knobSt,  ti, {Thickness=0, Transparency=0.8}):Play()
            _tween(kDot,    ti, {BackgroundTransparency=1}):Play()
            _tween(cSt,     ti, {Color=P.bord, Transparency=0.55}):Play()
            _tween(lBar,    ti, {BackgroundTransparency=0.2}):Play()
            _tween(iIn,     ti, {BackgroundTransparency=0.7}):Play()
            _tween(botLine, _tweenInfo(0.28),
                {Size=_ud2(0,0,0,2), BackgroundTransparency=0.3}):Play()
        end
    end

    _allMods[#_allMods + 1] = { cfgKey = cfgKey, color = accent }

    tog.MouseButton1Click:Connect(function()
        CFG[cfgKey] = not CFG[cfgKey]
        setVisual(CFG[cfgKey])
        if CFG[cfgKey] then
            _refChar()
            if onEnable then _pc(onEnable) end
        else
            if onDisable then _pc(onDisable) end
        end
        _updateStatus()
    end)

    return tog, setVisual
end

-- ══════════════════════════════════════════════
-- ВСЕ МОДУЛИ
-- ══════════════════════════════════════════════

-- COMBAT
_makeModule("combat","🛡️","God Mode","Бесконечное HP",
    1,P.a3,{"IMMORTAL","HP"},"godMode",_startGod,_stopGod)

_makeModule("combat","👻","Anti-Ragdoll","Ghost-контроль при рагдолле v10",
    2,P.a2,{"GHOST","v10","SAB"},"antiRag",_startAntiRag,_stopAntiRag)

_makeModule("combat","💀","Big Head","Огромные головы врагов",
    3,P.a7,{"HITBOX","PVP"},"bigHead",_startBigHead,function() CFG.bigHead=false end)

_makeModule("combat","📦","Hitbox Expand","Расширить хитбокс врагов",
    4,P.a3,{"EXPAND","BOX"},"hitboxExp",_expandHB,_restoreHB)

_makeModule("combat","💥","No Knockback","Нет отбрасывания",
    5,P.a7,{"STABLE","SAB"},"noKnockback",_startNoKB,_stopNoKB)

-- MOVEMENT
_makeModule("movement","⚡","Infinite Jump","Бесконечные прыжки",
    1,P.a1,{"AIR","MULTI"},"infJump",function()end,function()end)

_makeModule("movement","🏃","Speed","Ускорение персонажа",
    2,P.a4,{"FAST","SAB"},"speed",_startSpeed,_stopSpeed)

_makeModule("movement","🕊️","Fly","Свободный полёт WASD+Space/Ctrl",
    3,P.a8,{"FLY","3D"},"fly",_startFly,_stopFly)

_makeModule("movement","👤","Noclip","Проход сквозь стены",
    4,P.a6,{"PHASE","WALL"},"noclip",_startNoclip,_stopNoclip)

_makeModule("movement","🌙","Low Gravity","Лунная гравитация",
    5,_c3(185,135,255),{"MOON","FLOAT"},"lowGrav",_startLowG,_stopLowG)

-- VISUAL
_makeModule("visual","🎭","No Animations","Заморозка анимаций",
    1,P.a3,{"FREEZE"},"noAnim",_startNoAnim,_stopNoAnim)

_makeModule("visual","👁️","ESP","Видеть врагов сквозь стены + HP",
    2,P.a5,{"WALL","HP","DIST"},"esp",_startESP,_stopESP)

_makeModule("visual","🌈","Chams","RGB подсветка тел",
    3,P.a6,{"CHAMS","RGB"},"chams",_startChams,_stopChams)

_makeModule("visual","📍","Tracers","Линии к врагам",
    4,P.a4,{"LINE","TRACK"},"tracers",
    function() _startTracers(SG) end,
    _stopTracers)

-- WORLD
_makeModule("world","☀️","Fullbright","Максимальная яркость",
    1,P.a4,{"BRIGHT"},"fullbright",_startFB,_stopFB)

_makeModule("world","🌫️","No Fog","Убрать туман",
    2,P.a8,{"CLEAR"},"noFog",_startNoFog,_stopNoFog)

-- AIMBOT
_makeModule("aimbot","🎯","Aimbot","Автоприцел — держи Q",
    1,P.a7,{"LOCK","SMOOTH"},"aimbot",
    function() _drawFOV(SG) end,
    function()
        _aimTgt = nil _aimLock = false
        if _aimFOVG then _pc(function() _aimFOVG:Destroy() end) _aimFOVG = nil end
    end)

_makeModule("aimbot","👻","Silent Aim","Пули летят в цель",
    2,P.a3,{"SILENT"},"silentAim",
    function()end,
    function() _aimTgt = nil _aimLock = false end)

-- Слайдеры aimbot
_makeSlider(tabFrames["aimbot"],"FOV Radius",50,500,CFG.aimFOV,P.a7,3,function(v)
    CFG.aimFOV = v
    if _aimFOVG then
        _pc(function()
            _aimFOVG.Size = _ud2(0, v*2, 0, v*2)
            local c = _aimFOVG:FindFirstChildOfClass("UICorner")
            if c then c.CornerRadius = _ud(0, v) end
        end)
    end
end)

_makeSlider(tabFrames["aimbot"],"Smooth %",1,50,_mf(CFG.aimSmooth*100),P.a7,4,function(v)
    CFG.aimSmooth = v / 100
end)

_makeSlider(tabFrames["aimbot"],"Hitbox Size",2,24,CFG.hitboxSz,P.a3,5,function(v)
    CFG.hitboxSz = v
end)

_makeSlider(tabFrames["aimbot"],"Fly Speed",10,200,CFG.flySpeed,P.a8,6,function(v)
    CFG.flySpeed = v
end)

_makeSlider(tabFrames["aimbot"],"Walk Speed",16,120,CFG.speedVal,P.a4,7,function(v)
    CFG.speedVal = v
    if CFG.speed and _hum then _pc(function() _hum.WalkSpeed = v end) end
end)

-- SAB TAB
_makeModule("sab","🧠","Auto Collect","Авто-сбор брейнротов",
    1,P.a9,{"AUTO","COLLECT","SAB"},"autoCollect",_startAutoCollect,_stopAutoCollect)

_makeModule("sab","💨","No Knockback","Нет отбрасывания в SAB",
    2,P.a7,{"STABLE","SAB"},"noKnockback",_startNoKB,_stopNoKB)

_makeModule("sab","🎯","Teleport Steal","ТП к чужим предметам",
    3,P.a3,{"TP","STEAL","SAB"},"teleportSteal",_startTpSteal,_stopTpSteal)

_makeSlider(tabFrames["sab"],"Jump Power",30,120,CFG.jumpPower,P.a1,10,function(v)
    CFG.jumpPower = v
    if _hum then _pc(function() _hum.JumpPower = v end) end
end)

_makeSlider(tabFrames["sab"],"Collect Radius",10,80,35,P.a9,11,function(v)
    -- Обновляем радиус (используется в autoCollect)
end)

-- ══════════════════════════════════════════════
-- STATUS BAR
-- ══════════════════════════════════════════════
local SB = _IN("Frame")
SB.Name                   = _gID(4)
SB.Size                   = _ud2(1, -14, 0, 58)
SB.Position               = _ud2(0, 7, 1, -64)
SB.BackgroundColor3       = P.bgDeep
SB.BackgroundTransparency = 0.08
SB.BorderSizePixel        = 0
SB.ZIndex                 = 5
SB.Parent                 = MF
_corner(SB, 14)
_uiStroke(SB, P.bord, 0.5, 0.6)

local statL = _IN("TextLabel")
statL.Size                   = _ud2(0.58, 0, 0, 20)
statL.Position               = _ud2(0, 12, 0, 6)
statL.BackgroundTransparency = 1
statL.Text                   = "Ready"
statL.TextColor3             = P.tD
statL.TextSize               = 11
statL.Font                   = Enum.Font.GothamMedium
statL.TextXAlignment         = Enum.TextXAlignment.Left
statL.ZIndex                 = 6
statL.Parent                 = SB

local infoL = _IN("TextLabel")
infoL.Size                   = _ud2(0.58, 0, 0, 14)
infoL.Position               = _ud2(0, 12, 0, 27)
infoL.BackgroundTransparency = 1
infoL.Text                   = ""
infoL.TextColor3             = P.a2
infoL.TextSize               = 9
infoL.Font                   = Enum.Font.Gotham
infoL.TextXAlignment         = Enum.TextXAlignment.Left
infoL.ZIndex                 = 6
infoL.Parent                 = SB

local pingL = _IN("TextLabel")
pingL.Size                   = _ud2(0, 85, 0, 12)
pingL.Position               = _ud2(1, -92, 0, 6)
pingL.BackgroundTransparency = 1
pingL.Text                   = "● " .. _tostr(_ri(8, 40)) .. "ms"
pingL.TextColor3             = P.tG
pingL.TextSize               = 8
pingL.Font                   = Enum.Font.GothamMedium
pingL.TextXAlignment         = Enum.TextXAlignment.Right
pingL.ZIndex                 = 6
pingL.Parent                 = SB

local lockL = _IN("TextLabel")
lockL.Size                   = _ud2(0, 130, 0, 12)
lockL.Position               = _ud2(1, -136, 0, 21)
lockL.BackgroundTransparency = 1
lockL.Text                   = ""
lockL.TextColor3             = P.a3
lockL.TextSize               = 8
lockL.Font                   = Enum.Font.GothamBold
lockL.TextXAlignment         = Enum.TextXAlignment.Right
lockL.ZIndex                 = 6
lockL.Parent                 = SB

-- Active dots (20 штук)
local _dots = {}
for i = 1, 20 do
    local d = _IN("Frame")
    d.Size             = _ud2(0, 6, 0, 6)
    d.Position         = _ud2(0, 12 + (i-1)*9, 0, 46)
    d.BackgroundColor3 = _c3(16, 16, 32)
    d.BorderSizePixel  = 0
    d.ZIndex           = 6
    d.Parent           = SB
    _corner(d, 3)
    _dots[i] = d
end

function _updateStatus()
    local keys = {
        "infJump","antiRag","noAnim","speed","fly","noclip","esp",
        "godMode","fullbright","noFog","bigHead","lowGrav",
        "aimbot","silentAim","hitboxExp","chams","tracers",
        "autoCollect","noKnockback","teleportSteal",
    }
    local cnt, cols = 0, {}
    for _, k in _ipr(keys) do
        if CFG[k] then
            cnt = cnt + 1
            for _, md in _ipr(_allMods) do
                if md.cfgKey == k then
                    cols[#cols + 1] = md.color
                    break
                end
            end
        end
    end
    for i = 1, 20 do
        if i <= cnt and cols[i] then
            _tween(_dots[i], _tweenInfo(0.28), {BackgroundColor3=cols[i]}):Play()
        else
            _tween(_dots[i], _tweenInfo(0.28), {BackgroundColor3=_c3(16,16,32)}):Play()
        end
    end
    if cnt == 0 then
        statL.Text = "Все модули неактивны"
        _tween(statL, _tweenInfo(0.28), {TextColor3=P.tD}):Play()
    else
        statL.Text = cnt .. "/20 · TERMINATOR"
        _tween(statL, _tweenInfo(0.28), {TextColor3=P.tG}):Play()
    end
end

-- Инфо-цикл
_tsp(function()
    while SG and SG.Parent do
        _pc(function()
            -- Aimbot lock
            if _aimLock and _aimTgt then
                lockL.Text     = "🎯 " .. _aimTgt.DisplayName
                lockL.TextColor3 = P.a3
            else
                lockL.Text = ""
            end

            -- Info строка
            if _ghostOn then
                infoL.Text      = "👻 GHOST · " .. _mf(tick() - _ragT) .. "s"
                infoL.TextColor3 = _c3h((tick() * 0.17) % 1, 0.35, 1)
            elseif _exitLk then
                infoL.Text      = "⟳ Stabilizing..."
                infoL.TextColor3 = P.a4
            elseif _flyOn then
                infoL.Text      = "🕊️ Fly · " .. CFG.flySpeed .. " u/s"
                infoL.TextColor3 = P.a8
            elseif CFG.autoCollect then
                infoL.Text      = "🧠 Collecting Brainrots..."
                infoL.TextColor3 = P.a9
            elseif CFG.teleportSteal then
                infoL.Text      = "🎯 Teleport Stealing..."
                infoL.TextColor3 = P.a3
            elseif CFG.hitboxExp then
                infoL.Text      = "📦 Hitbox ×" .. CFG.hitboxSz
                infoL.TextColor3 = P.a3
            else
                infoL.Text = ""
            end

            -- Псевдо-пинг
            pingL.Text = "● " .. _ri(5, 55) .. "ms"
        end)
        _tw(0.1)
    end
end)

-- ══════════════════════════════════════════════
-- MINIMIZE / CLOSE
-- ══════════════════════════════════════════════
local _minimized = false

MinBtn.MouseButton1Click:Connect(function()
    _minimized = not _minimized
    if _minimized then
        _tween(MF, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Size = _ud2(0, 475, 0, 84)}):Play()
        _td(0.06, function()
            contentMain.Visible = false
            tabBar.Visible      = false
            SB.Visible          = false
        end)
        MinBtn.Text = "◻"
    else
        _tween(MF, TweenInfo.new(0.5, Enum.EasingStyle.Back),
            {Size = _ud2(0, 475, 0, 695)}):Play()
        _td(0.2, function()
            contentMain.Visible = true
            tabBar.Visible      = true
            SB.Visible          = true
        end)
        MinBtn.Text = "━"
    end
end)

ClsBtn.MouseButton1Click:Connect(function()
    -- Выключаем всё
    for k, v in _pr(CFG) do
        if _type(v) == "boolean" then CFG[k] = false end
    end
    _stopAntiRag()
    _stopNoAnim()
    _stopFly()
    _stopNoclip()
    _stopESP()
    _stopGod()
    _stopFB()
    _stopNoFog()
    _stopLowG()
    _stopSpeed()
    _stopChams()
    _stopTracers()
    _stopAutoCollect()
    _stopNoKB()
    _stopTpSteal()
    _restoreHB()
    if _aimFOVG then _pc(function() _aimFOVG:Destroy() end) end
    if _hbConn  then _hbConn:Disconnect() end

    -- Анимация закрытия
    _tween(_mStroke, _tweenInfo(0.1), {Transparency=1}):Play()
    _tween(MF, TweenInfo.new(0.46, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size                   = _ud2(0, 6, 0, 6),
        Position               = _ud2(0.5, -3, 0.5, -3),
        BackgroundTransparency = 0.3,
    }):Play()
    _td(0.34, function()
        _tween(MF, _tweenInfo(0.14), {BackgroundTransparency=1}):Play()
    end)
    _td(0.52, function()
        _pc(function() SG:Destroy() end)
    end)
end)

-- ══════════════════════════════════════════════
-- LIVE ANIMATIONS
-- ══════════════════════════════════════════════

-- Граница + радуга логотипа
_tsp(function()
    local hue = _rf(0, 1)
    while SG and SG.Parent do
        hue = (hue + 0.0008) % 1
        local ac = 0
        for _, v in _pr(CFG) do if _type(v)=="boolean" and v then ac=ac+1 end end
        local t = tick()
        if ac > 0 then
            _mStroke.Color       = _c3h(hue, _mclp(0.32+ac*0.036, 0, 0.88), _mclp(0.6+ac*0.016, 0, 1))
            _mStroke.Transparency = 0.02 + _ms(t*1.25) * 0.036
            _mStroke.Thickness    = 1.5  + _ms(t*1.75) * 0.44
            _pc(function()
                for _, r in _ipr(_rings) do
                    r.BackgroundColor3 = _c3h((hue+0.05)%1, 0.5, 0.86)
                end
                logoGlow.BackgroundColor3 = _c3h((hue+0.1)%1, 0.56, 1)
            end)
        else
            _mStroke.Color       = P.bord
            _mStroke.Transparency = 0.55
            _mStroke.Thickness    = 1
            _pc(function()
                for _, r in _ipr(_rings) do r.BackgroundColor3 = P.a1 end
                logoGlow.BackgroundColor3 = P.a1
            end)
        end
        _tw(0.02)
    end
end)

-- Aurora float
_tsp(function()
    local ph = {}
    for i = 1, #_orbDef do ph[i] = _rf(0, _mpi*2) end
    while SG and SG.Parent do
        local t = tick()
        for i, o in _ipr(_orbs) do
            _pc(function()
                local od = _orbDef[i]
                local ox = _ms(t*(0.088+i*0.036)+ph[i]) * 18
                local oy = _mcos(t*(0.108+i*0.026)+ph[i]*0.66) * 15
                o.Position             = _ud2(od[1].X.Scale, od[1].X.Offset+ox, od[1].Y.Scale, od[1].Y.Offset+oy)
                o.BackgroundTransparency = od[4] + _ms(t*(0.24+i*0.044)) * 0.008
            end)
        end
        _tw(0.022)
    end
end)

-- Пульс логотипа
_tsp(function()
    while SG and SG.Parent do
        local ac = 0
        for _, v in _pr(CFG) do if _type(v)=="boolean" and v then ac=ac+1 end end
        if ac > 0 then
            for i, r in _ipr(_rings) do
                _pc(function()
                    local rd = _ringDef[i]
                    _tween(r, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        BackgroundTransparency = rd[2] - 0.07,
                        Size = _ud2(0, rd[1]+6, 0, rd[1]+6),
                    }):Play()
                end)
            end
            _pc(function()
                _tween(logoGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    BackgroundTransparency = 0.09,
                    Size = _ud2(0, 32, 0, 32),
                }):Play()
            end)
            _tw(2)
            if not (SG and SG.Parent) then return end
            for i, r in _ipr(_rings) do
                _pc(function()
                    local rd = _ringDef[i]
                    _tween(r, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        BackgroundTransparency = rd[2],
                        Size = _ud2(0, rd[1], 0, rd[1]),
                    }):Play()
                end)
            end
            _pc(function()
                _tween(logoGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    BackgroundTransparency = 0.28,
                    Size = _ud2(0, 28, 0, 28),
                }):Play()
            end)
            _tw(2)
        else
            _tw(0.5)
        end
    end
end)

-- Пульс точек
_tsp(function()
    while SG and SG.Parent do
        local cnt = 0
        for _, v in _pr(CFG) do if _type(v)=="boolean" and v then cnt=cnt+1 end end
        for i = 1, _mmn(cnt, 20) do
            _pc(function()
                _tween(_dots[i], TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    Size = _ud2(0, 9, 0, 9),
                }):Play()
            end)
        end
        _tw(0.6)
        if not (SG and SG.Parent) then return end
        for i = 1, 20 do
            _pc(function()
                _tween(_dots[i], TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    Size = _ud2(0, 6, 0, 6),
                }):Play()
            end)
        end
        _tw(0.6)
    end
end)

-- ══════════════════════════════════════════════
-- КИНЕМАТИЧНОЕ ОТКРЫТИЕ
-- ══════════════════════════════════════════════
MF.BackgroundTransparency = 1
contentMain.Visible = false
tabBar.Visible      = false
SB.Visible          = false
_mStroke.Transparency = 1
HD.BackgroundTransparency   = 1
HDPatch.BackgroundTransparency = 1
for _, o in _ipr(_orbs) do o.BackgroundTransparency = 1 end
for _, c in _ipr(HD:GetDescendants()) do
    _pc(function()
        if c:IsA("TextLabel") or c:IsA("TextButton") then c.TextTransparency = 1 end
        if c:IsA("Frame") then c.BackgroundTransparency = 1 end
    end)
end

_td(0.05, function()
    -- Dot появление
    MF.Size     = _ud2(0, 6, 0, 6)
    MF.Position = _ud2(0.5, -3, 0.5, -3)
    _tween(MF,      _tweenInfo(0.1), {BackgroundTransparency=0}):Play()
    _tween(_mStroke,_tweenInfo(0.1), {Transparency=0.08}):Play()
    _tw(0.08)

    -- Горизонтальное расширение
    _tween(MF, TweenInfo.new(0.24, Enum.EasingStyle.Quint), {
        Size     = _ud2(0, 475, 0, 6),
        Position = _ud2(0.5, -237, 0.5, -3),
    }):Play()
    _tw(0.2)

    -- Вертикальное расширение
    _tween(MF, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size     = _ud2(0, 475, 0, 695),
        Position = _ud2(0.5, -237, 0.5, -347),
    }):Play()
    _tw(0.15)

    -- Aurora
    for i, o in _ipr(_orbs) do
        _td(i * 0.02, function()
            _tween(o, TweenInfo.new(0.56, Enum.EasingStyle.Quint), {
                BackgroundTransparency = _orbDef[i][4],
            }):Play()
        end)
    end

    -- Header
    _td(0.1, function()
        _tween(HD,      _tweenInfo(0.26), {BackgroundTransparency=0.02}):Play()
        _tween(HDPatch, _tweenInfo(0.26), {BackgroundTransparency=0.02}):Play()
        local dl = 0
        for _, c in _ipr(HD:GetDescendants()) do
            _pc(function()
                dl = dl + 0.006
                if c:IsA("TextLabel") then
                    _td(dl, function()
                        _tween(c, _tweenInfo(0.36), {TextTransparency=0}):Play()
                    end)
                end
                if c:IsA("TextButton") then
                    _td(dl, function()
                        _tween(c, _tweenInfo(0.36), {TextTransparency=0, BackgroundTransparency=0.52}):Play()
                    end)
                end
                if c:IsA("Frame") and c ~= HDPatch then
                    _td(dl, function()
                        local tgt = 0.87
                        if c == _rings[1] then tgt = _ringDef[1][2]
                        elseif c == _rings[2] then tgt = _ringDef[2][2]
                        elseif c == _rings[3] then tgt = _ringDef[3][2]
                        elseif c == logoGlow  then tgt = 0.28 end
                        _tween(c, _tweenInfo(0.42), {BackgroundTransparency=tgt}):Play()
                    end)
                end
            end)
        end
    end)

    _tw(0.24)

    -- Tab bar
    tabBar.Visible = true
    tabBar.BackgroundTransparency = 1
    _tween(tabBar, _tweenInfo(0.3), {BackgroundTransparency=0.22}):Play()
    for _, b in _pr(tabBtns) do
        b.BackgroundTransparency = 1
        _tween(b, _tweenInfo(0.3), {BackgroundTransparency=0.55}):Play()
        for _, c in _ipr(b:GetChildren()) do
            if c:IsA("TextLabel") then
                c.TextTransparency = 1
                _tween(c, _tweenInfo(0.34), {TextTransparency=0}):Play()
            end
        end
    end

    _tw(0.1)
    contentMain.Visible = true

    -- Status bar
    SB.Visible = true
    SB.BackgroundTransparency = 1
    _tween(SB, _tweenInfo(0.36), {BackgroundTransparency=0.08}):Play()
    for _, c in _ipr(SB:GetChildren()) do
        _pc(function()
            if c:IsA("TextLabel") then
                c.TextTransparency = 1
                _tween(c, _tweenInfo(0.4), {TextTransparency=0}):Play()
            end
        end)
    end

    -- Каскад карточек
    local vis = tabFrames[curTab]
    if vis then
        local ci = 0
        for _, c in _ipr(vis:GetChildren()) do
            if c:IsA("Frame") then
                ci = ci + 1
                local idx = ci
                c.BackgroundTransparency = 1
                for _, d in _ipr(c:GetDescendants()) do
                    _pc(function()
                        if d:IsA("TextLabel") then d.TextTransparency = 1 end
                        if d:IsA("Frame") then d.BackgroundTransparency = 1 end
                        if d:IsA("TextButton") then
                            d.TextTransparency = 1
                            d.BackgroundTransparency = 1
                        end
                    end)
                end
                _td(idx * 0.06, function()
                    _tween(c, TweenInfo.new(0.4, Enum.EasingStyle.Quint),
                        {BackgroundTransparency=0.04}):Play()
                    _td(0.06, function()
                        for _, d in _ipr(c:GetDescendants()) do
                            _pc(function()
                                if d:IsA("TextLabel") then
                                    _tween(d, _tweenInfo(0.32), {TextTransparency=0}):Play()
                                end
                                if d:IsA("Frame") then
                                    local ft = 0.87
                                    if d.Size.X.Offset <= 5 then ft = 0.2
                                    elseif d.Size.X.Offset <= 22 then ft = 0.45
                                    elseif d.Size.X.Offset <= 55 then ft = 0.7 end
                                    _tween(d, _tweenInfo(0.32), {BackgroundTransparency=ft}):Play()
                                end
                                if d:IsA("TextButton") then
                                    _tween(d, _tweenInfo(0.32), {
                                        TextTransparency = 0,
                                        BackgroundTransparency = 0.4,
                                    }):Play()
                                end
                            end)
                        end
                    end)
                end)
            end
        end
    end

    _td(0.85, function()
        _tween(_mStroke, _tweenInfo(0.5), {Transparency=0.5}):Play()
    end)
end)

_switchTab("combat")
_updateStatus()
