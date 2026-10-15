--!strict
return function(t: any)
	local Schema = require(game.ReplicatedStorage.Shared.Util.ProfileSchema)
	local Recovery = require(game.ServerScriptService.Server.Components.RecoveryPlan)
	t.test("recovery restores archived inventory without mutating active data", function()
		local current = Schema.New(); current.OwnerUserId = 123; current.Revision = 9
		current.ChestSequence = 4
		current.LastChestReceipt = {Sequence = 4, Id = "verdant_iron_sword", Region = "verdant", RateN = 1}
		local archive = Schema.New(); archive.OwnerUserId = 123
		archive.OwnedWeapons.verdant_crownblade = 2; archive.EquippedWeapon = "verdant_crownblade"
		local plan = Recovery.Prepare(current, archive, 123)
		t.expect.equal(plan.OwnedWeapons.verdant_crownblade, 2)
		t.expect.equal(current.OwnedWeapons.verdant_crownblade, nil)
		t.expect.equal(plan.ChestSequence, 4); t.expect.equal(plan.Revision, 10)
		t.expect.equal(plan.LastChestReceipt.Sequence, 4)
		plan.LastChestReceipt.Sequence = 99
		t.expect.equal(current.LastChestReceipt.Sequence, 4)
	end)
	t.test("recovery rejects another player's archive", function()
		local current, archive = Schema.New(), Schema.New()
		current.OwnerUserId = 123; archive.OwnerUserId = 456
		t.expect.falsy(pcall(Recovery.Prepare, current, archive, 123))
		t.expect.falsy(pcall(Recovery.Prepare, current, archive, 456))
	end)
	t.test("legacy archives preserve items and acquire the correct owner", function()
		local current = Schema.New(); current.OwnerUserId = 123
		local plan = Recovery.Prepare(current, {Version = 2, OwnedWeapons = {verdant_iron_sword = 3}}, 123)
		t.expect.equal(plan.OwnerUserId, 123); t.expect.equal(plan.OwnedWeapons.verdant_iron_sword, 3)
	end)
end
