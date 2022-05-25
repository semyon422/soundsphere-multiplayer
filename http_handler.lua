local url = require("socket.url")
local parse_query = require("parse_query")

local ok200 = ([[HTTP/1.1 200 OK
Content-Length: 0

]]):gsub("\n", "\r\n")

return function(server)
	local client, err = server:accept()
	if not client then
		return
	end

	local line, err = client:receive("*l")
	if err then
		print(err)
		client:close()
		return
	end
	local method, path = line:match("^(%S+)%s+(%S+)%s+")

	local headers = {}
	local line
	repeat
		line = client:receive("*l")
		if line then
			local key, value = line:match("^(%S+):%s+(.*)")
			if key then
				headers[key:lower()] = value
			end
		end
	until line == ""

	local content
	if headers["content-length"] then
		content = client:receive(tonumber(headers["content-length"]))
	end

	client:send(ok200)
	client:close()

	local response, err = url.parse(path)
	if not response then
		print(err)
		return
	end

	local params = {}
	response.params = params
	response.method = method
	response.headers = headers
	response.content = content

	if response.query then
		parse_query(response.query, params, true)
	end

	local content_type = headers["content-type"] and headers["content-type"]:lower()
	if content and content_type == "application/x-www-form-urlencoded" then
		parse_query(content, params, true)
	end

	return response
end
