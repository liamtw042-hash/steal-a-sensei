--!strict
-- Point-in-part tests for zone bounds and base regions (box test in the part's local space)
local Region = {}

function Region.isPointInPart(part: BasePart, point: Vector3, padding: number?): boolean
	local pad = padding or 0
	local rel = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X + pad and math.abs(rel.Y) <= half.Y + pad and math.abs(rel.Z) <= half.Z + pad
end

function Region.randomPointInPart(part: BasePart, rng: Random): Vector3
	local half = part.Size / 2
	local localPoint = Vector3.new(rng:NextNumber(-half.X, half.X), 0, rng:NextNumber(-half.Z, half.Z))
	return part.CFrame:PointToWorldSpace(localPoint)
end

-- Top surface centre of a part (useful for placing things on pads)
function Region.top(part: BasePart, lift: number?): Vector3
	return part.Position + Vector3.new(0, part.Size.Y / 2 + (lift or 0), 0)
end

return Region
