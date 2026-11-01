# Levels

## Campaign
75 levels in 8 realms (10 per realm, the last realm has 5). Levels 51–75 are the expansion (git
branch `expansion-75`); see "Expansion" below. Levels 1–50:
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

Logs (11) and the wheel (35) are tough rollers (`log` and `wheel` materials): they roll down, ram
the first thing they hit with `balance.rolling_log` and stay whole, so they knock out one part of the
fort instead of the whole thing. Levels 6, 32 to 36 and 42 to 48 were made harder in the style of
level 49: fewer free barrels, stone or block bases, extra guarded posts and second guards on the
last towers.

Phase D materials and mechanisms in the campaign: windmill (45), lever (18), rune switch +
trap door (24), rune crystal (31, 36), ice (41, 47), iron (38, 40), shield ring (20, 40, 50).
Challenges and secret levels 111-115 use them too.

## Expansion: levels 51–75
Harder than 1–50: more guards, iron and stone shelters, fewer power heroes, and set pieces that
must be used. Bosses at 60, 70 and 75 have three or four phases.

| Realm (gap) | Levels |
|---|---|
| 6 Scarlet Highlands (water) | 51 Powder Ridge, 52 Chain Gallery, 53 Hidden Switch, 54 Weight of Stone **(plate)**, 55 Twin Levers **(relay)**, 56 The Counterweight, 57 Turning Shields, 58 Hanging Fortress, 59 Load-Bearing, 60 Thane Brakk's Wagon **(boss)** |
| 7 Storm Crags (sea) | 61 Raft Run, 62 Double Sluice, 63 Burning Bridge, 64 Frozen Stilts, 65 Lodestone **(magnet)**, 66 Upside Down **(gravity)**, 67 Portal Keep **(portals)**, 68 Bounce House **(bounce pads)**, 69 Storm Vault **(3-lamp relay)**, 70 Morwen's Barge **(boss, ward + portals)** |
| 8 Iron Citadel (lava) | 71 Armoured Bastion, 72 Ever-Mending Wall **(repair crystal)**, 73 Prison Tower, 74 Forge Trap, 75 The Iron Citadel **(final boss)** |

New realms set `"look"` in `balance.realms` (the older realm whose music and ambience they use).
Their own stage, foreground and background art is used whenever the file exists
(`Background.art_key`); a realm with one foreground corner mirrors it into the other.

### Gadgets (`src/game/gadget.gd`, level JSON `gadgets`, numbers in `balance.gadgets`)
| Type | What it does | Generator helper |
|---|---|---|
| `portal` | Pair of rings; shots and small blocks leave the partner along its `dir` | `f.portals(a, b, dir_a, dir_b)` |
| `gravity` | Field that replaces gravity with `g`; `start_on`, `trigger`, `duration_s` | `f.gravity(x, y, w, h, g, ...)` |
| `magnet` | Pulls (or `push`es) iron blocks in `radius`; its trigger toggles it | `f.magnet(x, y, ...)` |
| `bumper` | Springy mushroom, bounces shots and blocks at least `kick` px/s | `f.bumper(x, y, ...)` |
| `plate` | Fires `triggers` once `mass` of blocks or heroes rests on it | `f.plate(x, surface, triggers, mass)` |
| `relay` | Fires `triggers` when all `inputs` fire within `window_s` | `f.relay(x, y, inputs, triggers, window)` |
| `repair` | Crystal block that rebuilds broken blocks in `radius` until it breaks | `f.repair(block_index, radius, delay)` |

Scene targets: `@@portal` (first gadget of that type) resolves to `gadget:<i>`.

## Level challenges (`balance.feats`, `src/game/feats.gd`)
Extra goals for one campaign level each, listed at the top of the Achievements screen. Four open
ones are shown and the set changes every `rotate_hours` (24); a challenge done on any win counts even
when not shown, and stays listed until claimed. Kinds: `max_shots` (win using at most `n` heroes),
`no_ability`, `all_soldiers`, `chain` (at least `n`), `fast` (within `n` seconds of play). The level
shows "CHALLENGE: ..." at the start when one of the shown set is for it. Every entry is checked
winnable with `python3 tools/record_trailer.py --search LEVEL SHOTS [SECONDS] [--no-powers] [--fast]`
(its result line prints shots, powers, lost, chain and time).

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
