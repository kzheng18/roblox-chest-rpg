--!strict
local Shared = game.ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Powers = require(Shared.Config.Powers)
local Progression = require(Shared.Util.Progression)
local DataService = require(script.Parent.DataService)
local RequestContext = require(script.Parent.Parent.Components.RequestContext)
local PlayerService = require(script.Parent.PlayerService)

local ProgressionService = {}
local lastTrain: {[Player]: number} = {}

function ProgressionService.Train(player: Player)
	local data = RequestContext.GetData(player, "Train", nil)
	if not data or not RequestContext.LivingRoot(player) then return end
	local now = os.clock()
	if now - (lastTrain[player] or 0) < Economy.TrainCooldown then return end
	lastTrain[player] = now
	data.Power += Progression.PowerGain(data)
	data.Gold += Progression.GoldGain(data)
	DataService.Touch(player, {"Power", "Gold"}, false)
end

function ProgressionService.Equip(player: Player, weaponId: string)
	local data = RequestContext.GetData(player, "EquipWeapon", weaponId)
	if not data or not Progression.OwnsWeapon(data, weaponId) then
		return
	end
	data.EquippedWeapon = weaponId
	DataService.Touch(player, {"EquippedWeapon", "PowerGain"}, true)
	DataService.RequestSave(player, "Weapon equip")
end

function ProgressionService.EquipBest(player: Player)
	local data = RequestContext.GetData(player, "EquipBest", nil)
	if not data then return end
	local best = Progression.BestOwnedWeapon(data)
	local changed = false
	if best ~= "" then data.EquippedWeapon = best; changed = true end
	-- Fill every anime slot with its strongest owned power.
	for _, theme in Powers.Themes do
		local bestPower = Progression.BestOwnedPower(data, theme.Id)
		if bestPower ~= "" then data.EquippedPowers[theme.Id] = bestPower; changed = true end
	end
	if not changed then return end
	DataService.Touch(player, {"EquippedWeapon", "EquippedPowers", "PowerGain", "PowerStack"}, true)
	DataService.RequestSave(player, "Weapon equip")
end

function ProgressionService.Rebirth(player: Player)
	local data = RequestContext.GetData(player, "Rebirth", nil)
	if not data or not Progression.ApplyRebirth(data) then return end
	DataService.Touch(player, {
		"Rebirths",
		"Luck",
		"Power",
		"Gold",
		"UnlockedRegions",
		"CurrentRegion",
		"PowerGain",
		"GoldGain",
	}, true)
	DataService.RequestSave(player, "Rebirth")
	PlayerService.Place(player)
end

function ProgressionService.UpdateSetting(player: Player, key: string, value: any)
	local data = RequestContext.GetData(player, "Setting", {Key = key, Value = value})
	if not data then return end
	if key == "RollAnimation" or key == "ReducedMotion" then
		if type(value) ~= "boolean" then return end
		data.Settings[key] = value
	elseif key == "Volume" then
		if type(value) ~= "number" then return end
		data.Settings.Volume = math.clamp(value, 0, 1)
	elseif key == "EffectsQuality" then
		if value ~= "Auto" and value ~= "Low" and value ~= "High" then return end
		data.Settings.EffectsQuality = value
	else
		return
	end
	DataService.Touch(player, {"Settings"}, true)
	DataService.RequestSave(player, "Settings")
end

function ProgressionService.Cleanup(player: Player)
	lastTrain[player] = nil
end

return ProgressionService
