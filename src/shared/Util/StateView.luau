--!strict
local Shared = script.Parent.Parent
local Progression = require(Shared.Util.Progression)
local Types = require(Shared.Types)

local StateView = {}
local publicFields = {Power = true, Gold = true, Luck = true, Rebirths = true,
	OwnedWeapons = true, EquippedWeapon = true, OwnedPowers = true, EquippedPowers = true, PowerStack = true, UnlockedRegions = true, CurrentRegion = true,
	Settings = true, PowerGain = true, GoldGain = true, ChestSequence = true}

local function valueFor(data: Types.PlayerData, key: string): any
	if key == "Luck" then return Progression.Luck(data) end
	if key == "PowerGain" then return Progression.PowerGain(data) end
	if key == "GoldGain" then return Progression.GoldGain(data) end
	if key == "PowerStack" then return Progression.PowerStackMultiplier(data) end
	return (data :: any)[key]
end

function StateView.Snapshot(data: Types.PlayerData): {[string]: any}
	return {
		Revision = data.Revision,
		ChestSequence = data.ChestSequence,
		Power = data.Power,
		Gold = data.Gold,
		Luck = Progression.Luck(data),
		Rebirths = data.Rebirths,
		OwnedWeapons = data.OwnedWeapons,
		EquippedWeapon = data.EquippedWeapon,
		OwnedPowers = data.OwnedPowers,
		EquippedPowers = data.EquippedPowers,
		PowerStack = Progression.PowerStackMultiplier(data),
		UnlockedRegions = data.UnlockedRegions,
		CurrentRegion = data.CurrentRegion,
		Settings = data.Settings,
		PowerGain = Progression.PowerGain(data),
		GoldGain = Progression.GoldGain(data),
	}
end

function StateView.Delta(data: Types.PlayerData, dirty: {[string]: boolean}): {[string]: any}
	local changes = {}
	for key in dirty do
		if publicFields[key] then changes[key] = valueFor(data, key) end
	end
	return changes
end

return StateView

