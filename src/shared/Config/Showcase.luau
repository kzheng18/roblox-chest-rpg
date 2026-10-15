--!strict
-- How rare pulls are shown off: reveal tiers and announcement thresholds.
return {
	-- Rarity -> reveal tier. Quick: normal reveal. Glow: color flash on settle.
	-- Cinematic: darkened screen, camera push to the chest, burst, then reveal.
	RevealTier = {
		Common = "Quick", Uncommon = "Quick",
		Rare = "Glow", Epic = "Glow",
		Legendary = "Cinematic", Mythic = "Cinematic",
		Divine = "Cinematic", Celestial = "Cinematic", Secret = "Cinematic",
	},
	-- Hard caps (seconds). Every reveal stays skippable.
	QuickRollSeconds = 1.0,
	CinematicSeconds = 3.0,
	-- Announce to the whole server at or above this rarity, or this rarity odds.
	ServerRarities = {Legendary = true, Mythic = true, Divine = true, Celestial = true, Secret = true},
	ServerMinRateN = 1_000,
	-- Announce to every server for the rarest pulls.
	GlobalRarities = {Mythic = true, Divine = true, Celestial = true, Secret = true},
	GlobalMinRateN = 5_000,
	GlobalTopic = "ChestRPG_RarePull_v1",
	-- Outgoing cross-server publishes per server, to respect MessagingService limits.
	GlobalPublishInterval = 2,
}
