--[[
    BreathingExercise.client.lua
    Triggered when the player reaches the Breathing Grove milestone.

    UI:
    - Full-screen dimmed overlay
    - Animated breathing circle that expands (inhale) and contracts (exhale)
    - Text cues: "Breathe In... Breathe Out..."
    - 4 cycles required → then fires BreathingComplete to server
    - Lantern reward notification shown on completion
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player   = Players.LocalPlayer
local gui      = player:WaitForChild("PlayerGui")

-- Remotes
local evBreathingStart    = RS:WaitForChild("BreathingStart",    60)
local evBreathingComplete = RS:WaitForChild("BreathingComplete", 60)
local evLanternAwarded    = RS:WaitForChild("LanternAwarded",    60)

-- Guard: only play once
local exerciseDone = false

-- ── Build ScreenGui ───────────────────────────────────────────────────────────

local function buildGui()
    local screen = Instance.new("ScreenGui")
    screen.Name           = "BreathingExerciseGui"
    screen.ResetOnSpawn   = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Enabled        = false
    screen.Parent         = gui

    -- Dark overlay
    local overlay = Instance.new("Frame")
    overlay.Name              = "Overlay"
    overlay.Size              = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3  = Color3.fromRGB(8, 5, 22)
    overlay.BackgroundTransparency = 0.25
    overlay.BorderSizePixel   = 0
    overlay.Parent            = screen

    -- Center container
    local center = Instance.new("Frame")
    center.Name              = "Center"
    center.Size              = UDim2.new(0, 400, 0, 460)
    center.AnchorPoint       = Vector2.new(0.5, 0.5)
    center.Position          = UDim2.new(0.5, 0, 0.5, 0)
    center.BackgroundTransparency = 1
    center.Parent            = overlay
    Instance.new("UICorner", center).CornerRadius = UDim.new(0, 20)

    -- Breathing circle (outer ring)
    local ring = Instance.new("Frame")
    ring.Name              = "Ring"
    ring.AnchorPoint       = Vector2.new(0.5, 0.5)
    ring.Position          = UDim2.new(0.5, 0, 0.44, 0)
    ring.Size              = UDim2.new(0, 160, 0, 160)
    ring.BackgroundColor3  = Color3.fromRGB(80, 200, 255)
    ring.BackgroundTransparency = 0.4
    ring.BorderSizePixel   = 0
    ring.ZIndex            = 2
    ring.Parent            = center
    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)
    ringCorner.Parent = ring

    -- Inner pulse circle
    local pulse = Instance.new("Frame")
    pulse.Name              = "Pulse"
    pulse.AnchorPoint       = Vector2.new(0.5, 0.5)
    pulse.Position          = UDim2.new(0.5, 0, 0.5, 0)
    pulse.Size              = UDim2.new(0.6, 0, 0.6, 0)
    pulse.BackgroundColor3  = Color3.fromRGB(180, 240, 255)
    pulse.BackgroundTransparency = 0.1
    pulse.BorderSizePixel   = 0
    pulse.ZIndex            = 3
    pulse.Parent            = ring
    local pulseCorner = Instance.new("UICorner")
    pulseCorner.CornerRadius = UDim.new(1, 0)
    pulseCorner.Parent = pulse

    -- Title
    local title = Instance.new("TextLabel")
    title.Name              = "Title"
    title.Size              = UDim2.new(1, 0, 0, 48)
    title.Position          = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text              = "✦  Breathing Grove  ✦"
    title.TextColor3        = Color3.fromRGB(180, 255, 230)
    title.TextScaled        = true
    title.Font              = Enum.Font.GothamBold
    title.ZIndex            = 4
    title.Parent            = center

    -- Instruction label
    local instruction = Instance.new("TextLabel")
    instruction.Name         = "Instruction"
    instruction.Size         = UDim2.new(1, 0, 0, 36)
    instruction.Position     = UDim2.new(0, 0, 0.78, 0)
    instruction.BackgroundTransparency = 1
    instruction.Text         = "Breathe In..."
    instruction.TextColor3   = Color3.fromRGB(255, 255, 255)
    instruction.TextScaled   = true
    instruction.Font         = Enum.Font.GothamSemibold
    instruction.ZIndex       = 4
    instruction.Parent       = center

    -- Cycle counter
    local cycleLabel = Instance.new("TextLabel")
    cycleLabel.Name          = "CycleLabel"
    cycleLabel.Size          = UDim2.new(1, 0, 0, 28)
    cycleLabel.Position      = UDim2.new(0, 0, 0.9, 0)
    cycleLabel.BackgroundTransparency = 1
    cycleLabel.Text          = "Cycle 1 of 4"
    cycleLabel.TextColor3    = Color3.fromRGB(180, 200, 220)
    cycleLabel.TextScaled    = true
    cycleLabel.Font          = Enum.Font.Gotham
    cycleLabel.ZIndex        = 4
    cycleLabel.Parent        = center

    return screen, ring, instruction, cycleLabel
end

-- ── Lantern reward notification ───────────────────────────────────────────────

local function showLanternNotification()
    local screen = Instance.new("ScreenGui")
    screen.Name           = "LanternNotifGui"
    screen.ResetOnSpawn   = false
    screen.Parent         = gui

    local frame = Instance.new("Frame")
    frame.Size              = UDim2.new(0, 380, 0, 100)
    frame.AnchorPoint       = Vector2.new(0.5, 0)
    frame.Position          = UDim2.new(0.5, 0, -0.15, 0)
    frame.BackgroundColor3  = Color3.fromRGB(255, 200, 60)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel   = 0
    frame.Parent            = screen
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

    local shadow = Instance.new("UIStroke")
    shadow.Color     = Color3.fromRGB(180, 120, 0)
    shadow.Thickness = 2
    shadow.Parent    = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(1, -20, 1, 0)
    lbl.Position          = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text              = "🏮  Lantern Earned!\nContinue your journey along the path."
    lbl.TextColor3        = Color3.fromRGB(60, 30, 0)
    lbl.TextScaled        = true
    lbl.Font              = Enum.Font.GothamBold
    lbl.Parent            = frame

    -- Slide in
    TweenService:Create(frame,
        TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.06, 0) }
    ):Play()

    -- Slide out after 4 seconds
    task.delay(4, function()
        TweenService:Create(frame,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, 0, -0.2, 0) }
        ):Play()
        task.delay(0.6, function() screen:Destroy() end)
    end)
end

-- ── Breathing animation loop ──────────────────────────────────────────────────

local function runBreathingExercise(screen, ring, instruction, cycleLabel)
    screen.Enabled = true
    local TOTAL_CYCLES = 4
    local INHALE_TIME  = 4
    local HOLD_TIME    = 2
    local EXHALE_TIME  = 5

    local ringBase  = 160   -- base pixel size
    local ringLarge = 240   -- expanded size during inhale

    for cycle = 1, TOTAL_CYCLES do
        cycleLabel.Text = string.format("Cycle %d of %d", cycle, TOTAL_CYCLES)

        -- Inhale: expand ring
        instruction.Text  = "Breathe In..."
        instruction.TextColor3 = Color3.fromRGB(120, 220, 255)
        TweenService:Create(ring,
            TweenInfo.new(INHALE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Size = UDim2.new(0, ringLarge, 0, ringLarge),
              BackgroundTransparency = 0.1 }
        ):Play()
        task.wait(INHALE_TIME)

        -- Hold
        instruction.Text  = "Hold..."
        instruction.TextColor3 = Color3.fromRGB(200, 200, 255)
        task.wait(HOLD_TIME)

        -- Exhale: shrink ring
        instruction.Text  = "Breathe Out..."
        instruction.TextColor3 = Color3.fromRGB(180, 255, 200)
        TweenService:Create(ring,
            TweenInfo.new(EXHALE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Size = UDim2.new(0, ringBase, 0, ringBase),
              BackgroundTransparency = 0.4 }
        ):Play()
        task.wait(EXHALE_TIME)
    end

    -- Done!
    instruction.Text      = "✦  Well done.  ✦"
    instruction.TextColor3 = Color3.fromRGB(255, 230, 100)
    cycleLabel.Text        = "Exercise complete"

    task.wait(1.5)

    -- Fade out overlay
    TweenService:Create(screen:FindFirstChild("Overlay"),
        TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 1 }
    ):Play()
    task.wait(1)
    screen.Enabled = false

    -- Notify server
    evBreathingComplete:FireServer()
end

-- ── Event listener ────────────────────────────────────────────────────────────

local screen, ring, instruction, cycleLabel = buildGui()

evBreathingStart.OnClientEvent:Connect(function()
    if exerciseDone then return end
    exerciseDone = true
    task.spawn(function()
        runBreathingExercise(screen, ring, instruction, cycleLabel)
    end)
end)

evLanternAwarded.OnClientEvent:Connect(function()
    showLanternNotification()
end)

print("[BreathingExercise] Client ready.")
