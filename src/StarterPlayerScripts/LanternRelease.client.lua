--[[
    LanternRelease.client.lua
    Handles the lantern release at the Glow Pond:

    - When CanReleaseLantern fires, shows a "Release Lantern" prompt
    - Player presses the button (or touches on mobile)
    - A glowing paper lantern Part is spawned above the player
    - Tweened upward with a gentle sway (BodyVelocity / physics-like)
    - Trail of sparkles follows it
    - After rising high, lantern fades out
    - Fires ReleaseLantern to server to update state
    - Cinematic camera widens during the release
    - Shows a final "Journey Complete" screen
]]

local Players        = game:GetService("Players")
local RS             = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local Workspace      = game:GetService("Workspace")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")

local evCanReleaseLantern = RS:WaitForChild("CanReleaseLantern", 60)
local evReleaseLantern    = RS:WaitForChild("ReleaseLantern",    60)

local released = false

-- ── Release Button UI ─────────────────────────────────────────────────────────

local function buildReleaseGui()
    local screen = Instance.new("ScreenGui")
    screen.Name         = "LanternReleaseGui"
    screen.ResetOnSpawn = false
    screen.Enabled      = false
    screen.Parent       = gui

    local btn = Instance.new("TextButton")
    btn.Name              = "ReleaseBtn"
    btn.Size              = UDim2.new(0, 280, 0, 64)
    btn.AnchorPoint       = Vector2.new(0.5, 1)
    btn.Position          = UDim2.new(0.5, 0, 0.85, 0)
    btn.BackgroundColor3  = Color3.fromRGB(255, 200, 50)
    btn.BackgroundTransparency = 0.05
    btn.BorderSizePixel   = 0
    btn.Text              = "🏮  Release Your Lantern"
    btn.TextColor3        = Color3.fromRGB(40, 20, 0)
    btn.TextScaled        = true
    btn.Font              = Enum.Font.GothamBold
    btn.Parent            = screen
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 16)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(200, 140, 0)
    stroke.Thickness = 2.5
    stroke.Parent    = btn

    -- Pulsing glow animation
    local ti = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    TweenService:Create(btn, ti, {
        BackgroundColor3 = Color3.fromRGB(255, 230, 120)
    }):Play()

    return screen, btn
end

-- ── Journey Complete screen ────────────────────────────────────────────────────

local function showJourneyComplete()
    local screen = Instance.new("ScreenGui")
    screen.Name         = "JourneyCompleteGui"
    screen.ResetOnSpawn = false
    screen.Parent       = gui

    local overlay = Instance.new("Frame")
    overlay.Size              = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3  = Color3.fromRGB(5, 3, 18)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel   = 0
    overlay.Parent            = screen

    -- Fade in overlay
    TweenService:Create(overlay,
        TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 0.25 }):Play()

    task.wait(1)

    local card = Instance.new("Frame")
    card.Size              = UDim2.new(0, 500, 0, 340)
    card.AnchorPoint       = Vector2.new(0.5, 0.5)
    card.Position          = UDim2.new(0.5, 0, 0.6, 0)
    card.BackgroundColor3  = Color3.fromRGB(14, 8, 35)
    card.BackgroundTransparency = 0.08
    card.BorderSizePixel   = 0
    card.Parent            = overlay
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 20)
    local cs = Instance.new("UIStroke")
    cs.Color     = Color3.fromRGB(255, 200, 80)
    cs.Thickness = 2
    cs.Parent    = card

    local emoji = Instance.new("TextLabel")
    emoji.Size              = UDim2.new(1, 0, 0, 80)
    emoji.Position          = UDim2.new(0, 0, 0.02, 0)
    emoji.BackgroundTransparency = 1
    emoji.Text              = "🏮"
    emoji.TextScaled        = true
    emoji.Parent            = card

    local title = Instance.new("TextLabel")
    title.Size              = UDim2.new(1, -20, 0, 52)
    title.Position          = UDim2.new(0, 10, 0.28, 0)
    title.BackgroundTransparency = 1
    title.Text              = "Your lantern rises into the night sky"
    title.TextColor3        = Color3.fromRGB(255, 230, 120)
    title.TextScaled        = true
    title.Font              = Enum.Font.GothamBold
    title.TextWrapped       = true
    title.Parent            = card

    local sub = Instance.new("TextLabel")
    sub.Size              = UDim2.new(1, -30, 0, 64)
    sub.Position          = UDim2.new(0, 15, 0.52, 0)
    sub.BackgroundTransparency = 1
    sub.Text              = "May your wishes travel far on the twilight breeze.\nThank you for walking this path."
    sub.TextColor3        = Color3.fromRGB(190, 200, 230)
    sub.TextSize          = 16
    sub.TextWrapped       = true
    sub.Font              = Enum.Font.Gotham
    sub.TextXAlignment    = Enum.TextXAlignment.Center
    sub.Parent            = card

    -- Slide card up into view
    card.Position = UDim2.new(0.5, 0, 0.9, 0)
    TweenService:Create(card,
        TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
end

-- ── Lantern Part animation ────────────────────────────────────────────────────

local function spawnLantern()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local spawnPos = root.Position + Vector3.new(0, 4, 0)

    -- Lantern body
    local lanternModel = Instance.new("Model")
    lanternModel.Name  = "ReleasedLantern"
    lanternModel.Parent = Workspace

    local body = Instance.new("Part")
    body.Name           = "LanternBody"
    body.Size           = Vector3.new(2, 3, 2)
    body.CFrame         = CFrame.new(spawnPos)
    body.Anchored       = true
    body.CanCollide     = false
    body.BrickColor     = BrickColor.new("Bright yellow")
    body.Material       = Enum.Material.Neon
    body.Transparency   = 0.15
    body.CastShadow     = false
    body.Parent         = lanternModel
    Instance.new("UICorner") -- visual

    local light = Instance.new("PointLight")
    light.Brightness = 2.5
    light.Range      = 28
    light.Color      = Color3.fromRGB(255, 200, 60)
    light.Parent     = body

    -- Inner flame glow
    local flame = Instance.new("Part")
    flame.Name        = "Flame"
    flame.Size        = Vector3.new(0.8, 0.8, 0.8)
    flame.CFrame      = CFrame.new(spawnPos)
    flame.Anchored    = true
    flame.CanCollide  = false
    flame.BrickColor  = BrickColor.new("Neon orange")
    flame.Material    = Enum.Material.Neon
    flame.Transparency= 0.2
    flame.CastShadow  = false
    flame.Parent      = lanternModel

    -- Sparkle trail (simple approach: spawn small glowing parts)
    local trailFolder = Instance.new("Folder")
    trailFolder.Name   = "Trail"
    trailFolder.Parent = lanternModel

    local totalFrames  = 280
    local frameCount   = 0
    local startY       = spawnPos.Y
    local swayAmplitude= 1.8
    local swaySpeed    = 1.2
    local riseSpeed    = 0.18
    local startTime    = tick()

    local trailParts   = {}
    local MAX_TRAIL    = 12

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        frameCount = frameCount + 1
        local t    = tick() - startTime
        local newY = spawnPos.Y + t * riseSpeed * 60 * dt

        -- sway
        local swayX = math.sin(t * swaySpeed) * swayAmplitude
        local swayZ = math.cos(t * swaySpeed * 0.7) * swayAmplitude * 0.5
        local newPos = Vector3.new(spawnPos.X + swayX, spawnPos.Y + t * 14, spawnPos.Z + swayZ)

        body.CFrame  = CFrame.new(newPos)
        flame.CFrame = CFrame.new(newPos)

        -- Spawn trail sparkle
        if frameCount % 6 == 0 then
            local spark = Instance.new("Part")
            spark.Size        = Vector3.new(0.3, 0.3, 0.3)
            spark.CFrame      = CFrame.new(newPos + Vector3.new(math.random(-5,5)/10, -1, math.random(-5,5)/10))
            spark.Anchored    = true
            spark.CanCollide  = false
            spark.BrickColor  = BrickColor.new("Bright yellow")
            spark.Material    = Enum.Material.Neon
            spark.Transparency= 0.3
            spark.CastShadow  = false
            spark.Parent      = trailFolder
            table.insert(trailParts, spark)

            -- Fade & remove old sparkles
            if #trailParts > MAX_TRAIL then
                local old = table.remove(trailParts, 1)
                TweenService:Create(old,
                    TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05) }
                ):Play()
                task.delay(0.45, function() if old then old:Destroy() end end)
            end
        end

        -- Gradually reduce lantern opacity as it rises high
        local progress = t / 14
        body.Transparency  = math.min(0.15 + progress * 0.85, 1)
        flame.Transparency = math.min(0.2  + progress * 0.8,  1)
        light.Brightness   = math.max(2.5  - progress * 2.5,  0)

        if frameCount >= totalFrames then
            conn:Disconnect()
            task.delay(1, function() lanternModel:Destroy() end)
            showJourneyComplete()
        end
    end)
end

-- ── Event wiring ─────────────────────────────────────────────────────────────

local releaseScreen, releaseBtn = buildReleaseGui()

evCanReleaseLantern.OnClientEvent:Connect(function()
    if released then return end
    releaseScreen.Enabled = true
end)

releaseBtn.MouseButton1Click:Connect(function()
    if released then return end
    released = true
    releaseScreen.Enabled = false
    evReleaseLantern:FireServer()
    spawnLantern()
end)

-- Mobile: TouchTap on button handled automatically by TextButton

print("[LanternRelease] Client ready.")
