--[[
  BreathingUI.client.lua  (LocalScript – StarterGui)

  Renders the box-breathing exercise overlay.
  Box breathing: Inhale 4s → Hold 4s → Exhale 4s → Hold 4s  (×4 cycles)

  Triggered by the OpenBreathing RemoteEvent from the server.
  On successful completion fires BreathingComplete back to server.
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local OpenBreathing     = Remotes:WaitForChild("OpenBreathing")
local BreathingComplete = Remotes:WaitForChild("BreathingComplete")
local AwardLantern      = Remotes:WaitForChild("AwardLantern")

-- ──────────────────────────────────────────────────────────
-- UI BUILD
-- ──────────────────────────────────────────────────────────
local function buildUI()
    local screen = Instance.new("ScreenGui")
    screen.Name            = "BreathingScreen"
    screen.ResetOnSpawn    = false
    screen.IgnoreGuiInset  = true
    screen.Enabled         = false
    screen.Parent          = playerGui

    -- Dark overlay
    local overlay = Instance.new("Frame", screen)
    overlay.Size              = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3  = Color3.fromRGB(8, 6, 20)
    overlay.BackgroundTransparency = 0.25
    overlay.BorderSizePixel   = 0

    -- Central card
    local card = Instance.new("Frame", overlay)
    card.Size                 = UDim2.new(0, 460, 0, 520)
    card.AnchorPoint          = Vector2.new(0.5, 0.5)
    card.Position             = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundColor3     = Color3.fromRGB(15, 12, 35)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel      = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 24)

    -- Title
    local title = Instance.new("TextLabel", card)
    title.Size               = UDim2.new(1, -40, 0, 48)
    title.Position           = UDim2.new(0, 20, 0, 18)
    title.BackgroundTransparency = 1
    title.Text               = "✦  Breathing Exercise  ✦"
    title.TextColor3         = Color3.fromRGB(200, 190, 255)
    title.Font               = Enum.Font.GothamBold
    title.TextSize           = 22

    -- Instruction sub-label
    local sub = Instance.new("TextLabel", card)
    sub.Size                 = UDim2.new(1, -40, 0, 30)
    sub.Position             = UDim2.new(0, 20, 0, 68)
    sub.BackgroundTransparency = 1
    sub.Text                 = "Follow the circle  •  4 rounds of box breathing"
    sub.TextColor3           = Color3.fromRGB(160, 155, 200)
    sub.Font                 = Enum.Font.Gotham
    sub.TextSize             = 15

    -- Breathing circle (expands/contracts)
    local circleContainer = Instance.new("Frame", card)
    circleContainer.Size              = UDim2.new(0, 200, 0, 200)
    circleContainer.AnchorPoint       = Vector2.new(0.5, 0)
    circleContainer.Position          = UDim2.new(0.5, 0, 0, 110)
    circleContainer.BackgroundTransparency = 1

    local circle = Instance.new("Frame", circleContainer)
    circle.Size              = UDim2.new(0, 80, 0, 80)
    circle.AnchorPoint       = Vector2.new(0.5, 0.5)
    circle.Position          = UDim2.new(0.5, 0, 0.5, 0)
    circle.BackgroundColor3  = Color3.fromRGB(100, 160, 255)
    circle.BackgroundTransparency = 0.1
    circle.BorderSizePixel   = 0
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    -- Phase label inside the circle
    local phaseLabel = Instance.new("TextLabel", circle)
    phaseLabel.Size              = UDim2.new(1, 0, 1, 0)
    phaseLabel.BackgroundTransparency = 1
    phaseLabel.Text              = "Get\nReady"
    phaseLabel.TextColor3        = Color3.fromRGB(255, 255, 255)
    phaseLabel.Font              = Enum.Font.GothamBold
    phaseLabel.TextSize          = 17

    -- Countdown number (outside circle)
    local countdown = Instance.new("TextLabel", card)
    countdown.Size               = UDim2.new(1, 0, 0, 40)
    countdown.Position           = UDim2.new(0, 0, 0, 318)
    countdown.BackgroundTransparency = 1
    countdown.Text               = ""
    countdown.TextColor3         = Color3.fromRGB(200, 200, 255)
    countdown.Font               = Enum.Font.GothamBold
    countdown.TextSize           = 32

    -- Progress bar (rounds)
    local progressBg = Instance.new("Frame", card)
    progressBg.Size              = UDim2.new(1, -60, 0, 10)
    progressBg.Position          = UDim2.new(0, 30, 0, 368)
    progressBg.BackgroundColor3  = Color3.fromRGB(40, 35, 70)
    progressBg.BorderSizePixel   = 0
    Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

    local progressBar = Instance.new("Frame", progressBg)
    progressBar.Size             = UDim2.new(0, 0, 1, 0)
    progressBar.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
    progressBar.BorderSizePixel  = 0
    Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)

    local progressLabel = Instance.new("TextLabel", card)
    progressLabel.Size              = UDim2.new(1, 0, 0, 28)
    progressLabel.Position          = UDim2.new(0, 0, 0, 384)
    progressLabel.BackgroundTransparency = 1
    progressLabel.Text              = "Round 0 / 4"
    progressLabel.TextColor3        = Color3.fromRGB(140, 130, 190)
    progressLabel.Font              = Enum.Font.Gotham
    progressLabel.TextSize          = 14

    -- Skip / close button (only visible if already completed)
    local closeBtn = Instance.new("TextButton", card)
    closeBtn.Name                = "CloseBtn"
    closeBtn.Size                = UDim2.new(0, 140, 0, 40)
    closeBtn.AnchorPoint         = Vector2.new(0.5, 0)
    closeBtn.Position            = UDim2.new(0.5, 0, 0, 460)
    closeBtn.BackgroundColor3    = Color3.fromRGB(60, 50, 100)
    closeBtn.BackgroundTransparency = 0.1
    closeBtn.Text                = "Close"
    closeBtn.TextColor3          = Color3.fromRGB(200, 195, 255)
    closeBtn.Font                = Enum.Font.GothamBold
    closeBtn.TextSize            = 15
    closeBtn.BorderSizePixel     = 0
    closeBtn.Visible             = false
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)

    return screen, {
        circle       = circle,
        phaseLabel   = phaseLabel,
        countdown    = countdown,
        progressBar  = progressBar,
        progressLabel = progressLabel,
        closeBtn     = closeBtn,
        overlay      = overlay,
    }
end

-- ──────────────────────────────────────────────────────────
-- BREATHING LOGIC
-- ──────────────────────────────────────────────────────────
local PHASES = {
    { name = "Inhale",   duration = 4, color = Color3.fromRGB(100, 160, 255), targetSize = 180 },
    { name = "Hold ↑",  duration = 4, color = Color3.fromRGB(160, 120, 255), targetSize = 180 },
    { name = "Exhale",   duration = 4, color = Color3.fromRGB(80,  200, 180), targetSize = 80  },
    { name = "Hold ↓",  duration = 4, color = Color3.fromRGB(120, 100, 200), targetSize = 80  },
}
local TOTAL_ROUNDS = 4

local activeSession = false

local function runBreathing(refs, screen, alreadyDone)
    if alreadyDone then
        refs.phaseLabel.Text  = "Already\nComplete ✓"
        refs.countdown.Text   = ""
        refs.closeBtn.Visible = true
        refs.closeBtn.MouseButton1Click:Connect(function()
            screen.Enabled = false
        end)
        return
    end

    if activeSession then return end
    activeSession = true

    -- Get ready pause
    task.wait(1)

    for round = 1, TOTAL_ROUNDS do
        refs.progressLabel.Text = "Round " .. round .. " / " .. TOTAL_ROUNDS
        TweenService:Create(refs.progressBar,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad),
            { Size = UDim2.new(round / TOTAL_ROUNDS, 0, 1, 0) }
        ):Play()

        for _, phase in ipairs(PHASES) do
            refs.phaseLabel.Text    = phase.name
            refs.circle.BackgroundColor3 = phase.color

            local targetPx = phase.targetSize
            TweenService:Create(refs.circle,
                TweenInfo.new(phase.duration * 0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Size = UDim2.new(0, targetPx, 0, targetPx) }
            ):Play()

            for t = phase.duration, 1, -1 do
                refs.countdown.Text = tostring(t)
                task.wait(1)
            end
            refs.countdown.Text = ""
        end
    end

    -- Completed!
    refs.phaseLabel.Text    = "Complete\n✓"
    refs.circle.BackgroundColor3 = Color3.fromRGB(80, 220, 140)
    TweenService:Create(refs.circle,
        TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 140, 0, 140) }
    ):Play()
    refs.progressLabel.Text = "Great job! A lantern rises for you."
    refs.countdown.Text     = ""

    -- Tell server
    BreathingComplete:FireServer()

    task.wait(2.5)

    -- Fade out
    TweenService:Create(refs.overlay,
        TweenInfo.new(1.2, Enum.EasingStyle.Quad),
        { BackgroundTransparency = 1 }
    ):Play()
    task.wait(1.3)
    screen.Enabled  = false
    activeSession   = false
end

-- ──────────────────────────────────────────────────────────
-- LANTERN REWARD NOTIFICATION
-- ──────────────────────────────────────────────────────────
local function showLanternNotif()
    local screen2 = Instance.new("ScreenGui", playerGui)
    screen2.Name           = "LanternNotif"
    screen2.ResetOnSpawn   = false
    screen2.IgnoreGuiInset = true

    local frame = Instance.new("Frame", screen2)
    frame.Size              = UDim2.new(0, 280, 0, 60)
    frame.AnchorPoint       = Vector2.new(0.5, 0)
    frame.Position          = UDim2.new(0.5, 0, 0, -70)
    frame.BackgroundColor3  = Color3.fromRGB(30, 25, 55)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel   = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

    local lbl = Instance.new("TextLabel", frame)
    lbl.Size                = UDim2.new(1, -20, 1, 0)
    lbl.Position            = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = "🏮  A lantern rises in your honour!"
    lbl.TextColor3          = Color3.fromRGB(255, 220, 120)
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 16

    -- Slide in from top
    TweenService:Create(frame,
        TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0, 24) }
    ):Play()
    task.wait(3)
    TweenService:Create(frame,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        { Position = UDim2.new(0.5, 0, 0, -70) }
    ):Play()
    task.wait(0.6)
    screen2:Destroy()
end

-- ──────────────────────────────────────────────────────────
-- EVENT WIRING
-- ──────────────────────────────────────────────────────────
local screen, refs = buildUI()

OpenBreathing.OnClientEvent:Connect(function(alreadyDone)
    -- Reset overlay transparency in case it was faded
    refs.overlay.BackgroundTransparency = 0.25
    screen.Enabled = true
    task.spawn(runBreathing, refs, screen, alreadyDone)
end)

AwardLantern.OnClientEvent:Connect(function()
    showLanternNotif()
end)
