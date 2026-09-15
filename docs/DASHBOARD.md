# Roblox Creator Dashboard: passes and products to create

Create these under your experience → **Monetization**. Then paste each id into
`src/shared/Config/Monetization.luau` (the `id = 0` fields). An id of 0 means the shop
shows the item but refuses the purchase with a warning, so nothing breaks while they're
missing.

Also set your group id in `src/shared/Config/Speed.luau` → `FreeRewards.groupId`
(0 = the group reward is given without checking).

## Gamepasses (14)

| Key in config | Name | Price (R$) | Effect |
| --- | --- | --- | --- |
| `Speed2x` | 2x Speed | 5 | speed stat ×2 |
| `Speed4x` | 4x Speed | 10 | speed stat ×4 |
| `Speed8x` | 8x Speed | 20 | speed stat ×8 |
| `Speed16x` | 16x Speed | 40 | speed stat ×16 |
| `Speed32x` | 32x Speed | 80 | speed stat ×32 |
| `Speed64x` | 64x Speed | 160 | speed stat ×64 |
| `Speed128x` | 128x Speed | 320 | speed stat ×128 |
| `Speed256x` | 256x Speed | 640 | speed stat ×256 |
| `Speed512x` | 512x Speed | 1,280 | speed stat ×512 |
| `Speed1024x` | 1024x Speed | 2,560 | speed stat ×1024 |
| `VIP` | VIP | 200 | 2x cash, +10s lock, VIP tag |
| `Growth2x` | 2x Growth | 150 | fighters gain XP twice as fast |
| `Slots5` | +5 Slots | 100 | five permanent extra base slots |
| `Guard` | Base Guard | 250 | guard NPC patrols your base and slows intruders |

All speed passes stack multiplicatively (owning all ten = ×2^55). That is the design as
specified; tune prices/multipliers in `Config/Speed.luau` + `Config/Monetization.luau`.

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
