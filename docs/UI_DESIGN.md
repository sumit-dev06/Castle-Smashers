# UI Design: screens, HUD and icons

Style: the same glossy cartoon as the game. Thick rounded shapes, a thin dark-brown outline
`#3a2212`, wooden signs and plank panels, gold accents, Lilita One for titles and Fredoka for
body text. Landscape 1280×720 design size; 20:9 phones see 1600×720, so anchor to the edges and
keep the centre 1280 px free of anything essential. Touch targets are at least 88 px.
Colours and sizes live in `data/balance.json` → `ui`.

## Screen flow
```
Splash → Home ─┬─ PLAY → Kingdom map → (story scene) → Level (flyover → Plan the Assault) → Results
               ├─ Challenges → mode card → Level → Results
               ├─ Workshop (heroes, Vanguard, siege weapons)
               ├─ Armory (skins and trails)
               ├─ Achievements
               ├─ Daily reward (popup)
               └─ Settings (popup)
```
Back on Android always goes one step up the flow; on Home it asks before quitting.

## Home screen
The owner's target is `docs/reference/home_screen_reference.png`: follow its layout and look. It is a
living 3D-looking diorama (our catapult with a boulder, Vanguard soldiers in gold helmets, a big
enemy castle with red banners across a valley) with wooden UI framed around it.
- **Top left: profile card.** Helmeted knight portrait, player name, a gold star with the kingdom
  rank number, and an XP bar ("860 / 1200"). Rank XP comes from stars and achievements.
- **Top right: currency bar.** Coins with a green "+". The reference also shows gems and tickets;
  we ship coins only until a second currency is designed (see `MONETIZATION.md`), and the slot
  stays ready. Then square wooden buttons: mail (inbox for rewards), friends (later, hidden for
  now) and settings.
- **Left column: tall wooden tiles** with an icon and label: Campaign (gold, selected), Challenges,
  Events (daily challenge for now), Shop. Red dots mark something new.
- **Right column:** a season/kingdom card ("Castle Conquest", crown and a star bar like "15/50",
  our realm star progress), Daily Rewards (chest), Achievements (target).
- **Centre bottom: PLAY,** a wide gold plank button with crossed swords and the subline
  "Campaign · Level 24". Gentle pulse.
- **Bottom left: current hero card.** Hero portrait, name, "Lv. 3", a progress bar and a green
  upgrade arrow that opens the Workshop for that hero.
- **Bottom bar:** Units (heroes and Vanguard), Upgrades, Workshop, Skins, Castle (our home keep and
  realm chests), square wooden tiles with icons and labels.
- **Bottom right: "Next World" card** with the next realm's art and name, and page dots.
- **Motion:** every 6–8 s the catapult fires, part of the castle wall crumbles in a small chain
  and rebuilds; banners wave; birds and clouds drift.

**As built (`src/ui/main_menu.gd`):** live realm backdrop with our catapult, three Vanguard
soldiers, the four bobbing heroes and two archers. Every button opens a different place (duplicates
were removed: Events, kingdom card, Kingdom tile and Next World all repeated Campaign/Challenges;
Army opened the old loadout; bottom Upgrades repeated the hero card; Trails is a tab of Skins).
- Profile card: soldier portrait, rank name with a crown, star bar to the next rank (opens Achievements).
- Currency bar (coins, gems, blueprints); each "+" opens its own Shop tab (`ShopScreen.tab_for`).
  Mail (one-time welcome gift, `home.welcome_mail`) and settings.
- Left: Campaign (gold, opens the map), Challenges (locked until L10 with a toast), Shop.
- Right: Daily Rewards, Spin Wheel, Achievements.
- Gold PLAY plank "Level N · Realm" (opens the next level).
- Hero card: the hero cheapest to upgrade, its level bar and an UPGRADE button that opens Upgrades
  with that hero focused (red dot when affordable). Skins tile bottom right. Red dots come from
`MetaFrame.has_news`. The first visit each day with an unclaimed daily reward opens Daily Rewards
(skip with `--no-popups`). The firing / crumbling castle motion is not built yet.

## Reference screens (not our art)
Screens from other games, kept in `art_source/reference_screens/` (not shipped) only for layout and
pacing ideas. Never copy their characters, card backs or logos.
| File | What to take |
|---|---|
| `hud_tutorial_1.jpeg`, `hud_tutorial_2.jpeg` | HUD stays out of the action: big round pause top left, level progress pips top centre, score plus a fill bar top right, hero cards bottom left with an "i" info badge and an ability cost, fast-forward button bottom right once the shots are done. Debris and sparks are big and bright. |
| `results_celebration.jpeg` | Results as a celebration: three large stars bursting over a ribbon, score on a wooden plaque, a "NEW HIGHSCORE!" sticker, confetti, the heroes lined up under it, a reward chest to the side. |
| `reward_cards.jpeg` | After a win, pick one of 5 face-down cards for a bonus (coins, upgrade parts, skin piece). |
| `spin_wheel.jpeg` | Daily spin: a wooden wheel with reward slices, "Jackpot chance" ribbon, SPIN button with remaining spins (extra spins by rewarded ad). |
| `cosmetics_shop.jpeg` | Skin shop: wooden frame, rarity tabs on the left, sets in rows with "0/7" progress, price per item at the top. |

The owner's own targets for the meta screens are in `docs/reference/` (see "Meta screens" below).

## Kingdom map
- One long painted scroll through the 5 realms (done), with a winding dotted road linking the nodes.
- **Nodes:** number medallion, 3 stars under it, the lock for future levels, a pulsing ring and our
  soldier standing on the next level. Boss nodes are castle icons with a red banner, which turns to
  our blue flag when beaten. Mode levels carry a small mode badge (chest, hourglass, "1", shield).
- **Secret nodes:** a "?" scroll, hidden until found, then a dotted path fades in.
- **Realm chests:** at 10/20/30 stars in each realm, a chest on the road opens with a pop.
- **Top bar:** home, realm name sign (updates while scrolling), stars per realm and total, coins.
- **Bottom right:** Workshop and Challenges shortcuts. Bottom: realm tabs (5 small shields) to jump.

**As built (`src/ui/world_map.gd`):** top left home, Upgrades, Shop, Achievements and (after L10)
Challenges shortcuts with red dots; top right rank chip, total stars and the wallet; realm sign at
the bottom. Each realm ends with a **realm chest** node showing the next tier ("Chest 2/3",
"14 / 20" stars). A ready chest glows and wobbles; tapping it claims it (rays, confetti, coins fly
into the wallet, "NEW SKIN!" stamp for skin tiers). A found **secret** shows as a glowing scroll in
its realm and opens the secret level (111–115); its results return to the map. Positions in
balance `map` (`chest_x/y`, `secret_x/y`). Realm tabs, level cards and mode badges are not built.
- Tapping a node opens a **level card**: name, mode, best score, stars, the materials and mechanics
  in it (icons), and PLAY.

## Plan the Assault (`src/ui/loadout_screen.gd`)
Overlay inside the level, opened after the fortress flyover (reference: the owner's "Plan the
Assault: Sunset Fortress" mock). Hero cards with large art and a plaque (name, tagline, "Power N ·
Max N", −/count/+ steppers); a Shots / Destruction / Objective panel top right; bottom row: FORTRESS
material strip, blue CATAPULT button (siege weapon), cream Recommended Loadout and green TO BATTLE!.
The world stays visible behind a dim (`loadout.dim_alpha`).

## In-level HUD
```
[logo]        [  Level sign / stars  ]   [Shots] [Destroy %] [Objective]  (II) (↻)
              [   boss bar + icons   ]                                     score
                                         [chain x12]
[wind sign]
                       [ objective hint line ]                 [ability button]
```
- **Shots chip:** the next hero's face and "left / total".
- **Destruction chip:** castle icon and percent.
- **Objective chip** changes with the mode: archers left (archer face), captives (cage),
  treasure (chest), time (hourglass, turns red under 10 s), waves (shield + "2/5"), engines (ship).
- **Chain counter:** appears at chain 3, grows with each link, shows the multiplier.
- **Boss bar:** name, HP, phase pips and defence icons (core, armor, cannon, engineer), each greyed
  out once disabled.
- **Ability button** (bottom right): shows the flying hero's ability icon while one is in the air,
  as a big touch target. Tapping anywhere still works.
- **Wind sign:** arrow and strength bars (done).
- **Ammo tray** (bottom left, `Hud.set_ammo`): framed icons of the heroes still to fire, the next one
  bigger with a NEXT label. Waiting hero sprites also draw in front of the catapult (`catapult.hero_wait_z`).
- Callout banners: centre top, wooden plank, 1.6 s.

## Results
- Win: "VICTORY!" banner, 3 stars pop in one by one, score count-up, then a breakdown: blocks,
  archers, unused heroes, **chain bonus**, **best chain**, mode bonus. Coins earned with a coin
  burst. Buttons: Map, Replay (the best chain), Retry, Next.
- Lose: "DEFEAT" sign, the reason (soldiers down / out of heroes / time up / chest lost /
  a ship docked), Retry, Map, and a tip.
- **As built (`Hud.show_result` + `_celebrate_result`):** stars slam in from 2.4x with a twist,
  rays, a dust puff, a rising note and a haptic tick (balance `ui_fx.star_slam_s`); the score rolls
  up; "NEW BEST!" stamps on when a replay beats the old best; then the earned coins, gems and
  blueprints fly into a wallet top right (it starts at the pre-win totals); 3 stars add confetti.
  Debug capture: `--level=N --force-win=1`.

## Pause
Dark overlay with a wooden panel: Resume, Restart, Map, music and SFX toggles, and the objective.
As built: title, level name, the level's `strategy` line, RESUME, then Map, Restart, Settings
(opens the settings popup over the pause), Music and SFX toggles.

## Settings popup
Music, SFX, haptics, language (English only in v1), reset tutorial, credits, privacy policy link,
version number. As built: `SettingsPopup` (`src/ui/settings_popup.gd`, CanvasLayer 60, works while
paused): music and SFX on/off with volume sliders (`music_volume`, `sfx_volume` in the save),
haptics, language (English), Replay Tutorial, Credits page, Privacy (balance
`settings.privacy_url`) and the version from `project.godot`.

## Challenges screen
Cards in a row, one per mode, each with a big icon, the mode name, a one-line rule, best result
and stars. The daily challenge card is first, gold-trimmed, with a countdown. Master Sieges is a
separate ten-level hard pack. Below 25 campaign stars the row shows one locked pack card with live
progress; at 25 stars it expands to ten violet-gold `MASTER SIEGE n / 10` cards. Special levels use
fixed four-shot loadouts and never enter the daily rotation.

## Armory
See "Skins (Armory)" below for the full layout. Summary: catapult skins and hero trails. Each item is a card with a preview, its source (realm
chest, achievement, coins) and Equip. Locked items show how to get them.

## Achievements
A scrolling list of plank rows: icon, name, description, a progress bar, and Claim (coins).

## Meta screens (owner references)
The owner's targets, follow their layout and mood (not pixel copies):
`docs/reference/spin_wheel_reference.png`, `shop_reference.png`, `daily_rewards_reference.png`,
`upgrades_reference.png`, `skins_reference.png`. They share one frame, which every meta screen uses:
- **Header:** square wooden back button, a plank title sign with the screen's icon.
- **Currency bar** top right (same on every screen): pill per currency with a green "+".
- **Left rail:** wooden tabs with icon + label; the selected tab is gold. Rail on the reward
  screens: Spin Wheel, Daily Rewards, Shop, Events, Challenges, Achievements.
- **Background:** a warm castle-hall or courtyard painting (banners, torches, gold piles), blurred a
  little so the panels read.

### Spin wheel
A big wooden wheel with iron brackets, 10 slices alternating gold, violet and blue, each with a
reward icon and amount, a gold star hub, and a red-gem pointer on top. A green SPIN button with a
video icon ("Watch Ad") and "3 spins left today" under it; the first spin of the day is free.
A "Possible rewards" parchment card on the right with ranges. Odds and rewards in
`data/balance.json` → `spin`.

### Daily rewards
"Login Daily" red ribbon, 7 day cards in a row (claimed days get a green tick, today glows and
bobs), day 7 is a large gold card with an Epic Chest. A green CLAIM REWARD button and a "Reward
preview" strip at the bottom. Missing a day does not reset the streak in v1 (kinder, fewer
complaints).

### Shop
Tabs: Special Offers, Gems, Gold, Siege Weapons, Skins, Bundles, Remove Ads, Resources. The offers
tab has a wide Starter Pack banner (sale ribbon, contents chips, price button), two pack cards, and
the Remove Ads card with ticks. Below: rows of gem and gold packs ("10% extra" stickers), siege
weapons and skins with an "i" button. Real-money prices come from Google Play Billing; the shop
never hard-codes them.

### Upgrades (Workshop)
Left rail of siege weapons (Catapult, Ballista, Trebuchet, later ones locked). The centre shows
the weapon large on a wooden platform with left and right arrows, its name, level and a one-line
description. Right: "Stats & upgrades" rows (icon, name, a segmented bar, Lv., green coin price
button). Bottom: the hero strip (equipped tick, price or "Lv. N" lock) and the skins strip.

### Skins (Armory)
Follows `skins_reference.png`. Left rail: Catapult, Trebuchet, Ballista, later weapons, Flags,
Trails. The centre shows the selected skin large on a round stone plinth with left and right
arrows; it idles (the arm creaks back and settles). Right: a framed card with the skin name, a
rarity pill (Common grey, Rare blue, Epic violet, Legendary gold), a one-line description, a perk
list and a big green EQUIP button (or the price / "Realm 3 chest" when locked). Bottom: a strip
of skin cards, each with its preview, name and rarity pill; the equipped one has a gold frame and a
green tick corner. First catapult set: Default, Royal, Ironclad, Forest, Lava, Ice, Desert, Shadow.
**Skins are cosmetic only.** Where the reference lists "+10% damage", ours lists what the skin
changes: its stone trail, impact effect and launch sound. No stat bonuses from skins (fairness,
and it keeps level balance in one place).

### Currencies
Decided: coins, gems and blueprints (owner approved). Rules and sources: `docs/MONETIZATION.md`
→ Currencies. Built: `Save.amount/add/spend`, `CurrencyBar` (live pills, roll-up, pop, deny shake).

## Juice: rewards, purchases and feedback
Every gain should feel physical. Shared helpers live in one `UIFx` class (`src/ui/ui_fx.gd`, built) so all screens match, and
all timings live in `data/balance.json` → `ui_fx`.
- **Coin fly:** coins burst from the source (chest, results panel, wheel slice) in an arc, spin,
  and fly one by one to the coin pill. Each arrival ticks the counter up with a "tink" (pitch rises
  per coin) and pops the pill (scale 1.0 → 1.18 → 1.0). The same for gems and blueprints with
  their own sound.
- **Count-up numbers:** scores and currency roll up with ease-out, never jump.
- **Purchase:** the button squashes on press, the card flashes white, a ray burst spins behind it,
  the item icon scales up and flies to its destination (pill, armory slot, hero card), confetti, a
  "PURCHASED!" stamp. If coins are short, the price shakes red and the "+" on the coin pill pulses.
- **Upgrade:** the stat bar fills segment by segment with a spark at the leading edge, "LV. 4"
  flips in, hammer-on-anvil sound, a small screen shake.
- **Chest open:** the chest drops in with a bounce, shakes 3 times with growing glow, the lid flies
  open with light rays; rewards pop out one by one onto cards, then fly to their pills.
- **Spin wheel:** fast start, long ease-out, the pointer ticks against each bracket (sound and a
  small pointer flick), the winning slice glows, then the reward pops and flies.
- **Daily reward:** today's card bobs, claim stamps a tick, the reward flies to the bar, and the
  next day's card shows a countdown.
- **Stars on results:** each star flies in from big, slams with a dust puff and a chord note (pitch
  rising per star); a "NEW BEST!" sticker spins in.
- **Buttons everywhere:** press squash (0.92), release overshoot, 80 ms; red dots pulse; idle CTAs
  (PLAY, CLAIM, SPIN) breathe and get a light sweep every few seconds.
- **Screen transitions:** wooden panels slide in with a small overshoot; popups scale from 0.8 with
  a dim fade; nothing appears instantly.
- **Unlocks:** a new hero, weapon or realm gets a full-screen reveal (dark, rays, the item rises
  in, its name on a ribbon, "TAP TO CONTINUE").

## Icon set
All icons are round-cornered, 128×128 SVG, `#3a2212` outline, generated by `tools/gen_art.py`
(`icon_<name>.svg`). AI versions are optional (see `AI_ART_PROMPTS.md`).

| Group | Icons |
|---|---|
| Navigation | home, map (levels), back, close, next, play, pause, restart, settings, replay |
| Currency | coin, star, gem slot (unused) |
| HUD objectives | archer, captive cage, chest, hourglass, wave shield, ship, castle, chain |
| Boss | crown, core, armor, cannon, engineer |
| Materials | wood, stone, ice, iron, crystal, rune, barrel |
| Mechanics | rope, lever, gear, crusher, geyser, wind |
| Menus | workshop, armory, challenges, trophy, daily chest, calendar, lock, no-ads |
| Modes | siege, rescue, heist, time attack, one shot, survival, reverse, boss rush |
| Settings | music, sound, haptics, info |
