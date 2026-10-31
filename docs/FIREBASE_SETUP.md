# Firebase Analytics + Crashlytics setup

The code is finished. `Analytics` (autoload, `src/autoload/analytics.gd`) is the only thing
gameplay calls. On Android it talks to our own small plugin **CastleFirebase**
(`addons/castle_firebase`, Kotlin source in `tools/android_plugins/firebase`), which wraps the
official Firebase Android SDK (Analytics + Crashlytics + Crashlytics NDK, BoM 33.7).

Firebase switches on **only when `android/build/google-services.json` exists**. Until then
builds work and send nothing. We verified both paths: a normal export, and an export with a
placeholder `google-services.json` that contains `FirebaseInitProvider`, `CrashlyticsRegistrar`,
`CrashlyticsNdkRegistrar`, the `libcrashlytics*.so` native handlers and `google_app_id`.

## Steps for the owner (about 15 minutes)
1. Go to <https://console.firebase.google.com> → **Add project** → name "Castle Smashers".
   Enable Google Analytics when asked, choose (or create) an Analytics account, and set the
   reporting country/currency.
2. In the project: **Add app → Android**. Fill in:

| Field | Value |
|---|---|
| Android package name | `com.castlesmashers.game` (exactly) |
| App nickname | Castle Smashers |
| Debug signing certificate SHA-1 | Optional (only needed for Google sign-in). If you add it: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android` |

3. **Download `google-services.json`** and copy it to
   `android/build/google-services.json` in this project (that folder is git-ignored, so the file
   never reaches GitHub).
4. Run `python3 tools/patch_android_template.py` once. It adds the Firebase Gradle plugins and the
   black launch splash to the Android build template. Run it again whenever you reinstall the
   Android build template from Godot. It is safe to run twice.
5. Export as usual. Skip the remaining SDK steps of the Firebase wizard ("Add Firebase SDK"):
   the plugin already does them.
6. Firebase console → **Crashlytics** → "Enable Crashlytics". Launch the game once from the
   phone; Crashlytics shows "app detected" after the first start.
7. For release builds also upload the Play app-signing SHA-1 and SHA-256 (Play Console → Setup →
   App signing) to Firebase → Project settings → your app → **Add fingerprint**.

## Checking it works
- **DebugView**: on a USB phone run
  `adb shell setprop debug.firebase.analytics.app com.castlesmashers.game`, open the game, and
  watch Firebase → Analytics → DebugView. Turn it off with `adb shell setprop debug.firebase.analytics.app .none.`
- Normal events show in the Analytics dashboard after up to 24 hours.
- **Crashlytics** reports show after the app is restarted following a crash.
- The player can turn both off in Settings → Analytics (`Analytics.set_enabled`).

## What is sent
Only whitelisted events and parameters (`Analytics.EVENTS`). Anything else is dropped. No names,
emails, device IDs, purchase tokens or free text are ever logged.

| Event | Parameters |
|---|---|
| `game_start` | `session_number`, `days_since_install`, `build` |
| `tutorial_complete` | `level_id` |
| `level_start` | `level_id`, `attempt`, `weapon`, `heroes`, `mode` |
| `level_complete` | `level_id`, `attempt`, `stars`, `score`, `duration_s`, `weapon`, `shots_used`, `used_hellfire` |
| `level_failed` | `level_id`, `attempt`, `reason`, `duration_s`, `weapon`, `shots_used` |
| `level_retry` | `level_id` |
| `rewarded_ad_watched` | `placement` (spin / extra_rocky / double_coins), `reward_amount`, `level_id` |
| `interstitial_shown` | `level_id` |
| `purchase_success` / `purchase_failed` | `product_id`, `reward_amount` / `reason` |
| `crate_opened` | `product_id`, `reward_type`, `reward_amount` |
| `hellfire_used` | `level_id`, `left` |
| `upgrade_bought` / `engine_forged` / `skin_bought` | `weapon`, `track`, `level`, `cost` / `weapon`, `cost` / `skin_id`, `cost` |
| `spin_used` | `paid_with_ad`, `reward_type`, `reward_amount` |
| `notification_opened` | `kind` |
| `session_end` | `duration_s`, `levels_played` |

Useful reports to build in Analytics → Explore: a funnel `level_start → level_complete` per
`level_id` (finds hard levels), `attempt` at completion, and `rewarded_ad_watched` by placement.

## Crashlytics: what each report contains
| Need | How |
|---|---|
| Device model, Android version, RAM, orientation | Collected by Crashlytics automatically |
| Game version | Crashlytics app version + custom key `build` |
| Frequency | Crashlytics groups issues and counts crashes and affected users |
| Stack traces | Java/Kotlin automatically; native engine crashes via Crashlytics NDK; GDScript errors are sent as non-fatal issues with the GDScript backtrace (`Analytics.ErrorForwarder`, max 10 distinct per session) |
| Was it during physics, loading or an ad? | Custom key `phase`: `loading` (scene build), `aiming`, `physics` (after a shot), `ad_rewarded`, `ad_interstitial`; plus keys `scene`, `level`, `weapon`, `projectile` |
| What happened just before | Breadcrumb log: shots (`shot:<hero>:<weapon>`), rewarded placements |

## Data safety form (Play Console → App content → Data safety)
Answer **Yes, the app collects data**; it is encrypted in transit; users can't request deletion
through the app (they can by email; see privacy policy).

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| App activity → App interactions | Yes | No | Analytics | Yes (Settings → Analytics) |
| App info and performance → Crash logs, Diagnostics | Yes | No | App functionality, Analytics | Yes |
| Device or other IDs (advertising ID, Firebase installation ID) | Yes | Yes (AdMob) | Advertising, Analytics, Fraud prevention | No (AdMob) |
| Financial info → Purchase history | Yes | No | App functionality | No |
| Approximate location (from IP, AdMob) | Yes | Yes | Advertising | No |
