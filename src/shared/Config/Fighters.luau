--!strict
--[[
	FIGHTERS, RARITIES, ECONOMY
	===========================
	Rarity order, cash-per-second by rarity, levelling, evolution, mutations, fusing,
	hatch times and the fighter roster. Add fighters by appending to `Roster`.

	Studio side: ReplicatedStorage.Fighters.<fighter name> (a Model with a PrimaryPart).
	Missing models get a placeholder block, so the game runs without any models at all.
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type FighterDef = {
	name: string, -- unique; also the expected model name
	displayName: string,
	rarity: Rarity,
	zoneId: number, -- which zone's Index set it belongs to
	cashPerSecond: number, -- base cps at level 1, no mutation
	evolvesInto: string?, -- name of fighter it becomes at level 10 (defaults to a random fighter of next rarity)
}

export type MutationDef = { name: string, multiplier: number, chance: number, color: Color3 }

-- Typed as plain strings so lookups by arbitrary saved data don't need casts.
local RarityOrder: { string } = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local RarityColor: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 190, 190),
	Uncommon = Color3.fromRGB(110, 210, 110),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 80, 120),
	Secret = Color3.fromRGB(30, 30, 40),
}

-- Base cash per second per rarity (scales hard). Individual fighters override with their own cps.
-- Tuned so a free player hits rebirth 1 in ~1h, 5 in ~1 day, 10 in ~1 week. See docs/ECONOMY.md.
local RarityCashPerSecond: { [string]: number } = {
	Common = 25,
	Uncommon = 120,
	Rare = 600,
	Epic = 3_000,
	Legendary = 40_000,
	Mythic = 250_000,
	Secret = 1_500_000,
}

-- Seconds for a scroll of this rarity to hatch once placed in a base slot.
local HatchSeconds: { [string]: number } = {
	Common = 20,
	Uncommon = 40,
	Rare = 75,
	Epic = 150,
	Legendary = 300,
	Mythic = 480,
	Secret = 720,
}

-- Mutations rolled on hatch. Chances are independent percentages checked from rarest to most common.
local Mutations: { MutationDef } = {
	{ name = "Void", multiplier = 5, chance = 0.5, color = Color3.fromRGB(60, 0, 90) },
	{ name = "Golden", multiplier = 3, chance = 2, color = Color3.fromRGB(255, 215, 0) },
	{ name = "Shadow", multiplier = 2, chance = 5, color = Color3.fromRGB(40, 40, 40) },
	{ name = "Shiny", multiplier = 1.5, chance = 10, color = Color3.fromRGB(200, 255, 255) },
}

local Levelling = {
	maxLevel = 10,
	xpPerMinutePlaced = 20, -- level 10 (evolution) after ~2 hours placed
	cashBonusPerLevel = 0.10, -- +10% per level above 1
	-- XP needed to go from level L to L+1
	xpToNext = function(level: number): number
		return math.floor(60 * (1.35 ^ (level - 1)))
	end,
}

local Fuse = {
	required = 3, -- three identical fighters -> one of the next rarity
}

-- Minimum roster: two per rarity. Add more freely.
local Roster: { FighterDef } = {
	-- Common (zone 1)
	{ name = "Dojo Novice", displayName = "Dojo Novice", rarity = "Common", zoneId = 1, cashPerSecond = 25 },
	{ name = "Straw Hat Kid", displayName = "Straw Hat Kid", rarity = "Common", zoneId = 1, cashPerSecond = 30 },
	-- Uncommon (zones 2 / 3)
	{ name = "Bamboo Striker", displayName = "Bamboo Striker", rarity = "Uncommon", zoneId = 2, cashPerSecond = 120 },
	{ name = "Shadow Scout", displayName = "Shadow Scout", rarity = "Uncommon", zoneId = 3, cashPerSecond = 140 },
	-- Rare (zones 4 / 5)
	{ name = "Storm Caller", displayName = "Storm Caller", rarity = "Rare", zoneId = 4, cashPerSecond = 600 },
	{ name = "Frost Blade", displayName = "Frost Blade", rarity = "Rare", zoneId = 5, cashPerSecond = 700 },
	-- Epic (zones 6 / 7)
	{ name = "Ember Fist", displayName = "Ember Fist", rarity = "Epic", zoneId = 6, cashPerSecond = 3_000 },
	{ name = "Tide Breaker", displayName = "Tide Breaker", rarity = "Epic", zoneId = 7, cashPerSecond = 3_500 },
	-- Legendary (zones 8 / 9)
	{ name = "Ruin Colossus", displayName = "Ruin Colossus", rarity = "Legendary", zoneId = 8, cashPerSecond = 40_000 },
	{
		name = "Celestial Blade",
		displayName = "Celestial Blade",
		rarity = "Legendary",
		zoneId = 9,
		cashPerSecond = 48_000,
	},
	-- Mythic (zone 10)
	{ name = "Sakura Reaper", displayName = "Sakura Reaper", rarity = "Mythic", zoneId = 10, cashPerSecond = 250_000 },
	{ name = "Void Dancer", displayName = "Void Dancer", rarity = "Mythic", zoneId = 10, cashPerSecond = 300_000 },
	-- Secret (zone 10)
	{
		name = "The First Sensei",
		displayName = "The First Sensei",
		rarity = "Secret",
		zoneId = 10,
		cashPerSecond = 1_500_000,
	},
	{
		name = "Eclipse Ronin",
		displayName = "Eclipse Ronin",
		rarity = "Secret",
		zoneId = 10,
		cashPerSecond = 2_000_000,
	},
}

-- Reward for completing a zone's Index set (every fighter with that zoneId hatched at least once).
local IndexRewards: { [number]: { speed: number, cash: number, skin: string } } = {
	[1] = { speed = 2_000, cash = 50_000, skin = "Novice Headband" },
	[2] = { speed = 15_000, cash = 500_000, skin = "Bamboo Cloak" },
	[3] = { speed = 120_000, cash = 5_000_000, skin = "Shadow Mask" },
	[4] = { speed = 1_200_000, cash = 50_000_000, skin = "Storm Aura" },
	[5] = { speed = 12_000_000, cash = 500_000_000, skin = "Frost Trail" },
	[6] = { speed = 120_000_000, cash = 5_000_000_000, skin = "Ember Wings" },
	[7] = { speed = 1_200_000_000, cash = 50_000_000_000, skin = "Abyss Crown" },
	[8] = { speed = 12_000_000_000, cash = 500_000_000_000, skin = "Golem Armour" },
	[9] = { speed = 120_000_000_000, cash = 5_000_000_000_000, skin = "Celestial Halo" },
	[10] = { speed = 1_200_000_000_000, cash = 50_000_000_000_000, skin = "Sakura Void Form" },
}

local Fighters = {
	RarityOrder = RarityOrder,
	RarityColor = RarityColor,
	RarityCashPerSecond = RarityCashPerSecond,
	HatchSeconds = HatchSeconds,
	Mutations = Mutations,
	Levelling = Levelling,
	Fuse = Fuse,
	Roster = Roster,
	IndexRewards = IndexRewards,
}

local byName: { [string]: FighterDef } = {}
local byRarity: { [string]: { FighterDef } } = {}
for _, def in Roster do
	byName[def.name] = def
	local list = byRarity[def.rarity]
	if not list then
		list = {}
		byRarity[def.rarity] = list
	end
	table.insert(list, def)
end

function Fighters.get(name: string): FighterDef?
	return byName[name]
end

function Fighters.ofRarity(rarity: string): { FighterDef }
	return byRarity[rarity] or {}
end

function Fighters.ofZone(zoneId: number): { FighterDef }
	local out = {}
	for _, def in Roster do
		if def.zoneId == zoneId then
			table.insert(out, def)
		end
	end
	return out
end

function Fighters.rarityIndex(rarity: string): number
	return table.find(RarityOrder, rarity) or 1
end

function Fighters.nextRarity(rarity: string): string?
	local i = Fighters.rarityIndex(rarity)
	return RarityOrder[i + 1]
end

function Fighters.mutation(name: string?): MutationDef?
	if not name then
		return nil
	end
	for _, m in Mutations do
		if m.name == name then
			return m
		end
	end
	return nil
end

return Fighters
