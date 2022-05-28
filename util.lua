local util = {}

function util.delete(t, v)
	if not v then
		return
	end
	for i, value in ipairs(t) do
		if value == v then
			table.remove(t, i)
			break
		end
	end
end

function util.indexof(t, v)
	for i, value in pairs(t) do
		if value == v then
			return i
		end
	end
	return nil
end

function util.indexofid(t, id)
	for i, value in pairs(t) do
		if value.id == id then
			return i
		end
	end
	return nil
end

return util
