--[[
    WorldBuilder.server.lua
    Constructs the entire twilight lantern-festival world:
    - Twilight sky with gradient, moon, and stars
    - Baseplate
    - Mountain range backdrop
    - Zigzag trail from spawn to Breathing Milestone → Bonfire → Glow Pond
    - Breathing milestone arch
    - Bonfire with musician NPC
    - Glow pond with shimmer surface
    - Ambient lighting and atmosphere
]]

local Lighting   = game:GetService("Lighting")
local Workspace  = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- ── helpers ──────────────────────────────────────────────────────────────────

local function part(parent, props)
    local p = Instance.new("Part")
    p.Anchored  = true
    p.CanCollide = props.CanCollide ~= nil and props.CanCollide or true
    p.Size      = props.Size  or Vector3.new(4, 4, 4)
    p.CFrame    = props.CFrame or CFrame.new(0, 0, 0)
    p.BrickColor = props.BrickColor or BrickColor.new("Medium stone grey")
    p.Material  = props.Material  or Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Transparency = props.Transparency or 0
    p.Name      = props.Name or "Part"
    p.CastShadow = props.CastShadow ~= nil and props.CastShadow or true
    p.Parent    = parent
    return p
end

local function weld(a, b)
    local w = Instance.new("WeldConstraint")
    w.Part0 = a
    w.Part1 = b
    w.Parent = a
    return w
end

local function sphere(parent, props)
    local p = part(parent, props)
    p.Shape = Enum.PartType.Ball
    return p
end

local function cylinder(parent, props)
    local p = part(parent, props)
    p.Shape = Enum.PartType.Cylinder
    return p
end

local function addDecal(p, face, id, transparency)
    local d = Instance.new("Decal")
    d.Face = face or Enum.NormalId.Top
    d.Texture = id
    d.Transparency = transparency or 0
    d.Parent = p
    return d
end

local function addPointLight(p, brightness, range, color)
    local l = Instance.new("PointLight")
    l.Brightness = brightness or 1
    l.Range      = range     or 20
    l.Color      = color     or Color3.fromRGB(255, 220, 100)
    l.Shadows    = true
    l.Parent     = p
    return l
end

local function addSurfaceLight(p, brightness, range, color)
    local l = Instance.new("SurfaceLight")
    l.Brightness = brightness or 1
    l.Range      = range     or 20
    l.Color      = color     or Color3.fromRGB(255, 220, 100)
    l.Face       = Enum.NormalId.Top
    l.Parent     = p
    return l
end

local function addBillboard(p, text, textColor, studSize, offset)
    local bg = Instance.new("BillboardGui")
    bg.Size    = UDim2.new(0, studSize * 20 or 200, 0, 60)
    bg.StudsOffset = offset or Vector3.new(0, 3, 0)
    bg.AlwaysOnTop = false
    bg.Parent = p
    local lbl = Instance.new("TextLabel")
    lbl.Size  = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text  = text
    lbl.TextColor3 = textColor or Color3.fromRGB(255, 240, 180)
    lbl.TextScaled = true
    lbl.Font  = Enum.Font.GothamBold
    lbl.Parent = bg
    return bg
end

-- ── FOLDER LAYOUT ─────────────────────────────────────────────────────────────

local worldFolder = Instance.new("Folder")
worldFolder.Name  = "LanternWorld"
worldFolder.Parent = Workspace

local function folder(name, parent)
    local f = Instance.new("Folder")
    f.Name   = name
    f.Parent = parent or worldFolder
    return f
end

local fSky      = folder("Sky")
local fTerrain  = folder("Terrain")
local fMountains= folder("Mountains")
local fTrail    = folder("Trail")
local fBreath   = folder("BreathingMilestone")
local fBonfire  = folder("Bonfire")
local fPond     = folder("GlowPond")
local fDeco     = folder("Decorations")

-- ── LIGHTING / SKY ────────────────────────────────────────────────────────────

Lighting.Ambient          = Color3.fromRGB(40, 30, 65)
Lighting.OutdoorAmbient   = Color3.fromRGB(70, 50, 100)
Lighting.Brightness       = 1.2
Lighting.ColorShift_Bottom= Color3.fromRGB(20, 10, 40)
Lighting.ColorShift_Top   = Color3.fromRGB(255, 130, 60)
Lighting.FogColor         = Color3.fromRGB(50, 35, 80)
Lighting.FogStart         = 200
Lighting.FogEnd           = 600
Lighting.ClockTime        = 19.5   -- deep twilight
Lighting.GeographicLatitude = 30

-- Atmosphere
local atmo = Instance.new("Atmosphere")
atmo.Density     = 0.45
atmo.Offset      = 0.18
atmo.Color       = Color3.fromRGB(200, 100, 60)
atmo.Decay       = Color3.fromRGB(90, 50, 110)
atmo.Glare       = 0.15
atmo.Haze        = 1.8
atmo.Parent      = Lighting

-- Sky
local sky = Instance.new("Sky")
sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
sky.StarCount = 4000
sky.Parent    = Lighting

-- Bloom + ColorCorrection for cinematic feel
local bloom = Instance.new("BloomEffect")
bloom.Intensity  = 0.6
bloom.Size       = 24
bloom.Threshold  = 0.9
bloom.Parent     = Lighting

local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.2
cc.TintColor  = Color3.fromRGB(200, 170, 255)
cc.Brightness = -0.06
cc.Contrast   = 0.12
cc.Parent     = Lighting

-- Sun-glow / Blur
local blur = Instance.new("BlurEffect")
blur.Size   = 0
blur.Parent = Lighting

-- ── MOON ──────────────────────────────────────────────────────────────────────

local moon = sphere(fSky, {
    Name       = "Moon",
    Size       = Vector3.new(30, 30, 30),
    CFrame     = CFrame.new(-180, 260, -400),
    BrickColor = BrickColor.new("White"),
    Material   = Enum.Material.Neon,
    Transparency = 0,
    CastShadow = false,
    CanCollide = false,
})

-- Moon glow aura
local moonAura = sphere(fSky, {
    Name        = "MoonAura",
    Size        = Vector3.new(55, 55, 55),
    CFrame      = moon.CFrame,
    BrickColor  = BrickColor.new("Institutional white"),
    Material    = Enum.Material.Neon,
    Transparency= 0.85,
    CastShadow  = false,
    CanCollide  = false,
})

addPointLight(moon, 0.6, 120, Color3.fromRGB(200, 210, 255))

-- ── STARS (decorative large stars near scene) ────────────────────────────────

local starPositions = {
    Vector3.new(100, 300, -350),
    Vector3.new(-120, 320, -380),
    Vector3.new(200, 280, -320),
    Vector3.new(-200, 310, -360),
    Vector3.new(50,  350, -420),
    Vector3.new(-60, 290, -300),
    Vector3.new(300, 270, -340),
    Vector3.new(-300, 340, -390),
    Vector3.new(150, 380, -450),
    Vector3.new(-150, 360, -410),
    Vector3.new(80,  220, -250),
    Vector3.new(-80, 240, -270),
}

for i, pos in ipairs(starPositions) do
    local starSize = math.random(2, 6)
    local s = sphere(fSky, {
        Name        = "Star" .. i,
        Size        = Vector3.new(starSize, starSize, starSize),
        CFrame      = CFrame.new(pos),
        BrickColor  = BrickColor.new("Institutional white"),
        Material    = Enum.Material.Neon,
        Transparency= math.random(0, 25) / 100,
        CastShadow  = false,
        CanCollide  = false,
    })
    -- Twinkle via PointLight
    addPointLight(s, 0.3, starSize * 3, Color3.fromRGB(220, 230, 255))
end

-- ── SUNSET GLOW PLANE (far horizon) ──────────────────────────────────────────

local horizonGlow = part(fSky, {
    Name        = "HorizonGlow",
    Size        = Vector3.new(1200, 60, 4),
    CFrame      = CFrame.new(0, 40, -500),
    BrickColor  = BrickColor.new("Deep orange"),
    Material    = Enum.Material.Neon,
    Transparency= 0.55,
    CastShadow  = false,
    CanCollide  = false,
})

local horizonGlow2 = part(fSky, {
    Name        = "HorizonGlow2",
    Size        = Vector3.new(1200, 30, 4),
    CFrame      = CFrame.new(0, 65, -498),
    BrickColor  = BrickColor.new("Bright orange"),
    Material    = Enum.Material.Neon,
    Transparency= 0.72,
    CastShadow  = false,
    CanCollide  = false,
})

-- ── BASEPLATE ─────────────────────────────────────────────────────────────────

local baseplate = part(fTerrain, {
    Name        = "Baseplate",
    Size        = Vector3.new(1000, 4, 1000),
    CFrame      = CFrame.new(0, -2, 0),
    BrickColor  = BrickColor.new("Dark green"),
    Material    = Enum.Material.Grass,
    CanCollide  = true,
})

-- Subtle rolling hills via overlapping plates
local hillData = {
    { Vector3.new(300, 12, 300), CFrame.new(180, 4,  150), "Moss" },
    { Vector3.new(250, 10, 250), CFrame.new(-200, 3, 180), "Moss" },
    { Vector3.new(200, 8,  200), CFrame.new(50,  2,  300), "Moss" },
}
for _, hd in ipairs(hillData) do
    part(fTerrain, {
        Name        = "Hill",
        Size        = hd[1],
        CFrame      = hd[2],
        BrickColor  = BrickColor.new(hd[3]),
        Material    = Enum.Material.Grass,
    })
end

-- ── MOUNTAINS ─────────────────────────────────────────────────────────────────

-- Each mountain: {width, height, depth, cx, cz, colorName}
local mountainData = {
    { 160, 260, 140, -320, -380, "Dark grey" },
    { 200, 320, 160, -180, -420, "Dark grey" },
    { 180, 280, 150, -60,  -450, "Dark grey" },
    { 200, 300, 160,  80,  -440, "Dark grey" },
    { 170, 260, 140,  220, -400, "Dark grey" },
    { 140, 220, 120,  340, -370, "Dark grey" },
    -- Snow caps
    { 100, 80,  90,  -180, -420, "White" },
    { 90,  70,  85,  -60,  -450, "White" },
    { 95,  75,  88,   80,  -440, "White" },
}

for i, md in ipairs(mountainData) do
    local w, h, d, cx, cz, col = md[1], md[2], md[3], md[4], md[5], md[6]
    -- Build wedge-like mountain from stacked layers
    local layers = 8
    for layer = 1, layers do
        local t    = layer / layers
        local lw   = w * (1 - t * 0.85)
        local ld   = d * (1 - t * 0.85)
        local ly   = (layer - 0.5) * (h / layers)
        part(fMountains, {
            Name        = "Mountain" .. i .. "_L" .. layer,
            Size        = Vector3.new(lw, h / layers + 2, ld),
            CFrame      = CFrame.new(cx, ly, cz),
            BrickColor  = BrickColor.new(col == "White" and layer <= 2 and "White" or col),
            Material    = col == "White" and Enum.Material.SmoothPlastic or Enum.Material.Rock,
        })
    end
end

-- ── ZIGZAG TRAIL ──────────────────────────────────────────────────────────────
--[[
    Trail waypoints (flat coordinates, Y=0 ground):
    Spawn  (0, 0, 0)
     → W1  (30, 0, -30)
     → W2  (-30, 0, -70)
     → W3  (30, 0, -110)
     → W4  (-30, 0, -150) ← Breathing Milestone
     → W5  (30, 0, -190)
     → W6  (-30, 0, -230)
     → W7  (30, 0, -270)  ← Bonfire
     → W8  (-30, 0, -310)
     → W9  (30, 0, -350)
     → W10 (0, 0, -390)   ← Glow Pond
]]

local trailWaypoints = {
    Vector3.new(0,   1,   0),
    Vector3.new(30,  1, -30),
    Vector3.new(-30, 1, -70),
    Vector3.new(30,  1,-110),
    Vector3.new(-30, 1,-150),  -- [5] Breathing
    Vector3.new(30,  1,-190),
    Vector3.new(-30, 1,-230),
    Vector3.new(30,  1,-270),  -- [8] Bonfire
    Vector3.new(-30, 1,-310),
    Vector3.new(30,  1,-350),
    Vector3.new(0,   1,-390),  -- [11] Glow Pond
}

-- Store waypoints in ReplicatedStorage so clients can read them
local RS = game:GetService("ReplicatedStorage")
local waypointsFolder = Instance.new("Folder")
waypointsFolder.Name = "TrailWaypoints"
waypointsFolder.Parent = RS
for i, wp in ipairs(trailWaypoints) do
    local v = Instance.new("Vector3Value")
    v.Name  = tostring(i)
    v.Value = wp
    v.Parent = waypointsFolder
end

-- Build trail path segments (stone cobble)
for i = 1, #trailWaypoints - 1 do
    local a = trailWaypoints[i]
    local b = trailWaypoints[i + 1]
    local mid   = (a + b) / 2
    local dist  = (b - a).Magnitude
    local look  = CFrame.lookAt(a, b)
    -- Pave with multiple small stones per segment
    local numStones = math.ceil(dist / 3)
    for s = 0, numStones do
        local t  = s / numStones
        local pos = a:Lerp(b, t)
        -- slight wobble for natural feel
        local offset = Vector3.new(math.random(-8,8)/10, 0, math.random(-8,8)/10)
        part(fTrail, {
            Name        = "Stone",
            Size        = Vector3.new(2.5, 0.35, 2.5),
            CFrame      = CFrame.new(pos + offset),
            BrickColor  = BrickColor.new("Medium stone grey"),
            Material    = Enum.Material.Cobblestone,
        })
    end
    -- Lantern posts every other segment
    if i % 2 == 0 then
        local postPos = Vector3.new(mid.X + 2.5, 0, mid.Z)
        local post = part(fDeco, {
            Name     = "LanternPost",
            Size     = Vector3.new(0.3, 4, 0.3),
            CFrame   = CFrame.new(postPos + Vector3.new(0, 2, 0)),
            BrickColor = BrickColor.new("Reddish brown"),
            Material = Enum.Material.Wood,
        })
        local lanternPart = part(fDeco, {
            Name        = "TrailLantern",
            Size        = Vector3.new(1, 1.4, 1),
            CFrame      = CFrame.new(postPos + Vector3.new(0, 4.7, 0)),
            BrickColor  = BrickColor.new("Bright yellow"),
            Material    = Enum.Material.Neon,
            Transparency= 0.4,
        })
        addPointLight(lanternPart, 0.8, 14, Color3.fromRGB(255, 210, 100))
    end
end

-- ── BREATHING MILESTONE ───────────────────────────────────────────────────────

local breathPos = trailWaypoints[5]

-- Stone arch
local archLeft = part(fBreath, {
    Name        = "ArchLeft",
    Size        = Vector3.new(1.2, 8, 1.2),
    CFrame      = CFrame.new(breathPos + Vector3.new(-4, 4, 0)),
    BrickColor  = BrickColor.new("Medium stone grey"),
    Material    = Enum.Material.SmoothPlastic,
})
local archRight = part(fBreath, {
    Name        = "ArchRight",
    Size        = Vector3.new(1.2, 8, 1.2),
    CFrame      = CFrame.new(breathPos + Vector3.new(4, 4, 0)),
    BrickColor  = BrickColor.new("Medium stone grey"),
    Material    = Enum.Material.SmoothPlastic,
})
local archTop = part(fBreath, {
    Name        = "ArchTop",
    Size        = Vector3.new(9, 1.2, 1.2),
    CFrame      = CFrame.new(breathPos + Vector3.new(0, 8.5, 0)),
    BrickColor  = BrickColor.new("Medium stone grey"),
    Material    = Enum.Material.SmoothPlastic,
})
-- Glow strips on arch
local archGlow = part(fBreath, {
    Name        = "ArchGlow",
    Size        = Vector3.new(8.6, 0.4, 0.4),
    CFrame      = CFrame.new(breathPos + Vector3.new(0, 8.5, -0.4)),
    BrickColor  = BrickColor.new("Cyan"),
    Material    = Enum.Material.Neon,
    Transparency= 0.2,
})
addPointLight(archGlow, 1.2, 25, Color3.fromRGB(100, 220, 255))

-- Sign above arch
addBillboard(archTop, "✦  Breathing Grove  ✦", Color3.fromRGB(180, 255, 230), 10, Vector3.new(0, 2, 0))

-- Zen stones around breathing spot
local zenRadius = 5
for i = 1, 6 do
    local angle = (i / 6) * math.pi * 2
    local zp    = breathPos + Vector3.new(math.cos(angle) * zenRadius, 0.4, math.sin(angle) * zenRadius)
    part(fBreath, {
        Name     = "ZenStone" .. i,
        Size     = Vector3.new(0.8, 0.8, 0.8),
        CFrame   = CFrame.new(zp),
        BrickColor = BrickColor.new("Light stone grey"),
        Material = Enum.Material.SmoothPlastic,
    })
end

-- Trigger zone (invisible, used by GameManager)
local breathTrigger = part(fBreath, {
    Name        = "BreathTrigger",
    Size        = Vector3.new(10, 6, 10),
    CFrame      = CFrame.new(breathPos + Vector3.new(0, 3, 0)),
    BrickColor  = BrickColor.new("Cyan"),
    Material    = Enum.Material.Neon,
    Transparency= 1,
    CanCollide  = false,
})
breathTrigger.Anchored = true

-- ── BONFIRE AREA ──────────────────────────────────────────────────────────────

local bonfirePos = trailWaypoints[8]

-- Ground platform / porch
local porch = part(fBonfire, {
    Name        = "Porch",
    Size        = Vector3.new(20, 0.6, 20),
    CFrame      = CFrame.new(bonfirePos + Vector3.new(0, 0, 0)),
    BrickColor  = BrickColor.new("Reddish brown"),
    Material    = Enum.Material.Wood,
})

-- Bonfire stones ring
for i = 1, 8 do
    local angle = (i / 8) * math.pi * 2
    local sp    = bonfirePos + Vector3.new(math.cos(angle) * 2.2, 0.5, math.sin(angle) * 2.2)
    part(fBonfire, {
        Name     = "FireRingStone" .. i,
        Size     = Vector3.new(0.9, 0.9, 0.9),
        CFrame   = CFrame.new(sp),
        BrickColor = BrickColor.new("Dark grey"),
        Material = Enum.Material.Rock,
    })
end

-- Fire base log
local log1 = part(fBonfire, {
    Name        = "Log1",
    Size        = Vector3.new(0.5, 0.5, 3),
    CFrame      = CFrame.new(bonfirePos + Vector3.new(0, 0.5, 0)),
    BrickColor  = BrickColor.new("Reddish brown"),
    Material    = Enum.Material.Wood,
})
local log2 = part(fBonfire, {
    Name        = "Log2",
    Size        = Vector3.new(0.5, 0.5, 3),
    CFrame      = CFrame.new(bonfirePos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.rad(60), 0),
    BrickColor  = BrickColor.new("Reddish brown"),
    Material    = Enum.Material.Wood,
})

-- Fire effect (neon layers)
local fireColors = {
    { Color3.fromRGB(255, 80, 0),  Vector3.new(1.4, 2.2, 1.4), 0.1 },
    { Color3.fromRGB(255, 160, 0), Vector3.new(1.0, 3.0, 1.0), 0.15 },
    { Color3.fromRGB(255, 220, 50),Vector3.new(0.6, 3.8, 0.6), 0.2 },
}
for fi, fd in ipairs(fireColors) do
    local fp = part(fBonfire, {
        Name        = "FireLayer" .. fi,
        Size        = fd[2],
        CFrame      = CFrame.new(bonfirePos + Vector3.new(0, fd[2].Y / 2 + 0.3, 0)),
        Material    = Enum.Material.Neon,
        Transparency= fd[3],
        CastShadow  = false,
        CanCollide  = false,
    })
    fp.BrickColor = BrickColor.new("Bright orange")
    fp.Color      = fd[1]
    if fi == 1 then
        addPointLight(fp, 3, 35, Color3.fromRGB(255, 150, 50))
    end
end

-- Smoke particles (using Smoke instance)
local smokePart = part(fBonfire, {
    Name        = "SmokePart",
    Size        = Vector3.new(0.5, 0.5, 0.5),
    CFrame      = CFrame.new(bonfirePos + Vector3.new(0, 4, 0)),
    Transparency= 1,
    CanCollide  = false,
})
local smoke = Instance.new("Smoke")
smoke.Color        = Color3.fromRGB(120, 100, 80)
smoke.Opacity      = 0.18
smoke.RiseVelocity = 4
smoke.Size         = 3
smoke.Parent       = smokePart

-- Musician NPC (simple humanoid representation)
local musicianRoot = Instance.new("Model")
musicianRoot.Name  = "Musician"
musicianRoot.Parent = fBonfire

local musicianSeat = bonfirePos + Vector3.new(5, 0.8, 0)
-- Body
local torso = part(musicianRoot, {
    Name     = "Torso",
    Size     = Vector3.new(2, 2, 1),
    CFrame   = CFrame.new(musicianSeat + Vector3.new(0, 1.8, 0)),
    BrickColor = BrickColor.new("Bright orange"),
    Material = Enum.Material.SmoothPlastic,
})
-- Head
local head = sphere(musicianRoot, {
    Name     = "Head",
    Size     = Vector3.new(1.4, 1.4, 1.4),
    CFrame   = CFrame.new(musicianSeat + Vector3.new(0, 3.5, 0)),
    BrickColor = BrickColor.new("Nougat"),
    Material = Enum.Material.SmoothPlastic,
})
-- Legs
local legL = part(musicianRoot, {
    Name     = "LegL",
    Size     = Vector3.new(0.9, 2, 0.9),
    CFrame   = CFrame.new(musicianSeat + Vector3.new(-0.55, 0, 0)),
    BrickColor = BrickColor.new("Dark blue"),
    Material = Enum.Material.SmoothPlastic,
})
local legR = part(musicianRoot, {
    Name     = "LegR",
    Size     = Vector3.new(0.9, 2, 0.9),
    CFrame   = CFrame.new(musicianSeat + Vector3.new(0.55, 0, 0)),
    BrickColor = BrickColor.new("Dark blue"),
    Material = Enum.Material.SmoothPlastic,
})
-- Guitar (simplified)
local guitarBody = part(musicianRoot, {
    Name        = "GuitarBody",
    Size        = Vector3.new(0.3, 1.6, 1.2),
    CFrame      = CFrame.new(musicianSeat + Vector3.new(-1.6, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(15)),
    BrickColor  = BrickColor.new("Reddish brown"),
    Material    = Enum.Material.Wood,
})
local guitarNeck = part(musicianRoot, {
    Name        = "GuitarNeck",
    Size        = Vector3.new(0.15, 2.2, 0.3),
    CFrame      = CFrame.new(musicianSeat + Vector3.new(-1.8, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(-25)),
    BrickColor  = BrickColor.new("Brown"),
    Material    = Enum.Material.Wood,
})

musicianRoot.PrimaryPart = torso

-- Billboard chat bubble above musician
addBillboard(head,
    "Hey traveller, come sit by the fire!\nWhat music speaks to your soul tonight?",
    Color3.fromRGB(255, 240, 200), 14, Vector3.new(0, 4, 0))

-- Trigger zone for musician
local musicianTrigger = part(fBonfire, {
    Name        = "MusicianTrigger",
    Size        = Vector3.new(14, 6, 14),
    CFrame      = CFrame.new(bonfirePos + Vector3.new(0, 3, 0)),
    Material    = Enum.Material.Neon,
    Transparency= 1,
    CanCollide  = false,
})

-- ── GLOW POND ─────────────────────────────────────────────────────────────────

local pondPos = trailWaypoints[11]

-- Pond bed
local pondBed = part(fPond, {
    Name        = "PondBed",
    Size        = Vector3.new(28, 1.5, 28),
    CFrame      = CFrame.new(pondPos + Vector3.new(0, -1.5, 0)),
    BrickColor  = BrickColor.new("Sand blue"),
    Material    = Enum.Material.SmoothPlastic,
})

-- Water surface
local water = part(fPond, {
    Name        = "Water",
    Size        = Vector3.new(26, 0.4, 26),
    CFrame      = CFrame.new(pondPos + Vector3.new(0, 0.2, 0)),
    BrickColor  = BrickColor.new("Cyan"),
    Material    = Enum.Material.Neon,
    Transparency= 0.45,
    CanCollide  = false,
})
addSurfaceLight(water, 1.4, 30, Color3.fromRGB(80, 200, 255))

-- Shimmering glow layer above water
local shimmer = part(fPond, {
    Name        = "Shimmer",
    Size        = Vector3.new(26, 0.15, 26),
    CFrame      = CFrame.new(pondPos + Vector3.new(0, 0.5, 0)),
    BrickColor  = BrickColor.new("Institutional white"),
    Material    = Enum.Material.Neon,
    Transparency= 0.75,
    CanCollide  = false,
})

-- Pond rim stones
for i = 1, 16 do
    local angle = (i / 16) * math.pi * 2
    local rx    = math.cos(angle) * 14
    local rz    = math.sin(angle) * 14
    part(fPond, {
        Name        = "RimStone" .. i,
        Size        = Vector3.new(1.8, 0.6, 1.8),
        CFrame      = CFrame.new(pondPos + Vector3.new(rx, 0.4, rz)),
        BrickColor  = BrickColor.new("Medium stone grey"),
        Material    = Enum.Material.Rock,
    })
end

-- Lily pads
local lilyPositions = {
    Vector3.new(4, 0.3, 3), Vector3.new(-5, 0.3, -4),
    Vector3.new(3, 0.3, -6), Vector3.new(-3, 0.3, 5),
    Vector3.new(7, 0.3, -2), Vector3.new(-7, 0.3, 2),
}
for i, lp in ipairs(lilyPositions) do
    local lily = cylinder(fPond, {
        Name        = "LilyPad" .. i,
        Size        = Vector3.new(2, 0.12, 2),
        CFrame      = CFrame.new(pondPos + lp) * CFrame.Angles(0, math.random(0, 6), 0),
        BrickColor  = BrickColor.new("Bright green"),
        Material    = Enum.Material.SmoothPlastic,
        CanCollide  = false,
    })
    -- Small lily flower
    sphere(fPond, {
        Name        = "LilyFlower" .. i,
        Size        = Vector3.new(0.5, 0.5, 0.5),
        CFrame      = CFrame.new(pondPos + lp + Vector3.new(0, 0.3, 0)),
        BrickColor  = BrickColor.new("Hot pink"),
        Material    = Enum.Material.Neon,
        Transparency= 0.1,
    })
end

-- Glow mist above pond (PointLight field)
for i = 1, 5 do
    local gp = part(fPond, {
        Name        = "GlowMist" .. i,
        Size        = Vector3.new(0.5, 0.5, 0.5),
        CFrame      = CFrame.new(pondPos + Vector3.new(math.random(-8,8), math.random(1,4), math.random(-8,8))),
        Transparency= 1,
        CanCollide  = false,
    })
    addPointLight(gp, 0.5, 18, Color3.fromRGB(100, 230, 255))
end

-- Lantern release zone
local releaseTrigger = part(fPond, {
    Name        = "ReleaseTrigger",
    Size        = Vector3.new(20, 6, 20),
    CFrame      = CFrame.new(pondPos + Vector3.new(0, 3, 0)),
    Material    = Enum.Material.Neon,
    Transparency= 1,
    CanCollide  = false,
})

addBillboard(water, "✦ Release your lantern here ✦",
    Color3.fromRGB(200, 255, 255), 12, Vector3.new(0, 4, 0))

-- ── AMBIENT FIREFLIES ─────────────────────────────────────────────────────────

for i = 1, 20 do
    local ffPos = Vector3.new(math.random(-60, 60), math.random(1, 6), math.random(-100, -50))
    local ff = sphere(fDeco, {
        Name        = "Firefly" .. i,
        Size        = Vector3.new(0.3, 0.3, 0.3),
        CFrame      = CFrame.new(ffPos),
        BrickColor  = BrickColor.new("Bright yellow"),
        Material    = Enum.Material.Neon,
        Transparency= 0.3,
        CanCollide  = false,
        CastShadow  = false,
    })
    addPointLight(ff, 0.25, 6, Color3.fromRGB(200, 255, 100))
end

-- ── SHIMMER ANIMATION (server-side tween loop) ───────────────────────────────

task.spawn(function()
    local ti = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    TweenService:Create(shimmer, ti, { Transparency = 0.55 }):Play()
    TweenService:Create(water,   TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.38 }):Play()
end)

print("[WorldBuilder] Twilight Lantern World loaded successfully.")
