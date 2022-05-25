local function inside(t, key)
	local subvalue = t
	for subkey in key:gmatch("[^.]+") do
		if type(subvalue) ~= "table" then
			return
		end
		subvalue = subvalue[subkey]
	end
	return subvalue
end

return inside
