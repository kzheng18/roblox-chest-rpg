--!strict
local Shared = script.Parent.Parent
local Economy = require(Shared.Config.Economy)
local Regions = require(Shared.Config.Regions)
local Weapons = require(Shared.Config.Weapons)
local Types = require(Shared.Types)

local Progression = {}

function Progression.New(): Types.PlayerData
	return {
		Version = 1,
		Revision = 0,
		Power = 0,
		Gold = Economy.StartingGold,
		Rebirths = 0,
		OwnedWeapons = {},
		EquippedWeapon = "",
		UnlockedRegions = {verdant = true},
		CurrentRegion = "verdant",
		Settings = {
			RollAnimation = true,
			ReducedMotion = false,
			Volume = 0.8,
		},
	}
end

function Progression.Migrate(data: any): Types.PlayerData
	local template = Progression.New()
	if type(data) ~= "table" then
		return template
	end
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		end
	end
	if type(data.Settings) ~= "table" then
		data.Settings = template.Settings
	else
		for key, value in template.Settings do
			if data.Settings[key] == nil then
				data.Settings[key] = value
			end
		end
	end
	data.Version = 1
	return data :: Types.PlayerData
end

function Progression.Luck(data: Types.PlayerData): number
	return 1 + data.Rebirths * Economy.LuckPerRebirth
end

function Progression.WeaponMultiplier(data: Types.PlayerData): number
	local weapon = Weapons.ById[data.EquippedWeapon]
	return if weapon then weapon.PowerMultiplier else 1
end

function Progression.PowerGain(data: Types.PlayerData): number
	local rebirthMultiplier = 1 + data.Rebirths * Economy.PowerPerRebirth
	return Economy.BasePowerGain * rebirthMultiplier * Progression.WeaponMultiplier(data)
end

function Progression.GoldGain(data: Types.PlayerData): number
	return Economy.BaseGoldGain * (1 + data.Rebirths * Economy.GoldPerRebirth)
end

function Progression.CurrentRateN(weapon: any, luck: number): number
	if weapon.RateN <= 1 then
		return 1
	end
	local divisor = math.max(1, luck) ^ weapon.LuckExponent
	return math.max(2, math.floor(weapon.RateN / divisor + 0.5))
end

function Progression.CanUnlockRegion(data: Types.PlayerData, regionId: string): (boolean, string?)
	local region = Regions.ById[regionId]
	if not region then
		return false, "Unknown region"
	end
	if data.UnlockedRegions[regionId] then
		return true
	end
	if data.Power < region.RequiredPower then
		return false, "Need more Power"
	end
	return true
end

function Progression.BestOwnedWeapon(data: Types.PlayerData): string
	local bestId = ""
	local bestMultiplier = 1
	for weaponId, count in data.OwnedWeapons do
		if count > 0 then
			local weapon = Weapons.ById[weaponId]
			if weapon and weapon.PowerMultiplier > bestMultiplier then
				bestId = weaponId
				bestMultiplier = weapon.PowerMultiplier
			end
		end
	end
	return bestId
end

return Progression

