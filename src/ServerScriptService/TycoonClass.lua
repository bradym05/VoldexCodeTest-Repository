--[[
This module initializes an OOP Tycoon class for ease of use and organization. The Tycoon class handles appearance, related events, and loading data.
Pad dependencies must refer to the purchaseable building. Multiple pads may be dependent on the same object. Pad names do not matter.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Modules
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local ShipClass = require(ServerScriptService:WaitForChild("ShipClass"))
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))

--Instances
local tycoonsFolder : Folder = workspace:WaitForChild("Tycoons")
local tycoonBuildings : Folder = ServerStorage:WaitForChild("Buildings")
local tycoonTemplate : Model = ServerStorage:WaitForChild("TycoonBase")
local priceLabelTemplate : BillboardGui = ServerStorage:WaitForChild("PriceLabel")
local remotes : Folder = ReplicatedStorage:WaitForChild("Remotes")
local padTouchedRemote : RemoteEvent = remotes:WaitForChild("PadTouched")

local remotes : Folder = ReplicatedStorage:WaitForChild("Remotes")
local ticketRemote : RemoteEvent = remotes:WaitForChild("TicketClaimed")

--Settings
local TYCOON_ANGLE = 45 --Angle between tycoons (in degrees)
local CIRCLE_RADIUS = 300 --Radius of tycoon "circle"
local MAX_TYCOONS = 5 --Max tycoons per server
local PAYOUT_INTERVAL = 1 --Seconds between payouts
local PAD_COOLDOWN = 1 --Cooldown time in seconds between registering pad touched

--Collision group name suffixes (prefix is UserId)
local characterGroupSuffix = "_Character"
local padsGroupSuffix = "_Pads"

--Manipulated
local availableSlots = {}
local cachedBuildings = {}
local tycoonQueue = {}
local paychecks = {}
local allBuildings = tycoonBuildings:GetChildren()
local requiredShip = 0
local totalBuildings = #allBuildings

------------------// PRIVATE FUNCTIONS \\------------------

--Translates cframes based on tycoon slot (stored as a function incase translation ever changes)
local function translateCFrame(originalCFrame : CFrame, slot : number) : CFrame
    --Increment the angle of each tycoon by TYCOON_ANGLE (starting at 0 degrees)
    local angleIncrement = (slot - 1) * TYCOON_ANGLE
    --Cosine(theta) = adjacent/hypotenuse, therefore; adjacent = cosine(theta) * hypotenuse.
    local zIncrement = math.cos(angleIncrement) * CIRCLE_RADIUS
    --Sin(theta) = opposite/hypotenuse, therefore; opposite = sin(theta) * hypotenuse
    local xIncrement = math.sin(angleIncrement) * CIRCLE_RADIUS
    --Calculate position along "circle" of tycoons, rotate 90 degrees extra to face inwards
    return originalCFrame * CFrame.Angles(0, math.rad(angleIncrement) + math.rad(90), 0) + Vector3.new(xIncrement, 0, zIncrement)
end

--Safely gets the next available tycoon spot, yielding if necessary
local function getSlot()
    --Attempt to get slot
    local index, slot = next(availableSlots)
    --Determine if yielding is necessary
    if not slot then
        --Create event
        local onAvailable = CustomSignal.new()
        --Add to queue
        table.insert(tycoonQueue, onAvailable)
        --Wait for availability
        slot = onAvailable:Wait()
        --Clean up
        onAvailable:Destroy()
    else
        --Remove slot
        table.remove(availableSlots, index)
    end
    return slot
end

--Sets collisions of group to only one collision group, or disables collisions with all if no group is provided
local function setCollisionGroupExclusive(exclusiveGroupName : string, collideWithName : string?)
    --Iterate over all registered groups
    for _, otherGroupTable : table in pairs(PhysicsService:GetRegisteredCollisionGroups()) do
        --GetRegisteredCollisionGroups returns an array with group mask and name, get name
        local otherGroupName : string = otherGroupTable.name
        --Make sure this is not the provided group
        if otherGroupName and otherGroupName ~= exclusiveGroupName then
            --Disable collisions with exclusive group
            PhysicsService:CollisionGroupSetCollidable(exclusiveGroupName, otherGroupName, false)
        end
    end
    --Check if a group was provided
    if collideWithName then
        --Enable collisions
        PhysicsService:CollisionGroupSetCollidable(exclusiveGroupName, collideWithName, true)
    end
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
    --Initialize ship pieces table
    self.shipPieces = {}
    --Initialize loaded variable
    self.loaded = false
    setmetatable(self, Tycoon)

    --// INITIAL SETUP CODE \\--

    --Get first available slot
    self.slot = getSlot()
    --getSlot() function may yield, check if player left
    if Player and Player:IsDescendantOf(Players) then
        --Correctly position tycoon
        self.tycoonModel:PivotTo(translateCFrame(self.tycoonModel:GetPivot(), self.slot))
        --Name tycoon to UserId and parent
        self.tycoonModel.Name = self.DataObject.Key
        self.tycoonModel.Parent = tycoonsFolder
        --Load purchased buildings (after pivot)
        self:Fulfill(self.DataObject:GetData("Purchased") or {})
        --Initialize pads after purchases have loaded (for dependencies)
        for _, Pad : Model in pairs(self.tycoonModel.Pads:GetChildren()) do
            self:PadSetup(Pad)
        end
        --Set loaded variable to true now that pads and purchases are loaded
        self.loaded = true
        --Call check ship method after loading (ship pieces are reparented which can cause incorrect dependency checks)
        self:CheckShip()
        --Create collision groups and set collisions
        PhysicsService:RegisterCollisionGroup(self.characterGroup)
        PhysicsService:RegisterCollisionGroup(self.padsGroup)
        --Set pads to only collide with character
        setCollisionGroupExclusive(self.padsGroup, self.characterGroup)
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
        --Load first character
        Player:LoadCharacter()
        return self
    else
        --Player left the game, destroy tycoon and cancel setup
        self:Destroy()
        return
     end
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
        tycoonQueue[1]:FireOnce(self.slot)
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
    table.clear(self.shipPieces)
    self.shipPieces = nil
    --Remove reference to ship object
    self.shipObject = nil
    --Clean up self
    table.clear(self)
    setmetatable(self, nil)
    --Prevent any methods from calling and indicate tycoon is inactive
    table.freeze(self)
end

--Checks if conditions are met to unlock ship and creates ship object
function Tycoon:CheckShip()
    --Check if all ship pieces are purchased, and tycoon is loaded to keep dependencies accurate. Make sure ship is not already created. Make sure player has claimed ticket.
    if self.loaded and not self.shipObject and self.DataObject:GetData("Ticket") == true and #self.shipPieces >= requiredShip then
        --Create ship object
        self.shipObject = ShipClass.new(self.Player, self.shipPieces)
        --Set character of ship object if loaded
        if self.character then
            self.shipObject:SetCharacter(self.character)
        end
    end
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
            --Tell player to animate press
            padTouchedRemote:FireClient(self.Player, paycheckMachine, false, true)
            --Cooldown time
            task.wait(PAD_COOLDOWN)
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
    --Update character variable
    self.character = character
    --Set ship object character if created
    if self.shipObject then
        self.shipObject:SetCharacter(character)
    end
    --Disconnect when character is removing
    removingConnection = self.Player.CharacterRemoving:Connect(function(removing : Model)
        --Make sure the removing character is the defined character
        if removing == character then
            --Disconnect
            removingConnection:Disconnect()
            descendantAddedConnection:Disconnect()
        end
    end)
    --Load new character if player dies
    character:WaitForChild("Humanoid").Died:Once(function()
        self.Player:LoadCharacter()
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
function Tycoon:ActivatePad(Pad : Model, target : string)
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
                --Tell player to animate pad purchase
                padTouchedRemote:FireClient(self.Player, Pad, true)
                --Subtract price from player's money
                self.DataObject:IncrementData("Money", -price)
                --Save purchase
                self.DataObject:ArrayInsert("Purchased", target)
                --Destroy pad after 5 seconds to give player time to animate
                task.delay(5, function()
                    Pad:Destroy()
                end)
                --Fulfill purchase
                self:Fulfill(target)
            else
                --Tell player to animate pad purchase failed
                padTouchedRemote:FireClient(self.Player, Pad, false)
                --Cooldown time
                task.wait(PAD_COOLDOWN)
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
    local requiresAll = Pad:GetAttribute("RequiresAll")
    --Make sure this pad hasn't been purchased already
    if self.purchasedFolder:FindFirstChild(target) then
        --Remove pad
        Pad:Destroy()
        --Cancel setup
        return
    end
    --Check if requires all other buildings
    if requiresAll then
        --Get total purchased
        local purchasedTotal = #self.purchasedFolder:GetChildren()
        --Check if all other buildings are purchased
        if purchasedTotal >= totalBuildings then
            self:ActivatePad(Pad, target)
        else
            --Hide pad
            Pad.Parent = self.padStorage
            --Create table if not already created
            if not self.requiresAll then
                self.requiresAll = {}
            end
            --Indicate that this pad is waiting for all other buildings
            table.insert(self.requiresAll, Pad)
        end
    else
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
end

--Sets up ticket cabin
function Tycoon:TicketCabinSetup(cabin : Model)
    --Make sure player has not already claimed their ticket
    if self.DataObject:GetData("Ticket") == false then
        --Get prompt part
        local promptPart : BasePart = cabin:WaitForChild("PromptPart")
        --Create proximity prompt
        local ticketPrompt : ProximityPrompt = Instance.new("ProximityPrompt")
        ticketPrompt.ObjectText = "Ticket Cabin"
        ticketPrompt.ActionText = "Claim Ticket"
        ticketPrompt.RequiresLineOfSight = false
        ticketPrompt.HoldDuration = 1
        ticketPrompt.Parent = promptPart
        --Listen to prompt triggered
        local promptTriggered
        promptTriggered = ticketPrompt.Triggered:Connect(function(playerWhoTriggered)
            --Check that owner of tycoon triggered prompt
            if playerWhoTriggered == self.Player then
                --Disconnect and destroy prompt
                promptTriggered:Disconnect()
                ticketPrompt:Destroy()
                --Grant ticket
                self.DataObject:SetData("Ticket", true)
                --Tell player they have received their ticket
                ticketRemote:FireClient(self.Player)
                --Check ship
                self:CheckShip()
            end
        end)
        --Add to table of connects for gc
        table.insert(self.connections, promptTriggered)
    end
end

--Fulfill purchases
function Tycoon:Fulfill(purchased : any)
    --Convert to table
    if type(purchased) ~= "table" then
        purchased = {purchased}
    end
    --Loop through new purchases
    for _, buildingName : string in pairs(purchased) do
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
        --Check if this is a part of the ship
        if building:GetAttribute("Ship") then
            --Update table of ship pieces
            table.insert(self.shipPieces, building)
            --Check ship
            self:CheckShip()
        end
        --Check if this is the ticket cabin
        if buildingName == "Ticket_Cabin" then
            --Setup ticket cabin
            self:TicketCabinSetup(building)
        end
        --Check if enough buildings have been purchased to unlock pads that require all
        if self.requiresAll and #self.purchasedFolder:GetChildren() >= totalBuildings and #self.requiresAll > 0 then
            --Activate pads
            for _, unlockedPad : Model in pairs(self.requiresAll) do
                self:ActivatePad(unlockedPad, unlockedPad:GetAttribute("Target"))
            end
            --Clear table
            table.clear(self.requiresAll)
            --Remove reference
            self.requiresAll = nil
        end
    end
end

---------------------// PRIVATE CODE \\--------------------

--Set all slots to available
for i = 1, MAX_TYCOONS do
    table.insert(availableSlots, i)
end

--Set pivot of all buildings to tycoon base for correct positioning
for _, building : Model in pairs(tycoonBuildings:GetChildren()) do
    --Make sure this is a valid building
    if building:IsA("Model") then
        --Set pivot
        building.WorldPivot = tycoonTemplate.WorldPivot
        --Set descendant count
        building:SetAttribute("DescendantCount", #building:GetDescendants())
        --Check if this is a ship part
        if building:GetAttribute("Ship") then
            --Update number of required ship pieces
            requiredShip += 1
        end
    end
end

--Loop through pads to set total buildings count
for _, Pad : Model in pairs(tycoonTemplate.Pads:GetChildren()) do
    --Check if pad requires all
    if Pad:GetAttribute("RequiresAll") then
        --Remove from total
        totalBuildings -= 1
    end
end

--Interval paycheck loop
task.spawn(function()
    while true do
        task.wait(PAYOUT_INTERVAL)
        --Loop all payout functions at once instead of multiple loops
        for _, payoutFunction in pairs(paychecks) do
            payoutFunction()
        end
    end
end)

return Tycoon