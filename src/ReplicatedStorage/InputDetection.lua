--[[
This module detects changes in input type and stores the current device. Fires a custom signal when device changes.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Modules
local CustomSignal = require(ReplicatedStorage:WaitForChild("CustomSignal"))

--Settings
local XBOX_INPUT_STRINGS = {"Gamepad"} --Patterns found in UserInputTypes indicating player is on Xbox
local PC_INPUT_STRINGS = {"Mouse", "Keyboard"} --Patterns found in UserInputTypes indicating player is on PC
local MOBILE_INPUT_STRINGS = {"Touch"} --Patterns found in UserInputTypes indicating player is on Mobile

--Manipulated
local changedSignal = CustomSignal.new()
local deviceTables = {
    XBOX = XBOX_INPUT_STRINGS,
    PC = PC_INPUT_STRINGS,
    MOBILE = MOBILE_INPUT_STRINGS,
}

------------------// PRIVATE FUNCTIONS \\------------------

--Gets device name from input type
local function GetDevice(lastInputType : Enum.UserInputType)
    --Make sure input type is not nil
    if lastInputType then
        --Initialize variables
        local device
        --Loop through possible devices
        for deviceName : string, deviceStrings : table in pairs(deviceTables) do
            --Iterate through all patterns
            for _, stringPattern : string in pairs(deviceStrings) do
                --Search for pattern
                if string.find(lastInputType.Name, stringPattern) then
                    --Set found device and stop searching
                    device = deviceName
                    break
                end
                --Stop searching if device was found
                if device then
                    break
                end
            end
        end
        --Return search result
        return device
    end
end

-----------------------// MODULE \\------------------------

local InputDetection = {
    DeviceChanged = changedSignal, --Reference to changed signal
    CurrentDevice = GetDevice(UserInputService:GetLastInputType()), --Reference to active device
}

function InputDetection.UpdateDevice(lastInputType : Enum.UserInputType)
    --Get new device
    local newDevice = GetDevice(lastInputType)
    --Look for change
    if newDevice and newDevice ~= InputDetection.CurrentDevice then
        --Set current device and fire change
        InputDetection.CurrentDevice = newDevice
        InputDetection.DeviceChanged:Fire(newDevice)
    end
end

---------------------// PRIVATE CODE \\--------------------

--Connect to changes
UserInputService.LastInputTypeChanged:Connect(InputDetection.UpdateDevice)

return InputDetection