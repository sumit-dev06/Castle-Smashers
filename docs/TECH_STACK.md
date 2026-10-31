# Tech Stack

| Area | Choice | Notes |
|---|---|---|
| Engine | Godot 4.7 stable | Installed at `/Users/sumit/Downloads/Godot.app` |
| Language | GDScript, static typing | No C#: it adds .NET to the APK and complicates Android export |
| Renderer | Compatibility (OpenGL ES 3.0) | Widest Android support, best for 2D. Mobile (Vulkan) not needed |
| Physics | Godot Physics 2D | 60 Hz, 24 solver iterations, blocks start asleep. Stability test passes (drift < 2 px over 10 s awake), so Rapier is not needed for now |
| Resolution | 1280×720 base, `canvas_items` stretch, `expand` aspect | 20:9 phones see 1600×720; HUD anchors to screen edges |
| Data | JSON in `data/` | Levels, materials, projectiles, balance, store catalogue |
| Save | `user://save.json` via `Save` autoload | Versioned, written atomically (temp file + rename) |
| Ads | Google AdMob via Poing Studios `godot-admob-plugin` (Android) | Includes UMP consent. Check the release that matches Godot 4.7 when integrating |
| IAP | Official GodotGooglePlayBilling 3.3.0 (`addons/GodotGooglePlayBilling`) | Billing Library 9.1 |
| Analytics / crashes | Firebase Analytics + Crashlytics (+NDK) via our plugin CastleFirebase (`addons/castle_firebase`, source `tools/android_plugins/firebase`) | Off until `android/build/google-services.json` exists |
| Notifications | Local notifications via our plugin CastleNotify (`addons/castle_notify`, source `tools/android_plugins/notify`) | AlarmManager, no server |
| Intro video | Ogg Theora + WAV in `assets/intro`, captured from the studio HTML by `tools/capture_intro.py` (Playwright + Chrome + imageio-ffmpeg) | |
| Build | Gradle build, Android App Bundle (`.aab`) for Play, APK for local testing | Gradle build is required for plugins |
| Android | min SDK 24, target SDK 36, arm64-v8a + armeabi-v7a | Java 17, SDK at `~/Library/Android/sdk`, build-tools 36.1 |
| Fonts | Lilita One (titles), Fredoka (body) | SIL OFL, `assets/fonts/` |
| Art tools | Hand-written SVG (Godot imports natively), AI images from the owner's image tool, ImageMagick for cutouts/resizing | |
| Audio tools | Python + numpy generators in `tools/`, CC0 libraries | `.ogg` for music, `.wav` for short SFX |
| Android plugin build | `tools/android_plugins` Gradle project (AGP 8.6.1, Kotlin 2.1.21) | `cd tools/android_plugins && ./gradlew assembleRelease`, then copy the AARs into `addons/castle_*/bin/` |
| Testing | Headless Godot test scripts in `tests/`, USB phone via `adb` | |

## Versions on the dev machine (2026-10-29)
Godot 4.7.stable.official.5b4e0cb0f · export templates 4.7.stable · Java 17.0.3 ·
Android build-tools 34–36.1, platforms 29–36.1, NDK 28.2 · Python 3 + numpy 2.5 · ImageMagick 7.
