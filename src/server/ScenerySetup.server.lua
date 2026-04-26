--[[
  ScenerySetup.server.lua
  Builds the full Twilight Trail environment:

    - Twilight evening sky (dusk light, large moon, stars)
    - Flat grassy baseplate with soft rolling edges
    - Zig-zag stone trail from spawn → Breathing Zone → Bonfire Zone
    - Breathing Zone: stone circle with lantern post & ProximityPrompt trigger
    - Bonfire Zone: fire pit, log seating, musician NPC, ProximityPrompt trigger
    - Ambient trees, rocks, fireflies
]]

local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")

-- ─────────────────────────────────────────────────────────
-- 1. LIGHTING  – early twilight, moon just risen
-- ─────────────────────────────────────────────────────────
local function setupLighting()
    Lighting.ClockTime          = 17.9        -- 7:36 PM – dusk, moon visible
    Lighting.GeographicLatitude = 45
    Lighting.Brightness         = 0.9
    Lighting.GlobalShadows      = true
    Lighting.OutdoorAmbient     = Color3.fromRGB(40, 35, 65)
    Lighting.Ambient            = Color3.fromRGB(55, 45, 80)
    Lighting.FogStart           = 320
    Lighting.FogEnd             = 850
    Lighting.FogColor           = Color3.fromRGB(25, 20, 45)

    local sky = Instance.new("Sky", Lighting)
    sky.StarCount       = 6000
    sky.MoonAngularSize = 16     -- large, soft moon
    sky.SunAngularSize  = 6

    local atmo = Instance.new("Atmosphere", Lighting)
    atmo.Density    = 0.28
    atmo.Offset     = 0.10
    atmo.Color      = Color3.fromRGB(80, 60, 120)   -- deep violet dusk
    atmo.Decay      = Color3.fromRGB(20, 15, 40)
    atmo.Glare      = 0.05
    atmo.Haze       = 0

    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.Brightness = -0.04
    cc.Contrast   = 0.10
    cc.Saturation = 0.05
    cc.TintColor  = Color3.fromRGB(210, 200, 255)   -- cool lavender cast

    -- local bloom = Instance.new("BloomEffect", Lighting)
    -- bloom.Intensity = 0.7
    -- bloom.Size      = 24
    -- bloom.Threshold = 0.88

    local sunRays = Instance.new("SunRaysEffect", Lighting)
    sunRays.Intensity = 0.08
    sunRays.Spread    = 0.5
end

-- ─────────────────────────────────────────────────────────
-- 2. BASEPLATE & GROUND
-- ─────────────────────────────────────────────────────────
local function buildGround()
    local terrain = Workspace.Terrain
    terrain:Clear()

    -- Main flat ground
    terrain:FillBlock(
        CFrame.new(0, -5, 0),
        Vector3.new(600, 10, 600),
        Enum.Material.Grass
    )

    -- Low perimeter hills to frame the scene
    local hills = {
        {-240, -200, 80, 40}, { 250, -210, 75, 38},
        {-220,  220, 85, 42}, { 230,  215, 78, 36},
        {  0,  -280, 90, 50}, {  0,   285, 88, 45},
        {-280,   10, 70, 35}, { 285,    5, 72, 37},
    }
    local rng = Random.new(55)
    for _, h in ipairs(hills) do
        local cx, cz, r, ht = h[1], h[2], h[3], h[4]
        for s = 0, 8 do
            local t  = s / 8
            local yr = t * ht
            local rr = r * math.sin(math.pi * (1 - t * 0.8))
            terrain:FillBall(Vector3.new(cx, yr, cz), rr, Enum.Material.Grass)
        end
        terrain:FillBall(Vector3.new(cx, ht - 3, cz), r * 0.16, Enum.Material.Rock)
    end
end

-- ─────────────────────────────────────────────────────────
-- 3. ZIG-ZAG TRAIL
--    Trail runs from spawn (0,0,80) → Breathing (0,0,-30)
--    → Bonfire (-60,0,-150)  in sweeping zig-zag segments.
--    Each segment is a flat stone-paved path block.
-- ─────────────────────────────────────────────────────────

-- Trail waypoints – start, zig, zag, milestone 1, zig, zag, milestone 2
local WAYPOINTS = {
    Vector3.new(  0, 0,  90),   -- [1] spawn
    Vector3.new( 45, 0,  55),   -- zig right
    Vector3.new( 45, 0,  15),   -- straight
    Vector3.new(  0, 0, -10),   -- zag centre
    Vector3.new(-40, 0, -40),   -- zig left
    Vector3.new(  0, 0, -75),   -- zag back centre
    Vector3.new( 35, 0,-110),   -- zig right again
    Vector3.new(  0, 0,-145),   -- zag to milestone 2
    Vector3.new(-60, 0,-165),   -- [9] bonfire
}

local PATH_WIDTH = 5

local function buildTrail(folder)
    for i = 1, #WAYPOINTS - 1 do
        local a = WAYPOINTS[i]
        local b = WAYPOINTS[i + 1]
        local mid    = (a + b) / 2
        local diff   = b - a
        local length = diff.Magnitude
        local angle  = math.atan2(diff.X, diff.Z)

        local slab = Instance.new("Part", folder)
        slab.Name          = "TrailSlab_" .. i
        slab.Size          = Vector3.new(PATH_WIDTH, 0.4, length)
        slab.CFrame        = CFrame.new(mid.X, 0.2, mid.Z) * CFrame.Angles(0, angle, 0)
        slab.Anchored      = true
        slab.Material      = Enum.Material.SmoothPlastic
        slab.BrickColor    = BrickColor.new("Medium stone grey")
        slab.TopSurface    = Enum.SurfaceType.Smooth
        slab.BottomSurface = Enum.SurfaceType.Smooth
        slab.CastShadow    = false

        -- Subtle path-side torch lights every other segment
        if i % 2 == 0 then
            for _, side in ipairs({-1, 1}) do
                local torchPos = mid + Vector3.new(side * (PATH_WIDTH / 2 + 1.5), 2.5, 0)
                local torch = Instance.new("Part", folder)
                torch.Size          = Vector3.new(0.3, 2.5, 0.3)
                torch.CFrame        = CFrame.new(torchPos)
                torch.Anchored      = true
                torch.Material      = Enum.Material.Wood
                torch.BrickColor    = BrickColor.new("Reddish brown")
                torch.TopSurface    = Enum.SurfaceType.Smooth
                torch.BottomSurface = Enum.SurfaceType.Smooth
                torch.CastShadow    = false

                local flame = Instance.new("Part", folder)
                flame.Size          = Vector3.new(0.35, 0.35, 0.35)
                flame.CFrame        = CFrame.new(torchPos + Vector3.new(0, 1.5, 0))
                flame.Anchored      = true
                flame.CanCollide    = false
                flame.CastShadow    = false
                flame.Material      = Enum.Material.Neon
                flame.Color         = Color3.fromRGB(255, 160, 50)
                flame.Transparency  = 0.3

                local fl = Instance.new("PointLight", flame)
                fl.Color      = Color3.fromRGB(255, 170, 70)
                fl.Brightness = 1.8
                fl.Range      = 18
                fl.Shadows    = false

                local fire = Instance.new("Fire", flame)
                fire.Heat           = 4
                fire.Size           = 0.5
                fire.Color          = Color3.fromRGB(255, 140, 30)
                fire.SecondaryColor = Color3.fromRGB(200, 60, 0)
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────
-- 4. SPAWN PLATFORM
-- ─────────────────────────────────────────────────────────
local function buildSpawn()
    local spawn = Instance.new("SpawnLocation", Workspace)
    spawn.CFrame        = CFrame.new(0, 1, 90)
    spawn.Size          = Vector3.new(10, 1, 10)
    spawn.Anchored      = true
    spawn.Material      = Enum.Material.SmoothPlastic
    spawn.BrickColor    = BrickColor.new("Medium stone grey")
    spawn.TopSurface    = Enum.SurfaceType.Smooth
    spawn.BottomSurface = Enum.SurfaceType.Smooth
    spawn.Neutral       = true
    spawn.Transparency  = 0

    -- Welcome sign
    local sign = Instance.new("Part", Workspace)
    sign.Name          = "WelcomeSign"
    sign.Size          = Vector3.new(8, 3, 0.4)
    sign.CFrame        = CFrame.new(0, 4, 96)
    sign.Anchored      = true
    sign.Material      = Enum.Material.Wood
    sign.BrickColor    = BrickColor.new("Reddish brown")
    sign.TopSurface    = Enum.SurfaceType.Smooth
    sign.BottomSurface = Enum.SurfaceType.Smooth

    local gui = Instance.new("SurfaceGui", sign)
    gui.Face        = Enum.NormalId.Front
    gui.SizingMode  = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50

    local label = Instance.new("TextLabel", gui)
    label.Size            = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text            = "✦ The Twilight Trail ✦\nFollow the path to find peace"
    label.TextColor3      = Color3.fromRGB(255, 240, 200)
    label.Font            = Enum.Font.GothamBold
    label.TextScaled      = true
end

-- ─────────────────────────────────────────────────────────
-- 5. BREATHING ZONE  (Milestone 1, around waypoint 4)
-- ─────────────────────────────────────────────────────────
local BREATHING_POS = Vector3.new(0, 0, -75)

local function buildBreathingZone(folder)
    -- Stone circle platform
    local platform = Instance.new("Part", folder)
    platform.Name          = "BreathingPlatform"
    platform.Shape         = Enum.PartType.Cylinder
    platform.Size          = Vector3.new(0.5, 22, 22)
    platform.CFrame        = CFrame.new(BREATHING_POS.X, 0.25, BREATHING_POS.Z)
                           * CFrame.Angles(0, 0, math.pi / 2)
    platform.Anchored      = true
    platform.Material      = Enum.Material.SmoothPlastic
    platform.BrickColor    = BrickColor.new("Fossil")
    platform.TopSurface    = Enum.SurfaceType.Smooth
    platform.BottomSurface = Enum.SurfaceType.Smooth

    -- Glowing central medallion
    local medallion = Instance.new("Part", folder)
    medallion.Name          = "BreathingMedallion"
    medallion.Shape         = Enum.PartType.Cylinder
    medallion.Size          = Vector3.new(0.2, 5, 5)
    medallion.CFrame        = CFrame.new(BREATHING_POS.X, 0.5, BREATHING_POS.Z)
                            * CFrame.Angles(0, 0, math.pi / 2)
    medallion.Anchored      = true
    medallion.CanCollide    = false
    medallion.CastShadow    = false
    medallion.Material      = Enum.Material.Neon
    medallion.Color         = Color3.fromRGB(120, 200, 255)
    medallion.Transparency  = 0.3

    local mLight = Instance.new("PointLight", medallion)
    mLight.Color      = Color3.fromRGB(130, 210, 255)
    mLight.Brightness = 3
    mLight.Range      = 35
    mLight.Shadows    = false

    -- Standing stone ring (8 stones)
    local stoneRing = 9
    for i = 1, stoneRing do
        local ang = (i / stoneRing) * math.pi * 2
        local sx  = BREATHING_POS.X + math.cos(ang) * 10
        local sz  = BREATHING_POS.Z + math.sin(ang) * 10
        local stone = Instance.new("Part", folder)
        stone.Size          = Vector3.new(1.2, 2.8, 0.9)
        stone.CFrame        = CFrame.new(sx, 1.4, sz) * CFrame.Angles(0, ang, 0)
        stone.Anchored      = true
        stone.Material      = Enum.Material.SmoothPlastic
        stone.BrickColor    = BrickColor.new("Medium stone grey")
        stone.TopSurface    = Enum.SurfaceType.Smooth
        stone.BottomSurface = Enum.SurfaceType.Smooth
    end

    -- Milestone sign
    local signPost = Instance.new("Part", folder)
    signPost.Size          = Vector3.new(0.4, 5, 0.4)
    signPost.CFrame        = CFrame.new(BREATHING_POS.X + 12, 2.5, BREATHING_POS.Z)
    signPost.Anchored      = true
    signPost.Material      = Enum.Material.Wood
    signPost.BrickColor    = BrickColor.new("Reddish brown")
    signPost.TopSurface    = Enum.SurfaceType.Smooth
    signPost.BottomSurface = Enum.SurfaceType.Smooth

    local signBoard = Instance.new("Part", folder)
    signBoard.Name          = "BreathingSign"
    signBoard.Size          = Vector3.new(5, 2, 0.3)
    signBoard.CFrame        = CFrame.new(BREATHING_POS.X + 12, 5.5, BREATHING_POS.Z)
    signBoard.Anchored      = true
    signBoard.Material      = Enum.Material.Wood
    signBoard.BrickColor    = BrickColor.new("Dark orange")
    signBoard.TopSurface    = Enum.SurfaceType.Smooth
    signBoard.BottomSurface = Enum.SurfaceType.Smooth

    local sGui = Instance.new("SurfaceGui", signBoard)
    sGui.Face = Enum.NormalId.Front
    sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sGui.PixelsPerStud = 60
    local sLabel = Instance.new("TextLabel", sGui)
    sLabel.Size                  = UDim2.new(1, 0, 1, 0)
    sLabel.BackgroundTransparency = 1
    sLabel.Text                  = "★ Breathing Circle\nStep inside to begin"
    sLabel.TextColor3            = Color3.fromRGB(255, 240, 200)
    sLabel.Font                  = Enum.Font.GothamBold
    sLabel.TextScaled            = true

    -- Invisible trigger part – the MilestoneManager will add ProximityPrompt
    local trigger = Instance.new("Part", folder)
    trigger.Name          = "BreathingTrigger"
    trigger.Size          = Vector3.new(8, 4, 8)
    trigger.CFrame        = CFrame.new(BREATHING_POS.X, 2, BREATHING_POS.Z)
    trigger.Anchored      = true
    trigger.CanCollide    = false
    trigger.CastShadow    = false
    trigger.Transparency  = 1
end

-- ─────────────────────────────────────────────────────────
-- 6. BONFIRE ZONE  (Milestone 2, around waypoint 9)
-- ─────────────────────────────────────────────────────────
local BONFIRE_POS = Vector3.new(-60, 0, -165)

local function buildBonfireZone(folder)
    -- Flat clearing platform
    local clearing = Instance.new("Part", folder)
    clearing.Name          = "BonfireClearing"
    clearing.Shape         = Enum.PartType.Cylinder
    clearing.Size          = Vector3.new(0.5, 30, 30)
    clearing.CFrame        = CFrame.new(BONFIRE_POS.X, 0.25, BONFIRE_POS.Z)
                           * CFrame.Angles(0, 0, math.pi / 2)
    clearing.Anchored      = true
    clearing.Material      = Enum.Material.SmoothPlastic
    clearing.BrickColor    = BrickColor.new("Dirt brown")
    clearing.TopSurface    = Enum.SurfaceType.Smooth
    clearing.BottomSurface = Enum.SurfaceType.Smooth

    -- Fire pit base (ring of stones)
    local pitStones = 10
    for i = 1, pitStones do
        local ang = (i / pitStones) * math.pi * 2
        local sx  = BONFIRE_POS.X + math.cos(ang) * 3.5
        local sz  = BONFIRE_POS.Z + math.sin(ang) * 3.5
        local ps  = Instance.new("Part", folder)
        ps.Size          = Vector3.new(1.4, 0.9, 1.0)
        ps.CFrame        = CFrame.new(sx, 0.45, sz) * CFrame.Angles(0, ang, 0)
        ps.Anchored      = true
        ps.Material      = Enum.Material.SmoothPlastic
        ps.BrickColor    = BrickColor.new("Dark grey")
        ps.TopSurface    = Enum.SurfaceType.Smooth
        ps.BottomSurface = Enum.SurfaceType.Smooth
    end

    -- Bonfire logs (X cross)
    local function makeLog(offsetX, offsetZ, rotY)
        local log = Instance.new("Part", folder)
        log.Size          = Vector3.new(0.6, 0.6, 5.5)
        log.CFrame        = CFrame.new(BONFIRE_POS.X + offsetX, 0.5, BONFIRE_POS.Z + offsetZ)
                          * CFrame.Angles(0, rotY, 0)
        log.Anchored      = true
        log.Material      = Enum.Material.Wood
        log.BrickColor    = BrickColor.new("Reddish brown")
        log.TopSurface    = Enum.SurfaceType.Smooth
        log.BottomSurface = Enum.SurfaceType.Smooth
    end
    makeLog(0, 0, 0)
    makeLog(0, 0, math.rad(60))
    makeLog(0, 0, math.rad(-60))

    -- Actual fire
    local firePart = Instance.new("Part", folder)
    firePart.Name          = "BonfireFire"
    firePart.Size          = Vector3.new(1, 1, 1)
    firePart.CFrame        = CFrame.new(BONFIRE_POS.X, 1.5, BONFIRE_POS.Z)
    firePart.Anchored      = true
    firePart.CanCollide    = false
    firePart.CastShadow    = false
    firePart.Transparency  = 1

    local fire = Instance.new("Fire", firePart)
    fire.Heat           = 12
    fire.Size           = 6
    fire.Color          = Color3.fromRGB(255, 140, 30)
    fire.SecondaryColor = Color3.fromRGB(220, 60, 0)

    local fireLight = Instance.new("PointLight", firePart)
    fireLight.Color      = Color3.fromRGB(255, 160, 60)
    fireLight.Brightness = 5
    fireLight.Range      = 60
    fireLight.Shadows    = true

    -- Log seats around the fire
    local seatAngles = {0.5, 1.8, 3.2, 4.6}
    for _, ang in ipairs(seatAngles) do
        local sx = BONFIRE_POS.X + math.cos(ang) * 7
        local sz = BONFIRE_POS.Z + math.sin(ang) * 7
        local seat = Instance.new("Part", folder)
        seat.Size          = Vector3.new(3.5, 0.7, 1.2)
        seat.CFrame        = CFrame.new(sx, 0.35, sz) * CFrame.Angles(0, ang + math.pi, 0)
        seat.Anchored      = true
        seat.Material      = Enum.Material.Wood
        seat.BrickColor    = BrickColor.new("Brown")
        seat.TopSurface    = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
    end

    -- Porch / small hut for the musician
    local porchBase = Instance.new("Part", folder)
    porchBase.Size          = Vector3.new(8, 0.5, 7)
    porchBase.CFrame        = CFrame.new(BONFIRE_POS.X - 10, 0.25, BONFIRE_POS.Z)
    porchBase.Anchored      = true
    porchBase.Material      = Enum.Material.Wood
    porchBase.BrickColor    = BrickColor.new("Brown")
    porchBase.TopSurface    = Enum.SurfaceType.Smooth
    porchBase.BottomSurface = Enum.SurfaceType.Smooth

    -- Porch roof (simple wedge-like block)
    local roof = Instance.new("Part", folder)
    roof.Size          = Vector3.new(9, 0.4, 8)
    roof.CFrame        = CFrame.new(BONFIRE_POS.X - 10, 4, BONFIRE_POS.Z)
    roof.Anchored      = true
    roof.Material      = Enum.Material.SmoothPlastic
    roof.BrickColor    = BrickColor.new("Dark red")
    roof.TopSurface    = Enum.SurfaceType.Smooth
    roof.BottomSurface = Enum.SurfaceType.Smooth

    for _, col in ipairs({-3.5, 3.5}) do
        for _, colz in ipairs({-3, 3}) do
            local pillar = Instance.new("Part", folder)
            pillar.Size          = Vector3.new(0.5, 4, 0.5)
            pillar.CFrame        = CFrame.new(BONFIRE_POS.X - 10 + col, 2, BONFIRE_POS.Z + colz)
            pillar.Anchored      = true
            pillar.Material      = Enum.Material.Wood
            pillar.BrickColor    = BrickColor.new("Reddish brown")
            pillar.TopSurface    = Enum.SurfaceType.Smooth
            pillar.BottomSurface = Enum.SurfaceType.Smooth
        end
    end

    -- Musician NPC (simple humanoid-shaped dummy) seated on the porch
    local npcRoot = Instance.new("Part", folder)
    npcRoot.Name          = "MusicianNPC"
    npcRoot.Size          = Vector3.new(2, 3, 1)
    npcRoot.CFrame        = CFrame.new(BONFIRE_POS.X - 10, 2, BONFIRE_POS.Z)
                          * CFrame.Angles(0, math.rad(120), 0)
    npcRoot.Anchored      = true
    npcRoot.Material      = Enum.Material.SmoothPlastic
    npcRoot.BrickColor    = BrickColor.new("Warm tan")
    npcRoot.TopSurface    = Enum.SurfaceType.Smooth
    npcRoot.BottomSurface = Enum.SurfaceType.Smooth

    local npcHead = Instance.new("Part", folder)
    npcHead.Name          = "MusicianHead"
    npcHead.Shape         = Enum.PartType.Ball
    npcHead.Size          = Vector3.new(1.5, 1.5, 1.5)
    npcHead.CFrame        = CFrame.new(BONFIRE_POS.X - 10, 4, BONFIRE_POS.Z)
    npcHead.Anchored      = true
    npcHead.Material      = Enum.Material.SmoothPlastic
    npcHead.BrickColor    = BrickColor.new("Warm tan")
    npcHead.TopSurface    = Enum.SurfaceType.Smooth
    npcHead.BottomSurface = Enum.SurfaceType.Smooth

    -- Name tag above NPC
    local nameTag = Instance.new("BillboardGui", npcHead)
    nameTag.Size         = UDim2.new(0, 180, 0, 44)
    nameTag.StudsOffset  = Vector3.new(0, 1.4, 0)
    nameTag.AlwaysOnTop  = false
    local nameLabel = Instance.new("TextLabel", nameTag)
    nameLabel.Size                  = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                  = "♪ The Musician"
    nameLabel.TextColor3            = Color3.fromRGB(255, 240, 180)
    nameLabel.Font                  = Enum.Font.GothamBold
    nameLabel.TextScaled            = true

    -- Guitar prop (simple block stand-in)
    local guitar = Instance.new("Part", folder)
    guitar.Size          = Vector3.new(0.4, 2.8, 0.5)
    guitar.CFrame        = CFrame.new(BONFIRE_POS.X - 8.5, 2, BONFIRE_POS.Z - 0.5)
                         * CFrame.Angles(0, 0, math.rad(30))
    guitar.Anchored      = true
    guitar.Material      = Enum.Material.Wood
    guitar.BrickColor    = BrickColor.new("Brown")
    guitar.TopSurface    = Enum.SurfaceType.Smooth
    guitar.BottomSurface = Enum.SurfaceType.Smooth

    local guitarBody = Instance.new("Part", folder)
    guitarBody.Shape         = Enum.PartType.Ball
    guitarBody.Size          = Vector3.new(1.4, 1.4, 0.5)
    guitarBody.CFrame        = CFrame.new(BONFIRE_POS.X - 9, 1.2, BONFIRE_POS.Z - 0.5)
    guitarBody.Anchored      = true
    guitarBody.Material      = Enum.Material.Wood
    guitarBody.BrickColor    = BrickColor.new("Dark orange")
    guitarBody.TopSurface    = Enum.SurfaceType.Smooth
    guitarBody.BottomSurface = Enum.SurfaceType.Smooth

    -- Invisible trigger – MilestoneManager attaches ProximityPrompt here
    local trigger = Instance.new("Part", folder)
    trigger.Name          = "BonfireTrigger"
    trigger.Size          = Vector3.new(8, 4, 8)
    trigger.CFrame        = CFrame.new(BONFIRE_POS.X, 2, BONFIRE_POS.Z)
    trigger.Anchored      = true
    trigger.CanCollide    = false
    trigger.CastShadow    = false
    trigger.Transparency  = 1

    -- Milestone sign
    local msSign = Instance.new("Part", folder)
    msSign.Size          = Vector3.new(5.5, 2, 0.3)
    msSign.CFrame        = CFrame.new(BONFIRE_POS.X + 12, 3.5, BONFIRE_POS.Z)
    msSign.Anchored      = true
    msSign.Material      = Enum.Material.Wood
    msSign.BrickColor    = BrickColor.new("Dark orange")
    msSign.TopSurface    = Enum.SurfaceType.Smooth
    msSign.BottomSurface = Enum.SurfaceType.Smooth

    local msGui = Instance.new("SurfaceGui", msSign)
    msGui.Face = Enum.NormalId.Front
    msGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    msGui.PixelsPerStud = 60
    local msLabel = Instance.new("TextLabel", msGui)
    msLabel.Size                  = UDim2.new(1, 0, 1, 0)
    msLabel.BackgroundTransparency = 1
    msLabel.Text                  = "♪ Bonfire & Music\nThe musician awaits"
    msLabel.TextColor3            = Color3.fromRGB(255, 240, 200)
    msLabel.Font                  = Enum.Font.GothamBold
    msLabel.TextScaled            = true
end

-- ─────────────────────────────────────────────────────────
-- 7. AMBIENT TREES + FIREFLIES
-- ─────────────────────────────────────────────────────────
local function buildAmbience(folder)
    local rng = Random.new(33)

    -- Firefly emitter
    local ffPart = Instance.new("Part", folder)
    ffPart.Size        = Vector3.new(300, 0.1, 300)
    ffPart.CFrame      = CFrame.new(0, 1.8, -80)
    ffPart.Anchored    = true
    ffPart.CanCollide  = false
    ffPart.CastShadow  = false
    ffPart.Transparency = 1

    local ff = Instance.new("ParticleEmitter", ffPart)
    ff.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(180, 255, 130)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 160)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(160, 240, 100)),
    })
    ff.LightEmission  = 1
    ff.LightInfluence = 0
    ff.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.3, 0.18),
        NumberSequenceKeypoint.new(1,   0),
    })
    ff.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.08),
        NumberSequenceKeypoint.new(0.8, 0.08), NumberSequenceKeypoint.new(1, 1),
    })
    ff.Lifetime     = NumberRange.new(5, 10)
    ff.Rate         = 18
    ff.Speed        = NumberRange.new(0.2, 1.2)
    ff.SpreadAngle  = Vector2.new(70, 70)
    ff.RotSpeed     = NumberRange.new(-25, 25)
    ff.Rotation     = NumberRange.new(0, 360)
end

-- ─────────────────────────────────────────────────────────
-- MAIN
-- ─────────────────────────────────────────────────────────
setupLighting()

local folder = Instance.new("Folder", Workspace)
folder.Name  = "TwilightTrail"

-- buildGround()
-- buildSpawn()
-- buildTrail(folder)
-- buildBreathingZone(folder)
-- buildBonfireZone(folder)
buildAmbience(folder)

print("[TwilightTrail] Scene built.")
