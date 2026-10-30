# Signature Features (Phase D design)

**Identity:** Think strategically. Master the siege. Smash the fortress. Conquer the kingdom.

Every level is a problem to solve (which hero, which material, which mechanism to trigger first) and
every good solution should end in a big, readable collapse. This doc says what each pillar means in
this game, what already exists, and what Phase D adds. Numbers go in `data/*.json`; the values here
are starting points.

## 1. Material-specific interactions
Each hero has a `material_mult` per material (`data/projectiles.json`), so the right hero matters.

| Material | Behaviour | Best answer | Status |
|---|---|---|---|
| Wood, crate, straw | Burns: fire spreads to touching wood | Blaze | done |
| Stone | Cracks in 3 stages, heavy | Rocky, Rumbler | done |
| Powder barrel | Explodes, chains into other barrels | anything | done |
| Crystal | Shatters and cuts neighbours | Rocky | done |
| **Ice** (new) | Slippery (friction 0.05), low HP, shatters into shards; fire melts it fast (×3) | Blaze, Rocky | done |
| **Iron** (changed) | Barely damaged; a hard hit **bends** a beam into a V so pieces slide off it; fire makes it **red-hot** for 5 s (takes ×2.5 damage) | Blaze, then Rocky or Boomer | done |
| **Rune crystal** (new) | Magic: **absorbs** blasts, fire and quakes without damage, then **redirects** the energy as a beam in the direction of its rune arrow, breaking what is in line | aim a blast at it | done |

The loadout screen shows the fortress materials and marks the heroes that are strong against them.

Built (numbers in `data/materials.json`):
- **Ice** (`ice_block`, `ice_slab`, `ice_pillar`): friction 0.05, 40 HP, takes ×1.3. Fire melts it at
  32 HP/s (no flames, no spreading) and Blaze does ×3. It shatters into ice shards that hurt
  blocks within 100 px.
- **Iron bend:** a single hit of 14% of max HP or more folds an `iron_beam` into `iron_beam_bent`
  (a V with a two-part collider, +300 points, a chain link). It stays bent.
- **Red-hot iron:** fire heats iron for 5 s instead of burning it. It glows orange and takes ×2.5.
- **Rune crystal** (`rune_crystal`, decor `dir` in degrees for the arrow): 150 HP. Blasts, fire,
  quakes and beams are absorbed. After 0.35 s it fires a 1200 px beam (110 damage, per-material
  multipliers, ignites wood, heats iron, melts ice, 30 damage to guards, cuts ropes, snaps bolts).
  A beam that hits another rune crystal charges it, so beams can be bounced. 1 s cooldown.
- **Loadout:** a FORTRESS strip lists materials with counts; tapping one shows its tip. Heroes whose
  block-weighted multiplier is at least ×1.2 get a STRONG HERE badge.

## 2. Interactive mechanical castles
Done: gates and drawbridges with pulley and counterweight rigs, moving platforms, swings, spikes,
lava, cuttable rope loads, hanging platforms, crushers, geysers, bolted joints, weak points.

Phase D (built, tunables in `balance.json` → `lever`, `rotor`, `rune_switch`, `trapdoor`):
- **Lever switch:** a shot, a fast block or a blast flips it and fires its `triggers` (open a gate,
  drop a crusher, open a trap door, stop a shield). 1,200 points.
- **Windmill / rotating tower:** a hub with 2 to 4 sails turning at `dps`. Sails swat shots (and
  blocks with `hits_blocks`); a hit on the hub jams it (2,500 points) and fires its `triggers`.
- **Rotating shield:** iron plates orbiting a tower or core on their own physics layer, so they stop
  shots but never push the fortress. Time the gap, or hit a lever to stop the ring.
- **Hidden mechanisms:** a rune switch under a block. It stays dark while covered; when the cover
  breaks it glows, shows "?", and a hit (3,000 points) springs a trap door under the archers.
  The flyover marks it with "?".
All five are chain links (`mechanism`) and are tested in `_mechanism_d_tests` (11 checks).

## 3. Spectacular chain-reaction destruction
Status: **done** (`src/game/chain.gd`, `src/game/replay.gd`, numbers in `balance.json` → `chain`, `replay`).
- **Chain:** every break, KO, barrel blast, rope cut, bolt snap and trigger within 1.2 s of the last
  one adds 1 to the chain. Multiplier = 1 + 0.1 per link after the first, up to ×2.5. When the chain
  ends, a chain of 3+ links pays its points again × (multiplier − 1).
- **HUD:** a chain chip under the score (from 3 links) pops on each link and heats from gold to red.
  Milestones float in the world and flash the chip: 5 "NICE!", 10 "GREAT CHAIN!", 20 "SMASHING!",
  35 "LEGENDARY!".
- **Cinematic camera:** from 8 links the camera eases toward the centre of the chain and zooms in a
  little. At 12 links, or a barrel blast in a chain of 4+, time slows to 0.35× for 0.8 s (4 s cooldown).
- **Replay:** the level records every block, archer, hero and moving part at 20 Hz (up to 90 s). The
  result screen's REPLAY button hides the HUD and plays the best chain (1.5 s either side) at 0.5×
  with letterbox bars. Tap to skip.
- Results show blocks smashed, guards defeated, heroes saved, best chain and chain bonus. The
  3-star score expects some chain bonus (`gen_levels.py`: base + 0.75 × block score + 10,000).

## 4. Multi-stage boss castles
Done: crowned boss, HP phases (reinforce, shield, enrage, charge), moving castles, boss bar.

Phase D turns each boss fight into stages: **disable the defences, expose the core, finish the
boss.**

**Status: built** (`src/game/boss_rig.gd`, tunables in `balance.json` → `boss_rig`, materials `core`
and `cannon`, 14 checks in `_boss_rig_tests`). Breaking the last core scores 5,000, drops the
shield, stuns the boss for 3 s and plays a slow-motion beat. Cannonballs ignore soldier shields and
hit twice. Engineers rebuild a broken block within 700 px every 6 s (2,000 points each).
- **Power core:** a glowing core block. While any core stands, the boss has an unbreakable shield.
- **Rotating armor:** iron plates orbit the core (pillar 2 rotating shield).
- **Defensive weapons:** cannon turrets fire cannonballs at your soldiers (2 damage); they are iron
  targets you can destroy.
- **Repair system:** engineers walk to broken spots and rebuild a destroyed block every 6 s until
  you knock them out.
- The boss bar shows status icons: core (lit / broken), armor, turrets, engineers.

| Boss | Castle | Defences | Core |
|---|---|---|---|
| L10 Siege Warlord | siege tower on wheels | 1 cannon, 1 engineer | war drum in the base |
| L20 Sandstone Sultan | citadel with sliding keep | rotating stone armor | gem in the keep |
| L30 Captain Ironhook | iron galleon on the tide | 2 cannons, 2 engineers | powder magazine (explodes) |
| L40 The Forgemaster | foundry on rails | rotating iron armor, engineer, lava geyser | furnace |
| L50 The Iron Baron | airship in the wind | rotating armor, 2 cannons, 2 engineers | 2 balloon cores |

## 5. Game modes and objectives
A level's `mode` sets its rules. Campaign levels mix them for variety; the **Challenges** screen
(opens after level 10) has the rest. Each mode has its own HUD objective chip.

| Mode | Goal | Stars by |
|---|---|---|
| Siege (default) | Defeat every archer | score |
| Rescue (done) | Free the captives and defeat the archers | score |
| **Treasure heist** | Break open the chests. A chest that falls into the gap is lost | chests + score |
| **Time attack** | Clear the fortress before the timer runs out; heroes keep coming | time left |
| **One shot** | One hero. Bring it all down with one chain reaction | score |
| **Survival siege** | Reinforcements arrive in waves by raft or airship; survive N waves | waves |
| **Reverse siege** | Enemy siege towers and ships cross the gap toward you; sink each one before it docks | engines sunk |
| **Boss rush** | All 5 bosses back to back, shared heroes, soldier HP carries over (after L50) | time |

A **daily challenge** picks one challenge by date and pays 100 coins once per day.

**Status: built.** `ModeRules` (`src/game/mode_rules.gd`) runs the rules from level JSON `mode` and
`mode_cfg`; tunables in `balance.json` → `modes`. Eight challenge levels (ids 101–108, authored in
`tools/campaign.py` → `CHALLENGES`, written to `data/challenges/`): Gold Rush and Pirate Hoard
(heist), Beat the Clock and Forge Sprint (time attack, 40 and 50 s), One Perfect Shot (one Boomer),
Hold the Line (3 survival waves), Sky Raiders and Harbor Assault (reverse siege). Boss Rush runs
levels 10–50 with an 18-hero shared pool after level 50 (stars at ≤ 450 / 330 / 240 s). The
Challenges screen opens after level 10 (map button); the daily card is first with a countdown.
28 checks in `_mode_tests`.

## 6. Kingdom conquest and progression
**Status: logic built** (`src/game/progression.gd`, 20 checks in `_progression_tests`; screens in
task 8). Data: `balance.json` → `siege_weapons`, `upgrades` (Vanguard armor +1 HP ×2, shields +8%
×3, weapon power +4% ×3, reload −8% ×3; later levels cost blueprints), `cosmetics` (8 skins, 5
trails; tints and trail colour only), `realm_chests` (10/20/30 stars), `rank`, `secrets`
(scrolls in levels 7, 15, 27, 36, 46 unlock secret levels 111–115), `achievements` (20).
The loadout screen has a siege-weapon chip (tap to cycle unlocked weapons).

- **Regions:** 5 realms with their own gap, hazards, castle style and boss (done). Clearing a
  realm boss flips its map castle to our blue flag.
- **Siege weapons** (pick on the loadout screen):
  - Catapult: balanced.
  - Ballista (unlocks after L20): flat, fast shots for front walls and turrets.
  - Trebuchet (unlocks after L30): high lobs with +35% hero mass for enclosed keeps; reloads slower.
- **Upgrades:** the Wizard's Workshop (heroes, done) gains Vanguard tracks (soldier HP, shield
  chance) and siege weapon tracks (reload, power).
- **Cosmetics:** catapult skins (Sakura, Desert Gold, Pirate, Forge, Sky) and hero trails (petals,
  sparks, stars). Earned from realm star chests, achievements or coins. Never stronger, only
  different.
- **Secret levels:** one per realm. A hidden map scroll sits in a crate in one level of the realm.
  Hit it to reveal a dotted path to a secret node on the map.
- **Realm chests** on the map at 10, 20 and 30 stars per realm.
- **Kingdom rank** from total stars: Squire, Knight, Captain, Baron, Duke, King.
- **Achievements:** about 20, for example "Chain of 20", "Bend 10 iron beams", "Beat a boss with
  the core first", "Sink 5 siege ships".

## Phase D build order
0. Phase C leftovers: cutout support for mechanism/block pieces; APK size pass.
1. Chain reactions (chain, HUD, cinematic camera, slow-mo, replay, results breakdown).
2. Materials (ice, iron bend and heat, rune crystal, loadout material panel).
3. Mechanisms (lever, windmill, rotating shield, hidden switch and trap door).
4. Boss stages (core, rotating armor, cannon turrets, engineers) and the 5 boss redesigns.
5. Modes (heist, time attack, one shot, survival, reverse, boss rush), challenge levels, daily.
6. Progression (siege weapons, Vanguard upgrades, cosmetics, secret levels, realm chests, rank,
   achievements).
7. Screens (see `UI_DESIGN.md`): icon set, home, map, HUD chips, results, pause, settings,
   armory, challenges, achievements, daily reward.
8. Weave the new content into the campaign, tests, docs, AI prompts, APK.
