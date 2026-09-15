--!strict
-- Centered window with a title bar, close button, optional tabs. Only one window is open at a time.
local TweenService = game:GetService("TweenService")

local Make = require(script.Parent.Make)
local Theme = require(script.Parent.Theme)

local Window = {}

export type Window = {
	gui: ScreenGui,
	frame: Frame,
	content: Frame,
	title: TextLabel,
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	toggle: () -> (),
	onOpen: (fn: () -> ()) -> (),
}

local openWindows: { [Window]: boolean } = {}

function Window.closeAll()
	for w, _ in openWindows do
		w.setOpen(false)
	end
end

function Window.new(name: string, titleText: string, size: UDim2?): Window
	local gui = Make.screen(name .. "Window", 10)
	gui.Enabled = false

	local frame = Make.frame({
		Name = "Frame",
		Size = size or UDim2.fromOffset(640, 460),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.panel,
		Parent = gui,
	})
	Make.corner(frame)
	Make.outline(frame, 4)
	Make.shadow(frame, 8)
	Make.new("UISizeConstraint", { MaxSize = Vector2.new(1000, 800), MinSize = Vector2.new(320, 240), Parent = frame })

	local titleBar = Make.frame({
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Theme.panel2,
		Parent = frame,
	})
	Make.corner(titleBar)
	local title = Make.display({
		Name = "Title",
		Text = titleText,
		TextSize = 26,
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		Parent = titleBar,
	})

	local content = Make.frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -64),
		Position = UDim2.fromOffset(12, 56),
		Parent = frame,
	})

	local w: Window
	local openCallbacks: { () -> () } = {}
	local open = false

	local function setOpen(v: boolean)
		if v then
			for other, _ in openWindows do
				if other ~= w then
					other.setOpen(false)
				end
			end
			openWindows[w] = true
			for _, fn in openCallbacks do
				task.spawn(fn)
			end
			gui.Enabled = true
			frame.Size = UDim2.fromOffset(
				(size or UDim2.fromOffset(640, 460)).X.Offset * 0.9,
				(size or UDim2.fromOffset(640, 460)).Y.Offset * 0.9
			)
			TweenService:Create(frame, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = size or UDim2.fromOffset(640, 460),
			}):Play()
		else
			openWindows[w] = nil
			gui.Enabled = false
		end
		open = v
	end

	Make.button({
		Name = "Close",
		Text = "✕",
		TextSize = 20,
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -42, 0, 6),
		BackgroundColor3 = Theme.red,
		Parent = titleBar,
	}, function()
		setOpen(false)
	end)

	w = {
		gui = gui,
		frame = frame,
		content = content,
		title = title,
		setOpen = setOpen,
		isOpen = function()
			return open
		end,
		toggle = function()
			setOpen(not open)
		end,
		onOpen = function(fn)
			table.insert(openCallbacks, fn)
		end,
	}
	return w
end

-- Tab bar inside a window's content. Returns a frame per tab; only one is visible.
function Window.tabs(content: Frame, names: { string }): { [string]: Frame }
	local bar = Make.row({ Name = "Tabs", Size = UDim2.new(1, 0, 0, 36), Parent = content })
	local pages: { [string]: Frame } = {}
	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for n, page in pages do
			page.Visible = n == name
			Make.tint(buttons[n], if n == name then Theme.accent else Theme.panel3)
		end
	end
	for _, name in names do
		local page = Make.frame({
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -44),
			Position = UDim2.fromOffset(0, 44),
			Visible = false,
			Parent = content,
		})
		pages[name] = page
		buttons[name] = Make.button({
			Text = name,
			Size = UDim2.fromOffset(math.max(90, #name * 11 + 24), 32),
			BackgroundColor3 = Theme.panel3,
			Parent = bar,
		}, function()
			select(name)
		end)
	end
	select(names[1])
	return pages
end

return Window
