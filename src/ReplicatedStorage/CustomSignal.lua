--[[
The custom signal class returns objects which mimic RBXScriptSignals. This was created for the PlayerData module to allow for external scripts to listen to changes in data.
This replaces the need to create BindableEvents and such for custom events.

The connection class adds the disconnect functionality to signals, the system is very simple but a cleaner approach to custom events.

--]]

------------------// PRIVATE FUNCTIONS \\------------------

--Convert arguments to a table safely to be stored as a variable (... can only be accessed from inside of its nested closure)
local function packArgs(...)
    --Converts tuple into a table without missing any values (like nil)
    return {n = select("#", ...), ...}
end

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

local Signal = {}
Signal.__index = Signal

--Signal creation
function Signal.new()
    local self = {}
    self.listeners = {} -- Holds all listener callback functions
    self._connections = {} -- Private connections for clean up
    setmetatable(self, Signal)
    return self
end

--Signal connection
function Signal:Connect(callback : any)
    --Connect to this Signal's listeners
    local connection = Connection.new(callback, self)
    --Add to connections
    table.insert(self._connections, connection)
    --Return connection
    return connection
end

--Connect and disconnect after fired
function Signal:Once(callback : any)
    --Initialize variables
    local connection
    --Connect to custom function
    connection = self:Connect(function(...)
        --Disconnect immediately
        connection:Disconnect()
        --Call callback
        callback(...)
    end)
    --Return connection
    return connection
end

--Connect via Once() and yield until fired
function Signal:Wait(maxTime : number)
    --Initialize variables
    local elapsed = 0
    local returnedTable
    --Connect a function to grab returned values
    self:Once(function(...)
        returnedTable = packArgs(...)
    end)
    --Yield until fired, disconnected, or max wait time has been reached
    repeat
        --Increment elapsed by change in time
        elapsed += task.wait()
    until returnedTable or (maxTime and elapsed >= maxTime) or not self or table.isfrozen(self)
    --Return original tuple or false if maximum wait exceeded
    return (returnedTable and unpack(returnedTable)) or false
end

--Fires all arguments to listeners
function Signal:Fire(...)
    --Loop through listeners
    for _, callback in pairs(self.listeners) do
        --Run
        task.spawn(callback, ...)
    end
end

--Fire signal and destroy immediately after
function Signal:FireOnce(...)
    --Fire
    self:Fire(...)
    --Destroy
    self:Destroy()
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