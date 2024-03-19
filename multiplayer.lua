local util = require("util")
local config = require("config")
local Room = require("Room")

local multiplayer = {
	handlers = {},
}
local handlers = multiplayer.handlers

local rooms = {}

local users = {}

local peers = {}
local peerIdByKey = {}
local peerUsers = {}
local peerRooms = {}

local function pushRooms()
	for _, p in pairs(peers) do
		local dtos = {}
		for i, room in ipairs(rooms) do
			dtos[i] = room:dto()
		end
		p._set("rooms", dtos)
	end
end

local function pushUsers()
	for _, p in pairs(peers) do
		p._set("users", users)
	end
end

local function isHost(peer)
	local room = peerRooms[peer.id]
	if not room or room.hostPeerId ~= peer.id then
		return false
	end
	return true
end

local function addUser(peer, user_id, user_name)
	local user = {
		id = user_id,
		peerId = peer.id,
		name = user_name,
		isReady = false,
		isNotechartFound = false,
		isPlaying = false,
		score = {},
		modifiers = {},
		notechart = {},
	}
	peerUsers[peer.id] = user
	table.insert(users, user)

	peer._set("user", user)
	pushUsers()
	pushRooms()
end

function multiplayer.peerconnected(peer)
	print("peerconnected", peer.id)

	peers[peer.id] = peer
end

function multiplayer.peerdisconnected(peer)
	local id = peer.id
	print("peerdisconnected", id)

	handlers.leaveRoom(peer)

	util.delete(users, peerUsers[id])
	pushUsers()

	peerUsers[id] = nil
	peers[id] = nil
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
	local peer = peers[peerIdByKey[params.key]]
	if not peer then
		return
	end
	peerIdByKey[params.key] = nil

	addUser(peer, tonumber(params.user_id), params.user_name)
end

-- remote handlers

function handlers.getRooms() return rooms end
function handlers.getUsers() return users end
function handlers.getUser(peer) return peerUsers[peer.id] end
function handlers.getRoom(peer) return peerRooms[peer.id]:dto() end

function handlers.login(peer)
	if peerUsers[peer.id] then
		return
	end

	if config.offlineMode then
		return ""
	end

	local key = tostring(math.random(1000000, 9999999))
	peerIdByKey[key] = peer.id

	return key
end

function handlers.loginOffline(peer, user_id, user_name)
	if not config.offlineMode then
		return
	end
	addUser(peer, user_id, user_name)
end

function handlers.startMatch(peer)
	local room = peerRooms[peer.id]
	if not room or room.isPlaying or not isHost(peer) then
		return
	end
	room:unreadyUsers()
	for _, p in pairs(room.peers) do
		p._startMatch()
	end
end

function handlers.stopMatch(peer)
	local room = peerRooms[peer.id]
	if not room or not room.isPlaying or not isHost(peer) then
		return
	end
	for _, p in pairs(room.peers) do
		p._stopMatch()
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
	room:pushUsers()
end

function handlers.setNotechartFound(peer, value)
	local room = peerRooms[peer.id]
	local user = peerUsers[peer.id]
	if not user or not room then
		return
	end
	user.isNotechartFound = value
	peer._set("user", user)
	room:pushUsers()
end

function handlers.setIsPlaying(peer, value)
	local user = peerUsers[peer.id]
	if not user then
		return
	end
	user.isPlaying = value
	peer._set("user", user)

	local room = peerRooms[peer.id]
	if room then
		room:pushUsers()
	end
end

function handlers.setScore(peer, score)
	local user = peerUsers[peer.id]
	if not user then
		return
	end
	user.score = score
end

local roomIdCounter = 0
function handlers.createRoom(peer, name, password)
	if peerRooms[peer.id] then
		return
	end

	local user = peerUsers[peer.id]

	roomIdCounter = roomIdCounter + 1
	local room = Room()
	peerRooms[peer.id] = room
	table.insert(rooms, room)

	table.insert(room.users, user)
	table.insert(room.peers, peer)
	room.password = password
	room.id = roomIdCounter
	room.name = name
	room.hostPeerId = peer.id

	room:pushUsers()
	pushRooms()

	return room:dto()
end

function handlers.joinRoom(peer, roomId, password)
	local room = rooms[util.indexofid(rooms, roomId)]
	if not room or peerRooms[peer.id] then
		return
	end

	if room.password ~= password then
		return
	end

	peerRooms[peer.id] = room
	table.insert(room.users, peerUsers[peer.id])
	table.insert(room.peers, peer)
	room:pushUsers()

	if not room.isFreeNotechart then
		peer._set("notechart", room.notechart)
	end
	if not room.isFreeModifiers then
		peer._set("modifiers", room.modifiers)
	end

	return room
end

function handlers.leaveRoom(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	util.delete(room.users, peerUsers[peer.id])
	util.delete(room.peers, peer)
	peerRooms[peer.id] = nil

	if #room.users == 0 then
		util.delete(rooms, room)
		pushRooms()
		return true
	end

	if room.hostPeerId == peer.id then
		room.hostPeerId = room.users[1].peerId
	end
	room:push()
	room:pushUsers()

	return true
end

function handlers.getRoomUsers(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	return room.users
end

function handlers.getRoomModifiers(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	return room.modifiers
end

function handlers.getRoomNotechart(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	return room.notechart
end

function handlers.setFreeModifiers(peer, isFreeModifiers)
	local room = peerRooms[peer.id]
	if not room or not isHost(peer) then
		return
	end
	room.isFreeModifiers = isFreeModifiers
	room:push()

	if isFreeModifiers then
		return
	end
	room:pushModifiers()
end

function handlers.setFreeNotechart(peer, isFreeNotechart)
	local room = peerRooms[peer.id]
	if not room or not isHost(peer) then
		return
	end
	room.isFreeNotechart = isFreeNotechart
	room:push()

	if isFreeNotechart then
		return
	end
	room:pushNotechart()
end

function handlers.setModifiers(peer, modifiers)
	local user = peerUsers[peer.id]
	if not user then
		return
	end
	user.modifiers = modifiers

	local room = peerRooms[peer.id]
	if not room then
		return
	end
	room:pushUsers()

	if not isHost(peer) then
		return
	end
	room.modifiers = modifiers

	if room.isFreeModifiers then
		return
	end
	room:pushModifiers()
end

function handlers.setNotechart(peer, notechart)
	local user = peerUsers[peer.id]
	if not user then
		return
	end
	user.notechart = notechart

	local room = peerRooms[peer.id]
	if not room then
		return
	end
	room:pushUsers()

	if not isHost(peer) then
		return
	end
	room.notechart = notechart

	if room.isFreeNotechart then
		return
	end
	room:pushNotechart()
end

function handlers.setHost(peer, peerId)
	local room = peerRooms[peer.id]
	if not room or not isHost(peer) then
		return
	end

	local user
	for _, u in pairs(room.users) do
		if u.peerId == peerId then
			user = u
			break
		end
	end
	if not user then
		return
	end

	room.hostPeerId = user.peerId
	room:push()
end

function handlers.kickUser(peer, peerId)
	local room = peerRooms[peer.id]
	if not room or not isHost(peer) or peer.id == peerId then
		return
	end

	local kickedPeer = peers[peerId]
	util.delete(room.users, peerUsers[peerId])
	util.delete(room.peers, kickedPeer)
	peerRooms[peerId] = nil

	kickedPeer._set("room", nil)
	room:pushUsers()
end

function handlers.sendMessage(peer, message)
	local room = peerRooms[peer.id]
	local user = peerUsers[peer.id]
	if not room or not user then
		return
	end

	message = user.name .. ": " .. tostring(message)

	room:pushMessage(message)
end

return multiplayer
