--[[
  BreathingModule.client.lua
  4-cycle guided breathing exercise.
  Fires Breathing_Complete to server on finish.
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")
local Remotes = RS:WaitForChild("Remotes")

local evStart    = Remotes:WaitForChild("Breathing_Start")
local evComplete = Remotes:WaitForChild("Breathing_Complete")

local CYCLES     = 4
local INHALE_T   = 4
local HOLD_T     = 2
local EXHALE_T   = 5
local done       = false

-- ── UI ────────────────────────────────────────────────────────────────────────

local function buildUI()
    local screen = Instance.new("ScreenGui")
    screen.Name           = "BreathingUI"
    screen.ResetOnSpawn   = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Enabled        = false
    screen.Parent         = gui

    local overlay = Instance.new("Frame", screen)
    overlay.Size             = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.fromRGB(5,3,18)
    overlay.BackgroundTransparency = 0.28
    overlay.BorderSizePixel  = 0

    local card = Instance.new("Frame", overlay)
    card.Size              = UDim2.new(0,360,0,400)
    card.AnchorPoint       = Vector2.new(0.5,0.5)
    card.Position          = UDim2.new(0.5,0,0.5,0)
    card.BackgroundColor3  = Color3.fromRGB(12,8,28)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel   = 0
    Instance.new("UICorner",card).CornerRadius = UDim.new(0,20)
    local cs = Instance.new("UIStroke",card)
    cs.Color = Color3.fromRGB(120,220,255); cs.Thickness = 2

    local title = Instance.new("TextLabel",card)
    title.Size = UDim2.new(1,-20,0,40); title.Position = UDim2.new(0,10,0,10)
    title.BackgroundTransparency = 1
    title.Text = "✦  Breathing Grove  ✦"
    title.TextColor3 = Color3.fromRGB(180,255,230)
    title.TextScaled = true; title.Font = Enum.Font.GothamBold

    -- Circle
    local ring = Instance.new("Frame",card)
    ring.Name = "Ring"
    ring.AnchorPoint = Vector2.new(0.5,0.5)
    ring.Position    = UDim2.new(0.5,0,0.47,0)
    ring.Size        = UDim2.new(0,140,0,140)
    ring.BackgroundColor3 = Color3.fromRGB(80,200,255)
    ring.BackgroundTransparency = 0.4
    ring.BorderSizePixel = 0
    Instance.new("UICorner",ring).CornerRadius = UDim.new(1,0)
    local inner = Instance.new("Frame",ring)
    inner.AnchorPoint = Vector2.new(0.5,0.5)
    inner.Position    = UDim2.new(0.5,0,0.5,0)
    inner.Size        = UDim2.new(0.55,0,0.55,0)
    inner.BackgroundColor3 = Color3.fromRGB(180,240,255)
    inner.BackgroundTransparency = 0.1
    inner.BorderSizePixel = 0
    Instance.new("UICorner",inner).CornerRadius = UDim.new(1,0)

    local instr = Instance.new("TextLabel",card)
    instr.Name = "Instr"
    instr.Size = UDim2.new(1,-20,0,32); instr.Position = UDim2.new(0,10,0.76,0)
    instr.BackgroundTransparency = 1
    instr.Text = "Breathe In..."; instr.TextColor3 = Color3.fromRGB(255,255,255)
    instr.TextScaled = true; instr.Font = Enum.Font.GothamSemibold

    local cycle = Instance.new("TextLabel",card)
    cycle.Name = "Cycle"
    cycle.Size = UDim2.new(1,-20,0,24); cycle.Position = UDim2.new(0,10,0.88,0)
    cycle.BackgroundTransparency = 1
    cycle.Text = ""; cycle.TextColor3 = Color3.fromRGB(160,200,220)
    cycle.TextScaled = true; cycle.Font = Enum.Font.Gotham

    return screen, ring, instr, cycle, overlay
end

-- ── Exercise loop ─────────────────────────────────────────────────────────────

local function run()
    local screen, ring, instr, cycle, overlay = buildUI()
    screen.Enabled = true

    for c = 1, CYCLES do
        cycle.Text = string.format("Cycle %d / %d", c, CYCLES)
        -- Inhale
        instr.Text = "Breathe In..."; instr.TextColor3 = Color3.fromRGB(120,220,255)
        TweenService:Create(ring, TweenInfo.new(INHALE_T, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {Size=UDim2.new(0,220,0,220), BackgroundTransparency=0.1}):Play()
        task.wait(INHALE_T)
        -- Hold
        instr.Text = "Hold..."; instr.TextColor3 = Color3.fromRGB(200,200,255)
        task.wait(HOLD_T)
        -- Exhale
        instr.Text = "Breathe Out..."; instr.TextColor3 = Color3.fromRGB(180,255,200)
        TweenService:Create(ring, TweenInfo.new(EXHALE_T, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {Size=UDim2.new(0,140,0,140), BackgroundTransparency=0.4}):Play()
        task.wait(EXHALE_T)
    end

    instr.Text = "✦  Well done  ✦"; instr.TextColor3 = Color3.fromRGB(255,230,100)
    cycle.Text = "Exercise complete"
    task.wait(1.5)

    TweenService:Create(overlay, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency=1}):Play()
    task.wait(0.9)
    screen:Destroy()
    evComplete:FireServer()
end

evStart.OnClientEvent:Connect(function()
    if done then return end
    done = true
    task.spawn(run)
end)

print("[BreathingModule] ready.")
