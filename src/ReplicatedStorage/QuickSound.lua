--[[
This module returns a function to play a one time sound, ensuring that the sound is cleaned up and assigned a sound group.
Automatically assigns a SoundGroup if not provided

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Instances
local sounds = ReplicatedStorage:WaitForChild("Sounds")
local soundPart = Instance.new("Part")

--Settings
local SOUND_DEFAULTS = { --Default sound properties (if set to default)
    RollOffMode = Enum.RollOffMode.Linear,
    RollOffMaxDistance = 500,
    RollOffMinDistance = 10,
    Volume = 0.5,
}

--Controlled
local hasCFrame = { --Instance classes which sounds can inherit CFrame from (https://create.roblox.com/docs/reference/engine/classes/Sound)
    "BasePart",
    "Attachment",
}

--Manipulated
local nameCache = {}
local groupCache = {}

-----------------------// FUNCTION \\----------------------

--Takes the sound or name of sound from ReplicatedStorage.Sounds to play, a parent or cframe (optional), and a SoundGroup (optional)
local function QuickSound(base : Sound | string, parentOrCFrame : (Instance | CFrame)?, defaults : boolean?, group : (SoundGroup | string)?)
    --Find base sound if string is provided
    if type(base) == "string" then
        --Set cache if not set (indexing nameCache is faster than FindFirstChild)
        if not nameCache[base] then
            --Find sound instance (automatically nil if not found)
            nameCache[base] = sounds:FindFirstChild(base)
        end
        --Get cache
        base = nameCache[base]
    end
    --Make sure provided base is a valid sound
    if base and typeof(base) == "Instance" and base:IsA("Sound") then
        --Initialize variables
        local sound = base:Clone()
        local destroyAfter = sound
        --Set defaults if requested
        if defaults then
            for propertyName : string, propertyValue : any in pairs(SOUND_DEFAULTS) do
                --Set sound property to default sound property
                sound[propertyName] = propertyValue
            end
        end
        --Get SoundGroup instance if group is a string (SoundGroup will be nil if not found and therefore set automatically)
        if group and type(group) == "string" then
            group = SoundService:FindFirstChild(group)
        elseif not group then
            --Allow for nil to be cached
            group = "nil"
        end
        --Automatically get a SoundGroup if none was provided, or provided is not a valid SoundGroup
        if not group or typeof(group) ~= "Instance" or not group:IsA("SoundGroup") then
            --Set cache if not set
            if not groupCache[group] then
                --Determine if parentOrCFrame is a CFrame or is a instance class with a CFrame
                if parentOrCFrame and (typeof(parentOrCFrame) == "CFrame" or (typeof(parentOrCFrame) == "Instance" and table.find(hasCFrame, parentOrCFrame.ClassName))) then
                    --Sound is being played in 3D space so is likely from the game
                    groupCache[group] = SoundService.GAME
                else
                    --Sound is not physical so is likely a GUI sound effect
                    groupCache[group] = SoundService.GUI
                end
            end
            --Get cache
            group = groupCache[group]
        end
        --Set SoundGroup
        sound.SoundGroup = group
        --Parent sound accordingly
        if typeof(parentOrCFrame) == "CFrame" then
            --Create an attachment if a CFrame was provided
            local attachment = Instance.new("Attachment")
            attachment.WorldCFrame = parentOrCFrame
            attachment.Parent = soundPart
            --Set parent to attachment
            parentOrCFrame = attachment
            --Set attachment to be destroyed instead of sound
            destroyAfter = attachment
        elseif not parentOrCFrame then
            --Default to SoundService
            parentOrCFrame = SoundService
        end
        --Sound can now be parented to parentOrCFrame
        sound.Parent = parentOrCFrame
        --Connect to sound ended for clean up
        sound.Ended:Once(function()
            destroyAfter:Destroy()
        end)
        --Play
        sound:Play()
        --Return ended signal incase needed
        return sound.Ended
    end
end

---------------------// PRIVATE CODE \\--------------------

--Setup sound part
soundPart.Anchored = true
soundPart.CanCollide = false
soundPart.CanQuery = false
soundPart.CanTouch = false
soundPart.Transparency = 1
soundPart.Name = "SoundPart"
soundPart.Parent = workspace


return QuickSound
