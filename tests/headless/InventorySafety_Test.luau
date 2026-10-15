-- Production services, explicit Roblox I/O doubles. Not a cloud save assertion.
return function(t, fixture)
	local Server = game.ServerScriptService.Server
	local Game = require(Server.Services.GameService)
	local Progression = require(Server.Services.ProgressionService)
	local Schema = require(game.ReplicatedStorage.Shared.Util.ProfileSchema)
	local function total(data)
		local n = 0; for _, count in data.OwnedWeapons do n += count end; return n
	end
	t.test("100 delayed network retries purchase only one item", function()
		local f = fixture.new(); local request = {RegionId = "verdant", Sequence = 1}
		Game.Handle(f.Player, "OpenChest", request)
		for _ = 1, 100 do fixture.advance(1); Game.Handle(f.Player, "OpenChest", request) end
		t.expect.equal(f.Data.Gold, 75); t.expect.equal(total(f.Data), 1)
		t.expect.equal(f.Data.ChestSequence, 1); t.expect.equal(fixture.saves(f.Player), 1)
	end)
	t.test("older sequences stay rejected after later purchases and migration", function()
		local f = fixture.new()
		Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		fixture.advance(1); Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 2})
		local restored = Schema.Migrate(f.Data)
		for key, value in restored do f.Data[key] = value end
		fixture.advance(1); Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		t.expect.equal(total(f.Data), 2); t.expect.equal(f.Data.Gold, 50)
	end)
	t.test("failed purchase does not consume the sequence or create a receipt", function()
		local f = fixture.new(); f.Data.Gold = 0
		Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		t.expect.equal(f.Data.ChestSequence, 0); t.expect.equal(f.Data.LastChestReceipt, nil)
		f.Data.Gold = 25; fixture.advance(1)
		Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		t.expect.equal(total(f.Data), 1); t.expect.equal(f.Data.Gold, 0)
	end)
	t.test("skipped sequence cannot buy and rebirth cannot reset receipts", function()
		local f = fixture.new()
		Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 9})
		t.expect.equal(total(f.Data), 0)
		Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		f.Data.Power = 20000; Game.Handle(f.Player, "Rebirth")
		fixture.advance(1); Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		t.expect.equal(total(f.Data), 1); t.expect.equal(f.Data.Gold, 100)
	end)
	t.test("one player cannot equip or mutate another player's inventory", function()
		local a, b = fixture.new(), fixture.new()
		b.Data.OwnedWeapons.verdant_crownblade = 3
		Game.Handle(a.Player, "EquipWeapon", "verdant_crownblade")
		Game.Handle(a.Player, "OpenChest", {RegionId = "verdant", Sequence = 1, OwnerUserId = b.Player.UserId})
		t.expect.equal(a.Data.EquippedWeapon, ""); t.expect.equal(total(a.Data), 0)
		t.expect.equal(b.Data.OwnedWeapons.verdant_crownblade, 3); t.expect.equal(b.Data.Gold, 100)
	end)
	t.test("actual remote entry rejects legacy requests and spoofed extra arguments", function()
		Game.Start()
		local a, b = fixture.new(), fixture.new()
		fixture.remote(a.Player, "OpenChest", "verdant")
		fixture.remote(a.Player, "OpenChest", {RegionId = "verdant", Sequence = 1}, b.Player)
		t.expect.equal(total(a.Data), 0); t.expect.equal(total(b.Data), 0)
		fixture.remote(a.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		t.expect.equal(total(a.Data), 1); t.expect.equal(total(b.Data), 0)
	end)
	t.test("training cadence is identical at 30, 60, 144 and 240 render FPS", function()
		local baseline
		for _, fps in {30, 60, 144, 240} do
			local f = fixture.new()
			-- Deliver the same timed inputs; render callbacks cannot grant extra ticks.
			for frame = 1, fps * 3 do
				fixture.advance(1/fps)
				if frame % (fps/2) == 0 then Progression.Train(f.Player) end
			end
			baseline = baseline or f.Data.Power
			t.expect.equal(f.Data.Power, baseline); t.expect.equal(f.Data.Power, 6)
		end
	end)
end
