--!strict
-- Character helpers shared by services: parts lookup, spawn, launch, knockback, collision groups.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local CharacterUtil = {}

CharacterUtil.PLAYER_GROUP = "Players"
CharacterUtil.NPC_GROUP = "NPC"
CharacterUtil.PICKUP_GROUP = "Pickups"

local groupsReady = false
function CharacterUtil.setupCollisionGroups()
	if groupsReady then
		return
	end
	groupsReady = true
	for _, g in { CharacterUtil.PLAYER_GROUP, CharacterUtil.NPC_GROUP, CharacterUtil.PICKUP_GROUP } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(g)
		end)
	end
	pcall(function()
		-- NPCs walk through players (no body-blocking a boss), pickups never block anyone
		PhysicsService:CollisionGroupSetCollidable(CharacterUtil.NPC_GROUP, CharacterUtil.PLAYER_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(CharacterUtil.PICKUP_GROUP, CharacterUtil.PLAYER_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(CharacterUtil.PICKUP_GROUP, CharacterUtil.NPC_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(CharacterUtil.PICKUP_GROUP, CharacterUtil.PICKUP_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(CharacterUtil.PLAYER_GROUP, CharacterUtil.PLAYER_GROUP, false)
	end)
end

function CharacterUtil.applyCharacterGroup(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = CharacterUtil.PLAYER_GROUP
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = CharacterUtil.PLAYER_GROUP
		end
	end)
end

function CharacterUtil.root(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function CharacterUtil.humanoid(player: Player): Humanoid?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChildOfClass("Humanoid")
end

function CharacterUtil.isAlive(player: Player): boolean
	local h = CharacterUtil.humanoid(player)
	return h ~= nil and h.Health > 0
end

function CharacterUtil.position(player: Player): Vector3?
	local root = CharacterUtil.root(player)
	return if root then root.Position else nil
end

function CharacterUtil.playerFromPart(part: BasePart): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

-- Workspace.Map.Spawn part, else any SpawnLocation, else above the origin
function CharacterUtil.spawnCFrame(): CFrame
	local map = Workspace:FindFirstChild("Map")
	local spawnPart = if map then map:FindFirstChild("Spawn") else nil
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart.CFrame + Vector3.new(0, spawnPart.Size.Y / 2 + 3, 0)
	end
	local loc = Workspace:FindFirstChildOfClass("SpawnLocation")
	if loc then
		return loc.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 5, 0)
end

function CharacterUtil.isInvulnerable(player: Player): boolean
	local char = player.Character
	if not char then
		return true
	end
	local untilT = char:GetAttribute("InvulnerableUntil")
	return typeof(untilT) == "number" and untilT > os.clock()
end

function CharacterUtil.setInvulnerable(player: Player, seconds: number)
	local char = player.Character
	if char then
		char:SetAttribute("InvulnerableUntil", os.clock() + seconds)
	end
end

function CharacterUtil.isInvisible(player: Player): boolean
	local char = player.Character
	if not char then
		return false
	end
	local untilT = char:GetAttribute("InvisibleUntil")
	return typeof(untilT) == "number" and untilT > os.clock()
end

-- Launch the player into the air, then teleport them to spawn with a short invulnerability window.
function CharacterUtil.launchToSpawn(player: Player, targetCFrame: CFrame?)
	local root = CharacterUtil.root(player)
	if not root then
		return
	end
	local B = Config.Zones.Boss
	CharacterUtil.setInvulnerable(player, B.catchInvulnerabilitySeconds + B.launchDelaySeconds)
	local char = player.Character
	if char then
		char:SetAttribute("Launched", true)
	end
	root.AssemblyLinearVelocity = Vector3.new(0, B.launchUpVelocity, 0)
	task.delay(B.launchDelaySeconds, function()
		local c = player.Character
		if not c or c ~= char then
			return
		end
		local r = CharacterUtil.root(player)
		if r then
			r.AssemblyLinearVelocity = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end
		c:PivotTo(targetCFrame or CharacterUtil.spawnCFrame())
		c:SetAttribute("Launched", nil)
	end)
end

function CharacterUtil.knockback(player: Player, fromPosition: Vector3, force: number, upward: number?)
	local root = CharacterUtil.root(player)
	if not root then
		return
	end
	local dir = (root.Position - fromPosition)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, 1)
	root.AssemblyLinearVelocity = dir * force + Vector3.new(0, upward or 25, 0)
end

function CharacterUtil.pullToward(player: Player, target: Vector3, force: number)
	local root = CharacterUtil.root(player)
	if not root then
		return
	end
	local dir = (target - root.Position)
	if dir.Magnitude < 0.5 then
		return
	end
	root.AssemblyLinearVelocity = dir.Unit * force + Vector3.new(0, 10, 0)
end

function CharacterUtil.teleport(player: Player, cframe: CFrame)
	local char = player.Character
	if char then
		local root = CharacterUtil.root(player)
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
		char:PivotTo(cframe)
	end
end

-- Straight-line visibility between two points, ignoring the listed instances
function CharacterUtil.hasLineOfSight(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local result = Workspace:Raycast(from, to - from, params)
	return result == nil
end

return CharacterUtil
