--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config.Performance)
local FrameMetrics = require(Shared.Util.FrameMetrics)
local player = Players.LocalPlayer
local userSettings = UserSettings():GetService("UserGameSettings")
local original: {[Instance]: any} = setmetatable({}, {__mode = "k"}) :: any
local started = false
local low = false

local function ownedEffect(instance: Instance): boolean
	if instance:GetAttribute("RPGEffect") == true then return true end
	local ancestor: Instance? = instance.Parent
	while ancestor and ancestor ~= workspace do
		if ancestor.Name == "ChestRPGWorld" or ancestor.Name == "EquippedSwordVisual" then return true end
		ancestor = ancestor.Parent
	end
	return false
end

local function apply(instance: Instance)
	if not ownedEffect(instance) then return end
	if instance:IsA("ParticleEmitter") then
		original[instance] = original[instance] or {Rate = instance.Rate}
		instance.Rate = original[instance].Rate * (if low then Config.LowEffectsRateScale else 1)
	elseif instance:IsA("Light") then
		original[instance] = original[instance] or {Shadows = instance.Shadows}
		instance.Shadows = if low then false else original[instance].Shadows
	elseif instance:IsA("BasePart") then
		original[instance] = original[instance] or {CastShadow = instance.CastShadow}
		instance.CastShadow = if low then false else original[instance].CastShadow
	end
end

local function configure()
	local preference = player:GetAttribute("EffectsQuality") or "Auto"
	local graphics = userSettings.SavedQualityLevel.Value
	low = preference == "Low" or (preference == "Auto" and
		(if graphics > 0 then graphics <= 4 else UserInputService.TouchEnabled))
	player:SetAttribute("EffectiveEffectsQuality", if low then "Low" else "High")
	-- Work is chunked outside rendering. Streaming additions are handled below.
	for index, instance in workspace:GetDescendants() do
		apply(instance)
		if index % Config.ApplyBatchSize == 0 then task.wait() end
	end
end

local PerformanceController = {}
function PerformanceController.Start()
	if started then return end
	started = true
	local metrics = FrameMetrics.new()
	local elapsed = 0
	RunService.RenderStepped:Connect(function(delta)
		metrics.Add(delta); elapsed += delta
		if elapsed < Config.SampleSeconds then return end
		local sample = metrics.Read()
		player:SetAttribute("ClientFPS", math.floor(sample.FPS + .5))
		player:SetAttribute("ClientFrameP95Ms", sample.P95Ms)
		player:SetAttribute("ClientFrameWorstMs", sample.WorstMs)
		metrics.Reset(); elapsed = 0
	end)
	player:GetAttributeChangedSignal("EffectsQuality"):Connect(function() task.spawn(configure) end)
	userSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function() task.spawn(configure) end)
	workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("BasePart") or instance:IsA("Light") or instance:IsA("ParticleEmitter") then
			task.defer(apply, instance)
		end
	end)
	task.spawn(configure)
end
return PerformanceController
