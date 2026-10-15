--!strict

local RarityFormat = {}

function RarityFormat.Rate(rateN: number): string
	local normalized = math.max(1, math.floor(rateN + 0.5))
	return "1/" .. tostring(normalized)
end

return RarityFormat
