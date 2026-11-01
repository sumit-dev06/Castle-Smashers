# Policy compliance audit (final, 2026-11-01, version 1.0.0)

Engineering checklist against Google Play Developer Policy, Play Billing policy, AdMob program
policies and Android platform rules, checked on the release bundle, the live website and the
automated tests. **Pass** = verified; **Owner** = a Play Console / AdMob action (steps in
`docs/FINAL_RELEASE_STEPS.md`). This is an engineering review, not legal advice.

## Google Play Billing / Payments
| Rule | Status | Evidence |
|---|---|---|
| Digital goods sold only through Play Billing | Pass | All 11 products (`balance.shop.order`) go through `Store` → Billing Library 9.1.0 |
| Product IDs match Play Console | Pass | coin_crate, gem_crate, hellfire_crate, remove_ads, addon_pirate_hat, addon_cap, addon_crown, addon_viking, addon_top_hat, addon_shades, addon_specs (owner created all 11, purchase option `buy`) |
| Purchases acknowledged/consumed within 3 days | Pass | Consumed / acknowledged right after the reward is saved; unfinished ones retried at every launch and resume |
| Rewards only for PURCHASED; pending handled | Pass | `PurchaseProcessor.process`; tests "pending grants nothing", "pending → purchased grants once" |
| No double grant, crash recovery | Pass | Token ledger in the save, written before consume; restart test |
| Non-consumables restorable, refunds revoked | Pass | `query_purchases` at start and on resume, Restore button; refunded addons / Remove Ads are removed |
| Prices are Play's localized prices | Pass | `Store.price_text` from Play; products created after install are re-queried when the shop opens |
| Loot boxes | Pass (n/a) | Crates have fixed, displayed contents |
| Payment sheet doesn't rotate the game | Pass | `ProxyBillingActivity` / `V2` set to `behind` (they follow the game's `sensorLandscape`; a fixed value crashes Android 8.0) (checked in the bundle by `release.py verify`) |
| No secrets in the client | Pass | No service-account keys in the repo or bundle |

## AdMob / Ads policy
| Rule | Status | Evidence |
|---|---|---|
| Real App ID and ad units in the release build | Pass | `ca-app-pub-1292430265619610~9195063737`, units `/6882407348` (interstitial) and `/1846749261` (rewarded), checked inside the bundle; debug builds use Google test units |
| Consent (UMP 4.0.0) before ads; can be changed | Pass | Requested before the first load; Settings → Ad Privacy where required. GDPR + US messages published in AdMob |
| app-ads.txt | Pass | `https://castle-smashers.pages.dev/app-ads.txt` = `google.com, pub-1292430265619610, DIRECT, f08c47fec0942fa0`. Owner: website field in the store listing must be `https://castle-smashers.pages.dev` |
| Ad content rating | Pass | Max rating T in code and AdMob; audience 13+ |
| Rewarded ads opt-in, reward named | Pass | "WATCH AD: …" buttons only |
| Interstitials only at natural breaks | Pass | Only after the player taps Next/Retry/Map/Restart; 1 per 4 matches, ≥ 60 s apart, none before level 3, never during play or on app open |
| No accidental clicks | Pass | No banners; full-screen ads use their own close button |
| Remove Ads removes every ad | Pass | `Ads.ads_removed()` blocks every format |
| Link the app in AdMob after it is live | Owner | AdMob → Apps → App settings → Add app store details |

## Privacy and data
| Rule | Status | Evidence |
|---|---|---|
| Privacy policy in app and listing | Pass | `https://castle-smashers.pages.dev/privacy/` (live, updated 2026-11-01: new events, rating/update prompts, backup). Settings → Privacy opens it |
| Analytics without personal data, user can turn off | Pass | Whitelist `Analytics.EVENTS` (unknown events dropped, tested); Settings → Analytics switch |
| Support contact | Pass | Settings → Contact Support (email); same email in the listing and policy |
| Backup | Pass | Only `save.json` + `save.json.bak` (`cs_data_rules.xml`); ad/Firebase IDs never restored |
| Data safety form | Owner | Answers in `FIREBASE_SETUP.md`; no new data types this release |
| Advertising ID declaration | Owner | AD_ID permission present → answer Yes (advertising + analytics) |
| Account deletion | Pass (n/a) | The game has no accounts |

## Ratings and updates (Play In-App Review / In-App Updates)
| Rule | Status | Evidence |
|---|---|---|
| Review prompt not incentivised or pre-filtered | Pass | No reward, no "do you like it?" question first; Google's own card after a 3-star win from level 8, max 3 asks, 30 days apart |
| Updates use Play's own flow | Pass | `CastlePlay.startUpdate`; immediate only for release priority ≥ 4 |

## Families / target audience
| Rule | Status | Notes |
|---|---|---|
| Not directed at children | Decided | Target audience **13+**. Under-13 groups would require the Families policy (child-directed ad settings, different analytics) |
| Content rating | Owner | IARC: cartoon/fantasy violence, in-app purchases, ads; no user interaction, no location sharing |

## Notifications (Android 13+, Play spam policy)
| Rule | Status | Evidence |
|---|---|---|
| POST_NOTIFICATIONS asked at runtime | Pass | About 1 s after the first home screen (Android never asks at install); fallback after a won level |
| Not spammy or misleading | Pass | Max 1 reminder a day, quiet hours 22:00–09:00, real triggers only (energy full, spin, daily reward, chest, special levels, update, 2/5/10 days away), no purchase pushes, Settings switch |
| No exact alarms | Pass | Inexact `AlarmManager.set`; no `SCHEDULE_EXACT_ALARM` |

## Permissions in the bundle (all granted at install except notifications)
INTERNET, ACCESS_NETWORK_STATE, VIBRATE, WAKE_LOCK, POST_NOTIFICATIONS (runtime), BILLING,
AD_ID + ACCESS_ADSERVICES_AD_ID / ATTRIBUTION (AdMob), c2dm RECEIVE (push), install referrer,
READ_BASIC_PHONE_STATE (normal permission added by a Google library, no prompt) and plain
FOREGROUND_SERVICE (from Google's WorkManager library; the game declares no foreground-service type,
so no foreground-service declaration applies). No location, camera, contacts, storage or SMS.

## Technical requirements
| Rule | Status | Evidence |
|---|---|---|
| Target API | Pass | targetSdk 36 (Android 16), minSdk 24 |
| 64-bit | Pass | arm64-v8a + armeabi-v7a |
| 16 KB page size | Pass | Every 64-bit native library in the bundle has 16 KB (0x4000) LOAD alignment (checked 2026-11-01). The 32-bit libraries are 4 KB, which is allowed (the rule is for 64-bit) |
| App Bundle, signed with the upload key | Pass | `release.py verify`: signer CN=Intercore matches `~/castle_upload.keystore`; Play App Signing re-signs |
| Size | Pass | About 133 MB, under the 200 MB limit |
| Automated tests | Pass | Full suite, `contraptions` (31) and `specials` (44) |
| Closed test, 12 testers for 14 days | Owner | `FINAL_RELEASE_STEPS.md` step 4 |

## Known risk
Levels 6, 32–36 and 42–48 were made harder on 2026-10-31. The automated tests check that they load,
stay stable and that their set-pieces work, but nobody has beaten every one of them yet. Ask closed
testers to report any level they can't beat.
