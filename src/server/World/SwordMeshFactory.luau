--!strict
-- Trusted authored geometry only. No remote accepts vertices, content, or asset IDs.
-- Opaque content is scoped to the current server; saved source regenerates it once.
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Factory = {}
local built = false

local function buildPart(data: any): MeshPart
	local low = Vector3.new(math.huge,math.huge,math.huge)
	local high = Vector3.new(-math.huge,-math.huge,-math.huge)
	for _, v in data.vertices do
		local p = Vector3.new(v[1],v[2],v[3])
		low = low:Min(p); high = high:Max(p)
	end
	local center = (low+high)/2
	local mesh = assert(AssetService:CreateEditableMesh(), "Sword mesh memory unavailable")
	local ok, result = pcall(function()
		local vertices, normals, uvs = {}, {}, {}
		for index, v in data.vertices do
			vertices[index] = mesh:AddVertex(Vector3.new(v[1],v[2],v[3])-center)
			local n = data.normals[index]
			normals[index] = mesh:AddNormal(Vector3.new(n[1],n[2],n[3]))
			uvs[index] = mesh:AddUV(Vector2.new(v[1],v[2]))
		end
		for _, triangle in data.triangles do
			local a,b,c = triangle[1],triangle[2],triangle[3]
			local face = mesh:AddTriangle(vertices[a],vertices[b],vertices[c])
			mesh:SetFaceNormals(face,{normals[a],normals[b],normals[c]})
			mesh:SetFaceUVs(face,{uvs[a],uvs[b],uvs[c]})
		end
		local status, content = AssetService:CreateDataModelContentAsync(Content.fromObject(mesh))
		assert(status == Enum.CreateContentResult.Success, "Sword content: " .. tostring(status))
		local part = AssetService:CreateMeshPartAsync(content, {
			CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise,
		})
		part.Name = data.name
		part.Color = Color3.new(data.color[1],data.color[2],data.color[3])
		part.Material = Enum.Material[data.material]
		part.CFrame = CFrame.new(center)
		part.Anchored = true; part.Massless = true
		part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
		part:SetAttribute("TriangleCount", #data.triangles)
		return part
	end)
	mesh:Destroy()
	assert(ok, tostring(result))
	return result :: MeshPart
end

function Factory.Build(): (boolean, string?)
	local source = ServerStorage:FindFirstChild("SwordGeometry")
	if not source then return false, "SwordGeometry source missing" end
	local old = ServerStorage:FindFirstChild("WeaponModels")
	if built and old and old:GetAttribute("SwordMeshVersion") == 1 then return true end
	-- Edit-scoped opaque content cannot be reused in a new Play/server DataModel.
	-- Remove stale templates before attempting fresh content, including on failure.
	if old and old:GetAttribute("SwordMeshVersion") == 1 then old:Destroy(); old = nil end
	local bank = Instance.new("Folder")
	bank.Name = "WeaponModels"
	local ok, err = pcall(function()
		for _, folder in source:GetChildren() do
			local meta = HttpService:JSONDecode(require(folder:FindFirstChild("Metadata") :: ModuleScript))
			local model = Instance.new("Model")
			model.Name = folder.Name; model:SetAttribute("DisplayName",meta.name)
			model:SetAttribute("Rarity",meta.tier); model:SetAttribute("Exclusive",meta.tier=="Exclusive")
			model.Parent = bank
			for _, name in meta.partNames do
				local data = HttpService:JSONDecode(require(folder:FindFirstChild(name) :: ModuleScript))
				buildPart(data).Parent = model
			end
			local grip = Instance.new("Part")
			grip.Name = "GripOrigin"; grip.Size = Vector3.new(.1,.1,.1)
			grip.Transparency = 1; grip.Anchored = true; grip.Massless = true
			grip.CanCollide = false; grip.CanTouch = false; grip.CanQuery = false
			grip.CFrame = CFrame.identity; grip.Parent = model; model.PrimaryPart = grip
			model:SetAttribute("Ready",true)
		end
	end)
	if not ok then bank:Destroy(); return false,tostring(err) end
	bank:SetAttribute("SwordMeshVersion",1)
	if old then old:Destroy() end
	bank.Parent = ServerStorage
	built = true
	return true
end

return Factory
