--!strict
local Shared = script.Parent.Parent
local Progression = require(Shared.Util.Progression)
local Types = require(Shared.Types)

local StateView = {}

local function valueFor(data: Types.PlayerData, key: string): any
	if key == "Luck" then return Progression.Luck(data) end
	if key == "PowerGain" then return Progression.PowerGain(data) end
	if key == "GoldGain" then return Progression.GoldGain(data) end
	return (data :: any)[key]
end

function StateView.Snapshot(data: Types.PlayerData): {[string]: any}
	return {
		Revision = data.Revision,
		Power = data.Power,
		Gold = data.Gold,
		Luck = Progression.Luck(data),
		Rebirths = data.Rebirths,
		OwnedWeapons = data.OwnedWeapons,
		EquippedWeapon = data.EquippedWeapon,
		UnlockedRegions = data.UnlockedRegions,
		CurrentRegion = data.CurrentRegion,
		Settings = data.Settings,
		PowerGain = Progression.PowerGain(data),
		GoldGain = Progression.GoldGain(data),
	}
end

function StateView.Delta(data: Types.PlayerData, dirty: {[string]: boolean}): {[string]: any}
	local changes = {}
	for key in dirty do changes[key] = valueFor(data, key) end
	return changes
end

return StateView

