# Status: what's verified, what needs a playtest, known limits

Last updated 2026-09-15.

## Verified

**Static (every commit):** `luau-lsp analyze` in strict mode over all of `src/` with the
Roblox type definitions, StyLua formatting, `rojo build` to a place file.

**Live in Studio (Rojo connected to the open "Steal a Sensei" baseplate, one player):**

- Rojo plugin connects and syncs; server + client start with no errors.
- Dev map auto-generates (zones, bases, spawn) on the blank baseplate.
- HUD, rail buttons, base panel (tabs, slot list), hotbar all render.
- Player is assigned Base 1 and spawns inside it; 30s join auto-lock counts down, unlock
  cooldown shows, Lock button appears when open.
- Zone boss spawns as a default R15 rig and patrols.
- Grabbing a scroll from a nest: carry indicator, "BRUTE IS CHASING YOU" warning.
- Boss chase + catch: caught toast, scroll dropped at the catch point, player launched to spawn.
- Reaching your own base with a scroll: "secured" toast, hatching scroll rendered in Slot 1,
  hatched into a fighter after the configured time, hatch toast, fighter model + label
  rendered, income starts ($4/s), cash rises on the HUD and leaderboard.

## Needs a real playtest (written, type-checked, not yet exercised)

Most of these need two or more players, real gamepass ids, or a lot of time:

- Zones 2–10 gates and all nine gimmicks (Corners, Teleport, SlowPatch, FireTrail, Pull,
  Boulder, Clones, OneHit). Only the Brute (no gimmick) was watched.
- Boss camping an unlocked base entrance vs bouncing off a locked one.
- Levelling, evolution at level 10, fusing, Index rewards (time-gated; xp is 10/min).
- Stealing: prompt, thief slow, owner alert + highlight, carrying home, level reset, loose
  fighter pickup/return, "vanish on rebirth".
- Laser gates for non-owners, friend whitelist, intruder ejection, alarm trap, guard NPC.
- Rebirth flow end to end (needs $500K + a Rare).
- Gamepasses / developer products (all ids are 0 until you create them), receipt handling,
  speed multiplier stacking, VIP, Growth, +5 Slots, Guard.
- Combat items (Slap, Trap, Smoke Bomb, Grapple, Body Swap, Shield): server logic exists and
  hotkeys are wired, but none were fired against another player.
- Events: Rift (first fires 5 min after server start), Void Surge (8 min), Hungry Sensei
  (15 min), token shop.
- Free rewards claim flow (group id is 0 so the group check is skipped).
- Data persistence across rejoins (Studio had API access disabled, so ProfileService used
  its mock store).
- Mobile / touch layout. The UI is fixed-size pixels; it will need scaling for phones.

## Known limits and honest caveats

- **Speed passes stack to ×2^55** if someone owns all ten, exactly as specified. That is
  likely far too strong; tune `Config/Speed.luau` MultiplierPasses.
- **Like / favourite rewards can't be verified**: Roblox has no API for it. They are honour
  system with a 5s "checking" delay. Group join is verified for real.
- **Boss pathfinding depends on your map**: bosses use PathfindingService with jump enabled.
  Narrow doors, floating platforms or unwalkable terrain will make them fall back to
  straight-line MoveTo and possibly get stuck (there is a stuck nudge + return-home timeout).
- **Gate collision is client-side** (standard Roblox pattern). The server ejects anyone who
  gets inside a locked base they're not allowed in, so exploiters gain nothing lasting, but
  they can visually clip a gate.
- **One scroll or fighter carried at a time.**
- **Per-rebirth slots before floor 2**: the +1 slot per rebirth only becomes usable if there
  are extra Floor-1 slot parts (see STUDIO_CHECKLIST.md). The dev map doesn't add any.
- **No animations, sounds, or real VFX**: effects are neon spheres and screen flashes, ready
  to be replaced.
- **Placeholder fighter stats and economy numbers**: everything scales roughly but the curve
  hasn't been balanced against real play. Rebirth 10 at $1T will take a very long time with
  the current cps table; adjust `RarityCashPerSecond` and the roster.
- **Studio command bar note**: during testing the character was teleported with the command
  bar (Client context). Those commands are not part of the game.
- Knit's client half is typed as `any` on the client (its package entry point is typed for
  the server), so client calls to services aren't type-checked beyond what strict Luau can
  see locally.
