--------// VARIABLES \\--------

--Services
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local options = Instance.new("DataStoreOptions")
local data = DataStoreService:GetDataStore("Save1")

--String keys to indexes
local keys = {
	Money = 1,
}

--Default data
local defaultData = {1000, 100, 0, {}} --Money, paycheck, paycheckWithdrawAmount, padsPurchased

----// PRIVATE FUNCTIONS \\----

--DataStore error codes and corresponding callbacks
local codeCallbacks = {}

--Callback for throughput errors
local function yield()
	task.wait(5)
end

--Throughput errors range from 301 - 306, assign to yield callback
for i = 301,306 do
	codeCallbacks[tostring(i)] = yield
end

--Safely handles DataStoreService requests and responds accordingly to errors
local function safeManage(functionName,...)
	--Initialize variables
	local succ, result, errorCode
	local arguments = {...}

	repeat
		succ, result, errorCode = pcall(function()
			--Call the datastore function with given arguments
			data[functionName](data, unpack(arguments))
		end)
		--Catch any errors: https://create.roblox.com/docs/cloud-services/datastores#error-codes
		if not succ then
			--See if a callback exists
			if codeCallbacks[tostring(result)] then
				--Run callback function
				codeCallbacks[tostring(result)]()
			else
				--Break loop if error has no callback
				break
			end
		end
	until succ

	--Return final result
	return result
end

-------// DATA CLASS \\-------

local PlayerData = {}
PlayerData.__index = PlayerData

--Responsible for loading new players
function PlayerData.new(Player : PLayer)
	--Get player data with UserId as the key
	local loadedData = safeManage("GetAsync",tostring(Player.UserId))
	--Called function yields, so check that Player is still in-game
	if Player and Player:IsDescendantOf(Players) then
		--Reconcile
		if not loadedData then
			loadedData = defaultData
		end
		--Create object and return
		local self = {}
		self.Data = loadedData
		self.Player = Player
		self.Key = tostring(Player.UserId)
		self.Changed = false

		setmetatable(self, PlayerData)
		return self
	end
	--Something went wrong, return false
	return false
end

--Increment data
function PlayerData:Increment(key, value, inc)
	--Convert to index
	key = keys[key]
	--Make sure index exists
	if key then
		--Reconcile if data does not exist
		if not self.Data[key] then
			self.Data[key] = inc
		else
			self.Data[key] += inc
		end
		--Indicate data has changed
		self.Changed = true
	end
end

--Cleans up PlayerData objects and saves
function PlayerData:Destroy()
	safeManage("SetAsync", self.Key, self.Data)
	table.clear(self)
	setmetatable(self,nil)
	table.freeze(self)
end

-------// DATA MANAGER \\-------

--Event instance to signal player data has loaded
local loadedEvent = Instance.new("BindableEvent")
--Declare class with initialized variables
local DataManager = {
	PlayerLoaded = loadedEvent.Event,
	PlayerSaves = {},
}

--Load added players
local function playerAdded(Player : Player)
	--Create a new data object
	local result = PlayerData.new(Player)
	--Make sure player successfully loaded
	if result then
		--Refer player to data object inside of PlayerSaves
		DataManager.PlayerSaves[Player] = result
		--Signal that the player loaded and send their data object
		loadedEvent:Fire(Player, result)
	end
end
Players.PlayerAdded:Connect(playerAdded)

--Clean up players once they leave
Players.PlayerRemoving:Connect(function(Player : Player)
	--Check if player has any stored reference
	if DataManager.PlayerSaves[Player] then
		--Clean up
		DataManager.PlayerSaves[Player]:Destroy()
		DataManager.PlayerSaves[Player] = nil
	end
end)

--Catch any players who may have already joined
for _, Player : Player in pairs(Players:GetPlayers()) do
	task.spawn(playerAdded, Player)
end

--Save all updated data in 30 second intervals
task.spawn(function()
	while true do
		task.wait(30)
		--Loop through all players
		for player, dataObject in pairs(DataManager.PlayerSaves) do
			--See if any changes have occurred
			if dataObject.Changed == true then
				--Update to indicate data has been saved
				dataObject.Changed = false
				--Save data
				safeManage("SetAsync", dataObject.Key, dataObject.Data)
			end
		end
	end
end)

return DataManager
