--[[
    CameraFollow.client.lua
    Provides a cinematic third-person camera that:
    - Smoothly follows the player with a slight lag
    - Maintains a scenic offset (behind + above) suitable for the twilight world
    - Allows mouse-drag orbit around the character
    - Auto-returns to default angle when idle
]]

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player   = Players.LocalPlayer
local camera   = workspace.CurrentCamera

-- Disable default camera script
local playerModule = player.PlayerScripts:WaitForChild("PlayerModule", 10)
if playerModule then
    -- Override camera type to Scriptable so we have full control
end

local CAMERA_OFFSET   = Vector3.new(0, 14, 20)   -- distance behind & above
local SMOOTH_FACTOR   = 0.08                       -- lerp speed (lower = smoother lag)
local ORBIT_SPEED     = 0.4                        -- degrees per pixel drag
local AUTO_RETURN_DELAY = 3                        -- seconds idle before camera returns
local FOV_DEFAULT     = 68
local FOV_RELEASE     = 80                         -- wider FOV for lantern release moment

camera.FieldOfView = FOV_DEFAULT
camera.CameraType  = Enum.CameraType.Scriptable

-- Internal state
local yaw     = 0    -- horizontal orbit angle (degrees)
local pitch   = 20   -- vertical look-down angle (degrees)
local isDragging  = false
local lastMousePos = Vector2.new()
local idleTimer   = 0
local targetCFrame = CFrame.new()
local currentCFrame= CFrame.new()

-- Store the "wide" FOV request when releasing lantern
local RS = game:GetService("ReplicatedStorage")
RS:WaitForChild("CanReleaseLantern", 60)
if RS:FindFirstChild("CanReleaseLantern") then
    RS.CanReleaseLantern.OnClientEvent:Connect(function()
        TweenService:Create(camera, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { FieldOfView = FOV_RELEASE }):Play()
    end)
end

-- Mouse input for orbit
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isDragging   = true
        lastMousePos = UserInputService:GetMouseLocation()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isDragging = false
        idleTimer  = 0
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
        local mousePos = UserInputService:GetMouseLocation()
        local delta    = mousePos - lastMousePos
        lastMousePos   = mousePos
        yaw   = yaw   - delta.X * ORBIT_SPEED
        pitch = math.clamp(pitch + delta.Y * ORBIT_SPEED * 0.6, 5, 55)
        idleTimer = 0
    end
end)

-- Mobile: touch drag
local touchStartPos = Vector2.new()
local touchDragging = false
UserInputService.TouchStarted:Connect(function(touch)
    touchStartPos = Vector2.new(touch.Position.X, touch.Position.Y)
    touchDragging = true
    idleTimer = 0
end)
UserInputService.TouchMoved:Connect(function(touch)
    if not touchDragging then return end
    local pos   = Vector2.new(touch.Position.X, touch.Position.Y)
    local delta = pos - touchStartPos
    touchStartPos = pos
    yaw   = yaw   - delta.X * ORBIT_SPEED * 0.5
    pitch = math.clamp(pitch + delta.Y * ORBIT_SPEED * 0.3, 5, 55)
    idleTimer = 0
end)
UserInputService.TouchEnded:Connect(function()
    touchDragging = false
end)

-- Main update loop
RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Auto-return yaw to 0 (behind player) when idle
    idleTimer = idleTimer + dt
    if idleTimer > AUTO_RETURN_DELAY then
        yaw   = yaw   + (0   - yaw)   * math.min(dt * 1.5, 1)
        pitch = pitch + (20  - pitch) * math.min(dt * 1.5, 1)
    end

    -- Build orbit rotation
    local orbitCF = CFrame.new(root.Position)
        * CFrame.Angles(0, math.rad(yaw), 0)
        * CFrame.Angles(math.rad(-pitch), 0, 0)

    -- Apply offset in orbit space
    local offsetCF = orbitCF * CFrame.new(0, 0, CAMERA_OFFSET.Z)
        + Vector3.new(0, CAMERA_OFFSET.Y * 0.5, 0)

    -- Point camera at root (slightly above)
    local lookTarget = root.Position + Vector3.new(0, 3, 0)
    targetCFrame = CFrame.lookAt(offsetCF.Position, lookTarget)

    -- Smooth lerp current to target
    currentCFrame = currentCFrame:Lerp(targetCFrame, math.min(SMOOTH_FACTOR + dt * 2, 1))
    camera.CFrame  = currentCFrame
end)

print("[CameraFollow] Cinematic camera active.")
