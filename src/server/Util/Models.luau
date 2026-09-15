--!strict
--[[
	Builds the visual models for scrolls and fighters.
	Looks for ReplicatedStorage.Scrolls.<Rarity> and ReplicatedStorage.Fighters.<FighterName>;
	falls back to generated placeholder parts so nothing is required to exist.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Economy = require(ReplicatedStorage.Shared.Util.Economy)
local CharacterUtil = require(script.Parent.CharacterUtil)

local Models = {}

local function prepareParts(model: Model, anchored: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
			d.CanCollide = false
			d.CanQuery = true
			d.CanTouch = false
			d.Massless = true
			d.CollisionGroup = CharacterUtil.PICKUP_GROUP
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

function Models.billboard(parent: BasePart, text: string, color: Color3, offsetY: number, size: UDim2?): TextLabel
	local existing = parent:FindFirstChild("Label")
	if existing then
		existing:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = size or UDim2.fromOffset(160, 44)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 80
	bb.Parent = parent
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Text"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.RichText = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = color
	lbl.TextStrokeTransparency = 0.25
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	lbl.Text = text
	lbl.Parent = bb
	return lbl
end

function Models.scroll(rarity: string): Model
	local folder = ReplicatedStorage:FindFirstChild("Scrolls")
	local tmpl = if folder then folder:FindFirstChild(rarity) else nil
	local model: Model
	if tmpl and tmpl:IsA("Model") and tmpl.PrimaryPart then
		model = tmpl:Clone()
	else
		model = Instance.new("Model")
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Shape = Enum.PartType.Cylinder
		handle.Size = Vector3.new(3, 1, 1)
		handle.Color = Rarity.color(rarity)
		handle.Material = Enum.Material.Neon
		handle.CFrame = CFrame.Angles(0, 0, math.rad(90))
		handle.Parent = model
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(1.2, 0.4, 1.2)
		band.Color = Color3.fromRGB(230, 220, 200)
		band.Material = Enum.Material.SmoothPlastic
		band.CFrame = handle.CFrame
		band.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = band
		weld.Parent = handle
		model.PrimaryPart = handle
	end
	model.Name = "Scroll"
	model:SetAttribute("Rarity", rarity)
	prepareParts(model, true)
	local pp = model.PrimaryPart :: BasePart
	Models.billboard(pp, `{rarity} Scroll`, Rarity.color(rarity), 2.2, UDim2.fromOffset(130, 30))
	return model
end

function Models.fighterCps(fighter: Types.Fighter): number
	return Economy.fighterCps(fighter)
end

function Models.fighterLabelText(fighter: Types.Fighter, extra: string?): string
	local def = Config.Fighters.get(fighter.name)
	local display = if def then def.displayName else fighter.name
	local mut = if fighter.mutation then `<font color="#ffd166">{fighter.mutation}</font> ` else ""
	local line2 = `{fighter.rarity} • Lv {fighter.level} • {Format.cash(Models.fighterCps(fighter))}/s`
	if extra then
		line2 = line2 .. "\n" .. extra
	end
	return `{mut}{display}\n<font size="14">{line2}</font>`
end

function Models.fighter(fighter: Types.Fighter, anchored: boolean): Model
	local folder = ReplicatedStorage:FindFirstChild("Fighters")
	local tmpl = if folder then folder:FindFirstChild(fighter.name) else nil
	local model: Model
	if tmpl and tmpl:IsA("Model") then
		model = tmpl:Clone()
		if not model.PrimaryPart then
			local hrp = model:FindFirstChild("HumanoidRootPart")
			local first = if hrp and hrp:IsA("BasePart") then hrp else model:FindFirstChildWhichIsA("BasePart", true)
			model.PrimaryPart = first
		end
	else
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(2.6, 3.6, 2.2)
		body.Color = Rarity.color(fighter.rarity)
		body.Material = Enum.Material.SmoothPlastic
		body.Parent = model
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(1.8, 1.8, 1.8)
		head.Color = Color3.fromRGB(240, 220, 200)
		head.Material = Enum.Material.SmoothPlastic
		head.CFrame = body.CFrame * CFrame.new(0, 2.7, 0)
		head.Parent = model
		local band = Instance.new("Part")
		band.Name = "Headband"
		band.Size = Vector3.new(1.9, 0.35, 1.9)
		band.Color = Rarity.color(fighter.rarity)
		band.Material = Enum.Material.Neon
		band.CFrame = head.CFrame * CFrame.new(0, 0.3, 0)
		band.Parent = model
		for _, p in { head, band } do
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = p
			w.Parent = body
		end
		model.PrimaryPart = body
	end
	model.Name = fighter.name
	model:SetAttribute("FighterId", fighter.id)
	model:SetAttribute("Rarity", fighter.rarity)
	prepareParts(model, anchored)

	local mut = Config.Fighters.mutation(fighter.mutation)
	if mut then
		local pp = model.PrimaryPart
		if pp then
			local light = Instance.new("PointLight")
			light.Color = mut.color
			light.Range = 8
			light.Brightness = 1.5
			light.Parent = pp
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = mut.color
			sparkles.Parent = pp
		end
	end
	return model
end

-- Weld a model to a character root so it rides above the player's head
function Models.attachToCharacter(model: Model, root: BasePart, offset: CFrame)
	prepareParts(model, false)
	local pp = model.PrimaryPart
	if not pp then
		return
	end
	model:PivotTo(root.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = pp
	weld.C0 = offset
	weld.Parent = pp
	model.Parent = root.Parent
end

return Models
