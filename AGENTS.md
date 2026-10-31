# AGENTS.md

Instructions for AI coding agents (and humans) working on Castle Smashers.
Read this first, then `docs/ARCHITECTURE.md` before changing code.

## Project
- 2D physics siege game, Android only, published on Google Play. Free with ads + in-app purchases.
- Engine: **Godot 4.7 stable**, GDScript only. Renderer: **Compatibility** (OpenGL ES 3).
- Godot binary on the dev machine: `/Users/sumit/Downloads/Godot.app/Contents/MacOS/Godot`
  (alias below as `$GODOT`).

## Commands
```sh
GODOT=/Users/sumit/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import                 # import assets, must print no errors
$GODOT --path .                                     # run the game
$GODOT --headless --path . -- --run-tests          # data, physics stability, shot + ability tests
$GODOT --path . -- --level=1 --screenshot=build/shots/a.png --shot-delay=4 [--autoshot=38,0.8,0.9]
                                                    # render a frame (autoshot = angle,power,ability_delay)
python3 tools/gen_art.py                            # regenerate all SVG art into assets/art/svg
$GODOT --headless --path . --export-debug "Android" build/castle_smashers_debug.apk
python3 tools/gen_sfx.py                            # regenerate sound effects into assets/audio/sfx
python3 tools/gen_music.py; python3 tools/gen_ambience.py   # adaptive music stems + stingers, realm ambience
$GODOT --path . -- --level=N --autoshot=38,0.85,0.9 --record-audio=14   # record the Master mix to build/shots/audio.wav
python3 tools/cutout.py --preview                   # new AI images in assets/art/ai/ -> refined PNGs in assets/art/ai/cut
python3 tools/gen_levels.py                         # rebuild levels from tools/campaign.py into data/levels
python3 tools/make_app_icon.py                      # app icon (adaptive layers, 192, 512, Play Store) from art_source/brand
$GODOT --path . -- --map | --story=N | --level=N | --loadout=N | --workshop | --challenges | --challenge=N   # jump to a screen
$GODOT --path . -- --meta=spin|daily|shop|upgrades|skins|achievements   # meta screens; --no-popups skips the daily popup
$GODOT --path . -- --training=fire | --meta=shop --tab=addons | --addons=crown,shades | --energy-popup=2 | --rename-popup   # debug previews
$GODOT --path . -- --level=11 --debug-roll                    # print rolling-log rams
$GODOT --path . -- --level=16 --hellfire=0.3 --no-plan        # debug: run a Hellfire strike after 0.3 s (none spent)
$GODOT --path . --resolution 3200x1440 -- --level=21 --no-plan --no-intro --no-popups --sharp-bg --no-hud --screenshot=build/shots/web.png --shot-delay=3   # clean, sharp website/store capture
$GODOT --path . -- --level=N --force-win=1 --screenshot=build/shots/r.png --shot-delay=9   # results screen capture (debug)
$GODOT --headless --path . --editor --quit          # refresh the class cache after adding a class_name file
$GODOT --headless --path . -- --run-tests=billing   # billing, ads, Hellfire, analytics, notifications only
$GODOT --path . -- --intro | --no-intro | --meta=settings   # studio intro + title card / skip it / settings popup
python3 tools/patch_android_template.py             # after (re)installing the Android build template: Firebase Gradle + black splash
python3 tools/capture_intro.py                      # re-capture the studio intro from art_source/intro/*.html
npx wrangler pages deploy web --project-name castle-smashers --branch main   # website + privacy policy (castle-smashers.pages.dev)

ADB=~/Library/Android/sdk/platform-tools/adb
$ADB install -r build/castle_smashers_debug.apk     # install on the USB test phone
$ADB shell am start -n com.castlesmashers.game/com.godot.game.GodotAppLauncher
$ADB logcat -s godot:V                              # game logs from the phone
```

Test device: Realme RMX3870, Android 16 (API 36), 1080×2400 (20:9), 480 dpi, arm64-v8a.

## Folder layout
| Path | Contents |
|---|---|
| `src/autoload/` | Global singletons (registered in project.godot) |
| `src/game/` | Gameplay: level, catapult, projectiles, blocks, units, camera, FX |
| `src/ui/` | Menus, HUD, popups |
| `scenes/` | Only `main.tscn`. Screens and level content are built in code from `data/` |
| `data/` | JSON: balance, materials, projectiles, levels. **All tunable numbers live here.** |
| `assets/art/svg/` | Hand-written vector art (source of truth, Godot imports SVG directly) |
| `assets/art/ai/cut/` | Refined AI art + `meta.json` (output of `tools/cutout.py`, shipped) |
| `art_source/ai/` | Original AI images (kept, never shipped: has `.gdignore`) |
| `assets/audio/` | `sfx/` (stereo WAV), `music/` (three synced Ogg stems per song + stingers), `ambience/` (Ogg beds + details), all generated |
| `assets/fonts/` | Lilita One (titles), Fredoka (body). Both SIL OFL. |
| `tools/` | Python generators: art, sfx, levels, AI cutout. Not shipped. |
| `tests/` | Headless test scripts |
| `docs/` | Design and process docs. Keep in sync with code. |
| `web/` | Static website and privacy policy (Cloudflare Pages). Has `.gdignore`; keep the policy in sync with `FIREBASE_SETUP.md` Data safety |

## Rules
1. **No magic numbers in gameplay code.** Add them to `data/*.json` and read via `Data` autoload.
2. **Static typing** in GDScript (`var hp: float`, `func f(x: int) -> void`). `snake_case` files,
   `PascalCase` class_name. One class per file.
3. **No allocations in `_physics_process`** hot paths where avoidable; pool particles/arrows.
4. Signals go through the `Events` autoload for cross-system communication. Direct calls are fine
   inside one scene.
5. **Monetization code only in `Ads` and `Store` autoloads** (analytics only in `Analytics`,
   notifications only in `Notifications`). Gameplay never calls a plugin
   directly. Both autoloads must work (as no-op stubs) when the Android plugin is missing, so the
   game runs on desktop.
6. Never show an interstitial ad during play; only at a break between matches (`Ads.match_break`). See `docs/MONETIZATION.md`.
7. Art: follow `docs/ART_DIRECTION.md` and `docs/reference/level_style_reference.png` (the owner's
   target look). Glossy cartoon with a **thin dark-brown outline `#3a2212`** on every piece.
   Never copy Rovio characters, birds, pigs or the slingshot shape.
   Raw AI images are never used directly: they go through `tools/cutout.py`.
8. Every asset not made in this repo must be listed in `docs/CREDITS.md` with its licence.
   Only CC0 / CC-BY / OFL / owned assets.
9. Never commit keystores, passwords, or ad unit IDs for production. Use `export_credentials.cfg`
   (git-ignored) and env vars.
10. After changes: run import + tests; both must be clean before reporting done.

## Coordinate conventions
- Design resolution 1280×720 landscape, stretch `canvas_items` / `expand` (20:9 phones see 1600×720).
- SVGs import at 2x; `Art.sprite()` applies `Art.SVG_SCALE` so 1 SVG unit = 1 world pixel.
- World units are pixels. Ground top (catapult ledge and fortress bases) is at `y = 0`; up is
  negative y. The gap between them has its surface at `gaps.<kind>.surface_y` (> 0). Catapult at `x ≈ 0`,
  fortress starts at `x ≈ 1400+`.
- Physics layers used: 1 world, 2 blocks, 3 projectiles, 4 archers. Soldiers, arrows and debris are
  not physics bodies (arrows test distance; debris is pooled sprites in `Fx`).
