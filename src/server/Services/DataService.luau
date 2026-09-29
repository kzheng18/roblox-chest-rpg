--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Economy = require(Shared.Config.Economy)
local ProfileSchema = require(Shared.Util.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local RuntimeState = require(script.Parent.Parent.Components.RuntimeState)
local StateReplicator = require(script.Parent.Parent.Components.StateReplicator)

ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Economy.AutoSaveSeconds)

local studio = RunService:IsStudio()
local store = ProfileStore.New(if studio then Economy.StudioStoreName else Economy.StoreName, ProfileSchema.New())
if studio then
	store = store.Mock
end

local profiles: {[Player]: any} = {}
local saveGeneration: {[Player]: number} = {}
local DataService = {}

function DataService.Get(player: Player): Types.PlayerData?
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return nil
	end
	return RuntimeState.Get(player)
end

function DataService.Snapshot(player: Player)
	StateReplicator.Snapshot(player)
end

function DataService.Touch(player: Player, fields: {string}, immediate: boolean?): number?
	local revision = RuntimeState.Commit(player, fields)
	if revision and immediate then
		StateReplicator.Flush(player)
	end
	return revision
end

function DataService.RequestSave(player: Player, reason: string?)
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return
	end
	local generation = (saveGeneration[player] or 0) + 1
	saveGeneration[player] = generation
	player:SetAttribute("SaveStatus", "Queued")
	player:SetAttribute("SaveReason", reason or "Progress")
	task.delay(Economy.CriticalSaveDebounce, function()
		if saveGeneration[player] ~= generation then
			return
		end
		local current = profiles[player]
		if current ~= profile or not profile:IsActive() then
			return
		end
		profile:Save()
	end)
end

local function createLeaderstats(player: Player)
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	for _, name in {"Power", "Gold"} do
		local stat = Instance.new("StringValue")
		stat.Name = name
		stat.Parent = leaderstats
	end
end

local function join(player: Player)
	player:SetAttribute("DataReady", false)
	player:SetAttribute("DataStatus", "Loading progression…")
	player:SetAttribute("SaveStatus", "Loading")
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
	local migratedOk, migrated = pcall(ProfileSchema.Migrate, profile.Data)
	if not migratedOk then
		warn(migrated)
		profile:EndSession()
		player:Kick("Your progression needs a data update. Please try again later.")
		return
	end
	local valid, validationReason = ProfileSchema.Validate(migrated)
	if not valid then
		warn("[DataService] Invalid migrated profile: " .. tostring(validationReason))
		profile:EndSession()
		player:Kick("Your progression needs a data update. Please try again later.")
		return
	end

	profile.Data = migrated
	profiles[player] = profile
	RuntimeState.Attach(player, migrated)
	createLeaderstats(player)

	profile.OnSave:Connect(function()
		player:SetAttribute("SaveStatus", "Saving")
	end)
	profile.OnAfterSave:Connect(function()
		player:SetAttribute("SaveStatus", "Saved")
	end)
	profile.OnSessionEnd:Connect(function()
		if profiles[player] == profile then
			profiles[player] = nil
		end
		saveGeneration[player] = nil
		RuntimeState.Detach(player)
		player:SetAttribute("DataReady", false)
		if player.Parent == Players then
			player:Kick("Your save session ended. Rejoin to protect your progression.")
		end
	end)

	player:SetAttribute("DataStatus", if studio then "Temporary Studio session" else "Cloud save active")
	player:SetAttribute("SaveStatus", "Loaded")
	player:SetAttribute("DataReady", true)
	StateReplicator.Snapshot(player)
end

function DataService.Start()
	StateReplicator.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(join, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		saveGeneration[player] = nil
		local profile = profiles[player]
		if profile then
			profiles[player] = nil
			RuntimeState.Detach(player)
			profile:EndSession()
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
end

return DataService
