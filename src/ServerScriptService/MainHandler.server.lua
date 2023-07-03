--[[
This script is responsible for bringing all parts of the game together. It handles tycoon creation, player data, and replication.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--Modules
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local TycoonClass = require(ServerScriptService:WaitForChild("TycoonClass"))
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))

--Instances
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

--DataStore template
PlayerData.TEMPLATE = {
    Money = 1000,
    Purchased = {},
    Paycheck = 100,
    MoneyToCollect = 0,
    Settings = {
        GameVolume = 1,
        GuiVolume = 1,
        Particles = 1,
        BuildAnimations = true,
    }
}

--Settings
local REPLICATED_STATS = { --Put the names and value ClassNames of data to be included in leaderstats here
    Money = "IntValue",
}
local CLIENT_ACCESS = { --Data which can be read and changed by players
    "Settings"
}

--Manipulated
local playerToTycoon = {}
local loadedSignals = {}
local playerToData = {}

------------------// PRIVATE FUNCTIONS \\------------------

--Load players
local function playerAdded(Player : Player)
    --Create data object
    local dataObject = PlayerData.new(Player)
    --Make sure player loaded
    if dataObject then
        --Check if data was being yielded
        if loadedSignals[Player] then
            --Signal that player did not load
            loadedSignals[Player]:FireOnce(true)
            --Clean up
            loadedSignals[Player] = nil
        end
        --Create tycoon and reference
        local Tycoon = TycoonClass.new(Player)
        playerToTycoon[Player] = Tycoon
        --Create data reference
        playerToData[Player] = dataObject
        --Create leaderstats
        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = Player
        --Loop through all replicated stats
        for name : string, ClassName : string in pairs(REPLICATED_STATS) do
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
    elseif loadedSignals[Player] then
         --Signal that player did not load
         loadedSignals[Player]:FireOnce(false)
         --Clean up
         loadedSignals[Player] = nil
    end
end

--Clean up when players leave
local function playerRemoving(Player : Player)
    if playerToTycoon[Player] then
        --Clean up tycoon
        playerToTycoon[Player]:Destroy()
        --Clean up loaded signal if active
        if loadedSignals[Player] then
            loadedSignals[Player]:FireOnce(false)
        end
        --Remove references
        playerToTycoon[Player] = nil
        playerToData[Player] = nil
        loadedSignals[Player] = nil
    end
end

--Yield until given player has loaded or left
local function getLoadedData(Player : Player)
    --Check if data is loaded and return first
    if playerToData[Player] then
        return playerToData[Player]
    else
        --Create signal if not created
        if not loadedSignals[Player] then
            loadedSignals[Player] = CustomSignal.new()
        end
        --Yield result of loaded signal
        local success = loadedSignals[Player]:Wait()
        --Return data or false
        return success and playerToData[Player] or false
    end
end

---------------------// PRIVATE CODE \\--------------------

--Catch players who may have already loaded
for _, Player : Player in pairs(Players:GetPlayers()) do
    task.spawn(playerAdded, Player)
end

--Connect to GetData remote
Remotes:WaitForChild("GetData").OnServerInvoke = function(Player : Player, dataName : string)
    --Verify this is data accessible by the client
    if dataName and table.find(CLIENT_ACCESS, dataName) then
        --Get data
        local data = getLoadedData(Player)
        --Verify data exists
        if data then
            --Return value
            return data:GetData(dataName)
        end
    end
end

--Connect to SetData remote
Remotes:WaitForChild("SetData").OnServerEvent:Connect(function(Player : Player, dataName : string, value : any)
    --Verify this is data accessible by the client
    if dataName and table.find(CLIENT_ACCESS, dataName) then
        --Get data
        local data = getLoadedData(Player)
        --Verify data exists
        if data then
            --Set data
            data:SetData(dataName, value)
        end
    end
end)

--Connections
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoving)