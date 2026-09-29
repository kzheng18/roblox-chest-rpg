--!strict
export type Region = {
	Id: string,
	Name: string,
	RequiredPower: number,
	ChestCost: number,
	Center: Vector3,
	Accent: Color3,
}

local Regions: {Region} = {
	{
		Id = "verdant",
		Name = "Verdant Crossroads",
		RequiredPower = 0,
		ChestCost = 25,
		Center = Vector3.new(0, 0, 0),
		Accent = Color3.fromRGB(85, 181, 111),
	},
	{
		Id = "frostfall",
		Name = "Frostfall Kingdom",
		RequiredPower = 2_500,
		ChestCost = 250,
		Center = Vector3.new(420, 0, 0),
		Accent = Color3.fromRGB(117, 197, 255),
	},
	{
		Id = "emberreach",
		Name = "Emberreach Dominion",
		RequiredPower = 12_000,
		ChestCost = 1_250,
		Center = Vector3.new(840, 0, 0),
		Accent = Color3.fromRGB(255, 126, 73),
	},
}

local byId: {[string]: Region} = {}
for _, region in Regions do
	byId[region.Id] = region
end

return {
	List = Regions,
	ById = byId,
}

