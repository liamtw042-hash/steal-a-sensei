--!strict
--[[
	TutorialController: first-join walkthrough. Three steps with a floating arrow over the
	target and an instruction card: grab a scroll -> run it home -> lock your base.
	Dismissable; shown once (profile flag `tutorialDone`).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)

local TutorialController = Knit.CreateController({ Name = "TutorialController" })

type Step = { title: string, body: string, target: () -> BasePart? }

local localPlayer = Players.LocalPlayer
local card: Frame
local cardTitle: TextLabel
local cardBody: TextLabel
local stepLabel: TextLabel
local arrow: BillboardGui
local arrowAny: any -- BillboardGui.Adornee is typed non-optional
local arrowLabel: TextLabel
local arrowAdornee: BasePart? = nil
local stepIndex = 0
local active = false
local steps: { Step } = {}

local function nearestNest(): BasePart?
	local zones = Workspace:FindFirstChild("Zones")
	local zone = if zones then zones:FindFirstChild("TrainingGrounds") else nil
	local nests = if zone then zone:FindFirstChild("Nests") else nil
	if not nests then
		return nil
	end
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local best: BasePart? = nil
	local bestDist = math.huge
	for _, n in nests:GetChildren() do
		if n:IsA("BasePart") then
			local d = if root and root:IsA("BasePart") then (n.Position - root.Position).Magnitude else 0
			if d < bestDist then
				bestDist = d
				best = n
			end
		end
	end
	return best
end

local function myBasePart(name: string): BasePart?
	local idx = Knit.GetService("BaseService").BaseIndex:Get()
	local bases = Workspace:FindFirstChild("Bases")
	local folder = if bases and typeof(idx) == "number" and idx > 0 then bases:FindFirstChild("Base" .. idx) else nil
	local part = if folder then folder:FindFirstChild(name) else nil
	return if part and part:IsA("BasePart") then part else nil
end

function TutorialController:KnitInit()
	local gui = Make.screen("Tutorial", 20)
	card = Make.frame({
		Size = UDim2.fromOffset(420, 120),
		Position = UDim2.new(0.5, 0, 1, -150),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.panel,
		Visible = false,
		Parent = gui,
	})
	Make.corner(card)
	Make.outline(card)
	Make.shadow(card, 6)
	Make.padding(card, 14, 10)
	Make.list(card, 4)
	stepLabel = Make.text({
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.accent2,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = card,
	})
	cardTitle = Make.display({
		Text = "",
		TextSize = 22,
		TextColor3 = Theme.gold,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = card,
	})
	cardBody = Make.text({ Text = "", TextSize = 15, Size = UDim2.new(1, 0, 0, 36), Parent = card })
	Make.button({
		Text = "Skip ✕",
		Size = UDim2.fromOffset(84, 28),
		TextSize = 14,
		Position = UDim2.new(1, -8, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.panel3,
		Parent = card,
	}, function()
		self:Finish()
	end)

	arrow = Make.new("BillboardGui", {
		Name = "TutorialArrow",
		Size = UDim2.fromOffset(160, 90),
		StudsOffset = Vector3.new(0, 7, 0),
		AlwaysOnTop = true,
		Enabled = false,
		Parent = gui,
	}) :: BillboardGui
	arrowAny = arrow
	arrowLabel = Make.display({
		Text = "▼",
		TextSize = 56,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 60),
		Parent = arrow,
	})
	Make.display({
		Name = "Caption",
		Text = "",
		TextSize = 18,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 60),
		Parent = arrow,
	})

	steps = {
		{
			title = "1. Grab a scroll",
			body = "Run to the Training Grounds (follow the arrow), stand by a nest and hold E / tap the prompt.",
			target = nearestNest,
		},
		{
			title = "2. Run it home!",
			body = "The boss is chasing you. Get inside your base gates and the scroll is safe. It hatches into a fighter that earns cash.",
			target = function()
				return myBasePart("Spawn")
			end,
		},
		{
			title = "3. Lock your base",
			body = "Step on the glowing lock pad so nobody can steal your fighters while you're out.",
			target = function()
				return myBasePart("LockPad")
			end,
		},
	}
end

function TutorialController:_show(i: number)
	stepIndex = i
	local step = steps[i]
	if not step then
		self:Finish()
		return
	end
	card.Visible = true
	stepLabel.Text = `TUTORIAL {i}/{#steps}`
	cardTitle.Text = step.title
	cardBody.Text = step.body
	local caption = arrow:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		caption.Text = step.title:gsub("^%d+%. ", "")
	end
end

function TutorialController:Finish()
	if not active then
		return
	end
	active = false
	card.Visible = false
	arrow.Enabled = false
	arrowAny.Adornee = nil
	task.spawn(function()
		Knit.GetService("DataService"):CompleteTutorial()
	end)
end

function TutorialController:KnitStart()
	local DataController = Knit.GetController("DataController")
	local CarryService = Knit.GetService("CarryService")
	local FighterService = Knit.GetService("FighterService")

	-- start once data is in and the tutorial hasn't been done
	local started = false
	DataController:Observe(function(data)
		if started then
			return
		end
		started = true
		if (data :: any).tutorialDone then
			return
		end
		active = true
		task.delay(2, function()
			if active then
				self:_show(1)
			end
		end)
	end)

	CarryService.Changed:Connect(function(info: any)
		if active and stepIndex == 1 and info and info.kind == "scroll" then
			self:_show(2)
		end
	end)
	FighterService.Notice:Connect(function(text: string)
		if active and stepIndex == 2 and text:find("secured") then
			self:_show(3)
		end
	end)

	-- arrow follows the current target; step 3 completes when the base locks
	RunService.Heartbeat:Connect(function()
		if not active or stepIndex == 0 then
			return
		end
		local step = steps[stepIndex]
		local target = step.target()
		if target ~= arrowAdornee then
			arrowAdornee = target
			arrowAny.Adornee = target
			arrow.Enabled = target ~= nil
		end
		-- bob the arrow
		arrowLabel.Position = UDim2.fromOffset(0, math.sin(os.clock() * 5) * 6)
		if stepIndex == 3 then
			local idx = Knit.GetService("BaseService").BaseIndex:Get()
			local bases = Workspace:FindFirstChild("Bases")
			local folder = if bases
					and typeof(idx) == "number"
					and idx > 0
				then bases:FindFirstChild("Base" .. idx)
				else nil
			local lockedUntil = if folder then folder:GetAttribute("LockedUntil") else nil
			-- the join auto-lock counts too, but only after the player has actually reached step 3
			if typeof(lockedUntil) == "number" and lockedUntil > Workspace:GetServerTimeNow() + 35 then
				self:Finish()
			end
		end
	end)
end

return TutorialController
