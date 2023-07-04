--[[
This module stores reusable classes for GUI components.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--Modules
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))
local QuickTween = require(ReplicatedStorage:WaitForChild("QuickTween"))

--Tweens
local sliderTF = TweenInfo.new(0.1, Enum.EasingStyle.Linear)

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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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

-----------------------// MODULE \\------------------------

--Initialize returned module
local GUI = {}
--Return functions to create all classes
GUI.Slider = Slider.new

return GUI
