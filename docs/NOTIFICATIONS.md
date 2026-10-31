# Notifications

## What popular habit-forming apps do (and what we copy)
- **Duolingo**: one reminder a day at the time the user usually plays, a mascot voice, many
  rotating lines so it never repeats, and it **backs off** (then stops) when ignored.
- **Zomato / Swiggy**: short, cheeky, very specific copy ("your cart is feeling lonely"), sent at
  meal times, a joke in the title, the real message in the body.
- **Clash of Clans / Royal Match**: event-driven reminders ("your builder is free", "lives are
  full") that point at something real and ready right now. No "come back" spam.
- Shared rules: a hard daily cap, quiet hours, never a fake reward, easy to turn off, and the
  Android 13 permission asked only after the player enjoys the app (asking on first launch gets
  far more "Don't allow").

## Our rules (`data/notifications.json`, `src/autoload/notifications.gd`)
- **Local notifications only**, scheduled on the phone with AlarmManager by our small plugin
  **CastleNotify** (`addons/castle_notify`, source `tools/android_plugins/notify`). They fire
  even when the game is closed. No server, no account, no extra data collected.
- Everything is scheduled when the game goes to the background and **cancelled when the player
  opens the game**, so nothing fires while playing and stale reminders never pile up.
- **At most 1 per day** (`max_per_day`). If two land on the same day the higher priority wins.
- **Quiet hours 22:00-09:00** local time (`quiet_start_hour`, `quiet_end_hour`): a reminder that
  would land there moves to 09:00.
- **Permission**: Android 13+ asks once, after the player wins level 3 (`ask_after_level`).
- **Opt-out**: Settings → Reminders, plus the Android notification channel "Siege reminders".
- Reminders only point at real things: a free spin that is really ready, a daily chest that is
  really waiting, a chest that is really 3 stars away. No purchase pushes.
- Idle reminders stop after day 10: one gentle last line, then silence. Back-off is built in
  because each later idle reminder only exists if the earlier ones were ignored (opening the
  game cancels and restarts the chain).
- Lines rotate and never repeat back to back.

## Triggers
| Kind | When | Condition | Priority |
|---|---|---|---|
| `spin_ready` | Next day 18:00 | Today's free spin was used | 1 |
| `daily_reward` | Next day 12:00 | Today's daily reward was claimed | 2 |
| `special_unlocked` | +20 h | Master Sieges just unlocked (25 stars) and not seen | 3 |
| `chest_almost` | +30 h | The current realm chest is 1-3 stars away | 4 |
| `update` | +3 h after first launch of a new version | Version changed | 6 |
| `idle_2d` / `idle_5d` / `idle_10d` | 2 / 5 / 10 days after last play | Always (cancelled by playing) | 7-9 |

## Sample copy (all lines are in `data/notifications.json`)
- **The wheel is spinning itself out of boredom**: "Your free spin is back. Master Orin swears he did not oil it for you."
- **Rocky misses you**: "He has been staring at the catapult for two days. It is getting weird. Level 14 awaits."
- **The Iron Baron is giving speeches now**: "Five days without a siege and he thinks he won. Prove him wrong on level 14."
- **The Vanguard took up knitting**: "Five days off. They made a scarf for the catapult. Please send them back to work."
- **Patch notes, but louder**: "The update is in. New things to break. You know what to do."

Placeholders: `{level}`, `{realm}`, `{boss}`, `{coins}`, `{streak_next}`, `{stars_short}`.
Add lines freely; keep them short (title ≤ 45 characters, body ≤ 110), specific to the game, and
never guilt-tripping.

## Is push (FCM) necessary?
**No, not for launch.** Every reminder above is predictable from the save, so local
notifications cover them with zero server cost and zero extra data. Push is only needed for
messages the phone can't know about: live events, a new realm going live on a fixed date, or
win-back campaigns targeted by Analytics audiences. Recommendation: launch without push; add FCM
when you run live events.

How to add push later (owner steps, after Firebase is set up per `FIREBASE_SETUP.md`):
1. Add `com.google.firebase:firebase-messaging` to `tools/android_plugins/firebase/build.gradle`
   and `addons/castle_firebase/export_plugin.gd`, and a `FirebaseMessagingService` that shows the
   message on the existing "Siege reminders" channel.
2. Firebase console → **Messaging** → create campaign → target the app or an Analytics audience
   (for example "played in last 30 days, not in last 7"). Respect the same quiet hours and cap.
3. Update the privacy policy and Data safety form (FCM token = device identifier).

## Testing
`--run-tests=billing` includes the notification planner: reminders are planned after the free
spin is used, never during quiet hours, at most one per day, placeholders filled, idle reminders
present, no spin/daily reminder while today's is still unclaimed, no repeated line, opt-out works.
On a phone: open the game, use the free spin, press Home; check `adb shell dumpsys alarm | grep castlesmashers`.
