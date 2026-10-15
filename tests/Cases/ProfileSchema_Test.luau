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

	t.test("malformed progression cannot overwrite a save with defaults", function()
		local ok = pcall(ProfileSchema.Migrate, {
			Version = 2,
			Power = -10,
			Gold = 0 / 0,
			Luck = math.huge,
			Rebirths = -9,
			Revision = -1,
		})
		t.expect.falsy(ok)
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

	t.test("invalid weapon counts stop migration rather than discard items", function()
		local ok = pcall(ProfileSchema.Migrate, {
			Version = 2,
			OwnedWeapons = {good = 2.8, zero = 0, negative = -2, text = "2"},
		})
		t.expect.falsy(ok)
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

	t.test("legacy inventory and retired IDs survive ownership migration", function()
		local data = ProfileSchema.Migrate({Version = 2, Gold = 900, OwnedWeapons = {verdant_iron_sword = 5, retired_blade = 2}, EquippedWeapon = "verdant_iron_sword"})
		t.expect.equal(data.OwnedWeapons.verdant_iron_sword, 5)
		t.expect.equal(data.OwnedWeapons.retired_blade, 2)
		t.expect.equal(data.Gold, 900); t.expect.equal(data.OwnerUserId, 0)
	end)
	t.test("profiles have independent inventory settings and receipt containers", function()
		local a, b = ProfileSchema.New(), ProfileSchema.New()
		a.OwnedWeapons.verdant_iron_sword = 5; a.Settings.Volume = 0
		t.expect.equal(b.OwnedWeapons.verdant_iron_sword, nil); t.expect.equal(b.Settings.Volume, .8)
	end)
	t.test("future schema, cyclic inventory and non-finite counts fail closed", function()
		local cyclic: any = {}; cyclic.item = cyclic
		for _, raw in {{Version = 999}, {OwnedWeapons = cyclic}, {OwnedWeapons = {blade = math.huge}}, {OwnedWeapons = {blade = 0/0}}, {EquippedWeapon = "unowned"}} do
			t.expect.falsy(pcall(ProfileSchema.Migrate, raw))
		end
	end)
end
