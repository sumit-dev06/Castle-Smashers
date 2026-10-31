# Google Play Release Checklist

## One-time setup
- [ ] Package name: `com.castlesmashers.game` (can never change after first upload)
- [ ] Upload keystore: create once, back it up in two places, never commit.
      `keytool -genkeypair -v -keystore castle_upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000`
- [ ] Enrol in Play App Signing (Google holds the app signing key, we sign with the upload key)
- [ ] Privacy policy page: enable GitHub Pages (repo Settings → Pages → branch `main`, folder
      `/docs`), set `CONTACT_EMAIL` in `docs/privacy/index.html`. URL:
      `https://sumit-dev06.github.io/Castle-Smashers/privacy/` (already used by Settings → Privacy)
- [ ] AdMob account + app, link to Play listing (`MONETIZATION.md`)
- [ ] In-app products, licence testers, regional prices (`BILLING_SETUP.md`)
- [ ] Firebase project + `google-services.json` (`FIREBASE_SETUP.md`)
- [ ] Personal developer accounts created after Nov 2023: **closed test with ≥12 testers for 14
      days** before production access

## Each release
- [ ] Bump `version/code` (+1) and `version/name` in `export_presets.cfg`
- [ ] Release export: Android App Bundle (`.aab`), Gradle build, arm64-v8a + armeabi-v7a
- [ ] Target SDK = current Play requirement (35+ in 2025, 36 set now)
- [ ] Real AdMob IDs, test IDs removed; `debug` flags off
- [ ] Test on device: install, play 3 levels, purchase test (licence tester account), ad test
- [ ] Upload to Internal testing → check pre-launch report → promote

## Store listing assets
| Asset | Size |
|---|---|
| App icon | 512×512 PNG, 32-bit |
| Feature graphic | 1024×500 |
| Phone screenshots | 2–8, 16:9 landscape, min 1080 px short side recommended |
| Tablet screenshots (7" and 10") | optional but improves reach |
| Short description | ≤80 chars |
| Full description | ≤4000 chars |

Draft short description: "Fling heroes from your catapult and smash cartoon castles to pieces!"

## Forms in Play Console
Content rating (IARC questionnaire: cartoon violence, in-app purchases), target audience 13+,
Data safety (answers in `FIREBASE_SETUP.md`), Ads declaration = yes, government app = no.
Full checklist: `POLICY_AUDIT.md`.

## Studio intro
The INTERCORE STUDIO intro (`assets/intro/`, made by `tools/capture_intro.py` from
`art_source/intro/intercore_studio_cinematic_intro.html`) plays on the first launch after install
and after every update. **Bump `application/config/version` in project settings for each release**:
that change is what makes the intro play again after an update.
