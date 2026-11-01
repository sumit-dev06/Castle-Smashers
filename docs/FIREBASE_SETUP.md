# Firebase setup: Analytics, Crashlytics, push (FCM)

The code is finished. Gameplay calls only two autoloads; each talks to a native plugin.

| Service | Autoload | Native plugin |
|---|---|---|
| Analytics + Crashlytics (+ NDK) | `Analytics` (`src/autoload/analytics.gd`) | our **CastleFirebase** (`addons/castle_firebase`, Kotlin source `tools/android_plugins/firebase`) |
| Push (Firebase Cloud Messaging) | `Notifications` (`src/autoload/notifications_push.gd`) | **GodotX Firebase 3.1.0** Core + Messaging (`addons/godotx_firebase`, `android/firebase_core`, `android/firebase_messaging`, MIT) |

Why two plugins: GodotX Firebase's Crashlytics module has no non-fatal error call (only
`log_message`, custom keys and a test `crash()`). CastleFirebase sends every GDScript error to
Crashlytics with its backtrace (`recordError`), which GodotX can't do. GodotX Messaging is a
complete, maintained FCM module, so we use it instead of writing our own. Both use the same
Firebase SDK versions (common 22.1, analytics 23.2, crashlytics 20.1, messaging 25.1), so the
APK carries one consistent set. GodotX's own Analytics and Crashlytics modules stay **off** in
the export preset.

Firebase switches on **only when `google-services.json` exists in the project root**. The GodotX
export plugin copies it into `android/build/` at export time, where the Google services Gradle
plugin reads it. Without the file builds work and send nothing. The file is git-ignored and is
excluded from the packed game files.

## Steps for the owner
1. <https://console.firebase.google.com> → **Add project** → "Stone Storm". Enable Google
   Analytics when asked. (Done: project `castle-smashers-a82d6`.)
2. **Add app → Android**:

| Field | Value |
|---|---|
| Android package name | `com.castlesmashers.game` (exactly) |
| App nickname | Stone Storm |
| Debug signing certificate SHA-1 | Optional (only needed for Google sign-in) |

3. **Download `google-services.json`** and put it in the project root, next to `project.godot`.
   (Done: the file is there and its package name matches.)
4. **"Add Firebase SDK" step of the wizard: skip it.** Godot's Android template uses Groovy
   `build.gradle`, not the Kotlin DSL the wizard shows, and the plugins already add the SDKs.
   `python3 tools/patch_android_template.py` adds the two Gradle plugins (`google-services`
   4.4.4, `firebase-crashlytics-gradle` 3.0.6, the versions GodotX is built and tested with).
   Run it again whenever you reinstall the Android build template. It is safe to run twice.
   Don't add the BoM line from the wizard: it would pull a second, newer set of Firebase
   libraries next to the plugins' set.
5. Export as usual (Project → Export → Android). The preset already has Use Gradle Build on and,
   under **Firebase**: Core on, Messaging on, Analytics off, Crashlytics off, config file
   `res://google-services.json`.
6. Firebase console → **Crashlytics** → "Enable Crashlytics". Start the game once on the phone.
7. Firebase console → **Messaging** → "Create your first campaign" → **Firebase Notification
   messages** → title + text → target **Topic** `all_players` (or `news`) → Review → Publish.
   Push the game to the background first: Android shows the notification itself.
8. Release builds: add the Play app-signing SHA-1 and SHA-256 (Play Console → Setup → App
   signing) in Firebase → Project settings → your app → **Add fingerprint**.
9. Data safety form: see below (FCM adds "Device or other IDs" for push delivery).

## Checking it works
- **DebugView**: on a USB phone run
  `adb shell setprop debug.firebase.analytics.app com.castlesmashers.game`, open the game, and
  watch Firebase → Analytics → DebugView. Turn it off with `adb shell setprop debug.firebase.analytics.app .none.`
- Normal events show in the Analytics dashboard after up to 24 hours.
- **Crashlytics** reports show after the app is restarted following a crash.
- The player can turn both off in Settings → Analytics (`Analytics.set_enabled`).
- **Push**: `adb logcat -s GodotxFCMService GodotxFirebaseMessaging godot` shows the topic
  subscription a few seconds after start. Send a campaign to `all_players` with the game in the
  background; the notification uses the white castle icon. Turning notifications off in
  Settings unsubscribes the phone from every topic.

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
| `level_quit` | `level_id`, `attempt`, `duration_s`, `shots_used`, `how` (map / restart from the pause menu) |
| `tutorial_begin` | `level_id` |
| `purchase_start` | `product_id` |
| `rewarded_ad_failed` | `placement` |
| `review_requested` | `level_id` |
| `update_prompted` | `mode` (flexible / immediate), `version_code`, `staleness_days` |
| `rewarded_ad_watched` | `placement` (spin / extra_rocky / double_coins), `reward_amount`, `level_id` |
| `interstitial_shown` | `level_id` |
| `purchase_success` / `purchase_failed` | `product_id`, `reward_amount` / `reason` |
| `crate_opened` | `product_id`, `reward_type`, `reward_amount` |
| `hellfire_used` | `level_id`, `left` |
| `upgrade_bought` / `engine_forged` / `skin_bought` | `weapon`, `track`, `level`, `cost` / `weapon`, `cost` / `skin_id`, `cost` |
| `spin_used` | `paid_with_ad`, `reward_type`, `reward_amount` |
| `notification_opened` | `kind` |
| `session_end` | `duration_s`, `levels_played` |
| `promo_shown` / `promo_tap` | `card` (noads / addons / skins / crates / upgrades / engines / missions) |

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
| Device or other IDs (advertising ID, Firebase installation ID, FCM token) | Yes | Yes (AdMob) | Advertising, Analytics, Fraud prevention, App functionality (push) | No (AdMob) |
| Financial info → Purchase history | Yes | No | App functionality | No |
| Approximate location (from IP, AdMob) | Yes | Yes | Advertising | No |
