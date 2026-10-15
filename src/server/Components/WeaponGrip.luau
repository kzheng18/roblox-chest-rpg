--!strict
-- Server-only cosmetic assembly. Ownership is checked by WeaponVisualService.
local WeaponGrip = {}

function WeaponGrip.Create(template: Model, hand: BasePart): Model
	assert(template.PrimaryPart and template.PrimaryPart.Name == "GripOrigin", "Sword grip origin missing")
	local visual = template:Clone()
	local scale = math.clamp(hand.Size.Y / (if hand.Name == "Right Arm" then 2 else .9), .65, 1.35)
	visual:ScaleTo(scale)
	local attachment = hand:FindFirstChild("RightGripAttachment")
	-- Respect each avatar's authored palm position, including non-human bundles.
	local palm = if attachment and attachment:IsA("Attachment") then attachment.Position
		else Vector3.new(0,-hand.Size.Y*.18,-.08)
	visual:PivotTo(hand.CFrame * CFrame.new(palm) * CFrame.Angles(math.rad(-65),0,0))
	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false; part.Massless = true
			part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand; weld.Part1 = part; weld.Parent = part
		end
	end
	return visual
end

return WeaponGrip
