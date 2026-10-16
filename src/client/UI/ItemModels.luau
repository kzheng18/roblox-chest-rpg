--!strict
-- Procedural display models for every reveal: one builder per power theme
-- ModelKind and per weapon Family. A new anime adds one builder here; the
-- shared turntable (ItemModels.Stage) and reveal code stay the same.
local RunService = game:GetService("RunService")

local ItemModels = {}

local function part(model: Model, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A swirled fruit: body sphere, spiral of raised swirl beads, stem and leaf.
local function fruit(primary: Color3, secondary: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Fruit"
	local body = part(model, Enum.PartType.Ball, Vector3.new(3, 3, 3), CFrame.new(), primary)
	model.PrimaryPart = body
	for ring = 0, 2 do
		for i = 0, 13 do
			local t = i / 14
			local angle = t * math.pi * 2 + ring * (math.pi * 2 / 3)
			local height = (t - 0.5) * 2.2
			local radius = math.sqrt(math.max(0, 1.5 ^ 2 - height ^ 2)) * 0.98
			local position = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
			part(model, Enum.PartType.Ball, Vector3.new(0.42, 0.42, 0.42), CFrame.new(position), secondary)
		end
	end
	part(model, Enum.PartType.Cylinder, Vector3.new(0.7, 0.22, 0.22), CFrame.new(0, 1.75, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(96, 64, 40))
	part(model, Enum.PartType.Block, Vector3.new(0.9, 0.08, 0.5), CFrame.new(0.45, 1.95, 0) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(86, 160, 72))
	return model
end

-- A closed spellbook: cover, page block, spine and a faceted gem emblem.
local function grimoire(primary: Color3, secondary: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Grimoire"
	local cover = part(model, nil, Vector3.new(2.4, 3.2, 0.12), CFrame.new(0, 0, 0.36), primary, Enum.Material.Fabric)
	part(model, nil, Vector3.new(2.4, 3.2, 0.12), CFrame.new(0, 0, -0.36), primary, Enum.Material.Fabric)
	part(model, nil, Vector3.new(2.25, 3.0, 0.62), CFrame.new(0.06, 0, 0), Color3.fromRGB(236, 226, 200))
	part(model, nil, Vector3.new(0.2, 3.24, 0.84), CFrame.new(-1.2, 0, 0), secondary, Enum.Material.Metal)
	for _, y in {1.45, -1.45} do
		part(model, nil, Vector3.new(0.5, 0.18, 0.86), CFrame.new(0.98, y, 0), secondary, Enum.Material.Metal)
	end
	local gem = part(model, nil, Vector3.new(0.7, 0.7, 0.2), CFrame.new(0, 0.2, 0.47) * CFrame.Angles(0, 0, math.rad(45)), secondary, Enum.Material.Neon)
	gem.Transparency = 0.05
	part(model, nil, Vector3.new(1.5, 0.08, 0.04), CFrame.new(0, -0.75, 0.43), secondary, Enum.Material.Metal)
	model.PrimaryPart = cover
	return model
end

local GRIP = Color3.fromRGB(70, 46, 34)

-- Weapon builders, keyed by weapon Family. Primary = metal, Secondary = accent.
local function blade(model: Model, length: number, width: number, primary: Color3, secondary: Color3)
	local half = length / 2
	part(model, nil, Vector3.new(width, length, 0.16), CFrame.new(0, 0.6 + half - 0.6, 0), primary, Enum.Material.Metal)
	part(model, nil, Vector3.new(width * 0.7, width * 0.7, 0.14), CFrame.new(0, 0.6 + length - 0.55, 0) * CFrame.Angles(0, 0, math.rad(45)), primary, Enum.Material.Metal)
	part(model, nil, Vector3.new(width * 0.18, length * 0.8, 0.18), CFrame.new(0, 0.6 + half - 0.7, 0), secondary, Enum.Material.Neon)
end
local function hilt(model: Model, guard: number, grip: number, secondary: Color3)
	part(model, nil, Vector3.new(guard, 0.24, 0.34), CFrame.new(0, 0.1, 0), secondary, Enum.Material.Metal)
	part(model, Enum.PartType.Cylinder, Vector3.new(grip, 0.24, 0.24), CFrame.new(0, -grip / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), GRIP, Enum.Material.Fabric)
	part(model, Enum.PartType.Ball, Vector3.new(0.38, 0.38, 0.38), CFrame.new(0, -grip - 0.1, 0), secondary, Enum.Material.Metal)
end
local function sword(primary: Color3, secondary: Color3): Model
	local model = Instance.new("Model"); model.Name = "Sword"
	blade(model, 3.0, 0.42, primary, secondary)
	hilt(model, 1.3, 0.9, secondary)
	return model
end
local function greatsword(primary: Color3, secondary: Color3): Model
	local model = Instance.new("Model"); model.Name = "Greatsword"
	blade(model, 3.2, 0.78, primary, secondary)
	hilt(model, 1.8, 1.1, secondary)
	return model
end
local function spear(primary: Color3, secondary: Color3): Model
	local model = Instance.new("Model"); model.Name = "Spear"
	part(model, Enum.PartType.Cylinder, Vector3.new(4.6, 0.2, 0.2), CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), GRIP, Enum.Material.Wood)
	part(model, nil, Vector3.new(0.5, 0.9, 0.12), CFrame.new(0, 2.35, 0), primary, Enum.Material.Metal)
	part(model, nil, Vector3.new(0.36, 0.36, 0.1), CFrame.new(0, 2.85, 0) * CFrame.Angles(0, 0, math.rad(45)), primary, Enum.Material.Metal)
	part(model, nil, Vector3.new(0.6, 0.16, 0.26), CFrame.new(0, 1.85, 0), secondary, Enum.Material.Neon)
	return model
end
local function bow(primary: Color3, secondary: Color3): Model
	local model = Instance.new("Model"); model.Name = "Bow"
	for i = -4, 4 do
		local y = i * 0.5
		local x = -0.9 * math.cos(i / 4 * math.pi / 2.4)
		part(model, nil, Vector3.new(0.24, 0.56, 0.24), CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(-i * 7)), if i == 0 then GRIP else primary, Enum.Material.Wood)
	end
	part(model, nil, Vector3.new(0.04, 4.2, 0.04), CFrame.new(-0.1, 0, 0), Color3.fromRGB(235, 230, 215))
	part(model, Enum.PartType.Ball, Vector3.new(0.34, 0.34, 0.34), CFrame.new(-0.9, 0, 0.12), secondary, Enum.Material.Neon)
	return model
end
local function gauntlets(primary: Color3, secondary: Color3): Model
	local model = Instance.new("Model"); model.Name = "Gauntlets"
	for _, x in {-0.85, 0.85} do
		part(model, nil, Vector3.new(1.0, 1.5, 1.0), CFrame.new(x, -0.4, 0), primary, Enum.Material.Metal)
		part(model, nil, Vector3.new(1.15, 0.8, 1.15), CFrame.new(x, 0.75, 0), primary, Enum.Material.Metal)
		part(model, nil, Vector3.new(1.2, 0.2, 0.3), CFrame.new(x, 0.75, 0.5), secondary, Enum.Material.Neon)
	end
	return model
end

local builders: {[string]: (Color3, Color3) -> Model} = {
	-- Powers (one per anime theme ModelKind)
	Fruit = fruit,
	Grimoire = grimoire,
	-- Weapons (one per weapon Family)
	Sword = sword,
	Greatsword = greatsword,
	Spear = spear,
	Bow = bow,
	Gauntlets = gauntlets,
}

-- Largest dimension (studs) any model may have inside the shared frame.
local FIT_SIZE = 4.6

export type Spec = {Kind: string, Primary: Color3, Secondary: Color3, Glow: Color3}

function ItemModels.Build(kind: string, primary: Color3, secondary: Color3): Model?
	local builder = builders[kind]
	if not builder then return nil end
	local model = builder(primary, secondary)
	-- Fit every model into the same frame: centre its bounds on the spin
	-- axis and scale down anything taller or wider than the fruit/book.
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local extent = d.Size.Magnitude / 2
			low = low:Min(d.Position - Vector3.one * extent)
			high = high:Max(d.Position + Vector3.one * extent)
		end
	end
	model.WorldPivot = CFrame.new((low + high) / 2)
	local size = high - low
	local largest = math.max(size.X, size.Y, size.Z)
	if largest > FIT_SIZE then model:ScaleTo(FIT_SIZE / largest) end
	return model
end

-- The one shared turntable for every reveal. Items swap inside it while the
-- camera, lighting and spin keep going, so all reveals look and move the same.
export type Stage = {
	Set: (Stage, Spec?, boolean?) -> (),
	Destroy: (Stage) -> (),
}

local SPIN_SPEED = 1.4
local SILHOUETTE = Color3.fromRGB(14, 16, 26)

function ItemModels.Stage(viewport: ViewportFrame): Stage
	viewport:ClearAllChildren()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, 7.4), Vector3.new(0, 0.1, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Ambient = Color3.fromRGB(150, 150, 165)
	viewport.LightDirection = Vector3.new(-0.6, -1, -0.8)
	local current: Model? = nil
	local angle = 0
	local function pose(model: Model)
		model:PivotTo(CFrame.Angles(0, angle, math.sin(angle * 0.7) * 0.12))
	end
	local connection = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Visible then return end
		angle += dt * SPIN_SPEED
		if current then pose(current) end
	end)
	local stage = {} :: any
	-- silhouette=true hides the item's colors (suspense before a rare reveal).
	function stage.Set(_self: Stage, spec: Spec?, silhouette: boolean?)
		if current then current:Destroy(); current = nil end
		if not spec then return end
		local model = ItemModels.Build(spec.Kind, spec.Primary, spec.Secondary)
		if not model then return end
		if silhouette then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then d.Color = SILHOUETTE; d.Material = Enum.Material.SmoothPlastic end
			end
		end
		viewport.LightColor = if silhouette then Color3.new(0, 0, 0) else spec.Glow
		pose(model)
		model.Parent = viewport
		current = model
	end
	function stage.Destroy(_self: Stage)
		connection:Disconnect()
		viewport:ClearAllChildren()
		current = nil
	end
	return stage :: Stage
end

return ItemModels
