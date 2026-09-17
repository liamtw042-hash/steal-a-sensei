--!strict
--[[
	BaseController: local gate collision (locked bases block everyone but the owner + friends),
	the Base window (slots, inventory, scroll bag, fuse, upgrades, friends) and theft alerts.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Economy = require(ReplicatedStorage.Shared.Util.Economy)
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)
local Window = require(script.Parent.Parent.UI.Window)
local Toast = require(script.Parent.Parent.UI.Toast)

local BaseController = Knit.CreateController({ Name = "BaseController" })

local localPlayer = Players.LocalPlayer
local window: Window.Window
local pages: { [string]: Frame }
local selectTab: (name: string) -> () = function() end

local function fighterName(f: Types.Fighter): string
	local def = Config.Fighters.get(f.name)
	return if def then def.displayName else f.name
end

--------------------------------------------------------------------------------
-- Gates
--------------------------------------------------------------------------------

local function isAuthorized(folder: Instance): boolean
	local owner = folder:GetAttribute("OwnerUserId")
	if owner == localPlayer.UserId then
		return true
	end
	local friendsJson = folder:GetAttribute("Friends")
	if typeof(friendsJson) == "string" then
		local ok, friends = pcall(function()
			return HttpService:JSONDecode(friendsJson)
		end)
		if ok and typeof(friends) == "table" and friends[tostring(localPlayer.UserId)] then
			return true
		end
	end
	return false
end

function BaseController:_gateLoop()
	local basesFolder = Workspace:WaitForChild("Bases", 60)
	if not basesFolder then
		return
	end
	while true do
		local now = Workspace:GetServerTimeNow()
		for _, folder in basesFolder:GetChildren() do
			local gates = folder:FindFirstChild("Gates")
			if not gates then
				continue
			end
			local lockedUntil = folder:GetAttribute("LockedUntil")
			local locked = typeof(lockedUntil) == "number" and lockedUntil > now
			local block = locked and not isAuthorized(folder)
			for _, gate in gates:GetChildren() do
				if gate:IsA("BasePart") then
					gate.CanCollide = block
				end
			end
			-- you can never steal from your own base, so hide those prompts locally
			if folder:GetAttribute("OwnerUserId") == localPlayer.UserId then
				for _, d in folder:GetDescendants() do
					if d:IsA("ProximityPrompt") and d.Name == "StealPrompt" and d.Enabled then
						d.Enabled = false
					end
				end
			end
		end
		task.wait(0.25)
	end
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local slotsScroll: ScrollingFrame
local inventoryScroll: ScrollingFrame
local upgradesFrame: Frame
local friendsScroll: ScrollingFrame
local headerLabel: TextLabel

local function clear(parent: Instance)
	for _, c in parent:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

function BaseController:_buildWindow()
	window = Window.new("Base", "🏯 Your Base", UDim2.fromOffset(720, 500))
	headerLabel = Make.text({
		Text = "",
		TextSize = 15,
		TextColor3 = Theme.muted,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = window.content,
	})
	local tabHost = Make.frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -26),
		Position = UDim2.fromOffset(0, 26),
		Parent = window.content,
	})
	pages, selectTab = Window.tabs(tabHost, { "Slots", "Inventory", "Upgrades", "Friends" })

	slotsScroll = Make.scroll({ Parent = pages.Slots }, 6)
	inventoryScroll = Make.scroll({ Parent = pages.Inventory }, 6)
	upgradesFrame = Make.frame({ BackgroundTransparency = 1, Parent = pages.Upgrades })
	Make.list(upgradesFrame, 8)
	friendsScroll = Make.scroll({ Parent = pages.Friends }, 6)

	window.onOpen(function()
		self:Refresh()
	end)
end

function BaseController:Refresh()
	if not window or not window.isOpen() then
		return
	end
	local DataController = Knit.GetController("DataController")
	local BaseService = Knit.GetService("BaseService")
	local FighterService = Knit.GetService("FighterService")
	local PowerService = Knit.GetService("PowerService")
	local data = DataController:Get()
	if not data then
		return
	end
	local info = BaseService:GetBaseInfo()
	if not info then
		headerLabel.Text = "No base assigned yet..."
		return
	end
	headerLabel.Text =
		`Base {info.index}  •  {info.unlockedSlots} slots unlocked (floor {info.unlockedFloor})  •  income {Format.cash(
			Economy.incomePerSecond(data)
		)}/s`

	-- Slots
	clear(slotsScroll)
	local bySlot: { [number]: Types.Fighter } = {}
	for _, f in data.fighters do
		if f.slot then
			bySlot[f.slot] = f
		end
	end
	local usable: { number } = info.usableSlots or {}
	for _, i in usable do
		local f = bySlot[i]
		local h = data.hatching[tostring(i)]
		local card = Make.card({ Parent = slotsScroll })
		local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
		if f then
			local mut = if f.mutation then `<font color="#ffd166">{f.mutation}</font> ` else ""
			Make.text({
				Text = `<b>Slot {i}</b>  {mut}<font color="#{Rarity.color(f.rarity):ToHex()}">{fighterName(f)}</font>  •  {f.rarity} Lv {f.level}  •  {Format.cash(
					Economy.fighterCps(f)
				)}/s`,
				Size = UDim2.new(1, -110, 1, 0),
				Parent = row,
			})
			local id = f.id
			Make.button(
				{ Text = "Store", Size = UDim2.fromOffset(100, 30), BackgroundColor3 = Theme.panel3, Parent = row },
				function()
					local ok, msg = FighterService:UnplaceFighter(id)
					Toast.show(msg, if ok then "success" else "warn")
				end
			)
		elseif h then
			local remaining = h.hatchAt - os.time()
			Make.text({
				Text = `<b>Slot {i}</b>  <font color="#{Rarity.color(h.rarity):ToHex()}">{h.rarity} scroll</font> hatching in {Format.time(
					remaining
				)}`,
				Size = UDim2.new(1, 0, 1, 0),
				Parent = row,
			})
		else
			Make.text({
				Text = `<b>Slot {i}</b>  <font color="#{Theme.muted:ToHex()}">empty</font>`,
				Size = UDim2.new(1, 0, 1, 0),
				Parent = row,
			})
		end
	end

	-- Inventory (unplaced fighters + scroll bag + fuse)
	clear(inventoryScroll)
	local counts: { [string]: number } = {}
	for _, f in data.fighters do
		counts[f.name] = (counts[f.name] or 0) + 1
	end
	local anyInv = false
	for _, f in data.fighters do
		if f.slot then
			continue
		end
		anyInv = true
		local card = Make.card({ Parent = inventoryScroll })
		local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
		Make.text({
			Text = `<font color="#{Rarity.color(f.rarity):ToHex()}">{fighterName(f)}</font>  •  {f.rarity} Lv {f.level}  •  {Format.cash(
				Economy.fighterCps(f)
			)}/s`,
			Size = UDim2.new(1, -110, 1, 0),
			Parent = row,
		})
		local id = f.id
		Make.button({
			Text = "Place",
			Size = UDim2.fromOffset(100, 30),
			BackgroundColor3 = Theme.green,
			TextColor3 = Theme.bg,
			Parent = row,
		}, function()
			-- first free usable slot
			local target: number? = nil
			for _, i in usable do
				if not bySlot[i] and not data.hatching[tostring(i)] then
					target = i
					break
				end
			end
			if not target then
				Toast.show("No free slot", "warn")
				return
			end
			local ok, msg = FighterService:PlaceFighter(id, target)
			Toast.show(msg, if ok then "success" else "warn")
		end)
	end
	for name, n in counts do
		if n >= Config.Fighters.Fuse.required then
			anyInv = true
			local card = Make.card({ Parent = inventoryScroll })
			local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
			Make.text({
				Text = `🔥 Fuse {Config.Fighters.Fuse.required} x {name} into the next rarity`,
				Size = UDim2.new(1, -110, 1, 0),
				Parent = row,
			})
			local fuseName = name
			Make.button(
				{ Text = "Fuse", Size = UDim2.fromOffset(100, 30), BackgroundColor3 = Theme.accent, Parent = row },
				function()
					local ok, msg = FighterService:Fuse(fuseName)
					Toast.show(msg, if ok then "success" else "warn")
				end
			)
		end
	end
	for i, entry in data.scrollBag do
		anyInv = true
		local card = Make.card({ Parent = inventoryScroll })
		local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
		Make.text({
			Text = `📜 <font color="#{Rarity.color(entry.rarity):ToHex()}">{entry.rarity} scroll</font> (bag)`,
			Size = UDim2.new(1, -110, 1, 0),
			Parent = row,
		})
		local idx = i
		Make.button({
			Text = "Hatch",
			Size = UDim2.fromOffset(100, 30),
			BackgroundColor3 = Theme.green,
			TextColor3 = Theme.bg,
			Parent = row,
		}, function()
			local ok, msg = FighterService:PlaceScrollFromBag(idx, nil)
			Toast.show(msg, if ok then "success" else "warn")
		end)
	end
	if not anyInv then
		Make.text({
			Text = "Nothing stored. Fighters you unplace, scrolls with no free slot, and fusable sets show up here.",
			TextColor3 = Theme.muted,
			Size = UDim2.new(1, 0, 0, 40),
			Parent = inventoryScroll,
		})
	end

	-- Upgrades
	clear(upgradesFrame)
	local BAG = Config.Power.PunchingBag
	local tCard = Make.card({ Parent = upgradesFrame })
	Make.text({
		Text = `🥊 Punching Bag — level {data.bagLevel}/{BAG.maxLevel}`,
		TextSize = 18,
		Parent = tCard,
	})
	local nextCost = Config.Power.bagUpgradeCost(data.bagLevel)
	Make.text({
		Text = if nextCost
			then `Hold <b>left mouse</b> (R2 on gamepad) at the bag in your base to train. <b>{Format.short(
				Config.Power.punchPower(data.bagLevel)
			)} Power</b> per punch. Next level: {Format.short(Config.Power.punchPower(data.bagLevel + 1))} per punch.`
			else `Hold <b>left mouse</b> (R2 on gamepad) at the bag in your base to train. <b>{Format.short(
				Config.Power.punchPower(data.bagLevel)
			)} Power</b> per punch — fully upgraded.`,
		TextColor3 = Theme.muted,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = tCard,
	})
	if nextCost then
		Make.button({
			Text = `Upgrade for {Format.cash(nextCost)}`,
			Size = UDim2.fromOffset(240, 34),
			BackgroundColor3 = Theme.accent2,
			TextColor3 = Theme.bg,
			Parent = tCard,
		}, function()
			local ok, msg = PowerService:UpgradeBag()
			Toast.show(msg, if ok then "success" else "warn")
		end)
	end
	local aCard = Make.card({ Parent = upgradesFrame })
	local A = Config.Base.AlarmTrap
	Make.text({ Text = "🚨 Alarm Trap", TextSize = 18, Parent = aCard })
	Make.text({
		Text = `Stuns intruders for {A.stunSeconds}s and gives you a {A.ownerSpeedMultiplier}x speed burst. {A.cooldownSeconds}s cooldown.`,
		TextColor3 = Theme.muted,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = aCard,
	})
	if data.alarmTrap then
		Make.text({ Text = "✅ Installed", TextColor3 = Theme.green, Parent = aCard })
	else
		Make.button({
			Text = `Install for {Format.cash(A.cost)}`,
			Size = UDim2.fromOffset(240, 34),
			BackgroundColor3 = Theme.accent2,
			TextColor3 = Theme.bg,
			Parent = aCard,
		}, function()
			local ok, msg = BaseService:BuyAlarmTrap()
			Toast.show(msg, if ok then "success" else "warn")
		end)
	end
	local lCard = Make.card({ Parent = upgradesFrame })
	Make.text({ Text = "🔒 Lock", TextSize = 18, Parent = lCard })
	local lockSeconds = Config.Base.Lock.padLockSeconds
		+ data.rebirths * Config.Base.Lock.perRebirthBonusSeconds
		+ (if data.gamepasses.VIP then Config.Base.Lock.vipBonusSeconds else 0)
	Make.text({
		Text = `Step on your lock pad (or use the HUD button) to lock for {lockSeconds}s. +{Config.Base.Lock.perRebirthBonusSeconds}s per rebirth, +{Config.Base.Lock.vipBonusSeconds}s with VIP.`,
		TextColor3 = Theme.muted,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = lCard,
	})

	-- Friends
	clear(friendsScroll)
	Make.text({
		Text = "Friends can walk through your lasers and can't steal from you.",
		TextColor3 = Theme.muted,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = friendsScroll,
	})
	local others = 0
	for _, p in Players:GetPlayers() do
		if p == localPlayer then
			continue
		end
		others += 1
		local allowed = data.friends[tostring(p.UserId)] == true
		local card = Make.card({ Parent = friendsScroll })
		local row = Make.row({ Size = UDim2.new(1, 0, 0, 34), Parent = card })
		Make.text({ Text = `{p.DisplayName} (@{p.Name})`, Size = UDim2.new(1, -130, 1, 0), Parent = row })
		local uid = p.UserId
		Make.button({
			Text = if allowed then "Remove" else "Allow",
			Size = UDim2.fromOffset(120, 30),
			BackgroundColor3 = if allowed then Theme.red else Theme.green,
			TextColor3 = Theme.bg,
			Parent = row,
		}, function()
			BaseService:SetFriend(uid, not allowed)
		end)
	end
	if others == 0 then
		Make.text({
			Text = "Nobody else is in the server right now.",
			TextColor3 = Theme.muted,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = friendsScroll,
		})
	end
end

--------------------------------------------------------------------------------

function BaseController:Open(tab: string?)
	window.setOpen(true)
	if tab then
		selectTab(tab)
	end
end

function BaseController:KnitStart()
	self:_buildWindow()
	local HUD = Knit.GetController("HUDController")
	HUD:AddRailButton("🏯 Base", Theme.panel3, function()
		window.toggle()
	end)
	Knit.GetController("DataController").Changed:Connect(function()
		self:Refresh()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if window.isOpen() and pages.Slots.Visible then
				self:Refresh() -- hatch countdowns
			end
		end
	end)
	task.spawn(function()
		self:_gateLoop()
	end)

	-- Theft alert: highlight the thief so you can chase them
	local BaseService = Knit.GetService("BaseService")
	BaseService.TheftAlert:Connect(function(thiefUserId: number, fighterNameText: string)
		local thief = Players:GetPlayerByUserId(thiefUserId)
		local char = if thief then thief.Character else nil
		Toast.show(
			`🚨 {if thief then thief.DisplayName else "Someone"} is stealing your {fighterNameText}! Chase them!`,
			"alarm",
			6
		)
		if char then
			local hl = Instance.new("Highlight")
			hl.Name = "ThiefHighlight"
			hl.FillColor = Theme.red
			hl.OutlineColor = Color3.new(1, 1, 1)
			hl.FillTransparency = 0.5
			hl.Parent = char
			task.delay(25, function()
				hl:Destroy()
			end)
		end
	end)
end

return BaseController
