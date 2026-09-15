--!strict
--[[
	DEV MAP
	=======
	If Workspace has no `Map` folder, this builds a crude placeholder map with every
	named part the scripts expect (zones, bases, spawn), so the whole loop is playable on
	a blank baseplate. Once you build the real map in Studio (with a Workspace.Map folder)
	this never runs. See docs/STUDIO_CHECKLIST.md for the full naming list.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.Zones)

local DevMap = {}

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function buildZone(zonesFolder: Folder, zone: ZonesConfig.ZoneDef, index: number)
	local size = 90
	local cz = 140 * index -- zones march along +Z
	local center = Vector3.new(0, 0, cz)
	local zf = folder(zone.folderName, zonesFolder)

	-- floor tint so zones are visible
	part({
		Name = "Floor",
		Size = Vector3.new(size, 1, size),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = zone.boss.color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.6),
		Material = Enum.Material.Slate,
	}, zf)

	part({
		Name = "Bounds",
		Size = Vector3.new(size, 40, size),
		Position = center + Vector3.new(0, 20, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, zf)

	-- entrance wall across the front (the -Z side), with side walls so you can't walk around
	part({
		Name = "Entrance",
		Size = Vector3.new(size, 14, 1),
		Position = center + Vector3.new(0, 8, -size / 2),
		Color = zone.boss.color,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
	}, zf)
	for _, sx in { -1, 1 } do
		part({
			Name = "SideWall",
			Size = Vector3.new(1, 14, size),
			Position = center + Vector3.new(sx * size / 2, 8, 0),
			Color = Color3.fromRGB(60, 60, 60),
			Transparency = 0.4,
		}, zf)
	end
	part({
		Name = "BackWall",
		Size = Vector3.new(size, 14, 1),
		Position = center + Vector3.new(0, 8, size / 2),
		Color = Color3.fromRGB(60, 60, 60),
		Transparency = 0.4,
	}, zf)

	part({
		Name = "BossSpawn",
		Size = Vector3.new(6, 1, 6),
		Position = center + Vector3.new(0, 1.5, size / 2 - 8),
		Color = Color3.fromRGB(120, 20, 20),
		Material = Enum.Material.Neon,
	}, zf)

	local nests = folder("Nests", zf)
	local offsets = {
		Vector3.new(-25, 0, -10),
		Vector3.new(25, 0, -10),
		Vector3.new(-25, 0, 20),
		Vector3.new(25, 0, 20),
	}
	for i, off in offsets do
		part({
			Name = "Nest" .. i,
			Size = Vector3.new(5, 1, 5),
			Position = center + off + Vector3.new(0, 1.5, 0),
			Color = Color3.fromRGB(230, 200, 120),
			Material = Enum.Material.Wood,
		}, nests)
	end

	local patrol = folder("PatrolPoints", zf)
	for i, off in { Vector3.new(-30, 0, 30), Vector3.new(30, 0, 30), Vector3.new(0, 0, 0), Vector3.new(0, 0, -30) } do
		part({
			Name = "P" .. i,
			Size = Vector3.new(2, 1, 2),
			Position = center + off + Vector3.new(0, 1.5, 0),
			Transparency = 1,
			CanCollide = false,
		}, patrol)
	end

	-- zone label
	local sign = part({
		Name = "ZoneSign",
		Size = Vector3.new(1, 1, 1),
		Position = center + Vector3.new(0, 18, -size / 2),
		Transparency = 1,
		CanCollide = false,
	}, zf)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(300, 60)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 400
	bb.Parent = sign
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0.3
	lbl.Text = `{zone.name}`
	lbl.Parent = bb
end

local function buildBase(basesFolder: Folder, index: number)
	local w, d = 44, 44
	local cx = -175 + (index - 1) * 50
	local cz = -90
	local center = Vector3.new(cx, 0, cz)
	local bf = folder("Base" .. index, basesFolder)

	part({
		Name = "Floor",
		Size = Vector3.new(w, 1, d),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(70, 70, 90),
		Material = Enum.Material.Concrete,
	}, bf)
	part({
		Name = "Region",
		Size = Vector3.new(w, 24, d),
		Position = center + Vector3.new(0, 12, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, bf)
	-- solid walls on three sides
	for _, sx in { -1, 1 } do
		part({
			Name = "Wall",
			Size = Vector3.new(1, 12, d),
			Position = center + Vector3.new(sx * w / 2, 7, 0),
			Color = Color3.fromRGB(90, 90, 110),
		}, bf)
	end
	part({
		Name = "Wall",
		Size = Vector3.new(w, 12, 1),
		Position = center + Vector3.new(0, 7, -d / 2),
		Color = Color3.fromRGB(90, 90, 110),
	}, bf)
	-- front side (toward +Z, facing the spawn): gate wall
	local gates = folder("Gates", bf)
	part({
		Name = "Gate",
		Size = Vector3.new(w, 12, 1),
		Position = center + Vector3.new(0, 7, d / 2),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
	}, gates)

	part({
		Name = "Entrance",
		Size = Vector3.new(6, 1, 6),
		Position = center + Vector3.new(0, 1.5, d / 2 + 5),
		Color = Color3.fromRGB(120, 120, 140),
	}, bf)
	part({
		Name = "LockPad",
		Size = Vector3.new(5, 1, 5),
		Position = center + Vector3.new(0, 1.5, d / 2 - 5),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
	}, bf)
	part({
		Name = "Treadmill",
		Size = Vector3.new(6, 1, 6),
		Position = center + Vector3.new(w / 2 - 5, 1.5, d / 2 - 5),
		Color = Color3.fromRGB(80, 220, 255),
		Material = Enum.Material.Neon,
	}, bf)
	part({
		Name = "Spawn",
		Size = Vector3.new(4, 1, 4),
		Position = center + Vector3.new(-w / 2 + 5, 1.5, d / 2 - 5),
		Color = Color3.fromRGB(120, 255, 120),
	}, bf)
	part({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		Position = center + Vector3.new(0, 16, d / 2),
		Transparency = 1,
		CanCollide = false,
	}, bf)

	local slots = folder("Slots", bf)
	local B = Config.Base
	local total = B.Floor1Slots + B.Floor2Slots + B.Floor3Slots
	local cols = 6
	local i = 0
	for row = 0, math.ceil(total / cols) - 1 do
		for col = 0, cols - 1 do
			i += 1
			if i > total then
				break
			end
			local floorN = if i <= B.Floor1Slots then 1 elseif i <= B.Floor1Slots + B.Floor2Slots then 2 else 3
			local x = -w / 2 + 6 + col * 6.4
			local z = d / 2 - 12 - row * 6.4
			local p = part({
				Name = "Slot" .. i,
				Size = Vector3.new(5, 0.4, 5),
				Position = center + Vector3.new(x, 1.2, z),
				Color = if floorN == 1
					then Color3.fromRGB(110, 110, 130)
					elseif floorN == 2 then Color3.fromRGB(130, 110, 150)
					else Color3.fromRGB(150, 130, 90),
			}, slots)
			p:SetAttribute("Floor", floorN)
		end
	end
end

function DevMap.ensure()
	if Workspace:FindFirstChild("Map") then
		return
	end
	warn(
		"[DevMap] No Workspace.Map found: generating a placeholder map so the game is playable. "
			.. "Build the real map (see docs/STUDIO_CHECKLIST.md) and this will stop."
	)

	local map = folder("Map", Workspace)
	part({
		Name = "Spawn",
		Size = Vector3.new(12, 1, 12),
		Position = Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(200, 200, 200),
	}, map)
	part({
		Name = "RiftSpawn",
		Size = Vector3.new(6, 1, 6),
		Position = Vector3.new(70, 0.5, 0),
		Color = Color3.fromRGB(150, 60, 220),
	}, map)
	part({
		Name = "HungrySenseiSpawn",
		Size = Vector3.new(6, 1, 6),
		Position = Vector3.new(-70, 0.5, 0),
		Color = Color3.fromRGB(220, 120, 60),
	}, map)

	if not Workspace:FindFirstChild("Zones") then
		local zones = folder("Zones", Workspace)
		for i, zone in Config.Zones.List do
			buildZone(zones, zone, i)
		end
	end
	if not Workspace:FindFirstChild("Bases") then
		local bases = folder("Bases", Workspace)
		for i = 1, Config.Base.Count do
			buildBase(bases, i)
		end
	end
end

return DevMap
