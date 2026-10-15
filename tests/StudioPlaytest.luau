--!strict
-- Run on the Studio SERVER after pressing Play. No production/test-grant remote exists.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local Regions = require(Shared.Config.Regions)
local Layout = require(Shared.Config.WorldLayout)
local Economy = require(Shared.Config.Economy)
local Server = game.ServerScriptService.Server
local DataService = require(Server.Services.DataService)
local GameService = require(Server.Services.GameService)
local PlayerService = require(Server.Services.PlayerService)

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

return function(player: Player?)
	assert(RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(), "Studio Play server only")
	local subject = player or Players:GetPlayers()[1]
	assert(subject and subject:GetAttribute("DataStatus") == "Temporary Studio session", "A loaded mock-profile player is required")
	local data = DataService.Get(subject)
	assert(data and subject.Character, "Wait for the player to spawn")
	local before = copy(data)
	local results = {}
	local function check(name: string, condition: boolean)
		assert(condition, name)
		table.insert(results, name)
		print("[PLAYTEST PASS] " .. name)
	end
	local function intent(action: string, payload: any?)
		GameService.Handle(subject, action, payload)
	end
	local function approachChest(regionId: string)
		subject.Character:PivotTo(CFrame.new(Regions.ById[regionId].Center + Layout.Get(regionId).Chest + Vector3.new(0, 2, 9)))
	end
	local ok, err = pcall(function()
		task.wait(3) -- Let any manual input budgets/cooldowns settle before the scripted sequence.
		check("player has living Humanoid and root", subject.Character:FindFirstChildOfClass("Humanoid") ~= nil and subject.Character:FindFirstChild("HumanoidRootPart") ~= nil)
		data.Power = 0; data.Gold = 100; data.CurrentRegion = "verdant"
		data.UnlockedRegions = {verdant = true}
		PlayerService.Place(subject)
		local power, gold = data.Power, data.Gold
		intent("Train")
		check("training increases Power and Gold", data.Power > power and data.Gold > gold)
		local sum = 0
		for _, n in data.OwnedWeapons do sum += n end
		gold = data.Gold
		approachChest("verdant")
		intent("OpenChest", "verdant")
		local after = 0
		for _, n in data.OwnedWeapons do after += n end
		check("nearby chest debits cost and grants weapon", data.Gold == gold - Regions.ById.verdant.ChestCost and after == sum + 1)
		intent("EquipBest")
		check("equipped weapon belongs to player", (data.OwnedWeapons[data.EquippedWeapon] or 0) > 0)
		gold = data.Gold
		intent("Train", {Gold = 1e9})
		check("malformed intent grants nothing", data.Gold == gold)
		intent("TravelRegion", "frostfall")
		check("locked travel rejected", data.CurrentRegion == "verdant")
		subject.Character:PivotTo(CFrame.new(0, 6, 100))
		task.wait(0.4)
		intent("OpenChest", "verdant")
		check("distant chest rejected without debit", data.Gold == gold)
		data.Power = Regions.ById.frostfall.RequiredPower
		intent("UnlockRegion", "frostfall")
		task.wait()
		check("region unlock and arrival", data.UnlockedRegions.frostfall == true and data.CurrentRegion == "frostfall" and (subject.Character:GetPivot().Position - (Regions.ById.frostfall.Center + Layout.Get("frostfall").Spawn)).Magnitude < 20)
		check("region respawn selected", subject.RespawnLocation ~= nil and subject.RespawnLocation.Parent.Name == "frostfall")
		data.Gold = Regions.ById.frostfall.ChestCost
		approachChest("frostfall")
		task.wait(0.4)
		intent("OpenChest", "frostfall")
		check("higher-region chest works", data.Gold == 0)
		local rebirths = data.Rebirths
		data.Power = Economy.RebirthPowerRequirement
		intent("Rebirth")
		check("Rebirth resets run and increments permanent count", data.Rebirths == rebirths + 1 and data.Power == 0 and data.CurrentRegion == "verdant")
		task.wait() -- Allow property signals to update the physical respawn/arrival.
		check("Rebirth returns avatar to starting region", (subject.Character:GetPivot().Position - (Regions.ById.verdant.Center + Layout.Get("verdant").Spawn)).Magnitude < 20)
		intent("Setting", {Key = "Volume", Value = 0.5})
		check("valid settings change", data.Settings.Volume == 0.5)
		intent("Setting", {Key = "Volume", Value = 0/0})
		check("non-finite setting rejected", data.Settings.Volume == 0.5)
		local old = subject.Character
		local humanoid = old:FindFirstChildOfClass("Humanoid")
		assert(humanoid); humanoid.Health = 0
		local deadline = os.clock() + 25
		repeat task.wait(0.2) until (subject.Character ~= old and subject:GetAttribute("SpawnStatus") == "Ready") or os.clock() >= deadline
		check("death respawns a controllable player", subject.Character ~= old and subject:GetAttribute("SpawnStatus") == "Ready" and subject.Character:FindFirstChild("HumanoidRootPart") ~= nil)
	end)
	-- Restore the test subject's mock progression even on failure; keep revisions monotonic.
	if DataService.Get(subject) == data then
		-- Retry sequences stay monotonic, just like revisions, even in mock tests.
		for key, value in before do
			if key ~= "Revision" and key ~= "ChestSequence" and key ~= "LastChestReceipt" then (data :: any)[key] = copy(value) end
		end
		DataService.Touch(subject, {"Power","Gold","Luck","Rebirths","OwnedWeapons","EquippedWeapon","UnlockedRegions","CurrentRegion","Settings","PowerGain","GoldGain"}, true)
		PlayerService.Place(subject)
	end
	assert(ok, tostring(err))
	return {Passed = #results, Checks = results, Persistence = "Mock only; no cloud save assertion"}
end
