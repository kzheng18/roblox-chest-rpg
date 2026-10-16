--!strict
local Shared = script.Parent.Parent
local Economy = require(Shared.Config.Economy)
local Types = require(Shared.Types)
local ProfileSchema = {}
ProfileSchema.Version = 4
local MAX_INTEGER = 2 ^ 53 - 1

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function integer(value: any, minimum: number): boolean
	return finite(value) and value >= minimum and value <= MAX_INTEGER and value % 1 == 0
end
local function identifier(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 80
end
local function dictionary(raw: any, inventory: boolean): any
	assert(type(raw) == "table", "Invalid persisted inventory/region container")
	local result, size = {}, 0
	for id, value in raw do
		size += 1
		assert(size <= 512 and identifier(id), "Invalid persisted inventory/region identifier")
		assert(if inventory then integer(value, 1) else type(value) == "boolean", "Invalid persisted inventory/region value")
		-- Retired IDs survive migrations, but confer no usable catalog ownership.
		result[id] = value
	end
	return result
end
local function equippedSlots(raw: any): {[string]: string}
	assert(type(raw) == "table", "Invalid persisted equipped powers")
	local result, size = {}, 0
	for slot, id in raw do
		size += 1
		assert(size <= 64 and identifier(slot) and identifier(id), "Invalid persisted equipped power")
		result[slot] = id
	end
	return result
end

function ProfileSchema.New(): Types.PlayerData
	return {
		Version = ProfileSchema.Version, Revision = 0, OwnerUserId = 0,
		ChestSequence = 0, LastChestReceipt = nil,
		Power = 0, Gold = Economy.StartingGold, Luck = 1, Rebirths = 0,
		OwnedWeapons = {}, EquippedWeapon = "",
		OwnedPowers = {}, EquippedPowers = {},
		UnlockedRegions = {verdant = true}, CurrentRegion = "verdant",
		Settings = {RollAnimation = true, ReducedMotion = false, Volume = 0.8, EffectsQuality = "Auto"},
	}
end

function ProfileSchema.Migrate(raw: any): Types.PlayerData
	-- A corrupt load must never become a writable empty inventory.
	assert(type(raw) == "table", "Persisted profile is not a table")
	local data = ProfileSchema.New()
	local version = raw.Version or 0
	assert(integer(version, 0) and version <= ProfileSchema.Version, "Unsupported persisted schema")
	for _, key in {"Power", "Gold", "Luck", "Rebirths", "Revision", "OwnerUserId", "ChestSequence"} do
		if raw[key] ~= nil then (data :: any)[key] = raw[key] end
	end
	if version < 2 or raw.Luck == nil then data.Luck = 1 + data.Rebirths * Economy.LuckPerRebirth end
	if raw.OwnedWeapons ~= nil then data.OwnedWeapons = dictionary(raw.OwnedWeapons, true) end
	-- Version 4 adds powers. Older profiles start with none.
	if raw.OwnedPowers ~= nil then data.OwnedPowers = dictionary(raw.OwnedPowers, true) end
	if raw.EquippedPowers ~= nil then data.EquippedPowers = equippedSlots(raw.EquippedPowers) end
	if raw.UnlockedRegions ~= nil then data.UnlockedRegions = dictionary(raw.UnlockedRegions, false) end
	data.UnlockedRegions.verdant = true
	if raw.EquippedWeapon ~= nil then data.EquippedWeapon = raw.EquippedWeapon end
	if raw.CurrentRegion ~= nil then data.CurrentRegion = raw.CurrentRegion end
	if raw.LastChestReceipt ~= nil then
		assert(type(raw.LastChestReceipt) == "table", "Invalid persisted chest receipt")
		local receipt = raw.LastChestReceipt
		data.LastChestReceipt = {Sequence = receipt.Sequence, Region = receipt.Region, Id = receipt.Id, RateN = receipt.RateN, Revision = receipt.Revision,
			PowerId = receipt.PowerId, PowerRateN = receipt.PowerRateN}
	end
	-- Repair presentation preferences without discarding earned progression.
	if type(raw.Settings) == "table" then
		for _, key in {"RollAnimation", "ReducedMotion"} do
			if type(raw.Settings[key]) == "boolean" then (data.Settings :: any)[key] = raw.Settings[key] end
		end
		if finite(raw.Settings.Volume) then data.Settings.Volume = math.clamp(raw.Settings.Volume, 0, 1) end
		if raw.Settings.EffectsQuality == "Auto" or raw.Settings.EffectsQuality == "Low" or raw.Settings.EffectsQuality == "High" then
			data.Settings.EffectsQuality = raw.Settings.EffectsQuality
		end
	end
	local valid, reason = ProfileSchema.Validate(data)
	assert(valid, reason)
	return data
end

function ProfileSchema.Validate(data: any): (boolean, string?)
	if type(data) ~= "table" or data.Version ~= ProfileSchema.Version then return false, "unexpected profile schema" end
	for _, key in {"Power", "Gold", "Luck"} do
		if not finite(data[key]) or data[key] < (if key == "Luck" then 1 else 0) then return false, key .. " out of range" end
	end
	for _, key in {"Rebirths", "Revision", "ChestSequence"} do
		if not integer(data[key], 0) then return false, key .. " must be a safe nonnegative integer" end
	end
	if not integer(data.OwnerUserId, -MAX_INTEGER) then return false, "invalid inventory owner" end
	local inventoryOk = pcall(dictionary, data.OwnedWeapons, true)
	local regionsOk = pcall(dictionary, data.UnlockedRegions, false)
	if not inventoryOk or not regionsOk then return false, "invalid inventory/region contents" end
	if type(data.EquippedWeapon) ~= "string" or #data.EquippedWeapon > 80 then return false, "invalid equipped ID" end
	if data.EquippedWeapon ~= "" and not integer(data.OwnedWeapons[data.EquippedWeapon], 1) then return false, "equipped item is not owned" end
	local powersOk = pcall(dictionary, data.OwnedPowers, true)
	local slotsOk, slots = pcall(equippedSlots, data.EquippedPowers)
	if not powersOk or not slotsOk then return false, "invalid power inventory" end
	for _, id in slots do
		if not integer(data.OwnedPowers[id], 1) then return false, "equipped power is not owned" end
	end
	if not identifier(data.CurrentRegion) or data.UnlockedRegions[data.CurrentRegion] ~= true then return false, "current region is not unlocked" end
	if data.UnlockedRegions.verdant ~= true then return false, "starting region is missing" end
	local receipt = data.LastChestReceipt
	if data.ChestSequence == 0 then
		if receipt ~= nil then return false, "unexpected chest receipt" end
	elseif type(receipt) ~= "table" or receipt.Sequence ~= data.ChestSequence or not identifier(receipt.Id)
		or not identifier(receipt.Region) or not integer(receipt.RateN, 1) then return false, "invalid chest receipt" end
	if receipt and (receipt.PowerId ~= nil or receipt.PowerRateN ~= nil)
		and (not identifier(receipt.PowerId) or not integer(receipt.PowerRateN, 1)) then return false, "invalid chest power receipt" end
	if receipt and receipt.Revision ~= nil and (not integer(receipt.Revision, 0) or receipt.Revision > data.Revision) then
		return false, "invalid chest receipt revision"
	end
	local settings = data.Settings
	if type(settings) ~= "table" or type(settings.RollAnimation) ~= "boolean" or type(settings.ReducedMotion) ~= "boolean"
		or not finite(settings.Volume) or settings.Volume < 0 or settings.Volume > 1
		or (settings.EffectsQuality ~= "Auto" and settings.EffectsQuality ~= "Low" and settings.EffectsQuality ~= "High") then return false, "invalid settings" end
	return true
end

return ProfileSchema
