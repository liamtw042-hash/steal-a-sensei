--!strict
--[[
	TrainingProp: the thing you punch in your base, swapped in place as the bag upgrades.

	  Lv 1 TrainingPost_L1   Lv 2 WoodenDummy_L2   Lv 3 IronPost_L3
	  Lv 4 MonkStatue_L4     Lv 5 DragonPost_L5

	The `PunchingBag` part is an invisible anchor sized to whatever prop is currently on it:
	PowerService reads it for range and swings it on each punch, and the prop's parts are
	unanchored and welded to it so the whole thing rocks together. Swapping levels rebuilds
	the visual on the same anchor, so nothing else has to know a swap happened.
]]
local Props = require(script.Parent.Props)

local TrainingProp = {}

local NAMES = { "TrainingPost_L1", "WoodenDummy_L2", "IronPost_L3", "MonkStatue_L4", "DragonPost_L5" }

local VISUAL = "TrainingVisual"

function TrainingProp.nameFor(level: number): string
	return NAMES[math.clamp(level, 1, #NAMES)]
end

-- Rebuild the visual standing on `anchor` for this bag level, and resize the anchor to match.
-- `anchor` keeps its base on the ground, so the prop always stands on the floor.
function TrainingProp.apply(anchor: BasePart, level: number)
	local name = TrainingProp.nameFor(level)
	if anchor:GetAttribute("TrainingProp") == name and anchor.Parent then
		local existing = anchor.Parent:FindFirstChild(VISUAL)
		if existing then
			return -- already showing the right prop
		end
	end

	local parent = anchor.Parent
	if not parent then
		return
	end
	local old = parent:FindFirstChild(VISUAL)
	if old then
		old:Destroy()
	end

	-- keep the anchor's base where it is while its height changes
	local baseY = anchor.Position.Y - anchor.Size.Y / 2
	local size = Props.size(name)
	if size then
		anchor.Size = Vector3.new(math.max(size.X, 1.5), size.Y, math.max(size.Z, 1.5))
	end
	anchor.CFrame = CFrame.new(anchor.Position.X, baseY + anchor.Size.Y / 2, anchor.Position.Z)
	anchor:SetAttribute("TrainingProp", name)

	local model = Props.place(name, CFrame.new(anchor.Position.X, baseY, anchor.Position.Z), parent, {
		unanchor = true,
		shadow = true,
		name = VISUAL,
	})
	if not model then
		return
	end
	-- weld every part to the anchor so tweening the anchor swings the whole prop
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = d
			weld.Parent = d
		end
	end
end

return TrainingProp
