--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local PowerMath = {}

-- Map the Power stat to a Humanoid.WalkSpeed using the curve in Config.Power (log10 interpolation)
function PowerMath.walkSpeedFor(power: number): number
	local curve = Config.Power.WalkSpeedCurve
	power = math.max(0, power)
	local first = curve[1]
	if power <= first[1] then
		return first[2]
	end
	for i = 2, #curve do
		local a = curve[i - 1]
		local b = curve[i]
		if power <= b[1] then
			local la = math.log10(a[1] + 1)
			local lb = math.log10(b[1] + 1)
			local t = (math.log10(power + 1) - la) / (lb - la)
			return math.min(Config.Power.MaxWalkSpeed, a[2] + (b[2] - a[2]) * t)
		end
	end
	return math.min(Config.Power.MaxWalkSpeed, curve[#curve][2])
end

-- Product of all owned Power gamepass multipliers, capped at Config.Power.MaxMultiplier
function PowerMath.gamepassMultiplier(ownedPasses: { [string]: boolean }): number
	local mult = 1
	for _, p in Config.Power.MultiplierPasses do
		if ownedPasses[p.key] then
			mult *= p.multiplier
		end
	end
	return math.min(mult, Config.Power.MaxMultiplier)
end

function PowerMath.effectivePower(rawStat: number, ownedPasses: { [string]: boolean }): number
	return rawStat * PowerMath.gamepassMultiplier(ownedPasses)
end

return PowerMath
