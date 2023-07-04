------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--Modules
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))

--Instances
local player : Player = Players.LocalPlayer
local hiddenstats : Folder = player:WaitForChild("hiddenstats")
local paycheckStat : IntValue = hiddenstats:WaitForChild("Paycheck")

local playerGui : PlayerGui = player:WaitForChild("PlayerGui")
local mainInterface : Frame = playerGui:WaitForChild("MainInterface")
local popup : Frame = mainInterface:WaitForChild("Popup")
local paycheckFrame : Frame = popup:WaitForChild("Container"):WaitForChild("Paycheck")
local currentPaycheckLabel : TextLabel = paycheckFrame:WaitForChild("CurrentPaycheck")
local paycheckValueLabel : TextLabel = currentPaycheckLabel:WaitForChild("PaycheckValue")
local shineGradient : UIGradient = paycheckValueLabel:WaitForChild("UIGradient")

--Tween Settings
local shineTF = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local shineTween = TweenService:Create(shineGradient, shineTF, {Offset = Vector2.new(1, 0)})

--Manipulated
local shineLooping = false

------------------// PRIVATE FUNCTIONS \\------------------

--Pause animations when frame is hidden
local function onVisibleChanged()
    --Look for change
    if paycheckFrame.Visible == true then
        --Play animations
        shineTween:Play()
    else
        --Stop animations
        shineTween:Cancel()
    end
end

---------------------// PRIVATE CODE \\--------------------

--Connect to shine animation ended for seamless loop
shineTween.Completed:Connect(function()
    --Make sure loop is not in progress
    if not shineLooping then
        --Indicate that tween is looping
        shineLooping = true
        --Reset gradient
        shineGradient.Offset = Vector2.new(-1, 0)
        --Wait a random amount of time before looping
        task.wait(math.random(5, 10))
        --Make sure frame is open first
        if paycheckFrame.Visible == true then
            --Loop
            shineTween:Play()
        end
        --Indicate that tween is not looping
        shineLooping = false
    end
end)

--Connections
paycheckFrame:GetPropertyChangedSignal("Visible"):Connect(onVisibleChanged)