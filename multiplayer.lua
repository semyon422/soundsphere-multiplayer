local table_util = require("table_util")
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
	user.id = ("%s/%s"):format(user_id, peer.id)
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

	local index = table_util.indexof(users, peer_users[id])
	table.remove(users, index)
	pushUsers()

	peer_users[id] = nil
end

function multiplayer.update()
	local needPushRooms = false
	local deleteRoomIndex = nil
	for i, room in pairs(rooms) do
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
		if #room.users == 0 then
			deleteRoomIndex = i
			needPushRooms = true
		end
	end
	if deleteRoomIndex then
		table.remove(rooms, deleteRoomIndex)
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
	return user.room and user.room:dto()
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

local roomIdCounter = 0
function handlers.createRoom(peer, name, password)
	local user = peer_users[peer.id]
	if user.room then
		return
	end

	roomIdCounter = roomIdCounter + 1
	local room = Room()
	table.insert(rooms, room)

	room.password = password
	room.id = roomIdCounter
	room.name = name
	room.host_user_id = user.id

	room:addUser(user)
	pushRooms()

	return room:dto()
end

function handlers.joinRoom(peer, roomId, password)
	local index = table_util.indexof(rooms, roomId, function(r) return r.id end)
	local room = rooms[index]
	local user = peer_users[peer.id]
	if not room or user.room or room.password ~= password then
		return
	end
	room:addUser(user)
	return room:dto()
end

function handlers.leaveRoom(peer)
	local user = peer_users[peer.id]
	if not user then
		return
	end
	local room = user.room
	if not room then
		return
	end
	room:kickUser(user.id)
end

function handlers.setModifiers(...)
	handlers.setUserModifiers(...)
	handlers.setRoomModifiers(...)
end

function handlers.setConst(...)
	handlers.setUserConst(...)
	handlers.setRoomConst(...)
end

function handlers.setRate(...)
	handlers.setUserRate(...)
	handlers.setRoomRate(...)
end

function handlers.setNotechart(peer, notechart)
	handlers.setUserNotechart(peer, notechart)
	handlers.setRoomNotechart(peer, notechart)
end

local function create_handler(resource, method, rules)
	return function(peer, ...)
		local user = peer_users[peer.id]
		if not user or not user.room then
			return
		end
		if rules.host and not user:isHost() then
			return
		end
		local res = user
		if resource == "room" then
			res = user.room
		end
		return res[method](res, ...)
	end
end

-- user

handlers.setScore = create_handler("user", "setScore", {})
handlers.switchReady = create_handler("user", "switchReady", {})
handlers.setNotechartFound = create_handler("user", "setNotechartFound", {})
handlers.setIsPlaying = create_handler("user", "setPlaying", {})

handlers.setUserModifiers = create_handler("user", "setModifiers", {})
handlers.setUserConst = create_handler("user", "setConst", {})
handlers.setUserRate = create_handler("user", "setRate", {})
handlers.setUserNotechart = create_handler("user", "setNotechart", {})

handlers.sendMessage = create_handler("user", "sendMessage", {})

-- room

handlers.setFreeModifiers = create_handler("room", "setFreeModifiers", {host = true})
handlers.setFreeRate = create_handler("room", "setFreeRate", {host = true})
handlers.setFreeConst = create_handler("room", "setFreeConst", {host = true})
handlers.setFreeNotechart = create_handler("room", "setFreeNotechart", {host = true})
handlers.setRoomModifiers = create_handler("room", "setModifiers", {host = true})
handlers.setRoomRate = create_handler("room", "setRate", {host = true})
handlers.setRoomConst = create_handler("room", "setConst", {host = true})
handlers.setRoomNotechart = create_handler("room", "setNotechart", {host = true})

handlers.setHost = create_handler("room", "setHost", {host = true})
handlers.kickUser = create_handler("room", "kickUser", {host = true})
handlers.startMatch = create_handler("room", "startMatch", {host = true})
handlers.stopMatch = create_handler("room", "stopMatch", {host = true})

return multiplayer
