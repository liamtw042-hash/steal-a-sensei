# Studio checklist: every part, folder and model the scripts look for

Names are **exact** and case-sensitive. Anything marked *optional* has a fallback.
Until you build these, the server generates a placeholder version of all of it
(`src/server/Util/DevMap.luau`) so the game is playable immediately.

Tip: build the real map inside a `Workspace.Map` folder. As soon as `Workspace.Map`
exists the dev map generator stops running.

## Workspace.Map (Folder)

| Name | Type | Purpose |
| --- | --- | --- |
| `Spawn` | Part | Where players are launched back to after a boss catches them. |
| `RiftSpawn` | Part | *optional* Rift boss spawn point (falls back to `Spawn`). |
| `HungrySenseiSpawn` | Part | *optional* Hungry Sensei spawn point (falls back to `Spawn`). |

Put all your decorative map geometry under `Map` too (or anywhere, it doesn't matter).

## Workspace.Zones (Folder) — ten zone folders

Zone folder names: `TrainingGrounds`, `BambooForest`, `ShadowVillage`, `StormPeak`,
`FrozenTemple`, `VolcanicDojo`, `AbyssShrine`, `AncientRuins`, `CelestialGate`, `SakuraVoid`.

Inside **each** zone folder:

| Name | Type | Purpose |
| --- | --- | --- |
| `Entrance` | Part | The gate wall. Keep it `Anchored`, `CanCollide = true`. Clients make it walk-through when they meet the speed requirement. Make sure players can't just walk around it (side walls). |
| `Bounds` | Part | Invisible box covering the whole zone (`Transparency 1`, `CanCollide false`). Used for "is this player inside the zone". |
| `BossSpawn` | Part | Where the boss stands and returns to. |
| `Nests` | Folder of Parts | One scroll spawns on top of each Part. 3–6 per zone is good. Any names. |
| `PatrolPoints` | Folder of Parts | *optional* Where the boss wanders (falls back to the nests). |

## Workspace.Bases (Folder) — `Base1` … `Base8`

Inside **each** base folder (Folder or Model):

| Name | Type | Purpose |
| --- | --- | --- |
| `Region` | Part | Invisible box covering the whole base interior. Being inside it = scroll secured / fighter stolen successfully. Intruders inside it while locked get ejected. |
| `Entrance` | Part | A pad just outside the gate. Bosses camp here; ejected intruders land here. |
| `Gates` | Folder of Parts | One or more laser-wall Parts across the entrance. Set `CanCollide = false`; the scripts handle collision per player. Give them a Neon look. |
| `LockPad` | Part | Owner steps on it to lock the base. |
| `Treadmill` | Part | Owner stands on it to gain speed. |
| `Spawn` | Part | Where the owner respawns. |
| `Slots` | Folder of Parts | `Slot1` … `SlotN`. Each Part needs a **number attribute `Floor`** = 1, 2 or 3. Floor 1 needs at least 10, floors 2 and 3 at least 8 each. Add extra Floor-1 slots (e.g. `Slot27`+) if you want rebirth/+5-slot bonuses usable before floor 2 unlocks. |
| `Sign` | Part | *optional* Invisible part above the gate; gets an owner-name billboard. |
| `GuardPath` | Folder of Parts | *optional* Waypoints for the Guard gamepass NPC (falls back to the slots). |

The base needs solid walls on every side except the gated entrance, or the lasers are pointless.

## ReplicatedStorage.Fighters (Folder) — *optional*

One `Model` per fighter, named **exactly** as `name` in `src/shared/Config/Fighters.luau`:

`Dojo Novice`, `Straw Hat Kid`, `Bamboo Striker`, `Shadow Scout`, `Storm Caller`, `Frost Blade`,
`Ember Fist`, `Tide Breaker`, `Ruin Colossus`, `Celestial Blade`, `Sakura Reaper`, `Void Dancer`,
`The First Sensei`, `Eclipse Ronin`.

Requirements: set a `PrimaryPart`. Animations/scripts inside are stripped. Missing models get a
coloured placeholder block, so add them one at a time whenever.

## ReplicatedStorage.Bosses (Folder) — *optional*

One `Model` per boss with a `Humanoid` and `HumanoidRootPart` (an R15/R6 rig works), named:
`Brute`, `Swordsman`, `Ninja`, `LightningMonk`, `IceWarrior`, `FlameRonin`, `SeaSerpent`,
`StoneGolem`, `StarSage`, `FallenSensei`. Also optional: `Guard`, `RiftBoss`, `HungrySensei`.

Missing ones use a default R15 rig tinted the boss colour (or a block rig if that fails).

## ReplicatedStorage.Scrolls (Folder) — *optional*

One `Model` (with PrimaryPart) per rarity: `Common`, `Uncommon`, `Rare`, `Epic`, `Legendary`,
`Mythic`, `Secret`. Missing ones use a glowing placeholder scroll.

## Things you do NOT need to create

- Any ScreenGui: the whole UI is built in code.
- RemoteEvents/RemoteFunctions: Knit creates them.
- Leaderstats, collision groups, the `Scrolls` / `LooseFighters` workspace folders: created at runtime.
- SpawnLocations: players are teleported to their base `Spawn` part on spawn. (A single
  SpawnLocation somewhere harmless is still fine.)
