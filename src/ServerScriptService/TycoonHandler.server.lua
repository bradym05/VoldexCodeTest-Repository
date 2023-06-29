--[[
This script is responsible for managing tycoon objects and the data associated with them

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

--Modules
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local TycoonClass = require(ServerScriptService:WaitForChild("TycoonClass"))

--DataStore template
PlayerData.TEMPLATE = {
    Money = 1000,
    Purchased = {},
    Paycheck = 100,
}

--Manipulated
local playerToTycoon = {}

------------------// PRIVATE FUNCTIONS \\------------------

--Load players
local function playerAdded(Player : Player)
    --Create data object
    local dataObject = PlayerData.new(Player)
    --Make sure player loaded
    if dataObject then
        --Create tycoon and reference
        local Tycoon = TycoonClass.new(Player)
        playerToTycoon[Player] = Tycoon
    end
end

--Clean up when players leave
local function playerRemoving(Player : Player)
    if playerToTycoon[Player] then
        --Clean up tycoon
        playerToTycoon[Player]:Destroy()
        --Remove reference
        playerToTycoon[Player] = nil
    end
end

---------------------// PRIVATE CODE \\--------------------

--Catch players who may have already loaded
for _, Player : Player in pairs(Players:GetPlayers()) do
    task.spawn(playerAdded, Player)
end

--Connections
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoving)