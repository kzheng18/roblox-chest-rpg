--!strict
-- Exact drop odds for the independent power roll. Pure and deterministic given
-- a draw function, so it can be tested without Roblox's Random.
local Powers = require(script.Parent.Parent.Config.Powers)

export type Entry = {Power: any, Probability: number, RateN: number}

local PowerOdds = {}

local function effectiveWeight(power: any, luck: number): number
	return power.Weight * math.max(1, luck) ^ power.LuckExponent
end

-- Final, unconditional probability of each power from one chest opening.
function PowerOdds.Table(regionId: string, luck: number): {Entry}
	local pool = Powers.ByRegion[regionId]
	local chance = Powers.DropChance[regionId] or 0
	if not pool or #pool == 0 or chance <= 0 then return {} end
	local total = 0
	for _, power in pool do total += effectiveWeight(power, luck) end
	local entries = {}
	for _, power in pool do
		local probability = chance * effectiveWeight(power, luck) / total
		table.insert(entries, {Power = power, Probability = probability, RateN = math.max(1, math.floor(1 / probability + 0.5))})
	end
	return entries
end

-- draw() must return a uniform number in [0, 1). Two draws: drop, then pick.
function PowerOdds.Roll(regionId: string, luck: number, draw: () -> number): (any?, number)
	local chance = Powers.DropChance[regionId] or 0
	if chance <= 0 or draw() >= chance then return nil, 1 end
	local entries = PowerOdds.Table(regionId, luck)
	if #entries == 0 then return nil, 1 end
	local pick = draw() * chance
	local cumulative = 0
	for _, entry in entries do
		cumulative += entry.Probability
		if pick < cumulative then return entry.Power, entry.RateN end
	end
	local last = entries[#entries]
	return last.Power, last.RateN
end

return PowerOdds
