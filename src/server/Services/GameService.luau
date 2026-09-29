--!strict
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local Remote = require(Shared.Remotes).Get()
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local ChestService = require(script.Parent.ChestService)
local RegionService = require(script.Parent.RegionService)

local GameService = {}

function GameService.Start()
	Remote.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		if type(action) ~= "string" then return end
		if action == "Train" then
			ProgressionService.Train(player)
		elseif action == "OpenChest" and type(payload) == "string" then
			ChestService.Open(player, payload)
		elseif action == "UnlockRegion" and type(payload) == "string" then
			RegionService.Unlock(player, payload)
		elseif action == "TravelRegion" and type(payload) == "string" then
			RegionService.Travel(player, payload)
		elseif action == "EquipWeapon" and type(payload) == "string" then
			ProgressionService.Equip(player, payload)
		elseif action == "EquipBest" then
			ProgressionService.EquipBest(player)
		elseif action == "Rebirth" then
			ProgressionService.Rebirth(player)
		elseif action == "Setting" and type(payload) == "table" then
			ProgressionService.UpdateSetting(player, payload.Key, payload.Value)
		elseif action == "RequestState" then
			DataService.Snapshot(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ProgressionService.Cleanup(player)
		ChestService.Cleanup(player)
	end)
end

return GameService

