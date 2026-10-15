--!strict
return function(t, fixture)
	local Regions = require(game.ReplicatedStorage.Shared.Config.Regions)
	local Layout = require(game.ReplicatedStorage.Shared.Config.WorldLayout)
	local Progression = require(game.ReplicatedStorage.Shared.Util.Progression)
	local RegionService = require(game.ServerScriptService.Server.Services.RegionService)
	t.test("linear map classifies seams and excludes off-map coordinates", function()
		t.expect.equal(Layout.RegionAt(fixture.position(0, 4, -234)), "verdant")
		t.expect.equal(Layout.RegionAt(fixture.position(0, 4, -235)), "frostfall")
		t.expect.equal(Layout.RegionAt(fixture.position(0, 4, -495)), "emberreach")
		t.expect.equal(Layout.RegionAt(fixture.position(300, 4, -400)), nil)
	end)
	t.test("walking into a locked region returns before the first locked gate", function()
		local f = fixture.new(); local gold = f.Data.Gold
		f.Root.Position = Regions.ById.frostfall.Center + Layout.Get("frostfall").Spawn
		RegionService.ObservePosition(f.Player)
		t.expect.equal(f.Data.CurrentRegion, "verdant")
		t.expect.equal(f.Data.Gold, gold)
		t.expect.truthy(f.Root.Position.Z > Regions.ById.frostfall.Center.Z + Layout.Get("frostfall").Front)
	end)
	t.test("unlocked walking updates region without teleporting or granting rewards", function()
		local f = fixture.new(); f.Data.UnlockedRegions.frostfall = true
		local gold = f.Data.Gold
		local arrival = fixture.position(0, 4, -300); f.Root.Position = arrival
		RegionService.ObservePosition(f.Player)
		t.expect.equal(f.Data.CurrentRegion, "frostfall")
		t.expect.equal(f.Root.Position, arrival)
		t.expect.equal(f.Data.Gold, gold)
	end)
	t.test("linear progression rejects skipping an earlier unlock", function()
		local f = fixture.new(); f.Data.Power = Regions.ById.emberreach.RequiredPower
		t.expect.falsy(Progression.CanUnlockRegion(f.Data, "emberreach"))
		f.Data.UnlockedRegions.emberreach = true
		f.Root.Position = Regions.ById.emberreach.Center + Layout.Get("emberreach").Spawn
		RegionService.ObservePosition(f.Player)
		t.expect.equal(f.Data.CurrentRegion, "verdant")
		t.expect.truthy(f.Root.Position.Z > Regions.ById.frostfall.Center.Z + Layout.Get("frostfall").Front)
	end)
end
