------------------// PRIVATE VARIABLES \\------------------

--Services
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--Instances
local player : Player = Players.LocalPlayer

local musicGroup : SoundGroup = SoundService:WaitForChild("MUSIC")

local sounds : Folder = ReplicatedStorage:WaitForChild("Sounds")
local music : Folder = sounds:WaitForChild("Music")

--Manipulated
local songAdded : RBXScriptConnection
local songCount = music:GetAttribute("SongCount")
local volumeSetting : IntValue
local paused = false
local loaded = false
local playlist = {}
local activeSong : Sound

------------------// PRIVATE FUNCTIONS \\------------------

--Shuffles the given array
local function shuffle(array : table) : table
    --Initialize variables
    local shuffled = {}
    --Loop through all indexes
    for i = 1, #array do
        --Select random index
        local randomIndex = math.random(1, #array)
        --Set shuffled table at this index to array at random index
        shuffled[i] = array[randomIndex]
        --Remove selection from array
        table.remove(array, randomIndex)
    end
    --Return new table
    return shuffled
end

--Plays the next song in the playlist, makes a playlist if current playlist is completed
local function playNext()
    --Check if music is muted first
    if paused then
        --No song is playing
        activeSong = nil
    else
        --Create a new playlist if playlist is empty
        if #playlist == 0 then
            playlist = shuffle(music:GetChildren())
        end
        --Get next song and set SoundGroup
        local song = playlist[1]
        song.SoundGroup = musicGroup
        --Remove from playlist
        table.remove(playlist, 1)
        --Play next song when this song stops
        song.Ended:Once(playNext)
        --Set active song and play
        activeSong = song
        song:Play()
    end
end

--Check if music can be played and play if passed
local function checkLoaded()
    --Make sure loaded is not already true and volume setting has loaded
    if not loaded and volumeSetting then
        --Check if songs have loaded
        if songCount and songCount == #music:GetChildren() then
            --Round volumes to prevent floating point error
            local roundedGroupVolume = math.round(musicGroup.Volume * 10)
            local roundedSettingVolume = math.round(volumeSetting.Value * 10)
            --Check if volume has loaded
            if roundedGroupVolume == roundedSettingVolume then
                --Set loaded to true
                loaded = true
                --Disconnect songAdded if connected
                if songAdded then
                    songAdded:Disconnect()
                end
                --Play music
                playNext()
            end
        elseif not songAdded then
            --Connect song added if not connect
            songAdded = music.ChildAdded:Connect(checkLoaded)
        end
    end
end

--Dynamically pauses or unpauses music based on changes in volume
local function onVolumeChanged()
    --Check loaded due to change in volume
    checkLoaded()
    --Check if muted and music is playing
	if musicGroup.Volume <= 0 and not paused then
        --Set paused
		paused = true
        --Pause active song
		if activeSong then
			activeSong:Pause()
		end
	elseif musicGroup.Volume > 0 and paused then
        --Set paused
		paused = false
        --Unpause active song
		if activeSong then
			activeSong:Resume()
        else
            --Play next song
            playNext()
		end
	end
end

---------------------// PRIVATE CODE \\--------------------

--Connect to volume changed
musicGroup.Changed:Connect(onVolumeChanged)

--Check if song count is loaded
if not songCount then
    --Set song count when loaded
    music:GetAttributeChangedSignal("SongCount"):Once(function()
        songCount = music:GetAttribute("SongCount")
    end)
end

--Yield until settings have loaded and initialize setting variable
volumeSetting = player:WaitForChild("Settings"):WaitForChild("MusicVolume")
--Check loaded incase missed by onVolumeChanged function
checkLoaded()


