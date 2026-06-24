--[[
    ████████████████████████████████████████████
    ██  RUNTIME PAYLOAD — DO NOT EDIT        ██
    ████████████████████████████████████████████
]]

-- ═══════════ POLYMORPHIC ANTI-DETECTION LAYER ═══════════
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

-- Spoofed environment wrapper
local _spoof_mt = {
    __index = function(_, k)
        return rawget(_, k)
    end,
    __newindex = function(_, k, v)
        rawset(_, k, v)
    end,
    __metatable = "locked"
}

-- Proxy service cache with delayed resolution
local _SVC = setmetatable({}, {
    __index = function(self, key)
        local s, v = pcall(game.GetService, game, key)
        if s and v then rawset(self, key, v) end
        return v
    end
})

local Players        = _SVC.Players
local UIS            = _SVC.UserInputService
local RunService     = _SVC.RunService
local TweenService   = _SVC.TweenService
local StarterGui     = _SVC.StarterGui
local Debris         = _SVC.Debris

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")
local Cam = workspace.CurrentCamera

-- ═══════════ ANTI-DETECTION: Obfuscated globals ═══════════
local _tWait   = task.wait
local _tDelay  = task.delay
local _tSpawn  = task.spawn
local _tDefer  = task.defer
local _tCancel = task.cancel
local _pCall   = pcall
local _iNew    = Instance.new
local _v3      = Vector3.new
local _v3z     = Vector3.zero
local _cf      = CFrame.new
local _cfLA    = CFrame.lookAt
local _cfI     = CFrame.identity
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
local _mCeil   = math.ceil
local _mSin    = math.sin
local _mCos    = math.cos
local _mAbs    = math.abs
local _mPi     = math.pi
local _mRad    = math.rad
local _mClamp  = math.clamp
local _mLerp   = function(a, b, t) return a + (b - a) * t end
local _strChar = string.char
local _strFmt  = string.format

-- Anti-detection: Variable execution delay
_tWait(_rF(0.01, 0.04))

-- ═══════════ CONFIG ═══════════
local CFG = {
    infJump      = false,
    antiRagdoll  = false,
    noAnim       = false,
    jumpPower    = 50,
    jumpCooldown = 0.12,
    maxFallVel   = -60,
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

-- Ghost v8 — FIXED
local _ghostActive  = false
local _ghostPart    = nil
local _ghostMovers  = {}
local _ragActive    = false
local _ragStart     = 0
local _preRagCF     = nil  -- Position BEFORE ragdoll started
local _ghostCF      = nil
local _exitingRag   = false
local _ragTimeout   = 8
local _exitLock     = false  -- Prevents multiple exit attempts
local _lastExitTime = 0

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

-- Safe CFrame snapshot
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

-- ═══════════ GHOST ANTI-RAGDOLL v8.0 — FIXED ═══════════
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

    -- Use pre-ragdoll position for ghost spawn
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
            -- Zero ALL velocities first
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

-- ═══ FIXED EXIT RAGDOLL — Single clean exit, no ping-pong ═══
local function _exitRagdoll()
    -- Hard lock: prevent ANY re-entry
    if _exitLock then return end
    if _exitingRag then return end
    
    local now = tick()
    if now - _lastExitTime < 1.5 then return end  -- Cooldown prevents rapid re-triggers
    
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

    -- Get the ghost's final position (where player walked to)
    local finalCF = _ghostCF

    -- Kill ghost and teleport body to ghost position
    _killGhost(true)

    -- Fix the character state
    _pCall(function() _hum.PlatformStand = false end)
    _nukeConstraints()
    _restoreMotors()

    -- Unanchor everything
    for _, v in ipairs(_char:GetDescendants()) do
        if v:IsA("BasePart") then
            _pCall(function() v.Anchored = false end)
        end
    end

    _pCall(function() _hum:ChangeState(_enumHS.GettingUp) end)

    -- Single delayed stabilization pass (not multiple!)
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
                
                -- Only teleport if body drifted significantly from ghost pos
                if finalCF and _rootPart and _rootPart.Parent then
                    local dist = (_rootPart.Position - finalCF.Position).Magnitude
                    if dist > 4 then
                        -- Zero velocity THEN teleport — one time only
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

    -- Final cleanup after stabilization window
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
        
        -- Release lock after full cooldown
        _tDelay(0.8, function()
            _exitLock = false
        end)
    end)
end

local function _onRagdollStart()
    -- Guard against re-entry during exit
    if _ragActive or _exitingRag or _exitLock then return end
    if not (_hum and _hum.Health > 0) then return end
    
    -- Snapshot position BEFORE ragdoll physics kick in
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
        -- Confirm it's really over with a single check
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

-- Continuously snapshot safe position when NOT ragdolling
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
        if _exitLock then return end  -- Don't re-trigger during exit
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
end)

-- ═══════════ RESPAWN ═══════════
LP.CharacterAdded:Connect(function()
    _tWait(_rF(0.3, 0.5))
    _killGhost(false)
    _ragActive = false
    _exitingRag = false
    _exitLock = false
    _preRagCF = nil
    _refreshChar()
    _tWait(_rF(0.15, 0.25))
    if CFG.antiRagdoll then _stopAntiRagdoll() _startAntiRagdoll() end
    if CFG.noAnim then _stopNoAnim() _tWait(0.12) _startNoAnim() end
end)


-- ══════════════════════════════════════════════════════
-- ══════════════ GUI v16.0 AURORA ═════════════════════
-- ══════════════════════════════════════════════════════

-- Cleanup old GUI
local _guiName = _genID(20)
for _, g in ipairs(PG:GetChildren()) do
    _pCall(function()
        if g:IsA("ScreenGui") and g:GetAttribute("_spectreTag") then
            g:Destroy()
        end
    end)
end

local SG = _iNew("ScreenGui")
SG.Name = _guiName
SG:SetAttribute("_spectreTag", true)
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = _rI(2, 8)
SG.IgnoreGuiInset = false
SG.Parent = PG

-- ═══ PALETTE v2 — Deeper, richer ═══
local P = {
    bg       = _c3(6, 6, 16),
    bgCard   = _c3(12, 12, 28),
    bgDeep   = _c3(4, 4, 12),
    header   = _c3(8, 8, 22),

    accent1  = _c3(120, 70, 255),   -- Purple
    accent2  = _c3(30, 185, 255),   -- Cyan
    accent3  = _c3(255, 45, 85),    -- Red-Pink
    accent4  = _c3(255, 190, 50),   -- Gold
    accent5  = _c3(50, 255, 140),   -- Emerald
    accent6  = _c3(255, 100, 210),  -- Pink

    textW    = _c3(235, 235, 250),
    textD    = _c3(65, 65, 95),
    textG    = _c3(50, 255, 120),

    toggleOff     = _c3(22, 22, 38),
    toggleKnobOff = _c3(85, 85, 110),
    border        = _c3(28, 28, 50),
    glow          = _c3(120, 70, 255),
}

-- ═══ HELPERS ═══
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

-- ═══ DRAGGING SYSTEM ═══
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
MF.Size = _ud2(0, 420, 0, 580)
MF.Position = _ud2(0.5, -210, 0.5, -290)
MF.BackgroundColor3 = P.bg
MF.BackgroundTransparency = 0.02
MF.BorderSizePixel = 0
MF.Active = true
MF.ClipsDescendants = true
MF.Parent = SG
corner(MF, 24)

local mainStroke = stroke(MF, P.accent1, 1.5, 0.5)

-- ═══ AURORA BACKGROUND — Animated gradient mesh ═══
local auroraOrbs = {}
local auroraData = {
    {_ud2(0, -80, 0, -80),   P.accent1, 260, 0.92},
    {_ud2(1, -120, 1, -140),  P.accent2, 240, 0.92},
    {_ud2(0.12, 0, 0.3, 0),  P.accent6, 160, 0.94},
    {_ud2(0.85, 0, 0.05, 0), P.accent5, 130, 0.95},
    {_ud2(0.5, -70, 0.65, 0),P.accent3, 180, 0.93},
    {_ud2(0.02, 0, 0.8, 0),  P.accent4, 110, 0.96},
    {_ud2(0.6, 0, 0.15, 0),  P.accent1, 100, 0.96},
    {_ud2(0.3, 0, 0.9, 0),   P.accent2, 90,  0.97},
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

-- Micro dot grid (finer, more subtle)
for row = 0, 16 do
    for col = 0, 11 do
        if _rI(1, 3) ~= 1 then  -- Sparse pattern
            local d = _iNew("Frame")
            d.Size = _ud2(0, 1, 0, 1)
            d.Position = _ud2(0, 10 + col * 36, 0, 78 + row * 30)
            d.BackgroundColor3 = P.textW
            d.BackgroundTransparency = 0.97
            d.BorderSizePixel = 0
            d.ZIndex = 0
            d.Parent = MF
        end
    end
end

-- ═══ HEADER ═══
local HD = _iNew("Frame")
HD.Name = _genID(4)
HD.Size = _ud2(1, 0, 0, 76)
HD.BackgroundColor3 = P.header
HD.BackgroundTransparency = 0.03
HD.BorderSizePixel = 0
HD.ZIndex = 5
HD.Parent = MF
corner(HD, 24)

-- Header bottom patch
local HDP = _iNew("Frame")
HDP.Size = _ud2(1, 0, 0, 28)
HDP.Position = _ud2(0, 0, 1, -28)
HDP.BackgroundColor3 = P.header
HDP.BackgroundTransparency = 0.03
HDP.BorderSizePixel = 0
HDP.ZIndex = 5
HDP.Parent = HD

-- Inner header glow
local headerGlow = _iNew("Frame")
headerGlow.Size = _ud2(1, 20, 0, 40)
headerGlow.Position = _ud2(0, -10, 1, -5)
headerGlow.BackgroundColor3 = P.accent1
headerGlow.BackgroundTransparency = 0.96
headerGlow.BorderSizePixel = 0
headerGlow.ZIndex = 4
headerGlow.Parent = HD
corner(headerGlow, 20)

makeDraggable(MF, HD)

-- Multi-layer gradient separator
local sepLines = {
    {0.96, 2.5, 0.0},
    {0.75, 1.2, 0.35},
    {0.5,  0.8, 0.6},
}
for idx, sl in ipairs(sepLines) do
    local line = _iNew("Frame")
    line.Name = _genID(3)
    line.Size = _ud2(sl[1], 0, 0, sl[2])
    line.Position = _ud2((1 - sl[1]) / 2, 0, 1, (idx - 1) * 3)
    line.BackgroundColor3 = P.textW
    line.BackgroundTransparency = sl[3]
    line.BorderSizePixel = 0
    line.ZIndex = 6
    line.Parent = HD
    corner(line, 2)

    local lineGrad = gradient(line, _csNew{
        _csk(0, P.accent1),
        _csk(0.15, P.accent2),
        _csk(0.35, P.accent5),
        _csk(0.55, P.accent4),
        _csk(0.75, P.accent6),
        _csk(0.9, P.accent3),
        _csk(1, P.accent1),
    })
    lineGrad.Transparency = _nsNew{
        _nsk(0, 0.9),
        _nsk(0.12, 0),
        _nsk(0.88, 0),
        _nsk(1, 0.9),
    }

    if idx == 1 then
        _tSpawn(function()
            local offset = 0
            while SG and SG.Parent do
                offset = (offset + 0.0015) % 1
                _pCall(function()
                    lineGrad.Offset = Vector2.new(_mSin(offset * _mPi * 2) * 0.4, 0)
                end)
                _tWait(0.02)
            end
        end)
    end
end

-- ═══ LOGO — Layered rings with particle shimmer ═══
local logoContainer = _iNew("Frame")
logoContainer.Size = _ud2(0, 56, 0, 56)
logoContainer.Position = _ud2(0, 14, 0.5, -28)
logoContainer.BackgroundTransparency = 1
logoContainer.ZIndex = 6
logoContainer.Parent = HD

local logoRingFrames = {}
local ringData = {
    {56, 0.76, 20},
    {44, 0.8, 16},
    {34, 0.84, 12},
}
for i, rd in ipairs(ringData) do
    local ring = _iNew("Frame")
    ring.Name = _genID(3)
    ring.Size = _ud2(0, rd[1], 0, rd[1])
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = _ud2(0.5, 0, 0.5, 0)
    ring.BackgroundColor3 = P.accent1
    ring.BackgroundTransparency = rd[2]
    ring.BorderSizePixel = 0
    ring.ZIndex = 6 + i
    ring.Parent = logoContainer
    corner(ring, _mFloor(rd[1] / 2))
    if i < 3 then stroke(ring, P.accent1, 0.8, 0.4 + i * 0.12) end
    logoRingFrames[i] = ring
end

-- Inner glow core
local logoGlow = _iNew("Frame")
logoGlow.Size = _ud2(0, 20, 0, 20)
logoGlow.AnchorPoint = Vector2.new(0.5, 0.5)
logoGlow.Position = _ud2(0.5, 0, 0.5, 0)
logoGlow.BackgroundColor3 = P.accent1
logoGlow.BackgroundTransparency = 0.4
logoGlow.ZIndex = 10
logoGlow.Parent = logoContainer
corner(logoGlow, 10)

-- Outer halo
local logoHalo = _iNew("Frame")
logoHalo.Size = _ud2(0, 70, 0, 70)
logoHalo.AnchorPoint = Vector2.new(0.5, 0.5)
logoHalo.Position = _ud2(0.5, 0, 0.5, 0)
logoHalo.BackgroundColor3 = P.accent1
logoHalo.BackgroundTransparency = 0.96
logoHalo.BorderSizePixel = 0
logoHalo.ZIndex = 5
logoHalo.Parent = logoContainer
corner(logoHalo, 35)

local logoText = _iNew("TextLabel")
logoText.Size = _ud2(1, 0, 1, 0)
logoText.BackgroundTransparency = 1
logoText.Text = "G"
logoText.TextColor3 = P.textW
logoText.TextSize = 15
logoText.Font = Enum.Font.GothamBlack
logoText.ZIndex = 11
logoText.Parent = logoRingFrames[3]

-- Title
local titleLbl = _iNew("TextLabel")
titleLbl.Size = _ud2(0, 180, 0, 26)
titleLbl.Position = _ud2(0, 80, 0, 10)
titleLbl.BackgroundTransparency = 1
titleLbl.RichText = true
titleLbl.Text = '<font color="#7846FF">GRANZ</font> <font color="#FFFFFF">HUB</font>'
titleLbl.TextSize = 20
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 6
titleLbl.Parent = HD

-- Subtitle
local subLbl = _iNew("TextLabel")
subLbl.Size = _ud2(0, 260, 0, 14)
subLbl.Position = _ud2(0, 80, 0, 38)
subLbl.BackgroundTransparency = 1
subLbl.Text = "aurora · v16.0 · phantom engine"
subLbl.TextColor3 = P.textD
subLbl.TextSize = 9.5
subLbl.Font = Enum.Font.GothamMedium
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.ZIndex = 6
subLbl.Parent = HD

-- Badges with glass effect
local badgeData = {
    {"AURORA", P.accent1},
    {"v8.0",   P.accent5},
    {"GHOST",  P.accent2},
    {"SAFE",   P.accent4},
}
local bx = 80
for _, bd in ipairs(badgeData) do
    local bf = _iNew("Frame")
    bf.Size = _ud2(0, #bd[1] * 5.6 + 18, 0, 18)
    bf.Position = _ud2(0, bx, 0, 54)
    bf.BackgroundColor3 = bd[2]
    bf.BackgroundTransparency = 0.87
    bf.BorderSizePixel = 0
    bf.ZIndex = 6
    bf.Parent = HD
    corner(bf, 7)
    stroke(bf, bd[2], 0.5, 0.55)

    local bl = _iNew("TextLabel")
    bl.Size = _ud2(1, 0, 1, 0)
    bl.BackgroundTransparency = 1
    bl.Text = bd[1]
    bl.TextColor3 = bd[2]
    bl.TextSize = 7
    bl.Font = Enum.Font.GothamBlack
    bl.ZIndex = 7
    bl.Parent = bf

    bx = bx + #bd[1] * 5.6 + 23
end

-- Header buttons (glass style)
local function makeHeaderBtn(pos, text, bgColor, hoverColor)
    local btn = _iNew("TextButton")
    btn.Size = _ud2(0, 38, 0, 38)
    btn.Position = pos
    btn.AnchorPoint = Vector2.new(0, 0)
    btn.BackgroundColor3 = bgColor
    btn.BackgroundTransparency = 0.5
    btn.Text = text
    btn.TextColor3 = P.textW
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.ZIndex = 6
    btn.Parent = HD
    corner(btn, 12)
    stroke(btn, bgColor, 0.5, 0.6)

    btn.MouseEnter:Connect(function()
        tween(btn, ti(0.25), {
            BackgroundTransparency = 0.15,
            Size = _ud2(0, 40, 0, 40),
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, ti(0.25), {
            BackgroundTransparency = 0.5,
            Size = _ud2(0, 38, 0, 38),
        }):Play()
    end)
    return btn
end

local MinBtn = makeHeaderBtn(_ud2(1, -90, 0, 18), "━", _c3(35, 35, 55))
local ClsBtn = makeHeaderBtn(_ud2(1, -48, 0, 18), "✕", _c3(150, 25, 40))

-- ═══ CONTENT SCROLL ═══
local CT = _iNew("ScrollingFrame")
CT.Name = _genID(4)
CT.Size = _ud2(1, -16, 1, -94)
CT.Position = _ud2(0, 8, 0, 84)
CT.BackgroundTransparency = 1
CT.BorderSizePixel = 0
CT.ScrollBarThickness = 3
CT.ScrollBarImageColor3 = P.accent1
CT.ScrollBarImageTransparency = 0.55
CT.CanvasSize = _ud2(0, 0, 0, 0)
CT.AutomaticCanvasSize = Enum.AutomaticSize.Y
CT.ZIndex = 3
CT.Parent = MF

local listLayout = _iNew("UIListLayout")
listLayout.Padding = _udim(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = CT

local ctPad = _iNew("UIPadding")
ctPad.PaddingTop = _udim(0, 4)
ctPad.PaddingBottom = _udim(0, 18)
ctPad.PaddingLeft = _udim(0, 3)
ctPad.PaddingRight = _udim(0, 3)
ctPad.Parent = CT

-- ═══ MODULE CARD FACTORY v2 — Glass morphism ═══
local function createModule(icon, name, desc, order, accentColor, tags)
    local card = _iNew("Frame")
    card.Name = _genID(5)
    card.Size = _ud2(1, 0, 0, 106)
    card.BackgroundColor3 = P.bgCard
    card.BackgroundTransparency = 0.06
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 3
    card.ClipsDescendants = true
    card.Parent = CT
    corner(card, 18)

    local cardStroke = stroke(card, P.border, 0.8, 0.55)

    -- Glass overlay
    local glassOverlay = _iNew("Frame")
    glassOverlay.Size = _ud2(1, 0, 0.5, 0)
    glassOverlay.Position = _ud2(0, 0, 0, 0)
    glassOverlay.BackgroundColor3 = _c3(255, 255, 255)
    glassOverlay.BackgroundTransparency = 0.97
    glassOverlay.BorderSizePixel = 0
    glassOverlay.ZIndex = 3
    glassOverlay.Parent = card
    corner(glassOverlay, 18)

    -- Left accent bar with gradient
    local leftBar = _iNew("Frame")
    leftBar.Size = _ud2(0, 3.5, 0.4, 0)
    leftBar.Position = _ud2(0, 0, 0.3, 0)
    leftBar.BackgroundColor3 = accentColor
    leftBar.BackgroundTransparency = 0.25
    leftBar.BorderSizePixel = 0
    leftBar.ZIndex = 4
    leftBar.Parent = card
    corner(leftBar, 2)
    local lbGrad = _iNew("UIGradient")
    lbGrad.Rotation = 90
    lbGrad.Transparency = _nsNew{_nsk(0, 0.8), _nsk(0.5, 0), _nsk(1, 0.8)}
    lbGrad.Parent = leftBar

    -- Icon container (concentric rings)
    local iconOuter = _iNew("Frame")
    iconOuter.Size = _ud2(0, 56, 0, 56)
    iconOuter.Position = _ud2(0, 16, 0, 14)
    iconOuter.BackgroundColor3 = accentColor
    iconOuter.BackgroundTransparency = 0.9
    iconOuter.BorderSizePixel = 0
    iconOuter.ZIndex = 4
    iconOuter.Parent = card
    corner(iconOuter, 18)

    local iconMid = _iNew("Frame")
    iconMid.Size = _ud2(0, 42, 0, 42)
    iconMid.AnchorPoint = Vector2.new(0.5, 0.5)
    iconMid.Position = _ud2(0.5, 0, 0.5, 0)
    iconMid.BackgroundColor3 = accentColor
    iconMid.BackgroundTransparency = 0.82
    iconMid.BorderSizePixel = 0
    iconMid.ZIndex = 5
    iconMid.Parent = iconOuter
    corner(iconMid, 14)

    local iconInner = _iNew("Frame")
    iconInner.Size = _ud2(0, 32, 0, 32)
    iconInner.AnchorPoint = Vector2.new(0.5, 0.5)
    iconInner.Position = _ud2(0.5, 0, 0.5, 0)
    iconInner.BackgroundColor3 = accentColor
    iconInner.BackgroundTransparency = 0.7
    iconInner.BorderSizePixel = 0
    iconInner.ZIndex = 6
    iconInner.Parent = iconMid
    corner(iconInner, 10)

    -- Icon glow
    local iconGlow = _iNew("Frame")
    iconGlow.Size = _ud2(0, 18, 0, 18)
    iconGlow.AnchorPoint = Vector2.new(0.5, 0.5)
    iconGlow.Position = _ud2(0.5, 0, 0.5, 0)
    iconGlow.BackgroundColor3 = accentColor
    iconGlow.BackgroundTransparency = 0.45
    iconGlow.ZIndex = 7
    iconGlow.Parent = iconInner
    corner(iconGlow, 9)

    local iconLabel = _iNew("TextLabel")
    iconLabel.Size = _ud2(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextSize = 18
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.ZIndex = 8
    iconLabel.Parent = iconInner

    -- Name label
    local nameLabel = _iNew("TextLabel")
    nameLabel.Size = _ud2(1, -170, 0, 24)
    nameLabel.Position = _ud2(0, 82, 0, 14)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = P.textW
    nameLabel.TextSize = 15
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 4
    nameLabel.Parent = card

    -- Description
    local descLabel = _iNew("TextLabel")
    descLabel.Size = _ud2(1, -170, 0, 14)
    descLabel.Position = _ud2(0, 82, 0, 40)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = desc
    descLabel.TextColor3 = P.textD
    descLabel.TextSize = 10
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.ZIndex = 4
    descLabel.Parent = card

    -- Tags
    if tags then
        local tx = 82
        for _, tagText in ipairs(tags) do
            local tagFrame = _iNew("Frame")
            tagFrame.Size = _ud2(0, #tagText * 5.4 + 16, 0, 18)
            tagFrame.Position = _ud2(0, tx, 0, 60)
            tagFrame.BackgroundColor3 = accentColor
            tagFrame.BackgroundTransparency = 0.88
            tagFrame.BorderSizePixel = 0
            tagFrame.ZIndex = 4
            tagFrame.Parent = card
            corner(tagFrame, 6)

            local tagLabel = _iNew("TextLabel")
            tagLabel.Size = _ud2(1, 0, 1, 0)
            tagLabel.BackgroundTransparency = 1
            tagLabel.Text = tagText
            tagLabel.TextColor3 = accentColor
            tagLabel.TextSize = 7
            tagLabel.Font = Enum.Font.GothamBlack
            tagLabel.ZIndex = 5
            tagLabel.Parent = tagFrame

            tx = tx + #tagText * 5.4 + 20
        end
    end

    -- Bottom shine line
    local bottomLine = _iNew("Frame")
    bottomLine.Size = _ud2(0, 0, 0, 2)
    bottomLine.AnchorPoint = Vector2.new(0.5, 0)
    bottomLine.Position = _ud2(0.5, 0, 1, -3)
    bottomLine.BackgroundColor3 = accentColor
    bottomLine.BackgroundTransparency = 0.35
    bottomLine.BorderSizePixel = 0
    bottomLine.ZIndex = 4
    bottomLine.Parent = card
    corner(bottomLine, 1)
    gradient(bottomLine, _csNew{_csk(0, accentColor), _csk(0.5, P.accent2), _csk(1, accentColor)})

    -- Status indicator
    local statusDot = _iNew("Frame")
    statusDot.Size = _ud2(0, 8, 0, 8)
    statusDot.Position = _ud2(1, -20, 0, 10)
    statusDot.BackgroundColor3 = _c3(28, 28, 42)
    statusDot.BorderSizePixel = 0
    statusDot.ZIndex = 5
    statusDot.Parent = card
    corner(statusDot, 4)

    -- Status glow ring
    local statusRing = _iNew("Frame")
    statusRing.Size = _ud2(0, 14, 0, 14)
    statusRing.Position = _ud2(1, -23, 0, 7)
    statusRing.BackgroundTransparency = 1
    statusRing.BorderSizePixel = 0
    statusRing.ZIndex = 4
    statusRing.Parent = card
    corner(statusRing, 7)
    local statusStroke = stroke(statusRing, _c3(28, 28, 42), 1, 0.6)

    -- Toggle pill
    local toggleBtn = _iNew("TextButton")
    toggleBtn.Size = _ud2(0, 58, 0, 30)
    toggleBtn.Position = _ud2(1, -72, 0.5, -15)
    toggleBtn.BackgroundColor3 = P.toggleOff
    toggleBtn.Text = ""
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 4
    toggleBtn.Parent = card
    corner(toggleBtn, 15)
    local toggleStroke = stroke(toggleBtn, P.border, 0.5, 0.5)

    -- Toggle inner shadow
    local toggleShadow = _iNew("Frame")
    toggleShadow.Size = _ud2(1, -4, 1, -4)
    toggleShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    toggleShadow.Position = _ud2(0.5, 0, 0.5, 0)
    toggleShadow.BackgroundColor3 = _c3(0, 0, 0)
    toggleShadow.BackgroundTransparency = 0.85
    toggleShadow.BorderSizePixel = 0
    toggleShadow.ZIndex = 4
    toggleShadow.Parent = toggleBtn
    corner(toggleShadow, 13)

    local knob = _iNew("Frame")
    knob.Size = _ud2(0, 24, 0, 24)
    knob.Position = _ud2(0, 3, 0.5, -12)
    knob.BackgroundColor3 = P.toggleKnobOff
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = toggleBtn
    corner(knob, 12)
    local knobStroke = stroke(knob, accentColor, 0, 0.8)

    -- Knob inner dot
    local knobDot = _iNew("Frame")
    knobDot.Size = _ud2(0, 8, 0, 8)
    knobDot.AnchorPoint = Vector2.new(0.5, 0.5)
    knobDot.Position = _ud2(0.5, 0, 0.5, 0)
    knobDot.BackgroundColor3 = accentColor
    knobDot.BackgroundTransparency = 1
    knobDot.BorderSizePixel = 0
    knobDot.ZIndex = 6
    knobDot.Parent = knob
    corner(knobDot, 4)

    -- Ripple effect on click
    local function createRipple(x, y)
        local ripple = _iNew("Frame")
        ripple.Size = _ud2(0, 0, 0, 0)
        ripple.AnchorPoint = Vector2.new(0.5, 0.5)
        ripple.Position = _ud2(0, x, 0, y)
        ripple.BackgroundColor3 = accentColor
        ripple.BackgroundTransparency = 0.7
        ripple.BorderSizePixel = 0
        ripple.ZIndex = 3
        ripple.Parent = card
        corner(ripple, 999)
        
        tween(ripple, _twInfo(0.6, _enumES.Quint), {
            Size = _ud2(0, 200, 0, 200),
            BackgroundTransparency = 1,
        }):Play()
        
        _tDelay(0.65, function()
            _pCall(function() ripple:Destroy() end)
        end)
    end

    -- Hover area
    local hoverBtn = _iNew("TextButton")
    hoverBtn.Size = _ud2(1, 0, 1, 0)
    hoverBtn.BackgroundTransparency = 1
    hoverBtn.Text = ""
    hoverBtn.ZIndex = 3
    hoverBtn.Parent = card

    hoverBtn.MouseEnter:Connect(function()
        tween(card, ti(0.3), {BackgroundTransparency = 0}):Play()
        tween(cardStroke, ti(0.3), {Transparency = 0.2, Color = accentColor}):Play()
        tween(leftBar, ti(0.35), {BackgroundTransparency = 0, Size = _ud2(0, 5, 0.5, 0)}):Play()
        tween(bottomLine, ti(0.45, _enumES.Quint), {Size = _ud2(0.85, 0, 0, 2.5)}):Play()
        tween(iconOuter, ti(0.3), {BackgroundTransparency = 0.8}):Play()
        tween(iconGlow, ti(0.3), {BackgroundTransparency = 0.25}):Play()
        tween(glassOverlay, ti(0.3), {BackgroundTransparency = 0.95}):Play()
        tween(logoHalo, ti(0.3), {BackgroundTransparency = 0.94}):Play()
    end)
    hoverBtn.MouseLeave:Connect(function()
        tween(card, ti(0.3), {BackgroundTransparency = 0.06}):Play()
        tween(cardStroke, ti(0.3), {Transparency = 0.55, Color = P.border}):Play()
        tween(leftBar, ti(0.35), {BackgroundTransparency = 0.25, Size = _ud2(0, 3.5, 0.4, 0)}):Play()
        tween(bottomLine, ti(0.45), {Size = _ud2(0, 0, 0, 2)}):Play()
        tween(iconOuter, ti(0.3), {BackgroundTransparency = 0.9}):Play()
        tween(iconGlow, ti(0.3), {BackgroundTransparency = 0.45}):Play()
        tween(glassOverlay, ti(0.3), {BackgroundTransparency = 0.97}):Play()
    end)

    local isOn = false

    local function setVisual(state)
        isOn = state
        local t = ti(0.4)
        local tFast = ti(0.2)

        if state then
            -- Ripple from toggle position
            createRipple(card.AbsoluteSize.X - 43, card.AbsoluteSize.Y / 2)
            
            -- ON animations
            tween(toggleBtn, t, {BackgroundColor3 = accentColor}):Play()
            tween(toggleShadow, t, {BackgroundTransparency = 0.92}):Play()
            tween(toggleStroke, t, {Color = accentColor, Transparency = 0.1}):Play()
            tween(knob, t, {
                Position = _ud2(1, -27, 0.5, -12),
                BackgroundColor3 = _c3(255, 255, 255)
            }):Play()
            tween(knobStroke, t, {Thickness = 2.5, Transparency = 0}):Play()
            tween(knobDot, t, {BackgroundTransparency = 0}):Play()
            tween(cardStroke, t, {Color = accentColor, Transparency = 0.2}):Play()
            tween(iconInner, t, {BackgroundTransparency = 0.5}):Play()
            tween(iconMid, t, {BackgroundTransparency = 0.68}):Play()
            tween(iconGlow, t, {BackgroundTransparency = 0.2}):Play()
            tween(leftBar, t, {BackgroundTransparency = 0}):Play()
            tween(statusDot, t, {BackgroundColor3 = P.textG}):Play()
            tween(statusStroke, t, {Color = P.textG, Transparency = 0.3}):Play()

            -- Activation bounce
            tween(toggleBtn, _twInfo(0.12, _enumES.Quad, _enumED.Out, 0, true), {
                Size = _ud2(0, 62, 0, 34)
            }):Play()

            -- Bottom flash
            tween(bottomLine, _twInfo(0.5, _enumES.Quint), {
                Size = _ud2(0.95, 0, 0, 3), BackgroundTransparency = 0.1
            }):Play()
            _tDelay(0.6, function()
                if isOn then
                    _pCall(function()
                        tween(bottomLine, ti(0.7), {
                            Size = _ud2(0.35, 0, 0, 2), BackgroundTransparency = 0.35
                        }):Play()
                    end)
                end
            end)

            -- Card flash
            tween(card, _twInfo(0.12, _enumES.Quad, _enumED.Out, 0, true), {
                BackgroundColor3 = accentColor
            }):Play()
        else
            -- OFF animations
            tween(toggleBtn, t, {BackgroundColor3 = P.toggleOff}):Play()
            tween(toggleShadow, t, {BackgroundTransparency = 0.85}):Play()
            tween(toggleStroke, t, {Color = P.border, Transparency = 0.5}):Play()
            tween(knob, t, {
                Position = _ud2(0, 3, 0.5, -12),
                BackgroundColor3 = P.toggleKnobOff
            }):Play()
            tween(knobStroke, t, {Thickness = 0, Transparency = 0.8}):Play()
            tween(knobDot, t, {BackgroundTransparency = 1}):Play()
            tween(cardStroke, t, {Color = P.border, Transparency = 0.55}):Play()
            tween(iconInner, t, {BackgroundTransparency = 0.7}):Play()
            tween(iconMid, t, {BackgroundTransparency = 0.82}):Play()
            tween(iconGlow, t, {BackgroundTransparency = 0.45}):Play()
            tween(leftBar, t, {BackgroundTransparency = 0.25}):Play()
            tween(statusDot, t, {BackgroundColor3 = _c3(28, 28, 42)}):Play()
            tween(statusStroke, t, {Color = _c3(28, 28, 42), Transparency = 0.6}):Play()
            tween(bottomLine, ti(0.35), {Size = _ud2(0, 0, 0, 2), BackgroundTransparency = 0.35}):Play()
        end
    end

    return toggleBtn, setVisual
end

-- Create modules
local jumpToggle, jumpVisual = createModule(
    "⚡", "Infinite Jump",
    "Прыжки в воздухе без ограничений",
    1, P.accent1, {"AIR", "MULTI", "v3"}
)

local ragToggle, ragVisual = createModule(
    "👻", "Ghost Anti-Ragdoll",
    "Призрак-контроль при рагдолле",
    2, P.accent2, {"GHOST", "v8", "FIXED"}
)

local animToggle, animVisual = createModule(
    "🎭", "No Animations",
    "Полная заморозка анимаций",
    3, P.accent3, {"FREEZE", "SILENT"}
)

-- Separator
local separator = _iNew("Frame")
separator.Size = _ud2(0.92, 0, 0, 1)
separator.BackgroundColor3 = P.textW
separator.BackgroundTransparency = 0.93
separator.BorderSizePixel = 0
separator.LayoutOrder = 5
separator.ZIndex = 3
separator.Parent = CT
corner(separator, 1)
local sepGrad = _iNew("UIGradient")
sepGrad.Transparency = _nsNew{_nsk(0, 1), _nsk(0.15, 0), _nsk(0.85, 0), _nsk(1, 1)}
sepGrad.Parent = separator

-- ═══ STATUS BAR ═══
local SB = _iNew("Frame")
SB.Name = _genID(4)
SB.Size = _ud2(1, 0, 0, 68)
SB.BackgroundColor3 = P.bgDeep
SB.BackgroundTransparency = 0.1
SB.BorderSizePixel = 0
SB.LayoutOrder = 10
SB.ZIndex = 3
SB.Parent = CT
corner(SB, 16)
stroke(SB, P.border, 0.5, 0.6)

-- Indicator dots
local indicatorDots = {}
local indicatorLabels = {}
local indicatorRings = {}
local dotColors = {P.accent1, P.accent2, P.accent3}
local dotNames = {"JMP", "RAG", "ANI"}

for i = 1, 3 do
    local dotGroup = _iNew("Frame")
    dotGroup.Size = _ud2(0, 36, 0, 38)
    dotGroup.Position = _ud2(0, 10 + (i - 1) * 42, 0, 8)
    dotGroup.BackgroundColor3 = _c3(14, 14, 28)
    dotGroup.BackgroundTransparency = 0.15
    dotGroup.BorderSizePixel = 0
    dotGroup.ZIndex = 4
    dotGroup.Parent = SB
    corner(dotGroup, 10)

    -- Outer ring
    local ring = _iNew("Frame")
    ring.Size = _ud2(0, 16, 0, 16)
    ring.AnchorPoint = Vector2.new(0.5, 0)
    ring.Position = _ud2(0.5, 0, 0, 4)
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel = 0
    ring.ZIndex = 5
    ring.Parent = dotGroup
    corner(ring, 8)
    local ringStroke = stroke(ring, _c3(28, 28, 42), 1.5, 0.4)
    indicatorRings[i] = ringStroke

    local dot = _iNew("Frame")
    dot.Size = _ud2(0, 10, 0, 10)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = _ud2(0.5, 0, 0.5, 0)
    dot.BackgroundColor3 = _c3(28, 28, 42)
    dot.BorderSizePixel = 0
    dot.ZIndex = 6
    dot.Parent = ring
    corner(dot, 5)
    indicatorDots[i] = dot

    local dLabel = _iNew("TextLabel")
    dLabel.Size = _ud2(1, 0, 0, 10)
    dLabel.Position = _ud2(0, 0, 1, -14)
    dLabel.BackgroundTransparency = 1
    dLabel.Text = dotNames[i]
    dLabel.TextColor3 = P.textD
    dLabel.TextSize = 6.5
    dLabel.Font = Enum.Font.GothamBlack
    dLabel.ZIndex = 5
    dLabel.Parent = dotGroup
    indicatorLabels[i] = dLabel
end

local statusLabel = _iNew("TextLabel")
statusLabel.Size = _ud2(1, -150, 0, 20)
statusLabel.Position = _ud2(0, 140, 0, 10)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = P.textD
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.ZIndex = 4
statusLabel.Parent = SB

local ghostInfoLabel = _iNew("TextLabel")
ghostInfoLabel.Size = _ud2(1, -150, 0, 14)
ghostInfoLabel.Position = _ud2(0, 140, 0, 30)
ghostInfoLabel.BackgroundTransparency = 1
ghostInfoLabel.Text = ""
ghostInfoLabel.TextColor3 = P.accent2
ghostInfoLabel.TextSize = 9
ghostInfoLabel.Font = Enum.Font.Gotham
ghostInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
ghostInfoLabel.ZIndex = 4
ghostInfoLabel.Parent = SB

local pingLabel = _iNew("TextLabel")
pingLabel.Size = _ud2(0, 80, 0, 12)
pingLabel.Position = _ud2(1, -90, 0, 48)
pingLabel.BackgroundTransparency = 1
pingLabel.Text = "●  " .. _rI(10, 35) .. "ms"
pingLabel.TextColor3 = P.textG
pingLabel.TextSize = 8
pingLabel.Font = Enum.Font.GothamMedium
pingLabel.TextXAlignment = Enum.TextXAlignment.Right
pingLabel.ZIndex = 4
pingLabel.Parent = SB

local function updateStatus()
    local count = 0
    local states = {CFG.infJump, CFG.antiRagdoll, CFG.noAnim}
    for i, active in ipairs(states) do
        local t = ti(0.35)
        if active then
            count += 1
            tween(indicatorDots[i], t, {BackgroundColor3 = dotColors[i]}):Play()
            tween(indicatorLabels[i], t, {TextColor3 = dotColors[i]}):Play()
            tween(indicatorRings[i], t, {Color = dotColors[i], Transparency = 0.15}):Play()
        else
            tween(indicatorDots[i], t, {BackgroundColor3 = _c3(28, 28, 42)}):Play()
            tween(indicatorLabels[i], t, {TextColor3 = P.textD}):Play()
            tween(indicatorRings[i], t, {Color = _c3(28, 28, 42), Transparency = 0.4}):Play()
        end
    end
    if count == 0 then
        statusLabel.Text = "Модули неактивны"
        tween(statusLabel, ti(0.3), {TextColor3 = P.textD}):Play()
    else
        statusLabel.Text = count .. "/3 · AURORA ACTIVE"
        tween(statusLabel, ti(0.3), {TextColor3 = P.textG}):Play()
    end
end

-- Ghost status updater
_tSpawn(function()
    while SG and SG.Parent do
        if _ghostActive then
            local elapsed = _mFloor(tick() - _ragStart)
            ghostInfoLabel.Text = "👻 GHOST · " .. elapsed .. "s · free movement"
            ghostInfoLabel.TextColor3 = _c3h((tick() * 0.2) % 1, 0.35, 1)
        elseif _exitLock then
            ghostInfoLabel.Text = "⟳ Stabilizing..."
            ghostInfoLabel.TextColor3 = P.accent4
        else
            ghostInfoLabel.Text = ""
        end
        _pCall(function() pingLabel.Text = "●  " .. _rI(6, 45) .. "ms" end)
        _tWait(0.1)
    end
end)

-- ═══ TOGGLE HANDLERS ═══
jumpToggle.MouseButton1Click:Connect(function()
    CFG.infJump = not CFG.infJump
    jumpVisual(CFG.infJump)
    if CFG.infJump then _refreshChar() end
    updateStatus()
end)

ragToggle.MouseButton1Click:Connect(function()
    CFG.antiRagdoll = not CFG.antiRagdoll
    ragVisual(CFG.antiRagdoll)
    if CFG.antiRagdoll then _refreshChar() _startAntiRagdoll()
    else _stopAntiRagdoll() end
    updateStatus()
end)

animToggle.MouseButton1Click:Connect(function()
    CFG.noAnim = not CFG.noAnim
    animVisual(CFG.noAnim)
    if CFG.noAnim then _refreshChar() _startNoAnim()
    else _stopNoAnim() end
    updateStatus()
end)

-- ═══ MINIMIZE / CLOSE ═══
local minimized = false
local fullSize = _ud2(0, 420, 0, 580)

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(MF, _twInfo(0.5, _enumES.Back, _enumED.In), {
            Size = _ud2(0, 420, 0, 76)
        }):Play()
        _tDelay(0.06, function() CT.Visible = false end)
        MinBtn.Text = "◻"
    else
        tween(MF, _twInfo(0.55, _enumES.Back), {Size = fullSize}):Play()
        _tDelay(0.3, function() CT.Visible = true end)
        MinBtn.Text = "━"
    end
end)

ClsBtn.MouseButton1Click:Connect(function()
    CFG.infJump = false
    CFG.antiRagdoll = false
    CFG.noAnim = false
    _stopAntiRagdoll()
    _stopNoAnim()
    if _heartbeatC then _heartbeatC:Disconnect() end

    -- Implode animation
    tween(mainStroke, ti(0.2), {Transparency = 1}):Play()
    
    -- Fade out content first
    for _, child in ipairs(CT:GetChildren()) do
        if child:IsA("Frame") then
            tween(child, ti(0.15), {BackgroundTransparency = 1}):Play()
            for _, desc in ipairs(child:GetDescendants()) do
                _pCall(function()
                    if desc:IsA("TextLabel") then tween(desc, ti(0.15), {TextTransparency = 1}):Play() end
                    if desc:IsA("Frame") then tween(desc, ti(0.15), {BackgroundTransparency = 1}):Play() end
                    if desc:IsA("TextButton") then tween(desc, ti(0.15), {TextTransparency = 1, BackgroundTransparency = 1}):Play() end
                end)
            end
        end
    end
    
    _tDelay(0.12, function()
        tween(MF, _twInfo(0.55, _enumES.Back, _enumED.In), {
            Size = _ud2(0, 48, 0, 48),
            Position = _ud2(0.5, -24, 0.5, -24),
            BackgroundTransparency = 0.3
        }):Play()
    end)
    _tDelay(0.45, function()
        tween(MF, ti(0.18), {BackgroundTransparency = 1}):Play()
    end)
    _tDelay(0.65, function()
        _pCall(function() SG:Destroy() end)
    end)
end)

-- ═══ LIVE ANIMATIONS ═══

-- 1. Rainbow border + logo color
_tSpawn(function()
    local hue = _rF(0, 1)
    while SG and SG.Parent do
        hue = (hue + 0.001) % 1
        local activeCount = (CFG.infJump and 1 or 0) + (CFG.antiRagdoll and 1 or 0) + (CFG.noAnim and 1 or 0)
        local t = tick()

        if activeCount > 0 then
            local sat = 0.4 + activeCount * 0.12
            local val = 0.7 + activeCount * 0.08
            mainStroke.Color = _c3h(hue, sat, val)
            mainStroke.Transparency = 0.03 + _mSin(t * 1.5) * 0.06
            mainStroke.Thickness = 1.5 + _mSin(t * 2) * 0.5

            _pCall(function()
                for _, ring in ipairs(logoRingFrames) do
                    ring.BackgroundColor3 = _c3h((hue + 0.06) % 1, 0.5, 0.85)
                end
                logoGlow.BackgroundColor3 = _c3h((hue + 0.12) % 1, 0.55, 1)
                logoHalo.BackgroundColor3 = _c3h((hue + 0.04) % 1, 0.3, 0.6)
                logoHalo.BackgroundTransparency = 0.92 + _mSin(t * 1.2) * 0.02
                headerGlow.BackgroundColor3 = _c3h((hue + 0.08) % 1, 0.35, 0.5)
                headerGlow.BackgroundTransparency = 0.93 + _mSin(t * 0.8) * 0.02
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
                logoHalo.BackgroundTransparency = 0.96
                headerGlow.BackgroundTransparency = 0.96
            end)
        end
        _tWait(0.022)
    end
end)

-- 2. Aurora orb floating (smoother sine paths)
_tSpawn(function()
    local phases = {}
    for i = 1, #auroraData do
        phases[i] = _rF(0, _mPi * 2)
    end
    while SG and SG.Parent do
        local t = tick()
        for i, o in ipairs(auroraOrbs) do
            _pCall(function()
                local od = auroraData[i]
                local ph = phases[i]
                local ox = _mSin(t * (0.15 + i * 0.06) + ph) * 15
                local oy = _mCos(t * (0.18 + i * 0.04) + ph * 0.7) * 12
                local sc = 1 + _mSin(t * (0.1 + i * 0.03) + ph * 1.3) * 0.06
                o.Position = _ud2(od[1].X.Scale, od[1].X.Offset + ox, od[1].Y.Scale, od[1].Y.Offset + oy)
                o.Size = _ud2(0, od[3] * sc, 0, od[3] * sc)
                o.BackgroundTransparency = od[4] + _mSin(t * (0.4 + i * 0.08)) * 0.015
            end)
        end
        _tWait(0.025)
    end
end)

-- 3. Logo breathing with rotation hint
_tSpawn(function()
    while SG and SG.Parent do
        local ac = (CFG.infJump and 1 or 0) + (CFG.antiRagdoll and 1 or 0) + (CFG.noAnim and 1 or 0)
        if ac > 0 then
            -- Breathe in
            for i, ring in ipairs(logoRingFrames) do
                _pCall(function()
                    local rd = ringData[i]
                    local sz = rd[1] + 4
                    tween(ring, _twInfo(2.5, _enumES.Sine, _enumED.InOut), {
                        BackgroundTransparency = rd[2] - 0.06,
                        Size = _ud2(0, sz, 0, sz),
                    }):Play()
                end)
            end
            _pCall(function()
                tween(logoGlow, _twInfo(2.5, _enumES.Sine, _enumED.InOut), {
                    BackgroundTransparency = 0.15,
                    Size = _ud2(0, 24, 0, 24),
                }):Play()
            end)
            _tWait(2.5)
            if not (SG and SG.Parent) then return end
            
            -- Breathe out
            for i, ring in ipairs(logoRingFrames) do
                _pCall(function()
                    local rd = ringData[i]
                    tween(ring, _twInfo(2.5, _enumES.Sine, _enumED.InOut), {
                        BackgroundTransparency = rd[2],
                        Size = _ud2(0, rd[1], 0, rd[1]),
                    }):Play()
                end)
            end
            _pCall(function()
                tween(logoGlow, _twInfo(2.5, _enumES.Sine, _enumED.InOut), {
                    BackgroundTransparency = 0.4,
                    Size = _ud2(0, 20, 0, 20),
                }):Play()
            end)
            _tWait(2.5)
        else
            _tWait(0.5)
        end
    end
end)

-- 4. Indicator dots pulse with ring glow
_tSpawn(function()
    while SG and SG.Parent do
        local states = {CFG.infJump, CFG.antiRagdoll, CFG.noAnim}
        for i, s in ipairs(states) do
            if s then
                _pCall(function()
                    tween(indicatorDots[i], _twInfo(1, _enumES.Sine, _enumED.InOut), {
                        Size = _ud2(0, 13, 0, 13),
                    }):Play()
                    tween(indicatorRings[i], _twInfo(1, _enumES.Sine, _enumED.InOut), {
                        Transparency = 0.05,
                    }):Play()
                end)
            end
        end
        _tWait(1)
        if not (SG and SG.Parent) then return end
        for i, s in ipairs(states) do
            if s then
                _pCall(function()
                    tween(indicatorDots[i], _twInfo(1, _enumES.Sine, _enumED.InOut), {
                        Size = _ud2(0, 10, 0, 10),
                    }):Play()
                    tween(indicatorRings[i], _twInfo(1, _enumES.Sine, _enumED.InOut), {
                        Transparency = 0.15,
                    }):Play()
                end)
            end
        end
        _tWait(1)
    end
end)

-- ═══ OPENING ANIMATION (Cinematic) ═══
MF.BackgroundTransparency = 1
CT.Visible = false
mainStroke.Transparency = 1
HD.BackgroundTransparency = 1
HDP.BackgroundTransparency = 1
headerGlow.BackgroundTransparency = 1

-- Hide all header children
for _, child in ipairs(HD:GetDescendants()) do
    _pCall(function()
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            child.TextTransparency = 1
        end
        if child:IsA("Frame") then
            child.BackgroundTransparency = 1
        end
    end)
end

-- Hide aurora orbs initially
for _, orb in ipairs(auroraOrbs) do
    orb.BackgroundTransparency = 1
end

_tDelay(0.05, function()
    -- Phase 1: Point of light
    MF.Size = _ud2(0, 6, 0, 6)
    MF.Position = _ud2(0.5, -3, 0.5, -3)
    tween(MF, ti(0.15), {BackgroundTransparency = 0}):Play()
    tween(mainStroke, ti(0.15), {Transparency = 0.1}):Play()
    _tWait(0.12)

    -- Phase 2: Horizontal expand
    tween(MF, _twInfo(0.35, _enumES.Quint), {
        Size = _ud2(0, 420, 0, 6),
        Position = _ud2(0.5, -210, 0.5, -3),
    }):Play()
    _tWait(0.3)

    -- Phase 3: Vertical expand
    tween(MF, _twInfo(0.6, _enumES.Back, _enumED.Out), {
        Size = _ud2(0, 420, 0, 580),
        Position = _ud2(0.5, -210, 0.5, -290),
    }):Play()
    _tWait(0.25)

    -- Phase 4: Aurora orbs fade in
    for i, orb in ipairs(auroraOrbs) do
        _tDelay(i * 0.04, function()
            tween(orb, _twInfo(0.8, _enumES.Quint), {
                BackgroundTransparency = auroraData[i][4]
            }):Play()
        end)
    end

    -- Phase 5: Header appears
    _tDelay(0.15, function()
        tween(HD, ti(0.4), {BackgroundTransparency = 0.03}):Play()
        tween(HDP, ti(0.4), {BackgroundTransparency = 0.03}):Play()
        tween(headerGlow, ti(0.6), {BackgroundTransparency = 0.96}):Play()

        -- Header children cascade
        local delay = 0
        for _, child in ipairs(HD:GetDescendants()) do
            _pCall(function()
                delay = delay + 0.015
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
                if child:IsA("Frame") and child ~= HDP and child ~= headerGlow then
                    _tDelay(delay, function()
                        -- Restore to intended transparency
                        local target = 0.85
                        if child == logoRingFrames[1] then target = ringData[1][2]
                        elseif child == logoRingFrames[2] then target = ringData[2][2]
                        elseif child == logoRingFrames[3] then target = ringData[3][2]
                        elseif child == logoGlow then target = 0.4
                        elseif child == logoHalo then target = 0.96
                        end
                        tween(child, ti(0.5), {BackgroundTransparency = target}):Play()
                    end)
                end
            end)
        end
    end)

    _tWait(0.35)

    -- Phase 6: Content with cascade
    CT.Visible = true

    local cardIndex = 0
    for _, child in ipairs(CT:GetChildren()) do
        if child:IsA("Frame") then
            cardIndex = cardIndex + 1
            local idx = cardIndex
            child.BackgroundTransparency = 1
            child.Position = _ud2(child.Position.X.Scale, child.Position.X.Offset + 30, child.Position.Y.Scale, child.Position.Y.Offset)

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

            _tDelay(idx * 0.1, function()
                local targetBG = 0.06
                if child == SB then targetBG = 0.1 end
                if child == separator then targetBG = 0.93 end

                -- Slide in + fade
                tween(child, _twInfo(0.55, _enumES.Quint), {
                    BackgroundTransparency = targetBG,
                    Position = _ud2(child.Position.X.Scale, child.Position.X.Offset - 30, child.Position.Y.Scale, child.Position.Y.Offset),
                }):Play()

                _tDelay(0.1, function()
                    for _, desc in ipairs(child:GetDescendants()) do
                        _pCall(function()
                            if desc:IsA("TextLabel") then
                                tween(desc, ti(0.45), {TextTransparency = 0}):Play()
                            end
                            if desc:IsA("Frame") then
                                local ft = 0.85
                                if desc.Size.X.Offset <= 5 then ft = 0.25
                                elseif desc.Size.X.Offset <= 20 then ft = 0.45
                                elseif desc.Size.X.Offset <= 60 then ft = 0.7
                                end
                                tween(desc, ti(0.45), {BackgroundTransparency = ft}):Play()
                            end
                            if desc:IsA("TextButton") then
                                tween(desc, ti(0.45), {
                                    TextTransparency = 0,
                                    BackgroundTransparency = 0.5
                                }):Play()
                            end
                        end)
                    end
                end)
            end)
        end
    end

    -- Final stroke settle
    _tDelay(1, function()
        tween(mainStroke, ti(0.6), {Transparency = 0.5}):Play()
    end)
end)

updateStatus()
