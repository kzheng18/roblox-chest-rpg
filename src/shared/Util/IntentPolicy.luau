--!strict
local Network = require(script.Parent.Parent.Config.Network)

local IntentPolicy = {}

function IntentPolicy.Validate(action: any, payload: any): (boolean, string?)
	if type(action) ~= "string" then return false, "action must be a string" end
	local policy = Network.Policies[action]
	if not policy then return false, "unknown action" end
	if policy.Payload == "none" then
		if payload ~= nil then return false, "unexpected payload" end
	elseif policy.Payload == "string" then
		if type(payload) ~= "string" or #payload == 0 or #payload > 80 then return false, "invalid string payload" end
	elseif policy.Payload == "setting" then
		if type(payload) ~= "table" or type(payload.Key) ~= "string" then return false, "invalid setting payload" end
		if payload.Key == "RollAnimation" or payload.Key == "ReducedMotion" then
			if type(payload.Value) ~= "boolean" then return false, "invalid setting value" end
		elseif payload.Key == "Volume" then
			if type(payload.Value) ~= "number"
				or payload.Value ~= payload.Value
				or math.abs(payload.Value) == math.huge
				or payload.Value < 0
				or payload.Value > 1
			then
				return false, "invalid volume"
			end
		else
			return false, "unknown setting"
		end
	end
	return true
end

return IntentPolicy
