--!strict
--[[
	Bases: eight dojo plots built from the prop kit in ReplicatedStorage.Props.

	  Floor      DojoFloorTile, edge to edge
	  Walls      WallSegment around the perimeter, with a gap at the entrance
	  Entrance   BaseGate in the gap; the laser beams sit inside it when locked
	  Lock pad   LockPad
	  Slots      DisplayPad per slot, in rows
	  Training   TrainingPost_L1 .. DragonPost_L5, swapped in place as the bag upgrades

	The props are decoration. Every part the rest of the code looks up by name still exists,
	as an invisible marker where the visual is a multi-part model:

	  Region, Entrance, Gate (in Gates), Lasers, LockPad, PunchingBag, Spawn, Sign,
	  Slots/Slot1..N (each with a `Floor` attribute)

	If a prop is missing from ReplicatedStorage.Props the base still builds; it just loses
	that piece of decoration.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.Layout)
local Props = require(script.Parent.Props)
local TrainingProp = require(script.Parent.TrainingProp)

local Bases = {}

local PlotColors = {
	Color3.fromRGB(255, 110, 110),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(255, 230, 90),
	Color3.fromRGB(120, 230, 120),
	Color3.fromRGB(90, 210, 255),
	Color3.fromRGB(150, 130, 255),
	Color3.fromRGB(255, 130, 220),
	Color3.fromRGB(255, 255, 255),
}

local TILE = 4 -- DojoFloorTile footprint
local TILE_LIFT = 0.05 -- keeps the tiles off the terrain so their undersides do not z-fight
local FLOOR_TOP = 0.26 + TILE_LIFT -- tile top: props inside the dojo stand this high
local GATE_WIDTH = 6.16 -- BaseGate footprint; the wall gap matches it

-- Smooth terrain renders its surface a couple of studs above the nominal fill height, so measure
-- the real ground under each plot and build on that; without it the floor tiles end up buried.
-- DevMap waits for the terrain to become queryable before any of this runs.
local function groundAt(x: number, z: number, ignore: Instance): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(Vector3.new(x, Layout.G + 60, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else Layout.G
end

local function invisibleWall(size: Vector3, cf: CFrame, parent: Instance)
	Build.part(
		{ Size = size, CFrame = cf, Transparency = 1, CanCollide = true, CanQuery = false, Name = "Wall" },
		parent
	)
end

-- An invisible marker part: the thing the code looks up, sitting where the prop is
local function marker(name: string, size: Vector3, position: Vector3, parent: Instance, canTouch: boolean?): Part
	return Build.part({
		Name = name,
		Size = size,
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = canTouch == true,
	}, parent)
end

--------------------------------------------------------------------------------

function Bases.build(parent: Folder, index: number)
	local w, d = Layout.BASE_W, Layout.BASE_D
	local hw, hd = w / 2, d / 2
	local cx = Layout.baseX(index)
	local cz = Layout.BASE_Z
	local center = Vector3.new(cx, groundAt(cx, cz, parent), cz)
	local color = PlotColors[((index - 1) % #PlotColors) + 1]
	local bf = Build.folder("Base" .. index, parent)
	local deco = Build.folder("Deco", bf)

	--------------------------------------------------------------------------
	-- Region + invisible collision walls (gap at the entrance)
	--------------------------------------------------------------------------
	Build.part({
		Name = "Region",
		Size = Vector3.new(w, 26, d),
		Position = center + Vector3.new(0, 13, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, bf)

	local halfGap = GATE_WIDTH / 2
	local frontRun = (w - GATE_WIDTH) / 2
	invisibleWall(Vector3.new(1, 14, d), CFrame.new(center + Vector3.new(-hw, 7, 0)), bf)
	invisibleWall(Vector3.new(1, 14, d), CFrame.new(center + Vector3.new(hw, 7, 0)), bf)
	invisibleWall(Vector3.new(w, 14, 1), CFrame.new(center + Vector3.new(0, 7, -hd)), bf)
	invisibleWall(Vector3.new(frontRun, 14, 1), CFrame.new(center + Vector3.new(-(halfGap + frontRun / 2), 7, hd)), bf)
	invisibleWall(Vector3.new(frontRun, 14, 1), CFrame.new(center + Vector3.new(halfGap + frontRun / 2, 7, hd)), bf)

	--------------------------------------------------------------------------
	-- Floor: DojoFloorTile edge to edge
	--------------------------------------------------------------------------
	local floor = Build.folder("Floor", deco)
	local tiles = math.floor(w / TILE)
	local first = -(tiles - 1) * TILE / 2
	for ix = 0, tiles - 1 do
		for iz = 0, tiles - 1 do
			local pos = center + Vector3.new(first + ix * TILE, TILE_LIFT, first + iz * TILE)
			Props.place("DojoFloorTile", CFrame.new(pos), floor, { collide = true })
		end
	end

	--------------------------------------------------------------------------
	-- Walls: WallSegment around the perimeter, gap at the entrance
	--------------------------------------------------------------------------
	local walls = Build.folder("Walls", deco)
	local function wall(pos: Vector3, rotY: number)
		Props.place("WallSegment", CFrame.new(pos) * CFrame.Angles(0, rotY, 0), walls)
	end
	for i = 0, tiles - 1 do
		local along = first + i * TILE
		wall(center + Vector3.new(along, 0, -hd), 0) -- back
		wall(center + Vector3.new(-hw, 0, along), math.rad(90)) -- left
		wall(center + Vector3.new(hw, 0, along), math.rad(90)) -- right
		if math.abs(along) > halfGap + 1 then -- front, minus the gate opening
			wall(center + Vector3.new(along, 0, hd), 0)
		end
	end
	-- close the short runs either side of the gate
	for _, x in { -(halfGap + 2.1), halfGap + 2.1 } do
		wall(center + Vector3.new(x, 0, hd), 0)
	end

	--------------------------------------------------------------------------
	-- Entrance: BaseGate in the gap, lasers strung inside it
	--------------------------------------------------------------------------
	Props.place("BaseGate", CFrame.new(center + Vector3.new(0, 0, hd)), deco)

	local gates = Build.folder("Gates", bf)
	-- the client toggles this part's collision to block non-owners while locked
	Build.part({
		Name = "Gate",
		Size = Vector3.new(GATE_WIDTH, 12, 1),
		Position = center + Vector3.new(0, 6, hd),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	}, gates)

	local lasers = Build.folder("Lasers", bf)
	local jambL = marker("LaserJamb", Vector3.new(0.2, 5, 0.2), center + Vector3.new(-halfGap, 2.5, hd), deco)
	local jambR = marker("LaserJamb", Vector3.new(0.2, 5, 0.2), center + Vector3.new(halfGap, 2.5, hd), deco)
	for i, y in { 0.7, 1.7, 2.7, 3.7 } do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, y - 2.5, 0)
		a0.Parent = jambL
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, y - 2.5, 0)
		a1.Parent = jambR
		local beam = Instance.new("Beam")
		beam.Name = "Laser" .. i
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 40, 40))
		beam.Width0 = 0.5
		beam.Width1 = 0.5
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(0.1)
		beam.FaceCamera = true
		beam.Enabled = false
		beam.Parent = lasers
	end

	-- tiled porch outside the gate + the marker bosses camp at
	local porch = Build.folder("Porch", deco)
	for ix = -1, 1 do
		for iz = 0, 1 do
			Props.place(
				"DojoFloorTile",
				CFrame.new(center + Vector3.new(ix * TILE, TILE_LIFT, hd + 2.5 + iz * TILE)),
				porch,
				{ collide = true }
			)
		end
	end
	marker("Entrance", Vector3.new(8, 1, 6), center + Vector3.new(0, 0.5, hd + 5), bf)

	--------------------------------------------------------------------------
	-- Lock pad
	--------------------------------------------------------------------------
	local lockPos = center + Vector3.new(0, FLOOR_TOP, hd - 7)
	Props.place("LockPad", CFrame.new(lockPos), deco)
	local lockSize = Props.size("LockPad") or Vector3.new(3.2, 0.42, 3.2)
	local lockMarker =
		marker("LockPad", Vector3.new(lockSize.X, 1.6, lockSize.Z), lockPos + Vector3.new(0, 0.8, 0), bf, true)
	Build.label(lockMarker, "🔒 LOCK", Color3.fromRGB(255, 220, 90), 2.6, 90, 45)

	--------------------------------------------------------------------------
	-- Fighter slots: a DisplayPad per slot, in rows
	--------------------------------------------------------------------------
	local slots = Build.folder("Slots", bf)
	local pads = Build.folder("Pads", deco)
	local B = Config.Base
	local total = B.Floor1Slots + B.Floor2Slots + B.Floor3Slots
	local padSize = Props.size("DisplayPad") or Vector3.new(3.32, 1.09, 3.32)
	local cols = 6
	local i = 0
	for row = 0, math.ceil(total / cols) - 1 do
		for col = 0, cols - 1 do
			i += 1
			if i > total then
				break
			end
			local floorN = if i <= B.Floor1Slots then 1 elseif i <= B.Floor1Slots + B.Floor2Slots then 2 else 3
			local x = -hw + 6 + col * 6.4
			local z = hd - 15 - row * 6.4
			local pos = center + Vector3.new(x, FLOOR_TOP, z)
			Props.place("DisplayPad", CFrame.new(pos), pads)
			-- the slot marker's top sits on the pad, so fighters stand on it
			local p = marker(
				"Slot" .. i,
				Vector3.new(padSize.X * 0.95, 0.2, padSize.Z * 0.95),
				pos + Vector3.new(0, padSize.Y - 0.1, 0),
				slots
			)
			p:SetAttribute("Floor", floorN)
		end
	end

	--------------------------------------------------------------------------
	-- Training: the punching bag anchor, with level 1's prop welded to it
	--------------------------------------------------------------------------
	local bagPos = center + Vector3.new(hw - 7, FLOOR_TOP, hd - 9)
	local bagSize = Props.size("TrainingPost_L1") or Vector3.new(2, 5.83, 2)
	local bag = Build.part({
		Name = "PunchingBag",
		Size = Vector3.new(math.max(bagSize.X, 1.5), bagSize.Y, math.max(bagSize.Z, 1.5)),
		Position = bagPos + Vector3.new(0, bagSize.Y / 2, 0),
		Transparency = 1,
		CanCollide = true,
		CanQuery = false,
		CanTouch = false,
	}, bf)
	Build.label(bag, "🥊 TRAINING\nhold to train", Color3.fromRGB(255, 190, 120), 2.5, 200, 55)

	-- Training input is bound client-side (left mouse / R2 / the mobile button), so the bag only
	-- carries the upgrade prompt. PowerService fills in its cost text.
	local upgrade = Instance.new("ProximityPrompt")
	upgrade.Name = "UpgradePrompt"
	upgrade.ActionText = "Upgrade"
	upgrade.ObjectText = "Training"
	upgrade.KeyboardKeyCode = Enum.KeyCode.F
	upgrade.HoldDuration = 0.35
	upgrade.MaxActivationDistance = 12
	upgrade.RequiresLineOfSight = false
	upgrade.UIOffset = Vector2.new(0, 70)
	upgrade.Parent = bag

	TrainingProp.apply(bag, 1)

	--------------------------------------------------------------------------
	-- Spawn mat + owner sign
	--------------------------------------------------------------------------
	local spawnMat = Build.cyl(
		Vector3.new(5, 0.4, 5),
		CFrame.new(center + Vector3.new(-hw + 6, FLOOR_TOP + 0.2, hd - 8)),
		color,
		Enum.Material.Fabric,
		bf
	)
	spawnMat.Name = "Spawn"
	spawnMat.CanCollide = false
	spawnMat.CastShadow = false

	marker("Sign", Vector3.new(1, 1, 1), center + Vector3.new(0, 9, hd), bf)
end

return Bases
