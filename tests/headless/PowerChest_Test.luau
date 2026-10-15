-- Production chest service with deterministic draws. Not an engine or cloud test.
return function(t, fixture)
	local Server = game.ServerScriptService.Server
	local Game = require(Server.Services.GameService)
	local Chest = require(Server.Services.ChestService)
	local Announce = require(Server.Services.AnnouncementService)
	local always = {NextInteger = function(_, minimum) return minimum end}
	local never = {NextInteger = function(_, _, maximum) return maximum end}
	local function lastResult(player)
		local events = fixture.events()
		for i = #events, 1, -1 do
			if events[i].Player == player and events[i].Kind == "ChestResult" then return events[i].Payload end
		end
		return nil
	end
	local function announcements()
		local n = 0
		for _, event in fixture.events() do if event.Kind == "Announce" then n += 1 end end
		return n
	end

	t.test("a chest can grant a bonus power, equip its slot and record the receipt", function()
		Chest.SetRandomForTests(always)
		local f = fixture.new()
		Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		Chest.SetRandomForTests(never)
		t.expect.equal(f.Data.OwnedPowers.pirate_rubber, 1)
		t.expect.equal(f.Data.EquippedPowers.pirate, "pirate_rubber")
		t.expect.equal(f.Data.LastChestReceipt.PowerId, "pirate_rubber")
		local result = lastResult(f.Player)
		t.expect.equal(result.Power.Id, "pirate_rubber")
		t.expect.equal(result.Power.SlotName, "Cursed Fruit")
	end)

	t.test("network retries replay the same power without granting it twice", function()
		Chest.SetRandomForTests(always)
		local f = fixture.new()
		local request = {RegionId = "verdant", Sequence = 1}
		Game.Handle(f.Player, "OpenChest", request)
		Chest.SetRandomForTests(never)
		for _ = 1, 5 do fixture.advance(1); Game.Handle(f.Player, "OpenChest", request) end
		t.expect.equal(f.Data.OwnedPowers.pirate_rubber, 1)
		local replay = lastResult(f.Player)
		t.expect.truthy(replay.Replay)
		t.expect.equal(replay.Power.Id, "pirate_rubber")
	end)

	t.test("a missed power roll leaves powers untouched and weapon odds unchanged", function()
		Chest.SetRandomForTests(never)
		local f = fixture.new()
		Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		t.expect.equal(next(f.Data.OwnedPowers), nil)
		t.expect.equal(f.Data.OwnedWeapons.verdant_iron_sword, 1)
		t.expect.equal(lastResult(f.Player).Power, nil)
	end)

	t.test("a weaker power does not replace a stronger one in the same slot", function()
		Chest.SetRandomForTests(always)
		local f = fixture.new()
		f.Data.OwnedPowers.pirate_smoke = 1; f.Data.EquippedPowers.pirate = "pirate_smoke"
		Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		Chest.SetRandomForTests(never)
		t.expect.equal(f.Data.OwnedPowers.pirate_rubber, 1)
		t.expect.equal(f.Data.EquippedPowers.pirate, "pirate_smoke")
	end)

	t.test("equip best fills every anime slot", function()
		local f = fixture.new()
		f.Data.OwnedPowers.pirate_rubber = 1; f.Data.OwnedPowers.pirate_frost = 1; f.Data.OwnedPowers.mage_mirror = 1
		Game.Handle(f.Player, "EquipBest")
		t.expect.equal(f.Data.EquippedPowers.pirate, "pirate_frost")
		t.expect.equal(f.Data.EquippedPowers.mage, "mage_mirror")
	end)

	t.test("rare pulls are announced to the server, common pulls are not", function()
		local before = announcements()
		local f = fixture.new()
		Announce.Consider(f.Player, "Ironleaf Sword", "Common", 1, "Weapon")
		t.expect.equal(announcements(), before)
		Announce.Consider(f.Player, "Mirror Grimoire", "Legendary", 1233, "Grimoire")
		Announce.Consider(f.Player, "Galevine Spear", "Rare", 1500, "Weapon")
		t.expect.equal(announcements(), before + 2)
		local announce, global = Announce.ShouldAnnounce("Mythic", 10)
		t.expect.truthy(announce); t.expect.truthy(global)
	end)

	t.test("the chest announces its own rare reward", function()
		Chest.SetRandomForTests(always) -- rarest weapon check succeeds first
		local f = fixture.new()
		local before = announcements()
		Game.Handle(f.Player, "OpenChest", {RegionId = "verdant", Sequence = 1})
		Chest.SetRandomForTests(never)
		t.expect.truthy(announcements() > before)
	end)
end
