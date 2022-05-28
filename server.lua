local enet = require("enet")
local socket = require("socket")
local remote = require("remote")
local MessagePack = require("MessagePack")
local multiplayer = require("multiplayer")
local http_handler = require("http_handler")

remote.encode = MessagePack.pack
remote.decode = MessagePack.unpack

-- enet host
local host = enet.host_create("*:9000")

-- web server
local server = assert(socket.tcp())
assert(server:bind("*", 9001))
assert(server:listen(32))
assert(server:settimeout(0))

while true do
	local event = host:service(0)
	if event then
		if event.type == "connect" then
			multiplayer.peerconnected(remote.peer(event.peer))
		elseif event.type == "disconnect" then
			multiplayer.peerdisconnected(remote.peer(event.peer))
		elseif event.type == "receive" then
			remote.receive(event, multiplayer.handlers)
		end
	end

	local res = http_handler(server)
	if res and res.method == "POST" and res.path == "/login" then
		multiplayer.login(res.params)
	end

	socket.sleep(0.1)
end


