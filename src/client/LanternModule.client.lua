--[[
  LanternModule.client.lua
  Lantern release from the dock ledge over the lake.

  • Shows a "Release" button when player is on the platform and has lanterns
  • Spawns one paper lantern Part per lantern owned
  • Each rises with gentle sway + sparkle trail
  • Wide-FOV cinematic camera zoom during release
  • Journey Complete card on finish
]]

local Players        = game:GetService("Players")
local RS             = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local Workspace      = game:GetService("Workspace")
local RunService     = game:GetService("RunService")

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")
local camera  = Workspace.CurrentCamera
local Remotes = RS:WaitForChild("Remotes")

local evStart   = Remotes:WaitForChild("Lantern_Start")
local evRelease = Remotes:WaitForChild("Lantern_Release")
local evCount   = Remotes:WaitForChild("Global_LanternCount")

local promptShown = false
local lanternCount = 0

-- Track count from server
evCount.OnClientEvent:Connect(function(n)
    lanternCount = n
end)

-- ── Lantern 3-D ───────────────────────────────────────────────────────────────

local lanternFolder = Instance.new("Folder",Workspace)
lanternFolder.Name  = "ReleasedLanterns"

local function launchLantern(spawnPos, palette)
    local bodyColor  = palette[1]
    local glowColor  = palette[2]

    local model = Instance.new("Model",lanternFolder)
    model.Name  = "Lantern"

    local body = Instance.new("Part",model)
    body.Size=Vector3.new(1.8,2.8,1.8); body.CFrame=CFrame.new(spawnPos)
    body.Anchored=true; body.CanCollide=false; body.CastShadow=false
    body.Material=Enum.Material.Neon; body.Color=bodyColor; body.Transparency=0.18

    local pl=Instance.new("PointLight",body)
    pl.Color=glowColor; pl.Brightness=2.2; pl.Range=25

    local flame=Instance.new("Part",model)
    flame.Size=Vector3.new(0.7,0.7,0.7); flame.Shape=Enum.PartType.Ball
    flame.CFrame=CFrame.new(spawnPos); flame.Anchored=true; flame.CanCollide=false; flame.CastShadow=false
    flame.Material=Enum.Material.Neon; flame.Color=Color3.fromRGB(255,220,80); flame.Transparency=0.2

    local trail=Instance.new("Folder",model); trail.Name="Trail"
    local trailParts={}

    local startTime=tick(); local totalTime=16
    local swayAmp=1.6; local swaySpeed=1.1
    local sideOffset=Vector3.new(math.random(-3,3)*0.5, 0, math.random(-3,3)*0.5)

    local conn
    conn=RunService.Heartbeat:Connect(function()
        local t=tick()-startTime
        if t>totalTime then
            conn:Disconnect()
            task.delay(0.5,function() model:Destroy() end)
            return
        end

        local rise  = t*13
        local swayX = math.sin(t*swaySpeed)*swayAmp + sideOffset.X
        local swayZ = math.cos(t*swaySpeed*0.8)*swayAmp*0.5 + sideOffset.Z
        local newPos = spawnPos+Vector3.new(swayX, rise, swayZ)

        body.CFrame  = CFrame.new(newPos)
        flame.CFrame = CFrame.new(newPos+Vector3.new(0,-0.6,0))

        -- Sparkle trail
        if math.floor(t*10)%3==0 then
            local sp=Instance.new("Part",trail)
            sp.Size=Vector3.new(0.25,0.25,0.25); sp.Shape=Enum.PartType.Ball
            sp.CFrame=CFrame.new(newPos+Vector3.new(math.random(-5,5)/10,-0.8,math.random(-5,5)/10))
            sp.Anchored=true; sp.CanCollide=false; sp.CastShadow=false
            sp.Material=Enum.Material.Neon; sp.Color=glowColor; sp.Transparency=0.25
            table.insert(trailParts,sp)
            if #trailParts>10 then
                local old=table.remove(trailParts,1)
                TweenService:Create(old,TweenInfo.new(0.35),{Transparency=1,Size=Vector3.new(0.05,0.05,0.05)}):Play()
                task.delay(0.4,function() if old then old:Destroy() end end)
            end
        end

        -- Fade as it rises high
        local progress = t/totalTime
        body.Transparency  = math.min(0.18 + progress*0.82, 1)
        flame.Transparency = math.min(0.2  + progress*0.8,  1)
        pl.Brightness      = math.max(2.2  - progress*2.2,  0)
    end)
end

-- ── UI ────────────────────────────────────────────────────────────────────────

local function buildReleaseBtn()
    local screen=Instance.new("ScreenGui")
    screen.Name="LanternReleaseUI"; screen.ResetOnSpawn=false; screen.Enabled=false; screen.Parent=gui

    local btn=Instance.new("TextButton",screen)
    btn.Name="ReleaseBtn"; btn.Size=UDim2.new(0,290,0,62)
    btn.AnchorPoint=Vector2.new(0.5,1); btn.Position=UDim2.new(0.5,0,0.88,0)
    btn.BackgroundColor3=Color3.fromRGB(255,200,50)
    btn.BackgroundTransparency=0.05; btn.BorderSizePixel=0
    btn.Text="🏮  Release Your Lanterns"; btn.TextColor3=Color3.fromRGB(40,20,0)
    btn.TextScaled=true; btn.Font=Enum.Font.GothamBold
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,16)
    local bs=Instance.new("UIStroke",btn); bs.Color=Color3.fromRGB(200,140,0); bs.Thickness=2.5

    -- Pulse tween
    local ti=TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true)
    TweenService:Create(btn,ti,{BackgroundColor3=Color3.fromRGB(255,230,120)}):Play()

    return screen, btn
end

local function showJourneyComplete()
    local screen=Instance.new("ScreenGui"); screen.Name="JourneyComplete"; screen.ResetOnSpawn=false; screen.Parent=gui
    local ov=Instance.new("Frame",screen)
    ov.Size=UDim2.new(1,0,1,0); ov.BackgroundColor3=Color3.fromRGB(4,2,14); ov.BackgroundTransparency=1; ov.BorderSizePixel=0
    TweenService:Create(ov,TweenInfo.new(1.8,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{BackgroundTransparency=0.22}):Play()
    task.wait(1)

    local card=Instance.new("Frame",ov)
    card.Size=UDim2.new(0,480,0,320); card.AnchorPoint=Vector2.new(0.5,0.5)
    card.Position=UDim2.new(0.5,0,0.9,0)
    card.BackgroundColor3=Color3.fromRGB(12,7,30); card.BackgroundTransparency=0.06; card.BorderSizePixel=0
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,20)
    local cs=Instance.new("UIStroke",card); cs.Color=Color3.fromRGB(255,200,80); cs.Thickness=2

    local e=Instance.new("TextLabel",card)
    e.Size=UDim2.new(1,0,0,70); e.Position=UDim2.new(0,0,0.02,0)
    e.BackgroundTransparency=1; e.Text="🏮"; e.TextScaled=true

    local t1=Instance.new("TextLabel",card)
    t1.Size=UDim2.new(1,-20,0,52); t1.Position=UDim2.new(0,10,0.28,0)
    t1.BackgroundTransparency=1; t1.Text="Your lanterns rise into the night"
    t1.TextColor3=Color3.fromRGB(255,228,120); t1.TextScaled=true
    t1.Font=Enum.Font.GothamBold; t1.TextWrapped=true

    local t2=Instance.new("TextLabel",card)
    t2.Size=UDim2.new(1,-30,0,70); t2.Position=UDim2.new(0,15,0.55,0)
    t2.BackgroundTransparency=1
    t2.Text="May your wishes travel far on the twilight breeze.\nThank you for walking this path tonight."
    t2.TextColor3=Color3.fromRGB(190,200,230); t2.TextSize=15; t2.Font=Enum.Font.Gotham
    t2.TextWrapped=true; t2.TextXAlignment=Enum.TextXAlignment.Center

    TweenService:Create(card,TweenInfo.new(1.1,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,0,0.5,0)}):Play()
end

-- ── Lantern palette table ─────────────────────────────────────────────────────

local LANTERN_PALETTES = {
    {Color3.fromRGB(255,200,50),  Color3.fromRGB(255,220,100)},
    {Color3.fromRGB(255,120,40),  Color3.fromRGB(255,180,80)},
    {Color3.fromRGB(200,80,220),  Color3.fromRGB(230,160,255)},
    {Color3.fromRGB(50,200,240),  Color3.fromRGB(150,230,255)},
    {Color3.fromRGB(80,220,120),  Color3.fromRGB(180,255,200)},
}
local function getPalette(i) return LANTERN_PALETTES[((i-1)%#LANTERN_PALETTES)+1] end

-- ── Main logic ────────────────────────────────────────────────────────────────

local releaseScreen, releaseBtn

local function handleStart()
    if promptShown then return end
    promptShown = true

    releaseScreen, releaseBtn = buildReleaseBtn()
    releaseScreen.Enabled = true

    releaseBtn.MouseButton1Click:Connect(function()
        if lanternCount < 1 then return end
        releaseScreen.Enabled = false
        evRelease:FireServer()

        -- Widen FOV for cinematic feel
        TweenService:Create(camera, TweenInfo.new(1.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            {FieldOfView=80}):Play()

        -- Spawn one lantern per earned lantern (up to 5)
        local char  = player.Character
        local root  = char and char:FindFirstChild("HumanoidRootPart")
        local baseP = root and root.Position or Vector3.new(0,2,0)
        local count = math.min(lanternCount, 5)

        for i=1,count do
            local offset = Vector3.new((i-1)*2.5 - (count-1)*1.25, i*0.4, 0)
            task.delay((i-1)*0.4, function()
                launchLantern(baseP+offset+Vector3.new(0,3,0), getPalette(i))
            end)
        end

        task.delay(3, function()
            showJourneyComplete()
        end)
    end)
end

evStart.OnClientEvent:Connect(handleStart)

print("[LanternModule] ready.")
