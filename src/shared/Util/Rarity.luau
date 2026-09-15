--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Fighters = Config.Fighters

local Rarity = {}

function Rarity.color(rarity: string): Color3
	return Fighters.RarityColor[rarity] or Color3.new(1, 1, 1)
end

function Rarity.index(rarity: string): number
	return table.find(Fighters.RarityOrder, rarity) or 1
end

function Rarity.atLeast(rarity: string, minimum: string): boolean
	return Rarity.index(rarity) >= Rarity.index(minimum)
end

function Rarity.hatchSeconds(rarity: string): number
	return Fighters.HatchSeconds[rarity] or 60
end

function Rarity.baseCps(rarity: string): number
	return Fighters.RarityCashPerSecond[rarity] or 1
end

return Rarity
