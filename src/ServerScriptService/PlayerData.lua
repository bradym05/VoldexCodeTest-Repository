--[[
This module initializes an OOP "PlayerData" class for ease of use. Each created object handles access to DataStores with security and loss prevention at the forefront.
See: https://devforum.roblox.com/t/details-on-datastoreservice-for-advanced-developers/175804

MessagingService is used for session locking, preventing data from saving on multiple servers. 

TODO:
Session locking

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")

--Current save
local SaveFile = DataStoreService:GetDataStore("Save123456")

--Unique server identifier
local serverCode = os.time()

--Settings
local RETRY_DELAY = 5
local MAX_RETRIES = 10
local CACHE_TIME = 5 -- IMPORTANT: VALUE MUST BE >= 4! Cache time in seconds for requests (currently only GetAsync)

--Manipulated
local requestCounts = {} -- {sent, pending}
local lastRequest = {}

------------------// PRIVATE FUNCTIONS \\------------------

--Convert arguments to a table safely to be stored as a variable (... can only be accessed from outside of its nested closure)
local function packArgs(...)
    --Converts tuple into a table without missing any values (like nil)
    return {n = select("#", ...), ...}
end

local function is_mixed(t)
    local arrayValues = 0 -- key value pairs
    local totalValues = 0 -- all values (including nil)
    -- ipairs iterates in order and will skip nil values
    for _ in ipairs(t) do 
        arrayValues += 1
    end
    -- pairs will catch all values including nil
    for _ in pairs(t) do 
        arrayValues += 1
    end
    --If key value pairs exist, and singular keys exist, return true
    return arrayValues > 0 and totalValues > arrayValues
end

--Checks if a value can be saved (Strings, numbers, booleans, and tables that are not mixed)
local function checkValue(returned)
    return type(returned) == "string" or 
        type(returned) == "number" or 
        type(returned) == "boolean" or 
        (type(returned) == "table" and not is_mixed(returned)) 
end

--Some of the DataStoreRequestType enums refer to multiple requests, translated here
local translatedRequests = {
    SetAsync = Enum.DataStoreRequestType.SetIncrementAsync,
    IncrementAsync = Enum.DataStoreRequestType.SetIncrementAsync,
}

--Error checks return true to retry, false to error (makes sure valid requests go through)
--The second return value determines is any budget was consumed (ex. invalid inputs consume no budget)
--Reference: https://create.roblox.com/docs/cloud-services/datastores#error-code-reference
local codeChecks = {
    ["101"] = function(key) -- Key name can't be empty
        return #key > 0, false
    end,
    ["102"] = function(key) -- Key name exceeds the 50 character limit.	
        return #key < 50, false
    end,
    ["103"] = function(_, returned) -- An invalid value of was returned by a bad update function.
        return checkValue(returned), false
    end,
    ["104"] = function(_, returned) -- A value returned by the update function did not serialize.
        return checkValue(returned), true
    end,
    ["105"] = function() -- Serialized value converted byte size exceeds max size 64*1024 bytes
        return false, true
    end,
    ["106"] = function(_, pageSize, min, max) -- MaxValue and MinValue are not integers or PageSize exceeded 100.
        return pageSize <= 100 and math.round(min) == min and math.round(max) == max, false
    end,
    ["404"] = function() -- The OrderedDataStore associated with this request has been removed.
        return false, true
    end,
    ["501"] = function() -- System is unable to parse value from response. Data may be corrupted.
        return false, true
    end,
    ["502"] = function() -- API Services rejected request, you may want to retry the request at a later time.
        return true, true
    end,
    ["503"] = function() -- DataStore Request successful, but key not found.	
        return false, true
    end,
    ["504"] = function() -- Data retrieved from GlobalDataStore was malformed. Data may be corrupted.
        return false, true
    end,
    ["505"] = function() -- Data retrieved from OrderedDataStore was malformed. Data may be corrupted.
        return false, true
    end,
    ["512"] = function() -- The caller provided too many user IDs in the user IDs array
        return false, true
    end,
    ["513"] = function() -- The user ID provided is not a number or the metadata is not a table.
        return false, true
    end
}

--When a request is dropped, it means the request has exceeded the maximum queue size so best practice is to yield one minute
--This is unlikely to happen due custom throttling
local function requestDropped()
    task.wait(65)
    return true, false
end
--Error codes 301 - 306 are dropped requests (handled the same) 
for i = 301,306 do codeChecks[tostring(i)] = requestDropped end

--Safely handles DataStoreService requests by determining the best course of action based on error codes
local function request(requestName : String, requestType : Enum.DataStoreRequestType, ...)
    --Store arguments for use in pcall
    local args = packArgs(...)
    --Check if this is a retry and get number of retries
    local retries = (args[#args - 1] and args[#args - 1] == "isRetry" and args[#args]) or 0
    --Initialize other variables
    local retry, budget = false, true
    --Make request
    local success, result = pcall(function()
        --Indexes string requestName to get function (SaveFile is a parameter because function is indexed)
        return SaveFile[requestName](SaveFile, unpack(args))
    end)
    --Handle errors
    if not success then
        retry, budget = (codeChecks[result] and codeChecks[result](...)) or true, false
    end
    --Increment sent requests (if budget was consumed)
    if budget then
        requestCounts[requestType][1] += 1 
    end
    --Return result if successful
    if success == true and result then
        return result
    elseif retries < MAX_RETRIES and retry then
        --Wait retry delay and return result (recursive)
        task.wait(RETRY_DELAY)
        return request(requestName, requestType, ..., "isRetry", retries + 1)
    else
        --Stop recursing and return false to indicate error
        return false
    end
end

--Ensures that DataStore requests stay within budget
--Although DataStoreService has its own throttling queue, there is a limit for the number of items in queue, which means data is lost when exceeded
--DataStoreService's request throttling also processes requests out of order, which is not ideal
function safeManage(requestName : String, ...)
    --Get request type
    local requestType = translatedRequests[requestName] or Enum.DataStoreRequestType[requestName]
    --Make sure request is valid before proceeding
    if requestType then
        --Check if references exist, or check if request limit has reset (once every minute)
        if not lastRequest[requestType] or os.clock() - lastRequest[requestType] >= 60 then
            --Reset
            lastRequest[requestType] = os.clock()
            --Create reference or reset sent requests
            if not requestCounts[requestType] then
                requestCounts[requestType] = {0, 0} -- {sent, pending}
            else
                requestCounts[requestType][1] = 0
            end
        end
        --Increment pending requests
        requestCounts[requestType][2] += 1
        --Get budget for this request
        local budget = DataStoreService:GetRequestBudgetForRequestType(requestType)
        --Check if current sent request count exceeds or equals budget
        if requestCounts[requestType][1] >= budget then
            --Account for pending requests (pending/budget = reset intervals until budget is respected)
            local additionalTime = 60 * math.floor(requestCounts[requestType][2]/budget)
            --Wait until budget resets (additional 5 seconds to be safe)
            task.wait(os.clock() - lastRequest[requestType] + additionalTime + 5)
        end
        --Return results
        return request(requestName, requestType, ...)
    end
end

------------------------// CLASS \\------------------------
local playerToData = {}

local DataObject = {
    TEMPLATE = {},
}
DataObject.__index = DataObject

function DataObject.new(Player : Player)
    --Create object and corresponding variables
    local self = {}
    self.Player = Player 
    self.Key = tostring(Player.UserId) -- Store in case player leaves before operation
    self.lastGet = os.clock() - CACHE_TIME -- Prevent unnecessary requests (subtract CACHE_TIME to allow for initial read)
    self.changed = false
    setmetatable(self, DataObject)
    --Call setup methods
    self:Read()
    --Reconcile data
    if not self.Data then
        self.Data = DataObject.TEMPLATE
    end
    --Methods yield, so make sure Player has not left
    if Player and Player:IsDescendantOf(Players) then
        --Create reference and return
        playerToData[Player] = self
        return self
    else
        --Clean up without saving
        self:Destroy(true)
        return false
    end
end

--Clean up
function DataObject:Destroy(dontSave : boolean)
    --Attempt save first
    if not dontSave then
        self:Update()
    end
    --Clean up self
    table.clear(self)
    setmetatable(self,nil)
    table.freeze(self)
end

--Get data from DataStore
function DataObject:Read() : boolean
    --Cache for CACHE_TIME seconds without updating (Roblox caches for 4 seconds so safeManage would falsely consume budget)
    if os.clock() - self.lastGet >= CACHE_TIME then
        --Temporarily set lastGet to a very high value to prevent requests during processing
        self.lastGet = os.clock() + 1000
        local result = safeManage("GetAsync", self.Key)
        --Check result
        if result then
            --Update lastGet and Data
            self.lastGet = os.clock()
            self.Data = result
            return true
        else
            --Request failed so there is no cache
            self.lastGet = os.clock() - CACHE_TIME
            return false
        end
    end
end

--Set data to DataStore
function DataObject:Update() : boolean
    --Make sure there is data to be saved
    if self.changed == true then
        --Set changed to false because data is syncing
        self.changed = false
        --Save
        local result = safeManage("SetAsync", self.Key, self.Data) ~= false
        --Revert changed to true if data was not saved
        self.changed = not result
        return result
    else
        return false
    end
end

--Get data from DataObject
function DataObject:GetData(key : String) : string | number | boolean | table
    return key and self.Data[key]
end

--Set data to DataObject
function DataObject:SetData(key : String, value : any) : boolean
    --Check if data is valid
    if checkValue(value) then
        --Indicate a change has occured
        self.changed = true
        --Set the value
        self.Data[key] = value
        return true
    else
        --Warn that data is not valid
        warn("The value: ", value, " cannot be saved.")
        return false
    end
end

--Increment number values
function DataObject:IncrementData(key : String, inc : number) : boolean
    --Get initial value
    local initialValue = self:GetData(key)
    --Check that value is a number
    if initialValue and type(initialValue) == "number" then
        --Set data to incremented value
        return self:SetData(key, initialValue + inc)
    end
    --Return false if check isn't passed
    return false
end

--Insert into table values
function DataObject:ArrayInsert(key : String, value : any) : boolean
    --Get initial value
    local inititalTable = self:GetData(key)
    --Check that value is a table
    if inititalTable and type(inititalTable) == "table" then
        --Set data to updated table
        table.insert(inititalTable, value)
        return self:SetData(key, inititalTable)
    end
    --Return false if check isn't passed
    return false
end

--Remove values from tables
function DataObject:ArrayRemove(key : String, value : any) : boolean
    --Get initial value
    local inititalTable = self:GetData(key)
    --Check that value is a table
    if inititalTable and type(inititalTable) == "table" then
        --Find value
        local foundIndex = table.find(inititalTable, value)
        --Check that value exists in table
        if foundIndex then
            --Set data to updated table
            return self:SetData(key, table.remove(inititalTable, foundIndex))
        end
    end
    --Return false if check isn't passed
    return false
end

---------------------// PRIVATE CODE \\--------------------

--Clean up on leave
Players.PlayerRemoving:Connect(function(Player : Player)
    if playerToData[Player] then
        playerToData[Player]:Destroy()
        playerToData[Player] = nil
    end
end)

--Save on close
game:BindToClose(function()
    for _, PlayerDataObject in pairs(playerToData) do
        task.spawn(PlayerDataObject.Update, PlayerDataObject) -- PlayerDataObject is needed as a parameter when indexing function
    end
end)

return DataObject