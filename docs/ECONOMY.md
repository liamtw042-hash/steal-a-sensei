# Economy tuning (2026-09-15 rebalance)

Targets from the design brief, for a dedicated **free** player:

| Milestone | Target | Requirement (Config/Rebirth.luau) |
| --- | --- | --- |
| Rebirth 1 | ~1 hour | $500K + one Rare |
| Rebirth 5 | ~1 day (6–8 h played + AFK) | $250M + one Legendary |
| Rebirth 10 | ~1 week | $1T + one Mythic |

## The numbers (all in `src/shared/Config/`)

**Cash per second per fighter, level 1, no mutation** (`Fighters.RarityCashPerSecond`):

| Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
| --- | --- | --- | --- | --- | --- | --- |
| 25 | 120 | 600 | 3,000 | 40,000 | 250,000 | 1,500,000 |

Each level adds +10% (level 10 = 1.9x). Mutations: Shiny 1.5x, Shadow 2x, Golden 3x, Void 5x.
Rebirth multiplier = 1 + rebirths (max 16). VIP 2x.

**Hatch times (s):** Common 20, Uncommon 40, Rare 75, Epic 150, Legendary 300, Mythic 480, Secret 720.

**XP:** 20 per minute placed. Level 10 needs ~2,385 XP total = **2 hours placed**. Reaching level 10
evolves the fighter into a random fighter of the next rarity (or its `evolvesInto` target).

**Fuse:** 3 fighters with the same name → 1 random fighter of the next rarity.

**Punching bag** (`Power.PunchingBag`): walk up to the bag in your base, hold E, and you land
one punch a second. Five levels, bought with cash.

| Level | Power / punch | Power / minute held | cost to reach |
| --- | --- | --- | --- |
| 1 | 25 | 1.5K | free |
| 2 | 1,000 | 60K | $5K |
| 3 | 40,000 | 2.4M | $500K |
| 4 | 1,600,000 | 96M | $50M |
| 5 | 64,000,000 | 3.84B | $10B |

Each level carries you roughly two zones. Time to reach a zone gate from zero, holding E:

| Zone | Power needed | at the level you'd own by then |
| --- | --- | --- |
| 2 Bamboo Forest | 5K | free rewards cover it (10K) |
| 4 Storm Peak | 500K | Lv 2 → 8 min |
| 6 Volcanic Dojo | 50M | Lv 3 → 21 min |
| 8 Ancient Ruins | 5B | Lv 4 → 52 min |
| 10 Sakura Void | 500B | Lv 5 → 2.2 h (index rewards cut this a lot) |

**Zone Power gates** are unchanged from the brief (5K, 50K, 500K, 5M, 50M, 500M, 5B, 50B, 500B).

## Why it hits the targets

**Rebirth 1 in ~1 hour.**
Free rewards give 10K Power on the spot → zones 1–2 open. A scroll run in zone 1–2 takes
about a minute (walk out, grab, walk back) and hatches in 20–40s, so after ~20 minutes a
player has ~14 fighters and 10 filled slots. A typical mix (4 Common + 6 Uncommon) earns
`4×25 + 6×120 = 820/s ≈ $49K/min`, so $500K takes ~10 minutes of income on top of that.
The Rare comes from fusing three identical Uncommons (zone 2 rolls Uncommon 35% of the
time, two Uncommon names in the roster → ~6 Uncommon hatches for a matching three). Total
≈ 45–60 minutes.

**Rebirth 5 in ~1 day.**
Rebirths 2–4 need $2.5M / $10M / $50M with the 2x–4x multiplier stacking; Rares (600/s)
from zone 4 need 500K Power, which bag level 2 delivers in ~8 minutes of holding E (level 2
costs $5K, affordable in the first few minutes). Epics (3,000/s) need zone 6
(50M Power): bag level 3 ($500K — affordable around rebirth 1) makes 50M in ~21 minutes.
Legendary for rebirth 5 comes from fusing 3 Epics (or evolving one
Epic to level 10 = 2 hours placed). $250M at 5x multiplier with ten Epics (150K/s) is
~28 minutes. Total: 6–8 hours of play plus bag time.

**Rebirth 10 in ~1 week.**
$1T at the 10x multiplier with 26 slots of Legendaries (40K/s each → 10.4M/s) is ~27
hours of placed time; Golden/Void mutations and evolutions shorten that a lot. The
Mythic comes from fusing 3 Legendaries (zone 8–9, 5B Power → bag level 4 at $50M, well
inside rebirth 4–5 income) or from zone 10 at 500B Power (bag level 5 at $10B for ~2.2h of
holding E, or the zone 9 index reward of +120B Power). Rebirths 6–9 need $1B–$150B, each 1–4 hours at their multipliers. Total: roughly 5–7 days of an
hour or two a day plus bag time.

## Knobs to turn if it's off

- Too slow early: raise `Uncommon` cps or lower `Requirements[1].cash`.
- Rare too hard: change `Requirements[1].fighterRarity` to "Uncommon" or make zone 3 roll
  some Rares in `Zones.luau` scrollPool.
- Mid-game grind: the bag's `powerPerPunch` and `upgradeCost` tables are the lever.
- Late game: `Legendary` cps and `Requirements[10].cash`.
