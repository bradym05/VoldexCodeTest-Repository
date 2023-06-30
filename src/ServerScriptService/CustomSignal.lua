--[[
The custom signal class returns objects which mimic RBXScriptSignals. This was created for the PlayerData module to allow for external scripts to listen to changes in data.
This replaces the need to create BindableEvents and such for custom events.

The connection class adds the disconnect functionality to signals, the system is very simple but a cleaner approach to custom events.

--]]

----------------------// CONNECTION \\-----------------------
local Connection = {}
Connection.__index = Connection

--Takes the callback function and table of listeners to join
function Connection.new(callback : any, signalObject : any)
    local self = {}
    --Store for disconnect method
    self.callback = callback
    self.signalObject = signalObject
    --Connect
    table.insert(signalObject.listeners, callback)
    setmetatable(self, Connection)
    return self
end

--Clean up
function Connection:Disconnect()
    --Check if connection is connected
    local index = table.find(self.signalObject.listeners, self.callback)
    if index then
        --Remove from signal
        table.remove(self.signalObject.listeners, index)
    end
    --Remove from signal's active connection
    local refIndex = table.find(self.signalObject._connections, self)
    if refIndex then
        --Remove from signal
        table.remove(self.signalObject._connections, refIndex)
    end
    --Clean up local connection
    self.callback = nil
    table.clear(self)
    setmetatable(self, nil)
    table.freeze(self)
end

------------------------// SIGNAL \\------------------------

local Signal = {
    listeners = {}, -- Holds all listener callback functions
    _connections = {}, -- Private connections for clean up
}
Signal.__index = Signal

--Signal creation
function Signal.new()
    local self = {}
    setmetatable(self, Signal)
    return self
end

--Signal connection
function Signal:Connect(callback : any)
    --Connect to this Signal's listeners
    local connection = Connection.new(callback, Signal)
    --Add to connections
    table.insert(self._connections, connection)
    --return connection
    return connection
end

--Fires all arguments to listeners
function Signal:Fire(...)
    --Loop through listeners
    for _, callback in pairs(self.listeners) do
        --Run
        task.spawn(callback, ...)
    end
end

--Clean up
function Signal:Destroy()
    --Disconnect all
    for _, connection in pairs(self._connections) do
        --Make sure connection is not already disconnected
        if connection and not table.isfrozen(connection) then
            connection:Disconnect()
        end
    end
    --Clear
    table.clear(self._connections)
    --Clean up signal
    table.clear(self)
    setmetatable(self, nil)
    table.freeze(self)
end

return Signal