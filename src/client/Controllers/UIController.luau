--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = game.ReplicatedStorage.Shared
local Remote = require(Shared.Remotes).Get()
local FormatNumber = require(Shared.Util.FormatNumber)
local Regions = require(Shared.Config.Regions)
local Weapons = require(Shared.Config.Weapons)
local Economy = require(Shared.Config.Economy)

local UIController = {}

local state: any = nil
local selectedRegion = "verdant"
local refs: {[string]: any} = {}

local C = {
	Panel = Color3.fromRGB(24, 22, 28),
	Panel2 = Color3.fromRGB(34, 31, 38),
	Gold = Color3.fromRGB(232, 190, 90),
	Cream = Color3.fromRGB(245, 235, 210),
	Muted = Color3.fromRGB(172, 166, 158),
	Green = Color3.fromRGB(89, 184, 118),
	Danger = Color3.fromRGB(209, 82, 82),
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(92, 81, 67)
	s.Transparency = transparency or 0.25
	s.Thickness = 1
	s.Parent = parent
end

local function text(parent: Instance, value: string, size: UDim2, pos: UDim2, font: Enum.Font, textSize: number, color: Color3, align: Enum.TextXAlignment?)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = pos
	label.Font = font
	label.Text = value
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function button(parent: Instance, value: string, size: UDim2, pos: UDim2)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = C.Panel2
	b.TextColor3 = C.Cream
	b.Text = value
	b.TextSize = 15
	b.Font = Enum.Font.GothamBold
	b.Parent = parent
	corner(b, 9)
	stroke(b)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(47, 42, 50)}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = C.Panel2}):Play()
	end)
	return b
end

local function panel(parent: Instance, size: UDim2, pos: UDim2)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = C.Panel
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel = 0
	f.Parent = parent
	corner(f, 12)
	stroke(f, 0.18)
	return f
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChestRPGUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local hud = panel(gui, UDim2.fromOffset(520, 70), UDim2.new(0.5, -260, 0, 18))
	refs.Power = text(hud, "POWER  0", UDim2.fromOffset(160, 28), UDim2.fromOffset(18, 10), Enum.Font.GothamBold, 18, C.Cream)
	refs.Gold = text(hud, "GOLD  0", UDim2.fromOffset(160, 28), UDim2.fromOffset(178, 10), Enum.Font.GothamBold, 18, C.Gold)
	refs.Luck = text(hud, "LUCK  x1.00", UDim2.fromOffset(160, 28), UDim2.fromOffset(338, 10), Enum.Font.GothamBold, 18, C.Green)
	refs.Gain = text(hud, "+1 Power / +2 Gold", UDim2.new(1, -36, 0, 20), UDim2.fromOffset(18, 42), Enum.Font.GothamMedium, 12, C.Muted)

	local action = panel(gui, UDim2.fromOffset(320, 94), UDim2.new(0.5, -160, 1, -120))
	local train = button(action, "TRAIN", UDim2.new(0.62, -12, 1, -24), UDim2.fromOffset(12, 12))
	train.TextSize = 22
	train.BackgroundColor3 = Color3.fromRGB(77, 62, 42)
	train.Activated:Connect(function() Remote:FireServer("Train") end)
	local chest = button(action, "OPEN\nCHEST", UDim2.new(0.38, -12, 1, -24), UDim2.new(0.62, 0, 0, 12))
	chest.TextWrapped = true
	chest.Activated:Connect(function()
		if state then Remote:FireServer("OpenChest", state.CurrentRegion) end
	end)
	refs.ChestButton = chest

	local menu = panel(gui, UDim2.fromOffset(210, 244), UDim2.new(0, 18, 0.5, -122))
	text(menu, "ADVENTURE", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 12), Enum.Font.GothamBlack, 19, C.Gold)
	local inventory = button(menu, "Inventory", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 52))
	local regions = button(menu, "Regions", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 101))
	local rebirth = button(menu, "Rebirth", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 150))
	local settings = button(menu, "Settings", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 199))

	local modal = panel(gui, UDim2.new(0.62, 0, 0.68, 0), UDim2.new(0.5, 0, 0.5, 0))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Visible = false
	refs.Modal = modal
	refs.ModalTitle = text(modal, "Inventory", UDim2.new(1, -100, 0, 38), UDim2.fromOffset(22, 16), Enum.Font.GothamBlack, 22, C.Gold)
	local close = button(modal, "X", UDim2.fromOffset(42, 36), UDim2.new(1, -58, 0, 14))
	close.Activated:Connect(function() modal.Visible = false end)

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, -36, 1, -76)
	body.Position = UDim2.fromOffset(18, 64)
	body.ScrollBarThickness = 5
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = modal
	refs.ModalBody = body

	local toast = text(gui, "", UDim2.fromOffset(420, 44), UDim2.new(0.5, -210, 0, 98), Enum.Font.GothamBold, 15, C.Cream, Enum.TextXAlignment.Center)
	toast.BackgroundTransparency = 0.12
	toast.BackgroundColor3 = C.Panel
	toast.Visible = false
	corner(toast, 9)
	stroke(toast)
	refs.Toast = toast

	local reveal = panel(gui, UDim2.fromOffset(460, 220), UDim2.new(0.5, 0, 0.5, 0))
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Visible = false
	reveal.ZIndex = 20
	refs.Reveal = reveal
	refs.RevealRarity = text(reveal, "RARITY", UDim2.new(1, -40, 0, 28), UDim2.fromOffset(20, 30), Enum.Font.GothamBold, 14, C.Gold, Enum.TextXAlignment.Center)
	refs.RevealName = text(reveal, "Weapon", UDim2.new(1, -40, 0, 48), UDim2.fromOffset(20, 68), Enum.Font.GothamBlack, 28, C.Cream, Enum.TextXAlignment.Center)
	refs.RevealOdds = text(reveal, "1/1", UDim2.new(1, -40, 0, 36), UDim2.fromOffset(20, 126), Enum.Font.GothamBold, 18, C.Green, Enum.TextXAlignment.Center)
	refs.RevealPower = text(reveal, "x1.00 Power", UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 166), Enum.Font.GothamMedium, 15, C.Muted, Enum.TextXAlignment.Center)

	local function show(which: string)
		modal.Visible = true
		refs.ModalTitle.Text = which
		for _, child in body:GetChildren() do child:Destroy() end
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = body

		if not state then return end
		if which == "Inventory" then
			local best = button(body, "EQUIP BEST", UDim2.new(1, -8, 0, 42), UDim2.new())
			best.BackgroundColor3 = Color3.fromRGB(78, 65, 42)
			best.Activated:Connect(function() Remote:FireServer("EquipBest") end)
			local ids = {}
			for id, count in state.OwnedWeapons do if count > 0 then table.insert(ids, id) end end
			table.sort(ids, function(a, b) return Weapons.ById[a].PowerMultiplier > Weapons.ById[b].PowerMultiplier end)
			for _, id in ids do
				local weapon = Weapons.ById[id]
				local count = state.OwnedWeapons[id]
				local equipped = state.EquippedWeapon == id
				local row = button(body, string.format("%s%s  ·  %s  ·  1/%d  ·  x%.2f  ·  x%d", equipped and "[EQUIPPED] " or "", weapon.Name, weapon.Rarity, weapon.RateN, weapon.PowerMultiplier, count), UDim2.new(1, -8, 0, 48), UDim2.new())
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Activated:Connect(function() Remote:FireServer("EquipWeapon", id) end)
			end
			if #ids == 0 then text(body, "Open your region chest to find your first weapon.", UDim2.new(1, -8, 0, 44), UDim2.new(), Enum.Font.GothamMedium, 14, C.Muted) end
		elseif which == "Regions" then
			for _, region in Regions.List do
				local unlocked = state.UnlockedRegions[region.Id] == true
				local progress = if region.RequiredPower <= 0 then 1 else math.clamp(state.Power / region.RequiredPower, 0, 1)
				local label = if unlocked then string.format("%s  ·  TRAVEL", region.Name) else string.format("%s  ·  %s / %s Power  ·  %d%%", region.Name, FormatNumber(state.Power), FormatNumber(region.RequiredPower), math.floor(progress * 100))
				local row = button(body, label, UDim2.new(1, -8, 0, 52), UDim2.new())
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Activated:Connect(function()
					selectedRegion = region.Id
					Remote:FireServer(if unlocked then "TravelRegion" else "UnlockRegion", region.Id)
				end)
			end
		elseif which == "Rebirth" then
			text(body, string.format("Rebirth at %s Power. Each Rebirth permanently boosts Power gain, Gold gain, and Luck. Weapons remain in your collection.", FormatNumber(Economy.RebirthPowerRequirement)), UDim2.new(1, -8, 0, 76), UDim2.new(), Enum.Font.GothamMedium, 15, C.Cream)
			local can = state.Power >= Economy.RebirthPowerRequirement
			local doIt = button(body, can and "REBIRTH NOW" or (FormatNumber(Economy.RebirthPowerRequirement - state.Power) .. " Power remaining"), UDim2.new(1, -8, 0, 48), UDim2.new())
			doIt.BackgroundColor3 = can and Color3.fromRGB(96, 68, 42) or Color3.fromRGB(57, 53, 57)
			doIt.Activated:Connect(function() if can then Remote:FireServer("Rebirth") end end)
		elseif which == "Settings" then
			local roll = button(body, "Chest reveal animation: " .. (state.Settings.RollAnimation and "ON" or "OFF"), UDim2.new(1, -8, 0, 48), UDim2.new())
			roll.Activated:Connect(function() Remote:FireServer("Setting", {Key="RollAnimation", Value=not state.Settings.RollAnimation}) end)
			local motion = button(body, "Reduced motion: " .. (state.Settings.ReducedMotion and "ON" or "OFF"), UDim2.new(1, -8, 0, 48), UDim2.new())
			motion.Activated:Connect(function() Remote:FireServer("Setting", {Key="ReducedMotion", Value=not state.Settings.ReducedMotion}) end)
		end
	end

	inventory.Activated:Connect(function() show("Inventory") end)
	regions.Activated:Connect(function() show("Regions") end)
	rebirth.Activated:Connect(function() show("Rebirth") end)
	settings.Activated:Connect(function() show("Settings") end)

	refs.RefreshModal = function()
		if modal.Visible then show(refs.ModalTitle.Text) end
	end
end

local function refresh(refreshModal: boolean?)
	if not state then return end
	(refs.Power :: TextLabel).Text = "POWER  " .. FormatNumber(state.Power)
	(refs.Gold :: TextLabel).Text = "GOLD  " .. FormatNumber(state.Gold)
	(refs.Luck :: TextLabel).Text = string.format("LUCK  x%.2f", state.Luck)
	(refs.Gain :: TextLabel).Text = string.format("+%.1f Power / +%.1f Gold per train", state.PowerGain, state.GoldGain)
	local region = Regions.ById[state.CurrentRegion]
	if region then
		(refs.ChestButton :: TextButton).Text = string.format("OPEN CHEST\n%s Gold", FormatNumber(region.ChestCost))
	end
	if refreshModal then
		local refreshModalFn = refs.RefreshModal :: any
		if refreshModalFn then refreshModalFn() end
	end
end

local toastToken = 0
local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	local toast = refs.Toast :: TextLabel
	toast.Text = message
	toast.Visible = true
	task.delay(2.4, function()
		if token == toastToken then toast.Visible = false end
	end)
end

local function showChestResult(result: any)
	if state and state.Settings and state.Settings.RollAnimation == false then
		showToast(string.format("%s · %s · 1/%d · x%.2f", result.Name, result.Rarity, result.RateN, result.PowerMultiplier))
		return
	end
	local reveal = refs.Reveal :: Frame
	(refs.RevealRarity :: TextLabel).Text = string.upper(result.Rarity)
	(refs.RevealName :: TextLabel).Text = result.Name
	(refs.RevealOdds :: TextLabel).Text = "RARITY  1/" .. tostring(result.RateN)
	(refs.RevealPower :: TextLabel).Text = string.format("x%.2f Power · %s", result.PowerMultiplier, result.Family)
	reveal.Visible = true
	reveal.Size = UDim2.fromOffset(400, 184)
	reveal.BackgroundTransparency = 0.25
	TweenService:Create(reveal, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=UDim2.fromOffset(460,220), BackgroundTransparency=0.08}):Play()
	task.delay(if state and state.Settings and state.Settings.ReducedMotion then 0.8 else 1.8, function()
		reveal.Visible = false
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
			refresh(true)
		elseif action == "StateDelta" then
			if type(payload) ~= "table" or type(payload.Changes) ~= "table" or type(payload.Revision) ~= "number" then return end
			if not state then
				Remote:FireServer("RequestState")
				return
			end
			if type(state.Revision) == "number" and payload.Revision <= state.Revision then return end
			local changes = payload.Changes
			for key, value in changes do
				state[key] = value
			end
			state.Revision = payload.Revision
			local needsModalRefresh = changes.OwnedWeapons ~= nil
				or changes.EquippedWeapon ~= nil
				or changes.UnlockedRegions ~= nil
				or changes.CurrentRegion ~= nil
				or changes.Settings ~= nil
				or changes.Rebirths ~= nil
			refresh(needsModalRefresh)
		elseif action == "Toast" and type(payload) == "string" then
			showToast(payload)
		elseif action == "ChestResult" and type(payload) == "table" then
			showChestResult(payload)
		end
	end)
	Remote:FireServer("RequestState")
end

return UIController
