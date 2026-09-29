--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Economy = require(Shared.Config.Economy)
local Progression = require(Shared.Util.Progression)
local FormatNumber = require(Shared.Util.FormatNumber)
local Remote = require(Shared.Remotes).Get()
local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)

local studio = RunService:IsStudio()
local store = ProfileStore.New(if studio then Economy.StudioStoreName else Economy.StoreName, Progression.New())
if studio then
	store = store.Mock
end

local profiles: {[Player]: any} = {}
local DataService = {}

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end

function DataService.Get(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return if profile and profile:IsActive() then profile.Data else nil
end

function DataService.Snapshot(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	Remote:FireClient(player, "State", {
		Power = data.Power,
		Gold = data.Gold,
		Luck = Progression.Luck(data),
		Rebirths = data.Rebirths,
		OwnedWeapons = data.OwnedWeapons,
		EquippedWeapon = data.EquippedWeapon,
		UnlockedRegions = data.UnlockedRegions,
		CurrentRegion = data.CurrentRegion,
		Settings = data.Settings,
		PowerGain = Progression.PowerGain(data),
		GoldGain = Progression.GoldGain(data),
	})
end

function DataService.Sync(player: Player, full: boolean?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("Power", data.Power)
	player:SetAttribute("Gold", data.Gold)
	player:SetAttribute("Luck", Progression.Luck(data))
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("EquippedWeapon", data.EquippedWeapon)
	player:SetAttribute("CurrentRegion", data.CurrentRegion)
	player:SetAttribute("PowerGain", Progression.PowerGain(data))
	player:SetAttribute("GoldGain", Progression.GoldGain(data))
	player:SetAttribute("RollAnimation", data.Settings.RollAnimation)
	player:SetAttribute("ReducedMotion", data.Settings.ReducedMotion)
	player:SetAttribute("Volume", data.Settings.Volume)

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local power = stats:FindFirstChild("Power") :: StringValue?
		local gold = stats:FindFirstChild("Gold") :: StringValue?
		if power then power.Value = FormatNumber(data.Power) end
		if gold then gold.Value = FormatNumber(data.Gold) end
	end

	if full then
		DataService.Snapshot(player)
	end
end

function DataService.Touch(player: Player, full: boolean?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Revision += 1
	DataService.Sync(player, full)
end

local function join(player: Player)
	player:SetAttribute("DataReady", false)
	player:SetAttribute("DataStatus", "Loading progression…")
	local started = os.clock()
	local ok, profile = pcall(function()
		return store:StartSessionAsync("Player_" .. player.UserId, {
			Cancel = function()
				return player.Parent ~= Players or os.clock() - started > Economy.LoadTimeout
			end,
		})
	end)
	if not ok or not profile then
		player:Kick("Your progression could not load safely. Please rejoin.")
		return
	end
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profile:AddUserId(player.UserId)
	local migratedOk, migrated = pcall(Progression.Migrate, copy(profile.Data))
	if not migratedOk then
		warn(migrated)
		profile:EndSession()
		player:Kick("Your progression needs a data update. Please try again later.")
		return
	end
	profile.Data = migrated
	profiles[player] = profile

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:SetAttribute("DataReady", false)
		if player.Parent == Players then
			player:Kick("Your save session ended. Rejoin to protect your progression.")
		end
	end)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	for _, name in {"Power", "Gold"} do
		local stat = Instance.new("StringValue")
		stat.Name = name
		stat.Parent = leaderstats
	end

	player:SetAttribute("DataStatus", if studio then "Temporary Studio session" else "Cloud save active")
	player:SetAttribute("DataReady", true)
	DataService.Sync(player, true)
end

function DataService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(join, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profiles[player] = nil
			profile:EndSession()
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
end

return DataService

