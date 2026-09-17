--!strict
-- RebirthController: rebirth screen with requirements, gains and a confirm step.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)
local Window = require(script.Parent.Parent.UI.Window)
local Toast = require(script.Parent.Parent.UI.Toast)

local RebirthController = Knit.CreateController({ Name = "RebirthController" })

local window: Window.Window
local body: ScrollingFrame
local confirming = false

local function clear(parent: Instance)
	for _, c in parent:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

function RebirthController:Refresh()
	if not window.isOpen() then
		return
	end
	local data = Knit.GetController("DataController"):Get()
	local RebirthService = Knit.GetService("RebirthService")
	if not data then
		return
	end
	clear(body)
	local R = Config.Rebirth
	local nextN = data.rebirths + 1
	Make.text({
		Text = `Rebirth <b>{data.rebirths}</b> / {R.MaxRebirths}   •   cash multiplier <b>x{R.multiplier(
			data.rebirths
		)}</b>`,
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = body,
	})

	if nextN > R.MaxRebirths then
		Make.text({ Text = "You've reached the maximum rebirth. Legend.", TextColor3 = Theme.gold, Parent = body })
		return
	end
	local req = R.Requirements[nextN]
	local hasCash = data.cash >= req.cash
	local hasFighter = false
	for _, f in data.fighters do
		if Rarity.atLeast(f.rarity, req.fighterRarity) then
			hasFighter = true
			break
		end
	end

	local reqCard = Make.card({ Parent = body })
	Make.text({ Text = `Requirements for rebirth {nextN}`, TextSize = 18, Parent = reqCard })
	Make.text({
		Text = `{if hasCash then "✅" else "❌"} {Format.cash(req.cash)} cash  (you have {Format.cash(data.cash)})`,
		TextColor3 = if hasCash then Theme.green else Theme.red,
		Parent = reqCard,
	})
	Make.text({
		Text = `{if hasFighter then "✅" else "❌"} one <font color="#{Rarity.color(req.fighterRarity):ToHex()}">{req.fighterRarity}</font> or better fighter`,
		TextColor3 = if hasFighter then Theme.green else Theme.red,
		Parent = reqCard,
	})

	local gainCard = Make.card({ Parent = body })
	Make.text({ Text = "You gain", TextSize = 18, Parent = gainCard })
	Make.text({
		Text = `• Cash multiplier x{R.multiplier(nextN)}\n• +{Config.Base.SlotsPerRebirth} base slot{if nextN
				== Config.Base.Floor2Rebirth
			then ` and Floor 2 (+{Config.Base.Floor2Slots})`
			elseif nextN == Config.Base.Floor3Rebirth then ` and Floor 3 (+{Config.Base.Floor3Slots})`
			else ""}\n• +{Config.Base.Lock.perRebirthBonusSeconds}s base lock time\n• {if nextN
					>= R.GearUnlocks.slapAtRebirth
				and not data.gear.Slap
			then "Slap unlocked"
			else ""}{if nextN >= R.GearUnlocks.trapUsesPerRebirthFrom
			then ` +{R.GearUnlocks.trapUsesPerRebirth} traps`
			else ""}`,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gainCard,
	})

	local loseCard = Make.card({ Parent = body })
	Make.text({ Text = "You lose", TextSize = 18, TextColor3 = Theme.red, Parent = loseCard })
	Make.text({
		Text = "• All cash\n• All fighters, hatching scrolls and your scroll bag\n• Any of your fighters currently being stolen vanish\n\nYou keep: Power, punching bag level, index, skins, gamepasses, gear.",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = loseCard,
	})

	local can = hasCash and hasFighter
	local btn = Make.button({
		Text = if confirming
			then "Are you sure? Click again to REBIRTH"
			elseif can then "🌸 Rebirth"
			else "Requirements not met",
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 18,
		BackgroundColor3 = if confirming then Theme.red elseif can then Theme.accent else Theme.panel3,
		Parent = body,
	})
	btn.Activated:Connect(function()
		if not can then
			return
		end
		if not confirming then
			confirming = true
			self:Refresh()
			task.delay(4, function()
				confirming = false
				self:Refresh()
			end)
			return
		end
		confirming = false
		local ok, msg = RebirthService:Rebirth()
		Toast.show(msg, if ok then "success" else "warn", 5)
		self:Refresh()
	end)
end

function RebirthController:Open()
	window.setOpen(true)
end

function RebirthController:KnitStart()
	window = Window.new("Rebirth", "🌸 Rebirth", UDim2.fromOffset(600, 520))
	body = Make.scroll({ Parent = window.content }, 8)
	window.onOpen(function()
		confirming = false
		self:Refresh()
	end)
	Knit.GetController("HUDController"):AddRailButton("🌸 Rebirth", Theme.accent, function()
		window.toggle()
	end)
	Knit.GetController("DataController").Changed:Connect(function()
		self:Refresh()
	end)
end

return RebirthController
