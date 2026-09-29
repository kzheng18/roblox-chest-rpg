--!strict
return function(t: any)
	local Network = require(game.ReplicatedStorage.Shared.Config.Network)

	t.test("replication target is twenty hertz", function()
		t.expect.near(Network.ReplicationInterval, 1 / 20)
	end)

	t.test("all gameplay intents have bounded policies", function()
		for _, action in {
			"Train",
			"OpenChest",
			"UnlockRegion",
			"TravelRegion",
			"EquipWeapon",
			"EquipBest",
			"Rebirth",
			"Setting",
			"RequestState",
		} do
			local policy = Network.Policies[action]
			t.expect.truthy(policy)
			t.expect.truthy(policy.Window > 0)
			t.expect.truthy(policy.Burst > 0)
			t.expect.truthy(policy.Payload == "none" or policy.Payload == "string" or policy.Payload == "setting")
		end
	end)

	t.test("high frequency train budget still has a hard ceiling", function()
		local train = Network.Policies.Train
		t.expect.truthy(train.Burst <= 10)
		t.expect.truthy(train.Window >= 1)
	end)

	t.test("slow intent diagnostic threshold is frame-safe", function()
		t.expect.truthy(Network.SlowIntentMilliseconds > 0)
		t.expect.truthy(Network.SlowIntentMilliseconds < 16.7)
	end)
end
