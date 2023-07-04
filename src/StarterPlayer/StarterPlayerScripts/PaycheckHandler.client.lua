------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--Modules
local TweenAny = require(ReplicatedStorage:WaitForChild("TweenAny"))
local QuickTween = require(ReplicatedStorage:WaitForChild("QuickTween"))
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))

--Instances
local player : Player = Players.LocalPlayer
local hiddenstats : Folder = player:WaitForChild("hiddenstats")
local paycheckStat : IntValue = hiddenstats:WaitForChild("Paycheck")

local playerGui : PlayerGui = player:WaitForChild("PlayerGui")
local mainInterface : Frame = playerGui:WaitForChild("MainInterface")
local popup : Frame = mainInterface:WaitForChild("Popup")
local paycheckFrame : Frame = popup:WaitForChild("Container"):WaitForChild("Paycheck")
local paycheckValueLabel : TextLabel = paycheckFrame:WaitForChild("PaycheckValue")
local shineGradient : UIGradient = paycheckValueLabel:WaitForChild("UIGradient")
local viewport : ViewportFrame = paycheckFrame:WaitForChild("PaycheckViewport")

local assets : Folder = ReplicatedStorage:WaitForChild("Assets")
local coinTemplate : MeshPart = assets:WaitForChild("Coin")
local coinPile : MeshPart = assets:WaitForChild("CoinPile"):Clone()

local sounds : Folder = ReplicatedStorage:WaitForChild("Sounds")
local coinSounds : table = sounds:WaitForChild("Coins"):GetChildren()

--Settings
local CAMERA_ANGLE = 20 --Camera angle (in degrees) specifying the amount to look down by
local CAMERA_DISTANCE = 10 --Camera distance from coin pile
local FOV = 15 --Base camera field of view
local PAYCHECK_PER_COIN = 10 --Minimum paycheck increment for one coin
local ANIM_TIME = 1.5 --Time for pile to scale in seconds and camera to adjust (coins fall in half this time)

--Tween Settings
local shineTF = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local shineTween = TweenService:Create(shineGradient, shineTF, {Offset = Vector2.new(1, 0)})

local cameraTF = TweenInfo.new(ANIM_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

--Manipulated
local shineLooping = false
local viewportCamera = Instance.new("Camera")
local lastPaycheck = paycheckStat.Value
local paycheckLerpSignal = CustomSignal.new()
local minPos : Vector3
local maxPos : Vector3
local pileScale : number

------------------// PRIVATE FUNCTIONS \\------------------

--Move camera based on settings and pile size
local function setCamera(animate : boolean?)
    --Scale fov to zoom in or out based on model size
    local adjustedFOV = FOV * pileScale
    --Get camera height from angle and distance
    local height = math.asin(math.rad(CAMERA_ANGLE)) * CAMERA_DISTANCE
    --Set CFrame to match angle and distance and look at the coin pile
    local cameraCFrame = CFrame.new(Vector3.new(0, height, CAMERA_DISTANCE), coinPile:GetPivot().Position)
    --Set camera
    if animate then
        QuickTween(viewportCamera, cameraTF, {["FieldOfView"] = adjustedFOV, ["CFrame"] = cameraCFrame})
    else
        viewportCamera.CFrame = cameraCFrame
        viewportCamera.FieldOfView = adjustedFOV
    end
end

--Scale pile of coins based on paycheck
local function setPile(animate : boolean?)
    --Get pile size
    pileScale = (paycheckStat.Value/PAYCHECK_PER_COIN)/10
    --Get half of pile size for min and max pos
    local halfSize = (coinPile.Pile.Size * pileScale)/2
    local pilePosition = coinPile:GetPivot().Position
    --Set min and max pos
    minPos = pilePosition - halfSize
    maxPos = pilePosition + halfSize
    --Scale pile
    if animate then
        TweenAny:TweenModel(coinPile, pileScale, ANIM_TIME)
    else
        coinPile:ScaleTo(pileScale)
    end
end

--Drop a coin
local function dropCoins(count : number)
    --Create given number of coins
    for i = 1, count do
        --Clone coin model
        local coin = coinTemplate:Clone()
        --Adjust size for visibility
        coin.Size *= math.clamp(pileScale, 1, math.huge)
        --Calculate random position above coin pile
        local position = Vector3.new(
            math.random(minPos.X, maxPos.X), --Get random x between min and max x
            maxPos.Y + 15, --Move 15 studs above top of pile
            math.random(minPos.Z, maxPos.Z) --Get random z between min and max z
        )
        --Move coin to position with random orientation
        coin.CFrame = CFrame.Angles(math.rad(math.random(0,360)),math.rad(math.random(0,360)),math.rad(math.random(0,360))) + position
        --Make coin visible
        coin.Parent = viewport
        --Play fall animation with random delay and connect to tween completed to destroy coin
        QuickTween(coin,
            TweenInfo.new(ANIM_TIME/2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, math.random(0,ANIM_TIME * 50)/100), --Tween info with random delay between 0 and half of anim time (max time would be anim time)
            {["CFrame"] = coin.CFrame * CFrame.Angles(math.rad(math.random(0,360)),math.rad(math.random(0,360)),math.rad(math.random(0,360))) - Vector3.new(0, (20 * pileScale), 0)}):Once(function() --Fall down with random orientation
                coin:Destroy()
            end)
    end
end

--Set text
local function setDisplayText(currentPaycheck : number)
    --Add info to paycheck value and round
    paycheckValueLabel.Text = "$ "..tostring(math.round(currentPaycheck)).." / second"
end

--Handle changes in paycheck value
local function paycheckChanged()
    --Check if a change has occured
    local difference = paycheckStat.Value - lastPaycheck
    if difference > 0 then
        --Animate if frame is visible
        local animate = paycheckFrame.Visible
        --Update pile size
        setPile(animate)
        --Update camera
        setCamera(animate)
        --Play other animations if frame is open
        if animate then
            --Get coins to drop
            local dropCount = math.round(difference/PAYCHECK_PER_COIN)
            --Make sure there are coins to drop
            if dropCount > 0 then
                dropCoins(dropCount)
            end
            --Lerp paycheck text
            TweenAny:TweenNumber(lastPaycheck, paycheckStat.Value, ANIM_TIME, paycheckLerpSignal)
        else
            --Set paycheck text
            setDisplayText(paycheckStat.Value)
        end
    end
    --Set last paycheck
    lastPaycheck = paycheckStat.Value
end

--Pause animations when frame is hidden
local function onVisibleChanged()
    --Look for change
    if paycheckFrame.Visible == true then
        --Play animations
        shineTween:Play()
    else
        --Stop animations
        shineTween:Cancel()
    end
end

---------------------// PRIVATE CODE \\--------------------

--Setup coin pile
coinPile:PivotTo(CFrame.new())
coinPile.Parent = viewport
setPile(false)

--Setup initial camera
viewportCamera.CameraType = Enum.CameraType.Scriptable
viewport.CurrentCamera = viewportCamera
setCamera(false)

--Set initial text
setDisplayText(paycheckStat.Value)

--Connect to shine animation ended for seamless loop
shineTween.Completed:Connect(function()
    --Make sure loop is not in progress
    if not shineLooping then
        --Indicate that tween is looping
        shineLooping = true
        --Reset gradient
        shineGradient.Offset = Vector2.new(-1, 0)
        --Wait a random amount of time before looping
        task.wait(math.random(5, 10))
        --Make sure frame is open first
        if paycheckFrame.Visible == true then
            --Loop
            shineTween:Play()
        end
        --Indicate that tween is not looping
        shineLooping = false
    end
end)

--Connections
paycheckFrame:GetPropertyChangedSignal("Visible"):Connect(onVisibleChanged)
paycheckStat.Changed:Connect(paycheckChanged)
paycheckLerpSignal:Connect(setDisplayText)
