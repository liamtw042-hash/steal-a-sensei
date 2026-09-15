--!strict
-- Where everything sits in the generated map. All other Map modules read from here.
local Build = require(script.Parent.Build)

local Layout = {}

Layout.G = Build.GROUND

-- Bases: one row south of the hub, gates facing north (+Z toward the hub)
Layout.BASE_Z = -135
Layout.BASE_W = 44
Layout.BASE_D = 44
function Layout.baseX(index: number): number
	return -175 + (index - 1) * 50
end

-- Hub plaza between the bases and the zones
Layout.HUB = Vector3.new(0, Layout.G, -50)
Layout.HUB_RADIUS = 34
Layout.SPAWN = Vector3.new(0, Layout.G, -84)

-- Zones march north along +Z inside a cliff-walled strip
Layout.ZONE_SIZE = 100 -- x and z extent of each zone floor
Layout.ZONE_GAP = 30 -- corridor between zones
Layout.STRIP_HALF = 50 -- half width of the walkable strip
Layout.CLIFF_THICK = 28
Layout.CLIFF_HEIGHT = 30
function Layout.zoneCenterZ(index: number): number
	return 80 + (Layout.ZONE_SIZE + Layout.ZONE_GAP) * (index - 1) + Layout.ZONE_SIZE / 2
end
function Layout.zoneFrontZ(index: number): number
	return Layout.zoneCenterZ(index) - Layout.ZONE_SIZE / 2
end
Layout.STRIP_START_Z = 20
Layout.STRIP_END_Z = Layout.zoneCenterZ(10) + Layout.ZONE_SIZE / 2 + 10

return Layout
