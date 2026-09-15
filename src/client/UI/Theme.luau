--!strict
-- Anime-styled palette: deep night panels, sakura + sky accents, chunky rounded shapes.
local Theme = {
	bg = Color3.fromRGB(22, 18, 34),
	panel = Color3.fromRGB(34, 28, 52),
	panel2 = Color3.fromRGB(48, 40, 72),
	panel3 = Color3.fromRGB(64, 54, 94),
	accent = Color3.fromRGB(255, 96, 150), -- sakura
	accent2 = Color3.fromRGB(90, 205, 255), -- sky
	gold = Color3.fromRGB(255, 205, 70),
	green = Color3.fromRGB(100, 230, 130),
	red = Color3.fromRGB(255, 80, 90),
	text = Color3.fromRGB(250, 246, 255),
	muted = Color3.fromRGB(180, 170, 205),
	stroke = Color3.fromRGB(255, 255, 255),
	outline = Color3.fromRGB(14, 10, 24), -- chunky dark outline around buttons/panels
	shadow = Color3.fromRGB(8, 6, 16),

	font = Enum.Font.FredokaOne, -- chunky rounded display font
	fontBlack = Enum.Font.FredokaOne,
	fontBody = Enum.Font.GothamBold,

	corner = 16,
	cornerSmall = 12,
	pad = 12,
	outlineThickness = 3,
}

return Theme
