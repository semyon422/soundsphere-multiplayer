local class = require("class")
local table_util = require("table_util")

---@class multiplayer.Room
---@operator call: multiplayer.Room
local Room = class()

Room.is_free_notechart = false
Room.isPlaying = false
Room.id = nil
Room.name = nil
Room.host_user_id = nil

Room.is_free_modifiers = false
Room.is_free_const = false
Room.is_free_rate = false
Room.modifiers = nil
Room.const = false
Room.rate = 1

function Room:new()
	self.password = ""
	self.users = {}
	self.notechart = {}
	self.modifiers = {}
end

function Room:dto()
	return {
		id = self.id,
		name = self.name,
		host_user_id = self.host_user_id,
		is_free_modifiers = self.is_free_modifiers,
		is_free_const = self.is_free_const,
		is_free_rate = self.is_free_rate,
		is_free_notechart = self.is_free_notechart,
		isPlaying = self.isPlaying,
		users = self:getUsers(),
		notechart = self.notechart,
		modifiers = self.modifiers,
		const = self.const,
		rate = self.rate,
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
	self:push()
	if self.host_user_id == user_id and self.users[1] then
		self:setHost(self.users[1].id)
	end
end

function Room:addUser(user)
	table.insert(self.users, user)
	user.room = self
	self:push()
end

function Room:setNotechart(notechart)
	self.notechart = notechart
	self:push()
end

function Room:setModifiers(modifiers)
	self.modifiers = modifiers
	self:push()
end

function Room:setConst(const)
	self.const = const
	self:push()
end

function Room:setRate(rate)
	self.rate = rate
	self:push()
end

function Room:setFreeNotechart(is_free_notechart)
	self.is_free_notechart = is_free_notechart
	self:push()
end

function Room:setFreeModifiers(is_free_modifiers)
	self.is_free_modifiers = is_free_modifiers
	self:push()
end

function Room:setFreeRate(is_free_rate)
	self.is_free_rate = is_free_rate
	self:push()
end

function Room:setFreeConst(is_free_const)
	self.is_free_const = is_free_const
	self:push()
end

function Room:push()
	for _, u in pairs(self.users) do
		u:pushRoom()
	end
end

function Room:unreadyUsers()
	for _, u in pairs(self.users) do
		u.isReady = false
	end
	self:push()
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
