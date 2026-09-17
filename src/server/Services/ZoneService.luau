--!strict
--[[
	ZoneService
	===========
	Reads Workspace.Zones.<folderName>, spawns scrolls on nests, handles pickups
	(with the speed requirement enforced server-side), dropped scrolls and Void Surge.
]]
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.Zones)
local Region = require(ReplicatedStorage.Shared.Util.Region)
local Weighted = require(ReplicatedStorage.Shared.Util.Weighted)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)
local Models = require(script.Parent.Parent.Util.Models)

export type ScrollRecord = {
	uid: string,
	zoneId: number,
	rarity: string,
	model: Model,
	nest: BasePart?, -- nil for dropped / surge scrolls
	dropped: boolean,
	surge: boolean,
	consumed: boolean,
}

export type ZoneRecord = {
	def: ZonesConfig.ZoneDef,
	folder: Instance,
	entrance: BasePart?,
	bounds: BasePart?,
	bossSpawn: BasePart?,
	nests: { BasePart },
	patrol: { BasePart },
	scrolls: { [string]: ScrollRecord },
	nestBusy: { [BasePart]: boolean },
	surgeUntil: number,
}

local ZoneService = Knit.CreateService({
	Name = "ZoneService",
	Client = {
		SurgeChanged = Knit.CreateSignal(), -- (zoneId, active, endsAt)
	},
	ScrollLifted = Signal.new(), -- (zoneId, player)  boss should chase
	ScrollPickedUp = Signal.new(), -- (player, record)
})

local PowerService: any
local CarryService: any

local zones: { [number]: ZoneRecord } = {}
local scrollsFolder: Folder

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

local function partsIn(parent: Instance?): { BasePart }
	local out = {}
	if parent then
		for _, c in parent:GetChildren() do
			if c:IsA("BasePart") then
				table.insert(out, c)
			end
		end
		table.sort(out, function(a, b)
			return a.Name < b.Name
		end)
	end
	return out
end

local function findPart(parent: Instance, name: string): BasePart?
	local c = parent:FindFirstChild(name)
	return if c and c:IsA("BasePart") then c else nil
end

function ZoneService:KnitInit()
	PowerService = Knit.GetService("PowerService")
	CarryService = Knit.GetService("CarryService")

	scrollsFolder = Instance.new("Folder")
	scrollsFolder.Name = "Scrolls"
	scrollsFolder.Parent = Workspace

	local zonesFolder = Workspace:FindFirstChild("Zones")
	if not zonesFolder then
		warn("[ZoneService] Workspace.Zones is missing; no zones will work")
		return
	end
	for _, def in Config.Zones.List do
		local folder = zonesFolder:FindFirstChild(def.folderName)
		if not folder then
			warn(`[ZoneService] zone folder Workspace.Zones.{def.folderName} is missing`)
			continue
		end
		local nests = partsIn(folder:FindFirstChild("Nests"))
		if #nests == 0 then
			warn(`[ZoneService] zone {def.folderName} has no Nests folder with parts`)
		end
		local patrol = partsIn(folder:FindFirstChild("PatrolPoints"))
		if #patrol == 0 then
			patrol = nests
		end
		local entrance = findPart(folder, "Entrance")
		if entrance then
			entrance:SetAttribute("ZoneId", def.id)
			entrance:SetAttribute("PowerRequirement", def.powerRequirement)
			entrance:SetAttribute("ZoneName", def.name)
		end
		folder:SetAttribute("ZoneId", def.id)
		zones[def.id] = {
			def = def,
			folder = folder,
			entrance = entrance,
			bounds = findPart(folder, "Bounds"),
			bossSpawn = findPart(folder, "BossSpawn"),
			nests = nests,
			patrol = patrol,
			scrolls = {},
			nestBusy = {},
			surgeUntil = 0,
		}
	end
end

function ZoneService:KnitStart()
	for _, zone in zones do
		for _, nest in zone.nests do
			self:_spawnNestScroll(zone, nest)
		end
	end
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------

function ZoneService:GetZone(zoneId: number): ZoneRecord?
	return zones[zoneId]
end

function ZoneService:GetZones(): { [number]: ZoneRecord }
	return zones
end

function ZoneService:GetZoneAt(position: Vector3): ZoneRecord?
	for _, zone in zones do
		if zone.bounds and Region.isPointInPart(zone.bounds, position) then
			return zone
		end
	end
	return nil
end

function ZoneService:MeetsRequirement(player: Player, zoneId: number): boolean
	local zone = zones[zoneId]
	if not zone then
		return false
	end
	return PowerService:GetEffectivePower(player) >= zone.def.powerRequirement
end

--------------------------------------------------------------------------------
-- Scroll models
--------------------------------------------------------------------------------

function ZoneService:_registerScroll(zone: ZoneRecord, record: ScrollRecord)
	zone.scrolls[record.uid] = record
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab Scroll"
	prompt.ObjectText = `{record.rarity}`
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = record.model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		self:_tryPickup(player, zone, record)
	end)
	record.model.Parent = scrollsFolder
	Models.floatScroll(record.model)
end

function ZoneService:_spawnNestScroll(zone: ZoneRecord, nest: BasePart)
	if zone.nestBusy[nest] then
		return
	end
	zone.nestBusy[nest] = true
	local rarity = Weighted.pick(zone.def.scrollPool, function(e)
		return e.weight
	end).rarity
	local model = Models.scroll(rarity)
	model:PivotTo(CFrame.new(Region.top(nest, 2)))
	local record: ScrollRecord = {
		uid = HttpService:GenerateGUID(false),
		zoneId = zone.def.id,
		rarity = rarity,
		model = model,
		nest = nest,
		dropped = false,
		surge = false,
		consumed = false,
	}
	self:_registerScroll(zone, record)
end

function ZoneService:_spawnLooseScroll(
	zone: ZoneRecord,
	position: Vector3,
	rarity: string,
	dropped: boolean,
	surge: boolean
)
	local model = Models.scroll(rarity)
	-- settle on the ground
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { scrollsFolder }
	local hit = Workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), params)
	local y = if hit then hit.Position.Y + 2 else position.Y + 2
	model:PivotTo(CFrame.new(position.X, y, position.Z))
	local record: ScrollRecord = {
		uid = HttpService:GenerateGUID(false),
		zoneId = zone.def.id,
		rarity = rarity,
		model = model,
		nest = nil,
		dropped = dropped,
		surge = surge,
		consumed = false,
	}
	self:_registerScroll(zone, record)
	if dropped then
		-- dropped scrolls despawn eventually so the map doesn't fill up
		task.delay(180, function()
			if not record.consumed then
				self:_removeScroll(zone, record)
			end
		end)
	end
	return record
end

function ZoneService:_removeScroll(zone: ZoneRecord, record: ScrollRecord)
	record.consumed = true
	zone.scrolls[record.uid] = nil
	record.model:Destroy()
	if record.nest then
		zone.nestBusy[record.nest] = nil
	end
end

-- Called when a carried scroll is dropped (boss catch, slap, death). Anyone can grab it, no speed check.
function ZoneService:SpawnDroppedScroll(position: Vector3, rarity: string, zoneId: number)
	local zone = zones[zoneId] or zones[1]
	if not zone then
		return
	end
	self:_spawnLooseScroll(zone, position, rarity, true, false)
end

function ZoneService:_tryPickup(player: Player, zone: ZoneRecord, record: ScrollRecord)
	if record.consumed then
		return
	end
	if not CharacterUtil.isAlive(player) or PowerService:IsStunned(player) then
		return
	end
	if not CarryService:CanCarry(player) then
		return
	end
	if not record.dropped and not self:MeetsRequirement(player, zone.def.id) then
		return
	end
	local root = CharacterUtil.root(player)
	local pivot = record.model:GetPivot().Position
	if not root or (root.Position - pivot).Magnitude > 14 then
		return
	end

	local nest = record.nest
	local insideZone = zone.bounds ~= nil and Region.isPointInPart(zone.bounds :: BasePart, pivot, 4)
	self:_removeScroll(zone, record)

	local ok = CarryService:PickupScroll(
		player,
		{ kind = "scroll", rarity = record.rarity, zoneId = zone.def.id, uid = record.uid }
	)
	if not ok then
		-- couldn't attach (race); put it back where it was
		self:_spawnLooseScroll(zone, pivot, record.rarity, true, false)
		return
	end
	self.ScrollPickedUp:Fire(player, record)
	if insideZone then
		self.ScrollLifted:Fire(zone.def.id, player)
	end
	if nest then
		local respawn = zone.def.scrollRespawnSeconds
		if zone.surgeUntil > os.clock() then
			respawn = math.max(3, respawn / Config.Events.VoidSurge.scrollMultiplier)
		end
		task.delay(respawn, function()
			self:_spawnNestScroll(zone, nest)
		end)
	end
end

--------------------------------------------------------------------------------
-- Void Surge
--------------------------------------------------------------------------------

function ZoneService:StartSurge(zoneId: number, multiplier: number, duration: number)
	local zone = zones[zoneId]
	if not zone then
		return
	end
	zone.surgeUntil = os.clock() + duration
	self.Client.SurgeChanged:FireAll(zoneId, true, os.time() + duration)
	local rng = Weighted.random()
	local extra = math.max(0, math.floor(#zone.nests * (multiplier - 1)))
	for i = 1, extra do
		local nest = zone.nests[(i % #zone.nests) + 1]
		if not nest then
			break
		end
		local rarity = Weighted.pick(zone.def.scrollPool, function(e)
			return e.weight
		end).rarity
		local offset = Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		self:_spawnLooseScroll(zone, Region.top(nest, 0) + offset, rarity, false, true)
	end
	task.delay(duration, function()
		for _, record in zone.scrolls do
			if record.surge and not record.consumed then
				self:_removeScroll(zone, record)
			end
		end
		self.Client.SurgeChanged:FireAll(zoneId, false, 0)
	end)
end

return ZoneService
