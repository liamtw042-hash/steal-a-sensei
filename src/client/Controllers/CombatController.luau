--!strict
--[[
	CombatController: hotbar (bottom centre) + hotkeys 1-5 for Slap, Trap, Smoke Bomb,
	Grapple, Body Swap. Targeted items pick the nearest other player in front of you.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Config = require(ReplicatedStorage.Shared.Config)
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)

local CombatController = Knit.CreateController({ Name = "CombatController" })

type Item = { key: string, label: string, hotkey: Enum.KeyCode, targeted: boolean }

local items: { Item } = {
	{ key = "Slap", label = "Slap", hotkey = Enum.KeyCode.One, targeted = false },
	{ key = "Trap", label = "Trap", hotkey = Enum.KeyCode.Two, targeted = false },
	{ key = "SmokeBomb", label = "Smoke", hotkey = Enum.KeyCode.Three, targeted = false },
	{ key = "Grapple", label = "Grapple", hotkey = Enum.KeyCode.Four, targeted = true },
	{ key = "BodySwap", label = "Swap", hotkey = Enum.KeyCode.Five, targeted = true },
}

local buttons: { [string]: TextButton } = {}
local localPlayer = Players.LocalPlayer

local function nearestTarget(range: number): Player?
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local best: Player? = nil
	local bestDist = range
	for _, p in Players:GetPlayers() do
		if p == localPlayer then
			continue
		end
		local c = p.Character
		local r = if c then c:FindFirstChild("HumanoidRootPart") else nil
		if r and r:IsA("BasePart") then
			local d = (r.Position - root.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = p
			end
		end
	end
	return best
end

function CombatController:Use(key: string)
	local CombatService = Knit.GetService("CombatService")
	local C = Config.Monetization.Combat
	local ok, msg
	if key == "Slap" then
		ok, msg = CombatService:UseSlap()
	elseif key == "Trap" then
		ok, msg = CombatService:PlaceTrap()
	elseif key == "SmokeBomb" then
		ok, msg = CombatService:UseSmokeBomb()
	elseif key == "Grapple" then
		local t = nearestTarget(C.grappleRange)
		if not t then
			Toast.show("No one in grapple range", "warn")
			return
		end
		ok, msg = CombatService:UseGrapple(t.UserId)
	elseif key == "BodySwap" then
		local t = nearestTarget(C.bodySwapRange)
		if not t then
			Toast.show("No one in swap range", "warn")
			return
		end
		ok, msg = CombatService:UseBodySwap(t.UserId)
	else
		return
	end
	if typeof(msg) == "string" then
		Toast.show(msg, if ok then "info" else "warn", 2)
	end
end

function CombatController:_refresh()
	local data = Knit.GetController("DataController"):Get()
	if not data then
		return
	end
	local gear = data.gear :: any
	for _, it in items do
		local btn = buttons[it.key]
		local have = gear[it.key]
		local owned = if typeof(have) == "number" then have > 0 else have == true
		local count = if typeof(have) == "number" then ` x{have}` else ""
		btn.Text = `{it.label}{count}`
		Make.tint(btn, if owned then Theme.panel2 else Theme.panel)
		btn.TextColor3 = if owned then Theme.text else Theme.muted
	end
end

function CombatController:KnitStart()
	local gui = Make.screen("Hotbar", 3)
	local bar = Make.frame({
		Size = UDim2.fromOffset(520, 64),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Make.list(bar, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	for i, it in items do
		local btn = Make.button({
			Text = it.label,
			Size = UDim2.fromOffset(100, 60),
			TextSize = 16,
			BackgroundColor3 = Theme.panel,
			Parent = bar,
		}, function()
			self:Use(it.key)
		end)
		Make.text({
			Text = tostring(i),
			TextSize = 12,
			TextColor3 = Theme.muted,
			Size = UDim2.fromOffset(16, 14),
			Position = UDim2.fromOffset(6, 3),
			Parent = btn,
		})
		buttons[it.key] = btn
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for _, it in items do
			if input.KeyCode == it.hotkey then
				self:Use(it.key)
			end
		end
	end)

	Knit.GetController("DataController"):Observe(function()
		self:_refresh()
	end)
end

return CombatController
