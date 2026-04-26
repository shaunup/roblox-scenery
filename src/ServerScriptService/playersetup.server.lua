local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GiveMaterial = ReplicatedStorage:WaitForChild("GiveMaterial")

-- Set up materials folder for each player on join
game.Players.PlayerAdded:Connect(function(player)
    local materials = Instance.new("Folder")
    materials.Name = "Materials"
    materials.Parent = player

    local paper = Instance.new("IntValue")
    paper.Name = "Paper"
    paper.Value = 0
    paper.Parent = materials

    local stick = Instance.new("IntValue")
    stick.Name = "Stick"
    stick.Value = 0
    stick.Parent = materials

    local candle = Instance.new("IntValue")
    candle.Name = "Candle"
    candle.Value = 0
    candle.Parent = materials
end)

-- Listen for material requests
GiveMaterial.OnServerEvent:Connect(function(player, materialName)
    local material = player.Materials:FindFirstChild(materialName)
    if material then
        material.Value += 1
        print(player.Name .. " received: " .. materialName) -- for debugging
    end
end)