--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = game.ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Economy = require(Shared.Config.Economy)
local ProfileSchema = require(Shared.Util.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local RuntimeState = require(script.Parent.Parent.Components.RuntimeState)
local StateReplicator = require(script.Parent.Parent.Components.StateReplicator)
local SaveCoordinator = require(script.Parent.Parent.Components.SaveCoordinator)

ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Economy.AutoSaveSeconds)

local studio = RunService:IsStudio()
local store = ProfileStore.New(if studio then Economy.StudioStoreName else Economy.StoreName, ProfileSchema.New())
if studio then
	store = store.Mock
end

local profiles: {[Player]: any} = {}
local queues: {[Player]: any} = {}
local DataService = {}
local startedService = false

local function updateSaveStatus(player: Player, queue: any)
	if player.Parent ~= Players or queues[player] ~= queue then return end
	local status = queue.Status()
	if player:GetAttribute("SaveStatus") ~= status then player:SetAttribute("SaveStatus", status) end
	if player:GetAttribute("SavedRevision") ~= queue.SavedRevision() then
		player:SetAttribute("SavedRevision", queue.SavedRevision())
	end
end

function DataService.Get(player: Player): Types.PlayerData?
	if player.Parent ~= Players then return nil end
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return nil
	end
	local data = RuntimeState.Get(player)
	return if data and data.OwnerUserId == player.UserId then data else nil
end

function DataService.Snapshot(player: Player)
	if DataService.Get(player) then StateReplicator.Snapshot(player) end
end

function DataService.Touch(player: Player, fields: {string}, immediate: boolean?): number?
	if not DataService.Get(player) then return nil end
	local revision = RuntimeState.Commit(player, fields)
	local queue = queues[player]
	if revision and queue then queue.Dirty(revision); updateSaveStatus(player, queue) end
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
	local queue = queues[player]
	if not queue or not DataService.Get(player) then return end
	player:SetAttribute("SaveReason", reason or "Progress")
	queue.Request()
	updateSaveStatus(player, queue)
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
	if not studio and ProfileStore.DataStoreState ~= "Access" then
		player:Kick("Cloud progression is unavailable. Please rejoin when saving is available.")
		return
	end
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

	local migratedOk, migrated = pcall(ProfileSchema.Migrate, profile.Data)
	if not migratedOk then
		warn(migrated)
		profile:EndSession()
		player:Kick("Your progression needs a data update. Please try again later.")
		return
	end
	local valid, validationReason = ProfileSchema.Validate(migrated)
	if migrated.OwnerUserId ~= 0 and migrated.OwnerUserId ~= player.UserId then
		valid = false; validationReason = "inventory owner mismatch"
	end
	if not valid then
		warn("[DataService] Invalid migrated profile: " .. tostring(validationReason))
		profile:EndSession()
		player:Kick("Your progression needs a data update. Please try again later.")
		return
	end

	local needsMigrationSave = profile.Data.Version ~= ProfileSchema.Version or migrated.OwnerUserId == 0
	migrated.OwnerUserId = player.UserId
	profile:AddUserId(player.UserId)
	profile.Data = migrated
	profiles[player] = profile
	local queue = SaveCoordinator.new(migrated.Revision, Economy)
	queues[player] = queue
	RuntimeState.Attach(player, migrated)
	createLeaderstats(player)

	profile.OnSave:Connect(function()
		if queues[player] ~= queue then return end
		queue.Begin(); updateSaveStatus(player, queue)
	end)
	profile.OnAfterSave:Connect(function(savedData: any)
		if queues[player] ~= queue or not profile:IsActive() then return end
		if type(savedData) ~= "table" or savedData.OwnerUserId ~= player.UserId
			or type(savedData.Revision) ~= "number" or savedData.Revision ~= savedData.Revision then return end
		queue.Acknowledge(savedData.Revision); updateSaveStatus(player, queue)
	end)
	profile.OnSessionEnd:Connect(function()
		if profiles[player] ~= profile then return end
		profiles[player] = nil
		queue.Detach()
		if queues[player] == queue then queues[player] = nil end
		RuntimeState.Detach(player)
		player:SetAttribute("DataReady", false)
		if player.Parent == Players then
			player:Kick("Your save session ended. Rejoin to protect your progression.")
		end
	end)

	player:SetAttribute("DataStatus", if studio then "Temporary Studio session" else "Cloud save active")
	player:SetAttribute("SaveStatus", "Loaded")
	player:SetAttribute("DataReady", true)
	if needsMigrationSave then
		DataService.Touch(player, {}, false)
		DataService.RequestSave(player, "Profile ownership migration")
	else updateSaveStatus(player, queue) end
	StateReplicator.Snapshot(player)
end

function DataService.Start()
	if startedService then return end
	startedService = true
	StateReplicator.Start()
	-- ProfileStore staggers the 60-second autosave/session-lock heartbeats and owns
	-- leave/shutdown saves. This scheduler retries critical checkpoints only.
	task.spawn(function()
		while not ProfileStore.IsClosing do
			task.wait(1)
			if ProfileStore.IsClosing then break end
			for player, queue in queues do
				local profile = profiles[player]
				if not profile or not profile:IsActive() then continue end
				local canWrite = studio
				if not studio then
					local ok, budget = pcall(function()
						return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
					end)
					canWrite = ok and budget > 0
				end
				if queue.Step(canWrite) then profile:Save() end
				updateSaveStatus(player, queue)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(join, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local queue = queues[player]
		if queue then queue.Detach(); queues[player] = nil end
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
