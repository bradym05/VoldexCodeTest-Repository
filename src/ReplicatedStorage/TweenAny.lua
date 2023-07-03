--[[
This module tweens instances which usually are not tweenable.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Modules
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))

--Manipulated
local tweens = {}
local elapsed = 0
local renderSteppedConnection

-------------------// PRIVATE FUNCTIONS \\------------------

--Function which is connected to RenderStepped
local function renderStepped(deltaTime : number)
    --Update time
    elapsed += deltaTime
    --Check if any tweens exist
    if next(tweens) then
        --Iterate over each model and their info
        for item, info in pairs(tweens) do
            --Change in time since start
            local timeDifference = elapsed - info.StartTime
            --Alpha of progress in time from start to finish
            local progress = math.clamp(timeDifference/info.Length, 0, 1)
            --Tween item based on type
            if item:IsA("Model") then
                --Lerp model
                item:PivotTo(info.StartValue:Lerp(info.Goal, progress))
            else
                --Lerp sequence
                for propertyName, propertyValue in pairs(info.StartValue) do
                    --Initialize variables
                    local goalKeypoints = info.Goal[propertyName].Keypoints
                    local newKeypoints = {}
                    local lastValue = goalKeypoints[1]
                    --Iterate over each base keypoint
                    for index, keypoint in pairs(propertyValue.Keypoints) do
                        --Get last value if goal keypoint doesn't have this index
                        local goalValue = (goalKeypoints[index] and goalKeypoints[index].Value) or lastValue
                        --Declare newValue variable
                        local newValue
                        --Numbers cannot be lerped, so implement custom lerp if value is a number
                        if typeof(goalValue) == "number" then
                            --Lerp value (start value plus difference to goal = goal so difference to goal times alpha = progress)
                            newValue = keypoint.Value + (goalValue - keypoint.Value)*progress
                        else
                            --Lerp value of start keypoint to value of same index goal keypoint
                            newValue = keypoint.Value:Lerp(goalValue, progress)
                        end
                        --Create sequence keypoint of same type
                        if typeof(keypoint) == "ColorSequenceKeypoint" then
                            table.insert(newKeypoints, ColorSequenceKeypoint.new(keypoint.Time, newValue))
                        else
                            table.insert(newKeypoints, NumberSequenceKeypoint.new(keypoint.Time, newValue))
                        end
                        --Set last value
                        lastValue = goalValue
                    end
                    --Create sequence of same type
                    local sequence
                    if typeof(propertyValue) == "ColorSequence" then
                        sequence = ColorSequence.new(newKeypoints)
                    else
                        sequence = NumberSequence.new(newKeypoints)
                    end
                    --Set property to lerped value
                    item[propertyName] = sequence
                end
            end
            --End tween if completed
            if progress == 1 then
                --Check if tween needs to reverse
                if info.Reverses then
                    --Temporarily store start to swap start and goal
                    local startTemp = info.StartValue
                    --Swap
                    info.StartValue = info.Goal
                    info.Goal = startTemp
                    --Reversing now, set reverse to false
                    info.Reverses = false
                    --Update info
                    tweens[item] = info
                else
                    --Tween completed, clean up
                    tweens[item] = nil
                    --Fire signal
                    info.Signal:FireOnce()
                end
            end
        end
    else
        --Disconnect since no tweens exist
        renderSteppedConnection:Disconnect()
        renderSteppedConnection = nil
    end
end

local function connectRenderStepped()
    --Check if tweens are already running
    if not renderSteppedConnection then
        --Connect render stepped
        renderSteppedConnection = RunService.RenderStepped:Connect(renderStepped)
    end
end

------------------------// MODULE \\------------------------
local TweenAny = {}

--Tweens model position via lerping
function TweenAny:TweenModel(model : Model, goal : CFrame, length : number, reverses : boolean?)
    if model:IsA("Model") then
        --Get start CFrame
        local startCFrame = model:GetPivot()
        --Create custom signal
        local signal = CustomSignal.new()
        --Reference model to info
        tweens[model] = {
            StartValue = startCFrame,
            Goal = goal,
            Length = length,
            Reverses = reverses,
            Signal = signal,
            StartTime = elapsed,
        }
        --Begin processing
        connectRenderStepped()
        --Return signal
        return signal
    end
end

--Tweens sequence keyframes via lerping
function  TweenAny:TweenSequence(object : any, goal : table, tweenInfo : TweenInfo)
    --Get start sequences
    local startSequences = {}
    for propertyName, _ in pairs(goal) do
        startSequences[propertyName] = object[propertyName]
    end
    --Create custom signal
    local signal = CustomSignal.new()
    --Reference object to info
    tweens[object] = {
        StartValue = startSequences,
        Goal = goal,
        Length = tweenInfo.Time,
        Reverses = tweenInfo.Reverses,
        Signal = signal,
        StartTime = elapsed,
    }
    --Begin processing
    connectRenderStepped()
    --Return signal
    return signal
end

return TweenAny