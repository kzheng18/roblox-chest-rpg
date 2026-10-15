-- Studio-only fixtures call the production grip assembler, without granting loot.
return function()
	assert(game:GetService("RunService"):IsStudio())
	local Grip = require(game.ServerScriptService.Server.Components.WeaponGrip)
	local bank = assert(game.ServerStorage:FindFirstChild("WeaponModels"))
	local report = {Passed=0,Failed=0,Checks={}}
	local old = workspace:FindFirstChild("SwordGripFixtures")
	if old then old:Destroy() end
	local fixtures = Instance.new("Folder"); fixtures.Name="SwordGripFixtures"; fixtures.Parent=workspace
	for _, rigType in {Enum.HumanoidRigType.R6,Enum.HumanoidRigType.R15} do
		local desc = Instance.new("HumanoidDescription")
		local base = game.Players:CreateHumanoidModelFromDescriptionAsync(desc,rigType)
		desc:Destroy()
		local hand = assert(base:FindFirstChild(if rigType==Enum.HumanoidRigType.R6 then "Right Arm" else "RightHand"))
		local attachment = hand:FindFirstChild("RightGripAttachment")
		local origin = if attachment then attachment.WorldPosition
			else hand.CFrame:PointToWorldSpace(Vector3.new(0,-hand.Size.Y*.18,-.08))
		for _, template in bank:GetChildren() do
			local model
			local ok,err = pcall(function()
				model=Grip.Create(template,hand); model.Parent=base
				assert((model.GripOrigin.Position-origin).Magnitude<.001)
				assert(model:GetScale()>=.65-.00001 and model:GetScale()<=1.35+.00001)
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") then
						assert(not part.Anchored and not part.CanCollide and part.Massless)
						assert(part:FindFirstChildOfClass("WeldConstraint").Part0==hand)
					end
				end
			end)
			if model then model:Destroy() end
			table.insert(report.Checks,{Name=tostring(rigType).." / "..template.Name,Passed=ok,Error=if ok then nil else tostring(err)})
			if ok then report.Passed+=1 else report.Failed+=1 end
		end
		-- Six temporary display rigs for client-side visual inspection.
		for index,id in {"verdant_iron_sword","frost_sovereign","exclusive_azure_oath"} do
			local rig=base:Clone(); rig.Name=rigType.Name.."_"..id; rig.Parent=fixtures
			local root=rig.HumanoidRootPart; root.Anchored=true
			rig:PivotTo(CFrame.new(-12+(index-1)*10+(if rigType==Enum.HumanoidRigType.R15 then 4 else 0),4,48))
			local h=rig:FindFirstChild(if rigType==Enum.HumanoidRigType.R6 then "Right Arm" else "RightHand")
			local sword=Grip.Create(bank[id],h); sword.Name="SwordDisplay"; sword.Parent=rig
		end
		base:Destroy()
	end
	local result=Instance.new("StringValue"); result.Name="SwordGripPlaytestReport"
	result.Value=game:GetService("HttpService"):JSONEncode(report); result.Parent=game.ServerStorage
	return report
end
