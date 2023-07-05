--[[
This module initializes a OOP ship replicator class to replicate client sided tasks regarding pirate ships.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    --Clean up destroy tasks
    table.clear(self.destroyTasks)
    --Clean up self
    table.clear(self)
    setmetatable(self, nil)
    table.freeze(self)
end

return ShipReplicator