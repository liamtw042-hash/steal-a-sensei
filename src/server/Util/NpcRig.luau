--!strict
--[[
	Builds NPC rigs. Order of preference:
	  1. ReplicatedStorage.Bosses.<name> (a Model with a Humanoid + HumanoidRootPart) cloned as-is
	  2. A default R15 rig from Players:CreateHumanoidModelFromDescriptionAsync, dressed by BossLooks
	  3. A hand-built block rig (never fails), dressed by BossLooks as far as it can be
	Also provides a tiny animator (idle / run loop + attack) for rigs with an Animator.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossLooks = require(script.Parent.Parent.Boss.BossLooks)

local NpcRig = {}

local ANIM_IDLE = "rbxassetid://507766388"
local ANIM_RUN = "rbxassetid://507767714"
local ANIM_ATTACK = "rbxassetid://522635514" -- classic sword slash (R15)

local function blockRig(color: Color3): Model
	local model = Instance.new("Model")

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.6, 3, 1.4)
	torso.Color = color
	torso.Material = Enum.Material.SmoothPlastic
	torso.CanCollide = true
	torso.CFrame = root.CFrame
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Color = color:Lerp(Color3.new(1, 1, 1), 0.3)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.CFrame = root.CFrame * CFrame.new(0, 2.3, 0)
	head.Parent = model

	for _, p in { torso, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = root
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

local function defaultRig(): Model?
	local ok, result = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		-- strip default clothing/accessories so the costume reads clean
		for _, d in result:GetDescendants() do
			if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Decal") then
				d:Destroy()
			end
		end
		return result
	end
	return nil
end

export type RigOptions = {
	name: string,
	displayName: string,
	color: Color3,
	walkSpeed: number,
	folderName: string?, -- ReplicatedStorage.<folderName> to look for a model in (default "Bosses")
	scale: number?, -- extra scale on top of the look's own scale
}

function NpcRig.build(opts: RigOptions): Model
	local model: Model? = nil
	local custom = false

	local folder = ReplicatedStorage:FindFirstChild(opts.folderName or "Bosses")
	local template = if folder then folder:FindFirstChild(opts.name) else nil
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") then
		model = template:Clone()
		custom = true
	end
	if not model then
		model = defaultRig()
	end
	if not model then
		model = blockRig(opts.color)
	end
	assert(model, "rig build failed")

	model.Name = opts.name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = opts.walkSpeed
	humanoid.JumpPower = 50
	humanoid.UseJumpPower = true
	humanoid.DisplayName = opts.displayName
	humanoid.NameDisplayDistance = 120
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
	end
	if not custom then
		BossLooks.dress(model, opts.name, opts.color)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "NPC"
		end
	end
	if opts.scale and opts.scale ~= 1 then
		pcall(function()
			model:ScaleTo(model:GetScale() * (opts.scale :: number))
		end)
	end
	return model
end

-- Server owns NPC physics so MoveTo works predictably
function NpcRig.claimOwnership(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored then
			pcall(function()
				d:SetNetworkOwner(nil)
			end)
		end
	end
end

export type NpcAnimator = {
	PlayAttack: () -> (),
	Destroy: () -> (),
}

-- Idle/run loop driven by the humanoid's MoveDirection, plus a one-shot attack.
function NpcRig.animate(model: Model): NpcAnimator
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	local look = BossLooks.get(model.Name)
	local noop: NpcAnimator = { PlayAttack = function() end, Destroy = function() end }
	if not humanoid or not animator then
		return noop
	end

	local function load(id: string): AnimationTrack?
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		return if ok then track else nil
	end

	local idle = load(ANIM_IDLE)
	local run = load(if look and look.runAnim then look.runAnim :: string else ANIM_RUN)
	local attack = load(ANIM_ATTACK)
	if attack then
		attack.Priority = Enum.AnimationPriority.Action
	end
	if idle then
		idle.Priority = Enum.AnimationPriority.Idle
		idle.Looped = true
	end
	if run then
		run.Priority = Enum.AnimationPriority.Movement
		run.Looped = true
	end

	local alive = true
	local moving = false
	task.spawn(function()
		if idle then
			idle:Play()
		end
		while alive and model.Parent do
			local isMoving = humanoid.MoveDirection.Magnitude > 0.05
			if isMoving ~= moving then
				moving = isMoving
				if run then
					if moving then
						run:Play(0.15)
						run:AdjustSpeed(math.clamp(humanoid.WalkSpeed / 16, 0.8, 2.2))
					else
						run:Stop(0.15)
					end
				end
			end
			task.wait(0.15)
		end
	end)

	return {
		PlayAttack = function()
			if attack then
				attack:Play(0.05)
			end
		end,
		Destroy = function()
			alive = false
			for _, t in { idle, run, attack } do
				if t then
					t:Stop()
				end
			end
		end,
	}
end

return NpcRig
