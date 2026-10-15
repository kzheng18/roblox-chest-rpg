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
	LastChestReceipt: {Sequence: number, Region: string, Id: string, RateN: number, Revision: number?}?,
	Power: number,
	Gold: number,
	Luck: number,
	Rebirths: number,
	OwnedWeapons: {[string]: number},
	EquippedWeapon: string,
	UnlockedRegions: {[string]: boolean},
	CurrentRegion: string,
	Settings: Settings,
}

return {}
