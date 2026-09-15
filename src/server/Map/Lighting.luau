--!strict
-- Bright, saturated anime-style lighting: sky, atmosphere, bloom, sun rays, colour grading, clouds.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LightingBuilder = {}

function LightingBuilder.build()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(120, 120, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 220)
	Lighting.ColorShift_Bottom = Color3.fromRGB(200, 220, 255)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.FogEnd = 1e5

	for _, c in Lighting:GetChildren() do
		if c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("PostEffect") then
			c:Destroy()
		end
	end

	-- Instance.new("Sky") ships with Roblox's default blue-sky textures; keep those
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.StarCount = 1500
	sky.Parent = Lighting

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.32
	atmo.Offset = 0.35
	atmo.Color = Color3.fromRGB(205, 220, 255)
	atmo.Decay = Color3.fromRGB(120, 150, 220)
	atmo.Glare = 0.35
	atmo.Haze = 1.6
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.7
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.12
	rays.Spread = 0.8
	rays.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.25
	cc.Contrast = 0.12
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 250, 245)
	cc.Parent = Lighting

	local terrain = Workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(40, 150, 220)
	terrain.WaterTransparency = 0.5
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 12
	terrain.WaterReflectance = 0.6

	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.35
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = Workspace.Terrain
end

return LightingBuilder
