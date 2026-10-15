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
local Network = require(Shared.Config.Network)

local GameService = {}
local lastWarning = -math.huge

local function warnBounded(message: string)
	local now = os.clock()
	if now - lastWarning < Network.WarningInterval then return end
	lastWarning = now
	warn(message)
end

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

function GameService.Handle(player: Player, action: any, payload: any, ...: any)
	if player.Parent ~= Players then return end
	-- Trusted server prompts/playtests may use region strings. The remote handler
	-- below rejects this legacy form before reaching this adapter.
	if action == "OpenChest" and type(payload) == "string" then
		local data = DataService.Get(player)
		if data then payload = {RegionId = payload, Sequence = data.ChestSequence + 1} end
	end
	local accepted, reason = IntentGate.Accept(player, action, payload, nil, select("#", ...))
	if not accepted then
		Diagnostics.Intent(player, 0, false)
		if reason ~= "rate limited" and reason ~= "server rate limited" then
			warnBounded("[GameService] Rejected intent: " .. tostring(reason))
		end
		return
	end
	if not DataService.Get(player) then
		Diagnostics.Intent(player, 0, false)
		return
	end
	local started = os.clock()
	local ok, err = pcall(dispatch, player, action, payload)
	local elapsedMs = (os.clock() - started) * 1000
	Diagnostics.Intent(player, elapsedMs, ok)
	if not ok then
		warnBounded(string.format("[GameService] %s failed: %s", action, tostring(err)))
	end
end

function GameService.Start()
	Remote.OnServerEvent:Connect(function(player: Player, action: any, payload: any, ...: any)
		if action == "OpenChest" and type(payload) ~= "table" then
			-- Charge malformed/legacy remote traffic against ingress budgets.
			IntentGate.Accept(player, action, payload)
			return
		end
		GameService.Handle(player, action, payload, ...)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ProgressionService.Cleanup(player)
		ChestService.Cleanup(player)
		IntentGate.Cleanup(player)
		Diagnostics.Cleanup(player)
	end)
end

return GameService
