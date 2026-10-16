--!strict
-- Shows rare-pull announcements from the server as stacked banners and as a
-- system chat line. Server and cross-server messages share one format.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.Shared
local Remote = require(Shared.Remotes).Get()
local FormatNumber = require(Shared.Util.FormatNumber)
local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Components = require(UI.Components)
local Colors = Theme.Colors

local player = Players.LocalPlayer
local AnnouncementController = {}
local MAX_BANNERS = 3
local BANNER_SECONDS = 5
local BANNER_HEIGHT = 46

local container: Frame? = nil
local banners: {Frame} = {}

local function layout()
	for index, banner in banners do
		TweenService:Create(banner, Theme.Motion.Panel, {Position = UDim2.new(0.5, 0, 0, (index - 1) * (BANNER_HEIGHT + 6))}):Play()
	end
end

local function remove(banner: Frame)
	local index = table.find(banners, banner)
	if not index then return end
	table.remove(banners, index)
	local tween = TweenService:Create(banner, Theme.Motion.Quick, {BackgroundTransparency = 1})
	tween:Play()
	for _, d in banner:GetDescendants() do
		if d:IsA("TextLabel") then TweenService:Create(d, Theme.Motion.Quick, {TextTransparency = 1}):Play() end
	end
	tween.Completed:Once(function() banner:Destroy() end)
	layout()
end

local function text(message: any): string
	local odds = "1 in " .. FormatNumber(message.RateN)
	return string.format("%s pulled <font color=\"#%s\"><b>%s</b></font> (%s)", message.PlayerName,
		Theme.RarityColor(message.Rarity):ToHex(), message.ItemName, odds)
end

local function show(message: any)
	if not container then return end
	local color = Theme.RarityColor(message.Rarity)
	local banner = Components.Panel(container, UDim2.new(1, 0, 0, BANNER_HEIGHT), UDim2.new(0.5, 0, 0, -BANNER_HEIGHT), true)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = color
	stripe.BorderSizePixel = 0
	stripe.Size = UDim2.new(0, 4, 1, 0)
	stripe.Parent = banner
	local kicker = (if message.Global then "GLOBAL  •  " else "") .. string.upper(message.Rarity) .. " " .. string.upper(message.Kind)
	Components.Label(banner, kicker, UDim2.new(1, -24, 0, 14), UDim2.fromOffset(14, 5), Theme.Font.Strong, 9, color, Enum.TextXAlignment.Left)
	local line = Components.Label(banner, "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(14, 19), Theme.Font.Medium, 13, Colors.Cream, Enum.TextXAlignment.Left)
	line.RichText = true
	line.TextTruncate = Enum.TextTruncate.AtEnd
	line.Text = text(message)
	table.insert(banners, 1, banner)
	while #banners > MAX_BANNERS do remove(banners[#banners]) end
	layout()
	task.delay(BANNER_SECONDS, remove, banner)

	-- Mirror into chat for players who missed the banner.
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local system = channels and channels:FindFirstChild("RBXSystem")
		if system and system:IsA("TextChannel") then
			system:DisplaySystemMessage(text(message))
		end
	end)
end

local function valid(message: any): boolean
	return type(message) == "table" and type(message.PlayerName) == "string" and type(message.ItemName) == "string"
		and type(message.Rarity) == "string" and type(message.Kind) == "string"
		and type(message.RateN) == "number" and message.RateN == message.RateN and message.RateN >= 1
end

-- The player's own pull would spoil their reveal, so it waits until the
-- reveal panel closes (UIController sets RevealOpen).
local held: {any} = {}
local function receive(message: any)
	if message.UserId == player.UserId and player:GetAttribute("RevealOpen") == true then
		table.insert(held, message)
	else
		show(message)
	end
end

function AnnouncementController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RarePullAnnouncements"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	-- Sit in the free strip at the very top so banners never cover the reveal panel.
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 6)
	frame.Size = UDim2.new(0, 420, 0, MAX_BANNERS * (BANNER_HEIGHT + 6))
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, math.huge)
	limit.Parent = frame
	frame.Size = UDim2.new(1, -24, 0, MAX_BANNERS * (BANNER_HEIGHT + 6))
	container = frame
	Remote.OnClientEvent:Connect(function(action: string, payload: any)
		if action == "Announce" and valid(payload) then receive(payload) end
	end)
	player:GetAttributeChangedSignal("RevealOpen"):Connect(function()
		if player:GetAttribute("RevealOpen") == true then return end
		local pending = held
		held = {}
		for _, message in pending do show(message) end
	end)
end

return AnnouncementController
