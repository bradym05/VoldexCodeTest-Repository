------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

--Modules
local TycoonHandler = require(ServerScriptService:WaitForChild("TycoonHandler"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

--DataStore template
PlayerData.TEMPLATE = {
    Money = 1000,
    Purchased = {},
}

--Other
local tycoons = {}

------------------// PRIVATE FUNCTIONS \\------------------

--Load players
local function playerAdded(Player : Player)
    --Create data object
    local dataObject = PlayerData.new(Player)
    --Make sure player loaded
    if dataObject then
        --Create tycoon and reconcile purchased data if nil
        local tycoon = TycoonHandler.new(Player, dataObject)
        --Create reference
        tycoons[Player] = tycoon
    end
end

--Clean up when players leave
local function playerRemoving(Player : Player)
    --Check if player loaded
    if tycoons[Player] then
        --Clean up and remove reference to tycoon
        tycoons[Player]:Destroy()
        tycoons[Player] = nil
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