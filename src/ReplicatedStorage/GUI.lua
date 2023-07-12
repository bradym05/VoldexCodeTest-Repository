--[[
This module stores reusable classes for GUI components.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

--Modules
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))
local QuickTween = require(ReplicatedStorage:WaitForChild("QuickTween"))
local QuickSound = require(ReplicatedStorage:WaitForChild("QuickSound"))

--Instances
local sounds : Folder = ReplicatedStorage:WaitForChild("Sounds")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local privateScreenGui : ScreenGui = Instance.new("ScreenGui")
local selectionFrame : Frame = Instance.new("Frame")
local selectionStroke : UIStroke = Instance.new("UIStroke")
local selectionCorner : UICorner = Instance.new("UICorner")

--Settings
local BUTTON_CLICK_IN : Sound = sounds:WaitForChild("SingleClick") --Sound played when a button is pressed
local BUTTON_CLICK_OUT : Sound = sounds:WaitForChild("ClickOut") --Sound played when button press ends

--Tweens
local sliderTF = TweenInfo.new(0.1, Enum.EasingStyle.Linear)
local buttonTF = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local selectionTF = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local selectionStrokeIn = TweenService:Create(selectionStroke, selectionTF, {Thickness = 2, Transparency = 0})
local selectionStrokeOut = TweenService:Create(selectionStroke, selectionTF, {Thickness = 0, Transparency = 1})

------------------// PRIVATE FUNCTIONS \\------------------

--Return true if input can be used to press a gui object
local function inputIsPress(inputObject : InputObject)
    return inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch
end

-----------------------// MODULE \\---------------------

local GUI = {
    LastTimestamp = 0,
    _connections = {}
}

--Parents selection stroke to the given object or disables if no object is given (timestamp is used for toggling after a delay in case overridden)
function GUI:Select(guiObject : GuiObject?, timestamp : number?, cornerRadius : UDim?)
    --Make sure background is visible so selection box is accurate (matches shape of the background)
    if guiObject and guiObject.BackgroundTransparency == 1 then return end
    --Reconcile timestamp
    timestamp = timestamp or os.clock()
    --Check if selection is being hidden
    if not guiObject then
        --Pause shortly in case another gui is selected quickly (for sliding animation)
        task.wait(0.05)
    end
    --Make sure this timestamp is the most recent
    if timestamp >= GUI.LastTimestamp then
        GUI.LastTimestamp = timestamp
        --Initialize variables
        local activeAnimations = {}
        --Disconnect all previous connections
        for _, connection : RBXScriptConnection in pairs(GUI._connections) do
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end
        table.clear(GUI._connections)
        --Determine if being toggled visible or invisible
        if guiObject and guiObject ~= GUI.ActiveSelection then
            --Convert abosolute size and position UDims to UDim2
            local goalPosition : UDim2, goalSize : UDim2 = UDim2.fromOffset(guiObject.AbsolutePosition.X,guiObject.AbsolutePosition.Y), UDim2.fromOffset(guiObject.AbsoluteSize.X, guiObject.AbsoluteSize.Y)
            --Check for ui corner if no radius is provided
            if not cornerRadius then
                local newCorner = guiObject:FindFirstChildOfClass("UICorner")
                cornerRadius = (newCorner and newCorner.CornerRadius) or nil
            end
            --Check if selection is already visible
            if not GUI.ActiveSelection then
                --Set stroke to fade in
                table.insert(activeAnimations, selectionStrokeIn)
                --Position and scale without tween
                selectionFrame.Position = goalPosition
                selectionFrame.Size = goalSize
                selectionCorner.CornerRadius = cornerRadius or UDim.new(0, 0)
            else
                --Reference objects to goals for animation
                activeAnimations[selectionFrame] = {Position = goalPosition, Size = goalSize}
                activeAnimations[selectionCorner] = {CornerRadius = cornerRadius or UDim.new(0, 0)}
            end
            --Connect to size and position changed
            local sizeConnection = guiObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                selectionFrame.Size = UDim2.fromOffset(guiObject.AbsoluteSize.X, guiObject.AbsoluteSize.Y)
            end)
            local posConnection = guiObject:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                selectionFrame.Position = UDim2.fromOffset(guiObject.AbsolutePosition.X,guiObject.AbsolutePosition.Y)
            end)
            --Add to connections table
            table.insert(self._connections, sizeConnection)
            table.insert(self._connections, posConnection)
        elseif GUI.ActiveSelection then
            --Set stroke to fade out
            table.insert(activeAnimations, selectionStrokeOut)
        end
        --Update active selection
        GUI.ActiveSelection = guiObject
        --Iterate over all active animations
        for object : Instance | number, tweenOrGoal : TweenBase | table in pairs(activeAnimations) do
           if typeof(object) == "Instance" and type(tweenOrGoal) == "table" then
                --Play one time animation
                QuickTween(object, selectionTF, tweenOrGoal)
                --Clear reference
                activeAnimations[object] = nil
            elseif typeof(tweenOrGoal) == "Instance" and tweenOrGoal:IsA("TweenBase") then
                --Play tween
                tweenOrGoal:Play()
            end
        end
        --Clear animation table and reference to it
        table.clear(activeAnimations)
        activeAnimations = nil
    end
end

--------------------// BUTTON CLASS \\---------------------

local Button = {}
Button.__index = Button

--Create new button object
function Button.new(base : GuiButton, callback : any?, doHighlight : boolean?)
    --Initialize variables
    local sizeIn = UDim2.new(base.Size.X.Scale * 0.95, 0, base.Size.Y.Scale * 0.95, 0) --Scale to 95% of original size when pressed
    local sizeOut = base.Size
    --Create object
    local self = {}
    --Initialize variables
    self.base = base
    self.callback = callback
    --Tweens
    self.tweenIn = TweenService:Create(base, buttonTF, {Size = sizeIn})
    self.tweenOut = TweenService:Create(base, buttonTF, {Size = sizeOut})
    --Connections table for GC
    self.connections = {}
    setmetatable(self, Button)
    --Check if highlighting is enabled (default is true)
    if doHighlight == nil or doHighlight == true then
        --Disable auto color
        base.AutoButtonColor = false
        --Connect to mouse entered
        local mouseEnter = base.MouseEnter:Connect(function()
            --Update timestamp and highlight
            self.timestamp = os.clock()
            GUI:Select(self.base, self.timestamp)
        end)
        --Connect to mouse left
        local mouseLeave = base.MouseLeave:Connect(function()
            --Deselect with timestamp
            GUI:Select(nil, self.timestamp)
        end)
        --Add connections to table for GC
        table.insert(self.connections, mouseEnter)
        table.insert(self.connections, mouseLeave)
    end
    --Connect to button press started
    local inputBegan = base.InputBegan:Connect(function(input)
        self:PressIn(input)
    end)
    --Connect to button press ended
    local inputEnded = base.InputEnded:Connect(function(input)
        self:PressOut(input)
    end)
    --Add connections to table for GC
    table.insert(self.connections, inputBegan)
    table.insert(self.connections, inputEnded)

    return self
end

--Clean up
function Button:Destroy()
    --Disconnect connections
    for _, connection : RBXScriptConnection in pairs(self.connections) do
        --Check if connection is connected
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    --Deselect if selected
    if GUI.ActiveSelection == self.base then
        GUI:Select(nil, self.timestamp)
    end
    --Destroy tweens
    self.tweenIn:Destroy()
    self.tweenOut:Destroy()
    --Clear self
    table.clear(self)
    setmetatable(self, nil)
    table.freeze(self)
end

--Click button in
function Button:PressIn(input : InputObject)
    --Determine if input is valid
    if inputIsPress(input) then
        --Set press input and timestamp
        self.pressInput = input
        self.timestamp = os.clock()
        --Play click sound
        QuickSound(BUTTON_CLICK_IN)
        --Play tween in
        self.tweenIn:Play()
    end
end

--Click button out
function Button:PressOut(input : InputObject)
    --Check if button is pressed and released input is pressed input
    if self.pressInput and self.pressInput == input then
        --Clear press input
        self.pressInput = nil
        --Play click sound
        QuickSound(BUTTON_CLICK_OUT)
        --Play tween out
        self.tweenOut:Play()
        --Check for callback
        if self.callback then
            --Run callback
            self.callback()
        end
    end
end

--------------------// SLIDER CLASS \\---------------------

local Slider = {}
Slider.__index = Slider

--Adds slider functionality to any ImageButton with a "Progress" frame
function Slider.new(base : ImageButton, progressBar : Frame)
    --Create object
    local self = {}
    --Manipulated
    self.value = 0
    --Min and max pos (anchor point X must be 0)
    self.minPos = base.AbsolutePosition.X
    self.maxPos = base.AbsoluteSize.X
    --Instances
    self.base = base
    self.progressBar = progressBar
    --Signals
    self.sliderChanged = CustomSignal.new()
    --Connections for GC
    self.connections = {}
    setmetatable(self, Slider)
    --Connect to input
    local inputBegan
    inputBegan = base.InputBegan:Connect(function(input : InputObject)
        --Determine if input is valid
        if inputIsPress(input) then
            --Update holding input
            self.holdInput = input
            --Update progress
            self:Update()
            --Connect to mouse movement and update
            self.changed = UserInputService.InputChanged:Connect(function()
                self:Update()
            end)
        end
    end)
    --Connect to input ended
    local inputEnded
    inputEnded = base.InputEnded:Connect(function(input)
        --Make sure ended input is the held input
        if self.holdInput and input.UserInputType == self.holdInput.UserInputType then
            --Clear holding input
            self.holdInput = nil
            --Disconnect changed from updating if connected
            if self.changed and self.changed.Connected then
                self.changed:Disconnect()
                self.changed = nil
            end
        end
    end)
    --Add to connections for GC
    table.insert(self.connections, inputBegan)
    table.insert(self.connections, inputEnded)
    return self
end

--Clean up
function Slider:Destroy()
    --Disconnect any active connections
    for _, connection : RBXScriptConnection in pairs(self.connections) do
        --Make sure connection is active
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    --Disconnect changed
    if self.changed and self.changed.Connected then
        self.changed:Disconnect()
    end
    --Clean up self
    table.clear(self)
    setmetatable(self, nil)
    table.freeze(self)
end

--Update slider value
function Slider:Update()
    --Get mouse X relative to slider UI
    local posX = UserInputService:GetMouseLocation().X - self.minPos
    --Get progress ratio between 0 and 1
    local progress = math.clamp(posX/self.maxPos, 0, 1)
    --Set value
    self:SetValue(progress)
end

--Set slider value
function Slider:SetValue(progress : number, noChange : boolean?)
    --Store last value
    local lastValue = self.value
    --Set value
    self.value = progress
    --Update appearance
    QuickTween(self.progressBar, sliderTF, {Size = UDim2.new(progress, 0, self.progressBar.Size.Y.Scale, 0)})
    --Fire changed if a change has occured
    if not noChange and progress ~= lastValue then
        self.sliderChanged:Fire(progress)
    end
end

---------------------// PRIVATE CODE \\--------------------

--Set up private ScreenGui
privateScreenGui.DisplayOrder = 9
privateScreenGui.IgnoreGuiInset = false
privateScreenGui.ResetOnSpawn = false
privateScreenGui.Parent = playerGui

--Set up selection frame
selectionFrame.BackgroundTransparency = 1
selectionFrame.BorderSizePixel = 0
selectionFrame.Visible = true
selectionFrame.Size = UDim2.new(0, 0, 0, 0)
selectionFrame.Parent = privateScreenGui

--Set up selection stroke
selectionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
selectionStroke.LineJoinMode = Enum.LineJoinMode.Round
selectionStroke.Thickness = 0
selectionStroke.Transparency = 1
selectionStroke.Color = Color3.new(1,1,1)
selectionStroke.Parent = selectionFrame

--Set up selection corner
selectionCorner.CornerRadius = UDim.new(0,0)
selectionCorner.Parent = selectionFrame

--Return functions to create all classes
GUI.Slider = Slider.new
GUI.Button = Button.new

return GUI
