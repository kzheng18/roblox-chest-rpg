--!strict
return function(t: any)
	local Shared = game.ReplicatedStorage.Shared
	local ProfileSchema = require(Shared.Util.ProfileSchema)
	local Economy = require(Shared.Config.Economy)

	t.test("new profile uses current schema defaults", function()
		local data = ProfileSchema.New()
		t.expect.equal(data.Version, ProfileSchema.Version)
		t.expect.equal(data.Revision, 0)
		t.expect.equal(data.Power, 0)
		t.expect.equal(data.Gold, Economy.StartingGold)
		t.expect.equal(data.Luck, 1)
		t.expect.truthy(data.UnlockedRegions.verdant)
	end)

	t.test("v1 profile derives persisted luck from rebirths", function()
		local data = ProfileSchema.Migrate({Version = 1, Rebirths = 4})
		t.expect.near(data.Luck, 1 + 4 * Economy.LuckPerRebirth)
		t.expect.equal(data.Version, ProfileSchema.Version)
	end)

	t.test("malformed numeric values are sanitized", function()
		local data = ProfileSchema.Migrate({
			Version = 2,
			Power = -10,
			Gold = 0 / 0,
			Luck = math.huge,
			Rebirths = -9,
			Revision = -1,
		})
		t.expect.equal(data.Power, 0)
		t.expect.equal(data.Gold, Economy.StartingGold)
		t.expect.equal(data.Luck, 1)
		t.expect.equal(data.Rebirths, 0)
		t.expect.equal(data.Revision, 0)
	end)

	t.test("missing and invalid settings are repaired", function()
		local data = ProfileSchema.Migrate({
			Version = 2,
			Settings = {RollAnimation = "yes", ReducedMotion = 4, Volume = 5},
		})
		t.expect.equal(data.Settings.RollAnimation, true)
		t.expect.equal(data.Settings.ReducedMotion, false)
		t.expect.equal(data.Settings.Volume, 1)
	end)

	t.test("invalid weapon counts are removed", function()
		local data = ProfileSchema.Migrate({
			Version = 2,
			OwnedWeapons = {good = 2.8, zero = 0, negative = -2, text = "2"},
		})
		t.expect.equal(data.OwnedWeapons.good, 2)
		t.expect.equal(data.OwnedWeapons.zero, nil)
		t.expect.equal(data.OwnedWeapons.negative, nil)
		t.expect.equal(data.OwnedWeapons.text, nil)
	end)

	t.test("migration does not mutate source tables", function()
		local raw = {
			Version = 2,
			OwnedWeapons = {weapon = 3},
			Settings = {RollAnimation = true, ReducedMotion = false, Volume = 0.4},
		}
		local data = ProfileSchema.Migrate(raw)
		data.OwnedWeapons.weapon = 9
		data.Settings.Volume = 0.9
		t.expect.equal(raw.OwnedWeapons.weapon, 3)
		t.expect.equal(raw.Settings.Volume, 0.4)
	end)

	t.test("migrated profiles pass validation", function()
		local data = ProfileSchema.Migrate({Version = 0})
		local valid, reason = ProfileSchema.Validate(data)
		t.expect.truthy(valid)
		t.expect.equal(reason, nil)
	end)
end
