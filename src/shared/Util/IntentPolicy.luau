--!strict
local Network = require(script.Parent.Parent.Config.Network)
local Regions = require(script.Parent.Parent.Config.Regions)
local Weapons = require(script.Parent.Parent.Config.Weapons)

local IntentPolicy = {}

function IntentPolicy.Validate(action: any, payload: any): (boolean, string?)
	if type(action) ~= "string" or #action == 0 or #action > Network.MaxActionLength then
		return false, "invalid action"
	end
	local policy = Network.Policies[action]
	if not policy then return false, "unknown action" end
	if policy.Payload == "none" then
		if payload ~= nil then return false, "unexpected payload" end
	elseif policy.Payload == "string" then
		if type(payload) ~= "string" or #payload == 0 or #payload > 80 then return false, "invalid string payload" end
		local catalog = if action == "EquipWeapon" then Weapons.ById else Regions.ById
		if not catalog[payload] then return false, "unknown identifier" end
	elseif policy.Payload == "chest" then
		if type(payload) ~= "table" then return false, "invalid chest request" end
		local count = 0
		for key in payload do
			count += 1
			if count > 2 or (key ~= "RegionId" and key ~= "Sequence") then return false, "unexpected chest field" end
		end
		if count ~= 2 or type(payload.RegionId) ~= "string" or #payload.RegionId > 80
			or not Regions.ById[payload.RegionId] then return false, "unknown chest" end
		local sequence = payload.Sequence
		if type(sequence) ~= "number" or sequence ~= sequence or sequence < 1
			or sequence >= 2^53 - 1 or sequence % 1 ~= 0 then return false, "invalid chest sequence" end
	elseif policy.Payload == "setting" then
		if type(payload) ~= "table" or type(payload.Key) ~= "string" then return false, "invalid setting payload" end
		-- Exactly two scalar fields. Stop at the first extra key without walking nested data.
		local count = 0
		for key in payload do
			count += 1
			if count > 2 or (key ~= "Key" and key ~= "Value") then return false, "unexpected setting field" end
		end
		if count ~= 2 then return false, "invalid setting payload" end
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
		elseif payload.Key == "EffectsQuality" then
			if payload.Value ~= "Auto" and payload.Value ~= "Low" and payload.Value ~= "High" then return false, "invalid effects quality" end
		else
			return false, "unknown setting"
		end
	else
		return false, "unsupported policy"
	end
	return true
end

return IntentPolicy
