--!strict
-- Anime-inspired power catalog. Every theme (one per anime update) owns one
-- equip slot. Equipped powers from different themes multiply together, so a
-- player with a Fruit and a Grimoire equipped gets both bonuses.
--
-- Naming rule: original names only. No character, attack, item or franchise
-- names from the source anime. See docs/ANIME_POWERS_SHOWCASE.md.

export type Theme = {
	Id: string,
	Name: string, -- player-facing theme name
	SlotName: string, -- what one item of this theme is called
	ModelKind: string, -- client model builder key (see client UI/ItemModels)
	Accent: Color3,
	Order: number,
}

export type Power = {
	Id: string,
	Name: string,
	Theme: string,
	Region: string,
	Rarity: string,
	-- Relative weight inside the region's power pool. Final odds are
	-- DropChance[region] * effectiveWeight / totalEffectiveWeight.
	Weight: number,
	-- Luck raises effective weight: Weight * luck ^ LuckExponent.
	LuckExponent: number,
	PowerMultiplier: number,
	Primary: Color3,
	Secondary: Color3,
}

local Themes: {Theme} = {
	{
		-- Inspired by a pirate adventure anime with power-granting fruits.
		Id = "pirate", Name = "Pirate Era", SlotName = "Cursed Fruit", ModelKind = "Fruit",
		Accent = Color3.fromRGB(235, 120, 72), Order = 1,
	},
	{
		-- Inspired by a magic-knight anime where each mage carries a grimoire.
		Id = "mage", Name = "Mage Kingdom", SlotName = "Grimoire", ModelKind = "Grimoire",
		Accent = Color3.fromRGB(120, 196, 140), Order = 2,
	},
}

-- Chance that a chest opening also grants a power, per region. The weapon
-- roll is unchanged; the power is an independent bonus roll.
local DropChance: {[string]: number} = {
	verdant = 0.12,
	frostfall = 0.14,
	emberreach = 0.16,
}

-- Curves intentionally differ by theme: Fruits start stronger, Grimoires
-- start weaker but peak higher. Both stack.
local Powers: {Power} = {
	-- Verdant Crossroads
	{Id="pirate_rubber", Name="Rubber Fruit", Theme="pirate", Region="verdant", Rarity="Common", Weight=600, LuckExponent=0, PowerMultiplier=1.40,
		Primary=Color3.fromRGB(176, 92, 196), Secondary=Color3.fromRGB(110, 48, 132)},
	{Id="pirate_smoke", Name="Smoke Fruit", Theme="pirate", Region="verdant", Rarity="Rare", Weight=50, LuckExponent=0.45, PowerMultiplier=2.20,
		Primary=Color3.fromRGB(196, 200, 208), Secondary=Color3.fromRGB(120, 126, 138)},
	{Id="mage_gale", Name="Gale Grimoire", Theme="mage", Region="verdant", Rarity="Common", Weight=600, LuckExponent=0, PowerMultiplier=1.25,
		Primary=Color3.fromRGB(92, 168, 112), Secondary=Color3.fromRGB(214, 232, 196)},
	{Id="mage_thorn", Name="Thorn Grimoire", Theme="mage", Region="verdant", Rarity="Rare", Weight=50, LuckExponent=0.45, PowerMultiplier=2.00,
		Primary=Color3.fromRGB(58, 104, 62), Secondary=Color3.fromRGB(188, 64, 82)},

	-- Frostfall Kingdom
	{Id="pirate_sand", Name="Sand Fruit", Theme="pirate", Region="frostfall", Rarity="Uncommon", Weight=500, LuckExponent=0.30, PowerMultiplier=2.60,
		Primary=Color3.fromRGB(222, 186, 116), Secondary=Color3.fromRGB(160, 120, 64)},
	{Id="pirate_frost", Name="Frost Fruit", Theme="pirate", Region="frostfall", Rarity="Epic", Weight=30, LuckExponent=0.60, PowerMultiplier=5.00,
		Primary=Color3.fromRGB(150, 214, 255), Secondary=Color3.fromRGB(70, 132, 210)},
	{Id="mage_rime", Name="Rime Grimoire", Theme="mage", Region="frostfall", Rarity="Uncommon", Weight=500, LuckExponent=0.30, PowerMultiplier=2.20,
		Primary=Color3.fromRGB(110, 160, 214), Secondary=Color3.fromRGB(226, 240, 252)},
	{Id="mage_mirror", Name="Mirror Grimoire", Theme="mage", Region="frostfall", Rarity="Legendary", Weight=6, LuckExponent=0.75, PowerMultiplier=7.50,
		Primary=Color3.fromRGB(200, 212, 230), Secondary=Color3.fromRGB(140, 120, 220)},

	-- Emberreach Dominion
	{Id="pirate_flame", Name="Flame Fruit", Theme="pirate", Region="emberreach", Rarity="Rare", Weight=400, LuckExponent=0.45, PowerMultiplier=6.00,
		Primary=Color3.fromRGB(255, 120, 48), Secondary=Color3.fromRGB(200, 40, 32)},
	{Id="pirate_radiance", Name="Radiance Fruit", Theme="pirate", Region="emberreach", Rarity="Mythic", Weight=2, LuckExponent=0.90, PowerMultiplier=15.00,
		Primary=Color3.fromRGB(255, 236, 140), Secondary=Color3.fromRGB(255, 196, 64)},
	{Id="mage_ember", Name="Ember Grimoire", Theme="mage", Region="emberreach", Rarity="Rare", Weight=400, LuckExponent=0.45, PowerMultiplier=5.00,
		Primary=Color3.fromRGB(150, 44, 40), Secondary=Color3.fromRGB(255, 150, 70)},
	{Id="mage_void", Name="Void Grimoire", Theme="mage", Region="emberreach", Rarity="Mythic", Weight=1, LuckExponent=0.90, PowerMultiplier=20.00,
		Primary=Color3.fromRGB(28, 22, 36), Secondary=Color3.fromRGB(196, 60, 90)},
}

local themeById: {[string]: Theme} = {}
for _, theme in Themes do
	themeById[theme.Id] = theme
end
local byId: {[string]: Power} = {}
local byRegion: {[string]: {Power}} = {}
for _, power in Powers do
	assert(themeById[power.Theme], "Power has unknown theme: " .. power.Id)
	assert(byId[power.Id] == nil, "Duplicate power id: " .. power.Id)
	byId[power.Id] = power
	byRegion[power.Region] = byRegion[power.Region] or {}
	table.insert(byRegion[power.Region], power)
end

return {
	Themes = Themes,
	ThemeById = themeById,
	List = Powers,
	ById = byId,
	ByRegion = byRegion,
	DropChance = DropChance,
}
