--------// VARIABLES \\--------

--Services
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")

--Modules
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

--Instances
local tycoonFolder = workspace:WaitForChild("Tycoons")
local tycoonBase = ServerStorage:WaitForChild("TycoonBase")
local buildingsFolder = ServerStorage:WaitForChild("Buildings")

--Other
local available = {1,2,3,4}
local cached = {}
local playerToTycoon = {}
local tycoonDistance = 300

----// PRVIATE FUNCTIONS \\----

local function descendantAdded(descendant, collisionGroup : String)
    --Make sure descendant has collisions
    if descendant and descendant:IsA("BasePart") then
        descendant.CollisionGroup = collisionGroup
    end
end

--Set collision group of models (or folders) which may change
local function setModelCollisions(base : Model, collisionGroup : String)
    --Register loaded parts' collision groups
     for _, descendant in pairs(base:GetDescendants()) do
        descendantAdded(descendant, collisionGroup)
    end
    --Register unloaded parts and return connection for GC
    return base.DescendantAdded:Connect(function(descendant) descendantAdded(descendant, collisionGroup) end)
end

local function getBuildingModel(buildingName : String)
    --Get base building from cache or find in folder
    local building = cached[buildingName] or buildingsFolder:FindFirstChild(buildingName)
    --Cache building if not already cached
    if not cached[buildingName] then
        cached[buildingName] = building
    end
    --Clone to preserve base building
    return building:Clone()
end

--------// PAD CLASS \\-------

local PadClass = {}
PadClass.__index = PadClass

--Main pad creation function
function PadClass.new(base : Model, Player : Player)
    --Load class
    local self = {}
    self.dependency = base:GetAttribute("Dependency")
    self.target = base:GetAttribute("Target")
    self.price = base:GetAttribute("Price") or 0
    self.base = base
    self.Player = Player
    self.connections = {}
    setmetatable(self, PadClass)
    --Register purchase attempts
    local touchPart = base:WaitForChild("Pad")
    local debounce = false
    local touchedConnection
    --No need for checking hit origin because of custom collisions
    touchedConnection = touchPart.Touched:Connect(function()
        if not debounce then
            --Stop simultaneous purchase attempts
            debounce = true
            --Run purchase function
            self:Purchase()
            --Reset
            debounce = false
        end
    end)
    --Ensure connection is GCed
    table.insert(self.connections, touchedConnection)
    return self
end

--Purchase handler
function PadClass:Purchase()
    local TycoonObject = playerToTycoon[self.Player]
    local DataObject = TycoonObject.DataObject
    local money = DataObject:GetData("Money")
    --Check funds and dependency
    if money >= self.price then
        --Subtract price from player's money
        DataObject:IncrementData("Money", -self.price)
        --Save purchase
        DataObject:ArrayInsert("Purchased", self.target)
        --Fulfill
        local model = getBuildingModel(self.target)
        model:PivotTo(model:GetPivot() + Vector3.new(0,0, tycoonDistance * TycoonObject.slot))
        model.Parent = TycoonObject.tycoon.Purchased
        --Destroy
        self:Destroy()
    end
end

--Easy cleanup
function PadClass:Destroy()
    --Delete instance
    self.base:Destroy()
    --Disconnect active connections
    for _, connection : RBXScriptConnection in pairs(self.connections) do
        --Check that connection is active to avoid errors
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    --Clean up metatable
    table.clear(self)
    setmetatable(self,nil)
    table.freeze(self)
end

-------// TYCOON CLASS \\------
local TycoonClass = {}
TycoonClass.__index = TycoonClass

--Main tycoon creation function
function TycoonClass.new(Player : Player, DataObject)
    --Get data
    local loaded = DataObject:GetData("Purchased")
    --Get tycoon slot and set to unavailable
    local slot = next(available)
    table.remove(available, table.find(available, slot))
    --Declarations
    local pads = {}
    local stringId = tostring(Player.UserId)
    local padsId = stringId.."Pads"
    --Create tycoon
    local tycoon = tycoonBase:Clone()
    local zPos = tycoonDistance * slot -- tycoonDistance studs between tycoons
    local essentials = tycoonBase:WaitForChild("Essentials")
    local spawnLocation = essentials:WaitForChild("SpawnLocation")
    --Set tycoon properties
    tycoon.Name = tostring(Player.UserId)
    tycoon:PivotTo(tycoon:GetPivot() + Vector3.new(0,0,zPos))
    --Set player's spawn location
    Player.RespawnLocation = spawnLocation
    --Create collision groups
    PhysicsService:RegisterCollisionGroup(stringId)
    PhysicsService:RegisterCollisionGroup(padsId)
    --Make character and pads collideable
    PhysicsService:CollisionGroupSetCollidable(stringId, padsId, true)
    --Make pads and default uncollidable
    PhysicsService:CollisionGroupSetCollidable("Default", padsId, false)

    --Load buildings and pads
    for _, pad in pairs(tycoon.Pads:GetChildren()) do
        --Set collisions
        setModelCollisions(pad, padsId)
        --Get base info
        local target = pad:GetAttribute("Target")
        --Check if purchased
        local purchased = table.find(loaded, target)
        if purchased then
            --Parent building and remove pad
            local model = getBuildingModel(target)
            model:PivotTo(model:GetPivot() + Vector3.new(0,0, zPos))
            model.Parent = tycoon.Purchased
            pad:Destroy()
        else
            --Initialize pad
            table.insert(pads, PadClass.new(pad, Player))
        end
    end
    --Load class
    local self = {}
    self.tycoon = tycoon
    self.pads = pads
    self.stringId = stringId
    self.DataObject = DataObject
    self.connections = {}
    self.purchasedRemote = Instance.new("RemoteEvent")
    self.slot = slot
    self.Player = Player
    setmetatable(self, TycoonClass)
    --Parent instances
    self.purchasedRemote.Parent = tycoon
    tycoon.Parent = tycoonFolder
    --Catch character if already loaded
    if Player.Character then
        Player.Character:PivotTo(spawnLocation.CFrame)
        self:CharacterAdded(Player.Character)
    end
    --Connect to CharacterAdded
    local addedConnection
    addedConnection = Player.CharacterAdded:Connect(function(char)
        self:CharacterAdded(char)
    end)
    --Make sure connection is GCed
    table.insert(self.connections, addedConnection)
    --Create reference
    playerToTycoon[Player] = self
    return self
end

--Set characters to collide with pads
function TycoonClass:CharacterAdded(char)
    --Check if other DescendantAdded connection is active and disconnect
    if self.descendantAddedConnection and self.descendantAddedConnection.Connected then
        self.descendantAddedConnection:Disconnect()
    end
    --Update connection and register collisions
    self.descendantAddedConnection = setModelCollisions(char, self.stringId)
end

--Easy cleanup
function TycoonClass:Destroy()
    --Remove reference
    playerToTycoon[self.Player] = nil
    --Set slot as available
    table.insert(available, self.slot)
    --Unregister collision groups
    PhysicsService:UnregisterCollisionGroup(self.stringId)
    PhysicsService:UnregisterCollisionGroup(self.stringId.."Pads")
    --Disconnect special case connections
    if self.descendantAddedConnection and self.descendantAddedConnection.Connected then
        self.descendantAddedConnection:Disconnect()
    end
    --Disconnect active connections
    for _, connection : RBXScriptConnection in pairs(self.connections) do
        --Check that connection is active to avoid errors
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    --Destroy remaining pad objects
    for _, pad in pairs(self.pads) do
        --Make sure pad is active
        if pad and not table.isfrozen(pad) then
            pad:Destroy()
        end
    end
    --Destroy tycoon model
    self.tycoon:Destroy()
    --Clean up metatable
    table.clear(self)
    setmetatable(self,nil)
    table.freeze(self)
end

return TycoonClass