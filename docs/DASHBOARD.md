# Roblox Creator Dashboard: passes and products to create

Create these under your experience → **Monetization**. Then paste each id into
`src/shared/Config/Monetization.luau` (the `id = 0` fields). An id of 0 means the shop
shows the item but refuses the purchase with a warning, so nothing breaks while they're
missing.

Also set your group id in `src/shared/Config/Power.luau` → `FreeRewards.groupId`
(0 = the group reward is given without checking).

## Gamepasses (14)

| Key in config | Name | Price (R$) | Effect |
| --- | --- | --- | --- |
| `Power2x` | 2x Power | 5 | Power ×2 |
| `Power4x` | 4x Power | 10 | Power ×4 |
| `Power8x` | 8x Power | 20 | Power ×8 |
| `Power16x` | 16x Power | 40 | Power ×16 |
| `Power32x` | 32x Power | 80 | Power ×32 |
| `Power64x` | 64x Power | 160 | Power ×64 |
| `Power128x` | 128x Power | 320 | Power ×128 |
| `Power256x` | 256x Power | 640 | Power ×256 |
| `Power512x` | 512x Power | 1,280 | Power ×512 |
| `Power1024x` | 1024x Power | 2,560 | Power ×1024 |
| `VIP` | VIP | 200 | 2x cash, +10s lock, VIP tag |
| `Growth2x` | 2x Growth | 150 | fighters gain XP twice as fast |
| `Slots5` | +5 Slots | 100 | five permanent extra base slots |
| `Guard` | Base Guard | 250 | guard NPC patrols your base and slows intruders |

All Power passes stack multiplicatively but the total is **capped at 1024x**
(`Config/Power.luau` → `MaxMultiplier`). Owning 2x+4x+8x+16x already reaches the cap, so
the 32x–1024x passes only add value for players who skipped lower ones. If you want every
pass to be worth buying, change the maths in `Shared/Util/PowerMath.luau` to additive.

## Developer products (6) — combat shop

| Key in config | Name | Price (R$) | Type |
| --- | --- | --- | --- |
| `Slap` | Slap | 50 | permanent |
| `Trap` | Trap (5 uses) | 30 | 5 uses |
| `SmokeBomb` | Smoke Bomb (5 uses) | 40 | 5 uses |
| `Grapple` | Grapple | 120 | permanent |
| `BodySwap` | Body Swap (3 uses) | 80 | 3 uses |
| `Shield` | Shield | 200 | permanent |

Slap is also granted free at rebirth 1, and 5 traps are granted at every rebirth from 2.

## Game settings to flip

- **Security → Enable Studio Access to API Services**: so ProfileService saves from Studio tests.
- **Options → Max players**: 8 (there are exactly eight bases; a ninth player gets no base).
- Publish the place before creating passes (the dashboard needs a published experience).
