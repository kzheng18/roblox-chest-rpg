--!strict
local Shared = game.ReplicatedStorage.Shared
local Regions = require(Shared.Config.Regions)
local Weapons = require(Shared.Config.Weapons)
local Progression = require(Shared.Util.Progression)
local Remote = require(Shared.Remotes).Get()
local DataService = require(script.Parent.DataService)
local RequestContext = require(script.Parent.Parent.Components.RequestContext)

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

local function resultFor(receipt: any, replay: boolean): any
	local weapon = Weapons.ById[receipt.Id]
	if not weapon then return nil end
	return {
		Id = weapon.Id, Region = receipt.Region, Name = weapon.Name, Rarity = weapon.Rarity,
		RateN = receipt.RateN, BaseRateN = weapon.RateN, PowerMultiplier = weapon.PowerMultiplier,
		Family = weapon.Family, Sequence = receipt.Sequence, Revision = receipt.Revision, Replay = replay,
	}
end

function ChestService.Open(player: Player, request: any)
	local data = RequestContext.GetData(player, "OpenChest", request)
	if not data then return end
	local regionId, sequence = request.RegionId, request.Sequence
	local function reject(message: string)
		Remote:FireClient(player, "ChestRejected", {Sequence = sequence, Message = message})
	end
	-- Sequence + receipt live in the same persisted profile as the debit/grant.
	-- Old sequences can never become new purchases, even after reconnect/Rebirth.
	if sequence <= data.ChestSequence then
		local receipt = data.LastChestReceipt
		local result = if receipt and receipt.Sequence == sequence and receipt.Region == regionId then resultFor(receipt, true) else nil
		if result then Remote:FireClient(player, "ChestResult", result)
		else reject("That opening was already processed. Your inventory is unchanged.") end
		return
	end
	if sequence ~= data.ChestSequence + 1 then
		reject("Refreshing your chest state. Please try again.")
		DataService.Snapshot(player)
		return
	end
	local region = Regions.ById[regionId]
	if not region or data.UnlockedRegions[regionId] ~= true or data.CurrentRegion ~= regionId then
		reject("Visit an unlocked region to open its chest."); return
	end
	if region.ChestCost ~= region.ChestCost or region.ChestCost <= 0 or region.ChestCost == math.huge then return end
	local now = os.clock()
	if now - (lastOpen[player] or 0) < 0.35 then reject("Please wait before opening again."); return end
	lastOpen[player] = now
	if not RequestContext.NearChest(player, regionId) then
		reject("Move closer to this region's treasure chest.")
		return
	end
	if type(data.Gold) ~= "number" or data.Gold ~= data.Gold or math.abs(data.Gold) == math.huge then return end
	if data.Gold < region.ChestCost then
		reject("Not enough Gold for this chest.")
		return
	end

	local luck = Progression.Luck(data)
	if luck ~= luck or math.abs(luck) == math.huge then return end
	local weapon, rateN = roll(regionId, luck)
	if not weapon then return end
	local count = data.OwnedWeapons[weapon.Id] or 0
	if type(count) ~= "number" or count ~= count or count < 0 or count % 1 ~= 0 or count >= 2^53 - 1 then return end
	-- All validation and roll work precedes a non-yielding debit/grant pair.
	data.Gold -= region.ChestCost
	data.OwnedWeapons[weapon.Id] = count + 1
	data.ChestSequence = sequence
	data.LastChestReceipt = {Sequence = sequence, Region = regionId, Id = weapon.Id, RateN = rateN, Revision = data.Revision + 1}
	local current = Weapons.ById[data.EquippedWeapon]
	if not current or weapon.PowerMultiplier > current.PowerMultiplier then
		data.EquippedWeapon = weapon.Id
	end
	DataService.Touch(player, {"Gold", "OwnedWeapons", "EquippedWeapon", "PowerGain", "ChestSequence"}, true)
	DataService.RequestSave(player, "Weapon reward")
	Remote:FireClient(player, "ChestResult", resultFor(data.LastChestReceipt, false))
end

function ChestService.Cleanup(player: Player)
	lastOpen[player] = nil
end

return ChestService
