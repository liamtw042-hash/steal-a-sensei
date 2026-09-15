--!strict
-- Bottom-centre toast notifications. Toast.show("text", "info" | "warn" | "alarm" | "success")
local TweenService = game:GetService("TweenService")

local Make = require(script.Parent.Make)
local Theme = require(script.Parent.Theme)

local Toast = {}

local gui: ScreenGui? = nil
local container: Frame? = nil

local colors: { [string]: Color3 } = {
	info = Theme.accent2,
	success = Theme.green,
	warn = Theme.gold,
	alarm = Theme.red,
	lock = Theme.gold,
	unlock = Theme.green,
}

local function ensure(): Frame
	if container then
		return container
	end
	gui = Make.screen("Toasts", 50)
	local c = Make.frame({
		Name = "Container",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(460, 300),
		Position = UDim2.new(0.5, 0, 1, -140),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = gui,
	})
	local layout = Make.list(c, 6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	container = c
	return c
end

function Toast.show(text: string, kind: string?, seconds: number?)
	local c = ensure()
	local color = colors[kind or "info"] or Theme.accent2
	local item = Make.frame({
		BackgroundColor3 = Theme.panel,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.1,
		Parent = c,
	})
	Make.corner(item, Theme.cornerSmall)
	Make.outline(item, 3)
	Make.stroke(item, color, 2, 0.2)
	Make.padding(item, 12, 8)
	Make.text({
		Text = text,
		TextSize = 16,
		TextColor3 = Theme.text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = item,
	})
	task.delay(seconds or 3.5, function()
		local tween = TweenService:Create(item, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		tween:Play()
		for _, d in item:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
		tween.Completed:Wait()
		item:Destroy()
	end)
end

return Toast
