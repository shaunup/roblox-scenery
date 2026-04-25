--[[
  CameraScript.client.lua
  Sets a cinematic default camera angle so players open the scene
  looking across the valley toward the mountains with lanterns rising.

  The camera starts in a gentle orbit pan to showcase the scenery.
  Once the player moves / clicks, standard Roblox camera takes over.
]]

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Initial cinematic camera position (slightly above the platform, looking at mountains)
local ORBIT_RADIUS  = 80
local ORBIT_HEIGHT  = 35
local ORBIT_SPEED   = 0.045   -- radians per second
local LOOK_TARGET   = Vector3.new(0, 40, -120)  -- mountains in the distance

local angle         = math.rad(200)  -- start from behind the platform
local cinematic     = true

local function updateCamera(dt)
    if not cinematic then return end

    angle = angle + ORBIT_SPEED * dt

    local camX = math.cos(angle) * ORBIT_RADIUS
    local camZ = math.sin(angle) * ORBIT_RADIUS
    local camPos = Vector3.new(camX, ORBIT_HEIGHT, camZ)

    camera.CFrame = CFrame.lookAt(camPos, LOOK_TARGET)
end

-- Exit cinematic mode on any player input
local function exitCinematic()
    if not cinematic then return end
    cinematic = false
    camera.CameraType = Enum.CameraType.Custom

    -- Smoothly tween back to the character before handing off
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local targetCF = CFrame.new(rootPart.Position + Vector3.new(0, 5, 10),
                                    rootPart.Position)
        local tween = TweenService:Create(camera, TweenInfo.new(1.2, Enum.EasingStyle.Quad,
                                           Enum.EasingDirection.Out), { CFrame = targetCF })
        tween:Play()
        tween.Completed:Connect(function()
            camera.CameraType = Enum.CameraType.Custom
        end)
    end
end

UserInputService.InputBegan:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.Keyboard
    or t == Enum.UserInputType.MouseButton1
    or t == Enum.UserInputType.Touch then
        exitCinematic()
    end
end)

-- Also exit if player character moves (e.g. controller)
local humanoid = character:FindFirstChildOfClass("Humanoid")
if humanoid then
    humanoid.Running:Connect(function(speed)
        if speed > 0.5 then exitCinematic() end
    end)
end

RunService.RenderStepped:Connect(updateCamera)
