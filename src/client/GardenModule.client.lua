--[[
  GardenModule.client.lua
  3-round gratitude flower planting.
  Each round: player writes gratitude → flower grows in 3-D at plot position.
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")

-- Bail out immediately if this module is disabled in ModuleConfig
local enabledFolder = RS:WaitForChild("EnabledModules", 10)
if not enabledFolder or not (enabledFolder:WaitForChild("Garden", 5)).Value then
    return
end

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")
local Remotes = RS:WaitForChild("Remotes")

local evStart     = Remotes:WaitForChild("Garden_Start")
local evFlower    = Remotes:WaitForChild("Garden_Flower")
local evComplete  = Remotes:WaitForChild("Garden_Complete")
-- GardenPlots is only created by the server when Garden is enabled,
-- so this WaitForChild is now safe (module is confirmed enabled above)
local plotsFolder = RS:WaitForChild("GardenPlots", 30)

local done = false

local PALETTES = {
    {Color3.fromRGB(255,190,50),  Color3.fromRGB(255,230,110), Color3.fromRGB(255,210,70) },
    {Color3.fromRGB(215,75,200),  Color3.fromRGB(255,160,240), Color3.fromRGB(195,95,220) },
    {Color3.fromRGB(70,200,115),  Color3.fromRGB(155,255,180), Color3.fromRGB(55,220,120) },
}
local NAMES   = {"Golden Sunbloom","Violet Dreamflower","Emerald Wishbloom"}
local PROMPTS = {
    "Someone showed you kindness recently.\nWhat made it meaningful to you?",
    "What small moment today made you feel\nalive or grateful?",
    "Name one simple thing — a sound, a feeling,\na view — that you treasure.",
}

-- ── 3-D flower ────────────────────────────────────────────────────────────────

local flowersFolder = Instance.new("Folder",Workspace)
flowersFolder.Name  = "GardenFlowers"

local function getPlotPos(plotIdx)
    -- Use centre plots of each bed: beds have indices 1-3/4-6/7-9; centres are 2,5,8
    local centres = {"2","5","8"}
    local v = plotsFolder and plotsFolder:FindFirstChild(centres[plotIdx])
    return v and v.Value or Vector3.new(0,2,0)
end

local function growFlower(plotIdx, palette)
    local pos = getPlotPos(plotIdx)
    local bloom, petal = palette[1], palette[2]
    local SH = 2.6   -- stem height

    -- Stem
    local stem = Instance.new("Part",flowersFolder)
    stem.Size=Vector3.new(0.18,0.001,0.18); stem.CFrame=CFrame.new(pos)
    stem.Anchored=true; stem.CanCollide=false; stem.CastShadow=false
    stem.Material=Enum.Material.SmoothPlastic
    stem.Color=Color3.fromRGB(45,140,55)
    stem.TopSurface=Enum.SurfaceType.Smooth; stem.BottomSurface=Enum.SurfaceType.Smooth

    TweenService:Create(stem, TweenInfo.new(0.9,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Size=Vector3.new(0.18,SH,0.18), CFrame=CFrame.new(pos+Vector3.new(0,SH/2,0))}):Play()
    task.wait(0.8)

    -- Bloom
    local bl = Instance.new("Part",flowersFolder)
    bl.Shape=Enum.PartType.Ball; bl.Size=Vector3.new(0.01,0.01,0.01)
    bl.CFrame=CFrame.new(pos+Vector3.new(0,SH,0))
    bl.Anchored=true; bl.CanCollide=false; bl.CastShadow=false
    bl.Material=Enum.Material.Neon; bl.Color=bloom; bl.Transparency=0.05
    TweenService:Create(bl, TweenInfo.new(0.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Size=Vector3.new(1,1,1)}):Play()
    local pl=Instance.new("PointLight",bl)
    pl.Color=palette[3]; pl.Brightness=0.75; pl.Range=10
    task.wait(0.3)

    -- Petals
    for p=1,5 do
        local a  = (p/5)*math.pi*2
        local pp = Instance.new("Part",flowersFolder)
        pp.Shape=Enum.PartType.Ball; pp.Size=Vector3.new(0.01,0.01,0.01)
        pp.CFrame=CFrame.new(pos+Vector3.new(0,SH,0))
        pp.Anchored=true; pp.CanCollide=false; pp.CastShadow=false
        pp.Material=Enum.Material.Neon; pp.Color=petal; pp.Transparency=0.15
        local tx = math.cos(a)*0.8; local tz = math.sin(a)*0.8
        TweenService:Create(pp, TweenInfo.new(0.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Size=Vector3.new(0.55,0.28,0.55), CFrame=CFrame.new(pos+Vector3.new(tx,SH+0.1,tz))}):Play()
    end
    task.wait(0.6)

    -- Burst
    local sh=Instance.new("Part",flowersFolder)
    sh.Size=Vector3.new(0.1,0.1,0.1); sh.CFrame=CFrame.new(pos+Vector3.new(0,SH+0.4,0))
    sh.Anchored=true; sh.CanCollide=false; sh.Transparency=1
    local pe=Instance.new("ParticleEmitter",sh)
    pe.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,petal),ColorSequenceKeypoint.new(1,bloom)})
    pe.LightEmission=1; pe.LightInfluence=0
    pe.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.2,0.3),NumberSequenceKeypoint.new(1,0)})
    pe.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.8,0.2),NumberSequenceKeypoint.new(1,1)})
    pe.Lifetime=NumberRange.new(0.8,1.4); pe.Rate=0; pe.Speed=NumberRange.new(4,10)
    pe.SpreadAngle=Vector2.new(80,80); pe:Emit(26)
    task.delay(2, function() sh:Destroy() end)

    -- Breathing loop
    task.spawn(function()
        while bl and bl.Parent do
            TweenService:Create(bl,TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                {Size=Vector3.new(1.12,1.12,1.12)}):Play()
            task.wait(2)
            TweenService:Create(bl,TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                {Size=Vector3.new(1,1,1)}):Play()
            task.wait(2)
        end
    end)
end

-- ── UI ────────────────────────────────────────────────────────────────────────

local function buildUI()
    local screen = Instance.new("ScreenGui")
    screen.Name="GardenUI"; screen.ResetOnSpawn=false
    screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    screen.Enabled=false; screen.Parent=gui

    local bg = Instance.new("Frame",screen)
    bg.Size=UDim2.new(1,0,1,0)
    bg.BackgroundColor3=Color3.fromRGB(5,3,18)
    bg.BackgroundTransparency=0.35; bg.BorderSizePixel=0

    local card = Instance.new("Frame",bg)
    card.Name="Card"
    card.Size=UDim2.new(0,500,0,430); card.AnchorPoint=Vector2.new(0.5,0.5)
    card.Position=UDim2.new(0.5,0,1.1,0)
    card.BackgroundColor3=Color3.fromRGB(12,8,28)
    card.BackgroundTransparency=0.05; card.BorderSizePixel=0
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,20)
    local cs=Instance.new("UIStroke",card); cs.Color=Color3.fromRGB(180,255,180); cs.Thickness=2

    -- Progress dots
    local dotRow=Instance.new("Frame",card)
    dotRow.Size=UDim2.new(0,110,0,26); dotRow.AnchorPoint=Vector2.new(0.5,0)
    dotRow.Position=UDim2.new(0.5,0,0,14); dotRow.BackgroundTransparency=1
    local dll=Instance.new("UIListLayout",dotRow)
    dll.FillDirection=Enum.FillDirection.Horizontal
    dll.HorizontalAlignment=Enum.HorizontalAlignment.Center
    dll.Padding=UDim.new(0,12)
    local dots={}
    for i=1,3 do
        local d=Instance.new("TextLabel",dotRow)
        d.Size=UDim2.new(0,26,0,26); d.BackgroundColor3=Color3.fromRGB(30,30,50)
        d.BackgroundTransparency=0; d.Text="🌑"; d.TextScaled=true
        d.BorderSizePixel=0; d.Font=Enum.Font.GothamBold
        Instance.new("UICorner",d).CornerRadius=UDim.new(1,0)
        dots[i]=d
    end

    local header=Instance.new("TextLabel",card)
    header.Size=UDim2.new(1,-20,0,32); header.Position=UDim2.new(0,10,0,48)
    header.BackgroundTransparency=1; header.Text="🌸  Garden of Gratitude  🌸"
    header.TextColor3=Color3.fromRGB(160,255,180); header.TextScaled=true
    header.Font=Enum.Font.GothamBold

    local flName=Instance.new("TextLabel",card)
    flName.Name="FlName"; flName.Size=UDim2.new(1,-20,0,24); flName.Position=UDim2.new(0,10,0,84)
    flName.BackgroundTransparency=1; flName.Text=""; flName.TextColor3=Color3.fromRGB(255,200,80)
    flName.TextScaled=true; flName.Font=Enum.Font.GothamSemibold

    local prompt=Instance.new("TextLabel",card)
    prompt.Name="Prompt"; prompt.Size=UDim2.new(1,-40,0,72); prompt.Position=UDim2.new(0,20,0,116)
    prompt.BackgroundTransparency=1; prompt.Text=""
    prompt.TextColor3=Color3.fromRGB(210,210,210); prompt.TextSize=16
    prompt.Font=Enum.Font.Gotham; prompt.TextWrapped=true
    prompt.TextXAlignment=Enum.TextXAlignment.Left; prompt.TextYAlignment=Enum.TextYAlignment.Top

    -- Input
    local inputF=Instance.new("Frame",card)
    inputF.Size=UDim2.new(1,-40,0,80); inputF.Position=UDim2.new(0,20,0,198)
    inputF.BackgroundColor3=Color3.fromRGB(22,14,46); inputF.BorderSizePixel=0
    Instance.new("UICorner",inputF).CornerRadius=UDim.new(0,10)
    local ist=Instance.new("UIStroke",inputF); ist.Color=Color3.fromRGB(70,170,90); ist.Thickness=1.5
    local tb=Instance.new("TextBox",inputF)
    tb.Name="TB"; tb.Size=UDim2.new(1,-12,1,0); tb.Position=UDim2.new(0,6,0,0)
    tb.BackgroundTransparency=1; tb.Text=""; tb.PlaceholderText="Write your gratitude…"
    tb.PlaceholderColor3=Color3.fromRGB(90,90,120)
    tb.TextColor3=Color3.fromRGB(210,255,210); tb.TextSize=14
    tb.Font=Enum.Font.Gotham; tb.TextWrapped=true; tb.MultiLine=true
    local cc=Instance.new("TextLabel",inputF)
    cc.Size=UDim2.new(0,56,0,18); cc.AnchorPoint=Vector2.new(1,1)
    cc.Position=UDim2.new(1,-3,1,-2); cc.BackgroundTransparency=1
    cc.Text="0/100"; cc.TextColor3=Color3.fromRGB(90,130,90); cc.TextSize=11
    cc.Font=Enum.Font.Gotham; cc.TextXAlignment=Enum.TextXAlignment.Right
    tb:GetPropertyChangedSignal("Text"):Connect(function()
        local t=tb.Text:sub(1,100); tb.Text=t; cc.Text=#t.."/100"
    end)

    local plantBtn=Instance.new("TextButton",card)
    plantBtn.Name="Btn"; plantBtn.Size=UDim2.new(0,190,0,42)
    plantBtn.AnchorPoint=Vector2.new(0.5,0); plantBtn.Position=UDim2.new(0.5,0,0,302)
    plantBtn.BackgroundColor3=Color3.fromRGB(75,175,95); plantBtn.BorderSizePixel=0
    plantBtn.Text="🌱  Plant"; plantBtn.TextColor3=Color3.fromRGB(10,38,14)
    plantBtn.TextScaled=true; plantBtn.Font=Enum.Font.GothamBold
    Instance.new("UICorner",plantBtn).CornerRadius=UDim.new(0,12)

    local status=Instance.new("TextLabel",card)
    status.Name="Status"; status.Size=UDim2.new(1,-20,0,28); status.Position=UDim2.new(0,10,0,356)
    status.BackgroundTransparency=1; status.Text=""
    status.TextColor3=Color3.fromRGB(155,235,155); status.TextScaled=true
    status.Font=Enum.Font.GothamSemibold

    return screen, card, dots, flName, prompt, tb, plantBtn, status
end

-- ── Main game loop ────────────────────────────────────────────────────────────

local function run()
    local screen,card,dots,flName,prompt,tb,plantBtn,status = buildUI()
    screen.Enabled=true
    TweenService:Create(card, TweenInfo.new(0.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,0,0.5,0)}):Play()
    task.wait(0.6)

    for round=1,3 do
        -- Update dots
        for i,d in ipairs(dots) do
            if i<round then d.Text="🌸"; d.BackgroundColor3=Color3.fromRGB(55,150,75)
            elseif i==round then d.Text="🌱"; d.BackgroundColor3=Color3.fromRGB(28,75,38)
            else d.Text="🌑"; d.BackgroundColor3=Color3.fromRGB(30,30,50) end
        end
        flName.Text = string.format("Flower %d / 3  –  %s", round, NAMES[round])
        prompt.Text = PROMPTS[round]
        tb.Text=""; status.Text=""
        plantBtn.Active=true; plantBtn.BackgroundColor3=Color3.fromRGB(75,175,95)
        plantBtn.Text="🌱  Plant"

        local submitted=false; local submitText=""
        local function trySubmit()
            local t=tb.Text:gsub("^%s+",""):gsub("%s+$","")
            if #t<3 then status.Text="✦ Please write a little more ✦"; status.TextColor3=Color3.fromRGB(255,130,130); return end
            submitted=true; submitText=t
        end
        local bc=plantBtn.MouseButton1Click:Connect(trySubmit)
        local fc=tb.FocusLost:Connect(function(e) if e then trySubmit() end end)
        while not submitted do task.wait(0.05) end
        bc:Disconnect(); fc:Disconnect()

        plantBtn.Active=false; plantBtn.BackgroundColor3=Color3.fromRGB(45,95,50)
        plantBtn.Text="🌿  Growing…"
        status.Text="✦  Your gratitude takes root…  ✦"; status.TextColor3=Color3.fromRGB(155,240,155)

        -- Send to server and wait for echo
        evFlower:FireServer(submitText)
        local plotIdx=nil
        local conn; conn=evFlower.OnClientEvent:Connect(function(idx)
            conn:Disconnect(); plotIdx=idx
        end)
        local t0=tick()
        while not plotIdx and tick()-t0<6 do task.wait(0.05) end

        if plotIdx then
            task.spawn(function() growFlower(plotIdx, PALETTES[round]) end)
        end

        task.wait(1.6)
        if round<3 then status.Text="Beautiful! Next flower…"; task.wait(1.1) end
    end

    -- Done
    for _,d in ipairs(dots) do d.Text="🌸"; d.BackgroundColor3=Color3.fromRGB(55,150,75) end
    plantBtn.Text="✦  Garden in bloom  ✦"; status.Text=""
    task.wait(0.8)

    TweenService:Create(card, TweenInfo.new(0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
        {Position=UDim2.new(0.5,0,-0.6,0)}):Play()
    task.wait(0.5); screen:Destroy()

    -- Confetti
    local ch=Instance.new("Part",Workspace)
    ch.Size=Vector3.new(0.1,0.1,0.1); ch.Anchored=true; ch.CanCollide=false; ch.Transparency=1
    local cfg2=RS:FindFirstChild("ModuleConfig") and require(RS.ModuleConfig)
    local gpos=(cfg2 and cfg2.Modules.Garden and cfg2.Modules.Garden.Position) or Vector3.new(0,5,0)
    ch.CFrame=CFrame.new(gpos+Vector3.new(0,5,0)); ch.Parent=flowersFolder
    local conf=Instance.new("ParticleEmitter",ch)
    conf.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,220,50)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(200,80,200)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(80,200,120)),
    })
    conf.LightEmission=0.8; conf.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.15,0.5),NumberSequenceKeypoint.new(1,0)})
    conf.Lifetime=NumberRange.new(2,3.5); conf.Rate=0; conf.Speed=NumberRange.new(8,18)
    conf.SpreadAngle=Vector2.new(180,180); conf:Emit(80)
    task.delay(4,function() ch:Destroy() end)

    evComplete:FireServer()

    -- Completion banner
    local bs=Instance.new("ScreenGui"); bs.Name="GardenComplete"; bs.ResetOnSpawn=false; bs.Parent=gui
    local bf=Instance.new("Frame",bs)
    bf.Size=UDim2.new(0,460,0,90); bf.AnchorPoint=Vector2.new(0.5,0)
    bf.Position=UDim2.new(0.5,0,-0.12,0)
    bf.BackgroundColor3=Color3.fromRGB(10,28,15); bf.BackgroundTransparency=0.08; bf.BorderSizePixel=0
    Instance.new("UICorner",bf).CornerRadius=UDim.new(0,14)
    local bst=Instance.new("UIStroke",bf); bst.Color=Color3.fromRGB(100,230,130); bst.Thickness=2
    local bl2=Instance.new("TextLabel",bf)
    bl2.Size=UDim2.new(1,-16,1,0); bl2.Position=UDim2.new(0,8,0,0)
    bl2.BackgroundTransparency=1
    bl2.Text="🌸  Garden of Gratitude complete – Lantern earned!  🌸"
    bl2.TextColor3=Color3.fromRGB(160,255,180); bl2.TextScaled=true; bl2.Font=Enum.Font.GothamBold
    TweenService:Create(bf, TweenInfo.new(0.6,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,0,0.05,0)}):Play()
    task.delay(5,function()
        TweenService:Create(bf, TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
            {Position=UDim2.new(0.5,0,-0.15,0)}):Play()
        task.delay(0.5,function() bs:Destroy() end)
    end)
end

evStart.OnClientEvent:Connect(function()
    if done then return end; done=true; task.spawn(run)
end)

print("[GardenModule] ready.")
