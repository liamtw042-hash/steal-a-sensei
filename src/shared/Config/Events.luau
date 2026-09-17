--!strict
--[[
	EVENTS
	======
	Studio side (optional): Workspace.Map.RiftSpawn (Part), Workspace.Map.HungrySenseiSpawn (Part).
	If missing, events use Workspace.Map.Spawn.
]]

export type TokenItem = { key: string, name: string, cost: number, description: string }

local TokenShop: { TokenItem } = {
	{ key = "PowerSmall", name = "+50K Power", cost = 10, description = "Permanent +50,000 Power." },
	{ key = "PowerLarge", name = "+5M Power", cost = 60, description = "Permanent +5,000,000 Power." },
	{ key = "CashPack", name = "Cash Pack", cost = 15, description = "Cash equal to 10 minutes of your income." },
	{ key = "RareScroll", name = "Rare Scroll", cost = 40, description = "A Rare scroll straight into your base." },
	{ key = "EpicScroll", name = "Epic Scroll", cost = 120, description = "An Epic scroll straight into your base." },
}

local Events = {
	Rift = {
		intervalSeconds = 30 * 60,
		firstAfterSeconds = 5 * 60,
		durationSeconds = 3 * 60,
		baseHealth = 400, -- plus healthPerPlayer per player in the server
		healthPerPlayer = 400,
		attackRange = 14,
		attackCooldown = 0.45,
		attackDamage = 1, -- + rebirths
		slapDamage = 8, -- Slap owners hit harder
		shockwaveIntervalSeconds = 6, -- boss knocks nearby players back
		shockwaveRadius = 12,
		shockwaveForce = 60,
		tokensBase = 25, -- everyone who dealt damage gets this
		tokensPool = 200, -- split by damage share
		walkSpeed = 10,
	},
	VoidSurge = {
		intervalSeconds = 20 * 60,
		firstAfterSeconds = 8 * 60,
		durationSeconds = 2 * 60,
		zoneId = 10,
		scrollMultiplier = 3,
	},
	HungrySensei = {
		intervalSeconds = 45 * 60,
		firstAfterSeconds = 15 * 60,
		walkSpeed = 24,
		eatDelaySeconds = 3,
		maxDurationSeconds = 4 * 60,
		warningSeconds = 20, -- heads-up before it spawns
	},
	TokenShop = TokenShop,
	TokenShopValues = {
		PowerSmall = 50_000,
		PowerLarge = 5_000_000,
		CashPackMinutes = 10,
	},
}

function Events.tokenItem(key: string): TokenItem?
	for _, it in TokenShop do
		if it.key == key then
			return it
		end
	end
	return nil
end

return Events
