--[[
    ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
    █  ENCRYPTED PAYLOAD — RUNTIME ONLY █
    ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
]]

local _Ω = Random.new(
    tick() * os.clock() * math.random(1,9999999)
    + select(2, pcall(function() return game:GetService("Stats"):GetTotalMemoryUsageMb() end)) or 0
)
local function _μ(l)
    l = l or _Ω:NextInteger(14,22)
    local t = {}
    for i = 1, l do
        local r = _Ω:NextInteger(1,5)
        if r <= 2 then t[i] = string.char(_Ω:NextInteger(97,122))
        elseif r <= 4 then t[i] = string.char(_Ω:NextInteger(65,90))
        else t[i] = string.char(_Ω:NextInteger(48,57))
        end
    end
    return table.concat(t)
end
local function _δ() return _Ω:NextNumber(0.002, 0.008) end
local function _ρ(a,b) return _Ω:NextNumber(a,b) end
local function _ι(a,b) return _Ω:NextInteger(a,b) end

local _G_ = setmetatable({}, {
    __index = function(s, k)
        local ok, v = pcall(game.GetService, game, k)
        if ok and v then rawset(s, k, v) end
        return v
    end
})

local _P   = _G_.Players
local _UI  = _G_.UserInputService
local _RS  = _G_.RunService
local _TW  = _G_.TweenService

local _lp  = _P.LocalPlayer
local _pg  = _lp:WaitForChild("PlayerGui")

-- ═══════════ CONFIG ═══════════
local _Σ = {
    j  = false,   -- InfJump
    ar = false,   -- AntiRagdoll
    na = false,   -- NoAnim
    jp = 50,
    cd = 0.12,
    mf = -60,
}

-- ═══════════ STATE ═══════════
local _lastJ    = 0
local _ch, _hu, _rt, _an
local _rc, _ac  = {}, {}
local _hb       = nil
local _trk      = {}
local _mS       = {}
local _fM       = {}

-- Ghost v6
local _gActive  = false
local _gPart    = nil
local _bM       = {}
local _rActive  = false
local _rStart   = 0
local _gCF      = nil
local _exiting  = false
local _rTimeout = 8
local _fc       = 0

local function _sf(o,n) local k,r = pcall(function() return o:FindFirstChild(n) end) return k and r end
local function _sfc(o,c) local k,r = pcall(function() return o:FindFirstChildOfClass(c) end) return k and r end

local function _ref()
    _ch = _lp.Character
    if not _ch then return false end
    _hu = _sfc(_ch, "Humanoid")
    _rt = _sf(_ch, "HumanoidRootPart")
    _an = _hu and _sfc(_hu, "Animator")
    return _hu ~= nil and _rt ~= nil
end
_ref()

-- ═══════════ INFINITE JUMP ═══════════
local function _dJ()
    if not _Σ.j then return end
    local jr = _rt
    if _gActive and _gPart and _gPart.Parent then jr = _gPart end
    if not (jr and jr.Parent) then return end
    if _hu and _hu.Health <= 0 then return end
    local n = tick()
    if n - _lastJ < _Σ.cd then return end
    _lastJ = n
    local cv = jr.AssemblyLinearVelocity
    local ny = _Σ.jp
    if cv.Y < _Σ.mf then ny = _Σ.jp + math.abs(cv.Y) * 0.3 end
    jr.AssemblyLinearVelocity = Vector3.new(
        cv.X * _ρ(0.87, 0.93),
        ny + _ρ(-0.2, 0.2),
        cv.Z * _ρ(0.87, 0.93)
    )
    task.delay(0.04 + _δ(), function()
        if jr and jr.Parent and _Σ.j then
            local v = jr.AssemblyLinearVelocity
            if v.Y < _Σ.jp * 0.75 then
                jr.AssemblyLinearVelocity = Vector3.new(v.X, _Σ.jp * _ρ(0.85, 0.95), v.Z)
            end
        end
    end)
end

_UI.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.Space then
        if not _hu then return end
        if _gActive then _dJ() return end
        if not _rt then return end
        local st = _hu:GetState()
        if st == Enum.HumanoidStateType.Freefall
            or st == Enum.HumanoidStateType.Jumping
            or st == Enum.HumanoidStateType.FallingDown then
            _dJ()
        end
    end
end)

-- ═══════════ GHOST ANTI-RAGDOLL v6.0 ═══════════
--[[
    ╔══════════════════════════════════════════════╗
    ║  КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ v6.0               ║
    ║                                              ║
    ║  ПРИЧИНА СМЕРТИ В v5:                        ║
    ║  Мы каждый кадр принудительно двигали        ║
    ║  HumanoidRootPart к призраку через CFrame.   ║
    ║  Это конфликтовало с серверной физикой:       ║
    ║  - Сервер двигал root в одну сторону          ║
    ║  - Мы двигали в другую                        ║
    ║  - Сервер видел "нелегальное движение"        ║
    ║  - Игра считала это падением/застреванием      ║
    ║  - Результат: смерть                          ║
    ║                                              ║
    ║  РЕШЕНИЕ v6:                                  ║
    ║  ПОЛНОСТЬЮ НЕ ТРОГАТЬ ТЕЛО ВО ВРЕМЯ РАГДОЛЛА ║
    ║                                              ║
    ║  1. Тело летит в рагдолле КАК ОБЫЧНО          ║
    ║  2. Призрак создаётся отдельно                 ║
    ║  3. Камера на призраке                         ║
    ║  4. WASD двигает призрака                      ║
    ║  5. Тело НЕ ТРОГАЕМ вообще                     ║
    ║  6. Когда рагдолл ЗАКАНЧИВАЕТСЯ САМИ (!)       ║
    ║     ТОЛЬКО ТОГДА телепортируем root к ghost    ║
    ║  7. Убираем призрака, камера обратно           ║
    ║                                              ║
    ║  Ключ: ждём ЕСТЕСТВЕННОГО конца рагдолла!     ║
    ╚══════════════════════════════════════════════╝
]]

local _ragS = {
    [Enum.HumanoidStateType.Ragdoll]     = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics]     = true,
}
local function _isR(st) return _ragS[st] == true end

local function _snapM()
    _mS = {}
    if not _ch then return end
    for _, v in ipairs(_ch:GetDescendants()) do
        if v:IsA("Motor6D") then
            _mS[#_mS + 1] = {
                r = v, n = v.Name, p = v.Parent,
                p0 = v.Part0, p1 = v.Part1,
                c0 = v.C0, c1 = v.C1,
            }
        end
    end
end

local function _restM()
    if not _ch then return end
    for _, d in ipairs(_mS) do
        pcall(function()
            if d.r and d.r.Parent then
                d.r.Enabled = true
                return
            end
            if not (d.p and d.p.Parent and d.p0 and d.p0.Parent and d.p1 and d.p1.Parent) then return end
            local ex = d.p:FindFirstChild(d.n)
            if ex and ex:IsA("Motor6D") then ex.Enabled = true d.r = ex return end
            local m = Instance.new("Motor6D")
            m.Name = d.n
            m.Part0 = d.p0
            m.Part1 = d.p1
            m.C0 = d.c0
            m.C1 = d.c1
            m.Parent = d.p
            d.r = m
            _fM[#_fM + 1] = m
        end)
    end
end

local function _nukC()
    if not _ch then return end
    local bad = {
        BallSocketConstraint = true,
        HingeConstraint = true,
        NoCollisionConstraint = true,
        RopeConstraint = true,
        SpringConstraint = true,
        CylindricalConstraint = true,
        PrismaticConstraint = true,
    }
    for _, v in ipairs(_ch:GetDescendants()) do
        pcall(function()
            if bad[v.ClassName] then v:Destroy() end
        end)
    end
end

-- ─── Создание призрака ───
local function _spawnG()
    if _gPart and _gPart.Parent then return end
    if not (_rt and _rt.Parent and _ch) then return end

    local cf = _rt.CFrame

    local g = Instance.new("Part")
    g.Name = _μ(12)
    g.Size = Vector3.new(2, 2, 1)
    g.Transparency = 1
    g.CanCollide = true
    g.CanQuery = false
    g.CanTouch = false
    g.Anchored = false
    g.Massless = false
    g.CFrame = cf
    g.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
    g.Parent = workspace

    _gPart = g
    _gCF = cf

    local bv = Instance.new("BodyVelocity")
    bv.Name = _μ(6)
    bv.MaxForce = Vector3.new(15000, 0, 15000)
    bv.Velocity = Vector3.zero
    bv.P = 2500
    bv.Parent = g
    _bM.bv = bv

    local bg = Instance.new("BodyGyro")
    bg.Name = _μ(6)
    bg.MaxTorque = Vector3.new(0, 15000, 0)
    bg.P = 5000
    bg.D = 200
    bg.Parent = g
    _bM.bg = bg

    local bf = Instance.new("BodyForce")
    bf.Name = _μ(6)
    bf.Force = Vector3.new(0, g:GetMass() * workspace.Gravity * 0.18, 0)
    bf.Parent = g
    _bM.bf = bf

    _gActive = true
end

-- ─── Управление призраком (каждый кадр) ───
local function _ctrlG()
    if not _gActive then return end
    if not (_gPart and _gPart.Parent) then
        _gActive = false
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local md = Vector3.zero
    local cf = cam.CFrame
    local fwd = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
    if fwd.Magnitude > 0.001 then fwd = fwd.Unit end
    local rgt = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
    if rgt.Magnitude > 0.001 then rgt = rgt.Unit end

    if _UI:IsKeyDown(Enum.KeyCode.W) then md = md + fwd end
    if _UI:IsKeyDown(Enum.KeyCode.S) then md = md - fwd end
    if _UI:IsKeyDown(Enum.KeyCode.D) then md = md + rgt end
    if _UI:IsKeyDown(Enum.KeyCode.A) then md = md - rgt end

    local spd = 16
    pcall(function() if _hu then spd = _hu.WalkSpeed end end)

    if md.Magnitude > 0.01 then
        md = md.Unit * spd
        if _bM.bg then
            pcall(function()
                _bM.bg.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(md.X, 0, md.Z))
            end)
        end
    end

    if _bM.bv then
        _bM.bv.Velocity = Vector3.new(md.X, 0, md.Z)
    end

    -- Камера следит за призраком
    pcall(function() cam.CameraSubject = _gPart end)

    -- Запоминаем позицию призрака (НО НЕ ДВИГАЕМ ТЕЛО!)
    _gCF = _gPart.CFrame
end

-- ─── Уничтожение призрака ───
local function _killG(teleport)
    local finalCF = _gCF

    for _, v in pairs(_bM) do pcall(function() v:Destroy() end) end
    _bM = {}

    if _gPart then
        pcall(function() _gPart:Destroy() end)
        _gPart = nil
    end

    -- Восстановить камеру
    pcall(function()
        if _hu then workspace.CurrentCamera.CameraSubject = _hu end
    end)

    _gActive = false

    -- Телепортация ТОЛЬКО если указано
    if teleport and finalCF and _rt and _rt.Parent then
        pcall(function()
            -- Обнуляем velocity ВСЕХ частей ПЕРЕД телепортацией
            for _, v in ipairs(_ch:GetDescendants()) do
                if v:IsA("BasePart") then
                    pcall(function()
                        v.AssemblyLinearVelocity = Vector3.zero
                        v.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
            -- Телепортируем root
            _rt.CFrame = finalCF
            _rt.AssemblyLinearVelocity = Vector3.zero
            _rt.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    return finalCF
end

-- ─── Выход из рагдолла ───
local function _exitR()
    if _exiting then return end
    _exiting = true

    if not (_hu and _ch and _rt) then
        _killG(false)
        _exiting = false
        _rActive = false
        return
    end

    if _hu.Health <= 0 then
        _killG(false)
        _exiting = false
        _rActive = false
        return
    end

    -- Шаг 1: Убить призрака И телепортировать тело к нему
    local finalCF = _killG(true)

    -- Шаг 2: PlatformStand off
    pcall(function() _hu.PlatformStand = false end)

    -- Шаг 3: Убить рагдолл-констрейнты
    _nukC()

    -- Шаг 4: Восстановить моторы
    _restM()

    -- Шаг 5: Разморозить
    for _, v in ipairs(_ch:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function() v.Anchored = false end)
        end
    end

    -- Шаг 6: GettingUp
    pcall(function() _hu:ChangeState(Enum.HumanoidStateType.GettingUp) end)

    -- Шаг 7: Подстраховка 60мс
    task.delay(0.06 + _δ(), function()
        if not _Σ.ar then _exiting = false _rActive = false return end
        pcall(function()
            if _hu and _hu.Health > 0 then
                _hu.PlatformStand = false
                _nukC()
                _restM()
                -- Повторная телепортация если нужно
                if finalCF and _rt and _rt.Parent then
                    local dist = (_rt.Position - finalCF.Position).Magnitude
                    if dist > 3 then
                        _rt.CFrame = finalCF
                        _rt.AssemblyLinearVelocity = Vector3.zero
                    end
                end
                _hu:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end)

    -- Шаг 8: Финальная страховка 200мс
    task.delay(0.2 + _δ(), function()
        if not _Σ.ar then _exiting = false _rActive = false return end
        pcall(function()
            if _hu and _hu.Health > 0 then
                _hu.PlatformStand = false
                local st = _hu:GetState()
                if _isR(st) or st == Enum.HumanoidStateType.PlatformStanding then
                    _nukC()
                    _restM()
                    _hu:ChangeState(Enum.HumanoidStateType.GettingUp)
                    task.delay(0.06, function()
                        pcall(function() _hu:ChangeState(Enum.HumanoidStateType.Running) end)
                    end)
                end
                if not _gActive then
                    workspace.CurrentCamera.CameraSubject = _hu
                end
            end
        end)
        _exiting = false
        _rActive = false
    end)

    -- Шаг 9: Абсолютная страховка 500мс
    task.delay(0.5 + _δ(), function()
        pcall(function()
            if _hu and _hu.Health > 0 and not _gActive then
                _hu.PlatformStand = false
                workspace.CurrentCamera.CameraSubject = _hu
                -- Финальная проверка позиции
                if finalCF and _rt and _rt.Parent then
                    local dist = (_rt.Position - finalCF.Position).Magnitude
                    if dist > 5 then
                        _rt.CFrame = finalCF
                    end
                end
            end
        end)
        _exiting = false
        _rActive = false
    end)
end

-- ─── Детекция начала рагдолла ───
local function _onRS()
    if _rActive or _exiting then return end
    if not (_hu and _hu.Health > 0) then return end
    _rActive = true
    _rStart = tick()

    -- Задержка перед созданием призрака
    task.delay(0.03 + _δ(), function()
        if not _Σ.ar then _rActive = false return end
        if not _rActive then return end
        if _hu and _hu.Health <= 0 then _rActive = false return end
        _spawnG()
    end)
end

-- ─── Проверка конца рагдолла ───
local function _chkEnd()
    if not _rActive then return end
    if _exiting then return end
    if not (_hu and _ch) then return end

    -- Если умерли — отмена
    if _hu.Health <= 0 then
        _killG(false)
        _rActive = false
        return
    end

    -- Таймаут
    if tick() - _rStart > _rTimeout then
        _exitR()
        return
    end

    local st = _hu:GetState()
    local ps = false
    pcall(function() ps = _hu.PlatformStand end)

    -- Рагдолл закончился ЕСТЕСТВЕННО?
    if not _isR(st) and st ~= Enum.HumanoidStateType.PlatformStanding and not ps then
        -- Подтверждение через 50мс (не ложное срабатывание)
        task.delay(0.05, function()
            if not _rActive or _exiting then return end
            if not _hu then return end
            if _hu.Health <= 0 then _killG(false) _rActive = false return end
            local st2 = _hu:GetState()
            local ps2 = false
            pcall(function() ps2 = _hu.PlatformStand end)
            if not _isR(st2) and st2 ~= Enum.HumanoidStateType.PlatformStanding and not ps2 then
                _exitR()
            end
        end)
    end
end

local function _startAR()
    if not (_ch and _hu) then return end
    _snapM()

    local c1 = _hu.StateChanged:Connect(function(_, new)
        if not _Σ.ar then return end
        if _isR(new) or new == Enum.HumanoidStateType.PlatformStanding then
            task.delay(_δ(), _onRS)
        end
    end)
    _rc[#_rc + 1] = c1

    local c2 = _hu:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not _Σ.ar then return end
        if _hu.PlatformStand and not _rActive then
            task.delay(_δ(), _onRS)
        end
    end)
    _rc[#_rc + 1] = c2

    local c3 = _ch.DescendantAdded:Connect(function(v)
        if not _Σ.ar then return end
        task.delay(_δ(), function()
            pcall(function()
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("NoCollisionConstraint") then
                    if not _rActive and not _exiting then _onRS() end
                end
            end)
        end)
    end)
    _rc[#_rc + 1] = c3

    local c4 = _ch.DescendantRemoving:Connect(function(v)
        if not _Σ.ar then return end
        if v:IsA("Motor6D") then
            local data = { n = v.Name, p = v.Parent, p0 = v.Part0, p1 = v.Part1, c0 = v.C0, c1 = v.C1 }
            local found = false
            for _, s in ipairs(_mS) do
                if s.n == data.n and s.p == data.p then
                    s.c0 = data.c0
                    s.c1 = data.c1
                    found = true
                    break
                end
            end
            if not found then _mS[#_mS + 1] = data end
            if not _rActive and not _exiting then _onRS() end
        end
    end)
    _rc[#_rc + 1] = c4
end

local function _stopAR()
    for _, c in ipairs(_rc) do pcall(function() c:Disconnect() end) end
    _rc = {}
    _killG(false)
    _rActive = false
    _exiting = false
    for _, m in ipairs(_fM) do pcall(function() if m and m.Parent then m:Destroy() end end) end
    _fM = {}
    _mS = {}
end

-- ═══════════ NO ANIMATIONS ═══════════
local function _hkT(t)
    if not t or _trk[t] then return end
    _trk[t] = true
    local c = t:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if not _Σ.na then return end
        if t.IsPlaying then
            task.delay(_δ(), function()
                pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
            end)
        end
    end)
    _ac[#_ac + 1] = c
    if _Σ.na and t.IsPlaying then
        pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
    end
end

local function _sT()
    if not _an then return end
    pcall(function()
        for _, t in ipairs(_an:GetPlayingAnimationTracks()) do
            pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
        end
    end)
end

local function _hkA()
    if not _an then return end
    pcall(function()
        local c = _an.AnimationPlayed:Connect(function(t)
            _hkT(t)
            if _Σ.na then
                task.delay(_δ(), function()
                    pcall(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
                end)
            end
        end)
        _ac[#_ac + 1] = c
    end)
    if _hu then
        for _, e in ipairs({"Running", "Jumping", "Climbing", "Swimming", "FreeFalling"}) do
            pcall(function()
                local c = _hu[e]:Connect(function()
                    if _Σ.na then task.defer(_sT) end
                end)
                _ac[#_ac + 1] = c
            end)
        end
        local c = _hu.StateChanged:Connect(function()
            if _Σ.na then task.defer(_sT) end
        end)
        _ac[#_ac + 1] = c
    end
    pcall(function()
        for _, t in ipairs(_an:GetPlayingAnimationTracks()) do _hkT(t) end
    end)
end
local function _startNA() _hkA() end
local function _stopNA()
    for _, c in ipairs(_ac) do pcall(function() c:Disconnect() end) end
    _ac = {}
    for t in pairs(_trk) do
        pcall(function() if t and t.IsPlaying then t:AdjustSpeed(1) t:AdjustWeight(1, 0.1) end end)
    end
    _trk = {}
end

-- ═══════════ HEARTBEAT ═══════════
_hb = _RS.Heartbeat:Connect(function()
    _fc = _fc + 1
    if not (_ch and _ch.Parent) then _ref() return end
    if not (_hu and _hu.Health > 0) then
        -- Если умерли и призрак есть — убить призрака
        if _gActive then _killG(false) _rActive = false end
        return
    end

    -- Ghost управление КАЖДЫЙ кадр
    if _Σ.ar and _gActive then
        _ctrlG()
    end

    -- Проверка рагдолла каждые 3 кадра
    if _Σ.ar and _fc % 3 == 0 then
        _chkEnd()

        -- Fallback: призрак мёртв но рагдолл ещё активен
        if _rActive and not (_gPart and _gPart.Parent) then
            _gActive = false
            local st = _hu:GetState()
            local ps = false
            pcall(function() ps = _hu.PlatformStand end)
            if _isR(st) or st == Enum.HumanoidStateType.PlatformStanding or ps then
                _spawnG()
            else
                _rActive = false
            end
        end
    end

    -- NoAnim
    if _Σ.na and _fc % 3 == 0 then _sT() end
end)

-- ═══════════ РЕСПАВН ═══════════
_lp.CharacterAdded:Connect(function()
    task.wait(_ρ(0.3, 0.5))
    _killG(false)
    _rActive = false
    _exiting = false
    _ref()
    task.wait(_ρ(0.15, 0.25))
    if _Σ.ar then _stopAR() _startAR() end
    if _Σ.na then _stopNA() task.wait(0.12) _startNA() end
end)

-- ═══════════════════════════════════════════
-- ═══════════ GUI v14.0 WRAITH ═════════════
-- ═══════════════════════════════════════════

local _gn = _μ(18)
for _, g in ipairs(_pg:GetChildren()) do
    if g:IsA("ScreenGui") then
        pcall(function() if g.Name ~= "GranzHubGUI" then return end g:Destroy() end)
    end
end

local SG = Instance.new("ScreenGui")
SG.Name = _gn
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = _ι(2, 10)
SG.Parent = _pg

-- ═══ PALETTE ═══
local Φ = {
    bg     = Color3.fromRGB(5, 5, 10),
    bg2    = Color3.fromRGB(10, 10, 18),
    pnl    = Color3.fromRGB(14, 14, 24),
    hdr    = Color3.fromRGB(8, 8, 16),

    a1     = Color3.fromRGB(130, 70, 255),
    a2     = Color3.fromRGB(40, 185, 255),
    a3     = Color3.fromRGB(255, 65, 65),
    a4     = Color3.fromRGB(255, 185, 40),
    a5     = Color3.fromRGB(55, 255, 140),
    a6     = Color3.fromRGB(255, 105, 190),

    tw     = Color3.fromRGB(225, 225, 238),
    td     = Color3.fromRGB(75, 75, 95),
    tg     = Color3.fromRGB(60, 255, 120),

    tOff   = Color3.fromRGB(28, 28, 42),
    tKOff  = Color3.fromRGB(100, 100, 120),
    brd    = Color3.fromRGB(32, 32, 50),
}

local function mc(p, r) local c = Instance.new("UICorner", p) c.CornerRadius = UDim.new(0, r or 12) return c end
local function ms(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or Φ.brd; s.Thickness = th or 1; s.Transparency = tr or 0.5
    s.Parent = p; return s
end
local function tw(d, s, dir) return TweenInfo.new(d or 0.3, s or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out) end
local function twn(obj, inf, props) return _TW:Create(obj, inf, props) end

-- ═══ MAIN FRAME ═══
local MF = Instance.new("Frame")
MF.Name = _μ(4)
MF.Size = UDim2.new(0, 380, 0, 520)
MF.Position = UDim2.new(0.5, -190, 0.5, -260)
MF.BackgroundColor3 = Φ.bg
MF.BackgroundTransparency = 0
MF.BorderSizePixel = 0
MF.Active = true
MF.Draggable = true
MF.ClipsDescendants = true
MF.Parent = SG
mc(MF, 26)

local MFS = ms(MF, Φ.a1, 1.5, 0.55)

-- Тени (4 слоя для глубины)
for i = 1, 4 do
    local sh = Instance.new("ImageLabel")
    sh.Name = _μ(2)
    sh.Size = UDim2.new(1, 15 + i * 14, 1, 15 + i * 14)
    sh.Position = UDim2.new(0, -7.5 - i * 7, 0, -7.5 - i * 7)
    sh.BackgroundTransparency = 1
    sh.Image = "rbxassetid://6015897843"
    sh.ImageColor3 = Color3.new(0, 0, 0)
    sh.ImageTransparency = 0.45 + i * 0.11
    sh.ScaleType = Enum.ScaleType.Slice
    sh.SliceCenter = Rect.new(49, 49, 450, 450)
    sh.ZIndex = -i
    sh.Parent = MF
end

-- Glow орбы (6 штук, разные цвета)
local orbs = {}
local orbData = {
    {UDim2.new(0, -55, 0, -55),  Φ.a1, 200, 0.94},
    {UDim2.new(1, -90, 1, -110), Φ.a2, 180, 0.94},
    {UDim2.new(0.2, 0, 0.3, 0), Φ.a3, 110, 0.96},
    {UDim2.new(0.75, 0, 0.1, 0),Φ.a5,  95, 0.96},
    {UDim2.new(0.5, -50, 0.65, 0), Φ.a6, 130, 0.95},
    {UDim2.new(0.1, 0, 0.8, 0), Φ.a4, 80, 0.97},
}
for i, od in ipairs(orbData) do
    local o = Instance.new("Frame")
    o.Name = _μ(2)
    o.Size = UDim2.new(0, od[3], 0, od[3])
    o.Position = od[1]
    o.BackgroundColor3 = od[2]
    o.BackgroundTransparency = od[4]
    o.BorderSizePixel = 0
    o.ZIndex = 0
    o.Parent = MF
    mc(o, od[3])
    orbs[i] = o
end

-- Точечная сетка (subtle)
for r = 0, 12 do
    for c = 0, 8 do
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, 1, 0, 1)
        d.Position = UDim2.new(0, 12 + c * 42, 0, 70 + r * 38)
        d.BackgroundColor3 = Φ.tw
        d.BackgroundTransparency = 0.96
        d.BorderSizePixel = 0
        d.ZIndex = 0
        d.Parent = MF
        mc(d, 1)
    end
end

-- ═══ HEADER ═══
local HD = Instance.new("Frame")
HD.Name = _μ(3)
HD.Size = UDim2.new(1, 0, 0, 68)
HD.BackgroundColor3 = Φ.hdr
HD.BackgroundTransparency = 0.08
HD.BorderSizePixel = 0
HD.ZIndex = 5
HD.Parent = MF
mc(HD, 26)

-- Header bottom fix
local HBF = Instance.new("Frame")
HBF.Size = UDim2.new(1, 0, 0, 26)
HBF.Position = UDim2.new(0, 0, 1, -26)
HBF.BackgroundColor3 = Φ.hdr
HBF.BackgroundTransparency = 0.08
HBF.BorderSizePixel = 0
HBF.ZIndex = 5
HBF.Parent = HD

-- Тройная градиентная линия
local lineData = {
    {0.92, 3, 0.15},
    {0.65, 1.5, 0.45},
    {0.4, 1, 0.7},
}
local mainLine
for idx, ld in ipairs(lineData) do
    local hl = Instance.new("Frame")
    hl.Name = _μ(2)
    hl.Size = UDim2.new(ld[1], 0, 0, ld[2])
    hl.Position = UDim2.new((1 - ld[1]) / 2, 0, 1, (idx - 1) * 4)
    hl.BackgroundColor3 = Φ.tw
    hl.BackgroundTransparency = ld[3]
    hl.BorderSizePixel = 0
    hl.ZIndex = 6
    hl.Parent = HD
    mc(hl, 3)

    local hlg = Instance.new("UIGradient")
    hlg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Φ.a1),
        ColorSequenceKeypoint.new(0.15, Φ.a2),
        ColorSequenceKeypoint.new(0.35, Φ.a5),
        ColorSequenceKeypoint.new(0.55, Φ.a4),
        ColorSequenceKeypoint.new(0.75, Φ.a6),
        ColorSequenceKeypoint.new(1, Φ.a3),
    }
    hlg.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(0.15, 0),
        NumberSequenceKeypoint.new(0.85, 0),
        NumberSequenceKeypoint.new(1, 0.8),
    }
    hlg.Parent = hl

    if idx == 1 then
        mainLine = hl
        task.spawn(function()
            local off = 0
            while SG and SG.Parent do
                off = (off + 0.0015) % 1
                pcall(function()
                    hlg.Offset = Vector2.new(math.sin(off * math.pi * 2) * 0.5, 0)
                end)
                task.wait(0.02)
            end
        end)
    end
end

-- Лого — тройной кольцевой
local logoRings = {}
for i = 1, 3 do
    local sz = 48 - (i - 1) * 8
    local ring = Instance.new("Frame")
    ring.Name = _μ(2)
    ring.Size = UDim2.new(0, sz, 0, sz)
    ring.Position = UDim2.new(0, 14 + (48 - sz) / 2, 0.5, -sz / 2)
    ring.BackgroundColor3 = Φ.a1
    ring.BackgroundTransparency = 0.8 + (i - 1) * 0.03
    ring.BorderSizePixel = 0
    ring.ZIndex = 5 + i
    ring.Parent = HD
    mc(ring, sz / 2)
    if i < 3 then ms(ring, Φ.a1, 1, 0.4 + i * 0.15) end
    logoRings[i] = ring
end

local logoTxt = Instance.new("TextLabel")
logoTxt.Size = UDim2.new(1, 0, 1, 0)
logoTxt.BackgroundTransparency = 1
logoTxt.Text = "G"
logoTxt.TextColor3 = Φ.tw
logoTxt.TextSize = 15
logoTxt.Font = Enum.Font.GothamBlack
logoTxt.ZIndex = 9
logoTxt.Parent = logoRings[3]

-- Title
local ttl = Instance.new("TextLabel")
ttl.Size = UDim2.new(0, 140, 0, 22)
ttl.Position = UDim2.new(0, 70, 0, 10)
ttl.BackgroundTransparency = 1
ttl.RichText = true
ttl.Text = '<font color="#8246FF">GRANZ</font> <font color="#FFFFFF">HUB</font>'
ttl.TextSize = 18
ttl.Font = Enum.Font.GothamBlack
ttl.TextXAlignment = Enum.TextXAlignment.Left
ttl.ZIndex = 6
ttl.Parent = HD

-- Subtitle
local stl = Instance.new("TextLabel")
stl.Size = UDim2.new(0, 220, 0, 14)
stl.Position = UDim2.new(0, 70, 0, 34)
stl.BackgroundTransparency = 1
stl.Text = "wraith · v14.0 · phantom ghost"
stl.TextColor3 = Φ.td
stl.TextSize = 9
stl.Font = Enum.Font.GothamMedium
stl.TextXAlignment = Enum.TextXAlignment.Left
stl.ZIndex = 6
stl.Parent = HD

-- Бейджи (теперь с градиентным фоном)
local badgeInfo = {
    {"WRAITH", Φ.a1},
    {"v6.0", Φ.a5},
    {"2026", Φ.a2},
}
local bx = 70
for _, bi in ipairs(badgeInfo) do
    local bf = Instance.new("Frame")
    bf.Size = UDim2.new(0, #bi[1] * 5.5 + 16, 0, 16)
    bf.Position = UDim2.new(0, bx, 0, 50)
    bf.BackgroundColor3 = bi[2]
    bf.BackgroundTransparency = 0.88
    bf.BorderSizePixel = 0
    bf.ZIndex = 6
    bf.Parent = HD
    mc(bf, 5)
    ms(bf, bi[2], 0.5, 0.55)

    local bl = Instance.new("TextLabel")
    bl.Size = UDim2.new(1, 0, 1, 0)
    bl.BackgroundTransparency = 1
    bl.Text = bi[1]
    bl.TextColor3 = bi[2]
    bl.TextSize = 7
    bl.Font = Enum.Font.GothamBlack
    bl.ZIndex = 7
    bl.Parent = bf

    bx = bx + #bi[1] * 5.5 + 20
end

-- Кнопки
local function mkBtn(pos, txt, bgC)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 38, 0, 38)
    b.Position = pos
    b.BackgroundColor3 = bgC
    b.BackgroundTransparency = 0.35
    b.Text = txt
    b.TextColor3 = Φ.tw
    b.TextSize = 15
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.ZIndex = 6
    b.Parent = HD
    mc(b, 12)

    b.MouseEnter:Connect(function()
        twn(b, tw(0.2), {BackgroundTransparency = 0.1}):Play()
    end)
    b.MouseLeave:Connect(function()
        twn(b, tw(0.2), {BackgroundTransparency = 0.35}):Play()
    end)
    return b
end

local MinB = mkBtn(UDim2.new(1, -90, 0, 15), "━", Color3.fromRGB(42, 42, 58))
local ClsB = mkBtn(UDim2.new(1, -48, 0, 15), "✕", Color3.fromRGB(165, 30, 30))

-- ═══ CONTENT ═══
local CT = Instance.new("ScrollingFrame")
CT.Name = _μ(3)
CT.Size = UDim2.new(1, -16, 1, -84)
CT.Position = UDim2.new(0, 8, 0, 76)
CT.BackgroundTransparency = 1
CT.BorderSizePixel = 0
CT.ScrollBarThickness = 2
CT.ScrollBarImageColor3 = Φ.a1
CT.ScrollBarImageTransparency = 0.65
CT.CanvasSize = UDim2.new(0, 0, 0, 0)
CT.AutomaticCanvasSize = Enum.AutomaticSize.Y
CT.ZIndex = 3
CT.Parent = MF

Instance.new("UIListLayout", CT).Padding = UDim.new(0, 7)
CT:FindFirstChildOfClass("UIListLayout").SortOrder = Enum.SortOrder.LayoutOrder

local pad = Instance.new("UIPadding", CT)
pad.PaddingTop = UDim.new(0, 2)
pad.PaddingBottom = UDim.new(0, 14)

-- ═══ MODULES v14 ═══
local function createMod(icon, name, desc, order, acCol, tags)
    local Mod = Instance.new("Frame")
    Mod.Name = _μ(4)
    Mod.Size = UDim2.new(1, 0, 0, 94)
    Mod.BackgroundColor3 = Φ.pnl
    Mod.BackgroundTransparency = 0.1
    Mod.BorderSizePixel = 0
    Mod.LayoutOrder = order
    Mod.ZIndex = 3
    Mod.ClipsDescendants = true
    Mod.Parent = CT
    mc(Mod, 18)

    local MS = ms(Mod, Φ.brd, 1, 0.65)

    -- Left gradient bar
    local LB = Instance.new("Frame")
    LB.Size = UDim2.new(0, 3.5, 0.5, 0)
    LB.Position = UDim2.new(0, 0, 0.25, 0)
    LB.BackgroundColor3 = acCol
    LB.BackgroundTransparency = 0.35
    LB.BorderSizePixel = 0
    LB.ZIndex = 4
    LB.Parent = Mod
    mc(LB, 2)
    local lbg = Instance.new("UIGradient", LB)
    lbg.Rotation = 90
    lbg.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 0.6),
    }

    -- Icon (triple ring)
    local icO = Instance.new("Frame")
    icO.Size = UDim2.new(0, 50, 0, 50)
    icO.Position = UDim2.new(0, 14, 0, 12)
    icO.BackgroundColor3 = acCol
    icO.BackgroundTransparency = 0.92
    icO.BorderSizePixel = 0
    icO.ZIndex = 4
    icO.Parent = Mod
    mc(icO, 16)

    local icM = Instance.new("Frame")
    icM.Size = UDim2.new(0, 38, 0, 38)
    icM.Position = UDim2.new(0.5, -19, 0.5, -19)
    icM.BackgroundColor3 = acCol
    icM.BackgroundTransparency = 0.85
    icM.BorderSizePixel = 0
    icM.ZIndex = 5
    icM.Parent = icO
    mc(icM, 12)

    local icI = Instance.new("Frame")
    icI.Size = UDim2.new(0, 28, 0, 28)
    icI.Position = UDim2.new(0.5, -14, 0.5, -14)
    icI.BackgroundColor3 = acCol
    icI.BackgroundTransparency = 0.75
    icI.BorderSizePixel = 0
    icI.ZIndex = 6
    icI.Parent = icM
    mc(icI, 9)

    local icL = Instance.new("TextLabel")
    icL.Size = UDim2.new(1, 0, 1, 0)
    icL.BackgroundTransparency = 1
    icL.Text = icon
    icL.TextSize = 16
    icL.Font = Enum.Font.GothamBold
    icL.ZIndex = 7
    icL.Parent = icI

    -- Name
    local NL = Instance.new("TextLabel")
    NL.Size = UDim2.new(1, -150, 0, 20)
    NL.Position = UDim2.new(0, 74, 0, 12)
    NL.BackgroundTransparency = 1
    NL.Text = name
    NL.TextColor3 = Φ.tw
    NL.TextSize = 14
    NL.Font = Enum.Font.GothamBold
    NL.TextXAlignment = Enum.TextXAlignment.Left
    NL.ZIndex = 4
    NL.Parent = Mod

    -- Desc
    local DL = Instance.new("TextLabel")
    DL.Size = UDim2.new(1, -150, 0, 14)
    DL.Position = UDim2.new(0, 74, 0, 34)
    DL.BackgroundTransparency = 1
    DL.Text = desc
    DL.TextColor3 = Φ.td
    DL.TextSize = 10
    DL.Font = Enum.Font.Gotham
    DL.TextXAlignment = Enum.TextXAlignment.Left
    DL.ZIndex = 4
    DL.Parent = Mod

    -- Tags
    if tags then
        local tx = 74
        for _, tg in ipairs(tags) do
            local tf = Instance.new("Frame")
            tf.Size = UDim2.new(0, #tg * 5 + 14, 0, 16)
            tf.Position = UDim2.new(0, tx, 0, 54)
            tf.BackgroundColor3 = acCol
            tf.BackgroundTransparency = 0.9
            tf.BorderSizePixel = 0
            tf.ZIndex = 4
            tf.Parent = Mod
            mc(tf, 5)

            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.new(1, 0, 1, 0)
            tl.BackgroundTransparency = 1
            tl.Text = tg
            tl.TextColor3 = acCol
            tl.TextSize = 8
            tl.Font = Enum.Font.GothamBold
            tl.ZIndex = 5
            tl.Parent = tf

            tx = tx + #tg * 5 + 18
        end
    end

    -- Bottom shine line
    local BL = Instance.new("Frame")
    BL.Size = UDim2.new(0, 0, 0, 2)
    BL.Position = UDim2.new(0.5, 0, 1, -3)
    BL.AnchorPoint = Vector2.new(0.5, 0)
    BL.BackgroundColor3 = acCol
    BL.BackgroundTransparency = 0.5
    BL.BorderSizePixel = 0
    BL.ZIndex = 4
    BL.Parent = Mod
    mc(BL, 1)

    -- Toggle pill
    local TB = Instance.new("TextButton")
    TB.Size = UDim2.new(0, 54, 0, 30)
    TB.Position = UDim2.new(1, -66, 0.5, -15)
    TB.BackgroundColor3 = Φ.tOff
    TB.Text = ""
    TB.BorderSizePixel = 0
    TB.AutoButtonColor = false
    TB.ZIndex = 4
    TB.Parent = Mod
    mc(TB, 15)
    local TBS = ms(TB, Φ.brd, 0.5, 0.55)

    local TK = Instance.new("Frame")
    TK.Size = UDim2.new(0, 24, 0, 24)
    TK.Position = UDim2.new(0, 3, 0.5, -12)
    TK.BackgroundColor3 = Φ.tKOff
    TK.BorderSizePixel = 0
    TK.ZIndex = 5
    TK.Parent = TB
    mc(TK, 12)
    local TKS = ms(TK, acCol, 0, 0.8)

    -- Status dot
    local SD = Instance.new("Frame")
    SD.Size = UDim2.new(0, 9, 0, 9)
    SD.Position = UDim2.new(1, -20, 0, 8)
    SD.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    SD.BorderSizePixel = 0
    SD.ZIndex = 5
    SD.Parent = Mod
    mc(SD, 5)

    -- Hover
    local hov = Instance.new("TextButton")
    hov.Size = UDim2.new(1, 0, 1, 0)
    hov.BackgroundTransparency = 1
    hov.Text = ""
    hov.ZIndex = 3
    hov.Parent = Mod

    hov.MouseEnter:Connect(function()
        twn(Mod, tw(0.25), {BackgroundTransparency = 0}):Play()
        twn(MS, tw(0.25), {Transparency = 0.3}):Play()
        twn(LB, tw(0.25), {BackgroundTransparency = 0.1, Size = UDim2.new(0, 5, 0.6, 0)}):Play()
        twn(BL, tw(0.35), {Size = UDim2.new(0.75, 0, 0, 2)}):Play()
        twn(icO, tw(0.3), {BackgroundTransparency = 0.85}):Play()
    end)
    hov.MouseLeave:Connect(function()
        twn(Mod, tw(0.25), {BackgroundTransparency = 0.1}):Play()
        twn(MS, tw(0.25), {Transparency = 0.65}):Play()
        twn(LB, tw(0.25), {BackgroundTransparency = 0.35, Size = UDim2.new(0, 3.5, 0.5, 0)}):Play()
        twn(BL, tw(0.35), {Size = UDim2.new(0, 0, 0, 2)}):Play()
        twn(icO, tw(0.3), {BackgroundTransparency = 0.92}):Play()
    end)

    local isOn = false

    local function updV(state)
        isOn = state
        local t = tw(0.35)
        if state then
            twn(TB, t, {BackgroundColor3 = acCol}):Play()
            twn(TBS, t, {Color = acCol, Transparency = 0.2}):Play()
            twn(TK, t, {Position = UDim2.new(1, -27, 0.5, -12), BackgroundColor3 = Color3.new(1, 1, 1)}):Play()
            twn(TKS, t, {Thickness = 3, Transparency = 0.1}):Play()
            twn(MS, t, {Color = acCol, Transparency = 0.3}):Play()
            twn(icI, t, {BackgroundTransparency = 0.6}):Play()
            twn(icM, t, {BackgroundTransparency = 0.75}):Play()
            twn(LB, t, {BackgroundTransparency = 0.05}):Play()
            twn(SD, t, {BackgroundColor3 = Φ.tg}):Play()
            -- Pulse
            twn(TB, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
                Size = UDim2.new(0, 58, 0, 34)
            }):Play()
            -- Bottom flash
            twn(BL, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {
                Size = UDim2.new(0.9, 0, 0, 2.5), BackgroundTransparency = 0.2
            }):Play()
            task.delay(0.6, function()
                if isOn then
                    pcall(function()
                        twn(BL, tw(0.5), {Size = UDim2.new(0.35, 0, 0, 2), BackgroundTransparency = 0.5}):Play()
                    end)
                end
            end)
        else
            twn(TB, t, {BackgroundColor3 = Φ.tOff}):Play()
            twn(TBS, t, {Color = Φ.brd, Transparency = 0.55}):Play()
            twn(TK, t, {Position = UDim2.new(0, 3, 0.5, -12), BackgroundColor3 = Φ.tKOff}):Play()
            twn(TKS, t, {Thickness = 0, Transparency = 0.8}):Play()
            twn(MS, t, {Color = Φ.brd, Transparency = 0.65}):Play()
            twn(icI, t, {BackgroundTransparency = 0.75}):Play()
            twn(icM, t, {BackgroundTransparency = 0.85}):Play()
            twn(LB, t, {BackgroundTransparency = 0.35}):Play()
            twn(SD, t, {BackgroundColor3 = Color3.fromRGB(35, 35, 50)}):Play()
            twn(BL, tw(0.3), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 0.5}):Play()
        end
    end

    return TB, updV
end

local JT, JV = createMod("⚡", "Infinite Jump", "Прыжки в воздухе без ограничений", 1, Φ.a1, {"AIR", "MULTI", "v3"})
local RT, RV = createMod("👻", "Ghost Anti-Ragdoll", "Призрак ходит — тело летит натурально", 2, Φ.a2, {"GHOST", "v6", "SAFE"})
local AT, AV = createMod("🎭", "No Animations", "Полная заморозка анимаций", 3, Φ.a3, {"FREEZE", "SILENT"})

-- Разделитель
local Sep = Instance.new("Frame")
Sep.Size = UDim2.new(0.88, 0, 0, 1)
Sep.BackgroundColor3 = Φ.tw
Sep.BackgroundTransparency = 0.93
Sep.BorderSizePixel = 0
Sep.LayoutOrder = 5
Sep.ZIndex = 3
Sep.Parent = CT
mc(Sep, 1)
local sg2 = Instance.new("UIGradient", Sep)
sg2.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.25, 0),
    NumberSequenceKeypoint.new(0.75, 0),
    NumberSequenceKeypoint.new(1, 1),
}

-- ═══ STATUS BAR v14 ═══
local SB = Instance.new("Frame")
SB.Name = _μ(3)
SB.Size = UDim2.new(1, 0, 0, 58)
SB.BackgroundColor3 = Φ.bg2
SB.BackgroundTransparency = 0.2
SB.BorderSizePixel = 0
SB.LayoutOrder = 10
SB.ZIndex = 3
SB.Parent = CT
mc(SB, 16)
ms(SB, Φ.brd, 0.5, 0.7)

-- Indicator boxes
local dots = {}
local dotLbls = {}
local dotCols = {Φ.a1, Φ.a2, Φ.a3}
local dotNames = {"JMP", "RAG", "ANI"}
for i = 1, 3 do
    local dg = Instance.new("Frame")
    dg.Size = UDim2.new(0, 32, 0, 32)
    dg.Position = UDim2.new(0, 10 + (i - 1) * 38, 0, 8)
    dg.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    dg.BackgroundTransparency = 0.25
    dg.BorderSizePixel = 0
    dg.ZIndex = 4
    dg.Parent = SB
    mc(dg, 9)

    local d = Instance.new("Frame")
    d.Size = UDim2.new(0, 10, 0, 10)
    d.Position = UDim2.new(0.5, -5, 0, 5)
    d.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    d.BorderSizePixel = 0
    d.ZIndex = 5
    d.Parent = dg
    mc(d, 5)
    dots[i] = d

    local dl = Instance.new("TextLabel")
    dl.Size = UDim2.new(1, 0, 0, 10)
    dl.Position = UDim2.new(0, 0, 1, -13)
    dl.BackgroundTransparency = 1
    dl.Text = dotNames[i]
    dl.TextColor3 = Φ.td
    dl.TextSize = 6
    dl.Font = Enum.Font.GothamBlack
    dl.ZIndex = 5
    dl.Parent = dg
    dotLbls[i] = dl
end

local SL = Instance.new("TextLabel")
SL.Size = UDim2.new(1, -135, 0, 16)
SL.Position = UDim2.new(0, 128, 0, 8)
SL.BackgroundTransparency = 1
SL.Text = "Ready"
SL.TextColor3 = Φ.td
SL.TextSize = 10
SL.Font = Enum.Font.GothamMedium
SL.TextXAlignment = Enum.TextXAlignment.Left
SL.ZIndex = 4
SL.Parent = SB

local GI = Instance.new("TextLabel")
GI.Size = UDim2.new(1, -135, 0, 14)
GI.Position = UDim2.new(0, 128, 0, 26)
GI.BackgroundTransparency = 1
GI.Text = ""
GI.TextColor3 = Φ.a2
GI.TextSize = 9
GI.Font = Enum.Font.Gotham
GI.TextXAlignment = Enum.TextXAlignment.Left
GI.ZIndex = 4
GI.Parent = SB

local PI = Instance.new("TextLabel")
PI.Size = UDim2.new(0, 70, 0, 12)
PI.Position = UDim2.new(1, -80, 0, 42)
PI.BackgroundTransparency = 1
PI.Text = "●  " .. _ι(10, 40) .. "ms"
PI.TextColor3 = Φ.tg
PI.TextSize = 8
PI.Font = Enum.Font.GothamMedium
PI.TextXAlignment = Enum.TextXAlignment.Right
PI.ZIndex = 4
PI.Parent = SB

local function updateSt()
    local cnt = 0
    local sts = {_Σ.j, _Σ.ar, _Σ.na}
    for i, s in ipairs(sts) do
        local t = tw(0.3)
        if s then
            cnt += 1
            twn(dots[i], t, {BackgroundColor3 = dotCols[i]}):Play()
            twn(dotLbls[i], t, {TextColor3 = dotCols[i]}):Play()
        else
            twn(dots[i], t, {BackgroundColor3 = Color3.fromRGB(30, 30, 45)}):Play()
            twn(dotLbls[i], t, {TextColor3 = Φ.td}):Play()
        end
    end
    if cnt == 0 then
        SL.Text = "Модули неактивны"
        twn(SL, tw(0.3), {TextColor3 = Φ.td}):Play()
    else
        SL.Text = cnt .. "/3 · WRAITH ACTIVE"
        twn(SL, tw(0.3), {TextColor3 = Φ.tg}):Play()
    end
end

-- Ghost status
task.spawn(function()
    while SG and SG.Parent do
        if _gActive then
            local e = math.floor(tick() - _rStart)
            GI.Text = "👻 GHOST · " .. e .. "s · free movement"
            GI.TextColor3 = Color3.fromHSV((tick() * 0.25) % 1, 0.45, 1)
        else
            GI.Text = ""
        end
        pcall(function() PI.Text = "●  " .. _ι(8, 45) .. "ms" end)
        task.wait(0.12)
    end
end)

-- ═══ HANDLERS ═══
JT.MouseButton1Click:Connect(function()
    _Σ.j = not _Σ.j
    JV(_Σ.j)
    if _Σ.j then _ref() end
    updateSt()
end)

RT.MouseButton1Click:Connect(function()
    _Σ.ar = not _Σ.ar
    RV(_Σ.ar)
    if _Σ.ar then _ref() _startAR()
    else _stopAR() end
    updateSt()
end)

AT.MouseButton1Click:Connect(function()
    _Σ.na = not _Σ.na
    AV(_Σ.na)
    if _Σ.na then _ref() _startNA()
    else _stopNA() end
    updateSt()
end)

-- ═══ MINIMIZE / CLOSE ═══
local _min = false
local _fSz = MF.Size

MinB.MouseButton1Click:Connect(function()
    _min = not _min
    if _min then
        twn(MF, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 380, 0, 68)
        }):Play()
        task.delay(0.05, function() CT.Visible = false end)
        MinB.Text = "◻"
    else
        twn(MF, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = _fSz}):Play()
        task.delay(0.3, function() CT.Visible = true end)
        MinB.Text = "━"
    end
end)

ClsB.MouseButton1Click:Connect(function()
    _Σ.j = false; _Σ.ar = false; _Σ.na = false
    _stopAR(); _stopNA()
    if _hb then _hb:Disconnect() end

    twn(MFS, tw(0.2), {Transparency = 1}):Play()
    twn(MF, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 44, 0, 44),
        Position = UDim2.new(0.5, -22, 0.5, -22),
        BackgroundTransparency = 0.4
    }):Play()
    task.delay(0.35, function()
        twn(MF, tw(0.15), {BackgroundTransparency = 1}):Play()
    end)
    task.delay(0.55, function() SG:Destroy() end)
end)

-- ═══ LIVE ANIMATIONS ═══

-- 1. Rainbow border
task.spawn(function()
    local h = _ρ(0, 1)
    while SG and SG.Parent do
        h = (h + 0.001) % 1
        local ac = (_Σ.j and 1 or 0) + (_Σ.ar and 1 or 0) + (_Σ.na and 1 or 0)
        local t = tick()
        if ac > 0 then
            MFS.Color = Color3.fromHSV(h, 0.5 + ac * 0.12, 0.75 + ac * 0.08)
            MFS.Transparency = 0.06 + math.sin(t * 1.6) * 0.06
            MFS.Thickness = 1.5 + math.sin(t * 2.2) * 0.5
            pcall(function()
                for _, ring in ipairs(logoRings) do
                    ring.BackgroundColor3 = Color3.fromHSV((h + 0.1) % 1, 0.6, 0.9)
                end
            end)
        else
            MFS.Color = Φ.brd; MFS.Transparency = 0.65; MFS.Thickness = 1
            pcall(function()
                for _, ring in ipairs(logoRings) do
                    ring.BackgroundColor3 = Φ.a1
                end
            end)
        end
        task.wait(0.02)
    end
end)

-- 2. Orb drift
task.spawn(function()
    while SG and SG.Parent do
        local t = tick()
        for i, o in ipairs(orbs) do
            pcall(function()
                local od = orbData[i]
                local ox = math.sin(t * (0.2 + i * 0.08) + i * 2) * 10
                local oy = math.cos(t * (0.25 + i * 0.06) + i * 1.5) * 8
                o.Position = UDim2.new(od[1].X.Scale, od[1].X.Offset + ox, od[1].Y.Scale, od[1].Y.Offset + oy)
                o.BackgroundTransparency = od[4] + math.sin(t * (0.6 + i * 0.15)) * 0.025
            end)
        end
        task.wait(0.03)
    end
end)

-- 3. Logo ring breathing
task.spawn(function()
    while SG and SG.Parent do
        local ac = (_Σ.j and 1 or 0) + (_Σ.ar and 1 or 0) + (_Σ.na and 1 or 0)
        if ac > 0 then
            for i, ring in ipairs(logoRings) do
                pcall(function()
                    local sz = (48 - (i - 1) * 8) + 2
                    twn(ring, tw(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        BackgroundTransparency = 0.72 + (i - 1) * 0.04,
                        Size = UDim2.new(0, sz, 0, sz),
                    }):Play()
                end)
            end
            task.wait(1.8)
            if not (SG and SG.Parent) then return end
            for i, ring in ipairs(logoRings) do
                pcall(function()
                    local sz = 48 - (i - 1) * 8
                    twn(ring, tw(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        BackgroundTransparency = 0.8 + (i - 1) * 0.03,
                        Size = UDim2.new(0, sz, 0, sz),
                    }):Play()
                end)
            end
            task.wait(1.8)
        else
            task.wait(0.4)
        end
    end
end)

-- 4. Dots pulse
task.spawn(function()
    while SG and SG.Parent do
        local sts = {_Σ.j, _Σ.ar, _Σ.na}
        for i, s in ipairs(sts) do
            if s then
                pcall(function()
                    twn(dots[i], tw(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        Size = UDim2.new(0, 13, 0, 13),
                        Position = UDim2.new(0.5, -6.5, 0, 3.5),
                    }):Play()
                end)
            end
        end
        task.wait(0.8)
        if not (SG and SG.Parent) then return end
        for i, s in ipairs(sts) do
            if s then
                pcall(function()
                    twn(dots[i], tw(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        Size = UDim2.new(0, 10, 0, 10),
                        Position = UDim2.new(0.5, -5, 0, 5),
                    }):Play()
                end)
            end
        end
        task.wait(0.8)
    end
end)

-- ═══ OPENING ANIMATION ═══
MF.Size = UDim2.new(0, 44, 0, 44)
MF.Position = UDim2.new(0.5, -22, 0.5, -22)
MF.BackgroundTransparency = 1
CT.Visible = false
MFS.Transparency = 1

task.delay(0.05, function()
    -- Phase 1: dot
    twn(MF, tw(0.15), {BackgroundTransparency = 0}):Play()
    twn(MFS, tw(0.2), {Transparency = 0.55}):Play()
    task.wait(0.12)

    -- Phase 2: expand
    twn(MF, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 380, 0, 520),
        Position = UDim2.new(0.5, -190, 0.5, -260),
    }):Play()
    task.wait(0.45)

    -- Phase 3: content
    CT.Visible = true

    -- Phase 4: cascade modules
    local kids = {}
    for _, ch in ipairs(CT:GetChildren()) do
        if ch:IsA("Frame") then
            ch.BackgroundTransparency = 1
            kids[#kids + 1] = ch
        end
    end

    for i, ch in ipairs(kids) do
        task.delay(i * 0.07, function()
            local tgt = (ch == SB) and 0.2 or 0.1
            local origPos = ch.Position
            -- Slide in from right with fade
            pcall(function()
                ch.Position = UDim2.new(origPos.X.Scale + 0.08, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset)
            end)
            twn(ch, tw(0.45, Enum.EasingStyle.Quint), {
                BackgroundTransparency = tgt,
                Position = origPos
            }):Play()
        end)
    end
end)

updateSt()
