# Game Design

## Flow
Main menu → **world map** (scroll the 8 realms, tap an unlocked level) → **story briefing**
(characters talk, tap to advance, Skip) → level → result → Next goes to the next story.

## Core loop (one level, 30–90 s, real time)
1. **Intro:** the Vanguard soldiers march in from the left and line up behind the catapult. A wooden
   sign shows the level name. Level 1 shows a "Drag & Release to Fire!" hand tutorial.
2. **Play, all in real time:**
   - Drag on the left part of the screen to pull the catapult back; a dotted line shows the arc.
     Release to fire.
   - The next hero hops into the bucket `catapult.reload_s + hop_s` (≈0.7 s) after a shot. You can
     fire again while the last shot is still flying or the tower is still falling.
   - Tap (short touch, no drag) to use the ability of the newest hero still in the air.
   - Every archer shoots on its own timer (`archers.fire_min_s..fire_max_s`), pulls its bow first,
     and stops shooting while it is falling or knocked over.
3. **Win:** all archers defeated → slow motion, soldiers charge the fortress, stars.
   **Lose:** all soldiers knocked out, or no heroes left and the fortress has settled.

## Our side
- **Catapult**: wooden throwing arm on wheels. Our own design (not a slingshot). The arm pulls back
  when dragged, and the projectile sits in the bucket.
- **Soldiers** (the Vanguard): 4 round soldiers stand behind the catapult. Each has 3 HP, loses 1 per
  arrow hit, and blocks 30% of arrows with the shield. At 0 HP a soldier sits down dazed ("knocked
  out", no gore). They march in, cheer on good hits and charge when you win.
- **Hero loadout:** before each battle, the Wizard's Arsenal lets the player choose exactly four
  heroes and arrange their firing order. Heroes unlock through the campaign story. Per-hero caps and
  an eight-point arcane-power budget prevent four-shot specialist spam. Recommendations and saved
  per-level loadouts remain available.

## Projectiles (heroes)
Values live in `data/projectiles.json`; the ones below are starting points.

| Hero | Mass | Special (tap in flight) | Strong vs | Weak vs |
|---|---|---|---|---|
| **Rocky** (stone) | heavy | Slam: dives straight down with 2.5× mass | stone, archers | none |
| **Blaze** (fire pot) | light | Fire dash: speeds up 1.55×. Always bursts into flames on impact (bigger burst after a dash); burning wood loses HP and spreads to touching wood | wood, roofs | stone |
| **Boomer** (bomb) | medium | Explodes (also explodes 1.5 s after first impact if not tapped). Radial impulse + damage, radius 220. | everything nearby | far targets |
| **Twister** (cyclone) | light | Turns into a whirlwind for 2.5 s that drifts forward, pulls nearby light bodies in and lifts them, then flings them. | light wood, archers on ledges | heavy stone |
| **Quaky** (quake stone) | very heavy | Earthbreak: dives and sends a wide ground shockwave through low supports; marked weak points take extra damage. | foundations, weak points | high targets |

## Enemies
- **Redcap Archer**: stands on fortress floors. 30 HP. Shoots a ballistic arrow at a random living
  soldier every 5.5–8.5 s, with aim error ±spread (data). Variants later: Shield
  Archer (blocks the front), Captain (fires 3 arrows), Fire Archer (burning arrows).
- Archers fall over and are defeated at 0 HP, or when they drop off the map.

## Materials
Values live in `data/materials.json`.

| Material | Look | HP | Density | Damage taken × | Flammable |
|---|---|---|---|---|---|
| wood plank | warm brown planks | 60 | 0.6 | 1.0 | yes |
| wood crate | crate with cross brace | 45 | 0.5 | 1.15 | yes |
| stone | grey rounded bricks | 140 | 1.6 | 0.35 | no |
| iron | dark riveted plate | 260 | 2.4 | 0.22 | no |
| crystal | glowing faceted crystal | 40 | 0.9 | 1.35 | no, shatters and hurts blocks within 120 px |
| boulder | round granite (rolls) | 400 | 2.2 | 0.2 | no |
| log | round trunk on slopes (rolls, rams what it hits) | 600 | 0.8 | 0.15 | yes |
| wheel | big cart wheel (level 35: rolls down and rams one part of the fort) | 1200 | 1.6 | 0.12 | no |
| straw roof | thatch triangle | 35 | 0.3 | 1.3 | very |
| powder barrel | red barrel | 25 | 0.6 | 1.6 | explodes |
| ice | pale translucent blue, frosty top | 40 | 0.9 | 1.3 | no, melts under fire (32 HP/s), slippery, shatters |
| rune crystal | violet socket with a glowing gem and an arrow | 150 | 1.2 | 0.45 | no, absorbs energy and fires a beam |

Iron beams bend into a V on a hard hit, and fire makes iron red-hot for 5 s (×2.5 damage). See
`docs/SIGNATURE_FEATURES.md` §1 for the full rules.

Each hero also has a `material_mult` per material (for example the bomb is better against iron).
Each block shows 3 damage stages (intact, cracked, badly cracked) and breaks into debris pieces.

## Castle mechanics
- Marked weak blocks have reduced HP, take extra damage, and can trigger a gate, drawbridge or
  captive release.
- Gates, drawbridges with visible pulley/counterweight rigs, moving platforms, pendulum obstacles,
  spikes and lava are data-driven level pieces.
- Captives in levels 6 and 12 must be rescued as well as defeating every archer.
- **Rope loads**: boulders, crates or cages hang from ropes. Any hero touching a rope, fire within
  120 px or an explosion cuts it and the load drops; it can also trigger another mechanism.
- **Hanging platforms** (gondolas and rope bridges) hang from two ropes: one cut tips them, two cuts
  drop them. Drawbridges show their working pulley and counterweight.
- **Flood gates** release a timed wave that pushes and floats blocks and drowns covered guards.
  **Water wheels** wait for a brake trigger, then their geared paddles sweep nearby structures.
- **Breakable ledges** tip and drop their entire load when their keystone trigger breaks.
- **Heavy throwing beams** launch a held boulder or powder keg when the short arm is slammed.
  **Explosive carts** carry bolted powder barrels down rails after their brake rope is cut.
- **Crushers** slam down on a cycle or when a trigger fires. **Geysers** burst up and throw heroes
  and pieces; lava geysers also burn.
- **Bolts** pin two blocks together. They snap after 40 damage, in an explosion or quake, or when
  one block breaks, so bolted towers fall as one piece.
- **Wind** (levels 29, 41–43, 45, 47–50) gusts left or right and pushes heroes in flight; the HUD
  shows it. **Tide** (levels 21, 23, 26, 28, 30) raises and lowers the sea and floating decks.
- **Bosses** (every 10th level): a crowned archer at 1.55× size with 160 HP and 3-arrow volleys.
  At HP thresholds it changes phase: reinforcements drop in, a 4 s shield, faster fire (enrage),
  or its moving castle speeds up 1.7× (charge). Defeat: 15,000 points. HUD boss bar with phase pips.
- Hero unlocks: Rocky 1, Blaze 3, Boomer 6, Twister 12, Quaky 22.
- Realm weather adds petals, leaves, pollen, rain or embers over the five painted environments.
- The fortress stands on bases across a gap from the catapult ledge. Anything knocked into the
  gap splashes and is gone: blocks count as destroyed (scored), archers as defeated.

## Story scenes
No text screens. Each story is an animated scene played in the level: characters walk or drop in,
talk in speech bubbles, react, and the camera points out the new mechanic with a ring, arrow and
sign. New mechanics get a ghost-shot demo; new heroes get a summon and ability preview; bosses get
a roar and name plate. Every level opens with a short flyover with up to 3 callouts. Tap skips a
beat, SKIP skips the scene.

## Damage
`impulse = contact relative normal speed × reduced mass`. Below `min_impulse` = no damage.
`damage = impulse × source_factor × material_factor`, with a per-body cooldown of 0.1 s.
Source factor: projectile 1.0, block 0.5, ground 0.4 (only above `ground_min_speed`).
Settling contacts never deal damage. Physics starts in "sleep" for the first 1.0 s so towers settle.

## Scoring and stars
- Archer defeated: 5,000. Block destroyed: 500 (stone 800). Unused hero: 10,000.
- Soldier knocked out: −2,000.
- Stars from the level's `star_scores` thresholds `[1★, 2★, 3★]` in the level file.

## Economy
- **Coins**: earned per level (stars × 50, first clear only + 10 on replays) and from rewarded ads.
- **Wizard's Workshop**: 3 upgrade levels per hero for 150 / 350 / 700 coins (Rocky +15% slam,
  Blaze +14% burst, Boomer +12% blast, Twister +18% whirl time, Quaky +12% shockwave reach).
- **Spend**: extra hero mid-level (+1 bomb, 150 coins), soldier shield upgrade, catapult skins.
- **Gems**: not in v1. One currency keeps it simple.

## Energy (army stamina)
- Up to `energy.max` (8) shield bars. Refill is non-linear: `energy.refill_s` = 1:40, 3:20, 5:30, 8, 11, 12, 13,
  14 min per bar (the first missing bar comes back fastest; empty to full is about 68 min). Refill runs on the
  wall clock from the saved time, so it continues while the app is closed.
- Levels up to `energy.free_until` (5) are free. A level costs 1 bar, 2 from realm 3, 3 for a boss. Retries cost too.
- Short on bars: the "YOUR ARMY IS EXHAUSTED!" popup offers an opt-in rewarded ad that pays for that one level only.
  The next level after an ad-paid one needs rested bars. Training ranges never cost energy.
- Code: `src/game/energy.gd` (rules, state in `Save.data.energy`), `src/ui/energy_ui.gd` (pill, popup).

## Training ranges
- Before the first level of a new hero (fire before 3, bomb 6, cyclone 12, quake 22) a short range shows how to use it.
  Rocky has a range too, reachable only from the Workshop. Tap a hero card in Master Orin's Workshop to practise again.
- Source: `TRAINING` in `tools/campaign.py`, generated to `data/training/`. Coach texts in `balance.training`.

## Rocky addons
- Hats (pirate hat, cap, crown, viking helmet, top hat) and glasses (shades, specs), one per slot, sold as Play
  one-time products. Worn on Rocky everywhere he appears (catapult, queue, flight, home). Looks only.
- Code: `src/game/hero_addons.gd`; catalogue `balance.cosmetics.hero_addons`; art `assets/art/svg/addon_*.svg`.

## Upgrade prices
- All Workshop upgrade tracks (Vanguard and each siege engine) cost twice the earlier prices. Forge (unlock) prices are unchanged.

## Profile name
- Default `balance.profile.default_name`. Rename is free once level `free_rename_level` (5) is reached, else 20 gems.
- The rename popup uses an in-game keyboard on the lower screen (the system keyboard floated over the field in landscape).

## Controls
- Drag anywhere on the left third to aim (not only on the catapult, easier on phones).
- Pinch to zoom, two-finger drag to pan while nothing is in flight.
- Tap to use ability. Pause button top left. Restart button next to it.

## Feel ("juice") checklist
Screen shake scaled by impulse, 60 ms hit-stop on big impacts, dust puffs, wood splinters and stone
chips, squash on launch and landing, slow motion when the last archer falls, star pop animation,
coin fly-to-counter, haptic tap on launch and big hits (Android vibrate, setting to turn off).
