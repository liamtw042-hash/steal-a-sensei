--!strict
-- Tiny UI builder so every screen is plain code. Chunky, outlined, mobile-scaled.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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

-- Chunky dark outline (the "sticker" look)
function Make.outline(parent: Instance, thickness: number?): UIStroke
	return Make.new("UIStroke", {
		Color = Theme.outline,
		Thickness = thickness or Theme.outlineThickness,
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	}) :: UIStroke
end

-- Vertical gradient that makes a flat colour read as a rounded, lit button
function Make.gloss(parent: Instance, strength: number?): UIGradient
	local s = strength or 0.18
	return Make.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1 - s, 1 - s, 1 - s)),
		}),
		Parent = parent,
	}) :: UIGradient
end

-- Drop shadow: a dark rounded frame parented to `frame`'s parent, sitting behind it.
-- Only for free-positioned frames (windows, HUD panels), not list items.
function Make.shadow(frame: GuiObject, offset: number?): Frame
	local o = offset or 6
	local sh = Make.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.shadow,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = frame.Size,
		Position = frame.Position + UDim2.fromOffset(0, o),
		AnchorPoint = frame.AnchorPoint,
		ZIndex = math.max(1, frame.ZIndex - 1),
		Parent = frame.Parent,
	}) :: Frame
	Make.corner(sh, Theme.corner)
	frame:GetPropertyChangedSignal("Size"):Connect(function()
		sh.Size = frame.Size
	end)
	frame:GetPropertyChangedSignal("Position"):Connect(function()
		sh.Position = frame.Position + UDim2.fromOffset(0, o)
	end)
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		sh.Visible = frame.Visible
	end)
	return sh
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

-- Outlined, rounded panel with a subtle drop shadow (HUD boxes)
function Make.panel(props: Props?, children: { Instance }?): Frame
	local f = Make.frame(merge({ BackgroundColor3 = Theme.panel }, props), children)
	Make.corner(f)
	Make.outline(f)
	if f.Parent then
		Make.shadow(f, 5)
	end
	return f
end

function Make.text(props: Props?, children: { Instance }?): TextLabel
	return Make.new(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			Font = Theme.fontBody,
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

-- Big display text (titles, numbers): chunky font with a dark outline
function Make.display(props: Props?): TextLabel
	local t = Make.text(merge({
		Font = Theme.font,
		TextSize = 24,
		TextStrokeTransparency = 0.35,
		TextStrokeColor3 = Theme.outline,
	}, props))
	return t
end

function Make.button(props: Props?, onClick: (() -> ())?, children: { Instance }?): TextButton
	local btn = Make.new(
		"TextButton",
		merge({
			BackgroundColor3 = Theme.accent,
			BorderSizePixel = 0,
			Font = Theme.font,
			TextColor3 = Theme.text,
			TextSize = 18,
			TextStrokeTransparency = 0.6,
			TextStrokeColor3 = Theme.outline,
			Size = UDim2.new(0, 120, 0, 40),
			AutoButtonColor = false,
			Text = "Button",
		}, props),
		children
	) :: TextButton
	Make.corner(btn, Theme.cornerSmall)
	Make.outline(btn)
	Make.gloss(btn)
	local base = btn.BackgroundColor3
	btn:SetAttribute("BaseColor", base)
	local function baseColor(): Color3
		local stored = btn:GetAttribute("BaseColor")
		return if typeof(stored) == "Color3" then stored else base
	end
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = baseColor():Lerp(Color3.new(1, 1, 1), 0.15)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = baseColor()
	end)
	btn.MouseButton1Down:Connect(function()
		btn.BackgroundColor3 = baseColor():Lerp(Color3.new(0, 0, 0), 0.15)
	end)
	btn.MouseButton1Up:Connect(function()
		btn.BackgroundColor3 = baseColor()
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
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = Theme.accent,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, props)
	) :: ScrollingFrame
	Make.list(sf, gap or 8)
	return sf
end

-- A horizontal row container
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

-- Card: panel2 background with padding, outline and a vertical list
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
	Make.outline(card, 2)
	Make.padding(card, 12, 10)
	Make.list(card, 4)
	return card
end

-- ScreenGui with a UIScale that follows the viewport (phones get ~0.6, 1080p gets 1)
function Make.screen(name: string, order: number?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Make.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 0,
		Parent = playerGui,
	}) :: ScreenGui
	local scale = Make.new("UIScale", { Name = "AutoScale", Parent = gui }) :: UIScale
	local function update()
		local cam = Workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		local s = math.min(vp.X / 1366, vp.Y / 768)
		scale.Scale = math.clamp(s, 0.55, 1.15)
	end
	update()
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local c = Workspace.CurrentCamera
		if c then
			c:GetPropertyChangedSignal("ViewportSize"):Connect(update)
			update()
		end
	end)
	return gui
end

return Make
