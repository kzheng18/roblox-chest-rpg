--!strict
return function(t: any)
	local Shared = game.ReplicatedStorage.Shared
	local Powers = require(Shared.Config.Powers)
	local Regions = require(Shared.Config.Regions)
	local Showcase = require(Shared.Config.Showcase)
	local PowerOdds = require(Shared.Util.PowerOdds)
	local Progression = require(Shared.Util.Progression)
	local ProfileSchema = require(Shared.Util.ProfileSchema)

	local function sequence(values: {number}): () -> number
		local i = 0
		return function()
			i += 1
			return values[i] or 0
		end
	end

	t.test("power catalog references real themes, regions and reveal tiers", function()
		for _, power in Powers.List do
			t.expect.truthy(Powers.ThemeById[power.Theme])
			t.expect.truthy(Regions.ById[power.Region])
			t.expect.truthy(Showcase.RevealTier[power.Rarity])
			t.expect.truthy(power.Weight > 0 and power.PowerMultiplier > 1)
		end
		for _, region in Regions.List do
			t.expect.truthy(Powers.ByRegion[region.Id] and #Powers.ByRegion[region.Id] > 0)
		end
	end)

	t.test("power and theme names avoid source-anime terms", function()
		local banned = {"gum", "mera", "hie", "goro", "yami", "luffy", "zoro", "asta", "yuno", "haki", "devil", "clover", "nen", "chakra", "bankai"}
		local names = {}
		for _, power in Powers.List do table.insert(names, power.Name) end
		for _, theme in Powers.Themes do table.insert(names, theme.Name); table.insert(names, theme.SlotName) end
		for _, name in names do
			for _, word in banned do
				t.expect.falsy(string.find(string.lower(name), word, 1, true))
			end
		end
	end)

	t.test("final power odds sum to the region drop chance", function()
		for regionId, chance in Powers.DropChance do
			local sum = 0
			for _, entry in PowerOdds.Table(regionId, 1) do sum += entry.Probability end
			t.expect.near(sum, chance, 1e-9)
		end
	end)

	t.test("displayed power odds are exact final odds", function()
		for _, entry in PowerOdds.Table("emberreach", 1) do
			if entry.Power.Id == "pirate_radiance" then
				t.expect.equal(entry.RateN, math.floor(1 / (0.16 * 2 / 803) + 0.5))
			end
		end
	end)

	t.test("luck raises rare power odds without changing drop chance", function()
		local function rate(luck: number): number
			for _, entry in PowerOdds.Table("emberreach", luck) do
				if entry.Power.Id == "mage_void" then return entry.Probability end
			end
			return 0
		end
		t.expect.truthy(rate(4) > rate(1))
		local sum = 0
		for _, entry in PowerOdds.Table("emberreach", 4) do sum += entry.Probability end
		t.expect.near(sum, Powers.DropChance.emberreach, 1e-9)
	end)

	t.test("power roll misses above the drop chance and picks by cumulative odds", function()
		t.expect.equal(PowerOdds.Roll("verdant", 1, sequence({0.5})), nil)
		local first = PowerOdds.Table("verdant", 1)[1]
		local power, rateN = PowerOdds.Roll("verdant", 1, sequence({0, 0}))
		t.expect.equal(power, first.Power); t.expect.equal(rateN, first.RateN)
		local last = PowerOdds.Roll("verdant", 1, sequence({0, 0.999999}))
		local entries = PowerOdds.Table("verdant", 1)
		t.expect.equal(last, entries[#entries].Power)
	end)

	t.test("one equipped power per anime and the slots multiply together", function()
		local data = Progression.New()
		local base = Progression.PowerGain(data)
		data.OwnedPowers.pirate_flame = 1
		data.OwnedPowers.mage_void = 1
		data.EquippedPowers.pirate = "pirate_flame"
		t.expect.near(Progression.PowerGain(data), base * 6.0)
		data.EquippedPowers.mage = "mage_void"
		t.expect.near(Progression.PowerStackMultiplier(data), 6.0 * 20.0)
		t.expect.near(Progression.PowerGain(data), base * 120.0)
	end)

	t.test("power stacking multiplies with weapon and rebirth bonuses", function()
		local data = Progression.New()
		data.Rebirths = 2
		data.OwnedWeapons.ember_starfall = 1; data.EquippedWeapon = "ember_starfall"
		data.OwnedPowers.pirate_rubber = 1; data.EquippedPowers.pirate = "pirate_rubber"
		data.OwnedPowers.mage_gale = 1; data.EquippedPowers.mage = "mage_gale"
		t.expect.near(Progression.PowerGain(data), 1 * 1.5 * 18.0 * 1.40 * 1.25)
	end)

	t.test("unowned or wrong-theme equipped powers grant nothing", function()
		local data = Progression.New()
		data.EquippedPowers.pirate = "pirate_flame"
		t.expect.near(Progression.PowerStackMultiplier(data), 1)
		data.OwnedPowers.mage_void = 1
		data.EquippedPowers.pirate = "mage_void"
		t.expect.near(Progression.PowerStackMultiplier(data), 1)
	end)

	t.test("best owned power is chosen per theme", function()
		local data = Progression.New()
		data.OwnedPowers.pirate_rubber = 3; data.OwnedPowers.pirate_frost = 1; data.OwnedPowers.mage_gale = 2
		t.expect.equal(Progression.BestOwnedPower(data, "pirate"), "pirate_frost")
		t.expect.equal(Progression.BestOwnedPower(data, "mage"), "mage_gale")
	end)

	t.test("rebirth keeps powers and their slots", function()
		local data = Progression.New()
		data.Power = 20_000
		data.OwnedPowers.pirate_frost = 1; data.EquippedPowers.pirate = "pirate_frost"
		t.expect.truthy(Progression.ApplyRebirth(data))
		t.expect.equal(data.OwnedPowers.pirate_frost, 1)
		t.expect.equal(data.EquippedPowers.pirate, "pirate_frost")
	end)

	t.test("version 3 profiles migrate to version 4 with empty powers", function()
		local data = ProfileSchema.Migrate({Version = 3, Gold = 700, OwnedWeapons = {verdant_iron_sword = 2}, EquippedWeapon = "verdant_iron_sword"})
		t.expect.equal(data.Version, 4)
		t.expect.equal(next(data.OwnedPowers), nil)
		t.expect.equal(next(data.EquippedPowers), nil)
		t.expect.equal(data.OwnedWeapons.verdant_iron_sword, 2)
	end)

	t.test("saved powers, slots and power receipts survive migration", function()
		local data = ProfileSchema.Migrate({
			Version = 4, ChestSequence = 3,
			LastChestReceipt = {Sequence = 3, Region = "verdant", Id = "verdant_iron_sword", RateN = 1, PowerId = "pirate_smoke", PowerRateN = 217},
			OwnedWeapons = {verdant_iron_sword = 3}, OwnedPowers = {pirate_smoke = 1, retired_fruit = 2},
			EquippedPowers = {pirate = "pirate_smoke"},
		})
		t.expect.equal(data.OwnedPowers.retired_fruit, 2)
		t.expect.equal(data.EquippedPowers.pirate, "pirate_smoke")
		t.expect.equal((data.LastChestReceipt :: any).PowerId, "pirate_smoke")
	end)

	t.test("invalid power saves are rejected rather than emptied", function()
		for _, raw in {
			{Version = 4, EquippedPowers = {pirate = "pirate_smoke"}},
			{Version = 4, OwnedPowers = {pirate_smoke = 0.5}},
			{Version = 4, ChestSequence = 1, LastChestReceipt = {Sequence = 1, Region = "verdant", Id = "verdant_iron_sword", RateN = 1, PowerId = "pirate_smoke"}},
		} do
			t.expect.falsy(pcall(ProfileSchema.Migrate, raw))
		end
	end)
end
