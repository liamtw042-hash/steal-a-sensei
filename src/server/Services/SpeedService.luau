--!strict
--[[
	SpeedService
	============
	Owns the speed stat -> WalkSpeed pipeline, movement modifiers (slows, stuns, boosts),
	the treadmill AFK gain, treadmill upgrades and the free-reward claims.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local SpeedMath = require(ReplicatedStorage.Shared.Util.SpeedMath)
local Region = require(ReplicatedStorage.Shared.Util.Region)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)

type Modifier = { multiplier: number, expiresAt: number? }

local SpeedService = Knit.CreateService({
	Name = "SpeedService",
	Client = {
		Speed = Knit.CreateProperty(0), -- effective speed stat (after gamepasses)
		WalkSpeed = Knit.CreateProperty(16),
		TreadmillActive = Knit.CreateProperty(false),
		Stunned = Knit.CreateSignal(), -- (seconds)
	},
	SpeedChanged = Signal.new(), -- (player, effectiveSpeed)
})

local DataService: any
local BaseService: any
local MonetizationService: any

local modifiers: { [Player]: { [string]: Modifier } } = {}
local stunUntil: { [Player]: number } = {}

function SpeedService:KnitInit()
	DataService = Knit.GetService("DataService")
	BaseService = Knit.GetService("BaseService")
	MonetizationService = Knit.GetService("MonetizationService")
	CharacterUtil.setupCollisionGroups()
end

function SpeedService:KnitStart()
	DataService.Loaded:Connect(function(player: Player)
		modifiers[player] = {}
		self:Refresh(player)
		local function onCharacter(char: Model)
			CharacterUtil.applyCharacterGroup(char)
			local humanoid = char:WaitForChild("Humanoid", 5)
			if humanoid then
				task.defer(function()
					self:Refresh(player)
				end)
			end
		end
		if player.Character then
			onCharacter(player.Character)
		end
		player.CharacterAdded:Connect(onCharacter)
	end)
	DataService.Released:Connect(function(player: Player)
		modifiers[player] = nil
		stunUntil[player] = nil
	end)
	MonetizationService.GamepassGranted:Connect(function(player: Player)
		self:Refresh(player)
	end)

	-- modifier expiry + treadmill tick
	task.spawn(function()
		local treadmillAccum = 0
		while true do
			local dt = task.wait(0.25)
			treadmillAccum += dt
			local doTreadmill = treadmillAccum >= 1
			if doTreadmill then
				treadmillAccum -= 1
			end
			local now = os.clock()
			for player, mods in modifiers do
				local dirty = false
				for key, mod in mods do
					if mod.expiresAt and mod.expiresAt <= now then
						mods[key] = nil
						dirty = true
					end
				end
				local stun = stunUntil[player]
				if stun and stun <= now then
					stunUntil[player] = nil
					dirty = true
				end
				if doTreadmill then
					dirty = self:_treadmillTick(player) or dirty
				end
				if dirty then
					self:Refresh(player)
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Speed stat
--------------------------------------------------------------------------------

function SpeedService:GetEffectiveSpeed(player: Player): number
	local data = DataService:Get(player)
	if not data then
		return 0
	end
	return SpeedMath.effectiveSpeed(data.speed, data.gamepasses)
end

function SpeedService:AddSpeed(player: Player, amount: number)
	local data = DataService:Get(player)
	if not data then
		return
	end
	data.speed = math.max(0, math.floor(data.speed + amount))
	self:Refresh(player)
end

function SpeedService:IsStunned(player: Player): boolean
	local s = stunUntil[player]
	return s ~= nil and s > os.clock()
end

function SpeedService:Stun(player: Player, seconds: number)
	local now = os.clock()
	stunUntil[player] = math.max(stunUntil[player] or 0, now + seconds)
	self.Client.Stunned:Fire(player, seconds)
	self:Refresh(player)
end

function SpeedService:AddModifier(player: Player, key: string, multiplier: number, duration: number?)
	local mods = modifiers[player]
	if not mods then
		return
	end
	mods[key] = { multiplier = multiplier, expiresAt = if duration then os.clock() + duration else nil }
	self:Refresh(player)
end

function SpeedService:RemoveModifier(player: Player, key: string)
	local mods = modifiers[player]
	if mods and mods[key] then
		mods[key] = nil
		self:Refresh(player)
	end
end

function SpeedService:GetWalkSpeed(player: Player): number
	local effective = self:GetEffectiveSpeed(player)
	local walk = SpeedMath.walkSpeedFor(effective)
	local mods = modifiers[player]
	if mods then
		for _, m in mods do
			walk *= m.multiplier
		end
	end
	if self:IsStunned(player) then
		walk = 0
	end
	return math.clamp(walk, 0, Config.Speed.MaxWalkSpeed * 2)
end

-- Recompute effective speed + WalkSpeed and push to the character and client
function SpeedService:Refresh(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local effective = SpeedMath.effectiveSpeed(data.speed, data.gamepasses)
	local walk = self:GetWalkSpeed(player)
	local humanoid = CharacterUtil.humanoid(player)
	if humanoid then
		humanoid.WalkSpeed = walk
		humanoid.JumpPower = if self:IsStunned(player) then 0 else 50
		humanoid.UseJumpPower = true
	end
	self.Client.Speed:SetFor(player, effective)
	self.Client.WalkSpeed:SetFor(player, walk)
	self.SpeedChanged:Fire(player, effective)
end

--------------------------------------------------------------------------------
-- Treadmill
--------------------------------------------------------------------------------

function SpeedService:_treadmillTick(player: Player): boolean
	local data = DataService:Get(player)
	local base = BaseService:GetBaseOf(player)
	local root = CharacterUtil.root(player)
	local active = false
	if data and base and root and base.treadmill then
		if Region.isPointInPart(base.treadmill, root.Position, 4) then
			local rate = Config.Speed.Treadmill.ratePerSecond(data.treadmillLevel)
			data.speed += rate
			active = true
		end
	end
	local was = self.Client.TreadmillActive:GetFor(player)
	if was ~= active then
		self.Client.TreadmillActive:SetFor(player, active)
	end
	return active
end

function SpeedService.Client:UpgradeTreadmill(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local T = Config.Speed.Treadmill
	if data.treadmillLevel >= T.maxLevel then
		return false, "Treadmill is max level"
	end
	local cost = T.upgradeCost(data.treadmillLevel)
	if not DataService:SpendCash(player, cost) then
		return false, "Not enough cash"
	end
	data.treadmillLevel += 1
	DataService:Replicate(player)
	return true, `Treadmill level {data.treadmillLevel}`
end

--------------------------------------------------------------------------------
-- Free rewards
--------------------------------------------------------------------------------

function SpeedService.Client:ClaimFreeReward(player: Player, kind: string): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local FR = Config.Speed.FreeRewards
	if kind ~= "like" and kind ~= "favourite" and kind ~= "group" then
		return false, "Unknown reward"
	end
	local rewards = data.freeRewards :: { [string]: boolean }
	if rewards[kind] then
		return false, "Already claimed"
	end
	if kind == "group" then
		if FR.groupId ~= 0 then
			local ok, inGroup = pcall(function()
				return player:IsInGroupAsync(FR.groupId)
			end)
			if not ok or not inGroup then
				return false, "Join the group first, then try again"
			end
		end
	else
		-- Roblox has no API to verify likes/favourites; honour system with a short delay
		task.wait(FR.honourDelaySeconds)
		if not player.Parent then
			return false, "Left"
		end
		if rewards[kind] then
			return false, "Already claimed"
		end
	end
	rewards[kind] = true
	local amount = (FR :: any)[kind].speed :: number
	self.Server:AddSpeed(player, amount)
	DataService:Replicate(player)
	return true, `+{amount} speed`
end

return SpeedService
