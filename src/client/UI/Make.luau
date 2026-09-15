--!strict
-- Tiny UI builder so every screen is plain code. `Make.frame({...}, {children})` etc.
local Theme = require(script.Parent.Theme)

local Make = {}

export type Props = { [string]: any }

function Make.new(className: string, props: Props?, children: { Instance }?): Instance
	local inst = Instance.new(className)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function merge(defaults: Props, props: Props?): Props
	local out = table.clone(defaults)
	if props then
		for k, v in props do
			out[k] = v
		end
	end
	return out
end

function Make.corner(parent: Instance, radius: number?): UICorner
	return Make.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.corner), Parent = parent }) :: UICorner
end

function Make.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Make.new("UIStroke", {
		Color = color or Theme.stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.8,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	}) :: UIStroke
end

function Make.padding(parent: Instance, px: number?, py: number?): UIPadding
	local x = px or Theme.pad
	local y = py or x
	return Make.new("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
		Parent = parent,
	}) :: UIPadding
end

function Make.list(
	parent: Instance,
	gap: number?,
	direction: Enum.FillDirection?,
	hAlign: Enum.HorizontalAlignment?
): UIListLayout
	return Make.new("UIListLayout", {
		Padding = UDim.new(0, gap or 8),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	}) :: UIListLayout
end

function Make.grid(parent: Instance, cellSize: UDim2, gap: number?): UIGridLayout
	return Make.new("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(gap or 8, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	}) :: UIGridLayout
end

function Make.frame(props: Props?, children: { Instance }?): Frame
	return Make.new(
		"Frame",
		merge({
			BackgroundColor3 = Theme.panel,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, props),
		children
	) :: Frame
end

function Make.text(props: Props?, children: { Instance }?): TextLabel
	return Make.new(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			Font = Theme.font,
			TextColor3 = Theme.text,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.new(1, 0, 0, 20),
			RichText = true,
			TextWrapped = true,
		}, props),
		children
	) :: TextLabel
end

function Make.button(props: Props?, onClick: (() -> ())?, children: { Instance }?): TextButton
	local btn = Make.new(
		"TextButton",
		merge({
			BackgroundColor3 = Theme.accent,
			BorderSizePixel = 0,
			Font = Theme.font,
			TextColor3 = Theme.text,
			TextSize = 16,
			Size = UDim2.new(0, 120, 0, 36),
			AutoButtonColor = false,
			Text = "Button",
		}, props),
		children
	) :: TextButton
	Make.corner(btn, Theme.cornerSmall)
	local base = btn.BackgroundColor3
	btn.MouseEnter:Connect(function()
		local stored = btn:GetAttribute("BaseColor")
		local from = if typeof(stored) == "Color3" then stored else base
		btn.BackgroundColor3 = from:Lerp(Color3.new(1, 1, 1), 0.15)
	end)
	btn.MouseLeave:Connect(function()
		local stored = btn:GetAttribute("BaseColor")
		btn.BackgroundColor3 = if typeof(stored) == "Color3" then stored else base
	end)
	if onClick then
		btn.Activated:Connect(onClick)
	end
	return btn
end

-- Re-tint a button (keeps hover behaviour sane)
function Make.tint(btn: TextButton, color: Color3)
	btn.BackgroundColor3 = color
	btn:SetAttribute("BaseColor", color)
end

function Make.scroll(props: Props?, gap: number?): ScrollingFrame
	local sf = Make.new(
		"ScrollingFrame",
		merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.muted,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, props)
	) :: ScrollingFrame
	Make.list(sf, gap or 8)
	return sf
end

-- A horizontal row container (auto height)
function Make.row(props: Props?, children: { Instance }?): Frame
	local row = Make.frame(
		merge({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
			AutomaticSize = Enum.AutomaticSize.None,
		}, props),
		children
	)
	Make.list(row, 8, Enum.FillDirection.Horizontal)
	return row
end

-- Card: panel2 background with padding and a vertical list
function Make.card(props: Props?, children: { Instance }?): Frame
	local card = Make.frame(
		merge({
			BackgroundColor3 = Theme.panel2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, props),
		children
	)
	Make.corner(card, Theme.cornerSmall)
	Make.padding(card, 10, 8)
	Make.list(card, 4)
	return card
end

function Make.screen(name: string, order: number?): ScreenGui
	local Players = game:GetService("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	return Make.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 0,
		Parent = playerGui,
	}) :: ScreenGui
end

return Make
