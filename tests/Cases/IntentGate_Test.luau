--!strict
return function(t: any)
	local IntentGate = require(game.ServerScriptService.Server.Components.IntentGate)
	local Network = require(game.ReplicatedStorage.Shared.Config.Network)
	local fakePlayer = {} :: any

	t.test("burst budget accepts up to configured ceiling", function()
		IntentGate.Cleanup(fakePlayer)
		local policy = Network.Policies.Train
		for _ = 1, policy.Burst do
			local accepted = select(1, IntentGate.Accept(fakePlayer, "Train", nil, 100))
			t.expect.truthy(accepted)
		end
		local accepted, reason = IntentGate.Accept(fakePlayer, "Train", nil, 100)
		t.expect.falsy(accepted)
		t.expect.equal(reason, "rate limited")
	end)

	t.test("fixed window resets after elapsed window", function()
		IntentGate.Cleanup(fakePlayer)
		local policy = Network.Policies.Rebirth
		for _ = 1, policy.Burst do
			t.expect.truthy(select(1, IntentGate.Accept(fakePlayer, "Rebirth", nil, 10)))
		end
		t.expect.falsy(select(1, IntentGate.Accept(fakePlayer, "Rebirth", nil, 10.5)))
		t.expect.truthy(select(1, IntentGate.Accept(fakePlayer, "Rebirth", nil, 10 + policy.Window)))
	end)

	t.test("malformed requests are rejected before budget use", function()
		IntentGate.Cleanup(fakePlayer)
		local accepted, reason = IntentGate.Accept(fakePlayer, "Train", {Gold = 999999}, 20)
		t.expect.falsy(accepted)
		t.expect.equal(reason, "unexpected payload")
		t.expect.truthy(select(1, IntentGate.Accept(fakePlayer, "Train", nil, 20)))
	end)

	IntentGate.Cleanup(fakePlayer)
end
