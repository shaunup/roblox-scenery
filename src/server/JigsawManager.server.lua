--[[
  JigsawManager.server.lua
  ─────────────────────────────────────────────────────────────────────────────
  Builds the Wisdom Puzzle station at JIGSAW_POS, wires a ProximityPrompt,
  and owns all server-side logic:

    • Sends shuffled word list for each round to the client
    • Validates submitted answers (answer keys never leave the server)
    • Awards a reward lantern on completion (same AwardLantern remote)

  Remote protocol  (all via RS/Remotes):
    OpenJigsaw   S→C          : open the UI (alreadyDone bool)
    JigsawRound  S→C          : { roundNumber, totalRounds, shuffledWords }
    JigsawSubmit C→S  (answer): player submits assembled sentence
    JigsawResult S→C          : { correct bool, roundNumber }
    JigsawDone   S→C          : all rounds complete
    AwardLantern S→C          : reuses existing remote
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- ═══════════════════════════════════════════════════════════════
--  POSITION – change this one line to move the whole station
local JIGSAW_POS = Vector3.new(24.791, 4.375, -20.5)
-- ═══════════════════════════════════════════════════════════════

-- ── Remotes ───────────────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function getOrMake(name)
    return Remotes:FindFirstChild(name) or Instance.new("RemoteEvent", Remotes) and Remotes[name]
    -- safer version:
end
local function ensureRemote(name)
    local r = Remotes:FindFirstChild(name)
    if r then return r end
    r = Instance.new("RemoteEvent", Remotes)
    r.Name = name
    return r
end

local OpenJigsaw   = ensureRemote("OpenJigsaw")
local JigsawRound  = ensureRemote("JigsawRound")
local JigsawSubmit = ensureRemote("JigsawSubmit")
local JigsawResult = ensureRemote("JigsawResult")
local JigsawDone   = ensureRemote("JigsawDone")
local AwardLantern = Remotes:WaitForChild("AwardLantern")

-- ── Puzzle data (answer keys server-side only) ────────────────────────────────
local ROUNDS = {
    {
        words  = { "Gratitude", "turns", "what", "we", "have", "into", "enough." },
        answer = "Gratitude turns what we have into enough.",
    },
    {
        words  = { "In", "every", "difficulty", "lies", "an", "opportunity." },
        answer = "In every difficulty lies an opportunity.",
    },
    {
        words  = { "The", "present", "moment", "is", "the", "only", "home." },
        answer = "The present moment is the only home.",
    },
}

-- ── Per-player state ──────────────────────────────────────────────────────────
local jigsawDone  = {}   -- [player] = bool
local jigsawRound = {}   -- [player] = number (last round completed, 0 = none)

Players.PlayerRemoving:Connect(function(p)
    jigsawDone[p]  = nil
    jigsawRound[p] = nil
end)

-- ── Scene folder ──────────────────────────────────────────────────────────────
local sceneFolder = Workspace:WaitForChild("TwilightTrail", 30)

-- ── 3-D prop helpers ─────────────────────────────────────────────────────────
local function makePart(parent, props)
    local p = Instance.new("Part")
    for k, v in pairs(props) do p[k] = v end
    p.Anchored      = true
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent        = parent
    return p
end

local function addLight(part, brightness, range, color)
    local l = Instance.new("PointLight", part)
    l.Brightness = brightness; l.Range = range; l.Color = color; l.Shadows = false
end

local function addBillboard(part, text, textColor, offset)
    local bg  = Instance.new("BillboardGui", part)
    bg.Size        = UDim2.new(0, 300, 0, 55)
    bg.StudsOffset = offset or Vector3.new(0, 3, 0)
    bg.AlwaysOnTop = false
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = textColor or Color3.fromRGB(255,240,200)
    lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold
end

-- ── Build station ─────────────────────────────────────────────────────────────
local function buildStation()
    local f = Instance.new("Folder", sceneFolder)
    f.Name  = "JigsawStation"
    local p = JIGSAW_POS

    -- Reading table (stone slab on four legs)
    makePart(f, {
        Name="TableTop", Size=Vector3.new(7, 0.35, 3.2),
        CFrame=CFrame.new(p + Vector3.new(0, 2.0, 0)),
        BrickColor=BrickColor.new("Medium stone grey"), Material=Enum.Material.SmoothPlastic,
    })
    for _, lx in ipairs({-2.8, 2.8}) do
        for _, lz in ipairs({-1.1, 1.1}) do
            makePart(f, {
                Name="TableLeg", Size=Vector3.new(0.3, 2.0, 0.3),
                CFrame=CFrame.new(p + Vector3.new(lx, 1.0, lz)),
                BrickColor=BrickColor.new("Medium stone grey"), Material=Enum.Material.SmoothPlastic,
            })
        end
    end

    -- Glowing puzzle tablet on the table surface
    local tablet = makePart(f, {
        Name="Tablet", Size=Vector3.new(6.4, 0.1, 2.6),
        CFrame=CFrame.new(p + Vector3.new(0, 2.22, 0)),
        BrickColor=BrickColor.new("Bright blue"),
        Material=Enum.Material.Neon, CanCollide=false, Transparency=0.5,
    })
    addLight(tablet, 0.7, 16, Color3.fromRGB(120, 190, 255))
    -- addBillboard(tablet, "✦  Wisdom Puzzle  ✦", Color3.fromRGB(190, 225, 255), Vector3.new(0, 4.5, 0))

    -- Two stone benches either side
    for _, bx in ipairs({-5.5, 5.5}) do
        makePart(f, {
            Name="BenchSeat", Size=Vector3.new(2.8, 0.3, 1.1),
            CFrame=CFrame.new(p + Vector3.new(bx, 1.1, 0)),
            BrickColor=BrickColor.new("Light stone grey"), Material=Enum.Material.SmoothPlastic,
        })
        makePart(f, {
            Name="BenchBase", Size=Vector3.new(2.4, 1.0, 0.22),
            CFrame=CFrame.new(p + Vector3.new(bx, 0.6, 0.32)),
            BrickColor=BrickColor.new("Light stone grey"), Material=Enum.Material.SmoothPlastic,
        })
    end

    -- Small hanging lanterns on two thin posts flanking the table
    for _, px in ipairs({-4.2, 4.2}) do
        makePart(f, {
            Name="Post", Size=Vector3.new(0.25, 3.8, 0.25),
            CFrame=CFrame.new(p + Vector3.new(px, 2.0, -1.8)),
            BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
        })
        local hang = makePart(f, {
            Name="HangLantern", Size=Vector3.new(0.7, 1.0, 0.7),
            CFrame=CFrame.new(p + Vector3.new(px, 4.1, -1.8)),
            BrickColor=BrickColor.new("Bright orange"),
            Material=Enum.Material.Neon, CanCollide=false, Transparency=0.25,
        })
        addLight(hang, 1.0, 14, Color3.fromRGB(255, 200, 80))
    end

    -- Firefly sparkles
    for i = 1, 5 do
        local a  = (i / 5) * math.pi * 2
        local fp = p + Vector3.new(math.cos(a) * 7, 2.5, math.sin(a) * 6)
        local sp = makePart(f, {
            Name="Firefly"..i, Size=Vector3.new(0.28, 0.28, 0.28),
            CFrame=CFrame.new(fp), BrickColor=BrickColor.new("Bright yellow"),
            Material=Enum.Material.Neon, CanCollide=false, CastShadow=false, Transparency=0.25,
        })
        sp.Shape = Enum.PartType.Ball
        addLight(sp, 0.32, 9, Color3.fromRGB(220, 255, 120))
    end

    -- Invisible ProximityPrompt trigger (just in front of the table)
    local trigger = makePart(f, {
        Name="JigsawTrigger", Size=Vector3.new(1, 1, 1),
        CFrame=CFrame.new(p + Vector3.new(0, 1.5, 3.5)),
        BrickColor=BrickColor.new("Bright blue"),
        Material=Enum.Material.Neon, CanCollide=false, Transparency=1,
    })
    local prompt = Instance.new("ProximityPrompt", trigger)
    prompt.ActionText            = "Attempt the Puzzle"
    prompt.ObjectText            = "✦ Wisdom Puzzle"
    prompt.MaxActivationDistance = 14
    prompt.HoldDuration          = 0
    prompt.RequiresLineOfSight   = false
    prompt.Style                 = Enum.ProximityPromptStyle.Default

    return prompt
end

-- ── Fisher-Yates shuffle (seeded so server and client stay in sync) ───────────
local function shuffle(list)
    local t = {}
    for i, v in ipairs(list) do t[i] = v end
    local rng = Random.new()
    for i = #t, 2, -1 do
        local j = rng:NextInteger(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- ── Send the next round to the client ────────────────────────────────────────
local function sendRound(player, roundNum)
    local rd = ROUNDS[roundNum]
    if not rd then return end
    JigsawRound:FireClient(player, {
        roundNumber  = roundNum,
        totalRounds  = #ROUNDS,
        shuffledWords = shuffle(rd.words),
    })
end

-- ── Wire the prompt ───────────────────────────────────────────────────────────
local prompt = buildStation()

prompt.Triggered:Connect(function(player)
    if jigsawDone[player] then
        OpenJigsaw:FireClient(player, true)  -- alreadyDone
        return
    end
    jigsawRound[player] = jigsawRound[player] or 0
    OpenJigsaw:FireClient(player, false)
    -- Send round 1 immediately
    sendRound(player, 1)
end)

-- ── Validate submission ───────────────────────────────────────────────────────
JigsawSubmit.OnServerEvent:Connect(function(player, submittedAnswer)
    if jigsawDone[player] then return end
    if type(submittedAnswer) ~= "string" then return end

    local currentRound = (jigsawRound[player] or 0) + 1
    if currentRound > #ROUNDS then return end

    local correct = (submittedAnswer == ROUNDS[currentRound].answer)
    JigsawResult:FireClient(player, { correct = correct, roundNumber = currentRound })

    if correct then
        jigsawRound[player] = currentRound
        if currentRound >= #ROUNDS then
            jigsawDone[player] = true
            JigsawDone:FireClient(player)
            AwardLantern:FireClient(player)
            print("[JigsawManager] " .. player.Name .. " completed the Wisdom Puzzle.")
        else
            -- Slight delay then send next round
            task.delay(1.2, function()
                if player and player.Parent then
                    sendRound(player, currentRound + 1)
                end
            end)
        end
    end
end)

-- ── Clean up on leave ─────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(p)
    jigsawDone[p]  = nil
    jigsawRound[p] = nil
end)

print("[JigsawManager] Wisdom Puzzle built at", JIGSAW_POS, "– ready.")
