local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- All your wellbeing messages
local messages = {
	"🌸 Take a deep breath. You're doing great.",
	"💛 It's okay to slow down.",
	"🌿 Remember to drink some water today.",
	"🏮 You are enough, just as you are.",
	"✨ Rest is not a reward — it's a necessity.",
	"🌙 It's okay to not have everything figured out.",
	"💛 Check in with yourself. How are you feeling?",
	"🌸 Small steps still move you forward.",
	"🌿 Be kind to yourself today.",
	"✨ You don't have to rush. Take your time.",
	"🏮 Breathe in slowly... and breathe out.",
	"💛 Your feelings are valid.",
	"🌸 It's okay to ask for help.",
	"🌿 Take a moment to notice something beautiful around you.",
	"✨ Progress, not perfection.",
	"🏮 You deserve the same kindness you give to others.",
	"🌙 Rest when you need to. The world can wait.",
	"💛 You are not alone.",
}

-- Create the notification GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WellbeingGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0.35, 0, 0.08, 0)
frame.Position = UDim2.new(0.5, 0, 0.85, 0)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 200, 80)
stroke.Thickness = 1.5
stroke.Transparency = 0.5
stroke.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -20, 1, 0)
label.Position = UDim2.new(0, 10, 0, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(255, 240, 200)
label.TextScaled = true
label.Font = Enum.Font.GothamMedium
label.TextXAlignment = Enum.TextXAlignment.Center
label.Parent = frame

-- Start fully invisible
frame.BackgroundTransparency = 1
stroke.Transparency = 1
label.TextTransparency = 1

local function showMessage(text)
	label.Text = text

	-- Fade in
	local fadeIn = TweenService:Create(frame, TweenInfo.new(1, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 0.2
	})
	local fadeInText = TweenService:Create(label, TweenInfo.new(1, Enum.EasingStyle.Sine), {
		TextTransparency = 0
	})
	local fadeInStroke = TweenService:Create(stroke, TweenInfo.new(1, Enum.EasingStyle.Sine), {
		Transparency = 0.3
	})

	fadeIn:Play()
	fadeInText:Play()
	fadeInStroke:Play()

	task.wait(5) -- message stays for 5 seconds

	-- Fade out
	local fadeOut = TweenService:Create(frame, TweenInfo.new(1, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 1
	})
	local fadeOutText = TweenService:Create(label, TweenInfo.new(1, Enum.EasingStyle.Sine), {
		TextTransparency = 1
	})
	local fadeOutStroke = TweenService:Create(stroke, TweenInfo.new(1, Enum.EasingStyle.Sine), {
		Transparency = 1
	})

	fadeOut:Play()
	fadeOutText:Play()
	fadeOutStroke:Play()
	task.wait(1)
end

-- Shuffle messages so they don't repeat in the same order
local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

-- Main loop
task.spawn(function()
	task.wait(10) -- wait 10 seconds before first message appears
	while true do
		shuffle(messages)
		for _, msg in ipairs(messages) do
			showMessage(msg)
			task.wait(60) -- new message every 60 seconds
		end
	end
end)
