--[[
  CameraScript.client.lua
  Standard follow-camera: the camera always tracks the player character.
  CameraType.Custom hands full control to Roblox's built-in follow camera,
  which supports mouse/touch orbit, zoom, and all default controls.
]]

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Custom
