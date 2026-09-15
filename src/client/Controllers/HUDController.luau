--!strict
--[[
	HUDController: always-visible HUD. Cash + speed (top-left), income, base lock status +
	lock button (top-right), carrying indicator + boss warning (top-centre), the left-hand
	button rail other controllers register their windows on, and server alerts as toasts.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Economy = require(ReplicatedStorage.Shared.Util.Economy)
local SpeedMath = require(ReplicatedStorage.Shared.Util.SpeedMath)
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)

local HUDController = Knit.CreateController({
	Name = "HUDController",
})

local gui: ScreenGui
local rail: Frame
local cashLabel: TextLabel
local incomeLabel: TextLabel
local speedLabel: TextLabel
local walkLabel: TextLabel
local carryLabel: TextLabel
local bossLabel: TextLabel
local lockLabel: TextLabel
local lockButton: TextButton
local tokensLabel: TextLabel

local currentBoss: string? = nil

function HUDController:KnitInit()
	gui = Make.screen("HUD", 1)

	-- Top-left stats
	local stats = Make.frame({
		Name = "Stats",
		Size = UDim2.fromOffset(250, 118),
		Position = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	Make.corner(stats)
	Make.outline(stats)
	Make.shadow(stats, 5)
	Make.padding(stats, 12, 8)
	Make.list(stats, 2)
	cashLabel = Make.display({
		Text = "💰 $0",
		TextSize = 30,
		TextColor3 = Theme.green,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = stats,
	})
	incomeLabel = Make.text({
		Text = "+$0/s",
		TextSize = 14,
		TextColor3 = Theme.muted,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = stats,
	})
	speedLabel = Make.display({
		Text = "⚡ 0 speed",
		TextSize = 22,
		TextColor3 = Theme.accent2,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = stats,
	})
	walkLabel =
		Make.text({ Text = "", TextSize = 13, TextColor3 = Theme.muted, Size = UDim2.new(1, 0, 0, 16), Parent = stats })
	tokensLabel =
		Make.text({ Text = "", TextSize = 13, TextColor3 = Theme.gold, Size = UDim2.new(1, 0, 0, 16), Parent = stats })

	-- Left rail
	rail = Make.frame({
		Name = "Rail",
		Size = UDim2.fromOffset(120, 400),
		Position = UDim2.fromOffset(16, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Make.list(rail, 8)

	-- Top-centre: carrying + boss warning
	local centre = Make.frame({
		Name = "Centre",
		Size = UDim2.fromOffset(520, 90),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Make.list(centre, 4, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
	bossLabel = Make.display({
		Text = "",
		TextSize = 30,
		TextColor3 = Theme.red,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = centre,
	})
	carryLabel = Make.display({
		Text = "",
		TextSize = 20,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = centre,
	})

	-- Top-right: base lock
	local basePanel = Make.frame({
		Name = "BasePanel",
		Size = UDim2.fromOffset(230, 84),
		Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	Make.corner(basePanel)
	Make.outline(basePanel)
	Make.shadow(basePanel, 5)
	Make.padding(basePanel, 12, 8)
	Make.list(basePanel, 6)
	lockLabel = Make.text({ Text = "Base: --", TextSize = 16, Size = UDim2.new(1, 0, 0, 20), Parent = basePanel })
	lockButton = Make.button({
		Text = "🔒 Lock Base",
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Theme.gold,
		TextColor3 = Theme.bg,
		Parent = basePanel,
	}, function()
		local ok, msg = Knit.GetService("BaseService"):LockBase()
		Toast.show(msg, if ok then "lock" else "warn")
	end)
end

function HUDController:AddRailButton(text: string, color: Color3?, onClick: () -> ()): TextButton
	local btn = Make.button({
		Text = text,
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 19,
		BackgroundColor3 = color or Theme.panel3,
		Parent = rail,
	}, onClick)
	return btn
end

function HUDController:KnitStart()
	local DataController = Knit.GetController("DataController")
	local BaseService = Knit.GetService("BaseService")
	local BossService = Knit.GetService("BossService")
	local CarryService = Knit.GetService("CarryService")
	local FighterService = Knit.GetService("FighterService")
	local TheftService = Knit.GetService("TheftService")
	local SpeedService = Knit.GetService("SpeedService")

	DataController.CashChanged:Connect(function(cash: number)
		cashLabel.Text = "💰 " .. Format.cash(cash)
	end)
	DataController.SpeedChanged:Connect(function(speed: number)
		speedLabel.Text = `⚡ {Format.short(speed)} speed`
		walkLabel.Text = `walk speed {string.format("%.1f", SpeedMath.walkSpeedFor(speed))}`
	end)
	DataController:Observe(function(data)
		incomeLabel.Text =
			`+{Format.cash(Economy.incomePerSecond(data))}/s  •  rebirth {data.rebirths} (x{Config.Rebirth.multiplier(
				data.rebirths
			)})`
		tokensLabel.Text = if data.tokens > 0 then `✦ {data.tokens} rift tokens` else ""
	end)
	SpeedService.TreadmillActive:Observe(function(active: boolean)
		if active then
			local data = DataController:Get()
			local rate = if data then Config.Speed.Treadmill.ratePerSecond(data.treadmillLevel) else 0
			walkLabel.Text = `🏃 treadmill +{Format.short(rate)} speed/s`
		end
	end)

	BaseService.Alert:Connect(function(text: string, kind: string)
		Toast.show(text, kind)
	end)
	FighterService.Notice:Connect(function(text: string)
		Toast.show(text, "success")
	end)
	FighterService.Hatched:Connect(function(fighter: any)
		local mut = if fighter.mutation then `{fighter.mutation} ` else ""
		Toast.show(`Hatched a {mut}{fighter.rarity} {fighter.name}!`, "success", 5)
	end)
	FighterService.Evolved:Connect(function(fighter: any)
		Toast.show(`Evolved into a {fighter.rarity} {fighter.name}!`, "success", 5)
	end)
	TheftService.Started:Connect(function(fighterName: string, ownerName: string)
		Toast.show(`Grabbed {ownerName}'s {fighterName}. RUN HOME!`, "warn", 4)
	end)

	CarryService.Changed:Connect(function(info: any)
		if not info then
			carryLabel.Text = ""
		elseif info.kind == "scroll" then
			carryLabel.Text = `📜 Carrying a {info.rarity} scroll — get inside your base gates!`
		else
			carryLabel.Text = `🥷 Carrying {info.name} — get home! (slowed 30%)`
		end
	end)
	BossService.ChaseState:Connect(function(bossName: string?)
		currentBoss = bossName
		bossLabel.Text = if bossName then `⚠ {string.upper(bossName)} IS CHASING YOU!` else ""
	end)
	BossService.Caught:Connect(function(bossName: string)
		Toast.show(`Caught by the {bossName}! Your scroll dropped where you fell.`, "alarm", 4)
		bossLabel.Text = ""
	end)

	-- Base lock status from the base folder's attributes
	task.spawn(function()
		local bases = Workspace:WaitForChild("Bases", 30)
		while true do
			local idx = BaseService.BaseIndex:Get()
			local folder = if bases
					and typeof(idx) == "number"
					and idx > 0
				then bases:FindFirstChild("Base" .. idx)
				else nil
			if folder then
				local now = Workspace:GetServerTimeNow()
				local lockedUntil = folder:GetAttribute("LockedUntil")
				local cooldownUntil = folder:GetAttribute("LockCooldownUntil")
				local lu = if typeof(lockedUntil) == "number" then lockedUntil else 0
				local cu = if typeof(cooldownUntil) == "number" then cooldownUntil else 0
				if lu > now then
					lockLabel.Text = `Base {idx}: 🔒 LOCKED {Format.time(lu - now)}`
					lockLabel.TextColor3 = Theme.green
					lockButton.Visible = false
				elseif cu > now then
					lockLabel.Text = `Base {idx}: 🔓 open • relock in {Format.time(cu - now)}`
					lockLabel.TextColor3 = Theme.gold
					lockButton.Visible = false
				else
					lockLabel.Text = `Base {idx}: 🔓 OPEN`
					lockLabel.TextColor3 = Theme.red
					lockButton.Visible = true
				end
			else
				lockLabel.Text = "Base: assigning..."
				lockButton.Visible = false
			end
			task.wait(0.5)
		end
	end)

	-- Boss warning pulse
	task.spawn(function()
		while true do
			if currentBoss then
				bossLabel.TextTransparency = 0
				task.wait(0.4)
				bossLabel.TextTransparency = 0.5
				task.wait(0.4)
			else
				task.wait(0.5)
			end
		end
	end)

	local localPlayer = Players.LocalPlayer
	localPlayer.CharacterAdded:Connect(function()
		bossLabel.Text = ""
		carryLabel.Text = ""
	end)
end

function HUDController:GetGui(): ScreenGui
	return gui
end

return HUDController
