--[[
  ScenerySetup.server.lua
  Builds the entire flying-lanterns twilight scenery on the server.

  Sub-systems:
    1. Lighting  – twilight sun angle, ambient colours, fog
    2. Atmosphere – haze, density, colour scatter for golden-hour look
    3. Sky / Stars – star count, moon, gradient skybox via ColorCorrection
    4. Terrain   – flat base + procedural mountain silhouettes
    5. Lanterns  – spawned in a circle, gently rising with a warm glow
    6. Ambient particles – soft firefly-like sparkles near the ground
]]

local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")
local Lighting     = game:GetService("Lighting")

-- ──────────────────────────────────────────────
-- 1. LIGHTING  (twilight / golden-hour dusk)
-- ──────────────────────────────────────────────
local function setupLighting()
    Lighting.Brightness        = 1.4
    Lighting.ClockTime         = 18.8          -- ~6:48 PM  – deep golden dusk
    Lighting.GeographicLatitude = 35
    Lighting.GlobalShadows     = true
    Lighting.OutdoorAmbient    = Color3.fromRGB(68, 52, 82)   -- cool purple shadow
    Lighting.Ambient           = Color3.fromRGB(90, 60, 40)   -- warm earth tones
    Lighting.FogEnd            = 1200
    Lighting.FogStart          = 400
    Lighting.FogColor          = Color3.fromRGB(180, 110, 70) -- dusty amber horizon fog

    -- Atmosphere
    local atmo = Instance.new("Atmosphere", Lighting)
    atmo.Density     = 0.42
    atmo.Offset      = 0.18
    atmo.Color       = Color3.fromRGB(210, 145, 95)   -- warm orange scatter
    atmo.Decay       = Color3.fromRGB(88,  55, 110)   -- violet decay at edges
    atmo.Glare       = 0.18
    atmo.Haze        = 2.6

    -- Subtle colour-correction to push the twilight palette
    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.Brightness = -0.03
    cc.Contrast   = 0.12
    cc.Saturation = 0.18
    cc.TintColor  = Color3.fromRGB(255, 225, 190)

    -- Bloom for lantern glow
    local bloom = Instance.new("BloomEffect", Lighting)
    bloom.Intensity = 0.8
    bloom.Size      = 28
    bloom.Threshold = 0.92

    -- Sun rays (DepthOfField removed – DepthOfField is client-pref)
    local sunRays = Instance.new("SunRaysEffect", Lighting)
    sunRays.Intensity = 0.15
    sunRays.Spread    = 0.6

    -- Sky – custom tinted sky colours via a Sky object
    local sky = Instance.new("Sky", Lighting)
    sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
    sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
    sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
    sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
    sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
    sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
    sky.StarCount = 5000         -- lots of stars visible at dusk
    sky.MoonAngularSize = 11     -- larger, romantic moon
    sky.SunAngularSize  = 8

    -- Slow the clock very slightly so the sun sets gradually over time
    task.spawn(function()
        while true do
            task.wait(4)
            -- Advance clock from ~18.8 toward 20.5 over ~30 minutes real-time (very slow)
            local t = Lighting.ClockTime
            if t < 20.5 then
                Lighting.ClockTime = t + 0.005
            end
        end
    end)
end

-- ──────────────────────────────────────────────
-- 2. TERRAIN  – rolling base + mountain ridges
-- ──────────────────────────────────────────────
local function buildTerrain()
    local terrain = Workspace.Terrain
    terrain:Clear()

    -- Flat grassy valley floor
    local VALLEY_SIZE   = 800
    local VALLEY_HEIGHT = 0       -- sea level

    -- Fill a flat base region (grass)
    terrain:FillBlock(
        CFrame.new(0, VALLEY_HEIGHT - 10, 0),
        Vector3.new(VALLEY_SIZE, 20, VALLEY_SIZE),
        Enum.Material.Grass
    )

    -- Water feature – a small reflective lake in the valley centre
    terrain:FillCylinder(
        CFrame.new(0, VALLEY_HEIGHT - 1, 0),
        6, 90,                      -- height, radius
        Enum.Material.Water
    )

    -- Mountain ridge builder: creates a row of overlapping FillBlock columns
    local function buildMountainRidge(centreX, centreZ, peakCount, baseRadius, maxHeight, angle)
        local mat = Enum.Material.Rock
        local rng = Random.new(centreX * 7 + centreZ * 13)

        for i = 1, peakCount do
            -- Spread peaks along the ridge direction
            local spread = (i - peakCount / 2) * (baseRadius * 0.55)
            local cx = centreX + math.cos(angle) * spread
            local cz = centreZ + math.sin(angle) * spread

            local h  = maxHeight  * rng:NextNumber(0.65, 1.0)
            local r  = baseRadius * rng:NextNumber(0.7,  1.0)
            local jx = rng:NextNumber(-baseRadius * 0.15, baseRadius * 0.15)
            local jz = rng:NextNumber(-baseRadius * 0.15, baseRadius * 0.15)

            -- Stacked spheres to form a mountain silhouette
            local steps = 10
            for s = 0, steps do
                local t    = s / steps
                local yOff = t * h
                local rad  = r * math.sin(math.pi * (1 - t * 0.85)) -- wider base, tapered top

                terrain:FillBall(
                    Vector3.new(cx + jx, VALLEY_HEIGHT + yOff, cz + jz),
                    rad,
                    mat
                )
            end

            -- Snow cap on tall peaks
            if h > maxHeight * 0.75 then
                terrain:FillBall(
                    Vector3.new(cx + jx, VALLEY_HEIGHT + h - 8, cz + jz),
                    baseRadius * 0.22,
                    Enum.Material.Snow
                )
            end
        end
    end

    -- Back-left ridge (behind the player viewpoint, stage-left)
    buildMountainRidge(-260, -330, 5, 70, 320, math.rad(15))
    -- Back-right ridge
    buildMountainRidge( 280, -340, 5, 70, 290, math.rad(-10))
    -- Distant centre peak – lone sentinel
    buildMountainRidge(  30, -480, 2, 55, 380, math.rad(0))
    -- Foreground low hills on the sides to frame the scene
    buildMountainRidge(-380,  50,  4, 50, 130, math.rad(80))
    buildMountainRidge( 400,  60,  4, 50, 120, math.rad(95))

    -- Forest treeline at mountain bases (cosmetic cylinder stand-ins)
    local treePositions = {
        {-180, 10}, {-200, -40}, {-160, -70}, {-220, 30},
        { 180, 15}, { 200, -35}, { 160, -65}, { 220, 35},
        {-120, -100}, {120, -90}, {-90, -110}, {95, -100},
    }
    for _, pos in ipairs(treePositions) do
        local x, z = pos[1], pos[2]
        local rng2  = Random.new(x * 3 + z * 7)
        local count = rng2:NextInteger(3, 6)
        for _ = 1, count do
            local ox = rng2:NextNumber(-18, 18)
            local oz = rng2:NextNumber(-18, 18)
            local h2  = rng2:NextNumber(12, 22)
            terrain:FillCylinder(
                CFrame.new(x + ox, VALLEY_HEIGHT + h2 / 2, z + oz),
                h2, rng2:NextNumber(5, 9),
                Enum.Material.LeafyGrass
            )
        end
    end
end

-- ──────────────────────────────────────────────
-- 3. LANTERN BUILDER
-- ──────────────────────────────────────────────
local LANTERN_RISE_SPEED = 4.5    -- studs per second upward
local LANTERN_DRIFT      = 1.8    -- horizontal drift amplitude
local LANTERN_COUNT      = 38

local function createLanternModel(parent)
    local model = Instance.new("Model", parent)
    model.Name  = "Lantern"

    -- Paper body
    local body = Instance.new("Part", model)
    body.Name        = "Body"
    body.Size        = Vector3.new(1.6, 2.2, 1.6)
    body.Shape       = Enum.PartType.Cylinder
    body.BrickColor  = BrickColor.new("Bright orange")
    body.Material    = Enum.Material.SmoothPlastic
    body.CastShadow  = false
    body.Transparency = 0.35
    body.TopSurface  = Enum.SurfaceType.Smooth
    body.BottomSurface = Enum.SurfaceType.Smooth
    body.CFrame      = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)

    -- Cap (top)
    local capTop = Instance.new("SpecialMesh", body)
    capTop.MeshType = Enum.MeshType.Cylinder

    -- Warm glow inside
    local flame = Instance.new("PointLight", body)
    flame.Color      = Color3.fromRGB(255, 195, 80)
    flame.Brightness = 4.5
    flame.Range      = 22
    flame.Shadows    = false

    -- Subtle inner fire particles
    local fireAttach = Instance.new("Attachment", body)
    fireAttach.Position = Vector3.new(0, -0.6, 0)

    local fire = Instance.new("Fire", body)
    fire.Heat       = 3
    fire.Size       = 0.6
    fire.Color      = Color3.fromRGB(255, 170, 40)
    fire.SecondaryColor = Color3.fromRGB(255, 80, 20)
    fire.Enabled    = true

    -- Thin bottom wire frame
    local base = Instance.new("Part", model)
    base.Name        = "Base"
    base.Size        = Vector3.new(1.4, 0.1, 1.4)
    base.BrickColor  = BrickColor.new("Dark orange")
    base.Material    = Enum.Material.Metal
    base.CastShadow  = false
    base.TopSurface  = Enum.SurfaceType.Smooth
    base.BottomSurface = Enum.SurfaceType.Smooth

    -- Weld base to body
    local weld = Instance.new("WeldConstraint", body)
    weld.Part0 = body
    weld.Part1 = base

    model.PrimaryPart = body
    return model, body
end

local function spawnLanterns(folder)
    local rng    = Random.new(42)
    local origin = Vector3.new(0, 2, 0)  -- spawn above the lake centre

    for i = 1, LANTERN_COUNT do
        local angle  = (i / LANTERN_COUNT) * math.pi * 2
        local radius = rng:NextNumber(12, 55)
        local startY = rng:NextNumber(-2, 8)

        local startPos = Vector3.new(
            origin.X + math.cos(angle) * radius,
            origin.Y + startY,
            origin.Z + math.sin(angle) * radius
        )

        local model, body = createLanternModel(folder)
        model:SetPrimaryPartCFrame(CFrame.new(startPos))

        -- Each lantern rises independently
        local phase    = rng:NextNumber(0, math.pi * 2)
        local driftX   = rng:NextNumber(-1, 1)
        local driftZ   = rng:NextNumber(-1, 1)
        local riseSpeed = LANTERN_RISE_SPEED * rng:NextNumber(0.7, 1.3)
        local spawnTime = tick()

        task.spawn(function()
            local lastT = tick()
            while model and model.Parent do
                local now  = tick()
                local dt   = now - lastT
                lastT      = now

                local elapsed = now - spawnTime
                local pos     = body.Position

                local newY = pos.Y + riseSpeed * dt
                local newX = pos.X + math.sin(elapsed * 0.4 + phase) * LANTERN_DRIFT * dt * driftX
                local newZ = pos.Z + math.cos(elapsed * 0.3 + phase) * LANTERN_DRIFT * dt * driftZ

                -- Gentle rotation
                body.CFrame = CFrame.new(newX, newY, newZ)
                    * CFrame.Angles(0, 0, math.pi / 2)
                    * CFrame.Angles(
                        math.sin(elapsed * 0.5) * 0.04,
                        elapsed * 0.18,
                        math.cos(elapsed * 0.5) * 0.04
                    )

                -- Fade out and re-spawn when very high
                if newY > 350 then
                    local newAngle  = rng:NextNumber(0, math.pi * 2)
                    local newRadius = rng:NextNumber(12, 55)
                    local resetPos  = Vector3.new(
                        origin.X + math.cos(newAngle) * newRadius,
                        origin.Y + rng:NextNumber(-2, 6),
                        origin.Z + math.sin(newAngle) * newRadius
                    )
                    body.CFrame = CFrame.new(resetPos) * CFrame.Angles(0, 0, math.pi / 2)
                    spawnTime   = tick()
                end

                RunService.Heartbeat:Wait()
            end
        end)
    end
end

-- ──────────────────────────────────────────────
-- 4. DECORATIVE ELEMENTS
-- ──────────────────────────────────────────────
local function buildDecorations(folder)
    -- Stone platform / viewpoint where players stand
    local platform = Instance.new("Part", folder)
    platform.Name        = "ViewingPlatform"
    platform.Size        = Vector3.new(28, 2, 28)
    platform.CFrame      = CFrame.new(0, 1, 30)
    platform.Anchored    = true
    platform.BrickColor  = BrickColor.new("Medium stone grey")
    platform.Material    = Enum.Material.SmoothPlastic
    platform.TopSurface  = Enum.SurfaceType.Smooth
    platform.BottomSurface = Enum.SurfaceType.Smooth

    -- Low stone railings around platform
    local railData = {
        { Vector3.new(28, 1.2, 1), Vector3.new(0, 2, 44.5) },
        { Vector3.new(28, 1.2, 1), Vector3.new(0, 2, 15.5) },
        { Vector3.new(1, 1.2, 28), Vector3.new(14.5, 2, 30) },
        { Vector3.new(1, 1.2, 28), Vector3.new(-14.5, 2, 30) },
    }
    for _, rd in ipairs(railData) do
        local rail = Instance.new("Part", folder)
        rail.Size          = rd[1]
        rail.CFrame        = CFrame.new(rd[2])
        rail.Anchored      = true
        rail.BrickColor    = BrickColor.new("Medium stone grey")
        rail.Material      = Enum.Material.SmoothPlastic
        rail.TopSurface    = Enum.SurfaceType.Smooth
        rail.BottomSurface = Enum.SurfaceType.Smooth
    end

    -- Hanging paper lantern strings (static decorative lanterns on poles)
    local polePositions = {
        Vector3.new(-10, 2, 28), Vector3.new(10, 2, 28),
        Vector3.new(-10, 2, 32), Vector3.new(10, 2, 32),
    }
    for _, ppos in ipairs(polePositions) do
        local pole = Instance.new("Part", folder)
        pole.Name        = "Pole"
        pole.Size        = Vector3.new(0.3, 7, 0.3)
        pole.CFrame      = CFrame.new(ppos + Vector3.new(0, 3.5, 0))
        pole.Anchored    = true
        pole.BrickColor  = BrickColor.new("Reddish brown")
        pole.Material    = Enum.Material.Wood
        pole.TopSurface  = Enum.SurfaceType.Smooth
        pole.BottomSurface = Enum.SurfaceType.Smooth

        -- Small decorative lantern on top of each pole
        local deco = Instance.new("Part", folder)
        deco.Size          = Vector3.new(0.9, 1.2, 0.9)
        deco.CFrame        = CFrame.new(ppos + Vector3.new(0, 8, 0))
        deco.Anchored      = true
        deco.BrickColor    = BrickColor.new("Bright red")
        deco.Material      = Enum.Material.SmoothPlastic
        deco.Transparency  = 0.25
        deco.TopSurface    = Enum.SurfaceType.Smooth
        deco.BottomSurface = Enum.SurfaceType.Smooth
        deco.CastShadow    = false

        local glow = Instance.new("PointLight", deco)
        glow.Color      = Color3.fromRGB(255, 160, 60)
        glow.Brightness = 2.5
        glow.Range      = 14
        glow.Shadows    = false
    end

    -- Firefly-like ambient particles in the valley
    local particleRoot = Instance.new("Part", folder)
    particleRoot.Name        = "FireflyEmitter"
    particleRoot.Size        = Vector3.new(1, 1, 1)
    particleRoot.CFrame      = CFrame.new(0, 3, 0)
    particleRoot.Anchored    = true
    particleRoot.Transparency = 1
    particleRoot.CanCollide  = false
    particleRoot.CastShadow  = false

    local emitAttach = Instance.new("Attachment", particleRoot)
    local particles  = Instance.new("ParticleEmitter", particleRoot)
    particles.Color        = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 230, 100)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 255, 150)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 210,  80)),
    })
    particles.LightEmission  = 1
    particles.LightInfluence = 0
    particles.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.3, 0.18),
        NumberSequenceKeypoint.new(1,   0),
    })
    particles.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   1),
        NumberSequenceKeypoint.new(0.2, 0.1),
        NumberSequenceKeypoint.new(0.8, 0.1),
        NumberSequenceKeypoint.new(1,   1),
    })
    particles.Lifetime       = NumberRange.new(4, 8)
    particles.Rate           = 18
    particles.Speed          = NumberRange.new(0.5, 2)
    particles.SpreadAngle    = Vector2.new(80, 80)
    particles.RotSpeed       = NumberRange.new(-45, 45)
    particles.Rotation       = NumberRange.new(0, 360)
    particles.EmissionDirection = Enum.NormalId.Top
    -- Spread particles across a wide area
    local spread = Instance.new("Part", folder)
    spread.Size        = Vector3.new(120, 0.1, 120)
    spread.CFrame      = CFrame.new(0, 1.5, 0)
    spread.Anchored    = true
    spread.Transparency = 1
    spread.CanCollide  = false
    spread.CastShadow  = false

    local spreadAttach = Instance.new("Attachment", spread)
    local spreadEmit   = particles:Clone()
    spreadEmit.Rate    = 32
    spreadEmit.Parent  = spread
end

-- ──────────────────────────────────────────────
-- 5. RESPAWN CAMERA HINT
--    Push SpawnLocation to the viewing platform
-- ──────────────────────────────────────────────
local function setupSpawnLocation()
    local spawn = Instance.new("SpawnLocation", Workspace)
    spawn.CFrame      = CFrame.new(0, 3, 30)
    spawn.Size        = Vector3.new(6, 1, 6)
    spawn.Anchored    = true
    spawn.BrickColor  = BrickColor.new("Medium stone grey")
    spawn.Material    = Enum.Material.SmoothPlastic
    spawn.TopSurface  = Enum.SurfaceType.Smooth
    spawn.BottomSurface = Enum.SurfaceType.Smooth
    spawn.Neutral     = true
    spawn.TeamColor   = BrickColor.new("White")
end

-- ──────────────────────────────────────────────
-- MAIN
-- ──────────────────────────────────────────────
setupLighting()

local sceneryFolder = Instance.new("Folder", Workspace)
sceneryFolder.Name  = "TwilightScenery"

buildTerrain()

buildDecorations(sceneryFolder)

local lanternFolder = Instance.new("Folder", sceneryFolder)
lanternFolder.Name  = "Lanterns"
spawnLanterns(lanternFolder)

setupSpawnLocation()

print("[TwilightScenery] Scene loaded successfully.")
