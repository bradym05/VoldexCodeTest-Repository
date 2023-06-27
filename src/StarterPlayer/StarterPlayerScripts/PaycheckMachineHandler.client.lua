local paycheckMachinesFolder = workspace.PaycheckMachines
local paycheckMachines = paycheckMachinesFolder:GetChildren()

local RequestPaycheck: RemoteFunction = game.ReplicatedStorage.Remotes.RequestPaycheck
local UpdatePaycheckMachines: RemoteEvent = game.ReplicatedStorage.Remotes.UpdatePaycheckMachines

local nextPaymentValue = 0

local debouncer = 0

for _, paycheckMachine in paycheckMachines do
	local pad: BasePart = paycheckMachine.PadComponents.Pad
	
	pad.Touched:Connect(function(hit)
		if os.time() - debouncer < 1 then
			return
		end
		
		local paycheck = RequestPaycheck:InvokeServer(nextPaymentValue)
		debouncer = os.time()
	end)
end

UpdatePaycheckMachines.OnClientEvent:Connect(function(amount)
	nextPaymentValue = amount
	for _, paycheckMachine in paycheckMachines do
		local moneyLabel = paycheckMachine:FindFirstChild("MoneyLabel", true)
		moneyLabel.Text = tostring(amount)
	end
end)