------------------// PRIVATE VARIABLES \\------------------

--Services
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Instances
local musicGroup = SoundService:WaitForChild("MUSIC")

local sounds = ReplicatedStorage:WaitForChild("Sounds")
local music = sounds:WaitForChild("Music")

--Manipulated
local paused = false
local playlist = {}
local activeSong : Sound

------------------// PRIVATE FUNCTIONS \\------------------

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

---------------------// PRIVATE CODE \\--------------------

--Connect to volume changed
musicGroup.Changed:Connect(function()
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
end)

--Begin playing music
playNext()


