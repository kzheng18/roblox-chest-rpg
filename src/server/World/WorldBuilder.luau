--!strict
-- Geometry only: the same builder runs in Edit and Play.
local Shared = game:GetService("ReplicatedStorage").Shared
local Regions = require(Shared.Config.Regions)
local Layout = require(Shared.Config.WorldLayout)
local Builder = {}
local stone = Color3.fromRGB(144, 142, 125)
local pale = Color3.fromRGB(222, 211, 174)
local wood = Color3.fromRGB(88, 62, 43)
local gold = Color3.fromRGB(201, 162, 73)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf
	p.Anchored = true; p.Color = color; p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m
end

local function label(p: BasePart, title: string, subtitle: string, color: Color3, distance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StationLabel"; gui.Size = UDim2.fromOffset(190, 54)
	gui.StudsOffset = Vector3.new(0, 3, 0); gui.MaxDistance = distance or 80
	gui.AlwaysOnTop = false; gui.Parent = p
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = Color3.fromRGB(29, 36, 34)
	bg.BackgroundTransparency = 0.12; bg.BorderSizePixel = 0; bg.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = bg
	local stroke = Instance.new("UIStroke"); stroke.Color = color; stroke.Thickness = 1; stroke.Parent = bg
	for i, text in {title, subtitle} do
		local t = Instance.new("TextLabel")
		t.Name = if i == 1 then "Title" else "Detail"
		t.BackgroundTransparency = 1; t.Text = text
		t.Position = UDim2.fromOffset(6, if i == 1 then 5 else 30)
		t.Size = UDim2.new(1, -12, 0, if i == 1 then 22 else 18)
		t.Font = if i == 1 then Enum.Font.GothamBold else Enum.Font.GothamMedium
		t.TextSize = if i == 1 then 16 else 11
		t.TextColor3 = if i == 1 then pale else Color3.fromRGB(203, 209, 195)
		t.Parent = bg
	end
end

local function disc(parent: Instance, name: string, center: Vector3, radius: number, thickness: number, color: Color3, material: Enum.Material): Part
	local p = part(parent, name, Vector3.new(thickness, radius * 2, radius * 2), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function marker(parent: Instance, name: string, position: Vector3): Part
	local p = part(parent, name, Vector3.new(2, 1, 2), CFrame.new(position), pale, Enum.Material.SmoothPlastic)
	p.Transparency = 1; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	return p
end

local function lantern(parent: Instance, position: Vector3)
	part(parent, "LampPost", Vector3.new(0.7, 8, 0.7), CFrame.new(position + Vector3.new(0, 4, 0)), wood, Enum.Material.Wood)
	part(parent, "LampCap", Vector3.new(2.5, 0.5, 2.5), CFrame.new(position + Vector3.new(0, 9, 0)), wood, Enum.Material.Wood)
	local glass = part(parent, "Lantern", Vector3.new(1.4, 1.8, 1.4), CFrame.new(position + Vector3.new(0, 7.9, 0)), Color3.fromRGB(255, 210, 129), Enum.Material.Neon)
	glass.CanCollide = false
	local light = Instance.new("PointLight"); light.Color = glass.Color; light.Brightness = 0.7; light.Range = 15; light.Parent = glass
end

local function stall(parent: Instance, position: Vector3, name: string, title: string, accent: Color3)
	local m = group(parent, name); m:SetAttribute("StationId", name); m:SetAttribute("Implementation", "Layout only")
	part(m, "Paving", Vector3.new(34, 0.35, 29), CFrame.new(position + Vector3.new(0, 0.175, 0)), stone, Enum.Material.Cobblestone)
	for _, x in {-13, 13} do
		for _, z in {-10, 10} do
			part(m, "TimberPillar", Vector3.new(1.3, 13, 1.3), CFrame.new(position + Vector3.new(x, 6.5, z)), wood, Enum.Material.Wood)
		end
	end
	for _, side in {-1, 1} do
		part(m, "Roof", Vector3.new(17, 1, 27), CFrame.new(position + Vector3.new(side * 7.7, 14.2, 0)) * CFrame.Angles(0, 0, -side * math.rad(17)), accent, Enum.Material.Slate)
	end
	part(m, "BackWall", Vector3.new(27, 7, 1.2), CFrame.new(position + Vector3.new(0, 3.9, -10)), pale, Enum.Material.Plaster)
	local counter = part(m, "Counter", Vector3.new(23, 3.8, 4.5), CFrame.new(position + Vector3.new(0, 2.1, 6)), wood, Enum.Material.WoodPlanks)
	part(m, "CounterTop", Vector3.new(25, 0.5, 5.5), counter.CFrame + Vector3.new(0, 2.1, 0), pale, Enum.Material.Sandstone)
	label(counter, title, "Coming soon", accent, 80)
	local stationLabel = counter:FindFirstChild("StationLabel") :: BillboardGui
	stationLabel.StudsOffset = Vector3.new(0, 5, 0)
	if name == "SellEquipment" then
		for i = 1, 3 do
			part(m, "GoodsCrate", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(-7 + i * 4, 2.4, -5)), wood:Lerp(pale, i * 0.08), Enum.Material.WoodPlanks)
		end
		for i = 1, 4 do disc(m, "CoinDisplay", position + Vector3.new(-4 + i * 2, 4.6, 6), 0.8, 0.22, gold, Enum.Material.Metal) end
	else
		part(m, "Forge", Vector3.new(7, 5, 6), CFrame.new(position + Vector3.new(-6, 2.8, -5)), stone, Enum.Material.Slate)
		local fire = part(m, "ForgeGlow", Vector3.new(4, 2, 0.1), CFrame.new(position + Vector3.new(-6, 2, -1.95)), Color3.fromRGB(237, 145, 69), Enum.Material.Neon)
		fire.CanCollide = false
		part(m, "AnvilBase", Vector3.new(3, 3, 3), CFrame.new(position + Vector3.new(6, 1.9, -4)), wood, Enum.Material.Wood)
		part(m, "Anvil", Vector3.new(6, 1.5, 2.5), CFrame.new(position + Vector3.new(6, 4, -4)), Color3.fromRGB(66, 71, 77), Enum.Material.Metal)
	end
	lantern(m, position + Vector3.new(-18, 0, 12))
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): WedgePart
    local p = Instance.new("WedgePart")
    p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = material
    p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.Parent = parent
    return p
end

local function ornament(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
    local p = part(parent, name, size, cf, color, material)
    p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
    return p
end

local function orb(parent: Instance, name: string, position: Vector3, size: Vector3, color: Color3, material: Enum.Material): Part
    local p = ornament(parent, name, size, CFrame.new(position), color, material)
    local mesh = Instance.new("SpecialMesh")
    mesh.Name = "OrganicForm"; mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
    return p
end

local function glow(p: BasePart, range: number)
    local light = Instance.new("PointLight")
    light.Color = p.Color; light.Range = range; light.Brightness = 0.55; light.Parent = p
end

local function crystal(parent: Instance, position: Vector3, height: number, color: Color3)
    local m = group(parent, "IceCrystal")
    for i, side in {-1, 1} do
        local p = wedge(m, "CrystalFacet", Vector3.new(height * 0.24, height, height * 0.35),
            CFrame.new(position + Vector3.new(side * height * 0.1, height * 0.48, 0)) * CFrame.Angles(0, i * math.pi, math.rad(side * 9)), color, Enum.Material.Ice)
        p.Transparency = 0.12
    end
    local core = ornament(m, "CrystalHeart", Vector3.new(0.45, height * 0.7, 0.45), CFrame.new(position + Vector3.new(0, height * 0.5, 0)), Color3.fromRGB(157, 231, 243), Enum.Material.Neon)
    glow(core, 9)
end

local function leafyTree(parent: Instance, position: Vector3, height: number, ancient: boolean?)
    local m = group(parent, if ancient then "AncientOak" else "WoodlandTree")
    local trunkWidth = if ancient then 5.5 else 2.4
    part(m, "Trunk", Vector3.new(trunkWidth, height, trunkWidth), CFrame.new(position + Vector3.new(0, height / 2, 0)), wood, Enum.Material.Wood)
    local crown = if ancient then 30 else 15
    for i = 1, 5 do
        local angle = i * math.pi * 2 / 5
        local offset = Vector3.new(math.cos(angle) * crown * 0.25, height - 2 + i % 2 * 3, math.sin(angle) * crown * 0.25)
        orb(m, "LeafCrown", position + offset, Vector3.new(crown * 0.75, crown * 0.6, crown * 0.75),
            Color3.fromRGB(59 + i * 4, 112 + i * 5, 68 + i * 2), Enum.Material.Grass)
    end
    if ancient then
        for _, side in {-1, 1} do
            wedge(m, "ButtressRoot", Vector3.new(6, 5, 9), CFrame.new(position + Vector3.new(side * 4, 2, 0)) * CFrame.Angles(0, side * math.pi / 2, 0), wood, Enum.Material.Wood)
            ornament(m, "HangingVine", Vector3.new(0.3, 12, 0.3), CFrame.new(position + Vector3.new(side * 9, height - 8, 3)), Color3.fromRGB(68, 133, 72), Enum.Material.Grass)
        end
    end
end

local function pine(parent: Instance, position: Vector3, height: number)
    local m = group(parent, "SnowPine")
    part(m, "PineTrunk", Vector3.new(1.6, height * 0.65, 1.6), CFrame.new(position + Vector3.new(0, height * 0.325, 0)), wood, Enum.Material.Wood)
    for layer = 1, 3 do
        local width = 17 - layer * 3
        local y = height * 0.3 + (layer - 1) * 4
        for _, rotation in {0, math.pi} do
            wedge(m, "NeedleBough", Vector3.new(width, 7, width / 2), CFrame.new(position + Vector3.new(0, y, if rotation == 0 then -width / 4 else width / 4)) * CFrame.Angles(0, rotation, 0), Color3.fromRGB(46, 81, 88), Enum.Material.Grass)
            wedge(m, "SnowBough", Vector3.new(width * 0.92, 6.6, width / 2), CFrame.new(position + Vector3.new(0, y + 0.45, if rotation == 0 then -width / 4 else width / 4)) * CFrame.Angles(0, rotation, 0), Color3.fromRGB(227, 237, 234), Enum.Material.Snow)
        end
    end
end

local function flowers(parent: Instance, position: Vector3, seed: number)
    local m = group(parent, "Wildflowers")
    for i = 1, 3 do
        local pos = position + Vector3.new(i * 1.5, 0, i % 2 * 1.4)
        ornament(m, "Stem", Vector3.new(0.15, 1.8, 0.15), CFrame.new(pos + Vector3.new(0, 0.9, 0)), Color3.fromRGB(77, 130, 56), Enum.Material.Grass)
        local color = if seed % 2 == 0 then Color3.fromRGB(211, 171, 88) else Color3.fromRGB(168, 117, 184)
        for j = 1, 4 do
            local angle = j * math.pi / 2
            orb(m, "Petal", pos + Vector3.new(math.cos(angle) * 0.45, 1.8, math.sin(angle) * 0.45), Vector3.new(0.8, 0.25, 0.8), color, Enum.Material.SmoothPlastic)
        end
    end
end

local function arch(parent: Instance, position: Vector3, name: string, accent: Color3, width: number, theme: string?): Part
    local m = group(parent, name)
    local dark = if theme == "emberreach" then Color3.fromRGB(53, 48, 52) elseif theme == "frostfall" then Color3.fromRGB(126, 157, 176) else stone
    for _, x in {-width / 2, width / 2} do
        part(m, "Footing", Vector3.new(6, 2, 7), CFrame.new(position + Vector3.new(x, 1, 0)), dark, Enum.Material.Rock)
        part(m, "Pillar", Vector3.new(3.5, 15, 4), CFrame.new(position + Vector3.new(x, 7.5, 0)), dark, if theme == "emberreach" then Enum.Material.Slate else Enum.Material.Cobblestone)
        ornament(m, "Banner", Vector3.new(2.7, 7, 0.25), CFrame.new(position + Vector3.new(x, 10, 2.2)), accent, Enum.Material.Fabric)
        if theme == "frostfall" then
            crystal(m, position + Vector3.new(x, 15, 0), 5.5, Color3.fromRGB(172, 223, 238))
            part(m, "SnowCap", Vector3.new(6, 0.6, 7), CFrame.new(position + Vector3.new(x, 2.2, 0)), Color3.fromRGB(234, 242, 241), Enum.Material.Snow)
        elseif theme == "emberreach" then
            local rune = ornament(m, "MoltenRune", Vector3.new(0.5, 9, 0.2), CFrame.new(position + Vector3.new(x, 7, 2.3)), accent, Enum.Material.Neon)
            glow(rune, 8)
            wedge(m, "ObsidianHorn", Vector3.new(3, 8, 4), CFrame.new(position + Vector3.new(x, 18, 0)) * CFrame.Angles(0, 0, math.rad(if x < 0 then 15 else -15)), dark, Enum.Material.Slate)
        else
            ornament(m, "MossBand", Vector3.new(4.2, 1.3, 4.3), CFrame.new(position + Vector3.new(x, 12, 0)), Color3.fromRGB(82, 132, 65), Enum.Material.Grass)
        end
    end
    local lintel = part(m, "Lintel", Vector3.new(width + 7, 3, 5), CFrame.new(position + Vector3.new(0, 16, 0)), dark, Enum.Material.Cobblestone)
    if theme == "frostfall" then
        ornament(m, "SnowLintel", Vector3.new(width + 8, 0.8, 6), lintel.CFrame + Vector3.new(0, 1.8, 0), Color3.fromRGB(236, 245, 244), Enum.Material.Snow)
    end
    return lintel
end

local function portal(parent: Instance, position: Vector3, target: any, name: string)
    local lintel = arch(parent, position, name, target.Accent, 30, target.Id)
    label(lintel, target.Name, tostring(target.RequiredPower) .. " Power", target.Accent, 100)
    local trigger = marker(lintel.Parent, "TravelPoint", position + Vector3.new(0, 3, 0))
    trigger:SetAttribute("TargetRegion", target.Id)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "RegionTravel"; prompt.ActionText = "Travel / unlock"; prompt.ObjectText = target.Name
    prompt.MaxActivationDistance = 12; prompt.RequiresLineOfSight = false; prompt.Parent = trigger
    part(lintel.Parent, "GatewayThreshold", Vector3.new(28, 0.3, 8), CFrame.new(position + Vector3.new(0, 0.15, 0)), target.Accent:Lerp(stone, 0.55), Enum.Material.Cobblestone)
end

local function regionChest(island: Model, field: Model, region: any, spec: any)
    local pos = region.Center + spec.Chest
    local frost = region.Id == "frostfall"; local ember = region.Id == "emberreach"
    local casing = if frost then Color3.fromRGB(170, 204, 218) elseif ember then Color3.fromRGB(48, 45, 49) else wood
    local trim = if frost then Color3.fromRGB(91, 158, 196) elseif ember then Color3.fromRGB(175, 101, 59) else gold
    local title = if frost then "GLACIER RELIQUARY" elseif ember then "CINDER VAULT" else "GROVEKEEPER CACHE"
    disc(field, "ChestBorder", Vector3.new(pos.X, 0.18, pos.Z), 14, 0.36, casing:Lerp(stone, 0.5), Enum.Material.Cobblestone)
    disc(field, "ChestPaving", Vector3.new(pos.X, 0.4, pos.Z), 12, 0.4, if frost then Color3.fromRGB(191, 220, 226) elseif ember then Color3.fromRGB(83, 65, 60) else pale, if frost then Enum.Material.Ice else Enum.Material.Sandstone)
    local base = part(island, "TreasureChest_" .. region.Id, Vector3.new(8, 3, 5), CFrame.new(pos), casing, if frost or ember then Enum.Material.Metal else Enum.Material.WoodPlanks)
    local lid = part(island, "TreasureChestLid_" .. region.Id, Vector3.new(8.4, 1.4, 5.4), base.CFrame + Vector3.new(0, 2.1, 0), trim, Enum.Material.Metal)
    for _, x in {-2.9, 2.9} do part(island, "ChestBand", Vector3.new(0.45, 4.9, 5.6), base.CFrame + Vector3.new(x, 0.8, 0), trim, Enum.Material.Metal) end
    local lock = ornament(island, "ChestSeal", Vector3.new(1.4, 1.4, 0.45), base.CFrame * CFrame.new(0, 0.8, 2.7) * CFrame.Angles(0, 0, math.pi / 4), region.Accent, Enum.Material.Neon)
    if frost then
        for _, x in {-2, 0, 2} do crystal(island, pos + Vector3.new(x, 2.8, 0), if x == 0 then 3.8 else 2.5, Color3.fromRGB(176, 225, 238)) end
    elseif ember then
        for _, x in {-3.5, 3.5} do
            wedge(island, "VaultHorn", Vector3.new(1, 3, 1.5), base.CFrame + Vector3.new(x, 3.5, 0), casing, Enum.Material.Slate)
            ornament(island, "VaultSeam", Vector3.new(0.15, 1.8, 0.1), base.CFrame + Vector3.new(x, 0, 2.6), region.Accent, Enum.Material.Neon)
        end
        glow(lock, 9)
    else
        for _, side in {-1, 1} do
            ornament(island, "ChestLeaf", Vector3.new(2.2, 0.25, 0.8), lid.CFrame * CFrame.new(side * 1.8, 1, 0) * CFrame.Angles(0, side * math.rad(25), 0), Color3.fromRGB(95, 153, 76), Enum.Material.Grass)
        end
    end
    label(lid, title, tostring(region.ChestCost) .. " Gold · regional weapons", trim, 70)
    local chestLabel = lid:FindFirstChild("StationLabel") :: BillboardGui
    chestLabel.StudsOffset = Vector3.new(0, 6, 0)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "OpenChest"; prompt.ActionText = "Open chest · " .. region.ChestCost .. " Gold"
    prompt.ObjectText = title; prompt.MaxActivationDistance = 20; prompt.RequiresLineOfSight = false; prompt.Parent = base
end

local function forestScenery(parent: Model, center: Vector3, spec: any)
    leafyTree(parent, center + Vector3.new(-96, 0, -127), 27, true)
    for i = 1, 6 do
        local z = 68 - (i - 1) * 54
        for _, side in {-1, 1} do
            local x = side * 116
            local rock = part(parent, "MossBoulder", Vector3.new(20, 9 + i % 3 * 3, 27), CFrame.new(center + Vector3.new(x, 3, z)) * CFrame.Angles(0, i * 0.3, 0), Color3.fromRGB(99, 108, 82), Enum.Material.Rock)
            orb(parent, "MossCap", rock.Position + Vector3.new(0, 5, 0), Vector3.new(20, 3, 23), Color3.fromRGB(86, 135, 67), Enum.Material.Grass)
            if i % 2 == 0 then leafyTree(parent, center + Vector3.new(side * 91, 0, z), 14) end
        end
    end
    local water = ornament(parent, "GroveStream", Vector3.new(13, 0.15, 113), CFrame.new(center + Vector3.new(-105, 0.22, -165)), Color3.fromRGB(68, 150, 156), Enum.Material.Glass)
    water.Transparency = 0.18
    for i = 1, 7 do flowers(parent, center + Vector3.new(if i % 2 == 0 then -29 else 62, 0, -67 - i * 20), i) end
    for _, x in {-13, 13} do
        part(parent, "GroveRuinsPillar", Vector3.new(2.4, 10, 2.4), CFrame.new(center + spec.Chest + Vector3.new(x, 2.7, -11)), stone, Enum.Material.Cobblestone)
        ornament(parent, "RuinsMoss", Vector3.new(3.2, 1, 3.2), CFrame.new(center + spec.Chest + Vector3.new(x, 7.7, -11)), Color3.fromRGB(94, 144, 77), Enum.Material.Grass)
    end
end

local function frostScenery(parent: Model, center: Vector3, spec: any)
    for i = 1, 6 do
        local z = 48 - (i - 1) * 43
        for _, side in {-1, 1} do
            wedge(parent, "GlacierFace", Vector3.new(17, 21 + i % 3 * 4, 28), CFrame.new(center + Vector3.new(side * 94, 10, z)) * CFrame.Angles(0, side * math.pi / 2, 0), Color3.fromRGB(162, 202, 216), Enum.Material.Ice)
            if i % 2 == 0 then pine(parent, center + Vector3.new(side * 77, 0, z + 9), 18) end
        end
    end
    local pond = disc(parent, "FrozenMirror", center + Vector3.new(57, 0.15, -57), 18, 0.3, Color3.fromRGB(111, 172, 199), Enum.Material.Ice)
    pond.CanCollide = false; pond.Transparency = 0.14
    for i = 1, 4 do ornament(parent, "IceFracture", Vector3.new(0.18, 0.08, 17), CFrame.new(center + Vector3.new(48 + i * 3, 0.34, -57)) * CFrame.Angles(0, i * 0.8, 0), Color3.fromRGB(211, 239, 242), Enum.Material.SmoothPlastic) end
    local tower = group(parent, "GlacierWatchspire")
    local pos = center + Vector3.new(-76, 0, -57)
    disc(tower, "SpireFoundation", pos + Vector3.new(0, 0.5, 0), 11, 1, Color3.fromRGB(118, 150, 173), Enum.Material.Slate)
    for _, x in {-5, 5} do part(tower, "SpireColumn", Vector3.new(3, 27, 3), CFrame.new(pos + Vector3.new(x, 13.5, 0)), Color3.fromRGB(132, 173, 197), Enum.Material.Cobblestone) end
    part(tower, "SpireCrown", Vector3.new(15, 2, 10), CFrame.new(pos + Vector3.new(0, 28, 0)), Color3.fromRGB(203, 225, 228), Enum.Material.Snow)
    crystal(tower, pos + Vector3.new(0, 29, 0), 12, Color3.fromRGB(149, 212, 233))
    for _, side in {-1, 1} do
        crystal(parent, center + spec.Chest + Vector3.new(side * 13, -2.3, -9), 7, Color3.fromRGB(175, 222, 236))
        part(parent, "FrozenShrineColumn", Vector3.new(3, 8, 3), CFrame.new(center + spec.BossSpawn + Vector3.new(side * 18, 4, -10)), Color3.fromRGB(115, 149, 169), Enum.Material.Cobblestone)
    end
end

local function emberScenery(parent: Model, center: Vector3, spec: any)
    local ash = Color3.fromRGB(48, 46, 51)
    for i = 1, 6 do
        local z = 47 - (i - 1) * 43
        for _, side in {-1, 1} do
            local h = 15 + i % 3 * 6
            part(parent, "BasaltColumn", Vector3.new(14, h, 23), CFrame.new(center + Vector3.new(side * 94, h / 2 - 1, z)) * CFrame.Angles(0, i * 0.3, 0), ash, Enum.Material.Slate)
            wedge(parent, "BasaltSpike", Vector3.new(12, 9, 20), CFrame.new(center + Vector3.new(side * 94, h + 2, z)), ash, Enum.Material.Rock)
            ornament(parent, "BasaltVein", Vector3.new(0.6, h * 0.7, 0.1), CFrame.new(center + Vector3.new(side * 87, h / 2, z)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(211, 94, 39), Enum.Material.Neon)
        end
    end
    part(parent, "LavaBed", Vector3.new(18, 0.5, 225), CFrame.new(center + Vector3.new(87, 0.1, -64)), ash, Enum.Material.Rock)
    ornament(parent, "LavaChannel", Vector3.new(11, 0.12, 221), CFrame.new(center + Vector3.new(87, 0.4, -64)), Color3.fromRGB(222, 94, 38), Enum.Material.Neon)
    local tower = group(parent, "CinderFurnace")
    local pos = center + Vector3.new(76, 0, -57)
    part(tower, "FurnaceBase", Vector3.new(19, 2, 19), CFrame.new(pos + Vector3.new(0, 1, 0)), ash, Enum.Material.Rock)
    part(tower, "FurnaceBody", Vector3.new(13, 27, 13), CFrame.new(pos + Vector3.new(0, 15, 0)), Color3.fromRGB(72, 55, 51), Enum.Material.Brick)
    for _, x in {-4, 4} do
        local vent = ornament(tower, "FurnaceVent", Vector3.new(1.2, 17, 0.12), CFrame.new(pos + Vector3.new(x, 14, 6.6)), Color3.fromRGB(229, 110, 47), Enum.Material.Neon)
        glow(vent, 13)
    end
    part(tower, "Chimney", Vector3.new(8, 13, 8), CFrame.new(pos + Vector3.new(0, 33, 0)), ash, Enum.Material.Slate)
    ornament(tower, "MoltenCrown", Vector3.new(9, 0.6, 9), CFrame.new(pos + Vector3.new(0, 40, 0)), Color3.fromRGB(228, 114, 56), Enum.Material.Neon)
    for _, offset in {Vector3.new(-75, 0, 7), Vector3.new(-77, 0, -84), Vector3.new(73, 0, -144)} do
        local posTree = center + offset
        local tree = group(parent, "CharredTree")
        part(tree, "BurntTrunk", Vector3.new(1.8, 13, 1.8), CFrame.new(posTree + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(8)), ash, Enum.Material.Wood)
        for _, side in {-1, 1} do ornament(tree, "BurntBranch", Vector3.new(1, 8, 1), CFrame.new(posTree + Vector3.new(side * 2, 10, 0)) * CFrame.Angles(0, 0, side * 0.65), ash, Enum.Material.Wood) end
    end
    for _, x in {-12, 12} do
        local p = ornament(parent, "VaultBrazier", Vector3.new(2, 1.5, 2), CFrame.new(center + spec.Chest + Vector3.new(x, 1, -10)), Color3.fromRGB(219, 120, 54), Enum.Material.Neon)
        glow(p, 10)
        part(parent, "BrazierPedestal", Vector3.new(3, 4, 3), CFrame.new(center + spec.Chest + Vector3.new(x, -0.3, -10)), ash, Enum.Material.Slate)
    end
end

local function buildRegion(root: Model, region: any, index: number)
    local spec = Layout.Get(region.Id)
    local center: Vector3 = region.Center
    local frost = region.Id == "frostfall"; local ember = region.Id == "emberreach"
    local groundColor = if frost then Color3.fromRGB(213, 231, 234) elseif ember then Color3.fromRGB(72, 62, 62) else Color3.fromRGB(93, 137, 76)
    local groundMaterial = if frost then Enum.Material.Snow elseif ember then Enum.Material.Slate else Enum.Material.Grass
    local roadColor = if frost then Color3.fromRGB(123, 152, 170) elseif ember then Color3.fromRGB(106, 85, 74) else Color3.fromRGB(172, 155, 109)
    local island = group(root, region.Id); island:SetAttribute("RegionId", region.Id)
    island:SetAttribute("ArtIdentity", if frost then "Frozen ruins" elseif ember then "Volcanic forge" else "Ancient woodland")
    local length = spec.Front - spec.Back
    local middle = (spec.Front + spec.Back) / 2
    part(island, "Ground", Vector3.new(spec.Width, 12, length), CFrame.new(center + Vector3.new(0, -6, middle)), groundColor, groundMaterial)
    part(island, "MainTrail", Vector3.new(20, 0.2, length), CFrame.new(center + Vector3.new(0, 0.15, middle)), roadColor, if frost or ember then Enum.Material.Cobblestone else Enum.Material.Ground)
    local field = group(island, "CombatField"); field:SetAttribute("ZoneType", "Combat")
    part(field, "ChestApproach", Vector3.new(math.abs(spec.Chest.X), 0.18, 10), CFrame.new(center + Vector3.new(spec.Chest.X / 2, 0.12, spec.Chest.Z)), roadColor, Enum.Material.Cobblestone)
    -- Small paving details stay non-collidable; the underlying road is continuous.
    local routeStart = if index == 1 then -72 else 40
    for z = routeStart, spec.Back + 12, -28 do
        ornament(field, "RoadPaver", Vector3.new(12, 0.1, 5), CFrame.new(center + Vector3.new(0, 0.29, z)), roadColor:Lerp(pale, 0.18), Enum.Material.Cobblestone)
    end
    if index == 1 then
        local hub = group(island, "BaseCamp"); hub:SetAttribute("ZoneType", "Hub")
        disc(hub, "PlazaBorder", center + Vector3.new(0, 0.12, 20), 47, 0.24, stone, Enum.Material.Cobblestone)
        disc(hub, "Plaza", center + Vector3.new(0, 0.26, 20), 43, 0.28, pale:Lerp(stone, 0.45), Enum.Material.Sandstone)
        part(hub, "StationWalk", Vector3.new(108, 0.2, 15), CFrame.new(center + Vector3.new(0, 0.4, 8)), pale:Lerp(stone, 0.5), Enum.Material.Cobblestone)
        stall(hub, center + spec.Sell, "SellEquipment", "SELL EQUIPMENT", Color3.fromRGB(73, 127, 92))
        stall(hub, center + spec.Upgrade, "UpgradeEquipment", "UPGRADE EQUIPMENT", Color3.fromRGB(92, 111, 143))
        local gate = arch(hub, center + spec.FieldEntrance, "FieldEntrance", region.Accent, 30, region.Id)
        label(gate, "VERDANT CROSSROADS", "Ancient woodland · chest ahead", region.Accent, 85)
        for _, x in {-68, 68} do part(hub, "CampBoundary", Vector3.new(100, 3, 3), CFrame.new(center + Vector3.new(x, 1.5, -55)), stone, Enum.Material.Cobblestone) end
        for _, x in {-86, 86} do part(hub, "RearWall", Vector3.new(60, 4, 3), CFrame.new(center + Vector3.new(x, 2, 83)), stone, Enum.Material.Cobblestone) end
        local fountain = group(hub, "TownFountain")
        local pos = center + Vector3.new(83, 0, 53)
        disc(fountain, "Basin", pos + Vector3.new(0, 0.7, 0), 10, 1.4, pale, Enum.Material.Sandstone)
        local water = disc(fountain, "Water", pos + Vector3.new(0, 1.45, 0), 8.5, 0.12, Color3.fromRGB(95, 167, 175), Enum.Material.Glass)
        water.CanCollide = false; water.Transparency = 0.17
        part(fountain, "CenterColumn", Vector3.new(3, 6, 3), CFrame.new(pos + Vector3.new(0, 4, 0)), stone, Enum.Material.Cobblestone)
        disc(fountain, "UpperBowl", pos + Vector3.new(0, 7.2, 0), 4.5, 0.8, pale, Enum.Material.Sandstone)
    else
        local waypoint = group(island, "ArrivalWaypoint")
        disc(waypoint, "ArrivalPaving", center + Vector3.new(0, 0.2, spec.Spawn.Z), 10, 0.4, stone:Lerp(region.Accent, 0.35), Enum.Material.Cobblestone)
        local sign = marker(waypoint, "RegionSign", center + Vector3.new(25, 6, spec.Spawn.Z))
        label(sign, region.Name, if frost then "Frozen ruins · chest on the left" else "Volcanic forge · chest on the right", region.Accent, 65)
    end
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "PlayerSpawn"; spawn.Size = Vector3.new(10, 1, 10); spawn.CFrame = CFrame.new(center + spec.Spawn)
    spawn.Anchored = true; spawn.Neutral = true; spawn.Duration = 3; spawn.Transparency = 1
    spawn.CanCollide = false; spawn.CanTouch = false; spawn.Parent = island
    regionChest(island, field, region, spec)
    local spawns = Instance.new("Folder"); spawns.Name = "MobSpawns"; spawns.Parent = field
    for i, offset in spec.MobSpawns do
        local p = marker(spawns, "Encounter" .. i, center + offset)
        p:SetAttribute("RegionId", region.Id); p:SetAttribute("LeashRadius", 18)
    end
    disc(field, "BossClearing", center + spec.BossSpawn + Vector3.new(0, 0.12, 0), 21, 0.24, groundColor:Lerp(stone, 0.45), if frost then Enum.Material.Ice else Enum.Material.Ground)
    marker(spawns, "Boss", center + spec.BossSpawn):SetAttribute("RegionId", region.Id)
    if index < #Regions.List then portal(field, center + spec.NextGate, Regions.List[index + 1], "NextRegionGate") end
    if index == #Regions.List then
        part(field, "RoadEnd", Vector3.new(spec.Width, 12, 30), CFrame.new(center + Vector3.new(0, -6, spec.Back - 15)), groundColor, groundMaterial)
        local endGate = arch(field, center + spec.NextGate, "FutureRegionEntrance", gold, 30, region.Id)
        label(endGate, "MORE REGIONS", "Coming soon", gold, 100)
        for i = -2, 2 do part(field, "TerminalCliff", Vector3.new(41, 25, 18), CFrame.new(center + Vector3.new(i * 40, 10, spec.Back - 26)), Color3.fromRGB(48, 46, 51), Enum.Material.Slate) end
    end
    local scenery = group(island, "Scenery")
    if frost then frostScenery(scenery, center, spec) elseif ember then emberScenery(scenery, center, spec) else forestScenery(scenery, center, spec) end
    local lanternStart = if index == 1 then -32 else 20
    for z = lanternStart, spec.Back + 15, -58 do
        for _, x in {-16, 16} do
            if index == 1 then lantern(island, center + Vector3.new(x, 0, z))
            elseif frost then crystal(island, center + Vector3.new(x, 0, z), 3, Color3.fromRGB(162, 217, 233))
            else
                local base = part(island, "RoadBrazier", Vector3.new(2, 3, 2), CFrame.new(center + Vector3.new(x, 1.5, z)), Color3.fromRGB(54, 49, 50), Enum.Material.Slate)
                local emberLight = ornament(island, "RoadEmber", Vector3.new(1.5, 0.6, 1.5), base.CFrame + Vector3.new(0, 1.9, 0), region.Accent, Enum.Material.Neon)
                glow(emberLight, 10)
            end
        end
    end
end

function Builder.Build(): Model
    local templateFloor = workspace:FindFirstChild("Baseplate")
    if templateFloor and templateFloor:IsA("BasePart") then
        templateFloor.Transparency = 1; templateFloor.CanCollide = false
        templateFloor.CanTouch = false; templateFloor.CanQuery = false
    end
    local templateSpawn = workspace:FindFirstChild("SpawnLocation")
    if templateSpawn and templateSpawn:IsA("SpawnLocation") then
        templateSpawn.Enabled = false; templateSpawn.Transparency = 1; templateSpawn.CanCollide = false
    end
    local old = workspace:FindFirstChild("ChestRPGWorld")
    if old then old:Destroy() end
    local root = Instance.new("Model")
    root.Name = "ChestRPGWorld"; root:SetAttribute("LayoutVersion", Layout.Version)
    for index, region in Regions.List do buildRegion(root, region, index) end
    root.Parent = workspace
    return root
end
return Builder
