-- Run in the Studio Edit datamodel after WorldBuilder.Build().
-- Export only our geometry/UI. Runtime attributes and prompt connections come from the builder.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before exporting")
local function pack(v)
	local kind = typeof(v)
	if kind == "Vector3" then return {kind, {v.X, v.Y, v.Z}} end
	if kind == "CFrame" then return {kind, {v:GetComponents()}} end
	if kind == "Color3" then return {kind, {v.R, v.G, v.B}} end
	if kind == "UDim2" then return {kind, {v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset}} end
	if kind == "UDim" then return {kind, {v.Scale, v.Offset}} end
	if kind == "EnumItem" then return {"token", v.Value} end
	return {kind, v}
end
local function capture(obj)
	local props = {Name = pack(obj.Name)}
	local function add(names)
		for _, name in names do props[name] = pack(obj[name]) end
	end
	if obj:IsA("BasePart") then add({"Anchored", "CanCollide", "CanTouch", "CanQuery", "Transparency", "Size", "CFrame", "Color", "Material", "TopSurface", "BottomSurface"}) end
	if obj:IsA("Part") then add({"Shape"}) end
	if obj:IsA("SpecialMesh") then add({"MeshType", "Scale", "Offset", "VertexColor"}) end
	if obj:IsA("SpawnLocation") then add({"Neutral", "Duration", "Enabled", "AllowTeamChangeOnTouch"}) end
	if obj:IsA("BillboardGui") then add({"Size", "StudsOffset", "MaxDistance", "AlwaysOnTop"}) end
	if obj:IsA("GuiObject") then add({"Size", "Position", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel"}) end
	if obj:IsA("TextLabel") then add({"Text", "TextColor3", "TextSize", "Font"}) end
	if obj:IsA("UICorner") then add({"CornerRadius"}) end
	if obj:IsA("UIStroke") then add({"Color", "Thickness"}) end
	if obj:IsA("PointLight") then add({"Color", "Brightness", "Range"}) end
	if obj:IsA("ProximityPrompt") then add({"ActionText", "ObjectText", "MaxActivationDistance", "RequiresLineOfSight", "KeyboardKeyCode"}) end
	local children = {}
	for _, child in obj:GetChildren() do table.insert(children, capture(child)) end
	return {Class = obj.ClassName, Properties = props, Children = children}
end
return game:GetService("HttpService"):JSONEncode(capture(workspace.ChestRPGWorld))
