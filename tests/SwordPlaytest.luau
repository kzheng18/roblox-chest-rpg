-- Run from a temporary normal server Script in a temporary Studio session.
-- Engine integration checks; profile changes are restored before returning.
return function()
	assert(game:GetService("RunService"):IsStudio())
	local HttpService = game:GetService("HttpService")
	local player = game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
	local deadline = os.clock()+20
	while player:GetAttribute("DataReady") ~= true and os.clock()<deadline do task.wait(.1) end
	assert(player:GetAttribute("DataStatus") == "Temporary Studio session", "Use mock profile only")
	local services = game.ServerScriptService.Server.Services
	local DataService = require(services.DataService)
	local Equip = require(services.ProgressionService)
	local data = assert(DataService.Get(player))
	local Weapons = require(game.ReplicatedStorage.Shared.Config.Weapons)
	local bank = assert(game.ServerStorage:FindFirstChild("WeaponModels"))
	local originalOwned = table.clone(data.OwnedWeapons)
	local originalEquipped = data.EquippedWeapon
	local report = {Passed=0,Failed=0,Checks={}}
	local function check(name, fn)
		local ok,err = pcall(fn)
		table.insert(report.Checks,{Name=name,Passed=ok,Error=if ok then nil else tostring(err)})
		if ok then report.Passed+=1 else report.Failed+=1 end
	end
	local function visual() return player.Character and player.Character:FindFirstChild("EquippedSwordVisual") end
	check("Eleven complete models with four actual mesh groups each",function()
		assert(#bank:GetChildren()==11)
		for _,model in bank:GetChildren() do
			assert(model:GetAttribute("Ready")); assert(model.PrimaryPart.Name=="GripOrigin")
			local meshes=0
			for _,p in model:GetChildren() do
				if p:IsA("MeshPart") then meshes+=1; assert(p.MeshContent.SourceType==Enum.ContentSourceType.Opaque) end
			end
			assert(meshes==4)
		end
	end)
	for _,weapon in Weapons.List do
		if weapon.Family == "Sword" or weapon.Family == "Greatsword" then
			check("Owned "..weapon.Name.." equips one collision-free welded model",function()
				data.OwnedWeapons[weapon.Id]=1
				task.wait(.25); Equip.Equip(player,weapon.Id); task.wait(.1)
				local model=assert(visual()); assert(model:GetAttribute("WeaponId")==weapon.Id)
				local hand=player.Character:FindFirstChild("RightHand") or player.Character:FindFirstChild("Right Arm")
				local attachment=hand:FindFirstChild("RightGripAttachment")
				if attachment then
					assert((model.GripOrigin.Position-attachment.WorldPosition).Magnitude<.001,"Grip missed avatar palm")
				end
				local count=0
				for _,child in player.Character:GetChildren() do if child.Name=="EquippedSwordVisual" then count+=1 end end
				assert(count==1)
				for _,p in model:GetDescendants() do
					if p:IsA("BasePart") then
						assert(not p.Anchored and p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery)
						assert(p:FindFirstChildOfClass("WeldConstraint"))
					end
				end
			end)
		end
	end
	check("Exclusive asset cannot be equipped through ordinary inventory",function()
		local before=data.EquippedWeapon
		task.wait(.25); Equip.Equip(player,"exclusive_azure_oath"); task.wait(.1)
		assert(data.EquippedWeapon==before and Weapons.ById.exclusive_azure_oath==nil)
	end)
	check("Invalid ownership removes the cosmetic even when equipped ID is spoofed",function()
		data.OwnedWeapons.verdant_iron_sword=0
		data.EquippedWeapon="verdant_iron_sword"
		DataService.Touch(player,{"EquippedWeapon"},true); task.wait(.1)
		assert(visual()==nil)
	end)
	check("Non-sword equipment clears the sword without changing its identity",function()
		data.OwnedWeapons.verdant_hunter_bow=1
		task.wait(.25); Equip.Equip(player,"verdant_hunter_bow"); task.wait(.1)
		assert(data.EquippedWeapon=="verdant_hunter_bow" and visual()==nil)
	end)
	check("Revoking ownership clears a sword even when its equipped ID stays the same",function()
		data.OwnedWeapons.verdant_iron_sword=1
		task.wait(.25); Equip.Equip(player,"verdant_iron_sword"); task.wait(.1)
		assert(visual())
		data.OwnedWeapons.verdant_iron_sword=0
		DataService.Touch(player,{"OwnedWeapons"},true); task.wait(.1)
		assert(data.EquippedWeapon=="verdant_iron_sword" and visual()==nil)
	end)
	check("Owned sword survives a new character without duplicate attachments",function()
		data.OwnedWeapons.verdant_iron_sword=1
		task.wait(.25); Equip.Equip(player,"verdant_iron_sword"); task.wait(.1)
		player:LoadCharacterAsync(); task.wait(.5)
		local model=assert(visual()); assert(model:GetAttribute("WeaponId")=="verdant_iron_sword")
		assert(model.GripOrigin:FindFirstChildOfClass("WeldConstraint").Part0:IsDescendantOf(player.Character))
	end)
	data.OwnedWeapons=originalOwned; data.EquippedWeapon=originalEquipped
	DataService.Touch(player,{"OwnedWeapons","EquippedWeapon","PowerGain"},true)
	local value=Instance.new("StringValue"); value.Name="SwordPlaytestReport"
	value.Value=HttpService:JSONEncode(report); value.Parent=game.ServerStorage
	return report
end
