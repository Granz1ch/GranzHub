--[[
    ██████████████████████████████████████████████
    ██  GRANZ HUB · NOVA v17.0 · UNIFIED      ██
    ██████████████████████████████████████████████
]]

-- ═══════════ POLYMORPHIC ANTI-DETECTION ═══════════
local _ENV_SEED = (tick() % 1) * os.clock() * math.random(100000, 9999999)
local _RNG = Random.new(math.floor(_ENV_SEED) % 2147483647)

local function _genID(len)
    len = len or _RNG:NextInteger(16, 28)
    local buf = table.create(len)
    for i = 1, len do
        local r = _RNG:NextInteger(1, 62)
        if r <= 26 then buf[i] = string.char(96 + r)
        elseif r <= 52 then buf[i] = string.char(38 + r)
        else buf[i] = string.char(r - 53 + 48) end
    end
    return table.concat(buf)
end

local function _jitter() return _RNG:NextNumber(0.001, 0.009) end
local function _rF(a, b) return _RNG:NextNumber(a, b) end
local function _rI(a, b) return _RNG:NextInteger(a, b) end

local _SVC = setmetatable({}, {
    __index = function(self, key)
        local s, v = pcall(game.GetService, game, key)
        if s and v then rawset(self, key, v) end
        return v
    end
})

local Players       = _SVC.Players
local UIS           = _SVC.UserInputService
local RunService    = _SVC.RunService
local TweenService  = _SVC.TweenService
local StarterGui    = _SVC.StarterGui
local Lighting      = _SVC.Lighting

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")
local Cam = workspace.CurrentCamera
local Mouse = LP:GetMouse()

-- Obfuscated globals
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
local _mFloor  = math.floor
local _mSin    = math.sin
local _mCos    = math.cos
local _mAbs    = math.abs
local _mPi     = math.pi
local _mClamp  = math.clamp
local _mHuge   = math.huge

_tWait(_rF(0.01, 0.04))

-- ═══════════ UNIFIED CONFIG ═══════════
local CFG = {
    -- Original modules
    infJump      = false,
    antiRagdoll  = false,
    noAnim       = false,
    jumpPower    = 50,
    jumpCooldown = 0.12,
    maxFallVel   = -60,
    -- Merged modules
    speed        = false,
    speedValue   = 32,
    fly          = false,
    flySpeed     = 60,
    noclip       = false,
    esp          = false,
    godMode      = false,
    fullbright   = false,
    noFog        = false,
    bigHead      = false,
    lowGravity   = false,
}

-- ═══════════ STATE ═══════════
local _lastJump     = 0
local _char, _hum, _rootPart, _animator
local _ragConns     = {}
local _animConns    = {}
local _heartbeatC   = nil
local _trackedAnims = {}
local _motorSnap    = {}
local _fabricMotors = {}
local _frameCount   = 0

-- Ghost v8
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

-- Fly state
local _flyBV        = nil
local _flyBG        = nil
local _flying       = false

-- ESP state
local _espObjects   = {}

-- Noclip state
local _noclipConn   = nil

-- Fullbright / fog state
local _origAmbient  = nil
local _origBright   = nil
local _origFogEnd   = nil
local _origFogStart = nil

-- God mode
local _godConn      = nil

-- Module connections storage
local _moduleConns  = {}

-- ═══════════ UTILITY ═══════════
local function _sf(obj, name)
    local ok, r = _pCall(function() return obj:FindFirstChild(name) end)
    return ok and r
end

local function _sfc(obj, cls)
    local ok, r = _pCall(function() return obj:FindFirstChildOfClass(cls) end)
    return ok and r
end

local function _refreshChar()
    _char = LP.Character
    if not _char then return false end
    _hum = _sfc(_char, "Humanoid")
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

-- ═══════════ INFINITE JUMP ═══════════
local function _doJump()
    if not CFG.infJump then return end
    local jumpRoot = _rootPart
    if _ghostActive and _ghostPart and _ghostPart.Parent then jumpRoot = _ghostPart end
    if not (jumpRoot and jumpRoot.Parent) then return end
    if _hum and _hum.Health <= 0 then return end

    local now = tick()
    if now - _lastJump < CFG.jumpCooldown then return end
    _lastJump = now

    local cv = jumpRoot.AssemblyLinearVelocity
    local newY = CFG.jumpPower
    if cv.Y < CFG.maxFallVel then
        newY = CFG.jumpPower + _mAbs(cv.Y) * 0.3
    end

    jumpRoot.AssemblyLinearVelocity = _v3(
        cv.X * _rF(0.87, 0.93),
        newY + _rF(-0.2, 0.2),
        cv.Z * _rF(0.87, 0.93)
    )

    _tDelay(0.04 + _jitter(), function()
        if jumpRoot and jumpRoot.Parent and CFG.infJump then
            local v = jumpRoot.AssemblyLinearVelocity
            if v.Y < CFG.jumpPower * 0.75 then
                jumpRoot.AssemblyLinearVelocity = _v3(v.X, CFG.jumpPower * _rF(0.85, 0.95), v.Z)
            end
        end
    end)
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == _enumKC.Space then
        if not _hum then return end
        if _ghostActive then _doJump() return end
        if not _rootPart then return end
        local st = _hum:GetState()
        if st == _enumHS.Freefall or st == _enumHS.Jumping or st == _enumHS.FallingDown then
            _doJump()
        end
    end
end)

-- ═══════════ GHOST ANTI-RAGDOLL v8.0 ═══════════
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
                p0 = v.Part0, p1 = v.Part1,
                c0 = v.C0, c1 = v.C1,
            }
        end
    end
end

local function _restoreMotors()
    if not _char then return end
    for _, d in ipairs(_motorSnap) do
        _pCall(function()
            if d.ref and d.ref.Parent then
                d.ref.Enabled = true
                return
            end
            if not (d.par and d.par.Parent and d.p0 and d.p0.Parent and d.p1 and d.p1.Parent) then return end
            local ex = d.par:FindFirstChild(d.name)
            if ex and ex:IsA("Motor6D") then
                ex.Enabled = true
                d.ref = ex
                return
            end
            local m = _iNew("Motor6D")
            m.Name = d.name
            m.Part0 = d.p0
            m.Part1 = d.p1
            m.C0 = d.c0
            m.C1 = d.c1
            m.Parent = d.par
            d.ref = m
            _fabricMotors[#_fabricMotors + 1] = m
        end)
    end
end

local function _nukeConstraints()
    if not _char then return end
    local badTypes = {
        BallSocketConstraint = true, HingeConstraint = true,
        NoCollisionConstraint = true, RopeConstraint = true,
        SpringConstraint = true, CylindricalConstraint = true,
        PrismaticConstraint = true,
    }
    for _, v in ipairs(_char:GetDescendants()) do
        _pCall(function()
            if badTypes[v.ClassName] then v:Destroy() end
        end)
    end
end

local function _spawnGhost()
    if _ghostPart and _ghostPart.Parent then return end
    if not (_rootPart and _rootPart.Parent and _char) then return end

    local cf = _preRagCF or _rootPart.CFrame
    local g = _iNew("Part")
    g.Name = _genID(14)
    g.Size = _v3(2, 2, 1)
    g.Transparency = 1
    g.CanCollide = true
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
    bv.Name = _genID(8)
    bv.MaxForce = _v3(15000, 0, 15000)
    bv.Velocity = _v3z
    bv.P = 2500
    bv.Parent = g
    _ghostMovers.bv = bv

    local bg = _iNew("BodyGyro")
    bg.Name = _genID(8)
    bg.MaxTorque = _v3(0, 15000, 0)
    bg.P = 5000
    bg.D = 200
    bg.Parent = g
    _ghostMovers.bg = bg

    local bf = _iNew("BodyForce")
    bf.Name = _genID(8)
    bf.Force = _v3(0, g:GetMass() * workspace.Gravity * 0.18, 0)
    bf.Parent = g
    _ghostMovers.bf = bf

    _ghostActive = true
end

local function _controlGhost()
    if not _ghostActive then return end
    if not (_ghostPart and _ghostPart.Parent) then
        _ghostActive = false
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local moveDir = _v3z
    local camCF = cam.CFrame
    local fwd = _v3(camCF.LookVector.X, 0, camCF.LookVector.Z)
    if fwd.Magnitude > 0.001 then fwd = fwd.Unit end
    local rgt = _v3(camCF.RightVector.X, 0, camCF.RightVector.Z)
    if rgt.Magnitude > 0.001 then rgt = rgt.Unit end

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

    if _ghostMovers.bv then
        _ghostMovers.bv.Velocity = _v3(moveDir.X, 0, moveDir.Z)
    end

    _pCall(function() cam.CameraSubject = _ghostPart end)
    _ghostCF = _ghostPart.CFrame
end

local function _killGhost(doTeleport)
    local finalCF = _ghostCF

    for _, v in pairs(_ghostMovers) do _pCall(function() v:Destroy() end) end
    _ghostMovers = {}

    if _ghostPart then
        _pCall(function() _ghostPart:Destroy() end)
        _ghostPart = nil
    end

    _pCall(function()
        if _hum then workspace.CurrentCamera.CameraSubject = _hum end
    end)

    _ghostActive = false

    if doTeleport and finalCF and _rootPart and _rootPart.Parent then
        _pCall(function()
            for _, v in ipairs(_char:GetDescendants()) do
                if v:IsA("BasePart") then
                    _pCall(function()
                        v.AssemblyLinearVelocity = _v3z
                        v.AssemblyAngularVelocity = _v3z
                    end)
                end
            end
            _rootPart.CFrame = finalCF
            _rootPart.AssemblyLinearVelocity = _v3z
            _rootPart.AssemblyAngularVelocity = _v3z
        end)
    end

    return finalCF
end

local function _exitRagdoll()
    if _exitLock then return end
    if _exitingRag then return end

    local now = tick()
    if now - _lastExitTime < 1.5 then return end

    _exitLock = true
    _exitingRag = true
    _lastExitTime = now

    if not (_hum and _char and _rootPart) then
        _killGhost(false)
        _exitingRag = false
        _ragActive = false
        _exitLock = false
        return
    end

    if _hum.Health <= 0 then
        _killGhost(false)
        _exitingRag = false
        _ragActive = false
        _exitLock = false
        return
    end

    local finalCF = _killGhost(true)

    _pCall(function() _hum.PlatformStand = false end)
    _nukeConstraints()
    _restoreMotors()

    for _, v in ipairs(_char:GetDescendants()) do
        if v:IsA("BasePart") then
            _pCall(function() v.Anchored = false end)
        end
    end

    _pCall(function() _hum:ChangeState(_enumHS.GettingUp) end)

    _tDelay(0.1 + _jitter(), function()
        if not CFG.antiRagdoll then
            _exitingRag = false
            _ragActive = false
            _exitLock = false
            return
        end
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
                                    v.AssemblyLinearVelocity = _v3z
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

    _tDelay(0.4 + _jitter(), function()
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
                if not _ghostActive then
                    workspace.CurrentCamera.CameraSubject = _hum
                end
            end
        end)
        _exitingRag = false
        _ragActive = false

        _tDelay(0.8, function()
            _exitLock = false
        end)
    end)
end

local function _onRagdollStart()
    if _ragActive or _exitingRag or _exitLock then return end
    if not (_hum and _hum.Health > 0) then return end

    _preRagCF = _safeCF()
    _ragActive = true
    _ragStart = tick()

    _tDelay(0.03 + _jitter(), function()
        if not CFG.antiRagdoll then _ragActive = false return end
        if not _ragActive then return end
        if _exitingRag or _exitLock then _ragActive = false return end
        if _hum and _hum.Health <= 0 then _ragActive = false return end
        _spawnGhost()
    end)
end

local function _checkRagdollEnd()
    if not _ragActive then return end
    if _exitingRag or _exitLock then return end
    if not (_hum and _char) then return end

    if _hum.Health <= 0 then
        _killGhost(false)
        _ragActive = false
        return
    end

    if tick() - _ragStart > _ragTimeout then
        _exitRagdoll()
        return
    end

    local st = _hum:GetState()
    local ps = false
    _pCall(function() ps = _hum.PlatformStand end)

    if not _isRagdoll(st) and st ~= _enumHS.PlatformStanding and not ps then
        _tDelay(0.08, function()
            if not _ragActive or _exitingRag or _exitLock then return end
            if not _hum then return end
            if _hum.Health <= 0 then _killGhost(false) _ragActive = false return end
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

    local c1 = _hum.StateChanged:Connect(function(_, newState)
        if not CFG.antiRagdoll then return end
        if _exitLock then return end
        if _isRagdoll(newState) or newState == _enumHS.PlatformStanding then
            _tDelay(_jitter(), _onRagdollStart)
        end
    end)
    _ragConns[#_ragConns + 1] = c1

    local c2 = _hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not CFG.antiRagdoll then return end
        if _exitLock then return end
        if _hum.PlatformStand and not _ragActive then
            _tDelay(_jitter(), _onRagdollStart)
        end
    end)
    _ragConns[#_ragConns + 1] = c2

    local c3 = _char.DescendantAdded:Connect(function(v)
        if not CFG.antiRagdoll then return end
        if _exitLock then return end
        _tDelay(_jitter(), function()
            _pCall(function()
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("NoCollisionConstraint") then
                    if not _ragActive and not _exitingRag and not _exitLock then _onRagdollStart() end
                end
            end)
        end)
    end)
    _ragConns[#_ragConns + 1] = c3

    local c4 = _char.DescendantRemoving:Connect(function(v)
        if not CFG.antiRagdoll then return end
        if _exitLock then return end
        if v:IsA("Motor6D") then
            local data = { name = v.Name, par = v.Parent, p0 = v.Part0, p1 = v.Part1, c0 = v.C0, c1 = v.C1 }
            local found = false
            for _, s in ipairs(_motorSnap) do
                if s.name == data.name and s.par == data.par then
                    s.c0 = data.c0
                    s.c1 = data.c1
                    found = true
                    break
                end
            end
            if not found then _motorSnap[#_motorSnap + 1] = data end
            if not _ragActive and not _exitingRag and not _exitLock then _onRagdollStart() end
        end
    end)
    _ragConns[#_ragConns + 1] = c4
end

local function _stopAntiRagdoll()
    for _, c in ipairs(_ragConns) do _pCall(function() c:Disconnect() end) end
    _ragConns = {}
    _killGhost(false)
    _ragActive = false
    _exitingRag = false
    _exitLock = false
    for _, m in ipairs(_fabricMotors) do _pCall(function() if m and m.Parent then m:Destroy() end end) end
    _fabricMotors = {}
    _motorSnap = {}
end

-- ═══════════ NO ANIMATIONS ═══════════
local function _hookTrack(track)
    if not track or _trackedAnims[track] then return end
    _trackedAnims[track] = true
    local c = track:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if not CFG.noAnim then return end
        if track.IsPlaying then
            _tDelay(_jitter(), function()
                _pCall(function() track:AdjustSpeed(0) track:AdjustWeight(0, 0) end)
            end)
        end
    end)
    _animConns[#_animConns + 1] = c
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
                _tDelay(_jitter(), function()
                    _pCall(function() t:AdjustSpeed(0) t:AdjustWeight(0, 0) end)
                end)
            end
        end)
        _animConns[#_animConns + 1] = c
    end)
    if _hum then
        for _, evt in ipairs({"Running", "Jumping", "Climbing", "Swimming", "FreeFalling"}) do
            _pCall(function()
                local c = _hum[evt]:Connect(function()
                    if CFG.noAnim then _tDefer(_stopAllTracks) end
                end)
                _animConns[#_animConns + 1] = c
            end)
        end
        local c = _hum.StateChanged:Connect(function()
            if CFG.noAnim then _tDefer(_stopAllTracks) end
        end)
        _animConns[#_animConns + 1] = c
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
        _pCall(function() if t and t.IsPlaying then t:AdjustSpeed(1) t:AdjustWeight(1, 0.1) end end)
    end
    _trackedAnims = {}
end

-- ═══════════ SPEED HACK ═══════════
local _origSpeed = 16

local function _startSpeed()
    _refreshChar()
    if _hum then
        _origSpeed = _hum.WalkSpeed
        _hum.WalkSpeed = CFG.speedValue
    end
end

local function _stopSpeed()
    if _hum then
        _hum.WalkSpeed = _origSpeed
    end
end

-- ═══════════ FLY ═══════════
local function _startFly()
    _refreshChar()
    if not (_rootPart and _hum) then return end
    _flying = true

    if _flyBV then _pCall(function() _flyBV:Destroy() end) end
    if _flyBG then _pCall(function() _flyBG:Destroy() end) end

    _flyBV = _iNew("BodyVelocity")
    _flyBV.Name = _genID(8)
    _flyBV.MaxForce = _v3(1e5, 1e5, 1e5)
    _flyBV.Velocity = _v3z
    _flyBV.P = 9000
    _flyBV.Parent = _rootPart

    _flyBG = _iNew("BodyGyro")
    _flyBG.Name = _genID(8)
    _flyBG.MaxTorque = _v3(1e5, 1e5, 1e5)
    _flyBG.P = 9000
    _flyBG.D = 500
    _flyBG.Parent = _rootPart
end

local function _controlFly()
    if not _flying then return end
    if not (_flyBV and _flyBV.Parent and _flyBG and _flyBG.Parent) then return end
    if not (_rootPart and _rootPart.Parent) then return end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local moveDir = _v3z
    local camCF = cam.CFrame

    if UIS:IsKeyDown(_enumKC.W) then moveDir = moveDir + camCF.LookVector end
    if UIS:IsKeyDown(_enumKC.S) then moveDir = moveDir - camCF.LookVector end
    if UIS:IsKeyDown(_enumKC.A) then moveDir = moveDir - camCF.RightVector end
    if UIS:IsKeyDown(_enumKC.D) then moveDir = moveDir + camCF.RightVector end
    if UIS:IsKeyDown(_enumKC.Space) then moveDir = moveDir + _v3(0, 1, 0) end
    if UIS:IsKeyDown(_enumKC.LeftControl) or UIS:IsKeyDown(_enumKC.LeftShift) then
        moveDir = moveDir - _v3(0, 1, 0)
    end

    if moveDir.Magnitude > 0.01 then
        moveDir = moveDir.Unit * CFG.flySpeed
    end

    _flyBV.Velocity = moveDir
    _flyBG.CFrame = camCF
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
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
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
        local char = player.Character
        if not char then return end

        -- Remove old
        if _espObjects[player] then
            for _, obj in ipairs(_espObjects[player]) do
                _pCall(function() obj:Destroy() end)
            end
        end
        _espObjects[player] = {}

        local hl = _iNew("Highlight")
        hl.Name = _genID(6)
        hl.FillColor = _c3(255, 50, 50)
        hl.FillTransparency = 0.65
        hl.OutlineColor = _c3(255, 255, 255)
        hl.OutlineTransparency = 0.2
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = char
        hl.Parent = char

        local bbg = _iNew("BillboardGui")
        bbg.Name = _genID(6)
        bbg.Size = _ud2(0, 120, 0, 30)
        bbg.StudsOffset = _v3(0, 3.5, 0)
        bbg.AlwaysOnTop = true
        bbg.Adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        bbg.Parent = char

        local nameTag = _iNew("TextLabel")
        nameTag.Size = _ud2(1, 0, 0.6, 0)
        nameTag.BackgroundTransparency = 1
        nameTag.Text = player.DisplayName
        nameTag.TextColor3 = _c3(255, 255, 255)
        nameTag.TextStrokeColor3 = _c3(0, 0, 0)
        nameTag.TextStrokeTransparency = 0.3
        nameTag.TextSize = 13
        nameTag.Font = Enum.Font.GothamBold
        nameTag.Parent = bbg

        local distTag = _iNew("TextLabel")
        distTag.Size = _ud2(1, 0, 0.4, 0)
        distTag.Position = _ud2(0, 0, 0.6, 0)
        distTag.BackgroundTransparency = 1
        distTag.Text = ""
        distTag.TextColor3 = _c3(200, 200, 200)
        distTag.TextStrokeColor3 = _c3(0, 0, 0)
        distTag.TextStrokeTransparency = 0.3
        distTag.TextSize = 10
        distTag.Font = Enum.Font.Gotham
        distTag.Parent = bbg

        -- Health bar
        local healthBG = _iNew("Frame")
        healthBG.Size = _ud2(0.7, 0, 0, 4)
        healthBG.Position = _ud2(0.15, 0, 1, 2)
        healthBG.BackgroundColor3 = _c3(30, 30, 30)
        healthBG.BorderSizePixel = 0
        healthBG.Parent = bbg
        local hc = _iNew("UICorner")
        hc.CornerRadius = _udim(0, 2)
        hc.Parent = healthBG

        local healthFill = _iNew("Frame")
        healthFill.Size = _ud2(1, 0, 1, 0)
        healthFill.BackgroundColor3 = _c3(50, 255, 100)
        healthFill.BorderSizePixel = 0
        healthFill.Parent = healthBG
        local hfc = _iNew("UICorner")
        hfc.CornerRadius = _udim(0, 2)
        hfc.Parent = healthFill

        _espObjects[player] = {hl, bbg}

        -- Update distance and health
        _tSpawn(function()
            while CFG.esp and bbg and bbg.Parent and char and char.Parent do
                _pCall(function()
                    if _rootPart and _rootPart.Parent then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local dist = (_rootPart.Position - hrp.Position).Magnitude
                            distTag.Text = _mFloor(dist) .. " studs"
                        end
                    end
                    local hum2 = char:FindFirstChildOfClass("Humanoid")
                    if hum2 then
                        local ratio = _mClamp(hum2.Health / hum2.MaxHealth, 0, 1)
                        healthFill.Size = _ud2(ratio, 0, 1, 0)
                        if ratio > 0.6 then
                            healthFill.BackgroundColor3 = _c3(50, 255, 100)
                        elseif ratio > 0.3 then
                            healthFill.BackgroundColor3 = _c3(255, 200, 50)
                        else
                            healthFill.BackgroundColor3 = _c3(255, 50, 50)
                        end
                    end
                end)
                _tWait(0.15)
            end
        end)
    end

    if player.Character then makeHighlight() end
    local conn = player.CharacterAdded:Connect(function()
        _tWait(0.5)
        if CFG.esp then makeHighlight() end
    end)
    _moduleConns[#_moduleConns + 1] = conn
end

local function _startESP()
    for _, p in ipairs(Players:GetPlayers()) do
        _createESP(p)
    end
    local conn = Players.PlayerAdded:Connect(function(p)
        if CFG.esp then _createESP(p) end
    end)
    _moduleConns[#_moduleConns + 1] = conn
end

local function _stopESP()
    for player, objs in pairs(_espObjects) do
        for _, obj in ipairs(objs) do
            _pCall(function() obj:Destroy() end)
        end
    end
    _espObjects = {}
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
        _origBright = Lighting.Brightness
        Lighting.Ambient = _c3(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.FogEnd = 1e10
    end)
end

local function _stopFullbright()
    _pCall(function()
        if _origAmbient then Lighting.Ambient = _origAmbient end
        if _origBright then Lighting.Brightness = _origBright end
    end)
end

-- ═══════════ NO FOG ═══════════
local function _startNoFog()
    _pCall(function()
        _origFogEnd = Lighting.FogEnd
        _origFogStart = Lighting.FogStart
        Lighting.FogEnd = 1e10
        Lighting.FogStart = 1e10
    end)
end

local function _stopNoFog()
    _pCall(function()
        if _origFogEnd then Lighting.FogEnd = _origFogEnd end
        if _origFogStart then Lighting.FogStart = _origFogStart end
    end)
end

-- ═══════════ LOW GRAVITY ═══════════
local _origGravity = workspace.Gravity

local function _startLowGravity()
    _origGravity = workspace.Gravity
    workspace.Gravity = 45
end

local function _stopLowGravity()
    workspace.Gravity = _origGravity
end

-- ═══════════ BIG HEAD (for all other players) ═══════════
local function _startBigHead()
    _tSpawn(function()
        while CFG.bigHead do
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    _pCall(function()
                        local head = p.Character:FindFirstChild("Head")
                        if head then
                            head.Size = _v3(5, 5, 5)
                        end
                    end)
                end
            end
            _tWait(0.5)
        end
        -- Reset
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                _pCall(function()
                    local head = p.Character:FindFirstChild("Head")
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

    if CFG.antiRagdoll and _ghostActive then
        _controlGhost()
    end

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

    if CFG.speed and _hum and _frameCount % 10 == 0 then
        _pCall(function() _hum.WalkSpeed = CFG.speedValue end)
    end
end)

-- ═══════════ RESPAWN ═══════════
LP.CharacterAdded:Connect(function()
    _tWait(_rF(0.3, 0.5))
    _killGhost(false)
    _ragActive = false
    _exitingRag = false
    _exitLock = false
    _preRagCF = nil
    _stopFly()
    _refreshChar()
    _tWait(_rF(0.15, 0.25))
    if CFG.antiRagdoll then _stopAntiRagdoll() _startAntiRagdoll() end
    if CFG.noAnim then _stopNoAnim() _tWait(0.12) _startNoAnim() end
    if CFG.speed then _startSpeed() end
    if CFG.fly then _startFly() end
    if CFG.noclip then _startNoclip() end
    if CFG.godMode then _startGodMode() end
end)


-- ══════════════════════════════════════════════════════
-- ══════════════ GUI v17.0 NOVA ═══════════════════════
-- ══════════════════════════════════════════════════════

local _guiName = _genID(20)
for _, g in ipairs(PG:GetChildren()) do
    _pCall(function()
        if g:IsA("ScreenGui") and g:GetAttribute("_novaTag") then
            g:Destroy()
        end
    end)
end

local SG = _iNew("ScreenGui")
SG.Name = _guiName
SG:SetAttribute("_novaTag", true)
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = _rI(2, 8)
SG.IgnoreGuiInset = false
SG.Parent = PG

-- ═══ PALETTE NOVA ═══
local P = {
    bg       = _c3(5, 5, 15),
    bgCard   = _c3(10, 10, 25),
    bgDeep   = _c3(3, 3, 10),
    header   = _c3(7, 7, 20),

    accent1  = _c3(130, 80, 255),
    accent2  = _c3(40, 195, 255),
    accent3  = _c3(255, 50, 90),
    accent4  = _c3(255, 195, 55),
    accent5  = _c3(55, 255, 150),
    accent6  = _c3(255, 110, 220),
    accent7  = _c3(255, 130, 50),
    accent8  = _c3(100, 200, 255),

    textW    = _c3(240, 240, 252),
    textD    = _c3(60, 60, 90),
    textG    = _c3(55, 255, 130),

    toggleOff     = _c3(18, 18, 34),
    toggleKnobOff = _c3(80, 80, 105),
    border        = _c3(25, 25, 48),
}

-- ═══ GUI HELPERS ═══
local function corner(parent, radius)
    local c = _iNew("UICorner")
    c.CornerRadius = _udim(0, radius or 12)
    c.Parent = parent
    return c
end

local function stroke(parent, col, thick, transp)
    local s = _iNew("UIStroke")
    s.Color = col or P.border
    s.Thickness = thick or 1
    s.Transparency = transp or 0.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function ti(dur, style, dir)
    return _twInfo(dur or 0.3, style or _enumES.Quint, dir or _enumED.Out)
end

local function tween(obj, info, props)
    return TweenService:Create(obj, info, props)
end

local function gradient(parent, colors, rotation, transparency)
    local g = _iNew("UIGradient")
    g.Color = colors or _csNew{_csk(0, P.accent1), _csk(1, P.accent2)}
    if rotation then g.Rotation = rotation end
    if transparency then g.Transparency = transparency end
    g.Parent = parent
    return g
end

-- ═══ DRAGGING ═══
local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart, startPos
    handle = handle or frame

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                         input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newPos = _ud2(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            tween(frame, ti(0.06, _enumES.Quad), {Position = newPos}):Play()
        end
    end)
end

-- ═══ MAIN FRAME ═══
local MF = _iNew("Frame")
MF.Name = _genID(6)
MF.Size = _ud2(0, 440, 0, 650)
MF.Position = _ud2(0.5, -220, 0.5, -325)
MF.BackgroundColor3 = P.bg
MF.BackgroundTransparency = 0.01
MF.BorderSizePixel = 0
MF.Active = true
MF.ClipsDescendants = true
MF.Parent = SG
corner(MF, 22)

local mainStroke = stroke(MF, P.accent1, 1.5, 0.5)

-- Aurora orbs
local auroraOrbs = {}
local auroraData = {
    {_ud2(0, -90, 0, -90),    P.accent1, 280, 0.91},
    {_ud2(1, -130, 1, -160),  P.accent2, 260, 0.91},
    {_ud2(0.1, 0, 0.25, 0),   P.accent6, 180, 0.93},
    {_ud2(0.88, 0, 0.03, 0),  P.accent5, 150, 0.94},
    {_ud2(0.45, -80, 0.6, 0), P.accent3, 200, 0.92},
    {_ud2(0, 0, 0.85, 0),     P.accent4, 130, 0.95},
    {_ud2(0.65, 0, 0.12, 0),  P.accent1, 110, 0.95},
    {_ud2(0.25, 0, 0.92, 0),  P.accent2, 100, 0.96},
}

for i, od in ipairs(auroraData) do
    local o = _iNew("Frame")
    o.Name = _genID(3)
    o.Size = _ud2(0, od[3], 0, od[3])
    o.Position = od[1]
    o.BackgroundColor3 = od[2]
    o.BackgroundTransparency = od[4]
    o.BorderSizePixel = 0
    o.ZIndex = 0
    o.Parent = MF
    corner(o, _mFloor(od[3] / 2))
    auroraOrbs[i] = o
end

-- ═══ HEADER ═══
local HD = _iNew("Frame")
HD.Name = _genID(4)
HD.Size = _ud2(1, 0, 0, 78)
HD.BackgroundColor3 = P.header
HD.BackgroundTransparency = 0.02
HD.BorderSizePixel = 0
HD.ZIndex = 5
HD.Parent = MF
corner(HD, 22)

local HDP = _iNew("Frame")
HDP.Size = _ud2(1, 0, 0, 28)
HDP.Position = _ud2(0, 0, 1, -28)
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
sepLine.BackgroundTransparency = 0.1
sepLine.BorderSizePixel = 0
sepLine.ZIndex = 6
sepLine.Parent = HD
corner(sepLine, 2)

local sepLineGrad = gradient(sepLine, _csNew{
    _csk(0, P.accent1),
    _csk(0.15, P.accent2),
    _csk(0.35, P.accent5),
    _csk(0.55, P.accent4),
    _csk(0.75, P.accent6),
    _csk(0.9, P.accent3),
    _csk(1, P.accent1),
})
sepLineGrad.Transparency = _nsNew{
    _nsk(0, 0.9),
    _nsk(0.1, 0),
    _nsk(0.9, 0),
    _nsk(1, 0.9),
}

_tSpawn(function()
    local offset = 0
    while SG and SG.Parent do
        offset = (offset + 0.0012) % 1
        _pCall(function()
            sepLineGrad.Offset = Vector2.new(_mSin(offset * _mPi * 2) * 0.35, 0)
        end)
        _tWait(0.02)
    end
end)

-- Logo
local logoContainer = _iNew("Frame")
logoContainer.Size = _ud2(0, 58, 0, 58)
logoContainer.Position = _ud2(0, 12, 0.5, -29)
logoContainer.BackgroundTransparency = 1
logoContainer.ZIndex = 6
logoContainer.Parent = HD

local logoRingFrames = {}
local ringData = {{58, 0.74, 22}, {46, 0.78, 16}, {36, 0.82, 12}}
for i, rd in ipairs(ringData) do
    local ring = _iNew("Frame")
    ring.Size = _ud2(0, rd[1], 0, rd[1])
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = _ud2(0.5, 0, 0.5, 0)
    ring.BackgroundColor3 = P.accent1
    ring.BackgroundTransparency = rd[2]
    ring.BorderSizePixel = 0
    ring.ZIndex = 6 + i
    ring.Parent = logoContainer
    corner(ring, _mFloor(rd[1] / 2))
    if i < 3 then stroke(ring, P.accent1, 0.6, 0.4 + i * 0.1) end
    logoRingFrames[i] = ring
end

local logoGlow = _iNew("Frame")
logoGlow.Size = _ud2(0, 22, 0, 22)
logoGlow.AnchorPoint = Vector2.new(0.5, 0.5)
logoGlow.Position = _ud2(0.5, 0, 0.5, 0)
logoGlow.BackgroundColor3 = P.accent1
logoGlow.BackgroundTransparency = 0.35
logoGlow.ZIndex = 10
logoGlow.Parent = logoContainer
corner(logoGlow, 11)

local logoText = _iNew("TextLabel")
logoText.Size = _ud2(1, 0, 1, 0)
logoText.BackgroundTransparency = 1
logoText.Text = "G"
logoText.TextColor3 = P.textW
logoText.TextSize = 16
logoText.Font = Enum.Font.GothamBlack
logoText.ZIndex = 11
logoText.Parent = logoRingFrames[3]

-- Title
local titleLbl = _iNew("TextLabel")
titleLbl.Size = _ud2(0, 200, 0, 28)
titleLbl.Position = _ud2(0, 82, 0, 8)
titleLbl.BackgroundTransparency = 1
titleLbl.RichText = true
titleLbl.Text = '<font color="#8250FF">GRANZ</font> <font color="#FFFFFF">HUB</font>'
titleLbl.TextSize = 21
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 6
titleLbl.Parent = HD

local subLbl = _iNew("TextLabel")
subLbl.Size = _ud2(0, 280, 0, 14)
subLbl.Position = _ud2(0, 82, 0, 38)
subLbl.BackgroundTransparency = 1
subLbl.Text = "nova · v17.0 · unified phantom engine"
subLbl.TextColor3 = P.textD
subLbl.TextSize = 9
subLbl.Font = Enum.Font.GothamMedium
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.ZIndex = 6
subLbl.Parent = HD

-- Badges
local badgeData = {
    {"NOVA",   P.accent1},
    {"v17.0",  P.accent5},
    {"UNIFIED",P.accent2},
    {"12 MODS",P.accent4},
}
local bx = 82
for _, bd in ipairs(badgeData) do
    local bf2 = _iNew("Frame")
    bf2.Size = _ud2(0, #bd[1] * 5.4 + 16, 0, 17)
    bf2.Position = _ud2(0, bx, 0, 55)
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

    bx = bx + #bd[1] * 5.4 + 21
end

-- Header buttons
local function makeHeaderBtn(pos, text, bgColor)
    local btn = _iNew("TextButton")
    btn.Size = _ud2(0, 36, 0, 36)
    btn.Position = pos
    btn.BackgroundColor3 = bgColor
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

    btn.MouseEnter:Connect(function()
        tween(btn, ti(0.2), {BackgroundTransparency = 0.15}):Play()
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, ti(0.2), {BackgroundTransparency = 0.5}):Play()
    end)
    return btn
end

local MinBtn = makeHeaderBtn(_ud2(1, -86, 0, 20), "━", _c3(32, 32, 52))
local ClsBtn = makeHeaderBtn(_ud2(1, -46, 0, 20), "✕", _c3(145, 25, 38))

-- ═══ TAB SYSTEM ═══
local currentTab = "combat"
local tabButtons = {}
local tabContents = {}

local tabBar = _iNew("Frame")
tabBar.Name = _genID(4)
tabBar.Size = _ud2(1, -12, 0, 38)
tabBar.Position = _ud2(0, 6, 0, 82)
tabBar.BackgroundColor3 = P.bgDeep
tabBar.BackgroundTransparency = 0.3
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 4
tabBar.Parent = MF
corner(tabBar, 12)

local tabLayout = _iNew("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = _udim(0, 4)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = tabBar

local tabPad = _iNew("UIPadding")
tabPad.PaddingLeft = _udim(0, 4)
tabPad.PaddingRight = _udim(0, 4)
tabPad.Parent = tabBar

local tabs = {
    {id = "combat",    icon = "⚔️",  name = "Combat",   color = P.accent3},
    {id = "movement",  icon = "🏃",  name = "Movement", color = P.accent1},
    {id = "visual",    icon = "👁️",  name = "Visual",   color = P.accent2},
    {id = "world",     icon = "🌍",  name = "World",    color = P.accent5},
}

local function switchTab(tabId)
    currentTab = tabId
    for id, btn in pairs(tabButtons) do
        local tabData
        for _, t in ipairs(tabs) do
            if t.id == id then tabData = t break end
        end
        if id == tabId then
            tween(btn, ti(0.3), {
                BackgroundColor3 = tabData.color,
                BackgroundTransparency = 0.15,
            }):Play()
            for _, child in ipairs(btn:GetChildren()) do
                if child:IsA("TextLabel") then
                    tween(child, ti(0.3), {TextColor3 = _c3(255, 255, 255)}):Play()
                end
            end
        else
            tween(btn, ti(0.3), {
                BackgroundColor3 = P.bgDeep,
                BackgroundTransparency = 0.5,
            }):Play()
            for _, child in ipairs(btn:GetChildren()) do
                if child:IsA("TextLabel") then
                    tween(child, ti(0.3), {TextColor3 = P.textD}):Play()
                end
            end
        end
    end
    for id, ct in pairs(tabContents) do
        ct.Visible = (id == tabId)
    end
end

for _, tabData in ipairs(tabs) do
    local btn = _iNew("TextButton")
    btn.Name = tabData.id
    btn.Size = _ud2(0, 95, 0, 30)
    btn.BackgroundColor3 = P.bgDeep
    btn.BackgroundTransparency = 0.5
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.ZIndex = 5
    btn.Parent = tabBar
    corner(btn, 9)

    local iconLbl = _iNew("TextLabel")
    iconLbl.Size = _ud2(0, 18, 1, 0)
    iconLbl.Position = _ud2(0, 6, 0, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = tabData.icon
    iconLbl.TextSize = 12
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextColor3 = P.textD
    iconLbl.ZIndex = 6
    iconLbl.Parent = btn

    local nameLbl = _iNew("TextLabel")
    nameLbl.Size = _ud2(1, -28, 1, 0)
    nameLbl.Position = _ud2(0, 26, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = tabData.name
    nameLbl.TextSize = 10
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextColor3 = P.textD
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 6
    nameLbl.Parent = btn

    btn.MouseButton1Click:Connect(function()
        switchTab(tabData.id)
    end)

    tabButtons[tabData.id] = btn
end

-- ═══ CONTENT AREA ═══
local contentFrame = _iNew("Frame")
contentFrame.Size = _ud2(1, -12, 1, -132)
contentFrame.Position = _ud2(0, 6, 0, 124)
contentFrame.BackgroundTransparency = 1
contentFrame.ZIndex = 3
contentFrame.Parent = MF

-- Create tab content scrolling frames
for _, tabData in ipairs(tabs) do
    local scroll = _iNew("ScrollingFrame")
    scroll.Name = tabData.id
    scroll.Size = _ud2(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = tabData.color
    scroll.ScrollBarImageTransparency = 0.5
    scroll.CanvasSize = _ud2(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Visible = (tabData.id == "combat")
    scroll.ZIndex = 3
    scroll.Parent = contentFrame

    local layout = _iNew("UIListLayout")
    layout.Padding = _udim(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local pad = _iNew("UIPadding")
    pad.PaddingTop = _udim(0, 3)
    pad.PaddingBottom = _udim(0, 14)
    pad.PaddingLeft = _udim(0, 2)
    pad.PaddingRight = _udim(0, 2)
    pad.Parent = scroll

    tabContents[tabData.id] = scroll
end

-- ═══ MODULE CARD FACTORY ═══
local allModuleData = {} -- for status tracking

local function createModule(tabId, icon, name, desc, order, accentColor, tags, cfgKey, onEnable, onDisable)
    local parentScroll = tabContents[tabId]
    if not parentScroll then return end

    local card = _iNew("Frame")
    card.Name = _genID(5)
    card.Size = _ud2(1, 0, 0, 88)
    card.BackgroundColor3 = P.bgCard
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 3
    card.ClipsDescendants = true
    card.Parent = parentScroll
    corner(card, 16)

    local cardStroke = stroke(card, P.border, 0.6, 0.55)

    -- Glass
    local glass = _iNew("Frame")
    glass.Size = _ud2(1, 0, 0.45, 0)
    glass.BackgroundColor3 = _c3(255, 255, 255)
    glass.BackgroundTransparency = 0.97
    glass.BorderSizePixel = 0
    glass.ZIndex = 3
    glass.Parent = card
    corner(glass, 16)

    -- Left bar
    local leftBar = _iNew("Frame")
    leftBar.Size = _ud2(0, 3, 0.35, 0)
    leftBar.Position = _ud2(0, 0, 0.325, 0)
    leftBar.BackgroundColor3 = accentColor
    leftBar.BackgroundTransparency = 0.25
    leftBar.BorderSizePixel = 0
    leftBar.ZIndex = 4
    leftBar.Parent = card
    corner(leftBar, 2)

    -- Icon
    local iconBg = _iNew("Frame")
    iconBg.Size = _ud2(0, 46, 0, 46)
    iconBg.Position = _ud2(0, 12, 0, 10)
    iconBg.BackgroundColor3 = accentColor
    iconBg.BackgroundTransparency = 0.88
    iconBg.BorderSizePixel = 0
    iconBg.ZIndex = 4
    iconBg.Parent = card
    corner(iconBg, 14)

    local iconInner = _iNew("Frame")
    iconInner.Size = _ud2(0, 30, 0, 30)
    iconInner.AnchorPoint = Vector2.new(0.5, 0.5)
    iconInner.Position = _ud2(0.5, 0, 0.5, 0)
    iconInner.BackgroundColor3 = accentColor
    iconInner.BackgroundTransparency = 0.72
    iconInner.BorderSizePixel = 0
    iconInner.ZIndex = 5
    iconInner.Parent = iconBg
    corner(iconInner, 10)

    local iconLabel = _iNew("TextLabel")
    iconLabel.Size = _ud2(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextSize = 16
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.ZIndex = 6
    iconLabel.Parent = iconInner

    -- Name
    local nameLabel = _iNew("TextLabel")
    nameLabel.Size = _ud2(1, -140, 0, 20)
    nameLabel.Position = _ud2(0, 68, 0, 12)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = P.textW
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 4
    nameLabel.Parent = card

    -- Desc
    local descLabel = _iNew("TextLabel")
    descLabel.Size = _ud2(1, -140, 0, 12)
    descLabel.Position = _ud2(0, 68, 0, 34)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = desc
    descLabel.TextColor3 = P.textD
    descLabel.TextSize = 9
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.ZIndex = 4
    descLabel.Parent = card

    -- Tags
    if tags then
        local tx = 68
        for _, tagText in ipairs(tags) do
            local tagFrame = _iNew("Frame")
            tagFrame.Size = _ud2(0, #tagText * 5.2 + 14, 0, 16)
            tagFrame.Position = _ud2(0, tx, 0, 52)
            tagFrame.BackgroundColor3 = accentColor
            tagFrame.BackgroundTransparency = 0.88
            tagFrame.BorderSizePixel = 0
            tagFrame.ZIndex = 4
            tagFrame.Parent = card
            corner(tagFrame, 5)

            local tagLabel = _iNew("TextLabel")
            tagLabel.Size = _ud2(1, 0, 1, 0)
            tagLabel.BackgroundTransparency = 1
            tagLabel.Text = tagText
            tagLabel.TextColor3 = accentColor
            tagLabel.TextSize = 6.5
            tagLabel.Font = Enum.Font.GothamBlack
            tagLabel.ZIndex = 5
            tagLabel.Parent = tagFrame

            tx = tx + #tagText * 5.2 + 18
        end
    end

    -- Bottom line
    local bottomLine = _iNew("Frame")
    bottomLine.Size = _ud2(0, 0, 0, 2)
    bottomLine.AnchorPoint = Vector2.new(0.5, 0)
    bottomLine.Position = _ud2(0.5, 0, 1, -3)
    bottomLine.BackgroundColor3 = accentColor
    bottomLine.BackgroundTransparency = 0.3
    bottomLine.BorderSizePixel = 0
    bottomLine.ZIndex = 4
    bottomLine.Parent = card
    corner(bottomLine, 1)
    gradient(bottomLine, _csNew{_csk(0, accentColor), _csk(0.5, P.accent2), _csk(1, accentColor)})

    -- Toggle
    local toggleBtn = _iNew("TextButton")
    toggleBtn.Size = _ud2(0, 52, 0, 26)
    toggleBtn.Position = _ud2(1, -64, 0.5, -13)
    toggleBtn.BackgroundColor3 = P.toggleOff
    toggleBtn.Text = ""
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 4
    toggleBtn.Parent = card
    corner(toggleBtn, 13)
    local toggleStroke = stroke(toggleBtn, P.border, 0.5, 0.5)

    local knob = _iNew("Frame")
    knob.Size = _ud2(0, 20, 0, 20)
    knob.Position = _ud2(0, 3, 0.5, -10)
    knob.BackgroundColor3 = P.toggleKnobOff
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = toggleBtn
    corner(knob, 10)
    local knobStroke = stroke(knob, accentColor, 0, 0.8)

    local knobDot = _iNew("Frame")
    knobDot.Size = _ud2(0, 7, 0, 7)
    knobDot.AnchorPoint = Vector2.new(0.5, 0.5)
    knobDot.Position = _ud2(0.5, 0, 0.5, 0)
    knobDot.BackgroundColor3 = accentColor
    knobDot.BackgroundTransparency = 1
    knobDot.BorderSizePixel = 0
    knobDot.ZIndex = 6
    knobDot.Parent = knob
    corner(knobDot, 4)

    -- Hover
    local hoverBtn = _iNew("TextButton")
    hoverBtn.Size = _ud2(1, 0, 1, 0)
    hoverBtn.BackgroundTransparency = 1
    hoverBtn.Text = ""
    hoverBtn.ZIndex = 3
    hoverBtn.Parent = card

    hoverBtn.MouseEnter:Connect(function()
        tween(card, ti(0.25), {BackgroundTransparency = 0}):Play()
        tween(cardStroke, ti(0.25), {Transparency = 0.15, Color = accentColor}):Play()
        tween(leftBar, ti(0.3), {BackgroundTransparency = 0, Size = _ud2(0, 4.5, 0.45, 0)}):Play()
        tween(bottomLine, ti(0.4), {Size = _ud2(0.8, 0, 0, 2.5)}):Play()
    end)
    hoverBtn.MouseLeave:Connect(function()
        tween(card, ti(0.25), {BackgroundTransparency = 0.05}):Play()
        tween(cardStroke, ti(0.25), {Transparency = 0.55, Color = P.border}):Play()
        tween(leftBar, ti(0.3), {BackgroundTransparency = 0.25, Size = _ud2(0, 3, 0.35, 0)}):Play()
        tween(bottomLine, ti(0.4), {Size = _ud2(0, 0, 0, 2)}):Play()
    end)

    local isOn = false

    local function setVisual(state)
        isOn = state
        local t = ti(0.35)

        if state then
            tween(toggleBtn, t, {BackgroundColor3 = accentColor}):Play()
            tween(toggleStroke, t, {Color = accentColor, Transparency = 0.1}):Play()
            tween(knob, t, {Position = _ud2(1, -23, 0.5, -10), BackgroundColor3 = _c3(255, 255, 255)}):Play()
            tween(knobStroke, t, {Thickness = 2, Transparency = 0}):Play()
            tween(knobDot, t, {BackgroundTransparency = 0}):Play()
            tween(cardStroke, t, {Color = accentColor, Transparency = 0.2}):Play()
            tween(leftBar, t, {BackgroundTransparency = 0}):Play()
            tween(iconInner, t, {BackgroundTransparency = 0.5}):Play()

            tween(toggleBtn, _twInfo(0.1, _enumES.Quad, _enumED.Out, 0, true), {
                Size = _ud2(0, 56, 0, 30)
            }):Play()
            tween(bottomLine, _twInfo(0.45, _enumES.Quint), {
                Size = _ud2(0.9, 0, 0, 2.5), BackgroundTransparency = 0.1
            }):Play()
            _tDelay(0.5, function()
                if isOn then
                    _pCall(function()
                        tween(bottomLine, ti(0.6), {
                            Size = _ud2(0.3, 0, 0, 2), BackgroundTransparency = 0.3
                        }):Play()
                    end)
                end
            end)
        else
            tween(toggleBtn, t, {BackgroundColor3 = P.toggleOff}):Play()
            tween(toggleStroke, t, {Color = P.border, Transparency = 0.5}):Play()
            tween(knob, t, {Position = _ud2(0, 3, 0.5, -10), BackgroundColor3 = P.toggleKnobOff}):Play()
            tween(knobStroke, t, {Thickness = 0, Transparency = 0.8}):Play()
            tween(knobDot, t, {BackgroundTransparency = 1}):Play()
            tween(cardStroke, t, {Color = P.border, Transparency = 0.55}):Play()
            tween(leftBar, t, {BackgroundTransparency = 0.25}):Play()
            tween(iconInner, t, {BackgroundTransparency = 0.72}):Play()
            tween(bottomLine, ti(0.3), {Size = _ud2(0, 0, 0, 2), BackgroundTransparency = 0.3}):Play()
        end
    end

    allModuleData[#allModuleData + 1] = {cfgKey = cfgKey, color = accentColor}

    toggleBtn.MouseButton1Click:Connect(function()
        CFG[cfgKey] = not CFG[cfgKey]
        setVisual(CFG[cfgKey])
        if CFG[cfgKey] then
            _refreshChar()
            if onEnable then onEnable() end
        else
            if onDisable then onDisable() end
        end
        updateStatus()
    end)

    return toggleBtn, setVisual
end

-- ═══ CREATE ALL MODULES ═══

-- COMBAT TAB
createModule("combat", "🛡️", "God Mode", "Бесконечное здоровье",
    1, P.accent3, {"IMMORTAL", "v2"}, "godMode", _startGodMode, _stopGodMode)

createModule("combat", "💀", "Big Head", "Увеличивает головы врагов (хитбокс)",
    2, P.accent7, {"HITBOX", "PVP"}, "bigHead", _startBigHead, function() CFG.bigHead = false end)

createModule("combat", "👻", "Anti-Ragdoll", "Ghost-контроль при рагдолле",
    3, P.accent2, {"GHOST", "v8", "FIXED"}, "antiRagdoll", _startAntiRagdoll, _stopAntiRagdoll)

-- MOVEMENT TAB
createModule("movement", "⚡", "Infinite Jump", "Прыжки в воздухе",
    1, P.accent1, {"AIR", "MULTI"}, "infJump", function() end, function() end)

createModule("movement", "🏃", "Speed", "Ускорение передвижения (x2)",
    2, P.accent4, {"FAST", "x2"}, "speed", _startSpeed, _stopSpeed)

createModule("movement", "🕊️", "Fly", "Свободный полёт (WASD + Space/Ctrl)",
    3, P.accent8, {"FLY", "3D"}, "fly", _startFly, _stopFly)

createModule("movement", "👤", "Noclip", "Проход сквозь стены",
    4, P.accent6, {"PHASE", "CLIP"}, "noclip", _startNoclip, _stopNoclip)

createModule("movement", "🌙", "Low Gravity", "Пониженная гравитация",
    5, _c3(180, 130, 255), {"MOON", "FLOAT"}, "lowGravity", _startLowGravity, _stopLowGravity)

-- VISUAL TAB
createModule("visual", "🎭", "No Animations", "Заморозка всех анимаций",
    1, P.accent3, {"FREEZE", "SILENT"}, "noAnim", _startNoAnim, _stopNoAnim)

createModule("visual", "👁️", "ESP", "Видеть игроков сквозь стены",
    2, P.accent5, {"WALLHACK", "HP"}, "esp", _startESP, _stopESP)

createModule("visual", "☀️", "Fullbright", "Максимальная яркость",
    3, P.accent4, {"BRIGHT", "LIGHT"}, "fullbright", _startFullbright, _stopFullbright)

-- WORLD TAB
createModule("world", "🌫️", "No Fog", "Убрать весь туман",
    1, P.accent8, {"CLEAR", "VIEW"}, "noFog", _startNoFog, _stopNoFog)

-- ═══ STATUS BAR ═══
local SB = _iNew("Frame")
SB.Size = _ud2(1, -12, 0, 50)
SB.Position = _ud2(0, 6, 1, -56)
SB.BackgroundColor3 = P.bgDeep
SB.BackgroundTransparency = 0.1
SB.BorderSizePixel = 0
SB.ZIndex = 5
SB.Parent = MF
corner(SB, 14)
stroke(SB, P.border, 0.5, 0.6)

local statusLabel = _iNew("TextLabel")
statusLabel.Size = _ud2(0.6, 0, 0, 18)
statusLabel.Position = _ud2(0, 14, 0, 6)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = P.textD
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.ZIndex = 6
statusLabel.Parent = SB

local ghostInfoLabel = _iNew("TextLabel")
ghostInfoLabel.Size = _ud2(0.6, 0, 0, 12)
ghostInfoLabel.Position = _ud2(0, 14, 0, 26)
ghostInfoLabel.BackgroundTransparency = 1
ghostInfoLabel.Text = ""
ghostInfoLabel.TextColor3 = P.accent2
ghostInfoLabel.TextSize = 8.5
ghostInfoLabel.Font = Enum.Font.Gotham
ghostInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
ghostInfoLabel.ZIndex = 6
ghostInfoLabel.Parent = SB

local pingLabel = _iNew("TextLabel")
pingLabel.Size = _ud2(0, 80, 0, 12)
pingLabel.Position = _ud2(1, -90, 0, 6)
pingLabel.BackgroundTransparency = 1
pingLabel.Text = "●  " .. _rI(10, 35) .. "ms"
pingLabel.TextColor3 = P.textG
pingLabel.TextSize = 8
pingLabel.Font = Enum.Font.GothamMedium
pingLabel.TextXAlignment = Enum.TextXAlignment.Right
pingLabel.ZIndex = 6
pingLabel.Parent = SB

local fpsLabel = _iNew("TextLabel")
fpsLabel.Size = _ud2(0, 80, 0, 12)
fpsLabel.Position = _ud2(1, -90, 0, 20)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "60 FPS"
fpsLabel.TextColor3 = P.textD
fpsLabel.TextSize = 8
fpsLabel.Font = Enum.Font.GothamMedium
fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
fpsLabel.ZIndex = 6
fpsLabel.Parent = SB

-- Active module dots
local activeDots = {}
for i = 1, 10 do
    local dot = _iNew("Frame")
    dot.Size = _ud2(0, 6, 0, 6)
    dot.Position = _ud2(0, 14 + (i - 1) * 10, 0, 40)
    dot.BackgroundColor3 = _c3(20, 20, 35)
    dot.BorderSizePixel = 0
    dot.ZIndex = 6
    dot.Parent = SB
    corner(dot, 3)
    activeDots[i] = dot
end

function updateStatus()
    local keys = {"infJump", "antiRagdoll", "noAnim", "speed", "fly", "noclip", "esp", "godMode", "fullbright", "noFog", "bigHead", "lowGravity"}
    local count = 0
    local activeColors = {}
    for _, k in ipairs(keys) do
        if CFG[k] then
            count += 1
            for _, md in ipairs(allModuleData) do
                if md.cfgKey == k then
                    activeColors[#activeColors + 1] = md.color
                    break
                end
            end
        end
    end

    -- Update dots
    for i = 1, 10 do
        if i <= count and activeColors[i] then
            tween(activeDots[i], ti(0.3), {BackgroundColor3 = activeColors[i]}):Play()
        else
            tween(activeDots[i], ti(0.3), {BackgroundColor3 = _c3(20, 20, 35)}):Play()
        end
    end

    if count == 0 then
        statusLabel.Text = "Все модули неактивны"
        tween(statusLabel, ti(0.3), {TextColor3 = P.textD}):Play()
    else
        statusLabel.Text = count .. "/12 · NOVA ACTIVE"
        tween(statusLabel, ti(0.3), {TextColor3 = P.textG}):Play()
    end
end

-- Status update loop
_tSpawn(function()
    while SG and SG.Parent do
        if _ghostActive then
            local elapsed = _mFloor(tick() - _ragStart)
            ghostInfoLabel.Text = "👻 GHOST · " .. elapsed .. "s · free movement"
            ghostInfoLabel.TextColor3 = _c3h((tick() * 0.2) % 1, 0.35, 1)
        elseif _exitLock then
            ghostInfoLabel.Text = "⟳ Stabilizing..."
            ghostInfoLabel.TextColor3 = P.accent4
        elseif _flying then
            ghostInfoLabel.Text = "🕊️ Flying · " .. CFG.flySpeed .. " speed"
            ghostInfoLabel.TextColor3 = P.accent8
        else
            ghostInfoLabel.Text = ""
        end
        _pCall(function()
            pingLabel.Text = "●  " .. _rI(6, 45) .. "ms"
            local fps = _mFloor(1 / RunService.Heartbeat:Wait())
            fpsLabel.Text = fps .. " FPS"
        end)
        _tWait(0.12)
    end
end)

-- ═══ MINIMIZE / CLOSE ═══
local minimized = false
local fullSize = _ud2(0, 440, 0, 650)

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(MF, _twInfo(0.5, _enumES.Back, _enumED.In), {
            Size = _ud2(0, 440, 0, 78)
        }):Play()
        _tDelay(0.06, function()
            contentFrame.Visible = false
            tabBar.Visible = false
            SB.Visible = false
        end)
        MinBtn.Text = "◻"
    else
        tween(MF, _twInfo(0.55, _enumES.Back), {Size = fullSize}):Play()
        _tDelay(0.25, function()
            contentFrame.Visible = true
            tabBar.Visible = true
            SB.Visible = true
        end)
        MinBtn.Text = "━"
    end
end)

ClsBtn.MouseButton1Click:Connect(function()
    -- Disable everything
    for k, v in pairs(CFG) do
        if type(v) == "boolean" then CFG[k] = false end
    end
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
    if _heartbeatC then _heartbeatC:Disconnect() end

    tween(mainStroke, ti(0.15), {Transparency = 1}):Play()

    -- Fade content
    for _, child in ipairs(contentFrame:GetDescendants()) do
        _pCall(function()
            if child:IsA("TextLabel") then tween(child, ti(0.1), {TextTransparency = 1}):Play() end
            if child:IsA("Frame") then tween(child, ti(0.1), {BackgroundTransparency = 1}):Play() end
            if child:IsA("TextButton") then tween(child, ti(0.1), {TextTransparency = 1, BackgroundTransparency = 1}):Play() end
        end)
    end

    _tDelay(0.1, function()
        tween(MF, _twInfo(0.5, _enumES.Back, _enumED.In), {
            Size = _ud2(0, 6, 0, 6),
            Position = _ud2(0.5, -3, 0.5, -3),
            BackgroundTransparency = 0.3
        }):Play()
    end)
    _tDelay(0.45, function()
        tween(MF, ti(0.15), {BackgroundTransparency = 1}):Play()
    end)
    _tDelay(0.62, function()
        _pCall(function() SG:Destroy() end)
    end)
end)

-- ═══ LIVE ANIMATIONS ═══

-- Border color
_tSpawn(function()
    local hue = _rF(0, 1)
    while SG and SG.Parent do
        hue = (hue + 0.001) % 1
        local activeCount = 0
        for k, v in pairs(CFG) do
            if type(v) == "boolean" and v then activeCount += 1 end
        end

        local t = tick()
        if activeCount > 0 then
            local sat = _mClamp(0.35 + activeCount * 0.05, 0, 0.8)
            local val = _mClamp(0.65 + activeCount * 0.03, 0, 1)
            mainStroke.Color = _c3h(hue, sat, val)
            mainStroke.Transparency = 0.02 + _mSin(t * 1.5) * 0.05
            mainStroke.Thickness = 1.5 + _mSin(t * 2) * 0.4

            _pCall(function()
                for _, ring in ipairs(logoRingFrames) do
                    ring.BackgroundColor3 = _c3h((hue + 0.06) % 1, 0.5, 0.85)
                end
                logoGlow.BackgroundColor3 = _c3h((hue + 0.12) % 1, 0.55, 1)
            end)
        else
            mainStroke.Color = P.border
            mainStroke.Transparency = 0.55
            mainStroke.Thickness = 1
            _pCall(function()
                for _, ring in ipairs(logoRingFrames) do
                    ring.BackgroundColor3 = P.accent1
                end
                logoGlow.BackgroundColor3 = P.accent1
            end)
        end
        _tWait(0.02)
    end
end)

-- Aurora float
_tSpawn(function()
    local phases = {}
    for i = 1, #auroraData do phases[i] = _rF(0, _mPi * 2) end
    while SG and SG.Parent do
        local t = tick()
        for i, o in ipairs(auroraOrbs) do
            _pCall(function()
                local od = auroraData[i]
                local ph = phases[i]
                local ox = _mSin(t * (0.12 + i * 0.05) + ph) * 14
                local oy = _mCos(t * (0.15 + i * 0.04) + ph * 0.7) * 11
                o.Position = _ud2(od[1].X.Scale, od[1].X.Offset + ox, od[1].Y.Scale, od[1].Y.Offset + oy)
                o.BackgroundTransparency = od[4] + _mSin(t * (0.3 + i * 0.06)) * 0.012
            end)
        end
        _tWait(0.025)
    end
end)

-- Logo pulse
_tSpawn(function()
    while SG and SG.Parent do
        local ac = 0
        for k, v in pairs(CFG) do
            if type(v) == "boolean" and v then ac += 1 end
        end
        if ac > 0 then
            for i, ring in ipairs(logoRingFrames) do
                _pCall(function()
                    local rd = ringData[i]
                    tween(ring, _twInfo(2.2, _enumES.Sine, _enumED.InOut), {
                        BackgroundTransparency = rd[2] - 0.06,
                        Size = _ud2(0, rd[1] + 4, 0, rd[1] + 4),
                    }):Play()
                end)
            end
            _pCall(function()
                tween(logoGlow, _twInfo(2.2, _enumES.Sine, _enumED.InOut), {
                    BackgroundTransparency = 0.15,
                    Size = _ud2(0, 26, 0, 26),
                }):Play()
            end)
            _tWait(2.2)
            if not (SG and SG.Parent) then return end
            for i, ring in ipairs(logoRingFrames) do
                _pCall(function()
                    local rd = ringData[i]
                    tween(ring, _twInfo(2.2, _enumES.Sine, _enumED.InOut), {
                        BackgroundTransparency = rd[2],
                        Size = _ud2(0, rd[1], 0, rd[1]),
                    }):Play()
                end)
            end
            _pCall(function()
                tween(logoGlow, _twInfo(2.2, _enumES.Sine, _enumED.InOut), {
                    BackgroundTransparency = 0.35,
                    Size = _ud2(0, 22, 0, 22),
                }):Play()
            end)
            _tWait(2.2)
        else
            _tWait(0.5)
        end
    end
end)

-- Dot pulse
_tSpawn(function()
    while SG and SG.Parent do
        local count = 0
        for k, v in pairs(CFG) do
            if type(v) == "boolean" and v then count += 1 end
        end
        for i = 1, math.min(count, 10) do
            _pCall(function()
                tween(activeDots[i], _twInfo(0.8, _enumES.Sine, _enumED.InOut), {
                    Size = _ud2(0, 8, 0, 8),
                }):Play()
            end)
        end
        _tWait(0.8)
        if not (SG and SG.Parent) then return end
        for i = 1, 10 do
            _pCall(function()
                tween(activeDots[i], _twInfo(0.8, _enumES.Sine, _enumED.InOut), {
                    Size = _ud2(0, 6, 0, 6),
                }):Play()
            end)
        end
        _tWait(0.8)
    end
end)

-- ═══ OPENING ANIMATION ═══
MF.BackgroundTransparency = 1
contentFrame.Visible = false
tabBar.Visible = false
SB.Visible = false
mainStroke.Transparency = 1
HD.BackgroundTransparency = 1
HDP.BackgroundTransparency = 1

for _, child in ipairs(HD:GetDescendants()) do
    _pCall(function()
        if child:IsA("TextLabel") or child:IsA("TextButton") then child.TextTransparency = 1 end
        if child:IsA("Frame") then child.BackgroundTransparency = 1 end
    end)
end

for _, orb in ipairs(auroraOrbs) do orb.BackgroundTransparency = 1 end

_tDelay(0.05, function()
    -- Point
    MF.Size = _ud2(0, 6, 0, 6)
    MF.Position = _ud2(0.5, -3, 0.5, -3)
    tween(MF, ti(0.12), {BackgroundTransparency = 0}):Play()
    tween(mainStroke, ti(0.12), {Transparency = 0.1}):Play()
    _tWait(0.1)

    -- H-expand
    tween(MF, _twInfo(0.3, _enumES.Quint), {
        Size = _ud2(0, 440, 0, 6),
        Position = _ud2(0.5, -220, 0.5, -3),
    }):Play()
    _tWait(0.25)

    -- V-expand
    tween(MF, _twInfo(0.55, _enumES.Back, _enumED.Out), {
        Size = _ud2(0, 440, 0, 650),
        Position = _ud2(0.5, -220, 0.5, -325),
    }):Play()
    _tWait(0.2)

    -- Orbs
    for i, orb in ipairs(auroraOrbs) do
        _tDelay(i * 0.03, function()
            tween(orb, _twInfo(0.7, _enumES.Quint), {
                BackgroundTransparency = auroraData[i][4]
            }):Play()
        end)
    end

    -- Header
    _tDelay(0.12, function()
        tween(HD, ti(0.35), {BackgroundTransparency = 0.02}):Play()
        tween(HDP, ti(0.35), {BackgroundTransparency = 0.02}):Play()

        local delay = 0
        for _, child in ipairs(HD:GetDescendants()) do
            _pCall(function()
                delay = delay + 0.01
                if child:IsA("TextLabel") then
                    _tDelay(delay, function()
                        tween(child, ti(0.4), {TextTransparency = 0}):Play()
                    end)
                end
                if child:IsA("TextButton") then
                    _tDelay(delay, function()
                        tween(child, ti(0.4), {TextTransparency = 0, BackgroundTransparency = 0.5}):Play()
                    end)
                end
                if child:IsA("Frame") and child ~= HDP then
                    _tDelay(delay, function()
                        local target = 0.85
                        if child == logoRingFrames[1] then target = ringData[1][2]
                        elseif child == logoRingFrames[2] then target = ringData[2][2]
                        elseif child == logoRingFrames[3] then target = ringData[3][2]
                        elseif child == logoGlow then target = 0.35
                        end
                        tween(child, ti(0.45), {BackgroundTransparency = target}):Play()
                    end)
                end
            end)
        end
    end)

    _tWait(0.3)

    -- Tab bar
    tabBar.Visible = true
    tabBar.BackgroundTransparency = 1
    tween(tabBar, ti(0.4), {BackgroundTransparency = 0.3}):Play()
    for _, child in ipairs(tabBar:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundTransparency = 1
            tween(child, ti(0.4), {BackgroundTransparency = 0.5}):Play()
            for _, desc in ipairs(child:GetChildren()) do
                if desc:IsA("TextLabel") then
                    desc.TextTransparency = 1
                    tween(desc, ti(0.4), {TextTransparency = 0}):Play()
                end
            end
        end
    end

    _tWait(0.15)

    -- Content
    contentFrame.Visible = true

    -- Status bar
    SB.Visible = true
    SB.BackgroundTransparency = 1
    tween(SB, ti(0.5), {BackgroundTransparency = 0.1}):Play()
    for _, child in ipairs(SB:GetChildren()) do
        _pCall(function()
            if child:IsA("TextLabel") then
                child.TextTransparency = 1
                tween(child, ti(0.5), {TextTransparency = 0}):Play()
            end
            if child:IsA("Frame") then
                child.BackgroundTransparency = 1
                tween(child, ti(0.5), {BackgroundTransparency = 0.5}):Play()
            end
        end)
    end

    -- Cascade cards in current tab
    local visibleScroll = tabContents[currentTab]
    if visibleScroll then
        local cardIdx = 0
        for _, child in ipairs(visibleScroll:GetChildren()) do
            if child:IsA("Frame") then
                cardIdx += 1
                local idx = cardIdx
                child.BackgroundTransparency = 1

                for _, desc in ipairs(child:GetDescendants()) do
                    _pCall(function()
                        if desc:IsA("TextLabel") then desc.TextTransparency = 1 end
                        if desc:IsA("Frame") then desc.BackgroundTransparency = 1 end
                        if desc:IsA("TextButton") then
                            desc.TextTransparency = 1
                            desc.BackgroundTransparency = 1
                        end
                    end)
                end

                _tDelay(idx * 0.08, function()
                    tween(child, _twInfo(0.5, _enumES.Quint), {
                        BackgroundTransparency = 0.05,
                    }):Play()

                    _tDelay(0.08, function()
                        for _, desc in ipairs(child:GetDescendants()) do
                            _pCall(function()
                                if desc:IsA("TextLabel") then
                                    tween(desc, ti(0.4), {TextTransparency = 0}):Play()
                                end
                                if desc:IsA("Frame") then
                                    local ft = 0.85
                                    if desc.Size.X.Offset <= 5 then ft = 0.25
                                    elseif desc.Size.X.Offset <= 20 then ft = 0.45
                                    elseif desc.Size.X.Offset <= 55 then ft = 0.72
                                    end
                                    tween(desc, ti(0.4), {BackgroundTransparency = ft}):Play()
                                end
                                if desc:IsA("TextButton") then
                                    tween(desc, ti(0.4), {
                                        TextTransparency = 0,
                                        BackgroundTransparency = 0.4
                                    }):Play()
                                end
                            end)
                        end
                    end)
                end)
            end
        end
    end

    _tDelay(0.9, function()
        tween(mainStroke, ti(0.5), {Transparency = 0.5}):Play()
    end)
end)

-- Initial tab
switchTab("combat")
updateStatus()
