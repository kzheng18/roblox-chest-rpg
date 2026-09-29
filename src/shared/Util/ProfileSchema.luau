--!strict
local Shared = script.Parent.Parent
local Economy = require(Shared.Config.Economy)
local Types = require(Shared.Types)

local ProfileSchema = {}
ProfileSchema.Version = 2

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

function ProfileSchema.New(): Types.PlayerData
	return {
		Version = ProfileSchema.Version,
		Revision = 0,
		Power = 0,
		Gold = Economy.StartingGold,
		Luck = 1,
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

local function finiteNumber(value: any, fallback: number, minimum: number?): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return if minimum then math.max(minimum, value) else value
end

function ProfileSchema.Migrate(raw: any): Types.PlayerData
	local template = ProfileSchema.New()
	if type(raw) ~= "table" then return template end
	local data = copy(raw)
	local sourceVersion = if type(data.Version) == "number" then data.Version else 0

	data.Power = finiteNumber(data.Power, 0, 0)
	data.Gold = finiteNumber(data.Gold, Economy.StartingGold, 0)
	data.Rebirths = math.floor(finiteNumber(data.Rebirths, 0, 0))
	data.Revision = math.floor(finiteNumber(data.Revision, 0, 0))
	if sourceVersion < 2 or type(data.Luck) ~= "number" then
		data.Luck = 1 + data.Rebirths * Economy.LuckPerRebirth
	else
		data.Luck = finiteNumber(data.Luck, 1, 1)
	end

	if type(data.OwnedWeapons) ~= "table" then data.OwnedWeapons = {} end
	for id, count in data.OwnedWeapons do
		if type(id) ~= "string" or type(count) ~= "number" or count < 1 then data.OwnedWeapons[id] = nil
		else data.OwnedWeapons[id] = math.floor(count) end
	end
	if type(data.EquippedWeapon) ~= "string" then data.EquippedWeapon = "" end
	if type(data.UnlockedRegions) ~= "table" then data.UnlockedRegions = {} end
	data.UnlockedRegions.verdant = true
	if type(data.CurrentRegion) ~= "string" then data.CurrentRegion = "verdant" end

	if type(data.Settings) ~= "table" then data.Settings = copy(template.Settings) end
	if type(data.Settings.RollAnimation) ~= "boolean" then data.Settings.RollAnimation = true end
	if type(data.Settings.ReducedMotion) ~= "boolean" then data.Settings.ReducedMotion = false end
	data.Settings.Volume = math.clamp(finiteNumber(data.Settings.Volume, 0.8, 0), 0, 1)
	data.Version = ProfileSchema.Version
	return data :: Types.PlayerData
end

function ProfileSchema.Validate(data: any): (boolean, string?)
	if type(data) ~= "table" then return false, "profile is not a table" end
	if data.Version ~= ProfileSchema.Version then return false, "unexpected schema version" end
	for _, key in {"Power", "Gold", "Luck", "Rebirths", "Revision"} do
		local value = data[key]
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
			return false, key .. " must be finite numeric"
		end
	end
	if data.Power < 0 or data.Gold < 0 or data.Luck < 1 or data.Rebirths < 0 then return false, "progression values out of range" end
	if type(data.OwnedWeapons) ~= "table" or type(data.UnlockedRegions) ~= "table" or type(data.Settings) ~= "table" then return false, "profile containers are invalid" end
	if type(data.EquippedWeapon) ~= "string" or type(data.CurrentRegion) ~= "string" then return false, "profile identifiers are invalid" end
	if type(data.Settings.RollAnimation) ~= "boolean" or type(data.Settings.ReducedMotion) ~= "boolean" then return false, "settings booleans are invalid" end
	if type(data.Settings.Volume) ~= "number" or data.Settings.Volume ~= data.Settings.Volume or data.Settings.Volume < 0 or data.Settings.Volume > 1 then
		return false, "settings volume is invalid"
	end
	return true
end

return ProfileSchema
