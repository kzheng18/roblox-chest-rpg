--!strict
local Shared = game.ReplicatedStorage.Shared
local Progression = require(Shared.Util.Progression)
local Weapons = require(Shared.Config.Weapons)

local data = Progression.New()
assert(data.Power == 0)
assert(data.Gold > 0)
assert(data.UnlockedRegions.verdant == true)
assert(Progression.Luck(data) == 1)
assert(Progression.PowerGain(data) == 1)

data.OwnedWeapons.verdant_gale_spear = 1
data.EquippedWeapon = "verdant_gale_spear"
assert(Progression.PowerGain(data) == Weapons.ById.verdant_gale_spear.PowerMultiplier)
assert(Progression.CurrentRateN(Weapons.ById.verdant_gale_spear, 1) == 12)

return true

