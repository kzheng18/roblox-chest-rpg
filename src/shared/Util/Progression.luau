--!strict
local Shared = script.Parent.Parent
local Economy = require(Shared.Config.Economy)
local Regions = require(Shared.Config.Regions)
local Weapons = require(Shared.Config.Weapons)
local Powers = require(Shared.Config.Powers)
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

function Progression.OwnsWeapon(data: Types.PlayerData, weaponId: string): boolean
	local count = data.OwnedWeapons[weaponId]
	return Weapons.ById[weaponId] ~= nil and type(count) == "number"
		and count == count and count > 0 and count <= 2^53 - 1 and count % 1 == 0
end

function Progression.WeaponMultiplier(data: Types.PlayerData): number
	local weapon = Weapons.ById[data.EquippedWeapon]
	return if weapon and Progression.OwnsWeapon(data, weapon.Id) then weapon.PowerMultiplier else 1
end

function Progression.OwnsPower(data: Types.PlayerData, powerId: string): boolean
	local count = data.OwnedPowers[powerId]
	return Powers.ById[powerId] ~= nil and type(count) == "number"
		and count == count and count > 0 and count <= 2^53 - 1 and count % 1 == 0
end

-- Multiplier from the power equipped in one theme's slot (1 when empty).
function Progression.ThemeMultiplier(data: Types.PlayerData, themeId: string): number
	local power = Powers.ById[data.EquippedPowers[themeId] or ""]
	return if power and power.Theme == themeId and Progression.OwnsPower(data, power.Id) then power.PowerMultiplier else 1
end

-- Every anime theme has its own slot, and the slots multiply together.
function Progression.PowerStackMultiplier(data: Types.PlayerData): number
	local total = 1
	for _, theme in Powers.Themes do
		total *= Progression.ThemeMultiplier(data, theme.Id)
	end
	return total
end

function Progression.BestOwnedPower(data: Types.PlayerData, themeId: string): string
	local bestId, bestMultiplier = "", 1
	for powerId in data.OwnedPowers do
		local power = Powers.ById[powerId]
		if power and power.Theme == themeId and Progression.OwnsPower(data, powerId) and power.PowerMultiplier > bestMultiplier then
			bestId, bestMultiplier = powerId, power.PowerMultiplier
		end
	end
	return bestId
end

function Progression.PowerGain(data: Types.PlayerData): number
	local rebirthMultiplier = 1 + data.Rebirths * Economy.PowerPerRebirth
	return Economy.BasePowerGain * rebirthMultiplier * Progression.WeaponMultiplier(data) * Progression.PowerStackMultiplier(data)
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
	for index, candidate in Regions.List do
		if candidate.Id == regionId and index > 1 and data.UnlockedRegions[Regions.List[index - 1].Id] ~= true then
			return false, "Unlock the previous region first"
		end
	end
	return true
end

function Progression.BestOwnedWeapon(data: Types.PlayerData): string
	local bestId = ""
	local bestMultiplier = 1
	for weaponId in data.OwnedWeapons do
		if Progression.OwnsWeapon(data, weaponId) then
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
