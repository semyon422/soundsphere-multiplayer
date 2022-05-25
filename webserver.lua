local socket = require("socket")

local webserver = {}

local server
function webserver.start(host, port)
	server = assert(socket.tcp())
	assert(server:bind(host, port))
	assert(server:listen(32))
	server:settimeout(0)
	webserver.server = server
end

function webserver.stop()
	server:close()
end

return webserver
