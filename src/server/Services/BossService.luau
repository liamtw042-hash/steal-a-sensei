--!strict
--[[
	BossService
	===========
	Owns one BossBrain per zone (plus temporary clones). Wires scroll pickups to chases,
	base entry to camping/returning, and resolves catches (shield, drop, launch).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)
local BossBrain = require(script.Parent.Parent.Boss.BossBrain)
local BossLooks = require(script.Parent.Parent.Boss.BossLooks)

local BossService = Knit.CreateService({
	Name = "BossService",
	Client = {
		ChaseState = Knit.CreateSignal(), -- to the carrier: (bossDisplayName or nil)
		Effect = Knit.CreateSignal(), -- to everyone: (kind, position)
		Caught = Knit.CreateSignal(), -- to the victim: (bossDisplayName)
	},
})

local DataService: any
local ZoneService: any
local CarryService: any
local BaseService: any
local SpeedService: any

local brains: { [number]: BossBrain.BossBrain } = {}
local clones: { BossBrain.BossBrain } = {}
local chasedBy: { [Player]: { [BossBrain.BossBrain]: boolean } } = {}

function BossService:KnitInit()
	DataService = Knit.GetService("DataService")
	ZoneService = Knit.GetService("ZoneService")
	CarryService = Knit.GetService("CarryService")
	BaseService = Knit.GetService("BaseService")
	SpeedService = Knit.GetService("SpeedService")
end

function BossService:_callbacks(): BossBrain.Callbacks
	return {
		onCatch = function(brain, player)
			self:_onCatch(brain, player)
		end,
		spawnClone = function(brain, lifetime, speedMult)
			self:_spawnClone(brain, lifetime, speedMult)
		end,
		effect = function(kind, position)
			self.Client.Effect:FireAll(kind, position)
		end,
		findCarrier = function(zoneId, exclude)
			return self:_findCarrier(zoneId, exclude)
		end,
		onStateChanged = function(brain, state, target)
			self:_onStateChanged(brain, state, target)
		end,
		services = { CarryService = CarryService, SpeedService = SpeedService, BaseService = BaseService },
	}
end

function BossService:KnitStart()
	for zoneId, zone in ZoneService:GetZones() do
		local spawnPart = zone.bossSpawn
		if not spawnPart then
			warn(`[BossService] zone {zone.def.folderName} has no BossSpawn part; no boss`)
			continue
		end
		local home = spawnPart.CFrame + Vector3.new(0, spawnPart.Size.Y / 2 + 3.5, 0)
		local brain = BossBrain.new(zoneId, zone.def.boss, home, zone.patrol, self:_callbacks())
		if brain then
			brains[zoneId] = brain
		end
	end

	ZoneService.ScrollLifted:Connect(function(zoneId: number, player: Player)
		local brain = brains[zoneId]
		if not brain then
			return
		end
		if brain.state == "Chase" and brain.target and brain.target ~= player then
			return -- already busy with someone
		end
		brain:Chase(player)
	end)

	CarryService.PickedUp:Connect(function(player: Player, item: any)
		if item.kind == "scroll" then
			local char = player.Character
			if char then
				char:SetAttribute("ShieldUsed", nil)
			end
		end
	end)

	CarryService.Secured:Connect(function(player: Player, item: any, base: any)
		if item.kind ~= "scroll" then
			return
		end
		local locked = BaseService:IsLocked(base)
		local entrance = base.entrance
		local entrancePos = if entrance then entrance.Position + Vector3.new(0, 3, 0) else nil
		for brain, _ in self:_chasers(player) do
			brain:OnCarrierSecured(locked, entrancePos)
		end
	end)

	CarryService.Dropped:Connect(function(player: Player, item: any, _pos: Vector3, reason: string)
		if item.kind ~= "scroll" or reason == "caught" then
			return
		end
		for brain, _ in self:_chasers(player) do
			brain:LoseTarget(false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for brain, _ in self:_chasers(player) do
			brain:LoseTarget(false)
		end
		chasedBy[player] = nil
	end)
end

function BossService:_chasers(player: Player): { [BossBrain.BossBrain]: boolean }
	local set = {}
	local current = chasedBy[player]
	if current then
		for brain, _ in current do
			set[brain] = true
		end
	end
	return set
end

function BossService:_onStateChanged(brain: BossBrain.BossBrain, state: string, target: Player?)
	if brain.model.Parent then
		BossLooks.setChasing(brain.model, state == "Chase")
	end
	-- maintain reverse index and tell carriers who's after them
	for player, set in chasedBy do
		if set[brain] and (state ~= "Chase" or target ~= player) then
			set[brain] = nil
			if next(set) == nil then
				chasedBy[player] = nil
				if player.Parent then
					self.Client.ChaseState:Fire(player, nil)
				end
			end
		end
	end
	if state == "Chase" and target then
		local set = chasedBy[target]
		if not set then
			set = {}
			chasedBy[target] = set
		end
		set[brain] = true
		self.Client.ChaseState:Fire(target, brain.def.displayName)
	end
end

function BossService:_findCarrier(zoneId: number, exclude: Player?): Player?
	for _, p in Players:GetPlayers() do
		if p == exclude then
			continue
		end
		local item = CarryService:Get(p)
		if item and item.kind == "scroll" and item.zoneId == zoneId and not CharacterUtil.isInvisible(p) then
			return p
		end
	end
	return nil
end

function BossService:_spawnClone(parent: BossBrain.BossBrain, lifetime: number, speedMult: number)
	local zone = ZoneService:GetZone(parent.zoneId)
	if not zone or not parent.target then
		return
	end
	local offset = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	local clone = BossBrain.new(
		parent.zoneId,
		parent.def,
		parent.model:GetPivot() + offset,
		zone.patrol,
		self:_callbacks(),
		{ isClone = true, lifetime = lifetime, speedMult = speedMult, target = parent.target }
	)
	if clone then
		table.insert(clones, clone)
		self.Client.Effect:FireAll("clone", clone.root.Position)
	end
end

function BossService:_onCatch(brain: BossBrain.BossBrain, player: Player)
	if CharacterUtil.isInvulnerable(player) then
		return
	end
	local data = DataService:Get(player)
	local char = player.Character
	local B = Config.Zones.Boss

	-- Shield: block one hit per run
	if
		data
		and data.gear.Shield
		and not brain.def.ignoresShield
		and char
		and char:GetAttribute("ShieldUsed") ~= true
	then
		char:SetAttribute("ShieldUsed", true)
		CharacterUtil.setInvulnerable(player, 1.5)
		brain:Stun(B.shieldStunSeconds)
		self.Client.Effect:FireAll("shield", brain.root.Position)
		BaseService:Notify(player, "Your Shield absorbed the hit!", "info")
		return
	end

	brain.animator.PlayAttack()
	local pos = CharacterUtil.position(player)
	CarryService:Drop(player, pos, "caught")
	if data then
		data.stats.timesCaught += 1
	end
	CharacterUtil.launchToSpawn(player)
	self.Client.Caught:Fire(player, brain.def.displayName)
	self.Client.Effect:FireAll("catch", pos or brain.root.Position)
	brain:AfterCatch()
end

function BossService:GetBrain(zoneId: number): BossBrain.BossBrain?
	return brains[zoneId]
end

return BossService
