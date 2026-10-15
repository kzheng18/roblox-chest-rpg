--!strict
-- Normal server Script, Studio Play only. Uses actual engine paths and profile state.
local RunService = game:GetService("RunService")
local Pathfinding = game:GetService("PathfindingService")
local Shared = game.ReplicatedStorage.Shared
local Regions = require(Shared.Config.Regions)
local Layout = require(Shared.Config.WorldLayout)
local Services = game.ServerScriptService.Server.Services
local DataService = require(Services.DataService)
local GameService = require(Services.GameService)
local PlayerService = require(Services.PlayerService)

local function copy(value: any): any
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in value do result[key] = copy(child) end
    return result
end

return function(player: Player)
    assert(RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(), "Studio Play server only")
    assert(player:GetAttribute("DataStatus") == "Temporary Studio session", "Mock profile only")
    local data = assert(DataService.Get(player))
    local before = copy(data)
    local character = assert(player.Character)
    local humanoid = assert(character:FindFirstChildOfClass("Humanoid"))
    local root = assert(character:FindFirstChild("HumanoidRootPart")) :: BasePart
    local checks = {}
    local function check(name: string, condition: boolean)
        assert(condition, name); table.insert(checks, name)
    end
    local function moveTo(position: Vector3)
        humanoid:MoveTo(position)
        assert(humanoid.MoveToFinished:Wait(), "Avatar blocked on the road")
        task.wait(0.3)
    end
    local ok, err = pcall(function()
        task.wait(3)
        local world = workspace:WaitForChild("ChestRPGWorld")
        check("current linear layout", world:GetAttribute("LayoutVersion") == Layout.Version)
        local hubs = 0
        for _, region in Regions.List do
            local zone = assert(world:FindFirstChild(region.Id))
            if zone:FindFirstChild("BaseCamp") then hubs += 1 end
            check(region.Id .. " has chest, road and encounters", zone:FindFirstChild("MainTrail") ~= nil and zone:FindFirstChild("TreasureChest_" .. region.Id) ~= nil and #zone.CombatField.MobSpawns:GetChildren() == 5)
        end
        check("one starting base for the entire road", hubs == 1 and world.verdant.BaseCamp:FindFirstChild("SellEquipment") ~= nil and world.verdant.BaseCamp:FindFirstChild("UpgradeEquipment") ~= nil)
        local walkPath: Path? = nil
        for index, region in Regions.List do
            local spec = Layout.Get(region.Id)
            local routes = {
                {Name = "chest", Offset = spec.Chest + Vector3.new(0, 1, 10)},
                {Name = "boss clearing", Offset = spec.BossSpawn + Vector3.new(0, 3, 0)},
                {Name = "end of region", Offset = spec.NextGate + Vector3.new(0, 3, 14)},
            }
            if index == 1 then
                table.insert(routes, {Name = "sell", Offset = spec.Sell + Vector3.new(0, 3, 14)})
                table.insert(routes, {Name = "upgrade", Offset = spec.Upgrade + Vector3.new(0, 3, 14)})
            end
            for _, route in routes do
                local path = Pathfinding:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 6})
                path:ComputeAsync(region.Center + spec.Spawn + Vector3.new(0, 3, 0), region.Center + route.Offset)
                check(region.Id .. " walkable: " .. route.Name, path.Status == Enum.PathStatus.Success)
                if index == 1 and route.Name == "chest" then walkPath = path end
            end
            if index > 1 then
                local previous = Regions.List[index - 1]
                check(region.Id .. " joins the previous region with no gap", previous.Center.X == region.Center.X and previous.Center.Z + Layout.Get(previous.Id).Back == region.Center.Z + spec.Front)
                local path = Pathfinding:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = false})
                local seam = region.Center + Vector3.new(0, 3, spec.Front)
                path:ComputeAsync(seam + Vector3.new(0, 0, 18), seam - Vector3.new(0, 0, 18))
                check(region.Id .. " gateway has a continuous walking path", path.Status == Enum.PathStatus.Success)
            end
        end
        data.CurrentRegion = "verdant"; data.UnlockedRegions = {verdant = true}; data.Power = 0
        DataService.Touch(player, {"CurrentRegion", "UnlockedRegions", "Power"}, true)
        PlayerService.Place(player)
        task.wait(0.3)
        for _, waypoint in assert(walkPath):GetWaypoints() do moveTo(waypoint.Position) end
        check("avatar walks from starting base to chest", (root.Position - Layout.Get("verdant").Chest).Magnitude < 16)
        local seam = Regions.ById.frostfall.Center + Vector3.new(0, 4, Layout.Get("frostfall").Front)
        character:PivotTo(CFrame.new(seam - Vector3.new(0, 0, 5)))
        task.wait(0.5)
        check("locked walking is returned before Frostfall", root.Position.Z > seam.Z and data.CurrentRegion == "verdant")
        data.Power = Regions.ById.emberreach.RequiredPower
        GameService.Handle(player, "UnlockRegion", "emberreach")
        check("cannot skip the middle region", data.UnlockedRegions.emberreach ~= true)
        for _, id in {"frostfall", "emberreach"} do
            data.Power = Regions.ById[id].RequiredPower
            GameService.Handle(player, "UnlockRegion", id)
            check(id .. " unlocks at its requirement", data.UnlockedRegions[id] == true)
            local boundary = Regions.ById[id].Center + Vector3.new(0, 3, Layout.Get(id).Front)
            character:PivotTo(CFrame.new(boundary + Vector3.new(0, 1, 14)))
            task.wait(0.4)
            local target = boundary - Vector3.new(0, 0, 14)
            moveTo(target)
            check(id .. " walking updates current region", data.CurrentRegion == id)
            check(id .. " crossing does not teleport to waypoint", (root.Position - target).Magnitude < 6)
            check(id .. " walking selects its respawn", player.RespawnLocation ~= nil and player.RespawnLocation.Parent.Name == id)
        end
        local lastBoundary = Regions.ById.emberreach.Center + Vector3.new(0, 3, Layout.Get("emberreach").Front)
        moveTo(lastBoundary + Vector3.new(0, 0, 14))
        check("walking backward returns to Frostfall naturally", data.CurrentRegion == "frostfall")
    end)
    humanoid:MoveTo(root.Position)
    if DataService.Get(player) == data then
        for key, value in before do if key ~= "Revision" then (data :: any)[key] = copy(value) end end
        DataService.Touch(player, {"Power", "Gold", "CurrentRegion", "UnlockedRegions", "OwnedWeapons", "EquippedWeapon", "PowerGain", "GoldGain"}, true)
        PlayerService.Place(player)
    end
    assert(ok, tostring(err))
    return {Passed = #checks, Checks = checks, Persistence = "Mock only"}
end
