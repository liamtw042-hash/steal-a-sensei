--!strict
--[[
	BaseService
	===========
	Eight bases per server. Assignment, locking (join auto-lock, lock pad, cooldown),
	laser gate enforcement, friend whitelist, alarm trap, guard NPC, slot unlock rules.
	Gate collision for non-owners is handled on the client; the server ejects anyone
	inside a locked base who isn't allowed there, so it can't be bypassed.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Region = require(ReplicatedStorage.Shared.Util.Region)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)
local NpcRig = require(script.Parent.Parent.Util.NpcRig)

export type BaseRecord = {
	index: number,
	folder: Instance,
	region: BasePart?,
	entrance: BasePart?,
	gates: { BasePart },
	lockPad: BasePart?,
	treadmill: BasePart?,
	spawn: BasePart?,
	slots: { BasePart }, -- sorted by numeric suffix; slot index = position in this list
	sign: BasePart?,
	guardPath: { BasePart },
	owner: Player?,
	lockedUntil: number, -- server time (Workspace:GetServerTimeNow())
	lockCooldownUntil: number,
	alarmReadyAt: number,
	guard: Model?,
	insideLastTick: { [Player]: boolean },
}

local BaseService = Knit.CreateService({
	Name = "BaseService",
	Client = {
		BaseIndex = Knit.CreateProperty(0),
		Alert = Knit.CreateSignal(), -- (text, kind)
		TheftAlert = Knit.CreateSignal(), -- (thiefUserId, fighterName)
	},
	Assigned = Signal.new(), -- (player, base)
	Unassigned = Signal.new(), -- (player, base)
	Intruder = Signal.new(), -- (base, intruder)  fired on entry into an unlocked base
})

local DataService: any
local SpeedService: any
local MonetizationService: any
local CarryService: any

local bases: { BaseRecord } = {}
local baseOf: { [Player]: BaseRecord } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function findPart(parent: Instance, name: string): BasePart?
	local c = parent:FindFirstChild(name)
	return if c and c:IsA("BasePart") then c else nil
end

local function partsIn(parent: Instance?, sortNumeric: boolean): { BasePart }
	local out = {}
	if parent then
		for _, c in parent:GetChildren() do
			if c:IsA("BasePart") then
				table.insert(out, c)
			end
		end
		table.sort(out, function(a, b)
			if sortNumeric then
				local na = tonumber(a.Name:match("%d+$")) or 0
				local nb = tonumber(b.Name:match("%d+$")) or 0
				if na ~= nb then
					return na < nb
				end
			end
			return a.Name < b.Name
		end)
	end
	return out
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function BaseService:KnitInit()
	DataService = Knit.GetService("DataService")
	SpeedService = Knit.GetService("SpeedService")
	MonetizationService = Knit.GetService("MonetizationService")
	CarryService = Knit.GetService("CarryService")

	local basesFolder = Workspace:FindFirstChild("Bases")
	if not basesFolder then
		warn("[BaseService] Workspace.Bases is missing; nobody can own a base")
		return
	end
	for i = 1, Config.Base.Count do
		local folder = basesFolder:FindFirstChild("Base" .. i)
		if not folder then
			warn(`[BaseService] Workspace.Bases.Base{i} is missing`)
			continue
		end
		local rec: BaseRecord = {
			index = i,
			folder = folder,
			region = findPart(folder, "Region"),
			entrance = findPart(folder, "Entrance"),
			gates = partsIn(folder:FindFirstChild("Gates"), false),
			lockPad = findPart(folder, "LockPad"),
			treadmill = findPart(folder, "Treadmill"),
			spawn = findPart(folder, "Spawn"),
			slots = partsIn(folder:FindFirstChild("Slots"), true),
			sign = findPart(folder, "Sign"),
			guardPath = partsIn(folder:FindFirstChild("GuardPath"), true),
			owner = nil,
			lockedUntil = 0,
			lockCooldownUntil = 0,
			alarmReadyAt = 0,
			guard = nil,
			insideLastTick = {},
		}
		if not rec.region then
			warn(`[BaseService] Base{i} has no Region part; securing scrolls there won't work`)
		end
		for _, gate in rec.gates do
			gate.CanCollide = false -- collision is per-client; server enforces by ejecting
			gate.CanTouch = false
		end
		folder:SetAttribute("BaseIndex", i)
		self:_writeAttributes(rec)
		self:_setupSign(rec)
		if rec.lockPad then
			rec.lockPad.Touched:Connect(function(hit)
				local player = CharacterUtil.playerFromPart(hit)
				if player and rec.owner == player then
					self:TryLock(player)
				end
			end)
		end
		table.insert(bases, rec)
	end
end

function BaseService:KnitStart()
	DataService.Loaded:Connect(function(player: Player)
		self:_assign(player)
	end)
	DataService.Released:Connect(function(player: Player)
		self:_unassign(player)
	end)
	MonetizationService.GamepassGranted:Connect(function(player: Player, key: string)
		local base = baseOf[player]
		if not base then
			return
		end
		if key == "Guard" then
			self:_spawnGuard(base)
		end
		self:_writeAttributes(base)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Base.Lock.intruderCheckInterval)
			self:_tick()
		end
	end)
end

function BaseService:_setupSign(base: BaseRecord)
	if not base.sign then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "OwnerSign"
	bb.Size = UDim2.fromOffset(260, 70)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	bb.Parent = base.sign
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Text"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0.3
	lbl.Text = "Empty Base"
	lbl.Parent = bb
end

function BaseService:_writeAttributes(base: BaseRecord)
	local f = base.folder
	local owner = base.owner
	f:SetAttribute("OwnerUserId", if owner then owner.UserId else 0)
	f:SetAttribute("OwnerName", if owner then owner.DisplayName else "")
	f:SetAttribute("LockedUntil", base.lockedUntil)
	f:SetAttribute("LockCooldownUntil", base.lockCooldownUntil)
	local data = if owner then DataService:Get(owner) else nil
	f:SetAttribute("Friends", if data then HttpService:JSONEncode(data.friends) else "{}")
	f:SetAttribute("UnlockedSlots", if data then self:GetUnlockedSlotCount(data) else 0)
	f:SetAttribute("UnlockedFloor", if data then self:GetUnlockedFloor(data) else 0)
	f:SetAttribute("AlarmTrap", if data then data.alarmTrap else false)
	local locked = self:IsLocked(base)
	local lasers = f:FindFirstChild("Lasers")
	if lasers then
		-- real laser beams: enable while locked
		for _, d in lasers:GetDescendants() do
			if d:IsA("Beam") then
				d.Enabled = locked
			end
		end
	else
		for _, gate in base.gates do
			gate.Transparency = if locked then 0.35 else 0.9
		end
	end
	local sign = base.sign
	local bb = if sign then sign:FindFirstChild("OwnerSign") else nil
	local lbl = if bb then bb:FindFirstChild("Text") else nil
	if lbl and lbl:IsA("TextLabel") then
		lbl.Text = if owner then `{owner.DisplayName}'s Base` else "Empty Base"
	end
end

--------------------------------------------------------------------------------
-- Assignment
--------------------------------------------------------------------------------

function BaseService:_assign(player: Player)
	if baseOf[player] then
		return
	end
	local free: BaseRecord? = nil
	for _, b in bases do
		if not b.owner then
			free = b
			break
		end
	end
	if not free then
		warn(`[BaseService] no free base for {player.Name}`)
		return
	end
	local base = free :: BaseRecord
	base.owner = player
	base.insideLastTick = {}
	baseOf[player] = base
	self.Client.BaseIndex:SetFor(player, base.index)

	-- spawn at base
	local function onCharacter(char: Model)
		task.defer(function()
			if base.owner ~= player then
				return
			end
			local spawnPart = base.spawn
			if spawnPart and char.Parent then
				char:PivotTo(spawnPart.CFrame + Vector3.new(0, spawnPart.Size.Y / 2 + 3.5, 0))
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	self:Lock(base, self:_lockDuration(player, Config.Base.Lock.joinLockSeconds), true)
	self:_writeAttributes(base)
	if MonetizationService:Owns(player, "Guard") then
		self:_spawnGuard(base)
	end
	self.Assigned:Fire(player, base)
end

function BaseService:_unassign(player: Player)
	local base = baseOf[player]
	if not base then
		return
	end
	baseOf[player] = nil
	self.Unassigned:Fire(player, base)
	base.owner = nil
	base.lockedUntil = 0
	base.lockCooldownUntil = 0
	base.insideLastTick = {}
	if base.guard then
		base.guard:Destroy()
		base.guard = nil
	end
	self:_writeAttributes(base)
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------

function BaseService:GetBaseOf(player: Player): BaseRecord?
	return baseOf[player]
end

function BaseService:GetBases(): { BaseRecord }
	return bases
end

function BaseService:GetBaseAt(position: Vector3): BaseRecord?
	for _, b in bases do
		if b.region and Region.isPointInPart(b.region, position) then
			return b
		end
	end
	return nil
end

function BaseService:IsInside(base: BaseRecord, position: Vector3): boolean
	return base.region ~= nil and Region.isPointInPart(base.region :: BasePart, position)
end

function BaseService:IsLocked(base: BaseRecord): boolean
	return base.owner ~= nil and base.lockedUntil > now()
end

function BaseService:IsAuthorized(base: BaseRecord, player: Player): boolean
	if base.owner == player then
		return true
	end
	local owner = base.owner
	local data = if owner then DataService:Get(owner) else nil
	return data ~= nil and data.friends[tostring(player.UserId)] == true
end

function BaseService:GetUnlockedFloor(data: Types.PlayerData): number
	local B = Config.Base
	if data.rebirths >= B.Floor3Rebirth then
		return 3
	elseif data.rebirths >= B.Floor2Rebirth then
		return 2
	end
	return 1
end

function BaseService:GetUnlockedSlotCount(data: Types.PlayerData): number
	local B = Config.Base
	local n = B.Floor1Slots + data.rebirths * B.SlotsPerRebirth
	if data.rebirths >= B.Floor2Rebirth then
		n += B.Floor2Slots
	end
	if data.rebirths >= B.Floor3Rebirth then
		n += B.Floor3Slots
	end
	if data.gamepasses.Slots5 then
		n += B.GamepassBonusSlots
	end
	return n
end

-- Slot indices (1-based positions in base.slots) the owner may currently use
function BaseService:GetUsableSlotIndices(base: BaseRecord, data: Types.PlayerData): { number }
	local floor = self:GetUnlockedFloor(data)
	local count = self:GetUnlockedSlotCount(data)
	local out = {}
	for i, part in base.slots do
		local f = part:GetAttribute("Floor")
		local slotFloor = if typeof(f) == "number" then f else 1
		if slotFloor <= floor then
			table.insert(out, i)
			if #out >= count then
				break
			end
		end
	end
	return out
end

function BaseService:GetSlotPart(base: BaseRecord, index: number): BasePart?
	return base.slots[index]
end

function BaseService:Notify(player: Player, text: string, kind: string?)
	self.Client.Alert:Fire(player, text, kind or "info")
end

function BaseService:RefreshAttributes(player: Player)
	local base = baseOf[player]
	if base then
		self:_writeAttributes(base)
	end
end

--------------------------------------------------------------------------------
-- Locking
--------------------------------------------------------------------------------

function BaseService:_lockDuration(player: Player, seconds: number): number
	local data = DataService:Get(player)
	local bonus = 0
	if data then
		bonus += data.rebirths * Config.Base.Lock.perRebirthBonusSeconds
		if data.gamepasses.VIP then
			bonus += Config.Base.Lock.vipBonusSeconds
		end
	end
	return seconds + bonus
end

function BaseService:Lock(base: BaseRecord, seconds: number, silent: boolean?)
	base.lockedUntil = now() + seconds
	self:_writeAttributes(base)
	local owner = base.owner
	if owner and not silent then
		self:Notify(owner, `Base locked for {math.floor(seconds)}s`, "lock")
	end
	task.delay(seconds + 0.05, function()
		if base.owner and base.lockedUntil <= now() then
			base.lockCooldownUntil = now() + Config.Base.Lock.cooldownAfterUnlockSeconds
			self:_writeAttributes(base)
			if base.owner then
				self:Notify(base.owner, "Base unlocked!", "unlock")
			end
		end
	end)
end

function BaseService:TryLock(player: Player): (boolean, string)
	local base = baseOf[player]
	if not base then
		return false, "No base"
	end
	if self:IsLocked(base) then
		return false, "Already locked"
	end
	if base.lockCooldownUntil > now() then
		return false, `Lock on cooldown ({math.ceil(base.lockCooldownUntil - now())}s)`
	end
	self:Lock(base, self:_lockDuration(player, Config.Base.Lock.padLockSeconds))
	return true, "Locked"
end

--------------------------------------------------------------------------------
-- Intruders, alarm, guard
--------------------------------------------------------------------------------

function BaseService:_eject(base: BaseRecord, intruder: Player)
	local entrance = base.entrance
	local target = if entrance
		then entrance.CFrame + Vector3.new(0, entrance.Size.Y / 2 + 3, 0)
		else CharacterUtil.spawnCFrame()
	CarryService:Drop(intruder, CharacterUtil.position(intruder), "lasers")
	CharacterUtil.teleport(intruder, target)
	if base.region then
		CharacterUtil.knockback(intruder, base.region.Position, 30, 20)
	end
	self:Notify(intruder, "That base is locked!", "warn")
end

function BaseService:_tick()
	local players = Players:GetPlayers()
	for _, base in bases do
		if not base.owner or not base.region then
			continue
		end
		local locked = self:IsLocked(base)
		for _, player in players do
			if player == base.owner then
				continue
			end
			local pos = CharacterUtil.position(player)
			local inside = pos ~= nil and Region.isPointInPart(base.region :: BasePart, pos :: Vector3)
			local wasInside = base.insideLastTick[player] == true
			base.insideLastTick[player] = inside
			if not inside then
				continue
			end
			if self:IsAuthorized(base, player) then
				continue
			end
			if locked then
				self:_eject(base, player)
			elseif not wasInside then
				self.Intruder:Fire(base, player)
				self:_onIntruderEntered(base, player)
			end
		end
	end
end

function BaseService:_onIntruderEntered(base: BaseRecord, intruder: Player)
	local owner = base.owner
	if not owner then
		return
	end
	local data = DataService:Get(owner)
	if data and data.alarmTrap and base.alarmReadyAt <= now() then
		local A = Config.Base.AlarmTrap
		base.alarmReadyAt = now() + A.cooldownSeconds
		SpeedService:Stun(intruder, A.stunSeconds)
		SpeedService:AddModifier(owner, "alarmBoost", A.ownerSpeedMultiplier, A.ownerBoostSeconds)
		self:Notify(owner, `ALARM! {intruder.DisplayName} is in your base!`, "alarm")
		self:Notify(intruder, "You triggered an alarm trap!", "warn")
	end
end

function BaseService:_spawnGuard(base: BaseRecord)
	if base.guard or not base.owner then
		return
	end
	local G = Config.Base.Guard
	local rig = NpcRig.build({
		name = "Guard",
		displayName = "Guard",
		color = Color3.fromRGB(60, 60, 200),
		walkSpeed = G.walkSpeed,
		folderName = "Bosses",
	})
	local path = if #base.guardPath > 0 then base.guardPath else base.slots
	local start = path[1] or base.spawn or base.region
	if start then
		rig:PivotTo(start.CFrame + Vector3.new(0, 4, 0))
	end
	rig.Parent = base.folder
	NpcRig.claimOwnership(rig)
	base.guard = rig

	task.spawn(function()
		local humanoid = rig:FindFirstChildOfClass("Humanoid")
		local root = rig:FindFirstChild("HumanoidRootPart")
		local idx = 1
		while base.guard == rig and rig.Parent and humanoid and root and root:IsA("BasePart") do
			local intruder: Player? = nil
			for _, p in Players:GetPlayers() do
				if p ~= base.owner and not self:IsAuthorized(base, p) then
					local pos = CharacterUtil.position(p)
					if pos and base.region and Region.isPointInPart(base.region, pos) then
						intruder = p
						if (pos - root.Position).Magnitude <= G.slowRadius then
							SpeedService:AddModifier(p, "guardSlow", G.slowMultiplier, G.slowSeconds)
						end
						break
					end
				end
			end
			if intruder then
				local pos = CharacterUtil.position(intruder)
				if pos then
					humanoid:MoveTo(pos)
				end
			else
				local target = path[idx]
				if target then
					if (target.Position - root.Position).Magnitude < 4 then
						idx = (idx % #path) + 1
					else
						humanoid:MoveTo(target.Position)
					end
				end
			end
			task.wait(G.tickSeconds)
		end
	end)
end

--------------------------------------------------------------------------------
-- Client API
--------------------------------------------------------------------------------

function BaseService.Client:SetFriend(player: Player, userId: number, allowed: boolean): boolean
	local data = DataService:Get(player)
	if not data or typeof(userId) ~= "number" or userId == player.UserId then
		return false
	end
	data.friends[tostring(math.floor(userId))] = if allowed then true else nil
	DataService:Replicate(player)
	self.Server:RefreshAttributes(player)
	return true
end

function BaseService.Client:LockBase(player: Player): (boolean, string)
	return self.Server:TryLock(player)
end

function BaseService.Client:BuyAlarmTrap(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if data.alarmTrap then
		return false, "Already owned"
	end
	if not DataService:SpendCash(player, Config.Base.AlarmTrap.cost) then
		return false, "Not enough cash"
	end
	data.alarmTrap = true
	DataService:Replicate(player)
	self.Server:RefreshAttributes(player)
	return true, "Alarm trap installed"
end

function BaseService.Client:GetBaseInfo(player: Player): Types.BaseInfo?
	local base = baseOf[player]
	if not base then
		return nil
	end
	local data = DataService:Get(player)
	return {
		index = base.index,
		ownerUserId = player.UserId,
		ownerName = player.DisplayName,
		lockedUntil = base.lockedUntil,
		lockCooldownUntil = base.lockCooldownUntil,
		friends = if data then data.friends else {},
		unlockedSlots = if data then self.Server:GetUnlockedSlotCount(data) else 0,
		unlockedFloor = if data then self.Server:GetUnlockedFloor(data) else 1,
		usableSlots = if data then self.Server:GetUsableSlotIndices(base, data) else {},
	}
end

return BaseService
