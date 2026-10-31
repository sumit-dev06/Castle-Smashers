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
- **Permission**: Android 13+ asks once, about a second after the first home screen appears (`ask_on_home_delay_s`), before the daily reward popup. Android never asks at install; it is a runtime prompt. If that moment is missed, it asks after the next won level (`ask_after_level` 0).
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

## Push (FCM)
Local reminders cover everything the phone can predict from the save. Push is for messages it
can't know about: live events, a new realm going live, win-back campaigns to an Analytics
audience. It is built in and switches on with `google-services.json` (see `FIREBASE_SETUP.md`).

- Plugin: GodotX Firebase 3.1.0, Core + Messaging modules only (`addons/godotx_firebase`). We did
  not write our own FCM plugin: GodotX's module already handles the token, topics, the message
  service, cold-start taps and Android 13 permission, and it targets Godot 4.7.
- Code: `src/autoload/notifications_push.gd`, created by `Notifications` on Android. Firebase Core
  starts, then Messaging; the phone is subscribed to the topics in
  `data/notifications.json` → `push.topics` (`all_players`, `news`) **only while notifications are
  on in Settings and the Android permission is granted**, and unsubscribed when either goes off.
  No token is stored or sent anywhere; campaigns target topics from the Firebase console.
- Permission: still asked once by CastleNotify after level 3, never at startup. The GodotX
  `request_permission()` is not called.
- Look: the manifest points FCM at the white castle icon (`@mipmap/icon_monochrome`, from
  `assets/art/brand/app_icon_mono.png`) and the same "Siege reminders" channel, so one system
  switch covers both kinds.
- Tapping a push opens the game and logs `notification_opened` with `kind = push`.
- While the game is open, Android doesn't show the push and the game shows nothing either
  (no interruptions mid-level).
- Rules for campaigns: at most one a day, never 22:00–09:00 local, no fake urgency, no guilt.
  Use topic `news` for releases and events, `all_players` for important announcements only.
- Privacy: the FCM registration token is a device identifier. Data safety: "Device or other IDs",
  collected, not shared, purpose "App functionality".

## Testing
`--run-tests=billing` includes the notification planner: reminders are planned after the free
spin is used, never during quiet hours, at most one per day, placeholders filled, idle reminders
present, no spin/daily reminder while today's is still unclaimed, no repeated line, opt-out works.
On a phone: open the game, use the free spin, press Home; check `adb shell dumpsys alarm | grep castlesmashers`.
