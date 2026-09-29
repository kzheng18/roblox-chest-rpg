--!strict
local Shared = game.ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Weapons = require(Shared.Config.Weapons)
local Progression = require(Shared.Util.Progression)
local DataService = require(script.Parent.DataService)

local ProgressionService = {}
local lastTrain: {[Player]: number} = {}

function ProgressionService.Train(player: Player)
	local data = DataService.Get(player)
	if not data then return end
	local now = os.clock()
	if now - (lastTrain[player] or 0) < Economy.TrainCooldown then return end
	lastTrain[player] = now
	data.Power += Progression.PowerGain(data)
	data.Gold += Progression.GoldGain(data)
	DataService.Touch(player, false)
end

function ProgressionService.Equip(player: Player, weaponId: string)
	local data = DataService.Get(player)
	if not data or not Weapons.ById[weaponId] or (data.OwnedWeapons[weaponId] or 0) <= 0 then
		return
	end
	data.EquippedWeapon = weaponId
	DataService.Touch(player, true)
end

function ProgressionService.EquipBest(player: Player)
	local data = DataService.Get(player)
	if not data then return end
	local best = Progression.BestOwnedWeapon(data)
	if best == "" then return end
	data.EquippedWeapon = best
	DataService.Touch(player, true)
end

function ProgressionService.Rebirth(player: Player)
	local data = DataService.Get(player)
	if not data or data.Power < Economy.RebirthPowerRequirement then return end
	data.Rebirths += 1
	data.Power = 0
	data.Gold = Economy.StartingGold
	data.UnlockedRegions = {verdant = true}
	data.CurrentRegion = "verdant"
	DataService.Touch(player, true)
end

function ProgressionService.UpdateSetting(player: Player, key: string, value: any)
	local data = DataService.Get(player)
	if not data then return end
	if key == "RollAnimation" or key == "ReducedMotion" then
		if type(value) ~= "boolean" then return end
		data.Settings[key] = value
	elseif key == "Volume" then
		if type(value) ~= "number" then return end
		data.Settings.Volume = math.clamp(value, 0, 1)
	else
		return
	end
	DataService.Touch(player, true)
end

function ProgressionService.Cleanup(player: Player)
	lastTrain[player] = nil
end

return ProgressionService

