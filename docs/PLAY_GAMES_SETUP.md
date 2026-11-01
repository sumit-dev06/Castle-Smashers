# Google Play Games sign-in: what's left for you (owner)

The code side is finished: Play Games Services v2 SDK (`play-services-games-v2:21.0.0`) inside our
CastlePlay plugin, project id `300021741882` in the manifest, automatic sign-in at start, and a
Settings → Play Games → **Sign in** button. Nothing more is needed in code.

Sign-in only works when the **SHA-1 fingerprint of the key that signed the installed app** is
registered as an Android credential in Play Games Services. There are three keys:

| Key | SHA-1 | Signs | Needed for |
|---|---|---|---|
| **App signing key** (Google holds it) | copy it from Play Console (step 1) | every copy installed **from Google Play** | **all real players. Required.** |
| Upload key (`~/castle_upload.keystore`) | `E8:2E:B0:4A:D6:0A:B3:C2:F8:6A:8E:68:C2:9C:97:E5:8D:CC:5A:D2` | `build/stone_storm.aab` before Google re-signs it | optional (only if you install the AAB yourself with bundletool) |
| Debug key (`~/.android/debug.keystore`) | `55:4F:3B:3C:E4:E3:76:84:9A:35:EC:33:D6:46:D4:79:B9:67:52:A1` | `build/stone_storm_debug.apk` (friends' test-ads copy) | optional (sign-in in the friends' APK) |

## Step 1. Copy the app signing key's SHA-1
1. Open https://play.google.com/console and pick **Stone Storm** (Castle Smashers).
2. Left menu: **Test and release → App integrity**.
3. Tab or section **Play app signing** → click **Settings** (or "App signing key certificate").
4. Under **App signing key certificate**, find **SHA-1 certificate fingerprint**. Click the copy
   icon next to it. It looks like `AB:12:...` (20 pairs). This is **not** the E8:2E... one above.

## Step 2. Add it as a credential
1. Left menu: **Grow users → Play Games Services → Setup and management → Configuration**.
2. You should see project **300021741882** and a credential for package `com.castlesmashers.game`.
3. Click the credential (or **Add credential** → **Android**).
4. If it already lists a SHA-1, check which one. If it is the upload key (E8:2E...), add a **second**
   Android credential:
   - Name: `Stone Storm (Play signing)`
   - Package name: `com.castlesmashers.game`
   - **Signing certificate fingerprint (SHA-1)**: paste the value from Step 1
   - Leave "Anti-piracy" off. Click **Save changes**.
5. Optional, for the friends' APK: add one more Android credential with the debug SHA-1
   `55:4F:3B:3C:E4:E3:76:84:9A:35:EC:33:D6:46:D4:79:B9:67:52:A1`. Google may warn that the
   package already has a credential: that's fine.

Note: if Google says the credential must be created in Google Cloud first, open the **OAuth
consent / Google Cloud** link it shows, create an **Android OAuth client** with the same package and
SHA-1, then come back and pick it. Use the same Google account as Play Console.

## Step 3. Testers (while Play Games Services is unpublished)
1. **Play Games Services → Setup and management → Testers → Add testers**.
2. Add your own Gmail and anyone testing. Unpublished projects only let testers sign in.

## Step 4. Test on your phone
1. Install 1.1.0 **from the Play internal testing link** (not the APK).
2. Open the game. Within a few seconds Google shows "Signed in as ..." at the top, or
   Settings → Play Games shows your name instead of the Sign in button.
3. If it shows **Sign in** and tapping it does nothing or flashes: the SHA-1 is wrong or the
   account is not a tester. Recheck Step 2 and 3.

## Step 5. Publish
1. **Play Games Services → Publishing** (or "Review and publish").
2. It lists anything missing (for example the game's icon or description for Play Games). Fill
   those in: icon `assets/art/brand/play_store_icon_512.png`, description from `store_listing/listing.md`.
3. Click **Publish**. After publishing every player can sign in, not just testers.

## What sign-in does today
Players get the Play Games welcome banner and their Play Games profile. **Progress is not stored
in the cloud yet** (Saved Games is enabled in the console but not used by the game). Saves stay on
the phone and in Android backup as before. Cloud save is the next step if you want progress to
follow a player to a new phone even without Android backup.
