--[[
  LanternCinematic.client.lua  (LocalScript – StarterGui)
  ─────────────────────────────────────────────────────────────────────────────
  The finale cinematic sequence, triggered by LanternReleased (S→All):

  PHASE 1 – POND AWAKENING  (0 – 4 s)
    Camera stays near release site.
    Pond surface lights bloom outward in a ring.
    100 bioluminescent firefly particles erupt upward from the water.
    Screen title fades in: player name + message.

  PHASE 2 – TRACKING SHOT  (4 – 10 s)
    Camera follows the player's lantern from a close distance,
    locked behind-and-below, watching it rise.
    Lantern leaves a bright sparkle trail.

  PHASE 3 – WIDE PULL-BACK  (10 – 18 s)
    Camera tweens outward to a birds-eye position high above the map.
    All 60+ lanterns are visible dotting the sky.
    HUD text: "You are not alone in this night."

  PHASE 4 – INTERACTIVE SKY  (18 – 50 s)
    Camera hovers at birds-eye, slowly orbiting.
    Every lantern Part has a ClickDetector.
    Player can click any lantern → message popup slides in.
    Small tooltip: "Click any lantern to read its wish."

  PHASE 5 – RETURN TO MENU  (50 s or after player clicks "End Journey")
    Screen fades to black.
    Title card: "Thank you for walking this path."
    "Play Again" button → TeleportService back to start place,
    or simply resets the character if single-place.

  Also handles:
    LanternMessage (S→C, message) → shows click-message card
    Pond ambience fireflies (purely client-side, spawned on the fly)
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = Workspace.CurrentCamera

local Remotes         = ReplicatedStorage:WaitForChild("Remotes")
local LanternReleased = Remotes:WaitForChild("LanternReleased")
local LanternMessage  = Remotes:WaitForChild("LanternMessage")
local LanternClicked  = Remotes:WaitForChild("LanternClicked")

-- ── Release-site position (matches server) ────────────────────────────────────
local RELEASE_POS = Vector3.new(-0.463, 7.75, -150)

-- ── Utility ───────────────────────────────────────────────────────────────────
local function tween(inst, info, props)
    local t = TweenService:Create(inst, info, props); t:Play(); return t
end

local function wait_tween(inst, info, props)
    local t = tween(inst, info, props); t.Completed:Wait()
end

-- ── FIRECRACKERS ─────────────────────────────────────────────────────────────
-- Bursts of coloured sparks fired upward from ground level around the release
-- site. Pure client-side Parts so they don't affect other players.
local function spawnFirecrackers()
    local folder = Instance.new("Folder", Workspace)
    folder.Name  = "Firecrackers_Client"

    -- Warm orange/yellow palette only, matching the lanterns
    local CRACKER_COLORS = {
        Color3.fromRGB(255, 200,  50),
        Color3.fromRGB(255, 155,  30),
        Color3.fromRGB(255, 230, 100),
        Color3.fromRGB(255, 120,  20),
    }

    -- Fire several volleys, each with multiple burst points
    local VOLLEYS = {
        { delay=0,    count=6 },
        { delay=1.2,  count=8 },
        { delay=2.5,  count=10 },
        { delay=4.0,  count=12 },
        { delay=5.5,  count=8  },
        { delay=7.0,  count=6  },
    }

    for _, volley in ipairs(VOLLEYS) do
        task.delay(volley.delay, function()
            for b = 1, volley.count do
                -- Random launch point on the ground around the release site
                local angle  = math.random() * math.pi * 2
                local dist   = math.random() * 18
                local origin = RELEASE_POS + Vector3.new(
                    math.cos(angle) * dist,
                    0.5,
                    math.sin(angle) * dist
                )

                -- Each burst = a host part that fires a ParticleEmitter once
                local host = Instance.new("Part", folder)
                host.Size        = Vector3.new(0.1, 0.1, 0.1)
                host.CFrame      = CFrame.new(origin)
                host.Anchored    = true
                host.CanCollide  = false
                host.Transparency = 1

                local col = CRACKER_COLORS[math.random(#CRACKER_COLORS)]

                -- Streak: thin bright line shooting upward
                local streak = Instance.new("ParticleEmitter", host)
                streak.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255,255,200)),
                    ColorSequenceKeypoint.new(0.3, col),
                    ColorSequenceKeypoint.new(1,   Color3.fromRGB(80, 40, 0)),
                })
                streak.LightEmission  = 1
                streak.LightInfluence = 0
                streak.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0,   0.12),
                    NumberSequenceKeypoint.new(0.6, 0.06),
                    NumberSequenceKeypoint.new(1,   0),
                })
                streak.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.7, 0.2),
                    NumberSequenceKeypoint.new(1, 1),
                })
                streak.Lifetime    = NumberRange.new(0.5, 0.9)
                streak.Rate        = 0
                streak.Speed       = NumberRange.new(28, 55)   -- fast upward streak
                streak.SpreadAngle = Vector2.new(8, 8)         -- near-vertical
                streak.RotSpeed    = NumberRange.new(-20, 20)
                streak.Rotation    = NumberRange.new(0, 360)
                streak.EmissionDirection = Enum.NormalId.Top

                -- Burst: radial explosion at the apex
                -- Slight delay so it pops after the streak reaches its peak
                local burstDelay = 0.05 + math.random() * 0.15

                task.delay(burstDelay, function()
                    -- Move host to apex height
                    local apexPos = origin + Vector3.new(
                        math.random(-3, 3),
                        math.random(18, 40),   -- height of burst
                        math.random(-3, 3)
                    )
                    host.CFrame = CFrame.new(apexPos)

                    local burst = Instance.new("ParticleEmitter", host)
                    burst.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255,255,220)),
                        ColorSequenceKeypoint.new(0.2, col),
                        ColorSequenceKeypoint.new(1,   Color3.fromRGB(60, 30, 0)),
                    })
                    burst.LightEmission  = 1
                    burst.LightInfluence = 0
                    burst.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0,   0),
                        NumberSequenceKeypoint.new(0.1, 0.28),
                        NumberSequenceKeypoint.new(1,   0),
                    })
                    burst.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0,   0),
                        NumberSequenceKeypoint.new(0.5, 0.1),
                        NumberSequenceKeypoint.new(1,   1),
                    })
                    burst.Lifetime    = NumberRange.new(0.8, 1.6)
                    burst.Rate        = 0
                    burst.Speed       = NumberRange.new(8, 20)
                    burst.SpreadAngle = Vector2.new(180, 180)   -- full sphere explosion
                    burst.RotSpeed    = NumberRange.new(-60, 60)
                    burst.Rotation    = NumberRange.new(0, 360)

                    -- Flash PointLight for the pop
                    local fl = Instance.new("PointLight", host)
                    fl.Color      = col
                    fl.Brightness = 8
                    fl.Range      = 40

                    streak:Emit(12)
                    burst:Emit(40)

                    TweenService:Create(fl,
                        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { Brightness = 0 }):Play()

                    task.delay(2, function() if host.Parent then host:Destroy() end end)
                end)
            end
        end)
    end

    -- Clean up folder after all volleys finish
    task.delay(12, function() if folder.Parent then folder:Destroy() end end)
end

-- ── POND AMBIENCE – bioluminescent fireflies ──────────────────────────────────
local function spawnPondAmbience()
    local folder = Instance.new("Folder", Workspace)
    folder.Name  = "PondAmbience_Cinematic"

    -- Bloom ring: expand outward from RELEASE_POS
    for ring = 1, 4 do
        task.delay(ring * 0.4, function()
            local radius = ring * 5
            for i = 1, 12 do
                local angle = (i / 12) * math.pi * 2
                local pos   = RELEASE_POS + Vector3.new(
                    math.cos(angle) * radius, 0.3, math.sin(angle) * radius)
                local sp = Instance.new("Part", folder)
                sp.Size        = Vector3.new(0.4, 0.4, 0.4)
                sp.Shape       = Enum.PartType.Ball
                sp.CFrame      = CFrame.new(pos)
                sp.Anchored    = true; sp.CanCollide = false; sp.CastShadow = false
                sp.Material    = Enum.Material.Neon
                sp.Color       = Color3.fromRGB(80 + ring*20, 200, 255)
                sp.Transparency = 0.1
                local pl = Instance.new("PointLight", sp)
                pl.Brightness = 0.8; pl.Range = 8; pl.Color = Color3.fromRGB(100, 210, 255)
                -- Fade out after brief flash
                tween(sp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Transparency = 1})
                task.delay(2.1, function() if sp.Parent then sp:Destroy() end end)
            end
        end)
    end

    -- Rising firefly wisps from the water surface
    for i = 1, 80 do
        task.delay(math.random() * 4, function()
            local angle = math.random() * math.pi * 2
            local dist  = math.random() * 14
            local startPos = RELEASE_POS + Vector3.new(
                math.cos(angle) * dist, 0.2, math.sin(angle) * dist)
            local endPos   = startPos + Vector3.new(
                math.random(-4, 4), math.random(8, 22), math.random(-4, 4))

            local ff = Instance.new("Part", folder)
            ff.Size  = Vector3.new(0.25, 0.25, 0.25)
            ff.Shape = Enum.PartType.Ball
            ff.CFrame = CFrame.new(startPos)
            ff.Anchored = true; ff.CanCollide = false; ff.CastShadow = false
            ff.Material = Enum.Material.Neon
            ff.Color    = Color3.fromRGB(
                100 + math.random(0,100),
                200 + math.random(0,55),
                200 + math.random(0,55))
            ff.Transparency = 0.3

            local pl = Instance.new("PointLight", ff)
            pl.Brightness = 0.4; pl.Range = 6
            pl.Color      = Color3.fromRGB(120, 230, 255)

            -- Rise slowly
            tween(ff, TweenInfo.new(6 + math.random()*4,
                Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { CFrame = CFrame.new(endPos), Transparency = 0.9 })
            task.delay(10, function() if ff.Parent then ff:Destroy() end end)
        end)
    end

    task.delay(55, function() if folder.Parent then folder:Destroy() end end)
end

-- ── PHASE 1 TITLE CARD ───────────────────────────────────────────────────────
local function showReleaseTitle(playerName, message)
    local s = Instance.new("ScreenGui", playerGui)
    s.Name = "CinTitle"; s.ResetOnSpawn = false; s.IgnoreGuiInset = true

    local f = Instance.new("Frame", s)
    f.Size = UDim2.new(0, 580, 0, 110)
    f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.new(0.5,0,0.82,0)
    f.BackgroundColor3 = Color3.fromRGB(12, 8, 28); f.BackgroundTransparency = 0.08
    f.BorderSizePixel  = 0; f.Transparency = 1
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 18)
    local fs = Instance.new("UIStroke", f); fs.Color = Color3.fromRGB(255,200,80); fs.Thickness = 1.5

    local name = Instance.new("TextLabel", f)
    name.Size = UDim2.new(1,-20,0,36); name.Position = UDim2.new(0,10,0,8)
    name.BackgroundTransparency = 1
    name.Text = playerName .. "'s lantern rises…"
    name.TextColor3 = Color3.fromRGB(255, 210, 100)
    name.Font = Enum.Font.GothamBold; name.TextSize = 20; name.Transparency = 1

    local msg = Instance.new("TextLabel", f)
    msg.Size = UDim2.new(1,-20,0,44); msg.Position = UDim2.new(0,10,0,44)
    msg.BackgroundTransparency = 1; msg.Text = '"' .. message .. '"'
    msg.TextColor3 = Color3.fromRGB(220, 210, 255)
    msg.Font = Enum.Font.GothamSemibold; msg.TextSize = 16
    msg.TextWrapped = true; msg.Transparency = 1

    tween(f, TweenInfo.new(1.2), {BackgroundTransparency = 0.08})
    tween(name, TweenInfo.new(1.2), {Transparency = 0})
    task.delay(0.3, function() tween(msg, TweenInfo.new(1.2), {Transparency = 0}) end)

    task.delay(7, function()
        tween(f,    TweenInfo.new(1.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
        tween(name, TweenInfo.new(1.5), {Transparency = 1})
        tween(msg,  TweenInfo.new(1.5), {Transparency = 1})
        task.delay(1.6, function() s:Destroy() end)
    end)
end

-- ── PHASE 3 HUD CAPTION ───────────────────────────────────────────────────────
local function showSkyCaption(text, delay, duration)
    task.delay(delay, function()
        local s = Instance.new("ScreenGui", playerGui)
        s.Name = "SkyCaption"; s.ResetOnSpawn = false; s.IgnoreGuiInset = true

        local lbl = Instance.new("TextLabel", s)
        lbl.Size = UDim2.new(0, 620, 0, 44)
        lbl.AnchorPoint = Vector2.new(0.5, 0.5); lbl.Position = UDim2.new(0.5,0,0.88,0)
        lbl.BackgroundTransparency = 1; lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(220, 210, 255); lbl.TextTransparency = 1
        lbl.Font = Enum.Font.GothamSemibold; lbl.TextSize = 19; lbl.TextWrapped = true

        tween(lbl, TweenInfo.new(1.5), {TextTransparency = 0})
        task.delay(duration or 5, function()
            tween(lbl, TweenInfo.new(1.5), {TextTransparency = 1})
            task.delay(1.6, function() s:Destroy() end)
        end)
    end)
end

-- ── INTERACTIVE SKY TOOLTIP ───────────────────────────────────────────────────
local function showClickTooltip()
    local s = Instance.new("ScreenGui", playerGui)
    s.Name = "ClickTooltip"; s.ResetOnSpawn = false; s.IgnoreGuiInset = true

    local f = Instance.new("Frame", s)
    f.Size = UDim2.new(0, 360, 0, 46)
    f.AnchorPoint = Vector2.new(0.5, 1); f.Position = UDim2.new(0.5,0,0.97,0)
    f.BackgroundColor3 = Color3.fromRGB(15,12,35); f.BackgroundTransparency = 0.15; f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,12)

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1,-12,1,0); lbl.Position = UDim2.new(0,6,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "✦ Click any lantern to read its wish"
    lbl.TextColor3 = Color3.fromRGB(200,190,255); lbl.Font = Enum.Font.Gotham; lbl.TextSize = 15

    local ti = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    TweenService:Create(lbl, ti, {TextColor3 = Color3.fromRGB(255,240,255)}):Play()

    return s
end

-- ── CLICK MESSAGE CARD ────────────────────────────────────────────────────────
local function showMessageCard(message)
    local s = Instance.new("ScreenGui", playerGui)
    s.Name = "LanternMsgCard"; s.ResetOnSpawn = false; s.IgnoreGuiInset = true

    local f = Instance.new("Frame", s)
    f.Size = UDim2.new(0, 480, 0, 100)
    f.AnchorPoint = Vector2.new(0.5, 0); f.Position = UDim2.new(0.5,0,-0.15,0)
    f.BackgroundColor3 = Color3.fromRGB(14,10,32); f.BackgroundTransparency=0.06; f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,16)
    local fs = Instance.new("UIStroke",f); fs.Color=Color3.fromRGB(200,160,255); fs.Thickness=1.5

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1,-20,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = '"' .. message .. '"'
    lbl.TextColor3 = Color3.fromRGB(230, 220, 255); lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 16; lbl.TextWrapped = true; lbl.TextXAlignment = Enum.TextXAlignment.Center

    tween(f, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5,0,0.06,0)})
    task.delay(5, function()
        tween(f, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5,0,-0.16,0)})
        task.delay(0.5, function() s:Destroy() end)
    end)
end

-- ── FINAL MENU SCREEN ─────────────────────────────────────────────────────────
local function showEndScreen()
    local s = Instance.new("ScreenGui", playerGui)
    s.Name = "EndScreen"; s.ResetOnSpawn = false; s.IgnoreGuiInset = true

    local overlay = Instance.new("Frame", s)
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.fromRGB(4,3,14)
    overlay.BackgroundTransparency = 1; overlay.BorderSizePixel = 0
    wait_tween(overlay, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency = 0})

    -- Card
    local card = Instance.new("Frame", overlay)
    card.Size = UDim2.new(0, 540, 0, 360)
    card.AnchorPoint = Vector2.new(0.5,0.5); card.Position = UDim2.new(0.5,0,0.6,0)
    card.BackgroundColor3 = Color3.fromRGB(14,10,32); card.BackgroundTransparency=0.05
    card.BorderSizePixel = 0
    Instance.new("UICorner",card).CornerRadius = UDim.new(0,24)
    local cs = Instance.new("UIStroke",card); cs.Color=Color3.fromRGB(255,200,80); cs.Thickness=2

    local lanternEmoji = Instance.new("TextLabel",card)
    lanternEmoji.Size = UDim2.new(1,0,0,70); lanternEmoji.Position = UDim2.new(0,0,0,12)
    lanternEmoji.BackgroundTransparency=1; lanternEmoji.Text="🏮"
    lanternEmoji.TextScaled=true; lanternEmoji.Transparency=1

    local title = Instance.new("TextLabel",card)
    title.Size = UDim2.new(1,-30,0,50); title.Position = UDim2.new(0,15,0,86)
    title.BackgroundTransparency=1; title.Text="Thank you for walking this path."
    title.TextColor3=Color3.fromRGB(255,220,120); title.Font=Enum.Font.GothamBold
    title.TextSize=24; title.TextWrapped=true; title.Transparency=1

    local sub = Instance.new("TextLabel",card)
    sub.Size = UDim2.new(1,-40,0,64); sub.Position = UDim2.new(0,20,0,148)
    sub.BackgroundTransparency=1
    sub.Text = "Your lantern carries your wish into the night.\nMay it find those who need it most."
    sub.TextColor3=Color3.fromRGB(190,185,230); sub.Font=Enum.Font.Gotham
    sub.TextSize=16; sub.TextWrapped=true; sub.TextXAlignment=Enum.TextXAlignment.Center
    sub.Transparency=1

    local playBtn = Instance.new("TextButton",card)
    playBtn.Size = UDim2.new(0,220,0,52)
    playBtn.AnchorPoint = Vector2.new(0.5,0); playBtn.Position = UDim2.new(0.5,0,0,240)
    playBtn.BackgroundColor3=Color3.fromRGB(70,130,230); playBtn.BorderSizePixel=0
    playBtn.Text="↩  Begin Again"; playBtn.TextColor3=Color3.fromRGB(220,240,255)
    playBtn.Font=Enum.Font.GothamBold; playBtn.TextSize=18; playBtn.Transparency=1
    Instance.new("UICorner",playBtn).CornerRadius=UDim.new(0,14)

    -- Fade in elements staggered
    tween(lanternEmoji, TweenInfo.new(0.8), {Transparency=0})
    task.delay(0.4, function() tween(title, TweenInfo.new(0.9), {Transparency=0}) end)
    task.delay(0.9, function() tween(sub,   TweenInfo.new(0.9), {Transparency=0}) end)
    task.delay(1.5, function()
        tween(playBtn, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Transparency=0, Position=UDim2.new(0.5,0,0,242)})
    end)

    card.Position = UDim2.new(0.5,0,0.65,0)
    tween(card, TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,0,0.5,0)})

    -- "Begin Again" resets the character (or teleport if multi-place)
    playBtn.MouseButton1Click:Connect(function()
        tween(overlay, TweenInfo.new(1.0), {BackgroundTransparency=1})
        task.delay(1.1, function()
            -- Reset character to re-experience the journey
            player:LoadCharacter()
            s:Destroy()
        end)
    end)
end

-- ── CINEMATIC CAMERA SEQUENCE ─────────────────────────────────────────────────

local function runCinematic(data)
    -- data = { playerId, playerName, lanternId, message, startPos }
    local isOwnLantern = (data.playerId == player.UserId)

    -- Lock camera to Scriptable for the duration
    local prevCamType = camera.CameraType
    camera.CameraType = Enum.CameraType.Scriptable

    -- Spawn pond ambience + firecrackers simultaneously
    task.spawn(spawnPondAmbience)
    task.spawn(spawnFirecrackers)   -- fireworks launch from the ground

    -- Show title card
    showReleaseTitle(data.playerName, data.message)

    -- ── PHASE 1: Pond wide shot (0–4 s) ──────────────────────────────────────
    local pondLookPos = data.startPos + Vector3.new(0, 1, 0)
    local phase1Pos   = data.startPos + Vector3.new(0, 8, 18)
    camera.CFrame = CFrame.lookAt(phase1Pos, pondLookPos)
    wait_tween(camera,
        TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { CFrame = CFrame.lookAt(phase1Pos + Vector3.new(0, 2, -3), pondLookPos) })

    -- ── PHASE 2: Tracking shot following lantern (4–12 s) ────────────────────
    local skyFolder = Workspace:WaitForChild("SkyLanterns", 5)
    local trackedLantern = skyFolder and skyFolder:FindFirstChild(data.lanternId)

    if trackedLantern then
        local trackConn
        local trackStart = tick()
        trackConn = RunService.RenderStepped:Connect(function()
            if not trackedLantern or not trackedLantern.Parent then
                trackConn:Disconnect(); return
            end
            local t = tick() - trackStart
            if t > 8 then trackConn:Disconnect(); return end

            local lp  = trackedLantern.Position
            local progress = t / 8   -- 0 → 1
            -- Camera starts close behind-below, pulls back as it rises
            local camOffset = Vector3.new(
                math.sin(t * 0.3) * 3,          -- gentle side sway
                -4 + progress * 6,               -- starts below, rises above
                8 - progress * 4                 -- pulls back slightly
            )
            local targetCFrame = CFrame.lookAt(lp + camOffset, lp + Vector3.new(0, 2, 0))
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, 0.06)
        end)
        task.wait(8)
    else
        task.wait(4)
    end

    -- ── PHASE 3: Pull back to birds-eye (12–20 s) ─────────────────────────────
    showSkyCaption("You are not alone in this night.", 0, 6)

    local birdEyePos = Vector3.new(RELEASE_POS.X, RELEASE_POS.Y + 200, RELEASE_POS.Z - 40)
    wait_tween(camera,
        TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
        { CFrame = CFrame.lookAt(birdEyePos, RELEASE_POS + Vector3.new(0, 80, -20)) })

    showSkyCaption("Every light up there carries someone's hope.", 2, 7)

    -- ── PHASE 4: Slow orbit + interactive sky (20–50 s) ──────────────────────
    local tooltipGui  = showClickTooltip()
    local orbitCenter = RELEASE_POS + Vector3.new(0, 130, -20)
    local orbitRadius = 80
    local orbitHeight = 200

    local orbitConn
    local orbitStart = tick()
    local orbitAngle = 0
    orbitConn = RunService.RenderStepped:Connect(function(dt)
        orbitAngle = orbitAngle + dt * 0.12   -- slow orbit
        local ox = orbitCenter.X + math.cos(orbitAngle) * orbitRadius
        local oz = orbitCenter.Z + math.sin(orbitAngle) * orbitRadius
        local oy = orbitCenter.Y + math.sin(orbitAngle * 0.4) * 15
        local camPos = Vector3.new(ox, oy, oz)
        camera.CFrame = camera.CFrame:Lerp(
            CFrame.lookAt(camPos, orbitCenter + Vector3.new(0, -30, 0)), 0.04)
    end)

    -- "End Journey" button appears after 10 s in orbit
    local endBtnGui
    task.delay(10, function()
        endBtnGui = Instance.new("ScreenGui", playerGui)
        endBtnGui.Name = "EndJourneyBtn"; endBtnGui.ResetOnSpawn = false; endBtnGui.IgnoreGuiInset = true

        local btn = Instance.new("TextButton", endBtnGui)
        btn.Size = UDim2.new(0, 220, 0, 48)
        btn.AnchorPoint = Vector2.new(1, 1); btn.Position = UDim2.new(0.98, 0, 0.97, 0)
        btn.BackgroundColor3 = Color3.fromRGB(60, 50, 100); btn.BackgroundTransparency = 0.1
        btn.BorderSizePixel = 0; btn.Text = "Complete Journey  →"
        btn.TextColor3 = Color3.fromRGB(200, 195, 255); btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

        btn.MouseButton1Click:Connect(function()
            orbitConn:Disconnect()
            if endBtnGui then endBtnGui:Destroy() end
            if tooltipGui then tooltipGui:Destroy() end
            camera.CameraType = prevCamType
            showEndScreen()
        end)
    end)

    -- Auto-advance after 32 s of orbit
    task.wait(32)
    if orbitConn.Connected then
        orbitConn:Disconnect()
    end
    if endBtnGui and endBtnGui.Parent then endBtnGui:Destroy() end
    if tooltipGui and tooltipGui.Parent then tooltipGui:Destroy() end

    camera.CameraType = prevCamType
    showEndScreen()
end

-- ── Wire events ───────────────────────────────────────────────────────────────

LanternReleased.OnClientEvent:Connect(function(data)
    task.spawn(runCinematic, data)
end)

LanternMessage.OnClientEvent:Connect(function(message)
    showMessageCard(message)
end)

print("[LanternCinematic] ready.")
