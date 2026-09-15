--!strict
-- Shared data types. The profile Data table is exactly `PlayerData`.

export type Fighter = {
	id: string,
	name: string, -- FighterDef.name
	rarity: string,
	level: number,
	xp: number,
	mutation: string?, -- "Shiny" | "Shadow" | "Golden" | "Void" | nil
	slot: number?, -- placed slot index (nil = in inventory)
}

export type HatchingScroll = {
	rarity: string,
	zoneId: number,
	hatchAt: number, -- os.time()
}

export type ScrollBagEntry = { rarity: string, zoneId: number }

export type Gear = {
	Slap: boolean,
	Trap: number,
	SmokeBomb: number,
	Grapple: boolean,
	BodySwap: number,
	Shield: boolean,
}

export type PlayerData = {
	version: number,
	cash: number,
	speed: number, -- raw stat before gamepass multipliers
	tokens: number,
	rebirths: number,
	treadmillLevel: number,
	nextFighterId: number,
	fighters: { [string]: Fighter },
	hatching: { [string]: HatchingScroll }, -- key = tostring(slotIndex)
	scrollBag: { ScrollBagEntry },
	index: { [string]: boolean }, -- fighter name -> discovered
	indexClaimed: { [string]: boolean }, -- tostring(zoneId) -> claimed
	skins: { [string]: boolean },
	freeRewards: { like: boolean, favourite: boolean, group: boolean },
	gear: Gear,
	gamepasses: { [string]: boolean },
	alarmTrap: boolean,
	friends: { [string]: boolean }, -- tostring(userId)
	stats: { scrollsSecured: number, fightersStolen: number, timesCaught: number, playtime: number },
}

-- What a player is physically carrying (server-side truth, mirrored to character attributes)
export type CarriedScroll = { kind: "scroll", rarity: string, zoneId: number, uid: string }
export type CarriedFighter = { kind: "fighter", fighter: Fighter, originalOwner: number, uid: string }
export type Carried = CarriedScroll | CarriedFighter

-- Lightweight info the client gets about a base
export type BaseInfo = {
	index: number,
	ownerUserId: number?,
	ownerName: string?,
	lockedUntil: number, -- os.time(); 0 = unlocked
	lockCooldownUntil: number,
	friends: { [string]: boolean },
	unlockedSlots: number,
	unlockedFloor: number,
}

return {}
