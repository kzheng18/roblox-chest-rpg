--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = game.ReplicatedStorage.Shared
local Remote = require(Shared.Remotes).Get()
local FormatNumber = require(Shared.Util.FormatNumber)
local Progression = require(Shared.Util.Progression)
local Regions = require(Shared.Config.Regions)
local Weapons = require(Shared.Config.Weapons)
local Economy = require(Shared.Config.Economy)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Components = require(UI.Components)
local Colors = Theme.Colors

local UIController = {}

local state: any = nil
local refs: {[string]: any} = {}
local currentScreen: string? = nil
local toastToken = 0
local revealToken = 0
local rebirthConfirmToken = 0

local NAV_ITEMS = {"Inventory", "Chest", "Regions", "Rebirth", "Settings"}

local function setZ(instance: GuiObject, z: number)
	instance.ZIndex = z
	for _, child in instance:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = z + 1
		end
	end
end

local function makeShadow(parent: Instance, size: UDim2, position: UDim2, radius: number): Frame
	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = Colors.Shadow
	shadow.BackgroundTransparency = 0.58
	shadow.BorderSizePixel = 0
	shadow.Size = size
	shadow.Position = position + UDim2.fromOffset(0, 5)
	shadow.Parent = parent
	Components.Corner(shadow, radius)
	return shadow
end

local function titleRule(parent: Instance, position: UDim2, width: UDim2, accent: Color3)
	local line = Instance.new("Frame")
	line.BackgroundColor3 = accent
	line.BackgroundTransparency = 0.18
	line.BorderSizePixel = 0
	line.Size = width
	line.Position = position
	line.Parent = parent
	Components.Gradient(line, accent, accent:Lerp(Colors.Panel, 0.8), 0)
end

local function makeStat(parent: Instance, title: string, color: Color3, index: number): TextLabel
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Colors.Ink
	card.BackgroundTransparency = 0.30
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1 / 3, -8, 1, -18)
	card.Position = UDim2.new((index - 1) / 3, 4 + (index - 1) * 4, 0, 9)
	card.Parent = parent
	Components.Corner(card, 9)

	local label = Components.Label(card, title, UDim2.new(1, -18, 0, 18), UDim2.fromOffset(10, 6), Theme.Font.Strong, 10, color)
	label.TextTransparency = 0.05
	local value = Components.Label(card, "0", UDim2.new(1, -18, 0, 28), UDim2.fromOffset(10, 22), Theme.Font.Display, 19, Colors.Cream)
	return value
end

local function setButtonEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.Selectable = enabled
	button.TextTransparency = if enabled then 0 else 0.42
	button.BackgroundTransparency = if enabled then 0 else 0.28
end

local function nextLockedRegion(): any?
	if not state then return nil end
	for _, region in Regions.List do
		if state.UnlockedRegions[region.Id] ~= true then
			return region
		end
	end
	return nil
end

local function clearBody()
	local body = refs.ModalBody :: ScrollingFrame
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	body.CanvasPosition = Vector2.zero
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body
	Components.Padding(body, 2, 2)
end

local function addSectionIntro(title: string, subtitle: string, accent: Color3?): Frame
	local body = refs.ModalBody :: ScrollingFrame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -8, 0, 55)
	frame.LayoutOrder = 1
	frame.Parent = body
	Components.Label(frame, title, UDim2.new(1, 0, 0, 24), UDim2.new(), Theme.Font.Strong, 16, accent or Colors.Cream)
	local sub = Components.Label(frame, subtitle, UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 25), Theme.Font.Body, 12, Colors.Muted)
	sub.TextWrapped = true
	sub.TextYAlignment = Enum.TextYAlignment.Top
	return frame
end

local function updateNavigationState()
	for name, button in refs.NavButtons do
		local active = currentScreen == name
		button.TextColor3 = if active then Colors.Gold else Colors.Cream
		local marker = button:FindFirstChild("ActiveMarker") :: Frame?
		if marker then marker.Visible = active end
	end
end

local function closeModal()
	currentScreen = nil
	refs.ModalOverlay.Visible = false
	GuiService.SelectedObject = nil
	updateNavigationState()
end

local function makeWeaponCard(parent: Instance, weapon: any, count: number, equipped: boolean): TextButton
	local rarityColor = Theme.RarityColor(weapon.Rarity)
	local card = Components.Button(parent, "", UDim2.new(), UDim2.new(), Colors.PanelRaised)
	card.Text = ""
	card.ClipsDescendants = true
	card.BackgroundColor3 = if equipped then rarityColor:Lerp(Colors.Panel, 0.78) else Colors.PanelRaised

	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = rarityColor
	stripe.BorderSizePixel = 0
	stripe.Size = UDim2.fromOffset(4, 122)
	stripe.Position = UDim2.fromOffset(0, 13)
	stripe.Parent = card
	Components.Corner(stripe, 999)

	local rarity = Components.Label(card, string.upper(weapon.Rarity), UDim2.new(0.58, -18, 0, 18), UDim2.fromOffset(16, 10), Theme.Font.Strong, 10, rarityColor)
	rarity.TextTruncate = Enum.TextTruncate.None
	local owned = Components.Pill(card, "x" .. tostring(count), Colors.Muted)
	owned.Size = UDim2.fromOffset(46, 22)
	owned.Position = UDim2.new(1, -58, 0, 8)

	local name = Components.Label(card, weapon.Name, UDim2.new(1, -30, 0, 38), UDim2.fromOffset(16, 32), Theme.Font.Strong, 15, Colors.Cream)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextTruncate = Enum.TextTruncate.None

	Components.Label(card, weapon.Family, UDim2.new(0.55, -16, 0, 18), UDim2.fromOffset(16, 76), Theme.Font.Body, 11, Colors.Muted)
	local multiplier = Components.Label(card, string.format("x%.2f Power", weapon.PowerMultiplier), UDim2.new(0.45, -16, 0, 18), UDim2.new(0.55, 0, 0, 76), Theme.Font.Strong, 11, Colors.Green, Enum.TextXAlignment.Right)
	multiplier.TextTruncate = Enum.TextTruncate.None

	Components.Label(card, "RARITY", UDim2.new(0.5, -16, 0, 16), UDim2.fromOffset(16, 101), Theme.Font.Strong, 9, Colors.Faint)
	Components.Label(card, "1/" .. tostring(weapon.RateN), UDim2.new(0.5, -16, 0, 22), UDim2.fromOffset(16, 115), Theme.Font.Display, 14, rarityColor)
	local status = Components.Pill(card, if equipped then "EQUIPPED" else "EQUIP", if equipped then Colors.Green else Colors.Gold)
	status.Size = UDim2.fromOffset(78, 24)
	status.Position = UDim2.new(1, -90, 1, -34)
	return card
end

local function buildInventory()
	clearBody()
	addSectionIntro("Weapon Collection", "Equip a weapon to multiply every Power gain. Rarity is always shown as 1/N.", Colors.Gold)
	local body = refs.ModalBody :: ScrollingFrame

	local summary = Components.Panel(body, UDim2.new(1, -8, 0, 66), UDim2.new(), true)
	summary.LayoutOrder = 2
	local equipped = Weapons.ById[state.EquippedWeapon]
	Components.Label(summary, "CURRENT WEAPON", UDim2.new(0.48, -18, 0, 16), UDim2.fromOffset(14, 9), Theme.Font.Strong, 9, Colors.Faint)
	Components.Label(summary, if equipped then equipped.Name else "No weapon equipped", UDim2.new(0.52, -18, 0, 26), UDim2.fromOffset(14, 27), Theme.Font.Strong, 14, if equipped then Theme.RarityColor(equipped.Rarity) else Colors.Muted)
	local best = Components.Button(summary, "EQUIP BEST", UDim2.fromOffset(146, 40), UDim2.new(1, -160, 0.5, -20), Colors.GoldSoft)
	best.Activated:Connect(function() Remote:FireServer("EquipBest") end)

	local ids = {}
	for id, count in state.OwnedWeapons do
		if count > 0 and Weapons.ById[id] then table.insert(ids, id) end
	end
	table.sort(ids, function(a, b)
		local wa = Weapons.ById[a]
		local wb = Weapons.ById[b]
		if wa.PowerMultiplier == wb.PowerMultiplier then return wa.RateN > wb.RateN end
		return wa.PowerMultiplier > wb.PowerMultiplier
	end)

	if #ids == 0 then
		local empty = Components.Panel(body, UDim2.new(1, -8, 0, 124), UDim2.new(), false)
		empty.LayoutOrder = 3
		Components.Label(empty, "YOUR FIRST WEAPON AWAITS", UDim2.new(1, -30, 0, 24), UDim2.fromOffset(15, 24), Theme.Font.Strong, 14, Colors.Gold, Enum.TextXAlignment.Center)
		local note = Components.Label(empty, "Open the Verdant chest to begin your collection.", UDim2.new(1, -40, 0, 42), UDim2.fromOffset(20, 54), Theme.Font.Body, 13, Colors.Muted, Enum.TextXAlignment.Center)
		note.TextWrapped = true
		return
	end

	local columns = if refs.IsCompact then 1 else 2
	local gridFrame = Instance.new("Frame")
	gridFrame.BackgroundTransparency = 1
	gridFrame.Size = UDim2.new(1, -8, 0, math.ceil(#ids / columns) * 154 - 8)
	gridFrame.LayoutOrder = 3
	gridFrame.Parent = body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / columns, if columns == 1 then 0 else -5, 0, 146)
	grid.CellPadding = UDim2.fromOffset(10, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame

	for order, id in ids do
		local weapon = Weapons.ById[id]
		local card = makeWeaponCard(gridFrame, weapon, state.OwnedWeapons[id], state.EquippedWeapon == id)
		card.LayoutOrder = order
		card.Activated:Connect(function()
			Remote:FireServer("EquipWeapon", id)
		end)
	end
end

local function buildChest()
	clearBody()
	local region = Regions.ById[state.CurrentRegion]
	if not region then return end
	addSectionIntro(region.Name .. " Treasure", "Luck improves your live 1/N rates. The reward itself is always selected on the server.", region.Accent)
	local body = refs.ModalBody :: ScrollingFrame

	local compact = refs.IsCompact == true
	local hero = Components.Panel(body, UDim2.new(1, -8, 0, if compact then 132 else 86), UDim2.new(), true)
	hero.LayoutOrder = 2
	titleRule(hero, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 3), region.Accent)
	Components.Label(hero, "CHEST COST", UDim2.new(0.5, -18, 0, 18), UDim2.fromOffset(16, 14), Theme.Font.Strong, 9, Colors.Faint)
	Components.Label(hero, FormatNumber(region.ChestCost) .. " Gold", UDim2.new(0.5, -18, 0, 26), UDim2.fromOffset(16, 32), Theme.Font.Display, 18, Colors.Gold)
	Components.Label(hero, string.format("Luck x%.2f", state.Luck), UDim2.new(0.5, -18, 0, 20), UDim2.fromOffset(16, 59), Theme.Font.Medium, 11, Colors.Green)
	local open = Components.Button(
		hero,
		"OPEN CHEST",
		if compact then UDim2.new(1, -32, 0, 42) else UDim2.fromOffset(164, 48),
		if compact then UDim2.fromOffset(16, 78) else UDim2.new(1, -180, 0.5, -24),
		region.Accent:Lerp(Colors.Panel, 0.45)
	)
	setButtonEnabled(open, state.Gold >= region.ChestCost)
	open.Text = if state.Gold >= region.ChestCost then "OPEN CHEST" else "NEED " .. FormatNumber(region.ChestCost - state.Gold) .. " GOLD"
	open.TextSize = if state.Gold >= region.ChestCost then 14 else 10
	open.Activated:Connect(function()
		Remote:FireServer("OpenChest", region.Id)
	end)

	local pool = table.clone(Weapons.ByRegion[region.Id] or {})
	table.sort(pool, function(a, b) return a.RateN < b.RateN end)
	for index, weapon in pool do
		local rarityColor = Theme.RarityColor(weapon.Rarity)
		local row = Components.Panel(body, UDim2.new(1, -8, 0, 64), UDim2.new(), false)
		row.LayoutOrder = 2 + index
		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = rarityColor
		stripe.BorderSizePixel = 0
		stripe.Size = UDim2.fromOffset(3, 42)
		stripe.Position = UDim2.fromOffset(10, 11)
		stripe.Parent = row
		Components.Corner(stripe, 999)
		Components.Label(row, weapon.Name, UDim2.new(0.50, -22, 0, 22), UDim2.fromOffset(22, 10), Theme.Font.Strong, 13, Colors.Cream)
		Components.Label(row, weapon.Rarity .. "  /  " .. weapon.Family, UDim2.new(0.50, -22, 0, 18), UDim2.fromOffset(22, 34), Theme.Font.Body, 10, rarityColor)
		local liveRate = Progression.CurrentRateN(weapon, state.Luck)
		Components.Label(row, "LIVE RATE", UDim2.new(0.23, 0, 0, 14), UDim2.new(0.55, 0, 0, 9), Theme.Font.Strong, 8, Colors.Faint, Enum.TextXAlignment.Right)
		Components.Label(row, "1/" .. tostring(liveRate), UDim2.new(0.23, 0, 0, 24), UDim2.new(0.55, 0, 0, 24), Theme.Font.Display, 15, rarityColor, Enum.TextXAlignment.Right)
		Components.Label(row, string.format("x%.2f", weapon.PowerMultiplier), UDim2.new(0.16, -12, 0, 26), UDim2.new(0.84, 0, 0.5, -13), Theme.Font.Strong, 12, Colors.Green, Enum.TextXAlignment.Right)
	end
end

local function buildRegions()
	clearBody()
	local nextRegion = nextLockedRegion()
	local subtitle = if nextRegion then "Your next milestone is " .. nextRegion.Name .. ". Reach its Power requirement to unlock travel." else "Every known region is unlocked. Continue growing toward your next Rebirth."
	addSectionIntro("World Progression", subtitle, Colors.Blue)
	local body = refs.ModalBody :: ScrollingFrame

	for index, region in Regions.List do
		local compact = refs.IsCompact == true
		local unlocked = state.UnlockedRegions[region.Id] == true
		local current = state.CurrentRegion == region.Id
		local progress = if region.RequiredPower <= 0 then 1 else math.clamp(state.Power / region.RequiredPower, 0, 1)
		local row = Components.Panel(body, UDim2.new(1, -8, 0, if compact then 150 else 114), UDim2.new(), true)
		row.LayoutOrder = 1 + index
		titleRule(row, UDim2.fromOffset(0, 0), UDim2.new(0, 4, 1, 0), region.Accent)
		Components.Label(row, string.upper(region.Name), if compact then UDim2.new(1, -126, 0, 24) else UDim2.new(0.62, -26, 0, 24), UDim2.fromOffset(18, 10), Theme.Font.Strong, if compact then 12 else 14, if unlocked then Colors.Cream else Colors.Muted)
		local statusText = if current then "CURRENT" elseif unlocked then "UNLOCKED" elseif progress >= 1 then "READY" else "LOCKED"
		local statusColor = if current then Colors.Gold elseif unlocked then Colors.Green elseif progress >= 1 then region.Accent else Colors.Muted
		local pill = Components.Pill(row, statusText, statusColor)
		pill.Position = UDim2.new(1, -104, 0, 9)

		local requirement = if region.RequiredPower <= 0 then "Starting region" else FormatNumber(state.Power) .. " / " .. FormatNumber(region.RequiredPower) .. " Power"
		Components.Label(row, requirement, if compact then UDim2.new(1, -36, 0, 18) else UDim2.new(0.62, -26, 0, 18), UDim2.fromOffset(18, 39), Theme.Font.Body, 11, Colors.Muted)
		local _, fill = Components.Progress(row, if compact then UDim2.new(1, -36, 0, 8) else UDim2.new(0.62, -28, 0, 8), UDim2.fromOffset(18, 64), progress, region.Accent)
		fill.BackgroundTransparency = if unlocked then 0 else 0.08
		local progressText = if unlocked then "Travel available" else string.format("%d%% complete", math.floor(progress * 100))
		Components.Label(row, progressText, UDim2.new(0.62, -26, 0, 18), UDim2.fromOffset(18, 78), Theme.Font.Medium, 10, if unlocked then Colors.Green else Colors.Muted)

		local actionText = if current then "YOU ARE HERE" elseif unlocked then "TRAVEL" elseif progress >= 1 then "UNLOCK" else FormatNumber(math.max(0, region.RequiredPower - state.Power)) .. " LEFT"
		local action = Components.Button(
			row,
			actionText,
			if compact then UDim2.new(1, -36, 0, 38) else UDim2.fromOffset(150, 44),
			if compact then UDim2.fromOffset(18, 102) else UDim2.new(1, -164, 1, -56),
			region.Accent:Lerp(Colors.Panel, 0.48)
		)
		action.TextSize = if #actionText > 12 then 10 else 13
		setButtonEnabled(action, not current and (unlocked or progress >= 1))
		action.Activated:Connect(function()
			Remote:FireServer(if unlocked then "TravelRegion" else "UnlockRegion", region.Id)
		end)
	end
end

local function buildRebirth()
	clearBody()
	addSectionIntro("Rebirth", "Reset your run progression for permanent growth while keeping your weapon collection.", Colors.Gold)
	local body = refs.ModalBody :: ScrollingFrame
	local progress = math.clamp(state.Power / Economy.RebirthPowerRequirement, 0, 1)

	local hero = Components.Panel(body, UDim2.new(1, -8, 0, 160), UDim2.new(), true)
	hero.LayoutOrder = 2
	titleRule(hero, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 3), Colors.Gold)
	Components.Label(hero, "REBIRTH " .. tostring(state.Rebirths + 1), UDim2.new(0.55, -20, 0, 24), UDim2.fromOffset(16, 16), Theme.Font.Display, 18, Colors.Gold)
	Components.Label(hero, tostring(state.Rebirths) .. " completed", UDim2.new(0.45, -20, 0, 20), UDim2.new(0.55, 0, 0, 18), Theme.Font.Medium, 11, Colors.Muted, Enum.TextXAlignment.Right)
	Components.Label(hero, FormatNumber(state.Power) .. " / " .. FormatNumber(Economy.RebirthPowerRequirement) .. " Power", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 50), Theme.Font.Strong, 12, Colors.Cream)
	Components.Progress(hero, UDim2.new(1, -32, 0, 10), UDim2.fromOffset(16, 76), progress, Colors.Gold)
	Components.Label(hero, string.format("%d%% complete", math.floor(progress * 100)), UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 92), Theme.Font.Medium, 10, Colors.Muted)

	local action = Components.Button(hero, if progress >= 1 then "REBIRTH NOW" else FormatNumber(Economy.RebirthPowerRequirement - state.Power) .. " POWER REMAINING", UDim2.new(1, -32, 0, 38), UDim2.fromOffset(16, 116), if progress >= 1 then Colors.GoldSoft else Colors.PanelSoft)
	setButtonEnabled(action, progress >= 1)
	action.TextSize = if progress >= 1 then 14 else 11
	action.Activated:Connect(function()
		if progress < 1 then return end
		rebirthConfirmToken += 1
		local token = rebirthConfirmToken
		if action:GetAttribute("Confirm") ~= true then
			action:SetAttribute("Confirm", true)
			action.Text = "CONFIRM REBIRTH"
			action.BackgroundColor3 = Colors.Danger:Lerp(Colors.Panel, 0.42)
			task.delay(4, function()
				if token == rebirthConfirmToken and action.Parent then
					action:SetAttribute("Confirm", false)
					action.Text = "REBIRTH NOW"
					action.BackgroundColor3 = Colors.GoldSoft
				end
			end)
			return
		end
		Remote:FireServer("Rebirth")
	end)

	local benefits = Components.Panel(body, UDim2.new(1, -8, 0, 136), UDim2.new(), false)
	benefits.LayoutOrder = 3
	Components.Label(benefits, "PERMANENT GAINS EACH REBIRTH", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 12), Theme.Font.Strong, 10, Colors.Faint)
	local gainTexts = {
		string.format("+%d%% Power gain", math.floor(Economy.PowerPerRebirth * 100 + 0.5)),
		string.format("+%d%% Gold gain", math.floor(Economy.GoldPerRebirth * 100 + 0.5)),
		string.format("+%.2f Luck", Economy.LuckPerRebirth),
	}
	for i, value in gainTexts do
		local stat = Components.Panel(benefits, UDim2.new(1 / 3, -12, 0, 56), UDim2.new((i - 1) / 3, 8 + (i - 1) * 4, 0, 38), true)
		Components.Label(stat, value, UDim2.new(1, -12, 1, -12), UDim2.fromOffset(6, 6), Theme.Font.Strong, 11, if i == 3 then Colors.Green else Colors.Gold, Enum.TextXAlignment.Center).TextWrapped = true
	end
	Components.Label(benefits, "Weapons stay. Run Power, Gold, and region access reset.", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 103), Theme.Font.Body, 10, Colors.Muted, Enum.TextXAlignment.Center)
end

local function makeToggleCard(parent: Instance, order: number, title: string, description: string, key: string, value: boolean)
	local card = Components.Panel(parent, UDim2.new(1, -8, 0, 76), UDim2.new(), true)
	card.LayoutOrder = order
	Components.Label(card, title, UDim2.new(1, -136, 0, 22), UDim2.fromOffset(14, 11), Theme.Font.Strong, 13, Colors.Cream)
	local note = Components.Label(card, description, UDim2.new(1, -136, 0, 32), UDim2.fromOffset(14, 34), Theme.Font.Body, 10, Colors.Muted)
	note.TextWrapped = true
	note.TextYAlignment = Enum.TextYAlignment.Top
	local toggle = Components.Button(card, if value then "ON" else "OFF", UDim2.fromOffset(92, 42), UDim2.new(1, -106, 0.5, -21), if value then Colors.Green:Lerp(Colors.Panel, 0.35) else Colors.PanelSoft)
	toggle.TextColor3 = if value then Colors.Green else Colors.Muted
	toggle.Activated:Connect(function()
		Remote:FireServer("Setting", {Key = key, Value = not value})
	end)
end

local function buildSettings()
	clearBody()
	addSectionIntro("Settings", "Tune presentation and accessibility. These preferences save with your profile.", Colors.Green)
	local body = refs.ModalBody :: ScrollingFrame
	makeToggleCard(body, 2, "Chest reveal animation", "Show the rolling sequence before the server-selected reward appears.", "RollAnimation", state.Settings.RollAnimation)
	makeToggleCard(body, 3, "Reduced motion", "Shortens panel and reward motion while keeping gameplay feedback readable.", "ReducedMotion", state.Settings.ReducedMotion)

	local volume = Components.Panel(body, UDim2.new(1, -8, 0, 100), UDim2.new(), true)
	volume.LayoutOrder = 4
	Components.Label(volume, "Master volume", UDim2.new(0.55, -14, 0, 22), UDim2.fromOffset(14, 10), Theme.Font.Strong, 13, Colors.Cream)
	local percent = math.floor(state.Settings.Volume * 100 + 0.5)
	Components.Label(volume, tostring(percent) .. "%", UDim2.new(0.45, -14, 0, 22), UDim2.new(0.55, 0, 0, 10), Theme.Font.Display, 14, Colors.Gold, Enum.TextXAlignment.Right)
	Components.Label(volume, "Global audio preference for music, ambience, and effects.", UDim2.new(1, -160, 0, 30), UDim2.fromOffset(14, 35), Theme.Font.Body, 10, Colors.Muted).TextWrapped = true

	local minus = Components.Button(volume, "-", UDim2.fromOffset(42, 38), UDim2.new(1, -142, 0, 45), Colors.PanelSoft)
	local plus = Components.Button(volume, "+", UDim2.fromOffset(42, 38), UDim2.new(1, -52, 0, 45), Colors.PanelSoft)
	local meter = Instance.new("Frame")
	meter.BackgroundColor3 = Colors.Ink
	meter.BackgroundTransparency = 0.18
	meter.BorderSizePixel = 0
	meter.Size = UDim2.fromOffset(40, 8)
	meter.Position = UDim2.new(1, -96, 0, 60)
	meter.Parent = volume
	Components.Corner(meter, 999)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Colors.Gold
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(state.Settings.Volume, 0, 1, 0)
	fill.Parent = meter
	Components.Corner(fill, 999)

	local function adjust(delta: number)
		local nextValue = math.clamp(math.round((state.Settings.Volume + delta) * 10) / 10, 0, 1)
		Remote:FireServer("Setting", {Key = "Volume", Value = nextValue})
	end
	minus.Activated:Connect(function() adjust(-0.1) end)
	plus.Activated:Connect(function() adjust(0.1) end)
	setButtonEnabled(minus, state.Settings.Volume > 0)
	setButtonEnabled(plus, state.Settings.Volume < 1)
end

local screenBuilders = {
	Inventory = buildInventory,
	Chest = buildChest,
	Regions = buildRegions,
	Rebirth = buildRebirth,
	Settings = buildSettings,
}

local function showScreen(which: string)
	if not state then return end
	local builder = screenBuilders[which]
	if not builder then return end
	currentScreen = which
	refs.ModalTitle.Text = which == "Chest" and "Treasure Chest" or which
	refs.ModalKicker.Text = if which == "Inventory" then "COLLECTION" elseif which == "Chest" then "TREASURE" elseif which == "Regions" then "WORLD MAP" elseif which == "Rebirth" then "ASCENSION" else "PREFERENCES"
	refs.ModalOverlay.Visible = true
	refs.ModalOverlay.BackgroundTransparency = 1
	TweenService:Create(refs.ModalOverlay, Theme.Motion.Quick, {BackgroundTransparency = 0.38}):Play()
	builder()
	updateNavigationState()
	local firstButton = (refs.ModalBody :: ScrollingFrame):FindFirstChildWhichIsA("GuiButton", true)
	if UserInputService.GamepadEnabled and firstButton then
		GuiService.SelectedObject = firstButton
	end
end

local function refreshModal()
	if currentScreen and refs.ModalOverlay.Visible then
		local builder = screenBuilders[currentScreen]
		if builder then builder() end
	end
end

local function updateResponsive()
	local gui = refs.Gui :: ScreenGui
	local width = gui.AbsoluteSize.X
	local height = gui.AbsoluteSize.Y
	local compact = width < 760 or height < 560
	refs.IsCompact = compact

	local hud = refs.Hud :: Frame
	local nav = refs.Nav :: Frame
	local action = refs.ActionDock :: Frame
	local objective = refs.Objective :: Frame
	local modal = refs.ModalCard :: Frame
	local navTitle = refs.NavTitle :: TextLabel
	local navSub = refs.NavSub :: TextLabel
	local navButtons = refs.NavButtons :: {[string]: TextButton}
	local hudShadow = refs.HudShadow :: Frame
	local reveal = refs.Reveal :: Frame

	if compact then
		hud.Size = UDim2.new(1, -20, 0, 72)
		hud.Position = UDim2.fromOffset(10, 10)
		hudShadow.Size = UDim2.new(1, -20, 0, 72)
		hudShadow.Position = UDim2.fromOffset(10, 15)
		objective.Size = UDim2.new(1, -28, 0, 34)
		objective.Position = UDim2.new(0.5, 0, 0, 88)
		nav.AnchorPoint = Vector2.new(0, 1)
		nav.Size = UDim2.new(1, -20, 0, 60)
		nav.Position = UDim2.new(0, 10, 1, -10)
		navTitle.Visible = false
		navSub.Visible = false
		for i, name in NAV_ITEMS do
			local button = navButtons[name]
			button.Size = UDim2.new(1 / #NAV_ITEMS, -6, 1, -12)
			button.Position = UDim2.new((i - 1) / #NAV_ITEMS, 3 + (i - 1) * 3, 0, 6)
			button.TextSize = 10
			button.TextXAlignment = Enum.TextXAlignment.Center
			button.Text = string.upper(name)
		end
		action.Size = UDim2.new(1, -20, 0, 76)
		action.Position = UDim2.new(0.5, 0, 1, -82)
		modal.Size = UDim2.new(1, -18, 0.70, 0)
		modal.Position = UDim2.new(0.5, 0, 0.46, 0)
		reveal.Size = UDim2.new(1, -36, 0, 254)
	else
		hud.Size = UDim2.fromOffset(570, 78)
		hud.Position = UDim2.new(0.5, -285, 0, 16)
		hudShadow.Size = UDim2.fromOffset(570, 78)
		hudShadow.Position = UDim2.new(0.5, -285, 0, 21)
		objective.Size = UDim2.fromOffset(520, 36)
		objective.Position = UDim2.new(0.5, 0, 0, 102)
		nav.AnchorPoint = Vector2.new(0, 0.5)
		nav.Size = UDim2.fromOffset(188, 306)
		nav.Position = UDim2.new(0, 18, 0.5, 0)
		navTitle.Visible = true
		navSub.Visible = true
		for i, name in NAV_ITEMS do
			local button = navButtons[name]
			button.Size = UDim2.new(1, -20, 0, 43)
			button.Position = UDim2.fromOffset(10, 50 + (i - 1) * 48)
			button.TextSize = 12
			button.TextXAlignment = Enum.TextXAlignment.Left
			button.Text = "   " .. string.upper(name)
		end
		action.Size = UDim2.fromOffset(384, 88)
		action.Position = UDim2.new(0.5, 0, 1, -28)
		modal.Size = UDim2.new(0.68, 0, 0.72, 0)
		modal.Position = UDim2.new(0.5, 0, 0.51, 0)
		reveal.Size = UDim2.fromOffset(480, 254)
	end
	if currentScreen and state then refreshModal() end
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChestRPGUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	refs.Gui = gui

	local hudShadow = makeShadow(gui, UDim2.fromOffset(570, 78), UDim2.new(0.5, -285, 0, 16), 13)
	hudShadow.Name = "HudShadow"
	refs.HudShadow = hudShadow
	local hud = Components.Panel(gui, UDim2.fromOffset(570, 78), UDim2.new(0.5, -285, 0, 16), true)
	hud.Name = "HeroHud"
	refs.Hud = hud
	titleRule(hud, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 2), Colors.Gold)
	refs.Power = makeStat(hud, "POWER", Colors.Cream, 1)
	refs.Gold = makeStat(hud, "GOLD", Colors.Gold, 2)
	refs.Luck = makeStat(hud, "LUCK", Colors.Green, 3)

	local objective = Components.Panel(gui, UDim2.fromOffset(520, 36), UDim2.new(0.5, 0, 0, 102), false)
	objective.AnchorPoint = Vector2.new(0.5, 0)
	objective.BackgroundTransparency = 0.12
	refs.Objective = objective
	refs.ObjectiveLabel = Components.Label(objective, "Loading progression...", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), Theme.Font.Medium, 11, Colors.Muted, Enum.TextXAlignment.Center)

	local nav = Components.Panel(gui, UDim2.fromOffset(188, 306), UDim2.new(0, 18, 0.5, 0), true)
	nav.AnchorPoint = Vector2.new(0, 0.5)
	refs.Nav = nav
	refs.NavButtons = {}
	local navTitle = Components.Label(nav, "ADVENTURE", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 10), Theme.Font.Display, 15, Colors.Gold)
	refs.NavTitle = navTitle
	local navSub = Components.Label(nav, "MENU", UDim2.new(1, -24, 0, 14), UDim2.fromOffset(12, 31), Theme.Font.Strong, 8, Colors.Faint)
	refs.NavSub = navSub
	for i, name in NAV_ITEMS do
		local button = Components.Button(nav, string.upper(name), UDim2.new(1, -20, 0, 43), UDim2.fromOffset(10, 50 + (i - 1) * 48), Colors.PanelSoft)
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = "   " .. string.upper(name)
		local marker = Instance.new("Frame")
		marker.Name = "ActiveMarker"
		marker.BackgroundColor3 = Colors.Gold
		marker.BorderSizePixel = 0
		marker.Size = UDim2.fromOffset(3, 20)
		marker.Position = UDim2.new(0, 5, 0.5, -10)
		marker.Visible = false
		marker.Parent = button
		Components.Corner(marker, 999)
		button.Activated:Connect(function() showScreen(name) end)
		refs.NavButtons[name] = button
	end

	local action = Components.Panel(gui, UDim2.fromOffset(384, 88), UDim2.new(0.5, 0, 1, -28), true)
	action.AnchorPoint = Vector2.new(0.5, 1)
	refs.ActionDock = action
	local train = Components.Button(action, "TRAIN", UDim2.new(0.57, -12, 1, -18), UDim2.fromOffset(9, 9), Colors.GoldSoft)
	train.TextSize = 20
	train.Activated:Connect(function() Remote:FireServer("Train") end)
	refs.TrainButton = train
	local chest = Components.Button(action, "OPEN CHEST", UDim2.new(0.43, -6, 1, -18), UDim2.new(0.57, 0, 0, 9), Colors.PanelSoft)
	chest.TextWrapped = true
	chest.TextSize = 13
	chest.Activated:Connect(function()
		if state then Remote:FireServer("OpenChest", state.CurrentRegion) end
	end)
	refs.ChestButton = chest
	local gain = Components.Pill(train, "+0 Power / +0 Gold", Colors.Gold)
	gain.Size = UDim2.new(1, -24, 0, 20)
	gain.Position = UDim2.new(0, 12, 1, -26)
	gain.BackgroundTransparency = 1
	gain.TextSize = 9
	refs.Gain = gain

	local loading = Components.Panel(gui, UDim2.fromOffset(252, 48), UDim2.new(0.5, 0, 0.5, 0), true)
	loading.AnchorPoint = Vector2.new(0.5, 0.5)
	Components.Label(loading, "ENTERING THE REALM...", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), Theme.Font.Strong, 11, Colors.Gold, Enum.TextXAlignment.Center)
	refs.Loading = loading

	local overlay = Instance.new("Frame")
	overlay.Name = "MenuOverlay"
	overlay.BackgroundColor3 = Colors.Shadow
	overlay.BackgroundTransparency = 0.38
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.Parent = gui
	refs.ModalOverlay = overlay
	local dismiss = Instance.new("TextButton")
	dismiss.BackgroundTransparency = 1
	dismiss.Text = ""
	dismiss.Size = UDim2.fromScale(1, 1)
	dismiss.Parent = overlay
	dismiss.Activated:Connect(closeModal)
	local modal = Components.Panel(overlay, UDim2.new(0.68, 0, 0.72, 0), UDim2.new(0.5, 0, 0.51, 0), true)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.ClipsDescendants = true
	refs.ModalCard = modal
	setZ(overlay, 50)
	titleRule(modal, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 3), Colors.Gold)
	refs.ModalKicker = Components.Label(modal, "COLLECTION", UDim2.new(1, -110, 0, 15), UDim2.fromOffset(22, 13), Theme.Font.Strong, 9, Colors.Gold)
	refs.ModalTitle = Components.Label(modal, "Inventory", UDim2.new(1, -110, 0, 32), UDim2.fromOffset(22, 28), Theme.Font.Display, 23, Colors.Cream)
	local close = Components.Button(modal, "X", UDim2.fromOffset(42, 36), UDim2.new(1, -56, 0, 14), Colors.PanelSoft)
	close.TextSize = 14
	close.Activated:Connect(closeModal)

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundColor3 = Colors.Ink
	body.BackgroundTransparency = 0.72
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, -28, 1, -78)
	body.Position = UDim2.fromOffset(14, 66)
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = Colors.GoldSoft
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = modal
	Components.Corner(body, 10)
	refs.ModalBody = body

	local toast = Components.Panel(gui, UDim2.fromOffset(420, 48), UDim2.new(0.5, 0, 0, 150), true)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Visible = false
	toast.BackgroundTransparency = 0.04
	setZ(toast, 75)
	refs.Toast = toast
	refs.ToastLabel = Components.Label(toast, "", UDim2.new(1, -28, 1, 0), UDim2.fromOffset(14, 0), Theme.Font.Strong, 12, Colors.Cream, Enum.TextXAlignment.Center)

	local revealOverlay = Instance.new("Frame")
	revealOverlay.BackgroundColor3 = Colors.Shadow
	revealOverlay.BackgroundTransparency = 0.25
	revealOverlay.BorderSizePixel = 0
	revealOverlay.Size = UDim2.fromScale(1, 1)
	revealOverlay.Visible = false
	revealOverlay.Parent = gui
	setZ(revealOverlay, 90)
	refs.RevealOverlay = revealOverlay
	local reveal = Components.Panel(revealOverlay, UDim2.fromOffset(480, 254), UDim2.new(0.5, 0, 0.5, 0), true)
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	refs.Reveal = reveal
	local revealAccent = Instance.new("Frame")
	revealAccent.BackgroundColor3 = Colors.Gold
	revealAccent.BorderSizePixel = 0
	revealAccent.Size = UDim2.new(1, 0, 0, 4)
	revealAccent.Parent = reveal
	refs.RevealAccent = revealAccent
	refs.RevealKicker = Components.Label(reveal, "TREASURE FOUND", UDim2.new(1, -40, 0, 18), UDim2.fromOffset(20, 24), Theme.Font.Strong, 10, Colors.Gold, Enum.TextXAlignment.Center)
	refs.RevealRarity = Components.Label(reveal, "RARITY", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 48), Theme.Font.Strong, 13, Colors.Gold, Enum.TextXAlignment.Center)
	refs.RevealName = Components.Label(reveal, "Weapon", UDim2.new(1, -40, 0, 48), UDim2.fromOffset(20, 77), Theme.Font.Display, 26, Colors.Cream, Enum.TextXAlignment.Center)
	refs.RevealName.TextWrapped = true
	refs.RevealOdds = Components.Label(reveal, "1/1", UDim2.new(1, -40, 0, 32), UDim2.fromOffset(20, 130), Theme.Font.Display, 18, Colors.Green, Enum.TextXAlignment.Center)
	refs.RevealPower = Components.Label(reveal, "x1.00 Power", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 164), Theme.Font.Medium, 12, Colors.Muted, Enum.TextXAlignment.Center)
	local continue = Components.Button(reveal, "CONTINUE", UDim2.fromOffset(150, 38), UDim2.new(0.5, -75, 1, -52), Colors.PanelSoft)
	continue.Activated:Connect(function()
		revealToken += 1
		revealOverlay.Visible = false
	end)
	refs.RevealContinue = continue

	setZ(overlay, 50)
	setZ(toast, 75)
	setZ(revealOverlay, 90)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsive)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.ButtonB and overlay.Visible then
			closeModal()
		end
	end)
	updateResponsive()
end

local function refreshHUD()
	if not state then return end
	(refs.Power :: TextLabel).Text = FormatNumber(state.Power)
	(refs.Gold :: TextLabel).Text = FormatNumber(state.Gold)
	(refs.Luck :: TextLabel).Text = string.format("x%.2f", state.Luck)
	(refs.Gain :: TextLabel).Text = string.format("+%.1f Power  /  +%.1f Gold", state.PowerGain, state.GoldGain)
	refs.Loading.Visible = false

	local currentRegion = Regions.ById[state.CurrentRegion]
	if currentRegion then
		local chest = refs.ChestButton :: TextButton
		local affordable = state.Gold >= currentRegion.ChestCost
		chest.Text = if affordable then "OPEN CHEST\n" .. FormatNumber(currentRegion.ChestCost) .. " GOLD" else "CHEST\nNEED " .. FormatNumber(currentRegion.ChestCost - state.Gold)
		setButtonEnabled(chest, affordable)
	end

	local nextRegion = nextLockedRegion()
	local objective = refs.ObjectiveLabel :: TextLabel
	if nextRegion then
		local progress = math.clamp(state.Power / nextRegion.RequiredPower, 0, 1)
		objective.Text = string.format("NEXT  %s   •   %d%%   •   %s Power remaining", string.upper(nextRegion.Name), math.floor(progress * 100), FormatNumber(math.max(0, nextRegion.RequiredPower - state.Power)))
		objective.TextColor3 = if progress >= 1 then nextRegion.Accent else Colors.Muted
	elseif state.Power >= Economy.RebirthPowerRequirement then
		objective.Text = "REBIRTH READY   •   Permanent Power, Gold, and Luck growth available"
		objective.TextColor3 = Colors.Gold
	else
		local rebirthProgress = math.floor(math.clamp(state.Power / Economy.RebirthPowerRequirement, 0, 1) * 100)
		objective.Text = string.format("NEXT  REBIRTH   •   %d%%   •   %s Power remaining", rebirthProgress, FormatNumber(math.max(0, Economy.RebirthPowerRequirement - state.Power)))
		objective.TextColor3 = Colors.Muted
	end
end

local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	local toast = refs.Toast :: Frame
	local label = refs.ToastLabel :: TextLabel
	label.Text = message
	toast.Visible = true
	toast.Position = UDim2.new(0.5, 0, 0, 138)
	toast.BackgroundTransparency = 0.28
	TweenService:Create(toast, Theme.Motion.Panel, {Position = UDim2.new(0.5, 0, 0, 150), BackgroundTransparency = 0.04}):Play()
	task.delay(2.5, function()
		if token ~= toastToken or not toast.Parent then return end
		local tween = TweenService:Create(toast, Theme.Motion.Quick, {Position = UDim2.new(0.5, 0, 0, 136), BackgroundTransparency = 1})
		tween:Play()
		tween.Completed:Once(function()
			if token == toastToken then toast.Visible = false end
		end)
	end)
end

local function settleReveal(result: any, token: number)
	if token ~= revealToken then return end
	local rarityColor = Theme.RarityColor(result.Rarity)
	refs.RevealAccent.BackgroundColor3 = rarityColor
	(refs.RevealKicker :: TextLabel).Text = "TREASURE FOUND"
	(refs.RevealKicker :: TextLabel).TextColor3 = Colors.Gold
	(refs.RevealRarity :: TextLabel).Text = string.upper(result.Rarity)
	(refs.RevealRarity :: TextLabel).TextColor3 = rarityColor
	(refs.RevealName :: TextLabel).Text = result.Name
	(refs.RevealOdds :: TextLabel).Text = "RARITY  1/" .. tostring(result.RateN)
	(refs.RevealOdds :: TextLabel).TextColor3 = rarityColor
	(refs.RevealPower :: TextLabel).Text = string.format("x%.2f Power   •   %s", result.PowerMultiplier, result.Family)
	local reveal = refs.Reveal :: Frame
	if not (state and state.Settings and state.Settings.ReducedMotion) then
		local finalSize = if refs.IsCompact then UDim2.new(1, -36, 0, 254) else UDim2.fromOffset(480, 254)
		local startSize = if refs.IsCompact then UDim2.new(1, -64, 0, 232) else UDim2.fromOffset(440, 232)
		reveal.Size = startSize
		TweenService:Create(reveal, Theme.Motion.Pop, {Size = finalSize}):Play()
	end
end

local function showChestResult(result: any)
	if state and state.Settings and state.Settings.RollAnimation == false then
		showToast(string.format("%s  •  %s  •  1/%d  •  x%.2f", result.Name, result.Rarity, result.RateN, result.PowerMultiplier))
		return
	end

	revealToken += 1
	local token = revealToken
	local overlay = refs.RevealOverlay :: Frame
	overlay.Visible = true
	local reveal = refs.Reveal :: Frame
	reveal.Size = if refs.IsCompact then UDim2.new(1, -36, 0, 254) else UDim2.fromOffset(480, 254)
	local reduced = state and state.Settings and state.Settings.ReducedMotion
	if reduced then
		settleReveal(result, token)
		return
	end

	(refs.RevealKicker :: TextLabel).Text = "OPENING TREASURE"
	(refs.RevealRarity :: TextLabel).Text = "ROLLING..."
	(refs.RevealName :: TextLabel).Text = "???"
	(refs.RevealOdds :: TextLabel).Text = "Luck is shaping the roll"
	(refs.RevealPower :: TextLabel).Text = ""
	local pool = Weapons.ByRegion[state.CurrentRegion] or Weapons.List
	task.spawn(function()
		for i = 1, 8 do
			if token ~= revealToken then return end
			local candidate = pool[((i * 3 + token) % #pool) + 1]
			local color = Theme.RarityColor(candidate.Rarity)
			(refs.RevealRarity :: TextLabel).Text = string.upper(candidate.Rarity)
			(refs.RevealRarity :: TextLabel).TextColor3 = color
			(refs.RevealName :: TextLabel).Text = candidate.Name
			(refs.RevealOdds :: TextLabel).Text = "RARITY  1/" .. tostring(Progression.CurrentRateN(candidate, state.Luck))
			(refs.RevealOdds :: TextLabel).TextColor3 = color
			task.wait(0.055 + i * 0.012)
		end
		settleReveal(result, token)
	end)
end

function UIController.Start()
	buildUI()
	Remote.OnClientEvent:Connect(function(action: string, payload: any)
		if action == "State" then
			if type(payload) ~= "table" then return end
			if state and type(state.Revision) == "number" and type(payload.Revision) == "number" and payload.Revision < state.Revision then
				return
			end
			state = payload
			refreshHUD()
			refreshModal()
		elseif action == "StateDelta" then
			if type(payload) ~= "table" or type(payload.Changes) ~= "table" or type(payload.Revision) ~= "number" then return end
			if not state then
				Remote:FireServer("RequestState")
				return
			end
			if type(state.Revision) == "number" and payload.Revision <= state.Revision then return end
			local changes = payload.Changes
			for key, value in changes do state[key] = value end
			state.Revision = payload.Revision
			refreshHUD()
			local modalRelevant = changes.OwnedWeapons ~= nil
				or changes.EquippedWeapon ~= nil
				or changes.UnlockedRegions ~= nil
				or changes.CurrentRegion ~= nil
				or changes.Settings ~= nil
				or changes.Rebirths ~= nil
			if modalRelevant then refreshModal() end
		elseif action == "Toast" and type(payload) == "string" then
			showToast(payload)
		elseif action == "ChestResult" and type(payload) == "table" then
			showChestResult(payload)
		end
	end)
	Remote:FireServer("RequestState")
end

return UIController
