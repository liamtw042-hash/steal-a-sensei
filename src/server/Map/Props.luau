--!strict
--[[
	Props: places the dojo kit from ReplicatedStorage.Props.

	Every model in that folder has its pivot at the model's base and no PrimaryPart, so a prop
	is placed with `PivotTo(CFrame.new(groundPosition))` and it stands on the ground.

	Decorative props are anchored, non-collidable and shadowless by default: there are thousands
	of them across eight bases, and the invisible collision walls already do the blocking.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Props = {}

export type PlaceOptions = {
	collide: boolean?, -- default false
	shadow: boolean?, -- default false
	unanchor: boolean?, -- default false (used when the prop is welded to a moving anchor)
	name: string?,
}

local warned: { [string]: boolean } = {}

function Props.folder(): Folder?
	local f = ReplicatedStorage:FindFirstChild("Props")
	return if f and f:IsA("Folder") then f else nil
end

function Props.get(name: string): Model?
	local folder = Props.folder()
	local m = if folder then folder:FindFirstChild(name) else nil
	if m and m:IsA("Model") then
		return m
	end
	if not warned[name] then
		warned[name] = true
		warn(`[Props] ReplicatedStorage.Props.{name} is missing; skipping it`)
	end
	return nil
end

function Props.exists(name: string): boolean
	local folder = Props.folder()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

-- Bounding size of a prop, or nil if it isn't there
function Props.size(name: string): Vector3?
	local m = Props.get(name)
	if not m then
		return nil
	end
	local _, size = m:GetBoundingBox()
	return size
end

-- Clone a prop and stand it on `cframe` (which should sit at ground level).
function Props.place(name: string, cframe: CFrame, parent: Instance, opts: PlaceOptions?): Model?
	local template = Props.get(name)
	if not template then
		return nil
	end
	local o: PlaceOptions = opts or {}
	local model = template:Clone()
	if o.name then
		model.Name = o.name
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = not o.unanchor
			d.CanCollide = o.collide == true
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = o.shadow == true
			if o.unanchor then
				d.Massless = true
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	model.Parent = parent
	model:PivotTo(cframe)
	return model
end

return Props
