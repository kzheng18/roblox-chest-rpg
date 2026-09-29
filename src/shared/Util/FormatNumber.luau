--!strict
local suffixes = {"", "K", "M", "B", "T", "Qa"}

return function(value: number): string
	if value ~= value or math.abs(value) == math.huge then
		return "—"
	end
	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)
	local i = 1
	while n >= 999.95 and i < #suffixes do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return sign .. tostring(math.floor(n))
	end
	return sign .. string.format("%.1f", n):gsub("%.0$", "") .. suffixes[i]
end

