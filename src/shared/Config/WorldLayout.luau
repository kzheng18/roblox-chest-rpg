--!strict
-- Region geometry and server bounds share these specifications.
local Regions = require(script.Parent.Regions)
local Layout = {Version = 3}
local specs = {
    verdant = {
        Width = 260, Front = 105, Back = -235,
        Spawn = Vector3.new(0, 0.6, 58),
        Chest = Vector3.new(37, 2.3, -118),
        Sell = Vector3.new(-44, 0, 8), Upgrade = Vector3.new(44, 0, 8),
        FieldEntrance = Vector3.new(0, 0, -55),
        NextGate = Vector3.new(0, 0, -235),
        MobSpawns = {Vector3.new(-51, 0, -91), Vector3.new(62, 0, -91), Vector3.new(-57, 0, -154), Vector3.new(58, 0, -173)},
        BossSpawn = Vector3.new(-51, 0, -193),
    },
    frostfall = {
        Width = 200, Front = 65, Back = -195,
        Spawn = Vector3.new(0, 0.6, 37),
        Chest = Vector3.new(-34, 2.3, -57),
        NextGate = Vector3.new(0, 0, -195),
        MobSpawns = {Vector3.new(-48, 0, 3), Vector3.new(48, 0, 3), Vector3.new(-47, 0, -110), Vector3.new(47, 0, -100)},
        BossSpawn = Vector3.new(47, 0, -156),
    },
    emberreach = {
        Width = 200, Front = 65, Back = -195,
        Spawn = Vector3.new(0, 0.6, 37),
        Chest = Vector3.new(34, 2.3, -57),
        NextGate = Vector3.new(0, 0, -195),
        MobSpawns = {Vector3.new(-48, 0, 3), Vector3.new(48, 0, 3), Vector3.new(-47, 0, -100), Vector3.new(47, 0, -110)},
        BossSpawn = Vector3.new(-47, 0, -156),
    },
}
function Layout.Get(regionId: string): any
    return assert((specs :: any)[regionId], "Missing layout for " .. regionId)
end
function Layout.RegionAt(position: Vector3): string?
    for _, region in Regions.List do
        local spec = Layout.Get(region.Id)
        local relative = position - region.Center
        if math.abs(relative.X) <= spec.Width / 2 and relative.Y >= -10 and relative.Y <= 180
            and relative.Z <= spec.Front and relative.Z > spec.Back then return region.Id end
    end
    return nil
end
return Layout
