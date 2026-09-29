--!strict
local Shared = game.ReplicatedStorage.Shared
local IntentPolicy = require(Shared.Util.IntentPolicy)
local Network = require(Shared.Config.Network)

type Bucket = {StartedAt: number, Count: number}
local buckets: {[Player]: {[string]: Bucket}} = {}
local IntentGate = {}

function IntentGate.Accept(player: Player, action: any, payload: any, now: number?): (boolean, string?)
	local valid, reason = IntentPolicy.Validate(action, payload)
	if not valid then return false, reason end
	local policy = Network.Policies[action]
	local t = now or os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then playerBuckets = {}; buckets[player] = playerBuckets end
	local bucket = playerBuckets[action]
	if not bucket or t - bucket.StartedAt >= policy.Window then
		bucket = {StartedAt = t, Count = 0}
		playerBuckets[action] = bucket
	end
	if bucket.Count >= policy.Burst then return false, "rate limited" end
	bucket.Count += 1
	return true
end

function IntentGate.Cleanup(player: Player) buckets[player] = nil end

return IntentGate

