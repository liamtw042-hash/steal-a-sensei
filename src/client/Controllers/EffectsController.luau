--!strict
--[[
	EffectsController: game feel. Particle bursts for server events, screen flash on hatch
	and stun, camera shake on catch, speed lines when you're running fast.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)

local EffectsController = Knit.CreateController({ Name = "EffectsController" })

local flashFrame: Frame
local speedLines: Frame
local lineFrames: { Frame } = {}
local shakeUntil = 0
local shakeStrength = 0

local colors: { [string]: Color3 } = {
	teleport = Color3.fromRGB(255, 240, 120),
	pull = Color3.fromRGB(60, 140, 255),
	boulder = Color3.fromRGB(150, 140, 120),
	clone = Color3.fromRGB(230, 200, 255),
	shield = Color3.fromRGB(120, 220, 255),
	catch = Color3.fromRGB(255, 60, 60),
	slap = Color3.fromRGB(255, 200, 80),
	trap = Color3.fromRGB(255, 80, 80),
	smoke = Color3.fromRGB(120, 120, 120),
	grapple = Color3.fromRGB(120, 255, 160),
	swap = Color3.fromRGB(200, 120, 255),
	shockwave = Color3.fromRGB(180, 80, 255),
	hit = Color3.fromRGB(255, 255, 255),
	eat = Color3.fromRGB(255, 140, 60),
}

local sizes: { [string]: number } = {
	boulder = 18,
	shockwave = 24,
	smoke = 14,
	catch = 10,
	hit = 3,
}

function EffectsController:Burst(kind: string, position: Vector3)
	local color = colors[kind] or Theme.accent
	local size = sizes[kind] or 6
	local p = Instance.new("Part")
	p.Name = "FX"
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.2
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(position)
	p.Parent = Workspace
	TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(size, size, size),
		Transparency = 1,
	}):Play()
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(8, 16)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = 1
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = p
	e:Emit(math.floor(size * 2))
	Debris:AddItem(p, 1.2)
end

function EffectsController:Flash(color: Color3, strength: number, seconds: number)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - strength
	TweenService:Create(flashFrame, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
end

function EffectsController:Shake(strength: number, seconds: number)
	shakeStrength = strength
	shakeUntil = os.clock() + seconds
end

function EffectsController:KnitInit()
	local gui = Make.screen("Flash", 0)
	flashFrame = Make.frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.red,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- speed lines: thin white bars radiating from the screen edges, hidden by default
	speedLines = Make.frame({
		Name = "SpeedLines",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local rng = Random.new()
	for i = 1, 26 do
		local fromLeft = i % 2 == 0
		local y = rng:NextNumber(0.05, 0.95)
		local len = rng:NextNumber(0.08, 0.22)
		local line = Make.frame({
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.55,
			Size = UDim2.new(len, 0, 0, rng:NextInteger(2, 4)),
			Position = if fromLeft then UDim2.fromScale(0, y) else UDim2.fromScale(1 - len, y),
			Parent = speedLines,
		})
		Make.corner(line, 2)
		Make.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, if fromLeft then 0 else 1),
				NumberSequenceKeypoint.new(1, if fromLeft then 1 else 0),
			}),
			Parent = line,
		})
		table.insert(lineFrames, line)
	end
end

function EffectsController:KnitStart()
	local BossService = Knit.GetService("BossService")
	local CombatService = Knit.GetService("CombatService")
	local EventService = Knit.GetService("EventService")
	local PowerService = Knit.GetService("PowerService")
	local FighterService = Knit.GetService("FighterService")

	BossService.Effect:Connect(function(kind: string, position: Vector3)
		self:Burst(kind, position)
	end)
	CombatService.Effect:Connect(function(kind: string, position: Vector3, extra: Vector3?)
		self:Burst(kind, position)
		if extra then
			self:Burst(kind, extra)
		end
	end)
	EventService.Effect:Connect(function(kind: string, position: Vector3)
		self:Burst(kind, position)
	end)
	BossService.Caught:Connect(function()
		self:Flash(Theme.red, 0.5, 0.8)
		self:Shake(1.4, 0.55)
	end)
	PowerService.Stunned:Connect(function(seconds: number)
		self:Flash(Theme.gold, 0.3, math.max(0.5, seconds))
		self:Shake(0.5, 0.3)
	end)
	FighterService.Hatched:Connect(function()
		self:Flash(Color3.new(1, 1, 1), 0.7, 0.6)
	end)
	FighterService.Evolved:Connect(function()
		self:Flash(Theme.accent, 0.6, 0.8)
	end)

	-- camera shake + speed lines every frame
	local localPlayer = Players.LocalPlayer
	local rng = Random.new()
	local linesAlpha = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local now = os.clock()
		if now < shakeUntil then
			local t = (shakeUntil - now)
			local s = shakeStrength * math.min(1, t * 2)
			cam.CFrame = cam.CFrame
				* CFrame.new(rng:NextNumber(-s, s), rng:NextNumber(-s, s), 0)
				* CFrame.Angles(rng:NextNumber(-s, s) * 0.02, rng:NextNumber(-s, s) * 0.02, 0)
		end

		local char = localPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local speed = if root and root:IsA("BasePart")
			then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			else 0
		local target = if speed > 28 then math.clamp((speed - 28) / 30, 0, 1) else 0
		linesAlpha += (target - linesAlpha) * math.min(1, dt * 6)
		local visible = linesAlpha > 0.03
		if speedLines.Visible ~= visible then
			speedLines.Visible = visible
		end
		if visible then
			for i, line in lineFrames do
				line.BackgroundTransparency = 1 - linesAlpha * 0.5
				-- slide the lines outward so they streak
				local pos = line.Position
				local dir = if i % 2 == 0 then 1 else -1
				local x = pos.X.Scale + dir * dt * 1.6
				if x > 1.2 then
					x = -0.3
				elseif x < -0.3 then
					x = 1.2
				end
				line.Position = UDim2.fromScale(x, pos.Y.Scale)
			end
		end
	end)
end

return EffectsController
