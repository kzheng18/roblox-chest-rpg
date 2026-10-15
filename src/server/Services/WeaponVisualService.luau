--!strict
-- Cosmetic meshes follow the active SERVER profile. No client model/ID requests.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game.ReplicatedStorage.Shared
local Weapons = require(Shared.Config.Weapons)
local Progression = require(Shared.Util.Progression)
local DataService = require(script.Parent.DataService)
local WeaponGrip = require(script.Parent.Parent.Components.WeaponGrip)
local WeaponVisualService = {}
local connections: {[Player]: {RBXScriptConnection}} = {}
local characterConnections: {[Player]: RBXScriptConnection} = {}
local started = false

local function refresh(player: Player)
	local character = player.Character
	if not character then return end
	local existing = character:FindFirstChild("EquippedSwordVisual")
	local data = DataService.Get(player)
	local id = if data then data.EquippedWeapon else ""
	local weapon = Weapons.ById[id]
	local bank = ServerStorage:FindFirstChild("WeaponModels")
	local template = if bank then bank:FindFirstChild(id) else nil
	local valid = data ~= nil and player:GetAttribute("DataReady") == true
		and Progression.OwnsWeapon(data, id) and weapon ~= nil
		and (weapon.Family == "Sword" or weapon.Family == "Greatsword")
		and template ~= nil and template:IsA("Model") and template:GetAttribute("Ready") == true
	if not valid then
		if existing then existing:Destroy() end
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then return end
	if existing and existing:GetAttribute("WeaponId") == id then return end
	if existing then existing:Destroy() end
	assert(template and template:IsA("Model"))
	local visual = WeaponGrip.Create(template,hand)
	visual.Name = "EquippedSwordVisual"
	visual:SetAttribute("WeaponId", id)
	visual.Parent = character
end

local function bindCharacter(player: Player, character: Model)
	local old = characterConnections[player]
	if old then old:Disconnect() end
	characterConnections[player] = character.ChildAdded:Connect(function(child)
		if child.Name == "RightHand" or child.Name == "Right Arm" then refresh(player) end
	end)
	refresh(player)
end

local function bind(player: Player)
	if connections[player] then return end
	connections[player] = {
		player:GetAttributeChangedSignal("EquippedWeapon"):Connect(function() refresh(player) end),
		player:GetAttributeChangedSignal("EquipmentRevision"):Connect(function() refresh(player) end),
		player:GetAttributeChangedSignal("DataReady"):Connect(function() refresh(player) end),
		player.CharacterAdded:Connect(function(character) bindCharacter(player,character) end),
	}
	if player.Character then bindCharacter(player,player.Character) end
end

function WeaponVisualService.Start()
	if started then return end
	started = true
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player] = nil
		if characterConnections[player] then characterConnections[player]:Disconnect() end
		characterConnections[player] = nil
	end)
	for _, player in Players:GetPlayers() do bind(player) end
end

return WeaponVisualService
