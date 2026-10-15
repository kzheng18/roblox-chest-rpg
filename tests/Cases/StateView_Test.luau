--!strict
return function(t: any)
	local Shared = game.ReplicatedStorage.Shared
	local StateView = require(Shared.Util.StateView)
	local Progression = require(Shared.Util.Progression)

	t.test("snapshot includes authoritative derived values", function()
		local data = Progression.New()
		data.Rebirths = 2
		data.Luck = 1.7
		local view = StateView.Snapshot(data)
		t.expect.equal(view.Luck, 1.7)
		t.expect.near(view.PowerGain, Progression.PowerGain(data))
		t.expect.near(view.GoldGain, Progression.GoldGain(data))
	end)

	t.test("delta includes only dirty fields", function()
		local data = Progression.New()
		data.Power = 10
		data.Gold = 20
		data.OwnedWeapons.verdant_gale_spear = 1
		local delta = StateView.Delta(data, {Power = true, Gold = true})
		t.expect.equal(delta.Power, 10)
		t.expect.equal(delta.Gold, 20)
		t.expect.equal(delta.OwnedWeapons, nil)
		t.expect.equal(delta.Settings, nil)
	end)

	t.test("power gain delta reflects equipment changes", function()
		local data = Progression.New()
		local base = StateView.Delta(data, {PowerGain = true}).PowerGain
		data.OwnedWeapons.verdant_gale_spear = 1
		data.EquippedWeapon = "verdant_gale_spear"
		local equipped = StateView.Delta(data, {PowerGain = true}).PowerGain
		t.expect.truthy(equipped > base)
	end)
	t.test("owner binding and transaction receipts never leak into state", function()
		local data = Progression.New(); data.OwnerUserId = 123
		local snapshot = StateView.Snapshot(data)
		local delta = StateView.Delta(data, {OwnerUserId = true, LastChestReceipt = true, ChestSequence = true})
		t.expect.equal(snapshot.OwnerUserId, nil); t.expect.equal(snapshot.LastChestReceipt, nil)
		t.expect.equal(delta.OwnerUserId, nil); t.expect.equal(delta.LastChestReceipt, nil)
		t.expect.equal(delta.ChestSequence, 0)
	end)
end
