--!strict
local RunService = game:GetService("RunService")
local root = script.Parent

local Remotes = {}

function Remotes.Get(): RemoteEvent
	if RunService:IsServer() then
		local existing = root:FindFirstChild("Intent")
		if existing then
			return existing :: RemoteEvent
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = "Intent"
		remote.Parent = root
		return remote
	end
	return root:WaitForChild("Intent") :: RemoteEvent
end

return Remotes

