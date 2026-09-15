--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local SpeedMath = {}

-- Map the speed stat to a Humanoid.WalkSpeed using the curve in Config.Speed (log10 interpolation)
function SpeedMath.walkSpeedFor(stat: number): number
	local curve = Config.Speed.WalkSpeedCurve
	stat = math.max(0, stat)
	local first = curve[1]
	if stat <= first[1] then
		return first[2]
	end
	for i = 2, #curve do
		local a = curve[i - 1]
		local b = curve[i]
		if stat <= b[1] then
			local la = math.log10(a[1] + 1)
			local lb = math.log10(b[1] + 1)
			local t = (math.log10(stat + 1) - la) / (lb - la)
			return math.min(Config.Speed.MaxWalkSpeed, a[2] + (b[2] - a[2]) * t)
		end
	end
	return math.min(Config.Speed.MaxWalkSpeed, curve[#curve][2])
end

-- Product of all owned speed gamepass multipliers
function SpeedMath.gamepassMultiplier(ownedPasses: { [string]: boolean }): number
	local mult = 1
	for _, p in Config.Speed.MultiplierPasses do
		if ownedPasses[p.key] then
			mult *= p.multiplier
		end
	end
	return math.min(mult, Config.Speed.MaxMultiplier)
end

function SpeedMath.effectiveSpeed(rawStat: number, ownedPasses: { [string]: boolean }): number
	return rawStat * SpeedMath.gamepassMultiplier(ownedPasses)
end

return SpeedMath
