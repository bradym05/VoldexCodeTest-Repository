------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Modules
local ShipReplicator = require(ReplicatedStorage:WaitForChild("ShipReplicator"))
local PlayerShip = require(ReplicatedStorage:WaitForChild("PlayerShip"))

--Instances
local player = Players.LocalPlayer
local shipFolder : Folder = workspace:WaitForChild("Ships")

--Manipulated
local playerKey = tostring(player.UserId)

------------------// PRIVATE FUNCTIONS \\------------------

local function onShipAdded(shipModel : Model)
    --Initialize ship object variable
    local shipObject
    --Check if this ship is the player's ship
    if shipModel.Name == playerKey then
        --Create player ship
        shipObject = PlayerShip.new(shipModel)
    else
        --Create replicator
        shipObject = ShipReplicator.new(shipModel)
    end
    --Connect to destroying once
    shipModel.Destroying:Once(function()
        --Destroy ship object
        shipObject:Destroy()
    end)
end

---------------------// PRIVATE CODE \\--------------------

--Setup existing ships
for _, shipModel : Model in pairs(shipFolder:GetChildren()) do
    task.spawn(onShipAdded, shipModel)
end

--Connect to setup new ships
shipFolder.ChildAdded:Connect(onShipAdded)