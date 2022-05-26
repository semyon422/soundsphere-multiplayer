local multiplayer = {
	handlers = {},
}
local handlers = multiplayer.handlers

local rooms = {}
local roomPasswords = {}

local users = {}

local peers = {}
local peerIdByKey = {}
local peerKeyById = {}
local peerUsers = {}
local peerRooms = {}

local roomById = {}

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

function multiplayer.peerconnected(peer)
	print("peerconnected", peer.id)

	peers[peer.id] = peer
end

function multiplayer.peerdisconnected(peer)
	local id = peer.id
	print("peerdisconnected", id)

	handlers.leaveRoom(peer)

	peers[id] = nil
	if peerKeyById[id] then
		peerIdByKey[peerKeyById[id]] = nil
		peerKeyById[id] = nil
	end

	delete(users, peerUsers[id])
	peerUsers[id] = nil
end

-- http handlers

function multiplayer.login(params)
	local peer = peers[peerIdByKey[params.key]]
	if not peer then
		return
	end
	local user = {
		id = params.user_id,
		name = params.user_name,
		isReady = false,
	}
	peerUsers[peer.id] = user
	table.insert(users, user)
end

-- remote handlers

handlers.getRooms = function(peer)
	return rooms
end

handlers.getUsers = function(peer)
	return users
end

handlers.getUser = function(peer)
	return peerUsers[peer.id]
end

handlers.getRoom = function(peer)
	return peerRooms[peer.id]
end

handlers.login = function(peer)
	if peerUsers[peer.id] then
		return
	end

	local key = tostring(math.random(1000000, 9999999))
	peerIdByKey[key] = peer.id
	peerKeyById[peer.id] = key

	return key
end

handlers.switchReady = function(peer)
	local user = peerUsers[peer.id]
	user.isReady = not user.isReady
end

local roomIdCounter = 0
handlers.createRoom = function(peer, name, password)
	if peerRooms[peer.id] then
		return
	end

	roomIdCounter = roomIdCounter + 1
	local room = {
		id = roomIdCounter,
		name = name,
		hostUser = peerUsers[peer.id],
		isFreeModifiers = false,
		users = {
			peerUsers[peer.id],
		},
	}
	peerRooms[peer.id] = room
	roomById[roomIdCounter] = room
	table.insert(rooms, room)

	roomPasswords[room.id] = password

	return room
end

handlers.joinRoom = function(peer, roomId, password)
	local room = roomById[roomId]
	if not room or peerRooms[peer.id] then
		return
	end

	if roomPasswords[room.id] ~= password then
		return
	end

	peerRooms[peer.id] = room
	table.insert(room.users, peerUsers[peer.id])

	return room
end

handlers.leaveRoom = function(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	delete(room.users, peerUsers[peer.id])
	peerRooms[peer.id] = nil

	if #room.users == 0 then
		delete(rooms, room)
		roomById[room.id] = nil
		roomPasswords[room.id] = nil
	end
	return true
end

handlers.setFreeModifiers = function(peer, isFreeModifiers)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	room.isFreeModifiers = isFreeModifiers
end

return multiplayer
