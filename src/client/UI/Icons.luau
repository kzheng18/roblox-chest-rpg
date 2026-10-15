--!strict
-- Original scalable UI drawings. No external images or borrowed game assets.
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local Icons = {}

function Icons.Draw(parent: Instance, kind: string, size: UDim2, position: UDim2): Frame
	local root = Instance.new("Frame")
	root.Name = "Icon_" .. kind; root.BackgroundTransparency = 1
	root.Size = size; root.Position = position; root.Parent = parent
	local function shape(x: number, y: number, w: number, h: number, color: Color3, rotation: number?, round: boolean?): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0; f.BackgroundColor3 = color
		f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h); f.Rotation = rotation or 0; f.Parent = root
		Components.Corner(f, if round then 999 else 2)
		Components.Stroke(f, Theme.Colors.Ink, 0.46, 1)
		return f
	end
	local white = Theme.Colors.Cream
	local gold = Theme.Colors.Gold
	local orange = Color3.fromRGB(166, 125, 94)
	local blue = Theme.Colors.Blue
	if kind == "Inventory" then
		shape(.5, .2, .32, .22, orange, 0, true)
		shape(.5, .53, .70, .66, Color3.fromRGB(76, 85, 122))
		shape(.5, .38, .77, .31, Color3.fromRGB(108, 113, 159))
		shape(.5, .71, .44, .25, Theme.Colors.PanelRaised)
		shape(.5, .47, .14, .22, gold)
		shape(.24, .60, .08, .33, orange); shape(.76, .60, .08, .33, orange)
	elseif kind == "Chest" then
		shape(.5, .62, .78, .46, Color3.fromRGB(91, 68, 71))
		shape(.5, .36, .82, .32, orange)
		shape(.23, .53, .13, .66, gold); shape(.77, .53, .13, .66, gold)
		shape(.5, .53, .19, .23, gold)
		shape(.5, .52, .045, .07, Theme.Colors.Ink)
	elseif kind == "Regions" then
		shape(.26, .56, .28, .67, Color3.fromRGB(74, 129, 131), -10)
		shape(.50, .53, .27, .65, Color3.fromRGB(170, 170, 151), 7)
		shape(.74, .50, .28, .65, Color3.fromRGB(89, 140, 140), -8)
		shape(.52, .56, .17, .17, blue, 45)
		shape(.70, .25, .04, .42, white)
		shape(.80, .14, .20, .17, Theme.Colors.Danger)
	elseif kind == "Rebirth" then
		shape(.47, .25, .60, .15, blue, -12, true)
		shape(.78, .35, .18, .18, blue, 45)
		shape(.53, .75, .60, .15, Theme.Colors.Danger, -12, true)
		shape(.22, .65, .18, .18, Theme.Colors.Danger, 45)
		shape(.5, .5, .25, .25, gold, 45)
	elseif kind == "Settings" then
		for i = 0, 3 do shape(.5, .5, .25, .88, Theme.Colors.Faint, i * 45) end
		shape(.5, .5, .66, .66, Theme.Colors.Text, 0, true)
		shape(.5, .5, .30, .30, Theme.Colors.PanelSoft, 0, true)
	elseif kind == "EquipBest" or kind == "Power" then
		shape(.5, .42, .22, .67, white, 35)
		shape(.51, .42, .06, .61, blue, 35)
		shape(.32, .67, .55, .13, gold, 35)
		shape(.22, .80, .14, .29, Color3.fromRGB(125, 111, 182), 35)
		shape(.15, .89, .20, .12, gold, 35)
	elseif kind == "Gold" then
		shape(.5, .5, .78, .78, orange, 0, true)
		shape(.5, .5, .57, .57, gold, 0, true)
		shape(.5, .5, .10, .32, white)
	elseif kind == "Luck" then
		shape(.5, .51, .55, .69, Theme.Colors.Green, 35)
		shape(.46, .45, .18, .50, white, 35)
	end
	return root
end

return Icons
