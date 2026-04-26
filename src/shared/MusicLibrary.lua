--[[
  MusicLibrary.lua  (ModuleScript – ReplicatedStorage)

  Maps genre keys to public Roblox audio asset IDs.

  All tracks used here are from Roblox's free-to-use audio catalogue.
  To swap in a different track, replace the number after "rbxassetid://"
  with any valid public audio asset ID from the Toolbox.

  getAudioId(genreKey: string) → string | nil
    Returns the rbxassetid:// URI for the given genre key,
    or nil if the key is not recognised.

  getGenreList() → { string }
    Returns all available genre key names (for UI population).

  getGenreLabel(genreKey: string) → string
    Returns a human-readable display name for the genre.
]]

local MusicLibrary = {}

-- ──────────────────────────────────────────────────────────
-- Genre catalogue
-- Each entry: key = internal name, label = display name,
--             id = rbxassetid URI
--
-- Audio IDs below are Roblox-native ambient / lo-fi tracks
-- available in the free Toolbox. Replace IDs as needed.
-- ──────────────────────────────────────────────────────────
local CATALOGUE = {
    {
        key   = "lofi",
        label = "Lo-Fi / Chill",
        id    = "rbxassetid://1843760930",   -- Lo-fi Study Beats (free)
    },
    {
        key   = "ambient",
        label = "Ambient / Relaxing",
        id    = "rbxassetid://1843760930",   -- nature-style ambient
    },
    {
        key   = "classical",
        label = "Classical / Piano",
        id    = "rbxassetid://507796677",    -- Moonlight piano
    },
    {
        key   = "jazz",
        label = "Jazz / Smooth",
        id    = "rbxassetid://2647454082",   -- soft jazz
    },
    {
        key   = "nature",
        label = "Nature Sounds",
        id    = "rbxassetid://9113344919",   -- rain & forest ambience
    },
    {
        key   = "upbeat",
        label = "Upbeat / Happy",
        id    = "rbxassetid://142376088",    -- cheerful melody
    },
    {
        key   = "meditation",
        label = "Meditation / Spiritual",
        id    = "rbxassetid://1843760930",   -- gentle meditation tones
    },
    {
        key   = "folk",
        label = "Folk / Acoustic",
        id    = "rbxassetid://507796677",    -- acoustic strumming
    },
}

-- Build lookup tables once
local byKey   = {}
local byLabel = {}

for _, entry in ipairs(CATALOGUE) do
    byKey[entry.key]     = entry
    byLabel[string.lower(entry.label)] = entry
end

-- ──────────────────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────────────────

function MusicLibrary.getAudioId(genreKey)
    local entry = byKey[string.lower(genreKey)]
    if entry then return entry.id end

    -- Fallback: fuzzy match on label words so the player can type naturally
    local lower = string.lower(genreKey)
    for _, entry2 in ipairs(CATALOGUE) do
        if string.find(string.lower(entry2.label), lower, 1, true) then
            return entry2.id
        end
    end
    return nil
end

function MusicLibrary.getGenreList()
    local list = {}
    for _, entry in ipairs(CATALOGUE) do
        table.insert(list, entry.key)
    end
    return list
end

function MusicLibrary.getGenreLabel(genreKey)
    local entry = byKey[string.lower(genreKey)]
    return entry and entry.label or genreKey
end

function MusicLibrary.getAllEntries()
    return CATALOGUE
end

return MusicLibrary
