--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Shared = game.ReplicatedStorage.Shared
local IntentPolicy = require(Shared.Util.IntentPolicy)
local Network = require(Shared.Config.Network)
local DataService = require(script.Parent.Parent.Services.DataService)

local RequestContext = {}

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function RequestContext.LivingRoot(player: Player): BasePart?
	local character = player.Character
	if not character or not character:IsDescendantOf(Workspace) then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not finite(humanoid.Health) or humanoid.Health <= 0 then return nil end
	if not root or not root:IsA("BasePart") then return nil end
	local p = root.Position
	if not finite(p.X) or not finite(p.Y) or not finite(p.Z) then return nil end
	return root
end

function RequestContext.GetData(player: Player, action: string, payload: any)
	if player.Parent ~= Players or not IntentPolicy.Validate(action, payload) then return nil end
	return DataService.Get(player) -- Active session, never attributes/client-provided state.
end

function RequestContext.NearChest(player: Player, regionId: string): boolean
	local root = RequestContext.LivingRoot(player)
	if not root then return false end
	local world = Workspace:FindFirstChild("ChestRPGWorld")
	local region = world and world:FindFirstChild(regionId)
	local chest = region and region:FindFirstChild("TreasureChest_" .. regionId)
	if not chest or not chest:IsA("BasePart") or not chest.Anchored then return false end
	local distance = (root.Position - chest.Position).Magnitude
	return finite(distance) and distance <= Network.ChestInteractionRadius
end

return RequestContext
