--!strict
export type Weapon = {
	Id: string,
	Name: string,
	Region: string,
	Rarity: string,
	RateN: number,
	LuckExponent: number,
	PowerMultiplier: number,
	Family: string,
}

local Weapons: {Weapon} = {
	{Id="verdant_iron_sword", Name="Ironleaf Sword", Region="verdant", Rarity="Common", RateN=1, LuckExponent=0, PowerMultiplier=1.10, Family="Sword"},
	{Id="verdant_hunter_bow", Name="Briar Hunter Bow", Region="verdant", Rarity="Uncommon", RateN=4, LuckExponent=0.30, PowerMultiplier=1.25, Family="Bow"},
	{Id="verdant_gale_spear", Name="Galevine Spear", Region="verdant", Rarity="Rare", RateN=12, LuckExponent=0.45, PowerMultiplier=1.55, Family="Spear"},
	{Id="verdant_clover_blade", Name="Clover Greatblade", Region="verdant", Rarity="Epic", RateN=60, LuckExponent=0.60, PowerMultiplier=2.10, Family="Greatsword"},
	{Id="verdant_crownblade", Name="Verdant Crownblade", Region="verdant", Rarity="Legendary", RateN=300, LuckExponent=0.75, PowerMultiplier=3.10, Family="Sword"},
	{Id="verdant_seraph", Name="Seraphic Thorn", Region="verdant", Rarity="Mythic", RateN=2_500, LuckExponent=0.90, PowerMultiplier=5.25, Family="Spear"},

	{Id="frost_steel_saber", Name="Froststeel Saber", Region="frostfall", Rarity="Common", RateN=1, LuckExponent=0, PowerMultiplier=2.40, Family="Sword"},
	{Id="frost_rime_bow", Name="Rimewood Longbow", Region="frostfall", Rarity="Uncommon", RateN=5, LuckExponent=0.30, PowerMultiplier=2.75, Family="Bow"},
	{Id="frost_glacier_pike", Name="Glacier Pike", Region="frostfall", Rarity="Rare", RateN=16, LuckExponent=0.45, PowerMultiplier=3.30, Family="Spear"},
	{Id="frost_winterfang", Name="Winterfang", Region="frostfall", Rarity="Epic", RateN=75, LuckExponent=0.60, PowerMultiplier=4.20, Family="Greatsword"},
	{Id="frost_aurora", Name="Aurora Edge", Region="frostfall", Rarity="Legendary", RateN=400, LuckExponent=0.75, PowerMultiplier=6.10, Family="Sword"},
	{Id="frost_sovereign", Name="Frost Sovereign", Region="frostfall", Rarity="Mythic", RateN=3_200, LuckExponent=0.90, PowerMultiplier=9.50, Family="Greatsword"},

	{Id="ember_ash_sword", Name="Ashforged Sword", Region="emberreach", Rarity="Common", RateN=1, LuckExponent=0, PowerMultiplier=5.50, Family="Sword"},
	{Id="ember_cinder_bow", Name="Cinder Bow", Region="emberreach", Rarity="Uncommon", RateN=5, LuckExponent=0.30, PowerMultiplier=6.25, Family="Bow"},
	{Id="ember_magma_spear", Name="Magma Lance", Region="emberreach", Rarity="Rare", RateN=18, LuckExponent=0.45, PowerMultiplier=7.40, Family="Spear"},
	{Id="ember_infernal", Name="Infernal Greatsword", Region="emberreach", Rarity="Epic", RateN=90, LuckExponent=0.60, PowerMultiplier=9.00, Family="Greatsword"},
	{Id="ember_sunbreaker", Name="Sunbreaker", Region="emberreach", Rarity="Legendary", RateN=500, LuckExponent=0.75, PowerMultiplier=12.50, Family="Greatsword"},
	{Id="ember_starfall", Name="Starfall Gauntlets", Region="emberreach", Rarity="Mythic", RateN=4_000, LuckExponent=0.90, PowerMultiplier=18.00, Family="Gauntlets"},
}

local byId: {[string]: Weapon} = {}
local byRegion: {[string]: {Weapon}} = {}
for _, weapon in Weapons do
	byId[weapon.Id] = weapon
	byRegion[weapon.Region] = byRegion[weapon.Region] or {}
	table.insert(byRegion[weapon.Region], weapon)
end

return {
	List = Weapons,
	ById = byId,
	ByRegion = byRegion,
}

