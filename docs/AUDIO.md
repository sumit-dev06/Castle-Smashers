# Audio

All audio is synthesised by the project's Python tools (numpy + scipy), so it is owned and needs no
credits. `tools/audio_dsp.py` holds the shared DSP: additive plucked strings, mallets, bells, reeds,
brass, flute, string and pad sections, a drum kit, a convolution room reverb and seamless-loop helpers.

| Tool | Output |
|---|---|
| `tools/gen_music.py` | `assets/audio/music/<song>_base.wav`, `<song>_action.wav`, `sting_*.wav` (32 kHz) |
| `tools/gen_ambience.py` | `assets/audio/ambience/bed_<realm>.wav`, `amb_<detail>_<n>.wav` (32 kHz) |
| `tools/gen_sfx.py` | `assets/audio/sfx/<name>_<n>.wav` (44.1 kHz, variants) |

Godot imports every WAV as QOA. Loop points are written into a WAV `smpl` chunk, and `Sound._looped()`
also forces forward looping, so loops need no import settings.

## Runtime mix (`src/autoload/sound.gd`)
Buses: `Master` (glue compressor + hard limiter) ← `Music` (low-pass), `Ambience` (low-pass),
`SFX` (realm reverb), `UI` (dry). The music slider drives `Music`. The sound-effects slider drives
`SFX`, `UI` and `Ambience`, so turning music off still leaves the world's sounds.
All numbers are in `data/balance.json -> audio`.

### Adaptive music
Every song has two stems of identical length that start together and stay in sync:
- **base**: harmony, bass and the lead melody. It always plays.
- **action**: drums, ostinato and a melody double. Its level follows the music state.

| State | When | Action stem |
|---|---|---|
| `menu` / `map` | home, meta screens, map | off |
| `aim` | a hero is in the bucket | −18 dB, rises with destruction energy |
| `flight` | `Events.projectile_launched` | −7 dB |
| `destruction` | first impact or break after a launch | up to 0 dB |
| `result` | `Events.level_finished` | off, base −12 dB under the stinger |

Destruction energy rises on big impacts, broken blocks, defeated archers, explosions and chain
links. It holds for 2.5 s, then decays, so the drums swell with the carnage and settle back by
themselves. Explosions duck the music 5 dB and stingers duck it 12 dB, with a smooth release.
Changing song crossfades over 1.6 s.

| Song | Character |
|---|---|
| `menu` | Heroic C-major march: horn and flute lead, strings, pizzicato, snare |
| `blossom` | D yo-scale: koto and shakuhachi, harp arpeggios, taiko and woodblock |
| `desert` | D phrygian dominant: oud and flute over a reed drone, doum/tek frame drums, tambourine |
| `harbor` | D dorian 6/8 shanty: accordion, banjo, tuba bass, claps and tambourine |
| `mines` | A minor: marimba and celesta, low strings, toms and anvil hits |
| `sky` | F lydian: celesta and flute, harp, airy pad, light kit and bells |
| `boss` | E harmonic minor at 128 BPM: horn and string ostinato, taiko, brass stabs |

The world map plays the music and ambience of the realm in view and crossfades as you scroll.
The loadout screen starts the level's realm song so it carries straight into the level.
Stingers: `win`, `lose`, `boss_intro` (played by the boss reveal), `siege_start` (when control
starts on non-boss levels), `reward`.

### Surroundings
`Sound.set_surroundings(realm, menu)` crossfades a 24 s ambience bed and scatters detail one-shots
at random gaps, levels and pitches, so the bed never loops audibly. It also sets the SFX bus reverb
for the realm. Menus play the bed 5 dB lower, with one detail type only.

| Realm | Bed | Details | SFX reverb |
|---|---|---|---|
| Blossom Valley | breeze, leaves, distant stream, faint crickets | birds, dove | open garden |
| Desert Ruins | warm wind, whistling gusts, sand hiss | gusts, hawk | dry, long pre-delay |
| Pirate Harbor | swell and wash in 8 s waves, lapping water | gulls, rope creaks, ship bell | medium |
| Crystal Mines | cave room tone, low drone, rumble | water drips, lava bubbles, distant picks | big cave (wet 0.17) |
| Sky Islands | high wind, airy hiss | wind chimes, gusts, high birds | wide open |

Pause and long slow motion glide a low-pass over music and ambience: 750 Hz when paused, 1.5 kHz
in slow motion. Slow motion longer than 0.15 s also drops world SFX pitch toward the time scale.
Short hit-stops do not.

### SFX
Pools: 14 world voices, 4 UI voices, 3 ambience voices. A quiet sound never steals a loud impact.
Each sound has a cooldown and pitch variation from `audio.cooldown_ms` / `pitch_variation`. Names
in `audio.ui_sounds` go to the dry UI bus.

`gen_sfx.py` runs every sound through `polish()`: a 40 Hz rumble cut, an 8.5–9.5 kHz roll-off, a
short room by family (UI nearly dry; impacts 0.45 s; big sounds 0.9 s) and soft-knee saturation.
Then it masters to a per-sound RMS target and peak ceiling. Impacts have a low "body" layer and
rounded 1–3 ms attacks, which avoids the thin digital click the old set had.

| Action | Sound(s) |
|---|---|
| Grab the catapult / pull | `aim_grab`, `creak` (pitch follows power) |
| Launch / flight | `launch` (wood thunk, rope twang, air), `whoosh` |
| Hero ability | `ability` sparkle + the hero's own `slam` / `fire` / `explosion` / `wind` / `quake` |
| Wood, stone, ice, crystal, iron hit and break | `wood_*`, `stone_*`, `ice_*`, `crystal_break`, `metal_*`, `straw_break` |
| Chain reaction | `combo` rising a semitone per link, `star` on milestones, `slowmo` / `slowmo_out` |
| Mechanisms | `lever`, `gears`, `trapdoor`, `switch_click`, `chain`, `gate_drop`, `rope_snap`, `geyser` |
| Boss rig | `cannon`, `repair`, `boss_roar`, `metal_bend`, `rune_charge`, `rune_beam` |
| Units | `arrow_shoot`, `arrow_hit`, `soldier_hit`, `soldier_ko`, `enemy_ko`, `enemy_laugh` |
| Story dialogue | `talk_hero`, `talk_high` (wizard, captive), `talk_enemy`: gibberish cartoon voices |
| Buttons | `ui_tap`, `ui_back` (home), `tab` (side rail), `play_press` (PLAY plank) |
| Popups / screens | `popup_open`, `popup_close`, `screen_whoosh` |
| Locked / can't afford | `locked`, `deny`, `toast` |
| Rewards | `coin_tink`, `gem_tink`, `wallet_land`, `count_tick` (count-ups), `purchase`, `chest_open`, `reveal`, `upgrade`, `anvil`, `wheel_tick` |
| Map | `map_select`, `locked` |

## Checking the mix without listening
Run `$GODOT --path . -- --level=31 --autoshot=38,0.85,0.9 --record-audio=14` (debug builds). It
writes the Master output to `build/shots/audio.wav` so levels, peaks and spectrum can be measured.
`tests/run_tests.gd` (`_audio_tests`) checks that every `Sound.play` name in `src/` has a file,
that every song has synced looping stems, that stingers exist and that every realm has its
ambience. It also checks the event-driven state machine.

## Possible later work
- Recorded or licensed instruments for a final soundtrack (list them in `docs/CREDITS.md`).
- Stereo panning of world SFX by screen position.
