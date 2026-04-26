--[[
  JigsawUI.client.lua  (LocalScript – StarterGui)
  ─────────────────────────────────────────────────────────────────────────────
  Wisdom Puzzle  –  reassemble a quote from shuffled word tiles.

  Layout (full-screen card, centred):
    ┌──────────────────────────────────────────────────┐
    │  ✦  Wisdom Puzzle  ✦          Round 1 / 3       │
    │  ─────────────────────────────────────────────── │
    │  SENTENCE TRAY  (tap a placed word to remove it) │
    │  ─────────────────────────────────────────────── │
    │  WORD BANK  (tap a word to place it)             │
    │  ─────────────────────────────────────────────── │
    │            [ ✓  Submit Answer ]                  │
    │            feedback line                         │
    └──────────────────────────────────────────────────┘

  Interaction:
    Tap a tile in the BANK  → moves to the end of the TRAY
    Tap a tile in the TRAY  → moves back to the BANK (in original order)
    Submit → server validates; wrong = shake + red flash; correct = celebrate

  Remotes (all in RS/Remotes):
    OpenJigsaw   S→C  (alreadyDone bool)
    JigsawRound  S→C  ({ roundNumber, totalRounds, shuffledWords })
    JigsawSubmit C→S  (answerString)
    JigsawResult S→C  ({ correct, roundNumber })
    JigsawDone   S→C  ()
    AwardLantern S→C  ()  – reused for the toast notification
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local OpenJigsaw   = Remotes:WaitForChild("OpenJigsaw")
local JigsawRound  = Remotes:WaitForChild("JigsawRound")
local JigsawSubmit = Remotes:WaitForChild("JigsawSubmit")
local JigsawResult = Remotes:WaitForChild("JigsawResult")
local JigsawDone   = Remotes:WaitForChild("JigsawDone")
local AwardLantern = Remotes:WaitForChild("AwardLantern")

-- ── Tile colour palette (cycles across words) ─────────────────────────────────
local TILE_COLORS = {
    Color3.fromRGB( 60, 120, 210),
    Color3.fromRGB(130,  55, 185),
    Color3.fromRGB( 35, 155, 110),
    Color3.fromRGB(175,  85,  45),
    Color3.fromRGB( 45, 140, 165),
    Color3.fromRGB(155,  50, 100),
}
local function tileColor(i) return TILE_COLORS[((i-1) % #TILE_COLORS) + 1] end

-- ── Build UI ──────────────────────────────────────────────────────────────────
local function buildUI()
    local screen = Instance.new("ScreenGui")
    screen.Name           = "JigsawScreen"
    screen.ResetOnSpawn   = false
    screen.IgnoreGuiInset = true
    screen.Enabled        = false
    screen.Parent         = playerGui

    -- Dark overlay (matches BreathingUI)
    local overlay = Instance.new("Frame", screen)
    overlay.Size             = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(8, 6, 20)
    overlay.BackgroundTransparency = 0.25
    overlay.BorderSizePixel  = 0

    -- Central card
    local card = Instance.new("Frame", overlay)
    card.Size              = UDim2.new(0, 620, 0, 490)
    card.AnchorPoint       = Vector2.new(0.5, 0.5)
    card.Position          = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundColor3  = Color3.fromRGB(15, 12, 35)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel   = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 24)

    -- Accent top bar (same style as BreathingUI glow)
    local topBar = Instance.new("Frame", card)
    topBar.Size            = UDim2.new(1, 0, 0, 5)
    topBar.BackgroundColor3 = Color3.fromRGB(100, 170, 255)
    topBar.BorderSizePixel = 0
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 24)

    -- Title
    local title = Instance.new("TextLabel", card)
    title.Size     = UDim2.new(1, -40, 0, 44)
    title.Position = UDim2.new(0, 20, 0, 14)
    title.BackgroundTransparency = 1
    title.Text     = "✦  Wisdom Puzzle  ✦"
    title.TextColor3 = Color3.fromRGB(200, 190, 255)
    title.Font     = Enum.Font.GothamBold
    title.TextSize = 22

    -- Round label (top-right)
    local roundLbl = Instance.new("TextLabel", card)
    roundLbl.Name  = "RoundLbl"
    roundLbl.Size  = UDim2.new(0, 120, 0, 28)
    roundLbl.AnchorPoint = Vector2.new(1, 0)
    roundLbl.Position    = UDim2.new(1, -16, 0, 20)
    roundLbl.BackgroundTransparency = 1
    roundLbl.Text  = ""
    roundLbl.TextColor3 = Color3.fromRGB(150, 145, 200)
    roundLbl.Font  = Enum.Font.Gotham
    roundLbl.TextSize = 14
    roundLbl.TextXAlignment = Enum.TextXAlignment.Right

    -- Instruction line
    local instr = Instance.new("TextLabel", card)
    instr.Size     = UDim2.new(1, -40, 0, 22)
    instr.Position = UDim2.new(0, 20, 0, 60)
    instr.BackgroundTransparency = 1
    instr.Text     = "Tap a word to place it  ·  tap a placed word to remove it"
    instr.TextColor3 = Color3.fromRGB(120, 115, 170)
    instr.Font     = Enum.Font.Gotham
    instr.TextSize = 13

    -- ── TRAY (sentence assembly area) ─────────────────────────────────────────
    local trayBg = Instance.new("Frame", card)
    trayBg.Name            = "TrayBg"
    trayBg.Size            = UDim2.new(1, -36, 0, 72)
    trayBg.Position        = UDim2.new(0, 18, 0, 90)
    trayBg.BackgroundColor3 = Color3.fromRGB(22, 18, 50)
    trayBg.BorderSizePixel = 0
    Instance.new("UICorner", trayBg).CornerRadius = UDim.new(0, 10)
    local trayStroke = Instance.new("UIStroke", trayBg)
    trayStroke.Color     = Color3.fromRGB(80, 100, 210)
    trayStroke.Thickness = 1.5

    local tray = Instance.new("ScrollingFrame", trayBg)
    tray.Name              = "Tray"
    tray.Size              = UDim2.new(1, 0, 1, 0)
    tray.BackgroundTransparency = 1
    tray.BorderSizePixel   = 0
    tray.ScrollBarThickness = 0
    tray.ScrollingDirection = Enum.ScrollingDirection.X
    tray.CanvasSize        = UDim2.new(0, 0, 1, 0)
    local trayLayout = Instance.new("UIListLayout", tray)
    trayLayout.FillDirection = Enum.FillDirection.Horizontal
    trayLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    trayLayout.Padding = UDim.new(0, 6)
    local trayPad = Instance.new("UIPadding", tray)
    trayPad.PaddingLeft = UDim.new(0, 8); trayPad.PaddingRight = UDim.new(0, 8)

    -- Placeholder text shown when tray is empty
    local trayHint = Instance.new("TextLabel", tray)
    trayHint.Name  = "Hint"
    trayHint.Size  = UDim2.new(0, 340, 1, 0)
    trayHint.BackgroundTransparency = 1
    trayHint.Text  = "Your sentence appears here…"
    trayHint.TextColor3 = Color3.fromRGB(60, 55, 100)
    trayHint.TextSize   = 13
    trayHint.Font       = Enum.Font.Gotham

    -- ── Divider label ──────────────────────────────────────────────────────────
    local divLbl = Instance.new("TextLabel", card)
    divLbl.Size     = UDim2.new(1, -40, 0, 22)
    divLbl.Position = UDim2.new(0, 20, 0, 170)
    divLbl.BackgroundTransparency = 1
    divLbl.Text     = "Word Bank"
    divLbl.TextColor3 = Color3.fromRGB(140, 130, 190)
    divLbl.Font     = Enum.Font.GothamSemibold
    divLbl.TextSize = 13
    divLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- ── BANK (word pool) ──────────────────────────────────────────────────────
    local bankBg = Instance.new("Frame", card)
    bankBg.Name            = "BankBg"
    bankBg.Size            = UDim2.new(1, -36, 0, 196)
    bankBg.Position        = UDim2.new(0, 18, 0, 196)
    bankBg.BackgroundColor3 = Color3.fromRGB(18, 14, 42)
    bankBg.BorderSizePixel = 0
    Instance.new("UICorner", bankBg).CornerRadius = UDim.new(0, 10)
    local bankStroke = Instance.new("UIStroke", bankBg)
    bankStroke.Color     = Color3.fromRGB(55, 65, 160)
    bankStroke.Thickness = 1.5

    local bank = Instance.new("ScrollingFrame", bankBg)
    bank.Name              = "Bank"
    bank.Size              = UDim2.new(1, 0, 1, 0)
    bank.BackgroundTransparency = 1
    bank.BorderSizePixel   = 0
    bank.ScrollBarThickness = 4
    bank.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 150)
    bank.ScrollingDirection = Enum.ScrollingDirection.Y
    bank.CanvasSize        = UDim2.new(0, 0, 0, 0)
    local bankGrid = Instance.new("UIGridLayout", bank)
    bankGrid.CellSize    = UDim2.new(0, 100, 0, 40)
    bankGrid.CellPadding = UDim2.new(0, 6, 0, 6)
    bankGrid.SortOrder   = Enum.SortOrder.LayoutOrder
    local bankPad = Instance.new("UIPadding", bank)
    bankPad.PaddingLeft = UDim.new(0, 8); bankPad.PaddingTop = UDim.new(0, 8)
    bankPad.PaddingRight = UDim.new(0, 8)

    -- ── Submit button ──────────────────────────────────────────────────────────
    local submitBtn = Instance.new("TextButton", card)
    submitBtn.Name   = "SubmitBtn"
    submitBtn.Size   = UDim2.new(0, 220, 0, 44)
    submitBtn.AnchorPoint = Vector2.new(0.5, 0)
    submitBtn.Position    = UDim2.new(0.5, 0, 0, 406)
    submitBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 230)
    submitBtn.BorderSizePixel  = 0
    submitBtn.Text   = "✓  Submit Answer"
    submitBtn.TextColor3 = Color3.fromRGB(230, 240, 255)
    submitBtn.Font   = Enum.Font.GothamBold
    submitBtn.TextSize = 16
    Instance.new("UICorner", submitBtn).CornerRadius = UDim.new(0, 12)

    -- ── Feedback label ─────────────────────────────────────────────────────────
    local feedback = Instance.new("TextLabel", card)
    feedback.Name  = "Feedback"
    feedback.Size  = UDim2.new(1, -40, 0, 30)
    feedback.Position = UDim2.new(0, 20, 0, 455)
    feedback.BackgroundTransparency = 1
    feedback.Text  = ""
    feedback.TextColor3 = Color3.fromRGB(200, 200, 255)
    feedback.Font  = Enum.Font.GothamSemibold
    feedback.TextSize = 15

    return screen, overlay, card, {
        roundLbl   = roundLbl,
        tray       = tray,
        trayHint   = trayHint,
        bank       = bank,
        bankGrid   = bankGrid,
        submitBtn  = submitBtn,
        feedback   = feedback,
    }
end

-- ── "Already done" screen ──────────────────────────────────────────────────────
local function showAlreadyDone()
    local s = Instance.new("ScreenGui", playerGui)
    s.Name = "JigsawDoneNotif"; s.ResetOnSpawn = false; s.IgnoreGuiInset = true
    local f = Instance.new("Frame", s)
    f.Size = UDim2.new(0, 340, 0, 60); f.AnchorPoint = Vector2.new(0.5, 0)
    f.Position = UDim2.new(0.5, 0, 0, -70)
    f.BackgroundColor3 = Color3.fromRGB(15, 12, 35); f.BackgroundTransparency = 0.1; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1,-16,1,0); l.Position = UDim2.new(0,8,0,0)
    l.BackgroundTransparency = 1; l.Text = "✦  Puzzle already solved — well done!"
    l.TextColor3 = Color3.fromRGB(180, 220, 255); l.Font = Enum.Font.GothamBold; l.TextSize = 15
    TweenService:Create(f, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,0,0,24)}):Play()
    task.delay(3, function()
        TweenService:Create(f, TweenInfo.new(0.4),{Position=UDim2.new(0.5,0,0,-70)}):Play()
        task.delay(0.5, function() s:Destroy() end)
    end)
end

-- ── Make a word tile ───────────────────────────────────────────────────────────
local function makeTile(parent, word, colorIdx, layoutOrder)
    local btn = Instance.new("TextButton", parent)
    btn.Size  = UDim2.new(0, 100, 0, 40)
    btn.BackgroundColor3 = tileColor(colorIdx)
    btn.BackgroundTransparency = 0.05
    btn.BorderSizePixel  = 0
    btn.Text = word
    btn.TextColor3 = Color3.fromRGB(240, 245, 255)
    btn.TextSize   = 14
    btn.Font       = Enum.Font.GothamSemibold
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.LayoutOrder  = layoutOrder or 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

-- ── Tray canvas width updater ─────────────────────────────────────────────────
local function updateTrayCanvas(tray)
    task.wait()   -- let layout compute first
    local w = 0
    for _, c in ipairs(tray:GetChildren()) do
        if c:IsA("TextButton") then w = w + c.AbsoluteSize.X + 6 end
    end
    tray.CanvasSize = UDim2.new(0, w + 16, 1, 0)
end

-- ── Shake animation ───────────────────────────────────────────────────────────
local function shake(frame)
    local orig = frame.Position
    for _ = 1, 3 do
        TweenService:Create(frame, TweenInfo.new(0.05), {Position = orig + UDim2.new(0, 7, 0, 0)}):Play()
        task.wait(0.05)
        TweenService:Create(frame, TweenInfo.new(0.05), {Position = orig - UDim2.new(0, 7, 0, 0)}):Play()
        task.wait(0.05)
    end
    frame.Position = orig
end

-- ── Main session ──────────────────────────────────────────────────────────────
local screen, overlay, card, refs = buildUI()

local trayWords = {}   -- { word, tile, originalIdx }
local bankTiles = {}   -- { word, tile, originalIdx }

local function clearAll()
    for _, item in ipairs(trayWords) do if item.tile and item.tile.Parent then item.tile:Destroy() end end
    for _, item in ipairs(bankTiles) do if item.tile and item.tile.Parent then item.tile:Destroy() end end
    trayWords = {}; bankTiles = {}
    refs.trayHint.Visible = true
    refs.feedback.Text = ""
end

local function populateBank(words)
    clearAll()
    for i, word in ipairs(words) do
        local tile = makeTile(refs.bank, word, i, i)
        local entry = { word = word, tile = tile, originalIdx = i }
        table.insert(bankTiles, entry)

        tile.MouseButton1Click:Connect(function()
            -- Move from bank → tray
            for bi = #bankTiles, 1, -1 do
                if bankTiles[bi].tile == tile then table.remove(bankTiles, bi); break end
            end
            tile.Parent = refs.tray
            table.insert(trayWords, entry)
            refs.trayHint.Visible = (#trayWords == 0)
            updateTrayCanvas(refs.tray)

            -- When in tray, clicking sends it back to bank
            local returnConn
            returnConn = tile.MouseButton1Click:Connect(function()
                returnConn:Disconnect()
                for ti = #trayWords, 1, -1 do
                    if trayWords[ti].tile == tile then table.remove(trayWords, ti); break end
                end
                tile.LayoutOrder = entry.originalIdx
                tile.Parent = refs.bank
                table.insert(bankTiles, entry)
                refs.trayHint.Visible = (#trayWords == 0)
                updateTrayCanvas(refs.tray)
                task.wait(); refs.bank.CanvasSize =
                    UDim2.new(0, 0, 0, refs.bankGrid.AbsoluteContentSize.Y + 20)
            end)
        end)
    end
    task.wait()
    refs.bank.CanvasSize = UDim2.new(0, 0, 0, refs.bankGrid.AbsoluteContentSize.Y + 20)
end

-- ── Receive round data ────────────────────────────────────────────────────────
JigsawRound.OnClientEvent:Connect(function(data)
    refs.roundLbl.Text = string.format("Round %d / %d", data.roundNumber, data.totalRounds)
    refs.submitBtn.Active = true
    refs.submitBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 230)
    refs.submitBtn.Text = "✓  Submit Answer"
    refs.feedback.Text  = ""
    populateBank(data.shuffledWords)
end)

-- ── Receive result ────────────────────────────────────────────────────────────
JigsawResult.OnClientEvent:Connect(function(data)
    refs.submitBtn.Active = true

    if data.correct then
        -- Green flash on tray tiles
        refs.feedback.Text      = "✦  Correct!  ✦"
        refs.feedback.TextColor3 = Color3.fromRGB(120, 255, 150)
        for _, item in ipairs(trayWords) do
            if item.tile and item.tile.Parent then
                TweenService:Create(item.tile, TweenInfo.new(0.3),
                    {BackgroundColor3 = Color3.fromRGB(50, 190, 90)}):Play()
            end
        end
    else
        -- Red flash + shake
        refs.feedback.Text      = "✦  Not quite — rearrange and try again  ✦"
        refs.feedback.TextColor3 = Color3.fromRGB(255, 120, 120)
        task.spawn(function() shake(refs.tray.Parent) end)
        for _, item in ipairs(trayWords) do
            if item.tile and item.tile.Parent then
                TweenService:Create(item.tile, TweenInfo.new(0.2),
                    {BackgroundColor3 = Color3.fromRGB(185, 50, 50)}):Play()
                task.wait(0.5)
                TweenService:Create(item.tile, TweenInfo.new(0.2),
                    {BackgroundColor3 = tileColor(item.originalIdx)}):Play()
            end
        end
    end
end)

-- ── All rounds complete ───────────────────────────────────────────────────────
JigsawDone.OnClientEvent:Connect(function()
    refs.feedback.Text      = "✦  Puzzle complete!  ✦"
    refs.feedback.TextColor3 = Color3.fromRGB(200, 190, 255)
    refs.submitBtn.Text      = "✦  Complete  ✦"
    task.wait(2)
    -- Fade out
    TweenService:Create(overlay, TweenInfo.new(1.2, Enum.EasingStyle.Quad),
        {BackgroundTransparency = 1}):Play()
    task.wait(1.3)
    screen.Enabled = false
end)

-- ── Submit button ─────────────────────────────────────────────────────────────
refs.submitBtn.MouseButton1Click:Connect(function()
    if #trayWords == 0 then
        refs.feedback.Text      = "Place some words first!"
        refs.feedback.TextColor3 = Color3.fromRGB(200, 180, 100)
        return
    end
    refs.submitBtn.Active = false
    refs.submitBtn.BackgroundColor3 = Color3.fromRGB(45, 80, 150)

    local parts = {}
    for _, item in ipairs(trayWords) do table.insert(parts, item.word) end
    JigsawSubmit:FireServer(table.concat(parts, " "))
end)

-- ── Entry point ───────────────────────────────────────────────────────────────
OpenJigsaw.OnClientEvent:Connect(function(alreadyDone)
    if alreadyDone then
        showAlreadyDone(); return
    end
    -- Reset overlay in case it was faded from a previous session
    overlay.BackgroundTransparency = 0.25
    screen.Enabled = true
end)

print("[JigsawUI] ready.")
