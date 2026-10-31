# Monetisation

Free to play with ads and four in-app products. The whole campaign can be finished without paying.
Gameplay never calls a plugin: everything goes through the `Ads` and `Store` autoloads.
Setup steps for the consoles: `BILLING_SETUP.md` (Play), `FIREBASE_SETUP.md`, and the AdMob section below.

## Ads (Google AdMob)
| Format | Where | Rules |
|---|---|---|
| Rewarded | Spin wheel: every spin after the daily free one ("WATCH AD: SPIN", up to `spin.ads_per_day` = 5) | Opt-in, button names the reward |
| Rewarded | Out of boulders: "WATCH AD: +1 Rocky" | Once per attempt. After that: Hellfire or Give up/replay |
| Rewarded | Win screen: "WATCH AD: +N coins" (doubles the level's coins) | Once per result screen |
| Rewarded | Out of energy: "WATCH AD" in the exhausted popup (placement `energy_refill`) | Pays for that one level; the next level needs rested bars |
| Interstitial | At the break after a match: the player taps **NEXT**, **RETRY** or **MAP** on the result screen, or **MAP** / **RESTART** in the pause menu | One per 4 matches (`ads.interstitial_every_matches`). A match is any attempt that ended, or was left or restarted after the first shot; wins and losses both count, training never. Count is saved across app restarts. Never during play, never before level 3, at least 60 s apart. If no ad is loaded the count is kept and it shows at the next break |
| Banner / app-open | Not used | They clash with the art and annoy players |

- **Remove Ads** turns off every format. Rewards that used to need a video (extra spins, +1 Rocky,
  double coins) are then granted instantly, so buyers are never punished.
- Consent: Google UMP form before the first ad request (required in the EEA/UK).
- Plugin: Poing Studios godot-admob-plugin 5.1 (`addons/admob`), Gradle build.
- Debug builds use Google test units. Release builds read `res://ad_ids.cfg` (git-ignored):
  ```
  [android]
  interstitial="ca-app-pub-XXXX/YYYY"
  rewarded="ca-app-pub-XXXX/ZZZZ"
  ```
- The AdMob **App ID** is in project setting `admob/general/android/app_id`:
  `ca-app-pub-1292430265619610~9195063737` (real; debug builds still request Google's test units).
- Release ad units (in `ad_ids.cfg`): interstitial `ca-app-pub-1292430265619610/6882407348`,
  rewarded `ca-app-pub-1292430265619610/1846749261`.
- Max ad content rating: **T** (in code and in AdMob → Blocking controls). MA is blocked.

### Why one interstitial per 4 matches
The owner asked for one ad per 4 matches, counting retries, not only new levels. The ad still
appears only at a break the player chose (a results or pause button), so it never interrupts play,
which is what the AdMob "unexpected interstitial" policy forbids. A match counts once its first
shot is fired, so opening and quitting a level does not count. Raise `interstitial_every_matches`
if day-1 retention drops; lower it only after looking at Firebase data.

## In-app products (Google Play Billing)
| Product ID | Type | US price | Gives |
|---|---|---|---|
| `remove_ads` | Non-consumable (acknowledged, never consumed, restored automatically) | $4.99 | No ads ever; ad rewards granted instantly |
| `coin_crate` | Consumable | $1.99 | 30,000 coins |
| `gem_crate` | Consumable | $4.99 | 400 gems |
| `hellfire_crate` | Consumable | $2.99 | 3 Hellfire strikes (purchase only) |

Every crate has **fixed, shown contents** (no random loot boxes, so no odds disclosure or
loot-box regulation applies). Prices shown in the game come from Google Play in the player's own
currency; the US prices above are only fallbacks for the price templates. Regional prices:
`BILLING_SETUP.md`.

### Pricing rationale
- **Coin Crate $1.99 = 30,000 coins.** A free player earns about 120 coins per new star and 25 per
  replay, so 30,000 coins equals roughly 20-30 levels of play. It buys the Ballista (18,000) plus a
  few upgrades, or most of the way to the Trebuchet (40,000). Cheap enough to be an impulse buy.
- **Gem Crate $4.99 = 400 gems** = exactly one legendary skin (400). Free gems are deliberately
  scarce (boss first clears, a rare spin jackpot, daily day 7) and the total free gems in the game
  stay below one legendary skin, so gems stay special.
- **Hellfire Crate $2.99 = 3 strikes.** Hellfire guarantees a win on any level, including bosses.
  It is a skip, not power: free players can always replay a level. Three strikes at about $1 each
  is in line with paid "skip level" items.
- **Remove Ads $2.99**: the standard price point for this genre; low enough that ad-annoyed
  players convert.

## Hellfire
Purchase only, never earned. When a level is lost because the boulders ran out, the popup offers
"USE HELLFIRE" (if owned) or "BUY HELLFIRE x3". A strike drops a fire boulder on every block and
defeats every archer (bosses too), so the level is always won. Tunables: `balance.hellfire`.

## Purchase safety (see `ARCHITECTURE.md` → Billing)
Rewards only for `PURCHASED` state; pending purchases wait; cancelled/failed purchases show a
message and grant nothing. Every purchase token is recorded in the save ledger before the consume
call, so a token is never granted twice and a crash between "granted" and "consumed" is repaired on
the next launch. An optional server verification hook is in `purchase_verifier.gd`
(`balance.shop.verify_url`); no secrets in the client.

## Currencies
| Currency | Role | Earned | Spent on |
|---|---|---|---|
| Coins | Soft, plentiful | Wins (120 per first-clear star, 25 per replay win), boss first clears (1,500), daily rewards, spin wheel, realm chests, achievements, double-coins video, Coin Crate | Siege engines (Ballista 18,000, Trebuchet 40,000), engine upgrade tracks, coin skins |
| Gems | Premium, scarce | 5 per first boss clear, 3-gem spin jackpot, 5 on daily day 7, small achievement amounts, Gem Crate | Premium skins, coin exchange |
| Hellfire | Paid skip | Hellfire Crate only | Guaranteed win |

Save version 4 removed blueprints (the parchment "map" icon). Old saves convert them to coins and
refund old hero-upgrade spending.

## Policy rules we follow
- Ad buttons always say "WATCH AD" with a video icon and the exact reward; nothing looks like a
  game button that secretly opens an ad.
- No ads before consent, mid-level, on app open, on Retry, or in the first session.
- Prices are never hard-coded in the UI; they come from Play.
- No random paid rewards, no fake timers, no "only today" pressure.
- Full audit: `POLICY_AUDIT.md`.
