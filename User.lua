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
		const = self.const,
		rate = self.rate,
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
	self.room:push()
end

function User:setModifiers(modifiers)
	self.modifiers = modifiers
	self.room:push()
end

function User:setConst(const)
	self.const = const
	self.room:push()
end

function User:setRate(rate)
	self.rate = rate
	self.room:push()
end

function User:setPlaying(value)
	self.isPlaying = value
	self:pushSelf()
	self.room:push()
end

function User:setNotechartFound(value)
	self.isNotechartFound = value
	self:pushSelf()
	self.room:push()
end

function User:switchReady()
	self.isReady = not self.isReady
	self:pushSelf()
	self.room:push()
end

function User:setScore(score)
	self.score = score
end

function User:pushSelf()
	self.peer._set("user", self:dto())
end

function User:pushRoom()
	self.peer._set("room", self.room:dto())
end

function User:pushRooms(rooms)
	self.peer._set("rooms", rooms)
end

function User:pushUsers(users)
	self.peer._set("users", users)
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
