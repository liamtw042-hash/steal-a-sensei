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

**Punching bag** (`Power.PunchingBag`): walk up to the bag in your base and hold the punch
input (left mouse on PC, R2 on gamepad, the on-screen button on mobile). One punch a second.
Five levels, bought with cash.

| Level | Power / punch | Power / minute held | cost to reach |
| --- | --- | --- | --- |
| 1 | 1 | 60 | free |
| 2 | 10 | 600 | $500 |
| 3 | 100 | 6K | $50K |
| 4 | 1,000 | 60K | $5M |
| 5 | 10,000 | 600K | $500M |

Each level is worth one zone step: at the level you can afford, the next gate is about
8 minutes of holding.

| Zone | Power needed | bag level | time holding |
| --- | --- | --- | --- |
| 2 Bamboo Forest | 5K | 2 | 8 min (free rewards give 10K anyway) |
| 3 Shadow Village | 50K | 3 | 8 min |
| 4 Storm Peak | 500K | 4 | 8 min |
| 5 Frozen Temple | 5M | 5 | 8 min |
| 6 Volcanic Dojo | 50M | 5 | 83 min |
| 7 Abyss Shrine | 500M | 5 | 14 h |
| 8+ | 5B and up | 5 | not reachable by punching alone |

**The bag tops out at zone 6.** From zone 7 on, Power has to come from index rewards
(+1.2M at zone 4, +12M at 5, +120M at 6, +1.2B at 7, +12B at 8, +120B at 9) and the Power
gamepasses, which multiply the stat up to 1024x. In practice a zone's Index set unlocks the
zone about two ahead of it, so the late game is collect-a-set rather than hold-the-button.
If you'd rather the bag carried players further, raise `powerPerPunch[5]` — that one number
is the whole late-game curve.
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
from zone 4 need 500K Power, which bag level 4 delivers in ~8 minutes of holding (level 4
costs $5M, affordable around rebirth 2-3). Epics (3,000/s) need zone 6
(50M Power): bag level 5 ($500M) makes 50M in ~83 minutes, or the zone 5 index set gives 12M outright.
Legendary for rebirth 5 comes from fusing 3 Epics (or evolving one
Epic to level 10 = 2 hours placed). $250M at 5x multiplier with ten Epics (150K/s) is
~28 minutes. Total: 6–8 hours of play plus bag time.

**Rebirth 10 in ~1 week.**
$1T at the 10x multiplier with 26 slots of Legendaries (40K/s each → 10.4M/s) is ~27
hours of placed time; Golden/Void mutations and evolutions shorten that a lot. The
Mythic comes from fusing 3 Legendaries (zone 8–9 needs 5B–50B Power, which comes from the
zone 7–8 index sets at +1.2B and +12B) or from zone 10 at 500B Power (the zone 9 index set
gives +120B, and the Power passes multiply it). Rebirths 6–9 need $1B–$150B, each 1–4 hours at their multipliers. Total: roughly 5–7 days of an
hour or two a day plus bag and index time.

## Knobs to turn if it's off

- Too slow early: raise `Uncommon` cps or lower `Requirements[1].cash`.
- Rare too hard: change `Requirements[1].fighterRarity` to "Uncommon" or make zone 3 roll
  some Rares in `Zones.luau` scrollPool.
- Mid-game grind: the bag's `powerPerPunch` and `upgradeCost` tables are the lever.
- Late game: `Legendary` cps and `Requirements[10].cash`.
