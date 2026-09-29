--!strict
local Shared = game.ReplicatedStorage.Shared
local Regions = require(Shared.Config.Regions)
local Weapons = require(Shared.Config.Weapons)
local Progression = require(Shared.Util.Progression)
local Remote = require(Shared.Remotes).Get()
local DataService = require(script.Parent.DataService)

local ChestService = {}
local rng = Random.new()
local lastOpen: {[Player]: number} = {}

local function roll(regionId: string, luck: number)
	local pool = Weapons.ByRegion[regionId]
	if not pool or #pool == 0 then return nil, 1 end
	local ordered = table.clone(pool)
	table.sort(ordered, function(a, b)
		return a.RateN > b.RateN
	end)
	local fallback = ordered[#ordered]
	for _, weapon in ordered do
		if weapon.RateN <= 1 then
			fallback = weapon
		else
			local rateN = Progression.CurrentRateN(weapon, luck)
			if rng:NextInteger(1, rateN) == 1 then
				return weapon, rateN
			end
		end
	end
	return fallback, 1
end

function ChestService.Open(player: Player, regionId: string)
	local data = DataService.Get(player)
	local region = Regions.ById[regionId]
	if not data or not region then return end
	if not data.UnlockedRegions[regionId] or data.CurrentRegion ~= regionId then return end
	local now = os.clock()
	if now - (lastOpen[player] or 0) < 0.35 then return end
	lastOpen[player] = now
	if data.Gold < region.ChestCost then
		Remote:FireClient(player, "Toast", "Not enough Gold for this chest.")
		return
	end

	data.Gold -= region.ChestCost
	local luck = Progression.Luck(data)
	local weapon, rateN = roll(regionId, luck)
	if not weapon then return end
	data.OwnedWeapons[weapon.Id] = (data.OwnedWeapons[weapon.Id] or 0) + 1
	local current = Weapons.ById[data.EquippedWeapon]
	if not current or weapon.PowerMultiplier > current.PowerMultiplier then
		data.EquippedWeapon = weapon.Id
	end
	DataService.Touch(player, {"Gold", "OwnedWeapons", "EquippedWeapon", "PowerGain"}, true)
	DataService.RequestSave(player, "Weapon reward")
	Remote:FireClient(player, "ChestResult", {
		Id = weapon.Id,
		Name = weapon.Name,
		Rarity = weapon.Rarity,
		RateN = rateN,
		BaseRateN = weapon.RateN,
		PowerMultiplier = weapon.PowerMultiplier,
		Family = weapon.Family,
	})
end

function ChestService.Cleanup(player: Player)
	lastOpen[player] = nil
end

return ChestService
