--[[
This module initializes an OOP ship class. The ship class is responsible for converting ships into physics assemblies, and only allowing the specified player to access them.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Instances
local shipFolder : Folder = workspace:WaitForChild("Ships")
local remotes : Folder = ReplicatedStorage:WaitForChild("Remotes")

local planePart : Part = workspace:WaitForChild("ShipPlane")
local planeAttachment : Attachment = planePart:WaitForChild("Plane")

--Settings
local MAX_FORCE = 14000000 --Maximum acceleration force, higher values result in higher responsiveness
local SHIP_SPEED = 25 --Speed in studs per second of ships

--Manipulated
local playerToShip = {}

------------------// PRIVATE FUNCTIONS \\------------------

--Weld two parts together with a weld constraint
local function weldParts(part : BasePart, weldTo : BasePart) : boolean
    --Make sure parts are not destroyed, parts are not the same, and both are BaseParts before continuing (https://create.roblox.com/docs/reference/engine/classes/WeldConstraint)
    if part and part.Parent and weldTo and weldTo.Parent and part ~= weldTo and (part:IsA("BasePart") or part:IsA("MeshPart")) and (weldTo:IsA("BasePart") or weldTo:IsA("MeshPart")) then
        --Also check if a weld constraint or motor already, because some ship parts have WeldConstraints and Motor6Ds
        if not part:FindFirstChildOfClass("Motor6D") and not part:FindFirstChildOfClass("WeldConstraint") then
            --Create weld constraint between both parts
            local weldConstraint = Instance.new("WeldConstraint")
            weldConstraint.Part0 = weldTo
            weldConstraint.Part1 = part
            --Parent to the part being welded
            weldConstraint.Parent = part
        end
        --Return success
        return true
    end
    --Return false by default
    return false
end

--Weld descendants of an instance to given root part
local function weldAll(group : Instance, root : BasePart)
    --Iterate over all descendants of given group
    for _, descendant in pairs(group:GetDescendants()) do
        --Typecheck to make sure descendant can be welded. Check that descendant is not root.
        if (descendant:IsA("BasePart") or descendant:IsA("MeshPart")) and descendant ~= root then
            --Attempt to weld descendant to root
            local weldSuccess = weldParts(descendant, root)
            --Unanchor descendant if welded
            if weldSuccess then
                descendant.Anchored = false
            end
        end
    end
end

--Create actuators for ships with predetermined properties
local function CreateActuators(rootPart : Part) : LinearVelocity & AngularVelocity
    --Create and parent attachment for actuators
    local centralAttachment = Instance.new("Attachment")
    centralAttachment.Parent = rootPart
    --Create plane constraint to restrict movement
    local planeConstraint : PlaneConstraint = Instance.new("PlaneConstraint")
    planeConstraint.Attachment0 = planeAttachment
    planeConstraint.Attachment1 = centralAttachment
    planeConstraint.Parent = rootPart
    --Create and parent linear velocity actuator
    local linearVelocity : LinearVelocity = Instance.new("LinearVelocity")
    linearVelocity.Attachment0 = centralAttachment
    linearVelocity.MaxForce = MAX_FORCE
    linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    linearVelocity.VectorVelocity = Vector3.new()
    linearVelocity.Parent = rootPart
    --Create and parent angular velocity actuator
    local angularVelocity : AngularVelocity = Instance.new("AngularVelocity")
    angularVelocity.Attachment0 = centralAttachment
    angularVelocity.MaxTorque = MAX_FORCE * 100
    angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    angularVelocity.Parent = rootPart
    --Only return linear and angular velocity (attachment and plane constraint are constant)
    return angularVelocity, linearVelocity
end

--Create root parts for ships with predetermined properties
local function CreateRootPart(baseCFrame : CFrame) : Part
    local rootPart = Instance.new("Part")
    rootPart.Transparency = 1
    rootPart.Anchored = true
    rootPart.CanCollide = false
    rootPart.CanTouch = false
    rootPart.CanQuery = false
    rootPart.Name = "ShipRoot"
    rootPart.CFrame = baseCFrame
    return rootPart
end

--Clean up ship when player leaves
local function onPlayerRemoving(player : Player)
    --Get ship object and check if it exists
    local shipObject = playerToShip[player]
    if shipObject then
        --Call destroy method
        shipObject:Destroy()
    end
end

---------------------// SHIP CLASS \\----------------------

local Ship = {}
Ship.__index = Ship

--Create a ship for a player from a table of ship pieces
function Ship.new(player : Player, shipPieces : table)
    --Initialize object
    local self = {}
    --Initialize variables
    self.player = player
    self.instances = {}
    self.mounted = false
    --Create ship model
    self.shipModel = Instance.new("Model")
    --Initialize table of connections for GC in Destroy method
    self.connections = {}
    setmetatable(self, Ship)

    --// INITIAL SETUP CODE \\--

    --Name and parent ship model
    self.shipModel.Name = tostring(player.UserId)
    self.shipModel.Parent = shipFolder
    --Initialize "Mounted" attribute
    self.shipModel:SetAttribute("Mounted", false)
    --Parent all ship pieces to ship model
    for _, shipPiece : Model in pairs(shipPieces) do
        shipPiece.Parent = self.shipModel
    end
    --Get mount and prompt parts
    self.mountPart = self.shipModel.Steering_Wheel.MountPart
    self.promptPart = self.shipModel.Steering_Wheel.PromptPart
    --Store base CFrame after shipModel is loaded
    self.baseCFrame = self.shipModel:GetPivot()
    --Create root part and set CFrame to base CFrame
    self.rootPart = CreateRootPart(self.baseCFrame)
    --Set root part parent and make primary part
    self.rootPart.Parent = self.shipModel
    self.shipModel.PrimaryPart = self.rootPart
    --Add created instances to table of instances for clean up
    table.insert(self.instances, self.shipModel)
    --Weld ship pieces to root part
    weldAll(self.shipModel, self.rootPart)
    --Create and store actuators
    self.linearVelocity, self.angularVelocity = CreateActuators(self.rootPart)
    --Setup proximity prompt
    self:SetupPrompt()
    --Create reference
    playerToShip[player] = self
    return self
end

--Clean up ship and anything related
function Ship:Destroy()
    --Remove reference
    playerToShip[self.player] = nil
    --Destroy all instances
    for _, instance : Instance in pairs(self.instances) do
        instance:Destroy()
    end
    --Disconnect from character child added if connected
    if self.childAddedConnection and self.childAddedConnection.Connected then
        self.childAddedConnection:Disconnect()
    end
    --Disconnect other connections
    for _, connection : RBXScriptConnection in pairs(self.connections) do
        --Make sure connection is connected
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    --Clean up table of connections
    table.clear(self.connections)
    --Clean up self
    table.clear(self)
    setmetatable(self, nil)
    table.freeze(self)
end

--Setup steering request proximity prompt
function Ship:SetupPrompt()
    --Check if prompt exists first
    if not self.prompt then
        --Create prompt
        self.prompt = Instance.new("ProximityPrompt")
        self.prompt.ObjectText = "Flying Ship"
        self.prompt.ActionText = "Steer"
        self.prompt.Name = "SteerPrompt"
        self.prompt.RequiresLineOfSight = false
        self.prompt.HoldDuration = 0.5
        self.prompt.Enabled = true
        self.prompt.Parent = self.promptPart
        --Register prompt triggered
        local promptTriggered
        promptTriggered = self.prompt.Triggered:Connect(function(playerWhoTriggered)
            --Validate request
            if playerWhoTriggered == self.player and not self.mounted then
                --Mount player
                self:ToggleMount(true)
            end
        end)
        --Add to table of connections for GC
        table.insert(self.connections, promptTriggered)
    end
end

--Update loaded character to respect ship state
function Ship:CharacterLoaded()
    --Mount new character if previously mounted
    self:ToggleMount(self.mounted)
end

--Set current character (MUST BE CALLED EXTERNALLY)
function Ship:SetCharacter(character : Model)
    --Clear references from previous character
    self.mountWeld = nil
    --Update character variable
    self.character = character
    --Update character loaded variable
    self.characterLoaded = character ~= nil
    --Update humanoid
    self.humanoid = character:FindFirstChild("Humanoid")
    --Disconnect from character child added if connected
    if self.childAddedConnection and self.childAddedConnection.Connected then
        self.childAddedConnection:Disconnect()
    end
    --Get humanoid or primary part if either has not loaded
    if not self.humanoid or not self.characterLoaded then
        --Connect to child added and set variable
        self.childAddedConnection = self.character.ChildAdded:Connect(function(child : Instance)
            --Update variables depending on what was added
            if child:IsA("Humanoid") then
                self.humanoid = child
            elseif self.character.PrimaryPart ~= nil then
                self.characterLoaded = true
            end
            --Check if connection is still needed, disconnect and clear reference if not
            if self.characterLoaded and self.humanoid then
                self.childAddedConnection:Disconnect()
                self.childAddedConnection = nil
            end
        end)
    end
end

--Mount or dismount ship
function Ship:ToggleMount(toggle : boolean?)
    --Make ship moveable or anchored
    self.rootPart.Anchored = not toggle
    --Mount player if toggled true
    if toggle then
        --Disable prompt while mounted
        self.prompt.Enabled = false
        --Move character to mount part and weld if character has loaded
        if self.characterLoaded then
            --Get half of character's height for pivoting
            local yIncrement : number = self.humanoid.HipHeight + self.character.PrimaryPart.Size.Y/2
            --Pivot to mount CFrame + half of characters height to line up player with ground
            self.character:PivotTo(self.mountPart.CFrame + Vector3.new(0, yIncrement, 0))
            weldParts(self.character.PrimaryPart, self.mountPart) 
        end
        --Check if ship has already been mounted
        if self.mounted ~= toggle then
            --Give control to the player
            self.rootPart:SetNetworkOwner(self.player)
        end
    else
        --Remove weld and reference if created
        if self.mountWeld then
            self.mountWeld:Destroy()
            self.mountWeld = nil
        end
        --Enable prompt
        self.prompt.Enabled = true
    end
    --Set mounted to given toggle
    self.mounted = toggle
    --Update attribute
    self.shipModel:SetAttribute("Mounted", self.mounted)
end

--Reset ship
function Ship:Reset()
    --Dismount
    self:ToggleMount(false)
    --Anchor root part to prevent movement
    self.rootPart.Anchored = true
    --Pivot ship to origin
    self.shipModel:PivotTo(self.baseCFrame)
end

---------------------// PRIVATE CODE \\--------------------

--Connect to player removing
Players.PlayerRemoving:Connect(onPlayerRemoving)

return Ship