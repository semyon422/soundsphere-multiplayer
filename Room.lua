local class = require("class")
local table_util = require("table_util")

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

function Room:getModifiers()
	return self.modifiers
end

function Room:getNotechart()
	return self.notechart
end

function Room:getUsers()
	local dtos = {}
	for i, user in ipairs(self.users) do
		dtos[i] = user:dto()
	end
	return dtos
end

local function _user_id(u) return u.id end

function Room:findUser(user_id)
	return table_util.indexof(self.users, user_id, _user_id)
end

function Room:setHost(user_id)
	if not self:findUser(user_id) then
		return
	end
	self.host_user_id = user_id
	self:push()
end

function Room:kickUser(user_id)
	local index = self:findUser(user_id)
	if not index then
		return
	end
	local user = table.remove(self.users, index)
	user.room = nil
	user:pushRoom(nil)
	self:pushUsers()
	if self.host_user_id == user_id and self.users[1] then
		self:setHost(self.users[1].id)
	end
end

function Room:addUser(user)
	user.room = self
	table.insert(self.users, user)
	self:pushUsers()
	if not self.isFreeNotechart then
		user:pushNotechart(self.notechart)
	end
	if not self.isFreeModifiers then
		user:pushModifiers(self.modifiers)
	end
end

function Room:setNotechart(notechart)
	self.notechart = notechart
	if self.isFreeNotechart then
		return
	end
	self:pushNotechart()
end

function Room:setModifiers(modifiers)
	self.modifiers = modifiers
	if self.isFreeModifiers then
		return
	end
	self:pushModifiers()
end

function Room:setFreeNotechart(isFreeNotechart)
	self.isFreeNotechart = isFreeNotechart
	self:push()
	if isFreeNotechart then
		return
	end
	self:pushNotechart()
end

function Room:setFreeModifiers(isFreeModifiers)
	self.isFreeModifiers = isFreeModifiers
	self:push()
	if isFreeModifiers then
		return
	end
	self:pushModifiers()
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
	if self.isPlaying then
		return
	end
	self:unreadyUsers()
	for _, u in pairs(self.users) do
		u:startMatch()
	end
end

function Room:stopMatch()
	if not self.isPlaying then
		return
	end
	for _, u in pairs(self.users) do
		u:stopMatch()
	end
end

return Room
