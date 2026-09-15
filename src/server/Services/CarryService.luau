--!strict
--[[
	CarryService
	============
	A player carries at most one thing: a scroll (from a zone) or a fighter (stolen).
	Handles the attached visual, dropping (boss catch, slap, death, leaving) and
	securing (walking into your own base region).
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)
local Models = require(script.Parent.Parent.Util.Models)

type Carried = Types.Carried

local CarryService = Knit.CreateService({
	Name = "CarryService",
	Client = {
		Changed = Knit.CreateSignal(), -- (carriedOrNil) to the carrier
	},
	PickedUp = Signal.new(), -- (player, carried)
	Dropped = Signal.new(), -- (player, carried, position, reason)
	Secured = Signal.new(), -- (player, carried, base)
})

local DataService: any
local SpeedService: any
local BaseService: any
local ZoneService: any
local FighterService: any

local carried: { [Player]: Carried } = {}
local visuals: { [Player]: Model } = {}

function CarryService:KnitInit()
	DataService = Knit.GetService("DataService")
	SpeedService = Knit.GetService("SpeedService")
	BaseService = Knit.GetService("BaseService")
	ZoneService = Knit.GetService("ZoneService")
	FighterService = Knit.GetService("FighterService")
end

function CarryService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		if carried[player] then
			self:Drop(player, CharacterUtil.position(player), "left")
		end
	end)
	DataService.Loaded:Connect(function(player: Player)
		local function onCharacter(char: Model)
			local humanoid = char:WaitForChild("Humanoid", 5)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					if carried[player] then
						self:Drop(player, CharacterUtil.position(player), "died")
					end
				end)
			end
		end
		if player.Character then
			onCharacter(player.Character)
		end
		player.CharacterAdded:Connect(onCharacter)
	end)

	-- secure check
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, item in carried do
				local pos = CharacterUtil.position(player)
				if not pos then
					continue
				end
				local base = BaseService:GetBaseOf(player)
				if base and BaseService:IsInside(base, pos) then
					self:Secure(player, base)
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------

function CarryService:Get(player: Player): Carried?
	return carried[player]
end

function CarryService:IsCarryingScroll(player: Player): boolean
	local c = carried[player]
	return c ~= nil and c.kind == "scroll"
end

function CarryService:CanCarry(player: Player): boolean
	return carried[player] == nil and CharacterUtil.isAlive(player) and DataService:IsLoaded(player)
end

function CarryService:_setAttributes(player: Player, item: Carried?)
	local char = player.Character
	if not char then
		return
	end
	if not item then
		char:SetAttribute("Carrying", nil)
		char:SetAttribute("CarryRarity", nil)
		char:SetAttribute("CarryName", nil)
		char:SetAttribute("CarryZone", nil)
	elseif item.kind == "scroll" then
		char:SetAttribute("Carrying", "scroll")
		char:SetAttribute("CarryRarity", item.rarity)
		char:SetAttribute("CarryName", `{item.rarity} Scroll`)
		char:SetAttribute("CarryZone", item.zoneId)
	else
		char:SetAttribute("Carrying", "fighter")
		char:SetAttribute("CarryRarity", item.fighter.rarity)
		char:SetAttribute("CarryName", item.fighter.name)
		char:SetAttribute("CarryZone", nil)
	end
end

function CarryService:_attachVisual(player: Player, item: Carried)
	self:_removeVisual(player)
	local root = CharacterUtil.root(player)
	if not root then
		return
	end
	local model: Model
	if item.kind == "scroll" then
		model = Models.scroll(item.rarity)
		Models.attachToCharacter(model, root, CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, 0))
	else
		model = Models.fighter(item.fighter, false)
		pcall(function()
			model:ScaleTo(0.45)
		end)
		Models.attachToCharacter(model, root, CFrame.new(0, 3.8, 0))
	end
	model.Name = "Carried"
	visuals[player] = model
end

function CarryService:_removeVisual(player: Player)
	local v = visuals[player]
	if v then
		v:Destroy()
		visuals[player] = nil
	end
end

function CarryService:_clientInfo(item: Carried?): any
	if not item then
		return nil
	end
	if item.kind == "scroll" then
		return { kind = "scroll", rarity = item.rarity, zoneId = item.zoneId }
	end
	return {
		kind = "fighter",
		rarity = item.fighter.rarity,
		name = item.fighter.name,
		level = item.fighter.level,
		originalOwner = item.originalOwner,
	}
end

function CarryService:PickupScroll(player: Player, scroll: Types.CarriedScroll): boolean
	if not self:CanCarry(player) then
		return false
	end
	carried[player] = scroll
	self:_attachVisual(player, scroll)
	self:_setAttributes(player, scroll)
	self.Client.Changed:Fire(player, self:_clientInfo(scroll))
	self.PickedUp:Fire(player, scroll)
	return true
end

function CarryService:PickupFighter(player: Player, fighter: Types.Fighter, originalOwner: number): boolean
	if not self:CanCarry(player) then
		return false
	end
	local item: Types.CarriedFighter = {
		kind = "fighter",
		fighter = fighter,
		originalOwner = originalOwner,
		uid = HttpService:GenerateGUID(false),
	}
	carried[player] = item
	self:_attachVisual(player, item)
	self:_setAttributes(player, item)
	SpeedService:AddModifier(player, "carryFighter", Config.Speed.Modifiers.carryingFighter)
	self.Client.Changed:Fire(player, self:_clientInfo(item))
	self.PickedUp:Fire(player, item)
	return true
end

function CarryService:_clear(player: Player): Carried?
	local item = carried[player]
	if not item then
		return nil
	end
	carried[player] = nil
	self:_removeVisual(player)
	self:_setAttributes(player, nil)
	SpeedService:RemoveModifier(player, "carryFighter")
	self.Client.Changed:Fire(player, nil)
	return item
end

-- Drop whatever is carried at `position` (or where the player is). Anyone can grab it after.
function CarryService:Drop(player: Player, position: Vector3?, reason: string?)
	local item = self:_clear(player)
	if not item then
		return
	end
	local pos = position or CharacterUtil.position(player) or CharacterUtil.spawnCFrame().Position
	if item.kind == "scroll" then
		ZoneService:SpawnDroppedScroll(pos, item.rarity, item.zoneId)
	else
		FighterService:SpawnLoosePickup(item.fighter, item.originalOwner, pos)
	end
	self.Dropped:Fire(player, item, pos, reason or "dropped")
end

-- Remove the carried item without dropping it (rebirth purge etc.)
function CarryService:Remove(player: Player): Carried?
	return self:_clear(player)
end

function CarryService:Secure(player: Player, base: any)
	local item = self:_clear(player)
	if not item then
		return
	end
	if item.kind == "scroll" then
		FighterService:ReceiveScroll(player, item.rarity, item.zoneId)
		local data = DataService:Get(player)
		if data then
			data.stats.scrollsSecured += 1
		end
	else
		FighterService:ReceiveFighter(player, item.fighter, item.originalOwner)
	end
	self.Secured:Fire(player, item, base)
end

-- When a player rebirths, any of their fighters mid-theft vanish (carried or on the ground)
function CarryService:PurgeOwner(userId: number)
	for player, item in carried do
		if item.kind == "fighter" and item.originalOwner == userId then
			self:_clear(player)
			BaseService:Notify(player, "The fighter you were carrying vanished (its owner rebirthed).")
		end
	end
	FighterService:PurgeLoose(userId)
end

return CarryService
