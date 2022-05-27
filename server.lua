local enet = require("enet")
local socket = require("socket")
local remote = require("remote")
local multiplayer = require("multiplayer")

remote.handlers = multiplayer.handlers

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
			remote.receive(event)
		end
	end

	local http_handler = loadfile("http_handler.lua")
	if http_handler then
		http_handler = http_handler()
		-- local method, path, content = webserver.accept()
		local res = http_handler(server)
		if res then
			print(require("inspect")(res))
			if res.method == "POST" and res.path == "/login" then
				multiplayer.login(res.params)
			end
		end
	end

	socket.sleep(0.1)
end


