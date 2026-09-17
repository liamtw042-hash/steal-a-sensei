# Status: what's verified, what needs a playtest, known limits

Last updated 2026-09-17 (Speed replaced by the Power system).

## Verified

**Static (every commit):** `luau-lsp analyze` in strict mode over all of `src/` with the
Roblox type definitions, StyLua formatting, `rojo build` to a place file.

**Live in Studio (Rojo connected, one player, blank baseplate):**

- New generated map builds in ~0.1s with no errors: terrain (leafy-grass floor, per-zone
  floor materials, cliff corridors, water pools, ice patches, lava mounds), sky/atmosphere/
  bloom/sun rays/colour grading/clouds, hub plaza (spawn pad, fuse machine, shop stall,
  rebirth shrine, spinning rift portal, index board), eight fenced base plots, ten dressed zones.
- Boss costumes render (Brute seen up close: horns, fists, belt); default-rig animation
  loop plays; chase trail/aura toggles with chase state.
- Scroll models with rarity particles on glowing pedestals; scrolls bob.
- HUD (now below Roblox's topbar, which had been hiding the cash line), chunky buttons,
  windows, toasts, zone prompt, hotbar all render; shop window shows the 1024x cap.
- Tutorial: step 1 → 2 on grab, → 3 on secure, finishes on the lock pad; saved flag.
- Full loop with new visuals: grab, "BRUTE IS CHASING YOU", catch (drop + launch), secure,
  hatch, income at the retuned rate ($25/s for a Common).
- Lock pad → "Base locked" toast → red laser beams across the gate.
- Hub shop prompt opens the Shop window.
- Phone layout (Studio device emulator, iPhone XR): HUD scales to ~0.55, rail/hotbar/tutorial
  card fit and don't overlap the joystick or jump button.
- Power system: HUD reads “💪 N Power”, holding E at the base punching bag ticks Power up once
  a second (0 → 150 in six punches at level 1), the Training panel shows the level, fill bar,
  per-punch rate and live total, releasing E stops it, F buys the next bag level ($5K taken,
  level 2 granted, prompt updated to $500K, rate 25 → 1,000 per punch), and the Bamboo Forest
  gate reads “Requires 5K Power (you have 100)”.

## Needs a real playtest

- Sounds: wired to every event but Studio audio wasn't audible to the test harness. They
  are Roblox built-in `rbxasset://sounds/*` files, so they will play; the *choice* of sound
  per event is a first guess.
- Camera shake, speed lines (>28 studs/s) and hatch flash: code ran without errors in the
  live loop; whether the strength feels right needs a human.
- Carry pose animation: loads Roblox's tool-hold animation; verify it looks right on R15
  avatars with different bundles.
- Zones 2–10 gimmicks, boss costumes other than the Brute up close, Sakura Void canopy
  and petal rate, floating platforms in Celestial Gate.
- Everything multiplayer: stealing, gate ejection, friends, alarm, guard, combat items,
  events (Rift, Void Surge, Hungry Sensei), rebirth flow, purchases (ids still 0).
- The economy curve in `docs/ECONOMY.md` is arithmetic, not playtested.
- Data persistence across rejoins (Studio API access is off; ProfileService used its mock).

## Known limits and honest caveats

- **StreamingEnabled is on** in the baseplate template. Far zones stream in as you approach.
  All gameplay is server-side so this is safe, but the client's zone prompt and tutorial
  arrow only appear once the relevant parts have streamed (a few hundred studs).
- **Power passes cap at 1024x total.** Owning 2x+4x+8x+16x already hits the cap; the
  32x–1024x passes only matter if a player skipped lower ones. That's the brief as specified.
  If you want every pass to be worth buying, make them additive (see `Config/Power.luau`).
- **Like / favourite rewards can't be verified** (no Roblox API). Honour system with a 5s delay.
- **Boss pathfinding depends on your map.** The generated corridors are wide and flat on
  purpose. Narrow doors, floating platforms or cliffs will strand bosses (there is a stuck
  nudge + return-home timeout).
- **Gate collision is client-side** (standard); the server ejects intruders from locked bases.
- **One scroll or fighter carried at a time.**
- **Per-rebirth slots before floor 2** only become usable with extra Floor-1 slot parts.

## What still looks placeholder / needs real assets

Be honest with yourself about this list before publishing:

- **Bosses** read as "what they are" (horns, swords, hat, tail, cape) but they are Roblox
  default R15 bodies with parts welded on. A modeller or Creator Store rigs
  (`ReplicatedStorage.Bosses.<Name>`) would be a big upgrade; the code swaps them in automatically.
- **Fighters** are still coloured placeholder blocks with a head. Every fighter needs a real
  model in `ReplicatedStorage.Fighters.<name>`.
- **Props are primitives.** Trees are cylinders + spheres, dummies are cylinders, bamboo is
  cylinders, coral is cylinders, pillars are cylinders. It reads as low-poly tycoon, but
  Creator Store meshes (trees, rocks, torii, lanterns, crystals) would lift it.
- **Terrain is flat.** Cliffs are box fills; no sculpted hills, caves or height variation.
- **Skybox** is Roblox's default blue sky (no custom skybox textures). Sakura Void's "dark
  sky" is a black slab overhead with neon dots, not a real night sky.
- **Particles use the two built-in textures** (sparkles, smoke). Petals, embers, snow and
  bubbles all use those; custom particle textures would help a lot.
- **Sounds are the built-in Roblox library** (unsheath, spring, click, ghost howl, victory...).
  They work everywhere but sound generic; pick real SFX and paste ids into `Shared/Sounds.luau`.
  There is no music.
- **No custom animations.** Player run/walk/jump are defaults; carry pose is the tool-hold
  animation; boss attack is the classic sword slash.
- **UI icons are emoji.** Fine for now; icon images would look more polished.
- **No 3D text/logo, no loading screen, no thumbnail.**
