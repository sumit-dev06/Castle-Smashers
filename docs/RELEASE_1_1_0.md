# Stone Storm 1.1.0: release the 75-level update

**Where we are:** 1.0.0 (code 9, still named Castle Smashers) is uploaded to Play **closed testing**
and the testers are already added. 1.1.0 (code 10) is the rebuilt Stone Storm version. It goes to
the **same closed testing track** as an update: testers get it automatically over 1.0.0 and keep
their progress, coins and purchases (same package `com.castlesmashers.game`). 1.1.0 is then the
build you send to production. 1.0.0 never goes to production.

Uploading a new release to the same track does **not** restart the 14-day closed-test clock; it
counts the days your 12+ testers stayed opted in.

## The files (never mix them up)
| File | What it is |
|---|---|
| `Documents/Castle Smashers Releases/castle_smashers_1.0.0_code9.aab` | 1.0.0, kept read-only. Your fallback. Never re-upload it after 1.1.0 (Play refuses lower codes). |
| `build/castle_smashers.aab` | Same 1.0.0 bundle. The new builds never write to it. |
| `build/stone_storm.aab` + copy `Documents/Castle Smashers Releases/stone_storm_1.1.0_code10.aab` | **1.1.0, the one to upload.** Real ads, real billing. |
| `build/stone_storm_debug.apk` | For friends who are not testers: Google test ads, purchases don't work. Can't be installed over the Play version (different signature): they uninstall it first. |

## What changed for players
- 75 levels: 25 new ones in the Scarlet Highlands, Storm Crags and Iron Citadel, all hard or very
  hard, with new contraptions (magnets, portals, gravity, bumpers, repair crystals, floods...).
- Rotating level challenges on the Achievements screen.
- "All realms conquered" screen after level 75: new levels are coming.
- Feature showcase on the home screen (Remove Ads, Addons, Skins, Crates, Workshop...).
- Army energy: 10 bars instead of 5, empty to full in 30 minutes, with a reminder when it is full.
- Google Play Games sign-in (automatic).
- New name and title screen: **Stone Storm**.
- Fixes: shop scrolling, payment screen no longer turns the game to portrait, calmer home screen,
  no more crackle in the studio intro.

## Step 1. Play Console changes that come with 1.1.0 (10 minutes)
1. **App name**: Play Console → your app → **Grow users → Store presence → Main store listing** →
   **App name**: `Stone Storm` (or `Stone Storm: Castle Siege`, max 30 characters). Save.
   Search Play for "Stone Storm" first: if another game has exactly that name, use the longer one.
2. Same page: **Short** and **Full description**: copy from `store_listing/listing.md`
   (now says 75 levels in eight realms). **Feature graphic**: `store_listing/feature_graphic_1024x500.png`.
   **Phone screenshots**: the files in `store_listing/screenshots_designed/` (they show the new name). Save.
3. **Play Games Services**: follow `docs/PLAY_GAMES_SETUP.md` (every click, with the SHA-1 values). Short version: Play Console → **Grow users → Play Games Services → Setup and management
   → Configuration**. Check the credential for `com.castlesmashers.game` lists **both** SHA-1
   fingerprints: the **upload key** and the **app signing key** (Play Console → Test and release →
   App integrity → App signing shows both). If only one is there, add an Android credential for the
   other. Without the app signing key, sign-in fails for everyone who installs from Play.
4. Leave Play Games Services **unpublished** until Step 3 shows sign-in works, then click
   **Publish** (Play Games Services → Publishing).
5. **Data safety**: no new data types. Play Games sign-in uses Google's own account screen; the
   game keeps only the display name in memory and sends nothing anywhere. Answers stay as in
   `FIREBASE_SETUP.md`.

## Step 2. Upload 1.1.0 to the closed testing track (where 1.0.0 is)
1. Play Console → **Test and release → Testing → Closed testing** → open the track 1.0.0 is on →
   **Create new release**.
2. **Upload** → `build/stone_storm.aab`. Wait for the row **10 (1.1.0)**. 1.0.0 (code 9) moves to
   "not included" by itself; that's correct.
3. Release notes:
   ```
   Castle Smashers is now Stone Storm! 75 levels, three new realms, new contraptions, level challenges, Play Games sign-in, more army energy and lots of fixes.
   ```
4. **Next → Save and publish** (Google reviews it, usually a few hours to 2 days).
5. Testers don't need to do anything: Play updates them. Tell them in your tester group that the
   name changed to Stone Storm.

## Step 3. Test on your phone (20 minutes)
Uninstall any test APK first, then install from the closed testing link (Play Store page).
- The launcher name reads **Stone Storm**; the title card shows the new logo.
- Google's "Signed in" banner appears (after `PLAY_GAMES_SETUP.md` is done).
- Buy something cheap with your licence-tester account: the payment sheet stays **in landscape**.
- Shop → Hero Addons scrolls. Home shows the DISCOVER MORE card once.
- Energy shows **x/10**. Settings → reminders on; leave the game; the "energy full" reminder comes.

## Step 4. Production
1. When the closed test has run 14 days with 12+ testers: **Dashboard → Apply for production**,
   answer the questions (what testers did, what you changed: "renamed to Stone Storm, 75 levels,
   fixes from tester feedback").
2. After Google approves: **Production → Create new release → Add from library → 10 (1.1.0)** →
   rollout **20%** → after 2 days with no new crashes in Crashlytics, **100%**.
   Details for the launch week: `FINAL_RELEASE_STEPS.md` Steps 8 and 9 (same clicks, use code 10).

## Step 5. After it is live
- AdMob and Firebase: rename the app to Stone Storm (cosmetic, nothing breaks if you don't).
- Website moved to `https://stonestorm.pages.dev` (live, with the privacy policy and `app-ads.txt`).
  The old `https://castle-smashers.pages.dev` stays online unchanged so 1.0.0 (which links to it)
  keeps working. In Play Console → Store settings → **Website**: `https://stonestorm.pages.dev`;
  App content → **Privacy policy**: `https://stonestorm.pages.dev/privacy/`. AdMob re-reads
  `app-ads.txt` from the new website within about a day (AdMob → Apps → app-ads.txt shows the status).
- Add a row to `docs/RELEASE_HISTORY.md` if you uploaded by hand.

## If you need to go back
Halt the rollout (Production → Manage → Halt). You can't upload 1.0.0 (code 9) again; fix and
build 1.1.1 (code 11) instead. Players on 1.1.0 keep their save either way.
