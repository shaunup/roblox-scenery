local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BreathingEvent = ReplicatedStorage:WaitForChild("BreathingEvent")

local CYCLE_TIME = 4
local TOTAL_ROUNDS = 3

local playerData = {}

local function startBreathing(player)
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

game.Players.PlayerAdded:Connect(function(player)
    task.wait(3)
    startBreathing(player)
end)