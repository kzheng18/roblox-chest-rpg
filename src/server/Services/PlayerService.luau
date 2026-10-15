--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Shared = game.ReplicatedStorage.Shared
local Regions = require(Shared.Config.Regions)
local Layout = require(Shared.Config.WorldLayout)
local DataService = require(script.Parent.DataService)

local PlayerService = {}
local connections: {[Player]: {RBXScriptConnection}} = {}
local deaths: {[Player]: RBXScriptConnection} = {}
local loading: {[Player]: boolean} = {}
local attempts: {[Player]: number} = {}

local function destination(player: Player): SpawnLocation?
	local data = DataService.Get(player)
	if not data then return nil end
	local id = data.CurrentRegion
	if not Regions.ById[id] or data.UnlockedRegions[id] ~= true then id = "verdant" end
	local world = Workspace:FindFirstChild("ChestRPGWorld")
	local region = world and world:FindFirstChild(id)
	local spawn = region and region:FindFirstChild("PlayerSpawn")
	return if spawn and spawn:IsA("SpawnLocation") then spawn else nil
end

function PlayerService.Place(player: Player)
	local spawn = destination(player)
	if not spawn then return end
	player.RespawnLocation = spawn
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root and root:IsA("BasePart") then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local spawnPlayer: (Player) -> ()
spawnPlayer = function(player: Player)
	if loading[player] or player.Parent ~= Players or not DataService.Get(player) then return end
	local spawn = destination(player)
	if not spawn then
		player:Kick("The test world could not load. Please rejoin.")
		return
	end
	loading[player] = true
	player.RespawnLocation = spawn
	player:SetAttribute("SpawnStatus", "Spawning")
	local ok = pcall(function() player:LoadCharacterAsync() end)
	loading[player] = nil
	if player.Parent ~= Players or not DataService.Get(player) then return end
	if not ok then
		attempts[player] = (attempts[player] or 0) + 1
		if attempts[player] >= 3 then
			player:Kick("Your character could not load. Please rejoin.")
		else
			task.delay(2, spawnPlayer, player)
		end
		return
	end
	attempts[player] = 0
	PlayerService.Place(player)
	player:SetAttribute("SpawnStatus", "Ready")
end

local function join(player: Player)
	if connections[player] then return end
	local function bindCharacter(character: Model)
			if deaths[player] then deaths[player]:Disconnect(); deaths[player] = nil end
			local humanoid = character:WaitForChild("Humanoid", 10)
			if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character or player.Parent ~= Players then return end
			deaths[player] = humanoid.Died:Connect(function()
				player:SetAttribute("SpawnStatus", "Respawning")
				task.delay(3, function()
					if player.Character == character then spawnPlayer(player) end
				end)
			end)
	end
	connections[player] = {
		player.CharacterAdded:Connect(bindCharacter),
		player:GetAttributeChangedSignal("DataReady"):Connect(function()
			if player:GetAttribute("DataReady") then
				if player.Character then PlayerService.Place(player) else task.spawn(spawnPlayer, player) end
			end
		end),
		player:GetAttributeChangedSignal("CurrentRegion"):Connect(function()
			-- Walking across a seam changes region/respawn without teleporting the avatar.
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and Layout.RegionAt(root.Position) == player:GetAttribute("CurrentRegion") then
				player.RespawnLocation = destination(player)
			else
				PlayerService.Place(player)
			end
		end),
	}
	if player.Character then task.spawn(bindCharacter, player.Character) end
	if DataService.Get(player) then
		if player.Character then PlayerService.Place(player) else task.spawn(spawnPlayer, player) end
	end
end

function PlayerService.Start()
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player)
		for _, connection in connections[player] or {} do connection:Disconnect() end
		if deaths[player] then deaths[player]:Disconnect() end
		connections[player] = nil; deaths[player] = nil; loading[player] = nil; attempts[player] = nil
	end)
	for _, player in Players:GetPlayers() do join(player) end
end

return PlayerService
