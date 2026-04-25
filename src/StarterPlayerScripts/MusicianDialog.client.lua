--[[
    MusicianDialog.client.lua
    Handles the bonfire musician interaction:
    - Shows a chat dialog UI when player approaches
    - Player types their music mood preference
    - Sends choice to server (GameManager)
    - Receives back the audio ID from Gemini
    - Plays the music and shows "Now Playing" notification
    - Music fades in, loops while player is in the bonfire area
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local evMusicianApproach = RS:WaitForChild("MusicianApproach", 60)
local evMusicChoice      = RS:WaitForChild("MusicChoice",      60)
local evPlayMusic        = RS:WaitForChild("PlayMusic",        60)

local dialogShown = false
local currentSound = nil

-- ── Build dialog UI ───────────────────────────────────────────────────────────

local function buildDialogGui()
    local screen = Instance.new("ScreenGui")
    screen.Name         = "MusicianDialogGui"
    screen.ResetOnSpawn = false
    screen.Enabled      = false
    screen.Parent       = gui

    -- Chat bubble panel (lower third)
    local panel = Instance.new("Frame")
    panel.Name              = "Panel"
    panel.Size              = UDim2.new(0, 560, 0, 280)
    panel.AnchorPoint       = Vector2.new(0.5, 1)
    panel.Position          = UDim2.new(0.5, 0, 1.1, 0)
    panel.BackgroundColor3  = Color3.fromRGB(20, 14, 40)
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel   = 0
    panel.Parent            = screen
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(255, 200, 80)
    stroke.Thickness = 2
    stroke.Parent    = panel

    -- Musician avatar icon
    local avatar = Instance.new("Frame")
    avatar.Size             = UDim2.new(0, 64, 0, 64)
    avatar.AnchorPoint      = Vector2.new(0, 0.5)
    avatar.Position         = UDim2.new(0, 16, 0, 0.28)
    avatar.BackgroundColor3 = Color3.fromRGB(200, 130, 60)
    avatar.BorderSizePixel  = 0
    avatar.Parent           = panel
    Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
    local avatarLabel = Instance.new("TextLabel")
    avatarLabel.Size   = UDim2.new(1,0,1,0)
    avatarLabel.BackgroundTransparency = 1
    avatarLabel.Text   = "🎸"
    avatarLabel.TextScaled = true
    avatarLabel.Parent = avatar

    -- Musician name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size          = UDim2.new(0.65, 0, 0, 28)
    nameLabel.Position      = UDim2.new(0.17, 0, 0.04, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text          = "Elara the Musician"
    nameLabel.TextColor3    = Color3.fromRGB(255, 200, 80)
    nameLabel.TextScaled    = true
    nameLabel.Font          = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent        = panel

    -- Dialog text
    local dialog = Instance.new("TextLabel")
    dialog.Name             = "DialogText"
    dialog.Size             = UDim2.new(0.78, 0, 0, 72)
    dialog.Position         = UDim2.new(0.17, 0, 0.24, 0)
    dialog.BackgroundTransparency = 1
    dialog.Text             = "\"Hey traveller, you made it to the fire!\nWhat kind of music speaks to your soul tonight?\n(calm, jazz, classical, upbeat, ambient...)\""
    dialog.TextColor3       = Color3.fromRGB(220, 220, 220)
    dialog.TextWrapped      = true
    dialog.TextScaled       = false
    dialog.TextSize         = 15
    dialog.Font             = Enum.Font.Gotham
    dialog.TextXAlignment   = Enum.TextXAlignment.Left
    dialog.TextYAlignment   = Enum.TextYAlignment.Top
    dialog.Parent           = panel

    -- Input box
    local inputFrame = Instance.new("Frame")
    inputFrame.Name           = "InputFrame"
    inputFrame.Size           = UDim2.new(0.72, 0, 0, 36)
    inputFrame.Position       = UDim2.new(0.17, 0, 0.72, 0)
    inputFrame.BackgroundColor3 = Color3.fromRGB(40, 30, 65)
    inputFrame.BorderSizePixel  = 0
    inputFrame.Parent           = panel
    Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0, 8)
    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color     = Color3.fromRGB(100, 80, 160)
    inputStroke.Thickness = 1.5
    inputStroke.Parent    = inputFrame

    local textBox = Instance.new("TextBox")
    textBox.Name              = "InputBox"
    textBox.Size              = UDim2.new(1, -10, 1, 0)
    textBox.Position          = UDim2.new(0, 5, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.Text              = ""
    textBox.PlaceholderText   = "Type your mood here..."
    textBox.PlaceholderColor3 = Color3.fromRGB(120, 110, 150)
    textBox.TextColor3        = Color3.fromRGB(255, 255, 255)
    textBox.TextSize          = 14
    textBox.Font              = Enum.Font.Gotham
    textBox.ClearTextOnFocus  = true
    textBox.Parent            = inputFrame

    -- Send button
    local sendBtn = Instance.new("TextButton")
    sendBtn.Name              = "SendBtn"
    sendBtn.Size              = UDim2.new(0.1, 0, 0, 36)
    sendBtn.Position          = UDim2.new(0.89, 0, 0.72, 0)
    sendBtn.BackgroundColor3  = Color3.fromRGB(255, 180, 40)
    sendBtn.BorderSizePixel   = 0
    sendBtn.Text              = "→"
    sendBtn.TextColor3        = Color3.fromRGB(30, 20, 0)
    sendBtn.TextScaled        = true
    sendBtn.Font              = Enum.Font.GothamBold
    sendBtn.Parent            = panel
    Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 8)

    return screen, panel, textBox, sendBtn, dialog
end

-- ── Now-playing banner ────────────────────────────────────────────────────────

local function showNowPlaying(moodText)
    local screen = Instance.new("ScreenGui")
    screen.Name         = "NowPlayingGui"
    screen.ResetOnSpawn = false
    screen.Parent       = gui

    local banner = Instance.new("Frame")
    banner.Size              = UDim2.new(0, 400, 0, 72)
    banner.AnchorPoint       = Vector2.new(0.5, 0)
    banner.Position          = UDim2.new(0.5, 0, -0.1, 0)
    banner.BackgroundColor3  = Color3.fromRGB(30, 20, 60)
    banner.BackgroundTransparency = 0.1
    banner.BorderSizePixel   = 0
    banner.Parent            = screen
    Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 14)
    local s = Instance.new("UIStroke")
    s.Color     = Color3.fromRGB(180, 120, 255)
    s.Thickness = 1.5
    s.Parent    = banner

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(1, -16, 1, 0)
    lbl.Position          = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text              = "♪  Now Playing: " .. moodText .. " vibes"
    lbl.TextColor3        = Color3.fromRGB(210, 180, 255)
    lbl.TextScaled        = true
    lbl.Font              = Enum.Font.GothamSemibold
    lbl.Parent            = banner

    TweenService:Create(banner,
        TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.03, 0) }):Play()

    task.delay(6, function()
        TweenService:Create(banner,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, 0, -0.15, 0) }):Play()
        task.delay(0.6, function() screen:Destroy() end)
    end)
end

-- ── Main logic ────────────────────────────────────────────────────────────────

local screen, panel, textBox, sendBtn, dialog = buildDialogGui()

local function showDialog()
    screen.Enabled = true
    -- Slide panel up
    TweenService:Create(panel,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.96, 0) }):Play()
end

local function hideDialog()
    TweenService:Create(panel,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, 1.1, 0) }):Play()
    task.delay(0.4, function() screen.Enabled = false end)
end

local function submitChoice()
    local choice = textBox.Text
    if choice == "" or choice == nil then return end
    sendBtn.Active = false
    sendBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 20)
    dialog.Text = "\"Great choice! Give me a moment to find the\nperfect tune for you...\""
    task.delay(1.5, hideDialog)
    evMusicChoice:FireServer(choice)
end

sendBtn.MouseButton1Click:Connect(submitChoice)
textBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then submitChoice() end
end)

evMusicianApproach.OnClientEvent:Connect(function()
    if dialogShown then return end
    dialogShown = true
    showDialog()
end)

evPlayMusic.OnClientEvent:Connect(function(audioId, moodText)
    -- Create Sound in SoundService
    if currentSound then
        currentSound:Stop()
        currentSound:Destroy()
    end

    local sound = Instance.new("Sound")
    sound.Name      = "BonfireMusic"
    sound.SoundId   = audioId
    sound.Volume    = 0
    sound.Looped    = true
    sound.Parent    = SoundService
    sound:Play()
    currentSound    = sound

    -- Fade in
    TweenService:Create(sound, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Volume = 0.6 }):Play()

    showNowPlaying(moodText or "your mood")
end)

print("[MusicianDialog] Client ready.")
