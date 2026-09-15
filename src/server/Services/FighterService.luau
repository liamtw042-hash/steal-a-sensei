--!strict
--[[
	FighterService
	==============
	Scroll hatching, fighter placement, income, XP/levelling, evolution, fusing,
	the Index, loose (dropped) fighters and rebirth wipes. Renders slot models in bases.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Region = require(ReplicatedStorage.Shared.Util.Region)
local Weighted = require(ReplicatedStorage.Shared.Util.Weighted)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Models = require(script.Parent.Parent.Util.Models)

type Fighter = Types.Fighter
type PlayerData = Types.PlayerData

type LoosePickup = { fighter: Fighter, originalOwner: number, model: Model, consumed: boolean }

local FighterService = Knit.CreateService({
	Name = "FighterService",
	Client = {
		Hatched = Knit.CreateSignal(), -- (fighter)
		Evolved = Knit.CreateSignal(), -- (fighter)
		Notice = Knit.CreateSignal(), -- (text)
	},
	FighterStolen = Signal.new(), -- (owner, thief, fighter)
})

local DataService: any
local BaseService: any
local CarryService: any
local TheftService: any

local slotModels: { [Player]: { [number]: Model } } = {}
local loose: { [Model]: LoosePickup } = {}
local looseFolder: Folder

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function FighterService:KnitInit()
	DataService = Knit.GetService("DataService")
	BaseService = Knit.GetService("BaseService")
	CarryService = Knit.GetService("CarryService")
	TheftService = Knit.GetService("TheftService")

	looseFolder = Instance.new("Folder")
	looseFolder.Name = "LooseFighters"
	looseFolder.Parent = Workspace
end

function FighterService:KnitStart()
	BaseService.Assigned:Connect(function(player: Player, base: any)
		slotModels[player] = {}
		self:_renderAll(player, base)
	end)
	BaseService.Unassigned:Connect(function(player: Player)
		self:_clearModels(player)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Base.Earning.tickSeconds)
			for _, player in Players:GetPlayers() do
				local data = DataService:Get(player)
				if data then
					self:_economyTick(player, data)
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function newId(data: PlayerData): string
	local id = tostring(data.nextFighterId)
	data.nextFighterId += 1
	return id
end

local function rollMutation(): string?
	for _, m in Config.Fighters.Mutations do
		if Weighted.chance(m.chance) then
			return m.name
		end
	end
	return nil
end

local function randomDefOfRarity(rarity: string)
	local list = Config.Fighters.ofRarity(rarity)
	if #list == 0 then
		list = Config.Fighters.Roster
	end
	return list[Weighted.random():NextInteger(1, #list)]
end

function FighterService:Cps(fighter: Fighter): number
	return Models.fighterCps(fighter)
end

function FighterService:GetPlacedFighters(data: PlayerData): { Fighter }
	local out = {}
	for _, f in data.fighters do
		if f.slot then
			table.insert(out, f)
		end
	end
	return out
end

function FighterService:IsSlotFree(data: PlayerData, slot: number): boolean
	if data.hatching[tostring(slot)] then
		return false
	end
	for _, f in data.fighters do
		if f.slot == slot then
			return false
		end
	end
	return true
end

function FighterService:FirstFreeSlot(player: Player, data: PlayerData): number?
	local base = BaseService:GetBaseOf(player)
	if not base then
		return nil
	end
	for _, idx in BaseService:GetUsableSlotIndices(base, data) do
		if self:IsSlotFree(data, idx) then
			return idx
		end
	end
	return nil
end

function FighterService:GetIncomePerSecond(player: Player): number
	local data = DataService:Get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, f in self:GetPlacedFighters(data) do
		total += self:Cps(f)
	end
	total *= Config.Rebirth.multiplier(data.rebirths)
	if data.gamepasses.VIP then
		total *= Config.Base.Earning.vipCashMultiplier
	end
	return total
end

function FighterService:HasFighterOfRarity(player: Player, minRarity: string): boolean
	local data = DataService:Get(player)
	if not data then
		return false
	end
	for _, f in data.fighters do
		if Rarity.atLeast(f.rarity, minRarity) then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

function FighterService:_clearModels(player: Player)
	local models = slotModels[player]
	if models then
		for _, m in models do
			m:Destroy()
		end
	end
	slotModels[player] = nil
end

function FighterService:_renderAll(player: Player, base: any)
	local data = DataService:Get(player)
	if not data then
		return
	end
	for key, _ in data.hatching do
		self:_renderSlot(player, base, tonumber(key) or 0)
	end
	for _, f in data.fighters do
		if f.slot then
			self:_renderSlot(player, base, f.slot)
		end
	end
end

function FighterService:_renderSlot(player: Player, base: any, slot: number)
	local models = slotModels[player]
	if not models then
		models = {}
		slotModels[player] = models
	end
	local old = models[slot]
	if old then
		old:Destroy()
		models[slot] = nil
	end
	local data = DataService:Get(player)
	local part = BaseService:GetSlotPart(base, slot)
	if not data or not part then
		return
	end

	local hatching = data.hatching[tostring(slot)]
	if hatching then
		local model = Models.scroll(hatching.rarity)
		model:PivotTo(CFrame.new(Region.top(part, 2)))
		model:SetAttribute("OwnerUserId", player.UserId)
		model.Name = "HatchingScroll"
		local pp = model.PrimaryPart :: BasePart
		Models.billboard(pp, `{hatching.rarity} Scroll\nhatching...`, Rarity.color(hatching.rarity), 2.4)
		model.Parent = base.folder
		Models.floatScroll(model)
		models[slot] = model
		return
	end

	for _, f in data.fighters do
		if f.slot == slot then
			local model = Models.fighter(f, true)
			local pp = model.PrimaryPart
			if pp then
				local height = model:GetExtentsSize().Y
				model:PivotTo(CFrame.new(Region.top(part, height / 2)))
				Models.billboard(
					pp,
					Models.fighterLabelText(f),
					Rarity.color(f.rarity),
					height / 2 + 1.5,
					UDim2.fromOffset(190, 60)
				)
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "StealPrompt"
				prompt.ActionText = "Steal"
				prompt.ObjectText = f.name
				prompt.HoldDuration = Config.Base.Theft.promptHoldSeconds
				prompt.MaxActivationDistance = Config.Base.Theft.promptDistance
				prompt.RequiresLineOfSight = false
				prompt.Parent = pp
				local fighterId = f.id
				prompt.Triggered:Connect(function(thief)
					TheftService:TrySteal(thief, player, fighterId)
				end)
			end
			model:SetAttribute("OwnerUserId", player.UserId)
			model.Parent = base.folder
			models[slot] = model
			return
		end
	end
end

function FighterService:_updateLabel(player: Player, f: Fighter)
	local models = slotModels[player]
	local model = if models and f.slot then models[f.slot] else nil
	local pp = if model then model.PrimaryPart else nil
	local bb = if pp then pp:FindFirstChild("Label") else nil
	local lbl = if bb then bb:FindFirstChild("Text") else nil
	if lbl and lbl:IsA("TextLabel") then
		lbl.Text = Models.fighterLabelText(f)
	end
end

function FighterService:_rerender(player: Player, slot: number?)
	local base = BaseService:GetBaseOf(player)
	if base and slot then
		self:_renderSlot(player, base, slot)
	end
end

--------------------------------------------------------------------------------
-- Economy tick: hatching, XP, evolution, income
--------------------------------------------------------------------------------

function FighterService:_hatch(player: Player, data: PlayerData, slot: number)
	local key = tostring(slot)
	local h = data.hatching[key]
	if not h then
		return
	end
	data.hatching[key] = nil
	local def = randomDefOfRarity(h.rarity)
	local fighter: Fighter = {
		id = newId(data),
		name = def.name,
		rarity = def.rarity,
		level = 1,
		xp = 0,
		mutation = rollMutation(),
		slot = slot,
	}
	data.fighters[fighter.id] = fighter
	data.index[fighter.name] = true
	self:_rerender(player, slot)
	self.Client.Hatched:Fire(player, fighter)
	DataService:Replicate(player)
end

function FighterService:_evolve(player: Player, data: PlayerData, f: Fighter)
	local nextRarity = Config.Fighters.nextRarity(f.rarity)
	if not nextRarity then
		return
	end
	local def = Config.Fighters.get(f.name)
	local candidate = if def and def.evolvesInto then Config.Fighters.get(def.evolvesInto :: string) else nil
	local target = if candidate and candidate.rarity == nextRarity then candidate else randomDefOfRarity(nextRarity)
	f.name = target.name
	f.rarity = target.rarity
	f.level = 1
	f.xp = 0
	data.index[f.name] = true
	self:_rerender(player, f.slot)
	self.Client.Evolved:Fire(player, f)
	DataService:Replicate(player)
end

function FighterService:_economyTick(player: Player, data: PlayerData)
	local dt = Config.Base.Earning.tickSeconds
	local L = Config.Fighters.Levelling
	local nowT = os.time()

	-- hatching
	for key, h in data.hatching do
		if nowT >= h.hatchAt then
			self:_hatch(player, data, tonumber(key) or 0)
		end
	end

	-- xp + income
	local placed = self:GetPlacedFighters(data)
	if #placed == 0 then
		return
	end
	local growth = if data.gamepasses.Growth2x then 2 else 1
	local xpGain = (L.xpPerMinutePlaced / 60) * dt * growth
	local income = 0
	for _, f in placed do
		income += self:Cps(f)
		if f.level < L.maxLevel then
			f.xp += xpGain
			local leveled = false
			while f.level < L.maxLevel and f.xp >= L.xpToNext(f.level) do
				f.xp -= L.xpToNext(f.level)
				f.level += 1
				leveled = true
			end
			if leveled then
				if f.level >= L.maxLevel and Config.Fighters.nextRarity(f.rarity) then
					self:_evolve(player, data, f)
				else
					self:_updateLabel(player, f)
				end
			end
		end
	end
	income *= Config.Rebirth.multiplier(data.rebirths)
	if data.gamepasses.VIP then
		income *= Config.Base.Earning.vipCashMultiplier
	end
	DataService:AddCash(player, income * dt)
end

--------------------------------------------------------------------------------
-- Receiving scrolls / fighters
--------------------------------------------------------------------------------

function FighterService:ReceiveScroll(player: Player, rarity: string, zoneId: number)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local slot = self:FirstFreeSlot(player, data)
	if slot then
		data.hatching[tostring(slot)] = {
			rarity = rarity,
			zoneId = zoneId,
			hatchAt = os.time() + Rarity.hatchSeconds(rarity),
		}
		self:_rerender(player, slot)
		self.Client.Notice:Fire(
			player,
			`{rarity} scroll secured! Hatching in {Format.time(Rarity.hatchSeconds(rarity))}`
		)
	else
		table.insert(data.scrollBag, { rarity = rarity, zoneId = zoneId })
		self.Client.Notice:Fire(player, `{rarity} scroll secured (no free slot, stored in your bag)`)
	end
	DataService:Replicate(player)
end

function FighterService:ReceiveFighter(player: Player, fighter: Fighter, originalOwner: number)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local copy: Fighter = {
		id = newId(data),
		name = fighter.name,
		rarity = fighter.rarity,
		level = fighter.level,
		xp = fighter.xp,
		mutation = fighter.mutation,
		slot = nil,
	}
	if originalOwner ~= player.UserId then
		copy.level = 1
		copy.xp = 0
		data.stats.fightersStolen += 1
	end
	data.fighters[copy.id] = copy
	data.index[copy.name] = true
	local slot = self:FirstFreeSlot(player, data)
	if slot then
		copy.slot = slot
		self:_rerender(player, slot)
	end
	self.Client.Notice:Fire(
		player,
		if originalOwner == player.UserId then `{copy.name} returned home!` else `Stole {copy.name}!`
	)
	DataService:Replicate(player)
end

-- Take a fighter out of a base for a thief. Returns a copy, or nil if it isn't there.
function FighterService:RemoveForTheft(owner: Player, fighterId: string): Fighter?
	local data = DataService:Get(owner)
	if not data then
		return nil
	end
	local f = data.fighters[fighterId]
	if not f or not f.slot then
		return nil
	end
	local slot = f.slot
	data.fighters[fighterId] = nil
	self:_rerender(owner, slot)
	DataService:Replicate(owner)
	return {
		id = f.id,
		name = f.name,
		rarity = f.rarity,
		level = f.level,
		xp = f.xp,
		mutation = f.mutation,
		slot = nil,
	}
end

-- Hungry Sensei: eat one random placed fighter. Returns it or nil.
function FighterService:EatRandomPlacedFighter(player: Player): Fighter?
	local data = DataService:Get(player)
	if not data then
		return nil
	end
	local placed = self:GetPlacedFighters(data)
	if #placed == 0 then
		return nil
	end
	local f = placed[Weighted.random():NextInteger(1, #placed)]
	data.fighters[f.id] = nil
	self:_rerender(player, f.slot)
	DataService:Replicate(player)
	return f
end

--------------------------------------------------------------------------------
-- Loose fighters on the ground
--------------------------------------------------------------------------------

function FighterService:SpawnLoosePickup(fighter: Fighter, originalOwner: number, position: Vector3)
	local model = Models.fighter(fighter, true)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { looseFolder }
	local hit = Workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), params)
	local height = model:GetExtentsSize().Y
	local y = if hit then hit.Position.Y + height / 2 else position.Y
	model:PivotTo(CFrame.new(position.X, y, position.Z))
	local pp = model.PrimaryPart
	local record: LoosePickup = { fighter = fighter, originalOwner = originalOwner, model = model, consumed = false }
	if pp then
		Models.billboard(
			pp,
			Models.fighterLabelText(fighter, "dropped!"),
			Rarity.color(fighter.rarity),
			height / 2 + 1.5,
			UDim2.fromOffset(190, 60)
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Pick up"
		prompt.ObjectText = fighter.name
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = pp
		prompt.Triggered:Connect(function(player)
			if record.consumed or not CarryService:CanCarry(player) then
				return
			end
			record.consumed = true
			loose[model] = nil
			model:Destroy()
			if not CarryService:PickupFighter(player, record.fighter, record.originalOwner) then
				self:SpawnLoosePickup(record.fighter, record.originalOwner, position)
			end
		end)
	end
	model.Name = "LooseFighter"
	model:SetAttribute("OriginalOwner", originalOwner)
	model.Parent = looseFolder
	loose[model] = record
	-- unclaimed for a while: return to owner if online, else gone
	task.delay(180, function()
		if record.consumed then
			return
		end
		record.consumed = true
		loose[model] = nil
		model:Destroy()
		local owner = Players:GetPlayerByUserId(originalOwner)
		if owner then
			self:ReceiveFighter(owner, record.fighter, originalOwner)
		end
	end)
end

function FighterService:PurgeLoose(userId: number)
	for model, record in loose do
		if record.originalOwner == userId then
			record.consumed = true
			loose[model] = nil
			model:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- Rebirth
--------------------------------------------------------------------------------

function FighterService:WipeForRebirth(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	data.fighters = {}
	data.hatching = {}
	data.scrollBag = {}
	self:_clearModels(player)
	slotModels[player] = {}
end

--------------------------------------------------------------------------------
-- Client API
--------------------------------------------------------------------------------

function FighterService.Client:PlaceFighter(player: Player, fighterId: string, slot: number): (boolean, string)
	local data = DataService:Get(player)
	local base = BaseService:GetBaseOf(player)
	if not data or not base then
		return false, "No base"
	end
	local f = data.fighters[tostring(fighterId)]
	if not f then
		return false, "Unknown fighter"
	end
	if typeof(slot) ~= "number" or not table.find(BaseService:GetUsableSlotIndices(base, data), slot) then
		return false, "Slot locked"
	end
	if not self.Server:IsSlotFree(data, slot) then
		return false, "Slot occupied"
	end
	local oldSlot = f.slot
	f.slot = slot
	if oldSlot then
		self.Server:_rerender(player, oldSlot)
	end
	self.Server:_rerender(player, slot)
	DataService:Replicate(player)
	return true, "Placed"
end

function FighterService.Client:UnplaceFighter(player: Player, fighterId: string): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local f = data.fighters[tostring(fighterId)]
	if not f or not f.slot then
		return false, "Not placed"
	end
	local slot = f.slot
	f.slot = nil
	self.Server:_rerender(player, slot)
	DataService:Replicate(player)
	return true, "Stored"
end

function FighterService.Client:PlaceScrollFromBag(player: Player, bagIndex: number, slot: number?): (boolean, string)
	local data = DataService:Get(player)
	local base = BaseService:GetBaseOf(player)
	if not data or not base then
		return false, "No base"
	end
	local entry = data.scrollBag[bagIndex]
	if not entry then
		return false, "No scroll there"
	end
	local target = slot or self.Server:FirstFreeSlot(player, data)
	if typeof(target) ~= "number" or not table.find(BaseService:GetUsableSlotIndices(base, data), target) then
		return false, "No free slot"
	end
	if not self.Server:IsSlotFree(data, target) then
		return false, "Slot occupied"
	end
	table.remove(data.scrollBag, bagIndex)
	data.hatching[tostring(target)] = {
		rarity = entry.rarity,
		zoneId = entry.zoneId,
		hatchAt = os.time() + Rarity.hatchSeconds(entry.rarity),
	}
	self.Server:_rerender(player, target)
	DataService:Replicate(player)
	return true, "Hatching"
end

-- Three identical (same name) fighters -> one of the next rarity
function FighterService.Client:Fuse(player: Player, fighterName: string): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local matches = {}
	for _, f in data.fighters do
		if f.name == fighterName then
			table.insert(matches, f)
		end
	end
	local need = Config.Fighters.Fuse.required
	if #matches < need then
		return false, `Need {need} x {fighterName}`
	end
	-- prefer consuming unplaced ones first
	table.sort(matches, function(a, b)
		local ap = if a.slot then 1 else 0
		local bp = if b.slot then 1 else 0
		if ap ~= bp then
			return ap < bp
		end
		return a.level < b.level
	end)
	local rarity = matches[1].rarity
	local nextRarity = Config.Fighters.nextRarity(rarity)
	if not nextRarity then
		return false, "Already max rarity"
	end
	local freedSlot: number? = nil
	for i = 1, need do
		local f = matches[i]
		data.fighters[f.id] = nil
		if f.slot then
			freedSlot = freedSlot or f.slot
			self.Server:_rerender(player, f.slot)
		end
	end
	local def = randomDefOfRarity(nextRarity)
	local fused: Fighter = {
		id = newId(data),
		name = def.name,
		rarity = def.rarity,
		level = 1,
		xp = 0,
		mutation = nil,
		slot = freedSlot,
	}
	data.fighters[fused.id] = fused
	data.index[fused.name] = true
	if freedSlot then
		self.Server:_rerender(player, freedSlot)
	end
	DataService:Replicate(player)
	return true, `Fused into {fused.name}!`
end

function FighterService.Client:ClaimIndexReward(player: Player, zoneId: number): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local reward = Config.Fighters.IndexRewards[zoneId]
	if not reward then
		return false, "No reward for that zone"
	end
	if data.indexClaimed[tostring(zoneId)] then
		return false, "Already claimed"
	end
	local set = Config.Fighters.ofZone(zoneId)
	if #set == 0 then
		return false, "Nothing to collect there"
	end
	for _, def in set do
		if not data.index[def.name] then
			return false, `Missing {def.displayName}`
		end
	end
	data.indexClaimed[tostring(zoneId)] = true
	data.skins[reward.skin] = true
	DataService:AddCash(player, reward.cash)
	Knit.GetService("SpeedService"):AddSpeed(player, reward.speed)
	DataService:Replicate(player)
	return true, `+{Format.short(reward.speed)} speed, {Format.cash(reward.cash)}, {reward.skin} skin`
end

return FighterService
