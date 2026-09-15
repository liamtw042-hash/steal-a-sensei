--!strict
--[[
	EventService
	============
	Rift (server boss, tokens + token shop), Void Surge (zone 10 triple scrolls),
	Hungry Sensei (wandering boss that eats fighters from unlocked bases).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)
local NpcRig = require(script.Parent.Parent.Util.NpcRig)
local PathWalker = require(script.Parent.Parent.Util.PathWalker)

local E = Config.Events

local EventService = Knit.CreateService({
	Name = "EventService",
	Client = {
		Banner = Knit.CreateProperty(nil), -- { name, text, endsAt }
		Rift = Knit.CreateProperty(nil), -- { hp, maxHp, endsAt }
		Announce = Knit.CreateSignal(), -- (text)
		Effect = Knit.CreateSignal(), -- (kind, position)
	},
})

local DataService: any
local ZoneService: any
local BaseService: any
local FighterService: any
local SpeedService: any

type Rift = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	hp: number,
	maxHp: number,
	endsAt: number,
	damage: { [Player]: number },
	alive: boolean,
}
local rift: Rift? = nil
local attackCooldown: { [Player]: number } = {}

function EventService:KnitInit()
	DataService = Knit.GetService("DataService")
	ZoneService = Knit.GetService("ZoneService")
	BaseService = Knit.GetService("BaseService")
	FighterService = Knit.GetService("FighterService")
	SpeedService = Knit.GetService("SpeedService")
end

local function mapPoint(name: string): CFrame
	local map = Workspace:FindFirstChild("Map")
	local p = if map then map:FindFirstChild(name) else nil
	if p and p:IsA("BasePart") then
		return p.CFrame + Vector3.new(0, p.Size.Y / 2 + 4, 0)
	end
	return CharacterUtil.spawnCFrame() + Vector3.new(20, 0, 0)
end

function EventService:KnitStart()
	local function schedule(first: number, interval: number, fn: () -> ())
		task.spawn(function()
			task.wait(first)
			while true do
				local ok, err = pcall(function()
					fn()
				end)
				if not ok then
					warn("[EventService]", err)
				end
				task.wait(interval)
			end
		end)
	end
	schedule(E.Rift.firstAfterSeconds, E.Rift.intervalSeconds, function()
		self:StartRift()
	end)
	schedule(E.VoidSurge.firstAfterSeconds, E.VoidSurge.intervalSeconds, function()
		self:StartVoidSurge()
	end)
	schedule(E.HungrySensei.firstAfterSeconds, E.HungrySensei.intervalSeconds, function()
		self:StartHungrySensei()
	end)
end

function EventService:_banner(name: string?, text: string?, endsAt: number?)
	if name then
		self.Client.Banner:Set({ name = name, text = text, endsAt = endsAt })
	else
		self.Client.Banner:Set(nil)
	end
end

--------------------------------------------------------------------------------
-- Rift
--------------------------------------------------------------------------------

function EventService:StartRift()
	if rift then
		return
	end
	local R = E.Rift
	local players = Players:GetPlayers()
	local maxHp = R.baseHealth + R.healthPerPlayer * #players
	local model = NpcRig.build({
		name = "RiftBoss",
		displayName = "Rift Sensei",
		color = Color3.fromRGB(150, 60, 220),
		walkSpeed = R.walkSpeed,
		scale = 2,
	})
	model:PivotTo(mapPoint("RiftSpawn"))
	model.Parent = Workspace
	NpcRig.claimOwnership(model)
	local walker = PathWalker.new(model, 1)
	if not walker then
		model:Destroy()
		return
	end
	local endsAt = os.time() + R.durationSeconds
	local r: Rift = {
		model = model,
		root = walker.root,
		humanoid = walker.humanoid,
		hp = maxHp,
		maxHp = maxHp,
		endsAt = endsAt,
		damage = {},
		alive = true,
	}
	rift = r
	self.Client.Rift:Set({ hp = r.hp, maxHp = r.maxHp, endsAt = endsAt })
	self:_banner("Rift", "A Rift has opened! Attack the Rift Sensei together (click it).", endsAt)
	self.Client.Announce:FireAll("A RIFT HAS OPENED! Fight the Rift Sensei near spawn!")

	task.spawn(function()
		local nextShock = os.clock() + R.shockwaveIntervalSeconds
		while r.alive and os.time() < endsAt and r.hp > 0 do
			-- shuffle toward the nearest player
			local nearest: Vector3? = nil
			local best = math.huge
			for _, p in Players:GetPlayers() do
				local pos = CharacterUtil.position(p)
				if pos then
					local d = (pos - r.root.Position).Magnitude
					if d < best then
						best = d
						nearest = pos
					end
				end
			end
			if nearest and best > 8 then
				walker:Step(nearest)
			else
				walker:Stop()
			end
			if os.clock() >= nextShock then
				nextShock = os.clock() + R.shockwaveIntervalSeconds
				self.Client.Effect:FireAll("shockwave", r.root.Position)
				for _, p in Players:GetPlayers() do
					local pos = CharacterUtil.position(p)
					if pos and (pos - r.root.Position).Magnitude <= R.shockwaveRadius then
						CharacterUtil.knockback(p, r.root.Position, R.shockwaveForce, 35)
					end
				end
			end
			task.wait(0.2)
		end
		self:_endRift(r.hp <= 0)
	end)
end

function EventService:_endRift(killed: boolean)
	local r = rift
	if not r then
		return
	end
	r.alive = false
	rift = nil
	r.model:Destroy()
	self.Client.Rift:Set(nil)
	self:_banner(nil)
	if killed then
		local R = E.Rift
		local total = 0
		for _, d in r.damage do
			total += d
		end
		for player, d in r.damage do
			if player.Parent and total > 0 then
				local tokens = R.tokensBase + math.floor(R.tokensPool * (d / total))
				DataService:AddTokens(player, tokens)
				BaseService:Notify(player, `Rift closed! +{tokens} tokens`, "info")
			end
		end
		self.Client.Announce:FireAll("The Rift Sensei was defeated!")
	else
		self.Client.Announce:FireAll("The Rift closed...")
	end
end

function EventService.Client:AttackRift(player: Player): boolean
	local r = rift
	if not r or not r.alive then
		return false
	end
	local now = os.clock()
	if (attackCooldown[player] or 0) > now then
		return false
	end
	local pos = CharacterUtil.position(player)
	if not pos or (pos - r.root.Position).Magnitude > E.Rift.attackRange + 6 then
		return false
	end
	attackCooldown[player] = now + E.Rift.attackCooldown
	local data = DataService:Get(player)
	local dmg = E.Rift.attackDamage + (if data then data.rebirths else 0)
	if data and data.gear.Slap then
		dmg += E.Rift.slapDamage
	end
	r.hp = math.max(0, r.hp - dmg)
	r.damage[player] = (r.damage[player] or 0) + dmg
	self.Server.Client.Rift:Set({ hp = r.hp, maxHp = r.maxHp, endsAt = r.endsAt })
	self.Server.Client.Effect:FireAll("hit", r.root.Position)
	return true
end

--------------------------------------------------------------------------------
-- Token shop
--------------------------------------------------------------------------------

function EventService.Client:BuyTokenItem(player: Player, key: string): (boolean, string)
	local data = DataService:Get(player)
	local item = E.tokenItem(key)
	if not data or not item then
		return false, "Unknown item"
	end
	if data.tokens < item.cost then
		return false, "Not enough tokens"
	end
	local V = E.TokenShopValues
	if key == "SpeedSmall" then
		SpeedService:AddSpeed(player, V.SpeedSmall)
	elseif key == "SpeedLarge" then
		SpeedService:AddSpeed(player, V.SpeedLarge)
	elseif key == "CashPack" then
		local perSec = FighterService:GetIncomePerSecond(player)
		DataService:AddCash(player, math.max(1000, perSec * 60 * V.CashPackMinutes))
	elseif key == "RareScroll" then
		FighterService:ReceiveScroll(player, "Rare", 4)
	elseif key == "EpicScroll" then
		FighterService:ReceiveScroll(player, "Epic", 6)
	else
		return false, "Not implemented"
	end
	DataService:SpendTokens(player, item.cost)
	DataService:Replicate(player)
	return true, `Bought {item.name}`
end

--------------------------------------------------------------------------------
-- Void Surge
--------------------------------------------------------------------------------

function EventService:StartVoidSurge()
	local V = E.VoidSurge
	local zone = ZoneService:GetZone(V.zoneId)
	if not zone then
		return
	end
	local endsAt = os.time() + V.durationSeconds
	ZoneService:StartSurge(V.zoneId, V.scrollMultiplier, V.durationSeconds)
	self:_banner("Void Surge", `{zone.def.name} has {V.scrollMultiplier}x scrolls!`, endsAt)
	self.Client.Announce:FireAll(
		`VOID SURGE! {zone.def.name} is overflowing with scrolls for {Format.time(V.durationSeconds)}!`
	)
	task.delay(V.durationSeconds, function()
		self:_banner(nil)
	end)
end

--------------------------------------------------------------------------------
-- Hungry Sensei
--------------------------------------------------------------------------------

function EventService:StartHungrySensei()
	local H = E.HungrySensei
	self.Client.Announce:FireAll(
		`The Hungry Sensei is coming in {H.warningSeconds}s. LOCK YOUR BASE or lose a fighter!`
	)
	self:_banner(
		"Hungry Sensei",
		"Lock your base! He eats fighters from unlocked bases.",
		os.time() + H.warningSeconds + H.maxDurationSeconds
	)
	task.wait(H.warningSeconds)

	local model = NpcRig.build({
		name = "HungrySensei",
		displayName = "Hungry Sensei",
		color = Color3.fromRGB(220, 120, 60),
		walkSpeed = H.walkSpeed,
		scale = 1.6,
	})
	model:PivotTo(mapPoint("HungrySenseiSpawn"))
	model.Parent = Workspace
	NpcRig.claimOwnership(model)
	local walker = PathWalker.new(model, 0.8)
	if not walker then
		model:Destroy()
		return
	end

	local deadline = os.clock() + H.maxDurationSeconds
	for _, base in BaseService:GetBases() do
		if os.clock() > deadline then
			break
		end
		local owner = base.owner
		local entrance = base.entrance
		if not owner or not entrance then
			continue
		end
		local goal = entrance.Position
		local arrived = false
		while os.clock() < deadline and model.Parent do
			if walker:Step(goal) < 5 then
				arrived = true
				break
			end
			task.wait(0.15)
		end
		walker:Stop()
		if not arrived then
			continue
		end
		owner = base.owner
		if owner and not BaseService:IsLocked(base) then
			task.wait(H.eatDelaySeconds)
			if base.owner == owner and not BaseService:IsLocked(base) then
				local eaten = FighterService:EatRandomPlacedFighter(owner)
				if eaten then
					self.Client.Effect:FireAll("eat", goal)
					BaseService:Notify(owner, `The Hungry Sensei ate your {eaten.name}!`, "alarm")
				end
			end
		else
			task.wait(1)
		end
	end
	model:Destroy()
	self:_banner(nil)
	self.Client.Announce:FireAll("The Hungry Sensei has left.")
end

return EventService
