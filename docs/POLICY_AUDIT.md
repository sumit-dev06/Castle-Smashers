# Policy compliance audit (2026-10-31)

Engineering checklist against Google Play Developer Policy, Play Billing policy, AdMob program
policies, and Android platform rules. **Pass** = verified in code/tests/device;
**Owner** = needs a console action. This is an engineering review, not legal advice.

## Google Play Billing / Payments
| Rule | Status | Evidence |
|---|---|---|
| Digital goods sold only through Play Billing | Pass | All four products go through `Store` → GodotGooglePlayBilling 3.3.0 (Billing Library 9.1, above the required v7+) |
| Purchases acknowledged/consumed within 3 days | Pass | Consumables consumed and Remove Ads acknowledged right after the reward is saved; unfinished ones are retried at every launch and resume |
| Rewards only for PURCHASED; pending handled | Pass | `PurchaseProcessor.process`; tests "pending grants nothing", "pending → purchased grants once" |
| No double grant, crash recovery | Pass | Token ledger in the save, written before consume; restart test |
| Remove Ads restorable | Pass | `query_purchases` at start + "Restore Purchases" button |
| Prices shown are Play's localized prices | Pass | `Store.price_text` uses `formatted_price`; the US value is shown only as "(test)" in debug builds |
| Loot boxes: odds disclosed | Pass (n/a) | Crates have fixed, displayed contents; no randomized paid items |
| No secrets in the client | Pass | Verification goes to an owner server via `verify_url`; no service-account keys in the repo |
| Merchant account, products, prices | Owner | `BILLING_SETUP.md` |

## AdMob / Ads policy
| Rule | Status | Evidence |
|---|---|---|
| Consent (UMP) before ads in EEA/UK | Pass | `ads_admob.gd` requests consent before the first load |
| Consent can be changed later (EU User Consent Policy, US states) | Pass | Settings → Ad Privacy (shown when UMP says privacy options are required) re-opens the form via `Ads.show_privacy_options()`. Owner: in AdMob → Privacy & messaging create the GDPR message and the US states message |
| Ad content suits the audience | Pass | `max_ad_content_rating` = PG, matching the Everyone / PEGI 7 content rating |
| Rewarded ads are opt-in and say what you get | Pass | Every button reads "WATCH AD: …" with a video icon (spin, +1 Rocky, double coins) |
| No interstitials at unexpected moments | Pass | Only at a break the player chose (results Next/Retry/Map, pause Map/Restart), never during play or on app open; tests cover pacing |
| Interstitial frequency reasonable | Pass | 1 per 4 matches, ≥ 60 s apart, none before level 3 |
| Ads not placed to cause accidental clicks | Pass | No banners, no ad next to buttons |
| Remove Ads actually removes all ads | Pass | `Ads.ads_removed()` blocks every format and shuts the SDK down |
| Ads declaration in Play Console = Yes | Owner | |
| Real App ID / ad units, app-ads.txt | Owner | Replace the test App ID; send the AdMob publisher ID (`pub-…`) so `web/app-ads.txt` can be published at `https://castle-smashers.pages.dev/app-ads.txt`. Set the Play listing website to `https://castle-smashers.pages.dev` |

- Energy refill ad is opt-in, names its reward, and is limited to one level at a time.
- Full-screen ads use `Theme.CastleAd` (castle_notify AAR) on AdActivity: fullscreen, edge-to-edge under the cutout.
- Rocky addons (hats, glasses) are cosmetic only; no gameplay advantage.

## Privacy and data
| Rule | Status | Evidence |
|---|---|---|
| Privacy policy linked in the app and listing | Pass | Live at `https://castle-smashers.pages.dev/privacy/` (Cloudflare Pages, source `web/`). Settings → Privacy opens it (`settings.privacy_url`). Developer Intercore, India; contact intercoreapp@gmail.com. Owner: paste the URL in Play Console → App content → Privacy policy and in the AdMob app settings |
| Analytics without personal data | Pass | Whitelist in `Analytics.EVENTS`; tests drop unknown events |
| User control | Pass | Settings toggles for Analytics and Reminders |
| Data safety form | Owner | Answers in `FIREBASE_SETUP.md` |
| AD_ID permission declared | Pass | Present in the APK manifest (needed for AdMob on Android 13+) |

## Families / target audience
| Rule | Status | Notes |
|---|---|---|
| Not directed at children | Decided | Game is for everyone but not designed for children. Set target audience **13+** (cartoon violence, ads, purchases). If you pick under-13 ages you must join the Families policy: certified ad SDK settings (`tag_for_child_directed_treatment`), no personalized ads, and different analytics settings |
| Content rating | Owner | IARC questionnaire: cartoon/fantasy violence, in-app purchases, ads. Expect PEGI 7 / Everyone 10+ |

## Notifications (Android 13+ and Play spam policy)
| Rule | Status | Evidence |
|---|---|---|
| POST_NOTIFICATIONS requested at runtime, in context | Pass | Asked once after winning level 3 |
| No spammy/misleading notifications | Pass | 1 per day max, quiet hours, real triggers only, no purchase pushes, opt-out |
| Exact alarms not used | Pass | Inexact `AlarmManager.set`; no `SCHEDULE_EXACT_ALARM` permission needed |

## Technical requirements
| Rule | Status | Evidence |
|---|---|---|
| Target API level | Pass | targetSdk 36 (requirement for new apps from Aug 2025 is 35) |
| 64-bit | Pass | arm64-v8a included |
| 16 KB page size (required for targetSdk 35+ updates from Nov 2025) | Pass | Godot 4.7 templates and NDK 29 build 16 KB-aligned libraries; check "16 KB support" in the Play Console bundle explorer after upload |
| App Bundle | Owner | Export `.aab` for Play (`PLAY_STORE.md`) |
| Closed test with 12 testers for 14 days (new personal accounts) | Owner | |

## Remaining owner actions
1. Payments profile + four products + prices (`BILLING_SETUP.md`).
2. AdMob app, real App ID in project settings, `ad_ids.cfg`, `app-ads.txt`.
3. Firebase project + `google-services.json` (`FIREBASE_SETUP.md`).
4. Paste `https://castle-smashers.pages.dev/privacy/` into Play Console and AdMob; set the listing website to `https://castle-smashers.pages.dev`.
5. Data safety, content rating, target audience, ads declaration forms.
