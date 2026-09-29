--!strict
return function(t: any)
	local IntentPolicy = require(game.ReplicatedStorage.Shared.Util.IntentPolicy)

	local function valid(action: any, payload: any): boolean
		return select(1, IntentPolicy.Validate(action, payload))
	end

	t.test("unknown actions are rejected", function()
		t.expect.falsy(valid("GiveMeGold", nil))
	end)

	t.test("payloadless intents reject supplied payloads", function()
		t.expect.truthy(valid("Train", nil))
		t.expect.falsy(valid("Train", 1000000))
		t.expect.falsy(valid("Rebirth", {}))
	end)

	t.test("string intents enforce shape and size", function()
		t.expect.truthy(valid("TravelRegion", "verdant"))
		t.expect.falsy(valid("TravelRegion", ""))
		t.expect.falsy(valid("EquipWeapon", string.rep("x", 81)))
		t.expect.falsy(valid("OpenChest", 42))
	end)

	t.test("boolean settings require booleans", function()
		t.expect.truthy(valid("Setting", {Key = "RollAnimation", Value = false}))
		t.expect.truthy(valid("Setting", {Key = "ReducedMotion", Value = true}))
		t.expect.falsy(valid("Setting", {Key = "RollAnimation", Value = 1}))
	end)

	t.test("volume setting rejects invalid numeric ranges", function()
		t.expect.truthy(valid("Setting", {Key = "Volume", Value = 0.5}))
		t.expect.falsy(valid("Setting", {Key = "Volume", Value = -0.1}))
		t.expect.falsy(valid("Setting", {Key = "Volume", Value = 1.1}))
		t.expect.falsy(valid("Setting", {Key = "Volume", Value = 0 / 0}))
		t.expect.falsy(valid("Setting", {Key = "Volume", Value = math.huge}))
	end)

	t.test("unknown settings are rejected", function()
		t.expect.falsy(valid("Setting", {Key = "Admin", Value = true}))
	end)
end
