local util = require("util")
local config = require("config")
local Room = require("Room")
local User = require("User")

local multiplayer = {
	handlers = {},
}
local handlers = multiplayer.handlers

local rooms = {}
local users = {}

local peer_by_key = {}
local peer_users = {}

local function pushRooms()
	local dtos = {}
	for i, room in ipairs(rooms) do
		dtos[i] = room:dto()
	end
	for _, u in pairs(users) do
		u:pushRooms(dtos)
	end
end

local function pushUsers()
	local dtos = {}
	for i, user in ipairs(users) do
		dtos[i] = user:dto()
	end
	for _, u in pairs(users) do
		u:pushUsers(dtos)
	end
end

local function addUser(peer, user_id, user_name)
	local user = User()
	user.id = user_id
	user.peer = peer
	user.name = user_name
	peer_users[peer.id] = user
	table.insert(users, user)

	user:pushSelf()
	pushUsers()
	pushRooms()
end

function multiplayer.peerconnected(peer)
	print("peerconnected", peer.id)
end

function multiplayer.peerdisconnected(peer)
	local id = peer.id
	print("peerdisconnected", id)

	handlers.leaveRoom(peer)

	util.delete(users, peer_users[id])
	pushUsers()

	peer_users[id] = nil
end

function multiplayer.update()
	local needPushRooms = false
	for _, room in pairs(rooms) do
		local isPlaying = false
		for _, user in pairs(room.users) do
			if user.isPlaying then
				isPlaying = true
				break
			end
		end
		if room.isPlaying ~= isPlaying then
			room.isPlaying = isPlaying
			needPushRooms = true
			room:push()
		end
	end
	if needPushRooms then
		pushRooms()
	end
end

-- http handlers

function multiplayer.login(params)
	local peer = peer_by_key[params.key]
	if not peer then
		return
	end
	peer_by_key[params.key] = nil

	addUser(peer, tonumber(params.user_id), params.user_name)
end

-- remote handlers

function handlers.getRooms() return rooms end
function handlers.getUsers() return users end
function handlers.getUser(peer) return peer_users[peer.id]:dto() end
function handlers.getRoom(peer)
	local user = peer_users[peer.id]
	return user.room:dto()
end

function handlers.login(peer)
	if peer_users[peer.id] then
		return
	end

	if config.offlineMode then
		return ""
	end

	local key = tostring(math.random(1000000, 9999999))
	peer_by_key[key] = peer

	return key
end

function handlers.loginOffline(peer, user_id, user_name)
	if not config.offlineMode then
		return
	end
	addUser(peer, user_id, user_name)
end

function handlers.startMatch(peer)
	local user = peer_users[peer.id]
	local room = user.room
	if not room or room.isPlaying or not user:isHost() then
		return
	end
	room:startMatch()
end

function handlers.stopMatch(peer)
	local user = peer_users[peer.id]
	local room = user.room
	if not room or not room.isPlaying or not user:isHost() then
		return
	end
	room:stopMatch()
end

function handlers.switchReady(peer)
	local user = peer_users[peer.id]
	local room = user.room
	if not room then
		return
	end
	user:switchReady()
end

function handlers.setNotechartFound(peer, value)
	local user = peer_users[peer.id]
	if not user then
		return
	end
	user:setNotechartFound(value)
end

function handlers.setIsPlaying(peer, value)
	local user = peer_users[peer.id]
	if not user then
		return
	end
	user:setPlaying(value)
end

function handlers.setScore(peer, score)
	local user = peer_users[peer.id]
	if not user then
		return
	end
	user.score = score
end

local roomIdCounter = 0
function handlers.createRoom(peer, name, password)
	local user = peer_users[peer.id]
	if user.room then
		return
	end

	roomIdCounter = roomIdCounter + 1
	local room = Room()
	user.room = room
	table.insert(rooms, room)

	table.insert(room.users, user)
	room.password = password
	room.id = roomIdCounter
	room.name = name
	room.host_user_id = user.id

	room:pushUsers()
	pushRooms()

	return room:dto()
end

function handlers.joinRoom(peer, roomId, password)
	local room = rooms[util.indexofid(rooms, roomId)]
	local user = peer_users[peer.id]
	if not room or user.room or room.password ~= password then
		return
	end
	room:addUser(user)
	return room:dto()
end

function handlers.leaveRoom(peer)
	local user = peer_users[peer.id]
	local room = user.room
	if not room then
		return
	end
	room:kickUser(user.id)

	if #room.users == 0 then
		util.delete(rooms, room)
		pushRooms()
		return true
	end

	if room.host_user_id == user.id then
		room:setHost(room.users[1].id)
	end

	return true
end

function handlers.getRoomUsers(peer)
	local user = peer_users[peer.id]
	local room = user.room
	if not room then
		return
	end
	local dtos = {}
	for i, user in ipairs(room.users) do
		dtos[i] = user:dto()
	end
	return dtos
end

function handlers.getRoomModifiers(peer)
	local user = peer_users[peer.id]
	local room = user.room
	if not room then
		return
	end
	return room.modifiers
end

function handlers.getRoomNotechart(peer)
	local user = peer_users[peer.id]
	local room = user.room
	if not room then
		return
	end
	return room.notechart
end

function handlers.setFreeModifiers(peer, isFreeModifiers)
	local user = peer_users[peer.id]
	local room = user.room
	if not room or not user:isHost() then
		return
	end
	room:setFreeModifiers(isFreeModifiers)
end

function handlers.setFreeNotechart(peer, isFreeNotechart)
	local user = peer_users[peer.id]
	local room = user.room
	if not room or not user:isHost() then
		return
	end
	room:setFreeNotechart(isFreeNotechart)
end

function handlers.setModifiers(peer, modifiers)
	handlers.setUserModifiers(peer, modifiers)
	handlers.setRoomModifiers(peer, modifiers)
end

function handlers.setUserModifiers(peer, modifiers)
	local user = peer_users[peer.id]
	if not user then
		return
	end
	user:setModifiers(modifiers)
end

function handlers.setRoomModifiers(peer, modifiers)
	local user = peer_users[peer.id]
	local room = user.room
	if not room or not user:isHost() then
		return
	end
	room:setModifiers(modifiers)
end

function handlers.setNotechart(peer, notechart)
	handlers.setUserNotechart(peer, notechart)
	handlers.setRoomNotechart(peer, notechart)
end

function handlers.setUserNotechart(peer, notechart)
	local user = peer_users[peer.id]
	if not user then
		return
	end
	user:setNotechart(notechart)
end

function handlers.setRoomNotechart(peer, notechart)
	local user = peer_users[peer.id]
	local room = user.room
	if not room or not user:isHost() then
		return
	end
	room:setNotechart(notechart)
end

function handlers.setHost(peer, user_id)
	local user = peer_users[peer.id]
	local room = user.room
	if not room or not user:isHost() then
		return
	end
	room:setHost(user_id)
end

function handlers.kickUser(peer, user_id)
	local user = peer_users[peer.id]
	local room = user.room
	if not room or not user:isHost() or user.id == user_id then
		return
	end
	room:kickUser(user_id)
end

function handlers.sendMessage(peer, message)
	local user = peer_users[peer.id]
	if not user then
		return
	end
	user:sendMessage(message)
end

return multiplayer
