local url = require("socket.url")

return function(query, params, need_unescape)
	params = params or {}
	query:gsub("([^&=]+)=([^&=]*)&?", function(k, v)
		if need_unescape then
			k = url.unescape(k)
			v = url.unescape(v)
		end
		params[k] = v
	end)
end
