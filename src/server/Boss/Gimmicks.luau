--!strict
--[[
	Boss gimmicks. Each handler gets the brain (see BossBrain) and reads its numbers from
	Config.Zones -> boss.params. Add a new gimmick by adding a handler here and a name in
	Config/Zones.luau's Gimmick type.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)

export type Handler = {
	onChaseStart: ((brain: any) -> ())?,
	onTick: ((brain: any, now: number) -> ())?,
	onChaseEnd: ((brain: any) -> ())?,
}

local handlers: { [string]: Handler } = {}
local Gimmicks = {}

local function param(brain: any, key: string, default: number): number
	local v = brain.def.params[key]
	return if typeof(v) == "number" then v else default
end

local function targetRoot(brain: any): BasePart?
	local t = brain.target :: Player?
	return if t then CharacterUtil.root(t) else nil
end

local function patchPart(brain: any, size: number, color: Color3, material: Enum.Material, lifetime: number): Part
	local p = Instance.new("Part")
	p.Name = "BossPatch"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Size = Vector3.new(size, 0.6, size)
	p.Color = color
	p.Material = material
	p.Transparency = 0.25
	local pos = brain.root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { brain.model }
	local hit = Workspace:Raycast(pos, Vector3.new(0, -12, 0), params)
	local y = if hit then hit.Position.Y + 0.3 else pos.Y - 2.5
	p.CFrame = CFrame.new(pos.X, y, pos.Z)
	p.Parent = Workspace
	Debris:AddItem(p, lifetime)
	return p
end

--------------------------------------------------------------------------------

handlers.None = {}
handlers.OneHit = {} -- handled by def.catchRadius / def.ignoresShield

-- Ninja: loses you if line of sight is broken for long enough
handlers.Corners = {
	onChaseStart = function(brain)
		brain.gimmickState.lostSince = nil
	end,
	onTick = function(brain, now)
		local root = targetRoot(brain)
		local target = brain.target :: Player?
		if not root or not target then
			return
		end
		local ignore = { brain.model }
		if target.Character then
			table.insert(ignore, target.Character :: Instance)
		end
		local visible = CharacterUtil.hasLineOfSight(brain.root.Position + Vector3.new(0, 1, 0), root.Position, ignore)
		if visible then
			brain.gimmickState.lostSince = nil
		else
			local since = brain.gimmickState.lostSince
			if not since then
				brain.gimmickState.lostSince = now
			elseif now - since >= param(brain, "loseAfterSeconds", 2.5) then
				brain:LoseTarget(true)
			end
		end
	end,
}

-- Lightning Monk: blinks to a point just behind you every N seconds
handlers.Teleport = {
	onChaseStart = function(brain)
		brain.gimmickState.nextAt = os.clock() + param(brain, "intervalSeconds", 8)
	end,
	onTick = function(brain, now)
		local nextAt = brain.gimmickState.nextAt or now
		if now < nextAt then
			return
		end
		brain.gimmickState.nextAt = now + param(brain, "intervalSeconds", 8)
		local root = targetRoot(brain)
		if not root then
			return
		end
		local dist = param(brain, "teleportDistance", 12)
		local behind = root.Position - root.CFrame.LookVector * dist
		brain.effect("teleport", brain.root.Position)
		brain.model:PivotTo(CFrame.new(behind + Vector3.new(0, 3, 0), root.Position))
		brain.walker:Reset()
		brain.effect("teleport", behind)
	end,
}

-- Ice Warrior: leaves slow patches behind it
handlers.SlowPatch = {
	onChaseStart = function(brain)
		brain.gimmickState.nextAt = os.clock()
	end,
	onTick = function(brain, now)
		local nextAt = brain.gimmickState.nextAt or now
		if now < nextAt then
			return
		end
		brain.gimmickState.nextAt = now + param(brain, "intervalSeconds", 2.5)
		local p = patchPart(
			brain,
			param(brain, "patchSize", 9),
			Color3.fromRGB(150, 220, 255),
			Enum.Material.Ice,
			param(brain, "patchLifetime", 8)
		)
		p.CanTouch = true
		p.Touched:Connect(function(hit)
			local player = CharacterUtil.playerFromPart(hit)
			if player then
				brain.services.PowerService:AddModifier(
					player,
					"icePatch",
					param(brain, "slowMultiplier", 0.55),
					param(brain, "slowSeconds", 2)
				)
			end
		end)
	end,
}

-- Flame Ronin: fire trail that damages
handlers.FireTrail = {
	onChaseStart = function(brain)
		brain.gimmickState.nextAt = os.clock()
	end,
	onTick = function(brain, now)
		local nextAt = brain.gimmickState.nextAt or now
		if now < nextAt then
			return
		end
		brain.gimmickState.nextAt = now + param(brain, "intervalSeconds", 0.6)
		local p = patchPart(
			brain,
			param(brain, "patchSize", 6),
			Color3.fromRGB(255, 120, 30),
			Enum.Material.Neon,
			param(brain, "patchLifetime", 6)
		)
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Heat = 8
		fire.Parent = p
		p.CanTouch = true
		local damage = param(brain, "damage", 12)
		local interval = param(brain, "damageIntervalSeconds", 0.5)
		p.Touched:Connect(function(hit)
			local player = CharacterUtil.playerFromPart(hit)
			local char = if player then player.Character else nil
			if not player or not char then
				return
			end
			local last = char:GetAttribute("LastFireHit")
			local t = os.clock()
			if typeof(last) == "number" and t - last < interval then
				return
			end
			char:SetAttribute("LastFireHit", t)
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(damage)
			end
		end)
	end,
}

-- Sea Serpent: yanks you back toward it when close
handlers.Pull = {
	onChaseStart = function(brain)
		brain.gimmickState.nextAt = os.clock()
	end,
	onTick = function(brain, now)
		local nextAt = brain.gimmickState.nextAt or now
		if now < nextAt then
			return
		end
		local root = targetRoot(brain)
		local target = brain.target :: Player?
		if not root or not target then
			return
		end
		if (root.Position - brain.root.Position).Magnitude <= param(brain, "pullRadius", 14) then
			brain.gimmickState.nextAt = now + param(brain, "intervalSeconds", 1.2)
			CharacterUtil.pullToward(target, brain.root.Position, param(brain, "pullForce", 55))
			brain.effect("pull", root.Position)
		end
	end,
}

-- Stone Golem: throws boulders that stun on landing
handlers.Boulder = {
	onChaseStart = function(brain)
		brain.gimmickState.nextAt = os.clock() + 2
	end,
	onTick = function(brain, now)
		local nextAt = brain.gimmickState.nextAt or now
		if now < nextAt then
			return
		end
		brain.gimmickState.nextAt = now + param(brain, "intervalSeconds", 6)
		local root = targetRoot(brain)
		if not root then
			return
		end
		local flight = param(brain, "flightSeconds", 1.2)
		local blast = param(brain, "blastRadius", 9)
		local stun = param(brain, "stunSeconds", 1.5)
		local predicted = root.Position + root.AssemblyLinearVelocity * (flight * 0.6)

		local ball = Instance.new("Part")
		ball.Name = "Boulder"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(5, 5, 5)
		ball.Color = Color3.fromRGB(110, 105, 95)
		ball.Material = Enum.Material.Slate
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CFrame = CFrame.new(brain.root.Position + Vector3.new(0, 6, 0))
		ball.Parent = Workspace
		local tween = TweenService:Create(ball, TweenInfo.new(flight, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(predicted + Vector3.new(0, 2.5, 0)),
		})
		tween:Play()
		tween.Completed:Connect(function()
			brain.effect("boulder", predicted)
			for _, p in Players:GetPlayers() do
				local pos = CharacterUtil.position(p)
				if pos and (pos - predicted).Magnitude <= blast and not CharacterUtil.isInvulnerable(p) then
					brain.services.PowerService:Stun(p, stun)
				end
			end
			ball:Destroy()
		end)
	end,
}

-- Star Sage: spawns short-lived clones
handlers.Clones = {
	onChaseStart = function(brain)
		brain.gimmickState.nextAt = os.clock() + 3
	end,
	onTick = function(brain, now)
		if brain.isClone then
			return
		end
		local nextAt = brain.gimmickState.nextAt or now
		if now < nextAt then
			return
		end
		brain.gimmickState.nextAt = now + param(brain, "intervalSeconds", 10)
		for _ = 1, param(brain, "count", 2) do
			brain.spawnClone(brain, param(brain, "cloneLifetime", 12), param(brain, "cloneSpeedMultiplier", 0.85))
		end
	end,
}

function Gimmicks.get(name: string): Handler
	return handlers[name] or handlers.None
end

return Gimmicks
