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

**Treadmill** (`Speed.Treadmill`): rate = `25 × 1.55^(L-1)` speed/s, upgrade cost = `1000 × 1.9^(L-1)`.

| Level | speed / s | speed / hour | upgrade cost to next | cumulative cost |
| --- | --- | --- | --- | --- |
| 1 | 25 | 90K | $1K | $0 |
| 5 | 144 | 520K | $13K | $19K |
| 10 | 1.3K | 4.7M | $323K | $680K |
| 15 | 11.6K | 42M | $8M | $17M |
| 20 | 104K | 375M | $196M | $410M |
| 25 | 934K | 3.4B | $4.8B | $10B |
| 30 | 8.4M | 30B | $120B | $250B |
| 35 | 75M | 270B | $2.9T | $6T |
| 40 | 675M | 2.4T | max | $150T |

**Zone speed gates** are unchanged from the brief (5K, 50K, 500K, 5M, 50M, 500M, 5B, 50B, 500B).

## Why it hits the targets

**Rebirth 1 in ~1 hour.**
Free rewards give 10K speed on the spot → zones 1–2 open. A scroll run in zone 1–2 takes
about a minute (walk out, grab, walk back) and hatches in 20–40s, so after ~20 minutes a
player has ~14 fighters and 10 filled slots. A typical mix (4 Common + 6 Uncommon) earns
`4×25 + 6×120 = 820/s ≈ $49K/min`, so $500K takes ~10 minutes of income on top of that.
The Rare comes from fusing three identical Uncommons (zone 2 rolls Uncommon 35% of the
time, two Uncommon names in the roster → ~6 Uncommon hatches for a matching three). Total
≈ 45–60 minutes.

**Rebirth 5 in ~1 day.**
Rebirths 2–4 need $2.5M / $10M / $50M with the 2x–4x multiplier stacking; Rares (600/s)
from zone 4 need 500K speed, which treadmill level 10 delivers in ~7 minutes AFK (level 10
costs $680K cumulative, affordable right after rebirth 1). Epics (3,000/s) need zone 6
(50M speed): treadmill level 20 (cumulative $410M — reachable during rebirth 4) makes
50M in ~8 minutes. Legendary for rebirth 5 comes from fusing 3 Epics (or evolving one
Epic to level 10 = 2 hours placed). $250M at 5x multiplier with ten Epics (150K/s) is
~28 minutes. Total: 6–8 hours of play plus AFK treadmill time.

**Rebirth 10 in ~1 week.**
$1T at the 10x multiplier with 26 slots of Legendaries (40K/s each → 10.4M/s) is ~27
hours of placed time; Golden/Void mutations and evolutions shorten that a lot. The
Mythic comes from fusing 3 Legendaries (zone 8–9, 5B speed → treadmill level 28,
cumulative ~$100B, well inside rebirth 8–9 income) or from zone 10 at 500B speed
(treadmill level 32–33 for ~6h AFK, or the zone 9 index reward of +120B speed). Rebirths
6–9 need $1B–$150B, each 1–4 hours at their multipliers. Total: roughly 5–7 days of an
hour or two a day plus AFK.

## Knobs to turn if it's off

- Too slow early: raise `Uncommon` cps or lower `Requirements[1].cash`.
- Rare too hard: change `Requirements[1].fighterRarity` to "Uncommon" or make zone 3 roll
  some Rares in `Zones.luau` scrollPool.
- Mid-game grind: the treadmill cost base (`1000`) and growth (`1.9`) are the lever.
- Late game: `Legendary` cps and `Requirements[10].cash`.
