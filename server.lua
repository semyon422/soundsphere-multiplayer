local enet = require("enet")
local socket = require("socket")
local remote = require("remote")
local MessagePack = require("MessagePack")
local multiplayer = require("multiplayer")
local http_handler = require("http_handler")

remote.encode = MessagePack.pack
remote.decode = MessagePack.unpack

local config = require("config")

-- enet host
local host = enet.host_create(("%s:%d"):format(config.enet.address, config.enet.port))

-- web server
local server
if not config.offlineMode then
	server = assert(socket.tcp())
	assert(server:bind(config.http.address, config.http.port))
	assert(server:listen(32))
	assert(server:settimeout(0))
end

while true do
	local event = host:service()
	while event do
		if event.type == "connect" then
			multiplayer.peerconnected(remote.peer(event.peer))
		elseif event.type == "disconnect" then
			multiplayer.peerdisconnected(remote.peer(event.peer))
		elseif event.type == "receive" then
			remote.receive(event, multiplayer.handlers)
		end
		event = host:service()
	end

	local res = http_handler(server)
	if
		res and
		res.method == "POST" and
		res.path == "/login" and
		res.params.token == config.http.token
	then
		multiplayer.login(res.params)
	end

	multiplayer.update()

	socket.sleep(0.01)
end


