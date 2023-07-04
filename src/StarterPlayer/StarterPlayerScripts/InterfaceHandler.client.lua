--[[
    TODO:
    Refactor variable gui functions to work with all properties instead of just size and position. Search for all attributes with
    device type and get property name from attribute name, then set guiObject[property name] to attribute value.
--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--Modules
local QuickSound = require(ReplicatedStorage:WaitForChild("QuickSound"))
local TweenAny = require(ReplicatedStorage:WaitForChild("TweenAny"))
local InputDetection = require(ReplicatedStorage:WaitForChild("InputDetection"))
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))

--Instances
local player : Player = Players.LocalPlayer
local playerGui : PlayerGui = player:WaitForChild("PlayerGui")

local interface : Frame = playerGui:WaitForChild("MainInterface")
local interfaceMenu : Frame = interface:WaitForChild("Menu")
local interfaceContainer : Frame = interfaceMenu:WaitForChild("Container")
local moneyLabel : TextLabel = interfaceMenu:WaitForChild("MoneyCount")
local moneyIncLabel : TextLabel = interfaceMenu:WaitForChild("MoneyIncrement")

local popup : Frame = interface:WaitForChild("Popup")
local popupContainer : Frame = popup:WaitForChild("Container")

local leaderstats : Folder = player:WaitForChild("leaderstats")
local moneyStat : IntValue = leaderstats:WaitForChild("Money")

local sounds : Folder = ReplicatedStorage:WaitForChild("Sounds")
local clickSound : Sound = sounds:WaitForChild("SingleClick")
local swishSoundIn : Sound = sounds:WaitForChild("SwishIn")
local swishSoundOut : Sound = sounds:WaitForChild("SwishOut")

--Settings
local MONEY_ANIM_TIME = 0.5 --Time it takes to animate money

--Tween Settings
local moneyOutGoal = {TextTransparency = 1, Position = UDim2.new(0.5, 0, -0.6, 0), Size = UDim2.new(0.5, 0, 0.4, 0)}

local moneyIncInTF = TweenInfo.new(MONEY_ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.InOut, 0, true)
local moneyIncTweenIn = TweenService:Create(moneyIncLabel, moneyIncInTF, {TextTransparency = 0, Position = UDim2.new(0.5, 0, -0.8, 0), Size = UDim2.new(0.65, 0, 0.45, 0)})
local moneyIncOutTF = TweenInfo.new(MONEY_ANIM_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, true, 0.5)
local moneyIncTweenOut = TweenService:Create(moneyIncLabel, moneyIncOutTF, moneyOutGoal)

local buttonTF = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local buttonHoverGoal = {Size = UDim2.new(0.9, 0, 0.9, 0)}

local popupTF = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)
local popupTweenIn = TweenService:Create(popup, popupTF, {Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.268, 0, 0.563, 0)})
local popupTweenOut = TweenService:Create(popup, popupTF, {Position = UDim2.new(0.5, 0, 1.3, 0), Size = UDim2.new(0.23, 0, 0.54, 0)})

local shineTF = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local shineGoal = {Offset = Vector2.new(1, 0)}
local brightnessGoal = {Color = ColorSequence.new(Color3.new(1,1,1))}

--Manipulated
local lastValue = moneyStat.Value
local closeTweens = {}
local nameToBrightness = {}
local guiDefaults = {}
local variableGui = {}
local constraints = {}
local popupOpen = false
local moneySignal = CustomSignal.new()
local popupFrame
local connection : RBXScriptConnection

------------------// PRIVATE FUNCTIONS \\------------------

--Set money display
local function updateMoney(lerped : number)
    moneyLabel.Text = "$ "..tostring(math.round(lerped))
end

--Play a table of tweens
local function tweenTable(tweens : table)
    for _, tween : Tween in pairs(tweens) do
        tween:Play()
    end
end

--Open or close popup based on variables
local function togglePopup(frame : Frame, open : boolean?)
    --Determine correct course of action
    if popupOpen and frame ~= popupFrame then -- Switch frames if open and frame is different
        --Switch frames
        popupFrame.Visible = false
        frame.Visible = true
        --Play other closing tweens
        tweenTable(closeTweens)
        --Set brightness
        nameToBrightness[popupFrame.Name](false)
        nameToBrightness[frame.Name](true)
        --Set open
        popupFrame = frame
    elseif (frame == popupFrame or open == false) and popupOpen then --Close if frame is toggled twice or open is false and popup is open
        --Set closed
        popupOpen = false
        --Close popup
        popupTweenOut:Play()
        --Play other closing tweens
        tweenTable(closeTweens)
        --Make button dark if frame is open
        if popupFrame then
            nameToBrightness[popupFrame.Name](false)
        end
        --Play swish out
        QuickSound(swishSoundOut)
    elseif frame and not popupOpen then --Open if a frame was provided and popup is closed
        --If a frame was open before hide
        if popupFrame then
            popupFrame.Visible = false
        end
        --Set visible
        frame.Visible = true
        --Make popup button bright
        nameToBrightness[frame.Name](true)
        --Set open frame
        popupFrame = frame
        --Set open to true
        popupOpen = true
        --Open popup
        popupTweenIn:Play()
        --Play swish in
        QuickSound(swishSoundIn)
    end
end

--Setup interface buttons
local function buttonSetup(buttonHolder : Frame)
    --Initialize variables
    local buttonCanvas : CanvasGroup = buttonHolder:WaitForChild("CanvasGroup")
    local buttonStroke : UIStroke = buttonHolder:WaitForChild("UIStroke")
    local imageButton : ImageButton = buttonCanvas:WaitForChild("Button")
    local buttonGradient : UIGradient = buttonCanvas:WaitForChild("UIGradient")
    local baseSequenceGoal = {Color = buttonGradient.Color}
    local designatedPopup : Frame = popupContainer:WaitForChild(buttonHolder.Name)
    local shineTween = TweenService:Create(buttonGradient, shineTF, shineGoal)
    local tweenIns = {}
    local tweenOuts = {}
    --Create base tweens
    table.insert(tweenIns, TweenService:Create(imageButton, buttonTF, buttonHoverGoal))
    table.insert(tweenOuts, TweenService:Create(imageButton, buttonTF, {Size = imageButton.Size}))
    table.insert(tweenIns, TweenService:Create(buttonStroke, buttonTF, {Thickness = 3}))
    table.insert(tweenOuts, TweenService:Create(buttonStroke, buttonTF, {Thickness = 0}))
    --Create custom tweens
    for _, buttonChild : GuiBase2d in pairs(imageButton:GetChildren()) do
        --See which children have tweens
        local goal = buttonChild:GetAttributes()
        if goal and next(goal) then
            --Get base values
            local baseValues = {}
            for propertyName, _ in pairs(goal) do
                --Set base values to current property value
                baseValues[propertyName] = buttonChild[propertyName]
            end
            --Create tweens
            table.insert(tweenIns, TweenService:Create(buttonChild, buttonTF, goal))
            table.insert(tweenOuts, TweenService:Create(buttonChild, buttonTF, baseValues))
        end
    end
    --Connect to hover tween completed
    shineTween.Completed:Connect(function()
        --Reset gradient
        buttonGradient.Offset = Vector2.new(-1, 0)
    end)
    --Connect activated event
    imageButton.Activated:Connect(function()
        --Play click
        QuickSound(clickSound)
        --Toggle popup
        togglePopup(designatedPopup)
        --Make sure the frame opened
        if popupFrame == designatedPopup and popupOpen then
            --Tween in
            tweenTable(tweenIns)
            --Set close tweens
            closeTweens = tweenOuts
        end
    end)
    --Connect hover event
    imageButton.MouseEnter:Connect(function()
        --Play shine animation
        shineTween:Play()
    end)
    --Create reference to toggle brightness
    nameToBrightness[buttonHolder.Name] = function(bright : boolean?)
        if bright then
            TweenAny:TweenSequence(buttonGradient, brightnessGoal, shineTF)
        else
            TweenAny:TweenSequence(buttonGradient, baseSequenceGoal, shineTF)
        end
    end
end

--Adjusts position and size of UI based on device
local function adjustGui(inputDevice : string)
    --Iterate through all variable gui
    for _, guiObject : GuiBase in pairs(variableGui) do
        --Get updated size and position
        local newSize : UDim2, newPosition : UDim2 = guiObject:GetAttribute(inputDevice.."_Size"), guiObject:GetAttribute(inputDevice.."_Position")
        --Update GUI position or set to default if none exists
        guiObject.Size = newSize or guiDefaults[guiObject].Size
        guiObject.Position = newPosition or guiDefaults[guiObject].Position
        --Update size and create size constraint or reset and remove size constraint
        if newSize then
            --Create size constraint
            local sizeConstraint : UISizeConstraint = Instance.new("UISizeConstraint")
            --Set size
            guiObject.Size = newSize
            --Set size constraint to be fixed at current size
            sizeConstraint.MinSize = guiObject.AbsoluteSize
            --Parent
            sizeConstraint.Parent = guiObject
            --Create reference
            constraints[guiObject] = sizeConstraint
        elseif constraints[guiObject] then
            --Remove size constraint
            constraints[guiObject]:Destroy()
            constraints[guiObject] = nil
        end
    end
end

---------------------// PRIVATE CODE \\--------------------

--Setup buttons
for _, buttonHolder in pairs(interfaceContainer:GetChildren()) do
    --Make sure this is a button holder and not something else
    if buttonHolder:IsA("Frame") then
        --Setup
        buttonSetup(buttonHolder)
    end
end

--Set moneyIncLabel to defaults
for propertyName : string, propertyValue in pairs(moneyOutGoal) do
    moneyIncLabel[propertyName] = propertyValue
end

--Connect to money animation change
moneySignal:Connect(updateMoney)

--Set moneyLabel text to initial value, without animation (elapsed = time so elapsed/time = 1, no animation)
updateMoney(moneyStat.Value) 

--Connect to changed
moneyStat.Changed:Connect(function()
    --Disconnect previous animation if active
    if connection and connection.Connected then
        connection:Disconnect()
    end
    --Initialize variables
    local goal = moneyStat.Value
    local difference = goal - lastValue
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
    --Tween money value
    TweenAny:TweenNumber(lastValue, goal, MONEY_ANIM_TIME, moneySignal)
    --Update last value
    lastValue = goal
end)

--Automatically tween out money increment after tweened in
moneyIncTweenIn.Completed:Connect(function()
    moneyIncTweenOut:Play()
end)

--Initialize GUI variations
for _, guiObject : GuiBase in pairs(interface:GetDescendants()) do
    --First check if this object has a Udim2 size
    if guiObject:IsA("GuiBase") then
        local attributes = guiObject:GetAttributes()
        --Look for an attribute with the suffix "Size" or "Position"indicating variation
        for attributeName, attributeValue in pairs(attributes) do
            if string.find(attributeName, "_Size") or string.find(attributeName, "_Position") then
                --Add to table of variations
                table.insert(variableGui, guiObject)
                --Set GUI defaults
                guiDefaults[guiObject] = {Size = guiObject.Size, Position = guiObject.Position}
                --Stop searching
                break
            end
        end

    end
end

--Adjust to initial device
if InputDetection.CurrentDevice then
    adjustGui(InputDetection.CurrentDevice)
end

--Connect to device changed
InputDetection.DeviceChanged:Connect(adjustGui)