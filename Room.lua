local class = require("class")

---@class multiplayer.Room
---@operator call: multiplayer.Room
local Room = class()

Room.isFreeModifiers = false
Room.isFreeNotechart = false
Room.isPlaying = false
Room.id = nil
Room.name = nil
Room.host_user_id = nil

function Room:new()
	self.password = ""
	self.users = {}
	self.modifiers = {}
	self.notechart = {}
end

function Room:dto()
	return {
		id = self.id,
		name = self.name,
		host_user_id = self.host_user_id,
		isFreeModifiers = self.isFreeModifiers,
		isFreeNotechart = self.isFreeNotechart,
		isPlaying = self.isPlaying,
	}
end

function Room:push()
	local dto = self:dto()
	for _, u in pairs(self.users) do
		u:pushRoom(dto)
	end
end

function Room:pushUsers()
	local dtos = {}
	for i, user in ipairs(self.users) do
		dtos[i] = user:dto()
	end
	for _, u in pairs(self.users) do
		u:pushRoomUsers(dtos)
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
	for _, u in pairs(self.users) do
		u:pushModifiers(self.modifiers)
	end
end

function Room:pushNotechart()
	self:unreadyUsers()
	for _, u in pairs(self.users) do
		u:pushNotechart(self.notechart)
	end
end

function Room:pushMessage(message)
	for _, u in pairs(self.users) do
		u:addMessage(message)
	end
end

function Room:startMatch()
	self:unreadyUsers()
	for _, u in pairs(self.users) do
		u:startMatch()
	end
end

function Room:stopMatch()
	for _, u in pairs(self.users) do
		u:stopMatch()
	end
end

return Room
