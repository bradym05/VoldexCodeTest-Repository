local Players = game:GetService("Players")
local PlayerData = require(script.Parent.PlayerData)

local RequestPaycheck: RemoteFunction = game.ReplicatedStorage.Remotes.RequestPaycheck
local UpdatePaycheckMachines: RemoteEvent = game.ReplicatedStorage.Remotes.UpdatePaycheckMachines

local PAYCHECK_UPDATE_INTERVAL = 1
local PAYCHECK_INCREMENTAL_VALUE = 100

local playersPaychecks = {}
local playerWallets = {}

local function onPlayerAdded(player)
	task.wait(2)
	
	while true do
		PlayerData:SetPaycheckWithdrawAmount(player, PlayerData:GetPaycheckWithdrawAmount(player) + PAYCHECK_INCREMENTAL_VALUE)
		UpdatePaycheckMachines:FireClient(player, PlayerData:GetPaycheckWithdrawAmount(player))
		task.wait(PAYCHECK_UPDATE_INTERVAL)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

RequestPaycheck.OnServerInvoke = function(player, amount)	
	PlayerData:AddMoney(player, amount)
	
	local paycheck = PlayerData:SetPaycheckWithdrawAmount(player, 0)
	UpdatePaycheckMachines:FireClient(player, PlayerData:GetPaycheckWithdrawAmount(player))
	
	return amount
end