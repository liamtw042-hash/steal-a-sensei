--!strict
-- Weighted random pick and percentage chance helpers
local Weighted = {}

local rng = Random.new()

function Weighted.pick<T>(list: { T }, weightOf: (T) -> number): T
	local total = 0
	for _, item in list do
		total += weightOf(item)
	end
	local r = rng:NextNumber() * total
	for _, item in list do
		r -= weightOf(item)
		if r <= 0 then
			return item
		end
	end
	return list[#list]
end

function Weighted.chance(percent: number): boolean
	return rng:NextNumber() * 100 < percent
end

function Weighted.random(): Random
	return rng
end

return Weighted
