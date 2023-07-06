--[[
This module initializes a OOP ship replicator class to replicate client sided tasks regarding pirate ships.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--Modules
local QuickTween = require(ReplicatedStorage:WaitForChild("QuickTween"))

--Instances
local player : Player = Players.LocalPlayer

local settingsFolder : Folder = player:WaitForChild("Settings")
local particleSetting : NumberValue = settingsFolder:WaitForChild("Particles")

--Tween Settings
local fadeTF = TweenInfo.new(0.5, Enum.EasingStyle.Linear)

--Manipulated
local setupFunctions = {}

------------------// PRIVATE FUNCTIONS \\------------------

--Setup particle effects
setupFunctions["ParticleEmitter"] = function(particleEmitter : ParticleEmitter)
    --Get base value
    local baseValue = particleEmitter.Rate
    --Connect to emitter enabled
    local emitterEnabled
    emitterEnabled = particleEmitter:GetPropertyChangedSignal("Enabled"):Connect(function()
        --Check if emitter is enabled
        if particleEmitter.Enabled == true then
            --Set rate of emitter to its base rate multiplied times the particle setting
            particleEmitter.Rate = baseValue * particleSetting.Value
        end
    end)
    --Set initial rate
    particleEmitter.Rate = baseValue * particleSetting.Value
    --Return connections
    return {emitterEnabled}
end

--Setup sound effects
setupFunctions["Sound"] = function(soundObject : Sound)
    --Get base value
    local baseValue = soundObject.Volume
    --Connect to sound played
    local played
    played = soundObject.Played:Connect(function()
        --Fade in
        QuickTween(soundObject, fadeTF, {Volume = baseValue})
    end)
    --Connect to sound stopped
    local stopped
    stopped = soundObject.Stopped:Connect(function()
        --Mute volume
        soundObject.Volume = 0
    end)
    --Mute sound if not playing
    if not soundObject.Playing then
        soundObject.Volume = 0
    end
    --Return connections
    return {played, stopped}
end

--Setup lights
setupFunctions["PointLight"] = function(light : Light)
    --Get base value
    local baseValue = light.Brightness
    --Connect to light enabled
    local enabled
    enabled = light:GetPropertyChangedSignal("Enabled"):Connect(function()
        if light.Enabled == true then
            --Fade in
            QuickTween(light, fadeTF, {Brightness = baseValue})
        else
            --Set brightness to 0
            light.Brightness = 0
        end
    end)
    --Set brightness to 0 if light is disabled
    if not light.Enabled then
        light.Brightness = 0
    end
    --Return connections
    return {enabled}
end

----------------// SHIP REPLICATOR CLASS \\-----------------

local ShipReplicator = {}
ShipReplicator.__index = ShipReplicator

--Create new replicator
function ShipReplicator.new(shipModel : Model)
    --Initialize temporary local variables for setup
    local steeringWheel : Model = shipModel:WaitForChild("Steering_Wheel")
    local promptPart : Part = steeringWheel:WaitForChild("PromptPart")
    local turnPart : Part = steeringWheel:WaitForChild("Wheel"):WaitForChild("Handles")
    --Create object
    local self = {}
    --Initialize instance variables
    self.shipModel = shipModel
    self.turnMotor = turnPart:WaitForChild("WheelMotor")
    self.prompt = promptPart:WaitForChild("SteerPrompt")
    self.rootPart = shipModel:WaitForChild("ShipRoot")
    self.linearVelocity = self.rootPart:WaitForChild("LinearVelocity")
    self.angularVelocity = self.rootPart:WaitForChild("AngularVelocity")
    --Initialize table of destroy tasks to add external tasks to :Destroy() method
    self.destroyTasks = {} -- {Callback = function, Parameters = table}
    --Initialize table of connections for GC
    self.connections = {}
    setmetatable(self, ShipReplicator)

    --// INITIAL SETUP CODE \\--

    --Disable steering prompt
    self.prompt.Enabled = false
    --Iterate over all descendants and setup effects
    for _, descendant : Instance in pairs(shipModel:GetDescendants()) do
        --Get instance type
        local instanceType = descendant.ClassName
        --Check for function
        if setupFunctions[instanceType] then
            --Call setup function and get connections
            local effectConnections : table = setupFunctions[instanceType](descendant)
            --Add connections to table for GC
            for _, connection in pairs(effectConnections) do
                table.insert(self.connections, connection)
            end
        end
    end
    return self
end

--Clean up ship replicator and anything related
function ShipReplicator:Destroy()
    --Call all destroy tasks if any
    for _, destroyTaskTable : table in pairs(self.destroyTasks) do
        --Make sure this can be called
        if destroyTaskTable.Callback and type(destroyTaskTable.Callback) == "function" then
            --Call destroy task with given parameters
            destroyTaskTable.Callback(unpack(destroyTaskTable.Parameters or {}))
            --Clear parameters if provided
            if destroyTaskTable.Parameters then
                table.clear(destroyTaskTable.Parameters)
            end
            --Clean up destroy table
            destroyTaskTable.Callback = nil
            destroyTaskTable.Parameters = nil
            table.clear(destroyTaskTable)
        end
    end
    --Clean up connections
    for _, connection : RBXScriptConnection in pairs(self.connections) do
        --Check if connection is connected and disconnect
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    --Clear connections table
    table.clear(self.connections)
    --Clear destroy tasks
    table.clear(self.destroyTasks)
    --Clean up self
    table.clear(self)
    setmetatable(self, nil)
    table.freeze(self)
end

--Private method to clear dictionaries
function ShipReplicator:_clearDictionary(dict : table)
    --Set all keys to nil
    for key, _ in pairs(dict) do
        dict[key] = nil
    end
end

return ShipReplicator