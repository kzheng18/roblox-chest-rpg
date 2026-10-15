-- Exact service code with mocked Roblox I/O; run via tools/test_local.py.
return function(t, fixture)
	local services = game.ServerScriptService.Server.Services
	local Game = require(services.GameService)
	local Chest = require(services.ChestService)
	local Progression = require(services.ProgressionService)
	local Region = require(services.RegionService)
	local Context = require(game.ServerScriptService.Server.Components.RequestContext)
	local Weapons = require(game.ReplicatedStorage.Shared.Config.Weapons)
	local Regions = require(game.ReplicatedStorage.Shared.Config.Regions)
	local function count(data)
		local total = 0
		for _, n in data.OwnedWeapons do total += n end
		return total
	end

	t.test("valid nearby chest spends once and grants an owned catalog item", function()
		local f = fixture.new(); local gold = f.Data.Gold
		Game.Handle(f.Player, "OpenChest", "verdant")
		t.expect.equal(f.Data.Gold, gold - Regions.ById.verdant.ChestCost)
		t.expect.equal(count(f.Data), 1)
		t.expect.truthy(Weapons.ById[f.Data.EquippedWeapon])
		t.expect.equal(fixture.saves(f.Player), 1)
	end)

	t.test("chest spam within cooldown cannot award extra items", function()
		local f = fixture.new()
		for _ = 1, 100 do Game.Handle(f.Player, "OpenChest", "verdant") end
		t.expect.equal(count(f.Data), 1)
	end)

	t.test("distant chest request leaves economy unchanged", function()
		local f = fixture.new(); local gold = f.Data.Gold
		f.Root.Position = fixture.position(0,3,100)
		Game.Handle(f.Player, "OpenChest", "verdant")
		t.expect.equal(f.Data.Gold, gold); t.expect.equal(count(f.Data), 0)
		t.expect.equal(fixture.saves(f.Player), 0)
	end)

	t.test("dead and unanchored chest interactions fail closed", function()
		local f = fixture.new()
		f.Humanoid.Health = 0
		t.expect.falsy(Context.NearChest(f.Player, "verdant"))
		Chest.Open(f.Player, {RegionId="verdant", Sequence=f.Data.ChestSequence+1})
		t.expect.equal(count(f.Data), 0)
		f.Humanoid.Health = 100; f.Chest.Anchored = false
		t.expect.falsy(Context.NearChest(f.Player, "verdant"))
	end)

	t.test("invalid character coordinates and health cannot bypass proximity", function()
		local f = fixture.new()
		for _, value in {0/0, math.huge, -math.huge} do
			f.Root.Position = fixture.position(value,3,-16)
			t.expect.falsy(Context.NearChest(f.Player, "verdant"))
		end
		f.Root.Position = fixture.position(0,3,-16); f.Humanoid.Health = 0/0
		t.expect.falsy(Context.LivingRoot(f.Player))
	end)

	t.test("locked or non-current region cannot supply chest rewards", function()
		local f = fixture.new(); local gold = f.Data.Gold
		Game.Handle(f.Player, "OpenChest", "frostfall")
		f.Data.UnlockedRegions.frostfall = true
		fixture.advance(1); Game.Handle(f.Player, "OpenChest", "frostfall")
		t.expect.equal(f.Data.Gold, gold); t.expect.equal(count(f.Data), 0)
	end)

	t.test("unknown chest and empty server loot pool never consume Gold", function()
		local f = fixture.new(); local gold = f.Data.Gold
		Chest.Open(f.Player, {}); Chest.Open(f.Player, "invented")
		local pool = Weapons.ByRegion.verdant
		Weapons.ByRegion.verdant = {}
		local ok, err = pcall(Chest.Open, f.Player, {RegionId="verdant", Sequence=f.Data.ChestSequence+1})
		Weapons.ByRegion.verdant = pool
		assert(ok, err)
		t.expect.equal(f.Data.Gold, gold); t.expect.equal(count(f.Data), 0)
	end)

	t.test("insufficient Gold and invalid balances cannot buy", function()
		for _, balance in {0, -1, 0/0, math.huge} do
			local f = fixture.new(); f.Data.Gold = balance
			Game.Handle(f.Player, "OpenChest", "verdant")
			t.expect.equal(count(f.Data), 0); t.expect.equal(fixture.saves(f.Player), 0)
		end
	end)

	t.test("loading or ended profiles and departed players cannot mutate", function()
		for _, departed in {false,true} do
			local f = fixture.new(); local gold = f.Data.Gold
			if departed then f.Player.Parent = nil else f.Player.Active = false end
			for _, action in {"Train","Rebirth","EquipBest","RequestState"} do Game.Handle(f.Player, action) end
			Game.Handle(f.Player, "OpenChest", "verdant")
			Chest.Open(f.Player, {RegionId="verdant", Sequence=f.Data.ChestSequence+1})
			t.expect.equal(f.Data.Gold, gold); t.expect.equal(f.Data.Power, 0)
			t.expect.equal(count(f.Data), 0); t.expect.equal(fixture.snapshots(f.Player), 0)
		end
	end)

	t.test("unowned equipment is rejected but valid ownership works", function()
		local f = fixture.new()
		Game.Handle(f.Player, "EquipWeapon", "verdant_gale_spear")
		t.expect.equal(f.Data.EquippedWeapon, "")
		f.Data.OwnedWeapons.verdant_gale_spear = 1
		Game.Handle(f.Player, "EquipWeapon", "verdant_gale_spear")
		t.expect.equal(f.Data.EquippedWeapon, "verdant_gale_spear")
	end)

	t.test("non-finite and fractional weapon counts do not confer ownership", function()
		local f = fixture.new()
		for _, value in {0/0, math.huge, -1, 0.5} do
			f.Data.OwnedWeapons.verdant_gale_spear = value
			Progression.Equip(f.Player, "verdant_gale_spear")
			Progression.EquipBest(f.Player)
			t.expect.equal(f.Data.EquippedWeapon, "")
		end
	end)

	t.test("spoofing replicated attributes cannot override authoritative state", function()
		local f = fixture.new()
		f.Player.DataReady = true; f.Player.Gold = 1e9; f.Player.CurrentRegion = "frostfall"
		f.Data.Gold = 0
		Game.Handle(f.Player, "OpenChest", "verdant")
		t.expect.equal(f.Data.Gold, 0); t.expect.equal(count(f.Data), 0)
	end)

	t.test("settings validate within the service as well as at ingress", function()
		local f = fixture.new(); local volume = f.Data.Settings.Volume
		for _, value in {0/0, math.huge, -0.1, 1.1, {}, "1"} do
			Progression.UpdateSetting(f.Player, "Volume", value)
		end
		Game.Handle(f.Player, "Setting", {Key="Volume",Value=0.2,Admin=true})
		t.expect.equal(f.Data.Settings.Volume, volume)
		Progression.UpdateSetting(f.Player, "Volume", 0.5)
		t.expect.equal(f.Data.Settings.Volume, 0.5)
	end)

	t.test("spoofed identity and extra remote arguments cannot select another profile", function()
		local a = fixture.new(); local b = fixture.new()
		Game.Handle(a.Player, "Train", {UserId=b.Player.UserId,Gold=1e9})
		Game.Handle(a.Player, "Train", nil, b.Player)
		t.expect.equal(a.Data.Power, 0); t.expect.equal(b.Data.Power, 0)
	end)

	t.test("request flooding produces bounded warnings", function()
		local f = fixture.new(); local before = fixture.warnings()
		for _ = 1, 10000 do Game.Handle(f.Player, {}, {}) end
		t.expect.truthy(fixture.warnings() - before <= 1)
		t.expect.equal(f.Data.Power, 0)
	end)

	t.test("living character is required for training and region travel", function()
		local f = fixture.new(); f.Humanoid.Health = 0
		f.Data.Power = 3000
		Region.Unlock(f.Player, "frostfall"); Progression.Train(f.Player)
		t.expect.equal(f.Data.UnlockedRegions.frostfall, nil)
		t.expect.equal(f.Data.Power, 3000)
		f.Humanoid.Health = 100
		Game.Handle(f.Player, "Train")
		t.expect.truthy(f.Data.Power > 3000)
		Game.Handle(f.Player, "UnlockRegion", "frostfall")
		t.expect.equal(f.Data.UnlockedRegions.frostfall, true)
		t.expect.equal(f.Data.CurrentRegion, "frostfall")
	end)

	t.test("travel still requires an unlocked region and rebirth requires Power", function()
		local f = fixture.new()
		Region.Travel(f.Player, "frostfall"); Region.Unlock(f.Player, "frostfall")
		Game.Handle(f.Player, "Rebirth")
		t.expect.equal(f.Data.CurrentRegion, "verdant"); t.expect.equal(f.Data.Rebirths, 0)
		f.Data.Power = 20000; fixture.advance(3)
		Game.Handle(f.Player, "Rebirth"); Game.Handle(f.Player, "Rebirth")
		t.expect.equal(f.Data.Rebirths, 1)
	end)
end
