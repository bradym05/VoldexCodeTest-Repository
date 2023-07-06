--[[
This module initializes an OOP ship class. The ship class is responsible for converting ships into physics assemblies, and only allowing the specified player to access them.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--Instances
local shipFolder : Folder = workspace:WaitForChild("Ships")
local planePart : Part = workspace:WaitForChild("ShipPlane")
local planeAttachment : Attachment = planePart:WaitForChild("Plane")

local remotes : Folder = ReplicatedStorage:WaitForChild("Remotes")
local dismountRemote : RemoteEvent = remotes:WaitForChild("Dismount")

--Settings
local MAX_FORCE = 14000000 --Maximum movement force, higher values result in higher responsiveness
local MAX_TORQUE = 2000000000 --Maximum turn force
local PARK_DISTANCE = 100 --Maximum distance in feet where ship is returned to tycoon when dismounted
local SHIP_SPEED = 25 --Speed in studs per second
local TURN_SPEED = 1 --Turning speed in studs per second
local EFFECT_VELOCITY = 8 --Velocity where visual effects are enabled or disabled

local VELOCITY_CHECKS = 3 --Required checks to calculate average velocity
local VELOCITY_CUSHION = 1.25 --Multiplied by SHIP_SPEED to determine maximum allowed velocity
local CHECK_RATE = 10 --How often checks are performed
local MAX_WARNINGS = 25 --Maximum warnings before ship is reset
local WARNING_EXPIRATION = 40 --How long each warning lasts

--Manipulated
local playerToShip = {}
local checkTime = 1/CHECK_RATE
local checkElapsed = 0

------------------// PRIVATE FUNCTIONS \\------------------

--Weld two parts together with a weld constraint
local function weldParts(part : BasePart, weldTo : BasePart) : boolean
    --Make sure parts are not destroyed, parts are not the same, and both are BaseParts before continuing (https://create.roblox.com/docs/reference/engine/classes/WeldConstraint)
    if part and part.Parent and weldTo and weldTo.Parent and part ~= weldTo and (part:IsA("BasePart") or part:IsA("MeshPart")) and (weldTo:IsA("BasePart") or weldTo:IsA("MeshPart")) then
        --Also check if a weld constraint or motor already, because some ship parts have WeldConstraints and Motor6Ds
        local weldConstraint
        if not part:FindFirstChildOfClass("Motor6D") and not part:FindFirstChildOfClass("WeldConstraint") then
            --Create weld constraint between both parts
            weldConstraint = Instance.new("WeldConstraint")
            weldConstraint.Part0 = weldTo
            weldConstraint.Part1 = part
            --Parent to the part being welded
            weldConstraint.Parent = part
        end
        --Return success and created constraint
        return true, weldConstraint
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
    angularVelocity.MaxTorque = MAX_TORQUE
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

--Handle requests to dismount ship
local function onDismountEvent(player : Player)
    --Get ship object
    local shipObject = playerToShip[player]
    --Check if ship exists and is mounted
    if shipObject and shipObject.mounted == true then
        --Call method for dismount
        shipObject:ToggleMount(false)
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
    --Initialize table of effects to activate on move and boolean to indicate if they are enabled
    self.moveEffects = {}
    self.effectsEnabled = false
    --Initialize total velocity and completed checks variable to calculate average velocity
    self.velocityTotal = 0
    self.checksCompleted = 0
    --Initialize warnings and reset cycle variable to measure suspicious activity
    self.warnings = 0
    self.resetCycle = 0
    --Initialize table of effects to activate on move

    setmetatable(self, Ship)

    --// INITIAL SETUP CODE \\--

    --Setup and parent ship model
    self.shipModel.Name = tostring(player.UserId)
    self.shipModel:SetAttribute("SHIP_SPEED", SHIP_SPEED)
    self.shipModel:SetAttribute("TURN_SPEED", TURN_SPEED)
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
    --Get all effects to activate on move
    for _, descendant : Instance in pairs(self.shipModel:GetDescendants()) do
        --Check if descendant is effect
        if descendant:GetAttribute("onMove") and descendant:IsA("ParticleEmitter") or descendant:IsA("Light") or descendant:IsA("Sound") then
            table.insert(self.moveEffects, descendant)
        end
    end
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
    --Reset ship and dismount
    self:Reset(true)
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
            --Weld character to ship and set mountWeld
            local _, mountWeld = weldParts(self.character.PrimaryPart, self.mountPart)
            self.mountWeld = mountWeld
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
        --Check proximity to tycoon
        if (self.rootPart.Position - self.baseCFrame.Position).Magnitude <= PARK_DISTANCE then
            --Reset ship since it is within parking distance
            self:Reset(false)
            --Pivot player with since ship has reset
            self.character:PivotTo(self.mountPart.CFrame + Vector3.new(0, 5, 0))
        end
    end
    --Set mounted to given toggle
    self.mounted = toggle
    --Update attribute
    self.shipModel:SetAttribute("Mounted", self.mounted)
end

--Reset ship
function Ship:Reset(dismount : boolean?)
    --Anchor root part to prevent movement
    self.rootPart.Anchored = true
    --Pivot ship to origin
    self.shipModel:PivotTo(self.baseCFrame)
    --Check if ship should also dismount
    if dismount then
        --Dismount
        self:ToggleMount(false)
    end
    --Clear assembly velocity
    for _, part : BasePart in pairs(self.shipModel:GetDescendants()) do
        --Check if part has velocity property
        if part:IsA("BasePart") or part:IsA("MeshPart") then
            --Clear velocities
            part.AssemblyAngularVelocity = Vector3.new()
            part.AssemblyLinearVelocity = Vector3.new()
        end
    end
end

--Toggle all visual effects
function Ship:ToggleEffects(toggle : boolean?)
    --Check that requested toggle is different from current toggle
    if toggle ~= self.effectsEnabled then
        --Set effects enabled to toggle
        self.effectsEnabled = toggle
        --Iterate through all effects
        for _, effect : ParticleEmitter | Light | Sound in pairs(self.moveEffects) do
            --Toggle by class
            if effect:IsA("ParticleEmitter") or effect:IsA("Light") then
                effect.Enabled = toggle
            elseif effect:IsA("Sound") then
                --Stop or play based on toggle
                if toggle == true then
                    effect:Play()
                else
                    effect:Stop()
                end
            end
        end
    end
end

--Adds a warning and determines if ship should be reset
function Ship:AddWarning()
    --Increment warnings
    self.warnings += 1
    --Check if max warnings is reached
    if self.warnings >= MAX_WARNINGS then
        --Reset warnings
        self.warnings = 0
        --Increment reset cycle
        self.resetCycle += 1
        --Reload player's character
        self.player:LoadCharacter()
    else
        --Store current reset cycle
        local currentCycle = self.resetCycle
        --Wait for set time
        task.delay(WARNING_EXPIRATION, function()
            --Remove warning if the cycle has not reset and ship is active
            if self and not table.isfrozen(self) and self.resetCycle == currentCycle then
                self.warnings -= 1
            end
        end)
    end
end

--Get velocity with change in time
function Ship:GetVelocity(deltaTime : number)
    --Check if last position is initialized
    if self.lastPosition then
        --Get change in distance
        local deltaDistance = (self.rootPart.Position - self.lastPosition).Magnitude
        --Calculate velocity and increment total
        self.velocityTotal += deltaDistance/deltaTime
        --Increment completed checks
        self.checksCompleted += 1
        --See if required checks have been completed
        if self.checksCompleted >= VELOCITY_CHECKS then
            --Calculate average velocity
            local averageVelocity = self.velocityTotal/self.checksCompleted
            --Reset variables
            self.velocityTotal = 0
            self.checksCompleted = 0
            --Check if calculated velocity is greater than maximum
            if averageVelocity > SHIP_SPEED * VELOCITY_CUSHION then
                self:AddWarning()
            end
            --Enable effects if they meet the EFFECT_VELOCITY setting, or disable
            self:ToggleEffects(averageVelocity >= EFFECT_VELOCITY)
        end
    end
    --Set last position to current position
    self.lastPosition = self.rootPart.Position
end

---------------------// PRIVATE CODE \\--------------------

--Connect to player removing
Players.PlayerRemoving:Connect(onPlayerRemoving)

--Connect to dismount requested
dismountRemote.OnServerEvent:Connect(onDismountEvent)

--Core heartbeat connection to calculate velocity
RunService.Heartbeat:Connect(function(deltaTime)
    --Increment time since last check
    checkElapsed += deltaTime
    --Check if enough time has passed to match set rate
    if checkElapsed >= checkTime then
        --Store elapsed time locally and reset
        local lastElapsed = checkElapsed
        checkElapsed = 0
        --Iterate over all ships
        for player : Player, shipObject in pairs(playerToShip) do
            --Make sure ship is active
            if shipObject and not table.isfrozen(shipObject) then
                --Call GetVelocity method with stored lastElapsed
                shipObject:GetVelocity(lastElapsed)
            else
                --Ship is inactive, remove reference
                playerToShip[player] = nil
            end
        end
    end
end)

return Ship
