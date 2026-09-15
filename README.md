# Steal a Sensei

Roblox tycoon in an original anime style. Run into a zone, grab a scroll from a nest, and
the zone's boss chases you all the way home. Get inside your base gates and the scroll is
safe; get caught and you're launched to spawn and the scroll drops for anyone to grab.
Scrolls hatch into fighters that earn cash, level up and evolve. Raid unlocked bases to steal
fighters. Rebirth for permanent multipliers.

Built with **Rojo** (file sync), **Wally** (packages), **Knit** (framework), strict **Luau**.

## Docs

- [docs/SETUP.md](docs/SETUP.md): connect the repo to Studio, run, tune.
- [docs/STUDIO_CHECKLIST.md](docs/STUDIO_CHECKLIST.md): every part/folder/model to create in Studio.
- [docs/DASHBOARD.md](docs/DASHBOARD.md): every gamepass and developer product to create.
- [docs/STATUS.md](docs/STATUS.md): what's verified, what needs a playtest, known limits.

## Layout

```
src/shared/Config/     all tuning (zones, bosses, fighters, speed, base, rebirth, monetization, events)
src/shared/Util/       formatting, speed maths, economy, region tests
src/server/Services/   Knit services: Data, Speed, Zone, Carry, Boss, Base, Fighter, Theft, Rebirth,
                       Monetization, Combat, Event
src/server/Boss/       BossBrain state machine + Gimmicks
src/server/Util/       rigs, models, pathfinding, character helpers, dev map generator
src/client/Controllers Knit controllers: Data, HUD, Zone, Base, Shop, Index, Rebirth, Combat, Event, Effects
src/client/UI/         code-built UI toolkit (Make, Window, Toast, Theme)
```

## Quick start

```powershell
rojo serve
```

then Rojo plugin → Connect in Studio → Play. With no map built yet, a placeholder map is
generated so the full loop is playable on a blank baseplate.

## Checks

```powershell
.\scripts\check.ps1
```
