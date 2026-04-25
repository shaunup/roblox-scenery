--[[
    GameConfig.lua
    Shared constants read by both server and client scripts.
]]

local GameConfig = {
    -- Trail waypoint indices
    BREATHING_WAYPOINT = 5,
    BONFIRE_WAYPOINT   = 8,
    POND_WAYPOINT      = 11,

    -- Breathing exercise
    BREATHING_CYCLES   = 4,
    INHALE_SECONDS     = 4,
    HOLD_SECONDS       = 2,
    EXHALE_SECONDS     = 5,

    -- Lantern
    LANTERN_RISE_SPEED = 14,   -- studs per second
    LANTERN_SWAY_AMP   = 1.8,  -- studs sideways sway
    LANTERN_SWAY_SPEED = 1.2,  -- radians per second

    -- Camera
    CAMERA_OFFSET = Vector3.new(0, 14, 20),
    CAMERA_SMOOTH = 0.08,
    CAMERA_FOV    = 68,
    CAMERA_FOV_RELEASE = 80,

    -- Lighting
    CLOCK_TIME    = 19.5,      -- twilight
    STAR_COUNT    = 4000,

    -- Gemini
    GEMINI_MODEL  = "gemini-pro",
    GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent",

    -- Fallback audio IDs (Roblox free library)
    FALLBACK_AUDIO = {
        calm      = "rbxassetid://1843734729",
        jazz      = "rbxassetid://142376088",
        classical = "rbxassetid://1843734729",
        lofi      = "rbxassetid://142376088",
        ambient   = "rbxassetid://1843734729",
        upbeat    = "rbxassetid://142376088",
        default   = "rbxassetid://142376088",
    },
}

return GameConfig
