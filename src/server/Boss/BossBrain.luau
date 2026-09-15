--!strict
--[[
	BossBrain: one zone boss (or clone). States:
	  Patrol  -> wanders between patrol points in its zone
	  Chase   -> pathfinds after a scroll carrier anywhere on the map
	  Camp    -> waits at an unlocked base entrance, then goes home
	  Return  -> pathfinds home, then patrols
	  Stunned -> frozen (shield absorbed a hit)
	BossService owns the brains and supplies the callbacks (onCatch, spawnClone, effect).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.Zones)
local Weighted = require(ReplicatedStorage.Shared.Util.Weighted)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)
local NpcRig = require(script.Parent.Parent.Util.NpcRig)
local PathWalker = require(script.Parent.Parent.Util.PathWalker)
local Gimmicks = require(script.Parent.Gimmicks)

local BossBrain = {}
BossBrain.__index = BossBrain

export type State = "Patrol" | "Chase" | "Camp" | "Return" | "Stunned"

export type Callbacks = {
	onCatch: (brain: any, player: Player) -> (),
	spawnClone: (brain: any, lifetime: number, speedMult: number) -> (),
	effect: (kind: string, position: Vector3) -> (),
	findCarrier: (zoneId: number, exclude: Player?) -> Player?,
	onStateChanged: (brain: any, state: State, target: Player?) -> (),
	services: { [string]: any },
}

export type Options = { isClone: boolean?, lifetime: number?, speedMult: number?, target: Player? }

type Fields = {
	zoneId: number,
	def: ZonesConfig.BossDef,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	walker: PathWalker.PathWalker,
	state: State,
	target: Player?,
	ignoreTarget: Player?,
	homeCFrame: CFrame,
	patrolPoints: { BasePart },
	patrolGoal: Vector3?,
	patrolDeadline: number,
	patrolWaitUntil: number,
	campPos: Vector3?,
	campUntil: number,
	stunnedUntil: number,
	returnStartedAt: number,
	alive: boolean,
	isClone: boolean,
	expiresAt: number?,
	gimmick: Gimmicks.Handler,
	gimmickState: { [string]: any },
	callbacks: Callbacks,
	services: { [string]: any },
	spawnClone: (brain: any, lifetime: number, speedMult: number) -> (),
	effect: (kind: string, position: Vector3) -> (),
	baseSpeed: number,
}

export type BossBrain = typeof(setmetatable({} :: Fields, BossBrain))

function BossBrain.new(
	zoneId: number,
	def: ZonesConfig.BossDef,
	homeCFrame: CFrame,
	patrolPoints: { BasePart },
	callbacks: Callbacks,
	opts: Options?
): BossBrain?
	local o: Options = opts or {}
	local speed = def.walkSpeed * (o.speedMult or 1)
	local model = NpcRig.build({
		name = def.name,
		displayName = if o.isClone then def.displayName .. " (clone)" else def.displayName,
		color = def.color,
		walkSpeed = speed,
	})
	model:PivotTo(homeCFrame)
	model.Parent = Workspace
	NpcRig.claimOwnership(model)
	local walker = PathWalker.new(model)
	if not walker then
		model:Destroy()
		return nil
	end

	local fields: Fields = {
		zoneId = zoneId,
		def = def,
		model = model,
		humanoid = walker.humanoid,
		root = walker.root,
		walker = walker,
		state = "Patrol",
		target = nil,
		ignoreTarget = nil,
		homeCFrame = homeCFrame,
		patrolPoints = patrolPoints,
		patrolGoal = nil,
		patrolDeadline = 0,
		patrolWaitUntil = 0,
		campPos = nil,
		campUntil = 0,
		stunnedUntil = 0,
		returnStartedAt = 0,
		alive = true,
		isClone = o.isClone == true,
		expiresAt = if o.lifetime then os.clock() + o.lifetime else nil,
		gimmick = Gimmicks.get(def.gimmick),
		gimmickState = {},
		callbacks = callbacks,
		services = callbacks.services,
		spawnClone = callbacks.spawnClone,
		effect = callbacks.effect,
		baseSpeed = speed,
	}
	local self: BossBrain = setmetatable(fields, BossBrain)

	model:SetAttribute("BossZoneId", zoneId)
	model:SetAttribute("IsClone", self.isClone)
	local target = o.target
	if target then
		self:Chase(target)
	end
	task.spawn(function()
		self:_loop()
	end)
	return self
end

--------------------------------------------------------------------------------
-- State changes
--------------------------------------------------------------------------------

function BossBrain._setState(self: BossBrain, state: State)
	if self.state == state then
		return
	end
	self.state = state
	self.walker:Reset()
	self.model:SetAttribute("State", state)
	self.callbacks.onStateChanged(self, state, self.target)
end

function BossBrain.Chase(self: BossBrain, player: Player)
	if not self.alive or self.state == "Stunned" then
		return
	end
	if self.ignoreTarget == player then
		return
	end
	self.target = player
	self.gimmickState = {}
	self:_setState("Chase")
	local onChaseStart = self.gimmick.onChaseStart
	if onChaseStart then
		onChaseStart(self)
	end
end

-- Drop the current target. If `giveUp`, don't retarget that same player for a while (ninja lost you).
function BossBrain.LoseTarget(self: BossBrain, giveUp: boolean?)
	local old = self.target
	if giveUp then
		self.ignoreTarget = old
		task.delay(8, function()
			if self.ignoreTarget == old then
				self.ignoreTarget = nil
			end
		end)
	end
	self.target = nil
	local onChaseEnd = self.gimmick.onChaseEnd
	if onChaseEnd then
		onChaseEnd(self)
	end
	if self.isClone then
		self:Destroy()
		return
	end
	local other = self.callbacks.findCarrier(self.zoneId, if giveUp then old else nil)
	if other then
		self:Chase(other)
	else
		self:GoHome()
	end
end

function BossBrain.GoHome(self: BossBrain)
	self.target = nil
	self.returnStartedAt = os.clock()
	self:_setState("Return")
end

-- Carrier reached their base. Locked -> bounce home. Unlocked -> camp the entrance.
function BossBrain.OnCarrierSecured(self: BossBrain, baseLocked: boolean, entrancePos: Vector3?)
	self.target = nil
	local onChaseEnd = self.gimmick.onChaseEnd
	if onChaseEnd then
		onChaseEnd(self)
	end
	if self.isClone then
		self:Destroy()
		return
	end
	if baseLocked or not entrancePos then
		self:GoHome()
	else
		self.campPos = entrancePos
		self.campUntil = os.clock() + self.def.campSeconds
		self:_setState("Camp")
	end
end

function BossBrain.AfterCatch(self: BossBrain)
	self.target = nil
	if self.isClone then
		self:Destroy()
		return
	end
	self:GoHome()
end

function BossBrain.Stun(self: BossBrain, seconds: number)
	self.stunnedUntil = os.clock() + seconds
	self.humanoid:MoveTo(self.root.Position)
	self:_setState("Stunned")
end

function BossBrain.Destroy(self: BossBrain)
	if not self.alive then
		return
	end
	self.alive = false
	self.callbacks.onStateChanged(self, "Return", nil)
	self.model:Destroy()
end

--------------------------------------------------------------------------------
-- Loop
--------------------------------------------------------------------------------

function BossBrain._targetValid(self: BossBrain): boolean
	local t = self.target
	if not t or not t.Parent then
		return false
	end
	if not CharacterUtil.isAlive(t) then
		return false
	end
	if CharacterUtil.isInvisible(t) then
		return false
	end
	if not self.services.CarryService:IsCarryingScroll(t) then
		return false
	end
	local pos = CharacterUtil.position(t)
	if not pos or (pos - self.root.Position).Magnitude > Config.Zones.Boss.chaseGiveUpDistance then
		return false
	end
	return true
end

function BossBrain._tryCatch(self: BossBrain, player: Player): boolean
	local pos = CharacterUtil.position(player)
	if not pos then
		return false
	end
	if (pos - self.root.Position).Magnitude > self.def.catchRadius then
		return false
	end
	if CharacterUtil.isInvulnerable(player) then
		return false
	end
	self.callbacks.onCatch(self, player)
	return true
end

function BossBrain._stepPatrol(self: BossBrain, now: number)
	if now < self.patrolWaitUntil then
		return
	end
	local goal = self.patrolGoal
	if not goal or now > self.patrolDeadline then
		local pts = self.patrolPoints
		if #pts > 0 then
			local p = pts[Weighted.random():NextInteger(1, #pts)]
			goal = p.Position
		else
			goal = self.homeCFrame.Position
		end
		self.patrolGoal = goal
		self.patrolDeadline = now + Config.Zones.Boss.patrolTimeoutSeconds
	end
	local dist = self.walker:Step(goal :: Vector3)
	if dist < 4 then
		self.patrolGoal = nil
		local idle = Config.Zones.Boss.patrolIdleSeconds
		self.patrolWaitUntil = now + Weighted.random():NextNumber(idle[1], idle[2])
		self.walker:Stop()
	end
end

function BossBrain._stepChase(self: BossBrain, now: number)
	if not self:_targetValid() then
		self:LoseTarget(false)
		return
	end
	local target = self.target :: Player
	if self:_tryCatch(target) then
		return
	end
	local onTick = self.gimmick.onTick
	if onTick then
		onTick(self, now)
		if self.state ~= "Chase" then
			return
		end
	end
	local pos = CharacterUtil.position(target)
	if pos then
		self.walker:Step(pos)
	end
end

function BossBrain._stepCamp(self: BossBrain, now: number)
	if now >= self.campUntil then
		self:GoHome()
		return
	end
	-- catch anyone carrying a scroll who wanders into reach
	for _, p in Players:GetPlayers() do
		if self.services.CarryService:IsCarryingScroll(p) and self:_tryCatch(p) then
			return
		end
	end
	local pos = self.campPos
	if pos then
		local dist = self.walker:Step(pos)
		if dist < 3 then
			self.walker:Stop()
		end
	end
end

function BossBrain._stepReturn(self: BossBrain, now: number)
	local home = self.homeCFrame.Position
	local dist = self.walker:Step(home)
	if dist < 4 then
		self.walker:Stop()
		self:_setState("Patrol")
	elseif now - self.returnStartedAt > Config.Zones.Boss.returnTimeoutSeconds then
		self.model:PivotTo(self.homeCFrame)
		self.walker:Reset()
		self:_setState("Patrol")
	end
end

function BossBrain._loop(self: BossBrain)
	while self.alive and self.model.Parent do
		local now = os.clock()
		local expiresAt = self.expiresAt
		if expiresAt and now > expiresAt then
			self:Destroy()
			break
		end
		if self.humanoid.Health <= 0 then
			-- never let a boss die: heal and continue
			self.humanoid.Health = self.humanoid.MaxHealth
		end
		local ok, err = pcall(function()
			if self.state == "Stunned" then
				if now >= self.stunnedUntil then
					if self.target and self:_targetValid() then
						self:_setState("Chase")
					else
						self:GoHome()
					end
				end
			elseif self.state == "Chase" then
				self:_stepChase(now)
			elseif self.state == "Camp" then
				self:_stepCamp(now)
			elseif self.state == "Return" then
				self:_stepReturn(now)
			else
				self:_stepPatrol(now)
			end
		end)
		if not ok then
			warn(`[BossBrain {self.def.name}] {err}`)
		end
		task.wait(0.1)
	end
end

return BossBrain
