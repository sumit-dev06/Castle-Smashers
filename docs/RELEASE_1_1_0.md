# Stone Storm 1.1.0: release the 75-level update

1.1.0 is the update after 1.0.0. It has the same package (`com.castlesmashers.game`), so it
installs over 1.0.0 and players keep their progress, coins and purchases. If 1.0.0 is still in
closed testing, do the 1.0.0 steps (`FINAL_RELEASE_STEPS.md`) with **this** file instead: Play
only needs the newest bundle.

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
- Army energy: 8 bars instead of 5, refills a bit faster (empty to full about 68 min).
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
3. **Play Games Services**: Play Console → **Grow users → Play Games Services → Setup and management
   → Configuration**. Check the credential for `com.castlesmashers.game` lists **both** SHA-1
   fingerprints: the **upload key** and the **app signing key** (Play Console → Test and release →
   App integrity → App signing shows both). If only one is there, add an Android credential for the
   other. Without the app signing key, sign-in fails for everyone who installs from Play.
4. Leave Play Games Services **unpublished** until Step 3 shows sign-in works, then click
   **Publish** (Play Games Services → Publishing).
5. **Data safety**: no new data types. Play Games sign-in uses Google's own account screen; the
   game keeps only the display name in memory and sends nothing anywhere. Answers stay as in
   `FIREBASE_SETUP.md`.

## Step 2. Upload 1.1.0 to Internal testing
1. Play Console → **Test and release → Testing → Internal testing → Create new release**.
2. **Upload** → `build/stone_storm.aab`. Wait for the row **10 (1.1.0)**.
3. Release notes:
   ```
   75 levels! Three new realms, new contraptions, level challenges, Play Games sign-in, more army energy and lots of fixes. Castle Smashers is now Stone Storm.
   ```
4. **Next → Save and publish**.

## Step 3. Test on your phone (20 minutes)
Uninstall any test APK first, then open the internal testing link and install from Play.
- The launcher name reads **Stone Storm**; the title card shows the new logo.
- A Google Play Games "Welcome back / Signed in" banner appears on first start (or Settings →
  Play Games → Sign in works).
- Buy something cheap with a test account: the payment sheet appears **in landscape**.
- Shop → Hero Addons scrolls. Home shows the DISCOVER MORE card once.
- Settings → reminders on; put the game in the background; the energy reminder arrives later.

## Step 4. Production
If 1.0.0 is already live: **Production → Create new release → Add from library → 10 (1.1.0)**,
roll out to 20%, then 100% after 2 days with no new crashes in Crashlytics
(`python3 tools/release.py rollout 1.0` works once the service account from `RELEASE_GUIDE.md`
part 3 exists). If 1.0.0 is still in closed testing, promote 1.1.0 there instead and continue
`FINAL_RELEASE_STEPS.md` from Step 4.

## Step 5. After it is live
- AdMob and Firebase: rename the app to Stone Storm (cosmetic, nothing breaks if you don't).
- Website `https://castle-smashers.pages.dev` is already updated. The address keeps the old name
  on purpose: the privacy policy URL and `app-ads.txt` are registered with Play and AdMob.
  Moving to a new domain later means updating both.
- Add a row to `docs/RELEASE_HISTORY.md` if you uploaded by hand.

## If you need to go back
Halt the rollout (Production → Manage → Halt). You can't upload 1.0.0 (code 9) again; fix and
build 1.1.1 (code 11) instead. Players on 1.1.0 keep their save either way.
