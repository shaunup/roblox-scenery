--[[
  ScenerySetup.server.lua
  Builds the Glowing Pond twilight environment.

  Contents:
    1. Lighting  – deep twilight sky, stars, moon, colour effects
    2. Terrain   – flat grassy ground, surrounding hills
                   NOTE: terrain:Clear() removed – existing lake is preserved
    3. Pond glow – layered translucent water surface, breathable PointLights,
                   slow-drift bioluminescent particles, animated pulse tweens
    4. Scenery   – rock clusters, flowers, reeds, firefly particles
    5. Spawn     – SpawnLocation on the bank of the pond
]]

local Workspace    = game:GetService("Workspace")
local Lighting     = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

-- ── Pond centre / radius (matches existing terrain lake) ─────────────────────
-- Adjust POND_X / POND_Z if the lake sits at a different position.
local POND_X      = 0
local POND_Y      = 0       -- water surface Y in your terrain
local POND_Z      = 0
local POND_RADIUS = 38      -- approximate radius of your lake in studs

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

    -- Bloom: gentle enough not to blow out the scene, strong enough for the
    -- pond glow and lanterns to feel magical
    local bloom = Instance.new("BloomEffect", Lighting)
    bloom.Intensity = 0.7
    bloom.Size      = 28
    bloom.Threshold = 0.92
end

-- ─────────────────────────────────────────────────────────
-- 2. TERRAIN
-- ─────────────────────────────────────────────────────────
local function buildTerrain()
    local terrain = Workspace.Terrain
    -- NOTE: terrain:Clear() intentionally omitted – existing lake is kept.

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

    -- Pond basin: skipped – existing terrain lake is used as-is.
    -- To regenerate the basin, uncomment the block below and set POND_RADIUS above.
    --[[
    terrain:FillCylinder(CFrame.new(POND_X, POND_Y - 3, POND_Z), 6, POND_RADIUS, Enum.Material.Mud)
    terrain:FillCylinder(CFrame.new(POND_X, POND_Y - 1, POND_Z), 4, POND_RADIUS, Enum.Material.Water)
    terrain:FillCylinder(CFrame.new(POND_X, POND_Y - 0.5, POND_Z), 3, POND_RADIUS + 8, Enum.Material.Mud)
    terrain:FillCylinder(CFrame.new(POND_X, POND_Y - 0.4, POND_Z), 3, POND_RADIUS, Enum.Material.Water)
    --]]
end

-- ─────────────────────────────────────────────────────────
-- 3. GLOWING POND – natural bioluminescent look
-- ─────────────────────────────────────────────────────────
--[[
  Design goals:
  • No single hard-edged neon disc – instead several semi-transparent layers
    at slightly different radii and heights produce a soft, depth-ful glow
  • PointLights are dim individually; their overlap creates brightness
    naturally, just like bioluminescence
  • Particles drift UPWARD very slowly (rising mist/glow wisps), not
    scattering sideways like sparks
  • A TweenService "breathing" pulse gently oscillates transparency of each
    layer so the whole pond feels alive
]]

local function buildPondGlow(folder)
    local cx, cy, cz = POND_X, POND_Y, POND_Z
    local R           = POND_RADIUS

    -- ── Helper: invisible anchor part for lights / particles ──────────────
    local function anchor(x, y, z, sz)
        sz = sz or Vector3.new(0.1, 0.1, 0.1)
        local p = Instance.new("Part", folder)
        p.Size        = sz
        p.CFrame      = CFrame.new(x, y, z)
        p.Anchored    = true
        p.CanCollide  = false
        p.CastShadow  = false
        p.Transparency = 1
        return p
    end

    -- ── Helper: build one translucent neon water layer ────────────────────
    local function waterLayer(name, radius, yOff, color, alpha)
        local p = Instance.new("Part", folder)
        p.Name        = name
        p.Shape       = Enum.PartType.Cylinder
        -- Cylinder's "height" axis is X when rotated 90° on Z
        p.Size        = Vector3.new(0.25, radius * 2, radius * 2)
        p.CFrame      = CFrame.new(cx, cy + yOff, cz)
                      * CFrame.Angles(0, 0, math.pi / 2)
        p.Anchored    = true
        p.CanCollide  = false
        p.CastShadow  = false
        p.Material    = Enum.Material.Neon
        p.Color       = color
        p.Transparency = alpha
        return p
    end

    -- ── Helper: breathing tween on Transparency ───────────────────────────
    local function breathe(part, alphaA, alphaB, period, offset)
        -- stagger start so layers don't all pulse in sync
        task.delay(offset or 0, function()
            local ti = TweenInfo.new(
                period / 2,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,   -- repeat forever
                true  -- reverse (ping-pong)
            )
            TweenService:Create(part, ti, { Transparency = alphaB }):Play()
        end)
    end

    -- ── Layer 1: deep-water base – wide, very translucent midnight blue ───
    --   Sits just below surface; gives the pond its deep colour
    local deep = waterLayer("PondDeep",
        R * 0.96,       -- slightly inside pond edge
        -0.05,          -- just below waterline
        Color3.fromRGB(18, 80, 160),
        0.82)
    breathe(deep, 0.82, 0.88, 6, 0)

    -- ── Layer 2: main bioluminescent surface glow – teal-cyan ─────────────
    --   Floats exactly on the water surface; this is the "main" glow
    local surface = waterLayer("PondSurface",
        R * 0.88,
        0.06,
        Color3.fromRGB(60, 190, 230),
        0.72)
    breathe(surface, 0.72, 0.80, 5, 0.8)

    -- ── Layer 3: inner bright ring – lighter aqua, smaller radius ─────────
    --   Concentrates brightness toward the centre like moonlight on water
    local inner = waterLayer("PondInner",
        R * 0.55,
        0.12,
        Color3.fromRGB(110, 220, 245),
        0.65)
    breathe(inner, 0.65, 0.74, 4, 1.6)

    -- ── Layer 4: central shimmer hotspot – near-white, small ──────────────
    --   Simulates the direct moon reflection at the very centre
    local hotspot = waterLayer("PondHotspot",
        R * 0.22,
        0.18,
        Color3.fromRGB(190, 245, 255),
        0.55)
    breathe(hotspot, 0.55, 0.68, 3, 0.4)

    -- ── Diffuse lighting: 3 low-brightness central lights ─────────────────
    --   Spread across a small triangle so shadows look natural, not flat
    local lightOffsets = {
        Vector3.new(0,      1.5, 0),
        Vector3.new(-R*0.3, 1.2, R*0.2),
        Vector3.new( R*0.3, 1.2,-R*0.2),
    }
    for i, off in ipairs(lightOffsets) do
        local lp = anchor(cx + off.X, cy + off.Y, cz + off.Z)
        local pl = Instance.new("PointLight", lp)
        pl.Color      = Color3.fromRGB(90, 210, 255)
        pl.Brightness = 1.4           -- gentle – relies on overlap for total brightness
        pl.Range      = R * 1.8
        pl.Shadows    = (i == 1)      -- only the central one casts shadows
    end

    -- ── Edge lights: 6 around the perimeter, alternating warm/cool ────────
    --   These light up reeds and rocks at the bank – crucial for depth
    local edgeColors = {
        Color3.fromRGB(80,  200, 255),   -- cool blue
        Color3.fromRGB(120, 230, 200),   -- mint green
        Color3.fromRGB(80,  200, 255),
        Color3.fromRGB(100, 215, 240),
        Color3.fromRGB(120, 230, 200),
        Color3.fromRGB(80,  200, 255),
    }
    for i = 1, 6 do
        local a  = (i / 6) * math.pi * 2
        local ep = anchor(
            cx + math.cos(a) * (R * 0.82),
            cy + 0.4,
            cz + math.sin(a) * (R * 0.82)
        )
        local el = Instance.new("PointLight", ep)
        el.Color      = edgeColors[i]
        el.Brightness = 0.9
        el.Range      = 28
        el.Shadows    = false
    end

    -- ── Rising mist wisps: slow upward drift, almost invisible ────────────
    --   Particles move upward at near-zero speed — gives the impression
    --   of the water "breathing" light into the air above it
    local function addWispEmitter(ox, oz, rate, color)
        local ep = anchor(cx + ox, cy + 0.3, cz + oz, Vector3.new(R*1.6, 0.2, R*1.6))
        local pe = Instance.new("ParticleEmitter", ep)
        pe.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   color),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(150, 230, 255)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(200, 245, 255)),
        })
        pe.LightEmission  = 1
        pe.LightInfluence = 0
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0),
            NumberSequenceKeypoint.new(0.15, 0.55),
            NumberSequenceKeypoint.new(0.7,  0.30),
            NumberSequenceKeypoint.new(1,   0),
        })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   1),
            NumberSequenceKeypoint.new(0.1, 0.60),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(0.9, 0.80),
            NumberSequenceKeypoint.new(1,   1),
        })
        pe.Lifetime          = NumberRange.new(5, 9)
        pe.Rate              = rate
        pe.Speed             = NumberRange.new(0.4, 1.0)   -- very slow rise
        pe.SpreadAngle       = Vector2.new(12, 12)         -- nearly vertical
        pe.RotSpeed          = NumberRange.new(-8, 8)
        pe.Rotation          = NumberRange.new(0, 360)
        pe.EmissionDirection = Enum.NormalId.Top
        return pe
    end

    -- Main surface wisps (teal, sparse)
    addWispEmitter(0, 0, 7, Color3.fromRGB(70, 200, 240))
    -- Slightly warmer near the centre (moonlight warmth)
    addWispEmitter(0, 0, 3, Color3.fromRGB(160, 235, 255))

    -- ── Floating sparkle motes: rare, crisp bright points ─────────────────
    --   NOT a carpet of sparks – just occasional glints on the water surface
    local sparkPart = anchor(cx, cy + 0.2, cz, Vector3.new(R*1.8, 0.1, R*1.8))
    local sparks    = Instance.new("ParticleEmitter", sparkPart)
    sparks.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 250, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 230, 255)),
    })
    sparks.LightEmission  = 1
    sparks.LightInfluence = 0
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.2, 0.18),
        NumberSequenceKeypoint.new(0.8, 0.10),
        NumberSequenceKeypoint.new(1,   0),
    })
    sparks.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   1),
        NumberSequenceKeypoint.new(0.1, 0.0),
        NumberSequenceKeypoint.new(0.85, 0.1),
        NumberSequenceKeypoint.new(1,   1),
    })
    sparks.Lifetime          = NumberRange.new(1.5, 4)
    sparks.Rate              = 4             -- rare: ~4 per second across the whole lake
    sparks.Speed             = NumberRange.new(0, 0.3)
    sparks.SpreadAngle       = Vector2.new(180, 180)
    sparks.RotSpeed          = NumberRange.new(0, 0)
    sparks.Rotation          = NumberRange.new(0, 360)
    sparks.EmissionDirection = Enum.NormalId.Top

    -- ── Lily pads – organic shape, softer glow ─────────────────────────────
    --   Removed Neon material; use SmoothPlastic with a dim PointLight instead
    --   so they look like real plants catching the glow, not light sources
    local rng       = Random.new(42)
    local lilyData  = {
        { 0.4,  8  }, { 1.1, 14 }, { 1.9, 22 },
        { 2.8, 10  }, { 3.6, 18 }, { 4.5, 25 }, { 5.3, 12 },
    }
    for _, ld in ipairs(lilyData) do
        local la, ldist = ld[1], ld[2]
        local lx = cx + math.cos(la) * ldist
        local lz = cz + math.sin(la) * ldist
        local padR = rng:NextNumber(1.0, 2.4)

        local pad = Instance.new("Part", folder)
        pad.Shape       = Enum.PartType.Cylinder
        pad.Size        = Vector3.new(0.14, padR * 2, padR * 2)
        pad.CFrame      = CFrame.new(lx, cy + 0.1, lz)
                        * CFrame.Angles(0, rng:NextNumber(0, math.pi*2), math.pi/2)
        pad.Anchored    = true
        pad.CanCollide  = false
        pad.CastShadow  = false
        pad.Material    = Enum.Material.SmoothPlastic
        pad.Color       = Color3.fromRGB(38, 110, 52)   -- dark swamp green
        pad.Transparency = 0.0

        -- Tiny warm point light underneath the pad: simulates glow seeping through
        local padGlow = Instance.new("PointLight", pad)
        padGlow.Color      = Color3.fromRGB(100, 230, 140)
        padGlow.Brightness = 0.6
        padGlow.Range      = 8
        padGlow.Shadows    = false

        -- Small flower on top
        local flower = Instance.new("Part", folder)
        flower.Shape       = Enum.PartType.Ball
        flower.Size        = Vector3.new(0.5, 0.5, 0.5)
        flower.CFrame      = CFrame.new(lx, cy + 0.35, lz)
        flower.Anchored    = true
        flower.CanCollide  = false
        flower.CastShadow  = false
        flower.Material    = Enum.Material.Neon
        flower.Color       = Color3.fromRGB(220, 160, 255)  -- soft violet
        flower.Transparency = 0.2
        local fl = Instance.new("PointLight", flower)
        fl.Color      = Color3.fromRGB(200, 140, 255)
        fl.Brightness = 0.4
        fl.Range      = 5
    end
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

    -- Lily pads are now built inside buildPondGlow with natural materials.
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
