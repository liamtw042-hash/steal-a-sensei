--!strict
--[[
	Hub: the central plaza. Spawn pad, fuse machine, shop stall, rebirth shrine, rift portal,
	index board. Props carry a ProximityPrompt with a `HubAction` attribute the client uses
	to open the matching window.
]]
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.Layout)

local Hub = {}

local G = Layout.G
local STONE = Color3.fromRGB(165, 160, 165)
local WOOD = Color3.fromRGB(150, 105, 65)

local function prompt(part: BasePart, action: string, text: string, object: string)
	local p = Instance.new("ProximityPrompt")
	p.Name = "HubPrompt"
	p.ActionText = text
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	p.Parent = part
	part:SetAttribute("HubAction", action)
end

local function fuseMachine(cf: CFrame, parent: Instance)
	local m = Build.model("FuseMachine", parent)
	Build.block(Vector3.new(10, 1, 8), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(70, 70, 80), Enum.Material.Metal, m)
	local body = Build.block(
		Vector3.new(7, 7, 6),
		cf * CFrame.new(0, 4.5, 0),
		Color3.fromRGB(110, 90, 200),
		Enum.Material.Metal,
		m
	)
	Build.block(
		Vector3.new(7.4, 0.8, 6.4),
		cf * CFrame.new(0, 8.3, 0),
		Color3.fromRGB(60, 50, 110),
		Enum.Material.Metal,
		m
	)
	-- hopper funnel
	Build.cyl(Vector3.new(5, 2.5, 5), cf * CFrame.new(0, 9.9, 0), Color3.fromRGB(190, 190, 200), Enum.Material.Metal, m)
	Build.cyl(
		Vector3.new(3.4, 2.7, 3.4),
		cf * CFrame.new(0, 9.9, 0),
		Color3.fromRGB(40, 40, 50),
		Enum.Material.Metal,
		m
	)
	-- glowing core window
	local core = Build.cyl(
		Vector3.new(3.5, 0.6, 3.5),
		cf * CFrame.new(0, 4.5, 3.1) * CFrame.Angles(math.rad(90), 0, 0),
		Color3.fromRGB(255, 120, 220),
		Enum.Material.Neon,
		m
	)
	Build.light(core, Color3.fromRGB(255, 120, 220), 16, 1.5)
	Build.particles(core, {
		Color = ColorSequence.new(Color3.fromRGB(255, 140, 230)),
		Rate = 8,
		Size = NumberSequence.new(0.5),
		Speed = NumberRange.new(2, 4),
	})
	-- pipes
	for _, x in { -2.4, 2.4 } do
		Build.cyl(
			Vector3.new(0.9, 6, 0.9),
			cf * CFrame.new(x, 4, -3.4),
			Color3.fromRGB(200, 200, 210),
			Enum.Material.Metal,
			m
		)
	end
	Build.label(body, "⚗ FUSE MACHINE\n3 identical → next rarity", Color3.fromRGB(255, 160, 240), 7, 260)
	prompt(body, "Fuse", "Open", "Fuse Machine")
end

local function shopStall(cf: CFrame, parent: Instance)
	local m = Build.model("ShopStall", parent)
	Build.block(Vector3.new(12, 3, 4), cf * CFrame.new(0, 1.5, 0), WOOD, Enum.Material.WoodPlanks, m)
	Build.block(
		Vector3.new(12.6, 0.4, 4.6),
		cf * CFrame.new(0, 3.2, 0),
		WOOD:Lerp(Color3.new(0, 0, 0), 0.2),
		Enum.Material.Wood,
		m
	)
	for _, x in { -5.5, 5.5 } do
		Build.block(Vector3.new(0.6, 9, 0.6), cf * CFrame.new(x, 4.5, -1.5), WOOD, Enum.Material.Wood, m)
	end
	-- striped awning
	for i = 0, 5 do
		local col = if i % 2 == 0 then Color3.fromRGB(255, 90, 120) else Color3.fromRGB(255, 240, 240)
		Build.wedge(
			Vector3.new(2.2, 2, 6),
			cf * CFrame.new(-5.5 + i * 2.2, 10, -1) * CFrame.Angles(0, math.pi, 0),
			col,
			Enum.Material.Fabric,
			m
		)
	end
	-- goods on the counter
	for i = -1, 1 do
		local orb = Build.ball(
			1.2,
			cf * CFrame.new(i * 3, 3.9, 0.5),
			Build.pick({ Color3.fromRGB(255, 200, 60), Color3.fromRGB(90, 210, 255), Color3.fromRGB(150, 130, 255) }),
			Enum.Material.Neon,
			m
		)
		Build.light(orb, orb.Color, 6, 0.6)
	end
	local counter = m:FindFirstChildWhichIsA("BasePart") :: BasePart
	Build.label(counter, "🛒 SHOP", Color3.fromRGB(255, 220, 90), 9, 160)
	prompt(counter, "Shop", "Open", "Shop")
end

local function rebirthShrine(cf: CFrame, parent: Instance)
	local m = Build.model("RebirthShrine", parent)
	local pink = Color3.fromRGB(255, 105, 150)
	for i = 0, 2 do
		local s = 14 - i * 3
		Build.block(
			Vector3.new(s, 1, s),
			cf * CFrame.new(0, 0.5 + i, 0),
			STONE:Lerp(Color3.new(1, 1, 1), i * 0.1),
			Enum.Material.Slate,
			m
		)
	end
	for _, x in { -4, 4 } do
		Build.cyl(
			Vector3.new(1.2, 9, 1.2),
			cf * CFrame.new(x, 7.5, 0),
			Color3.fromRGB(190, 40, 50),
			Enum.Material.SmoothPlastic,
			m
		)
	end
	Build.block(
		Vector3.new(12, 0.9, 1.2),
		cf * CFrame.new(0, 12.3, 0),
		Color3.fromRGB(150, 30, 40),
		Enum.Material.SmoothPlastic,
		m
	)
	Build.block(
		Vector3.new(9.5, 0.7, 1),
		cf * CFrame.new(0, 10.6, 0),
		Color3.fromRGB(190, 40, 50),
		Enum.Material.SmoothPlastic,
		m
	)
	local orb = Build.ball(3, cf * CFrame.new(0, 6.5, 0), pink, Enum.Material.Neon, m)
	Build.light(orb, pink, 22, 2)
	Build.particles(orb, {
		Color = ColorSequence.new(pink, Color3.fromRGB(255, 200, 230)),
		Rate = 15,
		Size = NumberSequence.new(0.6),
		Speed = NumberRange.new(2, 5),
		Lifetime = NumberRange.new(1.5, 3),
	})
	Build.hover(orb, 0.8, 2.5, true)
	Build.tree(cf.Position + Vector3.new(-9, 0, -4), 8, pink, Color3.fromRGB(70, 45, 55), m)
	Build.tree(cf.Position + Vector3.new(9, 0, -4), 7, pink, Color3.fromRGB(70, 45, 55), m)
	Build.label(orb, "🌸 REBIRTH SHRINE", pink, 5, 220)
	prompt(orb, "Rebirth", "Open", "Rebirth Shrine")
end

local function riftPortal(cf: CFrame, parent: Instance): BasePart
	local m = Build.model("RiftPortal", parent)
	local purple = Color3.fromRGB(160, 70, 255)
	local ring = Build.cyl(
		Vector3.new(16, 1.6, 16),
		cf * CFrame.new(0, 9, 0) * CFrame.Angles(math.rad(90), 0, 0),
		Color3.fromRGB(50, 30, 70),
		Enum.Material.Slate,
		m
	)
	local inner = Build.cyl(
		Vector3.new(13, 1.8, 13),
		cf * CFrame.new(0, 9, 0) * CFrame.Angles(math.rad(90), 0, 0),
		purple,
		Enum.Material.Neon,
		m
	)
	inner.Transparency = 0.35
	inner.CanCollide = false
	Build.light(inner, purple, 30, 2)
	Build.spin(inner, 6)
	Build.particles(inner, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(purple, Color3.fromRGB(255, 120, 255)),
		Rate = 30,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0.2) }),
		Speed = NumberRange.new(3, 6),
		Lifetime = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(360, 360),
		RotSpeed = NumberRange.new(-200, 200),
		LightEmission = 1,
	})
	-- stone base + steps
	Build.cyl(Vector3.new(20, 1, 20), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(60, 50, 80), Enum.Material.Slate, m)
	for _, a in { 0, 90, 180, 270 } do
		local spike = Build.wedge(
			Vector3.new(2, 6, 2),
			cf * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 4, 8.5),
			Color3.fromRGB(80, 60, 110),
			Enum.Material.Slate,
			m
		)
		spike.CastShadow = false
	end
	Build.label(ring, "RIFT PORTAL\nopens every 30 min", Color3.fromRGB(220, 170, 255), 10, 240)
	return ring
end

local function indexBoard(cf: CFrame, parent: Instance)
	local m = Build.model("IndexBoard", parent)
	for _, x in { -5, 5 } do
		Build.block(Vector3.new(0.8, 9, 0.8), cf * CFrame.new(x, 4.5, 0), WOOD, Enum.Material.Wood, m)
	end
	local board = Build.block(
		Vector3.new(11, 6, 0.6),
		cf * CFrame.new(0, 6, 0),
		Color3.fromRGB(40, 40, 60),
		Enum.Material.SmoothPlastic,
		m
	)
	Build.block(
		Vector3.new(11.6, 0.6, 1),
		cf * CFrame.new(0, 9.3, 0),
		WOOD:Lerp(Color3.new(0, 0, 0), 0.2),
		Enum.Material.Wood,
		m
	)
	-- little coloured "cards" on the board
	local cols = {
		Color3.fromRGB(190, 190, 190),
		Color3.fromRGB(110, 210, 110),
		Color3.fromRGB(80, 150, 255),
		Color3.fromRGB(190, 90, 255),
		Color3.fromRGB(255, 190, 40),
		Color3.fromRGB(255, 80, 120),
		Color3.fromRGB(80, 80, 100),
	}
	for i, col in cols do
		Build.block(
			Vector3.new(1.2, 1.6, 0.2),
			cf * CFrame.new(-4.2 + (i - 1) * 1.4, 6.5, 0.4),
			col,
			Enum.Material.Neon,
			m
		)
	end
	Build.label(board, "📖 INDEX", Color3.fromRGB(150, 220, 255), 4.5, 160)
	prompt(board, "Index", "Open", "Index Board")
end

function Hub.build(mapFolder: Folder)
	local hub = Layout.HUB
	local deco = Build.folder("Hub", mapFolder)

	-- plaza: big stone disc with a lighter ring and a path south to the bases
	Build.cyl(
		Vector3.new(Layout.HUB_RADIUS * 2, 0.5, Layout.HUB_RADIUS * 2),
		CFrame.new(hub + Vector3.new(0, 0.25, 0)),
		STONE,
		Enum.Material.Cobblestone,
		deco
	)
	local ring = Build.cyl(
		Vector3.new(Layout.HUB_RADIUS * 2 + 4, 0.4, Layout.HUB_RADIUS * 2 + 4),
		CFrame.new(hub + Vector3.new(0, 0.2, 0)),
		Color3.fromRGB(120, 115, 125),
		Enum.Material.Cobblestone,
		deco
	)
	ring.CanCollide = false
	Build.block(
		Vector3.new(380, 0.4, 14),
		CFrame.new(Vector3.new(0, G + 0.2, Layout.BASE_Z + Layout.BASE_D / 2 + 12)),
		STONE,
		Enum.Material.Cobblestone,
		deco
	)
	Build.block(
		Vector3.new(14, 0.4, 60),
		CFrame.new(Vector3.new(0, G + 0.2, (hub.Z + Layout.BASE_Z + Layout.BASE_D / 2 + 12) / 2)),
		STONE,
		Enum.Material.Cobblestone,
		deco
	)

	-- named spawn parts the scripts look for
	local spawnPad = Build.part({
		Name = "Spawn",
		Size = Vector3.new(12, 0.5, 12),
		Position = Layout.SPAWN + Vector3.new(0, 0.25, 0),
		Color = Color3.fromRGB(255, 220, 120),
		Material = Enum.Material.Fabric,
	}, mapFolder)
	Build.cyl(
		Vector3.new(14, 0.3, 14),
		CFrame.new(Layout.SPAWN + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(255, 240, 200),
		Enum.Material.SmoothPlastic,
		deco
	).Transparency =
		0.5
	Build.label(spawnPad, "SPAWN", Color3.fromRGB(255, 240, 200), 3, 120)

	local portalRing = riftPortal(CFrame.new(hub + Vector3.new(0, 0, 14)), deco)
	Build.part({
		Name = "RiftSpawn",
		Size = Vector3.new(6, 0.5, 6),
		Position = hub + Vector3.new(0, 0.5, 4),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, mapFolder)
	Build.part({
		Name = "HungrySenseiSpawn",
		Size = Vector3.new(6, 0.5, 6),
		Position = Vector3.new(90, G + 0.5, Layout.HUB.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, mapFolder)
	local _ = portalRing

	fuseMachine(CFrame.new(hub + Vector3.new(-26, 0, -6)) * CFrame.Angles(0, math.rad(35), 0), deco)
	shopStall(CFrame.new(hub + Vector3.new(26, 0, -6)) * CFrame.Angles(0, math.rad(-35), 0), deco)
	rebirthShrine(CFrame.new(hub + Vector3.new(-30, 0, 22)) * CFrame.Angles(0, math.rad(40), 0), deco)
	indexBoard(CFrame.new(hub + Vector3.new(30, 0, 22)) * CFrame.Angles(0, math.rad(-40), 0), deco)

	-- lamps + trees around the plaza
	for a = 0, 315, 45 do
		local r = Layout.HUB_RADIUS + 6
		local pos = hub + Vector3.new(math.cos(math.rad(a)) * r, 0, math.sin(math.rad(a)) * r)
		if a % 90 == 0 then
			Build.tree(
				pos,
				8,
				Build.pick({
					Color3.fromRGB(90, 200, 100),
					Color3.fromRGB(255, 150, 200),
					Color3.fromRGB(120, 220, 140),
				}),
				nil,
				deco
			)
		else
			local post = Build.cyl(
				Vector3.new(0.8, 8, 0.8),
				CFrame.new(pos + Vector3.new(0, 4, 0)),
				Color3.fromRGB(60, 60, 70),
				Enum.Material.Metal,
				deco
			)
			local lamp = Build.ball(
				2,
				post.CFrame * CFrame.new(0, 4.8, 0),
				Color3.fromRGB(255, 235, 190),
				Enum.Material.Neon,
				deco
			)
			Build.light(lamp, Color3.fromRGB(255, 235, 190), 18, 1)
		end
	end
	-- direction sign to the zones
	local sign = Build.block(
		Vector3.new(8, 2, 0.5),
		CFrame.new(Vector3.new(14, G + 6, hub.Z + Layout.HUB_RADIUS + 4)),
		WOOD,
		Enum.Material.Wood,
		deco
	)
	Build.block(
		Vector3.new(0.6, 6, 0.6),
		CFrame.new(Vector3.new(14, G + 3, hub.Z + Layout.HUB_RADIUS + 4)),
		WOOD,
		Enum.Material.Wood,
		deco
	)
	Build.label(sign, "⬆ ZONES THIS WAY", Color3.fromRGB(255, 240, 200), 1.5, 220)
end

return Hub
