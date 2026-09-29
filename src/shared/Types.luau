--!strict
export type Settings = {
	RollAnimation: boolean,
	ReducedMotion: boolean,
	Volume: number,
}

export type PlayerData = {
	Version: number,
	Revision: number,
	Power: number,
	Gold: number,
	Rebirths: number,
	OwnedWeapons: {[string]: number},
	EquippedWeapon: string,
	UnlockedRegions: {[string]: boolean},
	CurrentRegion: string,
	Settings: Settings,
}

return {}
