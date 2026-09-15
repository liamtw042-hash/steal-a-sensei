--!strict
--[[
	Bases: fenced plots on grass. Each base gets its own fence colour, a stone path,
	glowing lock pad, laser-beam gate (Lasers folder, beams toggled by BaseService),
	subtle slot pads, a treadmill prop and a spawn mat. Every named part the scripts
	expect is created here (see docs/STUDIO_CHECKLIST.md).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.Layout)

local Bases = {}

local FenceColors = {
	Color3.fromRGB(255, 110, 110),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(255, 230, 90),
	Color3.fromRGB(120, 230, 120),
	Color3.fromRGB(90, 210, 255),
	Color3.fromRGB(150, 130, 255),
	Color3.fromRGB(255, 130, 220),
	Color3.fromRGB(255, 255, 255),
}

local STONE = Color3.fromRGB(150, 150, 160)

local function invisibleWall(size: Vector3, cf: CFrame, parent: Instance)
	Build.part(
		{ Size = size, CFrame = cf, Transparency = 1, CanCollide = true, CanQuery = false, Name = "Wall" },
		parent
	)
end

local function treadmill(cf: CFrame, parent: Instance): Part
	local m = Build.model("TreadmillProp", parent)
	local base = Build.block(
		Vector3.new(6, 0.6, 9),
		cf * CFrame.new(0, 0.3, 0),
		Color3.fromRGB(60, 60, 70),
		Enum.Material.Metal,
		m
	)
	Build.block(
		Vector3.new(4.6, 0.3, 7.4),
		cf * CFrame.new(0, 0.75, 0),
		Color3.fromRGB(35, 35, 40),
		Enum.Material.Fabric,
		m
	) -- belt
	for _, z in { -3.9, 3.9 } do
		Build.cyl(
			Vector3.new(0.9, 5, 0.9),
			cf * CFrame.new(0, 0.75, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(200, 200, 210),
			Enum.Material.Metal,
			m
		)
	end
	-- handrail + console
	for _, x in { -2.6, 2.6 } do
		Build.block(
			Vector3.new(0.3, 3, 0.3),
			cf * CFrame.new(x, 1.8, -3.5),
			Color3.fromRGB(200, 200, 210),
			Enum.Material.Metal,
			m
		)
	end
	Build.block(
		Vector3.new(5.5, 0.3, 0.3),
		cf * CFrame.new(0, 3.3, -3.5),
		Color3.fromRGB(200, 200, 210),
		Enum.Material.Metal,
		m
	)
	local screen = Build.block(
		Vector3.new(3, 1.6, 0.3),
		cf * CFrame.new(0, 3.6, -3.6),
		Color3.fromRGB(80, 220, 255),
		Enum.Material.Neon,
		m
	)
	Build.light(screen, Color3.fromRGB(80, 220, 255), 8, 1)
	Build.label(screen, "TREADMILL", Color3.fromRGB(80, 220, 255), 2, 110, 45)
	return base
end

local function lockPad(cf: CFrame, parent: Instance): Part
	local m = Build.model("LockPadProp", parent)
	Build.cyl(
		Vector3.new(6.4, 0.5, 6.4),
		cf * CFrame.new(0, 0.25, 0),
		Color3.fromRGB(60, 55, 40),
		Enum.Material.Metal,
		m
	)
	local ring = Build.cyl(
		Vector3.new(6, 0.6, 6),
		cf * CFrame.new(0, 0.35, 0),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.Neon,
		m
	)
	Build.cyl(
		Vector3.new(4.2, 0.7, 4.2),
		cf * CFrame.new(0, 0.4, 0),
		Color3.fromRGB(50, 45, 35),
		Enum.Material.Metal,
		m
	)
	local core = Build.cyl(
		Vector3.new(1.6, 0.8, 1.6),
		cf * CFrame.new(0, 0.45, 0),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.Neon,
		m
	)
	Build.light(core, Color3.fromRGB(255, 200, 60), 10, 1.2)
	Build.particles(core, {
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 90)),
		Rate = 4,
		Size = NumberSequence.new(0.4),
		Speed = NumberRange.new(2, 3),
	})
	Build.label(core, "🔒 LOCK", Color3.fromRGB(255, 220, 90), 3.5, 90, 45)
	return ring
end

function Bases.build(parent: Folder, index: number)
	local G = Layout.G
	local w, d = Layout.BASE_W, Layout.BASE_D
	local cx = Layout.baseX(index)
	local cz = Layout.BASE_Z
	local center = Vector3.new(cx, G, cz)
	local color = FenceColors[((index - 1) % #FenceColors) + 1]
	local bf = Build.folder("Base" .. index, parent)

	-- Region + invisible walls (front has a 12-stud gate opening)
	Build.part({
		Name = "Region",
		Size = Vector3.new(w, 26, d),
		Position = center + Vector3.new(0, 13, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, bf)
	local hw, hd = w / 2, d / 2
	invisibleWall(Vector3.new(1, 14, d), CFrame.new(center + Vector3.new(-hw, 7, 0)), bf)
	invisibleWall(Vector3.new(1, 14, d), CFrame.new(center + Vector3.new(hw, 7, 0)), bf)
	invisibleWall(Vector3.new(w, 14, 1), CFrame.new(center + Vector3.new(0, 7, -hd)), bf)
	invisibleWall(Vector3.new((w - 12) / 2, 14, 1), CFrame.new(center + Vector3.new(-(hw + 6) / 2, 7, hd)), bf)
	invisibleWall(Vector3.new((w - 12) / 2, 14, 1), CFrame.new(center + Vector3.new((hw + 6) / 2, 7, hd)), bf)

	-- Fences (front has the gap)
	local deco = Build.folder("Deco", bf)
	local c00 = center + Vector3.new(-hw, 0, -hd)
	local c10 = center + Vector3.new(hw, 0, -hd)
	local c01 = center + Vector3.new(-hw, 0, hd)
	local c11 = center + Vector3.new(hw, 0, hd)
	Build.fence(c00, c10, color, deco)
	Build.fence(c00, c01, color, deco)
	Build.fence(c10, c11, color, deco)
	Build.fence(c01, center + Vector3.new(-6, 0, hd), color, deco)
	Build.fence(center + Vector3.new(6, 0, hd), c11, color, deco)

	-- Stone path from gate to the middle, and a little front porch
	Build.block(
		Vector3.new(8, 0.3, d - 6),
		CFrame.new(center + Vector3.new(0, 0.15, 3)),
		STONE,
		Enum.Material.Cobblestone,
		deco
	)
	Build.block(
		Vector3.new(12, 0.3, 8),
		CFrame.new(center + Vector3.new(0, 0.15, hd + 4)),
		STONE,
		Enum.Material.Cobblestone,
		deco
	)

	-- Gate: two tall posts, lanterns, red laser beams between them
	local gates = Build.folder("Gates", bf)
	Build.part({
		Name = "Gate",
		Size = Vector3.new(12, 12, 1),
		Position = center + Vector3.new(0, 6, hd),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
	}, gates)
	local lasers = Build.folder("Lasers", bf)
	local postL = Build.block(
		Vector3.new(1.4, 11, 1.4),
		CFrame.new(center + Vector3.new(-6.5, 5.5, hd)),
		color,
		Enum.Material.SmoothPlastic,
		deco
	)
	local postR = Build.block(
		Vector3.new(1.4, 11, 1.4),
		CFrame.new(center + Vector3.new(6.5, 5.5, hd)),
		color,
		Enum.Material.SmoothPlastic,
		deco
	)
	for _, post in { postL, postR } do
		local lamp = Build.ball(
			1.6,
			post.CFrame * CFrame.new(0, 6.2, 0),
			Color3.fromRGB(255, 240, 200),
			Enum.Material.Neon,
			deco
		)
		Build.light(lamp, Color3.fromRGB(255, 240, 200), 12, 1)
	end
	for i, y in { 1.2, 3.2, 5.2, 7.2, 9.2 } do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0.75, y - 5.5, 0)
		a0.Parent = postL
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(-0.75, y - 5.5, 0)
		a1.Parent = postR
		local beam = Instance.new("Beam")
		beam.Name = "Laser" .. i
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 40, 40))
		beam.Width0 = 0.6
		beam.Width1 = 0.6
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(0.1)
		beam.FaceCamera = true
		beam.Enabled = false
		beam.Parent = lasers
	end

	-- Entrance pad outside the gate, lock pad inside, treadmill and spawn in the corners
	Build.part({
		Name = "Entrance",
		Size = Vector3.new(8, 0.4, 6),
		Position = center + Vector3.new(0, 0.2, hd + 7),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
	}, bf)
	local pad = lockPad(CFrame.new(center + Vector3.new(0, 0, hd - 7)), deco)
	pad.Name = "LockPad"
	pad.Parent = bf
	local tm = treadmill(CFrame.new(center + Vector3.new(hw - 6, 0, hd - 8)), deco)
	tm.Name = "Treadmill"
	tm.Parent = bf
	local spawnMat = Build.cyl(
		Vector3.new(5, 0.4, 5),
		CFrame.new(center + Vector3.new(-hw + 6, 0.2, hd - 8)),
		Color3.fromRGB(120, 230, 140),
		Enum.Material.Fabric,
		bf
	)
	spawnMat.Name = "Spawn"

	-- Sign above the gate
	Build.part({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		Position = center + Vector3.new(0, 15, hd),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, bf)
	Build.block(
		Vector3.new(14, 2.2, 0.6),
		CFrame.new(center + Vector3.new(0, 12.2, hd)),
		color:Lerp(Color3.new(0, 0, 0), 0.25),
		Enum.Material.Wood,
		deco
	)

	-- Slots: subtle stone pads with a light rim, 6 per row
	local slots = Build.folder("Slots", bf)
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
			local x = -hw + 6 + col * 6.4
			local z = hd - 15 - row * 6.4
			local rim = Build.cyl(
				Vector3.new(5.4, 0.3, 5.4),
				CFrame.new(center + Vector3.new(x, 0.15, z)),
				color:Lerp(Color3.new(1, 1, 1), 0.5),
				Enum.Material.SmoothPlastic,
				deco
			)
			rim.Transparency = if floorN == 1 then 0.2 else 0.6
			local p = Build.cyl(
				Vector3.new(4.6, 0.4, 4.6),
				CFrame.new(center + Vector3.new(x, 0.25, z)),
				if floorN == 1
					then Color3.fromRGB(190, 185, 175)
					elseif floorN == 2 then Color3.fromRGB(175, 165, 190)
					else Color3.fromRGB(195, 175, 140),
				Enum.Material.Slate,
				slots
			)
			p.Name = "Slot" .. i
			p:SetAttribute("Floor", floorN)
		end
	end

	-- A couple of small trees + a lantern for warmth
	Build.tree(center + Vector3.new(-hw + 4, 0, -hd + 4), 6, color:Lerp(Color3.fromRGB(80, 200, 90), 0.7), nil, deco)
	Build.tree(center + Vector3.new(hw - 4, 0, -hd + 4), 5, color:Lerp(Color3.fromRGB(80, 200, 90), 0.7), nil, deco)
end

return Bases
