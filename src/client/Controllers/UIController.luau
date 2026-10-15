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
local RarityFormat = require(Shared.Util.RarityFormat)
local Regions = require(Shared.Config.Regions)
local Weapons = require(Shared.Config.Weapons)
local Economy = require(Shared.Config.Economy)
local Powers = require(Shared.Config.Powers)
local Showcase = require(Shared.Config.Showcase)
local PowerOdds = require(Shared.Util.PowerOdds)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Components = require(UI.Components)
local Icons = require(UI.Icons)
local ItemModels = require(UI.ItemModels)
local Cinematic = require(script.Parent.CinematicController)
local Colors = Theme.Colors

local UIController = {}

local state: any = nil
local refs: {[string]: any} = {}
local currentScreen: string? = nil
local toastToken = 0
local revealToken = 0
local rebirthConfirmToken = 0
local pendingChest: any = nil
local displayedChestSequence = 0
local showToast: (string) -> ()
local modalStatUpdates: {() -> ()} = {}
local inventoryQuery = ""
local inventorySort = "Power"
local inventorySelectedId: string? = nil
local bodyLayoutConnection: RBXScriptConnection? = nil

local function openChest(regionId: string)
	if not state or pendingChest then return end
	local request = {RegionId = regionId, Sequence = (state.ChestSequence or 0) + 1}
	pendingChest = request
	Remote:FireServer("OpenChest", request)
	-- A network retry reuses the same sequence, never a second purchase.
	task.spawn(function()
		for _ = 1, 3 do
			task.wait(3)
			if pendingChest ~= request then return end
			Remote:FireServer("OpenChest", request)
		end
		task.wait(3)
		if pendingChest == request then
			pendingChest = nil
			Remote:FireServer("RequestState")
			showToast("Connection delayed. Refreshing your inventory before another opening.")
		end
	end)
end

local NAV_ITEMS = {"Inventory", "Chest", "Regions", "Rebirth", "Settings"}
local settleReveal: (any, number) -> ()
local playNextReveal: () -> ()
-- One chest opening can reveal several items (weapon, then bonus power).
local revealQueue: {any} = {}
local activeCinematic: any = nil
local revealModelCleanup: (() -> ())? = nil

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
	card.Name = title .. "Counter"; card.BackgroundTransparency = 1
	card.Size = UDim2.new(1, 0, 1 / 3, 0)
	card.Position = UDim2.new(0, 0, (index - 1) / 3, 0); card.Parent = parent
	Icons.Draw(card, title, UDim2.fromOffset(30, 30), UDim2.fromOffset(0, 2))
	local value = Components.Label(card, "0", UDim2.new(1, -36, 1, 0), UDim2.fromOffset(36, 0), Theme.Font.Display, 22, color)
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
	table.clear(modalStatUpdates)
	local body = refs.ModalBody :: ScrollingFrame
	if bodyLayoutConnection then
		bodyLayoutConnection:Disconnect()
		bodyLayoutConnection = nil
	end
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	body.CanvasPosition = Vector2.zero
	body.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 18)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body
	Components.Padding(body, 17, 17)
	-- Explicit canvas sizing includes both vertical padding edges. It remains
	-- correct when the inventory grid grows after filtering or a resize.
	local function updateCanvas()
		body.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 42)
	end
	bodyLayoutConnection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
	updateCanvas()
end

local function addSectionIntro(title: string, subtitle: string, accent: Color3?): Frame
	local body = refs.ModalBody :: ScrollingFrame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	local narrow = (refs.BodyWidth or body.AbsoluteSize.X) < 330
	frame.Size = UDim2.new(1, -8, 0, if narrow then 106 else 64)
	frame.LayoutOrder = 1
	frame.Parent = body
	Components.Label(frame, title, UDim2.new(1, 0, 0, 24), UDim2.new(), Theme.Font.Strong, 16, accent or Colors.Cream)
	local sub = Components.Label(frame, subtitle, UDim2.new(1, 0, 0, if narrow then 75 else 34), UDim2.fromOffset(0, 25), Theme.Font.Body, 12, Colors.Muted)
	sub.TextWrapped = true
	sub.TextYAlignment = Enum.TextYAlignment.Top
	return frame
end

local function updateNavigationState()
	for name, button in refs.NavButtons do
		local active = currentScreen == name
		button.TextColor3 = if active then Colors.Gold else Colors.Cream
		button.Label.TextColor3 = if active then Colors.Gold else Colors.Cream
		local marker = button:FindFirstChild("ActiveMarker") :: Frame?
		if marker then marker.Visible = active end
		local tab = refs.ModalTabs and refs.ModalTabs[name]
		if tab then
			tab.BackgroundColor3 = if active then Colors.PanelSoft else Colors.Panel
			local label = tab:FindFirstChild("Label") :: TextLabel?
			if label then label.TextColor3 = if active then Colors.Gold else Colors.Muted end
			local tabMarker = tab:FindFirstChild("ActiveMarker") :: Frame?
			if tabMarker then tabMarker.Visible = active end
		end
	end
end

local function closeModal()
	currentScreen = nil
	refs.ModalOverlay.Visible = false
	GuiService.SelectedObject = nil
	updateNavigationState()
end

local function makeWeaponCard(parent: Instance, weapon: any, count: number, equipped: boolean, selected: boolean): TextButton
	local rarityColor = Theme.RarityColor(weapon.Rarity)
	local card = Components.Button(parent, "", UDim2.new(), UDim2.new(), rarityColor:Lerp(Colors.Panel, if selected then 0.65 else 0.91))
	card.Name = "Weapon_" .. weapon.Id
	card.Text = ""
	card.ClipsDescendants = true
	card:SetAttribute("WeaponId", weapon.Id)
	local border = card:FindFirstChildWhichIsA("UIStroke")
	if border then border.Color = if selected then Colors.Gold else Colors.Border end
	Icons.Draw(card, "Power", UDim2.fromOffset(34, 34), UDim2.fromOffset(10, 36))

	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = rarityColor
	stripe.BorderSizePixel = 0
	stripe.Size = UDim2.new(1, 0, 0, 3)
	stripe.Parent = card

	local rarity = Components.Label(card, string.upper(weapon.Rarity), UDim2.new(1, -64, 0, 18), UDim2.fromOffset(10, 9), Theme.Font.Strong, 10, rarityColor)
	rarity.TextTruncate = Enum.TextTruncate.None
	local owned = Components.Pill(card, "x" .. tostring(count), Colors.Faint)
	owned.Size = UDim2.fromOffset(46, 21)
	owned.Position = UDim2.new(1, -54, 0, 7)

	local name = Components.Label(card, weapon.Name, UDim2.new(1, -56, 0, 40), UDim2.fromOffset(51, 31), Theme.Font.Strong, 13, Colors.Cream)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextTruncate = Enum.TextTruncate.None

	Components.Label(card, weapon.Family, UDim2.new(1, -20, 0, 16), UDim2.fromOffset(10, 76), Theme.Font.Body, 10, Colors.Muted)
	Components.Label(card, string.format("x%.2f POWER", weapon.PowerMultiplier), UDim2.new(0.63, -10, 0, 19), UDim2.fromOffset(10, 96), Theme.Font.Strong, 11, Colors.Green)
	if equipped then
		local status = Components.Pill(card, "IN USE", Colors.Green)
		status.Size = UDim2.fromOffset(59, 22)
		status.Position = UDim2.new(1, -66, 1, -28)
	end
	local marker = Components.Label(card, "SELECTED", UDim2.fromOffset(62, 19), UDim2.new(1, -69, 1, -23), Theme.Font.Strong, 9, Colors.Gold, Enum.TextXAlignment.Center)
	marker.Name = "SelectionMarker"
	marker.Visible = selected and not equipped
	marker.TextTruncate = Enum.TextTruncate.None
	return card
end

local function buildInventory()
	clearBody()
	local body = refs.ModalBody :: ScrollingFrame
	local bodyWidth = refs.BodyWidth or body.AbsoluteSize.X
	local stacked = bodyWidth < 640
	local narrow = bodyWidth < 330
	addSectionIntro("THE ARMORY", "Browse your treasure. Select a weapon to inspect it, then equip it.", Colors.Gold)

	local ids: {string} = {}
	local copies = 0
	for id, count in state.OwnedWeapons do
		if count > 0 and Weapons.ById[id] then
			table.insert(ids, id)
			copies += count
		end
	end

	local summary = Components.Panel(body, UDim2.new(1, -8, 0, if narrow then 110 else 70), UDim2.new(), true)
	summary.LayoutOrder = 2
	titleRule(summary, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 3), Colors.Gold)
	local equipped = Weapons.ById[state.EquippedWeapon]
	Components.Label(summary, "CURRENTLY EQUIPPED", UDim2.new(1, if narrow then -28 else -158, 0, 18), UDim2.fromOffset(14, 9), Theme.Font.Strong, 10, Colors.Faint)
	Components.Label(summary, if equipped then equipped.Name else "No weapon equipped", UDim2.new(1, if narrow then -28 else -158, 0, 27), UDim2.fromOffset(14, 28), Theme.Font.Strong, if narrow then 13 else 15, if equipped then Theme.RarityColor(equipped.Rarity) else Colors.Muted)
	local best = Components.Button(summary, "EQUIP BEST", if narrow then UDim2.new(1, -28, 0, 38) else UDim2.fromOffset(126, 43), if narrow then UDim2.fromOffset(14, 65) else UDim2.new(1, -140, 0.5, -21), Colors.GoldSoft)
	best.TextSize = 13
	setButtonEnabled(best, #ids > 0)
	best.Activated:Connect(function()
		if #ids > 0 then Remote:FireServer("EquipBest") end
	end)

	local toolbar = Instance.new("Frame")
	toolbar.Name = "InventoryToolbar"
	toolbar.BackgroundTransparency = 1
	toolbar.Size = UDim2.new(1, -8, 0, if stacked then 92 else 50)
	toolbar.LayoutOrder = 3
	toolbar.Parent = body
	local search = Instance.new("TextBox")
	search.Name = "SearchWeapons"
	search.BackgroundColor3 = Colors.PanelRaised
	search.BorderSizePixel = 0
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Search weapons, families, or rarities..."
	search.PlaceholderColor3 = Colors.Faint
	search.Text = inventoryQuery
	search.TextColor3 = Colors.Cream
	search.TextSize = 13
	search.Font = Theme.Font.Medium
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.Size = if stacked then UDim2.new(1, 0, 0, 42) else UDim2.new(1, -162, 0, 44)
	search.Position = UDim2.fromOffset(0, 2)
	search.Parent = toolbar
	Components.Corner(search, 9)
	Components.Stroke(search, Colors.SurfaceBorder, 0.6, 1)
	Components.Padding(search, 12, 2)
	local sort = Components.Button(toolbar, "", if stacked then UDim2.new(0, if narrow then 126 else 142, 0, 38) else UDim2.fromOffset(152, 44), if stacked then UDim2.fromOffset(0, 51) else UDim2.new(1, -152, 0, 2), Colors.PanelSoft)
	sort.TextSize = 11
	local countLabel = Components.Label(toolbar, "", UDim2.new(1, -146, 0, 38), UDim2.new(0, 146, 0, 51), Theme.Font.Strong, 10, Colors.Muted, Enum.TextXAlignment.Right)
	countLabel.Visible = stacked and not narrow
	local function setSortText()
		sort.Text = "SORT: " .. (if inventorySort == "Power" then "POWER" elseif inventorySort == "Rarity" then "RARITY" else "NAME") .. "  >"
	end
	setSortText()

	if #ids == 0 then
		search.TextEditable = false
		setButtonEnabled(sort, false)
		local empty = Components.Panel(body, UDim2.new(1, -8, 0, 154), UDim2.new(), false)
		empty.LayoutOrder = 4
		Icons.Draw(empty, "Chest", UDim2.fromOffset(58, 58), UDim2.new(0.5, -29, 0, 12))
		Components.Label(empty, "YOUR ADVENTURE STARTS HERE", UDim2.new(1, -28, 0, 26), UDim2.fromOffset(14, 72), Theme.Font.Strong, 15, Colors.Gold, Enum.TextXAlignment.Center)
		Components.Label(empty, "Open a treasure chest to find your first weapon.", UDim2.new(1, -28, 0, 35), UDim2.fromOffset(14, 102), Theme.Font.Body, 12, Colors.Muted, Enum.TextXAlignment.Center).TextWrapped = true
		setSortText()
		countLabel.Text = "0 WEAPONS"
		return
	end

	local content = Instance.new("Frame")
	content.Name = "ArmoryContent"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -8, 0, if narrow then 620 elseif stacked then 520 else 420)
	content.LayoutOrder = 4
	content.Parent = body
	local detailHeight = if narrow then 340 else 240
	local collectionTop = if narrow then 350 else 250
	local details = Components.Panel(content, if stacked then UDim2.new(1, 0, 0, detailHeight) else UDim2.new(0.43, -5, 1, 0), if stacked then UDim2.new() else UDim2.new(0.57, 5, 0, 0), true)
	details.Name = "SelectedWeaponDetails"
	local detailContents = Instance.new("Frame")
	detailContents.BackgroundTransparency = 1
	detailContents.Size = UDim2.fromScale(1, 1)
	detailContents.Parent = details

	local collection = Components.Panel(content, if stacked then UDim2.new(1, 0, 0, 270) else UDim2.new(0.57, -5, 1, 0), if stacked then UDim2.fromOffset(0, collectionTop) else UDim2.new(), false)
	collection.Name = "WeaponCollection"
	local collectionTitle = Components.Label(collection, "YOUR WEAPONS", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 8), Theme.Font.Strong, 13, Colors.Gold)
	local gridScroll = Instance.new("ScrollingFrame")
	gridScroll.Name = "WeaponGrid"
	gridScroll.BackgroundTransparency = 1
	gridScroll.BorderSizePixel = 0
	gridScroll.Position = UDim2.fromOffset(9, 40)
	gridScroll.Size = UDim2.new(1, -18, 1, -48)
	gridScroll.ScrollBarThickness = if stacked then 0 else 3
	gridScroll.ScrollBarImageColor3 = Colors.Gold
	gridScroll.ScrollingEnabled = not stacked
	gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridScroll.CanvasSize = UDim2.new()
	gridScroll.Parent = collection
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	local columns = if stacked and bodyWidth < 390 then 1 else 2
	gridLayout.CellSize = UDim2.new(1 / columns, -6, 0, 123)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gridScroll

	local function sortedMatches(): {string}
		local matches: {string} = {}
		local query = string.lower(string.gsub(inventoryQuery, "^%s*(.-)%s*$", "%1"))
		for _, id in ids do
			local weapon = Weapons.ById[id]
			local region = Regions.ById[weapon.Region]
			local keywords = string.lower(weapon.Name .. " " .. weapon.Rarity .. " " .. weapon.Family .. " " .. (if region then region.Name else ""))
			if query == "" or string.find(keywords, query, 1, true) then table.insert(matches, id) end
		end
		table.sort(matches, function(a: string, b: string): boolean
			local wa, wb = Weapons.ById[a], Weapons.ById[b]
			if inventorySort == "Name" then return wa.Name < wb.Name end
			if inventorySort == "Rarity" and wa.RateN ~= wb.RateN then return wa.RateN > wb.RateN end
			if wa.PowerMultiplier ~= wb.PowerMultiplier then return wa.PowerMultiplier > wb.PowerMultiplier end
			return wa.Name < wb.Name
		end)
		return matches
	end

	local function paintDetails(id: string?)
		for _, child in detailContents:GetChildren() do child:Destroy() end
		local weapon = if id then Weapons.ById[id] else nil
		if not weapon then
			Components.Label(detailContents, "NO MATCHES", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 55), Theme.Font.Strong, 18, Colors.Gold, Enum.TextXAlignment.Center)
			Components.Label(detailContents, "Try another name, family, or rarity.", UDim2.new(1, -30, 0, 56), UDim2.fromOffset(15, 90), Theme.Font.Body, 12, Colors.Muted, Enum.TextXAlignment.Center).TextWrapped = true
			return
		end
		local color = Theme.RarityColor(weapon.Rarity)
		titleRule(detailContents, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 4), color)
		Components.Label(detailContents, "SELECTED EQUIPMENT", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(12, 9), Theme.Font.Strong, 10, Colors.Faint)
		local art = Instance.new("Frame")
		art.BackgroundColor3 = color:Lerp(Colors.Panel, 0.80)
		art.BorderSizePixel = 0
		art.Size = UDim2.fromOffset(if narrow then 64 elseif stacked then 74 else 98, if narrow then 70 elseif stacked then 85 else 120)
		art.Position = if narrow then UDim2.new(.5, -32, 0, 31) else UDim2.fromOffset(12, 34)
		art.Parent = detailContents
		Components.Corner(art, 10)
		Components.Stroke(art, color, 0.45, 1)
		Icons.Draw(art, "Power", UDim2.new(0.75, 0, 0.75, 0), UDim2.fromScale(0.125, 0.12))
		local infoX = if narrow then 12 elseif stacked then 98 else 122
		Components.Label(detailContents, string.upper(weapon.Rarity), UDim2.new(1, -infoX - 12, 0, 19), UDim2.fromOffset(infoX, if narrow then 110 else 34), Theme.Font.Strong, 11, color)
		local name = Components.Label(detailContents, weapon.Name, UDim2.new(1, -infoX - 12, 0, 48), UDim2.fromOffset(infoX, if narrow then 132 else 55), Theme.Font.Strong, if stacked then 15 else 17, Colors.Cream)
		name.TextWrapped = true
		name.TextTruncate = Enum.TextTruncate.None
		name.TextYAlignment = Enum.TextYAlignment.Top
		local region = Regions.ById[weapon.Region]
		Components.Label(detailContents, weapon.Family .. "  •  " .. (if region then region.Name else "Unknown region"), UDim2.new(1, -infoX - 10, 0, 32), UDim2.fromOffset(infoX, if narrow then 181 elseif stacked then 103 else 109), Theme.Font.Body, 10, Colors.Muted).TextWrapped = true
		local statsY = if narrow then 223 elseif stacked then 126 else 172
		Components.Label(detailContents, "POWER BOOST", UDim2.new(0.5, -16, 0, 18), UDim2.fromOffset(12, statsY), Theme.Font.Strong, 9, Colors.Faint)
		Components.Label(detailContents, string.format("x%.2f", weapon.PowerMultiplier), UDim2.new(0.5, -16, 0, 29), UDim2.fromOffset(12, statsY + 17), Theme.Font.Display, 23, Colors.Green)
		Components.Label(detailContents, "BASE CHEST ODDS", UDim2.new(0.5, -16, 0, 18), UDim2.new(0.5, 3, 0, statsY), Theme.Font.Strong, 9, Colors.Faint)
		Components.Label(detailContents, RarityFormat.Rate(weapon.RateN), UDim2.new(0.5, -16, 0, 29), UDim2.new(0.5, 3, 0, statsY + 17), Theme.Font.Display, 18, color)
		local actionY = if narrow then 283 elseif stacked then 184 else 282
		local active = state.EquippedWeapon == weapon.Id
		local equip = Components.Button(detailContents, if active then "EQUIPPED ✓" else "EQUIP WEAPON", UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, actionY), if active then Colors.Success else Colors.GoldSoft)
		equip.TextSize = 14
		setButtonEnabled(equip, not active)
		equip.Activated:Connect(function()
			if state and state.EquippedWeapon ~= weapon.Id and (state.OwnedWeapons[weapon.Id] or 0) > 0 then
				Remote:FireServer("EquipWeapon", weapon.Id)
			end
		end)
		if not stacked then
			Components.Label(detailContents, "Select a card to inspect • Equip to use", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 341), Theme.Font.Body, 10, Colors.Muted, Enum.TextXAlignment.Center)
		end
	end

	local function renderMatches()
		local matches = sortedMatches()
		local selectedExists = false
		for _, id in matches do if id == inventorySelectedId then selectedExists = true break end end
		if not selectedExists then
			inventorySelectedId = if #matches > 0 then matches[1] else nil
		end
		for _, child in gridScroll:GetChildren() do
			if child ~= gridLayout then child:Destroy() end
		end
		for order, id in matches do
			local weapon = Weapons.ById[id]
			local card = makeWeaponCard(gridScroll, weapon, state.OwnedWeapons[id], state.EquippedWeapon == id, id == inventorySelectedId)
			card.LayoutOrder = order
			card.Activated:Connect(function()
				inventorySelectedId = id
				for _, item in gridScroll:GetChildren() do
					if item:IsA("TextButton") then
						local active = item:GetAttribute("WeaponId") == id
			local base = Theme.RarityColor(Weapons.ById[item:GetAttribute("WeaponId")].Rarity):Lerp(Colors.Panel, if active then 0.65 else 0.91)
			item:SetAttribute("ButtonBaseColor", base)
			item.BackgroundColor3 = base
						local stroke = item:FindFirstChildWhichIsA("UIStroke")
						if stroke then stroke.Color = if active then Colors.Gold else Colors.Border end
						local marker = item:FindFirstChild("SelectionMarker")
						if marker and marker:IsA("TextLabel") then marker.Visible = active and item:GetAttribute("WeaponId") ~= state.EquippedWeapon end
					end
				end
				paintDetails(id)
			end)
		end
		collectionTitle.Text = string.format("YOUR WEAPONS  •  %d / %d", #matches, #ids)
		countLabel.Text = string.format("%d UNIQUE  •  %d TOTAL", #ids, copies)
		if stacked then
			local rows = math.max(1, math.ceil(#matches / columns))
			local gridHeight = rows * 123 + (rows - 1) * 8 + 4
			collection.Size = UDim2.new(1, 0, 0, 48 + gridHeight)
			content.Size = UDim2.new(1, -8, 0, collectionTop + 48 + gridHeight)
		end
		paintDetails(inventorySelectedId)
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		inventoryQuery = search.Text
		renderMatches()
	end)
	sort.Activated:Connect(function()
		inventorySort = if inventorySort == "Power" then "Rarity" elseif inventorySort == "Rarity" then "Name" else "Power"
		setSortText()
		renderMatches()
	end)
	if not inventorySelectedId or not Weapons.ById[inventorySelectedId] or not state.OwnedWeapons[inventorySelectedId] then
		inventorySelectedId = if equipped then equipped.Id else nil
	end
	renderMatches()
end

local function buildChest()
	clearBody()
	local region = Regions.ById[state.CurrentRegion]
	if not region then return end
	addSectionIntro(region.Name .. " Treasure", "Find stronger weapons! Luck improves your live 1/N rates. Move near the chest to open it.", region.Accent)
	local body = refs.ModalBody :: ScrollingFrame

	local compact = refs.IsCompact == true
	local narrow = (refs.BodyWidth or body.AbsoluteSize.X) < 330
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
		openChest(region.Id)
	end)
	table.insert(modalStatUpdates, function()
		local affordable = state.Gold >= region.ChestCost
		setButtonEnabled(open, affordable and pendingChest == nil)
		open.Text = if pendingChest then "OPENING..." elseif affordable then "OPEN CHEST" else "NEED " .. FormatNumber(region.ChestCost - state.Gold) .. " GOLD"
	end)

	local pool = table.clone(Weapons.ByRegion[region.Id] or {})
	table.sort(pool, function(a, b) return a.RateN < b.RateN end)
	for index, weapon in pool do
		local rarityColor = Theme.RarityColor(weapon.Rarity)
		local row = Components.Panel(body, UDim2.new(1, -8, 0, if narrow then 104 else 64), UDim2.new(), false)
		row.LayoutOrder = 2 + index
		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = rarityColor
		stripe.BorderSizePixel = 0
		stripe.Size = UDim2.fromOffset(3, 42)
		stripe.Position = UDim2.fromOffset(10, 11)
		stripe.Parent = row
		Components.Corner(stripe, 999)
		local name = Components.Label(row, weapon.Name, if narrow then UDim2.new(1, -42, 0, 35) else UDim2.new(0.50, -22, 0, 22), UDim2.fromOffset(22, 10), Theme.Font.Strong, 13, Colors.Cream)
		name.TextWrapped = narrow
		Components.Label(row, weapon.Rarity .. "  /  " .. weapon.Family, if narrow then UDim2.new(1, -42, 0, 18) else UDim2.new(0.50, -22, 0, 18), UDim2.fromOffset(22, if narrow then 48 else 34), Theme.Font.Body, 10, rarityColor)
		local liveRate = Progression.CurrentRateN(weapon, state.Luck)
		Components.Label(row, "LIVE RATE", if narrow then UDim2.new(0.40, 0, 0, 14) else UDim2.new(0.23, 0, 0, 14), if narrow then UDim2.fromOffset(22, 76) else UDim2.new(0.55, 0, 0, 9), Theme.Font.Strong, 8, Colors.Faint, if narrow then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right)
		Components.Label(row, RarityFormat.Rate(liveRate), if narrow then UDim2.new(0.33, 0, 0, 24) else UDim2.new(0.23, 0, 0, 24), if narrow then UDim2.new(0.45, 0, 0, 72) else UDim2.new(0.55, 0, 0, 24), Theme.Font.Display, 15, rarityColor, Enum.TextXAlignment.Right)
		Components.Label(row, string.format("x%.2f", weapon.PowerMultiplier), if narrow then UDim2.new(0.2, -2, 0, 24) else UDim2.new(0.16, -12, 0, 26), if narrow then UDim2.new(0.8, 0, 0, 73) else UDim2.new(0.84, 0, 0.5, -13), Theme.Font.Strong, 12, Colors.Green, Enum.TextXAlignment.Right)
	end
end

local function buildRegions()
	clearBody()
	local nextRegion = nextLockedRegion()
	local subtitle = if nextRegion then "Your next milestone is " .. nextRegion.Name .. ". Reach its Power requirement to unlock travel." else "Every known region is unlocked. Continue growing toward your next Rebirth."
	addSectionIntro("World Progression", subtitle, Colors.Blue)
	local body = refs.ModalBody :: ScrollingFrame
	local narrow = (refs.BodyWidth or body.AbsoluteSize.X) < 330

	for index, region in Regions.List do
		local compact = refs.IsCompact == true
		local unlocked = state.UnlockedRegions[region.Id] == true
		local current = state.CurrentRegion == region.Id
		local progress = if region.RequiredPower <= 0 then 1 else math.clamp(state.Power / region.RequiredPower, 0, 1)
		local row = Components.Panel(body, UDim2.new(1, -8, 0, if narrow then 180 elseif compact then 150 else 114), UDim2.new(), true)
		row.LayoutOrder = 1 + index
		titleRule(row, UDim2.fromOffset(0, 0), UDim2.new(0, 4, 1, 0), region.Accent)
		Components.Label(row, string.upper(region.Name), if narrow then UDim2.new(1, -36, 0, 24) elseif compact then UDim2.new(1, -126, 0, 24) else UDim2.new(0.62, -26, 0, 24), UDim2.fromOffset(18, 10), Theme.Font.Strong, if compact then 12 else 14, if unlocked then Colors.Cream else Colors.Muted)
		local statusText = if current then "CURRENT" elseif unlocked then "UNLOCKED" elseif progress >= 1 then "READY" else "LOCKED"
		local statusColor = if current then Colors.Gold elseif unlocked then Colors.Green elseif progress >= 1 then region.Accent else Colors.Muted
		local pill = Components.Pill(row, statusText, statusColor)
		pill.Position = if narrow then UDim2.fromOffset(18, 38) else UDim2.new(1, -104, 0, 9)

		local requirement = if region.RequiredPower <= 0 then "Starting region" else FormatNumber(state.Power) .. " / " .. FormatNumber(region.RequiredPower) .. " Power"
		local requirementLabel = Components.Label(row, requirement, if compact then UDim2.new(1, -36, 0, 18) else UDim2.new(0.62, -26, 0, 18), UDim2.fromOffset(18, if narrow then 71 else 39), Theme.Font.Body, 11, Colors.Muted)
		local _, fill = Components.Progress(row, if compact then UDim2.new(1, -36, 0, 8) else UDim2.new(0.62, -28, 0, 8), UDim2.fromOffset(18, if narrow then 96 else 64), progress, region.Accent)
		fill.BackgroundTransparency = if unlocked then 0 else 0.08
		local progressText = if unlocked then "Travel available" else string.format("%d%% complete", math.floor(progress * 100))
		local progressLabel = Components.Label(row, progressText, if narrow then UDim2.new(1, -36, 0, 18) else UDim2.new(0.62, -26, 0, 18), UDim2.fromOffset(18, if narrow then 111 else 78), Theme.Font.Medium, 10, if unlocked then Colors.Green else Colors.Muted)

		local actionText = if current then "YOU ARE HERE" elseif unlocked then "TRAVEL" elseif progress >= 1 then "UNLOCK" else FormatNumber(math.max(0, region.RequiredPower - state.Power)) .. " LEFT"
		local action = Components.Button(
			row,
			actionText,
			if compact then UDim2.new(1, -36, 0, 38) else UDim2.fromOffset(150, 44),
			if narrow then UDim2.fromOffset(18, 136) elseif compact then UDim2.fromOffset(18, 102) else UDim2.new(1, -164, 1, -56),
			region.Accent:Lerp(Colors.Panel, 0.48)
		)
		action.TextSize = if #actionText > 12 then 10 else 13
		setButtonEnabled(action, not current and (unlocked or progress >= 1))
		action.Activated:Connect(function()
			Remote:FireServer(if unlocked then "TravelRegion" else "UnlockRegion", region.Id)
		end)
		table.insert(modalStatUpdates, function()
			local fraction = if region.RequiredPower <= 0 then 1 else math.clamp(state.Power / region.RequiredPower, 0, 1)
			fill.Size = UDim2.fromScale(fraction, 1)
			requirementLabel.Text = if region.RequiredPower <= 0 then "Starting region" else FormatNumber(state.Power) .. " / " .. FormatNumber(region.RequiredPower) .. " Power"
			progressLabel.Text = if unlocked then "Travel available" else string.format("%d%% complete", math.floor(fraction * 100))
			pill.Text = if current then "CURRENT" elseif unlocked then "UNLOCKED" elseif fraction >= 1 then "READY" else "LOCKED"
			local color = if current then Colors.Gold elseif unlocked then Colors.Green elseif fraction >= 1 then region.Accent else Colors.Muted
			pill.TextColor3 = color; pill.BackgroundColor3 = color
			action.Text = if current then "YOU ARE HERE" elseif unlocked then "TRAVEL" elseif fraction >= 1 then "UNLOCK" else FormatNumber(math.max(0, region.RequiredPower - state.Power)) .. " LEFT"
			setButtonEnabled(action, not current and (unlocked or fraction >= 1))
		end)
	end
end

local function buildRebirth()
	clearBody()
	addSectionIntro("Rebirth", "Reset your run progression for permanent growth while keeping your weapon collection.", Colors.Gold)
	local body = refs.ModalBody :: ScrollingFrame
	local narrow = (refs.BodyWidth or body.AbsoluteSize.X) < 330
	local progress = math.clamp(state.Power / Economy.RebirthPowerRequirement, 0, 1)

	local hero = Components.Panel(body, UDim2.new(1, -8, 0, 160), UDim2.new(), true)
	hero.LayoutOrder = 2
	titleRule(hero, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 3), Colors.Gold)
	Components.Label(hero, "REBIRTH " .. tostring(state.Rebirths + 1), UDim2.new(0.55, -20, 0, 24), UDim2.fromOffset(16, 16), Theme.Font.Display, 18, Colors.Gold)
	Components.Label(hero, tostring(state.Rebirths) .. " completed", UDim2.new(0.45, -20, 0, 20), UDim2.new(0.55, 0, 0, 18), Theme.Font.Medium, 11, Colors.Muted, Enum.TextXAlignment.Right)
	local requirementLabel = Components.Label(hero, FormatNumber(state.Power) .. " / " .. FormatNumber(Economy.RebirthPowerRequirement) .. " Power", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 50), Theme.Font.Strong, 12, Colors.Cream)
	local _, progressFill = Components.Progress(hero, UDim2.new(1, -32, 0, 10), UDim2.fromOffset(16, 76), progress, Colors.Gold)
	local progressLabel = Components.Label(hero, string.format("%d%% complete", math.floor(progress * 100)), UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 92), Theme.Font.Medium, 10, Colors.Muted)

	local action = Components.Button(hero, if progress >= 1 then "REBIRTH NOW" else FormatNumber(Economy.RebirthPowerRequirement - state.Power) .. " POWER REMAINING", UDim2.new(1, -32, 0, 38), UDim2.fromOffset(16, 116), if progress >= 1 then Colors.GoldSoft else Colors.PanelSoft)
	setButtonEnabled(action, progress >= 1)
	action.TextSize = if progress >= 1 then 14 else 11
	action.Activated:Connect(function()
		if state.Power < Economy.RebirthPowerRequirement then return end
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
	table.insert(modalStatUpdates, function()
		local fraction = math.clamp(state.Power / Economy.RebirthPowerRequirement, 0, 1)
		progressFill.Size = UDim2.fromScale(fraction, 1)
		requirementLabel.Text = FormatNumber(state.Power) .. " / " .. FormatNumber(Economy.RebirthPowerRequirement) .. " Power"
		progressLabel.Text = string.format("%d%% complete", math.floor(fraction * 100))
		setButtonEnabled(action, fraction >= 1)
		if action:GetAttribute("Confirm") ~= true then
			action.Text = if fraction >= 1 then "REBIRTH NOW" else FormatNumber(Economy.RebirthPowerRequirement - state.Power) .. " POWER REMAINING"
			action.BackgroundColor3 = if fraction >= 1 then Colors.GoldSoft else Colors.PanelSoft
		end
	end)

	local benefits = Components.Panel(body, UDim2.new(1, -8, 0, if narrow then 234 else 136), UDim2.new(), false)
	benefits.LayoutOrder = 3
	Components.Label(benefits, "PERMANENT GAINS EACH REBIRTH", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 12), Theme.Font.Strong, 10, Colors.Faint)
	local gainTexts = {
		string.format("+%d%% Power gain", math.floor(Economy.PowerPerRebirth * 100 + 0.5)),
		string.format("+%d%% Gold gain", math.floor(Economy.GoldPerRebirth * 100 + 0.5)),
		string.format("+%.2f Luck", Economy.LuckPerRebirth),
	}
	for i, value in gainTexts do
		local stat = Components.Panel(benefits, if narrow then UDim2.new(1, -28, 0, 44) else UDim2.new(1 / 3, -32 / 3, 0, 56), if narrow then UDim2.fromOffset(14, 38 + (i - 1) * 48) else UDim2.new((i - 1) / 3, 8 - (i - 1) * 16 / 3, 0, 38), true)
		Components.Label(stat, value, UDim2.new(1, -12, 1, -12), UDim2.fromOffset(6, 6), Theme.Font.Strong, 11, if i == 3 then Colors.Green else Colors.Gold, Enum.TextXAlignment.Center).TextWrapped = true
	end
	Components.Label(benefits, "Weapons stay. Run Power, Gold, and region access reset.", UDim2.new(1, -28, 0, if narrow then 40 else 22), UDim2.fromOffset(14, if narrow then 189 else 103), Theme.Font.Body, 10, Colors.Muted, Enum.TextXAlignment.Center).TextWrapped = true
end

local function makeToggleCard(parent: Instance, order: number, title: string, description: string, key: string, value: boolean)
	local narrow = (refs.BodyWidth or (refs.ModalBody :: ScrollingFrame).AbsoluteSize.X) < 330
	local card = Components.Panel(parent, UDim2.new(1, -8, 0, if narrow then 122 else 76), UDim2.new(), true)
	card.LayoutOrder = order
	Components.Label(card, title, UDim2.new(1, if narrow then -28 else -136, 0, 22), UDim2.fromOffset(14, 11), Theme.Font.Strong, 13, Colors.Cream)
	local note = Components.Label(card, description, UDim2.new(1, if narrow then -28 else -136, 0, if narrow then 40 else 32), UDim2.fromOffset(14, 34), Theme.Font.Body, 10, Colors.Muted)
	note.TextWrapped = true
	note.TextYAlignment = Enum.TextYAlignment.Top
	local toggle = Components.Button(card, if value then "ON" else "OFF", UDim2.fromOffset(if narrow then 88 else 92, if narrow then 36 else 42), if narrow then UDim2.new(1, -102, 1, -42) else UDim2.new(1, -106, 0.5, -21), if value then Colors.Green:Lerp(Colors.Panel, 0.35) else Colors.PanelSoft)
	toggle.TextColor3 = if value then Colors.Green else Colors.Muted
	toggle.Activated:Connect(function()
		Remote:FireServer("Setting", {Key = key, Value = not value})
	end)
end

local function buildSettings()
	clearBody()
	addSectionIntro("Settings", "Tune presentation and accessibility. These preferences save with your profile.", Colors.Green)
	local body = refs.ModalBody :: ScrollingFrame
	local narrow = (refs.BodyWidth or body.AbsoluteSize.X) < 330
	makeToggleCard(body, 2, "Chest reveal animation", "Show the rolling sequence before the server-selected reward appears.", "RollAnimation", state.Settings.RollAnimation)
	makeToggleCard(body, 3, "Reduced motion", "Shortens panel and reward motion while keeping gameplay feedback readable.", "ReducedMotion", state.Settings.ReducedMotion)

	local volume = Components.Panel(body, UDim2.new(1, -8, 0, if narrow then 150 else 100), UDim2.new(), true)
	volume.LayoutOrder = 4
	Components.Label(volume, "Master volume", UDim2.new(0.55, -14, 0, 22), UDim2.fromOffset(14, 10), Theme.Font.Strong, 13, Colors.Cream)
	local percent = math.floor(state.Settings.Volume * 100 + 0.5)
	Components.Label(volume, tostring(percent) .. "%", UDim2.new(0.45, -14, 0, 22), UDim2.new(0.55, 0, 0, 10), Theme.Font.Display, 14, Colors.Gold, Enum.TextXAlignment.Right)
	Components.Label(volume, "Global audio preference for music, ambience, and effects.", UDim2.new(1, if narrow then -28 else -160, 0, if narrow then 48 else 30), UDim2.fromOffset(14, 35), Theme.Font.Body, 10, Colors.Muted).TextWrapped = true

	local minus = Components.Button(volume, "-", UDim2.fromOffset(42, 38), if narrow then UDim2.fromOffset(14, 98) else UDim2.new(1, -142, 0, 45), Colors.PanelSoft)
	local plus = Components.Button(volume, "+", UDim2.fromOffset(42, 38), UDim2.new(1, -52, 0, if narrow then 98 else 45), Colors.PanelSoft)
	local meter = Instance.new("Frame")
	meter.BackgroundColor3 = Colors.Ink
	meter.BackgroundTransparency = 0.18
	meter.BorderSizePixel = 0
	meter.Size = if narrow then UDim2.new(1, -126, 0, 8) else UDim2.fromOffset(40, 8)
	meter.Position = if narrow then UDim2.fromOffset(63, 113) else UDim2.new(1, -96, 0, 60)
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

	local effects = Components.Panel(body, UDim2.new(1, -8, 0, 160), UDim2.new(), true)
	effects.LayoutOrder = 5
	Components.Label(effects, "Effects quality", UDim2.new(1, -28, 0, 24), UDim2.fromOffset(14, 10), Theme.Font.Strong, 14, Colors.Cream)
	Components.Label(effects, "Auto adapts shadows and particles to your device. Low keeps combat cues visible.", UDim2.new(1, -28, 0, 38), UDim2.fromOffset(14, 36), Theme.Font.Body, 12, Colors.Muted).TextWrapped = true
	for index, quality in {"Auto", "Low", "High"} do
		local selected = state.Settings.EffectsQuality == quality
		local button = Components.Button(effects, quality, UDim2.new(1 / 3, -14, 0, 44), UDim2.new((index - 1) / 3, 10, 0, 78), if selected then Colors.GoldSoft else Colors.PanelSoft)
		button.Activated:Connect(function() Remote:FireServer("Setting", {Key = "EffectsQuality", Value = quality}) end)
	end
	local fps = player:GetAttribute("ClientFPS")
	refs.FrameRateLabel = Components.Label(effects, if fps then "Your frame rate: " .. tostring(fps) .. " FPS" else "Measuring your frame rate...", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 130), Theme.Font.Medium, 12, Colors.Muted)
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
		local screen = currentScreen
		local builder = screenBuilders[screen]
		if builder then
			local body = refs.ModalBody :: ScrollingFrame
			local scrollY = body.CanvasPosition.Y
			builder()
			task.defer(function()
				-- The layout needs a frame to recompute its canvas after rebuilding.
				task.wait()
				if currentScreen ~= screen or not body.Parent or not refs.ModalOverlay.Visible then return end
				local maxY = math.max(0, body.AbsoluteCanvasSize.Y - body.AbsoluteWindowSize.Y)
				body.CanvasPosition = Vector2.new(0, math.clamp(scrollY, 0, maxY))
			end)
		end
	end
end

local function updateResponsive()
	local gui = refs.Gui :: ScreenGui
	local width, height = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	local compact = width < 760 or height < 560
	local portrait = width < 500
	local landscape = compact and not portrait
	refs.IsCompact = compact
	local tile = if landscape then 46 elseif compact then 58 else 64
	local gap = if compact then 6 else 8
	local columns = if landscape then 3 elseif compact then 2 else 1
	local rows = if landscape then 2 elseif compact then 3 else 6
	local nav = refs.Nav :: Frame
	local navHeight = tile * rows + gap * (rows - 1)
	nav.Size = UDim2.fromOffset(tile * columns + gap * (columns - 1), navHeight)
	nav.Position = if compact then UDim2.fromOffset(10, if landscape then 80 else 92) else UDim2.fromOffset(14, math.max(130, math.floor((height - navHeight) / 2)))
	for i, name in NAV_ITEMS do
		local button = refs.NavButtons[name]
		button.Size = UDim2.fromOffset(tile, tile)
		button.Position = UDim2.fromOffset((i - 1) % columns * (tile + gap), math.floor((i - 1) / columns) * (tile + gap))
		button.Label.TextSize = if landscape then 9 elseif compact then 11 else 11
	end
	refs.MenuButton.Size = UDim2.fromOffset(tile, tile)
	refs.MenuButton.Position = UDim2.fromOffset(5 % columns * (tile + gap), math.floor(5 / columns) * (tile + gap))
	refs.MenuButton.Label.TextSize = if landscape then 8 elseif compact then 10 else 10
	refs.Hud.Size = UDim2.fromOffset(if compact then 128 else 154, if landscape then 72 elseif compact then 84 else 108)
	refs.Hud.Position = UDim2.fromOffset(if compact then 10 else 14, if compact then 2 else 6)
	for _, value in {refs.Gold, refs.Luck, refs.RebirthCount} do
		value.TextSize = if landscape then 17 elseif compact then 18 else 24
		local icon = value.Parent:FindFirstChildWhichIsA("Frame")
		if icon then icon.Size = UDim2.fromOffset(if landscape then 23 else 30, if landscape then 23 else 30) end
	end
	local objective = refs.Objective :: Frame
	objective.Size = if compact then UDim2.new(1, -154, 0, 76) else UDim2.fromOffset(math.min(600, width - 370), 76)
	objective.Position = if compact then UDim2.new(1, -10, 0, 2) else UDim2.new(.5, 0, 0, 8)
	objective.AnchorPoint = Vector2.new(if compact then 1 else .5, 0)
	refs.RegionTitle.TextSize = if compact then 16 else 22
	refs.ObjectiveLabel.TextSize = if compact then 14 else 20
	refs.SaveIndicator.Size = UDim2.fromOffset(if compact then width - 154 else 330, if compact then 34 else 20)
	refs.SaveIndicator.AnchorPoint = Vector2.new(if compact then 1 else .5, 0)
	refs.SaveIndicator.Position = UDim2.new(if compact then 1 else .5, if compact then -10 else 0, 0, 82)
	local dock = refs.ActionDock :: Frame
	dock.Size = UDim2.fromOffset(if compact then (if portrait then width - 24 else math.min(350, width - 290)) else 510, if compact then 106 else 146)
	dock.Position = UDim2.new(.5, 0, 1, if portrait then -152 else -14)
	refs.Power.TextSize = if compact then 22 else 32
	refs.Power.Size = UDim2.new(1, 0, 0, if compact then 26 else 36)
	refs.PowerTrack.Position = UDim2.fromOffset(0, if compact then 29 else 40)
	refs.PowerTrack.Size = UDim2.new(1, 0, 0, if compact then 25 else 33)
	refs.ProgressText.TextSize = if compact then 13 else 18
	for _, button in {refs.TrainButton, refs.ChestButton} do
		button.Size = UDim2.new(.5, -5, 0, if compact then 44 else 58)
		button.Position = UDim2.new(if button == refs.TrainButton then 0 else .5, if button == refs.TrainButton then 0 else 5, 1, if compact then -44 else -58)
		button.TextSize = if compact then 16 else 23
	end
	refs.TrainPadding.PaddingTop = UDim.new(0, 5)
	refs.Gain.TextSize = if compact then 8 else 10
	refs.Gain.Position = UDim2.new(0, 6, 1, -17)
	refs.Gain.Size = UDim2.new(1, -12, 0, 14)
	local modal = refs.ModalCard :: Frame
	local margin = if width < 500 then 12 elseif width < 760 then 20 else 32
	local modalWidth = math.max(1, math.min(920, width - 2 * margin))
	local modalHeight = math.max(1, math.min(640, height - (if height < 580 then 24 else 48)))
	modal.AnchorPoint = Vector2.new(.5, .5)
	modal.Position = UDim2.fromScale(.5, .5)
	modal.Size = UDim2.fromOffset(modalWidth, modalHeight)
	local sidebarWidth = if width < 360 then 68 elseif portrait then 102 elseif modalWidth < 760 then 142 else 182
	local contentX = sidebarWidth + (if width < 500 then 22 elseif modalWidth < 760 then 28 else 36)
	refs.ModalSidebar.Size = UDim2.new(0, sidebarWidth, 1, -24)
	refs.ModalSidebarTitle.Text = if width < 360 then "MENU" else "REALM MENU"
	refs.ModalSidebarTitle.TextSize = if portrait then 11 else 15
	refs.ModalSidebarTagline.Visible = not portrait
	local tight = modalHeight < 405
	local tabGap = if tight then 5 else 9
	local tabHeight = math.min(if portrait then 44 else 49, math.floor((modalHeight - 106 - 4 * tabGap) / 5))
	tabHeight = math.max(25, tabHeight)
	local tabNames = {Inventory = "Bag", Chest = "Chest", Regions = "World", Rebirth = "Reset", Settings = "Options"}
	for i, name in NAV_ITEMS do
		local tab = refs.ModalTabs[name] :: TextButton
		tab.Size = UDim2.new(1, -20, 0, tabHeight)
		tab.Position = UDim2.fromOffset(10, 74 + (i - 1) * (tabHeight + tabGap))
		local icon = tab:FindFirstChild("NavIcon") :: Frame?
		if icon then
			local iconSize = if width < 360 then 17 elseif portrait then 20 else 24
			icon.Size = UDim2.fromOffset(iconSize, iconSize)
			icon.Position = UDim2.fromOffset(if width < 360 then 15 elseif portrait then 7 else 11, math.floor((tabHeight - iconSize) / 2))
		end
		local label = tab:FindFirstChild("Label") :: TextLabel?
		if label then
			local offset = if width < 360 then 0 elseif portrait then 30 else 42
			label.Visible = width >= 360
			label.Text = if portrait then tabNames[name] else name
			label.Position = UDim2.fromOffset(offset, 0)
			label.Size = UDim2.new(1, -offset - 3, 1, 0)
			label.TextSize = if portrait then 10 elseif compact then 11 else 13
		end
	end
	refs.ModalKicker.Position = UDim2.fromOffset(contentX, 14)
	refs.ModalKicker.Size = UDim2.new(1, -contentX - 64, 0, 16)
	refs.ModalTitle.Position = UDim2.fromOffset(contentX, 32)
	refs.ModalTitle.Size = UDim2.new(1, -contentX - 66, 0, 35)
	refs.ModalTitle.TextSize = if portrait then 18 elseif compact then 23 else 29
	refs.ModalHeaderRule.Position = UDim2.fromOffset(contentX, 80)
	refs.ModalHeaderRule.Size = UDim2.new(1, -contentX - 18, 0, 2)
	refs.ModalBody.Position = UDim2.fromOffset(contentX, 96)
	refs.ModalBody.Size = UDim2.new(1, -contentX - 17, 1, -112)
	refs.BodyWidth = modalWidth - contentX - 17
	refs.IsCompact = refs.BodyWidth < 640
	refs.Reveal.Size = if compact then UDim2.new(1, -36, 0, math.min(286, height - 24)) else UDim2.fromOffset(500, 286)
	refs.Toast.Size = UDim2.fromOffset(math.min(420, width - 24), 48)
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

	local hud = Instance.new("Frame")
	hud.Name = "Counters"; hud.BackgroundTransparency = 1; hud.Parent = gui; refs.Hud = hud
	refs.Gold = makeStat(hud, "Gold", Colors.Gold, 1)
	refs.Luck = makeStat(hud, "Luck", Colors.Green, 2)
	refs.RebirthCount = makeStat(hud, "Rebirth", Colors.Danger, 3)

	local objective = Instance.new("Frame")
	objective.Name = "NextGoal"
	objective.BackgroundColor3 = Colors.Ink
	objective.BackgroundTransparency = 0.14
	objective.BorderSizePixel = 0
	objective.Parent = gui
	Components.Corner(objective, 12)
	Components.Stroke(objective, Colors.SurfaceBorder, 0.56, 1)
	refs.Objective = objective
	refs.RegionTitle = Components.Label(objective, "VERDANT CROSSROADS", UDim2.new(1, 0, 0, 26), UDim2.new(), Theme.Font.Display, 22, Colors.Cream, Enum.TextXAlignment.Center)
	refs.ObjectiveLabel = Components.Label(objective, "Loading progression...", UDim2.new(1, 0, 0, 46), UDim2.fromOffset(0, 27), Theme.Font.Display, 20, Colors.Gold, Enum.TextXAlignment.Center)
	refs.ObjectiveLabel.TextWrapped = true; refs.ObjectiveLabel.TextTruncate = Enum.TextTruncate.None
	refs.SaveIndicator = Components.Label(gui, "Loading progression...", UDim2.fromOffset(330, 20), UDim2.new(.5, 0, 0, 82), Theme.Font.Medium, 12, Colors.Muted, Enum.TextXAlignment.Center)
	refs.SaveIndicator.BackgroundColor3 = Colors.Ink
	refs.SaveIndicator.BackgroundTransparency = 0.18
	refs.SaveIndicator.BorderSizePixel = 0
	Components.Corner(refs.SaveIndicator, 7)
	refs.SaveIndicator.AnchorPoint = Vector2.new(.5, 0)
	refs.SaveIndicator.TextWrapped = true
	local function updateSaveIndicator()
		local status = player:GetAttribute("SaveStatus") or "Loading"
		local temporary = player:GetAttribute("DataStatus") == "Temporary Studio session"
		local messages = {Loading = "Loading progression...", Loaded = "Progress loaded", Pending = "Autosave pending",
			Queued = "Saving progress soon...", Saving = "Saving progress...", Saved = "Progress saved", Delayed = "Save delayed - retrying automatically"}
		refs.SaveIndicator.Text = (if temporary then "Studio test - " else "") .. (messages[status] or "Checking save status...")
		refs.SaveIndicator.TextColor3 = if status == "Delayed" then Colors.Danger elseif status == "Saved" then Colors.Green else Colors.Muted
		if refs.RevealHint and refs.LastRevealRevision and refs.RevealRolling ~= true then
			local saved = (player:GetAttribute("SavedRevision") or -1) >= refs.LastRevealRevision
			refs.RevealHint.Text = "In your inventory - " .. (if temporary then "Studio test: " else "")
				.. (if saved then "progress saved" elseif status == "Delayed" then "save delayed, retrying" else "saving progress...")
		end
	end
	refs.UpdateSaveIndicator = updateSaveIndicator
	player:GetAttributeChangedSignal("SaveStatus"):Connect(updateSaveIndicator)
	player:GetAttributeChangedSignal("SavedRevision"):Connect(updateSaveIndicator)
	player:GetAttributeChangedSignal("DataStatus"):Connect(updateSaveIndicator)
	player:GetAttributeChangedSignal("ClientFPS"):Connect(function()
		local label = refs.FrameRateLabel
		if label and label.Parent then label.Text = "Your frame rate: " .. tostring(player:GetAttribute("ClientFPS") or 0) .. " FPS" end
	end)
	updateSaveIndicator()

	local nav = Instance.new("Frame")
	nav.Name = "QuickMenu"; nav.BackgroundTransparency = 1; nav.Parent = gui
	refs.Nav = nav; refs.NavButtons = {}
	local function tile(name: string, label: string): TextButton
		local button = Components.Button(nav, "", UDim2.new(), UDim2.new(), Theme.Navigation[name])
		button.Name = name .. "Button"; button.ClipsDescendants = false
		Icons.Draw(button, name, UDim2.fromScale(.58, .56), UDim2.fromScale(.21, .07))
		local text = Components.Label(button, label, UDim2.new(1, -4, .30, 0), UDim2.new(0, 2, .69, 0), Theme.Font.Strong, 12, Colors.Cream, Enum.TextXAlignment.Center)
		text.Name = "Label"; text.TextTruncate = Enum.TextTruncate.None
		local marker = Instance.new("Frame")
		marker.Name = "ActiveMarker"; marker.Size = UDim2.new(1, -12, 0, 2)
		marker.Position = UDim2.fromOffset(6, 4); marker.BackgroundColor3 = Colors.Gold
		marker.BorderSizePixel = 0; marker.Visible = false; marker.Parent = button
		return button
	end
	for _, name in NAV_ITEMS do
		local button = tile(name, name)
		button.Activated:Connect(function()
			if currentScreen == name then closeModal() else showScreen(name) end
		end)
		refs.NavButtons[name] = button
	end
	local best = tile("EquipBest", "Equip best")
	best.Activated:Connect(function() if state then Remote:FireServer("EquipBest") end end)
	refs.MenuButton = best

	local action = Instance.new("Frame")
	action.Name = "PowerDock"; action.BackgroundTransparency = 1
	action.AnchorPoint = Vector2.new(.5, 1); action.Parent = gui; refs.ActionDock = action
	refs.Power = Components.Label(action, "0 Power", UDim2.new(1, 0, 0, 36), UDim2.new(), Theme.Font.Display, 32, Colors.Cream, Enum.TextXAlignment.Center)
	local track, fill = Components.Progress(action, UDim2.new(1, 0, 0, 33), UDim2.fromOffset(0, 40), 0, Colors.Green)
	track.Name = "PowerProgress"; refs.PowerTrack = track; refs.PowerFill = fill
	refs.ProgressText = Components.Label(track, "0 / 2.5K", UDim2.fromScale(1, 1), UDim2.new(), Theme.Font.Display, 18, Colors.Cream, Enum.TextXAlignment.Center)
	refs.ProgressText.ZIndex = 3
	local train = Components.Button(action, "TRAIN", UDim2.new(.5, -5, 0, 58), UDim2.new(0, 0, 1, -58), Colors.GoldSoft)
	train.Name = "TrainButton"; train.TextYAlignment = Enum.TextYAlignment.Top
	train.Activated:Connect(function() Remote:FireServer("Train") end)
	refs.TrainButton = train
	local trainPadding = Instance.new("UIPadding"); trainPadding.Parent = train; refs.TrainPadding = trainPadding
	local chest = Components.Button(action, "OPEN CHEST", UDim2.new(.5, -5, 0, 58), UDim2.new(.5, 5, 1, -58), Theme.Navigation.EquipBest)
	chest.Name = "OpenChestButton"; chest.TextWrapped = true
	chest.Activated:Connect(function() if state then openChest(state.CurrentRegion) end end)
	refs.ChestButton = chest
	local gain = Components.Label(train, "+0 Power / +0 Gold", UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 1, -17), Theme.Font.Strong, 10, Colors.Gold, Enum.TextXAlignment.Center)
	refs.Gain = gain

	local loading = Components.Panel(gui, UDim2.fromOffset(252, 48), UDim2.new(0.5, 0, 0.5, 0), true)
	loading.AnchorPoint = Vector2.new(0.5, 0.5)
	Components.Label(loading, "ENTERING THE REALM...", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), Theme.Font.Strong, 11, Colors.Gold, Enum.TextXAlignment.Center)
	refs.Loading = loading

	local overlay = Instance.new("Frame")
	overlay.Name = "MenuOverlay"
	overlay.BackgroundColor3 = Colors.Shadow
	overlay.BackgroundTransparency = 0.28
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
	titleRule(modal, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 2), Colors.BorderBright)
	local sidebar = Instance.new("Frame")
	sidebar.Name = "NavigationSidebar"
	sidebar.BackgroundColor3 = Colors.Ink
	sidebar.BorderSizePixel = 0
	sidebar.Position = UDim2.fromOffset(12, 12)
	sidebar.Parent = modal
	Components.Corner(sidebar, 9)
	Components.Stroke(sidebar, Colors.SurfaceBorder, 0.72, 1)
	refs.ModalSidebar = sidebar
	refs.ModalSidebarTitle = Components.Label(sidebar, "REALM MENU", UDim2.new(1, -22, 0, 22), UDim2.fromOffset(11, 11), Theme.Font.Strong, 15, Colors.Cream)
	refs.ModalSidebarTagline = Components.Label(sidebar, "ADVENTURER", UDim2.new(1, -22, 0, 18), UDim2.fromOffset(11, 32), Theme.Font.Medium, 9, Colors.Faint)
	titleRule(sidebar, UDim2.fromOffset(11, 59), UDim2.new(1, -22, 0, 1), Colors.BorderBright)
	refs.ModalKicker = Components.Label(modal, "COLLECTION", UDim2.new(1, -110, 0, 15), UDim2.fromOffset(218, 14), Theme.Font.Strong, 10, Colors.Gold)
	refs.ModalTitle = Components.Label(modal, "Inventory", UDim2.new(1, -110, 0, 32), UDim2.fromOffset(218, 32), Theme.Font.Display, 29, Colors.Cream)
	local close = Components.Button(modal, "X", UDim2.fromOffset(39, 35), UDim2.new(1, -55, 0, 18), Colors.PanelSoft)
	close.TextSize = 14
	close.Activated:Connect(closeModal)
	close.Name = "CloseMenu"
	local headingRule = Instance.new("Frame")
	headingRule.Name = "HeadingRule"
	headingRule.BackgroundColor3 = Colors.BorderBright
	headingRule.BackgroundTransparency = 0.40
	headingRule.BorderSizePixel = 0
	headingRule.Parent = modal
	refs.ModalHeaderRule = headingRule
	refs.ModalTabs = {}
	for i, name in NAV_ITEMS do
		local tab = Instance.new("TextButton")
		tab.Name = name .. "Tab"
		tab.Text = ""
		tab.AutoButtonColor = false
		tab.BackgroundColor3 = Colors.Panel
		tab.BorderSizePixel = 0
		tab.Parent = sidebar
		Components.Corner(tab, 8)
		Components.Stroke(tab, Colors.SurfaceBorder, 0.78, 1)
		local icon = Icons.Draw(tab, name, UDim2.fromOffset(24, 24), UDim2.fromOffset(11, 13))
		icon.Name = "NavIcon"
		local label = Components.Label(tab, name, UDim2.new(1, -46, 1, 0), UDim2.fromOffset(42, 0), Theme.Font.Medium, 13, Colors.Muted)
		label.Name = "Label"
		local marker = Instance.new("Frame")
		marker.Name = "ActiveMarker"
		marker.BackgroundColor3 = Colors.Gold
		marker.BorderSizePixel = 0
		marker.Size = UDim2.new(0, 3, 1, -14)
		marker.Position = UDim2.fromOffset(0, 7)
		marker.Visible = false
		marker.Parent = tab
		Components.Corner(marker, 2)
		tab.MouseEnter:Connect(function()
			if currentScreen ~= name then tab.BackgroundColor3 = Colors.PanelRaised end
		end)
		tab.MouseLeave:Connect(function()
			if currentScreen ~= name then tab.BackgroundColor3 = Colors.Panel end
		end)
		tab.Activated:Connect(function() showScreen(name) end)
		refs.ModalTabs[name] = tab
	end

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundColor3 = Colors.Ink
	body.BackgroundTransparency = 0.12
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, -235, 1, -112)
	body.Position = UDim2.fromOffset(218, 96)
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = Colors.BorderBright
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.AutomaticCanvasSize = Enum.AutomaticSize.None
	body.CanvasSize = UDim2.new()
	body.Parent = modal
	Components.Corner(body, 9)
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
	-- Full-screen rarity flash, layered under the reveal panel.
	local revealFlash = Instance.new("Frame")
	revealFlash.BackgroundColor3 = Colors.Cream
	revealFlash.BackgroundTransparency = 1
	revealFlash.BorderSizePixel = 0
	revealFlash.Size = UDim2.fromScale(1, 1)
	revealFlash.Parent = revealOverlay
	refs.RevealFlash = revealFlash
	local reveal = Components.Panel(revealOverlay, UDim2.fromOffset(500, 286), UDim2.new(0.5, 0, 0.5, 0), true)
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	refs.Reveal = reveal
	local revealAccent = Instance.new("Frame")
	revealAccent.BackgroundColor3 = Colors.Gold
	revealAccent.BorderSizePixel = 0
	revealAccent.Size = UDim2.new(1, 0, 0, 4)
	revealAccent.Parent = reveal
	refs.RevealAccent = revealAccent
	refs.RevealKicker = Components.Label(reveal, "TREASURE FOUND", UDim2.new(1, -40, 0, 18), UDim2.fromOffset(20, 20), Theme.Font.Strong, 10, Colors.Gold, Enum.TextXAlignment.Center)

	local reel = Instance.new("Frame")
	reel.BackgroundColor3 = Colors.Ink
	reel.BackgroundTransparency = 0.18
	reel.BorderSizePixel = 0
	reel.ClipsDescendants = true
	reel.Size = UDim2.new(1, -36, 0, 112)
	reel.Position = UDim2.fromOffset(18, 47)
	reel.Parent = reveal
	Components.Corner(reel, 7)
	Components.Stroke(reel, Colors.Border, 0.38)

	refs.RevealRarity = Components.Label(reel, "RARITY", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 8), Theme.Font.Strong, 11, Colors.Gold, Enum.TextXAlignment.Center)
	refs.RevealName = Components.Label(reel, "Weapon", UDim2.new(1, -28, 0, 44), UDim2.fromOffset(14, 28), Theme.Font.Display, 24, Colors.Cream, Enum.TextXAlignment.Center)
	refs.RevealName.TextWrapped = true
	refs.RevealOdds = Components.Label(reel, "1/1", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 75), Theme.Font.Display, 17, Colors.Green, Enum.TextXAlignment.Center)
	-- Spinning 3D model for themed items; labels shift right while it shows.
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromOffset(100, 100)
	viewport.Position = UDim2.fromOffset(6, 6)
	viewport.Visible = false
	viewport.Parent = reel
	refs.RevealViewport = viewport

	local spinner = Instance.new("Frame")
	spinner.BackgroundColor3 = Colors.Gold
	spinner.BorderSizePixel = 0
	spinner.Size = UDim2.new(0, 0, 0, 3)
	spinner.Position = UDim2.new(0, 0, 1, -3)
	spinner.Parent = reel
	refs.RevealSpinner = spinner

	refs.RevealPower = Components.Label(reveal, "x1.00 Power", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 168), Theme.Font.Medium, 12, Colors.Muted, Enum.TextXAlignment.Center)
	refs.RevealHint = Components.Label(reveal, "SERVER ROLL", UDim2.new(1, -40, 0, 16), UDim2.fromOffset(20, 194), Theme.Font.Strong, 8, Colors.Faint, Enum.TextXAlignment.Center)
	local continue = Components.Button(reveal, "CONTINUE", UDim2.fromOffset(156, 38), UDim2.new(0.5, -78, 1, -50), Colors.PanelSoft)
	continue.Activated:Connect(function()
		if refs.RevealRolling == true and refs.PendingReveal then
			local pending = refs.PendingReveal
			revealToken += 1
			settleReveal(pending, revealToken)
			return
		end
		revealToken += 1
		playNextReveal()
	end)
	refs.RevealContinue = continue

	setZ(overlay, 50)
	setZ(toast, 75)
	setZ(revealOverlay, 90)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsive)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.ButtonStart then
			if overlay.Visible then closeModal() else showScreen("Inventory") end
		elseif input.KeyCode == Enum.KeyCode.ButtonB and overlay.Visible then
			closeModal()
		end
	end)
	updateResponsive()
end

local function refreshHUD()
	if not state then return end
	;(refs.Power :: TextLabel).Text = FormatNumber(state.Power) .. " Power"
	;(refs.RebirthCount :: TextLabel).Text = tostring(state.Rebirths)
	;(refs.Gold :: TextLabel).Text = FormatNumber(state.Gold)
	;(refs.Luck :: TextLabel).Text = string.format("x%.2f", state.Luck)
	;(refs.Gain :: TextLabel).Text = string.format("+%.1f Power  /  +%.1f Gold", state.PowerGain, state.GoldGain)
	refs.Loading.Visible = false

	local currentRegion = Regions.ById[state.CurrentRegion]
	if currentRegion then
		refs.RegionTitle.Text = string.upper(currentRegion.Name)
		local chest = refs.ChestButton :: TextButton
		local affordable = state.Gold >= currentRegion.ChestCost
		chest.Text = if affordable then "OPEN CHEST\n" .. FormatNumber(currentRegion.ChestCost) .. " GOLD" else "CHEST\nNEED " .. FormatNumber(currentRegion.ChestCost - state.Gold)
		setButtonEnabled(chest, affordable)
	end

	local nextRegion = nextLockedRegion()
	local target = if nextRegion then nextRegion.RequiredPower else Economy.RebirthPowerRequirement
	local progress = math.clamp(state.Power / target, 0, 1)
	refs.PowerFill.Size = UDim2.fromScale(progress, 1)
	refs.ProgressText.Text = FormatNumber(state.Power) .. " / " .. FormatNumber(target)
	local objective = refs.ObjectiveLabel :: TextLabel
	if nextRegion then
		objective.Text = if progress >= 1 then "Ready! Unlock " .. nextRegion.Name else "Train to unlock " .. nextRegion.Name
	elseif progress >= 1 then
		objective.Text = "Rebirth ready! Keep your weapons, grow stronger."
	else
		objective.Text = "Next goal: " .. FormatNumber(target) .. " Power for Rebirth"
	end
	objective.TextColor3 = if progress >= 1 then Colors.Green else Colors.Gold

end

showToast = function(message: string)
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

local function revealTier(rarity: string): string
	return Showcase.RevealTier[rarity] or "Quick"
end

local function setRevealModel(model: any?)
	if revealModelCleanup then revealModelCleanup(); revealModelCleanup = nil end
	local viewport = refs.RevealViewport :: ViewportFrame
	local labels = {refs.RevealRarity, refs.RevealName, refs.RevealOdds}
	if model then
		viewport.Visible = true
		revealModelCleanup = ItemModels.Show(viewport, model.Kind, model.Primary, model.Secondary, model.Glow)
		for _, label in labels do
			label.Position = UDim2.fromOffset(112, label.Position.Y.Offset)
			label.Size = UDim2.new(1, -124, 0, label.Size.Y.Offset)
		end
	else
		viewport.Visible = false
		for _, label in labels do
			label.Position = UDim2.fromOffset(12, label.Position.Y.Offset)
			label.Size = UDim2.new(1, -24, 0, label.Size.Y.Offset)
		end
	end
end

local function finishCinematic()
	if activeCinematic then activeCinematic:Finish(); activeCinematic = nil end
end

local function flash(color: Color3, strength: number)
	local frame = refs.RevealFlash :: Frame
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - strength
	TweenService:Create(frame, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
end

settleReveal = function(item: any, token: number)
	if token ~= revealToken then return end
	local rarityColor = Theme.RarityColor(item.Rarity)
	local tier = revealTier(item.Rarity)
	local reduced = state and state.Settings and state.Settings.ReducedMotion
	refs.RevealAccent.BackgroundColor3 = rarityColor
	refs.RevealSpinner.BackgroundColor3 = rarityColor
	refs.RevealSpinner.Size = UDim2.new(1, 0, 0, 3)
	;(refs.RevealKicker :: TextLabel).Text = item.Kicker
	;(refs.RevealKicker :: TextLabel).TextColor3 = Colors.Gold
	;(refs.RevealRarity :: TextLabel).Text = string.upper(item.Rarity)
	;(refs.RevealRarity :: TextLabel).TextColor3 = rarityColor
	;(refs.RevealName :: TextLabel).Text = item.Name
	;(refs.RevealOdds :: TextLabel).Text = "RARITY  " .. RarityFormat.Rate(item.RateN)
	;(refs.RevealOdds :: TextLabel).TextColor3 = rarityColor
	;(refs.RevealPower :: TextLabel).Text = item.Detail
	;(refs.RevealHint :: TextLabel).Text = item.Hint or "Added to your inventory"
	;(refs.RevealContinue :: TextButton).Text = if #revealQueue > 0 then "NEXT" else "CONTINUE"
	setRevealModel(item.Model)
	refs.RevealRolling = false
	refs.PendingReveal = nil
	refs.LastRevealRevision = item.Revision
	if refs.UpdateSaveIndicator then refs.UpdateSaveIndicator() end
	local overlay = refs.RevealOverlay :: Frame
	if tier == "Cinematic" and activeCinematic then activeCinematic:Burst() end
	if not reduced then
		if tier == "Cinematic" then flash(rarityColor, 0.55) elseif tier == "Glow" then flash(rarityColor, 0.3) end
	end
	TweenService:Create(overlay, Theme.Motion.Quick, {BackgroundTransparency = 0.22}):Play()
	local reveal = refs.Reveal :: Frame
	if not reduced then
		local finalSize = if refs.IsCompact then UDim2.new(1, -36, 0, 286) else UDim2.fromOffset(500, 286)
		local startSize = if refs.IsCompact then UDim2.new(1, -66, 0, 262) else UDim2.fromOffset(458, 262)
		reveal.Size = startSize
		TweenService:Create(reveal, Theme.Motion.Pop, {Size = finalSize}):Play()
	end
end

local function showReveal(item: any)
	revealToken += 1
	local token = revealToken
	local tier = revealTier(item.Rarity)
	local reduced = state and state.Settings and state.Settings.ReducedMotion
	local overlay = refs.RevealOverlay :: Frame
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	-- Cinematics keep the world visible so the camera push to the chest reads.
	TweenService:Create(overlay, Theme.Motion.Quick, {BackgroundTransparency = if tier == "Cinematic" and not reduced then 0.62 else 0.22}):Play()
	local reveal = refs.Reveal :: Frame
	reveal.Size = if refs.IsCompact then UDim2.new(1, -36, 0, 286) else UDim2.fromOffset(500, 286)
	refs.PendingReveal = item
	refs.RevealRolling = true
	;(refs.RevealContinue :: TextButton).Text = "SKIP"
	refs.RevealSpinner.Size = UDim2.new(0, 0, 0, 3)
	setRevealModel(nil)
	if tier == "Cinematic" then
		finishCinematic()
		activeCinematic = Cinematic.Begin(item.Region, Theme.RarityColor(item.Rarity), not reduced)
	end
	if reduced then
		settleReveal(item, token)
		return
	end

	;(refs.RevealKicker :: TextLabel).Text = item.RollingKicker
	;(refs.RevealRarity :: TextLabel).Text = "ROLLING..."
	;(refs.RevealName :: TextLabel).Text = "???"
	;(refs.RevealOdds :: TextLabel).Text = "CALCULATING  1/N"
	;(refs.RevealOdds :: TextLabel).TextColor3 = Colors.Gold
	;(refs.RevealPower :: TextLabel).Text = ""
	;(refs.RevealHint :: TextLabel).Text = "CLICK SKIP TO REVEAL NOW"
	local pool = item.Pool
	task.spawn(function()
		-- The shared roll: ~0.9 s, same for every anime and item type.
		for i = 1, 10 do
			if token ~= revealToken then return end
			local candidate = pool[((i * 5 + token) % #pool) + 1]
			local color = Theme.RarityColor(candidate.Rarity)
			refs.RevealAccent.BackgroundColor3 = color
			refs.RevealSpinner.BackgroundColor3 = color
			refs.RevealSpinner.Size = UDim2.new(i / 10, 0, 0, 3)
			;(refs.RevealRarity :: TextLabel).Text = string.upper(candidate.Rarity)
			;(refs.RevealRarity :: TextLabel).TextColor3 = color
			;(refs.RevealName :: TextLabel).Text = candidate.Name
			;(refs.RevealOdds :: TextLabel).Text = "RARITY  " .. RarityFormat.Rate(candidate.RateN)
			;(refs.RevealOdds :: TextLabel).TextColor3 = color
			task.wait(0.04 + (i / 10) ^ 2 * 0.09)
		end
		if tier == "Cinematic" then
			-- Suspense beat in the true rarity color while the camera settles on the chest.
			local color = Theme.RarityColor(item.Rarity)
			;(refs.RevealKicker :: TextLabel).Text = "SOMETHING RARE STIRS..."
			;(refs.RevealName :: TextLabel).Text = "???"
			;(refs.RevealOdds :: TextLabel).Text = ""
			for pulse = 1, 4 do
				if token ~= revealToken then return end
				local on = pulse % 2 == 1
				refs.RevealAccent.BackgroundColor3 = if on then color else Colors.Gold
				;(refs.RevealRarity :: TextLabel).Text = if on then string.upper(item.Rarity) .. "?" else "..."
				;(refs.RevealRarity :: TextLabel).TextColor3 = color
				task.wait(0.2)
			end
		end
		settleReveal(item, token)
	end)
end

playNextReveal = function()
	finishCinematic()
	local item = table.remove(revealQueue, 1)
	if not item then
		setRevealModel(nil)
		;(refs.RevealOverlay :: Frame).Visible = false
		return
	end
	showReveal(item)
end

local function weaponItem(result: any): any
	local candidates = {}
	for _, weapon in Weapons.ByRegion[result.Region or state.CurrentRegion] or Weapons.List do
		table.insert(candidates, {Name = weapon.Name, Rarity = weapon.Rarity, RateN = Progression.CurrentRateN(weapon, state.Luck)})
	end
	return {
		Kind = "Weapon", Name = result.Name, Rarity = result.Rarity, RateN = result.RateN,
		Region = result.Region or state.CurrentRegion, Revision = result.Revision,
		Kicker = "TREASURE FOUND", RollingKicker = "OPENING TREASURE",
		Detail = string.format("x%.2f Power   •   %s", result.PowerMultiplier, result.Family),
		Pool = candidates,
	}
end

local function powerItem(result: any, power: any): any?
	local definition = Powers.ById[power.Id]
	local theme = definition and Powers.ThemeById[definition.Theme]
	if not definition or not theme then return nil end
	local region = result.Region or state.CurrentRegion
	local candidates = {}
	for _, entry in PowerOdds.Table(region, state.Luck) do
		table.insert(candidates, {Name = entry.Power.Name, Rarity = entry.Power.Rarity, RateN = entry.RateN})
	end
	if #candidates == 0 then candidates = {{Name = definition.Name, Rarity = definition.Rarity, RateN = power.RateN}} end
	local equipped = state.EquippedPowers and state.EquippedPowers[theme.Id] == definition.Id
	return {
		Kind = "Power", Name = definition.Name, Rarity = definition.Rarity, RateN = power.RateN,
		Region = region, Revision = result.Revision,
		Kicker = "BONUS " .. string.upper(theme.SlotName) .. " FOUND", RollingKicker = "SOMETHING ELSE IS INSIDE...",
		Detail = string.format("x%.2f Power   •   %s slot   •   stacks with other anime powers", definition.PowerMultiplier, theme.Name),
		Hint = if equipped then "Equipped  •  total power stack x" .. string.format("%.2f", state.PowerStack or 1) else "Added to your collection",
		Pool = candidates,
		Model = {Kind = theme.ModelKind, Primary = definition.Primary, Secondary = definition.Secondary, Glow = Theme.RarityColor(definition.Rarity)},
	}
end

local function showChestResult(result: any)
	local items = {weaponItem(result)}
	if type(result.Power) == "table" then
		local item = powerItem(result, result.Power)
		if item then table.insert(items, item) end
	end
	if state and state.Settings and state.Settings.RollAnimation == false then
		local parts = {}
		for _, item in items do
			table.insert(parts, string.format("%s  •  %s  •  %s", item.Name, item.Rarity, RarityFormat.Rate(item.RateN)))
		end
		showToast(table.concat(parts, "   +   "))
		return
	end
	revealQueue = items
	playNextReveal()
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
				or changes.OwnedPowers ~= nil
				or changes.EquippedPowers ~= nil
				or changes.UnlockedRegions ~= nil
				or changes.CurrentRegion ~= nil
				or changes.Settings ~= nil
				or changes.Rebirths ~= nil
			if modalRelevant then refreshModal()
			elseif currentScreen and refs.ModalOverlay.Visible and (changes.Power ~= nil or changes.Gold ~= nil) then
				-- Update threshold controls in place; avoid recreating inventory/cards.
				for _, update in modalStatUpdates do update() end
			end
		elseif action == "Toast" and type(payload) == "string" then
			showToast(payload)
		elseif action == "ChestResult" and type(payload) == "table" then
			if pendingChest and payload.Sequence == pendingChest.Sequence then pendingChest = nil end
			if type(payload.Sequence) == "number" then
				if payload.Sequence <= displayedChestSequence then return end
				displayedChestSequence = payload.Sequence
			end
			showChestResult(payload)
		elseif action == "ChestRejected" and type(payload) == "table" then
			if pendingChest and payload.Sequence == pendingChest.Sequence then pendingChest = nil end
			if type(payload.Message) == "string" then showToast(payload.Message) end
		end
	end)
	Remote:FireServer("RequestState")
end

return UIController
