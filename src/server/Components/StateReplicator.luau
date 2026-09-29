--!strict
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local Network = require(Shared.Config.Network)
local Progression = require(Shared.Util.Progression)
local StateView = require(Shared.Util.StateView)
local FormatNumber = require(Shared.Util.FormatNumber)
local Remote = require(Shared.Remotes).Get()
local RuntimeState = require(script.Parent.RuntimeState)
local Diagnostics = require(script.Parent.Diagnostics)

local StateReplicator = {}
local running = false

local function updateAttributes(player: Player, data: any, dirty: {[string]: boolean}?)
	local all = dirty == nil
	local function wants(key: string): boolean return all or (dirty :: any)[key] == true end
	if wants("Power") then player:SetAttribute("Power", data.Power) end
	if wants("Gold") then player:SetAttribute("Gold", data.Gold) end
	if wants("Luck") then player:SetAttribute("Luck", Progression.Luck(data)) end
	if wants("Rebirths") then player:SetAttribute("Rebirths", data.Rebirths) end
	if wants("EquippedWeapon") then player:SetAttribute("EquippedWeapon", data.EquippedWeapon) end
	if wants("CurrentRegion") then player:SetAttribute("CurrentRegion", data.CurrentRegion) end
	if wants("PowerGain") then player:SetAttribute("PowerGain", Progression.PowerGain(data)) end
	if wants("GoldGain") then player:SetAttribute("GoldGain", Progression.GoldGain(data)) end
	if wants("Settings") then
		player:SetAttribute("RollAnimation", data.Settings.RollAnimation)
		player:SetAttribute("ReducedMotion", data.Settings.ReducedMotion)
		player:SetAttribute("Volume", data.Settings.Volume)
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		if wants("Power") then local v = stats:FindFirstChild("Power"); if v then (v :: StringValue).Value = FormatNumber(data.Power) end end
		if wants("Gold") then local v = stats:FindFirstChild("Gold"); if v then (v :: StringValue).Value = FormatNumber(data.Gold) end end
	end
end

function StateReplicator.Snapshot(player: Player)
	local data = RuntimeState.Get(player)
	if not data then return end
	updateAttributes(player, data, nil)
	Remote:FireClient(player, "State", StateView.Snapshot(data))
	Diagnostics.Replication(player)
end

function StateReplicator.Flush(player: Player)
	local data = RuntimeState.Get(player)
	local dirty = RuntimeState.ConsumeDirty(player)
	if not data or not dirty then return end
	updateAttributes(player, data, dirty)
	Remote:FireClient(player, "StateDelta", {Revision = data.Revision, Changes = StateView.Delta(data, dirty)})
	Diagnostics.Replication(player)
end

function StateReplicator.Start()
	if running then return end
	running = true
	task.spawn(function()
		while running do
			task.wait(Network.ReplicationInterval)
			for _, player in Players:GetPlayers() do StateReplicator.Flush(player) end
		end
	end)
end

return StateReplicator
