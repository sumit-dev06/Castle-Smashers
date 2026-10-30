# Roadmap

## Phase 1: Playable slice (current)
- [x] Docs, reference archive
- [x] Godot project, autoloads, data files, Android export preset
- [x] SVG art for everything (tools/gen_art.py)
- [x] Catapult, 4 heroes with abilities, blocks with damage stages, archers vs soldiers
- [x] Camera, HUD, win/lose popup, 3 levels, generated SFX + music loop
- [x] Runs on the test phone (Realme RMX3870)
- [x] AI art pipeline (tools/cutout.py) with the owner's characters and 5 realm backgrounds
- [x] Real-time play: archers fire on their own, fast reload, several heroes in the air
- [x] Soldiers march in and charge on win; story briefing before every level
- [x] Reference-style scene and HUD; interactive world map; 20 levels
- [x] Four-shot Wizard's Arsenal with unlocks, ordered loadouts, specialist caps and power budget
- [x] Rumbler earthquake hero, weak points, gates, drawbridges, moving platforms, swings, spikes and lava
- [x] Rescue objectives and realm weather overlays
- [x] Safer audio mastering, limiter, quietest-voice allocation and dedicated mechanism/rescue cues
- [x] Sound redesign: adaptive two-stem music per realm + menu + boss, stingers, layered realm ambience with scattered details and per-realm reverb, smoothed SFX for every action (docs/AUDIO.md)
- [ ] Playtest and tune balance on device

## Phase 2: Content and art
- [x] Phase A stage system: ledge + fortress bases + lethal gap (water/sea/lava/clouds), softened
  backgrounds, realm foreground hooks, 5 new realms with placeholder art
- [x] Owner's AI stage art per realm (redo `fg_blossom_left`, `fg_sky_right`; add `boss_galleon_hull`, `boss_mine_cart`)
- [x] Phase B: 50 levels, 10 per realm, boss castle per realm
- [x] Phase C: crystal/iron/boulder materials; rope loads, hanging platforms, crushers, geysers;
  bolted joints; wind and tide; five multi-phase bosses; Wizard's Workshop upgrades; animated
  in-level story scenes and flyover callouts; all 50 levels redesigned (`tools/campaign.py`)
- [ ] Optional AI art for Phase C pieces and boss characters (`AI_ART_PROMPTS.md`, needs pipeline work)
- AI art pass (characters, backgrounds) using `AI_ART_PROMPTS.md`
- Character animation (blink, idle bob, hit reactions, cutout rigs)
- More levels (40), intro cutscene, more archer types
- Real SFX/music from CC0 sources, settings screen

## Phase D: Signature features (see `SIGNATURE_FEATURES.md`, `UI_DESIGN.md`)
- [x] Phase C leftovers: cutout support for mechanism/block pieces, APK size pass
- [x] Chain reactions: chain multiplier, HUD counter, cinematic camera, slow-mo, replay
- [x] Materials: ice, bending and red-hot iron, rune crystal; loadout material panel
- [x] Mechanisms: lever, windmill, rotating shield, hidden switch + trap door
- [x] Boss stages: power core, rotating armor, cannon turrets, engineers
- [x] Modes: heist, time attack, one shot, survival, reverse siege, boss rush, daily challenge
- [x] Progression: siege weapons, Vanguard upgrades, cosmetics, secret levels, realm chests, rank, achievements
- [x] Screens: icon set, home, map, HUD chips, results, pause, settings, armory, challenges, achievements,
      spin wheel, daily rewards, shop, upgrades (map realm tabs / level cards and the home castle motion later)

## Phase 3: Monetisation and services
- AdMob plugin + UMP consent, rewarded + interstitial
- Play Billing plugin, shop screen, restore purchases
- Coins economy, daily reward, upgrades, skins
- Optional: Play Games Services achievements and cloud save

## Phase 4: Release
- Performance pass on low-end device (target 60 fps, APK/AAB < 150 MB)
- Internal testing → closed testing (Play requires 12 testers for 14 days on new personal
  accounts) → production. See `PLAY_STORE.md`.
