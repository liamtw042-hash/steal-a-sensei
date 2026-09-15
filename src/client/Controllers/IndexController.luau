--!strict
-- IndexController: collection log per zone with completion rewards.
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

local IndexController = Knit.CreateController({ Name = "IndexController" })

local window: Window.Window
local scroll: ScrollingFrame

local function clear(parent: Instance)
	for _, c in parent:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

function IndexController:Refresh()
	if not window.isOpen() then
		return
	end
	local data = Knit.GetController("DataController"):Get()
	local FighterService = Knit.GetService("FighterService")
	if not data then
		return
	end
	clear(scroll)
	local found, total = 0, #Config.Fighters.Roster
	for _, def in Config.Fighters.Roster do
		if data.index[def.name] then
			found += 1
		end
	end
	Make.text({
		Text = `Discovered <b>{found}/{total}</b> fighters. Complete a zone's set for speed, cash and a skin.`,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = scroll,
	})

	for _, zone in Config.Zones.List do
		local set = Config.Fighters.ofZone(zone.id)
		if #set == 0 then
			continue
		end
		local card = Make.card({ Parent = scroll })
		local complete = true
		local lines = {}
		for _, def in set do
			local have = data.index[def.name] == true
			if not have then
				complete = false
			end
			local color = if have then Rarity.color(def.rarity):ToHex() else Theme.muted:ToHex()
			table.insert(
				lines,
				`<font color="#{color}">{if have then "✅ " .. def.displayName else "❔ ???"}</font> <font color="#{Theme.muted:ToHex()}">({def.rarity})</font>`
			)
		end
		local reward = Config.Fighters.IndexRewards[zone.id]
		local claimed = data.indexClaimed[tostring(zone.id)] == true
		local head = Make.row({ Size = UDim2.new(1, 0, 0, 30), Parent = card })
		Make.text({
			Text = `<b>{zone.id}. {zone.name}</b>`,
			TextSize = 18,
			Size = UDim2.new(1, -150, 1, 0),
			Parent = head,
		})
		if reward then
			local zoneId = zone.id
			Make.button({
				Text = if claimed then "✅ Claimed" elseif complete then "Claim reward" else "Incomplete",
				Size = UDim2.fromOffset(140, 28),
				BackgroundColor3 = if claimed then Theme.panel3 elseif complete then Theme.green else Theme.panel3,
				TextColor3 = if complete and not claimed then Theme.bg else Theme.text,
				Parent = head,
			}, function()
				if complete and not claimed then
					local ok, msg = FighterService:ClaimIndexReward(zoneId)
					Toast.show(msg, if ok then "success" else "warn")
				end
			end)
		end
		Make.text({
			Text = table.concat(lines, "   "),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = card,
		})
		if reward then
			Make.text({
				Text = `Reward: +{Format.short(reward.speed)} speed, {Format.cash(reward.cash)}, "{reward.skin}" skin`,
				TextColor3 = Theme.muted,
				TextSize = 13,
				Parent = card,
			})
		end
	end
end

function IndexController:KnitStart()
	window = Window.new("Index", "📖 Index", UDim2.fromOffset(680, 520))
	scroll = Make.scroll({ Parent = window.content }, 6)
	window.onOpen(function()
		self:Refresh()
	end)
	Knit.GetController("HUDController"):AddRailButton("📖 Index", Theme.panel3, function()
		window.toggle()
	end)
	Knit.GetController("DataController").Changed:Connect(function()
		self:Refresh()
	end)
end

return IndexController
