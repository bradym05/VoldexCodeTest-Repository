--------// VARIABLES \\--------
--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

--Modules
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

--Instances
local padsFolder = workspace:WaitForChild("Pads")
local pads = padsFolder:GetChildren()
local buildingsFolder = workspace:WaitForChild("Buildings")
local builtEvent = Instance.new("BindableEvent")

--Other
local built = {}
local debounce = {}

--------// PRIVATE FUNCTIONS \\--------

--Registers purchase requests and fulfills them
local function padPurchased(Player : Player, pad : Model)
	if not built[pad] and not debounce[Player] then
		--Set player debounce to prevent simultaneous requests
		debounce[Player] = true
		local data = PlayerData.PlayerSaves[Player]
		if data then
		--Check that player has sufficient funds
			local money = data.Data[1]
			local price = pad:GetAttribute("Price") or 0
			if money >= price then
				--Set pad to built
				built[pad] = true
				builtEvent:Fire(pad)
				--Subtract price
				data:Increment("Money", -price)
				--Build designated object
				local building = pad.Target.Value:Clone()
				building.Parent = workspace
				--Delete pad
				pad:Destroy()
			end
		end
		--Disable debounce
		debounce[Player] = false
	end
end

--Connect to Touched signal
local function connectTouch(pad, touchingArea)
	touchingArea.Touched:Connect(function(hit)
		--Get player
		local Player = Players:GetPlayerFromCharacter(hit.Parent)
		--Check that it was a player who touched
		if Player then
			padPurchased(Player, pad)
		end
	end)
end

-------------// CODE \\-------------

--Setup each pad
for _, pad in pairs(pads) do
	local dependency = pad.Dependency.Value
	local touchingArea: BasePart = pad.Pad

	--Check if pad is purchaseable
	if not dependency or built[dependency] then
		connectTouch(pad, touchingArea)
	else
		--Listen to new objects being purchased
		local builtConnection
		builtConnection = builtEvent.Event:Connect(function(object)
			--Check if dependency was purchased
			if object == dependency then
				--Disconnect listener and connect touch events
				builtConnection:Disconnect()
				connectTouch(pad,touchingArea)
			end
		end)
	end
end

--Hide buildings
buildingsFolder.Parent = game.ServerStorage
