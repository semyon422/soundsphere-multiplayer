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

function Room:push()
	local dto = self:dto()
	for _, p in pairs(self.peers) do
		p._set("room", dto)
	end
end

function Room:pushUsers()
	for _, p in pairs(self.peers) do
		p._set("roomUsers", self.users)
	end
end

function Room:unreadyUsers()
	for _, u in pairs(self.users) do
		u.isReady = false
	end
	self:pushUsers()
end

function Room:pushModifiers()
	self:unreadyUsers()
	for _, p in pairs(self.peers) do
		p._set("modifiers", self.modifiers)
	end
end

function Room:pushNotechart()
	self:unreadyUsers()
	for _, p in pairs(self.peers) do
		p._set("notechart", self.notechart)
	end
end

function Room:pushMessage(message)
	for _, p in pairs(self.peers) do
		p._addMessage(message)
	end
end

return Room
