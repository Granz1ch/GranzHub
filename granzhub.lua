--[[
    GRANZ HUB · TERMINATOR v18.0
]]

-- ═══════════ СЕРВИСЫ ═══════════
local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")

local LP    = Players.LocalPlayer
local PG    = LP:WaitForChild("PlayerGui")
local Cam   = workspace.CurrentCamera

-- ═══════════ АЛИАСЫ ═══════════
local _tWait   = task.wait
local _tDelay  = task.delay
local _tSpawn  = task.spawn
local _tDefer  = task.defer
local _pCall   = pcall
local _iNew    = Instance.new
local _v3      = Vector3.new
local _v3z     = Vector3.zero
local _cf      = CFrame.new
local _cfLA    = CFrame.lookAt
local _ud2     = UDim2.new
local _udim    = UDim.new
local _c3      = Color3.fromRGB
local _c3h     = Color3.fromHSV
local _csNew   = ColorSequence.new
local _csk     = ColorSequenceKeypoint.new
local _nsNew   = NumberSequence.new
local _nsk     = NumberSequenceKeypoint.new
local _twInfo  = TweenInfo.new
local _enumKC  = Enum.KeyCode
local _enumES  = Enum.EasingStyle
local _enumED  = Enum.EasingDirection
local _enumHS  = Enum.HumanoidStateType
local _enumUIT = Enum.UserInputType
local _mFloor  = math.floor
local _mSin    = math.sin
local _mCos    = math.cos
local _mAbs    = math.abs
local _mPi     = math.pi
local _mClamp  = math.clamp
local _mHuge   = math.huge
local _mSqrt   = math.sqrt
local _mAtan2  = math.atan2
local _mMax    = math.max
local _mMin    = math.min

-- ═══════════ КОНФИГ ═══════════
local CFG = {
    infJump      = false,
    jumpPower    = 50,
    jumpCooldown = 0.12,
    maxFallVel   = -60,
    speed        = false,
    speedValue   = 32,
    fly          = false,
    flySpeed     = 60,
    noclip       = false,
    lowGravity   = false,
    aimbot       = false,
    aimbotKey    = _enumKC.Q,
    aimbotFOV    = 200,
    aimbotSmooth = 0.18,
    aimbotPart   = "Head",
    silentAim    = false,
    hitboxExp    = false,
    hitboxSize   = 6,
    antiRagdoll  = false,
    godMode      = false,
    noAnim       = false,
    esp          = false,
    fullbright   = false,
    noFog        = false,
    chams        = false,
    tracers      = false,
    bigHead      = false,
}

-- ═══════════ СТЕЙТ ═══════════
local _lastJump     = 0
local _char, _hum, _rootPart, _animator
local _ragConns     = {}
local _animConns    = {}
local _heartbeatC
local _trackedAnims = {}
local _motorSnap    = {}
local _fabricMotors = {}
local _frameCount   = 0

local _ghostActive  = false
local _ghostPart    = nil
local _ghostMovers  = {}
local _ragActive    = false
local _ragStart     = 0
local _preRagCF     = nil
local _ghostCF      = nil
local _exitingRag   = false
local _ragTimeout   = 8
local _exitLock     = false
local _lastExitTime = 0

local _flyBV, _flyBG
local _flying = false

local _espObjects   = {}
local _chamObjects  = {}
local _tracerLines  = {}
local _noclipConn
local _godConn
local _origAmbient, _origBright, _origFogEnd, _origFogStart
local _origGravity  = workspace.Gravity
local _origSpeed    = 16
local _moduleConns  = {}

local _aimbotTarget   = nil
local _aimbotLocked   = false
local _hitboxParts    = {}
local _aimbotFOVPart  = nil

-- ═══════════ УТИЛИТЫ ═══════════
local function _sf(obj, name)
    if not obj then return nil end
    local ok, r = _pCall(function() return obj:FindFirstChild(name) end)
    return ok and r or nil
end

local function _sfc(obj, cls)
    if not obj then return nil end
    local ok, r = _pCall(function() return obj:FindFirstChildOfClass(cls) end)
    return ok and r or nil
end

local function _refreshChar()
    _char     = LP.Character
    if not _char then return false end
    _hum      = _sfc(_char, "Humanoid")
    _rootPart = _sf(_char, "HumanoidRootPart")
    _animator = _hum and _sfc(_hum, "Animator")
    return _hum ~= nil and _rootPart ~= nil
end
_refreshChar()

local function _safeCF()
    if _rootPart and _rootPart.Parent then
        local ok, cf = _pCall(function() return _rootPart.CFrame end)
        if ok then return cf end
    end
    return nil
end

local function _inFOV(pos)
    local sp, onScreen = Cam:WorldToViewportPoint(pos)
    if not onScreen then return false end
    local vp = Cam.ViewportSize
    local dx = sp.X - vp.X / 2
    local dy = sp.Y - vp.Y / 2
    return _mSqrt(dx * dx + dy * dy) <= CFG.aimbotFOV
end

-- ═══════════ AIMBOT ═══════════
local function _getPlayerPart(player)
    local ch = player.Character
    if not ch then return nil end
    return _sf(ch, CFG.aimbotPart) or _sf(ch, "HumanoidRootPart")
end

local function _isAlive(player)
    local ch = player.Character
    if not ch then return false end
    local h = _sfc(ch, "Humanoid")
    if not h then return false end
    return h.Health > 0
end

local function _getBestTarget()
    local bestDist = _mHuge
    local bestTarget = nil
    local vpCenter = Cam.ViewportSize / 2

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and _isAlive(p) then
            local part = _getPlayerPart(p)
            if part then
                local sp, onScreen = Cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dx = sp.X - vpCenter.X
                    local dy = sp.Y - vpCenter.Y
                    local dist = _mSqrt(dx * dx + dy * dy)
                    if dist < CFG.aimbotFOV and dist < bestDist then
                        bestDist = dist
                        bestTarget = p
                    end
                end
            end
        end
    end
    return bestTarget
end

local function _stepAimbot()
    if not CFG.aimbot then return end
    if not UIS:IsKeyDown(CFG.aimbotKey) then
        _aimbotLocked = false
        _aimbotTarget = nil
        return
    end

    if not _aimbotTarget or not _isAlive(_aimbotTarget) then
        _aimbotTarget = _getBestTarget()
        _aimbotLocked = _aimbotTarget ~= nil
    end

    if not _aimbotTarget then return end

    local part = _getPlayerPart(_aimbotTarget)
    if not (part and part.Parent) then
        _aimbotTarget = nil
        _aimbotLocked = false
        return
    end

    local camCF = Cam.CFrame
    local targetCF = _cfLA(camCF.Position, part.Position)
    local smooth = _mClamp(CFG.aimbotSmooth, 0.01, 1)
    _pCall(function() Cam.CFrame = camCF:Lerp(targetCF, smooth) end)
end

local function _expandHitboxes()
    _hitboxParts = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local ch = p.Character
            if ch then
                local head = _sf(ch, "Head")
                if head then
                    _pCall(function()
                        local orig = head.Size
                        head.Size = _v3(CFG.hitboxSize, CFG.hitboxSize, CFG.hitboxSize)
                        _hitboxParts[#_hitboxParts + 1] = {part = head, origSize = orig}
                    end)
                end
            end
        end
    end
end

local function _restoreHitboxes()
    for _, d in ipairs(_hitboxParts) do
        _pCall(function()
            if d.part and d.part.Parent then
                d.part.Size = d.origSize
            end
        end)
    end
    _hitboxParts = {}
end

local function _drawFOVCircle(sgRef)
    if _aimbotFOVPart then
        _pCall(function() _aimbotFOVPart:Destroy() end)
        _aimbotFOVPart = nil
    end

    local fovFrame = _iNew("Frame")
    fovFrame.Size = _ud2(0, CFG.aimbotFOV * 2, 0, CFG.aimbotFOV * 2)
    fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    fovFrame.Position = _ud2(0.5, 0, 0.5, 0)
    fovFrame.BackgroundTransparency = 1
    fovFrame.BorderSizePixel = 0
    fovFrame.ZIndex = 1
    fovFrame.Parent = sgRef

    local fovStroke = _iNew("UIStroke")
    fovStroke.Color = _c3(255, 50, 50)
    fovStroke.Thickness = 1.2
    fovStroke.Transparency = 0.3
    fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fovStroke.Parent = fovFrame

    local fovCorner = _iNew("UICorner")
    fovCorner.CornerRadius = _udim(0, CFG.aimbotFOV)
    fovCorner.Parent = fovFrame

    _aimbotFOVPart = fovFrame

    _tSpawn(function()
        while fovFrame and fovFrame.Parent and (CFG.aimbot or CFG.silentAim) do
            local locked = _aimbotLocked and _aimbotTarget ~= nil
            fovStroke.Color = locked and _c3(255, 50, 50) or _c3(255, 255, 255)
            fovStroke.Transparency = locked and 0.15 or 0.45
            _tWait(0.04)
        end
        _pCall(function() fovFrame:Destroy() end)
    end)
end

-- ═══════════ INFINITE JUMP ═══════════
local function _doJump()
    if not CFG.infJump then return end
    if not (_rootPart and _rootPart.Parent) then return end
    if _hum and _hum.Health <= 0 then return end

    local now = tick()
    if now - _lastJump < CFG.jumpCooldown then return end
    _lastJump = now

    local cv = _rootPart.AssemblyLinearVelocity
    _rootPart.AssemblyLinearVelocity = _v3(cv.X, CFG.jumpPower, cv.Z)
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == _enumKC.Space then
        if not _hum then return end
        if not _rootPart then return end
        local st = _hum:GetState()
        if st == _enumHS.Freefall or st == _enumHS.Jumping or st == _enumHS.FallingDown then
            _doJump()
        end
    end
end)

-- ═══════════ ANTI-RAGDOLL ═══════════
local _ragStates = {
    [_enumHS.Ragdoll]     = true,
    [_enumHS.FallingDown] = true,
    [_enumHS.Physics]     = true,
}

local function _isRagdoll(st) return _ragStates[st] == true end

local function _snapshotMotors()
    _motorSnap = {}
    if not _char then return end
    for _, v in ipairs(_char:GetDescendants()) do
        if v:IsA("Motor6D") then
            _motorSnap[#_motorSnap + 1] = {
                ref = v, name = v.Name, par = v.Parent,
                p0 = v.Part0, p1 = v.Part1, c0 = v.C0, c1 = v.C1,
            }
        end
    end
end

local function _restoreMotors()
    if not _char then return end
    for _, d in ipairs(_motorSnap) do
        _pCall(function()
            if d.ref and d.ref.Parent then d.ref.Enabled = true return end
            if not (d.par and d.par.Parent and d.p0 and d.p0.Parent and d.p1 and d.p1.Parent) then return end
            local ex = d.par:FindFirstChild(d.name)
            if ex and ex:IsA("Motor6D") then ex.Enabled = true d.ref = ex return end
            local m = _iNew("Motor6D")
            m.Name  = d.name
            m.Part0 = d.p0
            m.Part1 = d.p1
            m.C0    = d.c0
            m.C1    = d.c1
            m.Parent = d.par
            d.ref   = m
            _fabricMotors[#_fabricMotors + 1] = m
        end)
    end
end

local function _nukeConstraints()
    if not _char then return end
    local bad = {
        BallSocketConstraint=true, HingeConstraint=true,
        NoCollisionConstraint=true, RopeConstraint=true,
        SpringConstraint=true,
    }
    for _, v in ipairs(_char:GetDescendants()) do
        _pCall(function() if bad[v.ClassName] then v:Destroy() end end)
    end
end

local function _spawnGhost()
    if _ghostPart and _ghostPart.Parent then return end
    if not (_rootPart and _rootPart.Parent and _char) then return end

    local cf = _preRagCF or _rootPart.CFrame
    local g = _iNew("Part")
    g.Name = "GhostPart"
    g.Size = _v3(2, 2, 1)
    g.Transparency = 1
    g.CanCollide = false
    g.CanQuery = false
    g.CanTouch = false
    g.Anchored = false
    g.Massless = false
    g.CFrame = cf
    g.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
    g.Parent = workspace

    _ghostPart = g
    _ghostCF = cf

    local bv = _iNew("BodyVelocity")
    bv.MaxForce = _v3(15000, 0, 15000)
    bv.Velocity  = _v3z
    bv.P = 2500
    bv.Parent = g
    _ghostMovers.bv = bv

    local bg = _iNew("BodyGyro")
    bg.MaxTorque = _v3(0, 15000, 0)
    bg.P = 5000
    bg.D = 200
    bg.Parent = g
    _ghostMovers.bg = bg

    local bf = _iNew("BodyForce")
    bf.Force = _v3(0, g:GetMass() * workspace.Gravity * 0.18, 0)
    bf.Parent = g
    _ghostMovers.bf = bf

    _ghostActive = true
end

local function _controlGhost()
    if not _ghostActive then return end
    if not (_ghostPart and _ghostPart.Parent) then _ghostActive = false return end

    local camCF = Cam.CFrame
    local fwd = _v3(camCF.LookVector.X, 0, camCF.LookVector.Z)
    if fwd.Magnitude > 0.001 then fwd = fwd.Unit end
    local rgt = _v3(camCF.RightVector.X, 0, camCF.RightVector.Z)
    if rgt.Magnitude > 0.001 then rgt = rgt.Unit end

    local moveDir = _v3z
    if UIS:IsKeyDown(_enumKC.W) then moveDir = moveDir + fwd end
    if UIS:IsKeyDown(_enumKC.S) then moveDir = moveDir - fwd end
    if UIS:IsKeyDown(_enumKC.D) then moveDir = moveDir + rgt end
    if UIS:IsKeyDown(_enumKC.A) then moveDir = moveDir - rgt end

    local spd = 16
    _pCall(function() if _hum then spd = _hum.WalkSpeed end end)

    if moveDir.Magnitude > 0.01 then
        moveDir = moveDir.Unit * spd
        if _ghostMovers.bg then
            _pCall(function()
                _ghostMovers.bg.CFrame = _cfLA(_v3z, _v3(moveDir.X, 0, moveDir.Z))
            end)
        end
    end

    if _ghostMovers.bv then _ghostMovers.bv.Velocity = _v3(moveDir.X, 0, moveDir.Z) end
    _pCall(function() Cam.CameraSubject = _ghostPart end)
    _ghostCF = _ghostPart.CFrame
end

local function _killGhost(doTeleport)
    local finalCF = _ghostCF
    for _, v in pairs(_ghostMovers) do _pCall(function() v:Destroy() end) end
    _ghostMovers = {}
    if _ghostPart then _pCall(function() _ghostPart:Destroy() end) _ghostPart = nil end
    _pCall(function() if _hum then Cam.CameraSubject = _hum end end)
    _ghostActive = false

    if doTeleport and finalCF and _rootPart and _rootPart.Parent then
        _pCall(function()
            for _, v in ipairs(_char:GetDescendants()) do
                if v:IsA("BasePart") then
                    _pCall(function()
                        v.AssemblyLinearVelocity  = _v3z
                        v.AssemblyAngularVelocity = _v3z
                    end)
                end
            end
            _rootPart.CFrame = finalCF
            _rootPart.AssemblyLinearVelocity  = _v3z
            _rootPart.AssemblyAngularVelocity = _v3z
        end)
    end
    return finalCF
end

local function _exitRagdoll()
    if _exitLock or _exitingRag then return end
    local now = tick()
    if now - _lastExitTime < 1.5 then return end
    _exitLock = true
    _exitingRag = true
    _lastExitTime = now

    if not (_hum and _char and _rootPart) then
        _killGhost(false)
        _exitingRag = false
        _ragActive  = false
        _exitLock   = false
        return
    end
    if _hum.Health <= 0 then
        _killGhost(false)
        _exitingRag = false
        _ragActive  = false
        _exitLock   = false
        return
    end

    local finalCF = _killGhost(true)
    _pCall(function() _hum.PlatformStand = false end)
    _nukeConstraints()
    _restoreMotors()

    for _, v in ipairs(_char:GetDescendants()) do
        if v:IsA("BasePart") then _pCall(function() v.Anchored = false end) end
    end
    _pCall(function() _hum:ChangeState(_enumHS.GettingUp) end)

    _tDelay(0.1, function()
        if not CFG.antiRagdoll then _exitingRag=false _ragActive=false _exitLock=false return end
        _pCall(function()
            if _hum and _hum.Health > 0 then
                _hum.PlatformStand = false
                _nukeConstraints()
                _restoreMotors()
                if finalCF and _rootPart and _rootPart.Parent then
                    local dist = (_rootPart.Position - finalCF.Position).Magnitude
                    if dist > 4 then
                        for _, v in ipairs(_char:GetDescendants()) do
                            if v:IsA("BasePart") then
                                _pCall(function()
                                    v.AssemblyLinearVelocity  = _v3z
                                    v.AssemblyAngularVelocity = _v3z
                                end)
                            end
                        end
                        _rootPart.CFrame = finalCF
                    end
                end
                _hum:ChangeState(_enumHS.Running)
            end
        end)
    end)

    _tDelay(0.4, function()
        _pCall(function()
            if _hum and _hum.Health > 0 then
                _hum.PlatformStand = false
                local st = _hum:GetState()
                if _isRagdoll(st) or st == _enumHS.PlatformStanding then
                    _nukeConstraints()
                    _restoreMotors()
                    _hum:ChangeState(_enumHS.GettingUp)
                    _tDelay(0.08, function()
                        _pCall(function() _hum:ChangeState(_enumHS.Running) end)
                    end)
                end
                if not _ghostActive then Cam.CameraSubject = _hum end
            end
        end)
        _exitingRag = false
        _ragActive  = false
        _tDelay(0.8, function() _exitLock = false end)
    end)
end

local function _onRagdollStart()
    if _ragActive or _exitingRag or _exitLock then return end
    if not (_hum and _hum.Health > 0) then return end
    _preRagCF = _safeCF()
    _ragActive = true
    _ragStart  = tick()

    _tDelay(0.03, function()
        if not CFG.antiRagdoll then _ragActive=false return end
        if not _ragActive or _exitingRag or _exitLock then _ragActive=false return end
        if _hum and _hum.Health <= 0 then _ragActive=false return end
        _spawnGhost()
    end)
end

local function _checkRagdollEnd()
    if not _ragActive or _exitingRag or _exitLock then return end
    if not (_hum and _char) then return end
    if _hum.Health <= 0 then _killGhost(false) _ragActive=false return end
    if tick() - _ragStart > _ragTimeout then _exitRagdoll() return end

    local st = _hum:GetState()
    local ps = false
    _pCall(function() ps = _hum.PlatformStand end)
    if not _isRagdoll(st) and st ~= _enumHS.PlatformStanding and not ps then
        _tDelay(0.08, function()
            if not _ragActive or _exitingRag or _exitLock then return end
            if not _hum then return end
            if _hum.Health <= 0 then _killGhost(false) _ragActive=false return end
            local st2 = _hum:GetState()
            local ps2 = false
            _pCall(function() ps2 = _hum.PlatformStand end)
            if not _isRagdoll(st2) and st2 ~= _enumHS.PlatformStanding and not ps2 then
                _exitRagdoll()
            end
        end)
    end
end

_tSpawn(function()
    while true do
        _tWait(0.15)
        if _char and _hum and _rootPart and _rootPart.Parent then
            if not _ragActive and not _exitingRag and not _exitLock then
                if _hum.Health > 0 then
                    local st = _hum:GetState()
                    if not _isRagdoll(st) and st ~= _enumHS.PlatformStanding then
                        _preRagCF = _safeCF()
                    end
                end
            end
        end
    end
end)

local function _startAntiRagdoll()
    if not (_char and _hum) then return end
    _snapshotMotors()

    local c1 = _hum.StateChanged:Connect(function(_, ns)
        if not CFG.antiRagdoll or _exitLock then return end
        if _isRagdoll(ns) or ns == _enumHS.PlatformStanding then
            _tDelay(0, _onRagdollStart)
        end
    end)
    _ragConns[#_ragConns+1] = c1

    local c2 = _hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not CFG.antiRagdoll or _exitLock then return end
        if _hum.PlatformStand and not _ragActive then _tDelay(0, _onRagdollStart) end
    end)
    _ragConns[#_ragConns+1] = c2

    local c3 = _char.DescendantAdded:Connect(function(v)
        if not CFG.antiRagdoll or _exitLock then return end
        _tDelay(0, function()
            _pCall(function()
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                    if not _ragActive and not _exitingRag and not _exitLock then _onRagdollStart() end
                end
            end)
        end)
    end)
    _ragConns[#_ragConns+1] = c3

    local c4 = _char.DescendantRemoving:Connect(function(v)
        if not CFG.antiRagdoll or _exitLock then return end
        if v:IsA("Motor6D") then
            local data = {name=v.Name, par=v.Parent, p0=v.Part0, p1=v.Part1, c0=v.C0, c1=v.C1}
            local found = false
            for _, s in ipairs(_motorSnap) do
                if s.name == data.name and s.par == data.par then
                    s.c0=data.c0 s.c1=data.c1 found=true break
                end
            end
            if not found then _motorSnap[#_motorSnap+1] = data end
            if not _ragActive and not _exitingRag and not _exitLock then _onRagdollStart() end
        end
    end)
    _ragConns[#_ragConns+1] = c4
end

local function _stopAntiRagdoll()
    for _, c in ipairs(_ragConns) do _pCall(function() c:Disconnect() end) end
    _ragConns = {}
    _killGhost(false)
    _ragActive=false _exitingRag=false _exitLock=false
    for _, m in ipairs(_fabricMotors) do
        _pCall(function() if m and m.Parent then m:Destroy() end end)
    end
    _fabricMotors={} _motorSnap={}
end

-- ═══════════ NO ANIMATIONS ═══════════
local function _hookTrack(track)
    if not track or _trackedAnims[track] then return end
    _trackedAnims[track] = true
    local c = track:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if not CFG.noAnim then return end
        if track.IsPlaying then
            _pCall(function() track:AdjustSpeed(0) track:AdjustWeight(0, 0) end)
        end
    end)
    _animConns[#_animConns+1] = c
    if CFG.noAnim and track.IsPlaying then
        _pCall(function() track:AdjustSpeed(0) track:AdjustWeight(0, 0) end)
    end
end

local function _stopAllTracks()
    if not _animator then return end
    _pCall(function()
        for _, t in ipairs(_animator:GetPlayingAnimationTracks()) do
            _pCall(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
        end
    end)
end

local function _hookAnimator()
    if not _animator then return end
    _pCall(function()
        local c = _animator.AnimationPlayed:Connect(function(t)
            _hookTrack(t)
            if CFG.noAnim then
                _tDelay(0, function()
                    _pCall(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
                end)
            end
        end)
        _animConns[#_animConns+1] = c
    end)
    if _hum then
        local evts = {"Running","Jumping","Climbing","Swimming","FreeFalling"}
        for _, evt in ipairs(evts) do
            _pCall(function()
                local c = _hum[evt]:Connect(function()
                    if CFG.noAnim then _tDefer(_stopAllTracks) end
                end)
                _animConns[#_animConns+1] = c
            end)
        end
        local c = _hum.StateChanged:Connect(function()
            if CFG.noAnim then _tDefer(_stopAllTracks) end
        end)
        _animConns[#_animConns+1] = c
    end
    _pCall(function()
        for _, t in ipairs(_animator:GetPlayingAnimationTracks()) do _hookTrack(t) end
    end)
end

local function _startNoAnim() _hookAnimator() end
local function _stopNoAnim()
    for _, c in ipairs(_animConns) do _pCall(function() c:Disconnect() end) end
    _animConns = {}
    for t in pairs(_trackedAnims) do
        _pCall(function()
            if t and t.IsPlaying then t:AdjustSpeed(1) t:AdjustWeight(1, 0.1) end
        end)
    end
    _trackedAnims = {}
end

-- ═══════════ SPEED ═══════════
local function _startSpeed()
    _refreshChar()
    if _hum then _origSpeed = _hum.WalkSpeed _hum.WalkSpeed = CFG.speedValue end
end

local function _stopSpeed()
    if _hum then _hum.WalkSpeed = _origSpeed end
end

-- ═══════════ FLY ═══════════
local function _startFly()
    _refreshChar()
    if not (_rootPart and _hum) then return end
    _flying = true
    if _flyBV then _pCall(function() _flyBV:Destroy() end) end
    if _flyBG then _pCall(function() _flyBG:Destroy() end) end

    _flyBV = _iNew("BodyVelocity")
    _flyBV.MaxForce = _v3(1e5, 1e5, 1e5)
    _flyBV.Velocity  = _v3z
    _flyBV.P = 9000
    _flyBV.Parent = _rootPart

    _flyBG = _iNew("BodyGyro")
    _flyBG.MaxTorque = _v3(1e5, 1e5, 1e5)
    _flyBG.P = 9000
    _flyBG.D = 500
    _flyBG.Parent = _rootPart
end

local function _controlFly()
    if not _flying then return end
    if not (_flyBV and _flyBV.Parent and _flyBG and _flyBG.Parent) then return end
    if not (_rootPart and _rootPart.Parent) then return end

    local camCF = Cam.CFrame
    local moveDir = _v3z

    if UIS:IsKeyDown(_enumKC.W) then moveDir = moveDir + camCF.LookVector end
    if UIS:IsKeyDown(_enumKC.S) then moveDir = moveDir - camCF.LookVector end
    if UIS:IsKeyDown(_enumKC.A) then moveDir = moveDir - camCF.RightVector end
    if UIS:IsKeyDown(_enumKC.D) then moveDir = moveDir + camCF.RightVector end
    if UIS:IsKeyDown(_enumKC.Space) then
        moveDir = moveDir + _v3(0, 1, 0)
    end
    if UIS:IsKeyDown(_enumKC.LeftControl) or UIS:IsKeyDown(_enumKC.LeftShift) then
        moveDir = moveDir - _v3(0, 1, 0)
    end

    if moveDir.Magnitude > 0.01 then moveDir = moveDir.Unit * CFG.flySpeed end
    _flyBV.Velocity  = moveDir
    _flyBG.CFrame    = camCF
end

local function _stopFly()
    _flying = false
    if _flyBV then _pCall(function() _flyBV:Destroy() end) _flyBV = nil end
    if _flyBG then _pCall(function() _flyBG:Destroy() end) _flyBG = nil end
end

-- ═══════════ NOCLIP ═══════════
local function _startNoclip()
    if _noclipConn then _pCall(function() _noclipConn:Disconnect() end) end
    _noclipConn = RunService.Stepped:Connect(function()
        if not CFG.noclip then return end
        _pCall(function()
            if _char then
                for _, v in ipairs(_char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    end)
end

local function _stopNoclip()
    if _noclipConn then _pCall(function() _noclipConn:Disconnect() end) _noclipConn = nil end
    _pCall(function()
        if _char then
            for _, v in ipairs(_char:GetDescendants()) do
                if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                    v.CanCollide = true
                end
            end
        end
    end)
end

-- ═══════════ ESP ═══════════
local function _createESP(player)
    if player == LP then return end

    local function makeHighlight()
        local ch = player.Character
        if not ch then return end

        if _espObjects[player] then
            for _, obj in ipairs(_espObjects[player]) do _pCall(function() obj:Destroy() end) end
        end
        _espObjects[player] = {}

        local hl = _iNew("Highlight")
        hl.FillColor = _c3(255, 50, 50)
        hl.FillTransparency = 0.65
        hl.OutlineColor = _c3(255, 255, 255)
        hl.OutlineTransparency = 0.15
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = ch
        hl.Parent = ch

        local bbg = _iNew("BillboardGui")
        bbg.Size = _ud2(0, 130, 0, 36)
        bbg.StudsOffset = _v3(0, 3.8, 0)
        bbg.AlwaysOnTop = true
        bbg.Adornee = _sf(ch, "Head") or _sf(ch, "HumanoidRootPart")
        bbg.Parent = ch

        local nameTag = _iNew("TextLabel")
        nameTag.Size = _ud2(1, 0, 0.55, 0)
        nameTag.BackgroundTransparency = 1
        nameTag.Text = player.DisplayName
        nameTag.TextColor3 = _c3(255, 255, 255)
        nameTag.TextStrokeTransparency = 0.25
        nameTag.TextSize = 13
        nameTag.Font = Enum.Font.GothamBold
        nameTag.Parent = bbg

        local distTag = _iNew("TextLabel")
        distTag.Size = _ud2(1, 0, 0.3, 0)
        distTag.Position = _ud2(0, 0, 0.55, 0)
        distTag.BackgroundTransparency = 1
        distTag.Text = ""
        distTag.TextColor3 = _c3(200, 200, 200)
        distTag.TextStrokeTransparency = 0.3
        distTag.TextSize = 10
        distTag.Font = Enum.Font.Gotham
        distTag.Parent = bbg

        local hpBG = _iNew("Frame")
        hpBG.Size = _ud2(0.7, 0, 0, 4)
        hpBG.Position = _ud2(0.15, 0, 1, 2)
        hpBG.BackgroundColor3 = _c3(20, 20, 20)
        hpBG.BorderSizePixel = 0
        hpBG.Parent = bbg
        local hc = _iNew("UICorner") hc.CornerRadius = _udim(0, 2) hc.Parent = hpBG

        local hpFill = _iNew("Frame")
        hpFill.Size = _ud2(1, 0, 1, 0)
        hpFill.BackgroundColor3 = _c3(50, 255, 100)
        hpFill.BorderSizePixel = 0
        hpFill.Parent = hpBG
        local hfc = _iNew("UICorner") hfc.CornerRadius = _udim(0, 2) hfc.Parent = hpFill

        _espObjects[player] = {hl, bbg}

        _tSpawn(function()
            while CFG.esp and bbg and bbg.Parent and ch and ch.Parent do
                _pCall(function()
                    if _rootPart and _rootPart.Parent then
                        local hrp = _sf(ch, "HumanoidRootPart")
                        if hrp then
                            local dist = (_rootPart.Position - hrp.Position).Magnitude
                            distTag.Text = _mFloor(dist) .. " studs"
                        end
                    end
                    local h2 = _sfc(ch, "Humanoid")
                    if h2 then
                        local ratio = _mClamp(h2.Health / h2.MaxHealth, 0, 1)
                        hpFill.Size = _ud2(ratio, 0, 1, 0)
                        if ratio > 0.6 then hpFill.BackgroundColor3 = _c3(50, 255, 100)
                        elseif ratio > 0.3 then hpFill.BackgroundColor3 = _c3(255, 200, 50)
                        else hpFill.BackgroundColor3 = _c3(255, 50, 50) end

                        hl.OutlineColor = (_aimbotTarget == player) and _c3(255, 50, 50) or _c3(255, 255, 255)
                    end
                end)
                _tWait(0.12)
            end
        end)
    end

    if player.Character then makeHighlight() end
    local conn = player.CharacterAdded:Connect(function()
        _tWait(0.5)
        if CFG.esp then makeHighlight() end
    end)
    _moduleConns[#_moduleConns+1] = conn
end

local function _startESP()
    for _, p in ipairs(Players:GetPlayers()) do _createESP(p) end
    local conn = Players.PlayerAdded:Connect(function(p)
        if CFG.esp then _createESP(p) end
    end)
    _moduleConns[#_moduleConns+1] = conn
end

local function _stopESP()
    for _, objs in pairs(_espObjects) do
        for _, obj in ipairs(objs) do _pCall(function() obj:Destroy() end) end
    end
    _espObjects = {}
end

-- ═══════════ CHAMS ═══════════
local function _startChams()
    _tSpawn(function()
        while CFG.chams do
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    local ch = p.Character
                    if ch then
                        _pCall(function()
                            if _chamObjects[p] then return end
                            local hl = _iNew("Highlight")
                            hl.FillColor = _c3h((_frameCount * 0.01) % 1, 0.8, 1)
                            hl.FillTransparency = 0.3
                            hl.OutlineColor = _c3(255, 255, 255)
                            hl.OutlineTransparency = 0
                            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            hl.Adornee = ch
                            hl.Parent = ch
                            _chamObjects[p] = hl
                        end)
                    end
                end
            end
            _tWait(0.5)
        end
    end)
end

local function _stopChams()
    for _, hl in pairs(_chamObjects) do
        _pCall(function() if hl and hl.Parent then hl:Destroy() end end)
    end
    _chamObjects = {}
end

-- ═══════════ TRACERS ═══════════
local _tracerGui = nil

local function _startTracers(sgRef)
    if _tracerGui then _pCall(function() _tracerGui:Destroy() end) end

    _tracerGui = _iNew("ScrollingFrame")
    _tracerGui.Size = _ud2(1, 0, 1, 0)
    _tracerGui.BackgroundTransparency = 1
    _tracerGui.ZIndex = 1
    _tracerGui.ScrollBarThickness = 0
    _tracerGui.Parent = sgRef

    _tSpawn(function()
        while CFG.tracers and _tracerGui and _tracerGui.Parent do
            for _, v in ipairs(_tracerGui:GetChildren()) do
                _pCall(function() v:Destroy() end)
            end

            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and _isAlive(p) then
                    _pCall(function()
                        local part = _getPlayerPart(p)
                        if not (part and part.Parent) then return end

                        local sp, onScreen = Cam:WorldToViewportPoint(part.Position)
                        if not onScreen then return end

                        local vp = Cam.ViewportSize
                        local startX = vp.X / 2
                        local startY = vp.Y

                        local dx = sp.X - startX
                        local dy = sp.Y - startY
                        local len = _mSqrt(dx * dx + dy * dy)
                        local angle = _mAtan2(dy, dx)

                        local line = _iNew("Frame")
                        line.Size = _ud2(0, len, 0, 1.5)
                        line.Position = _ud2(0, startX, 0, startY)
                        line.AnchorPoint = Vector2.new(0, 0.5)
                        line.BackgroundColor3 = (_aimbotTarget == p) and _c3(255, 50, 50) or _c3(255, 200, 50)
                        line.BackgroundTransparency = 0.25
                        line.BorderSizePixel = 0
                        line.Rotation = math.deg(angle)
                        line.ZIndex = 2
                        line.Parent = _tracerGui
                    end)
                end
            end
            _tWait(0.03)
        end
        _pCall(function() if _tracerGui then _tracerGui:Destroy() end end)
        _tracerGui = nil
    end)
end

local function _stopTracers()
    if _tracerGui then _pCall(function() _tracerGui:Destroy() end) _tracerGui = nil end
    _tracerLines = {}
end

-- ═══════════ GOD MODE ═══════════
local function _startGodMode()
    _refreshChar()
    if not _hum then return end
    if _godConn then _pCall(function() _godConn:Disconnect() end) end
    _godConn = _hum:GetPropertyChangedSignal("Health"):Connect(function()
        if CFG.godMode and _hum then
            _pCall(function() _hum.Health = _hum.MaxHealth end)
        end
    end)
    _pCall(function() _hum.Health = _hum.MaxHealth end)
end

local function _stopGodMode()
    if _godConn then _pCall(function() _godConn:Disconnect() end) _godConn = nil end
end

-- ═══════════ FULLBRIGHT ═══════════
local function _startFullbright()
    _pCall(function()
        _origAmbient = Lighting.Ambient
        _origBright  = Lighting.Brightness
        Lighting.Ambient    = _c3(255, 255, 255)
        Lighting.Brightness = 2
    end)
end

local function _stopFullbright()
    _pCall(function()
        if _origAmbient then Lighting.Ambient    = _origAmbient end
        if _origBright  then Lighting.Brightness = _origBright  end
    end)
end

-- ═══════════ NO FOG ═══════════
local function _startNoFog()
    _pCall(function()
        _origFogEnd   = Lighting.FogEnd
        _origFogStart = Lighting.FogStart
        Lighting.FogEnd   = 1e10
        Lighting.FogStart = 1e10
    end)
end

local function _stopNoFog()
    _pCall(function()
        if _origFogEnd   then Lighting.FogEnd   = _origFogEnd   end
        if _origFogStart then Lighting.FogStart = _origFogStart end
    end)
end

-- ═══════════ LOW GRAVITY ═══════════
local function _startLowGravity()
    _origGravity = workspace.Gravity
    workspace.Gravity = 45
end

local function _stopLowGravity()
    workspace.Gravity = _origGravity
end

-- ═══════════ BIG HEAD ═══════════
local function _startBigHead()
    _tSpawn(function()
        while CFG.bigHead do
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    _pCall(function()
                        local head = _sf(p.Character, "Head")
                        if head then
                            head.Size = _v3(CFG.hitboxSize + 2, CFG.hitboxSize + 2, CFG.hitboxSize + 2)
                        end
                    end)
                end
            end
            _tWait(0.5)
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                _pCall(function()
                    local head = _sf(p.Character, "Head")
                    if head then head.Size = _v3(2, 1, 1) end
                end)
            end
        end
    end)
end

-- ═══════════ HEARTBEAT ═══════════
_heartbeatC = RunService.Heartbeat:Connect(function()
    _frameCount = _frameCount + 1

    if not (_char and _char.Parent) then _refreshChar() return end
    if not (_hum and _hum.Health > 0) then
        if _ghostActive then _killGhost(false) _ragActive = false end
        return
    end

    if CFG.antiRagdoll and _ghostActive then _controlGhost() end
    if CFG.antiRagdoll and _frameCount % 3 == 0 then
        _checkRagdollEnd()
        if _ragActive and not _exitingRag and not _exitLock and not (_ghostPart and _ghostPart.Parent) then
            _ghostActive = false
            local st = _hum:GetState()
            local ps = false
            _pCall(function() ps = _hum.PlatformStand end)
            if _isRagdoll(st) or st == _enumHS.PlatformStanding or ps then
                _spawnGhost()
            else
                _ragActive = false
            end
        end
    end

    if CFG.noAnim and _frameCount % 3 == 0 then _stopAllTracks() end
    if CFG.fly then _controlFly() end
    if CFG.speed and _hum and _frameCount % 12 == 0 then
        _pCall(function() _hum.WalkSpeed = CFG.speedValue end)
    end

    if (CFG.aimbot or CFG.silentAim) and _frameCount % 2 == 0 then
        _stepAimbot()
    end

    if CFG.hitboxExp and _frameCount % 30 == 0 then
        _expandHitboxes()
    end

    if CFG.chams and _frameCount % 8 == 0 then
        local h = (_frameCount * 0.003) % 1
        for _, hl in pairs(_chamObjects) do
            _pCall(function() hl.FillColor = _c3h(h, 0.8, 1) end)
        end
    end
end)

-- ═══════════ RESPAWN ═══════════
LP.CharacterAdded:Connect(function()
    _tWait(0.4)
    _killGhost(false)
    _ragActive=false _exitingRag=false _exitLock=false _preRagCF=nil
    _stopFly()
    _refreshChar()
    _tWait(0.2)
    if CFG.antiRagdoll then _stopAntiRagdoll() _startAntiRagdoll() end
    if CFG.noAnim then _stopNoAnim() _tWait(0.12) _startNoAnim() end
    if CFG.speed then _startSpeed() end
    if CFG.fly then _startFly() end
    if CFG.noclip then _startNoclip() end
    if CFG.godMode then _startGodMode() end
    if CFG.hitboxExp then _expandHitboxes() end
end)

-- ══════════════════════════════════════════════════
-- ══════════ GUI v18.0
-- ══════════════════════════════════════════════════

-- Удаляем старые копии
for _, g in ipairs(PG:GetChildren()) do
    _pCall(function()
        if g:IsA("ScreenGui") and g:GetAttribute("_txTag") then g:Destroy() end
    end)
end

local SG = _iNew("ScreenGui")
SG.Name = "GranzHub"
SG:SetAttribute("_txTag", true)
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 5
SG.IgnoreGuiInset = false
SG.Parent = PG

-- ═══ ПАЛИТРА ═══
local P = {
    bg       = _c3(4, 4, 12),
    bgCard   = _c3(8, 8, 22),
    bgDeep   = _c3(3, 3, 9),
    header   = _c3(6, 6, 18),
    acc1  = _c3(130, 80, 255),
    acc2  = _c3(40, 195, 255),
    acc3  = _c3(255, 45, 85),
    acc4  = _c3(255, 195, 55),
    acc5  = _c3(55, 255, 150),
    acc6  = _c3(255, 110, 220),
    acc7  = _c3(255, 130, 50),
    acc8  = _c3(100, 210, 255),
    textW = _c3(240, 240, 252),
    textD = _c3(55, 55, 85),
    textG = _c3(55, 255, 130),
    tOff  = _c3(16, 16, 30),
    tKnob = _c3(75, 75, 100),
    bord  = _c3(22, 22, 44),
}

-- ═══ ХЕЛПЕРЫ ═══
local function corner(p, r)
    local c = _iNew("UICorner")
    c.CornerRadius = _udim(0, r or 12)
    c.Parent = p
    return c
end

local function stroke(p, col, thick, tr)
    local s = _iNew("UIStroke")
    s.Color = col or P.bord
    s.Thickness = thick or 1
    s.Transparency = tr or 0.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function ti(dur, style, dir)
    return _twInfo(dur or 0.3, style or _enumES.Quint, dir or _enumED.Out)
end

local function tw(obj, info, props)
    return TweenService:Create(obj, info, props)
end

local function grad(p, colors, rot, trans)
    local g = _iNew("UIGradient")
    g.Color = colors or _csNew{_csk(0, P.acc1), _csk(1, P.acc2)}
    if rot   then g.Rotation = rot end
    if trans then g.Transparency = trans end
    g.Parent = p
    return g
end

-- ═══ DRAG ═══
local function makeDraggable(frame, handle)
    local dragging, dragStart, startPos = false
    handle = handle or frame
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == _enumUIT.MouseButton1 or
           input.UserInputType == _enumUIT.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == _enumUIT.MouseMovement or
                         input.UserInputType == _enumUIT.Touch) then
            local delta = input.Position - dragStart
            tw(frame, ti(0.05, _enumES.Quad), {
                Position = _ud2(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            }):Play()
        end
    end)
end

-- ═══ ГЛАВНЫЙ ФРЕЙМ ═══
local MF = _iNew("Frame")
MF.Size = _ud2(0, 460, 0, 660)
MF.Position = _ud2(0.5, -230, 0.5, -330)
MF.BackgroundColor3 = P.bg
MF.BackgroundTransparency = 0.01
MF.BorderSizePixel = 0
MF.Active = true
MF.ClipsDescendants = true
MF.Parent = SG
corner(MF, 20)

local mainStroke = stroke(MF, P.acc1, 1.5, 0.5)

-- Aurora orbs
local auroraOrbs = {}
local auroraData = {
    {_ud2(0,-100,0,-100), P.acc1, 300, 0.90},
    {_ud2(1,-140,1,-170), P.acc2, 280, 0.90},
    {_ud2(0.08,0,0.22,0), P.acc6, 200, 0.92},
    {_ud2(0.9,0,0.02,0),  P.acc5, 170, 0.93},
    {_ud2(0.42,-90,0.55,0),P.acc3, 220, 0.91},
    {_ud2(0,0,0.88,0),    P.acc4, 140, 0.94},
    {_ud2(0.68,0,0.1,0),  P.acc1, 120, 0.95},
    {_ud2(0.22,0,0.95,0), P.acc2, 110, 0.95},
    {_ud2(0.5,0,0.02,0),  P.acc7, 90,  0.96},
}
for i, od in ipairs(auroraData) do
    local o = _iNew("Frame")
    o.Size = _ud2(0, od[3], 0, od[3])
    o.Position = od[1]
    o.BackgroundColor3 = od[2]
    o.BackgroundTransparency = od[4]
    o.BorderSizePixel = 0
    o.ZIndex = 0
    o.Parent = MF
    corner(o, math.floor(od[3]/2))
    auroraOrbs[i] = o
end

-- ═══ ХЕДЕР ═══
local HD = _iNew("Frame")
HD.Size = _ud2(1, 0, 0, 80)
HD.BackgroundColor3 = P.header
HD.BackgroundTransparency = 0.02
HD.BorderSizePixel = 0
HD.ZIndex = 5
HD.Parent = MF
corner(HD, 20)

local HDP = _iNew("Frame")
HDP.Size = _ud2(1, 0, 0, 26)
HDP.Position = _ud2(0, 0, 1, -26)
HDP.BackgroundColor3 = P.header
HDP.BackgroundTransparency = 0.02
HDP.BorderSizePixel = 0
HDP.ZIndex = 5
HDP.Parent = HD

makeDraggable(MF, HD)

-- Separator line
local sepLine = _iNew("Frame")
sepLine.Size = _ud2(0.96, 0, 0, 2.5)
sepLine.Position = _ud2(0.02, 0, 1, 0)
sepLine.BackgroundColor3 = P.textW
sepLine.BackgroundTransparency = 0.05
sepLine.BorderSizePixel = 0
sepLine.ZIndex = 6
sepLine.Parent = HD
corner(sepLine, 2)

local sepGrad = grad(sepLine, _csNew{
    _csk(0, P.acc1), _csk(0.15, P.acc2), _csk(0.3, P.acc5),
    _csk(0.5, P.acc4), _csk(0.7, P.acc6), _csk(0.85, P.acc3), _csk(1, P.acc1),
})
sepGrad.Transparency = _nsNew{_nsk(0,0.9),_nsk(0.08,0),_nsk(0.92,0),_nsk(1,0.9)}

_tSpawn(function()
    local off = 0
    while SG and SG.Parent do
        off = (off + 0.001) % 1
        _pCall(function()
            sepGrad.Offset = Vector2.new(_mSin(off * _mPi * 2) * 0.3, 0)
        end)
        _tWait(0.02)
    end
end)

-- Логотип
local logoCont = _iNew("Frame")
logoCont.Size = _ud2(0, 60, 0, 60)
logoCont.Position = _ud2(0, 12, 0.5, -30)
logoCont.BackgroundTransparency = 1
logoCont.ZIndex = 6
logoCont.Parent = HD

local logoRings = {}
local ringDat = {{60,0.73,22},{48,0.77,16},{38,0.81,12}}
for i, rd in ipairs(ringDat) do
    local ring = _iNew("Frame")
    ring.Size = _ud2(0, rd[1], 0, rd[1])
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = _ud2(0.5, 0, 0.5, 0)
    ring.BackgroundColor3 = P.acc1
    ring.BackgroundTransparency = rd[2]
    ring.BorderSizePixel = 0
    ring.ZIndex = 6+i
    ring.Parent = logoCont
    corner(ring, math.floor(rd[1]/2))
    if i < 3 then stroke(ring, P.acc1, 0.6, 0.4+i*0.1) end
    logoRings[i] = ring
end

local logoGlow = _iNew("Frame")
logoGlow.Size = _ud2(0, 24, 0, 24)
logoGlow.AnchorPoint = Vector2.new(0.5, 0.5)
logoGlow.Position = _ud2(0.5, 0, 0.5, 0)
logoGlow.BackgroundColor3 = P.acc1
logoGlow.BackgroundTransparency = 0.3
logoGlow.ZIndex = 10
logoGlow.Parent = logoCont
corner(logoGlow, 12)

local logoTxt = _iNew("TextLabel")
logoTxt.Size = _ud2(1, 0, 1, 0)
logoTxt.BackgroundTransparency = 1
logoTxt.Text = "T"
logoTxt.TextColor3 = P.textW
logoTxt.TextSize = 17
logoTxt.Font = Enum.Font.GothamBlack
logoTxt.ZIndex = 11
logoTxt.Parent = logoRings[3]

-- Заголовок
local titleLbl = _iNew("TextLabel")
titleLbl.Size = _ud2(0, 220, 0, 28)
titleLbl.Position = _ud2(0, 84, 0, 8)
titleLbl.BackgroundTransparency = 1
titleLbl.RichText = true
titleLbl.Text = '<font color="#8250FF">GRANZ</font> <font color="#FFFFFF">HUB</font>'
titleLbl.TextSize = 22
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 6
titleLbl.Parent = HD

local subLbl = _iNew("TextLabel")
subLbl.Size = _ud2(0, 300, 0, 14)
subLbl.Position = _ud2(0, 84, 0, 38)
subLbl.BackgroundTransparency = 1
subLbl.Text = "terminator · v18.0 · unified"
subLbl.TextColor3 = P.textD
subLbl.TextSize = 9
subLbl.Font = Enum.Font.GothamMedium
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.ZIndex = 6
subLbl.Parent = HD

-- Бейджи
local badgeDat = {
    {"TERMINATOR", P.acc1},
    {"v18.0",      P.acc5},
    {"AIMBOT",     P.acc3},
    {"15 MODS",    P.acc4},
}
local bx = 84
for _, bd in ipairs(badgeDat) do
    local bf2 = _iNew("Frame")
    bf2.Size = _ud2(0, #bd[1]*5.2+16, 0, 17)
    bf2.Position = _ud2(0, bx, 0, 56)
    bf2.BackgroundColor3 = bd[2]
    bf2.BackgroundTransparency = 0.87
    bf2.BorderSizePixel = 0
    bf2.ZIndex = 6
    bf2.Parent = HD
    corner(bf2, 6)
    stroke(bf2, bd[2], 0.5, 0.55)

    local bl2 = _iNew("TextLabel")
    bl2.Size = _ud2(1, 0, 1, 0)
    bl2.BackgroundTransparency = 1
    bl2.Text = bd[1]
    bl2.TextColor3 = bd[2]
    bl2.TextSize = 6.5
    bl2.Font = Enum.Font.GothamBlack
    bl2.ZIndex = 7
    bl2.Parent = bf2

    bx = bx + #bd[1]*5.2+20
end

-- Кнопки хедера
local function makeHdrBtn(pos, text, col)
    local btn = _iNew("TextButton")
    btn.Size = _ud2(0, 36, 0, 36)
    btn.Position = pos
    btn.BackgroundColor3 = col
    btn.BackgroundTransparency = 0.5
    btn.Text = text
    btn.TextColor3 = P.textW
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.ZIndex = 6
    btn.Parent = HD
    corner(btn, 11)
    btn.MouseEnter:Connect(function() tw(btn, ti(0.2), {BackgroundTransparency=0.1}):Play() end)
    btn.MouseLeave:Connect(function() tw(btn, ti(0.2), {BackgroundTransparency=0.5}):Play() end)
    return btn
end

local MinBtn = makeHdrBtn(_ud2(1,-88,0,22), "━", _c3(30,30,50))
local ClsBtn = makeHdrBtn(_ud2(1,-48,0,22), "✕", _c3(140,22,35))

-- ═══ ТАБЫ ═══
local currentTab = "combat"
local tabButtons  = {}
local tabContents = {}

local tabBar = _iNew("Frame")
tabBar.Size = _ud2(1, -12, 0, 36)
tabBar.Position = _ud2(0, 6, 0, 84)
tabBar.BackgroundColor3 = P.bgDeep
tabBar.BackgroundTransparency = 0.25
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 4
tabBar.Parent = MF
corner(tabBar, 11)

local tabLayout = _iNew("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = _udim(0, 3)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
tabLayout.Parent = tabBar

local tabPad = _iNew("UIPadding")
tabPad.PaddingLeft  = _udim(0, 3)
tabPad.PaddingRight = _udim(0, 3)
tabPad.Parent = tabBar

local tabsDef = {
    {id="combat",   icon="🎯", name="Combat",   color=P.acc3},
    {id="movement", icon="🏃", name="Movement", color=P.acc1},
    {id="visual",   icon="👁️", name="Visual",   color=P.acc2},
    {id="world",    icon="🌍", name="World",    color=P.acc5},
    {id="aimbot",   icon="🤖", name="Aimbot",   color=P.acc7},
}

local contentFrame = _iNew("Frame")
contentFrame.Size = _ud2(1,-12,1,-148)
contentFrame.Position = _ud2(0,6,0,124)
contentFrame.BackgroundTransparency = 1
contentFrame.ZIndex = 3
contentFrame.Parent = MF

for _, td in ipairs(tabsDef) do
    local scroll = _iNew("ScrollingFrame")
    scroll.Name = td.id
    scroll.Size = _ud2(1,0,1,0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = td.color
    scroll.ScrollBarImageTransparency = 0.45
    scroll.CanvasSize = _ud2(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Visible = (td.id == "combat")
    scroll.ZIndex = 3
    scroll.Parent = contentFrame

    local layout = _iNew("UIListLayout")
    layout.Padding = _udim(0,7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local pad = _iNew("UIPadding")
    pad.PaddingTop    = _udim(0,3)
    pad.PaddingBottom = _udim(0,14)
    pad.PaddingLeft   = _udim(0,2)
    pad.PaddingRight  = _udim(0,2)
    pad.Parent = scroll

    tabContents[td.id] = scroll
end

local function switchTab(tabId)
    currentTab = tabId
    for id, btn in pairs(tabButtons) do
        local td2
        for _, t in ipairs(tabsDef) do if t.id==id then td2=t break end end
        if id == tabId then
            tw(btn, ti(0.3), {BackgroundColor3=td2.color, BackgroundTransparency=0.1}):Play()
            for _, ch in ipairs(btn:GetChildren()) do
                if ch:IsA("TextLabel") then tw(ch, ti(0.3), {TextColor3=_c3(255,255,255)}):Play() end
            end
        else
            tw(btn, ti(0.3), {BackgroundColor3=P.bgDeep, BackgroundTransparency=0.55}):Play()
            for _, ch in ipairs(btn:GetChildren()) do
                if ch:IsA("TextLabel") then tw(ch, ti(0.3), {TextColor3=P.textD}):Play() end
            end
        end
    end
    for id, ct in pairs(tabContents) do ct.Visible = (id==tabId) end
end

for _, td in ipairs(tabsDef) do
    local btn = _iNew("TextButton")
    btn.Name = td.id
    btn.Size = _ud2(0, 80, 0, 28)
    btn.BackgroundColor3 = P.bgDeep
    btn.BackgroundTransparency = 0.55
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.ZIndex = 5
    btn.Parent = tabBar
    corner(btn, 8)

    local iL = _iNew("TextLabel")
    iL.Size = _ud2(0, 16, 1, 0)
    iL.Position = _ud2(0, 5, 0, 0)
    iL.BackgroundTransparency = 1
    iL.Text = td.icon
    iL.TextSize = 11
    iL.Font = Enum.Font.GothamBold
    iL.TextColor3 = P.textD
    iL.ZIndex = 6
    iL.Parent = btn

    local nL = _iNew("TextLabel")
    nL.Size = _ud2(1,-24,1,0)
    nL.Position = _ud2(0,22,0,0)
    nL.BackgroundTransparency = 1
    nL.Text = td.name
    nL.TextSize = 9.5
    nL.Font = Enum.Font.GothamBold
    nL.TextColor3 = P.textD
    nL.TextXAlignment = Enum.TextXAlignment.Left
    nL.ZIndex = 6
    nL.Parent = btn

    btn.MouseButton1Click:Connect(function() switchTab(td.id) end)
    tabButtons[td.id] = btn
end

-- ═══ СЛАЙДЕР ═══
local function createSlider(parent, labelText, minVal, maxVal, currentVal, color, order, onChange)
    local sliderCard = _iNew("Frame")
    sliderCard.Size = _ud2(1, 0, 0, 56)
    sliderCard.BackgroundColor3 = P.bgCard
    sliderCard.BackgroundTransparency = 0.05
    sliderCard.BorderSizePixel = 0
    sliderCard.LayoutOrder = order
    sliderCard.ZIndex = 3
    sliderCard.ClipsDescendants = false
    sliderCard.Parent = parent
    corner(sliderCard, 14)
    stroke(sliderCard, P.bord, 0.6, 0.55)

    local sLabel = _iNew("TextLabel")
    sLabel.Size = _ud2(0.6,0,0,18)
    sLabel.Position = _ud2(0,12,0,6)
    sLabel.BackgroundTransparency = 1
    sLabel.Text = labelText
    sLabel.TextColor3 = P.textW
    sLabel.TextSize = 11
    sLabel.Font = Enum.Font.GothamBold
    sLabel.TextXAlignment = Enum.TextXAlignment.Left
    sLabel.ZIndex = 4
    sLabel.Parent = sliderCard

    local valLabel = _iNew("TextLabel")
    valLabel.Size = _ud2(0.35,0,0,18)
    valLabel.Position = _ud2(0.65,0,0,6)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(currentVal)
    valLabel.TextColor3 = color
    valLabel.TextSize = 11
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.ZIndex = 4
    valLabel.Parent = sliderCard

    local trackBG = _iNew("Frame")
    trackBG.Size = _ud2(1,-24,0,6)
    trackBG.Position = _ud2(0,12,0,34)
    trackBG.BackgroundColor3 = _c3(20,20,38)
    trackBG.BorderSizePixel = 0
    trackBG.ZIndex = 4
    trackBG.Parent = sliderCard
    corner(trackBG, 3)

    local trackFill = _iNew("Frame")
    local initRatio = (currentVal - minVal) / (maxVal - minVal)
    trackFill.Size = _ud2(initRatio, 0, 1, 0)
    trackFill.BackgroundColor3 = color
    trackFill.BorderSizePixel = 0
    trackFill.ZIndex = 5
    trackFill.Parent = trackBG
    corner(trackFill, 3)
    grad(trackFill, _csNew{_csk(0,color),_csk(1,P.acc2)})

    local knobBtn = _iNew("Frame")
    knobBtn.Size = _ud2(0,14,0,14)
    knobBtn.AnchorPoint = Vector2.new(0.5,0.5)
    knobBtn.Position = _ud2(initRatio,0,0.5,0)
    knobBtn.BackgroundColor3 = _c3(255,255,255)
    knobBtn.BorderSizePixel = 0
    knobBtn.ZIndex = 6
    knobBtn.Parent = trackBG
    corner(knobBtn, 7)
    stroke(knobBtn, color, 1.5, 0)

    local draggingSlider = false

    local sliderBtn = _iNew("TextButton")
    sliderBtn.Size = _ud2(1,0,1,20)
    sliderBtn.Position = _ud2(0,0,0,-10)
    sliderBtn.BackgroundTransparency = 1
    sliderBtn.Text = ""
    sliderBtn.ZIndex = 7
    sliderBtn.Parent = trackBG

    local function updateSlider(absX)
        local abs = trackBG.AbsolutePosition.X
        local w   = trackBG.AbsoluteSize.X
        local ratio = _mClamp((absX - abs) / w, 0, 1)
        local val   = math.floor(minVal + (maxVal - minVal) * ratio)
        valLabel.Text = tostring(val)
        tw(trackFill, ti(0.05), {Size=_ud2(ratio,0,1,0)}):Play()
        tw(knobBtn,   ti(0.05), {Position=_ud2(ratio,0,0.5,0)}):Play()
        if onChange then onChange(val) end
    end

    sliderBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == _enumUIT.MouseButton1 or inp.UserInputType == _enumUIT.Touch then
            draggingSlider = true
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == _enumUIT.MouseButton1 or inp.UserInputType == _enumUIT.Touch then
            draggingSlider = false
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if draggingSlider and (inp.UserInputType == _enumUIT.MouseMovement or inp.UserInputType == _enumUIT.Touch) then
            updateSlider(inp.Position.X)
        end
    end)

    return sliderCard
end

-- ═══ МОДУЛЬНЫЕ КАРТОЧКИ ═══
local allModuleData = {}

-- updateStatus объявляем заранее как forward-declaration
local updateStatus

local function createModule(tabId, icon, name, desc, order, accentColor, tags, cfgKey, onEnable, onDisable)
    local parentScroll = tabContents[tabId]
    if not parentScroll then return end

    local card = _iNew("Frame")
    card.Size = _ud2(1,0,0,88)
    card.BackgroundColor3 = P.bgCard
    card.BackgroundTransparency = 0.04
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 3
    card.ClipsDescendants = true
    card.Parent = parentScroll
    corner(card, 16)

    local cardStroke = stroke(card, P.bord, 0.6, 0.55)

    local glass = _iNew("Frame")
    glass.Size = _ud2(1,0,0.45,0)
    glass.BackgroundColor3 = _c3(255,255,255)
    glass.BackgroundTransparency = 0.97
    glass.BorderSizePixel = 0
    glass.ZIndex = 3
    glass.Parent = card
    corner(glass, 16)

    local leftBar = _iNew("Frame")
    leftBar.Size = _ud2(0,3,0.35,0)
    leftBar.Position = _ud2(0,0,0.325,0)
    leftBar.BackgroundColor3 = accentColor
    leftBar.BackgroundTransparency = 0.2
    leftBar.BorderSizePixel = 0
    leftBar.ZIndex = 4
    leftBar.Parent = card
    corner(leftBar, 2)

    local iconBg = _iNew("Frame")
    iconBg.Size = _ud2(0,48,0,48)
    iconBg.Position = _ud2(0,12,0,10)
    iconBg.BackgroundColor3 = accentColor
    iconBg.BackgroundTransparency = 0.87
    iconBg.BorderSizePixel = 0
    iconBg.ZIndex = 4
    iconBg.Parent = card
    corner(iconBg, 15)

    local iconInner = _iNew("Frame")
    iconInner.Size = _ud2(0,32,0,32)
    iconInner.AnchorPoint = Vector2.new(0.5,0.5)
    iconInner.Position = _ud2(0.5,0,0.5,0)
    iconInner.BackgroundColor3 = accentColor
    iconInner.BackgroundTransparency = 0.7
    iconInner.BorderSizePixel = 0
    iconInner.ZIndex = 5
    iconInner.Parent = iconBg
    corner(iconInner, 10)

    local iconLabel = _iNew("TextLabel")
    iconLabel.Size = _ud2(1,0,1,0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextSize = 16
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.ZIndex = 6
    iconLabel.Parent = iconInner

    local nameLabel = _iNew("TextLabel")
    nameLabel.Size = _ud2(1,-140,0,20)
    nameLabel.Position = _ud2(0,70,0,12)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = P.textW
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 4
    nameLabel.Parent = card

    local descLabel = _iNew("TextLabel")
    descLabel.Size = _ud2(1,-140,0,12)
    descLabel.Position = _ud2(0,70,0,33)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = desc
    descLabel.TextColor3 = P.textD
    descLabel.TextSize = 9
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.ZIndex = 4
    descLabel.Parent = card

    if tags then
        local tx = 70
        for _, tagText in ipairs(tags) do
            local tf = _iNew("Frame")
            tf.Size = _ud2(0,#tagText*5+14,0,15)
            tf.Position = _ud2(0,tx,0,51)
            tf.BackgroundColor3 = accentColor
            tf.BackgroundTransparency = 0.88
            tf.BorderSizePixel = 0
            tf.ZIndex = 4
            tf.Parent = card
            corner(tf, 5)

            local tl = _iNew("TextLabel")
            tl.Size = _ud2(1,0,1,0)
            tl.BackgroundTransparency = 1
            tl.Text = tagText
            tl.TextColor3 = accentColor
            tl.TextSize = 6.5
            tl.Font = Enum.Font.GothamBlack
            tl.ZIndex = 5
            tl.Parent = tf

            tx = tx + #tagText*5+17
        end
    end

    local bottomLine = _iNew("Frame")
    bottomLine.Size = _ud2(0,0,0,2)
    bottomLine.AnchorPoint = Vector2.new(0.5,0)
    bottomLine.Position = _ud2(0.5,0,1,-3)
    bottomLine.BackgroundColor3 = accentColor
    bottomLine.BackgroundTransparency = 0.3
    bottomLine.BorderSizePixel = 0
    bottomLine.ZIndex = 4
    bottomLine.Parent = card
    corner(bottomLine, 1)
    grad(bottomLine, _csNew{_csk(0,accentColor),_csk(0.5,P.acc2),_csk(1,accentColor)})

    local toggleBtn = _iNew("TextButton")
    toggleBtn.Size = _ud2(0,52,0,26)
    toggleBtn.Position = _ud2(1,-64,0.5,-13)
    toggleBtn.BackgroundColor3 = P.tOff
    toggleBtn.Text = ""
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 4
    toggleBtn.Parent = card
    corner(toggleBtn, 13)
    local toggleStroke = stroke(toggleBtn, P.bord, 0.5, 0.5)

    local knob = _iNew("Frame")
    knob.Size = _ud2(0,20,0,20)
    knob.Position = _ud2(0,3,0.5,-10)
    knob.BackgroundColor3 = P.tKnob
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = toggleBtn
    corner(knob, 10)
    local knobStroke = stroke(knob, accentColor, 0, 0.8)

    local knobDot = _iNew("Frame")
    knobDot.Size = _ud2(0,7,0,7)
    knobDot.AnchorPoint = Vector2.new(0.5,0.5)
    knobDot.Position = _ud2(0.5,0,0.5,0)
    knobDot.BackgroundColor3 = accentColor
    knobDot.BackgroundTransparency = 1
    knobDot.BorderSizePixel = 0
    knobDot.ZIndex = 6
    knobDot.Parent = knob
    corner(knobDot, 4)

    local hoverBtn = _iNew("TextButton")
    hoverBtn.Size = _ud2(1,0,1,0)
    hoverBtn.BackgroundTransparency = 1
    hoverBtn.Text = ""
    hoverBtn.ZIndex = 3
    hoverBtn.Parent = card

    hoverBtn.MouseEnter:Connect(function()
        tw(card, ti(0.25), {BackgroundTransparency=0}):Play()
        tw(cardStroke, ti(0.25), {Transparency=0.12, Color=accentColor}):Play()
        tw(leftBar, ti(0.3), {BackgroundTransparency=0, Size=_ud2(0,4.5,0.45,0)}):Play()
        tw(bottomLine, ti(0.4), {Size=_ud2(0.82,0,0,2.5)}):Play()
        tw(iconBg, ti(0.3), {BackgroundTransparency=0.78}):Play()
    end)
    hoverBtn.MouseLeave:Connect(function()
        tw(card, ti(0.25), {BackgroundTransparency=0.04}):Play()
        tw(cardStroke, ti(0.25), {Transparency=0.55, Color=P.bord}):Play()
        tw(leftBar, ti(0.3), {BackgroundTransparency=0.2, Size=_ud2(0,3,0.35,0)}):Play()
        tw(bottomLine, ti(0.4), {Size=_ud2(0,0,0,2)}):Play()
        tw(iconBg, ti(0.3), {BackgroundTransparency=0.87}):Play()
    end)

    local isOn = false

    local function setVisual(state)
        isOn = state
        local t = ti(0.35)
        if state then
            tw(toggleBtn, t, {BackgroundColor3=accentColor}):Play()
            tw(toggleStroke, t, {Color=accentColor, Transparency=0.08}):Play()
            tw(knob, t, {Position=_ud2(1,-23,0.5,-10), BackgroundColor3=_c3(255,255,255)}):Play()
            tw(knobStroke, t, {Thickness=2, Transparency=0}):Play()
            tw(knobDot, t, {BackgroundTransparency=0}):Play()
            tw(cardStroke, t, {Color=accentColor, Transparency=0.18}):Play()
            tw(leftBar, t, {BackgroundTransparency=0}):Play()
            tw(iconInner, t, {BackgroundTransparency=0.48}):Play()
            tw(bottomLine, _twInfo(0.4,_enumES.Quint), {Size=_ud2(0.88,0,0,2.5), BackgroundTransparency=0.08}):Play()
        else
            tw(toggleBtn, t, {BackgroundColor3=P.tOff}):Play()
            tw(toggleStroke, t, {Color=P.bord, Transparency=0.5}):Play()
            tw(knob, t, {Position=_ud2(0,3,0.5,-10), BackgroundColor3=P.tKnob}):Play()
            tw(knobStroke, t, {Thickness=0, Transparency=0.8}):Play()
            tw(knobDot, t, {BackgroundTransparency=1}):Play()
            tw(cardStroke, t, {Color=P.bord, Transparency=0.55}):Play()
            tw(leftBar, t, {BackgroundTransparency=0.2}):Play()
            tw(iconInner, t, {BackgroundTransparency=0.7}):Play()
            tw(bottomLine, ti(0.3), {Size=_ud2(0,0,0,2), BackgroundTransparency=0.3}):Play()
        end
    end

    allModuleData[#allModuleData+1] = {cfgKey=cfgKey, color=accentColor}

    toggleBtn.MouseButton1Click:Connect(function()
        CFG[cfgKey] = not CFG[cfgKey]
        setVisual(CFG[cfgKey])
        if CFG[cfgKey] then
            _refreshChar()
            if onEnable then onEnable() end
        else
            if onDisable then onDisable() end
        end
        if updateStatus then updateStatus() end
    end)

    return toggleBtn, setVisual
end

-- ═══ СОЗДАНИЕ МОДУЛЕЙ ═══

-- COMBAT
createModule("combat","🛡️","God Mode","Бесконечное здоровье",
    1,P.acc3,{"IMMORTAL","v2"},"godMode",_startGodMode,_stopGodMode)
createModule("combat","👻","Anti-Ragdoll","Ghost-контроль при рагдолле",
    2,P.acc2,{"GHOST","v8"},"antiRagdoll",_startAntiRagdoll,_stopAntiRagdoll)
createModule("combat","💀","Big Head","Увеличивает головы врагов",
    3,P.acc7,{"HITBOX","PVP"},"bigHead",_startBigHead,function() CFG.bigHead=false end)
createModule("combat","📦","Hitbox Expand","Расширить хитбокс цели",
    4,P.acc3,{"BOX","EXPAND"},"hitboxExp",_expandHitboxes,_restoreHitboxes)

-- MOVEMENT
createModule("movement","⚡","Infinite Jump","Прыжки в воздухе",
    1,P.acc1,{"AIR","MULTI"},"infJump",function() end,function() end)
createModule("movement","🏃","Speed Hack","Ускорение",
    2,P.acc4,{"FAST"},"speed",_startSpeed,_stopSpeed)
createModule("movement","🕊️","Fly","Свободный полёт",
    3,P.acc8,{"FLY","3D"},"fly",_startFly,_stopFly)
createModule("movement","👤","Noclip","Проход сквозь стены",
    4,P.acc6,{"PHASE"},"noclip",_startNoclip,_stopNoclip)
createModule("movement","🌙","Low Gravity","Пониженная гравитация",
    5,_c3(180,130,255),{"MOON"},"lowGravity",_startLowGravity,_stopLowGravity)

-- VISUAL
createModule("visual","🎭","No Animations","Заморозка анимаций",
    1,P.acc3,{"FREEZE"},"noAnim",_startNoAnim,_stopNoAnim)
createModule("visual","👁️","ESP","Видеть игроков сквозь стены",
    2,P.acc5,{"WALLHACK","HP"},"esp",_startESP,_stopESP)
createModule("visual","🌈","Chams","Цветная подсветка тел",
    3,P.acc6,{"RGB"},"chams",_startChams,_stopChams)
createModule("visual","📍","Tracers","Линии к игрокам",
    4,P.acc4,{"LINE"},"tracers",function() _startTracers(SG) end,_stopTracers)

-- WORLD
createModule("world","☀️","Fullbright","Максимальная яркость",
    1,P.acc4,{"BRIGHT"},"fullbright",_startFullbright,_stopFullbright)
createModule("world","🌫️","No Fog","Убрать туман",
    2,P.acc8,{"CLEAR"},"noFog",_startNoFog,_stopNoFog)

-- AIMBOT
createModule("aimbot","🎯","Aimbot","Автоприцеливание (Q)",
    1,P.acc7,{"AUTO","LOCK"},"aimbot",
    function() _drawFOVCircle(SG) end,
    function()
        _aimbotTarget=nil _aimbotLocked=false
        if _aimbotFOVPart then
            _pCall(function() _aimbotFOVPart:Destroy() end)
            _aimbotFOVPart=nil
        end
    end)

createModule("aimbot","👻","Silent Aim","Пули летят в цель",
    2,P.acc3,{"SILENT"},"silentAim",function() end,function()
        _aimbotTarget=nil
    end)

-- Слайдеры
createSlider(tabContents["aimbot"], "FOV Radius", 50, 500, CFG.aimbotFOV, P.acc7, 3, function(v)
    CFG.aimbotFOV = v
    if _aimbotFOVPart then
        _pCall(function()
            _aimbotFOVPart.Size = _ud2(0, v*2, 0, v*2)
            local c = _aimbotFOVPart:FindFirstChildOfClass("UICorner")
            if c then c.CornerRadius = _udim(0, v) end
        end)
    end
end)

createSlider(tabContents["aimbot"], "Smoothness", 1, 50, math.floor(CFG.aimbotSmooth*100), P.acc7, 4, function(v)
    CFG.aimbotSmooth = v / 100
end)

createSlider(tabContents["aimbot"], "Hitbox Size", 2, 20, CFG.hitboxSize, P.acc3, 5, function(v)
    CFG.hitboxSize = v
end)

createSlider(tabContents["aimbot"], "Fly Speed", 10, 200, CFG.flySpeed, P.acc8, 6, function(v)
    CFG.flySpeed = v
end)

createSlider(tabContents["aimbot"], "Walk Speed", 16, 100, CFG.speedValue, P.acc4, 7, function(v)
    CFG.speedValue = v
    if CFG.speed and _hum then _pCall(function() _hum.WalkSpeed = v end) end
end)

-- ═══ СТАТУС-БАР ═══
local SB = _iNew("Frame")
SB.Size = _ud2(1,-12,0,54)
SB.Position = _ud2(0,6,1,-60)
SB.BackgroundColor3 = P.bgDeep
SB.BackgroundTransparency = 0.08
SB.BorderSizePixel = 0
SB.ZIndex = 5
SB.Parent = MF
corner(SB, 14)
stroke(SB, P.bord, 0.5, 0.6)

local statusLabel = _iNew("TextLabel")
statusLabel.Size = _ud2(0.58,0,0,20)
statusLabel.Position = _ud2(0,12,0,6)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = P.textD
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.ZIndex = 6
statusLabel.Parent = SB

local infoLabel = _iNew("TextLabel")
infoLabel.Size = _ud2(0.58,0,0,14)
infoLabel.Position = _ud2(0,12,0,26)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = ""
infoLabel.TextColor3 = P.acc2
infoLabel.TextSize = 9
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.ZIndex = 6
infoLabel.Parent = SB

local pingLabel = _iNew("TextLabel")
pingLabel.Size = _ud2(0,80,0,12)
pingLabel.Position = _ud2(1,-90,0,6)
pingLabel.BackgroundTransparency = 1
pingLabel.Text = "● 20ms"
pingLabel.TextColor3 = P.textG
pingLabel.TextSize = 8
pingLabel.Font = Enum.Font.GothamMedium
pingLabel.TextXAlignment = Enum.TextXAlignment.Right
pingLabel.ZIndex = 6
pingLabel.Parent = SB

local fpsLabel = _iNew("TextLabel")
fpsLabel.Size = _ud2(0,80,0,12)
fpsLabel.Position = _ud2(1,-90,0,20)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "60 FPS"
fpsLabel.TextColor3 = P.textD
fpsLabel.TextSize = 8
fpsLabel.Font = Enum.Font.GothamMedium
fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
fpsLabel.ZIndex = 6
fpsLabel.Parent = SB

local lockLabel = _iNew("TextLabel")
lockLabel.Size = _ud2(0,80,0,12)
lockLabel.Position = _ud2(1,-90,0,34)
lockLabel.BackgroundTransparency = 1
lockLabel.Text = ""
lockLabel.TextColor3 = P.acc3
lockLabel.TextSize = 8
lockLabel.Font = Enum.Font.GothamBold
lockLabel.TextXAlignment = Enum.TextXAlignment.Right
lockLabel.ZIndex = 6
lockLabel.Parent = SB

-- Точки активных модулей
local activeDots = {}
for i = 1, 15 do
    local dot = _iNew("Frame")
    dot.Size = _ud2(0,6,0,6)
    dot.Position = _ud2(0,12+(i-1)*9,0,46)
    dot.BackgroundColor3 = _c3(18,18,32)
    dot.BorderSizePixel = 0
    dot.ZIndex = 6
    dot.Parent = SB
    corner(dot, 3)
    activeDots[i] = dot
end

-- Теперь объявляем updateStatus (больше не forward-declaration нужен)
updateStatus = function()
    local keys = {
        "infJump","antiRagdoll","noAnim","speed","fly","noclip",
        "esp","godMode","fullbright","noFog","bigHead","lowGravity",
        "aimbot","silentAim","hitboxExp","chams","tracers"
    }
    local count = 0
    local activeColors = {}
    for _, k in ipairs(keys) do
        if CFG[k] then
            count = count + 1
            for _, md in ipairs(allModuleData) do
                if md.cfgKey == k then
                    activeColors[#activeColors+1] = md.color
                    break
                end
            end
        end
    end
    for i = 1, 15 do
        if i <= count and activeColors[i] then
            tw(activeDots[i], ti(0.3), {BackgroundColor3=activeColors[i]}):Play()
        else
            tw(activeDots[i], ti(0.3), {BackgroundColor3=_c3(18,18,32)}):Play()
        end
    end
    if count == 0 then
        statusLabel.Text = "Все модули неактивны"
        tw(statusLabel, ti(0.3), {TextColor3=P.textD}):Play()
    else
        statusLabel.Text = count .. "/17 · TERMINATOR ACTIVE"
        tw(statusLabel, ti(0.3), {TextColor3=P.textG}):Play()
    end
end

-- Info loop
_tSpawn(function()
    while SG and SG.Parent do
        if _aimbotLocked and _aimbotTarget then
            lockLabel.Text = "🎯 LOCKED: " .. _aimbotTarget.DisplayName
        else
            lockLabel.Text = ""
        end

        if _ghostActive then
            infoLabel.Text = "👻 GHOST · " .. _mFloor(tick()-_ragStart) .. "s"
            infoLabel.TextColor3 = _c3h((tick()*0.2)%1, 0.35, 1)
        elseif _exitLock then
            infoLabel.Text = "⟳ Stabilizing..."
            infoLabel.TextColor3 = P.acc4
        elseif _flying then
            infoLabel.Text = "🕊️ Flying · " .. CFG.flySpeed .. " u/s"
            infoLabel.TextColor3 = P.acc8
        else
            infoLabel.Text = ""
        end

        _pCall(function()
            pingLabel.Text = "● " .. math.random(5,48) .. "ms"
            local dt = RunService.Heartbeat:Wait()
            if dt > 0 then
                fpsLabel.Text = _mFloor(1/dt) .. " FPS"
            end
        end)
        _tWait(0.1)
    end
end)

-- ═══ MIN / CLOSE ═══
local minimized = false

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tw(MF, _twInfo(0.48,_enumES.Back,_enumED.In), {Size=_ud2(0,460,0,80)}):Play()
        _tDelay(0.06, function()
            contentFrame.Visible=false
            tabBar.Visible=false
            SB.Visible=false
        end)
        MinBtn.Text = "◻"
    else
        tw(MF, _twInfo(0.52,_enumES.Back), {Size=_ud2(0,460,0,660)}):Play()
        _tDelay(0.22, function()
            contentFrame.Visible=true
            tabBar.Visible=true
            SB.Visible=true
        end)
        MinBtn.Text = "━"
    end
end)

ClsBtn.MouseButton1Click:Connect(function()
    for k, v in pairs(CFG) do if type(v)=="boolean" then CFG[k]=false end end
    _stopAntiRagdoll()
    _stopNoAnim()
    _stopFly()
    _stopNoclip()
    _stopESP()
    _stopGodMode()
    _stopFullbright()
    _stopNoFog()
    _stopLowGravity()
    _stopSpeed()
    _stopChams()
    _stopTracers()
    _restoreHitboxes()
    if _aimbotFOVPart then _pCall(function() _aimbotFOVPart:Destroy() end) end
    if _heartbeatC then _heartbeatC:Disconnect() end

    tw(MF, _twInfo(0.4,_enumES.Back,_enumED.In), {
        Size=_ud2(0,6,0,6),
        Position=_ud2(0.5,-3,0.5,-3),
    }):Play()
    _tDelay(0.45, function()
        tw(MF, ti(0.15), {BackgroundTransparency=1}):Play()
    end)
    _tDelay(0.65, function()
        _pCall(function() SG:Destroy() end)
    end)
end)

-- ═══ АНИМАЦИИ ═══

-- Радужная рамка
_tSpawn(function()
    local hue = 0
    while SG and SG.Parent do
        hue = (hue+0.001)%1
        local ac = 0
        for _, v in pairs(CFG) do if type(v)=="boolean" and v then ac=ac+1 end end
        local t = tick()
        if ac > 0 then
            mainStroke.Color = _c3h(hue, _mClamp(0.35+ac*0.04,0,0.85), _mClamp(0.65+ac*0.02,0,1))
            mainStroke.Transparency = 0.02 + _mSin(t*1.4)*0.04
            mainStroke.Thickness = 1.5 + _mSin(t*1.9)*0.4
            _pCall(function()
                for _, ring in ipairs(logoRings) do
                    ring.BackgroundColor3 = _c3h((hue+0.06)%1, 0.5, 0.85)
                end
                logoGlow.BackgroundColor3 = _c3h((hue+0.12)%1, 0.55, 1)
            end)
        else
            mainStroke.Color = P.bord
            mainStroke.Transparency = 0.55
            mainStroke.Thickness = 1
        end
        _tWait(0.02)
    end
end)

-- Аврора
_tSpawn(function()
    local phases = {}
    for i=1,#auroraData do phases[i]=math.random()*_mPi*2 end
    while SG and SG.Parent do
        local t = tick()
        for i, o in ipairs(auroraOrbs) do
            _pCall(function()
                local od = auroraData[i]
                local ph = phases[i]
                local ox = _mSin(t*(0.1+i*0.04)+ph)*16
                local oy = _mCos(t*(0.13+i*0.03)+ph*0.7)*13
                o.Position = _ud2(od[1].X.Scale, od[1].X.Offset+ox, od[1].Y.Scale, od[1].Y.Offset+oy)
                o.BackgroundTransparency = od[4] + _mSin(t*(0.28+i*0.05))*0.01
            end)
        end
        _tWait(0.025)
    end
end)

-- Пульс лого
_tSpawn(function()
    while SG and SG.Parent do
        local ac = 0
        for _, v in pairs(CFG) do if type(v)=="boolean" and v then ac=ac+1 end end
        if ac > 0 then
            for i, ring in ipairs(logoRings) do
                _pCall(function()
                    local rd = ringDat[i]
                    tw(ring, _twInfo(2,_enumES.Sine,_enumED.InOut), {
                        BackgroundTransparency = rd[2]-0.06,
                        Size = _ud2(0,rd[1]+5,0,rd[1]+5),
                    }):Play()
                end)
            end
            _pCall(function()
                tw(logoGlow, _twInfo(2,_enumES.Sine,_enumED.InOut), {
                    BackgroundTransparency=0.12, Size=_ud2(0,28,0,28),
                }):Play()
            end)
            _tWait(2)
            if not (SG and SG.Parent) then return end
            for i, ring in ipairs(logoRings) do
                _pCall(function()
                    local rd = ringDat[i]
                    tw(ring, _twInfo(2,_enumES.Sine,_enumED.InOut), {
                        BackgroundTransparency = rd[2],
                        Size = _ud2(0,rd[1],0,rd[1]),
                    }):Play()
                end)
            end
            _pCall(function()
                tw(logoGlow, _twInfo(2,_enumES.Sine,_enumED.InOut), {
                    BackgroundTransparency=0.3, Size=_ud2(0,24,0,24),
                }):Play()
            end)
            _tWait(2)
        else
            _tWait(0.5)
        end
    end
end)

-- Пульс точек
_tSpawn(function()
    while SG and SG.Parent do
        local count = 0
        for _, v in pairs(CFG) do if type(v)=="boolean" and v then count=count+1 end end
        for i = 1, _mMin(count, 15) do
            _pCall(function()
                tw(activeDots[i], _twInfo(0.7,_enumES.Sine,_enumED.InOut), {Size=_ud2(0,8,0,8)}):Play()
            end)
        end
        _tWait(0.7)
        if not (SG and SG.Parent) then return end
        for i = 1, 15 do
            _pCall(function()
                tw(activeDots[i], _twInfo(0.7,_enumES.Sine,_enumED.InOut), {Size=_ud2(0,6,0,6)}):Play()
            end)
        end
        _tWait(0.7)
    end
end)

-- ═══ АНИМАЦИЯ ОТКРЫТИЯ ═══
MF.BackgroundTransparency = 1
contentFrame.Visible=false
tabBar.Visible=false
SB.Visible=false
mainStroke.Transparency = 1

_tDelay(0.05, function()
    MF.Size = _ud2(0,6,0,6)
    MF.Position = _ud2(0.5,-3,0.5,-3)

    tw(MF, ti(0.1), {BackgroundTransparency=0}):Play()
    tw(mainStroke, ti(0.1), {Transparency=0.1}):Play()
    _tWait(0.08)

    tw(MF, _twInfo(0.28,_enumES.Quint), {
        Size=_ud2(0,460,0,6),
        Position=_ud2(0.5,-230,0.5,-3),
    }):Play()
    _tWait(0.22)

    tw(MF, _twInfo(0.52,_enumES.Back,_enumED.Out), {
        Size=_ud2(0,460,0,660),
        Position=_ud2(0.5,-230,0.5,-330),
    }):Play()
    _tWait(0.25)

    for i, orb in ipairs(auroraOrbs) do
        _tDelay(i*0.025, function()
            tw(orb, _twInfo(0.65,_enumES.Quint), {
                BackgroundTransparency=auroraData[i][4]
            }):Play()
        end)
    end

    _tDelay(0.15, function()
        tabBar.Visible = true
        tabBar.BackgroundTransparency = 1
        tw(tabBar, ti(0.35), {BackgroundTransparency=0.25}):Play()

        for _, btn in pairs(tabButtons) do
            btn.BackgroundTransparency = 1
            tw(btn, ti(0.35), {BackgroundTransparency=0.55}):Play()
            for _, desc in ipairs(btn:GetChildren()) do
                if desc:IsA("TextLabel") then
                    desc.TextTransparency = 1
                    tw(desc, ti(0.4), {TextTransparency=0}):Play()
                end
            end
        end
    end)

    _tDelay(0.28, function()
        contentFrame.Visible = true

        SB.Visible = true
        SB.BackgroundTransparency = 1
        tw(SB, ti(0.45), {BackgroundTransparency=0.08}):Play()
        for _, child in ipairs(SB:GetChildren()) do
            _pCall(function()
                if child:IsA("TextLabel") then
                    child.TextTransparency = 1
                    tw(child, ti(0.45), {TextTransparency=0}):Play()
                end
            end)
        end

        -- Карточки
        local visibleScroll = tabContents[currentTab]
        if visibleScroll then
            local cIdx = 0
            for _, child in ipairs(visibleScroll:GetChildren()) do
                if child:IsA("Frame") then
                    cIdx = cIdx + 1
                    local idx = cIdx
                    child.BackgroundTransparency = 1
                    _tDelay(idx*0.07, function()
                        tw(child, _twInfo(0.48,_enumES.Quint), {BackgroundTransparency=0.04}):Play()
                    end)
                end
            end
        end

        _tDelay(0.6, function()
            tw(mainStroke, ti(0.5), {Transparency=0.5}):Play()
        end)
    end)
end)

switchTab("combat")
updateStatus()
