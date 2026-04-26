--[[
═══════════════════════════════════════════════════════════════════════════════
  ModuleManager.server.lua
═══════════════════════════════════════════════════════════════════════════════
  Responsibilities:
    1. Reads ModuleConfig and builds each station's 3-D prop in Workspace
    2. Manages a proximity-based trigger for every enabled station
    3. Owns ALL RemoteEvents (clients never create remotes)
    4. Tracks per-player progress (completed modules, lantern count)
    5. Validates every client→server event before acting

  RemoteEvent naming convention:   "<ModuleID>_<Action>"
    Breathing_Start, Breathing_Complete
    Garden_Start, Garden_Flower, Garden_Complete
    Jigsaw_Start, Jigsaw_Submit, Jigsaw_Complete
    Lantern_Start, Lantern_Release
    Global_LanternCount   (server → client: tells client current count)
    Global_ModuleComplete (server → client: module ID that just finished)
═══════════════════════════════════════════════════════════════════════════════
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local Workspace    = game:GetService("Workspace")
local RunService   = game:GetService("RunService")

local Config       = require(RS:WaitForChild("ModuleConfig"))

-- ── Shared folders ────────────────────────────────────────────────────────────
local stationsFolder = Instance.new("Folder")
stationsFolder.Name  = "Stations"
stationsFolder.Parent = Workspace

local remotesFolder  = Instance.new("Folder")
remotesFolder.Name   = "Remotes"
remotesFolder.Parent = RS

-- Copy config into RS so clients can read positions / prerequisites
local configValue = Instance.new("ModuleScript")
configValue.Name   = "ModuleConfig"
configValue.Source = ""   -- clients require the shared module directly
-- (Rojo will handle the path; clients WaitForChild("ModuleConfig") in RS)

-- ── Remote factory ────────────────────────────────────────────────────────────
local remotes = {}
local function makeRemote(name)
    if remotes[name] then return remotes[name] end
    local r = Instance.new("RemoteEvent")
    r.Name   = name
    r.Parent = remotesFolder
    remotes[name] = r
    return r
end

-- Pre-create all remotes so clients can WaitForChild at startup
local evBreathingStart     = makeRemote("Breathing_Start")
local evBreathingComplete  = makeRemote("Breathing_Complete")
local evGardenStart        = makeRemote("Garden_Start")
local evGardenFlower       = makeRemote("Garden_Flower")      -- C→S text; S→C plotIdx
local evGardenComplete     = makeRemote("Garden_Complete")
local evJigsawStart        = makeRemote("Jigsaw_Start")
local evJigsawSubmit       = makeRemote("Jigsaw_Submit")      -- C→S answer; S→C result
local evJigsawComplete     = makeRemote("Jigsaw_Complete")
local evLanternStart       = makeRemote("Lantern_Start")
local evLanternRelease     = makeRemote("Lantern_Release")
local evGlobalLanternCount = makeRemote("Global_LanternCount")
local evGlobalModuleDone   = makeRemote("Global_ModuleDone")

-- ── Player state ──────────────────────────────────────────────────────────────
local pState = {}
-- [player] = {
--   done      = { Breathing=false, Garden=false, Jigsaw=false, Lantern=false },
--   lanterns  = 0,
--   gardenPlot= 0,
--   jigsawRound = 0,
-- }

Players.PlayerAdded:Connect(function(player)
    pState[player] = {
        done       = { Breathing=false, Garden=false, Jigsaw=false, Lantern=false },
        lanterns   = 0,
        gardenPlot = 0,
        jigsawRound= 0,
    }
    local ls = Instance.new("Folder")
    ls.Name   = "leaderstats"
    ls.Parent = player
    local lv  = Instance.new("IntValue")
    lv.Name   = "Lanterns"
    lv.Value  = 0
    lv.Parent = ls
end)
Players.PlayerRemoving:Connect(function(p) pState[p] = nil end)

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getChar(player)
    return player.Character
end

local function playerFromHit(hit)
    local c = hit and hit.Parent
    return c and Players:GetPlayerFromCharacter(c)
end

local function awardLantern(player, reason)
    local st = pState[player]
    if not st then return end
    st.lanterns = st.lanterns + 1
    local ls = player:FindFirstChild("leaderstats")
    if ls and ls:FindFirstChild("Lanterns") then
        ls.Lanterns.Value = st.lanterns
    end
    evGlobalLanternCount:FireClient(player, st.lanterns)
    print(string.format("[ModuleManager] %s earned lantern %d (%s)",
        player.Name, st.lanterns, reason))
end

local function markDone(player, moduleId)
    local st = pState[player]
    if not st then return end
    st.done[moduleId] = true
    evGlobalModuleDone:FireClient(player, moduleId)
end

local function prereqsMet(player, moduleId)
    local cfg = Config.Modules[moduleId]
    if not cfg then return false end
    local st  = pState[player]
    if not st then return false end
    for _, prereq in ipairs(cfg.Prerequisites) do
        if not st.done[prereq] then return false end
    end
    return true
end

local function hasLantern(player)
    local st = pState[player]
    return st and st.lanterns > 0
end

-- ── 3-D station builder ───────────────────────────────────────────────────────

local function makePart(parent, props)
    local p = Instance.new("Part")
    for k, v in pairs(props) do p[k] = v end
    p.Anchored    = true
    p.TopSurface  = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent      = parent
    return p
end

local function addLight(part, brightness, range, color)
    local l = Instance.new("PointLight", part)
    l.Brightness = brightness; l.Range = range; l.Color = color
    l.Shadows    = false
    return l
end

local function addBillboard(part, text, textColor, studOffset)
    local bg = Instance.new("BillboardGui", part)
    bg.Size   = UDim2.new(0, 260, 0, 60)
    bg.StudsOffset = studOffset or Vector3.new(0, 4, 0)
    bg.AlwaysOnTop = false
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size  = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text  = text
    lbl.TextColor3 = textColor or Color3.fromRGB(255, 240, 200)
    lbl.TextScaled = true
    lbl.Font  = Enum.Font.GothamBold
end

local function makeTrigger(parent, pos, radius, name)
    local t = Instance.new("Part", parent)
    t.Name        = name or "Trigger"
    t.Size        = Vector3.new(radius*2, 4, radius*2)
    t.CFrame      = CFrame.new(pos + Vector3.new(0, 2, 0))
    t.Anchored    = true
    t.CanCollide  = false
    t.Transparency = 1
    t.CastShadow  = false
    return t
end

-- ── Build: Breathing Station ──────────────────────────────────────────────────

local function buildBreathing()
    local cfg = Config.Modules.Breathing
    if not cfg or not cfg.Enabled then return end
    local pos = cfg.Position
    local f   = Instance.new("Folder", stationsFolder)
    f.Name    = "Station_Breathing"

    -- Stone arch
    local archMat = Enum.Material.SmoothPlastic
    local archColor = BrickColor.new("Medium stone grey")
    local function archPost(ox)
        return makePart(f, {
            Name=ox<0 and "ArchLeft" or "ArchRight",
            Size=Vector3.new(1,8,1),
            CFrame=CFrame.new(pos+Vector3.new(ox,4,0)),
            BrickColor=archColor, Material=archMat,
        })
    end
    archPost(-3.5); archPost(3.5)
    local archTop = makePart(f, {
        Name="ArchTop", Size=Vector3.new(8.8,1,1),
        CFrame=CFrame.new(pos+Vector3.new(0,8.5,0)),
        BrickColor=archColor, Material=archMat,
    })
    -- Cyan glow bar
    local glowBar = makePart(f, {
        Name="GlowBar", Size=Vector3.new(8.4,0.35,0.35),
        CFrame=CFrame.new(pos+Vector3.new(0,8.5,-0.35)),
        BrickColor=BrickColor.new("Cyan"),
        Material=Enum.Material.Neon,
        CanCollide=false, CastShadow=false, Transparency=0.15,
    })
    addLight(glowBar, 1.0, 22, Color3.fromRGB(120, 220, 255))
    addBillboard(archTop, "✦  Breathe  ✦", Color3.fromRGB(180,255,230), Vector3.new(0,3,0))

    -- Six zen stones in a circle
    for i = 1, 6 do
        local a = (i/6)*math.pi*2
        makePart(f, {
            Name="ZenStone"..i,
            Size=Vector3.new(0.8,0.8,0.8),
            CFrame=CFrame.new(pos+Vector3.new(math.cos(a)*5,0.4,math.sin(a)*5)),
            BrickColor=BrickColor.new("Light stone grey"),
            Material=Enum.Material.SmoothPlastic,
        })
    end

    makeTrigger(f, pos, Config.TRIGGER_RADIUS, "BreathingTrigger")
    return f
end

-- ── Build: Garden Station ─────────────────────────────────────────────────────

local function buildGarden()
    local cfg = Config.Modules.Garden
    if not cfg or not cfg.Enabled then return end
    local pos = cfg.Position
    local f   = Instance.new("Folder", stationsFolder)
    f.Name    = "Station_Garden"

    -- Grass pad
    makePart(f, {
        Name="GardenGround", Size=Vector3.new(26,0.25,22),
        CFrame=CFrame.new(pos+Vector3.new(0,-0.4,0)),
        BrickColor=BrickColor.new("Bright green"), Material=Enum.Material.Grass,
    })

    -- Entrance arch (wood)
    local function woodPost(ox)
        makePart(f, {
            Name="ArchPost"..ox, Size=Vector3.new(0.7,7,0.7),
            CFrame=CFrame.new(pos+Vector3.new(ox,3.5,5)),
            BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
        })
    end
    woodPost(-3); woodPost(3)
    local archTop = makePart(f, {
        Name="ArchTop", Size=Vector3.new(7.4,0.7,0.7),
        CFrame=CFrame.new(pos+Vector3.new(0,7.3,5)),
        BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
    })
    local stringLight = makePart(f, {
        Name="StringLight", Size=Vector3.new(7,0.18,0.18),
        CFrame=CFrame.new(pos+Vector3.new(0,6.9,5)),
        BrickColor=BrickColor.new("Bright yellow"),
        Material=Enum.Material.Neon,
        CanCollide=false, CastShadow=false, Transparency=0.1,
    })
    addLight(stringLight, 0.6, 14, Color3.fromRGB(255,220,130))
    addBillboard(archTop, "🌸  Gratitude Garden  🌸", Color3.fromRGB(255,220,180), Vector3.new(0,2.5,0))

    -- 3 raised beds in arc; store plot positions for client
    local plotsFolder = Instance.new("Folder", RS)
    plotsFolder.Name  = "GardenPlots"

    local bedOffsets = {
        Vector3.new(-6, 0, -2), Vector3.new(0, 0, -5), Vector3.new(6, 0, -2)
    }
    local plotIdx = 0
    for bi, boff in ipairs(bedOffsets) do
        local bp = pos + boff
        makePart(f, {
            Name="BedFrame"..bi, Size=Vector3.new(7.5,0.75,3.5),
            CFrame=CFrame.new(bp+Vector3.new(0,0.1,0)),
            BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
        })
        makePart(f, {
            Name="BedSoil"..bi, Size=Vector3.new(6.8,0.28,2.8),
            CFrame=CFrame.new(bp+Vector3.new(0,0.5,0)),
            BrickColor=BrickColor.new("Brown"), Material=Enum.Material.Ground,
        })
        local glow = makePart(f, {
            Name="BedGlow"..bi, Size=Vector3.new(7,0.1,0.1),
            CFrame=CFrame.new(bp+Vector3.new(0,0.55,1.75)),
            BrickColor=BrickColor.new("Hot pink"),
            Material=Enum.Material.Neon,
            CanCollide=false, CastShadow=false, Transparency=0.3,
        })
        addLight(glow, 0.4, 9, Color3.fromRGB(255,160,220))

        for pi = 1, 3 do
            plotIdx = plotIdx + 1
            local t     = (pi-1)/2 - 0.5
            local ppos  = bp + Vector3.new(t*5, 0.65, 0)
            local disc  = makePart(f, {
                Name="PlotDisc"..plotIdx,
                Size=Vector3.new(1.3,0.12,1.3),
                CFrame=CFrame.new(ppos)*CFrame.Angles(0,0,math.pi/2),
                BrickColor=BrickColor.new("Light stone grey"),
                Material=Enum.Material.SmoothPlastic,
                CanCollide=false,
            })
            disc.Shape = Enum.PartType.Cylinder
            local v    = Instance.new("Vector3Value", plotsFolder)
            v.Name     = tostring(plotIdx)
            v.Value    = ppos
        end
    end

    -- Fairy lights
    for i = 1, 5 do
        local a  = (i/5)*math.pi*2
        local fp = pos+Vector3.new(math.cos(a)*10, 2.2, math.sin(a)*8-2)
        local sp = makePart(f, {
            Name="Fairy"..i, Size=Vector3.new(0.3,0.3,0.3),
            CFrame=CFrame.new(fp),
            BrickColor=BrickColor.new("Bright yellow"),
            Material=Enum.Material.Neon,
            CanCollide=false, CastShadow=false, Transparency=0.2,
        })
        sp.Shape = Enum.PartType.Ball
        addLight(sp, 0.35, 9, Color3.fromRGB(255,230,140))
    end

    makeTrigger(f, pos, Config.TRIGGER_RADIUS, "GardenTrigger")
    return f
end

-- ── Build: Jigsaw Station ─────────────────────────────────────────────────────

local function buildJigsaw()
    local cfg = Config.Modules.Jigsaw
    if not cfg or not cfg.Enabled then return end
    local pos = cfg.Position
    local f   = Instance.new("Folder", stationsFolder)
    f.Name    = "Station_Jigsaw"

    -- Stone reading table
    makePart(f, {
        Name="Table", Size=Vector3.new(6,0.4,3),
        CFrame=CFrame.new(pos+Vector3.new(0,1.8,0)),
        BrickColor=BrickColor.new("Medium stone grey"), Material=Enum.Material.SmoothPlastic,
    })
    -- Table legs
    for _, lx in ipairs({-2.4, 2.4}) do
        for _, lz in ipairs({-0.9, 0.9}) do
            makePart(f, {
                Name="Leg", Size=Vector3.new(0.3,1.8,0.3),
                CFrame=CFrame.new(pos+Vector3.new(lx,0.9,lz)),
                BrickColor=BrickColor.new("Medium stone grey"), Material=Enum.Material.SmoothPlastic,
            })
        end
    end
    -- Glow tablet on table (where puzzle tiles appear)
    local tablet = makePart(f, {
        Name="Tablet", Size=Vector3.new(5.5,0.12,2.5),
        CFrame=CFrame.new(pos+Vector3.new(0,2.06,0)),
        BrickColor=BrickColor.new("Bright blue"),
        Material=Enum.Material.Neon,
        CanCollide=false, Transparency=0.55,
    })
    addLight(tablet, 0.6, 14, Color3.fromRGB(100,180,255))
    addBillboard(tablet, "✦  Wisdom Puzzle  ✦", Color3.fromRGB(180,220,255), Vector3.new(0,4,0))

    -- Two stone benches flanking the table
    for _, bx in ipairs({-5, 5}) do
        makePart(f, {
            Name="Bench", Size=Vector3.new(2.5,0.3,1),
            CFrame=CFrame.new(pos+Vector3.new(bx,1.0,0)),
            BrickColor=BrickColor.new("Light stone grey"), Material=Enum.Material.SmoothPlastic,
        })
        makePart(f, {
            Name="BenchLeg", Size=Vector3.new(2.2,1,0.2),
            CFrame=CFrame.new(pos+Vector3.new(bx,0.5,0.3)),
            BrickColor=BrickColor.new("Light stone grey"), Material=Enum.Material.SmoothPlastic,
        })
    end

    -- Ambient fireflies
    for i = 1, 6 do
        local a   = (i/6)*math.pi*2
        local ffp = pos+Vector3.new(math.cos(a)*7, 1.8, math.sin(a)*7)
        local ff  = makePart(f, {
            Name="Firefly"..i, Size=Vector3.new(0.28,0.28,0.28),
            CFrame=CFrame.new(ffp),
            BrickColor=BrickColor.new("Bright yellow"),
            Material=Enum.Material.Neon,
            CanCollide=false, CastShadow=false, Transparency=0.25,
        })
        ff.Shape = Enum.PartType.Ball
        addLight(ff, 0.3, 8, Color3.fromRGB(220,255,120))
    end

    makeTrigger(f, pos, Config.TRIGGER_RADIUS, "JigsawTrigger")
    return f
end

-- ── Build: Lantern Station (dock ledge) ───────────────────────────────────────

local function buildLantern()
    local cfg = Config.Modules.Lantern
    if not cfg or not cfg.Enabled then return end
    local pos = cfg.Position
    local f   = Instance.new("Folder", stationsFolder)
    f.Name    = "Station_Lantern"

    -- Viewing platform at the end of the dock
    local platform = makePart(f, {
        Name="Platform", Size=Vector3.new(8,0.4,6),
        CFrame=CFrame.new(pos+Vector3.new(0,0,0)),
        BrickColor=BrickColor.new("Medium stone grey"), Material=Enum.Material.Cobblestone,
    })

    -- Low railing on three sides (not the side the path comes from)
    local railData = {
        { Vector3.new(0,0.8,-3.2), Vector3.new(8,0.2,0.2) },   -- far side
        { Vector3.new(-4.2,0.8,0), Vector3.new(0.2,0.2,6.4) },  -- left
        { Vector3.new(4.2,0.8,0),  Vector3.new(0.2,0.2,6.4) },  -- right
    }
    for i, rd in ipairs(railData) do
        makePart(f, {
            Name="Rail"..i, Size=rd[2],
            CFrame=CFrame.new(pos+rd[1]),
            BrickColor=BrickColor.new("Medium stone grey"), Material=Enum.Material.Cobblestone,
        })
    end

    -- Two stone pillars with hanging lanterns
    for _, px in ipairs({-3, 3}) do
        makePart(f, {
            Name="Pillar", Size=Vector3.new(0.6,3.5,0.6),
            CFrame=CFrame.new(pos+Vector3.new(px,1.75,0)),
            BrickColor=BrickColor.new("Medium stone grey"), Material=Enum.Material.SmoothPlastic,
        })
        local hang = makePart(f, {
            Name="HangLantern", Size=Vector3.new(0.8,1.2,0.8),
            CFrame=CFrame.new(pos+Vector3.new(px,3.8,0)),
            BrickColor=BrickColor.new("Bright orange"),
            Material=Enum.Material.Neon,
            CanCollide=false, Transparency=0.2,
        })
        addLight(hang, 1.2, 18, Color3.fromRGB(255,200,80))
    end

    -- Water shimmer glow beneath the platform (points downward into lake)
    local waterGlow = makePart(f, {
        Name="WaterGlow", Size=Vector3.new(7,0.1,5),
        CFrame=CFrame.new(pos+Vector3.new(0,-0.6,0)),
        BrickColor=BrickColor.new("Cyan"),
        Material=Enum.Material.Neon,
        CanCollide=false, CastShadow=false, Transparency=0.5,
    })
    addLight(waterGlow, 0.9, 20, Color3.fromRGB(80,200,255))

    addBillboard(platform, "🏮  Release Your Lantern  🏮", Color3.fromRGB(255,220,120), Vector3.new(0,5,0))

    makeTrigger(f, pos, Config.TRIGGER_RADIUS, "LanternTrigger")
    return f
end

-- ── Build all enabled stations ────────────────────────────────────────────────

buildBreathing()
buildGarden()
buildJigsaw()
buildLantern()

-- ── Proximity trigger loop (polls every 0.5 s) ────────────────────────────────
--  Instead of .Touched (unreliable for non-physics parts), we use a heartbeat
--  scan so players just walking near a station activates it.

local HALF_INTERVAL = 0.5
local timers = {}   -- [player] = last check time

local function checkProximity()
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        local rp = root.Position

        -- Breathing
        local bcfg = Config.Modules.Breathing
        if bcfg and bcfg.Enabled then
            local st = pState[player]
            if st and not st.done.Breathing and prereqsMet(player, "Breathing") then
                if (rp - bcfg.Position).Magnitude < Config.TRIGGER_RADIUS + 2 then
                    evBreathingStart:FireClient(player)
                end
            end
        end
        -- Garden
        local gcfg = Config.Modules.Garden
        if gcfg and gcfg.Enabled then
            local st = pState[player]
            if st and not st.done.Garden and prereqsMet(player, "Garden") then
                if (rp - gcfg.Position).Magnitude < Config.TRIGGER_RADIUS + 2 then
                    evGardenStart:FireClient(player)
                end
            end
        end
        -- Jigsaw
        local jcfg = Config.Modules.Jigsaw
        if jcfg and jcfg.Enabled then
            local st = pState[player]
            if st and not st.done.Jigsaw and prereqsMet(player, "Jigsaw") then
                if (rp - jcfg.Position).Magnitude < Config.TRIGGER_RADIUS + 2 then
                    evJigsawStart:FireClient(player)
                end
            end
        end
        -- Lantern
        local lcfg = Config.Modules.Lantern
        if lcfg and lcfg.Enabled then
            local st = pState[player]
            if st and not st.done.Lantern and prereqsMet(player, "Lantern") and hasLantern(player) then
                if (rp - lcfg.Position).Magnitude < Config.TRIGGER_RADIUS + 2 then
                    evLanternStart:FireClient(player)
                end
            end
        end
    end
end

-- Debounce: only fire each start event once per 4 seconds per player
local startCooldowns = {}   -- [player..moduleId] = last fire time
local function cooldownedFire(remote, player, moduleId)
    local key = tostring(player.UserId) .. moduleId
    local now = tick()
    if startCooldowns[key] and now - startCooldowns[key] < 4 then return end
    startCooldowns[key] = now
    remote:FireClient(player)
end

-- Override above checkProximity to use cooldown
local function checkProximityDebounced()
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        local rp = root.Position
        local st = pState[player]
        if not st then continue end

        local checks = {
            { "Breathing", evBreathingStart, not st.done.Breathing },
            { "Garden",    evGardenStart,    not st.done.Garden    },
            { "Jigsaw",    evJigsawStart,    not st.done.Jigsaw    },
            { "Lantern",   evLanternStart,   not st.done.Lantern and hasLantern(player) },
        }
        for _, c in ipairs(checks) do
            local id, remote, cond = c[1], c[2], c[3]
            local cfg = Config.Modules[id]
            if cfg and cfg.Enabled and cond and prereqsMet(player, id) then
                if (rp - cfg.Position).Magnitude < Config.TRIGGER_RADIUS + 2 then
                    cooldownedFire(remote, player, id)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(HALF_INTERVAL)
        local ok, err = pcall(checkProximityDebounced)
        if not ok then warn("[ModuleManager] proximity check error:", err) end
    end
end)

-- ── Remote handlers ───────────────────────────────────────────────────────────

-- Breathing complete
evBreathingComplete.OnServerEvent:Connect(function(player)
    local st = pState[player]
    if not st or st.done.Breathing then return end
    markDone(player, "Breathing")
    awardLantern(player, "Breathing")
end)

-- Garden: player submits one gratitude text → server echoes back plot index
evGardenFlower.OnServerEvent:Connect(function(player, text)
    local st = pState[player]
    if not st or st.done.Garden then return end
    if not prereqsMet(player, "Garden") then return end
    if type(text) ~= "string" or #text:gsub("%s+","") < 2 then return end
    if st.gardenPlot >= 3 then return end
    st.gardenPlot = st.gardenPlot + 1
    evGardenFlower:FireClient(player, st.gardenPlot)
end)

evGardenComplete.OnServerEvent:Connect(function(player)
    local st = pState[player]
    if not st or st.done.Garden then return end
    if st.gardenPlot < 3 then return end
    markDone(player, "Garden")
    awardLantern(player, "Garden")
end)

-- Jigsaw: player submits tile order → server validates
-- The answer key is stored server-side only so the client can't cheat.
local JIGSAW_ROUNDS = {
    -- { shuffled tiles the client receives, correct order }
    {
        quote = "Gratitude turns what we have into enough.",
        words = {"turns","what","Gratitude","have","into","we","enough."},
        answer = "Gratitude turns what we have into enough.",
    },
    {
        quote = "In the middle of every difficulty lies opportunity.",
        words = {"every","In","middle","of","difficulty","lies","the","opportunity."},
        answer = "In the middle of every difficulty lies opportunity.",
    },
    {
        quote = "The present moment is the only moment available to us.",
        words = {"only","The","moment","present","the","available","is","moment","to","us."},
        answer = "The present moment is the only moment available to us.",
    },
}

-- Store per-player jigsaw state
-- jRound tracks which round they're on (1,2,3)

evJigsawStart.OnClientEvent = nil   -- not used; start fires from proximity

-- Server sends round data when client fires JigsawSubmit with round number 0 (request)
evJigsawSubmit.OnServerEvent:Connect(function(player, roundNumber, submittedAnswer)
    local st = pState[player]
    if not st or st.done.Jigsaw then return end
    if not prereqsMet(player, "Jigsaw") then return end

    -- If roundNumber == 0: client requesting the next round's data
    if roundNumber == 0 then
        local nextRound = st.jigsawRound + 1
        if nextRound > #JIGSAW_ROUNDS then return end
        local rdata = JIGSAW_ROUNDS[nextRound]
        -- Send shuffled word list (shuffle server-side so order is consistent)
        local shuffled = {}
        for i, w in ipairs(rdata.words) do shuffled[i] = w end
        -- Fisher-Yates
        local seed = math.random(1000)
        local rng  = Random.new(seed)
        for i = #shuffled, 2, -1 do
            local j = rng:NextInteger(1, i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end
        evJigsawSubmit:FireClient(player, "ROUND_DATA", nextRound, shuffled, #JIGSAW_ROUNDS)
        return
    end

    -- Otherwise validate submitted answer
    local round = JIGSAW_ROUNDS[roundNumber]
    if not round then return end
    local correct = (submittedAnswer == round.answer)
    evJigsawSubmit:FireClient(player, correct and "CORRECT" or "WRONG", roundNumber)

    if correct then
        st.jigsawRound = roundNumber
        if roundNumber >= #JIGSAW_ROUNDS then
            -- All rounds done
            markDone(player, "Jigsaw")
            awardLantern(player, "Jigsaw")
            evJigsawComplete:FireClient(player)
        end
    end
end)

-- Lantern release
evLanternRelease.OnServerEvent:Connect(function(player)
    local st = pState[player]
    if not st or st.done.Lantern then return end
    if not hasLantern(player) then return end
    markDone(player, "Lantern")
    -- Spend one lantern
    st.lanterns = math.max(0, st.lanterns - 1)
    evGlobalLanternCount:FireClient(player, st.lanterns)
    print("[ModuleManager]", player.Name, "released a lantern.")
end)

print("[ModuleManager] All stations built and live.")
