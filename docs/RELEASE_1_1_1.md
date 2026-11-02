# Stone Storm 1.1.1: everything left to make it all work

1.1.1 (code 11) replaces 1.1.0 (code 10) on the same Play testing track, and later in production.
Same package `com.castlesmashers.game`, so players keep their progress, coins and purchases.
The code is finished; what's below are the clicks only you can do. Do them in this order.

## What changed in 1.1.1
- **Cloud save** through Google Play Games: progress comes back on a new phone or after reinstalling.
  If the phone and the cloud have different progress, the player picks one. Signing in is never
  required; without it the game works exactly as before.
- Play Games sign-in starts after the home screen, not over the intro. It checks again when the
  player comes back to the game (for example after signing in from the Play Games app).
- First install: Intercore Studio intro with sound, then the title card (tap to begin), then the
  home screen. Later launches: a Stone Storm splash, then home. The intro no longer repeats after
  updates, and it plays on a reinstall even when Android restores the old save.
- No black screen on start (Stone Storm splash while the game loads).
- Settings fits on the screen; a long Play Games name shows on one line ("Unaccustome…").
- Fix: buying Hellfire on the "Out of boulders" popup and then using it froze the game.
- Fix: coins and confetti from the last results screen landed on the next screen (training card).

## Step 1. Google Cloud: fix "Access blocked" / Error 403 (5 minutes, required)
The 403 is not a code bug: the OAuth consent screen is still in **Testing**, so only its test
users can sign in. Full clicks: `docs/PLAY_GAMES_SETUP.md` Step 6. Short version:
1. https://console.cloud.google.com → project **300021741882**.
2. **Google Auth Platform → Branding**: name Stone Storm, support email, logo, home page
   `https://stonestorm.pages.dev`, privacy URL, authorized domain `pages.dev`. Save.
3. **Audience → Publish app → Confirm**. If Google asks for verification, send me a screenshot.

## Step 2. Play Console: Play Games Services (10 minutes, required)
**Grow users → Play Games Services → Setup and management**:
1. **Configuration → Credentials**: package `com.castlesmashers.game` needs Android credentials with
   these SHA-1s (`PLAY_GAMES_SETUP.md` Steps 1-2):
   - Play **app signing** key (Test and release → App integrity): needed for every Play install.
   - Debug key `55:4F:3B:3C:E4:E3:76:84:9A:35:EC:33:D6:46:D4:79:B9:67:52:A1`: only for test APKs.
2. **Saved Games** must be **On** (Configuration → Properties / Game details). You said it is.
3. **Testers**: add every Gmail that tests, until Step 6 below.

## Step 3. Build and upload 1.1.1
```sh
python3 tools/release.py check        # version 1.1.1 (code 11), keys, plugins
python3 tools/release.py test         # all tests
python3 tools/release.py aab          # build/stone_storm.aab (1.0.0's castle_smashers.aab is never touched)
python3 tools/release.py verify
```
Play Console → **Test and release → Testing → Closed testing** → your track → **Create new
release** → upload `build/stone_storm.aab` → row **11 (1.1.1)**. Release notes:
```
Cloud save with Google Play Games, smoother start-up, settings fit the screen, Hellfire freeze fixed.
```
**Next → Save and publish.**

## Step 4. Store listing and policy (5 minutes)
1. **Data safety**: no change needed. Cloud save stores the save file in the player's own Google
   Play Games account through Google's API; it is never sent to us.
2. The privacy policy already says this (live at the website; section "Google Play Games").
3. **Google Search Console**: the verification tag is on `stonestorm.pages.dev` (deployed). Click
   **Verify** in Search Console, then **Sitemaps** is optional for a one-page site.

## Step 5. Test on your phone (15 minutes)
Uninstall any test APK first, then install 1.1.1 from the testing link.
- First open: Intercore Studio intro **with sound** (turn the phone's media volume up; during
  my test it was at 0, so the intro played silently), then the title card, then home.
- Close and open again: the Stone Storm splash, then home. No intro, no black screen.
- About 1 s after home: Google's Play Games sheet → Continue. Settings → Play Games shows your
  name and "Cloud save on". If you press Cancel the game keeps working.
- Win a level, wait a minute, press Home: the cloud copy is saved.
- Cloud check: uninstall, install again, sign in: your progress comes back by itself.
- Lose a level → "Out of boulders" → Buy Hellfire → pay with the licence tester account →
  **Use Hellfire**: the strike runs and the level is won.

## Step 6. Publish Play Games Services (after Step 5 works)
**Play Games Services → Publishing → Publish.** After this every player can sign in, not just testers.

## Step 7. Production
When Google allows production: **Production → Create new release → Add from library →
11 (1.1.1)** → rollout 20% → 100% after two quiet days in Crashlytics. Same as
`RELEASE_1_1_0.md` Step 4, with code 11.

## Files
| File | What it is |
|---|---|
| `build/castle_smashers.aab` | 1.0.0, untouched. Never upload again. |
| `build/stone_storm.aab` | 1.1.1 after Step 3. The one to upload. |
| `build/stone_storm_test_1.1.1.apk` | My USB test build (debug key, test ads, no real purchases). |
