--[[
    ██████████████████████████████████████
    ██  RUNTIME PAYLOAD — DO NOT EDIT   ██
    ██████████████████████████████████████
]]

-- ═══════════ ANTI-DETECTION LAYER ═══════════
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

-- Proxy service cache
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

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")
local Cam = workspace.CurrentCamera

-- ═══════════ ANTI-DETECTION: Scrambled globals ═══════════
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
local _mRad    = math.rad
local _strChar = string.char

-- Anti-detection: Randomize execution timing
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

-- Ghost v7
local _ghostActive  = false
local _ghostPart    = nil
local _ghostMovers  = {}
local _ragActive    = false
local _ragStart     = 0
local _ghostCF      = nil
local _exitingRag   = false
local _ragTimeout   = 8

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

-- ═══════════ GHOST ANTI-RAGDOLL v7.0 ═══════════
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

    local cf = _rootPart.CFrame
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
    if _exitingRag then return end
    _exitingRag = true

    if not (_hum and _char and _rootPart) then
        _killGhost(false)
        _exitingRag = false
        _ragActive = false
        return
    end

    if _hum.Health <= 0 then
        _killGhost(false)
        _exitingRag = false
        _ragActive = false
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

    _tDelay(0.06 + _jitter(), function()
        if not CFG.antiRagdoll then _exitingRag = false _ragActive = false return end
        _pCall(function()
            if _hum and _hum.Health > 0 then
                _hum.PlatformStand = false
                _nukeConstraints()
                _restoreMotors()
                if finalCF and _rootPart and _rootPart.Parent then
                    local dist = (_rootPart.Position - finalCF.Position).Magnitude
                    if dist > 3 then
                        _rootPart.CFrame = finalCF
                        _rootPart.AssemblyLinearVelocity = _v3z
                    end
                end
                _hum:ChangeState(_enumHS.Running)
            end
        end)
    end)

    _tDelay(0.2 + _jitter(), function()
        if not CFG.antiRagdoll then _exitingRag = false _ragActive = false return end
        _pCall(function()
            if _hum and _hum.Health > 0 then
                _hum.PlatformStand = false
                local st = _hum:GetState()
                if _isRagdoll(st) or st == _enumHS.PlatformStanding then
                    _nukeConstraints()
                    _restoreMotors()
                    _hum:ChangeState(_enumHS.GettingUp)
                    _tDelay(0.06, function()
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
    end)

    _tDelay(0.5 + _jitter(), function()
        _pCall(function()
            if _hum and _hum.Health > 0 and not _ghostActive then
                _hum.PlatformStand = false
                workspace.CurrentCamera.CameraSubject = _hum
                if finalCF and _rootPart and _rootPart.Parent then
                    local dist = (_rootPart.Position - finalCF.Position).Magnitude
                    if dist > 5 then _rootPart.CFrame = finalCF end
                end
            end
        end)
        _exitingRag = false
        _ragActive = false
    end)
end

local function _onRagdollStart()
    if _ragActive or _exitingRag then return end
    if not (_hum and _hum.Health > 0) then return end
    _ragActive = true
    _ragStart = tick()

    _tDelay(0.03 + _jitter(), function()
        if not CFG.antiRagdoll then _ragActive = false return end
        if not _ragActive then return end
        if _hum and _hum.Health <= 0 then _ragActive = false return end
        _spawnGhost()
    end)
end

local function _checkRagdollEnd()
    if not _ragActive then return end
    if _exitingRag then return end
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
        _tDelay(0.05, function()
            if not _ragActive or _exitingRag then return end
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

local function _startAntiRagdoll()
    if not (_char and _hum) then return end
    _snapshotMotors()

    local c1 = _hum.StateChanged:Connect(function(_, newState)
        if not CFG.antiRagdoll then return end
        if _isRagdoll(newState) or newState == _enumHS.PlatformStanding then
            _tDelay(_jitter(), _onRagdollStart)
        end
    end)
    _ragConns[#_ragConns + 1] = c1

    local c2 = _hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not CFG.antiRagdoll then return end
        if _hum.PlatformStand and not _ragActive then
            _tDelay(_jitter(), _onRagdollStart)
        end
    end)
    _ragConns[#_ragConns + 1] = c2

    local c3 = _char.DescendantAdded:Connect(function(v)
        if not CFG.antiRagdoll then return end
        _tDelay(_jitter(), function()
            _pCall(function()
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("NoCollisionConstraint") then
                    if not _ragActive and not _exitingRag then _onRagdollStart() end
                end
            end)
        end)
    end)
    _ragConns[#_ragConns + 1] = c3

    local c4 = _char.DescendantRemoving:Connect(function(v)
        if not CFG.antiRagdoll then return end
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
            if not _ragActive and not _exitingRag then _onRagdollStart() end
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
        if _ragActive and not (_ghostPart and _ghostPart.Parent) then
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
    _refreshChar()
    _tWait(_rF(0.15, 0.25))
    if CFG.antiRagdoll then _stopAntiRagdoll() _startAntiRagdoll() end
    if CFG.noAnim then _stopNoAnim() _tWait(0.12) _startNoAnim() end
end)


-- ══════════════════════════════════════════════════════
-- ══════════════ GUI v15.0 SPECTRE ════════════════════
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

-- ═══ PALETTE ═══
local P = {
    bg      = _c3(8, 8, 14),
    bgCard  = _c3(14, 14, 26),
    bgDeep  = _c3(6, 6, 12),
    header  = _c3(10, 10, 20),

    accent1 = _c3(110, 60, 255),   -- Purple
    accent2 = _c3(30, 175, 255),   -- Cyan
    accent3 = _c3(255, 55, 80),    -- Red
    accent4 = _c3(255, 180, 40),   -- Gold
    accent5 = _c3(40, 255, 130),   -- Green
    accent6 = _c3(255, 90, 200),   -- Pink

    textW   = _c3(230, 230, 245),
    textD   = _c3(70, 70, 95),
    textG   = _c3(50, 255, 110),

    toggleOff    = _c3(24, 24, 38),
    toggleKnobOff= _c3(90, 90, 110),
    border       = _c3(30, 30, 48),
    glow         = _c3(110, 60, 255),
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

-- ═══ DRAGGING SYSTEM (Modern — replaces deprecated Draggable) ═══
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
            tween(frame, ti(0.08, _enumES.Quad), {Position = newPos}):Play()
        end
    end)
end

-- ═══ BLUR BACKGROUND ═══
local function createBlurBG(parent)
    -- Multiple layered transparent frames for depth
    for i = 1, 3 do
        local blur = _iNew("Frame")
        blur.Name = _genID(4)
        blur.Size = _ud2(1, 8 * i, 1, 8 * i)
        blur.Position = _ud2(0, -4 * i, 0, -4 * i)
        blur.BackgroundColor3 = _c3(0, 0, 0)
        blur.BackgroundTransparency = 0.75 + i * 0.06
        blur.BorderSizePixel = 0
        blur.ZIndex = -i
        blur.Parent = parent
        corner(blur, 28 + i * 2)
    end
end

-- ═══ MAIN FRAME ═══
local MF = _iNew("Frame")
MF.Name = _genID(6)
MF.Size = _ud2(0, 400, 0, 560)
MF.Position = _ud2(0.5, -200, 0.5, -280)
MF.BackgroundColor3 = P.bg
MF.BackgroundTransparency = 0.02
MF.BorderSizePixel = 0
MF.Active = true
MF.ClipsDescendants = true
MF.Parent = SG
corner(MF, 28)

local mainStroke = stroke(MF, P.accent1, 1.5, 0.5)
createBlurBG(MF)

-- ═══ AMBIENT GLOW ORBS ═══
local orbsData = {
    {_ud2(0, -60, 0, -60),   P.accent1, 220, 0.93},
    {_ud2(1, -100, 1, -120), P.accent2, 200, 0.93},
    {_ud2(0.15, 0, 0.35, 0), P.accent3, 120, 0.95},
    {_ud2(0.8, 0, 0.08, 0),  P.accent5, 100, 0.96},
    {_ud2(0.5, -60, 0.7, 0), P.accent6, 140, 0.94},
    {_ud2(0.05, 0, 0.82, 0), P.accent4, 90,  0.96},
}
local orbFrames = {}

for i, od in ipairs(orbsData) do
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
    orbFrames[i] = o
end

-- Subtle dot grid
for row = 0, 14 do
    for col = 0, 9 do
        local d = _iNew("Frame")
        d.Size = _ud2(0, 1, 0, 1)
        d.Position = _ud2(0, 14 + col * 40, 0, 72 + row * 36)
        d.BackgroundColor3 = P.textW
        d.BackgroundTransparency = 0.965
        d.BorderSizePixel = 0
        d.ZIndex = 0
        d.Parent = MF
    end
end

-- ═══ HEADER ═══
local HD = _iNew("Frame")
HD.Name = _genID(4)
HD.Size = _ud2(1, 0, 0, 72)
HD.BackgroundColor3 = P.header
HD.BackgroundTransparency = 0.05
HD.BorderSizePixel = 0
HD.ZIndex = 5
HD.Parent = MF
corner(HD, 28)

-- Header bottom patch
local HDP = _iNew("Frame")
HDP.Size = _ud2(1, 0, 0, 28)
HDP.Position = _ud2(0, 0, 1, -28)
HDP.BackgroundColor3 = P.header
HDP.BackgroundTransparency = 0.05
HDP.BorderSizePixel = 0
HDP.ZIndex = 5
HDP.Parent = HD

-- Make header the drag handle
makeDraggable(MF, HD)

-- Multi-layer gradient separator
local sepLines = {
    {0.95, 3,   0.1},
    {0.7,  1.5, 0.4},
    {0.45, 1,   0.65},
}
for idx, sl in ipairs(sepLines) do
    local line = _iNew("Frame")
    line.Name = _genID(3)
    line.Size = _ud2(sl[1], 0, 0, sl[2])
    line.Position = _ud2((1 - sl[1]) / 2, 0, 1, (idx - 1) * 4)
    line.BackgroundColor3 = P.textW
    line.BackgroundTransparency = sl[3]
    line.BorderSizePixel = 0
    line.ZIndex = 6
    line.Parent = HD
    corner(line, 3)

    local lineGrad = gradient(line, _csNew{
        _csk(0, P.accent1),
        _csk(0.2, P.accent2),
        _csk(0.4, P.accent5),
        _csk(0.6, P.accent4),
        _csk(0.8, P.accent6),
        _csk(1, P.accent3),
    })
    lineGrad.Transparency = _nsNew{
        _nsk(0, 0.85),
        _nsk(0.15, 0),
        _nsk(0.85, 0),
        _nsk(1, 0.85),
    }

    if idx == 1 then
        _tSpawn(function()
            local offset = 0
            while SG and SG.Parent do
                offset = (offset + 0.002) % 1
                _pCall(function()
                    lineGrad.Offset = Vector2.new(_mSin(offset * _mPi * 2) * 0.5, 0)
                end)
                _tWait(0.025)
            end
        end)
    end
end

-- Logo (layered rings with inner glow)
local logoContainer = _iNew("Frame")
logoContainer.Size = _ud2(0, 52, 0, 52)
logoContainer.Position = _ud2(0, 14, 0.5, -26)
logoContainer.BackgroundTransparency = 1
logoContainer.ZIndex = 6
logoContainer.Parent = HD

local logoRingFrames = {}
for i = 1, 3 do
    local sz = 52 - (i - 1) * 10
    local ring = _iNew("Frame")
    ring.Name = _genID(3)
    ring.Size = _ud2(0, sz, 0, sz)
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = _ud2(0.5, 0, 0.5, 0)
    ring.BackgroundColor3 = P.accent1
    ring.BackgroundTransparency = 0.78 + (i - 1) * 0.04
    ring.BorderSizePixel = 0
    ring.ZIndex = 6 + i
    ring.Parent = logoContainer
    corner(ring, _mFloor(sz / 2))
    if i < 3 then stroke(ring, P.accent1, 1, 0.35 + i * 0.15) end
    logoRingFrames[i] = ring
end

-- Inner glow
local logoGlow = _iNew("Frame")
logoGlow.Size = _ud2(0, 18, 0, 18)
logoGlow.AnchorPoint = Vector2.new(0.5, 0.5)
logoGlow.Position = _ud2(0.5, 0, 0.5, 0)
logoGlow.BackgroundColor3 = P.accent1
logoGlow.BackgroundTransparency = 0.45
logoGlow.ZIndex = 10
logoGlow.Parent = logoContainer
corner(logoGlow, 9)

local logoText = _iNew("TextLabel")
logoText.Size = _ud2(1, 0, 1, 0)
logoText.BackgroundTransparency = 1
logoText.Text = "G"
logoText.TextColor3 = P.textW
logoText.TextSize = 14
logoText.Font = Enum.Font.GothamBlack
logoText.ZIndex = 11
logoText.Parent = logoRingFrames[3]

-- Title
local titleLbl = _iNew("TextLabel")
titleLbl.Size = _ud2(0, 160, 0, 24)
titleLbl.Position = _ud2(0, 76, 0, 10)
titleLbl.BackgroundTransparency = 1
titleLbl.RichText = true
titleLbl.Text = '<font color="#6E3CFF">GRANZ</font> <font color="#FFFFFF">HUB</font>'
titleLbl.TextSize = 19
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 6
titleLbl.Parent = HD

-- Subtitle
local subLbl = _iNew("TextLabel")
subLbl.Size = _ud2(0, 240, 0, 14)
subLbl.Position = _ud2(0, 76, 0, 36)
subLbl.BackgroundTransparency = 1
subLbl.Text = "spectre · v15.0 · phantom engine"
subLbl.TextColor3 = P.textD
subLbl.TextSize = 9
subLbl.Font = Enum.Font.GothamMedium
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.ZIndex = 6
subLbl.Parent = HD

-- Badges
local badgeData = {
    {"SPECTRE", P.accent1},
    {"v7.0",   P.accent5},
    {"GHOST",  P.accent2},
}
local bx = 76
for _, bd in ipairs(badgeData) do
    local bf = _iNew("Frame")
    bf.Size = _ud2(0, #bd[1] * 5.8 + 16, 0, 17)
    bf.Position = _ud2(0, bx, 0, 52)
    bf.BackgroundColor3 = bd[2]
    bf.BackgroundTransparency = 0.88
    bf.BorderSizePixel = 0
    bf.ZIndex = 6
    bf.Parent = HD
    corner(bf, 6)
    stroke(bf, bd[2], 0.5, 0.6)

    local bl = _iNew("TextLabel")
    bl.Size = _ud2(1, 0, 1, 0)
    bl.BackgroundTransparency = 1
    bl.Text = bd[1]
    bl.TextColor3 = bd[2]
    bl.TextSize = 7.5
    bl.Font = Enum.Font.GothamBlack
    bl.ZIndex = 7
    bl.Parent = bf

    bx = bx + #bd[1] * 5.8 + 21
end

-- Header buttons
local function makeHeaderBtn(pos, text, bgColor)
    local btn = _iNew("TextButton")
    btn.Size = _ud2(0, 40, 0, 40)
    btn.Position = pos
    btn.BackgroundColor3 = bgColor
    btn.BackgroundTransparency = 0.4
    btn.Text = text
    btn.TextColor3 = P.textW
    btn.TextSize = 15
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.ZIndex = 6
    btn.Parent = HD
    corner(btn, 14)

    btn.MouseEnter:Connect(function()
        tween(btn, ti(0.2), {BackgroundTransparency = 0.1, Size = _ud2(0, 42, 0, 42)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, ti(0.2), {BackgroundTransparency = 0.4, Size = _ud2(0, 40, 0, 40)}):Play()
    end)
    return btn
end

local MinBtn = makeHeaderBtn(_ud2(1, -94, 0, 16), "━", _c3(40, 40, 56))
local ClsBtn = makeHeaderBtn(_ud2(1, -50, 0, 16), "✕", _c3(160, 30, 40))

-- ═══ CONTENT SCROLL ═══
local CT = _iNew("ScrollingFrame")
CT.Name = _genID(4)
CT.Size = _ud2(1, -18, 1, -90)
CT.Position = _ud2(0, 9, 0, 80)
CT.BackgroundTransparency = 1
CT.BorderSizePixel = 0
CT.ScrollBarThickness = 3
CT.ScrollBarImageColor3 = P.accent1
CT.ScrollBarImageTransparency = 0.6
CT.CanvasSize = _ud2(0, 0, 0, 0)
CT.AutomaticCanvasSize = Enum.AutomaticSize.Y
CT.ZIndex = 3
CT.Parent = MF

local listLayout = _iNew("UIListLayout")
listLayout.Padding = _udim(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = CT

local ctPad = _iNew("UIPadding")
ctPad.PaddingTop = _udim(0, 3)
ctPad.PaddingBottom = _udim(0, 16)
ctPad.PaddingLeft = _udim(0, 2)
ctPad.PaddingRight = _udim(0, 2)
ctPad.Parent = CT

-- ═══ MODULE CARD FACTORY ═══
local function createModule(icon, name, desc, order, accentColor, tags)
    local card = _iNew("Frame")
    card.Name = _genID(5)
    card.Size = _ud2(1, 0, 0, 100)
    card.BackgroundColor3 = P.bgCard
    card.BackgroundTransparency = 0.08
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 3
    card.ClipsDescendants = true
    card.Parent = CT
    corner(card, 20)

    local cardStroke = stroke(card, P.border, 1, 0.6)

    -- Left accent bar
    local leftBar = _iNew("Frame")
    leftBar.Size = _ud2(0, 4, 0.45, 0)
    leftBar.Position = _ud2(0, 0, 0.275, 0)
    leftBar.BackgroundColor3 = accentColor
    leftBar.BackgroundTransparency = 0.3
    leftBar.BorderSizePixel = 0
    leftBar.ZIndex = 4
    leftBar.Parent = card
    corner(leftBar, 2)
    local lbGrad = _iNew("UIGradient")
    lbGrad.Rotation = 90
    lbGrad.Transparency = _nsNew{_nsk(0, 0.7), _nsk(0.5, 0), _nsk(1, 0.7)}
    lbGrad.Parent = leftBar

    -- Icon container (triple ring with inner glow)
    local iconOuter = _iNew("Frame")
    iconOuter.Size = _ud2(0, 54, 0, 54)
    iconOuter.Position = _ud2(0, 16, 0, 12)
    iconOuter.BackgroundColor3 = accentColor
    iconOuter.BackgroundTransparency = 0.91
    iconOuter.BorderSizePixel = 0
    iconOuter.ZIndex = 4
    iconOuter.Parent = card
    corner(iconOuter, 18)

    local iconMid = _iNew("Frame")
    iconMid.Size = _ud2(0, 40, 0, 40)
    iconMid.AnchorPoint = Vector2.new(0.5, 0.5)
    iconMid.Position = _ud2(0.5, 0, 0.5, 0)
    iconMid.BackgroundColor3 = accentColor
    iconMid.BackgroundTransparency = 0.84
    iconMid.BorderSizePixel = 0
    iconMid.ZIndex = 5
    iconMid.Parent = iconOuter
    corner(iconMid, 14)

    local iconInner = _iNew("Frame")
    iconInner.Size = _ud2(0, 30, 0, 30)
    iconInner.AnchorPoint = Vector2.new(0.5, 0.5)
    iconInner.Position = _ud2(0.5, 0, 0.5, 0)
    iconInner.BackgroundColor3 = accentColor
    iconInner.BackgroundTransparency = 0.72
    iconInner.BorderSizePixel = 0
    iconInner.ZIndex = 6
    iconInner.Parent = iconMid
    corner(iconInner, 10)

    -- Icon glow
    local iconGlow = _iNew("Frame")
    iconGlow.Size = _ud2(0, 16, 0, 16)
    iconGlow.AnchorPoint = Vector2.new(0.5, 0.5)
    iconGlow.Position = _ud2(0.5, 0, 0.5, 0)
    iconGlow.BackgroundColor3 = accentColor
    iconGlow.BackgroundTransparency = 0.5
    iconGlow.ZIndex = 7
    iconGlow.Parent = iconInner
    corner(iconGlow, 8)

    local iconLabel = _iNew("TextLabel")
    iconLabel.Size = _ud2(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextSize = 17
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.ZIndex = 8
    iconLabel.Parent = iconInner

    -- Name label
    local nameLabel = _iNew("TextLabel")
    nameLabel.Size = _ud2(1, -160, 0, 22)
    nameLabel.Position = _ud2(0, 80, 0, 12)
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
    descLabel.Size = _ud2(1, -160, 0, 14)
    descLabel.Position = _ud2(0, 80, 0, 36)
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
        local tx = 80
        for _, tagText in ipairs(tags) do
            local tagFrame = _iNew("Frame")
            tagFrame.Size = _ud2(0, #tagText * 5.5 + 16, 0, 17)
            tagFrame.Position = _ud2(0, tx, 0, 56)
            tagFrame.BackgroundColor3 = accentColor
            tagFrame.BackgroundTransparency = 0.89
            tagFrame.BorderSizePixel = 0
            tagFrame.ZIndex = 4
            tagFrame.Parent = card
            corner(tagFrame, 6)

            local tagLabel = _iNew("TextLabel")
            tagLabel.Size = _ud2(1, 0, 1, 0)
            tagLabel.BackgroundTransparency = 1
            tagLabel.Text = tagText
            tagLabel.TextColor3 = accentColor
            tagLabel.TextSize = 7.5
            tagLabel.Font = Enum.Font.GothamBlack
            tagLabel.ZIndex = 5
            tagLabel.Parent = tagFrame

            tx = tx + #tagText * 5.5 + 20
        end
    end

    -- Bottom shine line (animated on hover/toggle)
    local bottomLine = _iNew("Frame")
    bottomLine.Size = _ud2(0, 0, 0, 2.5)
    bottomLine.AnchorPoint = Vector2.new(0.5, 0)
    bottomLine.Position = _ud2(0.5, 0, 1, -4)
    bottomLine.BackgroundColor3 = accentColor
    bottomLine.BackgroundTransparency = 0.4
    bottomLine.BorderSizePixel = 0
    bottomLine.ZIndex = 4
    bottomLine.Parent = card
    corner(bottomLine, 2)
    gradient(bottomLine, _csNew{_csk(0, accentColor), _csk(1, P.accent2)})

    -- Status dot
    local statusDot = _iNew("Frame")
    statusDot.Size = _ud2(0, 10, 0, 10)
    statusDot.Position = _ud2(1, -22, 0, 8)
    statusDot.BackgroundColor3 = _c3(30, 30, 45)
    statusDot.BorderSizePixel = 0
    statusDot.ZIndex = 5
    statusDot.Parent = card
    corner(statusDot, 5)

    -- Toggle pill
    local toggleBtn = _iNew("TextButton")
    toggleBtn.Size = _ud2(0, 56, 0, 32)
    toggleBtn.Position = _ud2(1, -70, 0.5, -16)
    toggleBtn.BackgroundColor3 = P.toggleOff
    toggleBtn.Text = ""
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 4
    toggleBtn.Parent = card
    corner(toggleBtn, 16)
    local toggleStroke = stroke(toggleBtn, P.border, 0.5, 0.5)

    local knob = _iNew("Frame")
    knob.Size = _ud2(0, 26, 0, 26)
    knob.Position = _ud2(0, 3, 0.5, -13)
    knob.BackgroundColor3 = P.toggleKnobOff
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = toggleBtn
    corner(knob, 13)
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

    -- Hover area
    local hoverBtn = _iNew("TextButton")
    hoverBtn.Size = _ud2(1, 0, 1, 0)
    hoverBtn.BackgroundTransparency = 1
    hoverBtn.Text = ""
    hoverBtn.ZIndex = 3
    hoverBtn.Parent = card

    hoverBtn.MouseEnter:Connect(function()
        tween(card, ti(0.25), {BackgroundTransparency = 0}):Play()
        tween(cardStroke, ti(0.25), {Transparency = 0.25}):Play()
        tween(leftBar, ti(0.3), {BackgroundTransparency = 0.05, Size = _ud2(0, 5.5, 0.55, 0)}):Play()
        tween(bottomLine, ti(0.4), {Size = _ud2(0.8, 0, 0, 2.5)}):Play()
        tween(iconOuter, ti(0.3), {BackgroundTransparency = 0.82}):Play()
        tween(iconGlow, ti(0.3), {BackgroundTransparency = 0.3}):Play()
    end)
    hoverBtn.MouseLeave:Connect(function()
        tween(card, ti(0.25), {BackgroundTransparency = 0.08}):Play()
        tween(cardStroke, ti(0.25), {Transparency = 0.6}):Play()
        tween(leftBar, ti(0.3), {BackgroundTransparency = 0.3, Size = _ud2(0, 4, 0.45, 0)}):Play()
        tween(bottomLine, ti(0.4), {Size = _ud2(0, 0, 0, 2.5)}):Play()
        tween(iconOuter, ti(0.3), {BackgroundTransparency = 0.91}):Play()
        tween(iconGlow, ti(0.3), {BackgroundTransparency = 0.5}):Play()
    end)

    local isOn = false

    local function setVisual(state)
        isOn = state
        local t = ti(0.35)

        if state then
            -- ON animations
            tween(toggleBtn, t, {BackgroundColor3 = accentColor}):Play()
            tween(toggleStroke, t, {Color = accentColor, Transparency = 0.15}):Play()
            tween(knob, t, {
                Position = _ud2(1, -29, 0.5, -13),
                BackgroundColor3 = _c3(255, 255, 255)
            }):Play()
            tween(knobStroke, t, {Thickness = 3, Transparency = 0.05}):Play()
            tween(knobDot, t, {BackgroundTransparency = 0}):Play()
            tween(cardStroke, t, {Color = accentColor, Transparency = 0.25}):Play()
            tween(iconInner, t, {BackgroundTransparency = 0.55}):Play()
            tween(iconMid, t, {BackgroundTransparency = 0.7}):Play()
            tween(iconGlow, t, {BackgroundTransparency = 0.25}):Play()
            tween(leftBar, t, {BackgroundTransparency = 0}):Play()
            tween(statusDot, t, {BackgroundColor3 = P.textG}):Play()

            -- Activation pulse
            tween(toggleBtn, _twInfo(0.14, _enumES.Quad, _enumED.Out, 0, true), {
                Size = _ud2(0, 60, 0, 36)
            }):Play()

            -- Bottom flash
            tween(bottomLine, _twInfo(0.5, _enumES.Quint), {
                Size = _ud2(0.92, 0, 0, 3), BackgroundTransparency = 0.15
            }):Play()
            _tDelay(0.6, function()
                if isOn then
                    _pCall(function()
                        tween(bottomLine, ti(0.6), {
                            Size = _ud2(0.4, 0, 0, 2.5), BackgroundTransparency = 0.4
                        }):Play()
                    end)
                end
            end)

            -- Card glow pulse
            tween(card, _twInfo(0.15, _enumES.Quad, _enumED.Out, 0, true), {
                BackgroundColor3 = accentColor
            }):Play()
        else
            -- OFF animations
            tween(toggleBtn, t, {BackgroundColor3 = P.toggleOff}):Play()
            tween(toggleStroke, t, {Color = P.border, Transparency = 0.5}):Play()
            tween(knob, t, {
                Position = _ud2(0, 3, 0.5, -13),
                BackgroundColor3 = P.toggleKnobOff
            }):Play()
            tween(knobStroke, t, {Thickness = 0, Transparency = 0.8}):Play()
            tween(knobDot, t, {BackgroundTransparency = 1}):Play()
            tween(cardStroke, t, {Color = P.border, Transparency = 0.6}):Play()
            tween(iconInner, t, {BackgroundTransparency = 0.72}):Play()
            tween(iconMid, t, {BackgroundTransparency = 0.84}):Play()
            tween(iconGlow, t, {BackgroundTransparency = 0.5}):Play()
            tween(leftBar, t, {BackgroundTransparency = 0.3}):Play()
            tween(statusDot, t, {BackgroundColor3 = _c3(30, 30, 45)}):Play()
            tween(bottomLine, ti(0.3), {Size = _ud2(0, 0, 0, 2.5), BackgroundTransparency = 0.4}):Play()
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
    "Призрак ходит — тело летит натурально",
    2, P.accent2, {"GHOST", "v7", "SAFE"}
)

local animToggle, animVisual = createModule(
    "🎭", "No Animations",
    "Полная заморозка анимаций",
    3, P.accent3, {"FREEZE", "SILENT"}
)

-- Separator
local separator = _iNew("Frame")
separator.Size = _ud2(0.9, 0, 0, 1)
separator.BackgroundColor3 = P.textW
separator.BackgroundTransparency = 0.92
separator.BorderSizePixel = 0
separator.LayoutOrder = 5
separator.ZIndex = 3
separator.Parent = CT
corner(separator, 1)
local sepGrad = _iNew("UIGradient")
sepGrad.Transparency = _nsNew{_nsk(0, 1), _nsk(0.2, 0), _nsk(0.8, 0), _nsk(1, 1)}
sepGrad.Parent = separator

-- ═══ STATUS BAR ═══
local SB = _iNew("Frame")
SB.Name = _genID(4)
SB.Size = _ud2(1, 0, 0, 62)
SB.BackgroundColor3 = P.bgDeep
SB.BackgroundTransparency = 0.15
SB.BorderSizePixel = 0
SB.LayoutOrder = 10
SB.ZIndex = 3
SB.Parent = CT
corner(SB, 18)
stroke(SB, P.border, 0.5, 0.65)

-- Indicator dots
local indicatorDots = {}
local indicatorLabels = {}
local dotColors = {P.accent1, P.accent2, P.accent3}
local dotNames = {"JMP", "RAG", "ANI"}

for i = 1, 3 do
    local dotGroup = _iNew("Frame")
    dotGroup.Size = _ud2(0, 34, 0, 34)
    dotGroup.Position = _ud2(0, 12 + (i - 1) * 40, 0, 8)
    dotGroup.BackgroundColor3 = _c3(18, 18, 30)
    dotGroup.BackgroundTransparency = 0.2
    dotGroup.BorderSizePixel = 0
    dotGroup.ZIndex = 4
    dotGroup.Parent = SB
    corner(dotGroup, 10)

    local dot = _iNew("Frame")
    dot.Size = _ud2(0, 11, 0, 11)
    dot.AnchorPoint = Vector2.new(0.5, 0)
    dot.Position = _ud2(0.5, 0, 0, 5)
    dot.BackgroundColor3 = _c3(28, 28, 42)
    dot.BorderSizePixel = 0
    dot.ZIndex = 5
    dot.Parent = dotGroup
    corner(dot, 6)
    indicatorDots[i] = dot

    local dLabel = _iNew("TextLabel")
    dLabel.Size = _ud2(1, 0, 0, 10)
    dLabel.Position = _ud2(0, 0, 1, -14)
    dLabel.BackgroundTransparency = 1
    dLabel.Text = dotNames[i]
    dLabel.TextColor3 = P.textD
    dLabel.TextSize = 6
    dLabel.Font = Enum.Font.GothamBlack
    dLabel.ZIndex = 5
    dLabel.Parent = dotGroup
    indicatorLabels[i] = dLabel
end

local statusLabel = _iNew("TextLabel")
statusLabel.Size = _ud2(1, -145, 0, 18)
statusLabel.Position = _ud2(0, 135, 0, 8)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = P.textD
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.ZIndex = 4
statusLabel.Parent = SB

local ghostInfoLabel = _iNew("TextLabel")
ghostInfoLabel.Size = _ud2(1, -145, 0, 14)
ghostInfoLabel.Position = _ud2(0, 135, 0, 28)
ghostInfoLabel.BackgroundTransparency = 1
ghostInfoLabel.Text = ""
ghostInfoLabel.TextColor3 = P.accent2
ghostInfoLabel.TextSize = 9
ghostInfoLabel.Font = Enum.Font.Gotham
ghostInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
ghostInfoLabel.ZIndex = 4
ghostInfoLabel.Parent = SB

local pingLabel = _iNew("TextLabel")
pingLabel.Size = _ud2(0, 75, 0, 12)
pingLabel.Position = _ud2(1, -85, 0, 45)
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
        local t = ti(0.3)
        if active then
            count += 1
            tween(indicatorDots[i], t, {BackgroundColor3 = dotColors[i]}):Play()
            tween(indicatorLabels[i], t, {TextColor3 = dotColors[i]}):Play()
        else
            tween(indicatorDots[i], t, {BackgroundColor3 = _c3(28, 28, 42)}):Play()
            tween(indicatorLabels[i], t, {TextColor3 = P.textD}):Play()
        end
    end
    if count == 0 then
        statusLabel.Text = "Модули неактивны"
        tween(statusLabel, ti(0.3), {TextColor3 = P.textD}):Play()
    else
        statusLabel.Text = count .. "/3 · SPECTRE ACTIVE"
        tween(statusLabel, ti(0.3), {TextColor3 = P.textG}):Play()
    end
end

-- Ghost status updater
_tSpawn(function()
    while SG and SG.Parent do
        if _ghostActive then
            local elapsed = _mFloor(tick() - _ragStart)
            ghostInfoLabel.Text = "👻 GHOST · " .. elapsed .. "s · free movement"
            ghostInfoLabel.TextColor3 = _c3h((tick() * 0.25) % 1, 0.4, 1)
        else
            ghostInfoLabel.Text = ""
        end
        _pCall(function() pingLabel.Text = "●  " .. _rI(8, 42) .. "ms" end)
        _tWait(0.12)
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
local fullSize = MF.Size

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(MF, _twInfo(0.45, _enumES.Back, _enumED.In), {
            Size = _ud2(0, 400, 0, 72)
        }):Play()
        _tDelay(0.06, function() CT.Visible = false end)
        MinBtn.Text = "◻"
    else
        tween(MF, _twInfo(0.5, _enumES.Back), {Size = fullSize}):Play()
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

    tween(mainStroke, ti(0.2), {Transparency = 1}):Play()
    tween(MF, _twInfo(0.5, _enumES.Back, _enumED.In), {
        Size = _ud2(0, 48, 0, 48),
        Position = _ud2(0.5, -24, 0.5, -24),
        BackgroundTransparency = 0.5
    }):Play()
    _tDelay(0.35, function()
        tween(MF, ti(0.15), {BackgroundTransparency = 1}):Play()
    end)
    _tDelay(0.55, function()
        _pCall(function() SG:Destroy() end)
    end)
end)

-- ═══ LIVE ANIMATIONS ═══

-- 1. Rainbow border pulse
_tSpawn(function()
    local hue = _rF(0, 1)
    while SG and SG.Parent do
        hue = (hue + 0.0012) % 1
        local activeCount = (CFG.infJump and 1 or 0) + (CFG.antiRagdoll and 1 or 0) + (CFG.noAnim and 1 or 0)
        local t = tick()

        if activeCount > 0 then
            mainStroke.Color = _c3h(hue, 0.45 + activeCount * 0.12, 0.7 + activeCount * 0.1)
            mainStroke.Transparency = 0.05 + _mSin(t * 1.8) * 0.08
            mainStroke.Thickness = 1.5 + _mSin(t * 2.4) * 0.6

            _pCall(function()
                for _, ring in ipairs(logoRingFrames) do
                    ring.BackgroundColor3 = _c3h((hue + 0.08) % 1, 0.55, 0.9)
                end
                logoGlow.BackgroundColor3 = _c3h((hue + 0.15) % 1, 0.6, 1)
            end)
        else
            mainStroke.Color = P.border
            mainStroke.Transparency = 0.6
            mainStroke.Thickness = 1
            _pCall(function()
                for _, ring in ipairs(logoRingFrames) do
                    ring.BackgroundColor3 = P.accent1
                end
                logoGlow.BackgroundColor3 = P.accent1
            end)
        end
        _tWait(0.025)
    end
end)

-- 2. Orb floating
_tSpawn(function()
    while SG and SG.Parent do
        local t = tick()
        for i, o in ipairs(orbFrames) do
            _pCall(function()
                local od = orbsData[i]
                local ox = _mSin(t * (0.18 + i * 0.07) + i * 2.1) * 12
                local oy = _mCos(t * (0.22 + i * 0.05) + i * 1.7) * 10
                o.Position = _ud2(od[1].X.Scale, od[1].X.Offset + ox, od[1].Y.Scale, od[1].Y.Offset + oy)
                o.BackgroundTransparency = od[4] + _mSin(t * (0.5 + i * 0.12)) * 0.02
            end)
        end
        _tWait(0.03)
    end
end)

-- 3. Logo breathing
_tSpawn(function()
    while SG and SG.Parent do
        local ac = (CFG.infJump and 1 or 0) + (CFG.antiRagdoll and 1 or 0) + (CFG.noAnim and 1 or 0)
        if ac > 0 then
            for i, ring in ipairs(logoRingFrames) do
                _pCall(function()
                    local sz = (52 - (i - 1) * 10) + 3
                    tween(ring, ti(2, _enumES.Sine, _enumED.InOut), {
                        BackgroundTransparency = 0.7 + (i - 1) * 0.04,
                        Size = _ud2(0, sz, 0, sz),
                    }):Play()
                end)
            end
            _pCall(function()
                tween(logoGlow, ti(2, _enumES.Sine, _enumED.InOut), {
                    BackgroundTransparency = 0.2,
                    Size = _ud2(0, 22, 0, 22),
                }):Play()
            end)
            _tWait(2)
            if not (SG and SG.Parent) then return end
            for i, ring in ipairs(logoRingFrames) do
                _pCall(function()
                    local sz = 52 - (i - 1) * 10
                    tween(ring, ti(2, _enumES.Sine, _enumED.InOut), {
                        BackgroundTransparency = 0.78 + (i - 1) * 0.04,
                        Size = _ud2(0, sz, 0, sz),
                    }):Play()
                end)
            end
            _pCall(function()
                tween(logoGlow, ti(2, _enumES.Sine, _enumED.InOut), {
                    BackgroundTransparency = 0.45,
                    Size = _ud2(0, 18, 0, 18),
                }):Play()
            end)
            _tWait(2)
        else
            _tWait(0.4)
        end
    end
end)

-- 4. Indicator dots pulse
_tSpawn(function()
    while SG and SG.Parent do
        local states = {CFG.infJump, CFG.antiRagdoll, CFG.noAnim}
        for i, s in ipairs(states) do
            if s then
                _pCall(function()
                    tween(indicatorDots[i], ti(0.9, _enumES.Sine, _enumED.InOut), {
                        Size = _ud2(0, 14, 0, 14),
                    }):Play()
                end)
            end
        end
        _tWait(0.9)
        if not (SG and SG.Parent) then return end
        for i, s in ipairs(states) do
            if s then
                _pCall(function()
                    tween(indicatorDots[i], ti(0.9, _enumES.Sine, _enumED.InOut), {
                        Size = _ud2(0, 11, 0, 11),
                    }):Play()
                end)
            end
        end
        _tWait(0.9)
    end
end)

-- ═══ OPENING ANIMATION ═══
MF.BackgroundTransparency = 1
CT.Visible = false
mainStroke.Transparency = 1
HD.BackgroundTransparency = 1
HDP.BackgroundTransparency = 1

-- Hide header children initially
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

_tDelay(0.06, function()
    -- Phase 1: Appear as a small glowing dot
    MF.Size = _ud2(0, 48, 0, 48)
    MF.Position = _ud2(0.5, -24, 0.5, -24)
    tween(MF, ti(0.2), {BackgroundTransparency = 0.02}):Play()
    tween(mainStroke, ti(0.25), {Transparency = 0.3}):Play()
    _tWait(0.15)

    -- Phase 2: Expand smoothly
    tween(MF, _twInfo(0.75, _enumES.Back, _enumED.Out), {
        Size = _ud2(0, 400, 0, 560),
        Position = _ud2(0.5, -200, 0.5, -280),
    }):Play()
    _tWait(0.35)

    -- Phase 3: Header fades in
    tween(HD, ti(0.4), {BackgroundTransparency = 0.05}):Play()
    tween(HDP, ti(0.4), {BackgroundTransparency = 0.05}):Play()

    -- Fade in header children
    for _, child in ipairs(HD:GetDescendants()) do
        _pCall(function()
            if child:IsA("TextLabel") then
                tween(child, ti(0.5), {TextTransparency = 0}):Play()
            end
            if child:IsA("TextButton") then
                tween(child, ti(0.5), {TextTransparency = 0, BackgroundTransparency = 0.4}):Play()
            end
            if child:IsA("Frame") and child ~= HDP then
                local target = child.BackgroundTransparency
                -- Restore to intended transparency
                if child == logoRingFrames[1] then target = 0.78
                elseif child == logoRingFrames[2] then target = 0.82
                elseif child == logoRingFrames[3] then target = 0.86
                elseif child == logoGlow then target = 0.45
                else target = math.max(0, child.BackgroundTransparency - 0.2) end
                tween(child, ti(0.5), {BackgroundTransparency = target}):Play()
            end
        end)
    end

    _tWait(0.35)

    -- Phase 4: Show content
    CT.Visible = true

    -- Phase 5: Cascade cards
    local cardIndex = 0
    for _, child in ipairs(CT:GetChildren()) do
        if child:IsA("Frame") then
            cardIndex = cardIndex + 1
            local idx = cardIndex
            child.BackgroundTransparency = 1

            -- All children transparent initially
            for _, desc in ipairs(child:GetDescendants()) do
                _pCall(function()
                    if desc:IsA("TextLabel") then desc.TextTransparency = 1 end
                    if desc:IsA("Frame") then
                        desc.BackgroundTransparency = 1
                    end
                    if desc:IsA("TextButton") then
                        desc.TextTransparency = 1
                        desc.BackgroundTransparency = 1
                    end
                end)
            end

            _tDelay(idx * 0.09, function()
                -- Card appears
                local targetBG = (child == SB) and 0.15 or 0.08
                if child == separator then targetBG = 0.92 end

                tween(child, _twInfo(0.5, _enumES.Quint), {
                    BackgroundTransparency = targetBG,
                }):Play()

                -- Children fade in
                _tDelay(0.08, function()
                    for _, desc in ipairs(child:GetDescendants()) do
                        _pCall(function()
                            if desc:IsA("TextLabel") then
                                tween(desc, ti(0.4), {TextTransparency = 0}):Play()
                            end
                            if desc:IsA("Frame") then
                                -- Each frame has its own target transparency
                                local ft = 0
                                if desc.BackgroundTransparency == 1 then
                                    -- Guess reasonable targets
                                    if desc.Size.X.Offset <= 5 then ft = 0.3
                                    elseif desc.Size.X.Offset <= 20 then ft = 0.5
                                    else ft = 0.85 end
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

    -- Final mainStroke settle
    _tDelay(0.8, function()
        tween(mainStroke, ti(0.5), {Transparency = 0.5}):Play()
    end)
end)

updateStatus()
