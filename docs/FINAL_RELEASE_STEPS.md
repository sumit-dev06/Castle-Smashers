# Castle Smashers 1.0.0: release it to everyone, step by step

Read every step. Do them in order. Don't skip one because it looks small.
Each step says **where to click**, **what to type** and **what you should see**.
If what you see is different, stop and read "If something goes wrong" at the end.

---

## Before you start: 5 things to understand

**1. There is only one "final" file.**
The file is `castle_smashers_1.0.0_code9.aab`. It is already the real game: real ads, real
purchases, signed with your key. Google doesn't have a separate "test build" and "real build".
The **same file** goes first to testers, then to everyone. You don't build anything new for the
public launch.

Where the file is:
- `Documents` → `Castle Smashers Releases` → `castle_smashers_1.0.0_code9.aab` (your safe copy)
- also `Documents` → `Castle Smashers 2` → `build` → `castle_smashers.aab` (same file)

**2. What you already have on Play.** Version 0.4.0 (code 4) is on **Internal testing**, and your
phone has it. Internal testing is a private room for you and your testers. Version 1.0.0 (code 9)
replaces it there, and later goes to the public room (**Production**).

**3. The path the game takes:**
```
Internal testing  →  Closed testing  →  (Google checks, 14 days)  →  Production (everyone)
   you, minutes        12+ testers           apply for access          20% first, then 100%
```

**4. Things that can never be undone.** Don't do these unless the step tells you to:
- Changing the package name `com.castlesmashers.game`.
- Making the app **Paid** (a free app can never become paid).
- Deleting or renaming a product ID (for example `remove_ads`).
- Using a version code that was already used (Play refuses it anyway).

**5. Your phone stays safe.** Never uninstall the game from your phone to test something. Always
update it from the Play Store. Your progress stays.

**What you need:** your Mac, your phone, the Gmail you use for Play Console, about 1 hour today,
12 friends with Android phones and Gmail, and 14 days of waiting.

---

## Step 1. Upload 1.0.0 to Internal testing (today, 15 minutes)

1. On the Mac, open **Google Chrome**. Go to **play.google.com/console**. Sign in.
2. You see a list of apps. Click **Castle Smashers**.
3. In the left menu, click **Test and release**. It opens. Click **Testing**, then **Internal testing**.
4. At the top right, click the blue button **Create new release**.
   - If Google asks about **Play App Signing**, it's already on. Click **Continue** if asked.
5. Find the box **App bundles**. Click **Upload**. A Finder window opens.
6. In the Finder window: click **Documents** on the left → double-click **Castle Smashers Releases**
   → click **castle_smashers_1.0.0_code9.aab** → click **Open**.
7. Wait. A bar fills up (2 to 5 minutes, the file is about 133 MB). When it's done you see a row:
   **9 (1.0.0)**. If you see a red error, go to "If something goes wrong".
8. **Release name**: Google fills in `9 (1.0.0)`. Leave it.
9. **Release notes**: there's a box with `<en-US>` and `</en-US>`. Click between them and type:
   ```
   Castle Smashers 1.0! 50 levels, 5 heroes, Master Sieges, Hellfire, daily rewards and much more.
   ```
   Keep the `<en-US>` and `</en-US>` lines as they are.
10. Click **Next** (bottom right).
11. Google shows a summary. Yellow **warnings** are fine (see the list at the end). A red **error**
    is not: stop and read "If something goes wrong".
12. Click **Save and publish**. If a box asks again, click **Save and publish** again.
13. You should see **"Available to internal testers"** within a few minutes.
14. On the Mac, write it down so you never reuse the number. Open Terminal and type:
    ```
    cd "/Users/sumit/Documents/Castle Smashers 2"
    open docs/RELEASE_HISTORY.md
    ```
    A text window opens. Add this line at the bottom, then save (Cmd+S) and close it:
    ```
    | 2026-11-01 12:00 | 9 | 1.0.0 | internal | manual upload | Version 1.0 |
    ```
    (Change the date and time to now.)

---

## Step 2. Test 1.0.0 on your phone (today, 20 minutes)

1. On your phone, open the **Play Store**. Search **Castle Smashers** and open its page.
2. Tap **Update**. If there's no Update button: close the Play Store completely (swipe it away
   from recent apps), wait 10 minutes, open it again. Repeat for up to 1 hour.
3. Open the game. Check each thing and tick it:
   - [ ] The intro says **INTERCORE STUDIOS** and the music is loud enough.
   - [ ] Your old progress is still there.
   - [ ] **Settings** (gear icon) → the bottom says **Version 1.0.0**.
   - [ ] **Shop** → every item shows a price in ₹, not "Loading...".
   - [ ] Buy **Coin Crate**. The Google sheet says **"Test card, always approves"**. Tap Buy.
         You get 30,000 coins. (If it shows your real card, press Back! See "If something goes wrong".)
   - [ ] Buy the **Pirate Hat** with the test card. Rocky wears it. During the payment the game
         stays sideways (landscape).
   - [ ] **Spin Wheel** → after the free spin, tap **WATCH AD: SPIN**. A video with **"Test Ad"**
         plays. Close it; the wheel spins.
   - [ ] Play 4 levels from level 3 or later. After the 4th, an ad with "Test Ad" shows.
   - [ ] Press the phone's home button in the middle of a level, then open the game again. It shows
         **PAUSED**.
   - [ ] Settings → **Contact Support** opens an email with the version and your phone model in it.
         Don't send it.
4. All ticked? Go to Step 3. Something wrong? Write down what happened and fix it before going on
   (ask your AI helper with `docs/RELEASE_GUIDE.md` part 17).

**Never tap an ad that does NOT say "Test Ad".** That can get your AdMob account closed.

---

## Step 3. Get 12 testers (today and tomorrow)

Google needs **at least 12 people** testing for **14 days in a row** before you can launch.
Get 15, because someone always forgets.

1. Ask 15 friends or family members. They need an Android phone and a Gmail address.
2. Write their Gmail addresses in a list (one per line).
3. Play Console → left menu **Test and release** → **Testing** → **Closed testing**.
4. You see a track called **Closed testing - Alpha** (or similar). Click **Manage track**.
   (If there's no track, click **Create track**, name it `Alpha`, click **Create track**.)
5. Click the **Testers** tab → **Create email list**.
   - List name: `Castle testers`
   - Paste all the Gmail addresses (comma or one per line) → press **Enter** → **Save changes**.
6. Make sure the box next to **Castle testers** is ticked. Click **Save**.
7. Make the testers' purchases free too: go back to the main Play Console page (click the Play
   Console logo top left) → left menu **Settings** → **License testing**. Add the same Gmail
   addresses → **Save changes**.
8. Back in **Closed testing** → **Testers** tab, scroll down to **How testers join your test**.
   Copy the **link** (it starts with `https://play.google.com/apps/testing/...`).
   You'll send it in Step 4.

---

## Step 4. Send 1.0.0 to the closed testers (today, 10 minutes)

1. Play Console → **Testing** → **Closed testing** → your Alpha track → **Create new release**.
2. In **App bundles** click **Add from library** (not Upload). Pick **9 (1.0.0)** → **Add to release**.
3. Release notes: the same text as in Step 1. Click **Next**.
4. Click **Save and publish**. Closed testing is reviewed by Google: it can take a few hours, up to
   2 days. Play Console → **Publishing overview** shows "In review", then "Published".
5. When it's published, send each tester this message on WhatsApp:
   ```
   Hi! Please help me test my game Castle Smashers for 2 weeks.
   1. Open this link on your Android phone, signed in with the Gmail you gave me: [PASTE LINK]
   2. Tap "Become a tester".
   3. Tap "Download it on Google Play" and install it.
   4. Please keep it installed for 14 days and play a little every 2-3 days.
   Purchases are free test purchases, you will not be charged. Tell me anything that is broken
   or too hard. Thank you!
   ```
6. **Days 1 to 14**: every 3 days, remind them to open the game. Write down what they tell you.
7. Play Console → **Dashboard** shows a counter for testers and days. It must reach
   **12 testers** and **14 days**.
8. During the 14 days, ship at least **one small update** with something a tester asked for
   (Google likes to see that). How: `docs/RELEASE_GUIDE.md` part 5 (version 1.0.1, code 10), upload
   to Internal, test, then add it to Closed testing like in this step.

---

## Step 5. Fill in the forms (do it during the 14 days, 1 hour)

Play Console → left menu **Policy and programs** (or **Monitor and improve**) → **App content**.
Each item below must end with a green tick. Click the item → **Start** (or **Manage**) → answer →
**Save** → **Back**.

| Item | What to choose |
|---|---|
| **Privacy policy** | Paste `https://castle-smashers.pages.dev/privacy/` → Save |
| **App access** | **All functionality in my app is available without any access restrictions** |
| **Ads** | **Yes, my app contains ads** |
| **Content rating** | Email: intercoreapp@gmail.com. Category: **Game**. Violence: **Yes**, cartoon/fantasy only, no blood, no realistic violence, no harm to realistic humans. Sexual content, language, drugs, gambling (real money): **No**. Users can interact/chat: **No**. Shares location: **No**. Digital purchases: **Yes**. Save → Next → **Submit**. |
| **Target audience and content** | Ages: tick **13-15**, **16-17**, **18 and over**. Do **not** tick anything under 13. "Could the store listing appeal to children?": answer honestly; if asked, explain the game is designed for teens and adults. |
| **Data safety** | Open `docs/FIREBASE_SETUP.md` on the Mac (section "Data safety form") and copy each answer. Encrypted in transit: **Yes**. Users can ask to delete data: **Yes** (by email). |
| **Advertising ID** | **Yes** → tick **Advertising or marketing** and **Analytics** |
| **Government apps** | **No** |
| **Financial features** | **My app doesn't provide any financial features** |
| **Health** | **My app doesn't have any health features** |
| **News apps** | **No** |

When every row is green, the **Dashboard** task list will show those as done.

---

## Step 6. The store page (during the 14 days, 30 minutes)

Everything is ready on the Mac in `Castle Smashers 2` → `store_listing`.

1. Play Console → left menu **Grow users** → **Store presence** → **Main store listing**.
2. **App name**: `Castle Smashers`
3. **Short description**: open `store_listing/listing.md` and copy the short description.
4. **Full description**: copy the full description from the same file.
5. **App icon**: upload `assets/art/brand/play_store_icon_512.png`.
6. **Feature graphic**: upload `store_listing/feature_graphic_1024x500.png`.
7. **Video** (optional): upload your edited video to YouTube (Public or Unlisted, ads off,
   no age limit), then paste its link here. Raw clips are in `store_listing/video/`.
8. **Phone screenshots**: upload the designed ones from `store_listing/screenshots_designed/`,
   in number order (01, 02, 03...). Use at least 4.
9. **7-inch and 10-inch tablet screenshots**: upload the same designed files.
10. Click **Save**.
11. Left menu **Store presence** → **Store settings**:
    - App category: **Game** → **Casual**
    - Email: `intercoreapp@gmail.com`
    - Website: `https://castle-smashers.pages.dev` (exactly this, it's needed for ads)
    - Click **Save**.
12. Left menu **Monetize with Play** → **Products** → **In-app products**: check all 11 say **Active**.

---

## Step 7. Apply for production (day 15)

1. Play Console → **Dashboard**. When the closed test has 12+ testers for 14+ days, a button
   **Apply for production** appears. Click it.
2. Answer the questions in your own words, honestly. Example answers:
   - *How did you recruit testers?* "Friends and family, 15 people with different Android phones."
   - *How engaged were they?* "They played every few days and sent feedback on WhatsApp."
   - *What did you learn / change?* Write the real things testers told you and what you fixed.
   - *Is the app ready?* "Yes."
3. Click **Submit**. Google usually answers within **7 days** by email. If they say no, read why,
   continue testing (often a few more days), and apply again.

---

## Step 8. Launch to the public (after Google says yes)

1. Play Console → **Test and release** → **Production** → **Countries / regions** tab →
   **Add countries / regions** → tick **all** (or the ones you want) → **Add** → **Save**.
2. **Releases** tab → **Create new release**.
3. **App bundles** → **Add from library** → pick the newest tested version (9, or 10 if you updated
   during testing) → **Add to release**.
4. Release notes: the same text as Step 1 (or your newest).
5. Click **Next**. On the review page find **Rollout percentage** and type **20**. This sends the
   game to 20% of people first, so a hidden problem only reaches a few.
6. Click **Save** → **Send for review** (or **Start rollout to Production** → **Rollout**).
7. Google reviews it: a few hours to 7 days for the first time. **Publishing overview** shows the status.
8. When it's live, your game has a public page. Open it on your phone and check it looks right.

**Do this on launch day (AdMob, important for money):**
1. Go to **admob.google.com** → **Apps** → **Castle Smashers** → **App settings**.
2. Click **Add app store details** (or **Link**). Search "Castle Smashers", pick it, **Save**.
3. Until you do this, few real ads show. AdMob then checks the app (a few days) until it says **Ready**.
4. AdMob → Apps → **app-ads.txt** tab: after a few days it should say **Found**.

---

## Step 9. The first week after launch

**Day 1 and 2:**
- Play Console → **Quality** → **Android vitals**: look at **Crash rate** and **ANR rate**.
  Good: crash under 1%, ANR under 0.5%.
- **firebase.google.com** → your project → **Crashlytics**: any new crash? Note the level and phone.
- **Ratings and reviews**: reply kindly to every review.

**Day 3, if everything looks fine:** Production → **Releases** → your release → **Manage rollout**
→ **Update rollout** → **50** → Update. **Day 5:** the same with **100**.

**If something is badly broken:** Production → your release → **Manage rollout** →
**Halt rollout**. People who have it keep it; nobody new gets it. Fix it, make version 1.0.1
(`docs/RELEASE_GUIDE.md` part 5), test on Internal, then send it to Production.

**Every month:** check money (`docs/RELEASE_GUIDE.md` part 12), back up your secret files:
```
cd "/Users/sumit/Documents/Castle Smashers 2"
python3 tools/release.py backup-secrets --to "/Volumes/YOUR_USB_NAME"
```

---

## If something goes wrong

| What you see | What it means | What to do |
|---|---|---|
| "Version code 9 has already been used" | This file was uploaded before | Use "Add from library" instead of Upload |
| "You uploaded an APK or Android App Bundle that is signed with the wrong key" | Wrong file | Use the file from `Castle Smashers Releases`, not one a friend sent |
| "Your app targets API level ..." error | Google's yearly rule changed | Needs a developer: update Godot (`RELEASE_GUIDE.md` part 10.5) |
| Warning: "This App Bundle contains native code, and you've not uploaded debug symbols" | Optional crash details | Ignore. Crashlytics already gets them |
| Warning: "There is no deobfuscation file" | Optional | Ignore |
| Warning about **"Advertising ID"** | Form not filled | Step 5, Advertising ID: Yes |
| Shop says "Loading..." | Phone not signed in as a tester, or installed by USB | Install from the Play test link; wait 1 hour |
| Payment sheet shows your **real card** | Your Gmail isn't a license tester | Press **Back**. Step 3.7, wait 15 minutes, reopen the game |
| An ad without "Test Ad" on your phone | Phone not an AdMob test device | Don't tap it. `RELEASE_GUIDE.md` part 4.2 |
| No Update button on your phone | Play hasn't reached your phone yet | Close the Play Store, wait 30 min, check you're signed in with a tester Gmail |
| "Apply for production" doesn't appear | Not 12 testers × 14 days yet | Dashboard shows how many; remind testers to keep the game installed |
| Google rejects the app or sends a policy email | A form or the listing needs a change | Read the email. Most fixes are in App content (Step 5). Give the email to your AI helper |
| "Changes not sent for review" | Play saved but didn't submit | **Publishing overview** → **Send changes for review** |

---

## Your checklist

- [ ] Step 1: 1.0.0 (code 9) on Internal testing, written in RELEASE_HISTORY
- [ ] Step 2: all phone tests ticked
- [ ] Step 3: 15 testers in an email list and in License testing
- [ ] Step 4: Closed testing published, link sent, 14 days counting
- [ ] Step 5: every App content item green
- [ ] Step 6: store listing, screenshots, feature graphic, settings saved; 11 products Active
- [ ] Step 7: applied for production, approved
- [ ] Step 8: production at 20%, AdMob app linked
- [ ] Step 9: 50%, then 100%; secrets backed up
