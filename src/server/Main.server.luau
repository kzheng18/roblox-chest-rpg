--!strict
game:GetService("Players").CharacterAutoLoads = false
local services = script.Parent.Services
local DataService = require(services.DataService)
local GameService = require(services.GameService)
local WorldService = require(services.WorldService)
local PlayerService = require(services.PlayerService)
local WeaponVisualService = require(services.WeaponVisualService)
local SwordMeshFactory = require(script.Parent.World.SwordMeshFactory)

WorldService.Build()
local swordsReady, swordError = SwordMeshFactory.Build()
if not swordsReady then warn("[Swords] Meshes unavailable: " .. tostring(swordError)) end
PlayerService.Start()
WeaponVisualService.Start()
DataService.Start()
GameService.Start()
