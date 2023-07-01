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
    MoneyToCollect = 0,
}

--Settings
local REPLICATED_STATS = { --Put the names and value ClassNames of data to be included in leaderstats here
    Money = "IntValue",
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
        --Create leaderstats
        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = Player
        --Loop through all replicated stats
        for name : String, ClassName : String in pairs(REPLICATED_STATS) do
            --Create value object and set loaded value
            local valueObject = Instance.new(ClassName)
            valueObject.Name = name
            valueObject.Value = dataObject:GetData(name)
            valueObject.Parent = leaderstats
            --Connect to changes
            dataObject:ListenToChange(name, function(newValue)
                valueObject.Value = newValue
            end)
        end
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