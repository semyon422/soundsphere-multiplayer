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
User.room = nil

function User:new()
	self.score = {}
	self.modifiers = {}
	self.notechart = {}
end

function User:dto()
	return {
		id = self.id,
		name = self.name,
		isReady = self.isReady,
		isNotechartFound = self.isNotechartFound,
		isPlaying = self.isPlaying,
		score = self.score,
		modifiers = self.modifiers,
		notechart = self.notechart,
	}
end

function User:isHost()
	local room = self.room
	return room and room.host_user_id == self.id
end

function User:sendMessage(message)
	self.room:pushMessage(("%s: %s"):format(self.name, message))
end

function User:setNotechart(notechart)
	self.notechart = notechart
	self.room:pushUsers()
end

function User:setModifiers(modifiers)
	self.modifiers = modifiers
	self.room:pushUsers()
end

function User:setPlaying(value)
	self.isPlaying = value
	self:pushSelf()
	self.room:pushUsers()
end

function User:setNotechartFound(value)
	self.isNotechartFound = value
	self:pushSelf()
	self.room:pushUsers()
end

function User:switchReady()
	self.isReady = not self.isReady
	self:pushSelf()
	self:pushUsers()
end

function User:pushSelf()
	self.peer._set("user", self:dto())
end

function User:pushRoom(room)
	self.peer._set("room", room)
end

function User:pushRooms(rooms)
	self.peer._set("rooms", rooms)
end

function User:pushUsers(users)
	self.peer._set("users", users)
end

function User:pushRoomUsers(users)
	self.peer._set("roomUsers", users)
end

function User:pushModifiers(modifiers)
	self.peer._set("modifiers", modifiers)
end

function User:pushNotechart(notechart)
	self.peer._set("notechart", notechart)
end

function User:addMessage(message)
	self.peer._addMessage(message)
end

function User:startMatch()
	self.peer._startMatch()
end

function User:stopMatch()
	self.peer._stopMatch()
end

return User
