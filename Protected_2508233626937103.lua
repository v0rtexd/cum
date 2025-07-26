local Library = loadstring(game:HttpGet("https://pastefy.app/JnuxQ5GL/raw"))()
local main = Library.new()

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInput = game:GetService("VirtualInputManager")
local Debris = game:GetService("Debris")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local Alive = workspace:WaitForChild('Alive')
local Balls = workspace:WaitForChild('Balls')

local clientCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local clientHumanoid = clientCharacter:FindFirstChildOfClass("Humanoid")
local AliveGroup = Workspace:FindFirstChild("Alive")

local lastInputType = UserInputService:GetLastInputType()
local currentMousePos = nil
local parryAnimation = nil
local Remotes = {}
local Parry_Key = nil

getgenv().SingularityActive = false
getgenv().AerodynamicActive = false
getgenv().AerodynamicTime = 0
getgenv().DeathSlashActive = false
getgenv().DeathSlashTime = 0
getgenv().DeathSlashParryCount = 0
getgenv().AerodynamicDetectionEnabled = false
getgenv().DeathSlashDetectionEnabled = false

if not getgenv().swordChangerInitialized then
    getgenv().Skin_Changer = false
    getgenv().Sword_Model = 'Base Sword'
    getgenv().Sword_Animation = getgenv().Sword_Model
    getgenv().Sword_VFX = getgenv().Sword_Model
    getgenv().originalSword = nil
    
    local Byte_Library = {}
    local Client = Players.LocalPlayer
    local Heartbeat = RunService.Heartbeat
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local Shared = ReplicatedStorage:WaitForChild("Shared")
    local FireSwordInfo = Remotes:WaitForChild("FireSwordInfo")
    local ParrySuccessAll = Remotes:WaitForChild("ParrySuccessAll")
    local ReplicatedInstances = Shared:WaitForChild("ReplicatedInstances")
    local Swords = require(ReplicatedInstances:WaitForChild("Swords"))
    
    local Play_Parry
    local Sword_Function
    local function getOriginalSword()
        return Client.Character and Client.Character:GetAttribute('CurrentlyEquippedSword') or "Base Sword"
    end
    local Default_Sword = getOriginalSword()
    local Saved_Sword_Model = Swords:GetSword(Default_Sword)
    
    getgenv().originalSword = Default_Sword
    
    debug.setupvalue(Swords.EquipSwordTo, 2, false)
    
    function Byte_Library.Update(Character)
        if not Character or not getgenv().Skin_Changer then return end
        
        local Sword_Model = Swords:GetSword(getgenv().Sword_Model)
        local Sword_Animation = Swords:GetSword(getgenv().Sword_Animation)
        
        if Sword_Model then
            Swords:EquipSwordTo(Character, Sword_Model.Name)
            Character:SetAttribute("CurrentlyEquippedSword", Sword_Model.Name)
        end
        
        if Sword_Animation and Sword_Function then
            Sword_Function(Sword_Animation.Name)
        end
    end
    
    for i, v in getconnections(FireSwordInfo.OnClientEvent) do
        if v.Function then
            Sword_Function = v.Function
        end
    end
    
    for i, v in getconnections(ParrySuccessAll.OnClientEvent) do
        if v.Function then
            Play_Parry = v.Function
            v:Disable()
        end
    end
    
    ParrySuccessAll.OnClientEvent:Connect(function(...)
        local args = {...}
        local current_sword = Swords:GetSword(getgenv().Sword_VFX)
        
        if getgenv().Skin_Changer then
            if args[2] and args[2] == Client.Character.PrimaryPart then
                args[1] = current_sword.SlashName
                args[3] = current_sword.Name
            end
        end
        
        return Play_Parry(unpack(args))
    end)
    
    local function handleCharacterSpawn(char)
        task.wait(2)
        getgenv().originalSword = getOriginalSword()
        if getgenv().Skin_Changer then
            Byte_Library.Update(char)
        end
    end
    
    if Client.Character then
        task.spawn(function()
            handleCharacterSpawn(Client.Character)
        end)
    end
    
    Client.CharacterAdded:Connect(handleCharacterSpawn)
    
    getgenv().swordChangerInitialized = true
    getgenv().ByteLibrary = Byte_Library
end

local CONFIG = {
    PARRY_TYPES = {
        CUSTOM = 'Custom',
        BACKWARDS = 'Backwards',
        UP = 'Up',
        DOT = 'Dot',
        LEFT = 'Left',
        RIGHT = 'Right',
        RANDOM = 'Random',
        STRAIGHT = 'Straight'
    },
    MAX_PARRIES = 8,
    PARRY_COOLDOWN = 0.4,
    CURVE_DETECTION = {
        MIN_SPEED = 80,
        DOT_THRESHOLD = 0.45,
        LERP_WEIGHT = 0.85,
        VELOCITY_MEMORY = 8,
        ADVANCED_PREDICTION = true,
        MULTI_BALL_TRACKING = true,
        VELOCITY_SMOOTHING = 0.7
    },
    SPAM = {
        SPEED_DIVISOR = 5.8,
        MAX_SPEED_ADJUSTMENT = 8
    },
    LOBBY_AP = {
        MIN_ACCURACY = 1,
        MAX_ACCURACY = 100,
        DEFAULT_ACCURACY = 85
    },
    REGIONS = {
        "US East",
        "US West", 
        "Europe",
        "Asia",
        "Australia",
        "South America"
    }
}

local State = {
    remotes = {},
    parryKey = nil,
    parryCount = 0,
    hasParried = false,
    isAerodynamic = false,
    aerodynamicTime = 0,
    lastWarpTime = 0,
    lerpRadians = 0,
    velocityHistory = {},
    closestEntity = nil,
    selectedParryType = CONFIG.PARRY_TYPES.CUSTOM,
    
    ballTrajectoryHistory = {},
    velocityPrediction = {},
    curveDetectionSensitivity = 0.8,
    advancedCurveDetection = true,
    
    lastSpamTime = 0,
    lastParryTime = 0,
    parryCooldown = 0.01,
    connManager = {},
    Parries = 0,
    parryFlag = false,
    selectedParryMode = "Custom",
    spamThreshold = 0.01,
    spamSpeed = 20,
    Spamming = false,
    Closest_Entity = nil,
    ServerStatsItem = Stats.Network.ServerStatsItem,
    activeMethod = "Remote",
    
    autoParryAccuracy = 100,
    randomizedParryAccuracy = false,
    
    manualSpamEnabled = false,
    spamming = false,
    spamRate = 0.0001,
    
    autoParryEnabled = true,
    autoSpamEnabled = true,
    triggerbotEnabled = false,
    ballTPEnabled = false,
    instantBallTPEnabled = false,
    lobbyAPEnabled = false,
    lobbyAccuracy = CONFIG.LOBBY_AP.DEFAULT_ACCURACY,
    randomizedAccuracy = false,
    
    speedEnabled = false,
    speedValue = 16,
    spinbotEnabled = false,
    fovEnabled = false,
    fovValue = 70,
    flyEnabled = false,
    playerFollowEnabled = false,
    followTarget = nil,
    hitSoundsEnabled = false,
    emotesEnabled = false,
    playerEffectsEnabled = false,
    
    customSkyEnabled = false,
    worldFilterEnabled = false,
    ballTrailEnabled = true,
    abilityESPEnabled = false,
    
    noRenderEnabled = false,
    ballStatsEnabled = false,
    visualiserEnabled = false,
    autoClaimRewardsEnabled = false,
    disableQuantumEffects = false,
    skinChangerEnabled = false,
    streamerModeEnabled = false,
    fpsBoostEnabled = false,
    
    pingRegionEnabled = false,
    selectedRegion = "US East",
    advancedFPSBoost = false,
    
    AIPlaying = false,
    AICoroutine = nil,
    AITarget = nil,
    AICurrentMethod = "Blatant",
    AIStuckCheck = {
        lastPosition = Vector3.new(),
        stuckDuration = 0
    },
    AICooldowns = {
        jump = 0,
        dash = 0,
        targetSwitch = 0,
        action = 0
    },
    
    manualSpamKey = Enum.KeyCode.Q,
    triggerbotKey = Enum.KeyCode.E,
    ballTPKey = Enum.KeyCode.R,
    instantBallTPKey = Enum.KeyCode.T,  
    lobbyAPKey = Enum.KeyCode.Y,
    parryTypeKey = Enum.KeyCode.P
}

local StatsData = {
    TotalParries = 0,
    SuccessfulParries = 0,
    MissedParries = 0,
    CurvedBallsDetected = 0,
    InfinityDetections = 0,
    SessionTime = tick(),
    BallsTPed = 0,
    TriggerbotActivations = 0,
    ManualSpamUses = 0,
    AccuracyRate = 0
}

getgenv().Gen = getgenv().Gen or {
    SwModel = "Dual Purity Blade",
    Animation = "Dual Purity Blade",
    Slash = "Dual Purity Blade"
}

task.spawn(function()
    for _, Value in getgc() do
        if type(Value) == 'function' and islclosure(Value) then
            local Protos = debug.getprotos(Value)
            local Upvalues = debug.getupvalues(Value)
            local Constants = debug.getconstants(Value)
            if #Protos == 4 and #Upvalues == 24 and #Constants >= 102 then
                local c62 = Constants[62]
                local c64 = Constants[64]
                local c65 = Constants[65]
                State.remotes[debug.getupvalue(Value, 16)] = c62
                State.parryKey = debug.getupvalue(Value, 17)
                State.remotes[debug.getupvalue(Value, 18)] = c64
                State.remotes[debug.getupvalue(Value, 19)] = c65
                break
            end
        end
    end
    if not State.parryKey or next(State.remotes) == nil then
        warn("[zeryx] Failed to find remotes or parry key. Falling back to Keypress method.")
        State.activeMethod = "F Key"
    else
        print("[zeryx] Successfully found remotes and parry key!")
    end
end)

local function executeTween(target, info, props)
    local tw = TweenService:Create(target, info, props)
    tw:Play()
    task.wait(info.Time)
    Debris:AddItem(tw, 0)
    tw:Destroy()
end

local Spam = {}

function Spam.Get_Closest()
    local Max_Distance = math.huge
    State.Closest_Entity = nil
    for _, Entity in pairs(Workspace.Alive:GetChildren()) do
        if tostring(Entity) ~= tostring(LocalPlayer) then
            local Distance = LocalPlayer:DistanceFromCharacter(Entity.PrimaryPart.Position)
            if Distance < Max_Distance then
                Max_Distance = Distance
                State.Closest_Entity = Entity
            end
        end
    end
    return State.Closest_Entity
end

function Spam.Entity_Properties()
    Spam.Get_Closest()
    if not State.Closest_Entity then
        return {Velocity=Vector3.zero, Direction=Vector3.zero, Distance=math.huge}
    end
    local Entity_Velocity = State.Closest_Entity.PrimaryPart.Velocity
    local Entity_Direction = (LocalPlayer.Character.PrimaryPart.Position - State.Closest_Entity.PrimaryPart.Position).Unit
    local Entity_Distance = (LocalPlayer.Character.PrimaryPart.Position - State.Closest_Entity.PrimaryPart.Position).Magnitude
    return {Velocity=Entity_Velocity, Direction=Entity_Direction, Distance=Entity_Distance}
end

function Spam.FetchBall()
    for _, b in pairs(Workspace.Balls:GetChildren()) do
        if b:GetAttribute("realBall") then
            b.CanCollide = false
            return b
        end
    end
end

function Spam.Ball_Properties()
    local Ball = Spam.FetchBall()
    if not Ball then
        return {Velocity=Vector3.zero, Direction=Vector3.zero, Distance=math.huge, Dot=0}
    end
    local Ball_Velocity = Ball:FindFirstChild("zoomies") and Ball.zoomies.VectorVelocity or Vector3.zero
    local Ball_Direction = (LocalPlayer.Character.PrimaryPart.Position - Ball.Position).Unit
    local Ball_Distance = (LocalPlayer.Character.PrimaryPart.Position - Ball.Position).Magnitude
    local Ball_Dot = Ball_Direction:Dot(Ball_Velocity.Unit)
    return {Velocity=Ball_Velocity, Direction=Ball_Direction, Distance=Ball_Distance, Dot=Ball_Dot}
end

function Spam.CalcAccuracy(params)
    local ball = Spam.FetchBall()
    if not ball then return 0 end
    Spam.Get_Closest()
    local accuracy = 0
    local vel = ball:FindFirstChild("zoomies") and ball.zoomies.VectorVelocity or ball.AssemblyLinearVelocity
    local spd = vel.Magnitude
    local toBall = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Unit
    local ballDir = vel.Unit
    local dot = toBall:Dot(ballDir)
    local targetPos = State.Closest_Entity and State.Closest_Entity.PrimaryPart.Position or Vector3.new()
    local targetDist = LocalPlayer:DistanceFromCharacter(targetPos)
    
    local maxSpamRange = (params.Ping / 8) + math.min(spd / 5, 120)
    
    if params.EntityProps.Distance > maxSpamRange then return accuracy end
    if params.BallProps.Distance > maxSpamRange then return accuracy end
    if targetDist > maxSpamRange then return accuracy end
    
    local maxSpeed = 7 - math.min(spd / 5, 7)
    local adjDot = math.clamp(dot, -1, 1) * maxSpeed
    
    accuracy = maxSpamRange - adjDot + (math.random() * 5)
    
    return accuracy
end

local AutoParry = {}

function AutoParry.playParryAnimation()
    local baseParryAnim = ReplicatedStorage.Shared.SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    local currSword = LocalPlayer.Character:GetAttribute("CurrentlyEquippedSword")
    if not currSword or not baseParryAnim then return end
    
    local swordInfo = ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(currSword)
    if not swordInfo or not swordInfo.AnimationType then return end

    for _, folder in pairs(ReplicatedStorage.Shared.SwordAPI.Collection:GetChildren()) do
        if folder.Name == swordInfo.AnimationType then
            local selName = folder:FindFirstChild("Grab") and "Grab" or "GrabParry"
            if folder:FindFirstChild(selName) then
                baseParryAnim = folder[selName]
            end
        end
    end

    parryAnimation = LocalPlayer.Character.Humanoid.Animator:LoadAnimation(baseParryAnim)
    parryAnimation:Play()
end

function AutoParry.fetchBalls()
    local balls = {}
    for _, b in pairs(Workspace.Balls:GetChildren()) do
        if b:GetAttribute("realBall") then
            b.CanCollide = false
            table.insert(balls, b)
        end
    end
    return balls
end

function AutoParry.Get_Ball()
    return Spam.FetchBall()
end

function AutoParry.computeParryData(mode)
    local eventTable = {}
    local cam = Workspace.CurrentCamera
    if lastInputType == Enum.UserInputType.MouseButton1 or
       lastInputType == Enum.UserInputType.MouseButton2 or
       lastInputType == Enum.UserInputType.Keyboard then
        local mPos = UserInputService:GetMouseLocation()
        currentMousePos = { mPos.X, mPos.Y }
    else
        currentMousePos = { cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2 }
    end

    for _, ent in ipairs(AliveGroup:GetChildren()) do
        eventTable[tostring(ent)] = cam:WorldToScreenPoint(ent.PrimaryPart.Position)
    end

    local camPos = cam.CFrame.Position
    if mode == "Custom" then
        return { 0, cam.CFrame, eventTable, currentMousePos }
    elseif mode == "Backwards" then
        return { 0, CFrame.new(camPos, camPos - (cam.CFrame.LookVector * 1000)), eventTable, currentMousePos }
    elseif mode == "Random" then
        return { 0, CFrame.new(camPos, Vector3.new(math.random(-3000,3000), math.random(-3000,3000), math.random(-3000,3000))), eventTable, currentMousePos }
    elseif mode == "Straight" then
        return { 0, CFrame.new(camPos, camPos + (cam.CFrame.LookVector * 1000)), eventTable, currentMousePos }
    elseif mode == "Up" then
        return { 0, CFrame.new(camPos, camPos + (cam.CFrame.UpVector * 1000)), eventTable, currentMousePos }
    elseif mode == "Right" then
        return { 0, CFrame.new(camPos, camPos + (cam.CFrame.RightVector * 1000)), eventTable, currentMousePos }
    elseif mode == "Left" then
        return { 0, CFrame.new(camPos, camPos - (cam.CFrame.RightVector * 1000)), eventTable, currentMousePos }
    elseif mode == "Dot" then
        local ball = AutoParry.Get_Ball()
        if ball then
            return { 0, CFrame.new(camPos, ball.Position), eventTable, currentMousePos }
        else
            return { 0, cam.CFrame, eventTable, currentMousePos }
        end
    else
        return mode
    end
end

local function canProcessParry()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if hrp:FindFirstChild("SingularityCape") then
        getgenv().SingularityActive = true
    else
        getgenv().SingularityActive = false
    end

    if getgenv().DeathSlashActive and getgenv().DeathSlashParryCount >= 34 then
        return false
    end

    return not getgenv().SingularityActive and not getgenv().AerodynamicActive
end

AutoParry.Parry = function(isSpam)
    if tick() - State.lastParryTime < State.parryCooldown + 0.02 then return false end
    State.lastParryTime = tick()
    
    if State.autoParryAccuracy < 100 then
        local accuracy = State.randomizedParryAccuracy and math.random(1, State.autoParryAccuracy * 0.8) or State.autoParryAccuracy * 0.8
        if math.random(1, 100) > accuracy then
            StatsData.MissedParries += 1
            return false
        end
    end

    local presses = isSpam and State.spamSpeed or 1

    if State.activeMethod == "F Key" then
        for i = 1, presses do
            VirtualInput:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            VirtualInput:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            task.wait(0.01)
        end
    else
        local Parry_Data = AutoParry.computeParryData(State.selectedParryMode)
        for i = 1, presses do
            for Remote, Args in pairs(State.remotes) do
                Remote:FireServer(Args, State.parryKey, Parry_Data[1], Parry_Data[2], Parry_Data[3], Parry_Data[4])
            end
            task.wait(0.005)
        end
    end

    if State.Parries > 7 then
        return false
    end
    State.Parries = State.Parries + 1
    StatsData.TotalParries += 1
    
    task.delay(0.6, function()
        if State.Parries > 0 then
            State.Parries = State.Parries - 1
        end
    end)

    if getgenv().DeathSlashActive then
        getgenv().DeathSlashParryCount = getgenv().DeathSlashParryCount + 1
        if getgenv().DeathSlashParryCount >= 35 then
            getgenv().DeathSlashActive = false
            getgenv().DeathSlashParryCount = 0
        end
    end
    return true
end

function AutoParry.triggerParry(mode)
    if not canProcessParry() then return end
    State.selectedParryMode = mode
    return AutoParry.Parry(false)
end

function AutoParry.detectCurve()
    local ball = AutoParry.Get_Ball()
    if not ball or not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local zoom = ball:FindFirstChild("zoomies")
    if not zoom then return false end

    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    local speed = zoom.VectorVelocity.Magnitude
    local distance = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Magnitude
    local dot = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Unit:Dot(zoom.VectorVelocity.Unit)

    if speed < CONFIG.CURVE_DETECTION.MIN_SPEED or distance < 10 then return false
    if math.abs(dot) > 0.6 then return false end

    StatsData.CurvedBallsDetected += 1
    return true
end

local BallUtils = {}

function BallUtils.GetBall()
    return AutoParry.Get_Ball()
end

function BallUtils.GetAllBalls()
    return AutoParry.fetchBalls()
end

function BallUtils.DetectInfinity(ball)
    if not ball or not ball:FindFirstChild('zoomies') then
        return false
    end

    local velocity = ball.zoomies.VectorVelocity
    local speed = velocity.Magnitude

    if speed > 500 or speed == math.huge or speed ~= speed then
        StatsData.InfinityDetections += 1
        return true
    end

    return false
end

function BallUtils.Closest_Player()
    return Spam.Get_Closest()
end

function BallUtils.Get_Ball_Properties(ball)
    local Ball_Velocity = ball.AssemblyLinearVelocity or (ball:FindFirstChild('zoomies') and ball.zoomies.VectorVelocity) or Vector3.zero
    local Ball_Direction = (Player.Character.PrimaryPart.Position - ball.Position).Unit
    local Ball_Distance = (Player.Character.PrimaryPart.Position - ball.Position).Magnitude
    local Ball_Dot = Ball_Direction:Dot(Ball_Velocity.Unit)

    return {
        Velocity = Ball_Velocity,
        Direction = Ball_Direction,
        Distance = Ball_Distance,
        Dot = Ball_Dot
    }
end

function BallUtils.Get_Entity_Properties()
    return Spam.Entity_Properties()
end

function BallUtils.Spam_Service(ball)
    return Spam.CalcAccuracy({
        BallProps = Spam.Ball_Properties(),
        EntityProps = Spam.Entity_Properties(),
        Ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 12
    })
end

function BallUtils.TeleportBall(instant)
    local ball = BallUtils.GetBall()
    if not ball or not Player.Character or not Player.Character.PrimaryPart then return end

    if instant then
        ball.CFrame = Player.Character.PrimaryPart.CFrame + Player.Character.PrimaryPart.CFrame.LookVector * 5
        StatsData.BallsTPed += 1
        Library.SendNotification({
            title = "Instant Ball TP",
            text = "Ball teleported instantly",
            duration = 2
        })
    else
        local tween = TweenService:Create(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
            CFrame = Player.Character.PrimaryPart.CFrame + Player.Character.PrimaryPart.CFrame.LookVector * 5
        })
        tween:Play()
        StatsData.BallsTPed += 1
        Library.SendNotification({
            title = "Ball TP",
            text = "Ball teleported smoothly",
            duration = 2
        })
    end
end

local ParrySystem = {}

function ParrySystem.GetParryData(parryType)
    return AutoParry.computeParryData(parryType)
end

function ParrySystem.Parry(parryType, isLobby)
    if not State.autoParryEnabled and not isLobby then return false end

    if isLobby and State.lobbyAPEnabled then
        local accuracy = State.randomizedAccuracy and math.random(1, State.lobbyAccuracy) or State.lobbyAccuracy
        if math.random(1, 100) > accuracy then
            return false
        end
    end

    return AutoParry.Parry(false)
end

function ParrySystem.ManualSpam()
    if not State.manualSpamEnabled then return end

    for i = 1, 3 do
        AutoParry.Parry(false)
        task.wait(0.15)
    end

    StatsData.ManualSpamUses += 1
    Library.SendNotification({
        title = "Manual Spam",
        text = "Executed 3 rapid parries",
        duration = 2
    })
end

function ParrySystem.Triggerbot(ball)
    if not State.triggerbotEnabled or not ball then return end

    local target = ball:GetAttribute('target')
    if target == tostring(Player) then
        if BallUtils.DetectInfinity(ball) then
            Library.SendNotification({
                title = "Triggerbot",
                text = "Infinity ball detected - Auto parried",
                duration = 2
            })
        end
        
        AutoParry.Parry(false)
        StatsData.TriggerbotActivations += 1
        
        Library.SendNotification({
            title = "Triggerbot",
            text = "Ball targeting detected - Auto parried",
            duration = 2
        })
    end
end

local function AutoSpam(ball)
    if not ball or not ball:FindFirstChild('zoomies') or not State.autoSpamEnabled then return end

    local Ball = Spam.FetchBall()
    if not Ball or not Ball:FindFirstChild("zoomies") then
        State.Spamming = false
        return
    end

    local Char = LocalPlayer.Character
    local HRP = Char and Char.PrimaryPart
    if not HRP then
        State.Spamming = false
        return
    end

    local ping = State.ServerStatsItem["Data Ping"]:GetValue() / 12
    local ballProps = Spam.Ball_Properties()
    local entityProps = Spam.Entity_Properties()

    local acc = Spam.CalcAccuracy({
        BallProps = ballProps,
        EntityProps = entityProps,
        Ping = ping
    })

    State.Spamming = entityProps.Distance <= acc * 0.95 and ballProps.Distance * 0.95 <= acc and State.Parries > 1

    if State.Spamming then
        for _ = 1, State.spamSpeed do
            task.spawn(function()
                AutoParry.Parry(false)
            end)
            task.wait(0.01)
        end
    end
end

local PlayerFeatures = {}

function PlayerFeatures.SetSpeed(speed)
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid.WalkSpeed = speed
    end
end

function PlayerFeatures.ToggleSpinbot()
    if State.spinbotEnabled then
        local spinConnection
        spinConnection = RunService.Heartbeat:Connect(function()
            if not State.spinbotEnabled then
                spinConnection:Disconnect()
                return
            end

            if Player.Character and Player.Character.PrimaryPart then
                Player.Character.PrimaryPart.CFrame = Player.Character.PrimaryPart.CFrame * CFrame.Angles(0, math.rad(10), 0)
            end
        end)
    end
end

function PlayerFeatures.SetFOV(fov)
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = fov
    end
end

function PlayerFeatures.ToggleFly()
    if not Player.Character or not Player.Character.PrimaryPart then return end

    if State.flyEnabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = Player.Character.PrimaryPart
        
        local flyConnection
        flyConnection = RunService.Heartbeat:Connect(function()
            if not State.flyEnabled then
                bodyVelocity:Destroy()
                flyConnection:Disconnect()
                return
            end     
            
            local camera = workspace.CurrentCamera
            local velocity = Vector3.new(0, 0, 0)
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                velocity = velocity + camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                velocity = velocity - camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                velocity = velocity - camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                velocity = velocity + camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                velocity = velocity + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                velocity = velocity - Vector3.new(0, 1, 0)
            end
            
            bodyVelocity.Velocity = velocity * 50
        end)
    end
end

function PlayerFeatures.ToggleEmotes()
    if State.emotesEnabled then
        task.spawn(function()
            while State.emotesEnabled do
                task.wait(math.random(5, 15))
                if State.emotesEnabled and Player.Character and Player.Character:FindFirstChild("Humanoid") then
                    local emotes = {"wave", "point", "dance", "dance2", "dance3", "cheer"}
                    local randomEmote = emotes[math.random(1, #emotes)]
                    Player.Character.Humanoid:PlayEmote(randomEmote)
                end
            end
        end)
    end
end

function PlayerFeatures.TogglePlayerEffects()
    if State.playerEffectsEnabled then
        local humanoid = Player.Character and Player.Character:FindFirstChild("Humanoid")
        if humanoid then
            local bodyColors = Player.Character:FindFirstChild("Body Colors")
            if bodyColors then
                task.spawn(function()
                    while State.playerEffectsEnabled do
                        task.wait(0.1)
                        local hue = (tick() % 3) / 3
                        local color = Color3.fromHSV(hue, 1, 1)
                        bodyColors.HeadColor3 = color
                        bodyColors.LeftArmColor3 = color
                        bodyColors.RightArmColor3 = color
                        bodyColors.LeftLegColor3 = color
                        bodyColors.RightLegColor3 = color
                        bodyColors.TorsoColor3 = color
                    end
                end)
            end
        end
    end
end

local WorldFeatures = {}

function WorldFeatures.SetCustomSky()
    if State.customSkyEnabled then
        local sky = Instance.new("Sky")
        sky.SkyboxBk = "rbxassetid://12064107"
        sky.SkyboxDn = "rbxassetid://12064152"
        sky.SkyboxFt = "rbxassetid://12064121"
        sky.SkyboxLf = "rbxassetid://12064115"
        sky.SkyboxRt = "rbxassetid://12064131"
        sky.SkyboxUp = "rbxassetid://12064143"
        sky.Parent = Lighting
    else
        for _, obj in pairs(Lighting:GetChildren()) do
            if obj:IsA("Sky") then
                obj:Destroy()
            end
        end
    end
end

function WorldFeatures.ApplyWorldFilter()
    if State.worldFilterEnabled then
        local colorCorrection = Instance.new("ColorCorrectionEffect")
        colorCorrection.Brightness = -0.2
        colorCorrection.Contrast = 0.3
        colorCorrection.Saturation = -0.5
        colorCorrection.TintColor = Color3.new(0.8, 0.9, 1)
        colorCorrection.Parent = Lighting
    else
        for _, obj in pairs(Lighting:GetChildren()) do
            if obj:IsA("ColorCorrectionEffect") then
                obj:Destroy()
            end
        end
    end
end

function WorldFeatures.CreateBallTrail(ball)
    if not ball or not State.ballTrailEnabled then return end

    local trail = Instance.new("Trail")
    trail.Texture = "rbxassetid://446111271"
    trail.TextureMode = Enum.TextureMode.Stretch
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 3),
        NumberSequenceKeypoint.new(0.5, 2),
        NumberSequenceKeypoint.new(1, 0)
    })
    trail.Transparency = NumberSequence.new(0.2)
    trail.Lifetime = 1.0

    local attachment0 = Instance.new("Attachment", ball)
    local attachment1 = Instance.new("Attachment", ball)
    attachment1.Position = Vector3.new(0, 0, -1)

    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    trail.Parent = ball

    RunService.Heartbeat:Connect(function()
        if ball.Parent and State.ballTrailEnabled then
            local hue = (tick() % 3) / 3
            trail.Color = ColorSequence.new(Color3.fromHSV(hue, 1, 1))
        else
            trail:Destroy()
        end
    end)
end

local Drawings = {}

local function clearVisualizer()
    for _, drawing in ipairs(Drawings) do
        if drawing and drawing.Remove then
            pcall(function() drawing:Remove() end)
        end
    end
    table.clear(Drawings)
end

RunService.RenderStepped:Connect(function()
    if not State.visualiserEnabled then
        clearVisualizer()
        return
    end

    clearVisualizer()

    local ball = Spam.FetchBall()
    if not ball then return end

    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local root = character.HumanoidRootPart

    local camera = Workspace.CurrentCamera
    if not camera then return end

    local ballScreenPos, onScreen = camera:WorldToViewportPoint(ball.Position)
    if not onScreen then return end

    local circle = Drawing.new("Circle")
    circle.Position = Vector2.new(ballScreenPos.X, ballScreenPos.Y)
    circle.Radius = 35
    circle.Thickness = 2
    circle.Color = Color3.fromRGB(0, 255, 127)
    circle.Filled = false
    circle.Transparency = 0.9
    circle.Visible = true
    Drawings[#Drawings + 1] = circle

    local playerScreenPos = camera:WorldToViewportPoint(root.Position)
    local line = Drawing.new("Line")
    line.From = Vector2.new(playerScreenPos.X, playerScreenPos.Y)
    line.To = Vector2.new(ballScreenPos.X, ballScreenPos.Y)
    line.Color = Color3.fromRGB(0, 170, 255)
    line.Thickness = 2
    line.Transparency = 0.8
    line.Visible = true
    Drawings[#Drawings + 1] = line

    local props = Spam.Ball_Properties()
    local dotStrength = math.clamp((props.Dot + 1) / 2, 0, 1)

    local bar = Drawing.new("Square")
    bar.Position = Vector2.new(ballScreenPos.X - 20, ballScreenPos.Y + 40)
    bar.Size = Vector2.new(40 * dotStrength, 4)
    bar.Color = Color3.fromRGB(255 * (1 - dotStrength), 255 * dotStrength, 0)
    bar.Filled = true
    bar.Transparency = 0.9
    bar.Visible = true
    Drawings[#Drawings + 1] = bar

    local bg = Drawing.new("Square")
    bg.Position = Vector2.new(ballScreenPos.X - 20, ballScreenPos.Y + 40)
    bg.Size = Vector2.new(40, 4)
    bg.Color = Color3.fromRGB(20, 20, 20)
    bg.Filled = false
    bg.Thickness = 1.5
    bg.Transparency = 0.9
    bg.Visible = true
    Drawings[#Drawings + 1] = bg
end)

local AbilityDrawings = {}

local function clearAbilityESP()
    for _, obj in ipairs(AbilityDrawings) do
        if obj and obj.Remove then
            pcall(function() obj:Remove() end)
        end
    end
    table.clear(AbilityDrawings)
end

RunService.RenderStepped:Connect(function()
    if not State.abilityESPEnabled then
        clearAbilityESP()
        return
    end

    clearAbilityESP()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local ability = player.Character:GetAttribute("Ability")

            if ability and typeof(ability) == "string" then
                local screenPos, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
                if onScreen then
                    local text = Drawing.new("Text")
                    text.Text = "[" .. ability .. "]"
                    text.Position = Vector2.new(screenPos.X - 30, screenPos.Y)
                    text.Color = Color3.fromRGB(255, 175, 0)
                    text.Size = 14
                    text.Center = false
                    text.Outline = true
                    text.Visible = true
                    AbilityDrawings[#AbilityDrawings + 1] = text
                end
            end
        end
    end
end)

local MiscFeatures = {}

function MiscFeatures.ToggleNoRender()
    if State.noRenderEnabled then
        RunService:Set3dRenderingEnabled(false)
    else
        RunService:Set3dRenderingEnabled(true)
    end
end

function MiscFeatures.ToggleAdvancedFPSBoost()
    if State.advancedFPSBoost then
        settings().Rendering.QualityLevel = 1
        UserSettings():GetService("UserGameSettings").SavedQualityLevel = 1
        
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                obj.Enabled = false
            elseif obj:IsA("Explosion") then
                obj.Visible = false
            elseif obj:IsA("Fire") or obj:IsA("Smoke") then
                obj.Enabled = false
            elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                obj.Enabled = false
            end
        end

        for _, sound in pairs(workspace:GetDescendants()) do
            if sound:IsA("Sound") then
                sound.Volume = 0
            end
        end
        
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        
        for _, gui in pairs(Player.PlayerGui:GetChildren()) do
            if gui.Name ~= "Chat" and gui.Name ~= "Backpack" and gui.Name ~= "PlayerList" then
                if gui:IsA("ScreenGui") then
                    gui.Enabled = false
                end
            end
        end
        
        Library.SendNotification({
            title = "FPS Boost",
            text = "Maximum performance optimization enabled",
            duration = 3
        })
    else
        settings().Rendering.QualityLevel = Enum.SavedQualitySetting.Automatic
        UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.Automatic
        
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                obj.Enabled = true
            elseif obj:IsA("Explosion") then
                obj.Visible = true
            elseif obj:IsA("Fire") or obj:IsA("Smoke") then
                obj.Enabled = true
            elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                obj.Enabled = true
            end
        end
        
        for _, sound in pairs(workspace:GetDescendants()) do
            if sound:IsA("Sound") then
                sound.Volume = 0.5
            end
        end
        
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 100000
        Lighting.Brightness = 2
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
        
        for _, gui in pairs(Player.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                gui.Enabled = true
            end
        end
        
        Library.SendNotification({
            title = "FPS Boost",
            text = "Performance optimization disabled",
            duration = 3
        })
    end
end

function MiscFeatures.ToggleBallStats()
    if State.ballStatsEnabled then
        local gui = Instance.new("ScreenGui")
        gui.Name = "BallStatsGUI"
        gui.Parent = Player.PlayerGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 250, 0, 120)
        frame.Position = UDim2.new(0, 10, 0, 100)
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        frame.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.Parent = frame
        
        RunService.Heartbeat:Connect(function()
            if State.ballStatsEnabled then
                local ball = BallUtils.GetBall()
                if ball and ball:FindFirstChild('zoomies') then
                    local speed = ball.zoomies.VectorVelocity.Magnitude
                    local distance = (Player.Character.PrimaryPart.Position - ball.Position).Magnitude
                    local target = ball:GetAttribute("target") or "None"
                    label.Text = string.format("Speed: %.1f\nDistance: %.1f\nTarget: %s", speed, distance, target)
                else
                    label.Text = "No ball detected"
                end
            else
                gui:Destroy()
            end
        end)
    else
        local gui = Player.PlayerGui:FindFirstChild("BallStatsGUI")
        if gui then gui:Destroy() end
    end
end

function MiscFeatures.ToggleAutoClaimRewards()
    if State.autoClaimRewardsEnabled then
        task.spawn(function()
            while State.autoClaimRewardsEnabled do
                task.wait(1)
                for _, remote in pairs(ReplicatedStorage.Remotes:GetChildren()) do
                    if remote.Name:lower():find("claim") or remote.Name:lower():find("reward") then
                        pcall(function()
                            remote:FireServer()
                        end)
                    end
                end
            end
        end)
    end
end

function MiscFeatures.ToggleStreamerMode()
    if State.streamerModeEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character and player.Character:FindFirstChild("Head") then
                local billboard = player.Character.Head:FindFirstChild("BillboardGui")
                if billboard then
                    billboard.Enabled = false
                end
            end
        end

        if Player.Character then
            for _, accessory in pairs(Player.Character:GetChildren()) do
                if accessory:IsA("Accessory") then
                    accessory:Destroy()
                end
            end
            
            local baconHair = Instance.new("Accessory")
            local handle = Instance.new("Part")
            handle.Name = "Handle"
            handle.Size = Vector3.new(1, 1, 1)
            handle.CanCollide = false
            handle.Parent = baconHair
            
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshId = "rbxassetid://1374148"
            mesh.TextureId = "rbxassetid://16627529"
            mesh.Parent = handle
            
            local weld = Instance.new("Weld")
            weld.Part0 = Player.Character.Head
            weld.Part1 = handle
            weld.C0 = CFrame.new(0, 0.5, 0)
            weld.Parent = handle
            
            baconHair.Parent = Player.Character
            
            if Player.Character:FindFirstChild("Right Leg") then
                Player.Character["Right Leg"].Transparency = 1
                Player.Character["Right Leg"].CanCollide = false
            end
            
            if Player.Character:FindFirstChild("Head") then
                for _, part in pairs(Player.Character.Head:GetChildren()) do
                    if part:IsA("Decal") then
                        part.Transparency = 1
                    end
                end
                Player.Character.Head.Transparency = 1
            end
        end

        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
        
        Library.SendNotification({
            title = "Streamer Mode",
            text = "Privacy mode enabled with bacon skin",
            duration = 3
        })
    else
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character and player.Character:FindFirstChild("Head") then
                local billboard = player.Character.Head:FindFirstChild("BillboardGui")
                if billboard then
                    billboard.Enabled = true
                end
            end
        end
        
        Player.CharacterAdded:Connect(function(character)
        end)
        Player:LoadCharacter()
        
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
        
        Library.SendNotification({
            title = "Streamer Mode",
            text = "Privacy mode disabled",
            duration = 3
        })
    end
end

function MiscFeatures.SetPingRegion(region)
    if not State.pingRegionEnabled then return end
    
    local regionServers = {
        ["US East"] = "us-east-1",
        ["US West"] = "us-west-1",
        ["Europe"] = "eu-west-1",
        ["Asia"] = "ap-southeast-1",
        ["Australia"] = "ap-southeast-2",
        ["South America"] = "sa-east-1"
    }
    
    local targetRegion = regionServers[region]
    if targetRegion then
        Library.SendNotification({
            title = "Ping Region",
            text = "Attempting to connect to " .. region .. " servers",
            duration = 3
        })
    end
end

local function InitializeAutoParry()
    State.connManager["Auto Parry"] = RunService.PreSimulation:Connect(function()
        if not State.autoParryEnabled then return end

        local ball = AutoParry.Get_Ball()
        local ballList = AutoParry.fetchBalls()
        for _, b in ipairs(ballList) do
            if not b then repeat task.wait(0.1) until b end
            local zoom = b:FindFirstChild("zoomies")
            if not zoom then return end
            b:GetAttributeChangedSignal("target"):Once(function() State.parryFlag = false end)
            if State.parryFlag then return end
            local ballTarget = b:GetAttribute("target")
            local primaryTarget = ball and ball:GetAttribute("target")
            local vel = zoom.VectorVelocity
            local dist = (LocalPlayer.Character.PrimaryPart.Position - b.Position).Magnitude
            local spd = vel.Magnitude
            local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            local parryThresh = (spd / 4.5) + (ping * spd * 1.2)
            local curved = AutoParry.detectCurve()
            
            ParrySystem.Triggerbot(b)
            
            if ballTarget == tostring(LocalPlayer) and getgenv().AerodynamicActive then
                if tick() - (getgenv().AerodynamicTime or 0) >= (getgenv().AerodynamicDelay or 0.6) then
                    getgenv().AerodynamicActive = false
                end
                return
            end
            if primaryTarget == tostring(LocalPlayer) and curved then 
                return 
            end
            if ballTarget == tostring(LocalPlayer) and dist <= parryThresh * 0.9 then
                if AutoParry.triggerParry(State.selectedParryMode) then
                    StatsData.SuccessfulParries += 1
                    AutoParry.playParryAnimation()
                end
                State.parryFlag = true
            end
            local lastCycle = tick()
            repeat 
                RunService.PreSimulation:Wait() 
            until (tick() - lastCycle) >= 1.2 or not State.parryFlag
            State.parryFlag = false
        end
    end)

    State.connManager["Auto Spam"] = RunService.Heartbeat:Connect(function()
        if not State.autoSpamEnabled then return end
        AutoSpam(AutoParry.Get_Ball())
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == State.manualSpamKey then
        ParrySystem.ManualSpam()
    elseif input.KeyCode == State.ballTPKey then
        BallUtils.TeleportBall(false)
    elseif input.KeyCode == State.instantBallTPKey then
        BallUtils.TeleportBall(true)
    elseif input.KeyCode == State.lobbyAPKey and State.lobbyAPEnabled then
        AutoParry.Parry(false)
        Library.SendNotification({
            title = "Lobby Auto Parry",
            text = "Manual parry executed",
            duration = 2
        })
    elseif input.KeyCode == State.parryTypeKey then
        local types = {}
        for _, v in pairs(CONFIG.PARRY_TYPES) do
            table.insert(types, v)
        end
        
        local currentIndex = 1
        for i, v in ipairs(types) do
            if v == State.selectedParryType then
                currentIndex = i
                break
            end
        end
        
        currentIndex = currentIndex % #types + 1
        State.selectedParryType = types[currentIndex]
        State.selectedParryMode = State.selectedParryType
        
        Library.SendNotification({
            title = "Hotkey Parry Type",
            text = "Switched to " .. State.selectedParryType,
            duration = 2
        })
    end
end)

workspace.Runtime.ChildAdded:Connect(function(value)
    if value.Name == 'Tornado' then
        State.aerodynamicTime = tick()
        State.isAerodynamic = true
        getgenv().AerodynamicTime = tick()
        getgenv().AerodynamicActive = true
    end
end)

workspace.Balls.ChildAdded:Connect(function(ball)
    State.hasParried = false
    State.parryFlag = false
    task.wait(0.1)
    WorldFeatures.CreateBallTrail(ball)
end)

workspace.Balls.ChildRemoved:Connect(function()
    State.parryCount = 0
    State.hasParried = false
    State.parryFlag = false
    State.Parries = 0
    State.Spamming = false
end)

ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
    StatsData.SuccessfulParries += 1
end)

ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(_, root)
    if root.Parent and root.Parent ~= Player.Character then
        StatsData.SuccessfulParries += 1
    end
end)

local auto_parry_tab = main:create_tab("Auto Parry", "rbxassetid://76499042599127")
local combat_tab = main:create_tab("Combat", "rbxassetid://76499042599127")
local player_tab = main:create_tab("Player", "rbxassetid://126017907477623")
local world_tab = main:create_tab("World", "rbxassetid://10723415040")
local misc_tab = main:create_tab("Misc", "rbxassetid://10709782497")
local stats_tab = main:create_tab("Statistics", "rbxassetid://10734950020")

local auto_parry_module = auto_parry_tab:create_module({
    title = "Auto Parry System",
    flag = "auto_parry_system",
    description = "Automatic parrying system",
    section = "left",
    callback = function(value)
        State.autoParryEnabled = value
        Library.SendNotification({
            title = "Auto Parry",
            text = value and "Enabled" or "Disabled",
            duration = 3
        })
    end
})

auto_parry_module:create_checkbox({
    title = "Enable Auto Parry",
    flag = "auto_parry_enabled",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.autoParryEnabled = value
        end
    end
})

auto_parry_module:create_slider({
    title = "Parry Accuracy",
    flag = "parry_accuracy",
    maximum_value = 100,
    minimum_value = 1,
    value = State.autoParryAccuracy,
    round_number = true,
    callback = function(value)
        State.autoParryAccuracy = value
    end
})

auto_parry_module:create_checkbox({
    title = "Randomized Accuracy",
    flag = "randomized_accuracy",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.randomizedParryAccuracy = value
        end
    end
})

auto_parry_module:create_checkbox({
    title = "Auto Spam",
    flag = "auto_spam",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.autoSpamEnabled = value
        end
    end
})

auto_parry_module:create_slider({
    title = "Spam Speed",
    flag = "spam_speed",
    maximum_value = 30,
    minimum_value = 1,
    value = State.spamSpeed,
    round_number = true,
    callback = function(value)
        State.spamSpeed = value
    end
})

local parry_config_module = auto_parry_tab:create_module({
    title = "Parry Configuration",
    flag = "parry_config",
    description = "Configure parry settings",
    section = "right",
    callback = function(value) end
})

local parryTypeOptions = {}
for _, parryType in pairs(CONFIG.PARRY_TYPES) do
    table.insert(parryTypeOptions, parryType)
end

parry_config_module:create_dropdown({
    title = "Parry Style",
    flag = "parry_style",
    options = parryTypeOptions,
    multi_dropdown = false,
    maximum_options = 1,
    callback = function(value)
        State.selectedParryType = value
        State.selectedParryMode = value
    end
})

parry_config_module:create_checkbox({
    title = "Curve Detection",
    flag = "curve_detection",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.advancedCurveDetection = value
        end
    end
})

parry_config_module:create_slider({
    title = "Curve Sensitivity",
    flag = "curve_sensitivity",
    maximum_value = 100,
    minimum_value = 10,
    value = State.curveDetectionSensitivity * 100,
    round_number = true,
    callback = function(value)
        State.curveDetectionSensitivity = value / 100
    end
})

local combat_module = combat_tab:create_module({
    title = "Combat Features",
    flag = "combat_features",
    description = "Combat related features",
    section = "left",
    callback = function(value) end
})

combat_module:create_checkbox({
    title = "Manual Spam",
    flag = "manual_spam",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.manualSpamEnabled = value
        end
    end
})

combat_module:create_checkbox({
    title = "Triggerbot",
    flag = "triggerbot",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.triggerbotEnabled = value
        end
    end
})

combat_module:create_checkbox({
    title = "Lobby Auto Parry",
    flag = "lobby_ap",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.lobbyAPEnabled = value
        end
    end
})

combat_module:create_slider({
    title = "Lobby Accuracy",
    flag = "lobby_accuracy",
    maximum_value = CONFIG.LOBBY_AP.MAX_ACCURACY,
    minimum_value = CONFIG.LOBBY_AP.MIN_ACCURACY,
    value = State.lobbyAccuracy,
    round_number = true,
    callback = function(value)
        State.lobbyAccuracy = value
    end
})

local ball_module = combat_tab:create_module({
    title = "Ball Features",
    flag = "ball_features",
    description = "Ball manipulation features",
    section = "right",
    callback = function(value) end
})

ball_module:create_feature({
    title = "Ball TP",
    flag = "ball_tp",
    disablecheck = true,
    button_callback = function()
        BallUtils.TeleportBall(false)
    end
})

ball_module:create_feature({
    title = "Instant Ball TP",
    flag = "instant_ball_tp",
    disablecheck = true,
    button_callback = function()
        BallUtils.TeleportBall(true)
    end
})

local movement_module = player_tab:create_module({
    title = "Movement",
    flag = "movement",
    description = "Player movement features",
    section = "left",
    callback = function(value) end
})

movement_module:create_checkbox({
    title = "Speed",
    flag = "speed_enabled",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.speedEnabled = value
            if value then
                if Player.Character and Player.Character:FindFirstChild("Humanoid") then
                    Player.Character.Humanoid.WalkSpeed = State.speedValue
                end
            else
                if Player.Character and Player.Character:FindFirstChild("Humanoid") then
                    Player.Character.Humanoid.WalkSpeed = 16
                end
            end
        end
    end
})

movement_module:create_slider({
    title = "Speed Value",
    flag = "speed_value",
    maximum_value = 100,
    minimum_value = 16,
    value = State.speedValue,
    round_number = true,
    callback = function(value)
        State.speedValue = value
        if State.speedEnabled and Player.Character and Player.Character:FindFirstChild("Humanoid") then
            Player.Character.Humanoid.WalkSpeed = value
        end
    end
})

movement_module:create_checkbox({
    title = "Spinbot",
    flag = "spinbot",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.spinbotEnabled = value
            PlayerFeatures.ToggleSpinbot()
        end
    end
})

movement_module:create_checkbox({
    title = "Fly",
    flag = "fly",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.flyEnabled = value
            PlayerFeatures.ToggleFly()
        end
    end
})

local effects_module = player_tab:create_module({
    title = "Effects",
    flag = "effects",
    description = "Player visual effects",
    section = "right",
    callback = function(value) end
})

effects_module:create_checkbox({
    title = "Field of View",
    flag = "fov_enabled",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.fovEnabled = value
            if value then
                workspace.CurrentCamera.FieldOfView = State.fovValue
            else
                workspace.CurrentCamera.FieldOfView = 70
            end
        end
    end
})

effects_module:create_slider({
    title = "FOV Value",
    flag = "fov_value",
    maximum_value = 120,
    minimum_value = 30,
    value = State.fovValue,
    round_number = true,
    callback = function(value)
        State.fovValue = value
        if State.fovEnabled then
            workspace.CurrentCamera.FieldOfView = value
        end
    end
})

effects_module:create_checkbox({
    title = "Emotes",
    flag = "emotes",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.emotesEnabled = value
            PlayerFeatures.ToggleEmotes()
        end
    end
})

effects_module:create_checkbox({
    title = "Player Effects",
    flag = "player_effects",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.playerEffectsEnabled = value
            PlayerFeatures.TogglePlayerEffects()
        end
    end
})

local world_visual_module = world_tab:create_module({
    title = "Visual",
    flag = "world_visual",
    description = "World visual features",
    section = "left",
    callback = function(value) end
})

world_visual_module:create_checkbox({
    title = "Custom Sky",
    flag = "custom_sky",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.customSkyEnabled = value
            WorldFeatures.SetCustomSky()
        end
    end
})

world_visual_module:create_checkbox({
    title = "World Filter",
    flag = "world_filter",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.worldFilterEnabled = value
            WorldFeatures.ApplyWorldFilter()
        end
    end
})

world_visual_module:create_checkbox({
    title = "Ball Trail",
    flag = "ball_trail",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.ballTrailEnabled = value
        end
    end
})

world_visual_module:create_checkbox({
    title = "Parry Visualizer",
    flag = "parry_visualizer",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.visualiserEnabled = value
        end
    end
})

local esp_module = world_tab:create_module({
    title = "ESP",
    flag = "esp",
    description = "ESP features",
    section = "right",
    callback = function(value) end
})

esp_module:create_checkbox({
    title = "Ability ESP",
    flag = "ability_esp",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.abilityESPEnabled = value
        end
    end
})

local utility_module = misc_tab:create_module({
    title = "Utility",
    flag = "utility",
    description = "Utility features",
    section = "left",
    callback = function(value) end
})

utility_module:create_checkbox({
    title = "No Render",
    flag = "no_render",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.noRenderEnabled = value
            MiscFeatures.ToggleNoRender()
        end
    end
})

utility_module:create_feature({
    title = "FPS Boost",
    flag = "fps_boost",
    disablecheck = true,
    button_callback = function()
        State.advancedFPSBoost = not State.advancedFPSBoost
        MiscFeatures.ToggleAdvancedFPSBoost()
    end
})

utility_module:create_checkbox({
    title = "Ball Stats",
    flag = "ball_stats",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.ballStatsEnabled = value
            MiscFeatures.ToggleBallStats()
        end
    end
})

utility_module:create_checkbox({
    title = "Auto Claim Rewards",
    flag = "auto_claim",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.autoClaimRewardsEnabled = value
            MiscFeatures.ToggleAutoClaimRewards()
        end
    end
})

utility_module:create_dropdown({
    title = "Select Region",
    flag = "region_select",
    options = CONFIG.REGIONS,
    multi_dropdown = false,
    maximum_options = 1,
    callback = function(value)
        State.selectedRegion = value
        MiscFeatures.SetPingRegion(value)
    end
})

local custom_module = misc_tab:create_module({
    title = "Customization",
    flag = "customization",
    description = "Customization features",
    section = "right",
    callback = function(value) end
})

custom_module:create_checkbox({
    title = "Enable Skin Changer",
    flag = "skin_changer_enabled",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            getgenv().Skin_Changer = value
            if value then
                if getgenv().ByteLibrary then
                    getgenv().ByteLibrary.Update(Player.Character)
                end
                Library.SendNotification({
                    title = "Skin Changer",
                    text = "Enabled - Changed to: " .. getgenv().Sword_Model,
                    duration = 3
                })
            else
                if Player.Character and getgenv().ByteLibrary then
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local Shared = ReplicatedStorage:WaitForChild("Shared")
                    local ReplicatedInstances = Shared:WaitForChild("ReplicatedInstances")
                    local Swords = require(ReplicatedInstances:WaitForChild("Swords"))
                    local originalSword = getgenv().originalSword or "Base Sword"
                    Swords:EquipSwordTo(Player.Character, originalSword)
                    Player.Character:SetAttribute('CurrentlyEquippedSword', originalSword)
                end
                Library.SendNotification({
                    title = "Skin Changer",
                    text = "Disabled - Restored original sword",
                    duration = 3
                })
            end
        end
    end
})

custom_module:create_textbox({
    title = "Sword Name",
    placeholder = "Enter sword name...",
    flag = "sword_name",
    callback = function(swordName)
        if swordName and swordName ~= "" then
            getgenv().Sword_Model = swordName
            getgenv().Sword_Animation = swordName
            getgenv().Sword_VFX = swordName
            if getgenv().Skin_Changer and getgenv().ByteLibrary then
                getgenv().ByteLibrary.Update(Player.Character)
            end
            Library.SendNotification({
                title = "Sword Updated",
                text = "Model, animations & VFX set to: " .. swordName,
                duration = 3
            })
        end
    end
})

custom_module:create_feature({
    title = "Update Sword",
    flag = "update_sword",
    disablecheck = true,
    button_callback = function()
        if getgenv().Skin_Changer then
            if getgenv().ByteLibrary then
                getgenv().ByteLibrary.Update(Player.Character)
            end
            Library.SendNotification({
                title = "Sword Updated",
                text = "Sword appearance refreshed",
                duration = 2
            })
        else
            Library.SendNotification({
                title = "Error",
                text = "Enable skin changer first",
                duration = 2
            })
        end
    end
})

custom_module:create_checkbox({
    title = "Streamer Mode",
    flag = "streamer_mode",
    callback = function(value)
        if not State.uiLocked or (State.uiLocked and not value) then
            State.streamerModeEnabled = value
            MiscFeatures.ToggleStreamerMode()
        end
    end
})

custom_module:create_checkbox({
    title = "Lock UI Toggles",
    flag = "ui_locked",
    callback = function(value)
        State.uiLocked = value
        Library.SendNotification({
            title = "UI Lock",
            text = value and "UI toggles locked (prevents enabling)" or "UI toggles unlocked",
            duration = 3
        })
    end
})

local stats_module = stats_tab:create_module({
    title = "Performance Metrics",
    flag = "stats",
    description = "Performance statistics",
    section = "left",
    callback = function(value) end
})

local function UpdateStatsDisplay()
    local sessionTime = math.floor(tick() - StatsData.SessionTime)
    local successRate = StatsData.TotalParries > 0 and math.floor((StatsData.SuccessfulParries / StatsData.TotalParries) * 100) or 0
    StatsData.AccuracyRate = successRate

    return string.format([[Session Time: %02d:%02d
Success Rate: %d%%
Total Parries: %d
Successful: %d
Missed: %d
Curved Balls: %d
Infinity Detections: %d
Balls TP'd: %d
Triggerbot Activations: %d
Manual Spam Uses: %d
Current Ping: %d ms]],
        math.floor(sessionTime / 60),
        sessionTime % 60,
        successRate,
        StatsData.TotalParries,
        StatsData.SuccessfulParries,
        StatsData.MissedParries,
        StatsData.CurvedBallsDetected,
        StatsData.InfinityDetections,
        StatsData.BallsTPed,
        StatsData.TriggerbotActivations,
        StatsData.ManualSpamUses,
        Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    )
end

local statsText = stats_module:create_text({
    text = UpdateStatsDisplay(),
    CustomYSize = 200
})

local reset_module = stats_tab:create_module({
    title = "Reset Options",
    flag = "reset",
    description = "Reset statistics",
    section = "right",
    callback = function(value) end
})

reset_module:create_feature({
    title = "Reset All Stats",
    flag = "reset_stats",
    disablecheck = true,
    button_callback = function()
        StatsData.TotalParries = 0
        StatsData.SuccessfulParries = 0
        StatsData.MissedParries = 0
        StatsData.CurvedBallsDetected = 0
        StatsData.InfinityDetections = 0
        StatsData.BallsTPed = 0
        StatsData.TriggerbotActivations = 0
        StatsData.ManualSpamUses = 0
        StatsData.SessionTime = tick()

        Library.SendNotification({
            title = "Statistics",
            text = "All stats have been reset",
            duration = 3
        })
    end
})

task.spawn(function()
    while task.wait(1) do
        if statsText then
            statsText:Set({
                text = UpdateStatsDisplay()
            })
        end
    end
end)

main:load()

InitializeAutoParry()

Library.SendNotification({
    title = "Zeryx Loaded",
    text = "meow i love v0rtexd",
    duration = 5
})
