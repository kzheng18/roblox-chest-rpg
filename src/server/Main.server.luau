--!strict
local services = script.Parent.Services
local DataService = require(services.DataService)
local GameService = require(services.GameService)
local WorldService = require(services.WorldService)

DataService.Start()
GameService.Start()
WorldService.Build()

