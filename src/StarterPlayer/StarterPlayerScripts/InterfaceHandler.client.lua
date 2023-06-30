------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--Instances
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local interface = playerGui:WaitForChild("MainInterface")
local interfaceMenu = interface:WaitForChild("Menu")
local interfaceContainer = interfaceMenu:WaitForChild("Container")
local moneyLabel = interfaceContainer:WaitForChild("MoneyCount")
local leaderstats = player:WaitForChild("leaderstats")
local moneyStat = leaderstats:WaitForChild("Money")

--Settings
local MONEY_ANIM_SPEED = 2

--Manipulated
local displayMoney = 0
local connection : RBXScriptConnection

------------------// PRIVATE FUNCTIONS \\------------------

local function updateMoney(start : number, goal : number, elapsed : number) : boolean?
    --Convert anim speed to time and get an alpha of elapsed/time (progress) and keep between 0 and 1
    local alpha = math.clamp(elapsed/(1/MONEY_ANIM_SPEED), 0, 1)
    --Lerp display value with calculated alpha (start value plus difference to goal = goal so difference to goal times alpha = progress)
    displayMoney = math.round(start + (goal - start)*alpha)
    --Set display
    moneyLabel.Text = "$ "..tostring(displayMoney)
    --Return true if value has completed animation
    if alpha == 1 then
        return true
    end
end

---------------------// PRIVATE CODE \\--------------------

--Set moneyLabel text to value without animation
updateMoney(displayMoney, moneyStat.Value, 1/MONEY_ANIM_SPEED) 

--Connect to changed
moneyStat.Changed:Connect(function()
    --Disconnect previous animation if active
    if connection and connection.Connected then
        connection:Disconnect()
    end
    --Initialize variables
    local elapsed = 0
    local goal = moneyStat.Value
    local start = displayMoney
    --Connect to new animation
    connection = RunService.RenderStepped:Connect(function(deltaTime)
        --Increment elapsed by change in time
        elapsed += deltaTime
        --Update GUI
        local disconnect = updateMoney(start, goal, elapsed)
        --Disconnect if animation completed
        if disconnect then
            connection:Disconnect()
        end
    end)
end)