--!strict
--[[
	Zones: the ten themed zones. Each gets a glowing portal entrance (the `Entrance` part),
	Bounds, BossSpawn, pedestal Nests, PatrolPoints and a pile of props matching its theme.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.Zones)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.Layout)

local Zones = {}

local G = Layout.G
local HALF = Layout.ZONE_SIZE / 2

type Dresser = (zf: Folder, center: Vector3, def: ZonesConfig.ZoneDef) -> ()

--------------------------------------------------------------------------------
-- Shared props
--------------------------------------------------------------------------------

local function pedestal(pos: Vector3, glow: Color3, parent: Instance): Part
	local m = Build.model("Pedestal", parent)
	Build.cyl(
		Vector3.new(6, 0.8, 6),
		CFrame.new(pos + Vector3.new(0, 0.4, 0)),
		Color3.fromRGB(120, 115, 110),
		Enum.Material.Slate,
		m
	)
	Build.cyl(
		Vector3.new(4.2, 1.4, 4.2),
		CFrame.new(pos + Vector3.new(0, 1.5, 0)),
		Color3.fromRGB(145, 140, 135),
		Enum.Material.Slate,
		m
	)
	local ring =
		Build.cyl(Vector3.new(5, 0.3, 5), CFrame.new(pos + Vector3.new(0, 2.3, 0)), glow, Enum.Material.Neon, m)
	Build.light(ring, glow, 10, 1.2)
	Build.particles(ring, {
		Color = ColorSequence.new(glow),
		Rate = 5,
		Size = NumberSequence.new(0.5),
		Speed = NumberRange.new(1.5, 3),
		Lifetime = NumberRange.new(1, 1.8),
	})
	local top = Build.cyl(
		Vector3.new(3.4, 0.4, 3.4),
		CFrame.new(pos + Vector3.new(0, 2.6, 0)),
		Color3.fromRGB(70, 65, 60),
		Enum.Material.Slate,
		m
	)
	return top
end

local function torii(pos: Vector3, color: Color3, scale: number, parent: Instance)
	local s = scale
	local m = Build.model("Torii", parent)
	for _, x in { -4 * s, 4 * s } do
		Build.cyl(
			Vector3.new(1.2 * s, 10 * s, 1.2 * s),
			CFrame.new(pos + Vector3.new(x, 5 * s, 0)),
			color,
			Enum.Material.SmoothPlastic,
			m
		)
	end
	Build.block(
		Vector3.new(12 * s, 0.9 * s, 1.2 * s),
		CFrame.new(pos + Vector3.new(0, 10.4 * s, 0)),
		color:Lerp(Color3.new(0, 0, 0), 0.2),
		Enum.Material.SmoothPlastic,
		m
	)
	Build.block(
		Vector3.new(9.5 * s, 0.7 * s, 1 * s),
		CFrame.new(pos + Vector3.new(0, 8.6 * s, 0)),
		color,
		Enum.Material.SmoothPlastic,
		m
	)
	Build.block(
		Vector3.new(10.5 * s, 0.6 * s, 1.4 * s),
		CFrame.new(pos + Vector3.new(0, 11.1 * s, 0)),
		Color3.fromRGB(40, 40, 45),
		Enum.Material.SmoothPlastic,
		m
	)
end

local function lantern(pos: Vector3, color: Color3, parent: Instance)
	local m = Build.model("Lantern", parent)
	Build.block(
		Vector3.new(0.5, 5, 0.5),
		CFrame.new(pos + Vector3.new(0, 2.5, 0)),
		Color3.fromRGB(50, 40, 35),
		Enum.Material.Wood,
		m
	)
	local paper =
		Build.block(Vector3.new(1.8, 2.2, 1.8), CFrame.new(pos + Vector3.new(0, 6, 0)), color, Enum.Material.Neon, m)
	paper.Transparency = 0.15
	Build.block(
		Vector3.new(2.4, 0.3, 2.4),
		CFrame.new(pos + Vector3.new(0, 7.2, 0)),
		Color3.fromRGB(50, 40, 35),
		Enum.Material.Wood,
		m
	)
	Build.light(paper, color, 14, 1.2)
end

local function pillar(pos: Vector3, height: number, radius: number, color: Color3, broken: boolean, parent: Instance)
	local m = Build.model("Pillar", parent)
	Build.cyl(
		Vector3.new(radius * 2.4, 0.8, radius * 2.4),
		CFrame.new(pos + Vector3.new(0, 0.4, 0)),
		color:Lerp(Color3.new(0, 0, 0), 0.1),
		Enum.Material.Limestone,
		m
	)
	local h = if broken then height * Build.rng:NextNumber(0.3, 0.6) else height
	Build.cyl(
		Vector3.new(radius * 2, h, radius * 2),
		CFrame.new(pos + Vector3.new(0, 0.8 + h / 2, 0)) * CFrame.Angles(0, 0, if broken then Build.jitter(0.08) else 0),
		color,
		Enum.Material.Limestone,
		m
	)
	if broken then
		-- fallen top piece next to it
		local len = height - h
		Build.cyl(
			Vector3.new(radius * 2, len, radius * 2),
			CFrame.new(pos + Vector3.new(Build.jitter(1) + radius * 3, radius, Build.jitter(4)))
				* CFrame.Angles(math.rad(90), Build.jitter(1), 0),
			color,
			Enum.Material.Limestone,
			m
		)
	else
		Build.cyl(
			Vector3.new(radius * 2.4, 0.8, radius * 2.4),
			CFrame.new(pos + Vector3.new(0, 0.8 + h + 0.4, 0)),
			color:Lerp(Color3.new(0, 0, 0), 0.1),
			Enum.Material.Limestone,
			m
		)
	end
end

local function scatter(n: number, center: Vector3, margin: number, fn: (pos: Vector3) -> ())
	for _ = 1, n do
		local x = Build.rng:NextNumber(-HALF + margin, HALF - margin)
		local z = Build.rng:NextNumber(-HALF + margin, HALF - margin)
		-- keep the middle lane clear-ish
		if math.abs(x) < 9 then
			x += if x < 0 then -10 else 10
		end
		fn(center + Vector3.new(x, 0, z))
	end
end

--------------------------------------------------------------------------------
-- Per-zone dressing
--------------------------------------------------------------------------------

local dressers: { [number]: Dresser } = {}

-- 1 Training Grounds: dummies, weapon racks, palms
dressers[1] = function(zf, c)
	local function dummy(pos: Vector3)
		local m = Build.model("Dummy", zf)
		Build.cyl(
			Vector3.new(0.8, 4, 0.8),
			CFrame.new(pos + Vector3.new(0, 2, 0)),
			Color3.fromRGB(120, 85, 50),
			Enum.Material.Wood,
			m
		)
		Build.cyl(
			Vector3.new(2.4, 3, 2.4),
			CFrame.new(pos + Vector3.new(0, 4.5, 0)),
			Color3.fromRGB(220, 190, 110),
			Enum.Material.Fabric,
			m
		)
		Build.ball(
			1.8,
			CFrame.new(pos + Vector3.new(0, 6.8, 0)),
			Color3.fromRGB(220, 190, 110),
			Enum.Material.Fabric,
			m
		)
		Build.block(
			Vector3.new(4.5, 0.5, 0.5),
			CFrame.new(pos + Vector3.new(0, 5.2, 0)),
			Color3.fromRGB(120, 85, 50),
			Enum.Material.Wood,
			m
		)
	end
	local function rack(pos: Vector3, rot: number)
		local m = Build.model("Rack", zf)
		local cf = CFrame.new(pos) * CFrame.Angles(0, rot, 0)
		for _, x in { -2.5, 2.5 } do
			Build.block(
				Vector3.new(0.5, 4, 0.5),
				cf * CFrame.new(x, 2, 0),
				Color3.fromRGB(120, 85, 50),
				Enum.Material.Wood,
				m
			)
		end
		Build.block(
			Vector3.new(6, 0.4, 0.5),
			cf * CFrame.new(0, 3.8, 0),
			Color3.fromRGB(120, 85, 50),
			Enum.Material.Wood,
			m
		)
		for i = -1, 1 do
			Build.block(
				Vector3.new(0.3, 4.2, 0.3),
				cf * CFrame.new(i * 1.6, 2.3, 0.4) * CFrame.Angles(0, 0, math.rad(8)),
				Color3.fromRGB(200, 200, 210),
				Enum.Material.Metal,
				m
			)
		end
	end
	scatter(8, c, 8, dummy)
	rack(c + Vector3.new(-38, 0, -30), 0)
	rack(c + Vector3.new(38, 0, -30), 0)
	rack(c + Vector3.new(-38, 0, 30), math.rad(90))
	for _, p in { Vector3.new(-42, 0, 42), Vector3.new(42, 0, 42), Vector3.new(-42, 0, -42), Vector3.new(42, 0, -42) } do
		Build.tree(c + p, 9, Color3.fromRGB(90, 200, 100), Color3.fromRGB(160, 120, 70), zf)
	end
end

-- 2 Bamboo Forest: bamboo stalks everywhere, grass tufts, mossy rocks
dressers[2] = function(zf, c)
	local function bamboo(pos: Vector3)
		local h = Build.rng:NextNumber(10, 18)
		local m = Build.model("Bamboo", zf)
		local green = Color3.fromRGB(110, 190, 70)
		Build.cyl(
			Vector3.new(0.9, h, 0.9),
			CFrame.new(pos + Vector3.new(0, h / 2, 0)),
			green,
			Enum.Material.SmoothPlastic,
			m
		)
		for y = 3, h - 1, 3 do
			Build.cyl(
				Vector3.new(1.1, 0.3, 1.1),
				CFrame.new(pos + Vector3.new(0, y, 0)),
				green:Lerp(Color3.new(0, 0, 0), 0.3),
				Enum.Material.SmoothPlastic,
				m
			)
		end
		for _ = 1, 3 do
			Build.wedge(
				Vector3.new(0.2, 1.2, 3),
				CFrame.new(pos + Vector3.new(0, h - Build.rng:NextNumber(0, 5), 0))
					* CFrame.Angles(0, Build.jitter(3), math.rad(60)),
				Color3.fromRGB(80, 170, 60),
				Enum.Material.Grass,
				m
			)
		end
	end
	scatter(60, c, 4, bamboo)
	scatter(10, c, 6, function(pos)
		Build.rock(pos + Vector3.new(0, 1, 0), Vector3.new(3, 2.2, 3), Color3.fromRGB(100, 130, 90), zf)
	end)
end

-- 3 Shadow Village: torii gates, lanterns, dark huts, purple mist particles
dressers[3] = function(zf, c)
	local red = Color3.fromRGB(190, 40, 50)
	torii(c + Vector3.new(0, 0, -30), red, 1.3, zf)
	torii(c + Vector3.new(0, 0, 10), red, 1, zf)
	scatter(14, c, 6, function(pos)
		lantern(pos, Color3.fromRGB(255, 150, 80), zf)
	end)
	local function hut(pos: Vector3, rot: number)
		local m = Build.model("Hut", zf)
		local cf = CFrame.new(pos) * CFrame.Angles(0, rot, 0)
		Build.block(
			Vector3.new(10, 6, 8),
			cf * CFrame.new(0, 3, 0),
			Color3.fromRGB(55, 50, 60),
			Enum.Material.WoodPlanks,
			m
		)
		Build.wedge(
			Vector3.new(11, 4, 5),
			cf * CFrame.new(0, 8, 2.5) * CFrame.Angles(0, math.pi, 0),
			Color3.fromRGB(35, 30, 40),
			Enum.Material.Slate,
			m
		)
		Build.wedge(
			Vector3.new(11, 4, 5),
			cf * CFrame.new(0, 8, -2.5),
			Color3.fromRGB(35, 30, 40),
			Enum.Material.Slate,
			m
		)
		local door = Build.block(
			Vector3.new(2.5, 3.5, 0.2),
			cf * CFrame.new(0, 1.75, 4.1),
			Color3.fromRGB(255, 170, 90),
			Enum.Material.Neon,
			m
		)
		Build.light(door, Color3.fromRGB(255, 170, 90), 10, 0.8)
	end
	hut(c + Vector3.new(-36, 0, -10), math.rad(90))
	hut(c + Vector3.new(36, 0, 20), math.rad(-90))
	hut(c + Vector3.new(-30, 0, 34), 0)
	local mist = Build.part({
		Size = Vector3.new(90, 1, 90),
		Position = c + Vector3.new(0, 1, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, zf)
	Build.particles(mist, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(120, 80, 160)),
		Rate = 6,
		Size = NumberSequence.new(8),
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.5, 1),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightEmission = 0.2,
	})
end

-- 4 Storm Peak: floating rocks, crackling lightning, dark jagged spires
dressers[4] = function(zf, c)
	scatter(12, c, 8, function(pos)
		local r = Build.rock(
			pos + Vector3.new(0, Build.rng:NextNumber(8, 16), 0),
			Vector3.new(5, 4, 5),
			Color3.fromRGB(90, 90, 105),
			zf
		)
		Build.hover(r, 2, Build.rng:NextNumber(3, 5), true)
		local e = Build.particles(r, {
			Color = ColorSequence.new(Color3.fromRGB(180, 220, 255)),
			Rate = 3,
			Size = NumberSequence.new(0.6),
			Speed = NumberRange.new(3, 6),
			Lifetime = NumberRange.new(0.3, 0.6),
		})
		e.LightEmission = 1
	end)
	scatter(8, c, 6, function(pos)
		local h = Build.rng:NextNumber(8, 16)
		Build.wedge(
			Vector3.new(3, h, 3),
			CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, Build.jitter(3), 0),
			Color3.fromRGB(70, 70, 85),
			Enum.Material.Slate,
			zf
		)
	end)
	-- lightning flashes: neon bolts that blink
	for i = 1, 4 do
		local pos = c + Vector3.new(Build.jitter(35), 0, Build.jitter(35))
		local bolt = Build.block(
			Vector3.new(0.5, 30, 0.5),
			CFrame.new(pos + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, Build.jitter(0.25)),
			Color3.fromRGB(220, 240, 255),
			Enum.Material.Neon,
			zf
		)
		bolt.Transparency = 1
		bolt.CanCollide = false
		local light = Build.light(bolt, Color3.fromRGB(200, 230, 255), 40, 0)
		task.spawn(function()
			task.wait(i * 1.3)
			while bolt.Parent do
				task.wait(Build.rng:NextNumber(4, 9))
				bolt.Transparency = 0
				light.Brightness = 4
				task.wait(0.12)
				bolt.Transparency = 1
				light.Brightness = 0
			end
		end)
	end
end

-- 5 Frozen Temple: ice crystal clusters, snowy pillars, a temple roof
dressers[5] = function(zf, c)
	local ice = Color3.fromRGB(160, 225, 255)
	scatter(16, c, 6, function(pos)
		local m = Build.model("Crystal", zf)
		for _ = 1, 3 do
			local h = Build.rng:NextNumber(4, 9)
			local p = Build.wedge(
				Vector3.new(1.6, h, 1.6),
				CFrame.new(pos + Vector3.new(Build.jitter(1.5), h / 2 - 0.5, Build.jitter(1.5)))
					* CFrame.Angles(Build.jitter(0.3), Build.jitter(3), Build.jitter(0.3)),
				ice,
				Enum.Material.Glass,
				m
			)
			p.Transparency = 0.3
		end
		local glow = Build.ball(1.2, CFrame.new(pos + Vector3.new(0, 1, 0)), ice, Enum.Material.Neon, m)
		Build.light(glow, ice, 12, 0.8)
	end)
	for _, x in { -20, 20 } do
		for _, z in { 20, 34 } do
			pillar(c + Vector3.new(x, 0, z), 12, 1.2, Color3.fromRGB(225, 235, 245), false, zf)
		end
	end
	Build.wedge(
		Vector3.new(50, 6, 10),
		CFrame.new(c + Vector3.new(0, 16.5, 32)) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(200, 220, 240),
		Enum.Material.Ice,
		zf
	)
	Build.wedge(
		Vector3.new(50, 6, 10),
		CFrame.new(c + Vector3.new(0, 16.5, 22)),
		Color3.fromRGB(200, 220, 240),
		Enum.Material.Ice,
		zf
	)
	local snow = Build.part({
		Size = Vector3.new(90, 1, 90),
		Position = c + Vector3.new(0, 30, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, zf)
	Build.particles(snow, {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Rate = 40,
		Size = NumberSequence.new(0.35),
		Speed = NumberRange.new(4, 7),
		Lifetime = NumberRange.new(5, 8),
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0, -2, 0),
		EmissionDirection = Enum.NormalId.Bottom,
	})
end

-- 6 Volcanic Dojo: lava pools with glow + embers, black rocks, an orange dojo gate
dressers[6] = function(zf, c)
	local lava = Color3.fromRGB(255, 110, 20)
	for _, off in { Vector3.new(-30, 0, -20), Vector3.new(28, 0, 10), Vector3.new(-10, 0, 36), Vector3.new(34, 0, -34) } do
		local pos = c + off
		local pool =
			Build.cyl(Vector3.new(14, 0.5, 14), CFrame.new(pos + Vector3.new(0, 0.25, 0)), lava, Enum.Material.Neon, zf)
		pool.CanCollide = false
		Build.light(pool, lava, 22, 1.5)
		Build.particles(pool, {
			Color = ColorSequence.new(Color3.fromRGB(255, 160, 40)),
			Rate = 10,
			Size = NumberSequence.new(0.5),
			Speed = NumberRange.new(3, 6),
			Lifetime = NumberRange.new(1, 2),
			Acceleration = Vector3.new(0, 4, 0),
		})
		Build.cyl(
			Vector3.new(16, 0.4, 16),
			CFrame.new(pos + Vector3.new(0, 0.2, 0)),
			Color3.fromRGB(35, 30, 30),
			Enum.Material.Basalt,
			zf
		).CanCollide =
			false
	end
	scatter(12, c, 6, function(pos)
		Build.rock(pos + Vector3.new(0, 1.5, 0), Vector3.new(4, 3.5, 4), Color3.fromRGB(40, 35, 35), zf)
	end)
	torii(c + Vector3.new(0, 0, -34), Color3.fromRGB(255, 120, 40), 1.4, zf)
	scatter(6, c, 10, function(pos)
		lantern(pos, Color3.fromRGB(255, 120, 40), zf)
	end)
end

-- 7 Abyss Shrine: coral, shells, a pagoda shrine, bubbles
dressers[7] = function(zf, c)
	local corals = {
		Color3.fromRGB(255, 120, 150),
		Color3.fromRGB(255, 180, 80),
		Color3.fromRGB(150, 100, 255),
		Color3.fromRGB(80, 230, 200),
	}
	scatter(22, c, 5, function(pos)
		local m = Build.model("Coral", zf)
		local col = Build.pick(corals)
		for _ = 1, 4 do
			local h = Build.rng:NextNumber(2, 6)
			Build.cyl(
				Vector3.new(0.7, h, 0.7),
				CFrame.new(pos + Vector3.new(Build.jitter(1.2), h / 2, Build.jitter(1.2)))
					* CFrame.Angles(Build.jitter(0.4), 0, Build.jitter(0.4)),
				col,
				Enum.Material.SmoothPlastic,
				m
			)
		end
		Build.ball(
			1.6,
			CFrame.new(pos + Vector3.new(0, 0.6, 0)),
			col:Lerp(Color3.new(1, 1, 1), 0.3),
			Enum.Material.SmoothPlastic,
			m
		)
	end)
	-- shrine
	local sp = c + Vector3.new(0, 0, 36)
	Build.block(
		Vector3.new(16, 1, 12),
		CFrame.new(sp + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(70, 90, 120),
		Enum.Material.Slate,
		zf
	)
	for _, x in { -6, 6 } do
		for _, z in { -4, 4 } do
			Build.cyl(
				Vector3.new(1, 8, 1),
				CFrame.new(sp + Vector3.new(x, 5, z)),
				Color3.fromRGB(40, 60, 110),
				Enum.Material.Wood,
				zf
			)
		end
	end
	Build.wedge(
		Vector3.new(18, 4, 7),
		CFrame.new(sp + Vector3.new(0, 11, 3.5)) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(30, 90, 160),
		Enum.Material.Slate,
		zf
	)
	Build.wedge(
		Vector3.new(18, 4, 7),
		CFrame.new(sp + Vector3.new(0, 11, -3.5)),
		Color3.fromRGB(30, 90, 160),
		Enum.Material.Slate,
		zf
	)
	local orb =
		Build.ball(2.5, CFrame.new(sp + Vector3.new(0, 4, 0)), Color3.fromRGB(80, 230, 255), Enum.Material.Neon, zf)
	Build.light(orb, Color3.fromRGB(80, 230, 255), 20, 1.5)
	Build.hover(orb, 1, 3, true)
	local bubbles = Build.part({
		Size = Vector3.new(90, 1, 90),
		Position = c + Vector3.new(0, 0.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, zf)
	Build.particles(bubbles, {
		Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)),
		Rate = 12,
		Size = NumberSequence.new(0.4),
		Speed = NumberRange.new(2, 4),
		Lifetime = NumberRange.new(3, 5),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(15, 15),
	})
end

-- 8 Ancient Ruins: broken pillars, crumbled walls, rubble
dressers[8] = function(zf, c)
	local stone = Color3.fromRGB(205, 190, 150)
	for i = 0, 5 do
		pillar(c + Vector3.new(-30, 0, -40 + i * 16), 14, 1.6, stone, i % 2 == 1, zf)
		pillar(c + Vector3.new(30, 0, -40 + i * 16), 14, 1.6, stone, i % 3 == 0, zf)
	end
	for _, off in { Vector3.new(-40, 0, 20), Vector3.new(40, 0, -10), Vector3.new(-42, 0, -30) } do
		local h = Build.rng:NextNumber(4, 8)
		Build.block(
			Vector3.new(12, h, 2),
			CFrame.new(c + off + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, Build.jitter(0.6), 0),
			stone:Lerp(Color3.new(0, 0, 0), 0.1),
			Enum.Material.Cobblestone,
			zf
		)
	end
	scatter(18, c, 4, function(pos)
		Build.block(
			Vector3.new(Build.rng:NextNumber(1, 3), Build.rng:NextNumber(0.8, 2), Build.rng:NextNumber(1, 3)),
			CFrame.new(pos + Vector3.new(0, 0.6, 0))
				* CFrame.Angles(Build.jitter(0.3), Build.jitter(3), Build.jitter(0.3)),
			stone,
			Enum.Material.Limestone,
			zf
		)
	end)
	-- altar on the raised terrain step
	local altar = Build.block(
		Vector3.new(6, 2, 4),
		CFrame.new(c + Vector3.new(0, 3, 30)),
		stone:Lerp(Color3.new(0, 0, 0), 0.2),
		Enum.Material.Limestone,
		zf
	)
	Build.label(altar, "⛩ Ancient Altar", Color3.fromRGB(255, 220, 150), 3)
end

-- 9 Celestial Gate: floating white platforms, stars, a golden gate
dressers[9] = function(zf, c)
	local white = Color3.fromRGB(245, 245, 255)
	local gold = Color3.fromRGB(255, 215, 90)
	scatter(10, c, 8, function(pos)
		local y = Build.rng:NextNumber(4, 12)
		local plat = Build.block(
			Vector3.new(Build.rng:NextNumber(6, 10), 1.2, Build.rng:NextNumber(6, 10)),
			CFrame.new(pos + Vector3.new(0, y, 0)),
			white,
			Enum.Material.Marble,
			zf
		)
		Build.hover(plat, 1.5, Build.rng:NextNumber(4, 7))
	end)
	scatter(24, c, 4, function(pos)
		local star = Build.ball(
			0.9,
			CFrame.new(pos + Vector3.new(0, Build.rng:NextNumber(6, 22), 0)),
			gold,
			Enum.Material.Neon,
			zf
		)
		star.CanCollide = false
		Build.light(star, gold, 10, 0.7)
		Build.particles(star, {
			Color = ColorSequence.new(gold),
			Rate = 2,
			Size = NumberSequence.new(0.5),
			Speed = NumberRange.new(0.5, 1),
		})
		Build.hover(star, 1, Build.rng:NextNumber(2, 4))
	end)
	-- the gate itself
	local gp = c + Vector3.new(0, 0, 36)
	for _, x in { -9, 9 } do
		Build.cyl(Vector3.new(2.4, 22, 2.4), CFrame.new(gp + Vector3.new(x, 11, 0)), white, Enum.Material.Marble, zf)
		Build.ball(3.4, CFrame.new(gp + Vector3.new(x, 23, 0)), gold, Enum.Material.Neon, zf)
	end
	Build.block(Vector3.new(24, 2.5, 3), CFrame.new(gp + Vector3.new(0, 24.5, 0)), gold, Enum.Material.Metal, zf)
	local portal = Build.block(
		Vector3.new(15, 18, 0.5),
		CFrame.new(gp + Vector3.new(0, 11, 0)),
		Color3.fromRGB(200, 220, 255),
		Enum.Material.Neon,
		zf
	)
	portal.Transparency = 0.5
	portal.CanCollide = false
	Build.light(portal, Color3.fromRGB(200, 220, 255), 30, 2)
end

-- 10 Sakura Void: cherry trees, falling petals, pink runes, a dark canopy overhead
dressers[10] = function(zf, c)
	local pink = Color3.fromRGB(255, 150, 200)
	scatter(14, c, 7, function(pos)
		Build.tree(pos, Build.rng:NextNumber(8, 13), pink, Color3.fromRGB(50, 35, 50), zf)
	end)
	scatter(10, c, 6, function(pos)
		local rune =
			Build.cyl(Vector3.new(4, 0.2, 4), CFrame.new(pos + Vector3.new(0, 0.15, 0)), pink, Enum.Material.Neon, zf)
		rune.CanCollide = false
		rune.Transparency = 0.3
		Build.light(rune, pink, 12, 0.8)
	end)
	-- dark canopy: big black slabs high up with tiny stars
	local canopy = Build.block(
		Vector3.new(120, 2, 110),
		CFrame.new(c + Vector3.new(0, 45, 0)),
		Color3.fromRGB(15, 10, 25),
		Enum.Material.SmoothPlastic,
		zf
	)
	canopy.CanCollide = false
	for _ = 1, 30 do
		local s = Build.ball(
			0.5,
			CFrame.new(c + Vector3.new(Build.jitter(55), 43.5, Build.jitter(50))),
			Color3.fromRGB(255, 220, 240),
			Enum.Material.Neon,
			zf
		)
		s.CanCollide = false
	end
	local petals = Build.part({
		Size = Vector3.new(90, 1, 90),
		Position = c + Vector3.new(0, 36, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, zf)
	Build.particles(petals, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 210), Color3.fromRGB(255, 120, 180)),
		Rate = 50,
		Size = NumberSequence.new(0.55),
		Speed = NumberRange.new(3, 5),
		Lifetime = NumberRange.new(7, 10),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(1.5, -2, 0),
		EmissionDirection = Enum.NormalId.Bottom,
		RotSpeed = NumberRange.new(-90, 90),
		LightEmission = 0.4,
	})
	-- dark lanterns
	scatter(6, c, 10, function(pos)
		lantern(pos, pink, zf)
	end)
end

--------------------------------------------------------------------------------

function Zones.build(parent: Folder, def: ZonesConfig.ZoneDef, index: number)
	local cz = Layout.zoneCenterZ(index)
	local center = Vector3.new(0, G, cz)
	local zf = Build.folder(def.folderName, parent)
	local color = def.boss.color

	Build.part({
		Name = "Bounds",
		Size = Vector3.new(Layout.ZONE_SIZE, 50, Layout.ZONE_SIZE),
		Position = center + Vector3.new(0, 25, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, zf)

	-- Entrance: a full-width glowing barrier with a torii-style portal arch in the middle
	local frontZ = cz - HALF
	local entrance = Build.part({
		Name = "Entrance",
		Size = Vector3.new(Layout.ZONE_SIZE, 18, 1.5),
		Position = center + Vector3.new(0, 9, -HALF),
		Color = color,
		Material = Enum.Material.ForceField,
		Transparency = 0.3,
		CanCollide = true,
		CanTouch = false,
	}, zf)
	Build.particles(entrance, {
		Color = ColorSequence.new(color),
		Rate = 14,
		Size = NumberSequence.new(0.7),
		Speed = NumberRange.new(1, 2),
		Lifetime = NumberRange.new(1.5, 3),
	})
	local deco = Build.folder("Deco", zf)
	torii(Vector3.new(0, G, frontZ), color, 1.5, deco)
	for _, x in { -12, 12 } do
		local lamp = Build.ball(2, CFrame.new(Vector3.new(x, G + 3, frontZ - 4)), color, Enum.Material.Neon, deco)
		Build.light(lamp, color, 16, 1.2)
		Build.cyl(
			Vector3.new(1, 2.5, 1),
			CFrame.new(Vector3.new(x, G + 1.25, frontZ - 4)),
			Color3.fromRGB(60, 60, 65),
			Enum.Material.Slate,
			deco
		)
	end
	-- zone name sign above the arch
	local signPart = Build.part({
		Name = "ZoneSign",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, G + 21, frontZ),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, deco)
	Build.label(signPart, `{def.id}. {def.name}`, Color3.new(1, 1, 1), 0, 340, 260)

	-- Boss spawn: a dark stone circle with a glowing rune
	local bossPos = center + Vector3.new(0, 0, HALF - 10)
	Build.cyl(
		Vector3.new(10, 0.5, 10),
		CFrame.new(bossPos + Vector3.new(0, 0.25, 0)),
		Color3.fromRGB(45, 40, 45),
		Enum.Material.Slate,
		deco
	)
	local rune = Build.cyl(
		Vector3.new(7, 0.3, 7),
		CFrame.new(bossPos + Vector3.new(0, 0.55, 0)),
		color,
		Enum.Material.Neon,
		deco
	)
	rune.Transparency = 0.4
	Build.light(rune, color, 16, 1)
	Build.part({
		Name = "BossSpawn",
		Size = Vector3.new(6, 0.6, 6),
		Position = bossPos + Vector3.new(0, 0.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, zf)

	-- Nests: four pedestals
	local nests = Build.folder("Nests", zf)
	local offsets =
		{ Vector3.new(-28, 0, -18), Vector3.new(28, 0, -18), Vector3.new(-24, 0, 18), Vector3.new(24, 0, 18) }
	for i, off in offsets do
		local top = pedestal(center + off, color, deco)
		local nest = Build.part({
			Name = "Nest" .. i,
			Size = Vector3.new(3, 0.4, 3),
			Position = top.Position + Vector3.new(0, 0.2, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}, nests)
		nest.Name = "Nest" .. i
	end

	local patrol = Build.folder("PatrolPoints", zf)
	for i, off in
		{
			Vector3.new(-32, 0, 30),
			Vector3.new(32, 0, 30),
			Vector3.new(0, 0, 0),
			Vector3.new(-30, 0, -30),
			Vector3.new(30, 0, -30),
		}
	do
		Build.part({
			Name = "P" .. i,
			Size = Vector3.new(2, 1, 2),
			Position = center + off + Vector3.new(0, 1, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}, patrol)
	end

	local dress = dressers[def.id]
	if dress then
		dress(deco, center, def)
	end
end

function Zones.buildAll(parent: Folder)
	for i, def in Config.Zones.List do
		Zones.build(parent, def, i)
	end
end

return Zones
