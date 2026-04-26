--[[
  GardenUI.client.lua  (StarterGui LocalScript)
  Handles the Gratitude Garden mini-game UI and 3-D flower growth.

  Flow:
    OpenGarden (S→C) → show 3-round prompt card
    Player writes gratitude → GardenFlower (C→S)
    GardenFlower (S→C, plotIdx) → grow 3-D flower on that plot disc
    After 3 flowers → GardenComplete (C→S) → AwardLantern toast appears
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")

-- Remotes
local Remotes        = RS:WaitForChild("Remotes")
local OpenGarden     = Remotes:WaitForChild("OpenGarden")
local GardenFlower   = Remotes:WaitForChild("GardenFlower")
local GardenComplete = Remotes:WaitForChild("GardenComplete")

-- Plot positions published by GardenManager
local plotsFolder = RS:WaitForChild("GardenPlots", 30)

local done = false

-- ── Flower palettes ───────────────────────────────────────────────────────────
local PALETTES = {
    { Color3.fromRGB(255, 190,  50), Color3.fromRGB(255, 230, 110), Color3.fromRGB(255, 210,  70) },
    { Color3.fromRGB(215,  75, 200), Color3.fromRGB(255, 160, 240), Color3.fromRGB(195,  95, 220) },
    { Color3.fromRGB( 70, 200, 115), Color3.fromRGB(155, 255, 180), Color3.fromRGB( 55, 220, 120) },
}
local NAMES   = { "Golden Sunbloom", "Violet Dreamflower", "Emerald Wishbloom" }
local PROMPTS = {
    "Think of someone who showed you kindness.\nWhat made it meaningful to you?",
    "What small moment today made you feel\nalive or grateful?",
    "Name one simple thing — a sound, a feeling,\na view — that you truly treasure.",
}

-- ── Helper: get plot world position ──────────────────────────────────────────
local function getPlotPos(i)
    local v = plotsFolder and plotsFolder:FindFirstChild(tostring(i))
    return v and v.Value or Vector3.new(0, 5, 0)
end

-- ── 3-D flower ────────────────────────────────────────────────────────────────
local flowersFolder = Instance.new("Folder", Workspace)
flowersFolder.Name  = "GardenFlowers"

local function growFlower(plotIdx, palette)
    local pos   = getPlotPos(plotIdx)
    local bloom = palette[1]
    local petal = palette[2]
    local glow  = palette[3]
    local SH    = 2.6  -- stem height

    -- Stem rises
    local stem = Instance.new("Part", flowersFolder)
    stem.Size   = Vector3.new(0.18, 0.001, 0.18)
    stem.CFrame = CFrame.new(pos)
    stem.Anchored = true; stem.CanCollide = false; stem.CastShadow = false
    stem.Material = Enum.Material.SmoothPlastic
    stem.Color    = Color3.fromRGB(45, 140, 55)
    stem.TopSurface = Enum.SurfaceType.Smooth; stem.BottomSurface = Enum.SurfaceType.Smooth
    TweenService:Create(stem,
        TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size  = Vector3.new(0.18, SH, 0.18),
          CFrame = CFrame.new(pos + Vector3.new(0, SH / 2, 0)) }
    ):Play()
    task.wait(0.8)

    -- Bloom pops in
    local bl = Instance.new("Part", flowersFolder)
    bl.Shape       = Enum.PartType.Ball
    bl.Size        = Vector3.new(0.01, 0.01, 0.01)
    bl.CFrame      = CFrame.new(pos + Vector3.new(0, SH, 0))
    bl.Anchored    = true; bl.CanCollide = false; bl.CastShadow = false
    bl.Material    = Enum.Material.Neon; bl.Color = bloom; bl.Transparency = 0.05
    TweenService:Create(bl,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = Vector3.new(1, 1, 1) }
    ):Play()
    local pl = Instance.new("PointLight", bl)
    pl.Color = glow; pl.Brightness = 0.75; pl.Range = 10
    task.wait(0.3)

    -- 5 petals fan out
    for p = 1, 5 do
        local a  = (p / 5) * math.pi * 2
        local pp = Instance.new("Part", flowersFolder)
        pp.Shape       = Enum.PartType.Ball
        pp.Size        = Vector3.new(0.01, 0.01, 0.01)
        pp.CFrame      = CFrame.new(pos + Vector3.new(0, SH, 0))
        pp.Anchored    = true; pp.CanCollide = false; pp.CastShadow = false
        pp.Material    = Enum.Material.Neon; pp.Color = petal; pp.Transparency = 0.15
        TweenService:Create(pp,
            TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Size  = Vector3.new(0.55, 0.28, 0.55),
              CFrame = CFrame.new(pos + Vector3.new(math.cos(a)*0.8, SH+0.1, math.sin(a)*0.8)) }
        ):Play()
    end
    task.wait(0.6)

    -- One-shot sparkle burst
    local sh = Instance.new("Part", flowersFolder)
    sh.Size = Vector3.new(0.1, 0.1, 0.1)
    sh.CFrame = CFrame.new(pos + Vector3.new(0, SH + 0.5, 0))
    sh.Anchored = true; sh.CanCollide = false; sh.Transparency = 1
    local pe = Instance.new("ParticleEmitter", sh)
    pe.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, petal),
        ColorSequenceKeypoint.new(1, bloom),
    })
    pe.LightEmission = 1; pe.LightInfluence = 0
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.2, 0.3),
        NumberSequenceKeypoint.new(1,   0),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.8, 0.2),
        NumberSequenceKeypoint.new(1,   1),
    })
    pe.Lifetime    = NumberRange.new(0.8, 1.4)
    pe.Rate        = 0
    pe.Speed       = NumberRange.new(4, 10)
    pe.SpreadAngle = Vector2.new(80, 80)
    pe:Emit(26)
    task.delay(2, function() if sh then sh:Destroy() end end)

    -- Bloom breathes gently in a loop
    task.spawn(function()
        while bl and bl.Parent do
            TweenService:Create(bl,
                TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Size = Vector3.new(1.12, 1.12, 1.12) }):Play()
            task.wait(2)
            TweenService:Create(bl,
                TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Size = Vector3.new(1, 1, 1) }):Play()
            task.wait(2)
        end
    end)
end

-- ── UI builder ────────────────────────────────────────────────────────────────
local function buildUI()
    local screen = Instance.new("ScreenGui")
    screen.Name           = "GardenUI"
    screen.ResetOnSpawn   = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Enabled        = false
    screen.Parent         = gui

    local bg = Instance.new("Frame", screen)
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(5,3,18)
    bg.BackgroundTransparency = 0.32; bg.BorderSizePixel = 0

    local card = Instance.new("Frame", bg)
    card.Name = "Card"
    card.Size = UDim2.new(0, 460, 0, 440)
    card.AnchorPoint = Vector2.new(0, 0.5)
    card.Position    = UDim2.new(-0.55, 0, 0.5, 0)   -- starts off-screen to the left
    card.BackgroundColor3 = Color3.fromRGB(12, 8, 28)
    card.BackgroundTransparency = 0.05; card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 20)
    local cs = Instance.new("UIStroke", card)
    cs.Color = Color3.fromRGB(180, 255, 180); cs.Thickness = 2

    -- Progress dots (🌑 → 🌱 → 🌸)
    local dotRow = Instance.new("Frame", card)
    dotRow.Size = UDim2.new(0, 110, 0, 26)
    dotRow.AnchorPoint = Vector2.new(0.5, 0); dotRow.Position = UDim2.new(0.5, 0, 0, 14)
    dotRow.BackgroundTransparency = 1
    local dll = Instance.new("UIListLayout", dotRow)
    dll.FillDirection = Enum.FillDirection.Horizontal
    dll.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dll.Padding = UDim.new(0, 12)
    local dots = {}
    for i = 1, 3 do
        local d = Instance.new("TextLabel", dotRow)
        d.Size = UDim2.new(0,26,0,26); d.BackgroundColor3 = Color3.fromRGB(30,30,50)
        d.BackgroundTransparency = 0; d.Text = "🌑"; d.TextScaled = true
        d.BorderSizePixel = 0; d.Font = Enum.Font.GothamBold
        Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
        dots[i] = d
    end

    -- Header
    local header = Instance.new("TextLabel", card)
    header.Size = UDim2.new(1,-20,0,32); header.Position = UDim2.new(0,10,0,48)
    header.BackgroundTransparency = 1; header.Text = "🌸  Garden of Gratitude  🌸"
    header.TextColor3 = Color3.fromRGB(160,255,180); header.TextScaled = true
    header.Font = Enum.Font.GothamBold

    -- Flower name label
    local flName = Instance.new("TextLabel", card)
    flName.Name = "FlName"; flName.Size = UDim2.new(1,-20,0,24)
    flName.Position = UDim2.new(0,10,0,84)
    flName.BackgroundTransparency = 1; flName.Text = ""
    flName.TextColor3 = Color3.fromRGB(255,200,80); flName.TextScaled = true
    flName.Font = Enum.Font.GothamSemibold

    -- Prompt label
    local prompt = Instance.new("TextLabel", card)
    prompt.Name = "Prompt"; prompt.Size = UDim2.new(1,-40,0,72)
    prompt.Position = UDim2.new(0,20,0,116)
    prompt.BackgroundTransparency = 1; prompt.Text = ""
    prompt.TextColor3 = Color3.fromRGB(210,210,210); prompt.TextSize = 16
    prompt.Font = Enum.Font.Gotham; prompt.TextWrapped = true
    prompt.TextXAlignment = Enum.TextXAlignment.Left
    prompt.TextYAlignment = Enum.TextYAlignment.Top

    -- Text input
    local inputF = Instance.new("Frame", card)
    inputF.Size = UDim2.new(1,-40,0,82); inputF.Position = UDim2.new(0,20,0,198)
    inputF.BackgroundColor3 = Color3.fromRGB(22,14,46); inputF.BorderSizePixel = 0
    Instance.new("UICorner", inputF).CornerRadius = UDim.new(0,10)
    local ist = Instance.new("UIStroke", inputF)
    ist.Color = Color3.fromRGB(70,170,90); ist.Thickness = 1.5
    local tb = Instance.new("TextBox", inputF)
    tb.Name = "TB"; tb.Size = UDim2.new(1,-12,1,0); tb.Position = UDim2.new(0,6,0,0)
    tb.BackgroundTransparency = 1; tb.Text = ""
    tb.PlaceholderText = "Write your gratitude here…"
    tb.PlaceholderColor3 = Color3.fromRGB(90,90,120)
    tb.TextColor3 = Color3.fromRGB(210,255,210); tb.TextSize = 14
    tb.Font = Enum.Font.Gotham; tb.TextWrapped = true; tb.MultiLine = true
    -- Character counter
    local cc = Instance.new("TextLabel", inputF)
    cc.Size = UDim2.new(0,56,0,18); cc.AnchorPoint = Vector2.new(1,1)
    cc.Position = UDim2.new(1,-3,1,-2); cc.BackgroundTransparency = 1
    cc.Text = "0/120"; cc.TextColor3 = Color3.fromRGB(90,130,90); cc.TextSize = 11
    cc.Font = Enum.Font.Gotham; cc.TextXAlignment = Enum.TextXAlignment.Right
    tb:GetPropertyChangedSignal("Text"):Connect(function()
        local t = tb.Text:sub(1,120); tb.Text = t; cc.Text = #t.."/120"
    end)

    -- Plant button
    local btn = Instance.new("TextButton", card)
    btn.Name = "Btn"; btn.Size = UDim2.new(0,200,0,44)
    btn.AnchorPoint = Vector2.new(0.5,0); btn.Position = UDim2.new(0.5,0,0,302)
    btn.BackgroundColor3 = Color3.fromRGB(75,175,95); btn.BorderSizePixel = 0
    btn.Text = "🌱  Plant This Flower"; btn.TextColor3 = Color3.fromRGB(10,38,14)
    btn.TextScaled = true; btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,12)
    -- Pulse
    task.spawn(function()
        while btn and btn.Parent do
            TweenService:Create(btn, TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                { BackgroundColor3 = Color3.fromRGB(115,220,128) }):Play()
            task.wait(1)
            TweenService:Create(btn, TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                { BackgroundColor3 = Color3.fromRGB(75,175,95) }):Play()
            task.wait(1)
        end
    end)

    -- Status line
    local status = Instance.new("TextLabel", card)
    status.Name = "Status"; status.Size = UDim2.new(1,-20,0,28)
    status.Position = UDim2.new(0,10,0,358); status.BackgroundTransparency = 1
    status.Text = ""; status.TextColor3 = Color3.fromRGB(155,235,155)
    status.TextScaled = true; status.Font = Enum.Font.GothamSemibold

    return screen, card, dots, flName, prompt, tb, btn, status
end

-- ── "Already done" screen ─────────────────────────────────────────────────────
local function showAlreadyDone()
    local bs = Instance.new("ScreenGui")
    bs.Name = "GardenDoneNotif"; bs.ResetOnSpawn = false; bs.Parent = gui
    local bf = Instance.new("Frame", bs)
    bf.Size = UDim2.new(0,400,0,80); bf.AnchorPoint = Vector2.new(0.5,0)
    bf.Position = UDim2.new(0.5,0,-0.12,0)
    bf.BackgroundColor3 = Color3.fromRGB(10,28,15); bf.BackgroundTransparency = 0.08; bf.BorderSizePixel = 0
    Instance.new("UICorner",bf).CornerRadius = UDim.new(0,14)
    local bst = Instance.new("UIStroke",bf); bst.Color=Color3.fromRGB(100,230,130); bst.Thickness=2
    local bl = Instance.new("TextLabel",bf)
    bl.Size=UDim2.new(1,-16,1,0); bl.Position=UDim2.new(0,8,0,0)
    bl.BackgroundTransparency=1; bl.Text="🌸  Your garden is already in bloom!"
    bl.TextColor3=Color3.fromRGB(160,255,180); bl.TextScaled=true; bl.Font=Enum.Font.GothamBold
    TweenService:Create(bf, TweenInfo.new(0.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,0,0.05,0)}):Play()
    task.delay(3, function()
        TweenService:Create(bf, TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
            {Position=UDim2.new(0.5,0,-0.15,0)}):Play()
        task.delay(0.5, function() bs:Destroy() end)
    end)
end

-- ── Completion banner ─────────────────────────────────────────────────────────
local function showComplete()
    local bs = Instance.new("ScreenGui")
    bs.Name = "GardenComplete"; bs.ResetOnSpawn = false; bs.Parent = gui
    local bf = Instance.new("Frame", bs)
    bf.Size = UDim2.new(0,480,0,90); bf.AnchorPoint = Vector2.new(0.5,0)
    bf.Position = UDim2.new(0.5,0,-0.12,0)
    bf.BackgroundColor3 = Color3.fromRGB(10,28,15); bf.BackgroundTransparency=0.08; bf.BorderSizePixel=0
    Instance.new("UICorner",bf).CornerRadius = UDim.new(0,14)
    local bst=Instance.new("UIStroke",bf); bst.Color=Color3.fromRGB(100,230,130); bst.Thickness=2
    local bl=Instance.new("TextLabel",bf)
    bl.Size=UDim2.new(1,-16,1,0); bl.Position=UDim2.new(0,8,0,0); bl.BackgroundTransparency=1
    bl.Text="🌸  Garden of Gratitude complete — Lantern earned!  🌸"
    bl.TextColor3=Color3.fromRGB(160,255,180); bl.TextScaled=true; bl.Font=Enum.Font.GothamBold
    TweenService:Create(bf, TweenInfo.new(0.6,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,0,0.05,0)}):Play()
    task.delay(5, function()
        TweenService:Create(bf, TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
            {Position=UDim2.new(0.5,0,-0.15,0)}):Play()
        task.delay(0.5, function() bs:Destroy() end)
    end)
end

-- ── Main game loop ─────────────────────────────────────────────────────────────
local function run()
    local screen, card, dots, flName, prompt, tb, btn, status = buildUI()
    screen.Enabled = true
    TweenService:Create(card, TweenInfo.new(0.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Position=UDim2.new(0.02, 0, 0.5, 0)}):Play()    -- sits on the left, right side open for flowers
    task.wait(0.6)

    for round = 1, 3 do
        -- Update progress dots
        for i, d in ipairs(dots) do
            if i < round then      d.Text="🌸"; d.BackgroundColor3=Color3.fromRGB(55,150,75)
            elseif i == round then d.Text="🌱"; d.BackgroundColor3=Color3.fromRGB(28,75,38)
            else                   d.Text="🌑"; d.BackgroundColor3=Color3.fromRGB(30,30,50) end
        end
        flName.Text = string.format("Flower %d / 3  –  %s", round, NAMES[round])
        prompt.Text = PROMPTS[round]
        tb.Text = ""; status.Text = ""
        btn.Active = true; btn.BackgroundColor3 = Color3.fromRGB(75,175,95)
        btn.Text = "🌱  Plant This Flower"

        -- Wait for the player to submit
        local submitted = false; local submitText = ""
        local function trySubmit()
            local t = tb.Text:gsub("^%s+",""):gsub("%s+$","")
            if #t < 3 then
                status.Text = "✦ Please write a little more ✦"
                status.TextColor3 = Color3.fromRGB(255,130,130); return
            end
            submitted = true; submitText = t
        end
        local bc = btn.MouseButton1Click:Connect(trySubmit)
        local fc = tb.FocusLost:Connect(function(e) if e then trySubmit() end end)
        while not submitted do task.wait(0.05) end
        bc:Disconnect(); fc:Disconnect()

        btn.Active = false; btn.BackgroundColor3 = Color3.fromRGB(45,95,50)
        btn.Text = "🌿  Growing…"
        status.Text = "✦  Your gratitude takes root…  ✦"
        status.TextColor3 = Color3.fromRGB(155,240,155)

        -- Send to server; wait for echo with plot index
        GardenFlower:FireServer(submitText)
        local plotIdx = nil
        local conn; conn = GardenFlower.OnClientEvent:Connect(function(idx)
            conn:Disconnect(); plotIdx = idx
        end)
        local t0 = tick()
        while not plotIdx and tick()-t0 < 6 do task.wait(0.05) end

        if plotIdx then
            task.spawn(function() growFlower(plotIdx, PALETTES[round]) end)
        end

        task.wait(1.6)
        if round < 3 then
            status.Text = "Beautiful! Next flower…"; task.wait(1.1)
        end
    end

    -- All 3 done
    for _, d in ipairs(dots) do d.Text="🌸"; d.BackgroundColor3=Color3.fromRGB(55,150,75) end
    btn.Text = "✦  Garden in bloom  ✦"; status.Text = ""
    task.wait(0.8)

    -- Slide card out
    TweenService:Create(card, TweenInfo.new(0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
        {Position=UDim2.new(-0.55, 0, 0.5, 0)}):Play()   -- slides back out to the left
    task.wait(0.5); screen:Destroy()

    -- Confetti burst above the garden
    local confettiHost = Instance.new("Part", Workspace)
    confettiHost.Size = Vector3.new(0.1,0.1,0.1)
    confettiHost.CFrame = CFrame.new(Vector3.new(-0.463, 7.75, -102.296) + Vector3.new(0,6,0))
    confettiHost.Anchored = true; confettiHost.CanCollide = false; confettiHost.Transparency = 1
    local conf = Instance.new("ParticleEmitter", confettiHost)
    conf.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255,220,50)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200,80,200)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(80,200,120)),
    })
    conf.LightEmission = 0.8
    conf.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(0.15,0.5), NumberSequenceKeypoint.new(1,0) })
    conf.Lifetime = NumberRange.new(2,3.5); conf.Rate = 0
    conf.Speed = NumberRange.new(8,18); conf.SpreadAngle = Vector2.new(180,180)
    conf:Emit(80)
    task.delay(4, function() confettiHost:Destroy() end)

    -- Tell server all 3 are done
    GardenComplete:FireServer()
    showComplete()
end

-- ── Listen ────────────────────────────────────────────────────────────────────
OpenGarden.OnClientEvent:Connect(function(alreadyDone)
    if alreadyDone then
        showAlreadyDone(); return
    end
    if done then return end
    done = true
    task.spawn(run)
end)

print("[GardenUI] ready.")
