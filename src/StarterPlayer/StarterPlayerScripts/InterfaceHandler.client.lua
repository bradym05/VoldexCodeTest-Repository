------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--Instances
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local interface = playerGui:WaitForChild("MainInterface")
local interfaceMenu = interface:WaitForChild("Menu")
local interfaceContainer = interfaceMenu:WaitForChild("Container")
local moneyLabel = interfaceMenu:WaitForChild("MoneyCount")
local moneyIncLabel = interfaceMenu:WaitForChild("MoneyIncrement")
local leaderstats = player:WaitForChild("leaderstats")
local moneyStat = leaderstats:WaitForChild("Money")

--Settings
local MONEY_ANIM_TIME = 0.5 --Time it takes to animate money

--Tween Settings
local moneyOutGoal = {TextTransparency = 1, Position = UDim2.new(0.5, 0, -0.6, 0), Size = UDim2.new(0.5, 0, 0.4, 0)}

local moneyIncInTF = TweenInfo.new(MONEY_ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.InOut, 0, true)
local moneyIncTweenIn = TweenService:Create(moneyIncLabel, moneyIncInTF, {TextTransparency = 0, Position = UDim2.new(0.5, 0, -0.8, 0), Size = UDim2.new(0.65, 0, 0.45, 0)})
local moneyIncOutTF = TweenInfo.new(MONEY_ANIM_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, true, 0.5)
local moneyIncTweenOut = TweenService:Create(moneyIncLabel, moneyIncOutTF, moneyOutGoal)

--Manipulated
local displayMoney = 0
local connection : RBXScriptConnection
local lastValue = moneyStat.Value

------------------// PRIVATE FUNCTIONS \\------------------

local function updateMoney(start : number, goal : number, elapsed : number) : boolean?
    --Convert anim speed to time and get an alpha of elapsed/time (progress) and keep between 0 and 1
    local alpha = math.clamp(elapsed/(MONEY_ANIM_TIME), 0, 1)
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

--Set moneyIncLabel to defaults
for propertyName : string, propertyValue in pairs(moneyOutGoal) do
    moneyIncLabel[propertyName] = propertyValue
end

--Set moneyLabel text to initial value, without animation (elapsed = time so elapsed/time = 1, no animation)
updateMoney(displayMoney, moneyStat.Value, MONEY_ANIM_TIME) 

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
    local difference = goal - lastValue
    --Update last value
    lastValue = goal
    --Set increment label appearance
    if difference < 0 then
        --Lost money
        moneyIncLabel.Text = "- "
        moneyIncLabel.TextColor3 = Color3.new(1, 0.4, 0.4)
    else
        --Gained money
        moneyIncLabel.Text = "+ "
        moneyIncLabel.TextColor3 = Color3.new(0.4,1,0.4)
    end
    moneyIncLabel.Text ..= tostring(math.abs(difference))
    --Play increment tween
    moneyIncTweenIn:Play()
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

--Automatically tween out money increment after tweened in
moneyIncTweenIn.Completed:Connect(function()
    moneyIncTweenOut:Play()
end)