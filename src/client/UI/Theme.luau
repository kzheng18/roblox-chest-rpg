--!strict

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromRGB(15, 15, 20),
	Backdrop = Color3.fromRGB(18, 18, 24),
	Panel = Color3.fromRGB(28, 27, 34),
	PanelRaised = Color3.fromRGB(38, 36, 44),
	PanelSoft = Color3.fromRGB(47, 44, 52),
	Border = Color3.fromRGB(108, 94, 74),
	BorderBright = Color3.fromRGB(156, 127, 76),
	Gold = Color3.fromRGB(237, 194, 92),
	GoldSoft = Color3.fromRGB(166, 132, 67),
	Cream = Color3.fromRGB(246, 238, 216),
	Text = Color3.fromRGB(232, 228, 218),
	Muted = Color3.fromRGB(166, 161, 154),
	Faint = Color3.fromRGB(113, 110, 112),
	Green = Color3.fromRGB(96, 197, 126),
	Blue = Color3.fromRGB(102, 174, 231),
	Danger = Color3.fromRGB(221, 91, 91),
	Success = Color3.fromRGB(96, 197, 126),
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
	Display = Enum.Font.GothamBlack,
	Strong = Enum.Font.GothamBold,
	Medium = Enum.Font.GothamMedium,
	Body = Enum.Font.Gotham,
}

Theme.Motion = {
	Fast = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Quick = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Panel = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

function Theme.RarityColor(rarity: string): Color3
	return Theme.Rarity[rarity] or Theme.Colors.Text
end

return Theme
