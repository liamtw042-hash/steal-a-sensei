--!strict
--[[
	EventController: event banner with countdown, Rift HP bar, click/tap to attack the Rift.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)

local EventController = Knit.CreateController({ Name = "EventController" })

local banner: Frame
local bannerTitle: TextLabel
local bannerBody: TextLabel
local riftFrame: Frame
local riftFill: Frame
local riftText: TextLabel

local bannerState: any = nil
local riftState: any = nil

function EventController:KnitInit()
	local gui = Make.screen("Events", 4)
	banner = Make.frame({
		Size = UDim2.fromOffset(420, 58),
		Position = UDim2.new(0.5, 0, 0, 100),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	Make.corner(banner)
	Make.stroke(banner, Theme.gold, 2, 0.3)
	Make.padding(banner, 12, 6)
	Make.list(banner, 0)
	bannerTitle = Make.text({
		Text = "",
		TextSize = 18,
		Font = Theme.fontBlack,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = banner,
	})
	bannerBody = Make.text({
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = banner,
	})

	riftFrame = Make.frame({
		Size = UDim2.fromOffset(420, 30),
		Position = UDim2.new(0.5, 0, 0, 164),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.panel,
		Visible = false,
		Parent = gui,
	})
	Make.corner(riftFrame, Theme.cornerSmall)
	Make.stroke(riftFrame, Theme.red, 2, 0.3)
	riftFill = Make.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.red, Parent = riftFrame })
	Make.corner(riftFill, Theme.cornerSmall)
	riftText = Make.text({
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = riftFrame,
	})
end

function EventController:KnitStart()
	local EventService = Knit.GetService("EventService")
	local ZoneService = Knit.GetService("ZoneService")

	EventService.Banner:Observe(function(state: any)
		bannerState = state
		banner.Visible = state ~= nil
	end)
	EventService.Rift:Observe(function(state: any)
		riftState = state
		riftFrame.Visible = state ~= nil
	end)
	EventService.Announce:Connect(function(text: string)
		Toast.show(text, "warn", 6)
	end)
	ZoneService.SurgeChanged:Connect(function(zoneId: number, active: boolean)
		if active then
			Toast.show(`Void Surge in {Config.Zones.get(zoneId).name}!`, "warn", 4)
		end
	end)

	task.spawn(function()
		while true do
			if bannerState then
				bannerTitle.Text = `✦ {bannerState.name}`
				local remaining = if typeof(bannerState.endsAt) == "number" then bannerState.endsAt - os.time() else 0
				bannerBody.Text = `{bannerState.text or ""}  ({Format.time(remaining)} left)`
			end
			if riftState then
				local frac = if riftState.maxHp > 0 then riftState.hp / riftState.maxHp else 0
				riftFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
				riftText.Text =
					`Rift Sensei  {Format.short(riftState.hp)} / {Format.short(riftState.maxHp)}  •  click it to attack`
			end
			task.wait(0.5)
		end
	end)

	-- click / tap to attack when a rift is up and you're close
	local localPlayer = Players.LocalPlayer
	local function tryAttack()
		if not riftState then
			return
		end
		local boss = Workspace:FindFirstChild("RiftBoss")
		local root = if boss then boss:FindFirstChild("HumanoidRootPart") else nil
		local char = localPlayer.Character
		local myRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and myRoot and myRoot:IsA("BasePart") then
			if (root.Position - myRoot.Position).Magnitude <= Config.Events.Rift.attackRange then
				EventService:AttackRift()
			end
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tryAttack()
		end
	end)
end

return EventController
