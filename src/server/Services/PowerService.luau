--!strict
--[[
	PowerService
	============
	Owns the Power stat -> WalkSpeed pipeline, movement modifiers (slows, stuns, boosts),
	punching-bag training, bag upgrades and the free-reward claims.

	Training: the client calls StartTraining when the player holds E at their bag and
	StopTraining when they let go. The server validates ownership, range, and liveness on
	every punch, so holding the key is the only thing the client actually controls.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local PowerMath = require(ReplicatedStorage.Shared.Util.PowerMath)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)

type Modifier = { multiplier: number, expiresAt: number? }

local PowerService = Knit.CreateService({
	Name = "PowerService",
	Client = {
		Power = Knit.CreateProperty(0), -- effective Power stat (after gamepasses)
		WalkSpeed = Knit.CreateProperty(16),
		Training = Knit.CreateProperty(false),
		Punch = Knit.CreateSignal(), -- (powerGained) each time a punch lands
		Stunned = Knit.CreateSignal(), -- (seconds)
	},
	PowerChanged = Signal.new(), -- (player, effectivePower)
})

local DataService: any
local BaseService: any
local MonetizationService: any

local modifiers: { [Player]: { [string]: Modifier } } = {}
local stunUntil: { [Player]: number } = {}
local training: { [Player]: boolean } = {}

function PowerService:KnitInit()
	DataService = Knit.GetService("DataService")
	BaseService = Knit.GetService("BaseService")
	MonetizationService = Knit.GetService("MonetizationService")
	CharacterUtil.setupCollisionGroups()
end

function PowerService:KnitStart()
	DataService.Loaded:Connect(function(player: Player)
		modifiers[player] = {}
		self:Refresh(player)
		local function onCharacter(char: Model)
			CharacterUtil.applyCharacterGroup(char)
			training[player] = nil
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
		training[player] = nil
	end)
	MonetizationService.GamepassGranted:Connect(function(player: Player)
		self:Refresh(player)
	end)
	BaseService.Assigned:Connect(function(player: Player, base: any)
		self:_refreshBagPrompt(base)
	end)

	-- modifier expiry + punching-bag tick
	task.spawn(function()
		local punchAccum = 0
		while true do
			local dt = task.wait(0.25)
			punchAccum += dt
			local doPunch = punchAccum >= Config.Power.PunchingBag.tickSeconds
			if doPunch then
				punchAccum -= Config.Power.PunchingBag.tickSeconds
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
				if doPunch and training[player] then
					dirty = self:_punchTick(player) or dirty
				end
				if dirty then
					self:Refresh(player)
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Power stat
--------------------------------------------------------------------------------

function PowerService:GetEffectivePower(player: Player): number
	local data = DataService:Get(player)
	if not data then
		return 0
	end
	return PowerMath.effectivePower(data.power, data.gamepasses)
end

function PowerService:AddPower(player: Player, amount: number)
	local data = DataService:Get(player)
	if not data then
		return
	end
	data.power = math.max(0, math.floor(data.power + amount))
	self:Refresh(player)
end

function PowerService:IsStunned(player: Player): boolean
	local s = stunUntil[player]
	return s ~= nil and s > os.clock()
end

function PowerService:Stun(player: Player, seconds: number)
	local now = os.clock()
	stunUntil[player] = math.max(stunUntil[player] or 0, now + seconds)
	self.Client.Stunned:Fire(player, seconds)
	self:Refresh(player)
end

function PowerService:AddModifier(player: Player, key: string, multiplier: number, duration: number?)
	local mods = modifiers[player]
	if not mods then
		return
	end
	mods[key] = { multiplier = multiplier, expiresAt = if duration then os.clock() + duration else nil }
	self:Refresh(player)
end

function PowerService:RemoveModifier(player: Player, key: string)
	local mods = modifiers[player]
	if mods and mods[key] then
		mods[key] = nil
		self:Refresh(player)
	end
end

function PowerService:GetWalkSpeed(player: Player): number
	local effective = self:GetEffectivePower(player)
	local walk = PowerMath.walkSpeedFor(effective)
	local mods = modifiers[player]
	if mods then
		for _, m in mods do
			walk *= m.multiplier
		end
	end
	if self:IsStunned(player) then
		walk = 0
	end
	return math.clamp(walk, 0, Config.Power.MaxWalkSpeed * 2)
end

-- Recompute effective Power + WalkSpeed and push to the character and client
function PowerService:Refresh(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local effective = PowerMath.effectivePower(data.power, data.gamepasses)
	local walk = self:GetWalkSpeed(player)
	local humanoid = CharacterUtil.humanoid(player)
	if humanoid then
		humanoid.WalkSpeed = walk
		humanoid.JumpPower = if self:IsStunned(player) then 0 else 50
		humanoid.UseJumpPower = true
	end
	self.Client.Power:SetFor(player, effective)
	self.Client.WalkSpeed:SetFor(player, walk)
	self.PowerChanged:Fire(player, effective)
end

--------------------------------------------------------------------------------
-- Punching bag
--------------------------------------------------------------------------------

-- Can this player train at their bag right now? Returns the bag part when they can.
function PowerService:_bagFor(player: Player): BasePart?
	local base = BaseService:GetBaseOf(player)
	local bag = if base then base.bag else nil
	if not bag then
		return nil
	end
	if not CharacterUtil.isAlive(player) or self:IsStunned(player) then
		return nil
	end
	local root = CharacterUtil.root(player)
	if not root or (root.Position - bag.Position).Magnitude > Config.Power.PunchingBag.range then
		return nil
	end
	return bag
end

function PowerService:_setTraining(player: Player, active: boolean)
	if (training[player] == true) == active then
		return
	end
	if active then
		training[player] = true
	else
		training[player] = nil
	end
	self.Client.Training:SetFor(player, active)
end

-- One punch: validate, grant Power, swing the bag. Returns true if the player is still training.
function PowerService:_punchTick(player: Player): boolean
	local data = DataService:Get(player)
	local bag = self:_bagFor(player)
	if not data or not bag then
		self:_setTraining(player, false)
		return false
	end
	local gain = Config.Power.punchPower(data.bagLevel)
	data.power += gain
	self.Client.Punch:Fire(player, gain)
	self:_swing(bag)
	return true
end

local swinging: { [BasePart]: boolean } = {}

function PowerService:_swing(bag: BasePart)
	if swinging[bag] then
		return
	end
	swinging[bag] = true
	local rest = bag.CFrame
	-- pivot about the top of the bag (where the chain is) in world space, so it swings rather than spins
	local height = math.max(bag.Size.X, bag.Size.Y, bag.Size.Z)
	local pivot = CFrame.new(bag.Position + Vector3.new(0, height / 2, 0))
	local hit = pivot * CFrame.Angles(math.rad(16), 0, 0) * pivot:Inverse() * rest
	local out =
		TweenService:Create(bag, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = hit })
	out:Play()
	out.Completed:Once(function()
		local back = TweenService:Create(
			bag,
			TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ CFrame = rest }
		)
		back:Play()
		back.Completed:Once(function()
			bag.CFrame = rest
			swinging[bag] = nil
		end)
	end)
end

-- The bag's upgrade prompt shows the owner's next cost, so refresh it whenever the level changes.
function PowerService:_refreshBagPrompt(base: any)
	local bag = base.bag
	local owner = base.owner
	local prompt = if bag then bag:FindFirstChild("UpgradePrompt") else nil
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	local data = if owner then DataService:Get(owner) else nil
	if not data then
		prompt.Enabled = false
		return
	end
	local Format = require(ReplicatedStorage.Shared.Util.Format)
	local cost = Config.Power.bagUpgradeCost(data.bagLevel)
	prompt.Enabled = true
	prompt.ObjectText = `Punching Bag (Lv {data.bagLevel})`
	if cost then
		prompt.ActionText = `Upgrade  {Format.cash(cost)}`
	else
		prompt.ActionText = "Max level"
	end
	if bag then
		bag:SetAttribute("BagLevel", data.bagLevel)
		bag:SetAttribute("PowerPerPunch", Config.Power.punchPower(data.bagLevel))
	end
end

function PowerService:RefreshBagFor(player: Player)
	local base = BaseService:GetBaseOf(player)
	if base then
		self:_refreshBagPrompt(base)
	end
end

function PowerService.Client:StartTraining(player: Player): boolean
	if not self.Server:_bagFor(player) then
		return false
	end
	self.Server:_setTraining(player, true)
	return true
end

function PowerService.Client:StopTraining(player: Player)
	self.Server:_setTraining(player, false)
end

function PowerService.Client:UpgradeBag(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local cost = Config.Power.bagUpgradeCost(data.bagLevel)
	if not cost then
		return false, "Punching bag is max level"
	end
	if not DataService:SpendCash(player, cost) then
		return false, "Not enough cash"
	end
	data.bagLevel += 1
	DataService:Replicate(player)
	self.Server:RefreshBagFor(player)
	local Format = require(ReplicatedStorage.Shared.Util.Format)
	return true,
		`Punching bag level {data.bagLevel} — {Format.short(Config.Power.punchPower(data.bagLevel))} Power per punch`
end

--------------------------------------------------------------------------------
-- Free rewards
--------------------------------------------------------------------------------

function PowerService.Client:ClaimFreeReward(player: Player, kind: string): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local FR = Config.Power.FreeRewards
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
	local amount = (FR :: any)[kind].power :: number
	self.Server:AddPower(player, amount)
	DataService:Replicate(player)
	return true, `+{amount} Power`
end

return PowerService
