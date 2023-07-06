--[[
This module is a subclass of ShipReplicator which performs additional setup and methods to add functionality to the local player's pirate ship.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--Modules
local ShipReplicator = require(ReplicatedStorage:WaitForChild("ShipReplicator"))
local QuickSound = require(ReplicatedStorage:WaitForChild("QuickSound"))
local UserInputService = game:GetService("UserInputService")

--Instances
local player : Player = Players.LocalPlayer
local playerGui : PlayerGui = player:WaitForChild("PlayerGui")
local mainInterface : ScreenGui = playerGui:WaitForChild("MainInterface")
local dismountInfo : TextLabel = mainInterface:WaitForChild("DismountInfo")

local steerAnimationsFolder : Folder = ReplicatedStorage:WaitForChild("SteerAnimations")
local steerIdle : Animation = steerAnimationsFolder:WaitForChild("SteerIdle")
local steerRight : Animation = steerAnimationsFolder:WaitForChild("SteerRight")
local steerLeft : Animation = steerAnimationsFolder:WaitForChild("SteerLeft")
local steerAnimations : table = steerAnimationsFolder:GetChildren()

local remotes : Folder = ReplicatedStorage:WaitForChild("Remotes")
local dismountRemote : RemoteEvent = remotes:WaitForChild("Dismount")

local sounds : Folder = ReplicatedStorage:WaitForChild("Sounds")
local swishSoundIn : Sound = sounds:WaitForChild("SwishIn")
local swishSoundOut : Sound = sounds:WaitForChild("SwishOut")

--Settings
local STEER_INPUTS = { --Inputs which can steer the ship
    --Keyboard inputs
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.D,
    Enum.KeyCode.Up,
    Enum.KeyCode.Left,
    Enum.KeyCode.Right,
    --Mobile input
    Enum.UserInputType.Touch,
}
local DIRECTION_MAP = { --Map of keycode names to directions (-1 = left | 0 = forward | 1 = right)
    --Keyboard inputs
    W = 0,
    A = -1,
    D = 1,
}

--Tween settings
local dismountInfoTF = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)
local dismountInfoTweenIn = TweenService:Create(dismountInfo, dismountInfoTF, {Position = UDim2.new(0.5, 0, 0.05, 0)})
local dismountInfoTweenOut = TweenService:Create(dismountInfo, dismountInfoTF, {Position = UDim2.new(0.5, 0, -0.5, 0)})

--Manipulated
local shipIndex = 0
local idToShip = {}
local steerPrefix = "Steer_"

------------------// PRIVATE FUNCTIONS \\------------------

--Callback function for ContextActionService
local function handleSteering(actionName : string, inputState: Enum.UserInputState, inputObject : InputObject)
    --Isolate ship Id using string.gsub
    local shipId = string.gsub(actionName, steerPrefix, "")
    --Check if this action is steering and ship is active
    if shipId and idToShip[shipId] and not table.isfrozen(idToShip[shipId]) then
        --Call ship's :Steer() method
        idToShip[shipId]:Steer(inputState, inputObject)
        --Indicate that action was handled
        return Enum.ContextActionResult.Sink
    else
        --Indicate that action was not handled
        return Enum.ContextActionResult.Pass
    end
end

----------------// PLAYER SHIP CLASS \\----------------------

local PlayerShip = {}
PlayerShip.__index = PlayerShip
--Set superclass
setmetatable(PlayerShip, ShipReplicator)

--Setup a player owned ship
function PlayerShip.new(shipModel : Model)
    --Create object and inherit superclass
    local self = ShipReplicator.new(shipModel)
    --Initialize variable to indicate if steering
    self.steering = false
    --Initialize animation dictionary
    self.animations = {}
    --Initialize active directions and direction variable
    self.activeDirections = 0
    self.directionTotal = 0
    --Initialize table of Motor6Ds to activate when moving
    self.movementMotors = {}
    self.motorsActive = false
    --Get turn and move speed from ship model
    self.moveSpeed = shipModel:GetAttribute("SHIP_SPEED")
    self.turnSpeed = shipModel:GetAttribute("TURN_SPEED")
    setmetatable(self, PlayerShip)

    --// INITIAL SETUP CODE \\--

    --Add custom destroy task to inherited :Destroy() method
    table.insert(self.destroyTasks, {Callback = self._destroy, Parameters = {self}})
    --Enable steering prompt
    self.prompt.Enabled = true
    --Get unique ship Id and update shipIndex
    shipIndex += 1
    self.shipId = tostring(shipIndex)
    --Create reference
    idToShip[self.shipId] = self
    --Iterate over all descendants
    for _, descendant : Instance in pairs(shipModel:GetDescendants()) do
        --Check what type of instance this is and reference accordingly
        if descendant:IsA("Motor6D") and descendant:GetAttribute("MoveVelocity")  then
            --Reference motor to velocity
            self.movementMotors[descendant] = descendant:GetAttribute("MoveVelocity")
        end
    end
    --Listen to ship mount/dismount
    local mountAttributeChanged
    mountAttributeChanged = shipModel:GetAttributeChangedSignal("Mounted"):Connect(function()
        --Call ToggleMount method
        self:ToggleMount(shipModel:GetAttribute("Mounted"))
    end)
    --Setup first character
    self:CharacterAdded(player.Character or player.CharacterAdded:Wait())
    --Listen to character added
    local characterAddedConnection
    characterAddedConnection = player.CharacterAdded:Connect(function(character)
        --Call character added method
        self:CharacterAdded(character)
    end)
    --Listen to jump request
    local jumpRequestConnection
    jumpRequestConnection = UserInputService.JumpRequest:Connect(function()
        --Call request dismount method
        self:RequestDismount()
    end)
    --Add connections to table of connections for GC
    table.insert(self.connections, mountAttributeChanged)
    table.insert(self.connections, characterAddedConnection)
    table.insert(self.connections, jumpRequestConnection)
    return self
end

--Clean up player ship and anything related (private)
function PlayerShip._destroy(self)
    --Clear reference
    idToShip[self.shipId] = nil
    --Clear animation dictionary
    self:_clearDictionary(self.animations)
    --Clear motor dictionary
    self:_clearDictionary(self.movementMotors)
    --Unbind steering action
    self:BindSteer(false)
    --Disconnect child added connection if connected
    if self.childAddedConnection and self.childAddedConnection.Connected then
        self.childAddedConnection:Disconnect()
        self.childAddedConnection = nil
    end
    --Clean up self
    table.clear(self)
    table.freeze(self)
    setmetatable(self, nil)
end

--Setup the player's character and update references
function PlayerShip:CharacterAdded(character : Model)
    --Disconnect previous child added connection if connected
    if self.childAddedConnection and self.childAddedConnection.Connected then
        self.childAddedConnection:Disconnect()
        self.childAddedConnection = nil
    end
    --Clear animation tracks
    self:_clearDictionary(self.animations)
    --Update character reference
    self.character = character
    --Update humanoid reference
    self.humanoid = character:FindFirstChild("Humanoid")
    --Check if humanoid has loaded
    if not self.humanoid then
        --Connect to ChildAdded to detect humanoid loaded and reference connection
        self.childAddedConnection = self.character.ChildAdded:Connect(function(child : Instance)
            --Check if this is the humanoid
            if child:IsA("Humanoid") then
                --Update humanoid reference and disconnect
                self.humanoid = child
                self.childAddedConnection:Disconnect()
                self.childAddedConnection = nil
                --Load animations
                self:LoadAnimations(self.humanoid:WaitForChild("Animator"))
            end
        end)
    else
        --Load animations
        self:LoadAnimations(self.humanoid:WaitForChild("Animator"))
    end
end

--Loads animations onto given animator and references tracks in dictionary
function PlayerShip:LoadAnimations(animator : Animator)
    --Iterate over all steering animations
    for _, animation : Animation in pairs(steerAnimations) do
        --Create reference from object to track
        self.animations[animation] = animator:LoadAnimation(animation)
    end
end

--Method to enable or disable Motor6D animations
function PlayerShip:ToggleMotors(toggle : boolean?)
    --Make sure the requested toggle is not the current toggle
    if toggle ~= self.motorsActive then
        --Set motors active
        self.motorsActive = toggle
        --Loop through all motor-moveSpeed pairs
        for motor : Motor6D, moveSpeed in pairs(self.movementMotors) do
            --Set speed to given speed or set to 0 if toggle is false
            motor.MaxVelocity = (toggle and moveSpeed) or 0
        end
    end
end

--Handle steering input
function PlayerShip:Steer(inputState : Enum.UserInputState, inputObject : InputObject)
    --Get direction increment if input object has a keycode
    local directionIncrement = inputObject.KeyCode and DIRECTION_MAP[inputObject.KeyCode.Name]
    --Check if direction is mapped
    if directionIncrement then
        --Check input states
        if inputState == Enum.UserInputState.Begin then
            --Increment active directions
            self.activeDirections += 1
        else
            --Decrement active directions
            self.activeDirections -= 1
            --Reverse sign
            directionIncrement *= -1
        end
        --Add direction increment to total
        self.directionTotal += directionIncrement
    end
    --Check if moving
    if self.activeDirections > 0 then
        --Move forward at set ship speed
        self.linearVelocity.VectorVelocity = Vector3.new(0, 0, self.moveSpeed)
        --Enable motor animations
        self:ToggleMotors(true)
        --Check if turning
        if math.abs(self.directionTotal) > 0 then
            --Get direction average
            local directionAverage = self.directionTotal/self.activeDirections
            --Set angular velocity and wheel angle to rotate based on move direction
            self.angularVelocity.AngularVelocity = Vector3.new(0, -directionAverage * self.turnSpeed, 0)
            self.turnMotor.DesiredAngle = -directionAverage/2
            --Get turn animation from sign
            local turnAnimation = (self.directionTotal > 0 and steerRight) or (self.directionTotal < 0 and steerLeft)
            --Check if current animation is different from turn animation
            if self.currentTurn ~= turnAnimation then
                --Stop current turn track if playing
                if self.currentTurn then
                    self.animations[self.currentTurn]:Stop()
                end
                --Play new animation and set current turn animation
                self.currentTurn = turnAnimation
                self.animations[turnAnimation]:Play()
            end
        else
            --Set angular velocity and wheel angle to 0
            self.angularVelocity.AngularVelocity = Vector3.new()
            self.turnMotor.DesiredAngle = 0
            --Stop current turn track if playing
            if self.currentTurn then
                self.animations[self.currentTurn]:Stop()
            end
            --Remove reference to current turn animation
            self.currentTurn = nil
        end
    else
        --Set velocity to 0
        self.linearVelocity.VectorVelocity = Vector3.new()
        self.angularVelocity.AngularVelocity = Vector3.new()
        --Disable motor animations
        self:ToggleMotors(false)
    end
end

--Connect player input to steer ship
function PlayerShip:BindSteer(toggle : boolean?)
    if toggle then
        --Bind steering to CAS with set inputs
        ContextActionService:BindAction(steerPrefix..self.shipId, handleSteering, false, unpack(STEER_INPUTS))
    else
        --Unbind steering
        ContextActionService:UnbindAction(steerPrefix..self.shipId)
    end
end

--Method to handle ship mounting and dismounting
function PlayerShip:ToggleMount(toggle : boolean?)
    --Bind steering inputs from toggle
    self:BindSteer(toggle)
    --Check toggle
    if toggle then
        --Get idle track
        local idleTrack : AnimationTrack = self.animations[steerIdle]
        --Check if it exists and is not playing
        if idleTrack and not idleTrack.IsPlaying then
            idleTrack:Play()
        end
        --Update states
        self.humanoid.PlatformStand = true
        --Tween in dismount info
        dismountInfoTweenIn:Play()
        QuickSound(swishSoundIn)
    else
        --Iterate over all loaded tracks
        for _, track : AnimationTrack in pairs(self.animations) do
            --Stop playing
            track:Stop()
        end
        --Remove reference to current turn
        self.currentTurn = nil
        --Update states
        self.humanoid.PlatformStand = false
        --Disable motor animations
        self:ToggleMotors(false)
        --Tween out dismount info
        dismountInfoTweenOut:Play()
        QuickSound(swishSoundOut)
    end
end

--Method to request that the server dismounts the player
function PlayerShip:RequestDismount()
    --Check if ship is mounted
    if self.shipModel:GetAttribute("Mounted") == true then
        --Request dismount
        dismountRemote:FireServer()
    end
end

return PlayerShip