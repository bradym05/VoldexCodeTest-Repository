------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--Modules
local TweenAny = require(ReplicatedStorage:WaitForChild("TweenAny"))
local QuickTween = require(ReplicatedStorage:WaitForChild("QuickTween"))
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))
local QuickSound = require(ReplicatedStorage:WaitForChild("QuickSound"))
local GUI = require(ReplicatedStorage:WaitForChild("GUI"))

--Instances
local player : Player = Players.LocalPlayer
local leaderstats : Folder = player:WaitForChild("leaderstats")
local moneyStat : IntValue = leaderstats:WaitForChild("Money")

local hiddenstats : Folder = player:WaitForChild("hiddenstats")
local paycheckStat : IntValue = hiddenstats:WaitForChild("Paycheck")
local priceStat : IntValue = hiddenstats:WaitForChild("UpgradeCost")

local playerGui : PlayerGui = player:WaitForChild("PlayerGui")
local mainInterface : Frame = playerGui:WaitForChild("MainInterface")
local popup : Frame = mainInterface:WaitForChild("Popup")
local paycheckFrame : Frame = popup:WaitForChild("Container"):WaitForChild("Paycheck")
local paycheckValueLabel : TextLabel = paycheckFrame:WaitForChild("PaycheckValue")
local priceLabel : TextLabel = paycheckFrame:WaitForChild("UpgradePrice")
local upgradeButton : ImageButton = paycheckFrame:WaitForChild("UpgradeButton")
local shineGradient : UIGradient = paycheckValueLabel:WaitForChild("UIGradient")
local viewport : ViewportFrame = paycheckFrame:WaitForChild("PaycheckViewport")

local assets : Folder = ReplicatedStorage:WaitForChild("Assets")
local coinTemplate : MeshPart = assets:WaitForChild("Coin")
local coinPile : MeshPart = assets:WaitForChild("CoinPile"):Clone()

local sounds : Folder = ReplicatedStorage:WaitForChild("Sounds")
local coinSounds : table = sounds:WaitForChild("Coins"):GetChildren()

local remotes : Folder = ReplicatedStorage:WaitForChild("Remotes")
local requestUpgrade : RemoteEvent = remotes:WaitForChild("RequestUpgrade")

--Settings
local CAMERA_ANGLE = 20 --Camera angle (in degrees) specifying the amount to look down by
local CAMERA_DISTANCE = 10 --Camera distance from coin pile
local PAYCHECK_PER_COIN = 10 --Minimum paycheck increment for one coin
local ANIM_TIME = 1.5 --Time for pile to scale in seconds and camera to adjust (coins fall in half this time)
local PURCHASE_FAIL = sounds:WaitForChild("Error") -- Sound played upon failed purchase
local PURCHASE_SOUND = sounds:WaitForChild("Purchase") -- Sound played on purchase

--Tween Settings
local shineTF = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local shineTween = TweenService:Create(shineGradient, shineTF, {Offset = Vector2.new(1, 0)})

local cameraTF = TweenInfo.new(ANIM_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

--Manipulated
local shineLooping = false
local viewportCamera = Instance.new("Camera")
local lastPaycheck = paycheckStat.Value
local lastPrice = priceStat.Value
local paycheckLerpSignal = CustomSignal.new()
local priceLerpSignal = CustomSignal.new()
local minPos : Vector3
local maxPos : Vector3
local pileScale : number

------------------// PRIVATE FUNCTIONS \\------------------

--Move camera based on settings and pile size
local function setCamera(animate : boolean?)
    --Move camera forward or back based on size
    local adjustedDistance = math.clamp(CAMERA_DISTANCE * (pileScale/5), CAMERA_DISTANCE/10, math.huge)
    --Get camera height from angle and distance
    local height = math.asin(math.rad(CAMERA_ANGLE)) * adjustedDistance
    --Set CFrame to match angle and distance and look at the coin pile
    local cameraCFrame = CFrame.new(Vector3.new(0, height, adjustedDistance), coinPile:GetPivot().Position)
    --Set camera
    if animate then
        QuickTween(viewportCamera, cameraTF, {["CFrame"] = cameraCFrame})
    else
        viewportCamera.CFrame = cameraCFrame
    end
end

--Scale pile of coins based on paycheck
local function setPile(animate : boolean?)
    --Set pile scale
    pileScale = (paycheckStat.Value/PAYCHECK_PER_COIN)/10
    --Get half of pile size for min and max pos
    local halfSize = (coinPile.Pile.Size/coinPile:GetScale() * pileScale)/2
    --Set min and max pos
    minPos = -halfSize
    maxPos = halfSize
    --Scale pile
    if animate then
        TweenAny:TweenModel(coinPile, pileScale, ANIM_TIME)
    else
        coinPile:ScaleTo(pileScale)
    end
end

--Drop a coin
local function dropCoins(count : number)
    --Clamp the number of coin sounds to 10
    local soundCount = math.clamp(count, 0, 10)
    --Create given number of coins
    for i = 1, count do
        --Clone coin model
        local coin = coinTemplate:Clone()
        --Get height to start falling at
        local startHeight = viewportCamera.CFrame.Position.Y + 5
        --Calculate random position above coin pile
        local position = Vector3.new(
            math.random(minPos.X, maxPos.X), --Get random x between min and max x
            startHeight,
            math.random(maxPos.Z/2, maxPos.Z) --Get random z between half and max z (start at half so that coins stay in front of the pile)
        )
        --Calculate fallen CFrame with random orientation
        local fallenCFrame = CFrame.Angles(math.rad(math.random(0,360)),math.rad(math.random(0,360)),math.rad(math.random(0,360))) + Vector3.new(position.X, maxPos.Y - 5, position.Z)
        --Create tween info with a random delay
        local fallTF = TweenInfo.new(ANIM_TIME/2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, math.random(0,ANIM_TIME * 50)/100)
        --Adjust size for visibility
        coin.Size *= math.clamp(pileScale, 1, math.huge)
        --Move coin to position with random orientation
        coin.CFrame = CFrame.Angles(math.rad(math.random(0,360)),math.rad(math.random(0,360)),math.rad(math.random(0,360))) + position
        --Make coin visible
        coin.Parent = viewport
        --Play fall animation and connect to tween completed to destroy coin
        QuickTween(coin, fallTF, {["CFrame"] = fallenCFrame}):Once(function()
                --Destroy coin once tween completes
                coin:Destroy()
                --Check if a sound should play
                if i <= soundCount then
                    --Play coin dropping sound
                    QuickSound(coinSounds[math.random(1, #coinSounds)])
                end
            end)
    end
end

--Set text
local function setDisplayText(currentPaycheck : number)
    --Add info to paycheck value and round
    paycheckValueLabel.Text = "$ "..tostring(math.round(currentPaycheck)).." / second"
end

--Set price text
local function setPriceText(currentPrice : number)
    --Add info to price value and round
    priceLabel.Text = "PRICE: $ "..tostring(math.round(currentPrice))
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

--Handle changes in price value
local function priceChanged()
    --Check if a change has occured
    if priceStat.Value ~= lastPrice then
        --Play purchase success sound
        QuickSound(PURCHASE_SOUND)
        --Check if value should be animated
        if paycheckFrame.Visible == true then
            TweenAny:TweenNumber(lastPrice, priceStat.Value, ANIM_TIME, priceLerpSignal)
        else
            setPriceText(priceStat.Value)
        end
        --Set last price
        lastPrice = priceStat.Value
    end
end

--Loop shine tween
local function loopShine()
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
end

--Request upgrade
local function requestUpgradeFunction()
    --Check sufficient funds
    if moneyStat.Value >= priceStat.Value then
        --Request upgrade
        requestUpgrade:FireServer()
    else
        --Play purchase failed sound
        QuickSound(PURCHASE_FAIL)
    end
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
setPriceText(priceStat.Value)

--Connect to shine animation ended for seamless loop
shineTween.Completed:Connect(loopShine)

--Connect to upgrade cost changed for animation
priceStat.Changed:Connect(priceChanged)

--Connect to button pressed to request upgrade
GUI.Button(upgradeButton, requestUpgradeFunction)

--Other Connections
paycheckFrame:GetPropertyChangedSignal("Visible"):Connect(onVisibleChanged)
paycheckStat.Changed:Connect(paycheckChanged)
paycheckLerpSignal:Connect(setDisplayText)
priceLerpSignal:Connect(setPriceText)