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
Lighting.ClockTime        = 18   -- deep twilight
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
sky.MoonAngularSize = 0
sky.SkyboxBk = "rbxasset://textures/sky/sky256_bk.tex"
sky.SkyboxDn = "rbxasset://textures/sky/sky32_dn.tex"
sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
sky.SkyboxUp = "rbxasset://textures/sky/sky32_up.tex"
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
cc.Brightness = 0.1
cc.Contrast   = 0.12
cc.Parent     = Lighting

local bloom = Instance.new("BloomEffect", Lighting)
    bloom.Intensity = 1.2
    bloom.Size      = 36
    bloom.Threshold = 0.85

-- Sun-glow / Blur
local blur = Instance.new("BlurEffect")
blur.Size   = 0
blur.Parent = Lighting

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

local function buildPondGlow(folder)
    -- Thin neon disc sitting on the water surface – the main glow source
    local glowDisc = Instance.new("Part", folder)
    glowDisc.Name          = "PondGlow2"
    glowDisc.Shape         = Enum.PartType.Cylinder
    glowDisc.Size          = Vector3.new(0.3, 300, 300)
    glowDisc.CFrame        = CFrame.new(200, 0.15, -57) * CFrame.Angles(0, 90, 90)
    glowDisc.Anchored      = true
    glowDisc.CanCollide    = false
    glowDisc.CastShadow    = false
    glowDisc.Material      = Enum.Material.Neon
    glowDisc.Color         = Color3.fromRGB(245, 164, 66)   -- icy cyan glow
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
        aLight.Color      = Color3.fromRGB(245, 164, 66)
        aLight.Brightness = 2.2
        aLight.Range      = 40
        aLight.Shadows    = false
    end

    -- Ripple / shimmer particle emitter on the pond surface
    local emitPart = Instance.new("Part", folder)
    emitPart.Size        = Vector3.new(1, 1, 1)
    emitPart.CFrame      = CFrame.new(200, 0.15, -57)
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
    spreadEmit.CFrame      = CFrame.new(200, 0.15, -57)
    spreadEmit.Anchored    = true
    spreadEmit.CanCollide  = false
    spreadEmit.CastShadow  = false
    spreadEmit.Transparency = 1

    local shimmer2 = shimmer:Clone()
    shimmer2.Rate   = 20
    shimmer2.Parent = spreadEmit
end
local folder = Instance.new("Folder", Workspace)
folder.Name  = "GlowingPondScene"
-- buildTerrain()
-- buildPondGlow(folder)
-- buildScenery(folder)
-- setupSpawn()

print("[GlowingPondScene] Scene ready.")