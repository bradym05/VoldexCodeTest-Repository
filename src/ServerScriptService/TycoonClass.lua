--[[
This module initializes an OOP Tycoon class for ease of use and organization. The Tycoon class handles appearance, related events, and loading data.
Pad dependencies must refer to the purchaseable building. Multiple pads may be dependent on the same object. Pad names do not matter.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

--Modules
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

--Instances
local tycoonsFolder = workspace:WaitForChild("Tycoons")
local tycoonBuildings = ServerStorage:WaitForChild("Buildings")
local tycoonTemplate = ServerStorage:WaitForChild("TycoonBase")
local priceLabelTemplate = ServerStorage:WaitForChild("PriceLabel")

--Settings
local TYCOON_DISTANCE = 300 --Studs between tycoons
local MAX_TYCOONS = 4 --Max tycoons per server

--Collision group name suffixes (prefix is UserId)
local characterGroupSuffix = "_Character"
local padsGroupSuffix = "_Pads"

--Manipulated
local availableSlots = {}
local cachedBuildings = {}
local tycoonQueue = {}
local paychecks = {}

------------------// PRIVATE FUNCTIONS \\------------------

--Translates cframes based on tycoon slot (stored as a function incase translation ever changes)
local function translateCFrame(originalCFrame : CFrame, slot : number) : CFrame
    --Calculate
    return originalCFrame + Vector3.new(0, 0, TYCOON_DISTANCE * slot)
end

--Safely gets the next available tycoon spot, yielding if necessary
local function getSlot()
    --Attempt to get slot
    local slot = next(availableSlots)
    --Determine if yielding is necessary
    if not slot then
        --Create event
        local onAvailable = Instance.new("BindableEvent")
        --Add to queue
        table.insert(tycoonQueue, onAvailable)
        --Wait for availability
        slot = onAvailable.Event:Wait()
        --Clean up
        onAvailable:Destroy()
    end
    return slot
end

---------------------// TYCOON CLASS \\-----------------------

local Tycoon = {}
Tycoon.__index = Tycoon

--Load tycoon with previously purchased objects
function Tycoon.new(Player : Player)
    --Create class object
    local self = {}
    self.Player = Player
    --Create a connections table for GC
    self.connections = {}
    --Create tycoon
    self.tycoonModel = tycoonTemplate:Clone()
    --Get DataObject
    self.DataObject = PlayerData.getDataObject(Player)
    --Create collision group names
    self.characterGroup = self.DataObject.Key..characterGroupSuffix
    self.padsGroup = self.DataObject.Key..padsGroupSuffix
    --Create reference to purchased folder for readability
    self.purchasedFolder = self.tycoonModel:WaitForChild("Purchased")
    --Create table to refer buildings to dependent pad(s)
    self.buildingToDependency = {}
    --Create folder to hold hidden pads
    self.padStorage = Instance.new("Folder")
    self.padStorage.Name = self.DataObject.Key.."_Storage"
    self.padStorage.Parent = game.ServerStorage
    setmetatable(self, Tycoon)

    --// INITIAL SETUP CODE \\--

    --Get first available slot
    self.slot = getSlot()
    --Remove slot because it is no longer available (if not received directly)
    local slotIndex = table.find(availableSlots, self.slot)
    if slotIndex then
        table.remove(availableSlots, slotIndex)
    end
    --Correctly position tycoon 
    self.tycoonModel:PivotTo(translateCFrame(self.tycoonModel:GetPivot(), self.slot))
    --Name tycoon to UserId and parent
    self.tycoonModel.Name = self.DataObject.Key
    self.tycoonModel.Parent = tycoonsFolder
    --Load purchased buildings (after pivot)
    self:Fulfill(self.DataObject:GetData("Purchased") or {}, false)
    --Initialize pads (after purchases have loaded)
    for _, Pad : Model in pairs(self.tycoonModel.Pads:GetChildren()) do
        self:PadSetup(Pad)
    end
    --Create collision groups and set collisions
    PhysicsService:RegisterCollisionGroup(self.characterGroup)
    PhysicsService:RegisterCollisionGroup(self.padsGroup)
    --Set character and pads to collide
    PhysicsService:CollisionGroupSetCollidable(self.characterGroup, self.padsGroup, true)
    --Make sure that pads can only collide with the character
    for _, otherGroupTable in pairs(PhysicsService:GetRegisteredCollisionGroups()) do
        --GetRegisteredCollisionGroups returns an array with group mask and name, get name
        local otherGroup = otherGroupTable.name
        --Check that this isn't the pads or character group
        if otherGroup ~= self.characterGroup and otherGroup ~= self.padsGroup then
            --Disable collisions with pads
            PhysicsService:CollisionGroupSetCollidable(self.padsGroup, otherGroup, false)
        end
    end
    --Initialize Paycheck Machince
    self:PaycheckSetup()
    --Set respawn location
    Player.RespawnLocation = self.tycoonModel.Essentials.SpawnLocation
    --Connect Tycoon:CharacterAdded() to Player.CharacterAdded
    local characterAddedConnection
    characterAddedConnection = Player.CharacterAdded:Connect(function(character : Model)
        self:CharacterAdded(character)
    end)
    --Add to connections for GC
    table.insert(self.connections, characterAddedConnection)
    --Make sure that the first character is moved and loaded
    task.spawn(function()
        --Get character model
        local character = Player.Character or Player.CharacterAdded:Wait()
        --Wait until character can be pivoted
        character:WaitForChild("HumanoidRootPart")
        --Move to spawn manually
        character:PivotTo(self.tycoonModel.Essentials.SpawnLocation.CFrame)
        --Load
        self:CharacterAdded(character)
    end)
    
    return self
end

--Clean up
function Tycoon:Destroy()
    --Remove from payout loop
    paychecks[self] = nil
    --Remove collision groups
    PhysicsService:UnregisterCollisionGroup(self.characterGroup)
    PhysicsService:UnregisterCollisionGroup(self.padsGroup)
    --Indicate slot availability
    if #tycoonQueue > 0 then
        --Notify
        tycoonQueue[1]:Fire(self.slot)
        --Remove from queue
        table.remove(tycoonQueue, 1)
    else
        table.insert(availableSlots, self.slot)
    end
    --Destroy tycoon instance
    self.tycoonModel:Destroy()
    self.tycoonModel = nil
    --Destroy pad storage folder
    self.padStorage:Destroy()
    self.padStorage = nil
    --Disconnect any active connections
    for _, connection : RBXScriptConnection in pairs(self.connections) do
        --Check that connection is active and disconnect
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    --Clean up tables with hard references
    table.clear(self.buildingToDependency)
    table.freeze(self.buildingToDependency)
    self.buildingToDependency = nil
    --Clean up self
    table.clear(self)
    setmetatable(self, nil)
    table.freeze(self)
end

--Set up paychecks and collection
function Tycoon:PaycheckSetup()
    --Initialize variables
    local paycheckMachine = self.tycoonModel:WaitForChild("PaycheckMachine")
    local moneyLabel = paycheckMachine:WaitForChild("Money_Info_Text"):WaitForChild("SurfaceGui"):WaitForChild("MoneyLabel")
    local touchPart = paycheckMachine:WaitForChild("PadComponents"):WaitForChild("Pad")
    local debounce = false
    --Set collision group of pad
    touchPart.CollisionGroup = self.padsGroup
    --Connect to touched
    local touched
    touched = touchPart.Touched:Connect(function()
        if not debounce then
            --Stop player from collecting paycheck more than once
            debounce = true
            --Increment player money by player money to collect
            self.DataObject:IncrementData("Money", self.DataObject:GetData("MoneyToCollect"))
            --Reset money to collect
            self.DataObject:SetData("MoneyToCollect", 0)
            --Allow next collection
            debounce = false
        end
    end)
    --Set initial appearance to initial money to collect
    moneyLabel.Text = "$ "..tostring(self.DataObject:GetData("MoneyToCollect"))
    --Set appearance when money to collect changes
    local collectChanged
    collectChanged = self.DataObject:ListenToChange("MoneyToCollect", function(newValue : number)
        moneyLabel.Text = "$ "..tostring(newValue)
    end)
    --Connect to core paycheck loop
    paychecks[self] = function()
        --Increment MoneyToCollect by Paycheck stat
        self.DataObject:IncrementData("MoneyToCollect", self.DataObject:GetData("Paycheck"))
    end
    --Add connections to local connections table for GC
    table.insert(self.connections, touched)
    table.insert(self.connections, collectChanged)
end

--Sets CollisionGroup of entire character securely
function Tycoon:CharacterAdded(character : Model)
    --Declare connection variables
    local descendantAddedConnection
    local removingConnection
    --Disconnect when character is removing
    removingConnection = self.Player.CharacterRemoving:Connect(function(removing : Model)
        --Make sure the removing character is the defined character
        if removing == character then
            --Disconnect
            removingConnection:Disconnect()
            descendantAddedConnection:Disconnect()
        end
    end)
    --Catch loaded parts
    for _, descendant in pairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.CollisionGroup = self.characterGroup
        end
    end
    --Catch parts which may still be loading
    descendantAddedConnection = character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            descendant.CollisionGroup = self.characterGroup
        end
    end)
end

--Pad functionality for purchases
function Tycoon:ActivatePad(Pad : Model, target : String)
    --Unhide pad
    Pad.Parent = self.tycoonModel.Pads
    --Initialize variables
    local price = Pad:GetAttribute("Price")
    local touchPart = Pad:WaitForChild("Pad")
    local debounce = false
    --Create price label
    local priceLabel = priceLabelTemplate:Clone()
    local priceText = priceLabel:WaitForChild("PriceFrame"):WaitForChild("PriceLabel")
    local titleText = priceLabel:WaitForChild("TitleLabel")
    --Display price, or "FREE" if price is 0
    if price == 0 then
        priceText.Text = "FREE"
    else
        priceText.Text = "$ "..tostring(price)
    end
    --Display object name and replace underscores with spaces
    titleText.Text = string.gsub(target, "_", " ")
    --Set parent
    priceLabel.Parent = touchPart
    --Set collision group to pads
    touchPart.CollisionGroup = self.padsGroup
    --Register purchase attempts (no need to check hit because only character can collide)
    local touched
    touched = touchPart.Touched:Connect(function()
        if not debounce then
            --Stop multiple purchase attempts
            debounce = true
            --Get money
            local money = self.DataObject:GetData("Money")
            --Check sufficient funds
            if money >= price then
                --No need to keep touched event connected
                touched:Disconnect()
                --Subtract price from player's money
                self.DataObject:IncrementData("Money", -price)
                --Save purchase
                self.DataObject:ArrayInsert("Purchased", target)
                --Destroy pad
                Pad:Destroy()
                --Fulfill purchase
                self:Fulfill(target)
            end
            --Allow retry
            debounce = false
        end
    end)
end

--Unlocks and activates pads when their dependency is added
function Tycoon:PadSetup(Pad : Model)
    --Initialize variables
    local target = Pad:GetAttribute("Target")
    local dependency = Pad:GetAttribute("Dependency")
    --Make sure this pad hasn't been purchased already
    if self.purchasedFolder:FindFirstChild(target) then
        --Remove pad
        Pad:Destroy()
        --Cancel setup
        return
    end
    --Check if dependency is purchased
    if not dependency or self.purchasedFolder:FindFirstChild(dependency) then
        self:ActivatePad(Pad, target)
    else
        --Hide pad
        Pad.Parent = self.padStorage
        --Check if dependency table exists
        if not self.buildingToDependency[dependency] then
            --Create table
            self.buildingToDependency[dependency] = {}
        end
        --Indicate that this pad is waiting for dependency to be built
        table.insert(self.buildingToDependency[dependency], Pad)
    end
end

--Fulfill purchases
function Tycoon:Fulfill(purchased : any)
    --Convert to table
    if type(purchased) ~= "table" then
        purchased = {purchased}
    end
    --Loop through new purchases
    for _, buildingName : String in pairs(purchased) do
        --Get cached building before using FindFirstChild (faster)
        local building = cachedBuildings[buildingName] or tycoonBuildings:FindFirstChild(buildingName)
        --Set cache
        if not cachedBuildings[buildingName] then
            cachedBuildings[buildingName] = building
        end
        --Create a copy
        building = building:Clone()
        --Position correctly and parent
        building:PivotTo(translateCFrame(building:GetPivot(), self.slot))
        building.Parent = self.purchasedFolder
        --Check for unlocked pads
        if self.buildingToDependency[buildingName] then
            --Active all unlocked pads
            for _, Pad : Model in pairs(self.buildingToDependency[buildingName]) do
                self:ActivatePad(Pad, Pad:GetAttribute("Target"))
            end
        end
    end
end

---------------------// PRIVATE CODE \\--------------------

--Set all slots to available
for i = 1, MAX_TYCOONS do
    table.insert(availableSlots, i)
end

--Interval paycheck loop
task.spawn(function()
    while true do
        task.wait(5)
        --Loop all payout functions at once instead of multiple loops
        for _, payoutFunction in pairs(paychecks) do
            payoutFunction()
        end
    end
end)

return Tycoon