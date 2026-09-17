# Setup: connect this repo to Roblox Studio

Everything in `src/` syncs into Studio through Rojo. You never edit scripts in Studio;
you edit files here and Rojo pushes them live.

## One-time install (already done on this PC)

The toolchain is managed by [Rokit](https://github.com/rojo-rbx/rokit) and pinned in
`rokit.toml`: Rojo 7.5.1, Wally, luau-lsp, StyLua, selene. On a fresh machine:

```powershell
# install rokit (see its README), then in the repo folder:
rokit install
wally install
```

## Every time you work on the game

1. Open a terminal in `C:\Users\liamt\dev\steal-a-sensei` and run:

   ```powershell
   rojo serve
   ```

   Leave it running. It prints `Rojo server listening: localhost:34872`.

2. In Roblox Studio, with your **Steal a Sensei** place open:
   - Click the **Plugins** tab in the ribbon.
   - Click the **Rojo** button. A panel opens.
   - It should show the project name `steal-a-sensei` under "localhost:34872".
     If not, type `localhost` and port `34872`.
   - Click **Connect**.

3. The Explorer now shows:
   - `ReplicatedStorage > Packages` (Knit, Promise, Signal, Trove …)
   - `ReplicatedStorage > Shared` (Config, Types, Util)
   - `ServerScriptService > Server` (Runtime, Services, Boss, Util)
   - `ServerStorage > ServerPackages` (ProfileService)
   - `StarterPlayer > StarterPlayerScripts > Client` (Runtime, Controllers, UI)

4. Press **Play**. On a blank baseplate the server builds a placeholder map automatically
   (you'll see a yellow warning `[DevMap] No Workspace.Map found ...` in Output). That's the
   whole game running with block-rig bosses and placeholder fighters, so you can test every
   system before building the real map.

5. Edit any file under `src/`, save, and Rojo updates Studio instantly. Stop and Play again
   to restart the server scripts.

> Do **not** click "Sync back" / two-way sync. Files are the source of truth.

## Enabling saves in Studio

Data is stored with ProfileService. In Studio it only really saves if you enable
**Game Settings > Security > Enable Studio Access to API Services** (the place must be
published first). Without it, ProfileService uses an in-memory mock store and prints
`Roblox API services unavailable - data will not be saved`. That's fine for testing.

## Checking the code without Studio

```powershell
.\scripts\check.ps1        # strict type-check + lint + format check
.\scripts\check.ps1 -Fix   # also reformat with StyLua
rojo build -o build\StealASensei.rbxl   # build a standalone place file
```

`scripts\check.ps1` is what was used to verify every commit. Run it before pushing.

## Where to tune things

All numbers live in `src/shared/Config/`:

| File | What's in it |
| --- | --- |
| `Zones.luau` | the ten zones, every boss speed / catch radius / gimmick number, scroll rarity pools, respawn times |
| `Fighters.luau` | rarities, cash-per-second, hatch times, mutations, levelling, fuse rule, the roster, index rewards |
| `Power.luau` | Power → WalkSpeed curve, free rewards (+ group id), punching bag rates/costs, Power passes |
| `Base.luau` | lock timings, slot counts, theft slow, guard, alarm trap, VIP cash multiplier |
| `Rebirth.luau` | the 16-rebirth requirement table, max multiplier, gear unlocks |
| `Monetization.luau` | gamepass + developer product ids/prices, combat item numbers |
| `Events.luau` | rift / void surge / hungry sensei timings, token shop |

## Adding a fighter

Append an entry to `Roster` in `Fighters.luau` and (optionally) drop a Model named exactly
the same into `ReplicatedStorage.Fighters`. No other code changes.

## Adding a boss gimmick

Add a name to the `Gimmick` type in `Zones.luau` and a handler in `src/server/Boss/Gimmicks.luau`.
