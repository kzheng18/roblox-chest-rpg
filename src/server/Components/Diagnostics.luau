--!strict
local Network = require(game.ReplicatedStorage.Shared.Config.Network)

type Metrics = {Accepted: number, Rejected: number, Replications: number, Slow: number, TotalMs: number}
local metrics: {[Player]: Metrics} = {}
local Diagnostics = {}

local function get(player: Player): Metrics
	local current = metrics[player]
	if current then return current end
	current = {Accepted = 0, Rejected = 0, Replications = 0, Slow = 0, TotalMs = 0}
	metrics[player] = current
	return current
end

function Diagnostics.Intent(player: Player, milliseconds: number, accepted: boolean)
	local m = get(player)
	if accepted then m.Accepted += 1 else m.Rejected += 1 end
	if accepted then
		m.TotalMs += milliseconds
		if milliseconds > Network.SlowIntentMilliseconds then m.Slow += 1 end
	end
end

function Diagnostics.Replication(player: Player)
	get(player).Replications += 1
end

function Diagnostics.Snapshot(player: Player): Metrics
	local m = get(player)
	return {Accepted=m.Accepted, Rejected=m.Rejected, Replications=m.Replications, Slow=m.Slow, TotalMs=m.TotalMs}
end

function Diagnostics.Cleanup(player: Player) metrics[player] = nil end

return Diagnostics

