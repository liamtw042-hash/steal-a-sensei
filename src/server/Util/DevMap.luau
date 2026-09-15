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
	if Workspace:FindFirstChild("Map") then
		return
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
