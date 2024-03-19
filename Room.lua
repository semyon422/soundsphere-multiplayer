local class = require("class")

---@class multiplayer.Room
---@operator call: multiplayer.Room
local Room = class()

Room.isFreeModifiers = false
Room.isFreeNotechart = false
Room.isPlaying = false
Room.id = nil
Room.name = nil
Room.hostPeerId = nil

function Room:new()
	self.password = ""
	self.users = {}
	self.peers = {}
	self.modifiers = {}
	self.notechart = {}
end

function Room:dto()
	return {
		id = self.id,
		name = self.name,
		hostPeerId = self.hostPeerId,
		isFreeModifiers = self.isFreeModifiers,
		isFreeNotechart = self.isFreeNotechart,
		isPlaying = self.isPlaying,
	}
end

return Room
