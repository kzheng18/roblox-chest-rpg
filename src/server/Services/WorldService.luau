--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Regions = require(Shared.Config.Regions)

local WorldService = {}

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addBillboard(adornee: BasePart, title: string, subtitle: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(300, 90)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = adornee
	billboard.Parent = adornee

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 18, 22)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 0.6, 0)
	label.Position = UDim2.fromOffset(8, 4)
	label.Font = Enum.Font.GothamBold
	label.Text = title
	label.TextColor3 = Color3.fromRGB(248, 238, 211)
	label.TextScaled = true
	label.Parent = frame

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -16, 0.28, 0)
	sub.Position = UDim2.new(0, 8, 0.64, 0)
	sub.Font = Enum.Font.GothamMedium
	sub.Text = subtitle
	sub.TextColor3 = Color3.fromRGB(194, 190, 181)
	sub.TextScaled = true
	sub.Parent = frame
end

local function makeChest(parent: Instance, region: any)
	local base = makePart(parent, "TreasureChest_" .. region.Id, Vector3.new(8, 3, 5), CFrame.new(region.Center + Vector3.new(0, 2, -18)), Color3.fromRGB(105, 63, 36), Enum.Material.WoodPlanks)
	local lid = makePart(parent, "TreasureChestLid_" .. region.Id, Vector3.new(8.4, 1.4, 5.4), base.CFrame * CFrame.new(0, 2.1, 0), region.Accent, Enum.Material.Metal)
	addBillboard(lid, region.Name .. " Chest", string.format("%d Gold", region.ChestCost))
end

function WorldService.Build()
	local old = Workspace:FindFirstChild("ChestRPGWorld")
	if old then old:Destroy() end

	local root = Instance.new("Folder")
	root.Name = "ChestRPGWorld"
	root.Parent = Workspace

	for index, region in Regions.List do
		local island = Instance.new("Folder")
		island.Name = region.Id
		island.Parent = root

		makePart(island, "Ground", Vector3.new(260, 6, 190), CFrame.new(region.Center + Vector3.new(0, -3, 0)), region.Accent:Lerp(Color3.fromRGB(55, 55, 58), 0.52), Enum.Material.Slate)
		local marker = makePart(island, "RegionMarker", Vector3.new(18, 1, 18), CFrame.new(region.Center + Vector3.new(0, 0.6, 0)), region.Accent, Enum.Material.Neon)
		addBillboard(marker, region.Name, if region.RequiredPower == 0 then "Starting Region" else string.format("Requires %d Power", region.RequiredPower))
		makeChest(island, region)

		for i = 1, 7 do
			local angle = (math.pi * 2) * (i / 7)
			local radius = 58 + (i % 2) * 24
			local p = region.Center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local height = 10 + (i % 3) * 4
			makePart(island, "Crystal" .. i, Vector3.new(4, height, 4), CFrame.new(p + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, angle, math.rad(8)), region.Accent, Enum.Material.Glass)
		end

		if index < #Regions.List then
			local nextRegion = Regions.List[index + 1]
			local midpoint = (region.Center + nextRegion.Center) / 2
			makePart(root, "Bridge_" .. region.Id, Vector3.new(160, 2, 18), CFrame.new(midpoint + Vector3.new(0, 1, 0)), Color3.fromRGB(88, 75, 61), Enum.Material.WoodPlanks)
		end
	end
end

return WorldService

