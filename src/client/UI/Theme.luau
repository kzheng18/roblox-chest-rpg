--!strict

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromRGB(12, 14, 24),
	Backdrop = Color3.fromRGB(15, 18, 30),
	Panel = Color3.fromRGB(24, 27, 41),
	PanelRaised = Color3.fromRGB(32, 36, 53),
	PanelSoft = Color3.fromRGB(43, 47, 68),
	Border = Color3.fromRGB(8, 10, 18),
	SurfaceBorder = Color3.fromRGB(82, 90, 122),
	BorderBright = Color3.fromRGB(140, 133, 204),
	Gold = Color3.fromRGB(224, 196, 132),
	GoldSoft = Color3.fromRGB(111, 87, 67),
	Cream = Color3.fromRGB(240, 242, 251),
	Text = Color3.fromRGB(219, 224, 241),
	Muted = Color3.fromRGB(176, 185, 208),
	Faint = Color3.fromRGB(147, 156, 182),
	Green = Color3.fromRGB(121, 212, 189),
	Blue = Color3.fromRGB(127, 182, 230),
	Danger = Color3.fromRGB(226, 124, 149),
	Crimson = Color3.fromRGB(111, 56, 87),
	Success = Color3.fromRGB(104, 184, 151),
	Shadow = Color3.fromRGB(0, 0, 0),
}

Theme.Rarity = {
	Common = Color3.fromRGB(190, 193, 198),
	Uncommon = Color3.fromRGB(102, 203, 126),
	Rare = Color3.fromRGB(82, 155, 232),
	Epic = Color3.fromRGB(178, 105, 232),
	Legendary = Color3.fromRGB(239, 178, 74),
	Mythic = Color3.fromRGB(240, 85, 119),
	Divine = Color3.fromRGB(246, 222, 116),
	Celestial = Color3.fromRGB(121, 231, 228),
	Secret = Color3.fromRGB(225, 111, 241),
}

Theme.Font = {
	Display = Enum.Font.GothamBold,
	Strong = Enum.Font.GothamSemibold,
	Medium = Enum.Font.GothamMedium,
	Body = Enum.Font.Gotham,
}

Theme.Navigation = {
	Inventory = Color3.fromRGB(48, 52, 76),
	Chest = Color3.fromRGB(72, 61, 85),
	Regions = Color3.fromRGB(46, 68, 88),
	Rebirth = Color3.fromRGB(80, 52, 79),
	Settings = Color3.fromRGB(49, 55, 76),
	EquipBest = Color3.fromRGB(78, 70, 123),
}

Theme.Motion = {
	Fast = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Quick = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Panel = TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

function Theme.RarityColor(rarity: string): Color3
	return Theme.Rarity[rarity] or Theme.Colors.Text
end

return Theme
