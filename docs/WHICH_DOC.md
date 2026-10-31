# Which doc do I open?

Start here. Find your situation in the left column and open only the doc on the right.
Docs marked **owner** are written for you (no coding). The rest are for whoever changes the code.

## Right now: getting 1.0.0 to the public

| I want to... | Open |
|---|---|
| Release the game to everyone, step by step | **`docs/FINAL_RELEASE_STEPS.md`** (owner). Follow Steps 1 to 9 in order. This is the only doc you need until launch. |
| Know what to paste into the Play store page | `store_listing/listing.md` (owner) |
| Know which image, icon or video goes where in Play Console | `store_listing/README.md` (owner) |
| Answer the Data safety, Ads or Content rating forms | `docs/FINAL_RELEASE_STEPS.md` Step 5 (owner). Background: `docs/FIREBASE_SETUP.md` "Data safety" |
| Check the game follows Play, AdMob and Billing rules | `docs/POLICY_AUDIT.md` |

## After launch: running the game

| I want to... | Open |
|---|---|
| Make and publish an update | `docs/RELEASE_GUIDE.md` part 5 (owner) |
| Let the tool upload to Play by itself (one-time) | `docs/RELEASE_GUIDE.md` part 3 (owner) |
| Understand internal, closed, open and production tracks | `docs/RELEASE_GUIDE.md` part 6 (owner) |
| Roll out to more players, or stop a bad update | `docs/RELEASE_GUIDE.md` part 8, and part 16 for the commands (owner) |
| Know what I can change without a new version (prices, products, listing) | `docs/RELEASE_GUIDE.md` part 9 (owner) |
| Check reviews, crashes and numbers after release | `docs/RELEASE_GUIDE.md` part 11 (owner) |
| Understand earnings, refunds and taxes | `docs/RELEASE_GUIDE.md` part 12 (owner) |
| Back up my keys and secret files | `docs/RELEASE_GUIDE.md` part 2 (owner). Do this before anything else. |
| Test on my phone or give the game to friends | `docs/RELEASE_GUIDE.md` part 13 (owner) |
| Move to a new Mac | `docs/RELEASE_GUIDE.md` part 14 (owner) |
| Fix a problem (upload refused, ads not showing, purchase fails) | `docs/FINAL_RELEASE_STEPS.md` "If something goes wrong", then `docs/RELEASE_GUIDE.md` part 15 (owner) |
| See which versions were released and when | `docs/RELEASE_HISTORY.md` (written by `tools/release.py`) |
| Ask an AI helper to change something | `docs/RELEASE_GUIDE.md` part 17 (owner); the helper itself reads `AGENTS.md` |

## Ads, purchases, analytics, notifications

| I want to... | Open |
|---|---|
| Add or change an in-app product, or test purchases | `docs/OWNER_SETUP_ADMOB_BILLING.md` parts 6 and 8 (owner) |
| Set regional prices | `docs/BILLING_SETUP.md` |
| Set up an AdMob test device or check ad units | `docs/OWNER_SETUP_ADMOB_BILLING.md` parts 3 and 7 (owner) |
| Understand where ads appear and why prices are what they are | `docs/MONETIZATION.md` |
| See what Firebase records (events, crashes) | `docs/FIREBASE_SETUP.md` |
| Change reminder notifications or their text | `docs/NOTIFICATIONS.md` |

## The game itself (for code changes)

| I want to... | Open |
|---|---|
| Rules, commands and folders for changing code | `AGENTS.md` (read first) |
| How the code fits together | `docs/ARCHITECTURE.md` |
| Engine, plugins and versions | `docs/TECH_STACK.md` |
| Game rules: heroes, materials, scoring | `docs/GAME_DESIGN.md` |
| Level list, realms and the level file format | `docs/LEVELS.md` |
| Signature features (Hellfire, bosses, contraptions...) | `docs/SIGNATURE_FEATURES.md` |
| Screens, HUD and icons | `docs/UI_DESIGN.md` |
| Art style and colours | `docs/ART_DIRECTION.md`; AI image prompts in `docs/AI_ART_PROMPTS.md` |
| Sound and music | `docs/AUDIO.md` |
| Where third-party assets came from and their licences | `docs/CREDITS.md` |
| The story and who the game is for | `docs/ABOUT.md` |
| What was planned and what is done | `docs/ROADMAP.md` |

## Older docs you can mostly ignore

| Doc | Why |
|---|---|
| `docs/PLAY_STORE.md` | Short early checklist. Replaced by `FINAL_RELEASE_STEPS.md` and `RELEASE_GUIDE.md` part 7. |
| `docs/OWNER_SETUP_ADMOB_BILLING.md` parts 1 to 5 and 9 | Already done (key, payments profile, AdMob, IDs, internal testing). Closed testing is now in `FINAL_RELEASE_STEPS.md` Step 3 and 4. |
| `docs/reference/PROTOTYPE_REFERENCE.md` | Notes from the old HTML version. History only. |
