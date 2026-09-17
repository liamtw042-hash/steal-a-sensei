--!strict
--[[
	ZONES + BOSSES
	==============
	Every boss speed and gimmick number lives here. Tune freely.

	How the gates work: a player's Power stat (a big number, e.g. 5K, 500B) is mapped
	to an actual Humanoid.WalkSpeed by Config.Power.WalkSpeedCurve. Each zone's
	`powerRequirement` is the Power needed to open its gate, and the boss's walkSpeed is
	set a touch below the WalkSpeed that requirement maps to, so a player who *just*
	meets the requirement can outrun the boss cleanly.

	Studio side (per zone): Workspace.Zones.<folderName> containing
	  - Entrance   (Part)   the gate wall. Client makes it walk-through when you meet the requirement.
	  - Bounds     (Part)   invisible box covering the zone. Used for "is player in zone".
	  - BossSpawn  (Part)   where the boss stands / returns to.
	  - Nests      (Folder) any number of Parts. A scroll spawns on each.
	  - PatrolPoints (Folder) optional Parts the boss wanders between (falls back to Nests).
]]

export type Gimmick =
	"None"
	| "Corners" -- loses you if line of sight is broken for a while
	| "Teleport" -- blinks toward you every N seconds
	| "SlowPatch" -- leaves patches that slow you
	| "FireTrail" -- leaves fire that damages you
	| "Pull" -- pulls you toward it when close
	| "Boulder" -- throws stunning boulders
	| "Clones" -- spawns short-lived clones
	| "OneHit" -- a catch cannot be shielded, and the catch radius is big

export type BossDef = {
	name: string, -- model name expected in ReplicatedStorage.Bosses (optional, placeholder rig otherwise)
	displayName: string,
	walkSpeed: number,
	catchRadius: number, -- studs
	gimmick: Gimmick,
	params: { [string]: number }, -- gimmick tuning
	ignoresShield: boolean,
	color: Color3, -- placeholder rig colour
	campSeconds: number, -- how long it camps an unlocked base entrance
}

export type ScrollPoolEntry = { rarity: string, weight: number }

export type ZoneDef = {
	id: number,
	name: string,
	folderName: string,
	powerRequirement: number,
	scrollPool: { ScrollPoolEntry },
	scrollRespawnSeconds: number,
	boss: BossDef,
}

type BossExtra = { catchRadius: number?, ignoresShield: boolean?, campSeconds: number? }

local function boss(
	name: string,
	displayName: string,
	walkSpeed: number,
	gimmick: Gimmick,
	params: { [string]: number },
	color: Color3,
	extra: BossExtra?
): BossDef
	local e: BossExtra = extra or {}
	return {
		name = name,
		displayName = displayName,
		walkSpeed = walkSpeed,
		catchRadius = e.catchRadius or 4.5,
		gimmick = gimmick,
		params = params,
		ignoresShield = e.ignoresShield or false,
		color = color,
		campSeconds = e.campSeconds or 15,
	}
end

local Zones: { ZoneDef } = {
	{
		id = 1,
		name = "Training Grounds",
		folderName = "TrainingGrounds",
		powerRequirement = 0,
		scrollPool = { { rarity = "Common", weight = 100 } },
		scrollRespawnSeconds = 20,
		boss = boss("Brute", "Brute", 13, "None", {}, Color3.fromRGB(150, 90, 60)),
	},
	{
		id = 2,
		name = "Bamboo Forest",
		folderName = "BambooForest",
		powerRequirement = 5_000,
		scrollPool = { { rarity = "Common", weight = 65 }, { rarity = "Uncommon", weight = 35 } },
		scrollRespawnSeconds = 25,
		boss = boss("Swordsman", "Swordsman", 19, "None", {}, Color3.fromRGB(80, 140, 70)),
	},
	{
		id = 3,
		name = "Shadow Village",
		folderName = "ShadowVillage",
		powerRequirement = 50_000,
		scrollPool = { { rarity = "Uncommon", weight = 100 } },
		scrollRespawnSeconds = 30,
		-- loses the carrier after `loseAfterSeconds` of broken line of sight
		boss = boss("Ninja", "Ninja", 26, "Corners", { loseAfterSeconds = 2.5 }, Color3.fromRGB(40, 40, 60)),
	},
	{
		id = 4,
		name = "Storm Peak",
		folderName = "StormPeak",
		powerRequirement = 500_000,
		scrollPool = { { rarity = "Rare", weight = 100 } },
		scrollRespawnSeconds = 35,
		-- teleports to `teleportDistance` studs behind the carrier every `intervalSeconds`
		boss = boss(
			"LightningMonk",
			"Lightning Monk",
			31,
			"Teleport",
			{ intervalSeconds = 8, teleportDistance = 12 },
			Color3.fromRGB(240, 220, 90)
		),
	},
	{
		id = 5,
		name = "Frozen Temple",
		folderName = "FrozenTemple",
		powerRequirement = 5_000_000,
		scrollPool = { { rarity = "Rare", weight = 100 } },
		scrollRespawnSeconds = 40,
		-- drops a patch every `intervalSeconds`; patch lasts `patchLifetime`, slows to `slowMultiplier` for `slowSeconds`
		boss = boss(
			"IceWarrior",
			"Ice Warrior",
			37,
			"SlowPatch",
			{ intervalSeconds = 2.5, patchLifetime = 8, patchSize = 9, slowMultiplier = 0.55, slowSeconds = 2 },
			Color3.fromRGB(140, 200, 255)
		),
	},
	{
		id = 6,
		name = "Volcanic Dojo",
		folderName = "VolcanicDojo",
		powerRequirement = 50_000_000,
		scrollPool = { { rarity = "Epic", weight = 100 } },
		scrollRespawnSeconds = 45,
		-- fire trail: `damage` per `damageIntervalSeconds` while standing in it
		boss = boss(
			"FlameRonin",
			"Flame Ronin",
			43,
			"FireTrail",
			{ intervalSeconds = 0.6, patchLifetime = 6, patchSize = 6, damage = 12, damageIntervalSeconds = 0.5 },
			Color3.fromRGB(255, 120, 30)
		),
	},
	{
		id = 7,
		name = "Abyss Shrine",
		folderName = "AbyssShrine",
		powerRequirement = 500_000_000,
		scrollPool = { { rarity = "Epic", weight = 100 } },
		scrollRespawnSeconds = 50,
		-- within `pullRadius` studs it yanks you back with `pullForce` every `intervalSeconds`
		boss = boss(
			"SeaSerpent",
			"Sea Serpent",
			49,
			"Pull",
			{ pullRadius = 14, pullForce = 55, intervalSeconds = 1.2 },
			Color3.fromRGB(30, 90, 160)
		),
	},
	{
		id = 8,
		name = "Ancient Ruins",
		folderName = "AncientRuins",
		powerRequirement = 5_000_000_000,
		scrollPool = { { rarity = "Legendary", weight = 100 } },
		scrollRespawnSeconds = 60,
		-- throws a boulder every `intervalSeconds`, flight time `flightSeconds`, stuns within `blastRadius` for `stunSeconds`
		boss = boss(
			"StoneGolem",
			"Stone Golem",
			54,
			"Boulder",
			{ intervalSeconds = 6, flightSeconds = 1.2, blastRadius = 9, stunSeconds = 1.5 },
			Color3.fromRGB(120, 120, 110)
		),
	},
	{
		id = 9,
		name = "Celestial Gate",
		folderName = "CelestialGate",
		powerRequirement = 50_000_000_000,
		scrollPool = { { rarity = "Legendary", weight = 100 } },
		scrollRespawnSeconds = 75,
		-- spawns `count` clones every `intervalSeconds`; clones live `cloneLifetime`s at `cloneSpeedMultiplier` speed
		boss = boss(
			"StarSage",
			"Star Sage",
			62,
			"Clones",
			{ intervalSeconds = 10, count = 2, cloneLifetime = 12, cloneSpeedMultiplier = 0.85 },
			Color3.fromRGB(230, 200, 255)
		),
	},
	{
		id = 10,
		name = "Sakura Void",
		folderName = "SakuraVoid",
		powerRequirement = 500_000_000_000,
		scrollPool = { { rarity = "Mythic", weight = 90 }, { rarity = "Secret", weight = 10 } },
		scrollRespawnSeconds = 90,
		boss = boss(
			"FallenSensei",
			"The Fallen Sensei",
			74,
			"OneHit",
			{},
			Color3.fromRGB(255, 150, 200),
			{ catchRadius = 7, ignoresShield = true, campSeconds = 20 }
		),
	},
}

local ZonesModule = {
	List = Zones,
	-- Shared boss behaviour numbers
	Boss = {
		pathRecomputeSeconds = 0.45, -- how often the boss re-plans its path to you
		waypointReachStuds = 3.5,
		patrolIdleSeconds = { 1.5, 4 }, -- random wait between patrol points
		patrolTimeoutSeconds = 12, -- give up walking to a patrol point after this
		returnTimeoutSeconds = 40, -- if it can't get home, it teleports home
		catchInvulnerabilitySeconds = 5, -- player can't be caught for this long after a launch
		shieldStunSeconds = 2.5, -- boss freezes when its hit is absorbed by a Shield
		launchUpVelocity = 90, -- how hard the catch launches you before the teleport
		launchDelaySeconds = 0.55,
		chaseGiveUpDistance = 900, -- safety: if the carrier is impossibly far, go home
	},
}

function ZonesModule.get(id: number): ZoneDef
	local z = Zones[id]
	assert(z, `Unknown zone id {id}`)
	return z
end

function ZonesModule.byFolderName(folderName: string): ZoneDef?
	for _, z in Zones do
		if z.folderName == folderName then
			return z
		end
	end
	return nil
end

return ZonesModule
