--!strict
return function(t: any)
	local IntentGate = require(game.ServerScriptService.Server.Components.IntentGate)
	local Network = require(game.ReplicatedStorage.Shared.Config.Network)
	local player = {} :: any

	t.test("per-action burst is bounded and tokens refill gradually", function()
		local gate = IntentGate.new()
		local policy = Network.Policies.Rebirth
		for _ = 1, policy.Burst do t.expect.truthy(gate.Accept(player, "Rebirth", nil, 10)) end
		t.expect.falsy(gate.Accept(player, "Rebirth", nil, 10.5))
		t.expect.truthy(gate.Accept(player, "Rebirth", nil, 11))
		t.expect.falsy(gate.Accept(player, "Rebirth", nil, 11))
		t.expect.truthy(gate.Accept(player, "Rebirth", nil, 13))
	end)

	t.test("malformed and mixed action spam consumes a shared player budget", function()
		local gate = IntentGate.new()
		for i = 1, Network.Ingress.Burst do
			local action = if i % 2 == 0 then "Unknown" else "Train"
			t.expect.falsy(gate.Accept(player, action, {Gold = 999}, 20))
		end
		local ok, reason = gate.Accept(player, "Setting", {Key="Volume", Value=0.5}, 20)
		t.expect.falsy(ok); t.expect.equal(reason, "rate limited")
		t.expect.truthy(gate.Accept(player, "Train", nil, 21))
	end)

	t.test("extra arguments are rejected and consume ingress budget", function()
		local gate = IntentGate.new()
		local ok, reason = gate.Accept(player, "Train", nil, 0, 1)
		t.expect.falsy(ok); t.expect.equal(reason, "unexpected arguments")
	end)

	t.test("one abusive player does not exhaust the server budget", function()
		local gate = IntentGate.new()
		for _ = 1, 10000 do gate.Accept(player, {}, nil, 1) end
		t.expect.truthy(gate.Accept({} :: any, "Train", nil, 1))
	end)

	t.test("many players still have a bounded aggregate server budget", function()
		local gate = IntentGate.new()
		for _ = 1, Network.ServerIngress.Burst do
			t.expect.truthy(gate.Accept({} :: any, "Train", nil, 1))
		end
		local ok, reason = gate.Accept({} :: any, "Train", nil, 1)
		t.expect.falsy(ok); t.expect.equal(reason, "server rate limited")
		t.expect.truthy(gate.Accept({} :: any, "Train", nil, 2))
	end)

	t.test("cleanup discards player buckets", function()
		local gate = IntentGate.new()
		for _ = 1, Network.Policies.Train.Burst do gate.Accept(player, "Train", nil, 1) end
		t.expect.falsy(gate.Accept(player, "Train", nil, 1))
		gate.Cleanup(player)
		t.expect.truthy(gate.Accept(player, "Train", nil, 1))
	end)

	t.test("clock reversal does not create tokens", function()
		local gate = IntentGate.new()
		for _ = 1, Network.Policies.Train.Burst do gate.Accept(player, "Train", nil, 10) end
		t.expect.falsy(gate.Accept(player, "Train", nil, 9))
		t.expect.falsy(gate.Accept(player, "Train", nil, 10))
	end)
end
