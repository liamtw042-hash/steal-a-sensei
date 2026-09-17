--!strict
--[[
	TrainingController: the punching bag.

	Hold E at your bag (tap and hold on mobile) and the server ticks Power up once a second.
	This controller turns the prompt's hold begin/end into StartTraining/StopTraining calls and
	draws the "Training..." panel: a bar that fills each punch, the Power per punch, and the
	live Power total climbing. Pressing F at the bag buys the next upgrade level.
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)

local TrainingController = Knit.CreateController({ Name = "TrainingController" })

local localPlayer = Players.LocalPlayer

local panel: Frame
local barFill: Frame
local titleLabel: TextLabel
local totalLabel: TextLabel
local perPunchLabel: TextLabel
local popupHolder: Frame

local holding = false

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
end

function TrainingController:_setPanel(active: boolean)
	panel.Visible = active
	popupHolder.Visible = active
	if active then
		self:_refreshLabels()
	else
		barFill.Size = UDim2.fromScale(0, 1)
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
	local PowerService = Knit.GetService("PowerService")
	PowerService:StartTraining()
end

function TrainingController:_stop()
	if not holding then
		return
	end
	holding = false
	local PowerService = Knit.GetService("PowerService")
	PowerService:StopTraining()
end

function TrainingController:KnitStart()
	local PowerService = Knit.GetService("PowerService")
	local DataController = Knit.GetController("DataController")

	local function isTrainPrompt(prompt: ProximityPrompt): boolean
		return prompt.Name == "TrainPrompt"
	end

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, player: Player)
		if player == localPlayer and isTrainPrompt(prompt) then
			self:_start()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt, player: Player)
		if player == localPlayer and isTrainPrompt(prompt) then
			self:_stop()
		end
	end)
	-- walking away (or the prompt being hidden for any reason) also stops the hold
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		if isTrainPrompt(prompt) then
			self:_stop()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player == localPlayer and prompt.Name == "UpgradePrompt" then
			local ok, msg = PowerService:UpgradeBag()
			Toast.show(msg, if ok then "success" else "warn")
		end
	end)

	localPlayer.CharacterAdded:Connect(function()
		holding = false
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
end

return TrainingController
