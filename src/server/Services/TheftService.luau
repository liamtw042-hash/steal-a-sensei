--!strict
--[[
	TheftService
	============
	Validates "Steal" prompts on placed fighters and alerts the owner.
	The thief then has to carry the fighter home (CarryService handles the rest).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CharacterUtil = require(script.Parent.Parent.Util.CharacterUtil)

local TheftService = Knit.CreateService({
	Name = "TheftService",
	Client = {
		Started = Knit.CreateSignal(), -- to thief: (fighterName, ownerName)
	},
})

local BaseService: any
local CarryService: any
local FighterService: any
local PowerService: any

function TheftService:KnitInit()
	BaseService = Knit.GetService("BaseService")
	CarryService = Knit.GetService("CarryService")
	FighterService = Knit.GetService("FighterService")
	PowerService = Knit.GetService("PowerService")
end

function TheftService:TrySteal(thief: Player, owner: Player, fighterId: string): boolean
	if thief == owner then
		return false
	end
	local base = BaseService:GetBaseOf(owner)
	if not base then
		return false
	end
	if BaseService:IsLocked(base) then
		BaseService:Notify(thief, "That base is locked!", "warn")
		return false
	end
	if BaseService:IsAuthorized(base, thief) then
		BaseService:Notify(thief, "You're on this base's friend list, so you can't steal here.", "warn")
		return false
	end
	if not CarryService:CanCarry(thief) then
		BaseService:Notify(thief, "You're already carrying something!", "warn")
		return false
	end
	if PowerService:IsStunned(thief) or not CharacterUtil.isAlive(thief) then
		return false
	end
	local pos = CharacterUtil.position(thief)
	if not pos or not BaseService:IsInside(base, pos) then
		return false
	end
	local fighter = FighterService:RemoveForTheft(owner, fighterId)
	if not fighter then
		return false
	end
	if not CarryService:PickupFighter(thief, fighter, owner.UserId) then
		-- give it back
		FighterService:ReceiveFighter(owner, fighter, owner.UserId)
		return false
	end
	FighterService.FighterStolen:Fire(owner, thief, fighter)
	BaseService.Client.TheftAlert:Fire(owner, thief.UserId, fighter.name)
	BaseService:Notify(owner, `{thief.DisplayName} is stealing your {fighter.name}!`, "alarm")
	self.Client.Started:Fire(thief, fighter.name, owner.DisplayName)
	return true
end

return TheftService
