local PlayerData = {}

local Players = game:GetService("Players")

local UpdateUI: RemoteEvent = game.ReplicatedStorage.Remotes.UpdateUI
local data = {}

local defaultData = {
	money = 1000,
	paycheck = 100,
	paycheckWithdrawAmount = 0,
	padsPurchased = {}
}

function PlayerData:GetPaycheckWithdrawAmount(player)
	local data = PlayerData:GetPlayerData(player)
	return data.paycheckWithdrawAmount
end

function PlayerData:SetPaycheckWithdrawAmount(player, amount)
	local data = PlayerData:GetPlayerData(player)
	data.paycheckWithdrawAmount = amount
end

function PlayerData:GetPlayerData(player)
	return data[player.UserId]
end

function PlayerData:GetMoney(player, amount)
	local data = PlayerData:GetPlayerData(player)
	return data.money
end

function PlayerData:SetMoney(player, amount)
	local data = PlayerData:GetPlayerData(player)
	data.money = amount
	UpdateUI:FireClient(player, data.money)
end

function PlayerData:GetPaycheck(player)
	local data = PlayerData:GetPlayerData(player)
	return data.paycheck
end

function PlayerData:SetPaycheck(player, amount)
	local data = PlayerData:GetPlayerData(player)
	data.paycheck = amount
end

function PlayerData:AddMoney(player, amount)
	local data = PlayerData:GetPlayerData(player)
	data.money += amount
	UpdateUI:FireClient(player, data.money)
end

function PlayerData:SubtractMoney(player, amount)
	local data = PlayerData:GetPlayerData(player)
	data.money -= amount
	UpdateUI:FireClient(player, data.money)
end

Players.PlayerAdded:Connect(function(player)
	data[player.UserId] = defaultData
end)


return PlayerData
