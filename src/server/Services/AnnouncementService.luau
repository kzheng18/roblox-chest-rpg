--!strict
-- Broadcasts rare pulls: whole server for Legendary+/1-in-1,000+, every server
-- for Mythic+/1-in-5,000+. Display text is built on clients from these fields.
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage.Shared
local Showcase = require(Shared.Config.Showcase)
local Remote = require(Shared.Remotes).Get()

local AnnouncementService = {}
local lastPublish = -math.huge
local started = false

export type Announcement = {
	PlayerName: string, UserId: number, ItemName: string, Rarity: string,
	RateN: number, Kind: string, Global: boolean,
}

local function valid(message: any): boolean
	return type(message) == "table" and type(message.PlayerName) == "string" and #message.PlayerName <= 40
		and type(message.ItemName) == "string" and #message.ItemName <= 60
		and type(message.Rarity) == "string" and #message.Rarity <= 20
		and type(message.Kind) == "string" and #message.Kind <= 30
		and type(message.RateN) == "number" and message.RateN == message.RateN and message.RateN >= 1 and message.RateN < 2^53
		and type(message.UserId) == "number"
end

function AnnouncementService.ShouldAnnounce(rarity: string, rateN: number): (boolean, boolean)
	local server = Showcase.ServerRarities[rarity] == true or rateN >= Showcase.ServerMinRateN
	local global = Showcase.GlobalRarities[rarity] == true or rateN >= Showcase.GlobalMinRateN
	return server or global, global
end

function AnnouncementService.Consider(player: Player, itemName: string, rarity: string, rateN: number, kind: string)
	local announce, global = AnnouncementService.ShouldAnnounce(rarity, rateN)
	if not announce then return end
	local message: Announcement = {
		PlayerName = player.DisplayName, UserId = player.UserId, ItemName = itemName,
		Rarity = rarity, RateN = rateN, Kind = kind, Global = false,
	}
	Remote:FireAllClients("Announce", message)
	if not global or RunService:IsStudio() then return end
	local now = os.clock()
	if now - lastPublish < Showcase.GlobalPublishInterval then return end
	lastPublish = now
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(Showcase.GlobalTopic, {
				JobId = game.JobId, PlayerName = message.PlayerName, UserId = message.UserId, ItemName = itemName,
				Rarity = rarity, RateN = rateN, Kind = kind,
			})
		end)
	end)
end

function AnnouncementService.Start()
	if started or RunService:IsStudio() then return end
	started = true
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(Showcase.GlobalTopic, function(packet)
				local data = packet.Data
				-- This server already showed its own pull as a server announcement.
				if not valid(data) or data.JobId == game.JobId then return end
				if #Players:GetPlayers() == 0 then return end
				Remote:FireAllClients("Announce", {
					PlayerName = data.PlayerName, UserId = data.UserId, ItemName = data.ItemName,
					Rarity = data.Rarity, RateN = data.RateN, Kind = data.Kind, Global = true,
				})
			end)
		end)
	end)
end

return AnnouncementService
