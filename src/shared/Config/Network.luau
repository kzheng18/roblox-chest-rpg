--!strict
return {
	ReplicationInterval = 1 / 20,
	SlowIntentMilliseconds = 12,
	Policies = {
		Train = {Window = 1, Burst = 9, Payload = "none"},
		OpenChest = {Window = 1, Burst = 4, Payload = "string"},
		UnlockRegion = {Window = 2, Burst = 4, Payload = "string"},
		TravelRegion = {Window = 1, Burst = 6, Payload = "string"},
		EquipWeapon = {Window = 1, Burst = 8, Payload = "string"},
		EquipBest = {Window = 1, Burst = 4, Payload = "none"},
		Rebirth = {Window = 2, Burst = 2, Payload = "none"},
		Setting = {Window = 1, Burst = 8, Payload = "setting"},
		RequestState = {Window = 3, Burst = 3, Payload = "none"},
	},
}

