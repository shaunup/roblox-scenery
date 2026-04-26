--[[
  GardenManager.server.lua
  Builds the Gratitude Garden at the exact world position supplied,
  wires a ProximityPrompt, and handles server-side logic:
    • Validates each gratitude submission (echoes plot index back to client)
    • Awards a reward lantern on completion (same pattern as BreathingZone)

  Integrates with the existing TwilightTrail scene and Remotes folder.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService")

-- ═══════════════════════════════════════════════════════════════
--  POSITION – change this to move the entire garden
local GARDEN_POS = Vector3.new(-0.463, 7.75, -102.296)
-- ═══════════════════════════════════════════════════════════════

-- ── Remotes (re-use existing folder, add garden remotes) ─────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getOrMake(name)
    local existing = Remotes:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new("RemoteEvent", Remotes)
    r.Name = name
    return r
end

local OpenGarden     = getOrMake("OpenGarden")       -- S → C : open the garden UI
local GardenFlower   = getOrMake("GardenFlower")     -- C → S : text;  S → C : plotIdx
local GardenComplete = getOrMake("GardenComplete")   -- C → S : all 3 done
local AwardLantern   = Remotes:WaitForChild("AwardLantern")

-- ── Scene folder (must already exist, created by ScenerySetup) ───────────────
local sceneFolder = Workspace:WaitForChild("TwilightTrail", 30)

-- ── Per-player state ──────────────────────────────────────────────────────────
local gardenDone  = {}   -- [player] = bool
local gardenPlot  = {}   -- [player] = 0..3  (flowers planted so far)

Players.PlayerRemoving:Connect(function(p)
    gardenDone[p] = nil
    gardenPlot[p] = nil
end)

-- ── Garden plot positions stored in ReplicatedStorage ────────────────────────
-- The client reads these to know where to grow flowers.
local plotsFolder = Instance.new("Folder", ReplicatedStorage)
plotsFolder.Name  = "GardenPlots"

-- Bed offsets relative to GARDEN_POS (centre discs of the 3 beds)
local BED_OFFSETS = {
    Vector3.new(-6,  0.65, -2),   -- left bed
    Vector3.new( 0,  0.65, -5),   -- middle bed
    Vector3.new( 6,  0.65, -2),   -- right bed
}
for i, off in ipairs(BED_OFFSETS) do
    local v = Instance.new("Vector3Value", plotsFolder)
    v.Name  = tostring(i)
    v.Value = GARDEN_POS + off
end

-- ── 3-D prop builder ──────────────────────────────────────────────────────────

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
    return l
end

local function buildGarden()
    local f  = Instance.new("Folder", sceneFolder)
    f.Name   = "GratitudeGarden"
    local pos = GARDEN_POS

    -- Soft grass clearing
    makePart(f, {
        Name="GardenGround", Size=Vector3.new(28, 0.3, 24),
        CFrame=CFrame.new(pos + Vector3.new(0, -0.45, 0)),
        BrickColor=BrickColor.new("Bright green"), Material=Enum.Material.Grass,
    })

    -- Wooden entrance arch
    for _, ox in ipairs({-3.2, 3.2}) do
        makePart(f, {
            Name="ArchPost", Size=Vector3.new(0.7, 7, 0.7),
            CFrame=CFrame.new(pos + Vector3.new(ox, 3.5, 5)),
            BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
        })
    end
    local archTop = makePart(f, {
        Name="ArchTop", Size=Vector3.new(8, 0.7, 0.7),
        CFrame=CFrame.new(pos + Vector3.new(0, 7.2, 5)),
        BrickColor=BrickColor.new("Reddish brown"), Material=Enum.Material.Wood,
    })
    -- Warm string-light strip along arch
    local strLight = makePart(f, {
        Name="StringLight", Size=Vector3.new(7.6, 0.18, 0.18),
        CFrame=CFrame.new(pos + Vector3.new(0, 6.85, 5)),
        BrickColor=BrickColor.new("Bright yellow"), Material=Enum.Material.Neon,
        CanCollide=false, CastShadow=false, Transparency=0.1,
    })
    addLight(strLight, 0.65, 16, Color3.fromRGB(255, 220, 130))

    -- Billboard sign on arch
    local bg = Instance.new("BillboardGui", archTop)
    bg.Size        = UDim2.new(0, 280, 0, 60)
    bg.StudsOffset = Vector3.new(0, 2.5, 0)
    bg.AlwaysOnTop = false
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = "🌸  Garden of Gratitude  🌸"
    lbl.TextColor3 = Color3.fromRGB(255, 220, 180)
    lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold

    -- 3 raised garden beds
    local bedColors = { "Reddish brown", "Reddish brown", "Reddish brown" }
    for bi, boff in ipairs(BED_OFFSETS) do
        local bp = pos + boff
        -- Frame
        makePart(f, {
            Name="BedFrame"..bi, Size=Vector3.new(8, 0.75, 3.8),
            CFrame=CFrame.new(bp + Vector3.new(0, 0.1, 0)),
            BrickColor=BrickColor.new(bedColors[bi]), Material=Enum.Material.Wood,
        })
        -- Soil
        makePart(f, {
            Name="BedSoil"..bi, Size=Vector3.new(7.2, 0.28, 3.1),
            CFrame=CFrame.new(bp + Vector3.new(0, 0.5, 0)),
            BrickColor=BrickColor.new("Brown"), Material=Enum.Material.Ground,
        })
        -- Pink neon glow strip along front edge
        local glow = makePart(f, {
            Name="BedGlow"..bi, Size=Vector3.new(7.4, 0.1, 0.1),
            CFrame=CFrame.new(bp + Vector3.new(0, 0.55, 1.9)),
            BrickColor=BrickColor.new("Hot pink"), Material=Enum.Material.Neon,
            CanCollide=false, CastShadow=false, Transparency=0.3,
        })
        addLight(glow, 0.4, 9, Color3.fromRGB(255, 160, 220))

        -- 3 plot discs per bed
        for pi = 1, 3 do
            local t    = (pi - 1) / 2 - 0.5
            local disc = makePart(f, {
                Name="PlotDisc"..((bi-1)*3+pi),
                Size=Vector3.new(0.12, 1.3, 1.3),
                CFrame=CFrame.new(bp + Vector3.new(t * 5.5, 0.65, 0))
                     * CFrame.Angles(0, 0, math.pi/2),
                BrickColor=BrickColor.new("Light stone grey"),
                Material=Enum.Material.SmoothPlastic, CanCollide=false,
            })
            disc.Shape = Enum.PartType.Cylinder
        end
    end

    -- Fairy lights around perimeter
    for i = 1, 6 do
        local a  = (i / 6) * math.pi * 2
        local fp = pos + Vector3.new(math.cos(a) * 11, 2.4, math.sin(a) * 9 - 2)
        local sp = makePart(f, {
            Name="Fairy"..i, Size=Vector3.new(0.32, 0.32, 0.32),
            CFrame=CFrame.new(fp),
            BrickColor=BrickColor.new("Bright yellow"), Material=Enum.Material.Neon,
            CanCollide=false, CastShadow=false, Transparency=0.2,
        })
        sp.Shape = Enum.PartType.Ball
        addLight(sp, 0.38, 10, Color3.fromRGB(255, 230, 140))
    end

    -- ProximityPrompt trigger part (invisible)
    local trigger = makePart(f, {
        Name="GardenTrigger",
        Size=Vector3.new(1, 1, 1),
        CFrame=CFrame.new(pos + Vector3.new(0, 1, 5)),   -- at the arch entrance
        BrickColor=BrickColor.new("Bright green"),
        Material=Enum.Material.Neon,
        CanCollide=false, CastShadow=false, Transparency=1,
    })

    local prompt = Instance.new("ProximityPrompt", trigger)
    prompt.ActionText              = "Begin Gratitude Garden"
    prompt.ObjectText              = "🌸 Garden of Gratitude"
    prompt.MaxActivationDistance   = 14
    prompt.HoldDuration            = 0
    prompt.RequiresLineOfSight     = false
    prompt.Style                   = Enum.ProximityPromptStyle.Default

    return prompt
end

-- ── Wire the ProximityPrompt ──────────────────────────────────────────────────

local prompt = buildGarden()

prompt.Triggered:Connect(function(player)
    if gardenDone[player] then
        -- Already done – soft re-open with done flag so UI can show a nice message
        OpenGarden:FireClient(player, true)
        return
    end
    gardenPlot[player] = gardenPlot[player] or 0
    OpenGarden:FireClient(player, false)
end)

-- ── Flower submission ─────────────────────────────────────────────────────────

GardenFlower.OnServerEvent:Connect(function(player, text)
    if gardenDone[player] then return end
    if type(text) ~= "string" or #text:gsub("%s+", "") < 2 then return end
    gardenPlot[player] = (gardenPlot[player] or 0)
    if gardenPlot[player] >= 3 then return end

    gardenPlot[player] = gardenPlot[player] + 1
    -- Echo the plot index (1, 2, or 3) back to the client so it knows which disc to bloom
    GardenFlower:FireClient(player, gardenPlot[player])
    print(string.format("[GardenManager] %s planted flower %d", player.Name, gardenPlot[player]))
end)

-- ── Completion ────────────────────────────────────────────────────────────────

GardenComplete.OnServerEvent:Connect(function(player)
    if gardenDone[player] then return end
    if (gardenPlot[player] or 0) < 3 then return end
    gardenDone[player] = true
    -- Reuse the existing AwardLantern remote so the same toast appears
    AwardLantern:FireClient(player)
    print("[GardenManager] " .. player.Name .. " completed the Gratitude Garden.")
end)

print("[GardenManager] Garden built at", GARDEN_POS, "– ready.")
