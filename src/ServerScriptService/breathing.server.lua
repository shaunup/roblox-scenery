local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BreathingEvent = ReplicatedStorage:WaitForChild("BreathingEvent")

local CYCLE_TIME = 4
local TOTAL_ROUNDS = 3

local playerData = {}
local isBreathing = {}

local BreathingTrigger = workspace:WaitForChild("BreathingTrigger")
local prompt = BreathingTrigger:WaitForChild("ProximityPrompt")

local function startBreathing(player)
	isBreathing[player] = true
	playerData[player] = { score = 0 }

	for round = 1, TOTAL_ROUNDS do
		BreathingEvent:FireClient(player, "Inhale", CYCLE_TIME)
		task.wait(CYCLE_TIME)

		BreathingEvent:FireClient(player, "Exhale", CYCLE_TIME)
		task.wait(CYCLE_TIME)

		playerData[player].score += 100
	end

	BreathingEvent:FireClient(player, "End", playerData[player].score)
	playerData[player] = nil
end

game.Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
end)

local BreathingTrigger = workspace:WaitForChild("BreathingTrigger")
local playersInside = {} -- prevents triggering twice

BreathingTrigger.Touched:Connect(function(hit)
	local character = hit.Parent
	local player = game.Players:GetPlayerFromCharacter(character)

	-- Only trigger if it's a real player and hasn't started yet
	if player and not playersInside[player] then
		playersInside[player] = true
		startBreathing(player)
	end
end)

-- Reset when player leaves the trigger
BreathingTrigger.TouchEnded:Connect(function(hit)
	local character = hit.Parent
	local player = game.Players:GetPlayerFromCharacter(character)
	if player then
		playersInside[player] = nil
	end
end)

-- Clean up on leave
game.Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
	playersInside[player] = nil
end)