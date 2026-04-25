--[[
  ScenerySetup.server.lua
  Builds the Glowing Pond twilight environment.

  Contents:
    1. Lighting  – deep twilight sky, stars, moon, colour effects
    2. Terrain   – flat grassy ground, surrounding hills, glowing pond
    3. Pond glow – neon water surface + PointLights + particle shimmer
    4. Scenery   – rock clusters, flowers, reeds, firefly particles
    5. Spawn     – SpawnLocation on the bank of the pond
]]

local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")

-- ─────────────────────────────────────────────────────────
-- 1. LIGHTING  (deep twilight – just after sunset)
-- ─────────────────────────────────────────────────────────
local function setupLighting()
    Lighting.ClockTime          = 20.2        -- ~8:12 PM, fully dark sky
    Lighting.GeographicLatitude = 40
    Lighting.Brightness         = 0.5
    Lighting.GlobalShadows      = true
    Lighting.OutdoorAmbient     = Color3.fromRGB(20, 18, 38)   -- deep indigo night
    Lighting.Ambient            = Color3.fromRGB(30, 22, 50)
    Lighting.FogStart           = 380
    Lighting.FogEnd             = 900
    Lighting.FogColor           = Color3.fromRGB(14, 12, 28)   -- near-black purple fog

    -- Night sky
    local sky = Instance.new("Sky", Lighting)
    sky.StarCount        = 8000
    sky.MoonAngularSize  = 14          -- large, romantic moon
    sky.SunAngularSize   = 5

    -- Atmosphere – thin, preserves stars but adds depth
    local atmo = Instance.new("Atmosphere", Lighting)
    atmo.Density    = 0.18
    atmo.Offset     = 0.06
    atmo.Color      = Color3.fromRGB(30, 25, 60)     -- deep blue-violet
    atmo.Decay      = Color3.fromRGB(10, 8, 20)
    atmo.Glare      = 0
    atmo.Haze       = 0.4

    -- Colour correction – cooler, slightly desaturated except the pond glow
    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.Brightness = -0.06
    cc.Contrast   = 0.14
    cc.Saturation = -0.08
    cc.TintColor  = Color3.fromRGB(200, 210, 255)    -- cool blue night tint

    -- Bloom makes the glowing pond and fireflies pop
    local bloom = Instance.new("BloomEffect", Lighting)
    bloom.Intensity = 1.2
    bloom.Size      = 36
    bloom.Threshold = 0.85
end

-- ─────────────────────────────────────────────────────────
-- 2. TERRAIN
-- ─────────────────────────────────────────────────────────
local function buildTerrain()
    local terrain = Workspace.Terrain
    terrain:Clear()

    -- Flat grassy ground plane
    terrain:FillBlock(
        CFrame.new(0, -6, 0),
        Vector3.new(700, 12, 700),
        Enum.Material.Grass
    )

    -- Dirt path leading to the pond (thin strip)
    terrain:FillBlock(
        CFrame.new(0, 0.2, 55),
        Vector3.new(6, 1, 60),
        Enum.Material.Ground
    )

    -- Rolling hills around the perimeter to close in the scene
    local rng = Random.new(99)
    local hillData = {
        -- {centreX, centreZ, radius, height}
        { -220, -180, 90, 55 },
        {  240, -200, 85, 60 },
        { -200,  200, 80, 45 },
        {  210,  190, 88, 50 },
        {    0, -260, 95, 70 },
        { -260,    0, 78, 42 },
        {  260,   10, 82, 48 },
    }
    for _, h in ipairs(hillData) do
        local cx, cz, rad, ht = h[1], h[2], h[3], h[4]
        -- Build hill as stacked spheres (wide base → tapered top)
        local steps = 8
        for s = 0, steps do
            local t   = s / steps
            local y   = t * ht
            local r   = rad * math.sin(math.pi * (1 - t * 0.8))
            terrain:FillBall(Vector3.new(cx, y, cz), r, Enum.Material.Grass)
        end
        -- Rocky cap on each hill
        terrain:FillBall(Vector3.new(cx, ht - 4, cz), rad * 0.18, Enum.Material.Rock)
    end

    -- Pond basin – scoop out a shallow bowl and fill with water
    -- First dig out a bowl shape
    local POND_Y      = 0
    local POND_RADIUS = 38
    terrain:FillCylinder(
        CFrame.new(0, POND_Y - 3, 0),
        6, POND_RADIUS,
        Enum.Material.Mud
    )
    -- Fill with water slightly above mud floor
    terrain:FillCylinder(
        CFrame.new(0, POND_Y - 1, 0),
        4, POND_RADIUS,
        Enum.Material.Water
    )
    -- Muddy / sandy bank ring around the pond
    terrain:FillCylinder(
        CFrame.new(0, POND_Y - 0.5, 0),
        3, POND_RADIUS + 8,
        Enum.Material.Mud
    )
    terrain:FillCylinder(
        CFrame.new(0, POND_Y - 0.4, 0),
        3, POND_RADIUS,     -- cut grass back out inside the bank
        Enum.Material.Water
    )
end

-- ─────────────────────────────────────────────────────────
-- 3. GLOWING POND SURFACE & LIGHTS
-- ─────────────────────────────────────────────────────────
local function buildPondGlow(folder)
    -- Thin neon disc sitting on the water surface – the main glow source
    local glowDisc = Instance.new("Part", folder)
    glowDisc.Name          = "PondGlow"
    glowDisc.Shape         = Enum.PartType.Cylinder
    glowDisc.Size          = Vector3.new(0.3, 74, 74)
    glowDisc.CFrame        = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
    glowDisc.Anchored      = true
    glowDisc.CanCollide    = false
    glowDisc.CastShadow    = false
    glowDisc.Material      = Enum.Material.Neon
    glowDisc.Color         = Color3.fromRGB(80, 210, 255)   -- icy cyan glow
    glowDisc.Transparency  = 0.35

    -- Central strong light – illuminates the whole area
    local centreLight = Instance.new("PointLight", glowDisc)
    centreLight.Color      = Color3.fromRGB(100, 220, 255)
    centreLight.Brightness = 6
    centreLight.Range      = 120
    centreLight.Shadows    = true

    -- Ring of softer accent lights around the pond edge for depth
    local ACCENT_COUNT  = 8
    local ACCENT_RADIUS = 34
    for i = 1, ACCENT_COUNT do
        local angle = (i / ACCENT_COUNT) * math.pi * 2
        local ax = math.cos(angle) * ACCENT_RADIUS
        local az = math.sin(angle) * ACCENT_RADIUS

        local accentPart = Instance.new("Part", folder)
        accentPart.Size        = Vector3.new(0.5, 0.5, 0.5)
        accentPart.CFrame      = CFrame.new(ax, 0.4, az)
        accentPart.Anchored    = true
        accentPart.CanCollide  = false
        accentPart.CastShadow  = false
        accentPart.Material    = Enum.Material.Neon
        accentPart.Color       = Color3.fromRGB(120, 230, 255)
        accentPart.Transparency = 0.5

        local aLight = Instance.new("PointLight", accentPart)
        aLight.Color      = Color3.fromRGB(100, 200, 255)
        aLight.Brightness = 2.2
        aLight.Range      = 40
        aLight.Shadows    = false
    end

    -- Ripple / shimmer particle emitter on the pond surface
    local emitPart = Instance.new("Part", folder)
    emitPart.Size        = Vector3.new(1, 1, 1)
    emitPart.CFrame      = CFrame.new(0, 0.5, 0)
    emitPart.Anchored    = true
    emitPart.CanCollide  = false
    emitPart.CastShadow  = false
    emitPart.Transparency = 1

    local shimmer = Instance.new("ParticleEmitter", emitPart)
    shimmer.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(150, 240, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 255, 255)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(100, 200, 255)),
    })
    shimmer.LightEmission  = 1
    shimmer.LightInfluence = 0
    shimmer.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.3, 0.35),
        NumberSequenceKeypoint.new(1,   0),
    })
    shimmer.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   1),
        NumberSequenceKeypoint.new(0.2, 0.15),
        NumberSequenceKeypoint.new(0.8, 0.15),
        NumberSequenceKeypoint.new(1,   1),
    })
    shimmer.Lifetime       = NumberRange.new(2, 5)
    shimmer.Rate           = 35
    shimmer.Speed          = NumberRange.new(0.2, 1.2)
    shimmer.SpreadAngle    = Vector2.new(60, 60)
    shimmer.RotSpeed       = NumberRange.new(-30, 30)
    shimmer.Rotation       = NumberRange.new(0, 360)
    shimmer.EmissionDirection = Enum.NormalId.Top

    -- Spread emitter over the whole pond area
    local spreadEmit = Instance.new("Part", folder)
    spreadEmit.Size        = Vector3.new(70, 0.1, 70)
    spreadEmit.CFrame      = CFrame.new(0, 0.3, 0)
    spreadEmit.Anchored    = true
    spreadEmit.CanCollide  = false
    spreadEmit.CastShadow  = false
    spreadEmit.Transparency = 1

    local shimmer2 = shimmer:Clone()
    shimmer2.Rate   = 20
    shimmer2.Parent = spreadEmit
end

-- ─────────────────────────────────────────────────────────
-- 4. SCENERY DETAILS
-- ─────────────────────────────────────────────────────────
local function buildScenery(folder)
    local rng = Random.new(77)

    -- ── Rocks around the pond bank ──
    local rockPositions = {
        {42, 0, 8},  {-40, 0, 12}, {30, 0, -30}, {-28, 0, -32},
        {45, 0, -15}, {-38, 0, -10}, {20, 0, 38}, {-22, 0, 36},
    }
    for _, rp in ipairs(rockPositions) do
        local rockCount = rng:NextInteger(2, 4)
        for _ = 1, rockCount do
            local rock = Instance.new("Part", folder)
            local scale = rng:NextNumber(1.2, 3.5)
            rock.Size          = Vector3.new(scale, scale * 0.7, scale * 0.9)
            rock.CFrame        = CFrame.new(
                rp[1] + rng:NextNumber(-4, 4),
                rp[2] + scale * 0.3,
                rp[3] + rng:NextNumber(-4, 4)
            ) * CFrame.Angles(
                rng:NextNumber(-0.2, 0.2),
                rng:NextNumber(0, math.pi * 2),
                rng:NextNumber(-0.15, 0.15)
            )
            rock.Anchored      = true
            rock.Material      = Enum.Material.SmoothPlastic
            rock.BrickColor    = BrickColor.new("Medium stone grey")
            rock.TopSurface    = Enum.SurfaceType.Smooth
            rock.BottomSurface = Enum.SurfaceType.Smooth
        end
    end

    -- ── Reed / grass tufts at water's edge ──
    local reedAngles = {}
    for i = 1, 20 do reedAngles[i] = (i / 20) * math.pi * 2 end
    for _, angle in ipairs(reedAngles) do
        local dist = rng:NextNumber(36, 46)
        local rx   = math.cos(angle) * dist
        local rz   = math.sin(angle) * dist
        local count = rng:NextInteger(2, 5)
        for _ = 1, count do
            local reed = Instance.new("Part", folder)
            local h    = rng:NextNumber(1.8, 4.2)
            reed.Size          = Vector3.new(0.18, h, 0.18)
            reed.CFrame        = CFrame.new(
                rx + rng:NextNumber(-3, 3),
                h / 2,
                rz + rng:NextNumber(-3, 3)
            ) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, math.pi * 2), 0)
            reed.Anchored      = true
            reed.Material      = Enum.Material.SmoothPlastic
            reed.BrickColor    = BrickColor.new("Reddish brown")
            reed.TopSurface    = Enum.SurfaceType.Smooth
            reed.BottomSurface = Enum.SurfaceType.Smooth
            reed.CastShadow    = false
        end
    end

    -- ── Trees scattered around the scene ──
    local treeSpots = {
        {80, 0, 20}, {-85, 0, 30}, {70, 0, -60}, {-75, 0, -55},
        {100, 0, -10}, {-105, 0, 5}, {55, 0, 90}, {-60, 0, 85},
        {90, 0, 70}, {-90, 0, -70}, {40, 0, -100}, {-45, 0, -95},
    }
    for _, tp in ipairs(treeSpots) do
        local treeCount = rng:NextInteger(1, 3)
        for _ = 1, treeCount do
            local ox  = tp[1] + rng:NextNumber(-12, 12)
            local oz  = tp[3] + rng:NextNumber(-12, 12)
            local trunkH = rng:NextNumber(6, 11)
            local trunkR = rng:NextNumber(0.5, 1.0)
            local canopyR = rng:NextNumber(5, 9)

            -- Trunk
            local trunk = Instance.new("Part", folder)
            trunk.Size          = Vector3.new(trunkR * 2, trunkH, trunkR * 2)
            trunk.CFrame        = CFrame.new(ox, trunkH / 2, oz)
            trunk.Anchored      = true
            trunk.Material      = Enum.Material.Wood
            trunk.BrickColor    = BrickColor.new("Reddish brown")
            trunk.TopSurface    = Enum.SurfaceType.Smooth
            trunk.BottomSurface = Enum.SurfaceType.Smooth

            -- Canopy (sphere)
            local canopy = Instance.new("Part", folder)
            canopy.Shape        = Enum.PartType.Ball
            canopy.Size         = Vector3.new(canopyR * 2, canopyR * 2, canopyR * 2)
            canopy.CFrame       = CFrame.new(ox, trunkH + canopyR * 0.7, oz)
            canopy.Anchored     = true
            canopy.Material     = Enum.Material.SmoothPlastic
            canopy.BrickColor   = BrickColor.new("Dark green")
            canopy.TopSurface   = Enum.SurfaceType.Smooth
            canopy.BottomSurface = Enum.SurfaceType.Smooth
            canopy.CastShadow   = true
        end
    end

    -- ── Firefly / ambient sparkles across the ground ──
    local fireflyEmitter = Instance.new("Part", folder)
    fireflyEmitter.Size        = Vector3.new(200, 0.1, 200)
    fireflyEmitter.CFrame      = CFrame.new(0, 1.5, 0)
    fireflyEmitter.Anchored    = true
    fireflyEmitter.CanCollide  = false
    fireflyEmitter.CastShadow  = false
    fireflyEmitter.Transparency = 1

    local ff = Instance.new("ParticleEmitter", fireflyEmitter)
    ff.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(180, 255, 130)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 160)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(160, 240, 100)),
    })
    ff.LightEmission  = 1
    ff.LightInfluence = 0
    ff.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.3, 0.22),
        NumberSequenceKeypoint.new(1,   0),
    })
    ff.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   1),
        NumberSequenceKeypoint.new(0.2, 0.05),
        NumberSequenceKeypoint.new(0.8, 0.05),
        NumberSequenceKeypoint.new(1,   1),
    })
    ff.Lifetime       = NumberRange.new(5, 10)
    ff.Rate           = 22
    ff.Speed          = NumberRange.new(0.3, 1.5)
    ff.SpreadAngle    = Vector2.new(70, 70)
    ff.RotSpeed       = NumberRange.new(-20, 20)
    ff.Rotation       = NumberRange.new(0, 360)

    -- ── Glowing lily pads on the pond ──
    local lilyAngles = {0.4, 1.1, 1.9, 2.8, 3.6, 4.5, 5.3}
    for _, la in ipairs(lilyAngles) do
        local ldist = rng:NextNumber(8, 28)
        local lx    = math.cos(la) * ldist
        local lz    = math.sin(la) * ldist

        local pad = Instance.new("Part", folder)
        local padR = rng:NextNumber(1.2, 2.8)
        pad.Shape        = Enum.PartType.Cylinder
        pad.Size         = Vector3.new(0.12, padR * 2, padR * 2)
        pad.CFrame       = CFrame.new(lx, 0.18, lz) * CFrame.Angles(0, 0, math.pi / 2)
        pad.Anchored     = true
        pad.CanCollide   = false
        pad.CastShadow   = false
        pad.Material     = Enum.Material.Neon
        pad.Color        = Color3.fromRGB(60, 200, 80)   -- soft green neon
        pad.Transparency = 0.45

        local padLight = Instance.new("PointLight", pad)
        padLight.Color      = Color3.fromRGB(80, 220, 100)
        padLight.Brightness = 1.2
        padLight.Range      = 12
        padLight.Shadows    = false
    end
end

-- ─────────────────────────────────────────────────────────
-- 5. SPAWN LOCATION  (on the pond bank, path entrance)
-- ─────────────────────────────────────────────────────────
local function setupSpawn()
    local spawn = Instance.new("SpawnLocation", Workspace)
    spawn.CFrame        = CFrame.new(0, 1, 88)
    spawn.Size          = Vector3.new(8, 1, 8)
    spawn.Anchored      = true
    spawn.Material      = Enum.Material.Grass
    spawn.BrickColor    = BrickColor.new("Medium green")
    spawn.TopSurface    = Enum.SurfaceType.Smooth
    spawn.BottomSurface = Enum.SurfaceType.Smooth
    spawn.Neutral       = true
    spawn.Transparency  = 1   -- invisible, blends into ground
end

-- ─────────────────────────────────────────────────────────
-- MAIN
-- ─────────────────────────────────────────────────────────
setupLighting()

local folder = Instance.new("Folder", Workspace)
folder.Name  = "GlowingPondScene"

buildTerrain()
buildPondGlow(folder)
buildScenery(folder)
setupSpawn()

print("[GlowingPondScene] Scene ready.")
