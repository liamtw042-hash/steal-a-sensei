--!strict
--[[
	BossLooks: dresses an NPC rig so each boss reads as what it is. Works on R15 rigs
	(from CreateHumanoidModelFromDescriptionAsync) and degrades gracefully on the block
	fallback rig. Accessories are plain parts welded to limbs. Also attaches the chase
	trail + aura (disabled until the boss starts chasing).
]]
local BossLooks = {}

type Piece = {
	limb: string, -- R15 limb name; falls back to Torso/Head
	shape: ("Block" | "Ball" | "Cylinder" | "Wedge")?,
	size: Vector3,
	offset: CFrame,
	color: Color3?,
	material: Enum.Material?,
	neon: boolean?,
	transparency: number?,
}

type Look = {
	scale: number,
	body: Color3,
	skin: Color3,
	pieces: { Piece },
	aura: Color3?,
	runAnim: string?,
}

local BLACK = Color3.fromRGB(30, 30, 35)
local STEEL = Color3.fromRGB(215, 220, 230)
local GOLD = Color3.fromRGB(255, 210, 80)

local function sword(limb: string, length: number, color: Color3?): { Piece }
	return {
		{
			limb = limb,
			size = Vector3.new(0.3, length, 0.8),
			offset = CFrame.new(0, -length / 2 - 0.6, 0),
			color = color or STEEL,
			material = Enum.Material.Metal,
		},
		{
			limb = limb,
			size = Vector3.new(0.5, 0.35, 1.8),
			offset = CFrame.new(0, -0.55, 0),
			color = GOLD,
			material = Enum.Material.Metal,
		},
		{
			limb = limb,
			shape = "Cylinder",
			size = Vector3.new(0.45, 1.2, 0.45),
			offset = CFrame.new(0, 0.2, 0),
			color = Color3.fromRGB(80, 40, 40),
		},
	}
end

local Looks: { [string]: Look } = {
	Brute = {
		scale = 1.7,
		body = Color3.fromRGB(150, 70, 50),
		skin = Color3.fromRGB(175, 100, 70),
		pieces = {
			{
				limb = "Head",
				shape = "Wedge",
				size = Vector3.new(0.5, 1.2, 0.5),
				offset = CFrame.new(-0.55, 0.8, 0) * CFrame.Angles(0, 0, math.rad(25)),
				color = Color3.fromRGB(240, 230, 200),
			},
			{
				limb = "Head",
				shape = "Wedge",
				size = Vector3.new(0.5, 1.2, 0.5),
				offset = CFrame.new(0.55, 0.8, 0) * CFrame.Angles(0, 0, math.rad(-25)),
				color = Color3.fromRGB(240, 230, 200),
			},
			{
				limb = "RightHand",
				shape = "Ball",
				size = Vector3.new(1.8, 1.8, 1.8),
				offset = CFrame.new(0, -0.3, 0),
				color = Color3.fromRGB(120, 55, 40),
			},
			{
				limb = "LeftHand",
				shape = "Ball",
				size = Vector3.new(1.8, 1.8, 1.8),
				offset = CFrame.new(0, -0.3, 0),
				color = Color3.fromRGB(120, 55, 40),
			},
			{
				limb = "LowerTorso",
				size = Vector3.new(2.3, 0.5, 1.3),
				offset = CFrame.new(0, 0.2, 0),
				color = GOLD,
				material = Enum.Material.Metal,
			},
			{
				limb = "UpperTorso",
				size = Vector3.new(0.6, 1.8, 1.4),
				offset = CFrame.new(-0.9, 0, 0) * CFrame.Angles(0, 0, math.rad(35)),
				color = Color3.fromRGB(90, 60, 45),
				material = Enum.Material.Fabric,
			},
		},
		aura = Color3.fromRGB(255, 100, 60),
		runAnim = "rbxassetid://616163682",
	},
	Swordsman = {
		scale = 1.1,
		body = Color3.fromRGB(70, 130, 70),
		skin = Color3.fromRGB(230, 200, 170),
		pieces = (function(): { Piece }
			local p = sword("RightHand", 3.2)
			table.insert(p, {
				limb = "Head",
				shape = "Cylinder",
				size = Vector3.new(2.8, 0.25, 2.8),
				offset = CFrame.new(0, 0.55, 0),
				color = Color3.fromRGB(215, 180, 110),
				material = Enum.Material.Fabric,
			})
			table.insert(p, {
				limb = "Head",
				shape = "Cylinder",
				size = Vector3.new(1.3, 0.6, 1.3),
				offset = CFrame.new(0, 0.9, 0),
				color = Color3.fromRGB(215, 180, 110),
				material = Enum.Material.Fabric,
			})
			table.insert(p, {
				limb = "UpperTorso",
				size = Vector3.new(2.2, 0.35, 1.2),
				offset = CFrame.new(0, -0.7, 0),
				color = BLACK,
				material = Enum.Material.Fabric,
			})
			return p
		end)(),
		aura = Color3.fromRGB(120, 230, 120),
	},
	Ninja = {
		scale = 1.0,
		body = BLACK,
		skin = BLACK,
		pieces = {
			{
				limb = "Head",
				size = Vector3.new(1.35, 0.35, 1.35),
				offset = CFrame.new(0, 0.15, 0),
				color = Color3.fromRGB(200, 40, 50),
				material = Enum.Material.Fabric,
			},
			{
				limb = "Head",
				size = Vector3.new(0.3, 0.15, 1.6),
				offset = CFrame.new(0, 0.15, -0.9) * CFrame.Angles(0, 0, math.rad(10)),
				color = Color3.fromRGB(200, 40, 50),
				material = Enum.Material.Fabric,
			},
			{
				limb = "Head",
				size = Vector3.new(1.3, 0.25, 0.3),
				offset = CFrame.new(0, 0.05, -0.62),
				color = Color3.fromRGB(255, 240, 220),
				neon = true,
			},
			{
				limb = "RightHand",
				size = Vector3.new(0.2, 1.6, 0.5),
				offset = CFrame.new(0, -1, 0),
				color = STEEL,
				material = Enum.Material.Metal,
			},
			{
				limb = "LeftHand",
				size = Vector3.new(0.2, 1.6, 0.5),
				offset = CFrame.new(0, -1, 0),
				color = STEEL,
				material = Enum.Material.Metal,
			},
			{
				limb = "UpperTorso",
				size = Vector3.new(0.5, 1.9, 0.5),
				offset = CFrame.new(0, 0.1, 0.8) * CFrame.Angles(0, 0, math.rad(45)),
				color = Color3.fromRGB(60, 40, 40),
			},
		},
		aura = Color3.fromRGB(120, 60, 200),
		runAnim = "rbxassetid://656118852",
	},
	LightningMonk = {
		scale = 1.15,
		body = Color3.fromRGB(240, 200, 70),
		skin = Color3.fromRGB(230, 190, 150),
		pieces = {
			{
				limb = "Head",
				shape = "Cylinder",
				size = Vector3.new(2.2, 0.15, 2.2),
				offset = CFrame.new(0, 1.1, 0),
				color = Color3.fromRGB(255, 240, 120),
				neon = true,
			},
			{
				limb = "RightHand",
				shape = "Cylinder",
				size = Vector3.new(0.3, 6, 0.3),
				offset = CFrame.new(0, 0, 0),
				color = Color3.fromRGB(120, 90, 50),
				material = Enum.Material.Wood,
			},
			{
				limb = "RightHand",
				shape = "Ball",
				size = Vector3.new(0.9, 0.9, 0.9),
				offset = CFrame.new(0, 3.1, 0),
				color = Color3.fromRGB(180, 230, 255),
				neon = true,
			},
			{
				limb = "UpperTorso",
				size = Vector3.new(2.3, 0.4, 1.3),
				offset = CFrame.new(0, -0.6, 0),
				color = Color3.fromRGB(200, 60, 40),
				material = Enum.Material.Fabric,
			},
		},
		aura = Color3.fromRGB(200, 230, 255),
	},
	IceWarrior = {
		scale = 1.25,
		body = Color3.fromRGB(120, 190, 240),
		skin = Color3.fromRGB(200, 230, 250),
		pieces = {
			{
				limb = "UpperTorso",
				shape = "Wedge",
				size = Vector3.new(1.2, 1.6, 1.2),
				offset = CFrame.new(-1.3, 0.9, 0) * CFrame.Angles(0, 0, math.rad(-30)),
				color = Color3.fromRGB(170, 230, 255),
				material = Enum.Material.Glass,
				transparency = 0.25,
			},
			{
				limb = "UpperTorso",
				shape = "Wedge",
				size = Vector3.new(1.2, 1.6, 1.2),
				offset = CFrame.new(1.3, 0.9, 0) * CFrame.Angles(0, 0, math.rad(30)),
				color = Color3.fromRGB(170, 230, 255),
				material = Enum.Material.Glass,
				transparency = 0.25,
			},
			{
				limb = "Head",
				shape = "Wedge",
				size = Vector3.new(0.5, 1.4, 0.5),
				offset = CFrame.new(0, 1, 0),
				color = Color3.fromRGB(200, 240, 255),
				material = Enum.Material.Glass,
				transparency = 0.2,
			},
			{
				limb = "RightHand",
				size = Vector3.new(0.4, 3.4, 1.4),
				offset = CFrame.new(0, -1.6, 0),
				color = Color3.fromRGB(180, 235, 255),
				material = Enum.Material.Glass,
				transparency = 0.2,
			},
		},
		aura = Color3.fromRGB(180, 230, 255),
	},
	FlameRonin = {
		scale = 1.2,
		body = Color3.fromRGB(60, 30, 30),
		skin = Color3.fromRGB(255, 130, 50),
		pieces = (function(): { Piece }
			local p = sword("RightHand", 3.6, Color3.fromRGB(255, 120, 40))
			table.insert(p, {
				limb = "Head",
				size = Vector3.new(1.4, 0.3, 1.4),
				offset = CFrame.new(0, 0.2, 0),
				color = Color3.fromRGB(255, 80, 20),
				neon = true,
			})
			table.insert(p, {
				limb = "UpperTorso",
				size = Vector3.new(2.4, 1.5, 0.3),
				offset = CFrame.new(0, -0.2, 0.9),
				color = Color3.fromRGB(255, 90, 30),
				material = Enum.Material.Fabric,
			})
			return p
		end)(),
		aura = Color3.fromRGB(255, 120, 30),
	},
	SeaSerpent = {
		scale = 1.3,
		body = Color3.fromRGB(30, 90, 160),
		skin = Color3.fromRGB(60, 150, 200),
		pieces = {
			{
				limb = "Head",
				shape = "Wedge",
				size = Vector3.new(0.4, 1.5, 1.2),
				offset = CFrame.new(0, 1, 0),
				color = Color3.fromRGB(80, 200, 220),
			},
			{
				limb = "UpperTorso",
				shape = "Wedge",
				size = Vector3.new(0.4, 1.8, 1.4),
				offset = CFrame.new(0, 0.6, 0.9) * CFrame.Angles(math.rad(20), 0, 0),
				color = Color3.fromRGB(80, 200, 220),
			},
			{
				limb = "LowerTorso",
				shape = "Cylinder",
				size = Vector3.new(0.9, 3.5, 0.9),
				offset = CFrame.new(0, -0.6, 2.2) * CFrame.Angles(math.rad(75), 0, 0),
				color = Color3.fromRGB(30, 90, 160),
			},
			{
				limb = "LowerTorso",
				shape = "Ball",
				size = Vector3.new(1.1, 1.1, 1.1),
				offset = CFrame.new(0, -1.4, 3.9),
				color = Color3.fromRGB(60, 150, 200),
			},
			{
				limb = "RightUpperArm",
				shape = "Wedge",
				size = Vector3.new(0.3, 1, 1.2),
				offset = CFrame.new(0.7, 0, 0) * CFrame.Angles(0, 0, math.rad(-90)),
				color = Color3.fromRGB(80, 200, 220),
			},
			{
				limb = "LeftUpperArm",
				shape = "Wedge",
				size = Vector3.new(0.3, 1, 1.2),
				offset = CFrame.new(-0.7, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
				color = Color3.fromRGB(80, 200, 220),
			},
		},
		aura = Color3.fromRGB(60, 160, 255),
	},
	StoneGolem = {
		scale = 2.1,
		body = Color3.fromRGB(110, 110, 105),
		skin = Color3.fromRGB(130, 128, 120),
		pieces = {
			{
				limb = "UpperTorso",
				size = Vector3.new(1.4, 1.4, 1.6),
				offset = CFrame.new(-1.4, 0.7, 0),
				color = Color3.fromRGB(95, 95, 90),
				material = Enum.Material.Slate,
			},
			{
				limb = "UpperTorso",
				size = Vector3.new(1.4, 1.4, 1.6),
				offset = CFrame.new(1.4, 0.7, 0),
				color = Color3.fromRGB(95, 95, 90),
				material = Enum.Material.Slate,
			},
			{
				limb = "UpperTorso",
				size = Vector3.new(0.3, 1.6, 0.15),
				offset = CFrame.new(0.3, 0, 0.55) * CFrame.Angles(0, 0, math.rad(20)),
				color = Color3.fromRGB(255, 160, 40),
				neon = true,
			},
			{
				limb = "Head",
				size = Vector3.new(1.2, 0.35, 0.2),
				offset = CFrame.new(0, 0.1, -0.6),
				color = Color3.fromRGB(255, 160, 40),
				neon = true,
			},
			{
				limb = "RightHand",
				size = Vector3.new(1.6, 1.6, 1.6),
				offset = CFrame.new(0, -0.4, 0),
				color = Color3.fromRGB(95, 95, 90),
				material = Enum.Material.Slate,
			},
			{
				limb = "LeftHand",
				size = Vector3.new(1.6, 1.6, 1.6),
				offset = CFrame.new(0, -0.4, 0),
				color = Color3.fromRGB(95, 95, 90),
				material = Enum.Material.Slate,
			},
		},
		aura = Color3.fromRGB(200, 170, 120),
		runAnim = "rbxassetid://616168032",
	},
	StarSage = {
		scale = 1.15,
		body = Color3.fromRGB(120, 80, 200),
		skin = Color3.fromRGB(240, 230, 255),
		pieces = {
			{
				limb = "Head",
				shape = "Cylinder",
				size = Vector3.new(2, 0.2, 2),
				offset = CFrame.new(0, 0.55, 0),
				color = Color3.fromRGB(80, 50, 150),
			},
			{
				limb = "Head",
				shape = "Cylinder",
				size = Vector3.new(1.1, 1.6, 1.1),
				offset = CFrame.new(0, 1.4, 0),
				color = Color3.fromRGB(80, 50, 150),
			},
			{
				limb = "Head",
				shape = "Cylinder",
				size = Vector3.new(0.6, 1.2, 0.6),
				offset = CFrame.new(0, 2.7, 0),
				color = Color3.fromRGB(80, 50, 150),
			},
			{
				limb = "Head",
				shape = "Ball",
				size = Vector3.new(0.7, 0.7, 0.7),
				offset = CFrame.new(0, 3.5, 0),
				color = GOLD,
				neon = true,
			},
			{
				limb = "LeftHand",
				shape = "Ball",
				size = Vector3.new(1.4, 1.4, 1.4),
				offset = CFrame.new(0, -0.9, 0),
				color = Color3.fromRGB(255, 230, 150),
				neon = true,
			},
			{
				limb = "UpperTorso",
				size = Vector3.new(2.6, 2.2, 0.25),
				offset = CFrame.new(0, -0.3, 0.85),
				color = Color3.fromRGB(60, 30, 120),
				material = Enum.Material.Fabric,
			},
		},
		aura = Color3.fromRGB(255, 230, 150),
	},
	FallenSensei = {
		scale = 1.4,
		body = Color3.fromRGB(25, 15, 30),
		skin = Color3.fromRGB(35, 25, 40),
		pieces = (function(): { Piece }
			local p = sword("RightHand", 4, Color3.fromRGB(255, 120, 200))
			table.insert(p, {
				limb = "Head",
				size = Vector3.new(1.3, 0.25, 0.3),
				offset = CFrame.new(0, 0.1, -0.62),
				color = Color3.fromRGB(255, 120, 200),
				neon = true,
			})
			table.insert(p, {
				limb = "Head",
				size = Vector3.new(1.4, 0.3, 1.4),
				offset = CFrame.new(0, 0.3, 0),
				color = Color3.fromRGB(255, 120, 200),
				material = Enum.Material.Fabric,
			})
			table.insert(p, {
				limb = "UpperTorso",
				shape = "Wedge",
				size = Vector3.new(0.25, 3, 2.6),
				offset = CFrame.new(0, -1, 1.1) * CFrame.Angles(math.rad(-100), 0, 0),
				color = Color3.fromRGB(40, 20, 45),
				material = Enum.Material.Fabric,
			})
			table.insert(p, {
				limb = "UpperTorso",
				size = Vector3.new(0.4, 1.6, 0.15),
				offset = CFrame.new(-0.3, 0, -0.55),
				color = Color3.fromRGB(255, 120, 200),
				neon = true,
			})
			table.insert(p, {
				limb = "LowerTorso",
				size = Vector3.new(2.2, 0.5, 1.2),
				offset = CFrame.new(0, 0.1, 0),
				color = Color3.fromRGB(255, 120, 200),
				material = Enum.Material.Fabric,
			})
			return p
		end)(),
		aura = Color3.fromRGB(255, 120, 200),
	},
	Guard = {
		scale = 1.05,
		body = Color3.fromRGB(50, 60, 150),
		skin = Color3.fromRGB(220, 190, 160),
		pieces = {
			{
				limb = "Head",
				shape = "Cylinder",
				size = Vector3.new(1.5, 0.5, 1.5),
				offset = CFrame.new(0, 0.7, 0),
				color = Color3.fromRGB(40, 50, 120),
			},
			{
				limb = "RightHand",
				shape = "Cylinder",
				size = Vector3.new(0.35, 5, 0.35),
				offset = CFrame.new(0, 0, 0),
				color = Color3.fromRGB(120, 90, 50),
				material = Enum.Material.Wood,
			},
		},
	},
	RiftBoss = {
		scale = 2.2,
		body = Color3.fromRGB(90, 40, 160),
		skin = Color3.fromRGB(150, 80, 220),
		pieces = {
			{
				limb = "Head",
				shape = "Wedge",
				size = Vector3.new(0.6, 1.8, 0.6),
				offset = CFrame.new(-0.6, 1, 0) * CFrame.Angles(0, 0, math.rad(20)),
				color = Color3.fromRGB(230, 150, 255),
				neon = true,
			},
			{
				limb = "Head",
				shape = "Wedge",
				size = Vector3.new(0.6, 1.8, 0.6),
				offset = CFrame.new(0.6, 1, 0) * CFrame.Angles(0, 0, math.rad(-20)),
				color = Color3.fromRGB(230, 150, 255),
				neon = true,
			},
			{
				limb = "UpperTorso",
				shape = "Ball",
				size = Vector3.new(1.2, 1.2, 1.2),
				offset = CFrame.new(0, 0, -0.7),
				color = Color3.fromRGB(255, 120, 255),
				neon = true,
			},
		},
		aura = Color3.fromRGB(200, 100, 255),
	},
	HungrySensei = {
		scale = 1.6,
		body = Color3.fromRGB(200, 110, 60),
		skin = Color3.fromRGB(230, 170, 120),
		pieces = {
			{
				limb = "LowerTorso",
				shape = "Ball",
				size = Vector3.new(2.6, 2.4, 2.4),
				offset = CFrame.new(0, 0.4, 0),
				color = Color3.fromRGB(200, 110, 60),
			},
			{
				limb = "Head",
				shape = "Cylinder",
				size = Vector3.new(2.6, 0.25, 2.6),
				offset = CFrame.new(0, 0.55, 0),
				color = Color3.fromRGB(215, 180, 110),
				material = Enum.Material.Fabric,
			},
			{
				limb = "RightHand",
				shape = "Cylinder",
				size = Vector3.new(0.2, 2.5, 0.2),
				offset = CFrame.new(0.2, -0.6, 0),
				color = Color3.fromRGB(150, 110, 60),
				material = Enum.Material.Wood,
			},
			{
				limb = "RightHand",
				shape = "Cylinder",
				size = Vector3.new(0.2, 2.5, 0.2),
				offset = CFrame.new(-0.2, -0.6, 0),
				color = Color3.fromRGB(150, 110, 60),
				material = Enum.Material.Wood,
			},
		},
		aura = Color3.fromRGB(255, 160, 60),
	},
}

local limbFallback: { [string]: string } = {
	RightHand = "Torso",
	LeftHand = "Torso",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	RightUpperArm = "Torso",
	LeftUpperArm = "Torso",
	Head = "Head",
}

local function findLimb(model: Model, name: string): BasePart?
	local direct = model:FindFirstChild(name)
	if direct and direct:IsA("BasePart") then
		return direct
	end
	local fb = model:FindFirstChild(limbFallback[name] or "Torso")
	if fb and fb:IsA("BasePart") then
		return fb
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp else nil
end

function BossLooks.get(name: string): Look?
	return Looks[name]
end

function BossLooks.dress(model: Model, name: string, fallbackColor: Color3)
	local look = Looks[name]
	local body = if look then look.body else fallbackColor
	local skin = if look then look.skin else fallbackColor:Lerp(Color3.new(1, 1, 1), 0.3)

	-- body colours: BodyColors if the rig supports it, otherwise tint parts
	local bc: BodyColors = model:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	bc.Parent = model
	bc.HeadColor3 = skin
	bc.TorsoColor3 = body
	bc.LeftArmColor3 = skin
	bc.RightArmColor3 = skin
	bc.LeftLegColor3 = body
	bc.RightLegColor3 = body
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			local isLimb = d.Name:find("Arm") or d.Name == "Head" or d.Name:find("Hand")
			d.Color = if isLimb then skin else body
			d.Material = Enum.Material.SmoothPlastic
		end
	end

	if look and look.scale ~= 1 then
		pcall(function()
			model:ScaleTo(look.scale)
		end)
	end

	local acc = Instance.new("Folder")
	acc.Name = "Costume"
	acc.Parent = model
	if look then
		for _, piece in look.pieces do
			local limb = findLimb(model, piece.limb)
			if not limb then
				continue
			end
			local scale = look.scale
			local p: BasePart
			if piece.shape == "Wedge" then
				local w = Instance.new("WedgePart")
				p = w
			else
				local part = Instance.new("Part")
				if piece.shape == "Ball" then
					part.Shape = Enum.PartType.Ball
				elseif piece.shape == "Cylinder" then
					part.Shape = Enum.PartType.Cylinder
				end
				p = part
			end
			local size = piece.size * scale
			if piece.shape == "Cylinder" then
				-- cylinder axis is X; we want it vertical
				p.Size = Vector3.new(size.Y, size.X, size.Z)
				p.CFrame = limb.CFrame
					* CFrame.new(piece.offset.Position * scale)
					* (piece.offset - piece.offset.Position)
					* CFrame.Angles(0, 0, math.rad(90))
			else
				p.Size = size
				p.CFrame = limb.CFrame
					* CFrame.new(piece.offset.Position * scale)
					* (piece.offset - piece.offset.Position)
			end
			p.Color = piece.color or body
			p.Material = if piece.neon then Enum.Material.Neon else (piece.material or Enum.Material.SmoothPlastic)
			p.Transparency = piece.transparency or 0
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.Anchored = false
			p.CastShadow = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = limb
			weld.Part1 = p
			weld.Parent = p
			p.Parent = acc
		end
	end

	-- Chase trail + aura on the root (off until chasing)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local auraColor = if look and look.aura then look.aura else fallbackColor
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-1, 0, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(1, 0, 0)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "ChaseTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(auraColor)
		trail.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		trail.Lifetime = 0.5
		trail.LightEmission = 1
		trail.WidthScale = NumberSequence.new(1)
		trail.Enabled = false
		trail.Parent = root
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "ChaseAura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(auraColor)
		aura.Rate = 25
		aura.Lifetime = NumberRange.new(0.4, 0.8)
		aura.Speed = NumberRange.new(3, 6)
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		aura.LightEmission = 1
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Enabled = false
		aura.Parent = root
		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = auraColor
		light.Range = 14
		light.Brightness = 1.5
		light.Enabled = false
		light.Parent = root
	end
end

function BossLooks.setChasing(model: Model, chasing: boolean)
	for _, name in { "ChaseTrail", "ChaseAura", "AuraLight" } do
		local inst = model:FindFirstChild(name, true)
		if inst then
			(inst :: any).Enabled = chasing
		end
	end
end

return BossLooks
