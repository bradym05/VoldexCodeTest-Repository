local UpdateUI: RemoteEvent = game.ReplicatedStorage.Remotes.UpdateUI

local PlayerGui = game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')
local ScreenGui = PlayerGui:WaitForChild("ScreenGui")
local HUD = ScreenGui:WaitForChild("Frame")


local moneyLabel = HUD:WaitForChild("TextLabel")

UpdateUI.OnClientEvent:Connect(function(amount)
	moneyLabel.Text = tostring(amount)
end)
