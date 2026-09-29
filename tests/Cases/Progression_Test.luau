--!strict
return function(t: any)
	local Shared = game.ReplicatedStorage.Shared
	local Progression = require(Shared.Util.Progression)
	local Economy = require(Shared.Config.Economy)
	local Weapons = require(Shared.Config.Weapons)

	t.test("rebirth applies permanent bonuses and resets run state", function()
		local data = Progression.New()
		data.Power = Economy.RebirthPowerRequirement
		data.Gold = 9000
		data.UnlockedRegions.frostfall = true
		data.CurrentRegion = "frostfall"
		data.OwnedWeapons.verdant_gale_spear = 1
		data.EquippedWeapon = "verdant_gale_spear"
		local oldLuck = data.Luck
		t.expect.truthy(Progression.ApplyRebirth(data))
		t.expect.equal(data.Rebirths, 1)
		t.expect.near(data.Luck, oldLuck + Economy.LuckPerRebirth)
		t.expect.equal(data.Power, 0)
		t.expect.equal(data.Gold, Economy.StartingGold)
		t.expect.truthy(data.UnlockedRegions.verdant)
		t.expect.equal(data.UnlockedRegions.frostfall, nil)
		t.expect.equal(data.CurrentRegion, "verdant")
		t.expect.equal(data.OwnedWeapons.verdant_gale_spear, 1)
		t.expect.equal(data.EquippedWeapon, "verdant_gale_spear")
	end)

	t.test("rebirth is rejected below requirement", function()
		local data = Progression.New()
		data.Power = Economy.RebirthPowerRequirement - 1
		t.expect.falsy(Progression.ApplyRebirth(data))
		t.expect.equal(data.Rebirths, 0)
	end)

	t.test("persisted luck drives current luck", function()
		local data = Progression.New()
		data.Luck = 2.75
		data.Rebirths = 99
		t.expect.equal(Progression.Luck(data), 2.75)
	end)

	t.test("best owned weapon uses highest multiplier", function()
		local data = Progression.New()
		data.OwnedWeapons.verdant_iron_sword = 5
		data.OwnedWeapons.verdant_crownblade = 1
		data.OwnedWeapons.verdant_gale_spear = 3
		t.expect.equal(Progression.BestOwnedWeapon(data), "verdant_crownblade")
	end)

	t.test("region gate follows configured power", function()
		local data = Progression.New()
		local allowed = select(1, Progression.CanUnlockRegion(data, "frostfall"))
		t.expect.falsy(allowed)
		data.Power = 2500
		allowed = select(1, Progression.CanUnlockRegion(data, "frostfall"))
		t.expect.truthy(allowed)
	end)

	t.test("rarity reciprocal odds preserve common and rare floors", function()
		local common = Weapons.ById.verdant_iron_sword
		local rare = Weapons.ById.verdant_gale_spear
		t.expect.equal(Progression.CurrentRateN(common, 999999), 1)
		t.expect.equal(Progression.CurrentRateN(rare, 1), rare.RateN)
		t.expect.equal(Progression.CurrentRateN(rare, 999999), 2)
	end)
end
