local multiplayer = {
	handlers = {},
}
local handlers = multiplayer.handlers

local rooms = {}
local roomPasswords = {}
local roomUsers = {}
local roomPeers = {}

local users = {}

local peers = {}
local peerIdByKey = {}
local peerUsers = {}
local peerRooms = {}

local function delete(t, v)
	if not v then
		return
	end
	for i, value in ipairs(t) do
		if value == v then
			table.remove(t, i)
			break
		end
	end
end

local function indexof(t, v)
	for i, value in pairs(t) do
		if value == v then
			return i
		end
	end
	return nil
end

function multiplayer.peerconnected(peer)
	print("peerconnected", peer.id)

	peers[peer.id] = peer
end

function multiplayer.peerdisconnected(peer)
	local id = peer.id
	print("peerdisconnected", id)

	handlers.leaveRoom(peer)

	delete(users, peerUsers[id])
	peerUsers[id] = nil
	peers[id] = nil
end

-- http handlers

function multiplayer.login(params)
	local peer = peers[peerIdByKey[params.key]]
	if not peer then
		return
	end
	peerIdByKey[params.key] = nil

	local user = {
		id = tonumber(params.user_id),
		name = params.user_name,
		isReady = false,
	}
	peerUsers[peer.id] = user
	table.insert(users, user)

	peer._set("user", user)
	for _, p in pairs(peers) do
		p._set("users", users)
	end
end

-- remote handlers

function handlers.getRooms() return rooms end
function handlers.getUsers() return users end
function handlers.getUser(peer) return peerUsers[peer.id] end
function handlers.getRoom(peer) return peerRooms[peer.id] end

function handlers.login(peer)
	if peerUsers[peer.id] then
		return
	end

	local key = tostring(math.random(1000000, 9999999))
	peerIdByKey[key] = peer.id

	return key
end

local function pushRoomUsers(room)
	for _, p in pairs(roomPeers[room.id]) do
		p._set("roomUsers", roomUsers[room.id])
	end
end

function handlers.switchReady(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	local user = peerUsers[peer.id]
	user.isReady = not user.isReady
	peer._set("user", user)
	pushRoomUsers(room)
end

local roomIdCounter = 0
function handlers.createRoom(peer, name, password)
	if peerRooms[peer.id] then
		return
	end

	local user = peerUsers[peer.id]

	roomIdCounter = roomIdCounter + 1
	local room = {
		id = roomIdCounter,
		name = name,
		hostUser = user,
		isFreeModifiers = false,
	}
	peerRooms[peer.id] = room
	table.insert(rooms, room)

	roomUsers[room.id] = {user}
	roomPeers[room.id] = {peer}
	roomPasswords[room.id] = password

	pushRoomUsers(room)
	for _, p in pairs(peers) do
		p._set("rooms", rooms)
	end

	return room
end

function handlers.joinRoom(peer, roomId, password)
	local room = indexof(rooms, roomId)
	if not room or peerRooms[peer.id] then
		return
	end

	if roomPasswords[room.id] ~= password then
		return
	end

	peerRooms[peer.id] = room
	table.insert(roomUsers[room.id], peerUsers[peer.id])
	table.insert(roomPeers[room.id], peer)
	pushRoomUsers(room)

	return room
end

function handlers.leaveRoom(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	delete(roomUsers[room.id], peerUsers[peer.id])
	delete(roomPeers[room.id], peer)
	peerRooms[peer.id] = nil
	pushRoomUsers(room)

	if #roomUsers[room.id] == 0 then
		delete(rooms, room)
		roomPasswords[room.id] = nil
		roomUsers[room.id] = nil
		roomPeers[room.id] = nil

		for _, p in pairs(peers) do
			p._set("rooms", rooms)
		end
	end
	return true
end

function handlers.setFreeModifiers(peer, isFreeModifiers)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	room.isFreeModifiers = isFreeModifiers
end

return multiplayer
