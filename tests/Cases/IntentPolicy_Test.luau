--!strict
return function(t: any)
	local IntentPolicy = require(game.ReplicatedStorage.Shared.Util.IntentPolicy)

	local function valid(action: any, payload: any): boolean
		return select(1, IntentPolicy.Validate(action, payload))
	end

	t.test("unknown actions are rejected", function()
		t.expect.falsy(valid("GiveMeGold", nil))
		t.expect.falsy(valid({}, nil))
		t.expect.falsy(valid(string.rep("x", 33), nil))
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
		t.expect.falsy(valid("OpenChest", "not_a_region"))
		t.expect.falsy(valid("EquipWeapon", "verdant"))
		t.expect.truthy(valid("EquipWeapon", "verdant_iron_sword"))
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
	t.test("chest requests require bounded sequence and reject owner selection", function()
		t.expect.truthy(valid("OpenChest", {RegionId = "verdant", Sequence = 1}))
		for _, sequence in {0, -1, .5, 0/0, math.huge, 2^53} do
			t.expect.falsy(valid("OpenChest", {RegionId = "verdant", Sequence = sequence}))
		end
		t.expect.falsy(valid("OpenChest", {RegionId = "verdant", Sequence = 1, UserId = 123}))
		t.expect.falsy(valid("OpenChest", "verdant"))
	end)
	t.test("effects settings cannot change gameplay or accept arbitrary values", function()
		for _, quality in {"Auto", "Low", "High"} do t.expect.truthy(valid("Setting", {Key = "EffectsQuality", Value = quality})) end
		t.expect.falsy(valid("Setting", {Key = "EffectsQuality", Value = "240FPS"}))
	end)

	t.test("settings reject surplus fields and nested or cyclic values", function()
		local cycle: any = {}; cycle.self = cycle
		t.expect.falsy(valid("Setting", {Key = "Volume", Value = 0.5, UserId = 123}))
		t.expect.falsy(valid("Setting", {Key = "Volume", Value = 0.5, Extra = cycle}))
		t.expect.falsy(valid("Setting", {Key = "Volume", Value = cycle}))
		t.expect.falsy(valid("Setting", {Key = "Volume"}))
		t.expect.falsy(valid("Setting", {Key = "Volume", Value = -math.huge}))
	end)
end
