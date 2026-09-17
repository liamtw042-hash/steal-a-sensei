--!strict
--[[
	MONETIZATION
	============
	Create every gamepass and developer product in the Roblox Creator Dashboard, then
	paste the IDs here. An id of 0 means "not configured": the shop shows it, but
	purchases are refused with a warning instead of erroring.
]]

export type GamepassDef = { key: string, name: string, price: number, id: number, description: string }
export type ProductDef = {
	key: string,
	name: string,
	price: number,
	id: number,
	description: string,
	kind: "permanent" | "uses",
	uses: number?,
}

local Gamepasses: { GamepassDef } = {
	-- Power ladder (each is a separate multiplicative pass)
	{ key = "Power2x", name = "2x Power", price = 5, id = 0, description = "Multiplies your Power by 2." },
	{ key = "Power4x", name = "4x Power", price = 10, id = 0, description = "Multiplies your Power by 4." },
	{ key = "Power8x", name = "8x Power", price = 20, id = 0, description = "Multiplies your Power by 8." },
	{ key = "Power16x", name = "16x Power", price = 40, id = 0, description = "Multiplies your Power by 16." },
	{ key = "Power32x", name = "32x Power", price = 80, id = 0, description = "Multiplies your Power by 32." },
	{ key = "Power64x", name = "64x Power", price = 160, id = 0, description = "Multiplies your Power by 64." },
	{ key = "Power128x", name = "128x Power", price = 320, id = 0, description = "Multiplies your Power by 128." },
	{ key = "Power256x", name = "256x Power", price = 640, id = 0, description = "Multiplies your Power by 256." },
	{
		key = "Power512x",
		name = "512x Power",
		price = 1280,
		id = 0,
		description = "Multiplies your Power by 512.",
	},
	{
		key = "Power1024x",
		name = "1024x Power",
		price = 2560,
		id = 0,
		description = "Multiplies your Power by 1024.",
	},
	-- Other passes
	{ key = "VIP", name = "VIP", price = 200, id = 0, description = "2x cash, +10s base lock, VIP tag." },
	{ key = "Growth2x", name = "2x Growth", price = 150, id = 0, description = "Fighters gain XP twice as fast." },
	{ key = "Slots5", name = "+5 Slots", price = 100, id = 0, description = "Five extra permanent base slots." },
	{
		key = "Guard",
		name = "Base Guard",
		price = 250,
		id = 0,
		description = "A guard patrols your base and slows intruders.",
	},
}

-- Combat shop (developer products)
local Products: { ProductDef } = {
	{
		key = "Slap",
		name = "Slap",
		price = 50,
		id = 0,
		kind = "permanent",
		description = "Knock the scroll or fighter out of a carrier's hands.",
	},
	{
		key = "Trap",
		name = "Trap (5 uses)",
		price = 30,
		id = 0,
		kind = "uses",
		uses = 5,
		description = "Place a trap that stuns whoever steps on it.",
	},
	{
		key = "SmokeBomb",
		name = "Smoke Bomb (5 uses)",
		price = 40,
		id = 0,
		kind = "uses",
		uses = 5,
		description = "Go invisible for 4 seconds. Bosses lose you.",
	},
	{
		key = "Grapple",
		name = "Grapple",
		price = 120,
		id = 0,
		kind = "permanent",
		description = "Pull a target player to you.",
	},
	{
		key = "BodySwap",
		name = "Body Swap (3 uses)",
		price = 80,
		id = 0,
		kind = "uses",
		uses = 3,
		description = "Swap positions with a target player.",
	},
	{
		key = "Shield",
		name = "Shield",
		price = 200,
		id = 0,
		kind = "permanent",
		description = "Block one boss hit per scroll run.",
	},
}

local Combat = {
	slapRange = 9,
	slapCooldown = 3,
	slapKnockback = 45,
	trapLifetimeSeconds = 120,
	trapStunSeconds = 2,
	trapArmDelay = 1, -- so you don't trigger your own trap immediately
	smokeSeconds = 4,
	smokeCooldown = 10,
	grappleRange = 35,
	grappleCooldown = 8,
	grappleForce = 70,
	bodySwapRange = 35,
	bodySwapCooldown = 10,
}

local Monetization = {
	Gamepasses = Gamepasses,
	Products = Products,
	Combat = Combat,
}

function Monetization.gamepass(key: string): GamepassDef?
	for _, g in Gamepasses do
		if g.key == key then
			return g
		end
	end
	return nil
end

function Monetization.gamepassById(id: number): GamepassDef?
	if id == 0 then
		return nil
	end
	for _, g in Gamepasses do
		if g.id == id then
			return g
		end
	end
	return nil
end

function Monetization.product(key: string): ProductDef?
	for _, p in Products do
		if p.key == key then
			return p
		end
	end
	return nil
end

function Monetization.productById(id: number): ProductDef?
	if id == 0 then
		return nil
	end
	for _, p in Products do
		if p.id == id then
			return p
		end
	end
	return nil
end

return Monetization
