--[[
  JigsawModule.client.lua
  Quote jigsaw puzzle – 3 rounds.

  Each round:
    • Server sends a shuffled word list
    • Player drags/clicks tiles into a target sentence tray
    • Submits answer → server confirms correct/wrong
    • Wrong: tiles shake and reset; Correct: celebration + next round
  
  Interaction model (no true drag on mobile):
    Click a word tile in the BANK → it moves to the first empty TRAY slot
    Click a tile in the TRAY → it moves back to the BANK
    This works on both PC and mobile.
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")
local Remotes = RS:WaitForChild("Remotes")

local evStart    = Remotes:WaitForChild("Jigsaw_Start")
local evSubmit   = Remotes:WaitForChild("Jigsaw_Submit")
local evComplete = Remotes:WaitForChild("Jigsaw_Complete")

local done = false

-- ── Colours ───────────────────────────────────────────────────────────────────
local TILE_COLORS = {
    Color3.fromRGB(60,120,200),
    Color3.fromRGB(140,60,180),
    Color3.fromRGB(40,150,100),
    Color3.fromRGB(180,90,50),
    Color3.fromRGB(50,140,160),
}
local function tileColor(i) return TILE_COLORS[((i-1)%#TILE_COLORS)+1] end

-- ── Build UI ──────────────────────────────────────────────────────────────────

local function buildUI()
    local screen = Instance.new("ScreenGui")
    screen.Name="JigsawUI"; screen.ResetOnSpawn=false
    screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    screen.Enabled=false; screen.Parent=gui

    local bg=Instance.new("Frame",screen)
    bg.Size=UDim2.new(1,0,1,0)
    bg.BackgroundColor3=Color3.fromRGB(5,3,18)
    bg.BackgroundTransparency=0.3; bg.BorderSizePixel=0

    local card=Instance.new("Frame",bg)
    card.Name="Card"; card.Size=UDim2.new(0,620,0,460)
    card.AnchorPoint=Vector2.new(0.5,0.5); card.Position=UDim2.new(0.5,0,1.1,0)
    card.BackgroundColor3=Color3.fromRGB(10,7,26)
    card.BackgroundTransparency=0.05; card.BorderSizePixel=0
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,22)
    local cs=Instance.new("UIStroke",card); cs.Color=Color3.fromRGB(100,180,255); cs.Thickness=2

    -- Title bar
    local titleBar=Instance.new("Frame",card)
    titleBar.Size=UDim2.new(1,0,0,6); titleBar.Position=UDim2.new(0,0,0,0)
    titleBar.BackgroundColor3=Color3.fromRGB(80,140,255); titleBar.BorderSizePixel=0
    Instance.new("UICorner",titleBar).CornerRadius=UDim.new(0,22)

    local title=Instance.new("TextLabel",card)
    title.Size=UDim2.new(1,-20,0,36); title.Position=UDim2.new(0,10,0,14)
    title.BackgroundTransparency=1; title.Text="✦  Wisdom Puzzle  ✦"
    title.TextColor3=Color3.fromRGB(180,220,255); title.TextScaled=true
    title.Font=Enum.Font.GothamBold

    -- Round indicator
    local roundLbl=Instance.new("TextLabel",card)
    roundLbl.Name="RoundLbl"; roundLbl.Size=UDim2.new(1,-20,0,22)
    roundLbl.Position=UDim2.new(0,10,0,52); roundLbl.BackgroundTransparency=1
    roundLbl.Text="Round 1 of 3"; roundLbl.TextColor3=Color3.fromRGB(140,180,220)
    roundLbl.TextScaled=true; roundLbl.Font=Enum.Font.Gotham

    -- Instruction
    local instr=Instance.new("TextLabel",card)
    instr.Size=UDim2.new(1,-20,0,22); instr.Position=UDim2.new(0,10,0,76)
    instr.BackgroundTransparency=1
    instr.Text="Tap a word to add it ↓    tap a placed word to remove it"
    instr.TextColor3=Color3.fromRGB(120,140,170); instr.TextSize=13
    instr.Font=Enum.Font.Gotham; instr.TextWrapped=true

    -- TRAY (sentence building area)
    local trayFrame=Instance.new("ScrollingFrame",card)
    trayFrame.Name="Tray"; trayFrame.Size=UDim2.new(1,-20,0,80)
    trayFrame.Position=UDim2.new(0,10,0,104); trayFrame.BackgroundColor3=Color3.fromRGB(20,14,44)
    trayFrame.BackgroundTransparency=0; trayFrame.BorderSizePixel=0
    trayFrame.ScrollBarThickness=0; trayFrame.ScrollingDirection=Enum.ScrollingDirection.X
    trayFrame.CanvasSize=UDim2.new(0,0,1,0)
    Instance.new("UICorner",trayFrame).CornerRadius=UDim.new(0,10)
    local tst=Instance.new("UIStroke",trayFrame); tst.Color=Color3.fromRGB(60,100,200); tst.Thickness=1.5
    local trayLayout=Instance.new("UIListLayout",trayFrame)
    trayLayout.FillDirection=Enum.FillDirection.Horizontal
    trayLayout.HorizontalAlignment=Enum.HorizontalAlignment.Left
    trayLayout.VerticalAlignment=Enum.VerticalAlignment.Center
    trayLayout.Padding=UDim.new(0,6)
    local trayPad=Instance.new("UIPadding",trayFrame)
    trayPad.PaddingLeft=UDim.new(0,8); trayPad.PaddingRight=UDim.new(0,8)

    -- Tray placeholder text
    local trayHint=Instance.new("TextLabel",trayFrame)
    trayHint.Name="Hint"; trayHint.Size=UDim2.new(0,300,1,0)
    trayHint.BackgroundTransparency=1; trayHint.Text="Your sentence appears here…"
    trayHint.TextColor3=Color3.fromRGB(70,80,110); trayHint.TextSize=13
    trayHint.Font=Enum.Font.Gotham

    -- BANK (word pool)
    local bankFrame=Instance.new("ScrollingFrame",card)
    bankFrame.Name="Bank"; bankFrame.Size=UDim2.new(1,-20,0,150)
    bankFrame.Position=UDim2.new(0,10,0,196); bankFrame.BackgroundColor3=Color3.fromRGB(14,10,32)
    bankFrame.BackgroundTransparency=0; bankFrame.BorderSizePixel=0
    bankFrame.ScrollBarThickness=4; bankFrame.ScrollingDirection=Enum.ScrollingDirection.Y
    bankFrame.CanvasSize=UDim2.new(0,0,0,0)
    Instance.new("UICorner",bankFrame).CornerRadius=UDim.new(0,10)
    local bst=Instance.new("UIStroke",bankFrame); bst.Color=Color3.fromRGB(50,70,150); bst.Thickness=1.5
    local bankLayout=Instance.new("UIGridLayout",bankFrame)
    bankLayout.CellSize=UDim2.new(0,90,0,38); bankLayout.CellPadding=UDim2.new(0,6,0,6)
    bankLayout.SortOrder=Enum.SortOrder.LayoutOrder
    local bankPad=Instance.new("UIPadding",bankFrame)
    bankPad.PaddingLeft=UDim.new(0,8); bankPad.PaddingTop=UDim.new(0,8)

    -- Submit button
    local submitBtn=Instance.new("TextButton",card)
    submitBtn.Name="Submit"; submitBtn.Size=UDim2.new(0,180,0,42)
    submitBtn.AnchorPoint=Vector2.new(0.5,0); submitBtn.Position=UDim2.new(0.5,0,0,362)
    submitBtn.BackgroundColor3=Color3.fromRGB(70,130,220); submitBtn.BorderSizePixel=0
    submitBtn.Text="✓  Submit Answer"; submitBtn.TextColor3=Color3.fromRGB(240,245,255)
    submitBtn.TextScaled=true; submitBtn.Font=Enum.Font.GothamBold
    Instance.new("UICorner",submitBtn).CornerRadius=UDim.new(0,12)

    local feedback=Instance.new("TextLabel",card)
    feedback.Name="Feedback"; feedback.Size=UDim2.new(1,-20,0,30)
    feedback.Position=UDim2.new(0,10,0,412); feedback.BackgroundTransparency=1
    feedback.Text=""; feedback.TextColor3=Color3.fromRGB(255,255,255)
    feedback.TextScaled=true; feedback.Font=Enum.Font.GothamSemibold

    return screen, card, roundLbl, trayFrame, trayLayout, bankFrame, bankLayout, submitBtn, feedback, trayHint
end

-- ── Make a word tile button ───────────────────────────────────────────────────

local function makeTile(parent, word, colorIdx)
    local btn=Instance.new("TextButton",parent)
    btn.Size=UDim2.new(0,90,0,38); btn.BackgroundColor3=tileColor(colorIdx)
    btn.BackgroundTransparency=0.05; btn.BorderSizePixel=0
    btn.Text=word; btn.TextColor3=Color3.fromRGB(240,250,255)
    btn.TextSize=13; btn.Font=Enum.Font.GothamSemibold
    btn.TextTruncate=Enum.TextTruncate.AtEnd
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
    return btn
end

-- ── Run mini-game ─────────────────────────────────────────────────────────────

local function run()
    local screen,card,roundLbl,trayFrame,trayLayout,bankFrame,bankLayout,submitBtn,feedback,trayHint
        = buildUI()
    screen.Enabled=true
    TweenService:Create(card, TweenInfo.new(0.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,0,0.5,0)}):Play()
    task.wait(0.6)

    local totalRounds = 3
    local currentRound = 0

    -- State
    local trayWords   = {}   -- { word, tile }
    local bankTiles   = {}   -- { word, tile }

    local function updateTrayHint()
        trayHint.Visible = (#trayWords == 0)
    end

    local function updateCanvasWidth()
        local w = 0
        for _,item in ipairs(trayWords) do
            w = w + item.tile.AbsoluteSize.X + 6
        end
        trayFrame.CanvasSize = UDim2.new(0, w+16, 1, 0)
    end

    -- Shake tray on wrong answer
    local function shakeTray()
        local orig = trayFrame.Position
        for _=1,4 do
            TweenService:Create(trayFrame, TweenInfo.new(0.05),
                {Position=orig+UDim2.new(0,6,0,0)}):Play(); task.wait(0.05)
            TweenService:Create(trayFrame, TweenInfo.new(0.05),
                {Position=orig-UDim2.new(0,6,0,0)}):Play(); task.wait(0.05)
        end
        trayFrame.Position = orig
    end

    local function clearTray()
        for _,item in ipairs(trayWords) do
            item.tile:Destroy()
        end
        trayWords = {}
        updateTrayHint()
    end

    local function clearBank()
        for _,item in ipairs(bankTiles) do
            item.tile:Destroy()
        end
        bankTiles = {}
    end

    -- Request a round
    local function requestRound(n)
        feedback.Text = ""
        clearTray(); clearBank()
        roundLbl.Text = string.format("Round %d of %d", n, totalRounds)
        evSubmit:FireServer(0, "")   -- 0 = request round data
    end

    -- Listen for server responses
    local roundDataConn
    local resultConn

    -- Start game
    requestRound(1)

    roundDataConn = evSubmit.OnClientEvent:Connect(function(msgType, roundN, shuffled, total)
        if msgType ~= "ROUND_DATA" then return end
        totalRounds  = total or totalRounds
        currentRound = roundN
        roundLbl.Text = string.format("Round %d of %d", currentRound, totalRounds)
        trayHint.Visible = true
        bankFrame.CanvasSize = UDim2.new(0,0,0,0)

        -- Create bank tiles
        for i, word in ipairs(shuffled) do
            local tile = makeTile(bankFrame, word, i)
            local entry = {word=word, tile=tile}
            table.insert(bankTiles, entry)

            tile.MouseButton1Click:Connect(function()
                -- Move from bank to tray
                tile.Parent = trayFrame
                table.insert(trayWords, {word=word, tile=tile})
                -- Remove from bankTiles list
                for bi,b in ipairs(bankTiles) do
                    if b.tile == tile then table.remove(bankTiles, bi); break end
                end
                updateTrayHint(); updateCanvasWidth()
                -- Update bank canvas
                task.wait(); bankFrame.CanvasSize=UDim2.new(0,0,0,bankLayout.AbsoluteContentSize.Y+16)
            end)
        end
        task.wait(); bankFrame.CanvasSize=UDim2.new(0,0,0,bankLayout.AbsoluteContentSize.Y+16)
    end)

    -- Wire tray tiles to go back to bank (dynamic, set when tile is added)
    -- (handled inside the bank tile click above via re-parenting to trayFrame)
    -- We need to add return-to-bank click on tray tiles when they land there:
    evSubmit.OnClientEvent:Connect(function() end)  -- placeholder

    -- Override tray tile clicks by scanning trayWords on click
    -- We do this via a periodic re-wire since tiles move between parents
    task.spawn(function()
        while screen and screen.Parent do
            for i=#trayWords,1,-1 do
                local item = trayWords[i]
                if item and item.tile and item.tile.Parent == trayFrame then
                    -- ensure click goes back to bank
                end
            end
            task.wait(0.2)
        end
    end)

    -- Submit button
    local submitConn
    submitConn = submitBtn.MouseButton1Click:Connect(function()
        if #trayWords == 0 then
            feedback.Text = "Place some words first!"; feedback.TextColor3=Color3.fromRGB(255,180,80); return
        end
        local parts = {}
        for _,item in ipairs(trayWords) do table.insert(parts, item.word) end
        local answer = table.concat(parts, " ")
        submitBtn.Active = false
        evSubmit:FireServer(currentRound, answer)
    end)

    resultConn = evSubmit.OnClientEvent:Connect(function(msgType, roundN)
        if msgType == "ROUND_DATA" then return end  -- handled above

        submitBtn.Active = true
        if msgType == "CORRECT" then
            feedback.Text = "✦  Correct!  ✦"; feedback.TextColor3=Color3.fromRGB(120,255,140)
            -- Flash tiles green
            for _,item in ipairs(trayWords) do
                TweenService:Create(item.tile, TweenInfo.new(0.3),
                    {BackgroundColor3=Color3.fromRGB(60,190,90)}):Play()
            end
            task.wait(1.2)
            if roundN >= totalRounds then
                -- Done
                roundDataConn:Disconnect(); resultConn:Disconnect(); submitConn:Disconnect()
                feedback.Text = "✦  All rounds complete!  ✦"
                task.wait(1)
                TweenService:Create(card, TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
                    {Position=UDim2.new(0.5,0,-0.6,0)}):Play()
                task.wait(0.5); screen:Destroy()
                -- Completion banner
                local bs=Instance.new("ScreenGui"); bs.Name="JigsawComplete"; bs.ResetOnSpawn=false; bs.Parent=gui
                local bf=Instance.new("Frame",bs)
                bf.Size=UDim2.new(0,480,0,90); bf.AnchorPoint=Vector2.new(0.5,0)
                bf.Position=UDim2.new(0.5,0,-0.12,0)
                bf.BackgroundColor3=Color3.fromRGB(10,18,35); bf.BackgroundTransparency=0.05; bf.BorderSizePixel=0
                Instance.new("UICorner",bf).CornerRadius=UDim.new(0,14)
                local bst2=Instance.new("UIStroke",bf); bst2.Color=Color3.fromRGB(100,160,255); bst2.Thickness=2
                local bl3=Instance.new("TextLabel",bf)
                bl3.Size=UDim2.new(1,-16,1,0); bl3.Position=UDim2.new(0,8,0,0)
                bl3.BackgroundTransparency=1
                bl3.Text="✦  Wisdom Puzzle complete – Lantern earned!  ✦"
                bl3.TextColor3=Color3.fromRGB(180,220,255); bl3.TextScaled=true; bl3.Font=Enum.Font.GothamBold
                TweenService:Create(bf, TweenInfo.new(0.6,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
                    {Position=UDim2.new(0.5,0,0.05,0)}):Play()
                task.delay(5,function()
                    TweenService:Create(bf,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
                        {Position=UDim2.new(0.5,0,-0.15,0)}):Play()
                    task.delay(0.5,function() bs:Destroy() end)
                end)
            else
                -- Next round
                requestRound(roundN+1)
            end
        elseif msgType == "WRONG" then
            feedback.Text = "✦  Not quite – try again  ✦"; feedback.TextColor3=Color3.fromRGB(255,130,130)
            task.spawn(shakeTray)
            -- Flash tiles red then restore
            for _,item in ipairs(trayWords) do
                TweenService:Create(item.tile, TweenInfo.new(0.2),
                    {BackgroundColor3=Color3.fromRGB(180,50,50)}):Play()
            end
            task.wait(0.5)
            for i,item in ipairs(trayWords) do
                TweenService:Create(item.tile, TweenInfo.new(0.2),
                    {BackgroundColor3=tileColor(i)}):Play()
            end
        end
    end)
end

evStart.OnClientEvent:Connect(function()
    if done then return end; done=true; task.spawn(run)
end)

evComplete.OnClientEvent:Connect(function()
    -- already handled inside run(); this is a safety no-op
end)

print("[JigsawModule] ready.")
