--[[
This module automatically cleans up tweens after playing

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local TweenService = game:GetService("TweenService")

-----------------------// FUNCTION \\----------------------

local function QuickTween(base : Instance, info : TweenInfo, goal : table)
    --Create tween
    local tween = TweenService:Create(base, info, goal)
    --Connect for cleanup
    tween.Completed:Once(function()
        --Destroy tween
        tween:Destroy()
    end)
    --Play
    tween:Play()
    --Return signal if needed
    return tween.Completed
end

return QuickTween