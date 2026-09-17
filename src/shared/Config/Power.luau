--!strict
--[[
	POWER SYSTEM
	============
	"Power" is the core progression stat (a big number). WalkSpeedCurve maps it to the
	character's real WalkSpeed, so more Power also means you outrun bosses. Sources of
	Power: free rewards, the punching bag in your base, index rewards, events.
	Gamepasses multiply the stat.
]]

local Power = {
	-- { powerStat, walkSpeed } breakpoints; interpolated in log10 space. Beyond the last point it's capped.
	WalkSpeedCurve = {
		{ 0, 16 },
		{ 5_000, 22 },
		{ 50_000, 28 },
		{ 500_000, 34 },
		{ 5_000_000, 40 },
		{ 50_000_000, 46 },
		{ 500_000_000, 52 },
		{ 5_000_000_000, 58 },
		{ 50_000_000_000, 64 },
		{ 500_000_000_000, 70 },
		{ 5_000_000_000_000, 76 },
	},
	MaxWalkSpeed = 80,

	-- Free rewards (total 10,000 Power). Like/favourite can't be verified by Roblox APIs,
	-- so they're honour-system with a delay.
	FreeRewards = {
		like = { power = 3_000, label = "Like the game" },
		favourite = { power = 3_000, label = "Favourite the game" },
		group = { power = 4_000, label = "Join the group" },
		groupId = 0, -- <- paste your Roblox group id here (0 = no group check, always succeeds)
		honourDelaySeconds = 5, -- how long the like/favourite button "checks" before paying out
	},

	--[[
		Punching bag: walk up to the bag in your base, hold E (tap and hold on mobile) and
		you gain Power every `tickSeconds`. Five levels, bought with cash. See docs/ECONOMY.md.

		Level | Power per punch | cost to reach
		    1 |              25 | free
		    2 |           1,000 | $5K
		    3 |          40,000 | $500K
		    4 |       1,600,000 | $50M
		    5 |      64,000,000 | $10B
	]]
	PunchingBag = {
		maxLevel = 5,
		tickSeconds = 1, -- one punch per second while held
		range = 14, -- studs; the server stops training if you walk further than this from the bag
		-- Power granted per punch at each level
		powerPerPunch = { 25, 1_000, 40_000, 1_600_000, 64_000_000 },
		-- Cash cost to go from level N to N+1 (index N)
		upgradeCost = { 5_000, 500_000, 50_000_000, 10_000_000_000 },
	},

	-- Multiplicative Power gamepasses. `key` matches Config.Monetization.Gamepasses.
	-- The product of every owned pass is CAPPED at MaxMultiplier (1024x). Owning 2x+4x+8x+16x already
	-- reaches the cap, so the higher passes only matter if you skipped lower ones. Documented in
	-- docs/DASHBOARD.md; consider making them additive if you want every pass to be worth buying.
	MaxMultiplier = 1024,
	MultiplierPasses = {
		{ key = "Power2x", multiplier = 2 },
		{ key = "Power4x", multiplier = 4 },
		{ key = "Power8x", multiplier = 8 },
		{ key = "Power16x", multiplier = 16 },
		{ key = "Power32x", multiplier = 32 },
		{ key = "Power64x", multiplier = 64 },
		{ key = "Power128x", multiplier = 128 },
		{ key = "Power256x", multiplier = 256 },
		{ key = "Power512x", multiplier = 512 },
		{ key = "Power1024x", multiplier = 1024 },
	},

	-- Movement modifiers used by other systems (these are WalkSpeed multipliers, not Power)
	Modifiers = {
		carryingFighter = 0.70, -- thief slowed 30%
	},
}

-- Power gained per punch at a bag level (clamped to the table)
function Power.punchPower(level: number): number
	local list = Power.PunchingBag.powerPerPunch
	return list[math.clamp(level, 1, #list)]
end

-- Cash cost to upgrade from `level` to `level + 1`, or nil at max level
function Power.bagUpgradeCost(level: number): number?
	return Power.PunchingBag.upgradeCost[level]
end

return Power
