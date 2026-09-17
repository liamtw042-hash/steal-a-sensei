--!strict
--[[
	DEV MAP
	=======
	If Workspace has no `Map` folder, this generates a full playable map at runtime:
	terrain (grass, per-zone floors, cliff corridors), lighting/sky, the hub plaza,
	eight fenced base plots and ten dressed zones. Every named part the scripts expect
	is created (see docs/STUDIO_CHECKLIST.md). Build a real `Workspace.Map` and this
	never runs.
]]
local Workspace = game:GetService("Workspace")

local Build = require(script.Parent.Parent.Map.Build)
local TerrainBuilder = require(script.Parent.Parent.Map.Terrain)
local LightingBuilder = require(script.Parent.Parent.Map.Lighting)
local Hub = require(script.Parent.Parent.Map.Hub)
local Bases = require(script.Parent.Parent.Map.Bases)
local Zones = require(script.Parent.Parent.Map.Zones)

local DevMap = {}

function DevMap.ensure()
	-- An EMPTY Map folder (e.g. left behind by an asset import) is not a map: generating
	-- anyway beats leaving the server with no bases and no zones.
	local existing = Workspace:FindFirstChild("Map")
	if existing and #existing:GetChildren() > 0 then
		return
	end
	if existing then
		warn("[DevMap] Workspace.Map exists but is empty; building the built-in map into it.")
		existing:Destroy()
	end
	warn(
		"[DevMap] No Workspace.Map found: generating the built-in map so the game is playable. "
			.. "Build your own map with a Workspace.Map folder (see docs/STUDIO_CHECKLIST.md) and this will stop."
	)
	local t0 = os.clock()

	-- hide the default spawn slab / baseplate decorations that would poke through the terrain
	for _, name in { "SpawnLocation" } do
		local inst = Workspace:FindFirstChild(name)
		if inst and inst:IsA("BasePart") then
			inst.Transparency = 1
			inst.CanCollide = false
		end
	end

	TerrainBuilder.build()
	LightingBuilder.build()

	-- Terrain collision meshes are rebuilt on a background thread, so a raycast fired in the same
	-- frame as the fill falls straight through to the baseplate. The bases measure the ground with
	-- a raycast, so wait until the terrain is actually queryable before placing anything on it.
	local probe = RaycastParams.new()
	probe.IgnoreWater = true
	for _ = 1, 240 do
		local hit = Workspace:Raycast(Vector3.new(0, 80, -50), Vector3.new(0, -200, 0), probe)
		if hit and hit.Instance == Workspace.Terrain then
			break
		end
		task.wait()
	end

	local map = Build.folder("Map", Workspace)
	Hub.build(map)

	if not Workspace:FindFirstChild("Bases") then
		local bases = Build.folder("Bases", Workspace)
		for i = 1, 8 do
			Bases.build(bases, i)
		end
	end
	if not Workspace:FindFirstChild("Zones") then
		local zones = Build.folder("Zones", Workspace)
		Zones.buildAll(zones)
	end

	print(`[DevMap] built in {string.format("%.2f", os.clock() - t0)}s`)
end

return DevMap
