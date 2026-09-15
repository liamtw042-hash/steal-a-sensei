--!strict
--[[
	ShopController: Speed passes, other gamepasses, combat shop (dev products), rift token
	shop, plus the Free Rewards window (like + favourite + group).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local SpeedMath = require(ReplicatedStorage.Shared.Util.SpeedMath)
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)
local Window = require(script.Parent.Parent.UI.Window)
local Toast = require(script.Parent.Parent.UI.Toast)

local ShopController = Knit.CreateController({ Name = "ShopController" })

local shop: Window.Window
local rewards: Window.Window
local pages: { [string]: Frame }
local speedScroll: ScrollingFrame
local passScroll: ScrollingFrame
local combatScroll: ScrollingFrame
local tokenScroll: ScrollingFrame
local rewardsFrame: Frame

local function clear(parent: Instance)
	for _, c in parent:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function robuxButton(parent: Instance, price: number, owned: boolean, onClick: () -> ())
	return Make.button({
		Text = if owned then "✅ Owned" else `R$ {price}`,
		Size = UDim2.fromOffset(120, 32),
		BackgroundColor3 = if owned then Theme.panel3 else Theme.green,
		TextColor3 = if owned then Theme.text else Theme.bg,
		Parent = parent,
	}, function()
		if not owned then
			onClick()
		end
	end)
end

function ShopController:_build()
	shop = Window.new("Shop", "🛒 Shop", UDim2.fromOffset(720, 520))
	pages = Window.tabs(shop.content, { "Speed", "Passes", "Combat", "Rift Tokens" })
	speedScroll = Make.scroll({ Parent = pages.Speed }, 6)
	passScroll = Make.scroll({ Parent = pages.Passes }, 6)
	combatScroll = Make.scroll({ Parent = pages.Combat }, 6)
	tokenScroll = Make.scroll({ Parent = pages["Rift Tokens"] }, 6)
	shop.onOpen(function()
		self:Refresh()
	end)

	rewards = Window.new("Rewards", "🎁 Free Rewards", UDim2.fromOffset(520, 360))
	rewardsFrame = Make.frame({ BackgroundTransparency = 1, Parent = rewards.content })
	Make.list(rewardsFrame, 8)
	rewards.onOpen(function()
		self:RefreshRewards()
	end)
end

function ShopController:Refresh()
	if not shop.isOpen() then
		return
	end
	local DataController = Knit.GetController("DataController")
	local Monetization = Knit.GetService("MonetizationService")
	local EventService = Knit.GetService("EventService")
	local data = DataController:Get()
	if not data then
		return
	end

	-- Speed ladder
	clear(speedScroll)
	Make.text({
		Text = `Your multiplier: <b>x{Format.short(SpeedMath.gamepassMultiplier(data.gamepasses))}</b>. Each pass stacks multiplicatively.`,
		TextColor3 = Theme.muted,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = speedScroll,
	})
	for _, def in Config.Monetization.Gamepasses do
		if not def.key:match("^Speed") then
			continue
		end
		local card = Make.card({ Parent = speedScroll })
		local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
		Make.text({
			Text = `⚡ <b>{def.name}</b>  <font color="#{Theme.muted:ToHex()}">{def.description}</font>`,
			Size = UDim2.new(1, -130, 1, 0),
			Parent = row,
		})
		local key = def.key
		robuxButton(row, def.price, data.gamepasses[key] == true, function()
			local ok, msg = Monetization:PromptGamepass(key)
			if not ok then
				Toast.show(msg, "warn")
			end
		end)
	end

	-- Other passes
	clear(passScroll)
	for _, def in Config.Monetization.Gamepasses do
		if def.key:match("^Speed") then
			continue
		end
		local card = Make.card({ Parent = passScroll })
		local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
		Make.text({
			Text = `⭐ <b>{def.name}</b>  <font color="#{Theme.muted:ToHex()}">{def.description}</font>`,
			Size = UDim2.new(1, -130, 1, 0),
			Parent = row,
		})
		local key = def.key
		robuxButton(row, def.price, data.gamepasses[key] == true, function()
			local ok, msg = Monetization:PromptGamepass(key)
			if not ok then
				Toast.show(msg, "warn")
			end
		end)
	end

	-- Combat
	clear(combatScroll)
	Make.text({
		Text = "Hotkeys: 1 Slap • 2 Trap • 3 Smoke Bomb • 4 Grapple • 5 Body Swap. Slap and Trap also unlock via rebirth.",
		TextColor3 = Theme.muted,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = combatScroll,
	})
	local gear = data.gear :: any
	for _, def in Config.Monetization.Products do
		local card = Make.card({ Parent = combatScroll })
		local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
		local have = gear[def.key]
		local status = if def.kind == "permanent"
			then (if have == true then " (owned)" else "")
			else ` (x{if typeof(have) == "number" then have else 0} left)`
		Make.text({
			Text = `🗡 <b>{def.name}</b>{status}  <font color="#{Theme.muted:ToHex()}">{def.description}</font>`,
			Size = UDim2.new(1, -130, 1, 0),
			Parent = row,
		})
		local key = def.key
		robuxButton(row, def.price, def.kind == "permanent" and have == true, function()
			local ok, msg = Monetization:PromptProduct(key)
			if not ok then
				Toast.show(msg, "warn")
			end
		end)
	end

	-- Tokens
	clear(tokenScroll)
	Make.text({
		Text = `You have <b>✦ {data.tokens}</b> rift tokens. Earn them by fighting the Rift Sensei when a Rift opens.`,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = tokenScroll,
	})
	for _, item in Config.Events.TokenShop do
		local card = Make.card({ Parent = tokenScroll })
		local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
		Make.text({
			Text = `<b>{item.name}</b>  <font color="#{Theme.muted:ToHex()}">{item.description}</font>`,
			Size = UDim2.new(1, -130, 1, 0),
			Parent = row,
		})
		local key = item.key
		Make.button({
			Text = `✦ {item.cost}`,
			Size = UDim2.fromOffset(120, 32),
			BackgroundColor3 = if data.tokens >= item.cost then Theme.gold else Theme.panel3,
			TextColor3 = Theme.bg,
			Parent = row,
		}, function()
			local ok, msg = EventService:BuyTokenItem(key)
			Toast.show(msg, if ok then "success" else "warn")
		end)
	end
end

function ShopController:RefreshRewards()
	if not rewards.isOpen() then
		return
	end
	local DataController = Knit.GetController("DataController")
	local SpeedService = Knit.GetService("SpeedService")
	local data = DataController:Get()
	if not data then
		return
	end
	clear(rewardsFrame)
	local FR = Config.Speed.FreeRewards
	local total = FR.like.speed + FR.favourite.speed + FR.group.speed
	Make.text({
		Text = `Claim all three for <b>{Format.short(total)} free speed</b>.`,
		TextSize = 17,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = rewardsFrame,
	})
	local items = {
		{
			key = "like",
			label = "👍 " .. FR.like.label,
			speed = FR.like.speed,
			hint = "Hit the thumbs-up on the game page, then claim.",
		},
		{
			key = "favourite",
			label = "⭐ " .. FR.favourite.label,
			speed = FR.favourite.speed,
			hint = "Hit the star on the game page, then claim.",
		},
		{
			key = "group",
			label = "👥 " .. FR.group.label,
			speed = FR.group.speed,
			hint = "Join the group, then claim (checked for real).",
		},
	}
	for _, it in items do
		local claimed = (data.freeRewards :: any)[it.key] == true
		local card = Make.card({ Parent = rewardsFrame })
		local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
		Make.text({
			Text = `<b>{it.label}</b>  +{Format.short(it.speed)} speed`,
			Size = UDim2.new(1, -150, 1, 0),
			Parent = row,
		})
		local btn = Make.button({
			Text = if claimed then "✅ Claimed" else "Claim",
			Size = UDim2.fromOffset(140, 30),
			BackgroundColor3 = if claimed then Theme.panel3 else Theme.green,
			TextColor3 = if claimed then Theme.text else Theme.bg,
			Parent = row,
		})
		Make.text({ Text = it.hint, TextColor3 = Theme.muted, TextSize = 13, Parent = card })
		local key = it.key
		btn.Activated:Connect(function()
			if claimed then
				return
			end
			btn.Text = "Checking..."
			task.spawn(function()
				local ok, msg = SpeedService:ClaimFreeReward(key)
				Toast.show(msg, if ok then "success" else "warn")
				self:RefreshRewards()
			end)
		end)
	end
end

function ShopController:KnitStart()
	self:_build()
	local HUD = Knit.GetController("HUDController")
	HUD:AddRailButton("🛒 Shop", Theme.accent, function()
		shop.toggle()
	end)
	HUD:AddRailButton("🎁 Rewards", Theme.gold, function()
		rewards.toggle()
	end)
	Knit.GetController("DataController").Changed:Connect(function()
		self:Refresh()
		self:RefreshRewards()
	end)
	Knit.GetService("MonetizationService").Purchased:Connect(function(kind: string, key: string)
		Toast.show(`Purchased {key}!`, "success")
	end)
end

function ShopController:Open()
	shop.setOpen(true)
end

return ShopController
