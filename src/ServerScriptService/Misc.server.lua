--[[
This script handles miscellaneous tasks.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Instances
local sounds : Folder = ReplicatedStorage:WaitForChild("Sounds")
local music : Folder = sounds:WaitForChild("Music")

---------------------// PRIVATE CODE \\--------------------

--Set attribute song count on music folder to total number of children
music:SetAttribute("SongCount", #music:GetChildren())