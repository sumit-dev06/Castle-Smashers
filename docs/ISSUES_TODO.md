# Open issues (testing round, Nov 2026)

Owner's bug/feature list. No release build until all are done. Update the status after each fix.
Status: TODO / DONE / PARTIAL (what is left is written under the item).

| # | Issue | Status |
|---|---|---|
| 1 | Out of energy: rewarded ad must always be offered (no "once in a row" limit) | DONE |
| 2 | Notifications: wrong/blank icon on some phones; add a soft notification sound | DONE (test on phone) |
| 3 | Levels 1-9 too easy (esp. 4, 5, 7, 8, 9) and early 30s too easy; new level ideas (balloon guard, walled pit + bomb drop, rising core) | PARTIAL |
| 4 | Challenge mode: next wave's enemies die at wave start, battle auto-wins | DONE |
| 5 | Never disable a button; keep it tappable and show the reason | DONE |
| 6 | Welcome bonus ("Hello Commander") claim doesn't update the wallet until a screen change | DONE |
| 8 | app-ads.txt for Liftoff (Vungle), InMobi, Unity on the website; mediation set-up noted | DONE (mediation switch-on later: docs/MONETIZATION.md) |
| 7 | More physics/puzzle depth in every level so they don't pass too quickly | PARTIAL |

## Notes per issue
**1 (DONE)** `Energy.ad_allowed()` is now always true while energy is on; the `ad_lock` save flag and
`ad_locked_text` are gone (`src/game/energy.gd`, `src/ui/energy_ui.gd`, `balance.energy`). Test: "the energy
video can be watched again for every battle".

**4 (DONE)** Cause: wave archers spawn `modes.wave_drop_px` (520 px) above their spot, and the landing
impulse (or rubble hitting them) killed them, so the wave emptied at once and the win fired. Fix:
`Archer.land_grace` (`balance.modes.wave_land_grace_s` = 3 s) ignores fall/rubble damage after a wave drop;
hero hits still count (`src/game/archer.gd`, `src/game/mode_rules.gd`). Only challenge 106 uses waves.

**5 (DONE)** New `UIKit.locked(button, reason)`: button stays tappable but greyed; a tap shows the reason
(`UIKit.say`) and the button's action does not run. `locked(b, "")` unlocks. Every `disabled = true` in
`src/ui` was replaced (results, Hellfire buy, shop, restore, skins, upgrades, achievements, daily, spin,
settings sign-in, loadout +/−/hero cards/BATTLE). Store reasons: `Store.buy_block_reason(id)`.
Rule for new code: never set `Button.disabled`; use `UIKit.locked`.

**6 (DONE)** Cause: popups were built on the shared `UIFxLayer` and closing them called `queue_free()` on that
whole layer, which also killed the flying coin icons, so the wallet bar never got its update until the next
screen. Fix: `UIFx.popup_layer()` gives each popup its own layer (freed by `Game._switch` too); the
flying-icon counter now drops in `tree_exited`, so a freed icon can never freeze the bar.

**2 (DONE, needs a phone check)** Cause: the small icon was `mipmap/icon_monochrome`, a 108 dp adaptive-icon
layer; some launchers drew it tiny or as a white square. Now `drawable/ic_stat_castle` (proper 24 dp
white silhouette, 5 densities), orange accent colour, and the colour app icon as large icon. Sound:
`castle_chime.ogg` (soft G5→E6 glockenspiel, 1.1 s, -6 dB) on new channel `castle_reminders_v2`.
Plugin rebuilt and copied into `addons/castle_notify/bin/castle_notify.aar` (old copy: /tmp/castle_notify.aar.bak).
Phone test: next debug APK, send yourself a reminder (leave the app with energy spent), check icon + tone.
Preview the tone: `build/shots/castle_chime.ogg`.

**3 + 7 (PARTIAL)** New puzzle pieces (all in `tools/gen_levels.py`, rebuild with `python3 tools/gen_levels.py`):
- `f.pit(x, gap, depth, archers, keg)`: two unbreakable rock walls (ramps) with a narrow aisle; guards
  and a keg at the bottom. New rule `projectiles.common.keg_detonate_speed` (450): a hard hero hit sets
  off a keg even when it is pinned on the ground (`src/game/projectile.gd`). Test: "level 7: a stone
  dropped down the pit aisle smashes the keg".
- `f.balloon_guard(x, y, travel_x, travel_y, period_s)`: guard in a hot-air balloon basket that bobs.
- `f.balloon_guard(..., rise={speed, escape_y, warn_px, lose_text})`: escaping balloon. Starts climbing
  at the player's first shot; "IT'S GETTING AWAY!" near the top; level lost if a guard is still aboard
  at `escape_y` (`CastleMechanism._update_rise`). Test: "an escaped balloon loses the level".
- Per-level `power_budget` in the level row extras (tighter plans).
Levels changed:
- L4: two guards walled inside the stone hall (only the drawbridge reaches them), stone towers, budget 6.
- L5: stone shield wall in front, stone keep floor, budget 6 (lob at the bolted balconies).
- L7: seesaw + walled pit with a keg, budget 7.
- L8: stone shrine towers, stone in front of the barrel stack, budget 7.
- L9: gondola + bobbing balloon scout, sturdier tower, budget 7.
- L31: crystal towers + rock chute with 2 guards and a keg.
- L32: extra guard on the stone stack, stone back keep.
- L33: balloon scout drifting side to side and up/down above the mine.
- L34: escaping messenger balloon (lose if it gets away).
Also fixed on the way: `Replay.stop()` left the fortress invisible when a block burned during a replay.

Left to do (next session):
- Play L4-L9 and L31-L34 on the phone and tune (balloon speed `rise.speed`, `travel_y`, pit `gap`).
  Headless tests only prove they are stable and the tricks work, not how hard they feel.
- L1-L3 untouched on purpose (tutorials); L6 untouched. Say if you want them harder too.
- Issue 7 for the rest of the campaign (L10+): apply the same pieces where a level is beaten by
  brute force; ideas: a pit behind a moving shield, two escaping balloons, a pit whose keg must be lit
  by Blaze (fire through a narrow slot).
- Write the new pieces into `docs/LEVELS.md` level list text once tuned.

## Session 2 (Nov 5)
**Difficulty probe** (new): `$GODOT --headless --path . -- --run-tests=probe:1-75` (or `probe:8,14,21`)
fires the recommended heroes straight at the nearest guard with no tricks and prints guards left.
"TOO EASY" = brute force clears it. Noisy (physics), so use it as a signal, not a verdict.
First run: 21 of 75 levels were TOO EASY. After this session about 4 still are (L1 tutorial, L21, L62, and
sometimes L8/L33).

New rule: blasts and fire bursts don't pass through solid ground or rock walls (`Level._behind_cover`,
`balance.physics.cover_lift_px`). Pit guards can't be bombed from outside; hills give real cover.

Levels changed this session: L5 (+pit), L15 (iron shed at the slope foot + balloon), L16 (iron towers:
crusher/kegs must do it), L17 (+pit behind the keep), L18 (iron towers), L21 (+guard in the iron shed),
L23 (stone towers: use the bell), L25 (stone towers + balloon over the spout), L28 (iron shed), L31
(+iron shed), L33 (iron front tower), L41 (balloon in the wind), L42 (balloon over the updraft), L43 (iron
back tower: use the hanging boulder), L44 (iron/stone cores: use the ice train), L45 (escaping balloon),
L47 (iron tower + balloon), L52 (iron keep base), L62 (both terrace sheds iron: lever + upper sluice),
L64 (iron front tower), L70 (witch HP 200 -> 320), L71 (budget 6, stone shield at the second keg).
Generator fixes: balloons over a terrace no longer drop their riders (`_air` skips terrace lift).

Debug APK built and installed on the RMX3870 (Nov 5, 20:12). Test L4-L9, L15-L18, L31-L34, L41-L47.

Still TOO EASY / next: L21 and L62 (direct hits on iron sheds still knock the guards; consider stone
shields in front of the sheds without blocking the flood), L1 (tutorial, leave?).

**app-ads.txt (issue 8)**: 751 lines live (AdMob, Liftoff 1 DIRECT + 277 RESELLER, InMobi, Unity).
`wrangler login` done on this Mac, so `npx wrangler pages deploy web --project-name stonestorm --branch main` works.
Unity showed "badUrlForm": that comes from the URL typed in the Unity dashboard, not the file (the file
returns HTTP 200, text/plain). In Unity Monetization → Settings → App-ads.txt, the developer website must
be exactly `https://stonestorm.pages.dev` (no `/app-ads.txt`, no trailing spaces), then re-check. Liftoff
and InMobi re-crawl within about 24 h.

**Mediation ON (Nov 5)**: `admob/mediation/{unity_ads,vungle,inmobi}=true` in project.godot. Verified in the
debug APK on the phone: all three adapters report ready. Privacy policy updated and deployed (effective
5 Nov 2026). Before the next Play upload: re-check Data safety (no new data types; sharing with ad partners).
If a partner fails, AdMob still serves its own ads (mediation only adds bidders).

**Results buttons stuck on "One moment..." (Nov 5, fixed)**: Retry/Map/Next wait for the between-levels ad
(`Ads.match_break`) and only continued when the ad reported "closed". When that report never came (the
ad failed to show or its close event was lost; more likely now with three mediation networks), the screen
froze. Fix: `match_break` continues on the ad's close event, OR when the game is back in front, OR after
`ads.break_timeout_s` (90 s), exactly once. The pressed button now says what it is doing ("Restarting
the battle...") and unlocks itself after `ui.busy_unlock_s` (1.5 s) if the screen is still there.
