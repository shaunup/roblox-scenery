--[[
  LanternCarry.client.lua  (LocalScript – StarterGui)
  ─────────────────────────────────────────────────────────────────────────────
  Handles the "carry" phase of the lantern journey:

    1. LanternPickedUp (S→C)
       • Spawns a glowing lantern Part above the player's right hand
       • Welds it to the character's RightHand / RightGrip using a WeldConstraint
       • Subtle bob animation
       • HUD: faint "Walk to the release site" prompt at bottom of screen

    2. LanternSiteReached (S→C)
       • Opens the message-writing popup (centred card, matches existing style)
       • Player writes their personal wish / message (150 chars)
       • "Release" button fires LanternRelease(message) to server
       • Popup fades out before cinematic begins
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local LanternPickedUp  = Remotes:WaitForChild("LanternPickedUp")
local LanternSiteReached = Remotes:WaitForChild("LanternSiteReached")
local LanternRelease   = Remotes:WaitForChild("LanternRelease")

local carrying        = false
local sitePromptShown = false
local lanternPart     = nil   -- the held lantern Part

-- ── Carried lantern (visual, client-only) ─────────────────────────────────────
local function spawnCarriedLantern()
    character = player.Character or player.CharacterAdded:Wait()
    local hand = character:WaitForChild("RightHand", 5)
            or character:WaitForChild("Right Arm", 5)
    if not hand then return end

    lanternPart = Instance.new("Part")
    lanternPart.Name        = "CarriedLantern"
    lanternPart.Size        = Vector3.new(0.9, 1.5, 0.9)
    lanternPart.Anchored    = false
    lanternPart.CanCollide  = false
    lanternPart.CastShadow  = false
    lanternPart.Material    = Enum.Material.Neon
    lanternPart.Color       = Color3.fromRGB(255, 210, 80)
    lanternPart.Transparency = 0.15
    lanternPart.Parent      = character

    -- Attach via WeldConstraint so it moves with the hand
    local weld         = Instance.new("WeldConstraint", lanternPart)
    weld.Part0         = lanternPart
    weld.Part1         = hand
    -- Position the lantern above the hand
    lanternPart.CFrame = hand.CFrame * CFrame.new(0, 1.4, 0)

    -- Glow
    local pl = Instance.new("PointLight", lanternPart)
    pl.Color      = Color3.fromRGB(255, 200, 80)
    pl.Brightness = 2.5
    pl.Range      = 18
    pl.Shadows    = false

    -- Flame effect
    local fire = Instance.new("Fire", lanternPart)
    fire.Heat           = 2
    fire.Size           = 0.4
    fire.Color          = Color3.fromRGB(255, 170, 40)
    fire.SecondaryColor = Color3.fromRGB(255, 80, 20)

    -- Gentle float bob
    task.spawn(function()
        local t = 0
        local bobConn
        bobConn = RunService.Heartbeat:Connect(function(dt)
            if not lanternPart or not lanternPart.Parent then
                bobConn:Disconnect(); return
            end
            t = t + dt
            -- Nudge the CFrame offset for a subtle up-down
            lanternPart.CFrame = hand.CFrame
                * CFrame.new(0.3, 1.4 + math.sin(t * 2) * 0.08, 0)
        end)
    end)
end

-- ── HUD: "walk to release site" hint ─────────────────────────────────────────
local function showCarryHint()
    local s = Instance.new("ScreenGui", playerGui)
    s.Name = "CarryHint"; s.ResetOnSpawn = false; s.IgnoreGuiInset = true

    local f = Instance.new("Frame", s)
    f.Size = UDim2.new(0, 380, 0, 52)
    f.AnchorPoint = Vector2.new(0.5, 1)
    f.Position    = UDim2.new(0.5, 0, 0.94, 0)
    f.BackgroundColor3 = Color3.fromRGB(15, 12, 35)
    f.BackgroundTransparency = 0.1; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", f)
    stroke.Color = Color3.fromRGB(255, 200, 80); stroke.Thickness = 1.5

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, -16, 1, 0); lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "🏮  Carry your lantern to the release site…"
    lbl.TextColor3 = Color3.fromRGB(255, 220, 130)
    lbl.Font = Enum.Font.GothamSemibold; lbl.TextSize = 15

    -- Slow pulse
    local ti = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    TweenService:Create(lbl, ti, { TextColor3 = Color3.fromRGB(255, 240, 200) }):Play()

    return s
end

-- ── Message popup ──────────────────────────────────────────────────────────────
local function buildMessagePopup()
    local screen = Instance.new("ScreenGui")
    screen.Name = "LanternMessagePopup"
    screen.ResetOnSpawn = false; screen.IgnoreGuiInset = true
    screen.Enabled = false; screen.Parent = playerGui

    -- Overlay
    local overlay = Instance.new("Frame", screen)
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.fromRGB(8, 6, 20)
    overlay.BackgroundTransparency = 0.3; overlay.BorderSizePixel = 0

    -- Card
    local card = Instance.new("Frame", overlay)
    card.Size = UDim2.new(0, 520, 0, 380)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position    = UDim2.new(0.5, 0, 1.2, 0)  -- off-screen start
    card.BackgroundColor3 = Color3.fromRGB(15, 12, 35)
    card.BackgroundTransparency = 0.04; card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 24)
    local cs = Instance.new("UIStroke", card)
    cs.Color = Color3.fromRGB(255, 200, 80); cs.Thickness = 2

    -- Gold accent bar at top
    local topBar = Instance.new("Frame", card)
    topBar.Size = UDim2.new(1, 0, 0, 5)
    topBar.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
    topBar.BorderSizePixel  = 0
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 24)

    -- Title
    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1,-40,0,48); title.Position = UDim2.new(0,20,0,14)
    title.BackgroundTransparency = 1
    title.Text = "🏮  Write Your Wish"
    title.TextColor3 = Color3.fromRGB(255, 220, 120)
    title.Font = Enum.Font.GothamBold; title.TextSize = 22

    -- Sub
    local sub = Instance.new("TextLabel", card)
    sub.Size = UDim2.new(1,-40,0,30); sub.Position = UDim2.new(0,20,0,64)
    sub.BackgroundTransparency = 1
    sub.Text = "Your message will travel with your lantern into the night sky."
    sub.TextColor3 = Color3.fromRGB(180, 175, 220)
    sub.Font = Enum.Font.Gotham; sub.TextSize = 14; sub.TextWrapped = true

    -- Text input
    local inputF = Instance.new("Frame", card)
    inputF.Size = UDim2.new(1,-40,0,130); inputF.Position = UDim2.new(0,20,0,106)
    inputF.BackgroundColor3 = Color3.fromRGB(22, 18, 50); inputF.BorderSizePixel = 0
    Instance.new("UICorner", inputF).CornerRadius = UDim.new(0,12)
    local ist = Instance.new("UIStroke", inputF)
    ist.Color = Color3.fromRGB(180, 150, 60); ist.Thickness = 1.5

    local tb = Instance.new("TextBox", inputF)
    tb.Name = "WishBox"; tb.Size = UDim2.new(1,-16,1,-8); tb.Position = UDim2.new(0,8,0,4)
    tb.BackgroundTransparency = 1; tb.Text = ""
    tb.PlaceholderText = "Write a wish, a hope, a gratitude…"
    tb.PlaceholderColor3 = Color3.fromRGB(80, 75, 120)
    tb.TextColor3 = Color3.fromRGB(255, 240, 200)
    tb.Font = Enum.Font.Gotham; tb.TextSize = 15
    tb.TextWrapped = true; tb.MultiLine = true

    -- Char count
    local cc = Instance.new("TextLabel", inputF)
    cc.Size = UDim2.new(0,60,0,18); cc.AnchorPoint = Vector2.new(1,1)
    cc.Position = UDim2.new(1,-4,1,-2); cc.BackgroundTransparency = 1
    cc.Text = "0/150"; cc.TextColor3 = Color3.fromRGB(100,90,140); cc.TextSize = 11
    cc.Font = Enum.Font.Gotham; cc.TextXAlignment = Enum.TextXAlignment.Right
    tb:GetPropertyChangedSignal("Text"):Connect(function()
        local t = tb.Text:sub(1,150); tb.Text = t; cc.Text = #t.."/150"
    end)

    -- Release button
    local releaseBtn = Instance.new("TextButton", card)
    releaseBtn.Name = "ReleaseBtn"
    releaseBtn.Size = UDim2.new(0, 260, 0, 52)
    releaseBtn.AnchorPoint = Vector2.new(0.5, 0); releaseBtn.Position = UDim2.new(0.5, 0, 0, 256)
    releaseBtn.BackgroundColor3 = Color3.fromRGB(220, 155, 30)
    releaseBtn.BorderSizePixel = 0
    releaseBtn.Text = "🏮  Release Into the Sky"
    releaseBtn.TextColor3 = Color3.fromRGB(40, 20, 0)
    releaseBtn.Font = Enum.Font.GothamBold; releaseBtn.TextSize = 17
    Instance.new("UICorner", releaseBtn).CornerRadius = UDim.new(0, 14)

    -- Pulse tween on button
    local ti = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    TweenService:Create(releaseBtn, ti, {BackgroundColor3 = Color3.fromRGB(255, 200, 60)}):Play()

    -- Status line
    local status = Instance.new("TextLabel", card)
    status.Size = UDim2.new(1,-20,0,26); status.Position = UDim2.new(0,10,0,320)
    status.BackgroundTransparency = 1; status.Text = ""
    status.TextColor3 = Color3.fromRGB(200,190,255)
    status.Font = Enum.Font.GothamSemibold; status.TextSize = 14

    return screen, card, overlay, tb, releaseBtn, status
end

-- ── Event handlers ────────────────────────────────────────────────────────────

local hintGui  = nil

LanternPickedUp.OnClientEvent:Connect(function()
    if carrying then return end
    carrying = true
    task.spawn(spawnCarriedLantern)
    hintGui = showCarryHint()
end)

LanternSiteReached.OnClientEvent:Connect(function()
    if sitePromptShown then return end
    sitePromptShown = true

    -- Dismiss carry hint
    if hintGui then
        TweenService:Create(hintGui:FindFirstChildOfClass("Frame"),
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}):Play()
        task.delay(0.45, function() if hintGui then hintGui:Destroy() end end)
    end

    local screen, card, overlay, tb, releaseBtn, status = buildMessagePopup()
    screen.Enabled = true

    -- Slide card up
    TweenService:Create(card,
        TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()

    releaseBtn.MouseButton1Click:Connect(function()
        local msg = tb.Text:gsub("^%s+",""):gsub("%s+$","")
        if #msg < 1 then
            status.Text = "Write something — even one word ✦"
            status.TextColor3 = Color3.fromRGB(255, 180, 80); return
        end
        releaseBtn.Active = false
        releaseBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 20)
        status.Text = "✦  Your lantern is ready to fly…"
        status.TextColor3 = Color3.fromRGB(255, 230, 120)

        -- Remove the carried lantern visually
        if lanternPart and lanternPart.Parent then
            TweenService:Create(lanternPart,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Transparency = 1}):Play()
            task.delay(0.55, function()
                if lanternPart then lanternPart:Destroy() end
            end)
        end

        task.wait(0.5)
        -- Fade popup out
        TweenService:Create(overlay,
            TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}):Play()
        task.wait(1.1); screen:Destroy()

        -- Tell server → cinematic begins
        LanternRelease:FireServer(msg)
    end)
end)

print("[LanternCarry] ready.")
