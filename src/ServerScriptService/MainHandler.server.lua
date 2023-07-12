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

--Instances
local remotes : Folder = ReplicatedStorage:WaitForChild("Remotes")
local getData : RemoteFunction = remotes:WaitForChild("GetData")
local setData : RemoteEvent = remotes:WaitForChild("SetData")
local upgradeEvent : RemoteEvent = remotes:WaitForChild("RequestUpgrade")

--Settings
local BASE_UPGRADE_PRICE = 500 --Price for each paycheck upgrade (increasing)
local BASE_PAYCHECK = 50 --Increment for paycheck upgrades

local REPLICATED_STATS = { --Put the names and value ClassNames of data to be included in leaderstats here
    Money = "IntValue",
}
local REPLICATED_HIDDEN = { --Put the names and value ClassNames of data to be replicated but hidden here
    Paycheck = "IntValue",
    UpgradeCost = "IntValue",
    Ticket = "BoolValue",
    MoneyToCollect = "IntValue",
}
local CLIENT_ACCESS = { --Data which can be read and changed by players
    "Settings"
}


--DataStore template
PlayerData.TEMPLATE = {
    Money = 1000,
    Purchased = {},
    Paycheck = BASE_PAYCHECK,
    UpgradeCost = BASE_UPGRADE_PRICE,
    MoneyToCollect = 0,
    Ticket = false,
    Settings = {
        GameVolume = 0.75,
        GuiVolume = 0.75,
        MusicVolume = 0.5,
        Particles = 1,
        BuildAnimations = true,
    },
    PurchaseHistory = {},
}

--Manipulated
local playerToTycoon = {}
local upgradeDebounce = {}
local changeCallbacks = {}

------------------// PRIVATE FUNCTIONS \\------------------
--Load players
local function playerAdded(player : Player)
    --Create data object
    local dataObject = PlayerData.new(player)
    --Make sure player loaded
    if dataObject then
        --Create tycoon and reference
        local Tycoon = TycoonClass.new(player)
        playerToTycoon[player] = Tycoon
        --Create leaderstats folder
        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
        --Create hidden stats folder
        local hiddenstats = Instance.new("Folder")
        hiddenstats.Name = "hiddenstats"
        hiddenstats.Parent = player
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
                --Call custom function if it exists
                if changeCallbacks[name] then
                    changeCallbacks[name](newValue, dataObject)
                end
            end)
        end
    end
end

--Clean up when players leave
local function playerRemoving(player : Player)
    if playerToTycoon[player] then
        --Clean up tycoon
        playerToTycoon[player]:Destroy()
        --Remove references
        playerToTycoon[player] = nil
        upgradeDebounce[player] = nil
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
local function getDataFunction(player : Player, dataName : string)
    --Verify this is data accessible by the client
    if verifyAccess(dataName) then
        --Get data
        local data = PlayerData.getDataObject(player)
        --Verify data exists
        if data then
            --Return value
            return data:GetData(dataName)
        end
    end
end

--Set data remote event
local function setDataFunction(player : Player, dataName : string, value : any)
    --Verify this is data accessible by the client
    if verifyAccess(dataName) then
        --Get data
        local data = PlayerData.getDataObject(player)
        --Verify data exists
        if data then
            --Set data
            data:SetData(dataName, value)
        end
    end
end

--Update paycheck price on change
local function onPaycheckChanged(newValue : number, dataObject)
    --Get the ratio of current paycheck to base paycheck
    local paycheckRatio = math.round(newValue/BASE_PAYCHECK)
    --Multiply ratio by upgrade cost
    local newPrice = paycheckRatio * BASE_UPGRADE_PRICE
    --Set data
    dataObject:SetData("UpgradeCost", newPrice)
end

--Upgrade paycheck remote event
local function upgradePaycheckFunction(player : Player)
    --Make sure another purchase is not processing
    if not upgradeDebounce[player] then
        --Disable other upgrade requests
        upgradeDebounce[player] = true
        --Get data
        local dataObject = PlayerData.getDataObject(player)
        --Verify data exists
        if dataObject then
            --Get balance and price
            local money = dataObject:GetData("Money")
            local price = dataObject:GetData("UpgradeCost")
            --Check sufficient funds
            if money >= price then
                --Deduct price from player's balance
                dataObject:IncrementData("Money", -price)
                --Increment paycheck
                dataObject:IncrementData("Paycheck", BASE_PAYCHECK)
            end
        end
        --Enable other upgrade requests
        upgradeDebounce[player] = false
    end
end

---------------------// PRIVATE CODE \\--------------------

--Combine REPLICATED_STATS and REPLICATED_HIDDEN
for i,v in pairs(REPLICATED_HIDDEN) do
    REPLICATED_STATS[i] = v
end

--Catch players who may have already loaded
for _, player : Player in pairs(Players:GetPlayers()) do
    task.spawn(playerAdded, player)
end

--Custom data changed callbacks
changeCallbacks["Paycheck"] = onPaycheckChanged

--Connections
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoving)
setData.OnServerEvent:Connect(setDataFunction)
upgradeEvent.OnServerEvent:Connect(upgradePaycheckFunction)

--Remote functions
getData.OnServerInvoke = getDataFunction
