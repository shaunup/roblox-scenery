--[[
  LightingSetup.server.lua
  Applies twilight sky, atmosphere, and post-processing.
  Does NOT touch Terrain – your map stays exactly as you built it.
]]

local Lighting = game:GetService("Lighting")

-- Clear any auto-added effects first (so re-running doesn't stack)
for _, child in ipairs(Lighting:GetChildren()) do
    if child:IsA("Sky") or child:IsA("Atmosphere")
    or child:IsA("BloomEffect") or child:IsA("ColorCorrectionEffect")
    or child:IsA("BlurEffect") then
        child:Destroy()
    end
end

-- Twilight timing
Lighting.ClockTime          = 19.8      -- just after sunset, moon rising
Lighting.GeographicLatitude = 35
Lighting.Brightness         = 0.55
Lighting.GlobalShadows      = true
Lighting.Ambient            = Color3.fromRGB(28, 20, 50)
Lighting.OutdoorAmbient     = Color3.fromRGB(40, 30, 70)
Lighting.FogColor           = Color3.fromRGB(30, 20, 55)
Lighting.FogStart           = 300
Lighting.FogEnd             = 800

-- Night sky – lots of stars, large moon
local sky         = Instance.new("Sky", Lighting)
sky.StarCount     = 6000
sky.MoonAngularSize = 16
sky.SunAngularSize  = 5

-- Thin twilight atmosphere (preserves stars, adds purple-orange depth)
local atmo        = Instance.new("Atmosphere", Lighting)
atmo.Density      = 0.22
atmo.Offset       = 0.08
atmo.Color        = Color3.fromRGB(160, 80, 50)   -- warm horizon
atmo.Decay        = Color3.fromRGB(60, 40, 100)   -- cool zenith
atmo.Glare        = 0.04
atmo.Haze         = 0.6

-- Colour correction: cool-tinted night with warm highlights
local cc          = Instance.new("ColorCorrectionEffect", Lighting)
cc.Saturation     = 0.10
cc.Contrast       = 0.14
cc.Brightness     = -0.05
cc.TintColor      = Color3.fromRGB(210, 215, 255)

-- Bloom: gentle – makes lanterns and neon glow pop without blowing out
local bloom       = Instance.new("BloomEffect", Lighting)
bloom.Intensity   = 0.65
bloom.Size        = 26
bloom.Threshold   = 0.93

print("[LightingSetup] Twilight lighting applied.")
