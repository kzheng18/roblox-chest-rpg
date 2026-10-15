--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Regions = require(Shared.Config.Regions)
local Builder = require(script.Parent.Parent.World.WorldBuilder)
local GameService = require(script.Parent.GameService)
local DataService = require(script.Parent.DataService)
local RegionService = require(script.Parent.RegionService)
local Players = game:GetService("Players")
local WorldService = {}

function WorldService.Build()
    local root = Builder.Build()
    for _, region in Regions.List do
        local island = root:FindFirstChild(region.Id)
        assert(island)
        for _, descendant in island:GetDescendants() do
            if descendant:IsA("ProximityPrompt") then
                if descendant.Name == "OpenChest" then
                    descendant.Triggered:Connect(function(player)
                        GameService.Handle(player, "OpenChest", region.Id)
                    end)
                elseif descendant.Name == "RegionTravel" then
                    local target = descendant.Parent and descendant.Parent:GetAttribute("TargetRegion")
                    if type(target) == "string" and Regions.ById[target] then
                        descendant.Triggered:Connect(function(player)
                            local data = DataService.Get(player)
                            if not data then return end
                            GameService.Handle(player, if data.UnlockedRegions[target] then "TravelRegion" else "UnlockRegion", target)
                        end)
                    end
                end
            end
        end
    end
    task.spawn(function()
        while root.Parent == workspace do
            task.wait(0.15)
            for _, player in Players:GetPlayers() do RegionService.ObservePosition(player) end
        end
    end)
end

return WorldService
