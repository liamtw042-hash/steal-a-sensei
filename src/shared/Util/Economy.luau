--!strict
-- Cash maths shared by server (actual income) and client (HUD preview).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)

local Economy = {}

-- Cash per second for one fighter (level + mutation, no player multipliers)
function Economy.fighterCps(fighter: Types.Fighter): number
	local def = Config.Fighters.get(fighter.name)
	local base = if def then def.cashPerSecond else Rarity.baseCps(fighter.rarity)
	local levelMult = 1 + Config.Fighters.Levelling.cashBonusPerLevel * (fighter.level - 1)
	local mut = Config.Fighters.mutation(fighter.mutation)
	local mutMult = if mut then mut.multiplier else 1
	return base * levelMult * mutMult
end

function Economy.playerMultiplier(data: Types.PlayerData): number
	local m = Config.Rebirth.multiplier(data.rebirths)
	if data.gamepasses.VIP then
		m *= Config.Base.Earning.vipCashMultiplier
	end
	return m
end

-- Total income per second from placed fighters, with rebirth + VIP multipliers
function Economy.incomePerSecond(data: Types.PlayerData): number
	local total = 0
	for _, f in data.fighters do
		if f.slot then
			total += Economy.fighterCps(f)
		end
	end
	return total * Economy.playerMultiplier(data)
end

return Economy
