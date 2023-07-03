--[[
This module keeps track of particles for use across multiple instances performantly. Cleans up inactive ParticleEmitters and dynamically adjusts emit count based
on camera distance. Uses a particle setting to multiply emit counts.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local Players = game:GetService("Players")

--Instances
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local particlePart = Instance.new("Part")

local settingsFolder = player:WaitForChild("Settings")
local particlesSetting = settingsFolder:WaitForChild("Particles")

--Settings
local DISTANCE_MAX = 100 -- Maximum distance from camera where particle emit count is constant

--------------------// PARTICLE CLASS \\-------------------
local Particle = {
    _active = {}, -- Private dictionary of parents to emitters
}
Particle.__index = Particle

--Create new particle object
function Particle.new(base : ParticleEmitter)
    local self = {}
    self.base = base
    setmetatable(self, Particle)
    return self
end

--Clean up
function Particle:Destroy()
    --Destroy emitters
    for parent, info in pairs(self._active) do
        --Check that this info is active
        if info and info.ParticleEmitter then
            info.ParticleEmitter:Destroy()
        end
    end
    --Clean up hard references
    table.clear(self._active)
    table.freeze(self._active)
    self._active = nil
    self.base = nil
    --Clean up self
    table.clear(self)
    setmetatable(self, nil)
    table.freeze(self)
end

--Emit function
function Particle:Emit(from : BasePart | Attachment | CFrame, emitCount : number)
    --Make sure particles are enabled before continuing
    if particlesSetting.Value > 0 then
        --Convert from to attachment if CFrame is provided
        local wasCreated = false
        if typeof(from) == "CFrame" then
            --Create and CFrame attachment to world
            local attachment = Instance.new("Attachment")
            attachment.Parent = particlePart
            attachment.WorldCFrame = from
            --Set from to created attachment
            from = attachment
            --Set created to true for clean up
            wasCreated = true
        end
        if from and (from:IsA("BasePart") or from:IsA("Attachment")) then
            --Initialize variables
            local startTime = os.clock()
            local fromCFrame
            --Find CFrame in world space
            if from:IsA("Attachment") then
                fromCFrame = from.WorldCFrame
            else
                fromCFrame = from.CFrame
            end
            --Calculate distance from camera
            local distance = (camera.CFrame.Position - fromCFrame.Position).Magnitude
            --Calculate multiplier from on distance between 0 and 1
            local distanceMulti = math.clamp(DISTANCE_MAX/distance, 0, 1)
            --Multiply by particle setting and distance multiplier
            emitCount *= particlesSetting.Value * distanceMulti
            --Check if emitter already exists in part
            if not self._active[from] then
                --Create emitter
                local emitter = self.base:Clone()
                emitter.Parent = from
                --Initialize table
                self._active[from] = {}
                self._active[from].ParticleEmitter = emitter
            end
            --Set start time
            self._active[from].StartTime = startTime
            --Emit particles
            self._active[from].ParticleEmitter:Emit(emitCount)
            --Wait for longest lifetime particles to finish emitting with one second grace period
            task.delay(self.base.Lifetime.Max + 1, function()
                --Make sure this is the last emission
                if self._active[from] and self._active[from].StartTime == startTime then
                    self._active[from].ParticleEmitter:Destroy()
                    self._active[from] = nil
                    --Destroy attachment if created
                    if wasCreated then
                        from:Destroy()
                    end
                end
            end)
        end
    end
end

---------------------// PRIVATE CODE \\--------------------

--Setup particle part
particlePart.Anchored = true
particlePart.CanCollide = false
particlePart.CanQuery = false
particlePart.CanTouch = false
particlePart.Transparency = 1
particlePart.Name = "ParticlePart"
particlePart.Parent = workspace

return Particle