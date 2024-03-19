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

function handlers.setModifiers(peer, modifiers)
	handlers.setUserModifiers(peer, modifiers)
	handlers.setRoomModifiers(peer, modifiers)
end

function handlers.setNotechart(peer, notechart)
	handlers.setUserNotechart(peer, notechart)
	handlers.setRoomNotechart(peer, notechart)
end

local function create_handler(resource, method, rules)
	return function(peer, ...)
		local user = peer_users[peer.id]
		if not user.room then
			return
		end
		if rules.host and not user:isHost() then
			return
		end
		local res = user
		if resource == "room" then
			res = user.room
		end
		res[method](res, ...)
	end
end

handlers.startMatch = create_handler("user", "startMatch", {host = true})
handlers.stopMatch = create_handler("user", "stopMatch", {host = true})
handlers.switchReady = create_handler("user", "switchReady", {})
handlers.setNotechartFound = create_handler("user", "setNotechartFound", {})
handlers.setIsPlaying = create_handler("user", "setPlaying", {})
handlers.setFreeModifiers = create_handler("room", "setFreeModifiers", {host = true})
handlers.setFreeNotechart = create_handler("room", "setFreeNotechart", {host = true})
handlers.setUserModifiers = create_handler("user", "setModifiers", {})
handlers.setRoomModifiers = create_handler("room", "setModifiers", {host = true})
handlers.setUserNotechart = create_handler("user", "setNotechart", {})
handlers.setRoomNotechart = create_handler("room", "setNotechart", {host = true})
handlers.setHost = create_handler("room", "setHost", {host = true})
handlers.kickUser = create_handler("room", "kickUser", {host = true})
handlers.sendMessage = create_handler("user", "sendMessage", {})

return multiplayer
