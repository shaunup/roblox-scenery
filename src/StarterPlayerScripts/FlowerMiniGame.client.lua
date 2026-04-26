--[[
    FlowerMiniGame.client.lua
    ══════════════════════════════════════════════════════════════════════════
    Gratitude Garden Mini-Game
    ══════════════════════════════════════════════════════════════════════════

    Flow:
      1. GardenStart remote fires when player touches the GardenTrigger
      2. A 3-step prompt panel appears – one step per flower (9 plots, 3 used)
      3. Each step:
           a. Prompt asks "What are you grateful for?" (e.g. round 1/3)
           b. Player types text into a TextBox
           c. On submit → fires GardenFlower(text) to server
           d. Server echoes back the plot index to bloom
           e. Client animates a flower growing on that plot in the 3-D world
              (stem rises, petals fan out, sparkle burst)
      4. After 3 flowers → fires GardenComplete to server
      5. Full-garden celebration: all flowers pulse, confetti burst, lantern award banner
      6. Outro message fades before returning player to the trail

    3-D Flower:
      We build the flower directly in Workspace (client-side) at the plot
      position stored in RS/GardenPlots.  Because this is client-only it is
      purely cosmetic – no server replication needed.

      Anatomy per flower:
        Stem    – thin green cylinder, tweened from size 0 → full height
        Bloom   – sphere, appears when stem is done, tweened from size 0 → full
        Petals  – 5 small spheres arranged radially, fan out with a tween
        Glow    – PointLight inside bloom
        Sparkle – ParticleEmitter burst (emit once)
]]

local Players        = game:GetService("Players")
local RS             = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local Workspace      = game:GetService("Workspace")
local RunService     = game:GetService("RunService")

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")

-- Remotes
local evGardenStart          = RS:WaitForChild("GardenStart",          60)
local evGardenFlower         = RS:WaitForChild("GardenFlower",         60)
local evGardenComplete       = RS:WaitForChild("GardenComplete",       60)
local evGardenLanternAwarded = RS:WaitForChild("GardenLanternAwarded", 60)
local evLanternAwarded       = RS:WaitForChild("LanternAwarded",       60)

-- Plot positions from server
local gardenPlotsFolder = RS:WaitForChild("GardenPlots", 60)

local gameDone = false

-- ── Colour palettes for the 3 flowers ────────────────────────────────────────

local FLOWER_PALETTES = {
    -- { bloom colour,         petal colour,            glow colour              }
    { Color3.fromRGB(255, 180,  50), Color3.fromRGB(255, 220, 100), Color3.fromRGB(255, 200,  60) }, -- golden
    { Color3.fromRGB(220,  80, 200), Color3.fromRGB(255, 160, 240), Color3.fromRGB(200, 100, 220) }, -- violet
    { Color3.fromRGB( 80, 200, 120), Color3.fromRGB(160, 255, 180), Color3.fromRGB( 60, 220, 120) }, -- emerald
}

-- ── Helper: get plot world position ──────────────────────────────────────────

local function getPlotPosition(plotIndex)
    -- plotIndex 1-9; we use only 1-3 (one per flower)
    -- We spread them: plot 1 → bed1/center, 2 → bed2/center, 3 → bed3/center
    -- Actual positions stored by WorldBuilder: keys "1".."9"
    -- We map flower 1→plot2 (bed1 middle), flower 2→plot5 (bed2 middle), flower 3→plot8 (bed3 middle)
    local plotKeys = { "2", "5", "8" }
    local key = plotKeys[plotIndex]
    if not key then return Vector3.new(0, 0, 0) end
    local v = gardenPlotsFolder:FindFirstChild(key)
    return v and v.Value or Vector3.new(0, 0, 0)
end

-- ── Grow a flower at the given world position ─────────────────────────────────

local flowerFolder = Instance.new("Folder")
flowerFolder.Name   = "GardenFlowers_Client"
flowerFolder.Parent = Workspace

local function growFlower(plotIndex, palette)
    local pos    = getPlotPosition(plotIndex)
    local bloom  = palette[1]
    local petal  = palette[2]
    local gcolor = palette[3]

    local STEM_HEIGHT = 2.8
    local BLOOM_SIZE  = 1.1
    local PETAL_SIZE  = 0.6

    -- ── Stem ──
    local stem = Instance.new("Part")
    stem.Name        = "FlowerStem_" .. plotIndex
    stem.Size        = Vector3.new(0.18, 0.001, 0.18)   -- start near-zero height
    stem.CFrame      = CFrame.new(pos + Vector3.new(0, 0, 0))
    stem.Anchored    = true
    stem.CanCollide  = false
    stem.CastShadow  = false
    stem.Material    = Enum.Material.SmoothPlastic
    stem.Color       = Color3.fromRGB(50, 150, 60)
    stem.TopSurface  = Enum.SurfaceType.Smooth
    stem.BottomSurface = Enum.SurfaceType.Smooth
    stem.Parent      = flowerFolder

    -- Grow stem upward: adjust size and CFrame together
    local stemGrow = TweenService:Create(stem,
        TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Size   = Vector3.new(0.18, STEM_HEIGHT, 0.18),
            CFrame = CFrame.new(pos + Vector3.new(0, STEM_HEIGHT / 2, 0)),
        }
    )
    stemGrow:Play()

    task.wait(0.75)

    -- ── Bloom centre ──
    local bloomPart = Instance.new("Part")
    bloomPart.Name       = "FlowerBloom_" .. plotIndex
    bloomPart.Shape      = Enum.PartType.Ball
    bloomPart.Size       = Vector3.new(0.01, 0.01, 0.01)
    bloomPart.CFrame     = CFrame.new(pos + Vector3.new(0, STEM_HEIGHT, 0))
    bloomPart.Anchored   = true
    bloomPart.CanCollide = false
    bloomPart.CastShadow = false
    bloomPart.Material   = Enum.Material.Neon
    bloomPart.Color      = bloom
    bloomPart.Transparency = 0.05
    bloomPart.Parent     = flowerFolder

    local pl = Instance.new("PointLight", bloomPart)
    pl.Color      = gcolor
    pl.Brightness = 0.8
    pl.Range      = 10
    pl.Shadows    = false

    TweenService:Create(bloomPart,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = Vector3.new(BLOOM_SIZE, BLOOM_SIZE, BLOOM_SIZE) }
    ):Play()

    task.wait(0.35)

    -- ── Petals (5, arranged radially) ────────────────────────────────────────
    local petalParts = {}
    for p = 1, 5 do
        local angle = (p / 5) * math.pi * 2
        local px    = math.cos(angle) * 0.01   -- start collapsed at centre
        local pz    = math.sin(angle) * 0.01

        local petalPart = Instance.new("Part")
        petalPart.Name       = "Petal_" .. plotIndex .. "_" .. p
        petalPart.Shape      = Enum.PartType.Ball
        petalPart.Size       = Vector3.new(0.01, 0.01, 0.01)
        petalPart.CFrame     = CFrame.new(pos + Vector3.new(0, STEM_HEIGHT, 0))
        petalPart.Anchored   = true
        petalPart.CanCollide = false
        petalPart.CastShadow = false
        petalPart.Material   = Enum.Material.Neon
        petalPart.Color      = petal
        petalPart.Transparency = 0.15
        petalPart.Parent     = flowerFolder

        local targetX = math.cos(angle) * (BLOOM_SIZE * 0.8)
        local targetZ = math.sin(angle) * (BLOOM_SIZE * 0.8)

        TweenService:Create(petalPart,
            TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {
                Size   = Vector3.new(PETAL_SIZE, PETAL_SIZE * 0.5, PETAL_SIZE),
                CFrame = CFrame.new(pos + Vector3.new(targetX, STEM_HEIGHT + 0.1, targetZ)),
            }
        ):Play()
        table.insert(petalParts, petalPart)
    end

    task.wait(0.6)

    -- ── Sparkle burst ────────────────────────────────────────────────────────
    local sparkHost = Instance.new("Part")
    sparkHost.Size        = Vector3.new(0.1, 0.1, 0.1)
    sparkHost.CFrame      = CFrame.new(pos + Vector3.new(0, STEM_HEIGHT + 0.5, 0))
    sparkHost.Anchored    = true
    sparkHost.CanCollide  = false
    sparkHost.CastShadow  = false
    sparkHost.Transparency = 1
    sparkHost.Parent      = flowerFolder

    local burst = Instance.new("ParticleEmitter", sparkHost)
    burst.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   petal),
        ColorSequenceKeypoint.new(0.5, bloom),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 255, 255)),
    })
    burst.LightEmission  = 1
    burst.LightInfluence = 0
    burst.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.2, 0.35),
        NumberSequenceKeypoint.new(1,   0),
    })
    burst.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.8, 0.2),
        NumberSequenceKeypoint.new(1,   1),
    })
    burst.Lifetime    = NumberRange.new(0.8, 1.4)
    burst.Rate        = 0
    burst.Speed       = NumberRange.new(4, 9)
    burst.SpreadAngle = Vector2.new(80, 80)
    burst.RotSpeed    = NumberRange.new(-45, 45)
    burst.Rotation    = NumberRange.new(0, 360)

    burst:Emit(28)   -- one-shot burst
    task.delay(2, function() sparkHost:Destroy() end)

    -- Gentle continuous breathing tween on bloom
    task.spawn(function()
        while bloomPart and bloomPart.Parent do
            TweenService:Create(bloomPart,
                TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Size = Vector3.new(BLOOM_SIZE * 1.12, BLOOM_SIZE * 1.12, BLOOM_SIZE * 1.12) }
            ):Play()
            task.wait(2)
            TweenService:Create(bloomPart,
                TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Size = Vector3.new(BLOOM_SIZE, BLOOM_SIZE, BLOOM_SIZE) }
            ):Play()
            task.wait(2)
        end
    end)
end

-- ── All-garden celebration (all 3 flowers pulse + confetti) ──────────────────

local function celebrateAllFlowers()
    -- Pulse all bloom parts brighter
    for _, child in ipairs(flowerFolder:GetChildren()) do
        if child.Name:sub(1, 11) == "FlowerBloom" then
            TweenService:Create(child,
                TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Size = child.Size * 1.4 }
            ):Play()
            task.delay(0.65, function()
                TweenService:Create(child,
                    TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                    { Size = child.Size / 1.4 }
                ):Play()
            end)
        end
    end

    -- Confetti host above garden centre
    local confettiHost = Instance.new("Part")
    confettiHost.Size        = Vector3.new(0.1, 0.1, 0.1)
    confettiHost.CFrame      = CFrame.new(-30, 6, -230)
    confettiHost.Anchored    = true
    confettiHost.CanCollide  = false
    confettiHost.Transparency = 1
    confettiHost.Parent      = flowerFolder

    local confetti = Instance.new("ParticleEmitter", confettiHost)
    confetti.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 220, 50)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(220,  80, 200)),
        ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80,  200, 120)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(100, 180, 255)),
    })
    confetti.LightEmission  = 0.8
    confetti.LightInfluence = 0.2
    confetti.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.1, 0.55),
        NumberSequenceKeypoint.new(1,   0),
    })
    confetti.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.85, 0.0),
        NumberSequenceKeypoint.new(1,   1),
    })
    confetti.Lifetime    = NumberRange.new(2, 3.5)
    confetti.Rate        = 0
    confetti.Speed       = NumberRange.new(8, 18)
    confetti.SpreadAngle = Vector2.new(180, 180)
    confetti.RotSpeed    = NumberRange.new(-90, 90)
    confetti.Rotation    = NumberRange.new(0, 360)
    confetti:Emit(80)
    task.delay(4, function() confettiHost:Destroy() end)
end

-- ── Prompts for each flower ───────────────────────────────────────────────────

local PROMPTS = {
    "Think of someone who has shown you\nkindness. What are you grateful for?",
    "What moment today made you feel\nalive, even in a small way?",
    "What is one simple thing — a smell,\na sound, a feeling — that you treasure?",
}

local FLOWER_NAMES = { "Golden Sunbloom", "Violet Dreamflower", "Emerald Wishbloom" }

-- ── Build the mini-game UI ────────────────────────────────────────────────────

local function buildGameGui()
    local screen = Instance.new("ScreenGui")
    screen.Name           = "FlowerMiniGameGui"
    screen.ResetOnSpawn   = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Enabled        = false
    screen.Parent         = gui

    -- ── Backdrop ──
    local backdrop = Instance.new("Frame")
    backdrop.Name              = "Backdrop"
    backdrop.Size              = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3  = Color3.fromRGB(5, 3, 18)
    backdrop.BackgroundTransparency = 0.35
    backdrop.BorderSizePixel   = 0
    backdrop.Parent            = screen

    -- ── Main card ──
    local card = Instance.new("Frame")
    card.Name              = "Card"
    card.Size              = UDim2.new(0, 520, 0, 420)
    card.AnchorPoint       = Vector2.new(0.5, 0.5)
    card.Position          = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundColor3  = Color3.fromRGB(14, 9, 30)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel   = 0
    card.Parent            = backdrop
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 22)
    local cs = Instance.new("UIStroke", card)
    cs.Color     = Color3.fromRGB(180, 255, 180)
    cs.Thickness = 2

    -- Decorative petal row at top
    local petalRow = Instance.new("Frame")
    petalRow.Name              = "PetalRow"
    petalRow.Size              = UDim2.new(1, 0, 0, 6)
    petalRow.Position          = UDim2.new(0, 0, 0, 0)
    petalRow.BackgroundColor3  = Color3.fromRGB(100, 220, 140)
    petalRow.BackgroundTransparency = 0
    petalRow.BorderSizePixel   = 0
    petalRow.Parent            = card
    Instance.new("UICorner", petalRow).CornerRadius = UDim.new(0, 22)

    -- Step icons (3 flower dots at top of card)
    local dotsFrame = Instance.new("Frame")
    dotsFrame.Name              = "DotsFrame"
    dotsFrame.Size              = UDim2.new(0, 120, 0, 28)
    dotsFrame.AnchorPoint       = Vector2.new(0.5, 0)
    dotsFrame.Position          = UDim2.new(0.5, 0, 0, 18)
    dotsFrame.BackgroundTransparency = 1
    dotsFrame.Parent            = card
    local dotLayout = Instance.new("UIListLayout", dotsFrame)
    dotLayout.FillDirection  = Enum.FillDirection.Horizontal
    dotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dotLayout.Padding        = UDim.new(0, 14)

    local dots = {}
    for i = 1, 3 do
        local dot = Instance.new("TextLabel")
        dot.Name              = "Dot" .. i
        dot.Size              = UDim2.new(0, 28, 0, 28)
        dot.BackgroundColor3  = Color3.fromRGB(50, 50, 80)
        dot.BackgroundTransparency = 0
        dot.Text              = "🌱"
        dot.TextScaled        = true
        dot.Font              = Enum.Font.GothamBold
        dot.BorderSizePixel   = 0
        dot.Parent            = dotsFrame
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        dots[i] = dot
    end

    -- Garden label
    local gardenLabel = Instance.new("TextLabel")
    gardenLabel.Name              = "GardenLabel"
    gardenLabel.Size              = UDim2.new(1, -20, 0, 34)
    gardenLabel.Position          = UDim2.new(0, 10, 0, 50)
    gardenLabel.BackgroundTransparency = 1
    gardenLabel.Text              = "🌸  Garden of Gratitude  🌸"
    gardenLabel.TextColor3        = Color3.fromRGB(160, 255, 180)
    gardenLabel.TextScaled        = true
    gardenLabel.Font              = Enum.Font.GothamBold
    gardenLabel.Parent            = card

    -- Flower name (updates per round)
    local flowerName = Instance.new("TextLabel")
    flowerName.Name              = "FlowerName"
    flowerName.Size              = UDim2.new(1, -20, 0, 26)
    flowerName.Position          = UDim2.new(0, 10, 0, 86)
    flowerName.BackgroundTransparency = 1
    flowerName.Text              = ""
    flowerName.TextColor3        = Color3.fromRGB(255, 200, 80)
    flowerName.TextScaled        = true
    flowerName.Font              = Enum.Font.GothamSemibold
    flowerName.Parent            = card

    -- Prompt text
    local promptLabel = Instance.new("TextLabel")
    promptLabel.Name              = "PromptLabel"
    promptLabel.Size              = UDim2.new(1, -40, 0, 80)
    promptLabel.Position          = UDim2.new(0, 20, 0, 120)
    promptLabel.BackgroundTransparency = 1
    promptLabel.Text              = ""
    promptLabel.TextColor3        = Color3.fromRGB(220, 220, 220)
    promptLabel.TextSize          = 17
    promptLabel.Font              = Enum.Font.Gotham
    promptLabel.TextWrapped       = true
    promptLabel.TextXAlignment    = Enum.TextXAlignment.Left
    promptLabel.TextYAlignment    = Enum.TextYAlignment.Top
    promptLabel.Parent            = card

    -- Input box container
    local inputFrame = Instance.new("Frame")
    inputFrame.Name              = "InputFrame"
    inputFrame.Size              = UDim2.new(1, -40, 0, 80)
    inputFrame.Position          = UDim2.new(0, 20, 0, 210)
    inputFrame.BackgroundColor3  = Color3.fromRGB(28, 18, 52)
    inputFrame.BackgroundTransparency = 0
    inputFrame.BorderSizePixel   = 0
    inputFrame.Parent            = card
    Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0, 10)
    local is = Instance.new("UIStroke", inputFrame)
    is.Color     = Color3.fromRGB(80, 180, 100)
    is.Thickness = 1.5

    local textBox = Instance.new("TextBox")
    textBox.Name              = "InputBox"
    textBox.Size              = UDim2.new(1, -16, 1, 0)
    textBox.Position          = UDim2.new(0, 8, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.Text              = ""
    textBox.PlaceholderText   = "Write your gratitude here..."
    textBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 130)
    textBox.TextColor3        = Color3.fromRGB(220, 255, 220)
    textBox.TextSize          = 15
    textBox.Font              = Enum.Font.Gotham
    textBox.TextWrapped       = true
    textBox.MultiLine         = true
    textBox.ClearTextOnFocus  = false
    textBox.Parent            = inputFrame

    -- Character counter
    local charCount = Instance.new("TextLabel")
    charCount.Name              = "CharCount"
    charCount.Size              = UDim2.new(0, 60, 0, 20)
    charCount.AnchorPoint       = Vector2.new(1, 1)
    charCount.Position          = UDim2.new(1, -4, 1, -2)
    charCount.BackgroundTransparency = 1
    charCount.Text              = "0/120"
    charCount.TextColor3        = Color3.fromRGB(100, 140, 100)
    charCount.TextSize          = 11
    charCount.Font              = Enum.Font.Gotham
    charCount.TextXAlignment    = Enum.TextXAlignment.Right
    charCount.Parent            = inputFrame

    textBox:GetPropertyChangedSignal("Text"):Connect(function()
        local txt = textBox.Text:sub(1, 120)
        textBox.Text = txt
        charCount.Text = #txt .. "/120"
    end)

    -- Plant button
    local plantBtn = Instance.new("TextButton")
    plantBtn.Name              = "PlantBtn"
    plantBtn.Size              = UDim2.new(0, 200, 0, 44)
    plantBtn.AnchorPoint       = Vector2.new(0.5, 0)
    plantBtn.Position          = UDim2.new(0.5, 0, 0, 310)
    plantBtn.BackgroundColor3  = Color3.fromRGB(80, 180, 100)
    plantBtn.BackgroundTransparency = 0
    plantBtn.BorderSizePixel   = 0
    plantBtn.Text              = "🌱  Plant This Flower"
    plantBtn.TextColor3        = Color3.fromRGB(10, 40, 15)
    plantBtn.TextScaled        = true
    plantBtn.Font              = Enum.Font.GothamBold
    plantBtn.Parent            = card
    Instance.new("UICorner", plantBtn).CornerRadius = UDim.new(0, 12)

    -- Pulse animation on the plant button
    task.spawn(function()
        while plantBtn and plantBtn.Parent do
            TweenService:Create(plantBtn,
                TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { BackgroundColor3 = Color3.fromRGB(120, 220, 130) }):Play()
            task.wait(1)
            TweenService:Create(plantBtn,
                TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { BackgroundColor3 = Color3.fromRGB(80, 180, 100) }):Play()
            task.wait(1)
        end
    end)

    -- "Growing…" status line
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name              = "StatusLabel"
    statusLabel.Size              = UDim2.new(1, -20, 0, 28)
    statusLabel.Position          = UDim2.new(0, 10, 0, 364)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text              = ""
    statusLabel.TextColor3        = Color3.fromRGB(160, 230, 160)
    statusLabel.TextScaled        = true
    statusLabel.Font              = Enum.Font.GothamSemibold
    statusLabel.Parent            = card

    return screen, card, dots, flowerName, promptLabel, textBox, plantBtn, statusLabel
end

-- ── Completion banner ─────────────────────────────────────────────────────────

local function showGardenComplete()
    local screen = Instance.new("ScreenGui")
    screen.Name         = "GardenCompleteGui"
    screen.ResetOnSpawn = false
    screen.Parent       = gui

    local overlay = Instance.new("Frame")
    overlay.Size              = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3  = Color3.fromRGB(5, 20, 10)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel   = 0
    overlay.Parent            = screen

    TweenService:Create(overlay,
        TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 0.3 }):Play()
    task.wait(0.8)

    local card = Instance.new("Frame")
    card.Size              = UDim2.new(0, 480, 0, 320)
    card.AnchorPoint       = Vector2.new(0.5, 0.5)
    card.Position          = UDim2.new(0.5, 0, 0.9, 0)
    card.BackgroundColor3  = Color3.fromRGB(10, 28, 15)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel   = 0
    card.Parent            = overlay
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 20)
    local s = Instance.new("UIStroke", card)
    s.Color     = Color3.fromRGB(100, 230, 130)
    s.Thickness = 2

    local emojis = Instance.new("TextLabel")
    emojis.Size  = UDim2.new(1, 0, 0, 64)
    emojis.Position = UDim2.new(0, 0, 0, 10)
    emojis.BackgroundTransparency = 1
    emojis.Text  = "🌸  🌼  🌿"
    emojis.TextScaled = true
    emojis.Parent = card

    local title = Instance.new("TextLabel")
    title.Size   = UDim2.new(1, -20, 0, 44)
    title.Position = UDim2.new(0, 10, 0, 78)
    title.BackgroundTransparency = 1
    title.Text   = "Your Garden of Gratitude is in bloom"
    title.TextColor3 = Color3.fromRGB(160, 255, 180)
    title.TextScaled = true
    title.Font   = Enum.Font.GothamBold
    title.TextWrapped = true
    title.Parent = card

    local sub = Instance.new("TextLabel")
    sub.Size     = UDim2.new(1, -30, 0, 64)
    sub.Position = UDim2.new(0, 15, 0, 132)
    sub.BackgroundTransparency = 1
    sub.Text     = "Every flower you planted carries a seed of gratitude\ninto the world. Carry this feeling as you walk on."
    sub.TextColor3 = Color3.fromRGB(190, 210, 190)
    sub.TextSize   = 15
    sub.Font       = Enum.Font.Gotham
    sub.TextWrapped = true
    sub.TextXAlignment = Enum.TextXAlignment.Center
    sub.Parent   = card

    local lanternRow = Instance.new("TextLabel")
    lanternRow.Size     = UDim2.new(1, 0, 0, 44)
    lanternRow.Position = UDim2.new(0, 0, 0, 210)
    lanternRow.BackgroundTransparency = 1
    lanternRow.Text     = "🏮  You have received a second lantern  🏮"
    lanternRow.TextColor3 = Color3.fromRGB(255, 220, 80)
    lanternRow.TextScaled = true
    lanternRow.Font     = Enum.Font.GothamBold
    lanternRow.Parent   = card

    -- Slide up from below
    TweenService:Create(card,
        TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()

    task.delay(7, function()
        TweenService:Create(overlay,
            TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { BackgroundTransparency = 1 }):Play()
        task.delay(0.9, function() screen:Destroy() end)
    end)
end

-- ── Main mini-game loop ────────────────────────────────────────────────────────

local function runMiniGame()
    local screen, card, dots, flowerName, promptLabel, textBox, plantBtn, statusLabel
        = buildGameGui()

    screen.Enabled = true
    -- Animate card in
    card.Position  = UDim2.new(0.5, 0, 1.1, 0)
    TweenService:Create(card,
        TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
    task.wait(0.7)

    for round = 1, 3 do
        -- Update dots to show progress
        for i, dot in ipairs(dots) do
            if i < round then
                dot.Text             = "🌸"
                dot.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
            elseif i == round then
                dot.Text             = "🌱"
                dot.BackgroundColor3 = Color3.fromRGB(30, 80, 40)
            else
                dot.Text             = "🌑"
                dot.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
            end
        end

        flowerName.Text  = string.format("Flower %d of 3  –  %s", round, FLOWER_NAMES[round])
        promptLabel.Text = PROMPTS[round]
        textBox.Text     = ""
        statusLabel.Text = ""
        plantBtn.Active  = true
        plantBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
        plantBtn.Text    = "🌱  Plant This Flower"

        -- Wait for player to click Plant
        local submitted = false
        local submitText = ""

        local function doSubmit()
            local txt = textBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
            if #txt < 3 then
                statusLabel.Text      = "✦ Please write at least a few words ✦"
                statusLabel.TextColor3 = Color3.fromRGB(255, 140, 140)
                return
            end
            submitted  = true
            submitText = txt
        end

        local btnConn = plantBtn.MouseButton1Click:Connect(doSubmit)
        local boxConn = textBox.FocusLost:Connect(function(enter)
            if enter then doSubmit() end
        end)

        -- Spin-wait for submission
        while not submitted do task.wait(0.05) end
        btnConn:Disconnect()
        boxConn:Disconnect()

        -- Lock UI, show growing state
        plantBtn.Active = false
        plantBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 55)
        plantBtn.Text  = "🌿  Growing…"
        statusLabel.Text      = "✦  Your gratitude takes root…  ✦"
        statusLabel.TextColor3 = Color3.fromRGB(160, 240, 160)

        -- Fire to server with gratitude text
        evGardenFlower:FireServer(submitText)

        -- Server echoes back the plot index → handled by evGardenFlower.OnClientEvent below
        -- We wait for the echo (up to 5 s) via a BindableEvent
        local bloomEvent  = Instance.new("BindableEvent")
        local echoConn
        echoConn = evGardenFlower.OnClientEvent:Connect(function(plotIdx)
            echoConn:Disconnect()
            bloomEvent:Fire(plotIdx)
        end)

        local plotIdx = nil
        local t0 = tick()
        bloomEvent.Event:Connect(function(idx) plotIdx = idx end)
        while plotIdx == nil and tick() - t0 < 5 do task.wait(0.05) end
        bloomEvent:Destroy()

        -- Grow the 3-D flower
        if plotIdx then
            growFlower(plotIdx, FLOWER_PALETTES[round])
        end

        -- Short pause before next round
        task.wait(1.8)

        if round < 3 then
            statusLabel.Text = "Beautiful! On to the next flower…"
            task.wait(1.2)
        end
    end

    -- Final dot update
    for _, dot in ipairs(dots) do
        dot.Text             = "🌸"
        dot.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
    end
    plantBtn.Text = "✦  Garden in bloom  ✦"
    statusLabel.Text = ""
    task.wait(1)

    -- Animate card out
    TweenService:Create(card,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, -0.6, 0) }):Play()
    task.wait(0.55)
    screen.Enabled = false

    -- 3-D celebration
    celebrateAllFlowers()

    -- Tell server garden is complete
    evGardenComplete:FireServer()

    -- Show completion screen (triggered by evGardenLanternAwarded)
end

-- ── Event listeners ───────────────────────────────────────────────────────────

evGardenStart.OnClientEvent:Connect(function()
    if gameDone then return end
    gameDone = true
    task.spawn(runMiniGame)
end)

evGardenLanternAwarded.OnClientEvent:Connect(function()
    showGardenComplete()
end)

print("[FlowerMiniGame] Client ready.")
