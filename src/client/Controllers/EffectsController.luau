--!strict
--[[
	EffectsController: cheap visual feedback for server events (boss gimmicks, combat,
	rift), screen flash when caught/stunned. Purely cosmetic; safe to replace with real VFX.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)

local EffectsController = Knit.CreateController({ Name = "EffectsController" })

local flashFrame: Frame

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
	Debris:AddItem(p, 0.6)
end

function EffectsController:Flash(color: Color3, strength: number, seconds: number)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - strength
	TweenService:Create(flashFrame, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
end

function EffectsController:KnitInit()
	local gui = Make.screen("Flash", 0)
	flashFrame = Make.frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.red,
		BackgroundTransparency = 1,
		Parent = gui,
	})
end

function EffectsController:KnitStart()
	local BossService = Knit.GetService("BossService")
	local CombatService = Knit.GetService("CombatService")
	local EventService = Knit.GetService("EventService")
	local SpeedService = Knit.GetService("SpeedService")

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
		self:Flash(Theme.red, 0.45, 0.8)
	end)
	SpeedService.Stunned:Connect(function(seconds: number)
		self:Flash(Theme.gold, 0.3, math.max(0.5, seconds))
	end)
end

return EffectsController
