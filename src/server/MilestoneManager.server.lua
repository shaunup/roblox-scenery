--[[
  MilestoneManager.server.lua
  Handles milestone interactions and rewards:

    Milestone 1 – Breathing Zone
      • Detects player proximity via ProximityPrompt on BreathingTrigger
      • Fires OpenBreathing → client shows breathing exercise UI
      • Listens for BreathingComplete from client
      • Awards one floating lantern above the player (AwardLantern)

    Milestone 2 – Bonfire / Musician
      • Detects player proximity via ProximityPrompt on BonfireTrigger
      • Fires OpenMusicDialog → client shows genre selection UI
      • Listens for PlayMusic(player, genreKey) from client
      • Fires PlayMusic back to that player with the audio ID from MusicLibrary
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- Wait for scene folder to exist
local sceneFolder = Workspace:WaitForChild("TwilightTrail", 30)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local OpenBreathing    = Remotes:WaitForChild("OpenBreathing")
local BreathingComplete = Remotes:WaitForChild("BreathingComplete")
local AwardLantern     = Remotes:WaitForChild("AwardLantern")
local OpenMusicDialog  = Remotes:WaitForChild("OpenMusicDialog")
local PlayMusicRemote  = Remotes:WaitForChild("PlayMusic")

local MusicLibrary = require(ReplicatedStorage:WaitForChild("MusicLibrary"))

-- Track which milestones each player has completed
local breathingDone  = {}    -- [player] = bool
local musicPlaying   = {}    -- [player] = bool

-- ──────────────────────────────────────────────
-- Helper: spawn a floating reward lantern
-- ──────────────────────────────────────────────
local function spawnRewardLantern(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local lanternFolder = sceneFolder:FindFirstChild("RewardLanterns")
    if not lanternFolder then
        lanternFolder = Instance.new("Folder", sceneFolder)
        lanternFolder.Name = "RewardLanterns"
    end

    local pos = root.Position + Vector3.new(0, 6, 0)

    local body = Instance.new("Part", lanternFolder)
    body.Name          = "RewardLantern_" .. player.Name
    body.Shape         = Enum.PartType.Cylinder
    body.Size          = Vector3.new(1.6, 2.2, 1.6)
    body.CFrame        = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
    body.Anchored      = false
    body.Material      = Enum.Material.SmoothPlastic
    body.BrickColor    = BrickColor.new("Bright orange")
    body.Transparency  = 0.35
    body.CastShadow    = false
    body.TopSurface    = Enum.SurfaceType.Smooth
    body.BottomSurface = Enum.SurfaceType.Smooth

    local fire = Instance.new("Fire", body)
    fire.Heat           = 3
    fire.Size           = 0.6
    fire.Color          = Color3.fromRGB(255, 170, 40)
    fire.SecondaryColor = Color3.fromRGB(255, 80, 20)

    local glow = Instance.new("PointLight", body)
    glow.Color      = Color3.fromRGB(255, 195, 80)
    glow.Brightness = 4.5
    glow.Range      = 22
    glow.Shadows    = false

    -- Attach to a BodyVelocity so it rises on its own
    local bv = Instance.new("BodyVelocity", body)
    bv.Velocity         = Vector3.new(0, 3.5, 0)
    bv.MaxForce         = Vector3.new(0, 4000, 0)
    bv.P                = 1000

    -- Remove after 30 s (it will have floated away)
    task.delay(30, function()
        if body and body.Parent then body:Destroy() end
    end)

    -- Notify client for any local effects
    AwardLantern:FireClient(player)
end

-- ──────────────────────────────────────────────
-- MILESTONE 1 – Breathing Zone
-- ──────────────────────────────────────────────
local function setupBreathingZone()
    local trigger = sceneFolder:WaitForChild("BreathingTrigger", 30)
    if not trigger then
        warn("[MilestoneManager] BreathingTrigger not found")
        return
    end

    local prompt = Instance.new("ProximityPrompt", trigger)
    prompt.ActionText   = "Begin Breathing Exercise"
    prompt.ObjectText   = "Breathing Circle"
    prompt.MaxActivationDistance = 12
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Default

    prompt.Triggered:Connect(function(player)
        if breathingDone[player] then
            -- Already completed; just show a gentle message
            OpenBreathing:FireClient(player, true)   -- true = already done
            return
        end
        OpenBreathing:FireClient(player, false)
    end)

    -- Listen for completion signal from client
    BreathingComplete.OnServerEvent:Connect(function(player)
        if breathingDone[player] then return end
        breathingDone[player] = true
        spawnRewardLantern(player)
        print("[MilestoneManager] " .. player.Name .. " completed breathing exercise.")
    end)
end

-- ──────────────────────────────────────────────
-- MILESTONE 2 – Bonfire / Musician
-- ──────────────────────────────────────────────
local function setupBonfireZone()
    local trigger = sceneFolder:WaitForChild("BonfireTrigger", 30)
    if not trigger then
        warn("[MilestoneManager] BonfireTrigger not found")
        return
    end

    local prompt = Instance.new("ProximityPrompt", trigger)
    prompt.ActionText   = "Talk to the Musician"
    prompt.ObjectText   = "♪ The Musician"
    prompt.MaxActivationDistance = 14
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false

    prompt.Triggered:Connect(function(player)
        OpenMusicDialog:FireClient(player)
    end)

    -- Client sends back the chosen genre key
    PlayMusicRemote.OnServerEvent:Connect(function(player, genreKey)
        local audioId = MusicLibrary.getAudioId(genreKey)
        if audioId then
            -- Send the resolved audio ID back to ONLY this player
            PlayMusicRemote:FireClient(player, genreKey, audioId)
            musicPlaying[player] = genreKey
            print("[MilestoneManager] Playing '" .. genreKey .. "' for " .. player.Name)
        else
            warn("[MilestoneManager] Unknown genre: " .. tostring(genreKey))
        end
    end)
end

-- Clean up on player leave
Players.PlayerRemoving:Connect(function(player)
    breathingDone[player] = nil
    musicPlaying[player]  = nil
end)

-- ──────────────────────────────────────────────
-- INIT
-- ──────────────────────────────────────────────
task.spawn(setupBreathingZone)
task.spawn(setupBonfireZone)

print("[MilestoneManager] Ready.")
