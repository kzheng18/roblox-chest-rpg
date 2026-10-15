--!strict
-- Local-only rare-roll cinematic: darken, push the camera to the chest, then
-- burst in the rarity color. Nothing here replicates or affects rewards.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Cinematic = {}

export type Handle = {Burst: (Handle) -> (), Finish: (Handle) -> ()}

local function chestFor(regionId: string): BasePart?
	local world = Workspace:FindFirstChild("ChestRPGWorld")
	local region = world and world:FindFirstChild(regionId)
	local chest = region and region:FindFirstChild("TreasureChest_" .. regionId)
	return if chest and chest:IsA("BasePart") then chest else nil
end

local function lowEffects(): boolean
	return player:GetAttribute("EffectsQuality") == "Low"
end

-- moveCamera=false keeps the camera still (Reduced motion).
function Cinematic.Begin(regionId: string, color: Color3, moveCamera: boolean): Handle
	local camera = Workspace.CurrentCamera
	local chest = chestFor(regionId)
	local savedType = camera.CameraType
	local finished = false

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RareRollGrade"
	grade.Parent = Lighting
	TweenService:Create(grade, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {Brightness = -0.22, Saturation = -0.45, Contrast = 0.18}):Play()

	local anchor: Part? = nil
	local emitter: ParticleEmitter? = nil
	local light: PointLight? = nil
	if chest then
		local a = Instance.new("Part")
		a.Name = "RareRollBurst"
		a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false
		a.Transparency = 1
		a.Size = Vector3.one
		a.CFrame = CFrame.new(chest.Position + Vector3.new(0, chest.Size.Y * 0.5 + 0.5, 0))
		a.Parent = Workspace
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		e.LightEmission = 1
		e.Speed = NumberRange.new(16, 34)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.5, 1.1)
		e.Drag = 3
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 0)})
		e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
		e.Parent = a
		local l = Instance.new("PointLight")
		l.Color = color; l.Range = 22; l.Brightness = 0
		l.Parent = a
		TweenService:Create(l, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {Brightness = 2.5}):Play()
		anchor, emitter, light = a, e, l

		if moveCamera then
			-- Approach from the side the player is already looking from.
			local fromChest = camera.CFrame.Position - chest.Position
			local flat = Vector3.new(fromChest.X, 0, fromChest.Z)
			local direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, 1)
			local eye = chest.Position + direction * 12 + Vector3.new(0, 5, 0)
			camera.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(camera, TweenInfo.new(1.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{CFrame = CFrame.lookAt(eye, chest.Position + Vector3.new(0, 1.5, 0))}):Play()
		end
	end

	local handle = {} :: any
	function handle.Burst(_self: Handle)
		if finished then return end
		if emitter then emitter:Emit(if lowEffects() then 18 else 70) end
		if light then
			light.Brightness = 8
			TweenService:Create(light, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {Brightness = 0}):Play()
		end
		if anchor and not lowEffects() then
			local ring = Instance.new("Part")
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false; ring.CanTouch = false
			ring.Material = Enum.Material.Neon
			ring.Color = color
			ring.Size = Vector3.new(0.2, 2, 2)
			ring.CFrame = anchor.CFrame * CFrame.Angles(0, 0, math.rad(90))
			ring.Parent = anchor
			TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {Size = Vector3.new(0.2, 26, 26), Transparency = 1}):Play()
		end
		grade.TintColor = color:Lerp(Color3.new(1, 1, 1), 0.55)
		grade.Brightness = 0.3
		TweenService:Create(grade, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0, Contrast = 0}):Play()
	end
	function handle.Finish(_self: Handle)
		if finished then return end
		finished = true
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = if savedType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else savedType
		end
		TweenService:Create(grade, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0, Contrast = 0}):Play()
		task.delay(1.2, function()
			grade:Destroy()
			if anchor then anchor:Destroy() end
		end)
	end
	return handle :: Handle
end

return Cinematic
