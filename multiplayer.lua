local multiplayer = {
	handlers = {},
}

local rooms = {}
local users = {}

local peers = {}
local peerIdByKey = {}
local peerKeyById = {}
local peerUsers = {}

function multiplayer.peerconnected(peer)
	print("peerconnected", peer.id)

	peers[peer.id] = peer
end

function multiplayer.peerdisconnected(peer)
	local id = peer.id
	print("peerdisconnected", id)

	peers[id] = nil
	peerIdByKey[peerKeyById[id]] = nil
	peerKeyById[id] = nil

	local user = peerUsers[id]
	if not user then
		return
	end
	for i, u in ipairs(users) do
		if u == user then
			table.remove(users, i)
			break
		end
	end
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
	}
	peerUsers[peer.id] = user
	table.insert(users, user)
end

-- remote handlers

local handlers = multiplayer.handlers

handlers.login = function(peer)
	local key = tostring(math.random(1000000, 9999999))
	peerIdByKey[key] = peer.id
	peerKeyById[peer.id] = key
	return key
end

handlers.getRooms = function(peer)
	return rooms
end

handlers.getUsers = function(peer)
	return users
end

handlers.getUser = function(peer)
	local id = peer.id
	local user = peerUsers[id]
	if not user then
		return
	end
	return user or {name = "guest"}
end

handlers.createRoom = function(peer, name, password)
	table.insert(rooms, {
		name = name,
		password = password,
	})
end

return multiplayer
