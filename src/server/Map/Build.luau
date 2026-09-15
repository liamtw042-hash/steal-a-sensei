--!strict
--[[
	Build: tiny helpers for generating map geometry from parts at runtime.
	Everything is anchored, chunky and low-poly on purpose.
]]
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Build = {}

Build.GROUND = 2 -- terrain top surface Y
Build.rng = Random.new(1337)

export type Props = { [string]: any }

local function apply(inst: Instance, props: Props?)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
		if props.Parent then
			inst.Parent = props.Parent
		end
	end
end

function Build.folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Build.model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Build.part(props: Props, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	apply(p, props)
	if parent then
		p.Parent = parent
	end
	return p
end

function Build.block(
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?,
	extra: Props?
): Part
	local p =
		Build.part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic })
	apply(p, extra)
	if parent then
		p.Parent = parent
	end
	return p
end

function Build.cyl(
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?,
	extra: Props?
): Part
	-- Cylinder parts lie along X; rotate so `size.Y` is the height
	local p = Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size.Y, size.X, size.Z),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	apply(p, extra)
	if parent then
		p.Parent = parent
	end
	return p
end

function Build.ball(
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?,
	extra: Props?
): Part
	local p = Build.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	apply(p, extra)
	if parent then
		p.Parent = parent
	end
	return p
end

function Build.wedge(
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?,
	extra: Props?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	apply(w, extra)
	if parent then
		w.Parent = parent
	end
	return w
end

function Build.cone(
	radius: number,
	height: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?
): Part
	-- a cone from a cylinder with a special mesh isn't available, so stack shrinking cylinders
	local m = Build.model("Cone", parent or Workspace)
	local layers = 4
	for i = 0, layers - 1 do
		local t = i / layers
		local r = radius * (1 - t)
		local h = height / layers
		Build.cyl(Vector3.new(r * 2, h, r * 2), cf * CFrame.new(0, -height / 2 + h * i + h / 2, 0), color, material, m)
	end
	local pp = m:FindFirstChildWhichIsA("BasePart") :: Part
	m.PrimaryPart = pp
	return pp
end

function Build.light(parent: BasePart, color: Color3, range: number, brightness: number?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = parent
	return l
end

function Build.particles(parent: BasePart, props: Props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 8
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(1, 2)
	e.Size = NumberSequence.new(0.5)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = 0.8
	e.SpreadAngle = Vector2.new(180, 180)
	apply(e, props)
	e.Parent = parent
	return e
end

function Build.label(part: BasePart, text: string, color: Color3, offsetY: number, width: number?, maxDistance: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(width or 220, 50)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDistance or 70
	bb.Parent = part
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = color
	lbl.TextStrokeTransparency = 0.2
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	lbl.Text = text
	lbl.Parent = bb
end

-- Slowly bob + spin a part forever (floating rocks, orbs, scrolls)
function Build.hover(part: BasePart, amplitude: number, seconds: number, spin: boolean?)
	local base = part.CFrame
	local up = base + Vector3.new(0, amplitude, 0)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local goal = if spin then up * CFrame.Angles(0, math.pi, 0) else up
	TweenService:Create(part, info, { CFrame = goal }):Play()
end

function Build.spin(part: BasePart, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false)
	-- two half-turns so the tween doesn't take the short way round
	task.spawn(function()
		while part.Parent do
			local a = TweenService:Create(
				part,
				TweenInfo.new(seconds / 2, Enum.EasingStyle.Linear),
				{ CFrame = part.CFrame * CFrame.Angles(0, math.pi, 0) }
			)
			a:Play()
			a.Completed:Wait()
			local b = TweenService:Create(
				part,
				TweenInfo.new(seconds / 2, Enum.EasingStyle.Linear),
				{ CFrame = part.CFrame * CFrame.Angles(0, math.pi, 0) }
			)
			b:Play()
			b.Completed:Wait()
		end
	end)
	local _ = info
end

function Build.jitter(amount: number): number
	return Build.rng:NextNumber(-amount, amount)
end

function Build.pick<T>(list: { T }): T
	return list[Build.rng:NextInteger(1, #list)]
end

-- A quick low-poly tree: trunk + 2-3 leaf balls
function Build.tree(pos: Vector3, height: number, leafColor: Color3, trunkColor: Color3?, parent: Instance?): Model
	local m = Build.model("Tree", parent or Workspace)
	local trunk = Build.cyl(
		Vector3.new(1.6, height, 1.6),
		CFrame.new(pos + Vector3.new(0, height / 2, 0)),
		trunkColor or Color3.fromRGB(110, 75, 45),
		Enum.Material.Wood,
		m
	)
	local r = height * 0.55
	Build.ball(r, CFrame.new(pos + Vector3.new(0, height + r * 0.25, 0)), leafColor, Enum.Material.Grass, m)
	Build.ball(
		r * 0.8,
		CFrame.new(pos + Vector3.new(r * 0.35, height - r * 0.05, r * 0.2)),
		leafColor:Lerp(Color3.new(1, 1, 1), 0.1),
		Enum.Material.Grass,
		m
	)
	Build.ball(
		r * 0.7,
		CFrame.new(pos + Vector3.new(-r * 0.35, height + r * 0.05, -r * 0.2)),
		leafColor:Lerp(Color3.new(0, 0, 0), 0.1),
		Enum.Material.Grass,
		m
	)
	m.PrimaryPart = trunk
	return m
end

-- A rock: a Head-mesh part reads as a rounded boulder
function Build.rock(pos: Vector3, size: Vector3, color: Color3, parent: Instance?): Part
	local p = Build.part({
		Size = size,
		CFrame = CFrame.new(pos) * CFrame.Angles(Build.jitter(0.4), Build.jitter(3), Build.jitter(0.4)),
		Color = color,
		Material = Enum.Material.Slate,
	}, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1, 1.25)
	mesh.Parent = p
	return p
end

-- Fence line from a to b: posts + two rails
function Build.fence(a: Vector3, b: Vector3, color: Color3, parent: Instance, height: number?)
	local h = height or 3.2
	local dir = b - a
	local len = dir.Magnitude
	if len < 1 then
		return
	end
	local unit = dir.Unit
	local look = CFrame.lookAt(a, b)
	local posts = math.max(2, math.floor(len / 5.5) + 1)
	for i = 0, posts - 1 do
		local t = if posts == 1 then 0 else i / (posts - 1)
		local pos = a + unit * (len * t)
		Build.block(
			Vector3.new(0.7, h, 0.7),
			CFrame.new(pos + Vector3.new(0, h / 2, 0)),
			color,
			Enum.Material.Wood,
			parent
		)
		Build.ball(
			0.9,
			CFrame.new(pos + Vector3.new(0, h + 0.2, 0)),
			color:Lerp(Color3.new(0, 0, 0), 0.15),
			Enum.Material.Wood,
			parent
		)
	end
	for _, y in { h * 0.42, h * 0.78 } do
		Build.block(
			Vector3.new(0.35, 0.5, len),
			look * CFrame.new(0, y, -len / 2),
			color:Lerp(Color3.new(1, 1, 1), 0.1),
			Enum.Material.Wood,
			parent
		)
	end
end

return Build
