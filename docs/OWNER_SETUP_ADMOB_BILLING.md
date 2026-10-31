# Owner guide: finish AdMob and Google Play Billing

> First-time setup only. For building, uploading, going public and managing the game afterwards, use **`docs/RELEASE_GUIDE.md`**.

This guide is for the owner (Intercore). The game code for ads and purchases is finished. What is
left is account and console work that only you can do, because it needs your Google login, bank,
tax and identity details.

Work through the parts in order. Each part ends with a "Done when" line so you know you can move
on. Google changes button names now and then. If a button is not exactly where this guide says,
look for the closest match in the same menu.

| Part | What | Time |
|---|---|---|
| 1 | Create the upload key (signing file) | 10 min |
| 2 | Play Console: payments profile (merchant account) | 15 min + Google review |
| 3 | AdMob: account, app, ad units, payments | 30 min |
| 4 | Send me the IDs; I build a release bundle (AAB) | me |
| 5 | Upload to Internal testing and add test users | 20 min |
| 6 | Create the in-app products | 30 min |
| 7 | AdMob test device (so you never click real ads) | 5 min |
| 8 | Test everything on the phone | 30 min |
| 9 | Closed testing with 12 testers (needed before production) | 14 days |

Words used in this guide:
- **Play Console**: https://play.google.com/console, where you manage the app on Google Play.
- **AdMob**: https://admob.google.com, where you manage ads and see ad earnings.
- **AAB**: the file you upload to Play (Android App Bundle). The APK I install over USB is only for quick tests.
- **Product ID**: the name of an in-app item, for example `remove_ads`. It must match the game exactly.

---

## Part 1. Create the upload key

Every file uploaded to Play must be signed with the same key. If you lose this key, you cannot
update the game until Google support resets it, which takes days. Keep two backups.

1. On the Mac, open **Terminal** (press Cmd + Space, type `Terminal`, press Enter).
2. Paste this line and press Enter:
   ```sh
   keytool -genkeypair -v -keystore ~/castle_upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
   If it says `keytool: command not found`, use this instead (it uses the Java inside Android Studio):
   ```sh
   "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkeypair -v -keystore ~/castle_upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
3. It asks for a **keystore password**. Type one (nothing shows while you type; that is normal),
   press Enter, then type it again. Write it down.
4. It asks for your name, organisation (`Intercore`), city, state and country code (`IN`).
   Answer each and press Enter. At "Is this correct?" type `yes`.
5. If it asks for a key password, press Enter to use the same password.
6. The file is now in your home folder: `castle_upload.keystore`.
7. Back it up in two places, for example Google Drive and a USB stick. Also save the password
   in a password manager.
8. **Never** put this file in the game folder or on GitHub.

Done when: `castle_upload.keystore` exists, is backed up twice, and you know its password.

---

## Part 2. Play Console: payments profile

Without a payments profile you cannot sell anything, and the product page stays locked.

1. Open https://play.google.com/console and sign in with the account that owns Castle Smashers.
2. In the left menu, click **Settings** (gear icon, near the bottom).
3. Click **Payments profile**.
4. Click **Create payments profile** (or **Set up a merchant account**).
5. Fill in:
   - Account type: **Business** (Intercore is a sole proprietorship).
   - Legal name and address: exactly as on your PAN / bank account.
   - Contact: intercoreapp@gmail.com.
   - Public merchant name: `Intercore`. Buyers see this on their receipt.
6. Add the **bank account** (account number, IFSC). Google may send a small test deposit that you
   confirm later.
7. Tax: add **PAN**. Add **GSTIN** if you have one (optional for small sellers; ask your CA).
8. Click **Submit**. Verification can take from a few hours to a few days. You will get an email.

Done when: Settings → Payments profile shows your merchant account as **active / verified**.

---

## Part 3. AdMob: account, app, ad units, payments

### 3.1 Account
1. Open https://admob.google.com and sign in with the same Google account.
2. If asked, accept the terms and pick country **India** and time zone **(GMT+05:30)**.
3. Your publisher ID is **pub-1292430265619610** (already in `app-ads.txt` on the website).

### 3.2 Add the app
1. Left menu → **Apps** → **Add app**.
2. Platform: **Android**.
3. "Is the app listed on a supported app store?":
   - If Castle Smashers is **not yet public** on Play, choose **No**. Name it `Castle Smashers`.
     You link it to the store later (step 3.5).
   - If it is already public, choose **Yes** and search `com.castlesmashers.game`.
4. Keep **user metrics** on. Click **Add app**.
5. AdMob shows the **App ID**. It looks like `ca-app-pub-1292430265619610~1234567890` (with a `~`).
   Copy it into a note as **APP ID**.

### 3.3 Create two ad units
The game uses exactly two: an interstitial (shown once per 4 matches at a break) and a rewarded
video (spin wheel, +1 Rocky, double coins, energy refill).

1. Inside the app → **Ad units** → **Add ad unit**.
2. Choose **Interstitial**. Name: `castle_interstitial`. Leave the defaults. Click **Create ad unit**.
3. Copy the **ad unit ID**. It looks like `ca-app-pub-1292430265619610/1111111111` (with a `/`).
   Save it in your note as **INTERSTITIAL**. Click **Done**.
4. **Add ad unit** again → **Rewarded**. Name: `castle_rewarded`.
   - Reward amount `1`, reward item `reward` (the game decides the real reward itself).
   - Click **Create ad unit**, copy the ID into your note as **REWARDED**, then click **Done**.

New ad units can take up to an hour to start serving. Until then you may see "no fill". The
game handles that and retries every 30 seconds.

### 3.4 Privacy and consent messages (required)
1. Left menu → **Privacy & messaging**.
2. **European regulations (GDPR)** → **Create message**. Select the Castle Smashers app. Add the privacy
   policy URL `https://castle-smashers.pages.dev/privacy/`. Keep the default choices
   ("Consent" and "Manage options"). Click **Publish**.
3. **US state regulations** → **Create message** → select the app → **Publish**.
4. The game already shows this form on first start in those regions, and adds an **Ad Privacy** button
   to Settings.

### 3.5 Content rating and app-ads.txt
1. Left menu → **Blocking controls** → **Content rating** (or app settings → **Max ad content rating**):
   choose **T** (Teens). The game also requests T from code. MA stays blocked.
2. Left menu → **Apps** → **View all apps** → the **app-ads.txt** tab. When Castle Smashers is
   public on Play with the website `https://castle-smashers.pages.dev` in its store listing,
   AdMob shows the app as **Verified** within about a day. Nothing to do on the website; the file
   is already live.
3. Once the game is public on Play, go to **Apps** → Castle Smashers → **App settings** → **Link to app store**,
   and pick it from Google Play.

### 3.6 Payments (so you get paid)
1. Left menu → **Payments** → **Payments info** → **Add payment method**.
2. Enter the bank account (same as Play), then tax info (PAN). AdMob pays monthly once you
   pass the payment threshold. The first payout also needs **address verification by PIN**: Google
   posts a letter with a PIN after you earn about $10. Enter it under Payments.

Done when: you have **APP ID**, **INTERSTITIAL** and **REWARDED** in your note, and the
GDPR and US messages are **Published**.

---

## Part 4. Send me the IDs; I build the release bundle

Send me in chat:
1. **APP ID** (`ca-app-pub-...~...`)
2. **INTERSTITIAL** (`ca-app-pub-.../...`)
3. **REWARDED** (`ca-app-pub-.../...`)
4. The path of the keystore (`~/castle_upload.keystore`). **Do not send the password in chat.**
   Type it yourself in step 4.3 below.

Ad IDs are not secret (they are inside every APK), so sharing them in chat is fine. The keystore
password is secret.

What I will do with them:
- Put the App ID in Project Settings → `admob/general/android/app_id`.
- Write `ad_ids.cfg` (git-ignored) with the two unit IDs. Debug builds keep using Google's test
  ads; only release builds use your real units.
- Raise the version code, then build `build/castle_smashers.aab`.

### 4.3 The one step you type yourself (keystore password)
1. Open Godot → open the Castle Smashers project.
2. Top menu **Project** → **Export...**.
3. Click the **Android** preset on the left.
4. On the right, scroll to **Keystore**:
   - **Release**: click the folder icon, pick `castle_upload.keystore` in your home folder.
   - **Release User**: `upload`
   - **Release Password**: your keystore password.
5. Close the window. Godot stores these in `.godot/export_credentials.cfg`, which is never
   committed.
6. Tell me "keystore set". I then export the AAB.

Done when: `build/castle_smashers.aab` exists (I will confirm).

---

## Part 5. Internal testing and test users

There are three kinds of "test users". You need all three.

| Kind | What it does | Where |
|---|---|---|
| **Internal testers** | Can install the game from Play before it is public (up to 100) | Play Console → Test and release → Testing → Internal testing → Testers |
| **License testers** | Pay with test cards, never charged | Play Console → Settings → License testing |
| **AdMob test devices** | See "Test Ad" on real ad units, so clicks never count | AdMob → Settings → Test devices (Part 7) |

### 5.1 Upload the AAB to Internal testing
1. Play Console → select **Castle Smashers**.
2. Left menu → **Test and release** → **Testing** → **Internal testing**.
3. Click **Create new release**.
4. If asked about **Play App Signing**, click **Continue** / **Use Google-generated key**. Google
   keeps the final signing key; you keep the upload key from Part 1.
5. Under **App bundles**, click **Upload** and choose `build/castle_smashers.aab` from the project folder.
6. Release name: leave the default.
7. Release notes: `Internal test: ads and purchases.`
8. Click **Next**. Fix any red errors it shows (yellow warnings are fine), then click **Save and publish**
   (or **Start rollout to Internal testing**).

### 5.2 Add internal testers
1. Same page → **Testers** tab.
2. Click **Create email list**. Name: `Castle core testers`.
3. Add the Gmail addresses, separated by commas. Add **your own phone's Google account** first.
4. Click **Save changes**, tick the list, then click **Save**.
5. Under **How testers join your test**, click **Copy link**. Send this link to each tester (and to yourself).

### 5.3 Add license testers
1. Left menu → **Settings** (gear) → **License testing**.
2. In the email box, add the same Gmail addresses (your own first).
3. **License response**: leave `RESPOND_NORMALLY`.
4. Click **Save changes**.

### 5.4 Install from Play on your phone (important)
1. On the phone, open the copied link while signed in with your tester Gmail.
2. Tap **Become a tester** / **Accept invite**.
3. Tap **Download it on Google Play**. Then on the Play page, tap **Install** (or **Update**).
   - If Play says the app is "not compatible" or shows nothing, wait 15 to 30 minutes after
     publishing and try again.
   - If you have my USB debug build installed, **uninstall it first** (long-press the icon → Uninstall).
     Play cannot update over a build signed with a different key.

Why this matters: purchases only work on a copy installed from Play. My USB builds show
"Loading..." on prices, because Play refuses product queries from apps it did not install.

Done when: the phone has Castle Smashers installed **from Play**, and the Play page shows
"(Internal testing)" or "You're a tester".

---

## Part 6. Create the in-app products

You can do this after Part 5.1, because Play unlocks products only after a build with
the billing permission is uploaded.

1. Play Console → Castle Smashers → left menu **Monetize with Play** → **Products** → **One-time products**.
2. Click **Create one-time product**.
3. Fill in one product (the table below lists all of them):
   - **Product ID**: exactly as in the table. It cannot be changed or reused later.
   - **Name** and **Description**: from the table.
4. Under **Purchase options**, Play creates a default **Buy** option. Open it:
   - **Availability**: all countries (or **Set prices** → **Add countries/regions** → select all).
   - **Price**: the USD price from the table. Play converts other currencies. You can fine-tune
     prices per country later (`BILLING_SETUP.md` part 3 has suggested Indian and other prices).
   - Leave tax settings at the default.
5. Click **Save**, then **Activate** (the status must say **Active**).
6. Repeat for every row.

| Product ID | Name | Description | Price (USD) |
|---|---|---|---|
| `remove_ads` | Remove Ads | No more ads. Video bonuses are granted instantly. | 4.99 |
| `coin_crate` | Coin Crate | 30,000 coins for engines and upgrades. | 1.99 |
| `gem_crate` | Gem Crate | 400 gems. | 4.99 |
| `hellfire_crate` | Hellfire Crate | 3 Hellfire strikes that burn down enemy structures. | 2.99 |
| `addon_pirate_hat` | Pirate Hat | Rocky addon: black tricorn with a skull badge. Looks only. | 0.99 |
| `addon_cap` | Slugger Cap | Rocky addon: red baseball cap with a star. Looks only. | 0.99 |
| `addon_crown` | Royal Crown | Rocky addon: gold crown with three gems. Looks only. | 1.99 |
| `addon_viking` | Viking Helmet | Rocky addon: horned steel helmet. Looks only. | 0.99 |
| `addon_top_hat` | Top Hat | Rocky addon: tall black hat with a red ribbon. Looks only. | 0.99 |
| `addon_shades` | Cool Shades | Rocky addon: dark sunglasses. Looks only. | 0.99 |
| `addon_specs` | Smart Specs | Rocky addon: round gold glasses. Looks only. | 0.99 |

Notes:
- All 11 are the same Play type, "one-time product". The game itself decides which ones can be
  bought again: crates are "consumed" so they can be bought again, while Remove Ads and addons are kept forever.
- Do not create subscriptions. The game has none.
- New products can take up to a few hours to appear in the game.

Done when: all 11 products show **Active**.

---

## Part 7. AdMob test device

Release builds show **real** ads. If you click your own real ads, AdMob can ban the account.
Register your phone as a test device so it gets real ads marked "Test Ad".

1. On the phone, open **Settings** → **Google** → **Ads** (on some phones: **Settings** →
   **Privacy** → **Ads**).
2. Copy the **Your advertising ID** value. If it says the ID was deleted, tap
   **Get new advertising ID** first.
3. On the Mac, open AdMob → left menu **Settings** → **Test devices** → **Add test device**.
4. Name: `Realme Sumit`. Platform: **Android**. Paste the advertising ID.
5. Ad inspector gesture: choose **Shake** (optional).
6. Click **Save**. It can take up to 15 minutes to take effect.
7. Do the same for every tester's phone, or tell testers **never to tap ads** in the game.

Done when: your phone is listed under Test devices.

---

## Part 8. Test that it works

Do these on the phone with the **Play-installed** copy (Part 5.4), signed in with a
license-tester account.

### 8.1 Purchases
1. Open the game → **Shop**.
2. **Prices load**: each item shows a price in rupees (for example `₹99.00`) instead of
   "Loading...". If it still says "Loading..." after a minute, see Troubleshooting.
3. Open **Hero Addons**, tap the price on **Pirate Hat**.
4. The Google Play sheet appears. Below the price it should say **"Test card, always approves"**.
   This line proves you are a license tester. If you see your real card instead, **press Back**:
   your account is not a license tester yet.
5. Tap **Buy**. In the game you should see "Pirate Hat delivered. Thank you!" and the card changes
   to **TAKE OFF**. Rocky now wears the hat on the home screen and in levels.
6. Repeat the other test cases:

| Test | What to do | Expected |
|---|---|---|
| Declined | Buy Coin Crate, pick **Test card, always declines** | "Payment declined", no coins |
| Cancel | Open a purchase and press Back | "Purchase cancelled", nothing given |
| Consumable | Buy **Coin Crate** twice with the approving card | +30,000 coins each time |
| Slow card | Buy Gem Crate with **Slow test card, approves after a few minutes** | "Payment pending...", gems arrive a few minutes later, even if you close the game |
| Remove Ads | Buy Remove Ads | No more interstitials; reward buttons give rewards without a video |
| Restore | Uninstall, reinstall from Play, open Shop | Remove Ads and addons come back by themselves (or tap **Restore Purchases**) |

7. On the Mac: Play Console → **Order management**. Your test orders show with a **Test** label.
   They are never charged.

### 8.2 Ads
1. Use an account **without** Remove Ads (or a second tester).
2. In a region where consent applies (EEA/UK), the consent form should appear on first start.
   In India it usually does not.
3. **Rewarded**: Home → **Spin Wheel** → after the free spin, tap **WATCH AD: SPIN**. A full-screen video
   with a **"Test Ad"** label should play, and the wheel spins after you close it.
4. **Interstitial**: play 4 matches from level 3 onwards. Wins, losses and retries after a
   shot all count. At the 4th break (NEXT, RETRY or MAP on the results screen, or MAP / RESTART in the
   pause menu), a full-screen ad shows. Close it and the game continues where you tapped.
5. The ad should cover the whole screen, including the camera notch area.
6. Next day, check AdMob → **Home** / **Reports**: you should see **Requests** and **Impressions**
   for both ad units. Test-device impressions earn nothing; that is expected.

### 8.3 Logs (optional, I can do this with you over USB)
With the phone on USB, I can run `adb logcat -s godot:V` and look for:
- `Ads: AdMob ready`: the ad SDK started.
- `Ads: interstitial failed to load: ...`: no fill yet (new units) or no internet. The game retries every 30 s.
- `Store: product query failed (...)`: products are not Active yet, the app was not installed from Play, or the
  account is not a tester.
- `Store: billing connection failed (...)`: the Play Store app needs an update or sign-in.

Done when: every row in 8.1 behaves as expected, a "Test Ad" rewarded video and an interstitial
have played, and AdMob Reports show requests.

---

## Part 9. Closed testing (needed before going public)

Google requires **new personal developer accounts** to run a **closed test with at least
12 testers who stay opted in for 14 days in a row** before they can apply for production.
If your account is an organisation account, or older than November 2023, this may not apply.
Play Console shows this on the **Dashboard** if it applies.

1. Play Console → **Test and release** → **Testing** → **Closed testing** → **Create track**
   (or use the default **Alpha** track) → **Create new release** → **Add from library**, pick the same
   AAB → **Save and publish**.
2. **Testers** tab → add an email list with at least 12 real people (friends and family). Send them the
   opt-in link. Each one must tap **Become a tester** and install the game.
3. Wait 14 days. Ask testers to open the game every few days. Google checks that they keep using it.
4. Dashboard → **Apply for production**. Answer the questions about the test (what you changed
   based on feedback).

Before production you also need (from earlier work): Store listing, Content rating questionnaire,
Target audience (13+), Data safety form (answers in `FIREBASE_SETUP.md`), Ads declaration = **Yes, contains ads**,
and the privacy policy URL `https://castle-smashers.pages.dev/privacy/`.

---

## Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| Shop says "Loading..." | Game installed by USB, products not Active, or less than a few hours since creating them | Install from the Play test link (Part 5.4); check all products are Active; wait |
| Play sheet shows a real card | Account is not a license tester | Add it in Settings → License testing, wait 15 min, reopen the game |
| "This item is unavailable" | Product ID typo or product inactive | Compare with the table in Part 6 letter by letter |
| "App not available" on the test link | Release still processing, or account not in the tester list | Wait 30 min; check the Testers tab |
| No ads at all | New ad units (up to 1 h), App ID or unit IDs wrong, Remove Ads owned | Wait; send me the IDs again to check; use a second account |
| Ads show but without "Test Ad" | Phone not registered as a test device | Part 7. Do not tap the ad |
| Can't update the game from Play | A USB debug build is installed | Uninstall it, then install from Play |

## Checklist

- [ ] Part 1: upload keystore created, backed up twice
- [ ] Part 2: payments profile verified
- [ ] Part 3: AdMob app, 2 ad units, GDPR + US messages published, payments info
- [ ] Part 4: IDs sent to me, keystore set in Godot, AAB built
- [ ] Part 5: AAB on Internal testing, internal testers + license testers added, installed from Play
- [ ] Part 6: 11 products Active
- [ ] Part 7: phone added as AdMob test device
- [ ] Part 8: all purchase tests pass, rewarded + interstitial ads seen
- [ ] Part 9: closed test with 12 testers for 14 days, then apply for production
