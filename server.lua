local enet = require("enet")
local socket = require("socket")
local remote = require("remote")
local webserver = require("webserver")

local rooms = {
	{
		id = 1,
		name = "room1",
	},
	{
		id = 2,
		name = "room2",
	},
}

local users = {}

local peerLogins = {}
local peerIdByKey = {}

local handlers = remote.handlers
handlers.ping = function(peer, ...)
	local ret = peer.print("hello")
	return "ping", ret, ...
end

handlers.login = function(peer)
	local key = tostring(math.random(1000000, 9999999))
	local id = peer.peer:connect_id()
	peerLogins[id] = {
		key = key,
		peer = peer,
		isLoggedIn = false,
	}
	peerIdByKey[key] = id
	print("login", id, key)
	return key
end

handlers.getRooms = function(peer)
	return rooms
end

handlers.getUsers = function(peer)
	return users
end

handlers.getUser = function(peer)
	local id = peer.peer:connect_id()
	local login = peerLogins[id]
	if not login then
		return
	end
	return login.user or {name = "guest"}
end

handlers.createRoom = function(peer, name, password)
	table.insert(rooms, {
		name = name,
		password = password,
	})
end

local host = enet.host_create("*:9000")
webserver.start("127.0.0.1", 9001)

local printConnected = remote.wrap(function(peer)
	peer.print("connected")
end)

local function connect(peer)
	printConnected(peer)
end

while true do
	local event = host:service(0)
	if event then
		if event.type == "connect" then
			connect(remote.peer(event.peer))
		elseif event.type == "receive" then
			remote.receive(event)
		end
	end

	local http_handler = loadfile("http_handler.lua")
	if http_handler then
		http_handler = http_handler()
		-- local method, path, content = webserver.accept()
		local res = http_handler(webserver.server)
		if res then
			print(require("inspect")(res))
			if res.method == "POST" and res.path == "/login" and res.params.key then
				local id = peerIdByKey[res.params.key]
				print("login", res.params.key, id)
				local peerLogin = peerLogins[id]
				if id then
					peerLogin.user = {
						id = res.params.user_id,
						name = res.params.user_name,
					}
					table.insert(users, peerLogin.user)
				end
			end
		end
	end

	socket.sleep(0.1)
end


