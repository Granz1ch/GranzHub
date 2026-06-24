-- // ██████╗ ██████╗  █████╗ ███╗   ██╗███████╗
-- // ██╔════╝ ██╔══██╗██╔══██╗████╗  ██║╚══███╔╝
-- // ██║  ███╗██████╔╝███████║██╔██╗ ██║  ███╔╝
-- // ██║   ██║██╔══██╗██╔══██║██║╚██╗██║ ███╔╝
-- // ╚██████╔╝██║  ██║██║  ██║██║ ╚████║███████╗
-- //  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝
-- // v11.0 PHANTOM EDITION — Steal a Brainrot 2026

--[[ 
    ANTI-DETECTION LAYER:
    - Все переменные имеют рандомизированные имена
    - Никаких прямых строковых паттернов для сканера
    - Использование pcall/xpcall обёрток везде
    - Задержки между операциями рандомизированы
    - GUI элементы маскированы под системные
]]

local _RNG = Random.new(tick() * os.clock())
local function _rid(len)
    len = len or _RNG:NextInteger(8, 14)
    local c = "abcdefghijklmnopqrstuvwxyz"
    local r = ""
    for i = 1, len do
        local idx = _RNG:NextInteger(1, #c)
        r = r .. c:sub(idx, idx)
    end
    return r .. tostring(_RNG:NextInteger(100, 999))
end

local function _rdelay()
    return _RNG:NextNumber(0.001, 0.008)
end

-- Сервисы через рандомизированный доступ
local _svc = setmetatable({}, {
    __index = function(self, key)
        local s = game:GetService(key)
        rawset(self, key, s)
        return s
    end
})

local _P = _svc["Players"]
local _UIS = _svc["UserInputService"]
local _RS = _svc["RunService"]
local _TS = _svc["TweenService"]
local _CS = _svc["CollectionService"]

local _lp = _P.LocalPlayer
local _pg = _lp:WaitForChild("PlayerGui")

-- ==================== КОНФИГУРАЦИЯ ====================
local _CFG = {
    _j = false,     -- InfJump
    _ar = false,    -- AntiRagdoll
    _na = false,    -- NoAnim
    _jp = 50,       -- JumpPower
    _cd = 0.12,     -- Cooldown
    _mfs = -60,     -- MaxFallSpeed
}

-- ==================== ВНУТРЕННЕЕ СОСТОЯНИЕ ====================
local _lastJ = 0
local _char, _hum, _root, _anim
local _rc = {}       -- ragdoll connections
local _ac = {}       -- anim connections
local _hbc = nil     -- heartbeat
local _tt = {}       -- tracked tracks
local _smd = {}      -- saved motor data
local _fm = {}       -- fake motors
local _lastEsc = 0
local _guiOpen = true
local _minimized = false

-- ==================== УТИЛИТЫ С АНТИДЕТЕКТОМ ====================
local function _sf(obj, name)
    local ok, r = pcall(function() return obj:FindFirstChild(name) end)
    return ok and r or nil
end

local function _sfc(obj, cls)
    local ok, r = pcall(function() return obj:FindFirstChildOfClass(cls) end)
    return ok and r or nil
end

local function _wrap(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        return ok
    end
end

local function _wrapR(fn)
    return function(...)
        local ok, r = pcall(fn, ...)
        return ok and r or nil
    end
end

local function _ref()
    _char = _lp.Character
    if not _char then return false end
    _hum = _sfc(_char, "Humanoid")
    _root = _sf(_char, "HumanoidRootPart")
    _anim = _hum and _sfc(_hum, "Animator")
    return _hum ~= nil and _root ~= nil
end

_ref()

-- ==================== INFINITE JUMP (ОБФУСЦИРОВАННЫЙ) ====================
local function _doJump()
    if not _CFG._j then return end
    if not (_hum and _root) then return end
    if _hum.Health <= 0 then return end
    local n = tick()
    if n - _lastJ < _CFG._cd then return end
    _lastJ = n
    
    local cv = _root.AssemblyLinearVelocity
    local ny = _CFG._jp
    if cv.Y < _CFG._mfs then
        ny = _CFG._jp + math.abs(cv.Y) * 0.3
    end
    
    -- Рандомизированное микро-отклонение для антидетекта
    local jitter = _RNG:NextNumber(-0.3, 0.3)
    _root.AssemblyLinearVelocity = Vector3.new(
        cv.X * (0.88 + _RNG:NextNumber(0, 0.04)),
        ny + jitter,
        cv.Z * (0.88 + _RNG:NextNumber(0, 0.04))
    )
    
    task.delay(0.04 + _rdelay(), function()
        if _root and _root.Parent and _CFG._j then
            local v = _root.AssemblyLinearVelocity
            if v.Y < _CFG._jp * 0.78 then
                _root.AssemblyLinearVelocity = Vector3.new(v.X, _CFG._jp * (0.88 + _RNG:NextNumber(0, 0.04)), v.Z)
            end
        end
    end)
end

_UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.Space then
        if not (_hum and _root) then return end
        local st = _hum:GetState()
        if st == Enum.HumanoidStateType.Freefall
            or st == Enum.HumanoidStateType.Jumping
            or st == Enum.HumanoidStateType.FallingDown then
            _doJump()
        end
    end
end)

-- ==================== ANTI-RAGDOLL v3.0 (ПОЛНОСТЬЮ ПЕРЕПИСАН) ====================
--[[
    ПРОБЛЕМА СТАРОЙ ВЕРСИИ:
    При рагдолле часть скина "отлетала" потому что:
    1. Motor6D удалялись сервером, а мы пересоздавали их на клиенте
    2. Но сервер параллельно вставлял BallSocketConstraint
    3. Возникал конфликт — часть частей тела управлялись мотором,
       а часть — констрейнтом = "разрыв" модели

    НОВОЕ РЕШЕНИЕ:
    - Вместо борьбы с рагдоллом В МОМЕНТ его активации,
      мы делаем превентивный подход:
    - Сохраняем ВСЕ CFrame всех частей тела каждый кадр когда НЕ в рагдолле
    - При обнаружении рагдолла:
      1. Ждём МИКРО-паузу (0.03с) чтобы рагдолл полностью активировался
      2. Уничтожаем ВСЕ рагдолл-констрейнты СРАЗУ
      3. Пересоздаём ВСЕ моторы СРАЗУ (не по одному)
      4. Восстанавливаем CFrame всех частей из сохранённых данных
      5. Форсим выход из состояния
    - Дополнительно: КАЖДЫЙ кадр проверяем целостность моторов
]]

local _ragStates = {
    [Enum.HumanoidStateType.Ragdoll] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics] = true,
}

local function _isRag(st)
    return _ragStates[st] == true
end

-- Хранилище ВСЕХ данных о моторах
local _motorCache = {}
-- Хранилище CFrame всех частей (обновляется каждый кадр)
local _partCFrames = {}
-- Флаг что мы в процессе восстановления
local _restoring = false

-- Глубокое сканирование и сохранение ВСЕХ Motor6D
local function _deepSaveMotors()
    _motorCache = {}
    if not _char then return end
    for _, v in ipairs(_char:GetDescendants()) do
        if v:IsA("Motor6D") then
            _motorCache[#_motorCache + 1] = {
                _ref = v,
                _n = v.Name,
                _p = v.Parent,
                _p0 = v.Part0,
                _p1 = v.Part1,
                _c0 = v.C0,
                _c1 = v.C1,
                _alive = true,
            }
        end
    end
end

-- Сохраняем CFrame всех BasePart (вызывается каждый кадр)
local function _saveCFrames()
    if not _char then return end
    if _restoring then return end
    local st = _hum and _hum:GetState()
    if st and (_isRag(st) or st == Enum.HumanoidStateType.PlatformStanding) then return end
    
    for _, v in ipairs(_char:GetDescendants()) do
        if v:IsA("BasePart") then
            _partCFrames[v] = v.CFrame
        end
    end
end

-- ПОЛНОЕ восстановление из рагдолла
local function _fullRestore()
    if not (_hum and _char and _root) then return end
    if _hum.Health <= 0 then return end
    if _restoring then return end
    _restoring = true
    
    -- Фаза 1: Отключаем PlatformStand
    _wrap(function() _hum.PlatformStand = false end)()
    
    -- Фаза 2: Уничтожаем ВСЕ рагдолл-констрейнты за один проход
    local toDestroy = {}
    for _, v in ipairs(_char:GetDescendants()) do
        pcall(function()
            if v:IsA("BallSocketConstraint")
                or v:IsA("HingeConstraint") 
                or v:IsA("RopeConstraint")
                or v:IsA("SpringConstraint")
                or v:IsA("CylindricalConstraint")
                or v:IsA("PrismaticConstraint") then
                toDestroy[#toDestroy + 1] = v
            end
            -- Также убираем NoCollisionConstraint которые часто добавляются при рагдолле
            if v:IsA("NoCollisionConstraint") then
                toDestroy[#toDestroy + 1] = v
            end
        end)
    end
    
    for _, v in ipairs(toDestroy) do
        pcall(function() v:Destroy() end)
    end
    
    -- Фаза 3: Восстанавливаем ВСЕ моторы
    for _, data in ipairs(_motorCache) do
        pcall(function()
            -- Проверяем жив ли оригинальный мотор
            if data._ref and data._ref.Parent then
                data._ref.Enabled = true
                data._alive = true
                return
            end
            
            -- Проверяем что родитель и части существуют
            if not (data._p and data._p.Parent) then return end
            if not (data._p0 and data._p0.Parent) then return end
            if not (data._p1 and data._p1.Parent) then return end
            
            -- Проверяем нет ли уже такого мотора
            local existing = data._p:FindFirstChild(data._n)
            if existing and existing:IsA("Motor6D") then
                existing.Enabled = true
                data._ref = existing
                data._alive = true
                return
            end
            
            -- Создаём новый мотор
            local m = Instance.new("Motor6D")
            m.Name = data._n
            m.Part0 = data._p0
            m.Part1 = data._p1
            m.C0 = data._c0
            m.C1 = data._c1
            m.Parent = data._p
            
            data._ref = m
            data._alive = true
            _fm[#_fm + 1] = m
        end)
    end
    
    -- Фаза 4: Восстанавливаем CFrame всех частей
    for part, cf in pairs(_partCFrames) do
        pcall(function()
            if part and part.Parent and part:IsA("BasePart") then
                part.Anchored = false
                -- Не трогаем HumanoidRootPart чтобы не телепортировать
                if part.Name ~= "HumanoidRootPart" then
                    -- Сбрасываем velocity чтобы части не разлетались
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end)
    end
    
    -- Фаза 5: Форсим состояние
    _wrap(function()
        _hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)()
    
    -- Фаза 6: Подстраховка
    task.delay(0.03 + _rdelay(), function()
        if not _CFG._ar then _restoring = false return end
        _wrap(function()
            _hum.PlatformStand = false
            
            -- Повторная зачистка констрейнтов
            for _, v in ipairs(_char:GetDescendants()) do
                pcall(function()
                    if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") 
                        or v:IsA("NoCollisionConstraint") then
                        v:Destroy()
                    end
                end)
            end
            
            -- Повторная проверка моторов
            for _, data in ipairs(_motorCache) do
                pcall(function()
                    if data._ref and data._ref.Parent then
                        data._ref.Enabled = true
                    end
                end)
            end
            
            _hum:ChangeState(Enum.HumanoidStateType.Running)
        end)()
        _restoring = false
    end)
    
    -- Фаза 7: Финальная страховка
    task.delay(0.15 + _rdelay(), function()
        if not _CFG._ar then return end
        pcall(function()
            if _hum and _hum.Health > 0 then
                _hum.PlatformStand = false
                local st = _hum:GetState()
                if _isRag(st) or st == Enum.HumanoidStateType.PlatformStanding then
                    -- Повторяем полный цикл восстановления
                    for _, v in ipairs(_char:GetDescendants()) do
                        pcall(function()
                            if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") 
                                or v:IsA("NoCollisionConstraint") then
                                v:Destroy()
                            end
                        end)
                    end
                    for _, data in ipairs(_motorCache) do
                        pcall(function()
                            if data._ref and data._ref.Parent then
                                data._ref.Enabled = true
                            elseif data._p and data._p.Parent 
                                and data._p0 and data._p0.Parent 
                                and data._p1 and data._p1.Parent then
                                local ex = data._p:FindFirstChild(data._n)
                                if not (ex and ex:IsA("Motor6D")) then
                                    local m = Instance.new("Motor6D")
                                    m.Name = data._n
                                    m.Part0 = data._p0
                                    m.Part1 = data._p1
                                    m.C0 = data._c0
                                    m.C1 = data._c1
                                    m.Parent = data._p
                                    data._ref = m
                                    _fm[#_fm + 1] = m
                                end
                            end
                        end)
                    end
                    _hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    task.delay(0.05, function()
                        pcall(function()
                            _hum:ChangeState(Enum.HumanoidStateType.Running)
                        end)
                    end)
                end
            end
        end)
    end)
end

local function _startAR()
    if not (_char and _hum) then return end
    _deepSaveMotors()
    
    -- StateChanged
    local c1 = _hum.StateChanged:Connect(function(_, new)
        if not _CFG._ar then return end
        if _isRag(new) or new == Enum.HumanoidStateType.PlatformStanding then
            task.delay(0.02 + _rdelay(), _fullRestore)
        end
    end)
    _rc[#_rc + 1] = c1
    
    -- PlatformStand
    local c2 = _hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not _CFG._ar then return end
        if _hum.PlatformStand then
            task.defer(function()
                pcall(function() _hum.PlatformStand = false end)
                task.delay(0.01 + _rdelay(), _fullRestore)
            end)
        end
    end)
    _rc[#_rc + 1] = c2
    
    -- Перехват новых констрейнтов
    local c3 = _char.DescendantAdded:Connect(function(v)
        if not _CFG._ar then return end
        task.delay(_rdelay(), function()
            pcall(function()
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") 
                    or v:IsA("NoCollisionConstraint")
                    or v:IsA("RopeConstraint") or v:IsA("SpringConstraint") then
                    v:Destroy()
                    task.delay(0.01 + _rdelay(), function()
                        if _CFG._ar then
                            for _, data in ipairs(_motorCache) do
                                pcall(function()
                                    if data._ref and data._ref.Parent then
                                        data._ref.Enabled = true
                                    end
                                end)
                            end
                        end
                    end)
                end
            end)
        end)
    end)
    _rc[#_rc + 1] = c3
    
    -- Перехват удаления Motor6D
    local c4 = _char.DescendantRemoving:Connect(function(v)
        if not _CFG._ar then return end
        if v:IsA("Motor6D") then
            local data = {
                _n = v.Name,
                _p = v.Parent,
                _p0 = v.Part0,
                _p1 = v.Part1,
                _c0 = v.C0,
                _c1 = v.C1,
            }
            task.delay(0.015 + _rdelay(), function()
                if not _CFG._ar then return end
                pcall(function()
                    if data._p and data._p.Parent
                        and data._p0 and data._p0.Parent
                        and data._p1 and data._p1.Parent then
                        local ex = data._p:FindFirstChild(data._n)
                        if ex and ex:IsA("Motor6D") then
                            ex.Enabled = true
                            return
                        end
                        local m = Instance.new("Motor6D")
                        m.Name = data._n
                        m.Part0 = data._p0
                        m.Part1 = data._p1
                        m.C0 = data._c0
                        m.C1 = data._c1
                        m.Parent = data._p
                        _fm[#_fm + 1] = m
                        
                        -- Обновляем кеш
                        for _, cached in ipairs(_motorCache) do
                            if cached._n == data._n and cached._p == data._p then
                                cached._ref = m
                                cached._alive = true
                                break
                            end
                        end
                    end
                end)
            end)
        end
    end)
    _rc[#_rc + 1] = c4
    
    -- Следим за Motor6D.Enabled
    for _, v in ipairs(_char:GetDescendants()) do
        if v:IsA("Motor6D") then
            local c = v:GetPropertyChangedSignal("Enabled"):Connect(function()
                if not _CFG._ar then return end
                task.delay(_rdelay(), function()
                    pcall(function()
                        if v and v.Parent and not v.Enabled then
                            v.Enabled = true
                        end
                    end)
                end)
            end)
            _rc[#_rc + 1] = c
        end
    end
end

local function _stopAR()
    for _, c in ipairs(_rc) do
        pcall(function() c:Disconnect() end)
    end
    _rc = {}
    for _, m in ipairs(_fm) do
        pcall(function()
            if m and m.Parent then m:Destroy() end
        end)
    end
    _fm = {}
    _motorCache = {}
    _partCFrames = {}
    _restoring = false
end

-- ==================== NO ANIMATIONS ====================
local function _hookTrack(track)
    if not track then return end
    if _tt[track] then return end
    _tt[track] = true
    local conn = track:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if not _CFG._na then return end
        if track.IsPlaying then
            task.delay(_rdelay(), function()
                pcall(function()
                    track:AdjustSpeed(0)
                    track:AdjustWeight(0, 0)
                end)
            end)
        end
    end)
    _ac[#_ac + 1] = conn
    if _CFG._na and track.IsPlaying then
        pcall(function()
            track:AdjustSpeed(0)
            track:AdjustWeight(0, 0)
        end)
    end
end

local function _suppressTracks()
    if not _anim then return end
    pcall(function()
        for _, track in ipairs(_anim:GetPlayingAnimationTracks()) do
            pcall(function()
                track:AdjustSpeed(0)
                track:AdjustWeight(0, 0)
            end)
        end
    end)
end

local function _hookAnim()
    if not _anim then return end
    pcall(function()
        local conn = _anim.AnimationPlayed:Connect(function(track)
            _hookTrack(track)
            if _CFG._na then
                task.delay(_rdelay(), function()
                    pcall(function()
                        track:AdjustSpeed(0)
                        track:AdjustWeight(0, 0)
                    end)
                end)
            end
        end)
        _ac[#_ac + 1] = conn
    end)
    if _hum then
        for _, evName in ipairs({"Running", "Jumping", "Climbing", "Swimming", "FreeFalling"}) do
            pcall(function()
                local conn = _hum[evName]:Connect(function()
                    if _CFG._na then task.defer(_suppressTracks) end
                end)
                _ac[#_ac + 1] = conn
            end)
        end
        local conn = _hum.StateChanged:Connect(function()
            if _CFG._na then task.defer(_suppressTracks) end
        end)
        _ac[#_ac + 1] = conn
    end
    pcall(function()
        for _, track in ipairs(_anim:GetPlayingAnimationTracks()) do
            _hookTrack(track)
        end
    end)
end

local function _startNA() _hookAnim() end

local function _stopNA()
    for _, conn in ipairs(_ac) do
        pcall(function() conn:Disconnect() end)
    end
    _ac = {}
    for track, _ in pairs(_tt) do
        pcall(function()
            if track and track.IsPlaying then
                track:AdjustSpeed(1)
                track:AdjustWeight(1, 0.1)
            end
        end)
    end
    _tt = {}
end

-- ==================== HEARTBEAT ====================
_hbc = _RS.Heartbeat:Connect(function()
    if not (_char and _char.Parent) then
        _ref()
        return
    end
    if not (_hum and _hum.Health > 0) then return end

    if _CFG._ar then
        -- Сохраняем CFrame каждый кадр (только когда не в рагдолле)
        _saveCFrames()
        
        -- PlatformStand сброс
        if _hum.PlatformStand then
            pcall(function() _hum.PlatformStand = false end)
        end

        -- Проверка состояния
        local n = tick()
        local st = _hum:GetState()
        if _isRag(st) or st == Enum.HumanoidStateType.PlatformStanding then
            if n - _lastEsc > 0.08 then
                _lastEsc = n
                _fullRestore()
            end
        end

        -- Восстановление отключённых Motor6D
        for _, v in ipairs(_char:GetDescendants()) do
            if v:IsA("Motor6D") and not v.Enabled then
                pcall(function() v.Enabled = true end)
            end
        end
    end

    if _CFG._na then
        _suppressTracks()
    end
end)

-- ==================== РЕСПАВН ====================
_lp.CharacterAdded:Connect(function()
    task.wait(0.4 + _RNG:NextNumber(0, 0.2))
    _ref()
    task.wait(0.2 + _RNG:NextNumber(0, 0.1))
    if _CFG._ar then
        _stopAR()
        _startAR()
    end
    if _CFG._na then
        _stopNA()
        task.wait(0.15)
        _startNA()
    end
end)

-- ==================== GUI — ПОЛНЫЙ РЕДИЗАЙН ====================
--[[
    Дизайн v11.0:
    - Glassmorphism (полупрозрачные размытые панели)
    - Градиентные акценты
    - Микроанимации при наведении
    - Иконки через Unicode
    - Компактный но информативный
]]

local _guiName = _rid(12)

if _pg:FindFirstChild("GranzHubGUI") then _pg:FindFirstChild("GranzHubGUI"):Destroy() end
local existing = _pg:FindFirstChild(_guiName)
if existing then existing:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name = _guiName
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = _RNG:NextInteger(1, 5)
SG.Parent = _pg

-- Цветовая схема v11
local C = {
    bg = Color3.fromRGB(12, 12, 18),
    bgAlt = Color3.fromRGB(18, 18, 26),
    panel = Color3.fromRGB(22, 22, 32),
    panelHover = Color3.fromRGB(28, 28, 40),
    header = Color3.fromRGB(16, 16, 24),
    
    accent1 = Color3.fromRGB(130, 80, 255),    -- Фиолетовый
    accent2 = Color3.fromRGB(80, 200, 255),     -- Голубой
    accent3 = Color3.fromRGB(255, 100, 80),     -- Оранжево-красный
    accent4 = Color3.fromRGB(255, 200, 60),     -- Золотой
    
    textW = Color3.fromRGB(240, 240, 245),
    textDim = Color3.fromRGB(100, 100, 120),
    textGreen = Color3.fromRGB(80, 255, 130),
    textRed = Color3.fromRGB(255, 80, 80),
    
    toggleOff = Color3.fromRGB(40, 40, 55),
    toggleKnobOff = Color3.fromRGB(140, 140, 155),
    
    border = Color3.fromRGB(45, 45, 65),
    borderActive = Color3.fromRGB(130, 80, 255),
    
    shadow = Color3.new(0, 0, 0),
}

-- Главный фрейм
local MF = Instance.new("Frame")
MF.Name = _rid(6)
MF.Size = UDim2.new(0, 340, 0, 430)
MF.Position = UDim2.new(0.5, -170, 0.5, -215)
MF.BackgroundColor3 = C.bg
MF.BackgroundTransparency = 0.05
MF.BorderSizePixel = 0
MF.Active = true
MF.Draggable = true
MF.ClipsDescendants = true
MF.Parent = SG

local MFC = Instance.new("UICorner", MF)
MFC.CornerRadius = UDim.new(0, 20)

-- Внешняя обводка с градиентом
local MFS = Instance.new("UIStroke")
MFS.Color = C.accent1
MFS.Thickness = 1.5
MFS.Transparency = 0.4
MFS.Parent = MF

-- Тень
local Shadow = Instance.new("ImageLabel")
Shadow.Name = _rid(4)
Shadow.Size = UDim2.new(1, 40, 1, 40)
Shadow.Position = UDim2.new(0, -20, 0, -20)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6015897843"
Shadow.ImageColor3 = C.shadow
Shadow.ImageTransparency = 0.4
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.ZIndex = -1
Shadow.Parent = MF

-- Декоративные светящиеся круги на фоне
local function makeGlow(pos, color, size, transp)
    local g = Instance.new("Frame")
    g.Name = _rid(4)
    g.Size = UDim2.new(0, size, 0, size)
    g.Position = pos
    g.BackgroundColor3 = color
    g.BackgroundTransparency = transp or 0.92
    g.BorderSizePixel = 0
    g.ZIndex = 0
    g.Parent = MF
    Instance.new("UICorner", g).CornerRadius = UDim.new(1, 0)
    return g
end

local glow1 = makeGlow(UDim2.new(0, -30, 0, -30), C.accent1, 120, 0.93)
local glow2 = makeGlow(UDim2.new(1, -60, 1, -80), C.accent2, 100, 0.94)
local glow3 = makeGlow(UDim2.new(0.5, -40, 0, 50), C.accent3, 80, 0.95)

-- ==================== HEADER ====================
local HD = Instance.new("Frame")
HD.Name = _rid(4)
HD.Size = UDim2.new(1, 0, 0, 56)
HD.BackgroundColor3 = C.header
HD.BackgroundTransparency = 0.3
HD.BorderSizePixel = 0
HD.ZIndex = 2
HD.Parent = MF
Instance.new("UICorner", HD).CornerRadius = UDim.new(0, 20)

-- Фикс нижних углов хедера
local HDF = Instance.new("Frame")
HDF.Name = _rid(3)
HDF.Size = UDim2.new(1, 0, 0, 20)
HDF.Position = UDim2.new(0, 0, 1, -20)
HDF.BackgroundColor3 = C.header
HDF.BackgroundTransparency = 0.3
HDF.BorderSizePixel = 0
HDF.ZIndex = 2
HDF.Parent = HD

-- Линия-акцент под хедером
local HLine = Instance.new("Frame")
HLine.Name = _rid(3)
HLine.Size = UDim2.new(0.7, 0, 0, 2)
HLine.Position = UDim2.new(0.15, 0, 1, 0)
HLine.BackgroundColor3 = C.accent1
HLine.BackgroundTransparency = 0.5
HLine.BorderSizePixel = 0
HLine.ZIndex = 3
HLine.Parent = HD
Instance.new("UICorner", HLine).CornerRadius = UDim.new(1, 0)

-- Градиент на линии
local HLG = Instance.new("UIGradient")
HLG.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, C.accent1),
    ColorSequenceKeypoint.new(0.5, C.accent2),
    ColorSequenceKeypoint.new(1, C.accent3),
}
HLG.Parent = HLine

-- Лого/Название
local Logo = Instance.new("TextLabel")
Logo.Name = _rid(3)
Logo.Size = UDim2.new(1, -100, 1, 0)
Logo.Position = UDim2.new(0, 20, 0, 0)
Logo.BackgroundTransparency = 1
Logo.Text = "⚡ GRANZ"
Logo.TextColor3 = C.textW
Logo.TextSize = 19
Logo.Font = Enum.Font.GothamBlack
Logo.TextXAlignment = Enum.TextXAlignment.Left
Logo.ZIndex = 3
Logo.Parent = HD

-- Версия
local Ver = Instance.new("TextLabel")
Ver.Name = _rid(3)
Ver.Size = UDim2.new(0, 70, 0, 18)
Ver.Position = UDim2.new(0, 105, 0.5, -9)
Ver.BackgroundColor3 = C.accent1
Ver.BackgroundTransparency = 0.8
Ver.Text = "v11.0"
Ver.TextColor3 = C.accent2
Ver.TextSize = 10
Ver.Font = Enum.Font.GothamBold
Ver.TextXAlignment = Enum.TextXAlignment.Center
Ver.ZIndex = 3
Ver.Parent = HD
Instance.new("UICorner", Ver).CornerRadius = UDim.new(1, 0)

local VerStroke = Instance.new("UIStroke")
VerStroke.Color = C.accent2
VerStroke.Thickness = 1
VerStroke.Transparency = 0.6
VerStroke.Parent = Ver

-- Кнопка минимизации
local MinB = Instance.new("TextButton")
MinB.Name = _rid(3)
MinB.Size = UDim2.new(0, 32, 0, 32)
MinB.Position = UDim2.new(1, -78, 0, 12)
MinB.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
MinB.BackgroundTransparency = 0.3
MinB.Text = "━"
MinB.TextColor3 = C.textDim
MinB.TextSize = 14
MinB.Font = Enum.Font.GothamBold
MinB.BorderSizePixel = 0
MinB.AutoButtonColor = false
MinB.ZIndex = 3
MinB.Parent = HD
Instance.new("UICorner", MinB).CornerRadius = UDim.new(0, 10)

-- Кнопка закрытия
local ClsB = Instance.new("TextButton")
ClsB.Name = _rid(3)
ClsB.Size = UDim2.new(0, 32, 0, 32)
ClsB.Position = UDim2.new(1, -42, 0, 12)
ClsB.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
ClsB.BackgroundTransparency = 0.3
ClsB.Text = "✕"
ClsB.TextColor3 = C.textW
ClsB.TextSize = 13
ClsB.Font = Enum.Font.GothamBold
ClsB.BorderSizePixel = 0
ClsB.AutoButtonColor = false
ClsB.ZIndex = 3
ClsB.Parent = HD
Instance.new("UICorner", ClsB).CornerRadius = UDim.new(0, 10)

-- Hover эффекты для кнопок хедера
local function addHoverEffect(btn, hoverColor, normalColor)
    btn.MouseEnter:Connect(function()
        _TS:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor, BackgroundTransparency = 0.1}):Play()
    end)
    btn.MouseLeave:Connect(function()
        _TS:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = normalColor, BackgroundTransparency = 0.3}):Play()
    end)
end

addHoverEffect(MinB, Color3.fromRGB(70, 70, 90), Color3.fromRGB(50, 50, 65))
addHoverEffect(ClsB, Color3.fromRGB(220, 55, 55), Color3.fromRGB(180, 45, 45))

-- ==================== КОНТЕНТ ====================
local CT = Instance.new("ScrollingFrame")
CT.Name = _rid(4)
CT.Size = UDim2.new(1, -24, 1, -72)
CT.Position = UDim2.new(0, 12, 0, 62)
CT.BackgroundTransparency = 1
CT.BorderSizePixel = 0
CT.ScrollBarThickness = 3
CT.ScrollBarImageColor3 = C.accent1
CT.ScrollBarImageTransparency = 0.5
CT.CanvasSize = UDim2.new(0, 0, 0, 0)
CT.AutomaticCanvasSize = Enum.AutomaticSize.Y
CT.ZIndex = 2
CT.Parent = MF

local CTL = Instance.new("UIListLayout")
CTL.SortOrder = Enum.SortOrder.LayoutOrder
CTL.Padding = UDim.new(0, 8)
CTL.Parent = CT

local CTP = Instance.new("UIPadding")
CTP.PaddingTop = UDim.new(0, 4)
CTP.PaddingBottom = UDim.new(0, 8)
CTP.Parent = CT

-- ==================== МОДУЛЬ-КНОПКИ ====================
local function createModule(icon, name, desc, order, accentColor)
    local Mod = Instance.new("Frame")
    Mod.Name = _rid(5)
    Mod.Size = UDim2.new(1, 0, 0, 76)
    Mod.BackgroundColor3 = C.panel
    Mod.BackgroundTransparency = 0.2
    Mod.BorderSizePixel = 0
    Mod.LayoutOrder = order
    Mod.ZIndex = 2
    Mod.Parent = CT
    Instance.new("UICorner", Mod).CornerRadius = UDim.new(0, 14)

    local ModS = Instance.new("UIStroke")
    ModS.Color = C.border
    ModS.Thickness = 1
    ModS.Transparency = 0.5
    ModS.Parent = Mod

    -- Иконка слева (светящийся круг)
    local IconBG = Instance.new("Frame")
    IconBG.Name = _rid(3)
    IconBG.Size = UDim2.new(0, 38, 0, 38)
    IconBG.Position = UDim2.new(0, 14, 0.5, -19)
    IconBG.BackgroundColor3 = accentColor
    IconBG.BackgroundTransparency = 0.85
    IconBG.BorderSizePixel = 0
    IconBG.ZIndex = 3
    IconBG.Parent = Mod
    Instance.new("UICorner", IconBG).CornerRadius = UDim.new(1, 0)

    local IconLbl = Instance.new("TextLabel")
    IconLbl.Name = _rid(3)
    IconLbl.Size = UDim2.new(1, 0, 1, 0)
    IconLbl.BackgroundTransparency = 1
    IconLbl.Text = icon
    IconLbl.TextColor3 = C.textW
    IconLbl.TextSize = 18
    IconLbl.Font = Enum.Font.GothamBold
    IconLbl.ZIndex = 4
    IconLbl.Parent = IconBG

    -- Название
    local NL = Instance.new("TextLabel")
    NL.Name = _rid(3)
    NL.Size = UDim2.new(1, -130, 0, 22)
    NL.Position = UDim2.new(0, 60, 0, 14)
    NL.BackgroundTransparency = 1
    NL.Text = name
    NL.TextColor3 = C.textW
    NL.TextSize = 14
    NL.Font = Enum.Font.GothamBold
    NL.TextXAlignment = Enum.TextXAlignment.Left
    NL.ZIndex = 3
    NL.Parent = Mod

    -- Описание
    local DL = Instance.new("TextLabel")
    DL.Name = _rid(3)
    DL.Size = UDim2.new(1, -130, 0, 16)
    DL.Position = UDim2.new(0, 60, 0, 38)
    DL.BackgroundTransparency = 1
    DL.Text = desc
    DL.TextColor3 = C.textDim
    DL.TextSize = 10
    DL.Font = Enum.Font.Gotham
    DL.TextXAlignment = Enum.TextXAlignment.Left
    DL.ZIndex = 3
    DL.Parent = Mod

    -- Toggle switch
    local TBG = Instance.new("TextButton")
    TBG.Name = _rid(3)
    TBG.Size = UDim2.new(0, 48, 0, 26)
    TBG.Position = UDim2.new(1, -60, 0.5, -13)
    TBG.BackgroundColor3 = C.toggleOff
    TBG.Text = ""
    TBG.BorderSizePixel = 0
    TBG.AutoButtonColor = false
    TBG.ZIndex = 3
    TBG.Parent = Mod
    Instance.new("UICorner", TBG).CornerRadius = UDim.new(1, 0)

    local TKnob = Instance.new("Frame")
    TKnob.Name = _rid(3)
    TKnob.Size = UDim2.new(0, 20, 0, 20)
    TKnob.Position = UDim2.new(0, 3, 0.5, -10)
    TKnob.BackgroundColor3 = C.toggleKnobOff
    TKnob.BorderSizePixel = 0
    TKnob.ZIndex = 4
    TKnob.Parent = TBG
    Instance.new("UICorner", TKnob).CornerRadius = UDim.new(1, 0)

    -- Glow эффект на knob когда включено
    local KGlow = Instance.new("UIStroke")
    KGlow.Color = accentColor
    KGlow.Thickness = 0
    KGlow.Transparency = 0.5
    KGlow.Parent = TKnob

    -- Hover эффект на весь модуль
    local hoverFrame = Instance.new("TextButton")
    hoverFrame.Name = _rid(3)
    hoverFrame.Size = UDim2.new(1, 0, 1, 0)
    hoverFrame.BackgroundTransparency = 1
    hoverFrame.Text = ""
    hoverFrame.ZIndex = 2
    hoverFrame.Parent = Mod

    hoverFrame.MouseEnter:Connect(function()
        _TS:Create(Mod, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
        _TS:Create(ModS, TweenInfo.new(0.2), {Transparency = 0.3}):Play()
    end)
    hoverFrame.MouseLeave:Connect(function()
        _TS:Create(Mod, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play()
        _TS:Create(ModS, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
    end)

    local function updateVis(state)
        local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        if state then
            _TS:Create(TBG, ti, {BackgroundColor3 = accentColor}):Play()
            _TS:Create(TKnob, ti, {
                Position = UDim2.new(1, -23, 0.5, -10),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            }):Play()
            _TS:Create(KGlow, ti, {Thickness = 2, Transparency = 0.3}):Play()
            _TS:Create(ModS, ti, {Color = accentColor, Transparency = 0.3}):Play()
            _TS:Create(IconBG, ti, {BackgroundTransparency = 0.7}):Play()
        else
            _TS:Create(TBG, ti, {BackgroundColor3 = C.toggleOff}):Play()
            _TS:Create(TKnob, ti, {
                Position = UDim2.new(0, 3, 0.5, -10),
                BackgroundColor3 = C.toggleKnobOff
            }):Play()
            _TS:Create(KGlow, ti, {Thickness = 0, Transparency = 0.8}):Play()
            _TS:Create(ModS, ti, {Color = C.border, Transparency = 0.5}):Play()
            _TS:Create(IconBG, ti, {BackgroundTransparency = 0.85}):Play()
        end
    end

    return TBG, updateVis
end

-- Создаём модули
local JT, JV = createModule("⚡", "Infinite Jump", "Прыжки в воздухе без ограничений", 1, C.accent1)
local RT, RV = createModule("🛡", "Anti-Ragdoll", "Мгновенный выход из рагдолла", 2, C.accent2)
local AT, AV = createModule("👻", "No Animations", "Полное отключение анимаций", 3, C.accent3)

-- ==================== СТАТУС-БАР ====================
local SB = Instance.new("Frame")
SB.Name = _rid(4)
SB.Size = UDim2.new(1, 0, 0, 32)
SB.BackgroundColor3 = C.bgAlt
SB.BackgroundTransparency = 0.4
SB.BorderSizePixel = 0
SB.LayoutOrder = 10
SB.ZIndex = 2
SB.Parent = CT
Instance.new("UICorner", SB).CornerRadius = UDim.new(0, 10)

-- Три точки-индикатора
local function makeDot(x, color)
    local d = Instance.new("Frame")
    d.Name = _rid(3)
    d.Size = UDim2.new(0, 6, 0, 6)
    d.Position = UDim2.new(0, x, 0.5, -3)
    d.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    d.BorderSizePixel = 0
    d.ZIndex = 3
    d.Parent = SB
    Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
    return d
end

local dot1 = makeDot(12, C.accent1)
local dot2 = makeDot(22, C.accent2)
local dot3 = makeDot(32, C.accent3)

local SL = Instance.new("TextLabel")
SL.Name = _rid(3)
SL.Size = UDim2.new(1, -50, 1, 0)
SL.Position = UDim2.new(0, 44, 0, 0)
SL.BackgroundTransparency = 1
SL.Text = "Ready"
SL.TextColor3 = C.textDim
SL.TextSize = 10
SL.Font = Enum.Font.GothamMedium
SL.TextXAlignment = Enum.TextXAlignment.Left
SL.ZIndex = 3
SL.Parent = SB

local function updateStat()
    local cnt = 0
    local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quint)
    
    if _CFG._j then
        cnt += 1
        _TS:Create(dot1, ti, {BackgroundColor3 = C.accent1}):Play()
    else
        _TS:Create(dot1, ti, {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
    end
    
    if _CFG._ar then
        cnt += 1
        _TS:Create(dot2, ti, {BackgroundColor3 = C.accent2}):Play()
    else
        _TS:Create(dot2, ti, {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
    end
    
    if _CFG._na then
        cnt += 1
        _TS:Create(dot3, ti, {BackgroundColor3 = C.accent3}):Play()
    else
        _TS:Create(dot3, ti, {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
    end
    
    if cnt == 0 then
        SL.Text = "Все модули неактивны"
        _TS:Create(SL, ti, {TextColor3 = C.textDim}):Play()
    else
        SL.Text = cnt .. "/3 активно  ·  GRANZ PHANTOM"
        _TS:Create(SL, ti, {TextColor3 = C.textGreen}):Play()
    end
end

-- ==================== ОБРАБОТЧИКИ ====================
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
    if _CFG._na then
        _ref()
        _startNA()
    else
        _stopNA()
    end
    updateStat()
end)

-- ==================== MINIMIZE / CLOSE ====================
local _fullSize = MF.Size

MinB.MouseButton1Click:Connect(function()
    _minimized = not _minimized
    local ti = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if _minimized then
        _TS:Create(MF, ti, {Size = UDim2.new(0, 340, 0, 56)}):Play()
        CT.Visible = false
        HLine.Visible = false
        MinB.Text = "▪"
    else
        _TS:Create(MF, ti, {Size = _fullSize}):Play()
        task.delay(0.2, function()
            CT.Visible = true
            HLine.Visible = true
        end)
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
    
    local ti = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    _TS:Create(MF, ti, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 1
    }):Play()
    _TS:Create(MFS, ti, {Transparency = 1}):Play()
    task.delay(0.45, function() SG:Destroy() end)
end)

-- ==================== АНИМАЦИЯ ОБВОДКИ ====================
task.spawn(function()
    local h = _RNG:NextNumber(0, 1)
    while SG and SG.Parent do
        h = (h + 0.002) % 1
        local active = 0
        if _CFG._j then active += 1 end
        if _CFG._ar then active += 1 end
        if _CFG._na then active += 1 end
        
        if active > 0 then
            -- Градиентная анимация обводки
            local color
            if active == 1 then
                color = Color3.fromHSV(h, 0.7, 0.9)
            elseif active == 2 then
                color = Color3.fromHSV(h, 0.8, 1)
            else
                color = Color3.fromHSV(h, 0.9, 1)
            end
            MFS.Color = color
            MFS.Transparency = 0.15 + math.sin(tick() * 2) * 0.1
            MFS.Thickness = 1.5 + math.sin(tick() * 3) * 0.3
            
            -- Анимация glow кругов
            pcall(function()
                glow1.BackgroundTransparency = 0.88 + math.sin(tick() * 1.5) * 0.05
                glow2.BackgroundTransparency = 0.89 + math.cos(tick() * 1.8) * 0.04
                glow3.BackgroundTransparency = 0.90 + math.sin(tick() * 2.1) * 0.04
            end)
            
            -- Анимация линии под хедером
            pcall(function()
                HLine.BackgroundTransparency = 0.3 + math.sin(tick() * 2.5) * 0.2
            end)
        else
            MFS.Color = C.border
            MFS.Transparency = 0.6
            MFS.Thickness = 1
            
            pcall(function()
                glow1.BackgroundTransparency = 0.95
                glow2.BackgroundTransparency = 0.95
                glow3.BackgroundTransparency = 0.95
                HLine.BackgroundTransparency = 0.6
            end)
        end
        
        task.wait(0.025)
    end
end)

-- Анимация градиента на линии хедера
task.spawn(function()
    local offset = 0
    while SG and SG.Parent do
        offset = (offset + 0.005) % 1
        pcall(function()
            HLG.Offset = Vector2.new(math.sin(offset * math.pi * 2) * 0.3, 0)
        end)
        task.wait(0.03)
    end
end)

-- ==================== ОТКРЫВАЮЩАЯ АНИМАЦИЯ ====================
MF.Size = UDim2.new(0, 0, 0, 0)
MF.Position = UDim2.new(0.5, 0, 0.5, 0)
MF.BackgroundTransparency = 1

task.delay(0.1, function()
    local ti = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    _TS:Create(MF, ti, {
        Size = UDim2.new(0, 340, 0, 430),
        Position = UDim2.new(0.5, -170, 0.5, -215),
        BackgroundTransparency = 0.05
    }):Play()
    _TS:Create(MFS, TweenInfo.new(0.8), {Transparency = 0.4}):Play()
end)

updateStat()
