local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local BreathingEvent = ReplicatedStorage:WaitForChild("BreathingEvent")

local player = game.Players.LocalPlayer
local gui = player.PlayerGui:WaitForChild("BreathingGui")
local frame = gui:WaitForChild("Frame")
local bubble = frame:WaitForChild("Bubble")
local phaseLabel = frame:WaitForChild("PhaseLabel")
local timerLabel = frame:WaitForChild("TimerLabel")
local scoreLabel = frame:WaitForChild("ScoreLabel")

local function animateBubble(phase, duration)
	local targetSize

	if phase == "Inhale" then
		targetSize = UDim2.new(0.4, 0, 0.4, 0)
		phaseLabel.Text = "Breathe In..."
	else
		targetSize = UDim2.new(0.15, 0, 0.15, 0)
		phaseLabel.Text = "Breathe Out..."
	end

	local tween = TweenService:Create(
		bubble,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{Size = targetSize}
	)
	tween:Play()
end

local countdownToken = 0 -- replace countdownActive with this

local function startCountdown(duration, token)
	local timeLeft = duration
	while timeLeft > 0 and countdownToken == token do -- checks if still valid
		timerLabel.Text = tostring(math.ceil(timeLeft))
		task.wait(0.1)
		timeLeft -= 0.1
	end
	if countdownToken == token then
		timerLabel.Text = ""
	end
end

BreathingEvent.OnClientEvent:Connect(function(phase, duration)
	if phase == "Inhale" or phase == "Exhale" then
		gui.Enabled = true
		countdownToken += 1 -- invalidates any previous countdown immediately
		animateBubble(phase, duration)
		task.spawn(startCountdown, duration, countdownToken) -- passes current token

	elseif phase == "End" then
		countdownToken += 1 -- stops any running countdown
		phaseLabel.Text = "Well done!"
		timerLabel.Text = ""
		scoreLabel.Text = "Score: " .. tostring(duration)
		task.wait(3)
		gui.Enabled = false
	end
end)

--print "Inside client"

--BreathingEvent.OnClientEvent:Connect(function(phase, duration)
--	if phase == "Inhale" or phase == "Exhale" then
--		gui.Enabled = true
--		countdownActive = false
--		animateBubble(phase, duration)
--		task.spawn(startCountdown, duration)

--	elseif phase == "End" then
--		countdownActive = false
--		phaseLabel.Text = "Well done!"
--		timerLabel.Text = ""
--		scoreLabel.Text = "Score: " .. tostring(duration)
--		task.wait(3)
--		gui.Enabled = false
--	end
--end)