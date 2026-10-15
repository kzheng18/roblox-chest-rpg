--!strict
export type Settings = {
	RollAnimation: boolean,
	ReducedMotion: boolean,
	Volume: number,
	EffectsQuality: string,
}

export type PlayerData = {
	Version: number,
	Revision: number,
	OwnerUserId: number,
	ChestSequence: number,
	LastChestReceipt: {Sequence: number, Region: string, Id: string, RateN: number, Revision: number?, PowerId: string?, PowerRateN: number?}?,
	Power: number,
	Gold: number,
	Luck: number,
	Rebirths: number,
	OwnedWeapons: {[string]: number},
	EquippedWeapon: string,
	OwnedPowers: {[string]: number},
	-- Theme id -> equipped power id. One slot per anime theme; slots stack.
	EquippedPowers: {[string]: string},
	UnlockedRegions: {[string]: boolean},
	CurrentRegion: string,
	Settings: Settings,
}

return {}
