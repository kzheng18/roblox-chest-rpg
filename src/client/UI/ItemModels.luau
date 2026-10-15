--!strict
-- Procedural display models for powers, one builder per theme ModelKind.
-- A new anime adds one builder here; the reveal and viewport code stay shared.
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

local builders: {[string]: (Color3, Color3) -> Model} = {
	Fruit = fruit,
	Grimoire = grimoire,
}

function ItemModels.Build(kind: string, primary: Color3, secondary: Color3): Model?
	local builder = builders[kind]
	return if builder then builder(primary, secondary) else nil
end

-- Shows a slowly spinning model in a ViewportFrame. Returns a cleanup function.
function ItemModels.Show(viewport: ViewportFrame, kind: string, primary: Color3, secondary: Color3, glow: Color3): () -> ()
	viewport:ClearAllChildren()
	local model = ItemModels.Build(kind, primary, secondary)
	if not model then return function() end end
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, 7.4), Vector3.new(0, 0.1, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Ambient = Color3.fromRGB(150, 150, 165)
	viewport.LightColor = glow
	viewport.LightDirection = Vector3.new(-0.6, -1, -0.8)
	local pivot = model:GetPivot()
	local angle = 0
	local connection = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Visible then return end
		angle += dt * 1.4
		model:PivotTo(pivot * CFrame.Angles(0, angle, math.sin(angle * 0.7) * 0.12))
	end)
	return function()
		connection:Disconnect()
		viewport:ClearAllChildren()
	end
end

return ItemModels
