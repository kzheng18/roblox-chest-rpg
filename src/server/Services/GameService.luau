--!strict
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local Remote = require(Shared.Remotes).Get()
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local ChestService = require(script.Parent.ChestService)
local RegionService = require(script.Parent.RegionService)
local IntentGate = require(script.Parent.Parent.Components.IntentGate)
local Diagnostics = require(script.Parent.Parent.Components.Diagnostics)

local GameService = {}

local function dispatch(player: Player, action: string, payload: any)
	if action == "Train" then
		ProgressionService.Train(player)
	elseif action == "OpenChest" then
		ChestService.Open(player, payload)
	elseif action == "UnlockRegion" then
		RegionService.Unlock(player, payload)
	elseif action == "TravelRegion" then
		RegionService.Travel(player, payload)
	elseif action == "EquipWeapon" then
		ProgressionService.Equip(player, payload)
	elseif action == "EquipBest" then
		ProgressionService.EquipBest(player)
	elseif action == "Rebirth" then
		ProgressionService.Rebirth(player)
	elseif action == "Setting" then
		ProgressionService.UpdateSetting(player, payload.Key, payload.Value)
	elseif action == "RequestState" then
		DataService.Snapshot(player)
	end
end

function GameService.Start()
	Remote.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		local accepted, reason = IntentGate.Accept(player, action, payload)
		if not accepted then
			Diagnostics.Intent(player, 0, false)
			if reason ~= "rate limited" then
				warn(string.format("[GameService] Rejected %s intent: %s", player.Name, tostring(reason)))
			end
			return
		end
		local started = os.clock()
		local ok, err = pcall(dispatch, player, action, payload)
		local elapsedMs = (os.clock() - started) * 1000
		Diagnostics.Intent(player, elapsedMs, true)
		if not ok then
			warn(string.format("[GameService] %s failed for %s: %s", tostring(action), player.Name, tostring(err)))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ProgressionService.Cleanup(player)
		ChestService.Cleanup(player)
		IntentGate.Cleanup(player)
		Diagnostics.Cleanup(player)
	end)
end

return GameService
