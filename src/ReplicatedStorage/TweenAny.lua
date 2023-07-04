--[[
This module tweens instances which usually are not tweenable.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Modules
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))

--Settings
local FREQUENCY = 60 --Target loops per second (essentially FPS)

--Manipulated
local tweens = {}
local elapsed = 0
local typeFunctions = {} -- Functions to return a lerped value for different types
local lastLoop = 0
local renderSteppedConnection

-------------------// PRIVATE FUNCTIONS \\------------------

--Function to lerp model
typeFunctions["Model"] = function(item : Model, info : table, progress : number)
    if typeof(info.Goal) == "CFrame" then
        --Pivot towards goal cframe
        item:PivotTo(info.StartValue:Lerp(info.Goal, progress))
    else
        --Scale towards goal size using number lerp function
        item:ScaleTo(typeFunctions["number"](nil, info, progress))
    end
    return item
end

--Function to lerp number
typeFunctions["number"] = function(_, info : table, progress : number)
    --Lerp value (start value plus difference to goal = goal so difference to goal times alpha = progress)
    local lerped = info.StartValue + (info.Goal - info.StartValue)*progress
    --Fire change if signal exists
    if info.Signal then
        info.Signal:Fire(lerped)
    end
    return lerped
end

--Function to lerp ColorSequence or NumberSequence
typeFunctions["Sequences"] = function(item : ColorSequence | NumberSequence, info : table, progress : number)
    for propertyName, propertyValue in pairs(info.StartValue) do
        --Initialize variables
        local goalKeypoints = info.Goal[propertyName].Keypoints
        local lastValue = goalKeypoints[1]
        local newKeypoints = {}
        --Iterate over each base keypoint
        for index, keypoint in pairs(propertyValue.Keypoints) do
            --Get last value if goal keypoint doesn't have this index
            local goalValue = (goalKeypoints[index] and goalKeypoints[index].Value) or lastValue
            --Declare newValue variable
            local newValue
            --Use number lerp function if necessary
            if typeof(goalValue) == "number" then
                newValue = typeFunctions.number(item, {Goal = goalValue, StartValue = keypoint.Value}, progress)
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
        --Set property to sequence of same type
        if typeof(propertyValue) == "ColorSequence" then
            item[propertyName] = ColorSequence.new(newKeypoints)
        else
            item[propertyName] = NumberSequence.new(newKeypoints)
        end
    end
    return item
end

--Function which is connected to RenderStepped
local function renderStepped(deltaTime : number)
    --Update time
    elapsed += deltaTime
    --Check if required time has passed to meet frequency setting
    if elapsed - lastLoop >= 1/FREQUENCY then
        --Set last loop
        lastLoop = elapsed
        --Initialize table of completed tweens
        local completed = {}
        --Check if any tweens exist
        if next(tweens) then
            --Iterate over each model and their info
            for item, info in pairs(tweens) do
                --Skip completed tweens if kept in table
                if not info then continue end
                --Change in time since start
                local timeDifference = elapsed - info.StartTime
                --Alpha of progress in time from start to finish
                local progress = math.clamp(timeDifference/info.Length, 0, 1)
                --Get item type
                local itemType = info.SetType or typeof(item)
                --Special cases
                if itemType == "Instance" then
                    itemType = item.ClassName
                end
                if not itemType or not typeFunctions[itemType] then
                    --Stop and cancel tween if type is not referenced
                    tweens[item] = nil
                    continue
                end
                --Tween item based on type
                typeFunctions[itemType](item, info, progress)
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
                        --Fire signal and destroy unless instructed otherwise
                        if not info.KeepSignal then
                            info.Signal:FireOnce(item)
                        end
                        --Tween completed, add to table
                        table.insert(completed, item)
                    end
                end
            end
        else
            --Disconnect since no tweens exist
            renderSteppedConnection:Disconnect()
            renderSteppedConnection = nil
        end
        --Remove all completed tweens from dictionary (must be done outside of above loop)
        for _, item in pairs(completed) do
            tweens[item] = nil
        end
        --Clean up completed table
        table.clear(completed)
        completed = nil
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
function TweenAny:TweenModel(model : Model, goal : CFrame | number, length : number, reverses : boolean?)
    if model:IsA("Model") then
        --Initialize start value
        local startValue
        --Set start value by type
        if typeof(goal) == "CFrame" then
            --Get start CFrame
            startValue = model:GetPivot()
        else
            startValue = model:GetScale()
        end
        --Create custom signal
        local signal = CustomSignal.new()
        --Reference model to info
        tweens[model] = {
            StartValue = startValue,
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
function TweenAny:TweenSequence(object : any, goal : table, tweenInfo : TweenInfo)
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
        SetType = "Sequences",
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

--Tween numbers via lerping and update with new or provided signal
function TweenAny:TweenNumber(number : number, goal : number, length : number, signal : table?, reverses : boolean?)
    --Set signal to be destroyed if created here, or kept if given
    local keepSignal = signal ~= nil
    --Create custom signal if none is provided
    if not signal then
        signal = CustomSignal.new()
    end
    --Reference number to info
    tweens[number] = {
        StartValue = number,
        Goal = goal,
        Reverses = reverses,
        Length = length,
        Signal = signal,
        StartTime = elapsed,
        KeepSignal = keepSignal,
    }
    --Begin processing
    connectRenderStepped()
    --Return signal if created
    if not keepSignal then
        return signal
    end
end

return TweenAny