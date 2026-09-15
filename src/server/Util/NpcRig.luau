--!strict
--[[
	Builds NPC rigs. Order of preference:
	  1. ReplicatedStorage.Bosses.<name> (a Model with a Humanoid + HumanoidRootPart) cloned
	  2. A default R15 rig from Players:CreateHumanoidModelFromDescription, tinted
	  3. A hand-built block rig (never fails)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcRig = {}

local function tint(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Color = color
			d.Material = Enum.Material.SmoothPlastic
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d:Destroy()
		elseif d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
end

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

local function defaultRig(color: Color3): Model?
	local ok, result = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local m = Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
		return m
	end)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		tint(result, color)
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
	scale: number?,
}

function NpcRig.build(opts: RigOptions): Model
	local model: Model? = nil

	local folder = ReplicatedStorage:FindFirstChild(opts.folderName or "Bosses")
	local template = if folder then folder:FindFirstChild(opts.name) else nil
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") then
		model = template:Clone()
	end
	if not model then
		model = defaultRig(opts.color)
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

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "NPC"
		end
	end
	if opts.scale and opts.scale ~= 1 then
		model:ScaleTo(opts.scale)
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

return NpcRig
