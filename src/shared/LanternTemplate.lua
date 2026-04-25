--[[
  LanternTemplate.lua  (ModuleScript – ReplicatedStorage)
  Shared constants and colour palette for lanterns.
  Both server and (optionally) client visual effects can reference this.
]]

local LanternTemplate = {}

-- Available lantern body colours (cycling randomly per lantern)
LanternTemplate.BodyColours = {
    Color3.fromRGB(255, 200,  80),   -- warm gold
    Color3.fromRGB(255, 140,  50),   -- deep amber
    Color3.fromRGB(230, 100,  60),   -- terracotta
    Color3.fromRGB(255, 220, 110),   -- pale yellow
    Color3.fromRGB(200, 160, 255),   -- lavender (rare)
    Color3.fromRGB(180, 230, 255),   -- ice blue  (rare)
}

-- Glow colours matching each body colour
LanternTemplate.GlowColours = {
    Color3.fromRGB(255, 210, 100),
    Color3.fromRGB(255, 170,  70),
    Color3.fromRGB(255, 130,  60),
    Color3.fromRGB(255, 235, 130),
    Color3.fromRGB(210, 160, 255),
    Color3.fromRGB(160, 220, 255),
}

LanternTemplate.DefaultRiseSpeed  = 4.5
LanternTemplate.DefaultDriftAmp   = 1.8
LanternTemplate.DefaultSpinSpeed  = 0.18   -- rad/s
LanternTemplate.GlowBrightness    = 4.5
LanternTemplate.GlowRange         = 22
LanternTemplate.BodyTransparency  = 0.35
LanternTemplate.ResetAltitude     = 350    -- studs above origin before respawning

return LanternTemplate
