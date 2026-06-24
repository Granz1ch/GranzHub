--[[ 
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    ░  OBFUSCATION LAYER — DO NOT EDIT ░
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
]]

local _E = Random.new(tick() * os.clock() * math.random(1,999999) + (game:GetService("Stats"):GetTotalMemoryUsageMb()))
local function _id(l)
    l=l or _E:NextInteger(12,20)
    local t={}
    for i=1,l do
        local r=_E:NextInteger(1,4)
        if r==1 then t[i]=string.char(_E:NextInteger(97,122))
        elseif r==2 then t[i]=string.char(_E:NextInteger(65,90))
        elseif r==3 then t[i]=string.char(_E:NextInteger(48,57))
        else t[i]="_"
        end
    end
    return table.concat(t)
end
local function _dly() return _E:NextNumber(0.001,0.007) end
local function _rn(a,b) return _E:NextNumber(a,b) end
local function _rin(a,b) return _E:NextInteger(a,b) end

-- Anti-detection: доступ к сервисам через метатаблицы
local _GS = setmetatable({},{
    __index = function(s,k)
        local ok,v = pcall(function() return game:GetService(k) end)
        if ok and v then rawset(s,k,v) return v end
    end
})

local _P = _GS.Players
local _UIS = _GS.UserInputService
local _RS = _GS.RunService
local _TS = _GS.TweenService
local _RP = _GS.ReplicatedStorage

local _lp = _P.LocalPlayer
local _pg = _lp:WaitForChild("PlayerGui")

-- ===================== КОНФИГ =====================
local _C = {
    _j = false,
    _ar = false,
    _na = false,
    _jp = 50,
    _cd = 0.12,
    _mfs = -60,
}

-- ===================== СОСТОЯНИЕ =====================
local _lastJ = 0
local _ch, _hu, _rt, _an
local _rc, _ac = {}, {}
local _hbc = nil
local _tt = {}
local _mSnap = {}
local _fM = {}

-- Ghost v5 state
local _ghostActive = false
local _ghostPart = nil
local _bMovers = {}
local _ragActive = false
local _ragStartTime = 0
local _preRagCF = nil
local _ghostCF = nil
local _exitingRag = false
local _ragTimeout = 6

-- Frame counter для антидетекта (не каждый кадр)
local _fc = 0
local _lastStateCheck = 0

local function _sf(o,n) local ok,r=pcall(function() return o:FindFirstChild(n) end) return ok and r or nil end
local function _sfc(o,c) local ok,r=pcall(function() return o:FindFirstChildOfClass(c) end) return ok and r or nil end
local function _w(fn) return function(...) local ok=pcall(fn,...) return ok end end

local function _ref()
    _ch = _lp.Character
    if not _ch then return false end
    _hu = _sfc(_ch,"Humanoid")
    _rt = _sf(_ch,"HumanoidRootPart")
    _an = _hu and _sfc(_hu,"Animator")
    return _hu ~= nil and _rt ~= nil
end
_ref()

-- ===================== INFINITE JUMP =====================
local function _doJ()
    if not _C._j then return end
    local jr = _rt
    if _ghostActive and _ghostPart and _ghostPart.Parent then
        jr = _ghostPart
    end
    if not (jr and jr.Parent) then return end
    if _hu and _hu.Health <= 0 then return end
    local n = tick()
    if n - _lastJ < _C._cd then return end
    _lastJ = n
    local cv = jr.AssemblyLinearVelocity
    local ny = _C._jp
    if cv.Y < _C._mfs then ny = _C._jp + math.abs(cv.Y)*0.3 end
    jr.AssemblyLinearVelocity = Vector3.new(
        cv.X * _rn(0.87,0.93),
        ny + _rn(-0.25,0.25),
        cv.Z * _rn(0.87,0.93)
    )
    task.delay(0.04+_dly(),function()
        if jr and jr.Parent and _C._j then
            local v = jr.AssemblyLinearVelocity
            if v.Y < _C._jp*0.75 then
                jr.AssemblyLinearVelocity = Vector3.new(v.X, _C._jp*_rn(0.85,0.95), v.Z)
            end
        end
    end)
end

_UIS.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.Space then
        if not _hu then return end
        if _ghostActive then _doJ() return end
        if not _rt then return end
        local st = _hu:GetState()
        if st==Enum.HumanoidStateType.Freefall or st==Enum.HumanoidStateType.Jumping or st==Enum.HumanoidStateType.FallingDown then
            _doJ()
        end
    end
end)

-- ===================== GHOST ANTI-RAGDOLL v5.0 =====================
--[[
    КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ v5.0:
    
    ПРОБЛЕМА v4: После рагдолла тело телепортировалось ОБРАТНО в точку рагдолла.
    Это происходило потому что:
    1. Сервер запоминал позицию рагдолла
    2. При GettingUp сервер ставил тело в позицию последней серверной CFrame
    3. Наша телепортация к призраку перезатиралась сервером
    
    РЕШЕНИЕ v5:
    - НЕ телепортируем тело к призраку мгновенно
    - Вместо этого: каждый кадр во время рагдолла ДВИГАЕМ HumanoidRootPart к призраку
    - Используем CFrame weld: привязываем root к ghost через невидимый WeldConstraint
    - Когда рагдолл кончается, root УЖЕ в позиции призрака
    - Сервер "думает" что тело само туда прилетело
    
    ДОПОЛНИТЕЛЬНО:
    - Проверяем рагдолл КАЖДЫЙ кадр (через PlatformStand + State)
    - Множественные fallback пути выхода
    - Таймаут 6 сек — если рагдолл застрял, форсим выход
    - Задержка перед созданием призрака — чтобы не конфликтовать с серверным кодом
]]

local _ragStates = {
    [Enum.HumanoidStateType.Ragdoll] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics] = true,
}
local function _isRag(st) return _ragStates[st]==true end

local function _snapMotors()
    _mSnap = {}
    if not _ch then return end
    for _,v in ipairs(_ch:GetDescendants()) do
        if v:IsA("Motor6D") then
            _mSnap[#_mSnap+1] = {
                _r=v, _n=v.Name, _p=v.Parent,
                _p0=v.Part0, _p1=v.Part1,
                _c0=v.C0, _c1=v.C1,
            }
        end
    end
end

local function _restoreMotors()
    if not _ch then return end
    for _,d in ipairs(_mSnap) do
        pcall(function()
            if d._r and d._r.Parent then d._r.Enabled=true return end
            if not(d._p and d._p.Parent and d._p0 and d._p0.Parent and d._p1 and d._p1.Parent) then return end
            local ex = d._p:FindFirstChild(d._n)
            if ex and ex:IsA("Motor6D") then ex.Enabled=true d._r=ex return end
            local m = Instance.new("Motor6D")
            m.Name=d._n m.Part0=d._p0 m.Part1=d._p1 m.C0=d._c0 m.C1=d._c1
            m.Parent=d._p
            d._r=m
            _fM[#_fM+1]=m
        end)
    end
end

local function _nukeConstraints()
    if not _ch then return end
    local types = {"BallSocketConstraint","HingeConstraint","NoCollisionConstraint",
        "RopeConstraint","SpringConstraint","CylindricalConstraint","PrismaticConstraint"}
    local typeSet = {}
    for _,t in ipairs(types) do typeSet[t]=true end
    for _,v in ipairs(_ch:GetDescendants()) do
        pcall(function()
            if typeSet[v.ClassName] then v:Destroy() end
        end)
    end
end

-- Создание призрака v5
local function _spawnGhost()
    if _ghostPart and _ghostPart.Parent then return end
    if not(_rt and _rt.Parent and _ch) then return end

    _preRagCF = _rt.CFrame
    _ghostCF = _preRagCF

    local g = Instance.new("Part")
    g.Name = _id(10)
    g.Size = Vector3.new(2, 2, 1)
    g.Transparency = 1
    g.CanCollide = true
    g.CanQuery = false
    g.CanTouch = false
    g.Anchored = false
    g.Massless = false
    g.CFrame = _preRagCF
    g.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
    g.CollisionGroup = "Default"
    g.Parent = workspace

    _ghostPart = g

    -- BodyVelocity — горизонтальное движение
    local bv = Instance.new("BodyVelocity")
    bv.Name = _id(5)
    bv.MaxForce = Vector3.new(15000, 0, 15000)
    bv.Velocity = Vector3.zero
    bv.P = 2000
    bv.Parent = g
    _bMovers.bv = bv

    -- BodyGyro — поворот
    local bg = Instance.new("BodyGyro")
    bg.Name = _id(5)
    bg.MaxTorque = Vector3.new(0, 15000, 0)
    bg.P = 4000
    bg.D = 150
    bg.Parent = g
    _bMovers.bg = bg

    -- Anti-gravity (частичная — чтобы не проваливался, но и не летал)
    local bf = Instance.new("BodyForce")
    bf.Name = _id(5)
    bf.Force = Vector3.new(0, g:GetMass() * workspace.Gravity * 0.2, 0)
    bf.Parent = g
    _bMovers.bf = bf

    _ghostActive = true
end

-- Управление призраком (каждый кадр)
local function _ctrlGhost()
    if not _ghostActive then return end
    if not(_ghostPart and _ghostPart.Parent) then
        _ghostActive = false
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    -- Ввод
    local md = Vector3.zero
    local cf = cam.CFrame
    local fwd = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
    if fwd.Magnitude > 0.001 then fwd = fwd.Unit end
    local rgt = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
    if rgt.Magnitude > 0.001 then rgt = rgt.Unit end

    local keys = {
        [Enum.KeyCode.W] = fwd,
        [Enum.KeyCode.S] = -fwd,
        [Enum.KeyCode.D] = rgt,
        [Enum.KeyCode.A] = -rgt,
    }
    for key, dir in pairs(keys) do
        if _UIS:IsKeyDown(key) then md = md + dir end
    end

    local spd = 16
    if _hu then pcall(function() spd = _hu.WalkSpeed end) end

    if md.Magnitude > 0.01 then
        md = md.Unit * spd
        if _bMovers.bg then
            pcall(function()
                _bMovers.bg.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(md.X, 0, md.Z))
            end)
        end
    end

    if _bMovers.bv then
        _bMovers.bv.Velocity = Vector3.new(md.X, 0, md.Z)
    end

    -- КЛЮЧЕВОЕ: камера на призрака
    pcall(function()
        cam.CameraSubject = _ghostPart
    end)

    -- КЛЮЧЕВОЕ v5: ПОСТОЯННО двигаем HumanoidRootPart к призраку
    -- Это гарантирует что при выходе из рагдолла тело БУДЕТ у призрака
    if _rt and _rt.Parent then
        pcall(function()
            _rt.CFrame = _ghostPart.CFrame
            _rt.AssemblyLinearVelocity = _ghostPart.AssemblyLinearVelocity
            _rt.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    _ghostCF = _ghostPart.CFrame
end

-- Уничтожение призрака
local function _killGhost()
    -- Финальная синхронизация позиции
    if _ghostPart and _ghostPart.Parent and _rt and _rt.Parent then
        pcall(function()
            _rt.CFrame = _ghostPart.CFrame
            _rt.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            _rt.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    for _,v in pairs(_bMovers) do pcall(function() v:Destroy() end) end
    _bMovers = {}

    if _ghostPart then
        pcall(function() _ghostPart:Destroy() end)
        _ghostPart = nil
    end

    pcall(function()
        if _hu then workspace.CurrentCamera.CameraSubject = _hu end
    end)

    _ghostActive = false
end

-- Полный выход из рагдолла
local function _fullExit()
    if _exitingRag then return end
    _exitingRag = true

    if not(_hu and _ch and _rt) then
        _exitingRag = false
        _killGhost()
        _ragActive = false
        return
    end
    if _hu.Health <= 0 then
        _exitingRag = false
        _killGhost()
        _ragActive = false
        return
    end

    -- Фаза 1: финальная позиция от призрака
    local finalCF = _ghostCF or (_ghostPart and _ghostPart.Parent and _ghostPart.CFrame) or _preRagCF
    _killGhost()

    -- Фаза 2: PlatformStand off
    _w(function() _hu.PlatformStand = false end)()

    -- Фаза 3: констрейнты
    _nukeConstraints()

    -- Фаза 4: моторы
    _restoreMotors()

    -- Фаза 5: разморозка
    for _,v in ipairs(_ch:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
                v.Anchored = false
                v.AssemblyLinearVelocity = Vector3.zero
                v.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    -- Фаза 6: позиция
    if finalCF and _rt and _rt.Parent then
        pcall(function()
            _rt.CFrame = finalCF
            _rt.AssemblyLinearVelocity = Vector3.zero
        end)
    end

    -- Фаза 7: состояние
    _w(function() _hu:ChangeState(Enum.HumanoidStateType.GettingUp) end)()

    -- Фаза 8: подстраховка через 50мс
    task.delay(0.05 + _dly(), function()
        if not _C._ar then _exitingRag=false _ragActive=false return end
        pcall(function()
            if _hu and _hu.Health > 0 then
                _hu.PlatformStand = false
                _nukeConstraints()
                _restoreMotors()
                if finalCF and _rt and _rt.Parent then
                    _rt.CFrame = finalCF
                end
                _hu:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end)

    -- Фаза 9: финальная страховка через 150мс
    task.delay(0.15 + _dly(), function()
        if not _C._ar then _exitingRag=false _ragActive=false return end
        pcall(function()
            if _hu and _hu.Health > 0 then
                _hu.PlatformStand = false
                local st = _hu:GetState()
                if _isRag(st) or st == Enum.HumanoidStateType.PlatformStanding then
                    _nukeConstraints()
                    _restoreMotors()
                    if finalCF and _rt and _rt.Parent then
                        _rt.CFrame = finalCF
                    end
                    _hu:ChangeState(Enum.HumanoidStateType.GettingUp)
                    task.delay(0.06, function()
                        pcall(function()
                            _hu:ChangeState(Enum.HumanoidStateType.Running)
                        end)
                    end)
                end
                -- Гарантируем камеру
                if not _ghostActive then
                    workspace.CurrentCamera.CameraSubject = _hu
                end
            end
        end)
        _exitingRag = false
        _ragActive = false
    end)

    -- Фаза 10: абсолютная страховка через 400мс
    task.delay(0.4 + _dly(), function()
        pcall(function()
            if _hu and _hu.Health > 0 and not _ghostActive then
                _hu.PlatformStand = false
                workspace.CurrentCamera.CameraSubject = _hu
                if finalCF and _rt and _rt.Parent then
                    local dist = (_rt.Position - finalCF.Position).Magnitude
                    if dist > 5 then
                        _rt.CFrame = finalCF
                    end
                end
            end
        end)
        _exitingRag = false
        _ragActive = false
    end)
end

-- Обнаружение рагдолла
local function _onRagStart()
    if _ragActive then return end
    if _exitingRag then return end
    _ragActive = true
    _ragStartTime = tick()

    -- Небольшая задержка перед призраком чтобы рагдолл успел активироваться
    task.delay(0.02 + _dly(), function()
        if not _C._ar then _ragActive=false return end
        if not _ragActive then return end
        _spawnGhost()
    end)
end

-- Проверка конца рагдолла (heartbeat)
local function _checkRagEnd()
    if not _ragActive then return end
    if _exitingRag then return end
    if not(_hu and _ch) then return end

    -- Таймаут
    if tick() - _ragStartTime > _ragTimeout then
        _fullExit()
        return
    end

    local st = _hu:GetState()
    local ps = false
    pcall(function() ps = _hu.PlatformStand end)

    -- Рагдолл НЕ активен И PlatformStand выключен → выход
    if not _isRag(st) and st ~= Enum.HumanoidStateType.PlatformStanding and not ps then
        -- Ждём 2 кадра для подтверждения (не ложное срабатывание)
        task.delay(0.03, function()
            if not _ragActive then return end
            if not _hu then return end
            local st2 = _hu:GetState()
            local ps2 = false
            pcall(function() ps2 = _hu.PlatformStand end)
            if not _isRag(st2) and st2 ~= Enum.HumanoidStateType.PlatformStanding and not ps2 then
                _fullExit()
            end
        end)
    end
end

local function _startAR()
    if not(_ch and _hu) then return end
    _snapMotors()

    -- StateChanged
    local c1 = _hu.StateChanged:Connect(function(_,new)
        if not _C._ar then return end
        if _isRag(new) or new==Enum.HumanoidStateType.PlatformStanding then
            task.delay(_dly(), _onRagStart)
        end
    end)
    _rc[#_rc+1] = c1

    -- PlatformStand
    local c2 = _hu:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not _C._ar then return end
        if _hu.PlatformStand and not _ragActive then
            task.delay(_dly(), _onRagStart)
        end
    end)
    _rc[#_rc+1] = c2

    -- DescendantAdded — ловим рагдолл констрейнты
    local c3 = _ch.DescendantAdded:Connect(function(v)
        if not _C._ar then return end
        task.delay(_dly(), function()
            pcall(function()
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("NoCollisionConstraint") then
                    if not _ragActive then _onRagStart() end
                end
            end)
        end)
    end)
    _rc[#_rc+1] = c3

    -- DescendantRemoving — ловим удаление моторов
    local c4 = _ch.DescendantRemoving:Connect(function(v)
        if not _C._ar then return end
        if v:IsA("Motor6D") then
            local data = {
                _n=v.Name, _p=v.Parent,
                _p0=v.Part0, _p1=v.Part1,
                _c0=v.C0, _c1=v.C1,
            }
            local found = false
            for _,s in ipairs(_mSnap) do
                if s._n==data._n and s._p==data._p then
                    s._c0=data._c0 s._c1=data._c1
                    found=true break
                end
            end
            if not found then _mSnap[#_mSnap+1]=data end
            if not _ragActive then _onRagStart() end
        end
    end)
    _rc[#_rc+1] = c4
end

local function _stopAR()
    for _,c in ipairs(_rc) do pcall(function() c:Disconnect() end) end
    _rc = {}
    _killGhost()
    _ragActive = false
    _exitingRag = false
    for _,m in ipairs(_fM) do pcall(function() if m and m.Parent then m:Destroy() end end) end
    _fM = {}
    _mSnap = {}
end

-- ===================== NO ANIMATIONS =====================
local function _hkT(t)
    if not t or _tt[t] then return end
    _tt[t]=true
    local c = t:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if not _C._na then return end
        if t.IsPlaying then
            task.delay(_dly(),function()
                pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0,0) end)
            end)
        end
    end)
    _ac[#_ac+1]=c
    if _C._na and t.IsPlaying then
        pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0,0) end)
    end
end

local function _supT()
    if not _an then return end
    pcall(function()
        for _,t in ipairs(_an:GetPlayingAnimationTracks()) do
            pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0,0) end)
        end
    end)
end

local function _hkA()
    if not _an then return end
    pcall(function()
        local c = _an.AnimationPlayed:Connect(function(t)
            _hkT(t)
            if _C._na then
                task.delay(_dly(),function()
                    pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0,0) end)
                end)
            end
        end)
        _ac[#_ac+1]=c
    end)
    if _hu then
        for _,e in ipairs({"Running","Jumping","Climbing","Swimming","FreeFalling"}) do
            pcall(function()
                local c = _hu[e]:Connect(function()
                    if _C._na then task.defer(_supT) end
                end)
                _ac[#_ac+1]=c
            end)
        end
        local c = _hu.StateChanged:Connect(function()
            if _C._na then task.defer(_supT) end
        end)
        _ac[#_ac+1]=c
    end
    pcall(function()
        for _,t in ipairs(_an:GetPlayingAnimationTracks()) do _hkT(t) end
    end)
end
local function _startNA() _hkA() end
local function _stopNA()
    for _,c in ipairs(_ac) do pcall(function() c:Disconnect() end) end
    _ac = {}
    for t in pairs(_tt) do
        pcall(function() if t and t.IsPlaying then t:AdjustSpeed(1) t:AdjustWeight(1,0.1) end end)
    end
    _tt = {}
end

-- ===================== HEARTBEAT =====================
_fc = 0
_hbc = _RS.Heartbeat:Connect(function(dt)
    _fc = _fc + 1
    if not(_ch and _ch.Parent) then _ref() return end
    if not(_hu and _hu.Health>0) then return end

    -- Ghost control КАЖДЫЙ кадр (для плавности)
    if _C._ar and _ghostActive then
        _ctrlGhost()
    end

    -- Ragdoll check каждые 2 кадра
    if _C._ar and _fc%2==0 then
        _checkRagEnd()

        -- Fallback: если ragActive но призрак мёртв
        if _ragActive and not(_ghostPart and _ghostPart.Parent) then
            _ghostActive = false
            -- Попробовать пересоздать
            if _hu.PlatformStand or _isRag(_hu:GetState()) then
                _spawnGhost()
            else
                _ragActive = false
            end
        end
    end

    -- NoAnim каждые 3 кадра
    if _C._na and _fc%3==0 then
        _supT()
    end
end)

-- ===================== РЕСПАВН =====================
_lp.CharacterAdded:Connect(function()
    task.wait(_rn(0.3,0.5))
    _killGhost()
    _ragActive = false
    _exitingRag = false
    _ref()
    task.wait(_rn(0.15,0.25))
    if _C._ar then _stopAR() _startAR() end
    if _C._na then _stopNA() task.wait(0.12) _startNA() end
end)

-- ===================== GUI v13.0 — ПОЛНЫЙ РЕДИЗАЙН =====================
local _gn = _id(16)
for _,g in ipairs(_pg:GetChildren()) do
    if g:IsA("ScreenGui") then
        pcall(function()
            if g.Name == "GranzHubGUI" or string.len(g.Name) > 10 then
                -- Не удаляем чужие GUI, только свои
            end
        end)
    end
end

local SG = Instance.new("ScreenGui")
SG.Name = _gn
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = _rin(1,10)
SG.Parent = _pg

-- ============ ПАЛИТРА v13 ============
local K = {
    -- Основные
    bg      = Color3.fromRGB(6, 6, 12),
    bg2     = Color3.fromRGB(12, 12, 20),
    panel   = Color3.fromRGB(16, 16, 26),
    panelH  = Color3.fromRGB(22, 22, 34),
    hdr     = Color3.fromRGB(10, 10, 18),
    
    -- Акценты
    a1 = Color3.fromRGB(140, 80, 255),   -- Фиолетовый
    a2 = Color3.fromRGB(50, 190, 255),    -- Голубой  
    a3 = Color3.fromRGB(255, 75, 75),     -- Красный
    a4 = Color3.fromRGB(255, 190, 45),    -- Золотой
    a5 = Color3.fromRGB(65, 255, 150),    -- Зелёный
    a6 = Color3.fromRGB(255, 120, 200),   -- Розовый
    
    -- Текст
    tw = Color3.fromRGB(230, 230, 240),
    td = Color3.fromRGB(80, 80, 100),
    tg = Color3.fromRGB(70, 255, 130),
    
    -- UI
    tOff  = Color3.fromRGB(30, 30, 45),
    tKOff = Color3.fromRGB(110, 110, 130),
    brd   = Color3.fromRGB(35, 35, 55),
}

-- Утилиты GUI
local function mkC(p,r) local c=Instance.new("UICorner",p) c.CornerRadius=UDim.new(0,r or 12) return c end
local function mkS(p,col,th,tr)
    local s=Instance.new("UIStroke") s.Color=col or K.brd s.Thickness=th or 1 s.Transparency=tr or 0.5 s.Parent=p return s
end
local function ti(d,s,dir) return TweenInfo.new(d or 0.3, s or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out) end

-- ============ MAIN FRAME ============
local MF = Instance.new("Frame")
MF.Name = _id(5)
MF.Size = UDim2.new(0,370,0,500)
MF.Position = UDim2.new(0.5,-185,0.5,-250)
MF.BackgroundColor3 = K.bg
MF.BackgroundTransparency = 0.01
MF.BorderSizePixel = 0
MF.Active = true
MF.Draggable = true
MF.ClipsDescendants = true
MF.Parent = SG
mkC(MF, 24)

local MFS = mkS(MF, K.a1, 1.5, 0.5)

-- Многослойная тень
for i = 1, 3 do
    local sh = Instance.new("ImageLabel")
    sh.Name = _id(2)
    sh.Size = UDim2.new(1, 20+i*15, 1, 20+i*15)
    sh.Position = UDim2.new(0, -10-i*7.5, 0, -10-i*7.5)
    sh.BackgroundTransparency = 1
    sh.Image = "rbxassetid://6015897843"
    sh.ImageColor3 = Color3.new(0,0,0)
    sh.ImageTransparency = 0.5 + i*0.12
    sh.ScaleType = Enum.ScaleType.Slice
    sh.SliceCenter = Rect.new(49,49,450,450)
    sh.ZIndex = -i
    sh.Parent = MF
end

-- Декоративные glow сферы (v13 — больше и красивее)
local glows = {}
local glowData = {
    {UDim2.new(0,-50,0,-50), K.a1, 180, 0.93},
    {UDim2.new(1,-80,1,-100), K.a2, 160, 0.94},
    {UDim2.new(0.25,0,0.3,0), K.a3, 100, 0.96},
    {UDim2.new(0.7,-20,0.15,0), K.a5, 90, 0.96},
    {UDim2.new(0.5,-40,0.7,0), K.a6, 120, 0.95},
}
for i, gd in ipairs(glowData) do
    local g = Instance.new("Frame")
    g.Name = _id(2)
    g.Size = UDim2.new(0, gd[3], 0, gd[3])
    g.Position = gd[1]
    g.BackgroundColor3 = gd[2]
    g.BackgroundTransparency = gd[4]
    g.BorderSizePixel = 0
    g.ZIndex = 0
    g.Parent = MF
    mkC(g, gd[3])
    glows[i] = g
end

-- Сетка точек (тоньше и красивее)
for row = 0, 10 do
    for col = 0, 7 do
        local dot = Instance.new("Frame")
        dot.Name = _id(1)
        dot.Size = UDim2.new(0, 1.5, 0, 1.5)
        dot.Position = UDim2.new(0, 15+col*46, 0, 65+row*42)
        dot.BackgroundColor3 = K.tw
        dot.BackgroundTransparency = 0.95
        dot.BorderSizePixel = 0
        dot.ZIndex = 0
        dot.Parent = MF
        mkC(dot, 2)
    end
end

-- ============ HEADER v13 ============
local HD = Instance.new("Frame")
HD.Name = _id(3)
HD.Size = UDim2.new(1,0,0,64)
HD.BackgroundColor3 = K.hdr
HD.BackgroundTransparency = 0.1
HD.BorderSizePixel = 0
HD.ZIndex = 5
HD.Parent = MF
mkC(HD, 24)

-- Bottom fix
local HDF = Instance.new("Frame")
HDF.Size = UDim2.new(1,0,0,24)
HDF.Position = UDim2.new(0,0,1,-24)
HDF.BackgroundColor3 = K.hdr
HDF.BackgroundTransparency = 0.1
HDF.BorderSizePixel = 0
HDF.ZIndex = 5
HDF.Parent = HD

-- Двойная градиентная линия
for i = 1, 2 do
    local hl = Instance.new("Frame")
    hl.Name = _id(2)
    hl.Size = UDim2.new(i==1 and 0.9 or 0.6, 0, 0, i==1 and 2.5 or 1.5)
    hl.Position = UDim2.new(i==1 and 0.05 or 0.2, 0, 1, i==1 and 0 or 4)
    hl.BackgroundColor3 = K.tw
    hl.BackgroundTransparency = i==1 and 0.25 or 0.6
    hl.BorderSizePixel = 0
    hl.ZIndex = 6
    hl.Parent = HD
    mkC(hl, 3)
    
    local hlg = Instance.new("UIGradient")
    hlg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, K.a1),
        ColorSequenceKeypoint.new(0.2, K.a2),
        ColorSequenceKeypoint.new(0.4, K.a5),
        ColorSequenceKeypoint.new(0.6, K.a4),
        ColorSequenceKeypoint.new(0.8, K.a6),
        ColorSequenceKeypoint.new(1, K.a3),
    }
    hlg.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(0.2, 0),
        NumberSequenceKeypoint.new(0.8, 0),
        NumberSequenceKeypoint.new(1, 0.7),
    }
    hlg.Parent = hl
    
    if i == 1 then
        -- Анимация ползущего градиента
        task.spawn(function()
            local off = 0
            while SG and SG.Parent do
                off = (off + 0.002) % 1
                pcall(function()
                    hlg.Offset = Vector2.new(math.sin(off*math.pi*2)*0.5, 0)
                end)
                task.wait(0.025)
            end
        end)
    end
end

-- Лого с анимированной обводкой
local LogoOuter = Instance.new("Frame")
LogoOuter.Name = _id(2)
LogoOuter.Size = UDim2.new(0,40,0,40)
LogoOuter.Position = UDim2.new(0,14,0.5,-20)
LogoOuter.BackgroundColor3 = K.a1
LogoOuter.BackgroundTransparency = 0.85
LogoOuter.BorderSizePixel = 0
LogoOuter.ZIndex = 6
LogoOuter.Parent = HD
mkC(LogoOuter, 12)
local LogoS = mkS(LogoOuter, K.a1, 1.5, 0.3)

-- Внутренний круг лого
local LogoInner = Instance.new("Frame")
LogoInner.Name = _id(2)
LogoInner.Size = UDim2.new(0,30,0,30)
LogoInner.Position = UDim2.new(0.5,-15,0.5,-15)
LogoInner.BackgroundColor3 = K.a1
LogoInner.BackgroundTransparency = 0.7
LogoInner.BorderSizePixel = 0
LogoInner.ZIndex = 7
LogoInner.Parent = LogoOuter
mkC(LogoInner, 15)

local LogoTxt = Instance.new("TextLabel")
LogoTxt.Size = UDim2.new(1,0,1,0)
LogoTxt.BackgroundTransparency = 1
LogoTxt.Text = "G"
LogoTxt.TextColor3 = K.tw
LogoTxt.TextSize = 16
LogoTxt.Font = Enum.Font.GothamBlack
LogoTxt.ZIndex = 8
LogoTxt.Parent = LogoInner

-- Title
local TitleLbl = Instance.new("TextLabel")
TitleLbl.Name = _id(2)
TitleLbl.Size = UDim2.new(0,130,0,22)
TitleLbl.Position = UDim2.new(0,62,0,10)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "GRANZ HUB"
TitleLbl.TextColor3 = K.tw
TitleLbl.TextSize = 17
TitleLbl.Font = Enum.Font.GothamBlack
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.ZIndex = 6
TitleLbl.Parent = HD

-- Subtitle с gradient
local SubLbl = Instance.new("TextLabel")
SubLbl.Name = _id(2)
SubLbl.Size = UDim2.new(0,200,0,14)
SubLbl.Position = UDim2.new(0,62,0,34)
SubLbl.BackgroundTransparency = 1
SubLbl.Text = "phantom wraith · v13.0 · 2026"
SubLbl.TextColor3 = K.td
SubLbl.TextSize = 10
SubLbl.Font = Enum.Font.GothamMedium
SubLbl.TextXAlignment = Enum.TextXAlignment.Left
SubLbl.ZIndex = 6
SubLbl.Parent = HD

-- Бейджи
local badges = {
    {text="WRAITH", col=K.a1, x=62},
    {text="GHOST", col=K.a5, x=120},
    {text="SAB", col=K.a2, x=166},
}
for _, bd in ipairs(badges) do
    local bf = Instance.new("Frame")
    bf.Size = UDim2.new(0, #bd.text*5.2+14, 0, 16)
    bf.Position = UDim2.new(0, bd.x, 0, 50)
    bf.BackgroundColor3 = bd.col
    bf.BackgroundTransparency = 0.88
    bf.BorderSizePixel = 0
    bf.ZIndex = 6
    bf.Parent = HD
    mkC(bf, 4)
    mkS(bf, bd.col, 0.5, 0.5)
    
    local bl = Instance.new("TextLabel")
    bl.Size = UDim2.new(1,0,1,0)
    bl.BackgroundTransparency = 1
    bl.Text = bd.text
    bl.TextColor3 = bd.col
    bl.TextSize = 7
    bl.Font = Enum.Font.GothamBlack
    bl.ZIndex = 7
    bl.Parent = bf
end

-- Header кнопки
local function mkHBtn(pos, txt, bgC)
    local b = Instance.new("TextButton")
    b.Name = _id(2)
    b.Size = UDim2.new(0,36,0,36)
    b.Position = pos
    b.BackgroundColor3 = bgC
    b.BackgroundTransparency = 0.35
    b.Text = txt
    b.TextColor3 = K.tw
    b.TextSize = 15
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.ZIndex = 6
    b.Parent = HD
    mkC(b, 11)
    
    -- Hover с масштабированием
    b.MouseEnter:Connect(function()
        _TS:Create(b, ti(0.2), {
            BackgroundTransparency = 0.1,
        }):Play()
    end)
    b.MouseLeave:Connect(function()
        _TS:Create(b, ti(0.2), {
            BackgroundTransparency = 0.35,
        }):Play()
    end)
    return b
end

local MinB = mkHBtn(UDim2.new(1,-86,0,14), "━", Color3.fromRGB(45,45,60))
local ClsB = mkHBtn(UDim2.new(1,-46,0,14), "✕", Color3.fromRGB(170,35,35))

-- ============ КОНТЕНТ ============
local CT = Instance.new("ScrollingFrame")
CT.Name = _id(3)
CT.Size = UDim2.new(1,-18,1,-80)
CT.Position = UDim2.new(0,9,0,72)
CT.BackgroundTransparency = 1
CT.BorderSizePixel = 0
CT.ScrollBarThickness = 2
CT.ScrollBarImageColor3 = K.a1
CT.ScrollBarImageTransparency = 0.6
CT.CanvasSize = UDim2.new(0,0,0,0)
CT.AutomaticCanvasSize = Enum.AutomaticSize.Y
CT.ZIndex = 3
CT.Parent = MF

local CTL = Instance.new("UIListLayout", CT)
CTL.SortOrder = Enum.SortOrder.LayoutOrder
CTL.Padding = UDim.new(0, 7)

local CTP = Instance.new("UIPadding", CT)
CTP.PaddingTop = UDim.new(0, 3)
CTP.PaddingBottom = UDim.new(0, 12)

-- ============ МОДУЛИ v13 ============
local function createMod(icon, name, desc, order, acCol, tags)
    local Mod = Instance.new("Frame")
    Mod.Name = _id(4)
    Mod.Size = UDim2.new(1,0,0,90)
    Mod.BackgroundColor3 = K.panel
    Mod.BackgroundTransparency = 0.12
    Mod.BorderSizePixel = 0
    Mod.LayoutOrder = order
    Mod.ZIndex = 3
    Mod.ClipsDescendants = true
    Mod.Parent = CT
    mkC(Mod, 16)

    local MS = mkS(Mod, K.brd, 1, 0.6)

    -- Градиентная полоска слева
    local LB = Instance.new("Frame")
    LB.Size = UDim2.new(0, 3.5, 0.55, 0)
    LB.Position = UDim2.new(0, 0, 0.225, 0)
    LB.BackgroundColor3 = acCol
    LB.BackgroundTransparency = 0.4
    LB.BorderSizePixel = 0
    LB.ZIndex = 4
    LB.Parent = Mod
    mkC(LB, 2)
    
    -- Градиент на полоске
    local LBG = Instance.new("UIGradient", LB)
    LBG.Rotation = 90
    LBG.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 0.5),
    }

    -- Иконка с двойным фоном
    local IcOuter = Instance.new("Frame")
    IcOuter.Size = UDim2.new(0, 46, 0, 46)
    IcOuter.Position = UDim2.new(0, 14, 0, 12)
    IcOuter.BackgroundColor3 = acCol
    IcOuter.BackgroundTransparency = 0.9
    IcOuter.BorderSizePixel = 0
    IcOuter.ZIndex = 4
    IcOuter.Parent = Mod
    mkC(IcOuter, 14)

    local IcInner = Instance.new("Frame")
    IcInner.Size = UDim2.new(0, 34, 0, 34)
    IcInner.Position = UDim2.new(0.5, -17, 0.5, -17)
    IcInner.BackgroundColor3 = acCol
    IcInner.BackgroundTransparency = 0.8
    IcInner.BorderSizePixel = 0
    IcInner.ZIndex = 5
    IcInner.Parent = IcOuter
    mkC(IcInner, 10)

    local IcLbl = Instance.new("TextLabel")
    IcLbl.Size = UDim2.new(1,0,1,0)
    IcLbl.BackgroundTransparency = 1
    IcLbl.Text = icon
    IcLbl.TextSize = 18
    IcLbl.Font = Enum.Font.GothamBold
    IcLbl.ZIndex = 6
    IcLbl.Parent = IcInner

    -- Название
    local NL = Instance.new("TextLabel")
    NL.Size = UDim2.new(1,-140,0,20)
    NL.Position = UDim2.new(0,70,0,12)
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
    DL.Size = UDim2.new(1,-140,0,14)
    DL.Position = UDim2.new(0,70,0,34)
    DL.BackgroundTransparency = 1
    DL.Text = desc
    DL.TextColor3 = K.td
    DL.TextSize = 10
    DL.Font = Enum.Font.Gotham
    DL.TextXAlignment = Enum.TextXAlignment.Left
    DL.ZIndex = 4
    DL.Parent = Mod

    -- Теги
    if tags then
        local tx = 70
        for _, tg in ipairs(tags) do
            local tf = Instance.new("Frame")
            tf.Size = UDim2.new(0, #tg*5+14, 0, 16)
            tf.Position = UDim2.new(0, tx, 0, 54)
            tf.BackgroundColor3 = acCol
            tf.BackgroundTransparency = 0.9
            tf.BorderSizePixel = 0
            tf.ZIndex = 4
            tf.Parent = Mod
            mkC(tf, 4)
            
            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.new(1,0,1,0)
            tl.BackgroundTransparency = 1
            tl.Text = tg
            tl.TextColor3 = acCol
            tl.TextSize = 8
            tl.Font = Enum.Font.GothamBold
            tl.ZIndex = 5
            tl.Parent = tf
            
            tx = tx + #tg*5 + 18
        end
    end

    -- Bottom accent line
    local BLine = Instance.new("Frame")
    BLine.Size = UDim2.new(0, 0, 0, 1.5)
    BLine.Position = UDim2.new(0.5, 0, 1, -2)
    BLine.AnchorPoint = Vector2.new(0.5, 0)
    BLine.BackgroundColor3 = acCol
    BLine.BackgroundTransparency = 0.6
    BLine.BorderSizePixel = 0
    BLine.ZIndex = 4
    BLine.Parent = Mod
    mkC(BLine, 1)

    -- Toggle v13 — pill-style с glow
    local TBG = Instance.new("TextButton")
    TBG.Name = _id(2)
    TBG.Size = UDim2.new(0, 52, 0, 28)
    TBG.Position = UDim2.new(1, -64, 0.5, -14)
    TBG.BackgroundColor3 = K.tOff
    TBG.Text = ""
    TBG.BorderSizePixel = 0
    TBG.AutoButtonColor = false
    TBG.ZIndex = 4
    TBG.Parent = Mod
    mkC(TBG, 14)
    local TBGS = mkS(TBG, K.brd, 0.5, 0.5)

    local TK = Instance.new("Frame")
    TK.Size = UDim2.new(0, 22, 0, 22)
    TK.Position = UDim2.new(0, 3, 0.5, -11)
    TK.BackgroundColor3 = K.tKOff
    TK.BorderSizePixel = 0
    TK.ZIndex = 5
    TK.Parent = TBG
    mkC(TK, 11)
    local TKS = mkS(TK, acCol, 0, 0.7)

    -- Статус
    local SD = Instance.new("Frame")
    SD.Size = UDim2.new(0, 8, 0, 8)
    SD.Position = UDim2.new(1, -18, 0, 8)
    SD.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    SD.BorderSizePixel = 0
    SD.ZIndex = 5
    SD.Parent = Mod
    mkC(SD, 4)

    -- Hover interaction
    local hov = Instance.new("TextButton")
    hov.Size = UDim2.new(1,0,1,0)
    hov.BackgroundTransparency = 1
    hov.Text = ""
    hov.ZIndex = 3
    hov.Parent = Mod

    hov.MouseEnter:Connect(function()
        _TS:Create(Mod, ti(0.25), {BackgroundTransparency = 0.02}):Play()
        _TS:Create(MS, ti(0.25), {Transparency = 0.3}):Play()
        _TS:Create(LB, ti(0.25), {BackgroundTransparency = 0.15, Size = UDim2.new(0, 4.5, 0.65, 0)}):Play()
        _TS:Create(BLine, ti(0.3), {Size = UDim2.new(0.7, 0, 0, 1.5)}):Play()
    end)
    hov.MouseLeave:Connect(function()
        _TS:Create(Mod, ti(0.25), {BackgroundTransparency = 0.12}):Play()
        _TS:Create(MS, ti(0.25), {Transparency = 0.6}):Play()
        _TS:Create(LB, ti(0.25), {BackgroundTransparency = 0.4, Size = UDim2.new(0, 3.5, 0.55, 0)}):Play()
        _TS:Create(BLine, ti(0.3), {Size = UDim2.new(0, 0, 0, 1.5)}):Play()
    end)

    local function updV(state)
        local t = ti(0.35)
        if state then
            _TS:Create(TBG, t, {BackgroundColor3 = acCol}):Play()
            _TS:Create(TBGS, t, {Color = acCol, Transparency = 0.2}):Play()
            _TS:Create(TK, t, {
                Position = UDim2.new(1, -25, 0.5, -11),
                BackgroundColor3 = Color3.fromRGB(255,255,255)
            }):Play()
            _TS:Create(TKS, t, {Thickness = 3, Transparency = 0.15}):Play()
            _TS:Create(MS, t, {Color = acCol, Transparency = 0.3}):Play()
            _TS:Create(IcOuter, t, {BackgroundTransparency = 0.75}):Play()
            _TS:Create(IcInner, t, {BackgroundTransparency = 0.65}):Play()
            _TS:Create(LB, t, {BackgroundTransparency = 0.1}):Play()
            _TS:Create(SD, t, {BackgroundColor3 = K.tg}):Play()
            -- Ripple pulse
            _TS:Create(TBG, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
                Size = UDim2.new(0, 56, 0, 32)
            }):Play()
            -- Bottom line flash
            _TS:Create(BLine, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                Size = UDim2.new(0.85, 0, 0, 2),
                BackgroundTransparency = 0.3
            }):Play()
            task.delay(0.6, function()
                if state then
                    pcall(function()
                        _TS:Create(BLine, ti(0.5), {Size = UDim2.new(0.3, 0, 0, 1.5), BackgroundTransparency = 0.6}):Play()
                    end)
                end
            end)
        else
            _TS:Create(TBG, t, {BackgroundColor3 = K.tOff}):Play()
            _TS:Create(TBGS, t, {Color = K.brd, Transparency = 0.5}):Play()
            _TS:Create(TK, t, {
                Position = UDim2.new(0, 3, 0.5, -11),
                BackgroundColor3 = K.tKOff
            }):Play()
            _TS:Create(TKS, t, {Thickness = 0, Transparency = 0.8}):Play()
            _TS:Create(MS, t, {Color = K.brd, Transparency = 0.6}):Play()
            _TS:Create(IcOuter, t, {BackgroundTransparency = 0.9}):Play()
            _TS:Create(IcInner, t, {BackgroundTransparency = 0.8}):Play()
            _TS:Create(LB, t, {BackgroundTransparency = 0.4}):Play()
            _TS:Create(SD, t, {BackgroundColor3 = Color3.fromRGB(40, 40, 55)}):Play()
            _TS:Create(BLine, ti(0.3), {Size = UDim2.new(0, 0, 0, 1.5), BackgroundTransparency = 0.6}):Play()
        end
    end

    return TBG, updV
end

-- Создание модулей
local JT, JV = createMod("⚡", "Infinite Jump", "Многократные прыжки в воздухе", 1, K.a1, {"AIR","MULTI","v3"})
local RT, RV = createMod("👻", "Ghost Anti-Ragdoll", "Призрак ходит — тело летит", 2, K.a2, {"GHOST","WRAITH","v5"})
local AT, AV = createMod("🎭", "No Animations", "Заморозка всех анимаций", 3, K.a3, {"FREEZE","SILENT"})

-- ============ РАЗДЕЛИТЕЛЬ ============
local Sep = Instance.new("Frame")
Sep.Size = UDim2.new(0.85,0,0,1)
Sep.BackgroundColor3 = K.tw
Sep.BackgroundTransparency = 0.92
Sep.BorderSizePixel = 0
Sep.LayoutOrder = 5
Sep.ZIndex = 3
Sep.Parent = CT
mkC(Sep, 1)
local SG2 = Instance.new("UIGradient", Sep)
SG2.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0,1),
    NumberSequenceKeypoint.new(0.3,0),
    NumberSequenceKeypoint.new(0.7,0),
    NumberSequenceKeypoint.new(1,1),
}

-- ============ СТАТУС-БАР v13 ============
local SB = Instance.new("Frame")
SB.Name = _id(3)
SB.Size = UDim2.new(1,0,0,52)
SB.BackgroundColor3 = K.bg2
SB.BackgroundTransparency = 0.25
SB.BorderSizePixel = 0
SB.LayoutOrder = 10
SB.ZIndex = 3
SB.Parent = CT
mkC(SB, 14)
mkS(SB, K.brd, 0.5, 0.7)

-- Три индикатора с labels
local dots = {}
local dotLabels = {}
local dotCols = {K.a1, K.a2, K.a3}
local dotNames = {"JMP", "RAG", "ANI"}
for i = 1, 3 do
    local dg = Instance.new("Frame")
    dg.Size = UDim2.new(0, 28, 0, 28)
    dg.Position = UDim2.new(0, 10+(i-1)*34, 0, 6)
    dg.BackgroundColor3 = Color3.fromRGB(25,25,38)
    dg.BackgroundTransparency = 0.3
    dg.BorderSizePixel = 0
    dg.ZIndex = 4
    dg.Parent = SB
    mkC(dg, 8)

    local d = Instance.new("Frame")
    d.Size = UDim2.new(0, 10, 0, 10)
    d.Position = UDim2.new(0.5, -5, 0, 4)
    d.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    d.BorderSizePixel = 0
    d.ZIndex = 5
    d.Parent = dg
    mkC(d, 5)
    dots[i] = d

    local dl = Instance.new("TextLabel")
    dl.Size = UDim2.new(1, 0, 0, 10)
    dl.Position = UDim2.new(0, 0, 1, -12)
    dl.BackgroundTransparency = 1
    dl.Text = dotNames[i]
    dl.TextColor3 = K.td
    dl.TextSize = 6
    dl.Font = Enum.Font.GothamBold
    dl.ZIndex = 5
    dl.Parent = dg
    dotLabels[i] = dl
end

-- Status text
local SL = Instance.new("TextLabel")
SL.Size = UDim2.new(1,-120,0,16)
SL.Position = UDim2.new(0,114,0,6)
SL.BackgroundTransparency = 1
SL.Text = "Ready"
SL.TextColor3 = K.td
SL.TextSize = 10
SL.Font = Enum.Font.GothamMedium
SL.TextXAlignment = Enum.TextXAlignment.Left
SL.ZIndex = 4
SL.Parent = SB

-- Ghost indicator
local GI = Instance.new("TextLabel")
GI.Size = UDim2.new(1,-120,0,14)
GI.Position = UDim2.new(0,114,0,24)
GI.BackgroundTransparency = 1
GI.Text = ""
GI.TextColor3 = K.a2
GI.TextSize = 9
GI.Font = Enum.Font.Gotham
GI.TextXAlignment = Enum.TextXAlignment.Left
GI.ZIndex = 4
GI.Parent = SB

-- Ping indicator (fake but cool)
local PI = Instance.new("TextLabel")
PI.Size = UDim2.new(0, 60, 0, 12)
PI.Position = UDim2.new(1, -70, 0, 36)
PI.BackgroundTransparency = 1
PI.Text = "●  " .. _rin(12,45) .. "ms"
PI.TextColor3 = K.tg
PI.TextSize = 8
PI.Font = Enum.Font.GothamMedium
PI.TextXAlignment = Enum.TextXAlignment.Right
PI.ZIndex = 4
PI.Parent = SB

local function updateStat()
    local cnt = 0
    local sts = {_C._j, _C._ar, _C._na}
    for i, s in ipairs(sts) do
        local t = ti(0.3)
        if s then
            cnt += 1
            _TS:Create(dots[i], t, {BackgroundColor3 = dotCols[i]}):Play()
            _TS:Create(dotLabels[i], t, {TextColor3 = dotCols[i]}):Play()
        else
            _TS:Create(dots[i], t, {BackgroundColor3 = Color3.fromRGB(35,35,50)}):Play()
            _TS:Create(dotLabels[i], t, {TextColor3 = K.td}):Play()
        end
    end
    if cnt == 0 then
        SL.Text = "Модули неактивны"
        _TS:Create(SL, ti(0.3), {TextColor3 = K.td}):Play()
    else
        SL.Text = cnt.."/3 активно · WRAITH"
        _TS:Create(SL, ti(0.3), {TextColor3 = K.tg}):Play()
    end
end

-- Ghost status updater
task.spawn(function()
    while SG and SG.Parent do
        if _ghostActive then
            local elapsed = math.floor(tick() - _ragStartTime)
            GI.Text = "👻 GHOST · "..elapsed.."s · moving freely"
            GI.TextColor3 = Color3.fromHSV((tick()*0.3)%1, 0.5, 1)
        else
            GI.Text = ""
        end
        -- Update fake ping
        pcall(function()
            PI.Text = "●  ".._rin(10,50).."ms"
        end)
        task.wait(0.15)
    end
end)

-- ============ ОБРАБОТЧИКИ ============
JT.MouseButton1Click:Connect(function()
    _C._j = not _C._j
    JV(_C._j)
    if _C._j then _ref() end
    updateStat()
end)

RT.MouseButton1Click:Connect(function()
    _C._ar = not _C._ar
    RV(_C._ar)
    if _C._ar then _ref() _startAR()
    else _stopAR() end
    updateStat()
end)

AT.MouseButton1Click:Connect(function()
    _C._na = not _C._na
    AV(_C._na)
    if _C._na then _ref() _startNA()
    else _stopNA() end
    updateStat()
end)

-- ============ MINIMIZE / CLOSE ============
local _fullSz = MF.Size

MinB.MouseButton1Click:Connect(function()
    _minimized = not _minimized
    if _minimized then
        _TS:Create(MF, ti(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 370, 0, 64)
        }):Play()
        task.delay(0.05, function() CT.Visible = false end)
        MinB.Text = "◻"
    else
        _TS:Create(MF, ti(0.5, Enum.EasingStyle.Back), {Size = _fullSz}):Play()
        task.delay(0.3, function() CT.Visible = true end)
        MinB.Text = "━"
    end
end)

ClsB.MouseButton1Click:Connect(function()
    _C._j = false
    _C._ar = false
    _C._na = false
    _stopAR()
    _stopNA()
    if _hbc then _hbc:Disconnect() end

    -- Multi-stage close animation
    _TS:Create(MFS, ti(0.2), {Transparency = 1}):Play()
    
    -- Shrink to center
    _TS:Create(MF, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(0.5, -20, 0.5, -20),
        BackgroundTransparency = 0.5
    }):Play()
    
    task.delay(0.3, function()
        _TS:Create(MF, ti(0.2), {BackgroundTransparency = 1}):Play()
    end)
    task.delay(0.55, function() SG:Destroy() end)
end)

-- ============ ЖИВЫЕ АНИМАЦИИ ============

-- 1. Обводка rainbow-переливание
task.spawn(function()
    local h = _rn(0,1)
    while SG and SG.Parent do
        h = (h + 0.001) % 1
        local ac = 0
        if _C._j then ac+=1 end
        if _C._ar then ac+=1 end
        if _C._na then ac+=1 end
        
        if ac > 0 then
            local sat = 0.55 + ac*0.12
            local val = 0.8 + ac*0.06
            local t = tick()
            MFS.Color = Color3.fromHSV(h, sat, val)
            MFS.Transparency = 0.08 + math.sin(t*1.8)*0.06
            MFS.Thickness = 1.5 + math.sin(t*2.5)*0.5
            
            -- Logo stroke follows
            pcall(function()
                LogoS.Color = Color3.fromHSV((h+0.15)%1, sat, val)
                LogoS.Transparency = 0.2 + math.sin(t*2)*0.1
            end)
        else
            MFS.Color = K.brd
            MFS.Transparency = 0.65
            MFS.Thickness = 1
            pcall(function()
                LogoS.Color = K.a1
                LogoS.Transparency = 0.5
            end)
        end
        task.wait(0.02)
    end
end)

-- 2. Glow сферы дрейфуют и дышат
task.spawn(function()
    local basePos = {}
    for i, gd in ipairs(glowData) do
        basePos[i] = {gd[1].X.Offset, gd[1].Y.Offset}
    end
    while SG and SG.Parent do
        local t = tick()
        for i, g in ipairs(glows) do
            pcall(function()
                local bx = basePos[i][1]
                local by = basePos[i][2]
                local ox = math.sin(t*0.3 + i*1.5) * 8
                local oy = math.cos(t*0.4 + i*1.2) * 6
                g.Position = UDim2.new(glowData[i][1].X.Scale, bx+ox, glowData[i][1].Y.Scale, by+oy)
                g.BackgroundTransparency = glowData[i][4] + math.sin(t*(0.8+i*0.2))*0.03
            end)
        end
        task.wait(0.03)
    end
end)

-- 3. Logo breathing
task.spawn(function()
    while SG and SG.Parent do
        local ac = 0
        if _C._j then ac+=1 end
        if _C._ar then ac+=1 end
        if _C._na then ac+=1 end
        
        if ac > 0 then
            _TS:Create(LogoInner, ti(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.6,
                Size = UDim2.new(0, 32, 0, 32),
            }):Play()
            _TS:Create(LogoOuter, ti(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.78,
            }):Play()
            task.wait(1.5)
            if not(SG and SG.Parent) then return end
            _TS:Create(LogoInner, ti(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.75,
                Size = UDim2.new(0, 30, 0, 30),
            }):Play()
            _TS:Create(LogoOuter, ti(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.88,
            }):Play()
            task.wait(1.5)
        else
            task.wait(0.5)
        end
    end
end)

-- 4. Dots pulse
task.spawn(function()
    while SG and SG.Parent do
        local sts = {_C._j, _C._ar, _C._na}
        for i, s in ipairs(sts) do
            if s then
                pcall(function()
                    _TS:Create(dots[i], ti(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        Size = UDim2.new(0, 12, 0, 12),
                        Position = UDim2.new(0.5, -6, 0, 3),
                    }):Play()
                end)
            end
        end
        task.wait(0.7)
        if not(SG and SG.Parent) then return end
        for i, s in ipairs(sts) do
            if s then
                pcall(function()
                    _TS:Create(dots[i], ti(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        Size = UDim2.new(0, 10, 0, 10),
                        Position = UDim2.new(0.5, -5, 0, 4),
                    }):Play()
                end)
            end
        end
        task.wait(0.7)
    end
end)

-- ============ ОТКРЫВАЮЩАЯ АНИМАЦИЯ (МНОГОЭТАПНАЯ) ============
MF.Size = UDim2.new(0, 40, 0, 40)
MF.Position = UDim2.new(0.5, -20, 0.5, -20)
MF.BackgroundTransparency = 1
CT.Visible = false
MFS.Transparency = 1

task.delay(0.05, function()
    -- Step 1: dot appears
    _TS:Create(MF, ti(0.2), {BackgroundTransparency = 0.01}):Play()
    _TS:Create(MFS, ti(0.3), {Transparency = 0.5}):Play()
    task.wait(0.15)
    
    -- Step 2: expand with spring
    _TS:Create(MF, TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0), {
        Size = UDim2.new(0, 370, 0, 500),
        Position = UDim2.new(0.5, -185, 0.5, -250),
    }):Play()
    task.wait(0.4)
    
    -- Step 3: content fades in
    CT.Visible = true
    
    -- Step 4: modules cascade
    local children = {}
    for _, ch in ipairs(CT:GetChildren()) do
        if ch:IsA("Frame") then
            ch.BackgroundTransparency = 1
            children[#children+1] = ch
        end
    end
    
    for i, ch in ipairs(children) do
        task.delay(i * 0.06, function()
            local targetTr = (ch == SB) and 0.25 or 0.12
            -- Slide in from right
            local origPos = ch.Position
            ch.Position = UDim2.new(origPos.X.Scale + 0.1, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset)
            _TS:Create(ch, ti(0.4, Enum.EasingStyle.Quint), {
                BackgroundTransparency = targetTr,
                Position = origPos
            }):Play()
        end)
    end
end)

updateStat()
