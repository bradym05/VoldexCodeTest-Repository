------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

--Modules
local GUI = require(ReplicatedStorage:WaitForChild("GUI"))
local QuickSound = require(ReplicatedStorage:WaitForChild("QuickSound"))

--Instances
local player : Player = Players.LocalPlayer
local playerGui : PlayerGui = player:WaitForChild("PlayerGui")
local mainInterface : Frame = playerGui:WaitForChild("MainInterface")
local popup : Frame = mainInterface:WaitForChild("Popup")
local settingsFrame : Frame = popup:WaitForChild("Container"):WaitForChild("Settings")
local audioFrame : Frame = settingsFrame:WaitForChild("Audio")
local toggleFrame : Frame = settingsFrame:WaitForChild("Toggle")
local particleSlider : Frame = settingsFrame:WaitForChild("Particles")

local sounds : Folder = ReplicatedStorage:WaitForChild("Sounds")
local clickSound : Sound = sounds:WaitForChild("SingleClick")

local remotes : Folder = ReplicatedStorage:WaitForChild("Remotes")
local getData : RemoteFunction = remotes:WaitForChild("GetData")
local setData : RemoteEvent = remotes:WaitForChild("SetData")

--Initial settings
local settingsData = getData:InvokeServer("Settings")

--Settings
local TOGGLE_IMAGES = { --Images for checkboxes
    ["true"] = "rbxassetid://13939588429", --Checkmark
    ["false"] = "rbxassetid://13939592873", --X
}
local TYPE_TO_CLASS = { --Setting value types to object class
    ["number"] = "NumberValue",
    ["boolean"] = "BoolValue",
}

--Create public folder
local settingsFolder = Instance.new("Folder")

------------------// PRIVATE FUNCTIONS \\------------------

--Update setting data and value
local function updateSetting(settingName : string, settingValue : any)
    --Get value object
    local valueObject = settingsFolder[settingName]
    --Set value
    valueObject.Value = settingValue
    --Update setting data
    settingsData[settingName] = settingValue
    setData:FireServer("Settings", settingsData)
end

--Setup sliders
local function sliderSetup(sliderSection : Frame, respondingObject : any?, respondingProperty : string?)
    --Initialize variables
    local settingName = sliderSection.Name
    --Find volume slider and progress bar
    local sliderGui : ImageButton = sliderSection.Slider
    local progressBar : Frame = sliderGui.Progress
    --Add functionality
    local slider = GUI.Slider(sliderGui, progressBar)
    --Set to saved volume without signaling a change
    slider:SetValue(settingsData[settingName], true)
    --Update initial responding value
    if respondingObject and respondingProperty then
        respondingObject[respondingProperty] = settingsData[settingName]
    end
    --Connect to value changed
    slider.sliderChanged:Connect(function(newValue : number)
        --Update responding value
        if respondingObject and respondingProperty then
            respondingObject[respondingProperty] = newValue
        end
        --Update setting
        updateSetting(settingName, newValue)
    end)
end

--Setup audio sliders
local function audioSetup(audioSection : Frame)
    --Get responding sound group name
    local soundGroupName : string = audioSection:GetAttribute("SoundGroup")
    --Get sound group object 
    local soundGroup : SoundGroup = soundGroupName and SoundService:FindFirstChild(soundGroupName)
    --Check that sound group exists
    if soundGroup then
        --Setup slider
        sliderSetup(audioSection, soundGroup, "Volume")
    end
end

--Get toggle image from boolean
local function setToggleImage(imageGui : ImageButton | ImageLabel, toggle : boolean)
    --Get image
    local image = TOGGLE_IMAGES[tostring(toggle)]
    --Make sure image exists
    if image then
        --Set image
        imageGui.Image = image
    end
end

--Setup checkboxes
local function toggleSetup(toggleSection : Frame)
    --Initialize variables
    local settingName = toggleSection.Name
    local checkBox : ImageButton = toggleSection.CheckBox
    local toggled = settingsData[settingName]
    --Set initial appearance
    setToggleImage(checkBox, toggled)
    --Connect input
    checkBox.Activated:Connect(function(inputObject, clickCount)
        --Play sound
        QuickSound(clickSound)
        --Toggle
        toggled = not toggled
        --Update image
        setToggleImage(checkBox, toggled)
        --Update setting
        updateSetting(settingName, toggled)
    end)
end

--Setup groups of UI
local function groupSetup(section : Frame, classCheck : string, setupFunction : any)
    --Setup sections
    for _, subSection in pairs(section:GetChildren()) do
        --Make sure this is the right class
        if subSection:IsA(classCheck) then
            --Setup
            setupFunction(subSection)
        end
    end
end

---------------------// PRIVATE CODE \\--------------------

--Setup audio sections
groupSetup(audioFrame, "Frame", audioSetup)

--Setup toggle sections
groupSetup(toggleFrame, "Frame", toggleSetup)

--Setup sliders
sliderSetup(particleSlider)

--Load folder
settingsFolder.Name = "Settings"
--Load each setting
for settingName : string, settingValue : any in pairs(settingsData) do
    --Get value object class from setting value type
    local valueClass = TYPE_TO_CLASS[typeof(settingValue)]
    --Check if setting value has a corresponding class
    if valueClass then
        --Create value object
        local valueObject = Instance.new(valueClass)
        --Set value and name
        valueObject.Name = settingName
        valueObject.Value = settingValue
        --Parent to folder
        valueObject.Parent = settingsFolder
    end
end
--Make public
settingsFolder.Parent = player