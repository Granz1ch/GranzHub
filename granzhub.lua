--[[
    ╔══════════════════════════════════════════════════╗
    ║   GRANZ HUB · TERMINATOR v19.0 · SAB EDITION   ║
    ║   Steal a Brainrot · Ultra Stealth Engine       ║
    ╚══════════════════════════════════════════════════╝
]]

-- ═══ IDENTITY SCRAMBLE ═══
local _ID = tostring(math.random(100000,999999))
local _SALT = tick() * math.random(1,9999)

-- ═══ SERVICES (via index to avoid detection) ═══
local _gs = game.GetService
local _Players      = _gs(game, "Players")
local _UIS          = _gs(game, "UserInputService")
local _RS           = _gs(game, "RunService")
local _TS           = _gs(game, "TweenService")
local _Lighting     = _gs(game, "Lighting")
local _HTTP         = _gs(game, "HttpService") -- for JSON tricks

local _LP   = _Players.LocalPlayer
local _PG   = _LP:WaitForChild("PlayerGui")
local _Cam  = workspace.CurrentCamera

-- ═══ STEALTH: FUNCTION ALIASES ═══
local _tw   = task.wait
local _td   = task.delay
local _tsp  = task.spawn
local _tdf  = task.defer
local _pc   = pcall
local _xpc  = xpcall
local _IN   = Instance.new
local _v3   = Vector3.new
local _v3z  = Vector3.zero
local _cf   = CFrame.new
local _cfL  = CFrame.lookAt
local _ud2  = UDim2.new
local _ud   = UDim.new
local _c3   = Color3.fromRGB
local _c3h  = Color3.fromHSV
local _mf   = math.floor
local _ms   = math.sin
local _mc   = math.cos
local _ma   = math.abs
local _mpi  = math.pi
local _mclp = math.clamp
local _msq  = math.sqrt
local _mat  = math.atan2
local _mmx  = math.max
local _mmn  = math.min
local _mhg  = math.huge
local _mrd  = math.random
local _mrnd = math.round
local _tbl  = table
local _str  = string
local _type = type
local _iprs = ipairs
local _prs  = pairs
local _toN  = tonumber
local _toS  = tostring

-- ═══ STEALTH RNG ═══
local _RNG = Random.new(os.clock() * tick() % 2147483647)
local function _rf(a,b) return _RNG:NextNumber(a,b) end
local function _ri(a,b) return _RNG:NextInteger(a,b) end
local function _jit() return _rf(0.001, 0.007) end

-- Random ID generator (obfuscate instance names)
local _CHARS = "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM"
local function _gID(n)
    n = n or _ri(10,18)
    local b = table.create(n)
    for i=1,n do b[i]=_CHARS:sub(_ri(1,#_CHARS),_ri(1,#_CHARS)) or "x" end
    return table.concat(b)
end

-- ═══ STEALTH: DELAYED START ═══
_tw(_rf(0.05, 0.15))

-- ═══════════════════════════════════════════════
-- STEAL A BRAINROT · GAME DETECTION
-- ═══════════════════════════════════════════════
local _SAB_GAME = {
    -- SAB specific paths (adjust per game update)
    brainrotFolder  = nil,
    gameFolder      = nil,
    isDetected      = false,
}

_tsp(function()
    _tw(1)
    _pc(function()
        -- Try to find SAB-specific objects
        for _, v in _iprs(workspace:GetChildren()) do
            if v:IsA("Folder") or v:IsA("Model") then
                _SAB_GAME.gameFolder = v
            end
        end
        _SAB_GAME.isDetected = true
    end)
end)

-- ═══════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════
local CFG = {
    -- Movement
    infJump      = false,
    jumpPower    = 55,
    jumpCooldown = 0.10,
    speed        = false,
    speedValue   = 32,
    fly          = false,
    flySpeed     = 65,
    noclip       = false,
    lowGravity   = false,
    -- Combat
    antiRagdoll  = false,
    godMode      = false,
    noAnim       = false,
    bigHead      = false,
    hitboxExp    = false,
    hitboxSize   = 8,
    -- Aimbot
    aimbot       = false,
    aimbotKey    = Enum.KeyCode.Q,
    aimbotFOV    = 180,
    aimbotSmooth = 0.15,
    aimbotPart   = "Head",
    silentAim    = false,
    -- Visual
    esp          = false,
    chams        = false,
    tracers      = false,
    fullbright   = false,
    noFog        = false,
    -- SAB Specific
    autoBrainrot = false,  -- auto collect brainrots
    speedBoost   = false,  -- special SAB speed
    noKnockback  = false,  -- no knockback in SAB
}

-- ═══════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════
local _char, _hum, _hrp, _anim
local _lastJump   = 0
local _ragConns   = {}
local _animConns  = {}
local _trackedA   = {}
local _motorSnap  = {}
local _fabMotors  = {}
local _fc         = 0  -- frame counter

-- Ghost system
local _ghostOn    = false
local _ghostPart  = nil
local _ghostMvrs  = {}
local _ragOn      = false
local _ragT       = 0
local _preRagCF   = nil
local _ghostCF    = nil
local _exitingR   = false
local _ragMax     = 7
local _exitLk     = false
local _lastExit   = 0

-- Fly
local _flyBV, _flyBG
local _flyOn = false

-- ESP/Visual
local _espObj  = {}
local _chamObj = {}
local _tracerF = nil
local _noclipC = nil
local _godC    = nil
local _hitPrts = {}
local _modC    = {}

-- Lighting backup
local _origAmb, _origBri, _origFogE, _origFogS
local _origGrav = workspace.Gravity
local _origSpd  = 16

-- Aimbot
local _aimTgt  = nil
local _aimLock = false
local _aimFOVG = nil

-- SAB specific
local _sabConns = {}
local _autoBrainrotConn = nil

-- ═══════════════════════════════════════════════
-- STEALTH: FAKE HUMANOID CALLS
-- (mimics normal player behavior)
-- ═══════════════════════════════════════════════
local _stealthCalls = {
    function() end,
    function() _tw(_jit()) end,
    function() local _ = workspace.Gravity end,
}

local function _disguise()
    -- random call to look normal
    _stealthCalls[_ri(1,#_stealthCalls)]()
end

-- ═══════════════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════════════
local function _sf(obj, name)
    if not obj then return nil end
    local ok,r = _pc(function() return obj:FindFirstChild(name) end)
    return ok and r or nil
end

local function _sfc(obj, cls)
    if not obj then return nil end
    local ok,r = _pc(function() return obj:FindFirstChildOfClass(cls) end)
    return ok and r or nil
end

local function _sfd(obj, cls)
    if not obj then return nil end
    local ok,r = _pc(function() return obj:FindFirstChildWhichIsA(cls) end)
    return ok and r or nil
end

local function _refChar()
    _char = _LP.Character
    if not _char then return false end
    _hum  = _sfc(_char,"Humanoid")
    _hrp  = _sf(_char,"HumanoidRootPart")
    _anim = _hum and _sfc(_hum,"Animator")
    return _hum~=nil and _hrp~=nil
end
_refChar()

local function _safeCF()
    if not (_hrp and _hrp.Parent) then return nil end
    local ok,cf = _pc(function() return _hrp.CFrame end)
    return ok and cf or nil
end

local function _isAlive(p)
    local ok,r = _pc(function()
        local ch = p.Character
        if not ch then return false end
        local h = ch:FindFirstChildOfClass("Humanoid")
        return h and h.Health>0
    end)
    return ok and r
end

local function _getPart(p, pn)
    local ok,r = _pc(function()
        local ch = p.Character
        if not ch then return nil end
        return ch:FindFirstChild(pn or CFG.aimbotPart) or ch:FindFirstChild("HumanoidRootPart")
    end)
    return ok and r or nil
end

local function _getTarget()
    local bd,bt = _mhg, nil
    local vp = _Cam.ViewportSize
    local cx,cy = vp.X/2, vp.Y/2
    for _,p in _iprs(_Players:GetPlayers()) do
        if p~=_LP and _isAlive(p) then
            local pt = _getPart(p)
            if pt then
                local ok,sp,on = _pc(function()
                    return _Cam:WorldToViewportPoint(pt.Position)
                end)
                if ok and on then
                    local dx,dy = sp.X-cx, sp.Y-cy
                    local dist = _msq(dx*dx+dy*dy)
                    if dist<CFG.aimbotFOV and dist<bd then
                        bd,bt = dist,p
                    end
                end
            end
        end
    end
    return bt
end

-- ═══════════════════════════════════════════════
-- SAB SPECIFIC FUNCTIONS
-- ═══════════════════════════════════════════════

-- Auto collect brainrots (SAB mechanic)
local function _startAutoBrainrot()
    if _autoBrainrotConn then
        _pc(function() _autoBrainrotConn:Disconnect() end)
    end
    _autoBrainrotConn = _RS.Heartbeat:Connect(function()
        if not CFG.autoBrainrot then return end
        _pc(function()
            if not (_hrp and _hrp.Parent) then return end
            -- Scan for collectible brainrot items
            for _, obj in _iprs(workspace:GetDescendants()) do
                if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                    -- Check for proximity / collectible tags
                    local tag = obj:FindFirstChild("Collectible") or 
                                obj:FindFirstChild("Brainrot") or
                                obj:FindFirstChild("PickUp") or
                                obj:FindFirstChildOfClass("BillboardGui")
                    if tag then
                        local dist = (_hrp.Position - obj.Position).Magnitude
                        if dist < 30 then
                            -- Teleport close to collect
                            local ok = _pc(function()
                                local tpCF = CFrame.new(obj.Position + Vector3.new(0,3,0))
                                _hrp.CFrame = tpCF
                            end)
                            _tw(0.05)
                        end
                    end
                end
            end
        end)
    end)
end

local function _stopAutoBrainrot()
    if _autoBrainrotConn then
        _pc(function() _autoBrainrotConn:Disconnect() end)
        _autoBrainrotConn = nil
    end
end

-- No knockback for SAB
local _nkbConn = nil
local function _startNoKnockback()
    if _nkbConn then _pc(function() _nkbConn:Disconnect() end) end
    _nkbConn = _RS.Heartbeat:Connect(function()
        if not CFG.noKnockback then return end
        _pc(function()
            if _hrp and _hrp.Parent then
                local vel = _hrp.AssemblyLinearVelocity
                -- Only cancel horizontal knockback, preserve vertical
                if _ma(vel.X) > 35 or _ma(vel.Z) > 35 then
                    _hrp.AssemblyLinearVelocity = _v3(
                        vel.X * 0.15,
                        vel.Y,
                        vel.Z * 0.15
                    )
                end
            end
        end)
    end)
end

local function _stopNoKnockback()
    if _nkbConn then _pc(function() _nkbConn:Disconnect() end) _nkbConn = nil end
end

-- SAB Speed Boost (uses character's own velocity)
local function _startSABSpeed()
    _refChar()
    if _hum then
        _origSpd = _hum.WalkSpeed
        _hum.WalkSpeed = CFG.speedValue
        -- Also boost jump height for SAB
        _hum.JumpPower = CFG.jumpPower
    end
end

local function _stopSABSpeed()
    if _hum then
        _hum.WalkSpeed = _origSpd
        _hum.JumpPower = 50
    end
end

-- ═══════════════════════════════════════════════
-- INFINITE JUMP (STEALTH IMPROVED)
-- ═══════════════════════════════════════════════
local function _doJump()
    if not CFG.infJump then return end
    local jRoot = _hrp
    if _ghostOn and _ghostPart and _ghostPart.Parent then jRoot = _ghostPart end
    if not (jRoot and jRoot.Parent) then return end
    if _hum and _hum.Health<=0 then return end

    local now = tick()
    if now-_lastJump < CFG.jumpCooldown then return end
    _lastJump = now
    _disguise()

    local cv = jRoot.AssemblyLinearVelocity
    local ny = CFG.jumpPower + _rf(-1.5, 1.5)

    -- Stealth: randomize slightly each jump
    jRoot.AssemblyLinearVelocity = _v3(
        cv.X * _rf(0.88,0.95),
        ny,
        cv.Z * _rf(0.88,0.95)
    )

    -- Secondary boost with micro-delay
    _td(0.03+_jit(), function()
        if jRoot and jRoot.Parent and CFG.infJump then
            local v = jRoot.AssemblyLinearVelocity
            if v.Y < CFG.jumpPower*0.6 then
                jRoot.AssemblyLinearVelocity = _v3(v.X, CFG.jumpPower*_rf(0.8,0.92), v.Z)
            end
        end
    end)
end

_UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.Space then
        if not _hum then return end
        if _ghostOn then _doJump() return end
        if not _hrp then return end
        local st = _hum:GetState()
        if st==Enum.HumanoidStateType.Freefall or
           st==Enum.HumanoidStateType.Jumping or
           st==Enum.HumanoidStateType.FallingDown then
            _doJump()
        end
    end
end)

-- ═══════════════════════════════════════════════
-- ANTI-RAGDOLL v9 · GHOST ENGINE
-- ═══════════════════════════════════════════════
local _RAG_STATES = {
    [Enum.HumanoidStateType.Ragdoll]     = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics]     = true,
}
local function _isRag(st) return _RAG_STATES[st]==true end

local function _snapMotors()
    _motorSnap = {}
    if not _char then return end
    for _,v in _iprs(_char:GetDescendants()) do
        if v:IsA("Motor6D") then
            _motorSnap[#_motorSnap+1]={
                ref=v,name=v.Name,par=v.Parent,
                p0=v.Part0,p1=v.Part1,c0=v.C0,c1=v.C1
            }
        end
    end
end

local function _restMotors()
    if not _char then return end
    for _,d in _iprs(_motorSnap) do
        _pc(function()
            if d.ref and d.ref.Parent then d.ref.Enabled=true return end
            if not(d.par and d.par.Parent and d.p0 and d.p0.Parent and d.p1 and d.p1.Parent) then return end
            local ex = d.par:FindFirstChild(d.name)
            if ex and ex:IsA("Motor6D") then ex.Enabled=true d.ref=ex return end
            local m=_IN("Motor6D")
            m.Name=d.name m.Part0=d.p0 m.Part1=d.p1
            m.C0=d.c0 m.C1=d.c1 m.Parent=d.par
            d.ref=m _fabMotors[#_fabMotors+1]=m
        end)
    end
end

local function _nukeConstr()
    if not _char then return end
    local bad={BallSocketConstraint=true,HingeConstraint=true,
               NoCollisionConstraint=true,RopeConstraint=true,
               SpringConstraint=true,CylindricalConstraint=true}
    for _,v in _iprs(_char:GetDescendants()) do
        _pc(function() if bad[v.ClassName] then v:Destroy() end end)
    end
end

local function _killGhost(doTp)
    local fcf = _ghostCF
    for _,v in _prs(_ghostMvrs) do _pc(function() v:Destroy() end) end
    _ghostMvrs = {}
    if _ghostPart then _pc(function() _ghostPart:Destroy() end) _ghostPart=nil end
    _pc(function()
        if _hum then workspace.CurrentCamera.CameraSubject=_hum end
    end)
    _ghostOn = false
    if doTp and fcf and _hrp and _hrp.Parent then
        _pc(function()
            for _,v in _iprs(_char:GetDescendants()) do
                if v:IsA("BasePart") then
                    _pc(function()
                        v.AssemblyLinearVelocity=_v3z
                        v.AssemblyAngularVelocity=_v3z
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
    if not(_hrp and _hrp.Parent and _char) then return end

    local cf = _preRagCF or _hrp.CFrame
    local g = _IN("Part")
    g.Name                = _gID(10)
    g.Size                = _v3(2,2,1)
    g.Transparency        = 1
    g.CanCollide          = true
    g.CanQuery            = false
    g.CanTouch            = false
    g.Anchored            = false
    g.Massless            = false
    g.CFrame              = cf
    g.CustomPhysicalProperties = PhysicalProperties.new(0.7,0.3,0.5)
    g.Parent              = workspace

    _ghostPart = g
    _ghostCF   = cf

    local bv = _IN("BodyVelocity")
    bv.Name     = _gID(6)
    bv.MaxForce = _v3(18000,0,18000)
    bv.Velocity = _v3z
    bv.P        = 3000
    bv.Parent   = g
    _ghostMvrs.bv = bv

    local bg = _IN("BodyGyro")
    bg.Name      = _gID(6)
    bg.MaxTorque = _v3(0,18000,0)
    bg.P         = 6000
    bg.D         = 250
    bg.Parent    = g
    _ghostMvrs.bg = bg

    local bf = _IN("BodyForce")
    bf.Name  = _gID(6)
    bf.Force = _v3(0, g:GetMass()*workspace.Gravity*0.2, 0)
    bf.Parent = g
    _ghostMvrs.bf = bf

    _ghostOn = true
end

local function _ctrlGhost()
    if not (_ghostOn and _ghostPart and _ghostPart.Parent) then
        if _ghostOn then _ghostOn=false end return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local md  = _v3z
    local ccf = cam.CFrame
    local fwd = _v3(ccf.LookVector.X,0,ccf.LookVector.Z)
    if fwd.Magnitude>0.001 then fwd=fwd.Unit end
    local rgt = _v3(ccf.RightVector.X,0,ccf.RightVector.Z)
    if rgt.Magnitude>0.001 then rgt=rgt.Unit end

    if _UIS:IsKeyDown(Enum.KeyCode.W) then md=md+fwd end
    if _UIS:IsKeyDown(Enum.KeyCode.S) then md=md-fwd end
    if _UIS:IsKeyDown(Enum.KeyCode.D) then md=md+rgt end
    if _UIS:IsKeyDown(Enum.KeyCode.A) then md=md-rgt end

    local spd=16
    _pc(function() if _hum then spd=_hum.WalkSpeed end end)
    if md.Magnitude>0.01 then
        md = md.Unit*spd
        if _ghostMvrs.bg then
            _pc(function() _ghostMvrs.bg.CFrame=_cfL(_v3z,_v3(md.X,0,md.Z)) end)
        end
    end
    if _ghostMvrs.bv then _ghostMvrs.bv.Velocity=_v3(md.X,0,md.Z) end
    _pc(function() cam.CameraSubject=_ghostPart end)
    _ghostCF = _ghostPart.CFrame
end

local function _exitRag()
    if _exitLk or _exitingR then return end
    local now = tick()
    if now-_lastExit<1.5 then return end
    _exitLk   = true
    _exitingR = true
    _lastExit = now

    if not(_hum and _char and _hrp) then
        _killGhost(false) _exitingR=false _ragOn=false _exitLk=false return
    end
    if _hum.Health<=0 then
        _killGhost(false) _exitingR=false _ragOn=false _exitLk=false return
    end

    local fcf = _killGhost(true)
    _pc(function() _hum.PlatformStand=false end)
    _nukeConstr()
    _restMotors()
    for _,v in _iprs(_char:GetDescendants()) do
        if v:IsA("BasePart") then _pc(function() v.Anchored=false end) end
    end
    _pc(function() _hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)

    _td(0.1+_jit(), function()
        if not CFG.antiRagdoll then _exitingR=false _ragOn=false _exitLk=false return end
        _pc(function()
            if _hum and _hum.Health>0 then
                _hum.PlatformStand=false
                _nukeConstr() _restMotors()
                if fcf and _hrp and _hrp.Parent then
                    if (_hrp.Position-fcf.Position).Magnitude>4 then
                        for _,v in _iprs(_char:GetDescendants()) do
                            if v:IsA("BasePart") then
                                _pc(function()
                                    v.AssemblyLinearVelocity=_v3z
                                    v.AssemblyAngularVelocity=_v3z
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

    _td(0.4+_jit(), function()
        _pc(function()
            if _hum and _hum.Health>0 then
                _hum.PlatformStand=false
                local st=_hum:GetState()
                if _isRag(st) or st==Enum.HumanoidStateType.PlatformStanding then
                    _nukeConstr() _restMotors()
                    _hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    _td(0.08,function()
                        _pc(function() _hum:ChangeState(Enum.HumanoidStateType.Running) end)
                    end)
                end
                if not _ghostOn then
                    workspace.CurrentCamera.CameraSubject=_hum
                end
            end
        end)
        _exitingR=false _ragOn=false
        _td(0.8, function() _exitLk=false end)
    end)
end

local function _onRagStart()
    if _ragOn or _exitingR or _exitLk then return end
    if not(_hum and _hum.Health>0) then return end
    _preRagCF = _safeCF()
    _ragOn    = true
    _ragT     = tick()
    _td(0.03+_jit(), function()
        if not CFG.antiRagdoll then _ragOn=false return end
        if not _ragOn or _exitingR or _exitLk then _ragOn=false return end
        if _hum and _hum.Health<=0 then _ragOn=false return end
        _spawnGhost()
    end)
end

local function _chkRagEnd()
    if not _ragOn or _exitingR or _exitLk then return end
    if not(_hum and _char) then return end
    if _hum.Health<=0 then _killGhost(false) _ragOn=false return end
    if tick()-_ragT>_ragMax then _exitRag() return end
    local st=_hum:GetState()
    local ps=false
    _pc(function() ps=_hum.PlatformStand end)
    if not _isRag(st) and st~=Enum.HumanoidStateType.PlatformStanding and not ps then
        _td(0.08, function()
            if not _ragOn or _exitingR or _exitLk then return end
            if not _hum then return end
            if _hum.Health<=0 then _killGhost(false) _ragOn=false return end
            local st2=_hum:GetState()
            local ps2=false
            _pc(function() ps2=_hum.PlatformStand end)
            if not _isRag(st2) and st2~=Enum.HumanoidStateType.PlatformStanding and not ps2 then
                _exitRag()
            end
        end)
    end
end

-- Snapshot loop
_tsp(function()
    while true do
        _tw(0.18)
        _pc(function()
            if _char and _hum and _hrp and _hrp.Parent then
                if not _ragOn and not _exitingR and not _exitLk and _hum.Health>0 then
                    local st=_hum:GetState()
                    if not _isRag(st) and st~=Enum.HumanoidStateType.PlatformStanding then
                        _preRagCF=_safeCF()
                    end
                end
            end
        end)
    end
end)

local function _startAntiRag()
    if not(_char and _hum) then return end
    _snapMotors()
    local c1=_hum.StateChanged:Connect(function(_,ns)
        if not CFG.antiRagdoll or _exitLk then return end
        if _isRag(ns) or ns==Enum.HumanoidStateType.PlatformStanding then
            _td(_jit(),_onRagStart)
        end
    end)
    _ragConns[#_ragConns+1]=c1
    local c2=_hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not CFG.antiRagdoll or _exitLk then return end
        if _hum.PlatformStand and not _ragOn then _td(_jit(),_onRagStart) end
    end)
    _ragConns[#_ragConns+1]=c2
    local c3=_char.DescendantAdded:Connect(function(v)
        if not CFG.antiRagdoll or _exitLk then return end
        _td(_jit(),function()
            _pc(function()
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("NoCollisionConstraint") then
                    if not _ragOn and not _exitingR and not _exitLk then _onRagStart() end
                end
            end)
        end)
    end)
    _ragConns[#_ragConns+1]=c3
    local c4=_char.DescendantRemoving:Connect(function(v)
        if not CFG.antiRagdoll or _exitLk then return end
        if v:IsA("Motor6D") then
            local data={name=v.Name,par=v.Parent,p0=v.Part0,p1=v.Part1,c0=v.C0,c1=v.C1}
            local found=false
            for _,s in _iprs(_motorSnap) do
                if s.name==data.name and s.par==data.par then
                    s.c0=data.c0 s.c1=data.c1 found=true break
                end
            end
            if not found then _motorSnap[#_motorSnap+1]=data end
            if not _ragOn and not _exitingR and not _exitLk then _onRagStart() end
        end
    end)
    _ragConns[#_ragConns+1]=c4
end

local function _stopAntiRag()
    for _,c in _iprs(_ragConns) do _pc(function() c:Disconnect() end) end
    _ragConns={}
    _killGhost(false)
    _ragOn=false _exitingR=false _exitLk=false
    for _,m in _iprs(_fabMotors) do
        _pc(function() if m and m.Parent then m:Destroy() end end)
    end
    _fabMotors={} _motorSnap={}
end

-- ═══════════════════════════════════════════════
-- NO ANIMATIONS
-- ═══════════════════════════════════════════════
local function _hookTrack(t)
    if not t or _trackedA[t] then return end
    _trackedA[t]=true
    local c=t:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if not CFG.noAnim then return end
        if t.IsPlaying then
            _td(_jit(),function()
                _pc(function() t:AdjustSpeed(0) t:AdjustWeight(0,0) end)
            end)
        end
    end)
    _animConns[#_animConns+1]=c
    if CFG.noAnim and t.IsPlaying then
        _pc(function() t:AdjustSpeed(0) t:AdjustWeight(0,0) end)
    end
end

local function _stopTracks()
    if not _anim then return end
    _pc(function()
        for _,t in _iprs(_anim:GetPlayingAnimationTracks()) do
            _pc(function() t:AdjustSpeed(0) t:AdjustWeight(0,0) end)
        end
    end)
end

local function _startNoAnim()
    if not _anim then return end
    _pc(function()
        local c=_anim.AnimationPlayed:Connect(function(t)
            _hookTrack(t)
            if CFG.noAnim then
                _td(_jit(),function()
                    _pc(function() t:AdjustSpeed(0) t:AdjustWeight(0,0) end)
                end)
            end
        end)
        _animConns[#_animConns+1]=c
    end)
    if _hum then
        for _,ev in _iprs({"Running","Jumping","Climbing","Swimming","FreeFalling"}) do
            _pc(function()
                local c=_hum[ev]:Connect(function()
                    if CFG.noAnim then _tdf(_stopTracks) end
                end)
                _animConns[#_animConns+1]=c
            end)
        end
        local c=_hum.StateChanged:Connect(function()
            if CFG.noAnim then _tdf(_stopTracks) end
        end)
        _animConns[#_animConns+1]=c
    end
    _pc(function()
        for _,t in _iprs(_anim:GetPlayingAnimationTracks()) do _hookTrack(t) end
    end)
end

local function _stopNoAnim()
    for _,c in _iprs(_animConns) do _pc(function() c:Disconnect() end) end
    _animConns={}
    for t in _prs(_trackedA) do
        _pc(function()
            if t and t.IsPlaying then t:AdjustSpeed(1) t:AdjustWeight(1,0.1) end
        end)
    end
    _trackedA={}
end

-- ═══════════════════════════════════════════════
-- FLY
-- ═══════════════════════════════════════════════
local function _startFly()
    _refChar()
    if not(_hrp and _hum) then return end
    _flyOn=true
    if _flyBV then _pc(function() _flyBV:Destroy() end) end
    if _flyBG then _pc(function() _flyBG:Destroy() end) end
    _flyBV=_IN("BodyVelocity")
    _flyBV.Name=_gID(6) _flyBV.MaxForce=_v3(1e5,1e5,1e5)
    _flyBV.Velocity=_v3z _flyBV.P=9000 _flyBV.Parent=_hrp
    _flyBG=_IN("BodyGyro")
    _flyBG.Name=_gID(6) _flyBG.MaxTorque=_v3(1e5,1e5,1e5)
    _flyBG.P=9000 _flyBG.D=500 _flyBG.Parent=_hrp
end

local function _ctrlFly()
    if not _flyOn then return end
    if not(_flyBV and _flyBV.Parent and _flyBG and _flyBG.Parent) then return end
    if not(_hrp and _hrp.Parent) then return end
    local ccf=workspace.CurrentCamera.CFrame
    local md=_v3z
    if _UIS:IsKeyDown(Enum.KeyCode.W)           then md=md+ccf.LookVector end
    if _UIS:IsKeyDown(Enum.KeyCode.S)           then md=md-ccf.LookVector end
    if _UIS:IsKeyDown(Enum.KeyCode.A)           then md=md-ccf.RightVector end
    if _UIS:IsKeyDown(Enum.KeyCode.D)           then md=md+ccf.RightVector end
    if _UIS:IsKeyDown(Enum.KeyCode.Space)       then md=md+_v3(0,1,0) end
    if _UIS:IsKeyDown(Enum.KeyCode.LeftControl) then md=md-_v3(0,1,0) end
    if md.Magnitude>0.01 then md=md.Unit*CFG.flySpeed end
    _flyBV.Velocity=md _flyBG.CFrame=ccf
end

local function _stopFly()
    _flyOn=false
    if _flyBV then _pc(function() _flyBV:Destroy() end) _flyBV=nil end
    if _flyBG then _pc(function() _flyBG:Destroy() end) _flyBG=nil end
end

-- ═══════════════════════════════════════════════
-- NOCLIP
-- ═══════════════════════════════════════════════
local function _startNoclip()
    if _noclipC then _pc(function() _noclipC:Disconnect() end) end
    _noclipC=_RS.Stepped:Connect(function()
        if not CFG.noclip then return end
        _pc(function()
            if _char then
                for _,v in _iprs(_char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide=false end
                end
            end
        end)
    end)
end

local function _stopNoclip()
    if _noclipC then _pc(function() _noclipC:Disconnect() end) _noclipC=nil end
    _pc(function()
        if _char then
            for _,v in _iprs(_char:GetDescendants()) do
                if v:IsA("BasePart") and v.Name~="HumanoidRootPart" then
                    v.CanCollide=true
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════
-- GOD MODE
-- ═══════════════════════════════════════════════
local function _startGod()
    _refChar()
    if not _hum then return end
    if _godC then _pc(function() _godC:Disconnect() end) end
    _godC=_hum:GetPropertyChangedSignal("Health"):Connect(function()
        if CFG.godMode and _hum then
            _pc(function() _hum.Health=_hum.MaxHealth end)
        end
    end)
    _pc(function() _hum.Health=_hum.MaxHealth end)
end

local function _stopGod()
    if _godC then _pc(function() _godC:Disconnect() end) _godC=nil end
end

-- ═══════════════════════════════════════════════
-- HITBOX EXPAND
-- ═══════════════════════════════════════════════
local function _expandHB()
    _hitPrts={}
    for _,p in _iprs(_Players:GetPlayers()) do
        if p~=_LP then
            _pc(function()
                local ch=p.Character
                if not ch then return end
                local head=ch:FindFirstChild("Head")
                if head then
                    local orig=head.Size
                    head.Size=_v3(CFG.hitboxSize,CFG.hitboxSize,CFG.hitboxSize)
                    _hitPrts[#_hitPrts+1]={part=head,origSize=orig}
                end
            end)
        end
    end
end

local function _restoreHB()
    for _,d in _iprs(_hitPrts) do
        _pc(function()
            if d.part and d.part.Parent then d.part.Size=d.origSize end
        end)
    end
    _hitPrts={}
end

-- ═══════════════════════════════════════════════
-- ESP (IMPROVED)
-- ═══════════════════════════════════════════════
local function _makeESP(player)
    if player==_LP then return end
    local function build()
        _pc(function()
            local ch=player.Character
            if not ch then return end
            if _espObj[player] then
                for _,o in _iprs(_espObj[player]) do _pc(function() o:Destroy() end) end
            end
            _espObj[player]={}

            local hl=_IN("Highlight")
            hl.Name=_gID(5)
            hl.FillColor=_c3(255,60,60)
            hl.FillTransparency=0.65
            hl.OutlineColor=_c3(255,255,255)
            hl.OutlineTransparency=0.1
            hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee=ch hl.Parent=ch

            local bbg=_IN("BillboardGui")
            bbg.Name=_gID(5)
            bbg.Size=_ud2(0,140,0,44)
            bbg.StudsOffset=_v3(0,4.5,0)
            bbg.AlwaysOnTop=true
            bbg.Adornee=ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
            bbg.Parent=ch

            local nl=_IN("TextLabel")
            nl.Size=_ud2(1,0,0.55,0) nl.BackgroundTransparency=1
            nl.Text=player.DisplayName nl.TextColor3=_c3(255,255,255)
            nl.TextStrokeTransparency=0.2 nl.TextSize=13
            nl.Font=Enum.Font.GothamBold nl.Parent=bbg

            local dl=_IN("TextLabel")
            dl.Size=_ud2(1,0,0.3,0) dl.Position=_ud2(0,0,0.55,0)
            dl.BackgroundTransparency=1 dl.Text=""
            dl.TextColor3=_c3(200,200,200) dl.TextSize=10
            dl.Font=Enum.Font.Gotham dl.Parent=bbg

            local hpBG=_IN("Frame")
            hpBG.Size=_ud2(0.7,0,0,4) hpBG.Position=_ud2(0.15,0,1,3)
            hpBG.BackgroundColor3=_c3(20,20,20) hpBG.BorderSizePixel=0 hpBG.Parent=bbg
            local uc=_IN("UICorner") uc.CornerRadius=_ud(0,2) uc.Parent=hpBG
            local hf=_IN("Frame")
            hf.Size=_ud2(1,0,1,0) hf.BackgroundColor3=_c3(50,255,100)
            hf.BorderSizePixel=0 hf.Parent=hpBG
            local uc2=_IN("UICorner") uc2.CornerRadius=_ud(0,2) uc2.Parent=hf

            _espObj[player]={hl,bbg}

            _tsp(function()
                while CFG.esp and bbg and bbg.Parent and ch and ch.Parent do
                    _pc(function()
                        if _hrp and _hrp.Parent then
                            local hrp2=ch:FindFirstChild("HumanoidRootPart")
                            if hrp2 then
                                dl.Text=_mf(((_hrp.Position-hrp2.Position).Magnitude)).." studs"
                            end
                        end
                        local h2=ch:FindFirstChildOfClass("Humanoid")
                        if h2 then
                            local r=_mclp(h2.Health/h2.MaxHealth,0,1)
                            hf.Size=_ud2(r,0,1,0)
                            hf.BackgroundColor3=r>0.6 and _c3(50,255,100)
                                or r>0.3 and _c3(255,200,50) or _c3(255,50,50)
                        end
                        hl.OutlineColor=(_aimTgt==player) and _c3(255,50,50) or _c3(255,255,255)
                    end)
                    _tw(0.1)
                end
            end)
        end)
    end
    if player.Character then build() end
    local c=player.CharacterAdded:Connect(function()
        _tw(0.5) if CFG.esp then build() end
    end)
    _modC[#_modC+1]=c
end

local function _startESP()
    for _,p in _iprs(_Players:GetPlayers()) do _makeESP(p) end
    local c=_Players.PlayerAdded:Connect(function(p)
        if CFG.esp then _makeESP(p) end
    end)
    _modC[#_modC+1]=c
end

local function _stopESP()
    for _,objs in _prs(_espObj) do
        for _,o in _iprs(objs) do _pc(function() o:Destroy() end) end
    end
    _espObj={}
end

-- ═══════════════════════════════════════════════
-- CHAMS
-- ═══════════════════════════════════════════════
local function _startChams()
    _tsp(function()
        while CFG.chams do
            for _,p in _iprs(_Players:GetPlayers()) do
                if p~=_LP then
                    _pc(function()
                        local ch=p.Character
                        if ch and not _chamObj[p] then
                            local hl=_IN("Highlight")
                            hl.Name=_gID(5)
                            hl.FillColor=_c3h(0,0.8,1)
                            hl.FillTransparency=0.28
                            hl.OutlineColor=_c3(255,255,255)
                            hl.OutlineTransparency=0
                            hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                            hl.Adornee=ch hl.Parent=ch
                            _chamObj[p]=hl
                        end
                    end)
                end
            end
            _tw(0.45)
        end
    end)
end

local function _stopChams()
    for _,hl in _prs(_chamObj) do
        _pc(function() if hl and hl.Parent then hl:Destroy() end end)
    end
    _chamObj={}
end

-- ═══════════════════════════════════════════════
-- TRACERS
-- ═══════════════════════════════════════════════
local function _startTracers(sg)
    if _tracerF then _pc(function() _tracerF:Destroy() end) end
    _tracerF=_IN("Frame")
    _tracerF.Name=_gID(8)
    _tracerF.Size=_ud2(1,0,1,0)
    _tracerF.BackgroundTransparency=1
    _tracerF.ZIndex=1
    _tracerF.Parent=sg

    _tsp(function()
        while CFG.tracers and _tracerF and _tracerF.Parent do
            for _,v in _iprs(_tracerF:GetChildren()) do _pc(function() v:Destroy() end) end
            local vp=_Cam.ViewportSize
            local sx,sy=vp.X/2,vp.Y
            for _,p in _iprs(_Players:GetPlayers()) do
                if p~=_LP and _isAlive(p) then
                    _pc(function()
                        local pt=_getPart(p)
                        if not(pt and pt.Parent) then return end
                        local sp,on=_Cam:WorldToViewportPoint(pt.Position)
                        if not on then return end
                        local dx,dy=sp.X-sx,sp.Y-sy
                        local len=_msq(dx*dx+dy*dy)
                        local ang=math.deg(_mat(dy,dx))
                        local ln=_IN("Frame")
                        ln.Size=_ud2(0,len,0,1.5)
                        ln.Position=_ud2(0,sx,0,sy)
                        ln.AnchorPoint=Vector2.new(0,0.5)
                        ln.BackgroundColor3=(_aimTgt==p) and _c3(255,50,50) or _c3(255,210,50)
                        ln.BackgroundTransparency=0.2
                        ln.BorderSizePixel=0
                        ln.Rotation=ang ln.ZIndex=2 ln.Parent=_tracerF
                    end)
                end
            end
            _tw(0.03)
        end
        _pc(function() if _tracerF then _tracerF:Destroy() end end)
        _tracerF=nil
    end)
end

local function _stopTracers()
    if _tracerF then _pc(function() _tracerF:Destroy() end) _tracerF=nil end
end

-- ═══════════════════════════════════════════════
-- VISUAL MODS
-- ═══════════════════════════════════════════════
local function _startFB()
    _pc(function()
        _origAmb=_Lighting.Ambient _origBri=_Lighting.Brightness
        _Lighting.Ambient=_c3(255,255,255) _Lighting.Brightness=2
    end)
end
local function _stopFB()
    _pc(function()
        if _origAmb then _Lighting.Ambient=_origAmb end
        if _origBri then _Lighting.Brightness=_origBri end
    end)
end

local function _startNoFog()
    _pc(function()
        _origFogE=_Lighting.FogEnd _origFogS=_Lighting.FogStart
        _Lighting.FogEnd=1e10 _Lighting.FogStart=1e10
    end)
end
local function _stopNoFog()
    _pc(function()
        if _origFogE then _Lighting.FogEnd=_origFogE end
        if _origFogS then _Lighting.FogStart=_origFogS end
    end)
end

local function _startLowG()
    _origGrav=workspace.Gravity workspace.Gravity=42
end
local function _stopLowG()
    workspace.Gravity=_origGrav
end

-- Big Head
local function _startBigHead()
    _tsp(function()
        while CFG.bigHead do
            for _,p in _iprs(_Players:GetPlayers()) do
                if p~=_LP then
                    _pc(function()
                        local ch=p.Character
                        if ch then
                            local head=ch:FindFirstChild("Head")
                            if head then head.Size=_v3(CFG.hitboxSize+2,CFG.hitboxSize+2,CFG.hitboxSize+2) end
                        end
                    end)
                end
            end
            _tw(0.45)
        end
        for _,p in _iprs(_Players:GetPlayers()) do
            if p~=_LP then
                _pc(function()
                    local ch=p.Character
                    if ch then
                        local head=ch:FindFirstChild("Head")
                        if head then head.Size=_v3(2,1,1) end
                    end
                end)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════
-- AIMBOT (IMPROVED FOV + SMOOTH)
-- ═══════════════════════════════════════════════
local function _stepAim()
    if not(CFG.aimbot or CFG.silentAim) then return end
    if not _aimTgt or not _isAlive(_aimTgt) then _aimTgt=nil _aimLock=false end

    if CFG.aimbot and _UIS:IsKeyDown(CFG.aimbotKey) then
        if not _aimTgt then
            _aimTgt=_getTarget() _aimLock=_aimTgt~=nil
        end
        if _aimTgt then
            local pt=_getPart(_aimTgt)
            if pt and pt.Parent then
                local ccf=_Cam.CFrame
                local tcf=_cfL(ccf.Position,pt.Position)
                local sm=_mclp(CFG.aimbotSmooth+_rf(-0.003,0.003),0.01,1)
                _pc(function() _Cam.CFrame=ccf:Lerp(tcf,sm) end)
            else
                _aimTgt=nil _aimLock=false
            end
        end
    elseif not _UIS:IsKeyDown(CFG.aimbotKey) then
        if CFG.aimbot then _aimTgt=nil _aimLock=false end
    end

    if CFG.silentAim and not _aimLock then
        _aimTgt=_getTarget()
    end
end

local function _drawFOV(sg)
    if _aimFOVG then _pc(function() _aimFOVG:Destroy() end) _aimFOVG=nil end
    local ff=_IN("Frame")
    ff.Name=_gID(5)
    ff.Size=_ud2(0,CFG.aimbotFOV*2,0,CFG.aimbotFOV*2)
    ff.AnchorPoint=Vector2.new(0.5,0.5)
    ff.Position=_ud2(0.5,0,0.5,0)
    ff.BackgroundTransparency=1
    ff.BorderSizePixel=0
    ff.ZIndex=1 ff.Parent=sg

    local fs=_IN("UIStroke")
    fs.Color=_c3(255,50,50) fs.Thickness=1.2
    fs.Transparency=0.3
    fs.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    fs.Parent=ff

    local fc=_IN("UICorner")
    fc.CornerRadius=_ud(0,CFG.aimbotFOV)
    fc.Parent=ff
    _aimFOVG=ff

    _tsp(function()
        while ff and ff.Parent and (CFG.aimbot or CFG.silentAim) do
            local locked=_aimLock and _aimTgt~=nil
            fs.Color=locked and _c3(255,50,50) or _c3(180,180,255)
            fs.Transparency=locked and 0.05 or 0.4
            _tw(0.04)
        end
        _pc(function() ff:Destroy() end) _aimFOVG=nil
    end)
end

-- ═══════════════════════════════════════════════
-- MASTER HEARTBEAT (STEALTH THROTTLED)
-- ═══════════════════════════════════════════════
local _hbConn
local _hbSkip = 0

_hbConn = _RS.Heartbeat:Connect(function(dt)
    _fc = _fc + 1
    _hbSkip = _hbSkip + 1

    -- Throttle non-critical checks
    if not(_char and _char.Parent) then
        if _fc%8==0 then _refChar() end return
    end
    if not(_hum and _hum.Health>0) then
        if _ghostOn then _killGhost(false) _ragOn=false end return
    end

    -- Anti-ragdoll
    if CFG.antiRagdoll then
        if _ghostOn then _ctrlGhost() end
        if _fc%4==0 then
            _chkRagEnd()
            if _ragOn and not _exitingR and not _exitLk and not(_ghostPart and _ghostPart.Parent) then
                _ghostOn=false
                local st=_hum:GetState()
                local ps=false
                _pc(function() ps=_hum.PlatformStand end)
                if _isRag(st) or st==Enum.HumanoidStateType.PlatformStanding or ps then
                    _spawnGhost()
                else
                    _ragOn=false
                end
            end
        end
    end

    -- Fly
    if CFG.fly then _ctrlFly() end

    -- Speed keepalive (throttled)
    if CFG.speed and _hum and _fc%18==0 then
        _pc(function() _hum.WalkSpeed=CFG.speedValue end)
    end

    -- No anim
    if CFG.noAnim and _fc%4==0 then _stopTracks() end

    -- Aimbot (every 2nd frame)
    if _fc%2==0 then _stepAim() end

    -- Hitbox (throttled)
    if CFG.hitboxExp and _fc%28==0 then _expandHB() end

    -- Chams color cycle
    if CFG.chams and _fc%12==0 then
        local h=(_fc*0.003)%1
        for _,hl in _prs(_chamObj) do
            _pc(function() hl.FillColor=_c3h(h,0.82,1) end)
        end
    end

    -- Disguise calls (anti-detection)
    if _fc%60==0 then _disguise() end
end)

-- ═══════════════════════════════════════════════
-- RESPAWN HANDLER
-- ═══════════════════════════════════════════════
_LP.CharacterAdded:Connect(function()
    _tw(_rf(0.3,0.55))
    _killGhost(false)
    _ragOn=false _exitingR=false _exitLk=false _preRagCF=nil
    _stopFly()
    _refChar()
    _tw(_rf(0.1,0.2))
    if CFG.antiRagdoll then _stopAntiRag() _startAntiRag() end
    if CFG.noAnim      then _stopNoAnim()  _tw(0.1) _startNoAnim() end
    if CFG.speed       then _startSABSpeed() end
    if CFG.fly         then _startFly() end
    if CFG.noclip      then _startNoclip() end
    if CFG.godMode     then _startGod() end
    if CFG.hitboxExp   then _expandHB() end
    if CFG.noKnockback then _startNoKnockback() end
end)

-- ══════════════════════════════════════════════════════════
-- ═══════════════════ GUI v19.0 ════════════════════════════
-- ══════════════════════════════════════════════════════════

-- Cleanup old instances
for _,g in _iprs(_PG:GetChildren()) do
    _pc(function()
        if g:IsA("ScreenGui") and g:GetAttribute("_GH19") then g:Destroy() end
    end)
end

local SG=_IN("ScreenGui")
SG.Name=_gID(16)
SG:SetAttribute("_GH19",true)
SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.DisplayOrder=15
SG.IgnoreGuiInset=false
SG.Parent=_PG

-- ═══ PALETTE ═══
local P={
    bg     =_c3(5,5,14),
    bgCard =_c3(9,9,24),
    bgDeep =_c3(3,3,10),
    header =_c3(7,7,20),
    acc1   =_c3(140,85,255),
    acc2   =_c3(45,200,255),
    acc3   =_c3(255,50,90),
    acc4   =_c3(255,200,55),
    acc5   =_c3(55,255,155),
    acc6   =_c3(255,115,225),
    acc7   =_c3(255,135,50),
    acc8   =_c3(105,215,255),
    textW  =_c3(242,242,255),
    textD  =_c3(58,58,88),
    textG  =_c3(55,255,130),
    tOff   =_c3(16,16,32),
    tKnob  =_c3(78,78,105),
    bord   =_c3(24,24,46),
}

-- ═══ GUI HELPERS ═══
local function _corner(p,r)
    local c=_IN("UICorner") c.CornerRadius=_ud(0,r or 12) c.Parent=p return c
end
local function _stroke(p,col,thick,tr)
    local s=_IN("UIStroke") s.Color=col or P.bord s.Thickness=thick or 1
    s.Transparency=tr or 0.5 s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    s.Parent=p return s
end
local function _ti(d,st,sd)
    return TweenInfo.new(d or 0.3,st or Enum.EasingStyle.Quint,sd or Enum.EasingDirection.Out)
end
local function _tw2(o,i,pr) return _TS:Create(o,i,pr) end
local function _grad(p,cols,rot,tr)
    local g=_IN("UIGradient") g.Color=cols
    if rot then g.Rotation=rot end if tr then g.Transparency=tr end
    g.Parent=p return g
end

-- Drag
local function _drag(frame,handle)
    local dragging,dragStart,startPos=false
    handle=handle or frame
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or
           inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true dragStart=inp.Position startPos=frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    _UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or
                         inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-dragStart
            _tw2(frame,_ti(0.04,Enum.EasingStyle.Quad),{
                Position=_ud2(startPos.X.Scale,startPos.X.Offset+d.X,
                              startPos.Y.Scale,startPos.Y.Offset+d.Y)
            }):Play()
        end
    end)
end

-- ═══ MAIN FRAME ═══
local MF=_IN("Frame")
MF.Name=_gID(5)
MF.Size=_ud2(0,470,0,680)
MF.Position=_ud2(0.5,-235,0.5,-340)
MF.BackgroundColor3=P.bg
MF.BackgroundTransparency=0.01
MF.BorderSizePixel=0
MF.Active=true
MF.ClipsDescendants=true
MF.Parent=SG
_corner(MF,22)
local _mStroke=_stroke(MF,P.acc1,1.5,0.5)

-- Aurora orbs
local _orbs={}
local _orbDat={
    {_ud2(0,-110,0,-110),P.acc1,320,0.91},
    {_ud2(1,-150,1,-180),P.acc2,290,0.91},
    {_ud2(0.06,0,0.2,0),P.acc6,210,0.93},
    {_ud2(0.88,0,0.04,0),P.acc5,180,0.93},
    {_ud2(0.4,-95,0.52,0),P.acc3,230,0.91},
    {_ud2(0,0,0.86,0),P.acc4,150,0.94},
    {_ud2(0.65,0,0.08,0),P.acc1,130,0.95},
    {_ud2(0.2,0,0.93,0),P.acc2,120,0.95},
}
for i,od in _iprs(_orbDat) do
    local o=_IN("Frame")
    o.Name=_gID(3) o.Size=_ud2(0,od[3],0,od[3])
    o.Position=od[1] o.BackgroundColor3=od[2]
    o.BackgroundTransparency=od[4] o.BorderSizePixel=0
    o.ZIndex=0 o.Parent=MF
    _corner(o,_mf(od[3]/2))
    _orbs[i]=o
end

-- ═══ HEADER ═══
local HD=_IN("Frame")
HD.Name=_gID(4) HD.Size=_ud2(1,0,0,82)
HD.BackgroundColor3=P.header HD.BackgroundTransparency=0.02
HD.BorderSizePixel=0 HD.ZIndex=5 HD.Parent=MF
_corner(HD,22)

local HDPatch=_IN("Frame")
HDPatch.Size=_ud2(1,0,0,28) HDPatch.Position=_ud2(0,0,1,-28)
HDPatch.BackgroundColor3=P.header HDPatch.BackgroundTransparency=0.02
HDPatch.BorderSizePixel=0 HDPatch.ZIndex=5 HDPatch.Parent=HD

_drag(MF,HD)

-- Separator
local sep=_IN("Frame")
sep.Size=_ud2(0.96,0,0,2.5) sep.Position=_ud2(0.02,0,1,0)
sep.BackgroundColor3=P.textW sep.BackgroundTransparency=0.05
sep.BorderSizePixel=0 sep.ZIndex=6 sep.Parent=HD
_corner(sep,2)
local sepG=_grad(sep,ColorSequence.new{
    ColorSequenceKeypoint.new(0,P.acc1),ColorSequenceKeypoint.new(0.14,P.acc2),
    ColorSequenceKeypoint.new(0.33,P.acc5),ColorSequenceKeypoint.new(0.52,P.acc4),
    ColorSequenceKeypoint.new(0.72,P.acc6),ColorSequenceKeypoint.new(0.88,P.acc3),
    ColorSequenceKeypoint.new(1,P.acc1),
})
sepG.Transparency=NumberSequence.new{
    NumberSequenceKeypoint.new(0,0.9),NumberSequenceKeypoint.new(0.07,0),
    NumberSequenceKeypoint.new(0.93,0),NumberSequenceKeypoint.new(1,0.9),
}

_tsp(function()
    local off=0
    while SG and SG.Parent do
        off=(off+0.0008)%1
        _pc(function() sepG.Offset=Vector2.new(_ms(off*_mpi*2)*0.32,0) end)
        _tw(0.02)
    end
end)

-- Logo
local logoCont=_IN("Frame")
logoCont.Size=_ud2(0,62,0,62) logoCont.Position=_ud2(0,13,0.5,-31)
logoCont.BackgroundTransparency=1 logoCont.ZIndex=6 logoCont.Parent=HD

local rings,rDat={},{{62,0.74,23},{50,0.78,17},{40,0.82,13}}
for i,rd in _iprs(rDat) do
    local r=_IN("Frame")
    r.Size=_ud2(0,rd[1],0,rd[1]) r.AnchorPoint=Vector2.new(0.5,0.5)
    r.Position=_ud2(0.5,0,0.5,0) r.BackgroundColor3=P.acc1
    r.BackgroundTransparency=rd[2] r.BorderSizePixel=0
    r.ZIndex=6+i r.Parent=logoCont
    _corner(r,_mf(rd[1]/2))
    if i<3 then _stroke(r,P.acc1,0.6,0.4+i*0.1) end
    rings[i]=r
end

local logoGlow=_IN("Frame")
logoGlow.Size=_ud2(0,26,0,26) logoGlow.AnchorPoint=Vector2.new(0.5,0.5)
logoGlow.Position=_ud2(0.5,0,0.5,0) logoGlow.BackgroundColor3=P.acc1
logoGlow.BackgroundTransparency=0.28 logoGlow.ZIndex=10 logoGlow.Parent=logoCont
_corner(logoGlow,13)

local logoT=_IN("TextLabel")
logoT.Size=_ud2(1,0,1,0) logoT.BackgroundTransparency=1
logoT.Text="G" logoT.TextColor3=P.textW
logoT.TextSize=17 logoT.Font=Enum.Font.GothamBlack
logoT.ZIndex=11 logoT.Parent=rings[3]

-- Title
local titleL=_IN("TextLabel")
titleL.Size=_ud2(0,240,0,28) titleL.Position=_ud2(0,86,0,8)
titleL.BackgroundTransparency=1 titleL.RichText=true
titleL.Text='<font color="#8C55FF">GRANZ</font> <font color="#FFFFFF">HUB</font>'
titleL.TextSize=22 titleL.Font=Enum.Font.GothamBlack
titleL.TextXAlignment=Enum.TextXAlignment.Left titleL.ZIndex=6 titleL.Parent=HD

local subL=_IN("TextLabel")
subL.Size=_ud2(0,310,0,14) subL.Position=_ud2(0,86,0,38)
subL.BackgroundTransparency=1 subL.Text="terminator · v19.0 · steal a brainrot edition"
subL.TextColor3=P.textD subL.TextSize=9 subL.Font=Enum.Font.GothamMedium
subL.TextXAlignment=Enum.TextXAlignment.Left subL.ZIndex=6 subL.Parent=HD

-- Badges
local bdDat={{"TERMINATOR",P.acc1},{"v19",P.acc5},{"SAB",P.acc3},{"18 MODS",P.acc4}}
local bxO=86
for _,bd in _iprs(bdDat) do
    local bf=_IN("Frame")
    bf.Size=_ud2(0,#bd[1]*5.2+16,0,17) bf.Position=_ud2(0,bxO,0,57)
    bf.BackgroundColor3=bd[2] bf.BackgroundTransparency=0.87
    bf.BorderSizePixel=0 bf.ZIndex=6 bf.Parent=HD
    _corner(bf,6) _stroke(bf,bd[2],0.5,0.55)
    local bl=_IN("TextLabel")
    bl.Size=_ud2(1,0,1,0) bl.BackgroundTransparency=1
    bl.Text=bd[1] bl.TextColor3=bd[2]
    bl.TextSize=6.5 bl.Font=Enum.Font.GothamBlack
    bl.ZIndex=7 bl.Parent=bf
    bxO=bxO+#bd[1]*5.2+20
end

-- Header buttons
local function _hdrBtn(pos,txt,col)
    local b=_IN("TextButton")
    b.Size=_ud2(0,36,0,36) b.Position=pos
    b.BackgroundColor3=col b.BackgroundTransparency=0.52
    b.Text=txt b.TextColor3=P.textW b.TextSize=13
    b.Font=Enum.Font.GothamBold b.BorderSizePixel=0
    b.AutoButtonColor=false b.ZIndex=6 b.Parent=HD
    _corner(b,11)
    b.MouseEnter:Connect(function() _tw2(b,_ti(0.18),{BackgroundTransparency=0.1}):Play() end)
    b.MouseLeave:Connect(function() _tw2(b,_ti(0.18),{BackgroundTransparency=0.52}):Play() end)
    return b
end
local MinBtn=_hdrBtn(_ud2(1,-88,0,23),"━",_c3(32,32,52))
local ClsBtn=_hdrBtn(_ud2(1,-48,0,23),"✕",_c3(145,22,38))

-- ═══ TABS ═══
local curTab="combat"
local tabBtns,tabContent={},{}

local tabBar=_IN("Frame")
tabBar.Name=_gID(4) tabBar.Size=_ud2(1,-14,0,36)
tabBar.Position=_ud2(0,7,0,86) tabBar.BackgroundColor3=P.bgDeep
tabBar.BackgroundTransparency=0.22 tabBar.BorderSizePixel=0
tabBar.ZIndex=4 tabBar.Parent=MF
_corner(tabBar,11)

local tLL=_IN("UIListLayout")
tLL.FillDirection=Enum.FillDirection.Horizontal tLL.Padding=_ud(0,3)
tLL.HorizontalAlignment=Enum.HorizontalAlignment.Center
tLL.VerticalAlignment=Enum.VerticalAlignment.Center tLL.Parent=tabBar

local tLP=_IN("UIPadding")
tLP.PaddingLeft=_ud(0,3) tLP.PaddingRight=_ud(0,3) tLP.Parent=tabBar

local TABS={
    {id="combat",   icon="🎯",name="Combat",  col=P.acc3},
    {id="movement", icon="🏃",name="Move",    col=P.acc1},
    {id="visual",   icon="👁️",name="Visual",  col=P.acc2},
    {id="world",    icon="🌍",name="World",   col=P.acc5},
    {id="aimbot",   icon="🤖",name="Aimbot",  col=P.acc7},
    {id="sab",      icon="🧠",name="SAB",     col=P.acc6},
}

local contentF=_IN("Frame")
contentF.Size=_ud2(1,-14,1,-152) contentF.Position=_ud2(0,7,0,126)
contentF.BackgroundTransparency=1 contentF.ZIndex=3 contentF.Parent=MF

for _,td in _iprs(TABS) do
    local sc=_IN("ScrollingFrame")
    sc.Name=td.id sc.Size=_ud2(1,0,1,0)
    sc.BackgroundTransparency=1 sc.BorderSizePixel=0
    sc.ScrollBarThickness=3 sc.ScrollBarImageColor3=td.col
    sc.ScrollBarImageTransparency=0.42 sc.CanvasSize=_ud2(0,0,0,0)
    sc.AutomaticCanvasSize=Enum.AutomaticSize.Y
    sc.Visible=(td.id=="combat") sc.ZIndex=3 sc.Parent=contentF

    local ll=_IN("UIListLayout")
    ll.Padding=_ud(0,7) ll.SortOrder=Enum.SortOrder.LayoutOrder ll.Parent=sc

    local lp=_IN("UIPadding")
    lp.PaddingTop=_ud(0,3) lp.PaddingBottom=_ud(0,14)
    lp.PaddingLeft=_ud(0,2) lp.PaddingRight=_ud(0,2) lp.Parent=sc

    tabContent[td.id]=sc
end

local function _switchTab(id)
    curTab=id
    for tid,btn in _prs(tabBtns) do
        local td2
        for _,t in _iprs(TABS) do if t.id==tid then td2=t break end end
        if not td2 then continue end
        if tid==id then
            _tw2(btn,_ti(0.28),{BackgroundColor3=td2.col,BackgroundTransparency=0.1}):Play()
            for _,ch in _iprs(btn:GetChildren()) do
                if ch:IsA("TextLabel") then _tw2(ch,_ti(0.28),{TextColor3=_c3(255,255,255)}):Play() end
            end
        else
            _tw2(btn,_ti(0.28),{BackgroundColor3=P.bgDeep,BackgroundTransparency=0.55}):Play()
            for _,ch in _iprs(btn:GetChildren()) do
                if ch:IsA("TextLabel") then _tw2(ch,_ti(0.28),{TextColor3=P.textD}):Play() end
            end
        end
    end
    for tid,ct in _prs(tabContent) do ct.Visible=(tid==id) end
end

for _,td in _iprs(TABS) do
    local btn=_IN("TextButton")
    btn.Name=td.id btn.Size=_ud2(0,70,0,28)
    btn.BackgroundColor3=P.bgDeep btn.BackgroundTransparency=0.55
    btn.Text="" btn.BorderSizePixel=0
    btn.AutoButtonColor=false btn.ZIndex=5 btn.Parent=tabBar
    _corner(btn,8)

    local iL=_IN("TextLabel")
    iL.Size=_ud2(0,15,1,0) iL.Position=_ud2(0,5,0,0)
    iL.BackgroundTransparency=1 iL.Text=td.icon
    iL.TextSize=11 iL.Font=Enum.Font.GothamBold
    iL.TextColor3=P.textD iL.ZIndex=6 iL.Parent=btn

    local nL=_IN("TextLabel")
    nL.Size=_ud2(1,-22,1,0) nL.Position=_ud2(0,20,0,0)
    nL.BackgroundTransparency=1 nL.Text=td.name
    nL.TextSize=9.5 nL.Font=Enum.Font.GothamBold
    nL.TextColor3=P.textD nL.TextXAlignment=Enum.TextXAlignment.Left
    nL.ZIndex=6 nL.Parent=btn

    btn.MouseButton1Click:Connect(function() _switchTab(td.id) end)
    tabBtns[td.id]=btn
end

-- ═══ SLIDER ═══
local function _slider(parent,label,mn,mx,cur,col,order,onChange)
    local sc=_IN("Frame")
    sc.Size=_ud2(1,0,0,58) sc.BackgroundColor3=P.bgCard
    sc.BackgroundTransparency=0.04 sc.BorderSizePixel=0
    sc.LayoutOrder=order sc.ZIndex=3
    sc.ClipsDescendants=false sc.Parent=parent
    _corner(sc,14) _stroke(sc,P.bord,0.6,0.55)

    local sL=_IN("TextLabel")
    sL.Size=_ud2(0.62,0,0,18) sL.Position=_ud2(0,12,0,7)
    sL.BackgroundTransparency=1 sL.Text=label
    sL.TextColor3=P.textW sL.TextSize=11
    sL.Font=Enum.Font.GothamBold sL.TextXAlignment=Enum.TextXAlignment.Left
    sL.ZIndex=4 sL.Parent=sc

    local vL=_IN("TextLabel")
    vL.Size=_ud2(0.34,0,0,18) vL.Position=_ud2(0.66,0,0,7)
    vL.BackgroundTransparency=1 vL.Text=_toS(cur)
    vL.TextColor3=col vL.TextSize=11
    vL.Font=Enum.Font.GothamBold vL.TextXAlignment=Enum.TextXAlignment.Right
    vL.ZIndex=4 vL.Parent=sc

    local trBG=_IN("Frame")
    trBG.Size=_ud2(1,-24,0,6) trBG.Position=_ud2(0,12,0,36)
    trBG.BackgroundColor3=_c3(20,20,40) trBG.BorderSizePixel=0
    trBG.ZIndex=4 trBG.Parent=sc
    _corner(trBG,3)

    local ir=_mclp((cur-mn)/(mx-mn),0,1)

    local trFill=_IN("Frame")
    trFill.Size=_ud2(ir,0,1,0) trFill.BackgroundColor3=col
    trFill.BorderSizePixel=0 trFill.ZIndex=5 trFill.Parent=trBG
    _corner(trFill,3)
    _grad(trFill,ColorSequence.new{ColorSequenceKeypoint.new(0,col),ColorSequenceKeypoint.new(1,P.acc2)})

    local knob=_IN("Frame")
    knob.Size=_ud2(0,14,0,14) knob.AnchorPoint=Vector2.new(0.5,0.5)
    knob.Position=_ud2(ir,0,0.5,0) knob.BackgroundColor3=_c3(255,255,255)
    knob.BorderSizePixel=0 knob.ZIndex=6 knob.Parent=trBG
    _corner(knob,7) _stroke(knob,col,1.5,0)

    local draggingS=false
    local sBtn=_IN("TextButton")
    sBtn.Size=_ud2(1,0,1,22) sBtn.Position=_ud2(0,0,0,-11)
    sBtn.BackgroundTransparency=1 sBtn.Text=""
    sBtn.ZIndex=7 sBtn.Parent=trBG

    local function upd(ax)
        local absX=trBG.AbsolutePosition.X
        local w=trBG.AbsoluteSize.X
        local r=_mclp((ax-absX)/w,0,1)
        local val=_mf(mn+(mx-mn)*r)
        vL.Text=_toS(val)
        _tw2(trFill,_ti(0.04),{Size=_ud2(r,0,1,0)}):Play()
        _tw2(knob,_ti(0.04),{Position=_ud2(r,0,0.5,0)}):Play()
        if onChange then onChange(val) end
    end

    sBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or
           inp.UserInputType==Enum.UserInputType.Touch then draggingS=true end
    end)
    _UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or
           inp.UserInputType==Enum.UserInputType.Touch then draggingS=false end
    end)
    _UIS.InputChanged:Connect(function(inp)
        if draggingS and (inp.UserInputType==Enum.UserInputType.MouseMovement or
                          inp.UserInputType==Enum.UserInputType.Touch) then
            upd(inp.Position.X)
        end
    end)
    return sc
end

-- ═══ MODULE CARD ═══
local allMods={}

local function _module(tabId,icon,name,desc,order,accent,tags,cfgKey,onOn,onOff)
    local ps=tabContent[tabId]
    if not ps then return nil,nil end

    local card=_IN("Frame")
    card.Name=_gID(5) card.Size=_ud2(1,0,0,90)
    card.BackgroundColor3=P.bgCard card.BackgroundTransparency=0.04
    card.BorderSizePixel=0 card.LayoutOrder=order
    card.ZIndex=3 card.ClipsDescendants=true card.Parent=ps
    _corner(card,16)
    local cStroke=_stroke(card,P.bord,0.6,0.55)

    local glass=_IN("Frame")
    glass.Size=_ud2(1,0,0.42,0) glass.BackgroundColor3=_c3(255,255,255)
    glass.BackgroundTransparency=0.97 glass.BorderSizePixel=0
    glass.ZIndex=3 glass.Parent=card
    _corner(glass,16)

    local lBar=_IN("Frame")
    lBar.Size=_ud2(0,3,0.34,0) lBar.Position=_ud2(0,0,0.33,0)
    lBar.BackgroundColor3=accent lBar.BackgroundTransparency=0.2
    lBar.BorderSizePixel=0 lBar.ZIndex=4 lBar.Parent=card
    _corner(lBar,2)

    local iBG=_IN("Frame")
    iBG.Size=_ud2(0,50,0,50) iBG.Position=_ud2(0,12,0,10)
    iBG.BackgroundColor3=accent iBG.BackgroundTransparency=0.87
    iBG.BorderSizePixel=0 iBG.ZIndex=4 iBG.Parent=card
    _corner(iBG,15)

    local iIn=_IN("Frame")
    iIn.Size=_ud2(0,34,0,34) iIn.AnchorPoint=Vector2.new(0.5,0.5)
    iIn.Position=_ud2(0.5,0,0.5,0) iIn.BackgroundColor3=accent
    iIn.BackgroundTransparency=0.7 iIn.BorderSizePixel=0
    iIn.ZIndex=5 iIn.Parent=iBG
    _corner(iIn,10)

    local iL=_IN("TextLabel")
    iL.Size=_ud2(1,0,1,0) iL.BackgroundTransparency=1
    iL.Text=icon iL.TextSize=17
    iL.Font=Enum.Font.GothamBold iL.ZIndex=6 iL.Parent=iIn

    local nL=_IN("TextLabel")
    nL.Size=_ud2(1,-145,0,20) nL.Position=_ud2(0,72,0,12)
    nL.BackgroundTransparency=1 nL.Text=name
    nL.TextColor3=P.textW nL.TextSize=13
    nL.Font=Enum.Font.GothamBold nL.TextXAlignment=Enum.TextXAlignment.Left
    nL.ZIndex=4 nL.Parent=card

    local dL=_IN("TextLabel")
    dL.Size=_ud2(1,-145,0,12) dL.Position=_ud2(0,72,0,34)
    dL.BackgroundTransparency=1 dL.Text=desc
    dL.TextColor3=P.textD dL.TextSize=9
    dL.Font=Enum.Font.Gotham dL.TextXAlignment=Enum.TextXAlignment.Left
    dL.ZIndex=4 dL.Parent=card

    if tags then
        local tx=72
        for _,tag in _iprs(tags) do
            local tf=_IN("Frame")
            tf.Size=_ud2(0,#tag*5.1+14,0,15) tf.Position=_ud2(0,tx,0,52)
            tf.BackgroundColor3=accent tf.BackgroundTransparency=0.88
            tf.BorderSizePixel=0 tf.ZIndex=4 tf.Parent=card
            _corner(tf,5)
            local tl=_IN("TextLabel")
            tl.Size=_ud2(1,0,1,0) tl.BackgroundTransparency=1
            tl.Text=tag tl.TextColor3=accent
            tl.TextSize=6.5 tl.Font=Enum.Font.GothamBlack
            tl.ZIndex=5 tl.Parent=tf
            tx=tx+#tag*5.1+17
        end
    end

    local botLine=_IN("Frame")
    botLine.Size=_ud2(0,0,0,2) botLine.AnchorPoint=Vector2.new(0.5,0)
    botLine.Position=_ud2(0.5,0,1,-3) botLine.BackgroundColor3=accent
    botLine.BackgroundTransparency=0.3 botLine.BorderSizePixel=0
    botLine.ZIndex=4 botLine.Parent=card
    _corner(botLine,1)
    _grad(botLine,ColorSequence.new{
        ColorSequenceKeypoint.new(0,accent),
        ColorSequenceKeypoint.new(0.5,P.acc2),
        ColorSequenceKeypoint.new(1,accent),
    })

    local togBtn=_IN("TextButton")
    togBtn.Size=_ud2(0,54,0,27) togBtn.Position=_ud2(1,-66,0.5,-13.5)
    togBtn.BackgroundColor3=P.tOff togBtn.Text=""
    togBtn.BorderSizePixel=0 togBtn.AutoButtonColor=false
    togBtn.ZIndex=4 togBtn.Parent=card
    _corner(togBtn,13.5)
    local togS=_stroke(togBtn,P.bord,0.5,0.5)

    local knob=_IN("Frame")
    knob.Size=_ud2(0,21,0,21) knob.Position=_ud2(0,3,0.5,-10.5)
    knob.BackgroundColor3=P.tKnob knob.BorderSizePixel=0
    knob.ZIndex=5 knob.Parent=togBtn
    _corner(knob,11)
    local kS=_stroke(knob,accent,0,0.8)

    local kDot=_IN("Frame")
    kDot.Size=_ud2(0,7,0,7) kDot.AnchorPoint=Vector2.new(0.5,0.5)
    kDot.Position=_ud2(0.5,0,0.5,0) kDot.BackgroundColor3=accent
    kDot.BackgroundTransparency=1 kDot.BorderSizePixel=0
    kDot.ZIndex=6 kDot.Parent=knob
    _corner(kDot,4)

    local hov=_IN("TextButton")
    hov.Size=_ud2(1,0,1,0) hov.BackgroundTransparency=1
    hov.Text="" hov.ZIndex=3 hov.Parent=card

    hov.MouseEnter:Connect(function()
        _tw2(card,_ti(0.22),{BackgroundTransparency=0}):Play()
        _tw2(cStroke,_ti(0.22),{Transparency=0.1,Color=accent}):Play()
        _tw2(lBar,_ti(0.28),{BackgroundTransparency=0,Size=_ud2(0,4.5,0.46,0)}):Play()
        _tw2(botLine,_ti(0.38),{Size=_ud2(0.84,0,0,2.5)}):Play()
        _tw2(iBG,_ti(0.28),{BackgroundTransparency=0.76}):Play()
    end)
    hov.MouseLeave:Connect(function()
        _tw2(card,_ti(0.22),{BackgroundTransparency=0.04}):Play()
        _tw2(cStroke,_ti(0.22),{Transparency=0.55,Color=P.bord}):Play()
        _tw2(lBar,_ti(0.28),{BackgroundTransparency=0.2,Size=_ud2(0,3,0.34,0)}):Play()
        _tw2(botLine,_ti(0.38),{Size=_ud2(0,0,0,2)}):Play()
        _tw2(iBG,_ti(0.28),{BackgroundTransparency=0.87}):Play()
    end)

    local isOn=false
    local function setV(state)
        isOn=state
        local t=_ti(0.32)
        if state then
            _tw2(togBtn,t,{BackgroundColor3=accent}):Play()
            _tw2(togS,t,{Color=accent,Transparency=0.06}):Play()
            _tw2(knob,t,{Position=_ud2(1,-24,0.5,-10.5),BackgroundColor3=_c3(255,255,255)}):Play()
            _tw2(kS,t,{Thickness=2,Transparency=0}):Play()
            _tw2(kDot,t,{BackgroundTransparency=0}):Play()
            _tw2(cStroke,t,{Color=accent,Transparency=0.16}):Play()
            _tw2(lBar,t,{BackgroundTransparency=0}):Play()
            _tw2(iIn,t,{BackgroundTransparency=0.46}):Play()
            _tw2(botLine,TweenInfo.new(0.4,Enum.EasingStyle.Quint),
                {Size=_ud2(0.9,0,0,2.5),BackgroundTransparency=0.06}):Play()
        else
            _tw2(togBtn,t,{BackgroundColor3=P.tOff}):Play()
            _tw2(togS,t,{Color=P.bord,Transparency=0.5}):Play()
            _tw2(knob,t,{Position=_ud2(0,3,0.5,-10.5),BackgroundColor3=P.tKnob}):Play()
            _tw2(kS,t,{Thickness=0,Transparency=0.8}):Play()
            _tw2(kDot,t,{BackgroundTransparency=1}):Play()
            _tw2(cStroke,t,{Color=P.bord,Transparency=0.55}):Play()
            _tw2(lBar,t,{BackgroundTransparency=0.2}):Play()
            _tw2(iIn,t,{BackgroundTransparency=0.7}):Play()
            _tw2(botLine,_ti(0.28),{Size=_ud2(0,0,0,2),BackgroundTransparency=0.3}):Play()
        end
    end

    allMods[#allMods+1]={cfgKey=cfgKey,color=accent}

    togBtn.MouseButton1Click:Connect(function()
        CFG[cfgKey]=not CFG[cfgKey]
        setV(CFG[cfgKey])
        if CFG[cfgKey] then
            _refChar()
            if onOn then _pc(onOn) end
        else
            if onOff then _pc(onOff) end
        end
        updateStatus()
    end)

    return togBtn,setV
end

-- ══════════════════════════════════
-- ALL MODULES
-- ══════════════════════════════════

-- COMBAT
_module("combat","🛡️","God Mode","Бесконечное здоровье (перерождение безопасно)",
    1,P.acc3,{"IMMORTAL","AUTO-HEAL"},"godMode",_startGod,_stopGod)

_module("combat","👻","Anti-Ragdoll","Ghost-контроль при рагдолле v9",
    2,P.acc2,{"GHOST","v9","SAB"},"antiRagdoll",_startAntiRag,_stopAntiRag)

_module("combat","💀","Big Head","Огромные головы врагов",
    3,P.acc7,{"HITBOX","PVP"},"bigHead",_startBigHead,function() CFG.bigHead=false end)

_module("combat","📦","Hitbox Expand","Расширить хитбокс врагов",
    4,P.acc3,{"EXPAND","BOX"},"hitboxExp",_expandHB,_restoreHB)

_module("combat","💥","No Knockback","Нет отбрасывания (SAB)",
    5,P.acc7,{"STABLE","SAB"},"noKnockback",_startNoKnockback,_stopNoKnockback)

-- MOVEMENT
_module("movement","⚡","Infinite Jump","Бесконечные прыжки в воздухе",
    1,P.acc1,{"AIR","MULTI"},"infJump",function()end,function()end)

_module("movement","🏃","Speed Boost","Ускорение персонажа",
    2,P.acc4,{"FAST","SAB"},"speed",_startSABSpeed,_stopSABSpeed)

_module("movement","🕊️","Fly","Свободный полёт WASD+Space/Ctrl",
    3,P.acc8,{"FLY","3D"},"fly",_startFly,_stopFly)

_module("movement","👤","Noclip","Проход сквозь стены",
    4,P.acc6,{"PHASE","WALL"},"noclip",_startNoclip,_stopNoclip)

_module("movement","🌙","Low Gravity","Лунная гравитация",
    5,_c3(185,135,255),{"MOON","FLOAT"},"lowGravity",_startLowG,_stopLowG)

-- VISUAL
_module("visual","🎭","No Animations","Заморозка анимаций",
    1,P.acc3,{"FREEZE","SILENT"},"noAnim",_startNoAnim,_stopNoAnim)

_module("visual","👁️","ESP","Видеть врагов сквозь стены + HP + дист",
    2,P.acc5,{"WALLHACK","HP","DIST"},"esp",_startESP,_stopESP)

_module("visual","🌈","Chams","RGB подсветка тел врагов",
    3,P.acc6,{"CHAMS","RGB"},"chams",_startChams,_stopChams)

_module("visual","📍","Tracers","Линии к врагам",
    4,P.acc4,{"LINE","TRACK"},"tracers",
    function() _startTracers(SG) end, _stopTracers)

-- WORLD
_module("world","☀️","Fullbright","Максимальная яркость карты",
    1,P.acc4,{"BRIGHT","LIGHT"},"fullbright",_startFB,_stopFB)

_module("world","🌫️","No Fog","Убрать туман",
    2,P.acc8,{"CLEAR","FOG"},"noFog",_startNoFog,_stopNoFog)

-- AIMBOT
_module("aimbot","🎯","Aimbot","Автоприцел — держи Q",
    1,P.acc7,{"LOCK","SMOOTH","AUTO"},"aimbot",
    function() _drawFOV(SG) end,
    function()
        _aimTgt=nil _aimLock=false
        if _aimFOVG then _pc(function() _aimFOVG:Destroy() end) _aimFOVG=nil end
    end)

_module("aimbot","👻","Silent Aim","Пули летят в цель незаметно",
    2,P.acc3,{"SILENT","INVISIBLE"},"silentAim",
    function()end,
    function() _aimTgt=nil _aimLock=false end)

-- AIMBOT SLIDERS
_slider(tabContent["aimbot"],"FOV Radius",50,500,CFG.aimbotFOV,P.acc7,3,function(v)
    CFG.aimbotFOV=v
    if _aimFOVG then
        _pc(function()
            _aimFOVG.Size=_ud2(0,v*2,0,v*2)
            local c=_aimFOVG:FindFirstChildOfClass("UICorner")
            if c then c.CornerRadius=_ud(0,v) end
        end)
    end
end)

_slider(tabContent["aimbot"],"Smooth %",1,50,_mf(CFG.aimbotSmooth*100),P.acc7,4,function(v)
    CFG.aimbotSmooth=v/100
end)

_slider(tabContent["aimbot"],"Hitbox Size",2,24,CFG.hitboxSize,P.acc3,5,function(v)
    CFG.hitboxSize=v
end)

_slider(tabContent["aimbot"],"Fly Speed",10,200,CFG.flySpeed,P.acc8,6,function(v)
    CFG.flySpeed=v
end)

_slider(tabContent["aimbot"],"Walk Speed",16,120,CFG.speedValue,P.acc4,7,function(v)
    CFG.speedValue=v
    if CFG.speed and _hum then _pc(function() _hum.WalkSpeed=v end) end
end)

-- SAB TAB
_module("sab","🧠","Auto Brainrot","Авто-сбор брейнротов на карте",
    1,P.acc6,{"SAB","AUTO","COLLECT"},"autoBrainrot",_startAutoBrainrot,_stopAutoBrainrot)

-- SAB Sliders
_slider(tabContent["sab"],"Jump Power",30,120,CFG.jumpPower,P.acc1,10,function(v)
    CFG.jumpPower=v
    if _hum then _pc(function() _hum.JumpPower=v end) end
end)

-- ═══ STATUS BAR ═══
local SB=_IN("Frame")
SB.Name=_gID(4) SB.Size=_ud2(1,-14,0,56)
SB.Position=_ud2(0,7,1,-62) SB.BackgroundColor3=P.bgDeep
SB.BackgroundTransparency=0.08 SB.BorderSizePixel=0
SB.ZIndex=5 SB.Parent=MF
_corner(SB,14) _stroke(SB,P.bord,0.5,0.6)

local statL=_IN("TextLabel")
statL.Size=_ud2(0.6,0,0,20) statL.Position=_ud2(0,12,0,6)
statL.BackgroundTransparency=1 statL.Text="Ready"
statL.TextColor3=P.textD statL.TextSize=11
statL.Font=Enum.Font.GothamMedium statL.TextXAlignment=Enum.TextXAlignment.Left
statL.ZIndex=6 statL.Parent=SB

local infoL=_IN("TextLabel")
infoL.Size=_ud2(0.6,0,0,14) infoL.Position=_ud2(0,12,0,27)
infoL.BackgroundTransparency=1 infoL.Text=""
infoL.TextColor3=P.acc2 infoL.TextSize=9
infoL.Font=Enum.Font.Gotham infoL.TextXAlignment=Enum.TextXAlignment.Left
infoL.ZIndex=6 infoL.Parent=SB

local pingL=_IN("TextLabel")
pingL.Size=_ud2(0,85,0,12) pingL.Position=_ud2(1,-92,0,6)
pingL.BackgroundTransparency=1 pingL.Text="● "..tostring(_ri(8,35)).."ms"
pingL.TextColor3=P.textG pingL.TextSize=8
pingL.Font=Enum.Font.GothamMedium pingL.TextXAlignment=Enum.TextXAlignment.Right
pingL.ZIndex=6 pingL.Parent=SB

local lockL=_IN("TextLabel")
lockL.Size=_ud2(0,130,0,12) lockL.Position=_ud2(1,-136,0,21)
lockL.BackgroundTransparency=1 lockL.Text=""
lockL.TextColor3=P.acc3 lockL.TextSize=8
lockL.Font=Enum.Font.GothamBold lockL.TextXAlignment=Enum.TextXAlignment.Right
lockL.ZIndex=6 lockL.Parent=SB

-- Active dots (18 total)
local dots={}
for i=1,18 do
    local d=_IN("Frame")
    d.Size=_ud2(0,6,0,6) d.Position=_ud2(0,12+(i-1)*9,0,44)
    d.BackgroundColor3=_c3(18,18,34) d.BorderSizePixel=0
    d.ZIndex=6 d.Parent=SB
    _corner(d,3) dots[i]=d
end

function updateStatus()
    local keys={
        "infJump","antiRagdoll","noAnim","speed","fly","noclip","esp",
        "godMode","fullbright","noFog","bigHead","lowGravity",
        "aimbot","silentAim","hitboxExp","chams","tracers",
        "autoBrainrot","noKnockback",
    }
    local cnt,acolors=0,{}
    for _,k in _iprs(keys) do
        if CFG[k] then
            cnt=cnt+1
            for _,md in _iprs(allMods) do
                if md.cfgKey==k then acolors[#acolors+1]=md.color break end
            end
        end
    end
    for i=1,18 do
        if i<=cnt and acolors[i] then
            _tw2(dots[i],_ti(0.28),{BackgroundColor3=acolors[i]}):Play()
        else
            _tw2(dots[i],_ti(0.28),{BackgroundColor3=_c3(18,18,34)}):Play()
        end
    end
    if cnt==0 then
        statL.Text="Все модули неактивны"
        _tw2(statL,_ti(0.28),{TextColor3=P.textD}):Play()
    else
        statL.Text=cnt.."/19 · TERMINATOR ON"
        _tw2(statL,_ti(0.28),{TextColor3=P.textG}):Play()
    end
end

-- Info loop
_tsp(function()
    while SG and SG.Parent do
        _pc(function()
            if _aimLock and _aimTgt then
                lockL.Text="🎯 LOCKED: ".._aimTgt.DisplayName
                lockL.TextColor3=P.acc3
            else lockL.Text="" end

            if _ghostOn then
                infoL.Text="👻 GHOST · ".._mf(tick()-_ragT).."s"
                infoL.TextColor3=_c3h((tick()*0.18)%1,0.35,1)
            elseif _exitLk then
                infoL.Text="⟳ Stabilizing..."
                infoL.TextColor3=P.acc4
            elseif _flyOn then
                infoL.Text="🕊️ Fly · "..CFG.flySpeed.."u/s"
                infoL.TextColor3=P.acc8
            elseif CFG.autoBrainrot then
                infoL.Text="🧠 Auto-Collecting Brainrots..."
                infoL.TextColor3=P.acc6
            elseif CFG.hitboxExp then
                infoL.Text="📦 Hitbox ×"..CFG.hitboxSize
                infoL.TextColor3=P.acc3
            else infoL.Text="" end

            pingL.Text="● ".._ri(5,52).."ms"
        end)
        _tw(0.1)
    end
end)

-- ═══ MIN/CLOSE ═══
local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    if minimized then
        _tw2(MF,TweenInfo.new(0.42,Enum.EasingStyle.Back,Enum.EasingDirection.In),
            {Size=_ud2(0,470,0,82)}):Play()
        _td(0.06,function()
            contentF.Visible=false tabBar.Visible=false SB.Visible=false
        end)
        MinBtn.Text="◻"
    else
        _tw2(MF,TweenInfo.new(0.5,Enum.EasingStyle.Back),
            {Size=_ud2(0,470,0,680)}):Play()
        _td(0.2,function()
            contentF.Visible=true tabBar.Visible=true SB.Visible=true
        end)
        MinBtn.Text="━"
    end
end)

ClsBtn.MouseButton1Click:Connect(function()
    for k,v in _prs(CFG) do if _type(v)=="boolean" then CFG[k]=false end end
    _stopAntiRag() _stopNoAnim()   _stopFly()
    _stopNoclip()  _stopESP()      _stopGod()
    _stopFB()      _stopNoFog()    _stopLowG()
    _stopSABSpeed() _stopChams()   _stopTracers()
    _stopAutoBrainrot() _stopNoKnockback()
    _restoreHB()
    if _aimFOVG then _pc(function() _aimFOVG:Destroy() end) end
    if _hbConn then _hbConn:Disconnect() end
    _tw2(_mStroke,_ti(0.1),{Transparency=1}):Play()
    _tw2(MF,TweenInfo.new(0.48,Enum.EasingStyle.Back,Enum.EasingDirection.In),{
        Size=_ud2(0,6,0,6),Position=_ud2(0.5,-3,0.5,-3),
        BackgroundTransparency=0.3,
    }):Play()
    _td(0.36,function() _tw2(MF,_ti(0.14),{BackgroundTransparency=1}):Play() end)
    _td(0.54,function() _pc(function() SG:Destroy() end) end)
end)

-- ═══ LIVE ANIMATIONS ═══

-- Border + logo rainbow
_tsp(function()
    local hue=_rf(0,1)
    while SG and SG.Parent do
        hue=(hue+0.0009)%1
        local ac=0
        for _,v in _prs(CFG) do if _type(v)=="boolean" and v then ac=ac+1 end end
        local t=tick()
        if ac>0 then
            _mStroke.Color=_c3h(hue,_mclp(0.33+ac*0.038,0,0.88),_mclp(0.62+ac*0.018,0,1))
            _mStroke.Transparency=0.02+_ms(t*1.3)*0.038
            _mStroke.Thickness=1.5+_ms(t*1.8)*0.42
            _pc(function()
                for _,r in _iprs(rings) do r.BackgroundColor3=_c3h((hue+0.05)%1,0.5,0.86) end
                logoGlow.BackgroundColor3=_c3h((hue+0.1)%1,0.55,1)
            end)
        else
            _mStroke.Color=P.bord _mStroke.Transparency=0.55 _mStroke.Thickness=1
            _pc(function()
                for _,r in _iprs(rings) do r.BackgroundColor3=P.acc1 end
                logoGlow.BackgroundColor3=P.acc1
            end)
        end
        _tw(0.02)
    end
end)

-- Aurora float
_tsp(function()
    local ph={}
    for i=1,#_orbDat do ph[i]=_rf(0,_mpi*2) end
    while SG and SG.Parent do
        local t=tick()
        for i,o in _iprs(_orbs) do
            _pc(function()
                local od=_orbDat[i]
                local ox=_ms(t*(0.09+i*0.038)+ph[i])*17
                local oy=_mc(t*(0.11+i*0.028)+ph[i]*0.68)*14
                o.Position=_ud2(od[1].X.Scale,od[1].X.Offset+ox,od[1].Y.Scale,od[1].Y.Offset+oy)
                o.BackgroundTransparency=od[4]+_ms(t*(0.26+i*0.046))*0.009
            end)
        end
        _tw(0.024)
    end
end)

-- Logo pulse
_tsp(function()
    while SG and SG.Parent do
        local ac=0
        for _,v in _prs(CFG) do if _type(v)=="boolean" and v then ac=ac+1 end end
        if ac>0 then
            for i,r in _iprs(rings) do
                _pc(function()
                    local rd=rDat[i]
                    _tw2(r,TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                        {BackgroundTransparency=rd[2]-0.07,Size=_ud2(0,rd[1]+6,0,rd[1]+6)}):Play()
                end)
            end
            _pc(function()
                _tw2(logoGlow,TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                    {BackgroundTransparency=0.1,Size=_ud2(0,30,0,30)}):Play()
            end)
            _tw(2)
            if not(SG and SG.Parent) then return end
            for i,r in _iprs(rings) do
                _pc(function()
                    local rd=rDat[i]
                    _tw2(r,TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                        {BackgroundTransparency=rd[2],Size=_ud2(0,rd[1],0,rd[1])}):Play()
                end)
            end
            _pc(function()
                _tw2(logoGlow,TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                    {BackgroundTransparency=0.28,Size=_ud2(0,26,0,26)}):Play()
            end)
            _tw(2)
        else _tw(0.5) end
    end
end)

-- Dots pulse
_tsp(function()
    while SG and SG.Parent do
        local cnt=0
        for _,v in _prs(CFG) do if _type(v)=="boolean" and v then cnt=cnt+1 end end
        for i=1,_mmn(cnt,18) do
            _pc(function()
                _tw2(dots[i],TweenInfo.new(0.65,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                    {Size=_ud2(0,9,0,9)}):Play()
            end)
        end
        _tw(0.65)
        if not(SG and SG.Parent) then return end
        for i=1,18 do
            _pc(function()
                _tw2(dots[i],TweenInfo.new(0.65,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                    {Size=_ud2(0,6,0,6)}):Play()
            end)
        end
        _tw(0.65)
    end
end)

-- ═══ CINEMATIC OPEN ═══
MF.BackgroundTransparency=1
contentF.Visible=false tabBar.Visible=false SB.Visible=false
_mStroke.Transparency=1
HD.BackgroundTransparency=1 HDPatch.BackgroundTransparency=1
for _,o in _iprs(_orbs) do o.BackgroundTransparency=1 end
for _,c in _iprs(HD:GetDescendants()) do
    _pc(function()
        if c:IsA("TextLabel") or c:IsA("TextButton") then c.TextTransparency=1 end
        if c:IsA("Frame") then c.BackgroundTransparency=1 end
    end)
end

_td(0.06,function()
    MF.Size=_ud2(0,6,0,6) MF.Position=_ud2(0.5,-3,0.5,-3)
    _tw2(MF,_ti(0.1),{BackgroundTransparency=0}):Play()
    _tw2(_mStroke,_ti(0.1),{Transparency=0.1}):Play()
    _tw(0.08)
    _tw2(MF,TweenInfo.new(0.26,Enum.EasingStyle.Quint),{
        Size=_ud2(0,470,0,6),Position=_ud2(0.5,-235,0.5,-3),
    }):Play()
    _tw(0.2)
    _tw2(MF,TweenInfo.new(0.52,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{
        Size=_ud2(0,470,0,680),Position=_ud2(0.5,-235,0.5,-340),
    }):Play()
    _tw(0.16)

    for i,o in _iprs(_orbs) do
        _td(i*0.022,function()
            _tw2(o,TweenInfo.new(0.58,Enum.EasingStyle.Quint),
                {BackgroundTransparency=_orbDat[i][4]}):Play()
        end)
    end

    _td(0.1,function()
        _tw2(HD,_ti(0.28),{BackgroundTransparency=0.02}):Play()
        _tw2(HDPatch,_ti(0.28),{BackgroundTransparency=0.02}):Play()
        local dl=0
        for _,c in _iprs(HD:GetDescendants()) do
            _pc(function()
                dl=dl+0.007
                if c:IsA("TextLabel") then
                    _td(dl,function() _tw2(c,_ti(0.38),{TextTransparency=0}):Play() end)
                end
                if c:IsA("TextButton") then
                    _td(dl,function()
                        _tw2(c,_ti(0.38),{TextTransparency=0,BackgroundTransparency=0.52}):Play()
                    end)
                end
                if c:IsA("Frame") and c~=HDPatch then
                    _td(dl,function()
                        local tgt=0.87
                        if c==rings[1] then tgt=rDat[1][2]
                        elseif c==rings[2] then tgt=rDat[2][2]
                        elseif c==rings[3] then tgt=rDat[3][2]
                        elseif c==logoGlow then tgt=0.28 end
                        _tw2(c,_ti(0.44),{BackgroundTransparency=tgt}):Play()
                    end)
                end
            end)
        end
    end)

    _tw(0.26)
    tabBar.Visible=true tabBar.BackgroundTransparency=1
    _tw2(tabBar,_ti(0.32),{BackgroundTransparency=0.22}):Play()
    for _,b in _prs(tabBtns) do
        b.BackgroundTransparency=1
        _tw2(b,_ti(0.32),{BackgroundTransparency=0.55}):Play()
        for _,c in _iprs(b:GetChildren()) do
            if c:IsA("TextLabel") then
                c.TextTransparency=1 _tw2(c,_ti(0.36),{TextTransparency=0}):Play()
            end
        end
    end

    _tw(0.1)
    contentF.Visible=true
    SB.Visible=true SB.BackgroundTransparency=1
    _tw2(SB,_ti(0.38),{BackgroundTransparency=0.08}):Play()
    for _,c in _iprs(SB:GetChildren()) do
        _pc(function()
            if c:IsA("TextLabel") then
                c.TextTransparency=1 _tw2(c,_ti(0.42),{TextTransparency=0}):Play()
            end
        end)
    end

    -- Cards cascade
    local vis=tabContent[curTab]
    if vis then
        local ci=0
        for _,c in _iprs(vis:GetChildren()) do
            if c:IsA("Frame") then
                ci=ci+1
                local idx=ci
                c.BackgroundTransparency=1
                for _,d in _iprs(c:GetDescendants()) do
                    _pc(function()
                        if d:IsA("TextLabel") then d.TextTransparency=1 end
                        if d:IsA("Frame") then d.BackgroundTransparency=1 end
                        if d:IsA("TextButton") then d.TextTransparency=1 d.BackgroundTransparency=1 end
                    end)
                end
                _td(idx*0.065,function()
                    _tw2(c,TweenInfo.new(0.42,Enum.EasingStyle.Quint),
                        {BackgroundTransparency=0.04}):Play()
                    _td(0.06,function()
                        for _,d in _iprs(c:GetDescendants()) do
                            _pc(function()
                                if d:IsA("TextLabel") then
                                    _tw2(d,_ti(0.35),{TextTransparency=0}):Play()
                                end
                                if d:IsA("Frame") then
                                    local ft=0.87
                                    if d.Size.X.Offset<=5 then ft=0.2
                                    elseif d.Size.X.Offset<=22 then ft=0.45
                                    elseif d.Size.X.Offset<=55 then ft=0.7 end
                                    _tw2(d,_ti(0.35),{BackgroundTransparency=ft}):Play()
                                end
                                if d:IsA("TextButton") then
                                    _tw2(d,_ti(0.35),{TextTransparency=0,BackgroundTransparency=0.4}):Play()
                                end
                            end)
                        end
                    end)
                end)
            end
        end
    end

    _td(0.9,function()
        _tw2(_mStroke,_ti(0.5),{Transparency=0.5}):Play()
    end)
end)

_switchTab("combat")
updateStatus()
