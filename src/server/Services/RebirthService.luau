--!strict
--[[
	RebirthService
	==============
	Wipes cash + fighters for permanent multipliers, slots, lock time and gear.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local RebirthService = Knit.CreateService({
	Name = "RebirthService",
	Client = {
		Rebirthed = Knit.CreateSignal(), -- (newCount)
	},
})

local DataService: any
local FighterService: any
local CarryService: any
local BaseService: any
local PowerService: any

function RebirthService:KnitInit()
	DataService = Knit.GetService("DataService")
	FighterService = Knit.GetService("FighterService")
	CarryService = Knit.GetService("CarryService")
	BaseService = Knit.GetService("BaseService")
	PowerService = Knit.GetService("PowerService")
end

function RebirthService:CanRebirth(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local nextN = data.rebirths + 1
	if nextN > Config.Rebirth.MaxRebirths then
		return false, "Max rebirths reached"
	end
	local req = Config.Rebirth.Requirements[nextN]
	if not req then
		return false, "No requirement configured"
	end
	if data.cash < req.cash then
		return false, `Need {Format.cash(req.cash)} (you have {Format.cash(data.cash)})`
	end
	if not FighterService:HasFighterOfRarity(player, req.fighterRarity) then
		return false, `Need a {req.fighterRarity} or better fighter`
	end
	return true, "Ready"
end

function RebirthService:DoRebirth(player: Player): (boolean, string)
	local ok, why = self:CanRebirth(player)
	if not ok then
		return false, why
	end
	local data = DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local newCount = data.rebirths + 1

	-- wipe
	CarryService:Remove(player)
	CarryService:PurgeOwner(player.UserId)
	FighterService:WipeForRebirth(player)
	DataService:SetCash(player, 0)

	-- gains
	DataService:SetRebirths(player, newCount)
	local G = Config.Rebirth.GearUnlocks
	if newCount >= G.slapAtRebirth then
		data.gear.Slap = true
	end
	if newCount >= G.trapUsesPerRebirthFrom then
		data.gear.Trap += G.trapUsesPerRebirth
	end

	DataService:Replicate(player)
	BaseService:RefreshAttributes(player)
	PowerService:Refresh(player)
	self.Client.Rebirthed:Fire(player, newCount)
	BaseService:Notify(player, `Rebirth {newCount}! Cash x{Config.Rebirth.multiplier(newCount)}`, "info")
	return true, `Rebirth {newCount}`
end

function RebirthService.Client:CanRebirth(player: Player): (boolean, string)
	return self.Server:CanRebirth(player)
end

function RebirthService.Client:Rebirth(player: Player): (boolean, string)
	return self.Server:DoRebirth(player)
end

return RebirthService
