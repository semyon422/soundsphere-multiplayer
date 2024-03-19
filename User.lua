local class = require("class")

---@class multiplayer.User
---@operator call: multiplayer.User
local User = class()

User.id = nil
User.peer = nil
User.name = nil
User.isReady = false
User.isNotechartFound = false
User.isPlaying = false

function User:new()
	self.score = {}
	self.modifiers = {}
	self.notechart = {}
end

function User:dto()
	return {
		id = self.id,
		peerId = self.peer.id,
		name = self.name,
		isReady = self.isReady,
		isNotechartFound = self.isNotechartFound,
		isPlaying = self.isPlaying,
		score = self.score,
		modifiers = self.modifiers,
		notechart = self.notechart,
	}
end

return User
