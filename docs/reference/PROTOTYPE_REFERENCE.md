# Prototype Reference (archived HTML version)

The first version of Castle Smashers was two HTML files (Matter.js physics + canvas drawing).
They were deleted on 2026-10-29 when the project restarted in Godot. This file keeps what was
worth knowing. Screenshots: `prototype_intro.png`, `prototype_map.png`.

**Use this for premise and ideas only. The new game is designed from scratch.**

## Premise
Our kingdom marches on enemy fortresses. A catapult hurls projectiles to smash walls, towers
and gates and defeat the guards inside. Clearing a fortress unlocks the next on a campaign map.

## Intro cutscene ("Gate Siege Prologue")
Our castle on a cliff (left) → army crosses a stone bridge over a river and waterfall → reaches
a grey stone gatehouse with a wooden gate and archers on the battlements (right).
Captions in order:
1. "THE SIEGE BEGINS — APPROACHING THE ENEMY GATE..."
2. "HALT! BREAK DOWN THE ENEMY WALL & GATE!"
3. "CATAPULT FIRE! SHATTER THE GATEHOUSE!"
4. "GATE BREACHED! VICTORY FOR THE VANGUARD!"

## Campaign
20 levels, 3 stars each (60 total), 5 biomes of 4 levels each.

| Biome | Name | Tagline |
|---|---|---|
| 1 | The Emerald Valley | Sunlit Alpine Valleys & Royal Meadows |
| 2 | The Golden Riverlands | Amber Estuary & Twilight Crossing |
| 3 | The Stormy Crags | Granite Crags & Thunder Basin |
| 4 | The Scarlet Highlands | Scarlet Ridge & Autumn Citadel |
| 5 | Imperial Fortress | Imperial Fortress Finale & Siege of Fire |

Level names: 1 Wooden Watchtower, 2 Twin River Bastion, 3 Royal Cliff Citadel, 4 Timber Outpost,
5 Stonebridge Crossing, 6 Barrel Wharf, 7 Twin Watchtowers, 8 The Long Hall, 9 Cliffside Smithy,
10 Powder Keg Keep, 11 Granite Sentinel, 12 Broken Span, 13 Twin Keeps, 14 Citadel Gate,
15 Highwatch Spire, 16 Barrel Bastion, 17 The Great Wall, 18 Royal Arsenal, 19 Ruined Fortress,
20 Castle Smashers Finale.

## Rules that worked
- 3 shots per level (4 from level 13).
- Win = all guards defeated. Lose = out of shots with guards alive.
- Score: 5,000 per guard + destruction% × 150 + 10,000 per unused shot.
- Stars: 3 if ≥2 shots left (or 1 left and ≥70% destruction); 2 if 1 left or ≥85%; else 1.

## Materials (Matter.js units, relative values are what matter)
| Kind | Density | Friction | Restitution | HP | Damage taken ×|
|---|---|---|---|---|---|
| wood | 0.0024 | 0.82 | 0.05 | 55 | 1.0 |
| xframe (braced wood) | 0.0028 | 0.86 | 0.04 | 70 | 0.7 |
| crate | 0.0022 | 0.74 | 0.08 | 42 | 1.15 |
| stone | 0.0055 | 0.90 | 0.03 | 130 | 0.30 |
| barrel (explodes) | 0.0026 | 0.70 | 0.10 | 28 | 1.6 |
| roof | 0.0022 | 0.80 | 0.04 | 65 | 0.8 |
Guard: 32×48, HP 24.

## Damage model
Impulse-based: `impulse = (1+e) * normalSpeed / (1/mA + 1/mB)`, ignored below a threshold.
Projectile hits ×1.3, falling rubble ×0.55 (only above a speed), ground hits only on hard falls.
A short per-body damage cooldown stopped resting contacts from draining HP.

## Visual style that worked
Flat cartoon, bright saturated sky gradient, layered mountains/hills, chunky rounded UI with
thick dark outlines, fonts Lilita One (titles) and Fredoka (body), orange primary buttons,
dark translucent pill HUD chips, parchment campaign map.

## What was missing
No characters with personality, no animation, synthesized "beep" audio, single projectile type,
no ads/IAP, browser-only.
