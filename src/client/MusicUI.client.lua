--[[
  MusicUI.client.lua  (LocalScript – StarterGui)

  Renders the musician dialog overlay:
    1. The musician greets the player with a short dialogue bubble.
    2. Genre buttons are revealed (Lo-Fi, Ambient, Classical, Jazz, etc.)
    3. Player clicks a genre → sent to server via PlayMusic RemoteEvent.
    4. Server replies with the resolved audio ID.
    5. A SoundService Sound is created/updated and played client-side.
    6. A now-playing bar appears at the bottom of the screen.
    7. Player can stop music or choose another genre at any time.
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes         = ReplicatedStorage:WaitForChild("Remotes")
local OpenMusicDialog = Remotes:WaitForChild("OpenMusicDialog")
local PlayMusicRemote = Remotes:WaitForChild("PlayMusic")

local MusicLibrary = require(ReplicatedStorage:WaitForChild("MusicLibrary"))

-- ──────────────────────────────────────────────────────────
-- GENRE DATA (from shared module)
-- ──────────────────────────────────────────────────────────
local GENRES = MusicLibrary.getAllEntries()

-- ──────────────────────────────────────────────────────────
-- SOUND PLAYER
-- ──────────────────────────────────────────────────────────
local activeSound = nil

local function playSound(audioId, genreLabel)
    if activeSound then
        activeSound:Stop()
        activeSound:Destroy()
        activeSound = nil
    end

    local sound = Instance.new("Sound", SoundService)
    sound.Name    = "MusicianTrack"
    sound.SoundId = audioId
    sound.Volume  = 0.65
    sound.Looped  = true
    sound:Play()
    activeSound = sound
    return sound
end

local function stopSound()
    if activeSound then
        activeSound:Stop()
        activeSound:Destroy()
        activeSound = nil
    end
end

-- ──────────────────────────────────────────────────────────
-- NOW-PLAYING BAR
-- ──────────────────────────────────────────────────────────
local nowPlayingScreen = nil

local function buildNowPlayingBar(genreLabel)
    if nowPlayingScreen then nowPlayingScreen:Destroy() end

    local screen = Instance.new("ScreenGui", playerGui)
    screen.Name            = "NowPlayingBar"
    screen.ResetOnSpawn    = false
    screen.IgnoreGuiInset  = true
    nowPlayingScreen       = screen

    local bar = Instance.new("Frame", screen)
    bar.Size              = UDim2.new(0, 360, 0, 56)
    bar.AnchorPoint       = Vector2.new(0.5, 1)
    bar.Position          = UDim2.new(0.5, 0, 1, 80)
    bar.BackgroundColor3  = Color3.fromRGB(18, 14, 40)
    bar.BackgroundTransparency = 0.08
    bar.BorderSizePixel   = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 16)

    local icon = Instance.new("TextLabel", bar)
    icon.Size              = UDim2.new(0, 44, 1, 0)
    icon.Position          = UDim2.new(0, 8, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text              = "♪"
    icon.TextColor3        = Color3.fromRGB(180, 220, 255)
    icon.Font              = Enum.Font.GothamBold
    icon.TextSize          = 28

    local nowLabel = Instance.new("TextLabel", bar)
    nowLabel.Size          = UDim2.new(1, -110, 1, 0)
    nowLabel.Position      = UDim2.new(0, 54, 0, 0)
    nowLabel.BackgroundTransparency = 1
    nowLabel.Text          = "Now playing: " .. genreLabel
    nowLabel.TextColor3    = Color3.fromRGB(220, 215, 255)
    nowLabel.Font          = Enum.Font.Gotham
    nowLabel.TextSize      = 14
    nowLabel.TextXAlignment = Enum.TextXAlignment.Left

    local stopBtn = Instance.new("TextButton", bar)
    stopBtn.Size           = UDim2.new(0, 50, 0, 30)
    stopBtn.AnchorPoint    = Vector2.new(1, 0.5)
    stopBtn.Position       = UDim2.new(1, -8, 0.5, 0)
    stopBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 100)
    stopBtn.BackgroundTransparency = 0.1
    stopBtn.Text           = "Stop"
    stopBtn.TextColor3     = Color3.fromRGB(255, 180, 200)
    stopBtn.Font           = Enum.Font.GothamBold
    stopBtn.TextSize       = 13
    stopBtn.BorderSizePixel = 0
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)

    stopBtn.MouseButton1Click:Connect(function()
        stopSound()
        TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
            { Position = UDim2.new(0.5, 0, 1, 80) }):Play()
        task.wait(0.5)
        screen:Destroy()
        nowPlayingScreen = nil
    end)

    -- Slide in from bottom
    TweenService:Create(bar, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 1, -20) }):Play()
end

-- ──────────────────────────────────────────────────────────
-- MUSICIAN DIALOG UI
-- ──────────────────────────────────────────────────────────
local dialogScreen = nil

local MUSICIAN_LINES = {
    "Ah, a wanderer on the trail...",
    "The fire's warm, the night is young.",
    "What sort of music speaks to your soul tonight?",
}

local function buildDialogUI()
    if dialogScreen then
        dialogScreen.Enabled = true
        return
    end

    local screen = Instance.new("ScreenGui", playerGui)
    screen.Name           = "MusicianDialog"
    screen.ResetOnSpawn   = false
    screen.IgnoreGuiInset = true
    dialogScreen          = screen

    -- Dim overlay (lighter than breathing – this is a chat, not immersive)
    local overlay = Instance.new("Frame", screen)
    overlay.Size              = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.55
    overlay.BorderSizePixel   = 0

    -- Dialog card (bottom third of screen, wide)
    local card = Instance.new("Frame", overlay)
    card.Size              = UDim2.new(0.9, 0, 0, 380)
    card.AnchorPoint       = Vector2.new(0.5, 1)
    card.Position          = UDim2.new(0.5, 0, 1, 20)
    card.BackgroundColor3  = Color3.fromRGB(14, 10, 32)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel   = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 20)

    -- NPC portrait placeholder
    local portrait = Instance.new("Frame", card)
    portrait.Size              = UDim2.new(0, 64, 0, 64)
    portrait.Position          = UDim2.new(0, 18, 0, 14)
    portrait.BackgroundColor3  = Color3.fromRGB(80, 60, 120)
    portrait.BorderSizePixel   = 0
    Instance.new("UICorner", portrait).CornerRadius = UDim.new(1, 0)

    local portraitIcon = Instance.new("TextLabel", portrait)
    portraitIcon.Size              = UDim2.new(1, 0, 1, 0)
    portraitIcon.BackgroundTransparency = 1
    portraitIcon.Text              = "♪"
    portraitIcon.TextColor3        = Color3.fromRGB(255, 240, 180)
    portraitIcon.Font              = Enum.Font.GothamBold
    portraitIcon.TextSize          = 32

    local npcName = Instance.new("TextLabel", card)
    npcName.Size               = UDim2.new(1, -100, 0, 28)
    npcName.Position           = UDim2.new(0, 92, 0, 18)
    npcName.BackgroundTransparency = 1
    npcName.Text               = "The Musician"
    npcName.TextColor3         = Color3.fromRGB(255, 220, 140)
    npcName.Font               = Enum.Font.GothamBold
    npcName.TextSize           = 17
    npcName.TextXAlignment     = Enum.TextXAlignment.Left

    -- Dialogue text box
    local dialogText = Instance.new("TextLabel", card)
    dialogText.Size              = UDim2.new(1, -36, 0, 52)
    dialogText.Position          = UDim2.new(0, 18, 0, 52)
    dialogText.BackgroundTransparency = 1
    dialogText.Text              = MUSICIAN_LINES[3]
    dialogText.TextColor3        = Color3.fromRGB(220, 215, 255)
    dialogText.Font              = Enum.Font.Gotham
    dialogText.TextSize          = 15
    dialogText.TextWrapped       = true
    dialogText.TextXAlignment    = Enum.TextXAlignment.Left
    dialogText.RichText          = true

    -- Genre selection label
    local pickLabel = Instance.new("TextLabel", card)
    pickLabel.Size              = UDim2.new(1, -36, 0, 24)
    pickLabel.Position          = UDim2.new(0, 18, 0, 106)
    pickLabel.BackgroundTransparency = 1
    pickLabel.Text              = "Choose a mood:"
    pickLabel.TextColor3        = Color3.fromRGB(160, 150, 200)
    pickLabel.Font              = Enum.Font.Gotham
    pickLabel.TextSize          = 13
    pickLabel.TextXAlignment    = Enum.TextXAlignment.Left

    -- Genre buttons (2-column grid)
    local btnContainer = Instance.new("Frame", card)
    btnContainer.Size              = UDim2.new(1, -36, 0, 190)
    btnContainer.Position          = UDim2.new(0, 18, 0, 132)
    btnContainer.BackgroundTransparency = 1

    local layout = Instance.new("UIGridLayout", btnContainer)
    layout.CellSize        = UDim2.new(0.5, -6, 0, 40)
    layout.CellPadding     = UDim2.new(0, 6, 0, 6)
    layout.FillDirection   = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment   = Enum.VerticalAlignment.Top
    layout.SortOrder       = Enum.SortOrder.LayoutOrder

    for i, genre in ipairs(GENRES) do
        local btn = Instance.new("TextButton", btnContainer)
        btn.LayoutOrder        = i
        btn.BackgroundColor3   = Color3.fromRGB(45, 35, 80)
        btn.BackgroundTransparency = 0.05
        btn.Text               = genre.label
        btn.TextColor3         = Color3.fromRGB(210, 200, 255)
        btn.Font               = Enum.Font.Gotham
        btn.TextSize           = 13
        btn.BorderSizePixel    = 0
        btn.AutoButtonColor    = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(80, 60, 140)
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(45, 35, 80)
            }):Play()
        end)

        btn.MouseButton1Click:Connect(function()
            dialogText.Text = "<i>\"Ah, a fine choice — " .. genre.label .. ".\nLet the night carry the sound...\"</i>"
            -- Tell server
            PlayMusicRemote:FireServer(genre.key)
            -- Slide card out
            task.wait(1.5)
            TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Quad),
                { Position = UDim2.new(0.5, 0, 1, 20) }):Play()
            task.wait(0.55)
            screen.Enabled = false
        end)
    end

    -- Close / dismiss button
    local closeBtn = Instance.new("TextButton", card)
    closeBtn.Size              = UDim2.new(0, 80, 0, 30)
    closeBtn.AnchorPoint       = Vector2.new(1, 0)
    closeBtn.Position          = UDim2.new(1, -14, 0, 14)
    closeBtn.BackgroundColor3  = Color3.fromRGB(55, 40, 80)
    closeBtn.BackgroundTransparency = 0.15
    closeBtn.Text              = "✕  Close"
    closeBtn.TextColor3        = Color3.fromRGB(180, 160, 220)
    closeBtn.Font              = Enum.Font.Gotham
    closeBtn.TextSize          = 13
    closeBtn.BorderSizePixel   = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
            { Position = UDim2.new(0.5, 0, 1, 20) }):Play()
        task.wait(0.45)
        screen.Enabled = false
    end)

    -- Animate card in
    TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 1, -10) }):Play()

    -- Type out musician lines sequentially then show the genre picker
    task.spawn(function()
        for _, line in ipairs(MUSICIAN_LINES) do
            dialogText.Text = line
            task.wait(1.8)
        end
    end)
end

-- ──────────────────────────────────────────────────────────
-- EVENT WIRING
-- ──────────────────────────────────────────────────────────
OpenMusicDialog.OnClientEvent:Connect(function()
    if dialogScreen then
        -- Re-show with slide-in animation
        dialogScreen.Enabled = true
        local card = dialogScreen:FindFirstChildWhichIsA("Frame")
                     and dialogScreen:FindFirstChild("Frame")
        if card then
            TweenService:Create(card:FindFirstChildWhichIsA("Frame"),
                TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Position = UDim2.new(0.5, 0, 1, -10) }):Play()
        end
    else
        buildDialogUI()
    end
end)

-- Server replies with confirmed genre + audio ID
PlayMusicRemote.OnClientEvent:Connect(function(genreKey, audioId)
    local label = MusicLibrary.getGenreLabel(genreKey)
    playSound(audioId, label)
    buildNowPlayingBar(label)
end)
