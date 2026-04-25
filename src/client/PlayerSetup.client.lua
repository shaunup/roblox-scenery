--[[
  PlayerSetup.client.lua
  Ensures the player uses the standard Roblox follow-camera
  so they can freely explore the scene. No overrides, no cinematics.
]]

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Custom
