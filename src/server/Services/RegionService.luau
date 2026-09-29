--!strict
local Shared = game.ReplicatedStorage.Shared
local Regions = require(Shared.Config.Regions)
local Progression = require(Shared.Util.Progression)
local Remote = require(Shared.Remotes).Get()
local DataService = require(script.Parent.DataService)

local RegionService = {}

local function teleport(player: Player, regionId: string)
	local region = Regions.ById[regionId]
	local character = player.Character
	if region and character then
		character:PivotTo(CFrame.new(region.Center + Vector3.new(0, 8, 0)))
	end
end

function RegionService.Unlock(player: Player, regionId: string)
	local data = DataService.Get(player)
	if not data then return end
	local allowed, reason = Progression.CanUnlockRegion(data, regionId)
	if not allowed then
		Remote:FireClient(player, "Toast", reason or "Region is locked.")
		return
	end
	data.UnlockedRegions[regionId] = true
	data.CurrentRegion = regionId
	DataService.Touch(player, true)
	teleport(player, regionId)
end

function RegionService.Travel(player: Player, regionId: string)
	local data = DataService.Get(player)
	if not data or not data.UnlockedRegions[regionId] or not Regions.ById[regionId] then return end
	data.CurrentRegion = regionId
	DataService.Touch(player, true)
	teleport(player, regionId)
end

return RegionService

