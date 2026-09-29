--!strict
local Shared = script.Parent.Parent
local Economy = require(Shared.Config.Economy)
local Regions = require(Shared.Config.Regions)
local Weapons = require(Shared.Config.Weapons)
local Types = require(Shared.Types)
local ProfileSchema = require(Shared.Util.ProfileSchema)

local Progression = {}

function Progression.New(): Types.PlayerData
	return ProfileSchema.New()
end

function Progression.Migrate(data: any): Types.PlayerData
	return ProfileSchema.Migrate(data)
end

function Progression.Luck(data: Types.PlayerData): number
	return math.max(1, data.Luck)
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

function Progression.ApplyRebirth(data: Types.PlayerData): boolean
	if data.Power < Economy.RebirthPowerRequirement then
		return false
	end
	data.Rebirths += 1
	data.Luck = math.max(1, data.Luck) + Economy.LuckPerRebirth
	data.Power = 0
	data.Gold = Economy.StartingGold
	data.UnlockedRegions = {verdant = true}
	data.CurrentRegion = "verdant"
	return true
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
