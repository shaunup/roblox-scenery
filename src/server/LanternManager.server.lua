--[[
  LanternManager.server.lua
  ─────────────────────────────────────────────────────────────────────────────
  Owns all server logic for the lantern finale:

  1. SHOP  – builds a small lantern-shop stall at SHOP_POS.
             ProximityPrompt "Pick up your lantern".
             One lantern per player; fires LanternPickedUp to the client.

  2. RELEASE SITE – invisible trigger at RELEASE_POS.
                    When a player carrying a lantern walks near,
                    fires LanternSiteReached so the client shows the
                    message-writing popup.

  3. RELEASE  – client fires LanternRelease(message).
                Server spawns a permanent glowing lantern Part in the
                SkyLanterns folder, tagged with the message.
                Fires LanternReleased back to all clients so the
                cinematic can begin.

  4. SKY LANTERNS – pre-populates ~60 AI lanterns with positive messages
                    at the session start so the sky looks full from the
                    beginning. Stored in Workspace/SkyLanterns.

  5. CLICK MESSAGE – client fires LanternClicked(lanternPart).
                     Server sends back the message attached to that lantern.

  Remote events (all in RS/Remotes):
    LanternPickedUp  S→C
    LanternSiteReached S→C
    LanternRelease   C→S  (message string)
    LanternReleased  S→All (lanternData table)
    LanternClicked   C→S  (lanternId string)
    LanternMessage   S→C  (message string)
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

-- ═══════════════════════════════════════════════════════════════
--  POSITIONS  – change these to match your terrain
local SHOP_POS    = Vector3.new( 20,  7.75,  -80)    -- lantern shop stall
local RELEASE_POS = Vector3.new( -0.463, 7.75, -150)  -- dock / pond edge
-- ═══════════════════════════════════════════════════════════════

-- ── Remotes ───────────────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function ensureRemote(name)
    local r = Remotes:FindFirstChild(name)
    if r then return r end
    r = Instance.new("RemoteEvent", Remotes)
    r.Name = name
    return r
end

local LanternPickedUp   = ensureRemote("LanternPickedUp")
local LanternSiteReached = ensureRemote("LanternSiteReached")
local LanternRelease    = ensureRemote("LanternRelease")
local LanternReleased   = ensureRemote("LanternReleased")
local LanternClicked    = ensureRemote("LanternClicked")
local LanternMessage    = ensureRemote("LanternMessage")

-- ── State ─────────────────────────────────────────────────────────────────────
local hasLantern   = {}   -- [player] = bool  (picked up but not released)
local releasedBy   = {}   -- [player] = bool  (already released)

Players.PlayerRemoving:Connect(function(p)
    hasLantern[p] = nil; releasedBy[p] = nil
end)

-- ── Scene folder ──────────────────────────────────────────────────────────────
local sceneFolder = Workspace:WaitForChild("TwilightTrail", 30)

-- ── Sky lanterns folder (permanent, shared) ───────────────────────────────────
local skyFolder = Instance.new("Folder", Workspace)
skyFolder.Name  = "SkyLanterns"

-- Map lanternId → message (server-side)
local lanternMessages = {}
local lanternIdCounter = 0
local function newLanternId()
    lanternIdCounter = lanternIdCounter + 1
    return "L" .. lanternIdCounter
end

-- ── Prop helpers ──────────────────────────────────────────────────────────────
local function makePart(parent, props)
    local p = Instance.new("Part")
    for k, v in pairs(props) do p[k] = v end
    p.Anchored      = true
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent        = parent
    return p
end

local function addLight(part, brightness, range, color)
    local l = Instance.new("PointLight", part)
    l.Brightness = brightness; l.Range = range; l.Color = color; l.Shadows = false
    return l
end

-- ── Build lantern shop ────────────────────────────────────────────────────────
local function buildShop()
    local f = Instance.new("Folder", sceneFolder)
    f.Name  = "LanternShop"
    local p = SHOP_POS

    -- Stall roof (awning)
    makePart(f, {
        Name="Awning", Size=Vector3.new(8, 0.3, 5),
        CFrame=CFrame.new(p + Vector3.new(0, 5, 0)),
        BrickColor=BrickColor.new("Bright red"), Material=Enum.Material.SmoothPlastic,
    })
    -- Support posts
    for _, ox in ipairs({-3.5, 3.5}) do
        makePart(f, {
            Name="Post", Size=Vector3.new(0.4, 5, 0.4),
            CFrame=CFrame.new(p + Vector3.new(ox, 2.5, -1.8)),
            BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
        })
    end
    -- Counter
    makePart(f, {
        Name="Counter", Size=Vector3.new(7, 0.35, 1.8),
        CFrame=CFrame.new(p + Vector3.new(0, 2.0, -0.5)),
        BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
    })
    -- Display lanterns on counter
    for i, ox in ipairs({-2.5, 0, 2.5}) do
        local dl = makePart(f, {
            Name="DisplayLantern"..i, Size=Vector3.new(0.9, 1.4, 0.9),
            CFrame=CFrame.new(p + Vector3.new(ox, 3.0, -0.5)),
            BrickColor=BrickColor.new("Bright orange"),
            Material=Enum.Material.Neon, CanCollide=false, Transparency=0.25,
        })
        addLight(dl, 0.7, 10, Color3.fromRGB(255, 200, 80))
    end
    -- Hanging lantern strings from awning
    for i, ox in ipairs({-2, 0, 2}) do
        local hl = makePart(f, {
            Name="HangLantern"..i, Size=Vector3.new(0.7, 1.1, 0.7),
            CFrame=CFrame.new(p + Vector3.new(ox, 4.5, 0)),
            BrickColor=BrickColor.new("Bright yellow"),
            Material=Enum.Material.Neon, CanCollide=false, Transparency=0.2,
        })
        addLight(hl, 0.5, 8, Color3.fromRGB(255, 230, 120))
    end
    -- Billboard sign
    local sign = makePart(f, {
        Name="Sign", Size=Vector3.new(6, 1.4, 0.2),
        CFrame=CFrame.new(p + Vector3.new(0, 6.2, -1.8)),
        BrickColor=BrickColor.new("Bright red"), Material=Enum.Material.SmoothPlastic,
    })
    local bg = Instance.new("BillboardGui", sign)
    bg.Size = UDim2.new(0, 320, 0, 70); bg.StudsOffset = Vector3.new(0, 0.5, 0)
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = "🏮  Lantern Shop  🏮"
    lbl.TextColor3 = Color3.fromRGB(255, 240, 180)
    lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold

    -- ProximityPrompt trigger
    local trigger = makePart(f, {
        Name="ShopTrigger", Size=Vector3.new(1, 1, 1),
        CFrame=CFrame.new(p + Vector3.new(0, 1.5, 2)),
        Material=Enum.Material.Neon, CanCollide=false, Transparency=1,
    })
    local prompt = Instance.new("ProximityPrompt", trigger)
    prompt.ActionText            = "Pick Up Lantern"
    prompt.ObjectText            = "🏮 Lantern Shop"
    prompt.MaxActivationDistance = 10
    prompt.HoldDuration          = 0.8   -- short hold so it feels intentional
    prompt.RequiresLineOfSight   = false

    return prompt
end

-- ── Build release site trigger ────────────────────────────────────────────────
local function buildReleaseSite()
    local f = Instance.new("Folder", sceneFolder)
    f.Name  = "ReleaseSite"
    local p = RELEASE_POS

    -- Stone viewing platform (walkable)
    local platform = makePart(f, {
        Name="Platform", Size=Vector3.new(10, 0.4, 8),
        CFrame=CFrame.new(p + Vector3.new(0, -0.2, 0)),
        BrickColor=BrickColor.new("Medium stone grey"), Material=Enum.Material.Cobblestone,
    })

    -- Low railing on three sides (far, left, right — path side stays open)
    local rails = {
        { Vector3.new(0,  0.5, -4),  Vector3.new(10, 0.3, 0.3) },  -- far rail
        { Vector3.new(-5, 0.5,  0),  Vector3.new(0.3, 0.3, 8)  },  -- left rail
        { Vector3.new( 5, 0.5,  0),  Vector3.new(0.3, 0.3, 8)  },  -- right rail
    }
    for i, rd in ipairs(rails) do
        makePart(f, {
            Name="Rail"..i, Size=rd[2],
            CFrame=CFrame.new(p + rd[1]),
            BrickColor=BrickColor.new("Medium stone grey"), Material=Enum.Material.Cobblestone,
        })
    end

    -- Two wooden posts with glowing hanging lanterns flanking the platform
    for _, px in ipairs({-3.5, 3.5}) do
        makePart(f, {
            Name="LanternPost", Size=Vector3.new(0.4, 4.5, 0.4),
            CFrame=CFrame.new(p + Vector3.new(px, 2.25, -3.5)),
            BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
        })
        local hang = makePart(f, {
            Name="HangLantern", Size=Vector3.new(0.85, 1.3, 0.85),
            CFrame=CFrame.new(p + Vector3.new(px, 5.0, -3.5)),
            BrickColor=BrickColor.new("Bright orange"),
            Material=Enum.Material.Neon, CanCollide=false, Transparency=0.2,
        })
        addLight(hang, 1.4, 20, Color3.fromRGB(255, 200, 80))
    end

    -- Glowing neon ground ring to make the spot obvious from a distance
    local ring = makePart(f, {
        Name="GlowRing", Size=Vector3.new(0.25, 9.6, 9.6),
        CFrame=CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi/2),
        BrickColor=BrickColor.new("Bright yellow"),
        Material=Enum.Material.Neon, CanCollide=false, CastShadow=false, Transparency=0.35,
    })
    ring.Shape = Enum.PartType.Cylinder
    addLight(ring, 1.0, 22, Color3.fromRGB(255, 220, 80))

    -- Sign billboard above the platform
    local signPost = makePart(f, {
        Name="SignPost", Size=Vector3.new(0.3, 5, 0.3),
        CFrame=CFrame.new(p + Vector3.new(0, 2.5, -4.2)),
        BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
    })
    local bg = Instance.new("BillboardGui", signPost)
    bg.Size        = UDim2.new(0, 340, 0, 80)
    bg.StudsOffset = Vector3.new(0, 4, 0)
    bg.AlwaysOnTop = false
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = "🏮  Lantern Release  🏮\nStand here to release your lantern"
    lbl.TextColor3 = Color3.fromRGB(255, 230, 140)
    lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold

    -- ProximityPrompt so the player gets a clear "you're in the right spot" cue
    -- (the proximity poll will still fire LanternSiteReached, this is extra clarity)
    local promptPart = makePart(f, {
        Name="ReleasePromptPart", Size=Vector3.new(1, 1, 1),
        CFrame=CFrame.new(p + Vector3.new(0, 1.5, 0)),
        Material=Enum.Material.Neon, CanCollide=false, Transparency=1,
    })
    local pp = Instance.new("ProximityPrompt", promptPart)
    pp.ActionText            = "Release Lantern"
    pp.ObjectText            = "🏮 Release Site"
    pp.MaxActivationDistance = 12
    pp.HoldDuration          = 0
    pp.RequiresLineOfSight   = false

    -- Invisible trigger zone (same as before, used by proximity poll)
    local trigger = makePart(f, {
        Name="ReleaseTrigger", Size=Vector3.new(12, 6, 12),
        CFrame=CFrame.new(p + Vector3.new(0, 3, 0)),
        Material=Enum.Material.Neon, CanCollide=false, Transparency=1,
    })
    return trigger
end

-- ── Spawn a sky lantern (shared, replicates to all) ───────────────────────────
local LANTERN_COLORS = {
    Color3.fromRGB(255, 200,  50),
    Color3.fromRGB(255, 130,  40),
    Color3.fromRGB(255, 100, 180),
    Color3.fromRGB(100, 200, 255),
    Color3.fromRGB(160, 255, 180),
    Color3.fromRGB(220, 160, 255),
}
local function colorForIdx(i) return LANTERN_COLORS[((i-1) % #LANTERN_COLORS) + 1] end

local function spawnSkyLantern(position, message, colorIdx)
    local id  = newLanternId()
    local col = colorForIdx(colorIdx)

    local body = Instance.new("Part", skyFolder)
    body.Name        = id
    body.Size        = Vector3.new(1.4, 2.2, 1.4)
    body.CFrame      = CFrame.new(position)
    body.Anchored    = true
    body.CanCollide  = false
    body.CastShadow  = false
    body.Material    = Enum.Material.Neon
    body.Color       = col
    body.Transparency = 0.22

    local glow = addLight(body, 1.0, 16, col)

    -- Flame flicker (Fire effect)
    local fire = Instance.new("Fire", body)
    fire.Heat = 2; fire.Size = 0.5
    fire.Color = Color3.fromRGB(255, 180, 50)
    fire.SecondaryColor = Color3.fromRGB(255, 100, 20)

    -- Tag the lantern so the client can ClickDetector → server lookup
    local tag = Instance.new("StringValue", body)
    tag.Name  = "LanternId"
    tag.Value = id

    -- Add ClickDetector so clients can interact
    local cd = Instance.new("ClickDetector", body)
    cd.MaxActivationDistance = 999   -- visible from far, camera will pan close

    lanternMessages[id] = message

    -- Gentle bob via a server-side tween loop
    task.spawn(function()
        while body and body.Parent do
            local base = body.Position
            TweenService:Create(body, TweenInfo.new(3 + math.random()*2,
                Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Position = base + Vector3.new(math.sin(tick())*0.3, 0.6, 0) }):Play()
            task.wait(3 + math.random()*2)
            TweenService:Create(body, TweenInfo.new(3 + math.random()*2,
                Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Position = base }):Play()
            task.wait(3 + math.random()*2)
        end
    end)

    return id, body
end

-- ── Pre-populate sky with AI lanterns ─────────────────────────────────────────
local AI_MESSAGES = {
    "You are enough, exactly as you are.",
    "The world is brighter because you are in it.",
    "Every step forward is progress.",
    "You have survived every hard day so far.",
    "Kindness you show today echoes forever.",
    "Your dreams deserve to take up space.",
    "Today I am grateful for the small things.",
    "Love is the light that guides us home.",
    "The night is always followed by dawn.",
    "You are worthy of all good things.",
    "Thank you for existing.",
    "Breathe. You are right where you need to be.",
    "Stars shine brightest in the darkest sky.",
    "Your presence is a gift.",
    "Every moment holds the seed of wonder.",
    "Be gentle with yourself today.",
    "The journey is the destination.",
    "Small acts of courage change the world.",
    "You are loved more than you know.",
    "Hope floats like a lantern in the night.",
    "All shall be well.",
    "Your light cannot be extinguished.",
    "Gratitude opens every door.",
    "This too shall pass — and bloom.",
    "You matter deeply.",
    "The universe conspires in your favour.",
    "Every breath is a new beginning.",
    "You carry the light within you.",
    "Tonight I release what no longer serves me.",
    "I am grateful for this beautiful sky.",
    "Healing is not linear, but it is real.",
    "You are braver than you believe.",
    "The stars remember every wish.",
    "Peace is possible.",
    "I choose joy.",
    "The quiet moments hold the most magic.",
    "You have come so far.",
    "Love more. Fear less.",
    "This moment is sacred.",
    "I release and I trust.",
    "You are a miracle.",
    "The world needs exactly what you carry.",
    "Be the warmth you wish to feel.",
    "Joy is an act of resistance.",
    "Keep going.",
    "You are not alone.",
    "Float like a lantern, free and bright.",
    "Your story is still being written.",
    "The light you give returns to you.",
    "Tonight, let your heart be light.",
    "Rise, shine, and be free.",
    "Love is the answer to every question.",
    "The sky is full of second chances.",
    "You deserve rest and renewal.",
    "Let go and let fly.",
    "Each lantern is a prayer answered.",
    "Stars are just lanterns that never went out.",
    "This night holds infinite possibility.",
    "Be here. Be you. Be enough.",
    "Your warmth touches lives you will never know.",
}

task.spawn(function()
    task.wait(2)  -- let scene load first
    local rng  = Random.new(42)
    local count = 60
    for i = 1, count do
        -- Spread across a large sky area above the map
        local x  = rng:NextNumber(-120, 120)
        local y  = rng:NextNumber(80,  220)
        local z  = rng:NextNumber(-220, -60)
        local msg = AI_MESSAGES[((i-1) % #AI_MESSAGES) + 1]
        spawnSkyLantern(Vector3.new(x, y, z), msg, i)
        task.wait(0.04)  -- stagger so server doesn't spike
    end
    print("[LanternManager] Sky populated with", count, "lanterns.")
end)

-- ── Wire the shop prompt ──────────────────────────────────────────────────────
local shopPrompt    = buildShop()
local releaseTrigger = buildReleaseSite()

shopPrompt.Triggered:Connect(function(player)
    if hasLantern[player] or releasedBy[player] then return end
    hasLantern[player] = true
    LanternPickedUp:FireClient(player)
    print("[LanternManager] " .. player.Name .. " picked up a lantern.")
end)

-- ── Release site proximity ────────────────────────────────────────────────────
-- Poll rather than .Touched so it's reliable
task.spawn(function()
    local INTERVAL = 0.4
    while true do
        task.wait(INTERVAL)
        for _, player in ipairs(Players:GetPlayers()) do
            if not hasLantern[player] then continue end
            if releasedBy[player] then continue end
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            if (root.Position - RELEASE_POS).Magnitude < 10 then
                LanternSiteReached:FireClient(player)
            end
        end
    end
end)

-- ── Handle release ────────────────────────────────────────────────────────────
LanternRelease.OnServerEvent:Connect(function(player, message)
    if not hasLantern[player] then return end
    if releasedBy[player] then return end
    if type(message) ~= "string" then message = "✦" end
    message = message:sub(1, 140)  -- cap length

    hasLantern[player]  = false
    releasedBy[player]  = true

    -- Spawn the player's personal lantern at release site, slightly above water
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local spawnPos = root and (root.Position + Vector3.new(0, 3, 0)) or (RELEASE_POS + Vector3.new(0, 4, 0))

    local id, lanternPart = spawnSkyLantern(spawnPos, message, lanternIdCounter)

    -- Animate it rising to join the sky (server-side, so all clients see it)
    task.spawn(function()
        local targetPos = spawnPos + Vector3.new(
            math.random(-30, 30),
            math.random(100, 180),
            math.random(-60, -20)
        )
        TweenService:Create(lanternPart,
            TweenInfo.new(18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Position = targetPos }):Play()
    end)

    -- Broadcast to ALL clients to start the cinematic
    LanternReleased:FireAllClients({
        playerId   = player.UserId,
        playerName = player.Name,
        lanternId  = id,
        message    = message,
        startPos   = spawnPos,
    })
    print("[LanternManager] " .. player.Name .. " released lantern: " .. message:sub(1,40))
end)

-- ── Click handler ─────────────────────────────────────────────────────────────
LanternClicked.OnServerEvent:Connect(function(player, lanternId)
    local msg = lanternMessages[lanternId]
    if msg then
        LanternMessage:FireClient(player, msg)
    end
end)

-- Wire ClickDetectors as they appear
skyFolder.ChildAdded:Connect(function(child)
    if not child:IsA("Part") then return end
    local cd = child:FindFirstChildOfClass("ClickDetector")
    if not cd then return end
    local idTag = child:FindFirstChild("LanternId")
    if not idTag then return end
    cd.MouseClick:Connect(function(player)
        LanternClicked:FireClient(player, idTag.Value)
    end)
end)

print("[LanternManager] Ready.  Shop:", SHOP_POS, " Release:", RELEASE_POS)
