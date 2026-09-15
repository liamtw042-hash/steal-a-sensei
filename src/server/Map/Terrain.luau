--!strict
-- Terrain: grass floor, per-zone floor materials, cliff walls bordering the zone strip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)

local TerrainBuilder = {}

-- Floor material per zone id
local ZoneMaterial: { [number]: Enum.Material } = {
	[1] = Enum.Material.Sand,
	[2] = Enum.Material.LeafyGrass,
	[3] = Enum.Material.Basalt,
	[4] = Enum.Material.Rock,
	[5] = Enum.Material.Snow,
	[6] = Enum.Material.CrackedLava,
	[7] = Enum.Material.Sandstone,
	[8] = Enum.Material.Limestone,
	[9] = Enum.Material.Salt,
	[10] = Enum.Material.Basalt,
}

function TerrainBuilder.zoneMaterial(zoneId: number): Enum.Material
	return ZoneMaterial[zoneId] or Enum.Material.LeafyGrass
end

function TerrainBuilder.build()
	local T = Workspace.Terrain
	local G = Layout.G

	-- Grass everywhere (top surface at y = G). LeafyGrass: plain Grass grows knee-high animated blades that hide props.
	T:FillBlock(CFrame.new(0, G - 4, 600), Vector3.new(800, 8, 2000), Enum.Material.LeafyGrass)

	-- Zone floors + corridor pavement between them
	for i, _ in Config.Zones.List do
		local cz = Layout.zoneCenterZ(i)
		T:FillBlock(
			CFrame.new(0, G - 3, cz),
			Vector3.new(Layout.ZONE_SIZE, 6, Layout.ZONE_SIZE),
			TerrainBuilder.zoneMaterial(i)
		)
		local gapCenter = Layout.zoneFrontZ(i) - Layout.ZONE_GAP / 2
		T:FillBlock(CFrame.new(0, G - 3, gapCenter), Vector3.new(24, 6, Layout.ZONE_GAP), Enum.Material.Pavement)
	end
	-- path from the hub to zone 1
	T:FillBlock(
		CFrame.new(0, G - 3, (Layout.HUB.Z + Layout.zoneFrontZ(1)) / 2),
		Vector3.new(24, 6, Layout.zoneFrontZ(1) - Layout.HUB.Z),
		Enum.Material.Pavement
	)

	-- Cliff walls either side of the strip, grass on top
	local stripLen = Layout.STRIP_END_Z - Layout.STRIP_START_Z
	local stripMid = (Layout.STRIP_END_Z + Layout.STRIP_START_Z) / 2
	local cliffX = Layout.STRIP_HALF + Layout.CLIFF_THICK / 2
	for _, sx in { -1, 1 } do
		T:FillBlock(
			CFrame.new(sx * cliffX, G + Layout.CLIFF_HEIGHT / 2, stripMid),
			Vector3.new(Layout.CLIFF_THICK, Layout.CLIFF_HEIGHT, stripLen),
			Enum.Material.Rock
		)
		T:FillBlock(
			CFrame.new(sx * cliffX, G + Layout.CLIFF_HEIGHT + 1, stripMid),
			Vector3.new(Layout.CLIFF_THICK, 4, stripLen),
			Enum.Material.LeafyGrass
		)
	end
	-- Back wall behind the last zone
	T:FillBlock(
		CFrame.new(0, G + Layout.CLIFF_HEIGHT / 2, Layout.STRIP_END_Z + Layout.CLIFF_THICK / 2),
		Vector3.new(Layout.STRIP_HALF * 2 + Layout.CLIFF_THICK * 2, Layout.CLIFF_HEIGHT, Layout.CLIFF_THICK),
		Enum.Material.Rock
	)

	-- Abyss Shrine (7): water pools set into the floor
	local z7 = Layout.zoneCenterZ(7)
	for _, off in { Vector3.new(-30, 0, 0), Vector3.new(30, 0, 8), Vector3.new(0, 0, 32) } do
		T:FillCylinder(CFrame.new(off.X, G - 1.5, z7 + off.Z), 3, 10, Enum.Material.Water)
	end
	-- Frozen Temple (5): ice patches
	local z5 = Layout.zoneCenterZ(5)
	for _, off in { Vector3.new(-28, 0, -20), Vector3.new(25, 0, 15), Vector3.new(0, 0, 35) } do
		T:FillCylinder(CFrame.new(off.X, G - 1.5, z5 + off.Z), 3, 8, Enum.Material.Glacier)
	end
	-- Volcanic Dojo (6): lava rock mounds
	local z6 = Layout.zoneCenterZ(6)
	T:FillBall(Vector3.new(-40, G - 2, z6 + 30), 9, Enum.Material.Basalt)
	T:FillBall(Vector3.new(42, G - 2, z6 - 25), 8, Enum.Material.Basalt)
	-- Ancient Ruins (8): raised sandstone steps
	local z8 = Layout.zoneCenterZ(8)
	T:FillBlock(CFrame.new(0, G + 1, z8 + 30), Vector3.new(40, 2, 20), Enum.Material.Sandstone)
end

return TerrainBuilder
