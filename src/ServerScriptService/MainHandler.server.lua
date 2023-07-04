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
local remotes : Folder = ReplicatedStorage:WaitForChild("Remotes")
local getData : RemoteFunction = remotes:WaitForChild("GetData")
local setData : RemoteEvent = remotes:WaitForChild("SetData")

--DataStore template
PlayerData.TEMPLATE = {
    Money = 1000,
    Purchased = {},
    Paycheck = 50,
    MoneyToCollect = 0,
    Settings = {
        GameVolume = 0.75,
        GuiVolume = 0.75,
        MusicVolume = 0.5,
        Particles = 1,
        BuildAnimations = true,
    }
}

--Settings
local REPLICATED_STATS = { --Put the names and value ClassNames of data to be included in leaderstats here
    Money = "IntValue",
}
local REPLICATED_HIDDEN = { --Put the names and value ClassNames of data to be replicated but hidden here
    Paycheck = "IntValue",
}
local CLIENT_ACCESS = { --Data which can be read and changed by players
    "Settings"
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
        --Create leaderstats folder
        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = Player
        --Create hidden stats folder
        local hiddenstats = Instance.new("Folder")
        hiddenstats.Name = "hiddenstats"
        hiddenstats.Parent = Player
        --Loop through all replicated stats
        for name : string, ClassName : string in pairs(REPLICATED_STATS) do
            --Create value object and set loaded value
            local valueObject = Instance.new(ClassName)
            valueObject.Name = name
            valueObject.Value = dataObject:GetData(name)
            --Determine parent
            if REPLICATED_HIDDEN[name] then
                valueObject.Parent = hiddenstats
            else
                valueObject.Parent = leaderstats
            end
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
        --Remove references
        playerToTycoon[Player] = nil
    end
end

--Verify data access
local function verifyAccess(dataName : string)
    --Check if data is in the CLIENT_ACCESS table
    if dataName and table.find(CLIENT_ACCESS, dataName) then
        return true
    else
        return false
    end
end

--Get data remote function
local function getDataFunction(Player : Player, dataName : string)
    --Verify this is data accessible by the client
    if verifyAccess(dataName) then
        --Get data
        local data = PlayerData.getDataObject(Player)
        --Verify data exists
        if data then
            --Return value
            return data:GetData(dataName)
        end
    end
end

--Set data remote event
local function setDataFunction(Player : Player, dataName : string, value : any)
    --Verify this is data accessible by the client
    if verifyAccess(dataName) then
        --Get data
        local data = PlayerData.getDataObject(Player)
        --Verify data exists
        if data then
            --Set data
            data:SetData(dataName, value)
        end
    end
end

---------------------// PRIVATE CODE \\--------------------

--Combine REPLICATED_STATS and REPLICATED_HIDDEN
for i,v in pairs(REPLICATED_HIDDEN) do
    REPLICATED_STATS[i] = v
end

--Catch players who may have already loaded
for _, Player : Player in pairs(Players:GetPlayers()) do
    task.spawn(playerAdded, Player)
end

--Remote functions
getData.OnServerInvoke = getDataFunction

--Connections
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoving)
setData.OnServerEvent:Connect(setDataFunction)
