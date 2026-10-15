--!strict
local Shared = game.ReplicatedStorage.Shared
local Regions = require(Shared.Config.Regions)
local Progression = require(Shared.Util.Progression)
local Remote = require(Shared.Remotes).Get()
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local RequestContext = require(script.Parent.Parent.Components.RequestContext)
local Layout = require(Shared.Config.WorldLayout)

local RegionService = {}
local deniedAt: {[Player]: number} = setmetatable({}, {__mode = "k"}) :: any

-- Server-observed crossing only: walking never unlocks a region or awards currency.
function RegionService.ObservePosition(player: Player)
	local data = DataService.Get(player)
	local root = RequestContext.LivingRoot(player)
	if not data or not root then return end
	local id = Layout.RegionAt(root.Position)
	if not id or id == data.CurrentRegion then return end
	local reachable = true
	local firstLocked = nil
	for _, region in Regions.List do
		if data.UnlockedRegions[region.Id] ~= true then reachable = false; firstLocked = firstLocked or region end
		if region.Id == id then break end
	end
	if not reachable then
		assert(firstLocked)
		local safe = firstLocked.Center + Vector3.new(0, 4, Layout.Get(firstLocked.Id).Front + 14)
		player.Character:PivotTo(CFrame.new(safe))
		root.AssemblyLinearVelocity = Vector3.zero
		if os.clock() - (deniedAt[player] or -math.huge) > 2 then
			deniedAt[player] = os.clock()
			Remote:FireClient(player, "Toast", "Unlock " .. firstLocked.Name .. " at its entrance first.")
		end
		return
	end
	data.CurrentRegion = id
	DataService.Touch(player, {"CurrentRegion"}, true)
end

local function teleport(player: Player, regionId: string)
	if Regions.ById[regionId] then PlayerService.Place(player) end
end

function RegionService.Unlock(player: Player, regionId: string)
	local data = RequestContext.GetData(player, "UnlockRegion", regionId)
	if not data or not RequestContext.LivingRoot(player) then return end
	local allowed, reason = Progression.CanUnlockRegion(data, regionId)
	if not allowed then
		Remote:FireClient(player, "Toast", reason or "Region is locked.")
		return
	end
	data.UnlockedRegions[regionId] = true
	data.CurrentRegion = regionId
	DataService.Touch(player, {"UnlockedRegions", "CurrentRegion"}, true)
	DataService.RequestSave(player, "Region unlock")
	teleport(player, regionId)
end

function RegionService.Travel(player: Player, regionId: string)
	local data = RequestContext.GetData(player, "TravelRegion", regionId)
	if not data or data.UnlockedRegions[regionId] ~= true or not RequestContext.LivingRoot(player) then return end
	data.CurrentRegion = regionId
	DataService.Touch(player, {"CurrentRegion"}, true)
	teleport(player, regionId)
end

return RegionService
