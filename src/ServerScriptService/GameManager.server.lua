--[[
    GameManager.server.lua
    Manages game state, remote events, breathing rewards, and Gemini music fetch.

    Flow:
    1. Player spawns at origin, camera follow begins (client-side)
    2. Player walks the zigzag trail
    3. Touches BreathTrigger  → server fires BreathingStart remote to client
    4. Client completes breathing exercise → fires BreathingComplete to server
    5. Server awards lantern (adds LanternValue to player)
    6. Player reaches MusicianTrigger → server fires MusicianApproach
    7. Client submits music preference → fires MusicChoice to server
    8. Server calls Gemini API to search for a matching free audio asset ID
    9. Server fires PlayMusic with the resulting sound ID
    10. Player reaches ReleaseTrigger → server fires CanReleaseLantern
    11. Client releases lantern, physics sim plays out (client-side)
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local HttpService  = game:GetService("HttpService")
local Workspace    = game:GetService("Workspace")

-- ── Remote events setup ───────────────────────────────────────────────────────

local function makeRemote(name, isFunction)
    local existing = RS:FindFirstChild(name)
    if existing then return existing end
    local r
    if isFunction then
        r = Instance.new("RemoteFunction")
    else
        r = Instance.new("RemoteEvent")
    end
    r.Name   = name
    r.Parent = RS
    return r
end

local evBreathingStart    = makeRemote("BreathingStart")
local evBreathingComplete = makeRemote("BreathingComplete")
local evLanternAwarded    = makeRemote("LanternAwarded")
local evMusicianApproach  = makeRemote("MusicianApproach")
local evMusicChoice       = makeRemote("MusicChoice")
local evPlayMusic         = makeRemote("PlayMusic")
local evCanReleaseLantern = makeRemote("CanReleaseLantern")
local evReleaseLantern    = makeRemote("ReleaseLantern")

-- ── Player data ───────────────────────────────────────────────────────────────

local playerState = {}  -- [player] = { hasLantern, breathDone, musicDone, pondReached }

Players.PlayerAdded:Connect(function(player)
    playerState[player] = {
        hasLantern  = false,
        breathDone  = false,
        musicDone   = false,
        pondReached = false,
    }
    -- Store lantern count as leaderstats
    local ls = Instance.new("Folder")
    ls.Name   = "leaderstats"
    ls.Parent = player
    local lanternCount = Instance.new("IntValue")
    lanternCount.Name   = "Lanterns"
    lanternCount.Value  = 0
    lanternCount.Parent = ls
end)

Players.PlayerRemoving:Connect(function(player)
    playerState[player] = nil
end)

-- ── Trigger touch detection ───────────────────────────────────────────────────

local world      = Workspace:WaitForChild("LanternWorld")
local breathNode = world:WaitForChild("BreathingMilestone")
local bonfireNode= world:WaitForChild("Bonfire")
local pondNode   = world:WaitForChild("GlowPond")

local breathTrigger   = breathNode:WaitForChild("BreathTrigger")
local musicianTrigger = bonfireNode:WaitForChild("MusicianTrigger")
local releaseTrigger  = pondNode:WaitForChild("ReleaseTrigger")

local function getPlayerFromHit(hit)
    local char = hit.Parent
    if char then
        local p = Players:GetPlayerFromCharacter(char)
        return p
    end
    return nil
end

breathTrigger.Touched:Connect(function(hit)
    local player = getPlayerFromHit(hit)
    if not player then return end
    local state = playerState[player]
    if not state or state.breathDone then return end
    evBreathingStart:FireClient(player)
end)

musicianTrigger.Touched:Connect(function(hit)
    local player = getPlayerFromHit(hit)
    if not player then return end
    local state = playerState[player]
    if not state or state.musicDone then return end
    if not state.breathDone then return end  -- must complete breathing first
    evMusicianApproach:FireClient(player)
end)

releaseTrigger.Touched:Connect(function(hit)
    local player = getPlayerFromHit(hit)
    if not player then return end
    local state = playerState[player]
    if not state or state.pondReached then return end
    if not state.hasLantern then return end
    state.pondReached = true
    evCanReleaseLantern:FireClient(player)
end)

-- ── Breathing complete handler ────────────────────────────────────────────────

evBreathingComplete.OnServerEvent:Connect(function(player)
    local state = playerState[player]
    if not state or state.breathDone then return end
    state.breathDone  = true
    state.hasLantern  = true

    local ls = player:FindFirstChild("leaderstats")
    if ls then
        ls.Lanterns.Value = ls.Lanterns.Value + 1
    end

    evLanternAwarded:FireClient(player)
    print("[GameManager] Lantern awarded to", player.Name)
end)

-- ── Gemini music fetch ─────────────────────────────────────────────────────────
--[[
    GEMINI_API_KEY must be set as an environment variable / secret.
    We ask Gemini to suggest a Roblox free audio asset ID for the given mood.
    If the API is unavailable we fall back to a curated list.

    Gemini endpoint: https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent
]]

local GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or ""

local fallbackAudioIds = {
    calm        = "rbxassetid://1843734729",
    jazz        = "rbxassetid://142376088",
    classical   = "rbxassetid://1843734729",
    lofi        = "rbxassetid://142376088",
    ambient     = "rbxassetid://1843734729",
    upbeat      = "rbxassetid://142376088",
    default     = "rbxassetid://142376088",
}

local function normalizeMood(text)
    text = text:lower()
    if text:find("calm") or text:find("peace") or text:find("relax") then return "calm"
    elseif text:find("jazz") then return "jazz"
    elseif text:find("class") then return "classical"
    elseif text:find("lofi") or text:find("lo%-fi") then return "lofi"
    elseif text:find("ambient") then return "ambient"
    elseif text:find("upbeat") or text:find("happy") then return "upbeat"
    else return "default" end
end

local function geminiMusicSearch(mood)
    if GEMINI_API_KEY == "" then
        warn("[GameManager] GEMINI_API_KEY not set – using fallback audio.")
        local key = normalizeMood(mood)
        return fallbackAudioIds[key] or fallbackAudioIds["default"]
    end

    local url    = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=" .. GEMINI_API_KEY
    local prompt = string.format(
        "A Roblox player at a peaceful twilight lantern festival asks for %s music. "..
        "Reply with ONLY a valid Roblox free audio asset ID (digits only, no prefix) "..
        "that matches this mood from the Roblox audio library. "..
        "If unsure, reply with: 142376088",
        mood
    )

    local body = HttpService:JSONEncode({
        contents = {
            { parts = { { text = prompt } } }
        }
    })

    local ok, response = pcall(function()
        return HttpService:RequestAsync({
            Url    = url,
            Method = "POST",
            Headers= { ["Content-Type"] = "application/json" },
            Body   = body,
        })
    end)

    if not ok or not response or response.StatusCode ~= 200 then
        warn("[GameManager] Gemini API error – using fallback. Response:", response and response.StatusCode)
        local key = normalizeMood(mood)
        return fallbackAudioIds[key] or fallbackAudioIds["default"]
    end

    local decoded = HttpService:JSONDecode(response.Body)
    local text    = decoded
        and decoded.candidates
        and decoded.candidates[1]
        and decoded.candidates[1].content
        and decoded.candidates[1].content.parts
        and decoded.candidates[1].content.parts[1]
        and decoded.candidates[1].content.parts[1].text
        or ""

    -- Extract numeric asset id from response
    local assetId = text:match("%d%d%d%d%d+")
    if assetId then
        return "rbxassetid://" .. assetId
    end

    local key = normalizeMood(mood)
    return fallbackAudioIds[key] or fallbackAudioIds["default"]
end

-- ── Music choice handler ───────────────────────────────────────────────────────

evMusicChoice.OnServerEvent:Connect(function(player, moodText)
    local state = playerState[player]
    if not state or state.musicDone then return end
    state.musicDone = true

    print("[GameManager] Fetching Gemini music for mood:", moodText)
    local audioId = geminiMusicSearch(moodText)
    print("[GameManager] Playing audio:", audioId, "for", player.Name)
    evPlayMusic:FireClient(player, audioId, moodText)
end)

-- ── Lantern release handler ────────────────────────────────────────────────────

evReleaseLantern.OnServerEvent:Connect(function(player)
    local state = playerState[player]
    if not state then return end
    state.hasLantern = false
    print("[GameManager]", player.Name, "released their lantern!")
end)

print("[GameManager] Server ready.")
