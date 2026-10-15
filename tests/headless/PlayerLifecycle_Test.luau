-- Lifecycle tests with scheduler/profile/avatar I/O doubles; live rig loading requires Studio.
return function(t, fixture)
	local PlayerService = require(game.ServerScriptService.Server.Services.PlayerService)
	PlayerService.Start()
	t.test("already-present avatars acquire placement and death handling", function()
		local f = fixture.new()
		fixture.join(f.Player)
		t.expect.equal(f.Player.RespawnLocation.Parent.Name, "verdant")
		f.Humanoid.Died:Fire(); fixture.advance(3)
		t.expect.equal(f.Player.LoadCount, 1)
		fixture.leave(f.Player)
	end)
	t.test("profile readiness gates initial avatar spawn", function()
		local f = fixture.new(); f.Player.Character=nil; f.Player.Active=false
		fixture.join(f.Player)
		t.expect.equal(f.Player.LoadCount, 0)
		f.Player.Active=true; f.Player:SetAttribute("DataReady", true)
		t.expect.equal(f.Player.LoadCount, 1)
		t.expect.equal(f.Player:GetAttribute("SpawnStatus"), "Ready")
		t.expect.equal(f.Player.RespawnLocation.Parent.Name, "verdant")
		fixture.leave(f.Player)
	end)
	t.test("death schedules one respawn at the current region", function()
		local f = fixture.new(); f.Player.Character=nil
		f.Data.UnlockedRegions.frostfall=true; f.Data.CurrentRegion="frostfall"
		fixture.join(f.Player)
		f.Humanoid.Died:Fire()
		t.expect.equal(f.Player:GetAttribute("SpawnStatus"), "Respawning")
		fixture.advance(2); t.expect.equal(f.Player.LoadCount, 1)
		fixture.advance(1); t.expect.equal(f.Player.LoadCount, 2)
		t.expect.equal(f.Player.RespawnLocation.Parent.Name, "frostfall")
		fixture.leave(f.Player)
	end)
	t.test("region reset updates physical arrival and respawn", function()
		local f = fixture.new(); f.Player.Character=nil
		f.Data.UnlockedRegions.frostfall=true; f.Data.CurrentRegion="frostfall"
		fixture.join(f.Player)
		f.Data.CurrentRegion="verdant"; f.Data.UnlockedRegions={verdant=true}
		f.Player:SetAttribute("CurrentRegion", "verdant")
		t.expect.equal(f.Player.RespawnLocation.Parent.Name, "verdant")
		t.expect.equal(f.Root.Position.X, 0)
		fixture.leave(f.Player)
	end)
	t.test("leaving or losing a profile cancels pending respawn", function()
		for _, leave in {false,true} do
			local f = fixture.new(); f.Player.Character=nil; fixture.join(f.Player)
			f.Humanoid.Died:Fire()
			if leave then fixture.leave(f.Player) else f.Player.Active=false end
			fixture.advance(3); t.expect.equal(f.Player.LoadCount, 1)
			if not leave then fixture.leave(f.Player) end
		end
	end)
	t.test("failed character loading retries with a bound", function()
		local f = fixture.new(); f.Player.Character=nil; f.Player.FailLoads=true
		fixture.join(f.Player); fixture.advance(2); fixture.advance(2)
		t.expect.equal(f.Player.LoadCount, 3)
		t.expect.truthy(f.Player.Kicked)
		fixture.leave(f.Player)
	end)
end
