local util = require("util")
local config = require("config")

local multiplayer = {
	handlers = {},
}
local handlers = multiplayer.handlers

local rooms = {}
local roomPasswords = {}
local roomUsers = {}
local roomPeers = {}
local roomModifiers = {}
local roomNotecharts = {}

local users = {}

local peers = {}
local peerIdByKey = {}
local peerUsers = {}
local peerRooms = {}

local function pushRoom(room)
	for _, p in pairs(roomPeers[room.id]) do
		p._set("room", room)
	end
end

local function pushRoomUsers(room)
	for _, p in pairs(roomPeers[room.id]) do
		p._set("roomUsers", roomUsers[room.id])
	end
end

local function unreadyRoomUsers(room)
	for _, p in pairs(roomPeers[room.id]) do
		peerUsers[p.id].isReady = false
	end
	pushRoomUsers(room)
end

local function pushRoomModifiers(room)
	unreadyRoomUsers(room)
	for _, p in pairs(roomPeers[room.id]) do
		p._set("modifiers", roomModifiers[room.id])
	end
end

local function pushRoomNotechart(room)
	unreadyRoomUsers(room)
	for _, p in pairs(roomPeers[room.id]) do
		p._set("notechart", roomNotecharts[room.id])
	end
end

local function pushRoomMessage(room, message)
	for _, p in pairs(roomPeers[room.id]) do
		p._addMessage(message)
	end
end

local function pushRooms()
	for _, p in pairs(peers) do
		p._set("rooms", rooms)
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
		for _, user in pairs(roomUsers[room.id]) do
			if user.isPlaying then
				isPlaying = true
				break
			end
		end
		if room.isPlaying ~= isPlaying then
			room.isPlaying = isPlaying
			needPushRooms = true
			pushRoom(room)
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
function handlers.getRoom(peer) return peerRooms[peer.id] end

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
	unreadyRoomUsers(room)
	for _, p in pairs(roomPeers[room.id]) do
		p._startMatch()
	end
end

function handlers.stopMatch(peer)
	local room = peerRooms[peer.id]
	if not room or not room.isPlaying or not isHost(peer) then
		return
	end
	for _, p in pairs(roomPeers[room.id]) do
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
	pushRoomUsers(room)
end

function handlers.setNotechartFound(peer, value)
	local room = peerRooms[peer.id]
	local user = peerUsers[peer.id]
	if not user or not room then
		return
	end
	user.isNotechartFound = value
	peer._set("user", user)
	pushRoomUsers(room)
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
		pushRoomUsers(room)
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
	local room = {
		id = roomIdCounter,
		name = name,
		hostPeerId = peer.id,
		isFreeModifiers = false,
		isFreeNotechart = false,
		isPlaying = false,
	}
	peerRooms[peer.id] = room
	table.insert(rooms, room)

	roomUsers[room.id] = {user}
	roomPeers[room.id] = {peer}
	roomPasswords[room.id] = password
	roomModifiers[room.id] = {}
	roomNotecharts[room.id] = {}

	pushRoomUsers(room)
	pushRooms()

	return room
end

function handlers.joinRoom(peer, roomId, password)
	local room = rooms[util.indexofid(rooms, roomId)]
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

	if not room.isFreeNotechart then
		peer._set("notechart", roomNotecharts[room.id])
	end
	if not room.isFreeModifiers then
		peer._set("modifiers", roomModifiers[room.id])
	end

	return room
end

function handlers.leaveRoom(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	util.delete(roomUsers[room.id], peerUsers[peer.id])
	util.delete(roomPeers[room.id], peer)
	peerRooms[peer.id] = nil

	if #roomUsers[room.id] == 0 then
		util.delete(rooms, room)
		roomPasswords[room.id] = nil
		roomUsers[room.id] = nil
		roomPeers[room.id] = nil
		roomModifiers[room.id] = nil
		roomNotecharts[room.id] = nil

		pushRooms()
		return true
	end

	if room.hostPeerId == peer.id then
		room.hostPeerId = roomUsers[room.id][1].peerId
	end
	pushRoom(room)
	pushRoomUsers(room)

	return true
end

function handlers.getRoomUsers(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	return roomUsers[room.id]
end

function handlers.getRoomModifiers(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	return roomModifiers[room.id]
end

function handlers.getRoomNotechart(peer)
	local room = peerRooms[peer.id]
	if not room then
		return
	end
	return roomNotecharts[room.id]
end

function handlers.setFreeModifiers(peer, isFreeModifiers)
	local room = peerRooms[peer.id]
	if not room or not isHost(peer) then
		return
	end
	room.isFreeModifiers = isFreeModifiers
	pushRoom(room)

	if isFreeModifiers then
		return
	end
	pushRoomModifiers(room)
end

function handlers.setFreeNotechart(peer, isFreeNotechart)
	local room = peerRooms[peer.id]
	if not room or not isHost(peer) then
		return
	end
	room.isFreeNotechart = isFreeNotechart
	pushRoom(room)

	if isFreeNotechart then
		return
	end
	pushRoomNotechart(room)
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
	pushRoomUsers(room)

	if not isHost(peer) then
		return
	end
	roomModifiers[room.id] = modifiers

	if room.isFreeModifiers then
		return
	end
	pushRoomModifiers(room)
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
	pushRoomUsers(room)

	if not isHost(peer) then
		return
	end
	roomNotecharts[room.id] = notechart

	if room.isFreeNotechart then
		return
	end
	pushRoomNotechart(room)
end

function handlers.setHost(peer, peerId)
	local room = peerRooms[peer.id]
	if not room or not isHost(peer) then
		return
	end

	local user
	for _, u in pairs(roomUsers[room.id]) do
		if u.peerId == peerId then
			user = u
			break
		end
	end
	if not user then
		return
	end

	room.hostPeerId = user.peerId
	pushRoom(room)
end

function handlers.kickUser(peer, peerId)
	local room = peerRooms[peer.id]
	if not room or not isHost(peer) or peer.id == peerId then
		return
	end

	local kickedPeer = peers[peerId]
	util.delete(roomUsers[room.id], peerUsers[peerId])
	util.delete(roomPeers[room.id], kickedPeer)
	peerRooms[peerId] = nil

	kickedPeer._set("room", nil)
	pushRoomUsers(room)
end

function handlers.sendMessage(peer, message)
	local room = peerRooms[peer.id]
	local user = peerUsers[peer.id]
	if not room or not user then
		return
	end

	message = user.name .. ": " .. tostring(message)

	pushRoomMessage(room, message)
end

return multiplayer
