------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

--Modules
local QuickSound = require(ReplicatedStorage:WaitForChild("QuickSound"))
local QuickTween = require(ReplicatedStorage:WaitForChild("QuickTween"))
local TweenAny = require(ReplicatedStorage:WaitForChild("TweenAny"))
local ParticleHandler = require(ReplicatedStorage:WaitForChild("ParticleHandler"))

--Instances
local player = Players.LocalPlayer
local tycoons = workspace:WaitForChild("Tycoons")
local playerTycoon = tycoons:WaitForChild(tostring(player.UserId))
local buildings = playerTycoon:WaitForChild("Purchased")

local particles = ReplicatedStorage:WaitForChild("Particles")
local sounds = ReplicatedStorage:WaitForChild("Sounds")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local padTouchedRemote = remotes:WaitForChild("PadTouched")

local buildSounds = sounds:WaitForChild("BuildSounds"):GetChildren()
local swishSounds = sounds:WaitForChild("SwishSounds"):GetChildren()

local settingsFolder = player:WaitForChild("Settings")
local buildAnimationsSetting = settingsFolder:WaitForChild("BuildAnimations")

--Settings
local BUTTON_SOUND = sounds:WaitForChild("ButtonPress") -- Sound played upon stepping on a pad
local PURCHASE_FAIL = sounds:WaitForChild("Error") -- Sound played upon failed purchase
local PURCHASE_SOUND = sounds:WaitForChild("Purchase") -- Sound played on purchase
local PAD_SINK = 4 -- Studs that pads will sink into the ground on purchase
local PURCHASE_EMIT = 20 -- Particles to emit on purchase
local BUILDING_RANDOMNESS = 25 -- Used for max distance and max delay of build animation

--Tween Settings
local buttonTF = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, true)
local buttonFailGoal = {Color =Color3.new(1,0,0)}

local padTransparencyTF = TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local padTransparencyGoal = {Transparency = 1}

local purchasePressTF = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut) -- Same as buttonTF but no reverse

--Particles
local coinExplosion = ParticleHandler.new(particles:WaitForChild("CoinExplosion"))

--Manipulated
local cache = {}

---------------------// PRIVATE CODE \\--------------------

--Pad press animation
padTouchedRemote.OnClientEvent:Connect(function(Pad : Model, purchased : boolean, constant : boolean?)
    --Get button instance
    local padButton = Pad:WaitForChild("Skin"):WaitForChild("ButtonComponents"):WaitForChild("Button")
    --Create tween if not created
    if not cache[Pad] then
        --Initialize goal for tween (move down 0.3 studs)
        local pressedGoal = {Position = padButton.Position - (padButton.CFrame.upVector * 0.3)}
        --Create cache and tweens
        cache[Pad] = {}
        cache[Pad].Pressed = TweenService:Create(padButton, buttonTF, pressedGoal)
        cache[Pad].PurchasePressed = TweenService:Create(padButton, purchasePressTF, pressedGoal)
        cache[Pad].Failed = TweenService:Create(padButton, buttonTF, buttonFailGoal)
        --Create table of beams
        cache[Pad].Beams = {}
        for _, beam : Beam in pairs(Pad.Skin.Beams:GetChildren()) do
            if beam:IsA("Beam") then
                table.insert(cache[Pad].Beams, beam)
            end
        end
    end
    --Play button pressed sound
    QuickSound(BUTTON_SOUND, padButton, true)
    --See if purchase was successful
    if purchased then
        --Play button pressed animation without reverse
        cache[Pad].PurchasePressed:Play()
        --Tween beams to shoot up and fade out
        for _, beam : Beam in pairs(cache[Pad].Beams) do
            --Shoot up
            QuickTween(beam, purchasePressTF, {Width0 = 50, Width1 = 50})
            --Fade out
            TweenAny:TweenSequence(beam, {Transparency = NumberSequence.new(1)}, purchasePressTF)
        end
        --Clear cache and tweens after done using (pad will be destroyed)
        cache[Pad].Pressed:Destroy()
        cache[Pad].Failed:Destroy()
        table.clear(cache[Pad].Beams)
        cache[Pad] = nil
        --Get pad CFrame for sound, particles, and tween
        local padCFrame = Pad:GetPivot()
        --Play purchase sound
        QuickSound(PURCHASE_SOUND, padCFrame, true)
        --Emit purchase particles
        coinExplosion:Emit(padCFrame, PURCHASE_EMIT)
        --Tween transparency of pad
        for _, part : BasePart in pairs(Pad:GetDescendants()) do
            if part:IsA("BasePart") then
                QuickTween(part, padTransparencyTF, padTransparencyGoal)
            end
        end
        --Sink pad into ground by PAD_SINK in the same time it takes to tween transparency
        TweenAny:TweenModel(Pad, padCFrame - (padCFrame.UpVector * PAD_SINK), padTransparencyTF.Time):Once(function()
            --Destroy pad after tween has completed
            Pad:Destroy()
        end)
    else
        --Play button pressed animation
        cache[Pad].Pressed:Play()
        --Make sure this pad can fail
        if not constant then
            --Play purchase failed animations
            cache[Pad].Failed:Play()
            for _, beam : Beam in pairs(cache[Pad].Beams) do
                --Tween beam color the same as pad color
                TweenAny:TweenSequence(beam, {Color = ColorSequence.new(buttonFailGoal.Color)}, buttonTF)
            end
            --Play purchase failed sound
            QuickSound(PURCHASE_FAIL, padButton, true)
        end
    end
end)

----------------// TYCOON BUILD ANIMATION \\---------------

local function animatePart(part : BasePart)
    if part:IsA("BasePart") then
        --Store original values as goal
        local goal = {Transparency = part.Transparency, Size = part.Size, ["CFrame"] = part.CFrame}
        --Move to random location
        local positionOffset = Vector3.new(math.random(-BUILDING_RANDOMNESS,BUILDING_RANDOMNESS),math.random(-BUILDING_RANDOMNESS,BUILDING_RANDOMNESS),math.random(-BUILDING_RANDOMNESS,BUILDING_RANDOMNESS))
        local rotationOffset = CFrame.Angles(math.rad(math.random(0,360)),math.rad(math.random(0,360)),math.rad(math.random(0,360)))
        part.CFrame = part.CFrame * rotationOffset + positionOffset
        --Make random size
        part.Size = part.Size * math.random(5,10)/10
        --Make transparent
        part.Transparency = 1
        --Store original CanCollide value and disable CanCollide
        local wasCollideable = part.CanCollide
        part.CanCollide = false
        --Create tween info with a random delay time
        local delayTime = math.random(0, BUILDING_RANDOMNESS * 3)/100
        local buildingTF = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.InOut, 0, false, delayTime)
        --Play random swish sound when tween starts
        task.delay(delayTime, function()
            QuickSound(swishSounds[math.random(1, #swishSounds)], part)
        end)
        --Tween
        QuickTween(part, buildingTF, goal):Once(function()
            --Play random build sound
            QuickSound(buildSounds[math.random(1, #buildSounds)], part, true)
            --Make sure all values are exact
            for propertyName, propertyValue in pairs(goal) do
                part[propertyName] = propertyValue
            end
            --Reset CanCollide
            part.CanCollide = wasCollideable
        end)
    end
end


--Function to animate building on purchased
local function animateBuilding(building : Model)
    --Check if animations are enabled first
    if buildAnimationsSetting.Value == true then
        --Initialize descendant count and get loaded descendant count
        local loadedDescendants = building:GetAttribute("DescendantCount")
        local currentDescendants = 0
        --Animate existing parts
        for _, descendant in pairs(building:GetDescendants()) do
            --Animate descendant
            animatePart(descendant)
            --Increment descendant count
            currentDescendants += 1
        end
        --Animate newly added parts if building has not fully loaded
        if currentDescendants ~= loadedDescendants then
            local descendantAddedConnection
            descendantAddedConnection = building.DescendantAdded:Connect(function(descendant)
                --Animate descendant
                animatePart(descendant)
                --Increment descendant count
                currentDescendants += 1
                --Disconnect if model has loaded
                if currentDescendants == loadedDescendants then
                    descendantAddedConnection:Disconnect()
                    descendantAddedConnection = nil
                end
            end)
        end
    end
end

--Connect to animate new buildings
buildings.ChildAdded:Connect(animateBuilding)

-------------------// FLOATING DEBRIS \\-------------------

