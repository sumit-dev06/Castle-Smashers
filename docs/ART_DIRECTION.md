# Art Direction

## Target look
**`docs/reference/level_style_reference.png`** (owner's reference, "Twin Towers") is the target:
glossy cartoon characters and props with a **thin dark-brown outline (`#3a2212`)**, painted realm
backdrops, warm wood towers on grey stone bases, terracotta tiled roofs with red flags, red banners,
a grassy boulder cliff as ground, leafy branches/fence/bushes framing the screen, wooden-sign and
dark-slate HUD panels, round orange buttons with labels.

**Legal line:** we take the *style*, never the *content*. No birds, no green pigs, no Y-shaped
slingshot, no Rovio fonts or logos.

## Two art pipelines
| Asset type | Pipeline |
|---|---|
| Characters, realm backgrounds | AI images from the owner → `tools/cutout.py` → `assets/art/ai/cut/` |
| Blocks + damage stages, roofs, flags, banners, catapult, ground cliff, foreground framing, UI, map nodes | SVG from `tools/gen_art.py` |

### What `tools/cutout.py` does to AI images
1. Moves new files from `assets/art/ai/` to `art_source/ai/` (originals kept, never shipped).
2. Removes the white background by flood fill from the borders, plus large enclosed white pockets
   (e.g. inside a bow); small whites such as eyes and teeth stay.
3. Soft anti-aliased edge and colour decontamination so no white halo remains; specks removed.
4. Light colour grade, trim, one pixel scale per character family so all poses match in size.
5. Adds the 5 px dark-brown outline used by the rest of the art, then light sharpening.
6. Mirrors archers to face left. Backgrounds are graded and resized to 900 px tall.
7. Writes `meta.json` (feet point, body circle, sizes) used by `Art` to place sprites.

## Lighting and shape rules
- Light from top-left. Highlight = lighter tint + white ellipse at 25–40% opacity.
- Characters: ~70% body is one round shape. Eyes take ~30% of face width. Feet and hands are small.
- Blocks: corners rounded 6–10 px at 1x. Wood shows grain, stone shows 2–4 bricks with mortar.
- Silhouettes must read at 64 px tall on a phone.

## Palette
| Use | Colours |
|---|---|
| Sky | `#2f9df4` top → `#8fd6ff` → `#e4f7ff` horizon |
| Grass | `#7ccf3a` light, `#4f9e26` mid, `#2f6e1c` shadow |
| Wood | `#e0a35c` light, `#b8733a` mid, `#7e4a22` dark |
| Stone | `#d7dde4` light, `#a7b1bd` mid, `#6f7b89` dark |
| Iron | `#8a96a3`, `#56616e`, `#2f3842` |
| Our team (Vanguard) | blue `#3d7fe0`, gold `#ffc93a`, cream `#fff3d6` |
| Enemy (Redcaps) | red `#e04040`, maroon `#8e1f2a`, leather `#7a4b2a` |
| Fire | `#fff3a0` → `#ffb02e` → `#ff5a1f` |
| UI primary (play/next) | green `#5ccf3c` / `#2f9a28`; secondary orange `#ffae2b` / `#e06a10`; panels cream `#fff4dc` with wood frame |

## Characters
| Character | Description |
|---|---|
| **Rocky** (stone) | Round grey boulder with moss tuft on top, heavy brow, grumpy determined eyes, small chip on cheek |
| **Blaze** (fire pot) | Round orange clay pot, flame "hair" on top, fierce excited eyes, cork-band belt |
| **Boomer** (bomb) | Round navy-black bomb, short lit fuse curling up, huge grin, gold band |
| **Twister** (cyclone) | Pale teal swirl-shaped puff, spiral body, dizzy happy eyes, leaves orbiting |
| **Vanguard soldier** | Round blue-tunic soldier, gold-trim kettle helmet, small round shield, rosy cheeks, brave smile |
| **Redcap Archer** | Round red-hooded archer, pointed hood with feather, mischievous squint, short bow, leather quiver |
| **Iron Baron** (boss, later) | Big round armoured man, curled moustache, spiked iron helmet |

Current SVG placeholders exist for every character (`tools/gen_art.py`). Each character needs poses: idle, blink (eyes closed), hit/dizzy, and for projectiles: flying
(squashed with motion). Soldiers: idle, cheer, duck, knocked out. Archers: idle, draw bow, hit,
defeated.

## Biomes (5 realms)
1. **Blossom Valley** (gap: water): moonlit or dawn valley, cherry blossom, stone masonry ledges.
2. **Desert Ruins** (water): sandstone mesas, palms, ruined arches, layered red rock.
3. **Pirate Harbor** (sea): sunset or storm harbour, wooden piers on posts.
4. **Crystal Mines** (lava): dark rock with glowing cracks and crystals, mine-cart rails.
5. **Sky Islands** (clouds): floating grassy rocks over a sea of clouds.

Until the owner's AI art for a realm exists, its painting falls back to an older one (`fallback_bg`
in `balance.json`) and the stage pieces are SVG placeholders from `gen_art.py` (`stage_assets`).

Each background = 3 parallax layers: far (sky + mountains), mid (hills/landmarks), near (ground
decoration, bushes). Backgrounds are delivered sharp and softened in game (downscale + haze shader); the play area
(ledge, bases, fortress) stays sharp in front of them, like the reference screenshots.

## UI
Rounded panels with a wooden or cream bevel, big rounded buttons with a 6 px darker bottom edge
(pressed look), Lilita One for titles with a white-to-yellow gradient and dark brown shadow,
Fredoka for body text. Icons are simple filled SVG shapes.

## Asset list (phase 1)
`assets/art/svg/`: blocks (wood plank long/short/post, crate, stone square/long, roof, barrel) × 3
damage stages, debris pieces, catapult (base, arm, bucket, wheel), arrow, ground strip, sky
gradient + clouds + hills (placeholder background), all 4 heroes, soldier, archer, UI buttons,
star, coin, heart, pause/restart icons.
