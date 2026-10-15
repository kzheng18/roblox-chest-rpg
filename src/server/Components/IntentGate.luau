--!strict
local Shared = game.ReplicatedStorage.Shared
local IntentPolicy = require(Shared.Util.IntentPolicy)
local Network = require(Shared.Config.Network)

type Bucket = {At: number, Tokens: number}
local function consume(bucket: Bucket, policy: {Window: number, Burst: number}, now: number): boolean
	local elapsed = math.max(0, now - bucket.At)
	bucket.Tokens = math.min(policy.Burst, bucket.Tokens + elapsed * policy.Burst / policy.Window)
	bucket.At = math.max(bucket.At, now)
	if bucket.Tokens < 1 then return false end
	bucket.Tokens -= 1
	return true
end

local IntentGate = {}

-- Isolated instances let tests use deterministic clocks without resetting the live limiter.
function IntentGate.new()
	local players: {[Player]: {Ingress: Bucket, Actions: {[string]: Bucket}}} = {}
	local server: Bucket? = nil
	local gate = {}
	function gate.Accept(player: Player, action: any, payload: any, now: number?, extraCount: number?): (boolean, string?)
		local t = now or os.clock()
		local entry = players[player]
		if not entry then
			entry = {Ingress = {At = t, Tokens = Network.Ingress.Burst}, Actions = {}}
			players[player] = entry
		end
		-- Charge unknown actions, invalid types, and surplus arguments too.
		if not consume(entry.Ingress, Network.Ingress, t) then return false, "rate limited" end
		-- A single already-throttled player cannot consume the shared budget.
		if not server then server = {At = t, Tokens = Network.ServerIngress.Burst} end
		if not consume(server :: Bucket, Network.ServerIngress, t) then return false, "server rate limited" end
		if extraCount and extraCount > 0 then return false, "unexpected arguments" end
		local valid, reason = IntentPolicy.Validate(action, payload)
		if not valid then return false, reason end
		local policy = Network.Policies[action]
		local bucket = entry.Actions[action]
		if not bucket then
			bucket = {At = t, Tokens = policy.Burst}
			entry.Actions[action] = bucket
		end
		if not consume(bucket, policy, t) then return false, "rate limited" end
		return true
	end
	function gate.Cleanup(player: Player) players[player] = nil end
	return gate
end

local live = IntentGate.new()
IntentGate.Accept = live.Accept
IntentGate.Cleanup = live.Cleanup
return IntentGate
