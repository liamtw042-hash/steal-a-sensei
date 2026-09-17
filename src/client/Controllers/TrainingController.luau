--!strict
--[[
	TrainingController: the punching bag.

	Stand at your bag and hold the punch input — left mouse button on PC, right trigger (R2) on
	a gamepad, or the on-screen button on mobile — and the server ticks Power up once a second.
	The action is only bound while you're in range of your own bag, so left-click behaves
	normally everywhere else. Pressing F at the bag buys the next upgrade level.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)

local TrainingController = Knit.CreateController({ Name = "TrainingController" })

local ACTION = "StealASenseiTrain"

local localPlayer = Players.LocalPlayer

local panel: Frame
local barFill: Frame
local titleLabel: TextLabel
local totalLabel: TextLabel
local perPunchLabel: TextLabel
local popupHolder: Frame
local hint: Frame
local hintLabel: TextLabel

local holding = false
local bound = false

function TrainingController:KnitInit()
	local gui = Make.screen("Training", 6)
	panel = Make.frame({
		Name = "TrainingPanel",
		Size = UDim2.fromOffset(340, 124),
		-- dead centre: clear of the HUD (top-left), base panel (top-right), hotbar and tutorial card (bottom)
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.panel,
		Visible = false,
		Parent = gui,
	})
	Make.corner(panel)
	Make.outline(panel)
	Make.shadow(panel, 6)
	Make.padding(panel, 14, 10)
	Make.list(panel, 4)

	titleLabel = Make.display({
		Text = "🥊 TRAINING...",
		TextSize = 22,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = panel,
	})

	local barBg = Make.frame({
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = Theme.panel3,
		Parent = panel,
	})
	Make.corner(barBg, 8)
	Make.outline(barBg, 2)
	barFill = Make.frame({
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.gold,
		Parent = barBg,
	})
	Make.corner(barFill, 8)
	Make.gloss(barFill)

	perPunchLabel = Make.text({
		Text = "",
		TextSize = 14,
		TextColor3 = Theme.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = panel,
	})
	totalLabel = Make.display({
		Text = "",
		TextSize = 20,
		TextColor3 = Theme.accent2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = panel,
	})

	-- floating "+N Power" numbers rise out of the panel on each punch
	popupHolder = Make.frame({
		Name = "Popups",
		Size = UDim2.fromOffset(340, 90),
		Position = UDim2.new(0.5, 0, 0.5, -70),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})

	-- "hold X to train" hint, shown while you're stood at the bag and not yet training
	hint = Make.frame({
		Name = "Hint",
		Size = UDim2.fromOffset(330, 44),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.panel,
		Visible = false,
		Parent = gui,
	})
	Make.corner(hint)
	Make.outline(hint)
	Make.shadow(hint, 5)
	Make.padding(hint, 12, 6)
	hintLabel = Make.display({
		Text = "",
		TextSize = 18,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = hint,
	})
end

-- What to tell the player to hold, based on what they're playing on
local function inputHint(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Hold the 🥊 button to train"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Hold R2 to train"
	end
	return "Hold left mouse to train"
end

function TrainingController:_setPanel(active: boolean)
	panel.Visible = active
	popupHolder.Visible = active
	if active then
		hint.Visible = false
		self:_refreshLabels()
	else
		barFill.Size = UDim2.fromScale(0, 1)
		hint.Visible = bound
	end
end

function TrainingController:_refreshLabels()
	local DataController = Knit.GetController("DataController")
	local data = DataController:Get()
	local level = if data then data.bagLevel else 1
	local per = Config.Power.punchPower(level)
	titleLabel.Text = `🥊 TRAINING... (Lv {level})`
	perPunchLabel.Text = `+{Format.short(per)} Power per punch`
	totalLabel.Text = `💪 {Format.short(DataController.Power)} Power`
end

function TrainingController:_punch(gain: number)
	-- refill the bar over one punch interval
	local tick = Config.Power.PunchingBag.tickSeconds
	barFill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(barFill, TweenInfo.new(tick, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	self:_refreshLabels()

	local popup = Make.display({
		Text = `+{Format.short(gain)}`,
		TextSize = 26,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromScale(0, 1),
		Parent = popupHolder,
	})
	TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.95, function()
		popup:Destroy()
	end)
end

function TrainingController:_start()
	if holding then
		return
	end
	holding = true
	Knit.GetService("PowerService"):StartTraining()
end

function TrainingController:_stop()
	if not holding then
		return
	end
	holding = false
	Knit.GetService("PowerService"):StopTraining()
end

-- The bag in the player's own base, or nil if they have no base yet
function TrainingController:_myBag(): BasePart?
	local idx = Knit.GetService("BaseService").BaseIndex:Get()
	if typeof(idx) ~= "number" or idx <= 0 then
		return nil
	end
	local bases = Workspace:FindFirstChild("Bases")
	local folder = if bases then bases:FindFirstChild("Base" .. idx) else nil
	local bag = if folder then folder:FindFirstChild("PunchingBag") else nil
	return if bag and bag:IsA("BasePart") then bag else nil
end

function TrainingController:_bind()
	if bound then
		return
	end
	bound = true
	ContextActionService:BindAction(ACTION, function(_action: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			self:_start()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			self:_stop()
		end
		-- Pass so a left click still reaches everything else (UI, tools, the rift boss)
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION, "🥊")
	hintLabel.Text = inputHint()
	hint.Visible = not panel.Visible
end

function TrainingController:_unbind()
	if not bound then
		return
	end
	bound = false
	ContextActionService:UnbindAction(ACTION)
	hint.Visible = false
	self:_stop()
end

function TrainingController:KnitStart()
	local PowerService = Knit.GetService("PowerService")
	local DataController = Knit.GetController("DataController")

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player == localPlayer and prompt.Name == "UpgradePrompt" then
			local ok, msg = PowerService:UpgradeBag()
			Toast.show(msg, if ok then "success" else "warn")
		end
	end)

	localPlayer.CharacterAdded:Connect(function()
		holding = false
		self:_unbind()
	end)

	PowerService.Training:Observe(function(active: boolean)
		self:_setPanel(active == true)
	end)
	PowerService.Punch:Connect(function(gain: number)
		self:_punch(gain)
	end)
	DataController.PowerChanged:Connect(function()
		if panel.Visible then
			self:_refreshLabels()
		end
	end)

	-- bind the punch input only while stood at your own bag
	task.spawn(function()
		while true do
			task.wait(0.25)
			local bag = self:_myBag()
			local char = localPlayer.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			local inRange = bag ~= nil
				and root ~= nil
				and root:IsA("BasePart")
				and (root.Position - (bag :: BasePart).Position).Magnitude <= Config.Power.PunchingBag.range
			if inRange then
				self:_bind()
			else
				self:_unbind()
			end
		end
	end)
end

return TrainingController
