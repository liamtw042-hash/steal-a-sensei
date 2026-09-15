--!strict
--[[
	SPEED SYSTEM
	============
	"Speed" is the core progression stat (a big number). WalkSpeedCurve maps it to
	the character's real WalkSpeed. Sources of speed: free rewards, treadmill (AFK),
	index rewards, events. Gamepasses multiply the stat.
]]

local Speed = {
	-- { stat, walkSpeed } breakpoints; interpolated in log10 space. Beyond the last point it's capped.
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

	-- Free rewards (total 10,000). Like/favourite can't be verified by Roblox APIs, so they're honour-system with a delay.
	FreeRewards = {
		like = { speed = 3_000, label = "Like the game" },
		favourite = { speed = 3_000, label = "Favourite the game" },
		group = { speed = 4_000, label = "Join the group" },
		groupId = 0, -- <- paste your Roblox group id here (0 = no group check, always succeeds)
		honourDelaySeconds = 5, -- how long the like/favourite button "checks" before paying out
	},

	-- Treadmill: stand on Workspace.Bases.BaseN.Treadmill to gain speed every second.
	Treadmill = {
		maxLevel = 40,
		-- see docs/ECONOMY.md for the table these produce
		ratePerSecond = function(level: number): number
			return math.floor(25 * (1.55 ^ (level - 1)))
		end,
		upgradeCost = function(level: number): number -- cost to go from `level` to `level + 1`
			return math.floor(1000 * (1.9 ^ (level - 1)))
		end,
	},

	-- Multiplicative speed gamepasses. `key` matches Config.Monetization.Gamepasses.
	-- The product of every owned pass is CAPPED at MaxMultiplier (1024x). Owning 2x+4x+8x+16x already
	-- reaches the cap, so the higher passes only matter if you skipped lower ones. Documented in
	-- docs/DASHBOARD.md; consider making them additive if you want every pass to be worth buying.
	MaxMultiplier = 1024,
	MultiplierPasses = {
		{ key = "Speed2x", multiplier = 2 },
		{ key = "Speed4x", multiplier = 4 },
		{ key = "Speed8x", multiplier = 8 },
		{ key = "Speed16x", multiplier = 16 },
		{ key = "Speed32x", multiplier = 32 },
		{ key = "Speed64x", multiplier = 64 },
		{ key = "Speed128x", multiplier = 128 },
		{ key = "Speed256x", multiplier = 256 },
		{ key = "Speed512x", multiplier = 512 },
		{ key = "Speed1024x", multiplier = 1024 },
	},

	-- Movement modifiers used by other systems
	Modifiers = {
		carryingFighter = 0.70, -- thief slowed 30%
	},
}

return Speed
