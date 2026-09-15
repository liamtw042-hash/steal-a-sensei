--!strict
--[[
	CombatService
	=============
	Slap, Trap, Smoke Bomb, Grapple, Body Swap. Shield is passive (BossService).
	Everything is validated server-side: ownership/uses, cooldown, range.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)

local C = Config.Monetization.Combat

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		Effect = Knit.CreateSignal(), -- to everyone: (kind, position, extra)
	},
})

local DataService: any
local SpeedService: any
local CarryService: any
local BaseService: any

local cooldowns: { [Player]: { [string]: number } } = {}

function CombatService:KnitInit()
	DataService = Knit.GetService("DataService")
	SpeedService = Knit.GetService("SpeedService")
	CarryService = Knit.GetService("CarryService")
	BaseService = Knit.GetService("BaseService")
end

function CombatService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

local function onCooldown(player: Player, key: string, seconds: number): boolean
	local cds = cooldowns[player]
	if not cds then
		cds = {}
		cooldowns[player] = cds
	end
	local now = os.clock()
	if (cds[key] or 0) > now then
		return true
	end
	cds[key] = now + seconds
	return false
end

local function nearestOther(player: Player, range: number): Player?
	local pos = CharacterUtil.position(player)
	if not pos then
		return nil
	end
	local best: Player? = nil
	local bestDist = range
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local op = CharacterUtil.position(other)
		if op and CharacterUtil.isAlive(other) then
			local d = (op - pos).Magnitude
			if d < bestDist then
				best = other
				bestDist = d
			end
		end
	end
	return best
end

local function playerInRange(player: Player, targetUserId: number, range: number): Player?
	local target = Players:GetPlayerByUserId(targetUserId)
	local pos = CharacterUtil.position(player)
	local tp = if target then CharacterUtil.position(target) else nil
	if not target or not pos or not tp or target == player then
		return nil
	end
	if (tp - pos).Magnitude > range then
		return nil
	end
	return target
end

local function useCharge(data: any, key: string): boolean
	local gear = data.gear
	local v = gear[key]
	if typeof(v) == "number" then
		if v <= 0 then
			return false
		end
		gear[key] = v - 1
		return true
	end
	return v == true
end

--------------------------------------------------------------------------------

function CombatService.Client:UseSlap(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data or not data.gear.Slap then
		return false, "You don't own Slap"
	end
	if SpeedService:IsStunned(player) or not CharacterUtil.isAlive(player) then
		return false, "Can't right now"
	end
	if onCooldown(player, "Slap", C.slapCooldown) then
		return false, "Slap is on cooldown"
	end
	local pos = CharacterUtil.position(player) :: Vector3
	local target = nearestOther(player, C.slapRange)
	self.Client.Effect:FireAll("slap", pos, nil)
	if not target then
		return true, "Whiff!"
	end
	if CharacterUtil.isInvulnerable(target) then
		return true, "They're invulnerable"
	end
	local tpos = CharacterUtil.position(target)
	CarryService:Drop(target, tpos, "slapped")
	CharacterUtil.knockback(target, pos, C.slapKnockback, 30)
	BaseService:Notify(target, `{player.DisplayName} slapped you!`, "warn")
	return true, `Slapped {target.DisplayName}`
end

function CombatService.Client:PlaceTrap(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if not CharacterUtil.isAlive(player) then
		return false, "Can't right now"
	end
	if data.gear.Trap <= 0 then
		return false, "No traps left"
	end
	if onCooldown(player, "Trap", 1) then
		return false, "Too fast"
	end
	useCharge(data, "Trap")
	DataService:Replicate(player)

	local pos = CharacterUtil.position(player) :: Vector3
	local trap = Instance.new("Part")
	trap.Name = "Trap"
	trap.Size = Vector3.new(4, 0.4, 4)
	trap.Anchored = true
	trap.CanCollide = false
	trap.CanQuery = false
	trap.Color = Color3.fromRGB(200, 60, 60)
	trap.Material = Enum.Material.Metal
	trap.Transparency = 0.3
	trap.CFrame = CFrame.new(pos - Vector3.new(0, 2.8, 0))
	trap:SetAttribute("OwnerUserId", player.UserId)
	trap.Parent = Workspace
	Debris:AddItem(trap, C.trapLifetimeSeconds)
	local armed = false
	task.delay(C.trapArmDelay, function()
		armed = true
	end)
	local sprung = false
	trap.Touched:Connect(function(hit)
		if sprung or not armed then
			return
		end
		local victim = CharacterUtil.playerFromPart(hit)
		if not victim or victim == player or CharacterUtil.isInvulnerable(victim) then
			return
		end
		sprung = true
		SpeedService:Stun(victim, C.trapStunSeconds)
		self.Client.Effect:FireAll("trap", trap.Position, nil)
		BaseService:Notify(victim, `You stepped on {player.DisplayName}'s trap!`, "warn")
		trap:Destroy()
	end)
	return true, "Trap placed"
end

function CombatService.Client:UseSmokeBomb(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if data.gear.SmokeBomb <= 0 then
		return false, "No smoke bombs left"
	end
	local char = player.Character
	if not char or not CharacterUtil.isAlive(player) then
		return false, "Can't right now"
	end
	if onCooldown(player, "SmokeBomb", C.smokeCooldown) then
		return false, "Smoke bomb is on cooldown"
	end
	useCharge(data, "SmokeBomb")
	DataService:Replicate(player)

	char:SetAttribute("InvisibleUntil", os.clock() + C.smokeSeconds)
	local originals: { [Instance]: number } = {}
	for _, d in char:GetDescendants() do
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			originals[d] = (d :: any).Transparency;
			(d :: any).Transparency = 1
		end
	end
	local carriedVisual = char:FindFirstChild("Carried")
	if carriedVisual then
		for _, d in carriedVisual:GetDescendants() do
			if d:IsA("BasePart") then
				originals[d] = d.Transparency
				d.Transparency = 1
			end
		end
	end
	self.Client.Effect:FireAll("smoke", CharacterUtil.position(player) :: Vector3, nil)
	task.delay(C.smokeSeconds, function()
		for inst, t in originals do
			if inst.Parent then
				(inst :: any).Transparency = t
			end
		end
	end)
	return true, "Smoke!"
end

function CombatService.Client:UseGrapple(player: Player, targetUserId: number): (boolean, string)
	local data = DataService:Get(player)
	if not data or not data.gear.Grapple then
		return false, "You don't own Grapple"
	end
	if typeof(targetUserId) ~= "number" then
		return false, "No target"
	end
	local target = playerInRange(player, targetUserId, C.grappleRange)
	if not target then
		return false, "Target out of range"
	end
	if onCooldown(player, "Grapple", C.grappleCooldown) then
		return false, "Grapple is on cooldown"
	end
	local pos = CharacterUtil.position(player) :: Vector3
	CharacterUtil.pullToward(target, pos, C.grappleForce)
	self.Client.Effect:FireAll("grapple", pos, CharacterUtil.position(target))
	return true, `Grappled {target.DisplayName}`
end

function CombatService.Client:UseBodySwap(player: Player, targetUserId: number): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if data.gear.BodySwap <= 0 then
		return false, "No body swaps left"
	end
	if typeof(targetUserId) ~= "number" then
		return false, "No target"
	end
	local target = playerInRange(player, targetUserId, C.bodySwapRange)
	if not target then
		return false, "Target out of range"
	end
	if onCooldown(player, "BodySwap", C.bodySwapCooldown) then
		return false, "Body swap is on cooldown"
	end
	local a = player.Character
	local b = target.Character
	if not a or not b then
		return false, "No character"
	end
	useCharge(data, "BodySwap")
	DataService:Replicate(player)
	local ca = a:GetPivot()
	local cb = b:GetPivot()
	CharacterUtil.teleport(player, cb)
	CharacterUtil.teleport(target, ca)
	self.Client.Effect:FireAll("swap", ca.Position, cb.Position)
	BaseService:Notify(target, `{player.DisplayName} swapped places with you!`, "warn")
	return true, `Swapped with {target.DisplayName}`
end

return CombatService
