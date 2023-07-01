------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--Modules
local QuickSound = require(ReplicatedStorage:WaitForChild("QuickSound"))
local QuickTween = require(ReplicatedStorage:WaitForChild("QuickTween"))
local TweenAny = require(ReplicatedStorage:WaitForChild("TweenAny"))
local ParticleHandler = require(ReplicatedStorage:WaitForChild("ParticleHandler"))

--Instances
local particles = ReplicatedStorage:WaitForChild("Particles")
local sounds = ReplicatedStorage:WaitForChild("Sounds")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local padTouchedRemote = remotes:WaitForChild("PadTouched")

--Settings
local BUTTON_SOUND = sounds:WaitForChild("ButtonPress") -- Sound played upon stepping on a pad
local PURCHASE_FAIL = sounds:WaitForChild("Error") -- Sound played upon failed purchase
local PURCHASE_SOUNDS = sounds:WaitForChild("Purchase"):GetChildren() -- Folder of sounds to choose randomly when purchased
local PAD_SINK = 4 -- Studs that pads will sink into the ground on purchase
local PURCHASE_EMIT = 20 -- Particles to emit on purchase

--Tween Settings
local buttonTF = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, true)
local buttonFailGoal = {Color =Color3.new(1,0,0)}

local padTransparencyTF = TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local padTransparencyGoal = {Transparency = 1}

--Particles
local coinExplosion = ParticleHandler.new(particles:WaitForChild("CoinExplosion"))

--Manipulated
local cache = {}

---------------------// PRIVATE CODE \\--------------------

--Pad press animation
padTouchedRemote.OnClientEvent:Connect(function(Pad : Model, purchased : boolean)
    --Get button instance
    local padButton = Pad:WaitForChild("Skin"):WaitForChild("ButtonComponents"):WaitForChild("Button")
    --Create tween if not created
    if not cache[Pad] then
        --Initialize goal for tween (move down 0.3 studs)
        local pressedGoal = {Position = padButton.Position - (padButton.CFrame.upVector * 0.3)}
        --Create cache and tweens
        cache[Pad] = {}
        cache[Pad].Pressed = TweenService:Create(padButton, buttonTF, pressedGoal)
        cache[Pad].Failed = TweenService:Create(padButton, buttonTF, buttonFailGoal)
        --Create table of beams
        cache[Pad].Beams = {}
        for _, beam : Beam in pairs(Pad.Skin.Beams:GetChildren()) do
            if beam:IsA("Beam") then
                table.insert(cache[Pad].Beams, beam)
            end
        end
    end
    --Play button pressed animation
    cache[Pad].Pressed:Play()
    --Play button pressed sound
    QuickSound(BUTTON_SOUND, padButton, true)
    --See if purchase was successful
    if purchased then
        --Clear cache and tweens (pad will be destroyed)
        cache[Pad].Pressed:Destroy()
        cache[Pad].Failed:Destroy()
        for _, tween in pairs(cache[Pad].Beams) do
            tween:Destroy()
        end
        cache[Pad] = nil
        --Get pad CFrame for sound, particles, and tween
        local padCFrame = Pad:GetPivot()
        --Play random purchase sound
        QuickSound(PURCHASE_SOUNDS[math.random(1, #PURCHASE_SOUNDS)], padCFrame, true)
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
        --Play purchase failed animations
        cache[Pad].Failed:Play()
        for _, beam in pairs(cache[Pad].Beams) do
            --Tween beam color the same as pad color
            TweenAny:TweenSequence(beam, {Color = ColorSequence.new(buttonFailGoal.Color)}, buttonTF)
        end
        --Play purchase failed sound
        QuickSound(PURCHASE_FAIL, padButton, true)
    end
end)