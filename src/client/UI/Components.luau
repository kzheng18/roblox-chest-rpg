--!strict
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Colors = Theme.Colors

local Components = {}

function Components.Corner(parent: Instance, radius: number): UICorner
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
	return item
end

function Components.Stroke(parent: Instance, color: Color3?, transparency: number?, thickness: number?): UIStroke
	local item = Instance.new("UIStroke")
	item.Color = color or Colors.Border
	item.Transparency = transparency or 0.25
	item.Thickness = thickness or 1
	item.Parent = parent
	return item
end

function Components.Padding(parent: Instance, horizontal: number, vertical: number): UIPadding
	local item = Instance.new("UIPadding")
	item.PaddingLeft = UDim.new(0, horizontal)
	item.PaddingRight = UDim.new(0, horizontal)
	item.PaddingTop = UDim.new(0, vertical)
	item.PaddingBottom = UDim.new(0, vertical)
	item.Parent = parent
	return item
end

function Components.Gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local item = Instance.new("UIGradient")
	item.Color = ColorSequence.new(top, bottom)
	item.Rotation = rotation or 90
	item.Parent = parent
	return item
end

function Components.Label(
	parent: Instance,
	value: string,
	size: UDim2,
	position: UDim2,
	font: Enum.Font,
	textSize: number,
	color: Color3,
	align: Enum.TextXAlignment?
): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Size = size
	item.Position = position
	item.Font = font
	item.Text = value
	item.TextSize = textSize
	item.TextColor3 = color
	item.TextXAlignment = align or Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Parent = parent
	return item
end

function Components.Panel(parent: Instance, size: UDim2, position: UDim2, raised: boolean?): Frame
	local item = Instance.new("Frame")
	item.BackgroundColor3 = if raised then Colors.PanelRaised else Colors.Panel
	item.BackgroundTransparency = 0.05
	item.BorderSizePixel = 0
	item.Size = size
	item.Position = position
	item.Parent = parent
	Components.Corner(item, 12)
	Components.Stroke(item, Colors.Border, 0.22)
	return item
end

function Components.Button(
	parent: Instance,
	value: string,
	size: UDim2,
	position: UDim2,
	accent: Color3?
): TextButton
	local base = accent or Colors.PanelRaised
	local hover = base:Lerp(Colors.Cream, 0.08)
	local pressed = base:Lerp(Colors.Ink, 0.14)
	local item = Instance.new("TextButton")
	item.AutoButtonColor = false
	item.BackgroundColor3 = base
	item.BorderSizePixel = 0
	item.Size = size
	item.Position = position
	item.Font = Theme.Font.Strong
	item.Text = value
	item.TextColor3 = Colors.Cream
	item.TextSize = 14
	item.Selectable = true
	item.Parent = parent
	Components.Corner(item, 10)
	Components.Stroke(item, if accent then accent:Lerp(Colors.Cream, 0.25) else Colors.Border, 0.28)

	item.MouseEnter:Connect(function()
		TweenService:Create(item, Theme.Motion.Fast, {BackgroundColor3 = hover}):Play()
	end)
	item.MouseLeave:Connect(function()
		TweenService:Create(item, Theme.Motion.Fast, {BackgroundColor3 = base}):Play()
	end)
	item.MouseButton1Down:Connect(function()
		TweenService:Create(item, Theme.Motion.Fast, {BackgroundColor3 = pressed}):Play()
	end)
	item.MouseButton1Up:Connect(function()
		TweenService:Create(item, Theme.Motion.Fast, {BackgroundColor3 = hover}):Play()
	end)
	return item
end

function Components.Pill(parent: Instance, value: string, color: Color3): TextLabel
	local item = Components.Label(parent, value, UDim2.fromOffset(88, 24), UDim2.new(), Theme.Font.Strong, 11, color, Enum.TextXAlignment.Center)
	item.BackgroundColor3 = color
	item.BackgroundTransparency = 0.86
	item.TextColor3 = color
	Components.Corner(item, 12)
	Components.Stroke(item, color, 0.45)
	return item
end

function Components.Progress(parent: Instance, size: UDim2, position: UDim2, value: number, accent: Color3): (Frame, Frame)
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Colors.Ink
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	track.Size = size
	track.Position = position
	track.ClipsDescendants = true
	track.Parent = parent
	Components.Corner(track, 999)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(math.clamp(value, 0, 1), 0, 1, 0)
	fill.Parent = track
	Components.Corner(fill, 999)
	return track, fill
end

return Components
