--!strict
--[[
	REBIRTH
	=======
	Wipes cash + fighters. Keeps Power, index, gamepasses, punching bag level.
	Gains: cash multiplier, +1 slot, +10s lock, gear unlocks.
]]

export type RebirthReq = { cash: number, fighterRarity: string }

local Requirements: { [number]: RebirthReq } = {
	[1] = { cash = 500_000, fighterRarity = "Rare" },
	[2] = { cash = 2_500_000, fighterRarity = "Rare" },
	[3] = { cash = 10_000_000, fighterRarity = "Epic" },
	[4] = { cash = 50_000_000, fighterRarity = "Epic" },
	[5] = { cash = 250_000_000, fighterRarity = "Legendary" },
	[6] = { cash = 1_000_000_000, fighterRarity = "Legendary" },
	[7] = { cash = 5_000_000_000, fighterRarity = "Legendary" },
	[8] = { cash = 25_000_000_000, fighterRarity = "Legendary" },
	[9] = { cash = 150_000_000_000, fighterRarity = "Legendary" },
	[10] = { cash = 1_000_000_000_000, fighterRarity = "Mythic" },
	[11] = { cash = 5_000_000_000_000, fighterRarity = "Mythic" },
	[12] = { cash = 25_000_000_000_000, fighterRarity = "Mythic" },
	[13] = { cash = 100_000_000_000_000, fighterRarity = "Mythic" },
	[14] = { cash = 500_000_000_000_000, fighterRarity = "Secret" },
	[15] = { cash = 2_500_000_000_000_000, fighterRarity = "Secret" },
	[16] = { cash = 10_000_000_000_000_000, fighterRarity = "Secret" },
}

local Rebirth = {
	MaxRebirths = 16,
	-- cash multiplier = min(1 + rebirths, MaxMultiplier)
	MaxMultiplier = 16,

	-- Requirement to perform rebirth N (index = N). Must own at least one fighter of that rarity or better.
	Requirements = Requirements,

	-- Gear given for free at these rebirth counts (so free players get Slap and Trap)
	GearUnlocks = {
		slapAtRebirth = 1,
		trapUsesPerRebirthFrom = 2, -- from this rebirth onward, each rebirth grants trapUsesPerRebirth
		trapUsesPerRebirth = 5,
	},
}

function Rebirth.multiplier(rebirths: number): number
	return math.min(1 + rebirths, Rebirth.MaxMultiplier)
end

return Rebirth
