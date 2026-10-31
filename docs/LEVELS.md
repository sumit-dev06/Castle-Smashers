# Levels

## Campaign
50 levels in 5 realms, 10 per realm. Designed in `tools/campaign.py` and built by `tools/gen_levels.py`
(pieces: floors in wood/stone/crystal/iron, towers with tiled roofs + flags, stacks, walls,
terraces, balconies, bridges, pyramids, moving decks, rope loads, hanging platforms, crushers,
geysers, bolts, boss units). Animated story scenes play on realm openers, new mechanics, hero
unlocks, rescues and bosses. Every 10th level is a moving boss castle with a multi-phase boss
and power budget 9 (others 8):
siege tower on wheels (10), sandstone citadel with a sliding keep (20), iron galleon on the swell (30),
foundry on rails (40), the Baron's airship (50).

Hero unlocks: Rocky 1, Blaze 3, Boomer 6, Twister 12, Quaky 22.

| Realm (gap) | Levels |
|---|---|
| 1 Blossom Valley (water) | 1 Wooden Watchtower, 2 The Hanging Rock, 3 Lantern Pagodas, 4 Petal Bridge, 5 Bolted Balconies, 6 Moonlit Storehouse, 7 Seesaw Watch, 8 Captive Shrine, 9 River Gondola, 10 The Siege Tower **(boss)** |
| 2 Desert Ruins (water) | 11 Sandstone Ruins, 12 Twin Mesas, 13 Crusher Gate, 14 Domino Ruins, 15 Boulder Run, 16 Powder Caravan, 17 Boulder Trap, 18 Prisoner Well, 19 Ropebridge Ambush, 20 Sandstone Citadel **(boss)** |
| 3 Pirate Harbor (sea) | 21 Dockside Shacks **(tide)**, 22 Smugglers' Pier, 23 Harbor Bell **(tide)**, 24 Harbor Lighthouse, 25 Water Spout, 26 Two Ships **(tide)**, 27 Dockside Crane, 28 Captive Brig **(tide)**, 29 Storm Watch **(wind)**, 30 The Iron Galleon **(boss, tide)** |
| 4 Crystal Mines (lava) | 31 Crystal Cavern, 32 Powder Express, 33 Rail Cart, 34 Lava Plume, 35 Runaway Wheel, 36 Powder Magazine, 37 Hanging Cages, 38 Iron Forge, 39 Wrecking Ball, 40 The Foundry **(boss)** |
| 5 Sky Islands (clouds) | 41 First Island **(wind)**, 42 Island Hop **(wind)**, 43 Spring Trap **(wind)**, 44 Ice Slide, 45 Windmill Isle **(wind)**, 46 Sky Seesaws, 47 Sky Captive **(wind)**, 48 Twin Airships **(wind)**, 49 Baron's Contraption **(wind)**, 50 The Baron's Airship **(boss, wind)** |

Physics set-pieces (built from `ramps`, `tethers` and mechanisms): seesaw (7), rolling logs (11),
heavy throwing beam (12), dominoes (14), boulder run (15), boulder trap on a latch (17), visible
pulley/counterweight drawbridge (18), collapsing rope bridge (19), flood gate (21), breakable cliff
ledge (22), hanging bell (23), crane with counterweight (27), explosive powder cart (32), runaway
wheel (35), hanging cages (37), triggered water wheel/gears (38), wrecking ball on a latch (39),
spring trap (43), ice slide (44), twin seesaws (46), and cart → dominoes → keep (49). Run
`--run-tests=contraptions`.

Phase D materials and mechanisms in the campaign: windmill (45), lever (18), rune switch +
trap door (24), rune crystal (31, 36), ice (41, 47), iron (38, 40), shield ring (20, 40, 50).
Challenges and secret levels 111-115 use them too.

## Master Sieges special pack
Master Sieges unlocks at **25 campaign stars**. It lives on the Challenges screen but is indexed
separately from ids 101–108, so none of these levels enters the daily rotation. The ten levels use
fixed four-shot loadouts, normal challenge rewards, and `required_mechanics` metadata. Their iron
rooms and protected guards make the listed contraptions the intended route rather than decoration.

| ID | Level | Required mechanics |
|---:|---|---|
| 121 | Flooded Foundry | flood gate |
| 122 | Mill of Teeth | triggered water wheel/gears |
| 123 | The Last Rope | collapsing rope bridge |
| 124 | Faultline Vault | breakable cliff ledge |
| 125 | Counterweight Hall | drawbridge pulley/counterweight |
| 126 | Powder Express II | explosive powder cart |
| 127 | The Siege Pitcher | heavy seesaw launch |
| 128 | Clockwork Deluge | water wheel + flood gate |
| 129 | Bridge at World's End | collapsing bridge + breakable cliff |
| 130 | Master's Chain | explosive cart + launch beam |

Run `--run-tests=specials` for catalog, gate, required-mechanic, daily-isolation, 10-second stability,
and 20:9/16:9 framing checks.

Bosses: Siege Warlord (10), Sandstone Sultan (20), Captain Ironhook (30), The Forgemaster (40),
The Iron Baron (50).

To change a level, edit its function in `tools/campaign.py` and run `python3 tools/gen_levels.py`;
don't hand-edit the JSON. Each `LEVELS` entry is `(name, realm, build_fn, heroes, extras, scene,
strategy)`; `extras` holds `wind` / `tide`. Scene beats are written with the helpers `T` (title),
`E` (enter), `S` (say), `M` (emote), `F` (focus), `D` (demo), `H` (hero), `B` (boss) and `MARCH`.
`make_scene` adds the boss and new-hero beats automatically; targets like `@crusher` resolve to
`mech:i` (`resolve_target`).

## Training ranges
`data/training/training_<hero>.json` (stone, fire, bomb, cyclone, quake), same format as levels plus
`training` and `before_level`. Built by `write_training()` in `tools/gen_levels.py`.

## File format (`data/levels/level_001.json`)
```json
{
  "id": 1,
  "name": "Wooden Watchtower",
  "realm": 1,
  "heroes": ["stone", "stone", "stone"],
  "story": [{"who": "captain", "text": "..."}],
  "soldiers": 3,
  "star_scores": [10000, 25000, 40000],
  "camera_right": 2600,
  "blocks": [
    {"type": "post", "x": 1600, "y": -60},
    {"type": "plank_long", "x": 1660, "y": -132, "rot": 0}
  ],
  "archers": [ {"x": 1660, "y": -175} ],
  "bg_variant": 0,
  "stage": {"ledge_right": 470, "bases": [{"x0": 778, "x1": 1193, "top": 0}]}
}
```
- `x`, `y` are the **centre** of the block in world pixels, ground top is `y = 0`.
- `rot` in degrees (optional). `type` keys come from `data/materials.json` → `shapes`.
- `stage` = the catapult ledge edge and the fortress bases (islands) across the gap. `gen_levels.py`
  builds bases from the grounded footprint (+50 px margin, pieces >200 px apart get separate islands,
  first base at least 260 px after the ledge). Optional `gap` / `surface_y` override the realm's gap.
  Optional per-base `art`: `wide` or `small`.
- `terrace(x0, x1, dy)` in the generator raises an island; `deck(...)` puts a fortress on a
  moving platform (optional `chassis`/`balloon` art, `floating` = hangs over the gap).
- `camera_top` = highest point of the level; the resting camera zooms out to keep it on screen.
- `bg_variant` picks the realm painting variant (alternates per level).
- `heroes` is the queue order. `star_scores` thresholds for 1/2/3 stars.
- `mechanisms`: gate, drawbridge, moving_platform, swing, spikes, lava, `rope_load`, `hanging_platform`,
  `crusher` (`mode`: `cycle`/`trigger`), `geyser`, `frame`. A rope load can name `releases` (indices
  of mechanisms it triggers when cut).
  Phase D: `lever` (`triggers`: ids it fires, `facing`), `windmill` (`arms`, `arm_len`, `dps`,
  `hits_blocks`, `triggers` on jam), `shield_ring` (`radius`, `plates`, `plate_len`, `dps`; its
  `trigger` stops it), `rune_switch` (`triggers`; place a block over it), `trapdoor` (`size`, `hinge`
  -1/1, `trigger`; `style: rock|timber` makes a breakaway ledge), and `flood` (`pool`, `pool_h`,
  `reach`, `depth`, optional `trigger`). A `windmill` with `style: wheel` and `start_on` is a water
  wheel that waits for its brake trigger. Generator helpers include
  `Fort.lever/windmill/water_wheel/shield_ring/rune_switch/trapdoor/flood/ledge`.
- `bolts`: `[[block_a, block_b], ...]` block-index pairs pinned together (snap on damage/blast).
- `wind`: `{strength, period_s, gust_s, dir, alternate}`. `tide`: `{amp_px, period_s}`.
- `boss_unit`: `{name, hp, x, y, phases: [{at, do: [reinforce|shield|enrage|charge]}], reinforce: [[x, y]]}`.
- `mode` / `mode_cfg`: heist (`need`), time_attack (`time_s`, `refill`, `star_time`), one_shot,
  survival (`waves: [{archers, heroes}]`), reverse_siege (engines carry `approach`). Regular daily
  candidates come from `tools/campaign.py` → `CHALLENGES`; secrets use `SECRETS`; Master Sieges use
  `SPECIALS` + `SPECIAL_REQUIRED`. All JSON lives in `data/challenges/`, while `index.json` keeps
  `challenges` and `specials` as separate lists. Special JSON has `special: true` and
  `required_mechanics`.
- `engineers`: `[{x, y}]` boss-rig engineers. Blocks `power_core` and `cannon_turret` make the boss rig.
- `cinematic`: the story beats (see `docs/ARCHITECTURE.md` → Cinematics). `callouts`: up to 3
  `{target, text}` shown in the opening flyover.

## Block shapes (`data/materials.json`)
| Type | Size (px) | Material |
|---|---|---|
| `plank_long` | 220×26 | wood |
| `plank_short` | 110×26 | wood |
| `post` | 26×120 | wood |
| `post_tall` | 26×200 | wood |
| `crate` | 64×64 | crate |
| `stone_block` | 64×64 | stone |
| `stone_slab` | 180×40 | stone |
| `stone_pillar` | 40×140 | stone |
| `roof` | 140×70 triangle | straw |
| `barrel` | 46×58 | barrel |
| `plank_xl` | 330×26 | wood |
| `roof_tile` | 250×100 triangle | tile (terracotta) |
| `crystal_block` | 64×64 | crystal (shatters, hurts neighbours) |
| `crystal_pillar` | 40×140 | crystal |
| `iron_block` | 64×64 | iron (very tough) |
| `iron_beam` | 220×26 | iron |
| `boulder` | 90 round | boulder (rolls) |
Blocks may carry `"flag": true` (roof flag) or `"banner": true` (red banner under a plank).

## Design rules
- Structure must stand still for 10 s with no input (`tests/` checks every level).
- Archers must be reachable by at least one shot. Tutorial levels: winnable with one good shot.
- Ground-level space between catapult (x 0) and fortress ≥ 1300 px.
