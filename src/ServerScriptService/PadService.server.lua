local PadPurchase: BindableEvent = game.ReplicatedStorage.PadPurchase
local PlayerData = require(script.Parent.PlayerData)

local padsFolder = workspace.Pads
local pads = padsFolder:GetChildren()

local buildingsFolder = workspace.Buildings
buildingsFolder.Parent = game.ReplicatedStorage

local function onPadTouch(player, pad)
	PlayerData:SubtractMoney(player, pad:GetAttribute("Price"))
	local buildingClone = pad.Target.Value:Clone()
	buildingClone.Parent = workspace

	pad.Skin:Destroy()
	pad.Pad:Destroy()

	print(PlayerData:GetMoney(player))
	PadPurchase:Fire(pad)
end

for index, pad in pads do
	if pad:GetAttribute("isFinished") then
		return
	end

	local dependency = pad.Dependency.Value

	local touchingArea: BasePart = pad.Pad
	touchingArea.Touched:Connect(function(hit)
		if dependency then
			if not dependency:GetAttribute("isFinished") then				
				return
			end
		end

		pad:SetAttribute("isFinished", true)
		
		local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
		onPadTouch(player, pad)
	end)
end

local function onPadPurchased(pad)
	local message = ("Pad %s was purchased!"):format(pad.Name)
end

PadPurchase.Event:Connect(onPadPurchased)