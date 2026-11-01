#!/usr/bin/env python3
"""Stone Storm release tool: check, version, test, build, verify, upload, roll out.

Owner manual: docs/RELEASE_GUIDE.md. Every command prints what it did and ends with OK or FAILED.

    python3 tools/release.py check                     # is everything ready for a release build?
    python3 tools/release.py version [--name 1.0.0]    # +1 version code, new version name
    python3 tools/release.py test                      # import + all automated tests
    python3 tools/release.py aab                       # signed release bundle for Google Play (+ verify)
    python3 tools/release.py apk                       # debug APK with test ads (friends, not Play)
    python3 tools/release.py verify                    # re-check build/stone_storm.aab
    python3 tools/release.py upload --track internal --notes "Bug fixes"   # send the AAB to Play
    python3 tools/release.py status                    # what is on each Play track
    python3 tools/release.py promote --from internal --to production --rollout 0.2 --confirm
    python3 tools/release.py rollout --track production --fraction 1.0 --confirm
    python3 tools/release.py halt --track production --confirm
    python3 tools/release.py release --track internal --notes "New levels"  # all steps in a row
    python3 tools/release.py phone                     # what is installed on the USB phone
    python3 tools/release.py logs                      # game log from the USB phone (Ctrl+C to stop)
    python3 tools/release.py backup-secrets --to /Volumes/USB   # zip of keys and config files
    python3 tools/release.py web                       # deploy the website + privacy policy

Nothing here deletes data, uninstalls the game or touches the phone's install.
"""
import argparse
import datetime
import filecmp
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "/Users/sumit/Downloads/Godot.app/Contents/MacOS/Godot")
SDK = os.path.expanduser(os.environ.get("ANDROID_HOME", "~/Library/Android/sdk"))
ADB = os.path.join(SDK, "platform-tools", "adb")
PACKAGE = "com.castlesmashers.game"
PRESET = os.path.join(ROOT, "export_presets.cfg")
PROJECT = os.path.join(ROOT, "project.godot")
CREDS = os.path.join(ROOT, ".godot", "export_credentials.cfg")
AD_IDS = os.path.join(ROOT, "ad_ids.cfg")
GS_ROOT = os.path.join(ROOT, "google-services.json")
GS_BUILD = os.path.join(ROOT, "android", "build", "google-services.json")
# Stone Storm builds use their own names: build/stone_storm.aab (1.0.0) is never overwritten.
AAB = os.path.join(ROOT, "build", "stone_storm.aab")
APK = os.path.join(ROOT, "build", "stone_storm_debug.apk")
LOGS = os.path.join(ROOT, "build", "tmp")
HISTORY = os.path.join(ROOT, "docs", "RELEASE_HISTORY.md")
ARCHIVE = os.path.expanduser(os.environ.get("CASTLE_RELEASES", "~/Documents/Castle Smashers Releases"))
SECRETS = os.path.expanduser(os.environ.get("CASTLE_SECRETS", "~/.castle_secrets"))
SERVICE_ACCOUNT = os.environ.get("PLAY_SERVICE_ACCOUNT", os.path.join(SECRETS, "play-service-account.json"))
TEST_PUBLISHER = "3940256099942544"  # Google's public test ads account
EXPECTED_SIGNER = "CN=Intercore"
TRACKS = {"internal": "internal", "closed": "alpha", "alpha": "alpha", "open": "beta", "beta": "beta",
          "production": "production"}
NOTES_MAX = 500  # Play limit per language


# ------------------------------------------------------------------------------------ printing
class Report:
    def __init__(self, title):
        self.title = title
        self.failed = 0
        self.warned = 0
        print(f"\n=== {title} ===")

    def ok(self, msg):
        print(f"  [ OK ] {msg}")

    def warn(self, msg):
        self.warned += 1
        print(f"  [WARN] {msg}")

    def fail(self, msg):
        self.failed += 1
        print(f"  [FAIL] {msg}")

    def check(self, cond, good, bad, warn_only=False):
        if cond:
            self.ok(good)
        elif warn_only:
            self.warn(bad)
        else:
            self.fail(bad)
        return cond

    def end(self):
        if self.failed:
            print(f"=== {self.title}: FAILED ({self.failed} problem(s)) ===")
            return False
        extra = f" with {self.warned} warning(s)" if self.warned else ""
        print(f"=== {self.title}: OK{extra} ===")
        return True


def die(msg):
    print(f"  [FAIL] {msg}")
    print("=== FAILED ===")
    sys.exit(1)


def run(cmd, log=None, timeout=None, env=None):
    """Runs a command. Returns (exit code, output). Output also goes to `log` if given."""
    try:
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout, env=env)
        out = (p.stdout or "") + (p.stderr or "")
        code = p.returncode
    except subprocess.TimeoutExpired as e:
        out = str(e.stdout or "") + "\nTIMEOUT"
        code = 124
    except FileNotFoundError as e:
        out, code = str(e), 127
    if log:
        os.makedirs(os.path.dirname(log), exist_ok=True)
        with open(log, "w") as fh:
            fh.write(out)
    return code, out


# ------------------------------------------------------------------------------------ files
def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def preset_value(key):
    m = re.search(r"^" + re.escape(key) + r"=(.*)$", read(PRESET), re.M)
    return m.group(1).strip().strip('"') if m else None


def set_preset_value(key, value, quoted):
    s = read(PRESET)
    line = f'{key}="{value}"' if quoted else f"{key}={value}"
    new, n = re.subn(r"^" + re.escape(key) + r"=.*$", line, s, count=1, flags=re.M)
    if n != 1:
        die(f"{key} not found in export_presets.cfg")
    write(PRESET, new)


def version():
    return int(preset_value("version/code") or 0), preset_value("version/name") or ""


def project_version():
    m = re.search(r'^config/version="([^"]*)"', read(PROJECT), re.M)
    return m.group(1) if m else ""


def set_project_version(name):
    s = read(PROJECT)
    new, n = re.subn(r'^config/version="[^"]*"', f'config/version="{name}"', s, count=1, flags=re.M)
    if n != 1:
        die("config/version not found in project.godot")
    write(PROJECT, new)


def admob_app_id():
    m = re.search(r'^general/android/app_id="([^"]*)"', read(PROJECT), re.M)
    return m.group(1) if m else ""


def credentials():
    """(keystore path, alias, password) for the release key from Godot's git-ignored credentials file."""
    if not os.path.exists(CREDS):
        return None, None, None
    s = read(CREDS)
    def get(k):
        m = re.search(r"^keystore/" + k + r'="(.*)"$', s, re.M)
        return m.group(1).replace('\\"', '"').replace("\\\\", "\\") if m else ""
    return get("release"), get("release_user"), get("release_password")


def ad_ids(text):
    return dict(re.findall(r'^(interstitial|rewarded)="([^"]*)"', text, re.M))


def history_codes():
    if not os.path.exists(HISTORY):
        return []
    return [int(c) for c in re.findall(r"^\|\s*[\d-]+ [\d:]+\s*\|\s*(\d+)\s*\|", read(HISTORY), re.M)]


def add_history(code, name, track, what, notes):
    if not os.path.exists(HISTORY):
        write(HISTORY, "# Release history\n\nWritten by `tools/release.py` after every upload, promote, rollout\n"
              "and halt. Version codes must always go up; the next upload needs a code above the\n"
              "highest one here.\n\n| Date | Code | Name | Track | What | Notes |\n|---|---|---|---|---|---|\n")
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    clean = notes.replace("|", "/").replace("\n", " ")[:120]
    with open(HISTORY, "a", encoding="utf-8") as fh:
        fh.write(f"| {stamp} | {code} | {name} | {track} | {what} | {clean} |\n")


def build_tool(name):
    tools = sorted(glob.glob(os.path.join(SDK, "build-tools", "*", name)))
    return tools[-1] if tools else None


def git(*args):
    return run(["git", *args])


# ------------------------------------------------------------------------------------ check
def cmd_check(_a=None):
    r = Report("Release check")
    r.check(os.path.exists(GODOT), f"Godot found ({GODOT})", f"Godot not found at {GODOT}. Set GODOT=/path/to/Godot")
    r.check(os.path.exists(ADB), "Android SDK found", f"Android SDK not found at {SDK}. Set ANDROID_HOME")
    tpl = os.path.join(ROOT, "android", "build")
    if r.check(os.path.isdir(tpl), "Android build template installed", "android/build missing: open Godot > Project > Install Android Build Template, then run python3 tools/patch_android_template.py"):
        man = read(os.path.join(tpl, "src", "main", "AndroidManifest.xml"))
        r.check("cs_data_rules" in man, "template patched (backup rules)", "run: python3 tools/patch_android_template.py")
        r.check("only when google-services.json" in read(os.path.join(tpl, "build.gradle")), "template patched (Firebase)", "run: python3 tools/patch_android_template.py")
    # Signing key
    ks, alias, pw = credentials()
    if r.check(ks is not None, "Godot export credentials found", "no .godot/export_credentials.cfg: set the release keystore in Godot > Project > Export > Android (docs/RELEASE_GUIDE.md part 2)"):
        if r.check(bool(ks) and os.path.exists(ks), f"upload keystore found ({ks})", f"keystore file not found: '{ks}'"):
            r.check(alias == "upload", "key alias is 'upload'", f"key alias is '{alias}', expected 'upload'", warn_only=True)
            env = dict(os.environ, CS_KS_PW=pw or "")
            code, out = run(["keytool", "-list", "-keystore", ks, "-alias", alias or "upload", "-storepass:env", "CS_KS_PW"], env=env)
            r.check(code == 0, "keystore password works", "keystore password or alias is wrong (Godot > Export > Android > Keystore)")
    # Ads
    app_id = admob_app_id()
    r.check(app_id.startswith("ca-app-pub-") and "~" in app_id and TEST_PUBLISHER not in app_id,
            f"real AdMob App ID in project.godot ({app_id})", f"AdMob App ID missing or a test ID: '{app_id}'")
    if r.check(os.path.exists(AD_IDS), "ad_ids.cfg found", "ad_ids.cfg missing: release builds would show test ads (part 4 of the guide)"):
        ids = ad_ids(read(AD_IDS))
        for k in ("interstitial", "rewarded"):
            v = ids.get(k, "")
            r.check(re.fullmatch(r"ca-app-pub-\d+/\d+", v or "") is not None and TEST_PUBLISHER not in v,
                    f"real {k} ad unit ({v})", f"{k} ad unit missing or a test unit: '{v}'")
        pub = app_id.split("~")[0]
        r.check(all(v.startswith(pub + "/") for v in ids.values()), "ad units belong to the same AdMob account as the App ID",
                "ad unit IDs and App ID are from different AdMob accounts")
    # Firebase
    if r.check(os.path.exists(GS_ROOT), "google-services.json found", "google-services.json missing (Firebase console > Project settings > Your apps)", warn_only=True):
        pk = [c["client_info"]["android_client_info"]["package_name"] for c in json.load(open(GS_ROOT))["client"]]
        r.check(PACKAGE in pk, "google-services.json is for " + PACKAGE, f"google-services.json is for {pk}")
        r.check(os.path.exists(GS_BUILD) and filecmp.cmp(GS_ROOT, GS_BUILD, shallow=False),
                "android/build/google-services.json is the same file", f"copy it: cp google-services.json {GS_BUILD}")
    # Version and settings
    code, name = version()
    r.check(code > 0 and re.fullmatch(r"\d+\.\d+\.\d+", name or "") is not None, f"version {name} (code {code})", f"bad version: name '{name}', code {code}")
    r.check(project_version() == name, "project.godot version matches", f"project.godot config/version is '{project_version()}' but export is '{name}': run python3 tools/release.py version --keep-code --name {name}")
    done = history_codes()
    if done:
        r.check(code > max(done), f"version code {code} is above the last upload ({max(done)})",
                f"version code {code} was already used (last upload {max(done)}): run python3 tools/release.py version")
    r.check(preset_value("package/unique_name") == PACKAGE, "package name " + PACKAGE, "package name changed! It must stay " + PACKAGE)
    r.check(preset_value("user_data_backup/allow") == "true", "Android backup of the save file is on", "user_data_backup/allow is not true", warn_only=True)
    r.check(preset_value("gradle_build/export_format") == "0", "export preset is in its normal (APK) state", "gradle_build/export_format is not 0: a build was interrupted; set it back to 0")
    # Upload access (only needed for upload/status/promote)
    r.check(os.path.exists(SERVICE_ACCOUNT), "Play upload key found (service account)",
            f"no {SERVICE_ACCOUNT}: upload/status/promote won't work until you do part 3 of the guide (manual upload still works)", warn_only=True)
    c, out = git("status", "--porcelain")
    changed = [l for l in out.splitlines() if l.strip()]
    r.check(not changed, "git: everything committed", f"git: {len(changed)} uncommitted file(s) (fine while working; commit before a release)", warn_only=True)
    return r.end()


# ------------------------------------------------------------------------------------ version
def cmd_version(a):
    r = Report("Version")
    code, name = version()
    new_code = code if a.keep_code else (a.code if a.code else code + 1)
    if a.name:
        new_name = a.name
    else:
        parts = [int(x) for x in (name if re.fullmatch(r"\d+\.\d+\.\d+", name or "") else "0.0.0").split(".")]
        parts[2] += 1
        new_name = ".".join(map(str, parts))
    if not re.fullmatch(r"\d+\.\d+\.\d+", new_name):
        die(f"version name must look like 1.2.3, got '{new_name}'")
    done = history_codes()
    if done and new_code <= max(done):
        die(f"version code {new_code} is not above the last upload ({max(done)})")
    if new_code < code:
        die(f"version code can only go up ({code} -> {new_code})")
    set_preset_value("version/code", new_code, quoted=False)
    set_preset_value("version/name", new_name, quoted=True)
    set_project_version(new_name)
    r.ok(f"{name} (code {code})  ->  {new_name} (code {new_code})")
    r.ok("written to export_presets.cfg and project.godot")
    return r.end()


# ------------------------------------------------------------------------------------ test
def cmd_test(_a=None):
    r = Report("Tests")
    print("  import... (1-2 min)")
    code, out = run([GODOT, "--headless", "--path", ".", "--import"], log=os.path.join(LOGS, "import.log"), timeout=1200)
    bad = [l for l in out.splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
    r.check(not bad, "import clean", "import errors:\n      " + "\n      ".join(bad[:5]))
    print("  tests... (5-15 min)")
    code, out = run([GODOT, "--headless", "--path", ".", "--", "--run-tests"], log=os.path.join(LOGS, "tests.log"), timeout=3000)
    fails = [l.strip() for l in out.splitlines() if re.match(r"^\s+FAIL", l) or "SCRIPT ERROR" in l]
    passed = "TESTS PASSED" in out
    r.check(passed and not fails, "all tests passed", "tests failed (full log: build/tmp/tests.log):\n      " + "\n      ".join(fails[:10] or [out[-300:]]))
    return r.end()


# ------------------------------------------------------------------------------------ build
def export(kind, out_path):
    """kind: 'release' (AAB) or 'debug' (APK)."""
    if not os.path.exists(GODOT):
        die("Godot not found")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    if os.path.exists(out_path):
        os.remove(out_path)
    backup = os.path.join(LOGS, "export_presets.bak")
    os.makedirs(LOGS, exist_ok=True)
    shutil.copy(PRESET, backup)
    try:
        if kind == "release":
            set_preset_value("gradle_build/export_format", 1, quoted=False)  # 1 = Android App Bundle
        flag = "--export-release" if kind == "release" else "--export-debug"
        print(f"  building {os.path.basename(out_path)}... (3-8 min)")
        code, out = run([GODOT, "--headless", "--path", ".", flag, "Android", out_path],
                        log=os.path.join(LOGS, f"export_{kind}.log"), timeout=2400)
    finally:
        shutil.copy(backup, PRESET)  # always back to the normal APK setting
    if not os.path.exists(out_path):
        errs = [l for l in out.splitlines() if "ERROR" in l or "FAILED" in l or "error:" in l][:8]
        die(f"build failed, see build/tmp/export_{kind}.log\n      " + "\n      ".join(errs))
    return out_path


def proto_manifest_text(aab):
    """Readable manifest of the AAB's base module (via aapt2 convert), or None."""
    aapt2 = build_tool("aapt2")
    if not aapt2:
        return None
    tmp = tempfile.mkdtemp()
    proto = os.path.join(tmp, "proto.apk")
    with zipfile.ZipFile(aab) as z, zipfile.ZipFile(proto, "w") as out:
        for n in z.namelist():
            if not n.startswith("base/"):
                continue
            rel = n[5:]
            if rel == "manifest/AndroidManifest.xml":
                rel = "AndroidManifest.xml"
            elif not (rel == "resources.pb" or rel.startswith("res/")):
                continue
            out.writestr(rel, z.read(n))
    conv = os.path.join(tmp, "bin.apk")
    code, _ = run([aapt2, "convert", "--output-format", "binary", "-o", conv, proto])
    if code != 0:
        return None
    code, text = run([aapt2, "dump", "xmltree", "--file", "AndroidManifest.xml", conv])
    shutil.rmtree(tmp, ignore_errors=True)
    return text if code == 0 else None


def is_true(xmltree, attr):
    """aapt2 prints booleans as =true or =(type 0x12)0xffffffff."""
    return re.search(attr + r"\([^)]*\)=(\(type 0x12\))?(true|0xffffffff|-1)\b", xmltree) is not None


def cert_sha256(args, env=None):
    code, out = run(["keytool", *args], env=env)
    m = re.search(r"SHA256:\s*([0-9A-F:]+)", out)
    return m.group(1) if m else None, out


def cmd_verify(_a=None, path=AAB):
    r = Report("Verify release bundle")
    if not os.path.exists(path):
        die(f"{path} not found: run python3 tools/release.py aab")
    size = os.path.getsize(path) / 1e6
    r.check(size < 200, f"size {size:.0f} MB (Play limit 200 MB for the base download)", f"size {size:.0f} MB is over Play's 200 MB limit")
    code, out = run(["jarsigner", "-verify", path])
    r.check("jar verified" in out, "signature valid", "signature check failed:\n" + out[-300:])
    aab_sha, out = cert_sha256(["-printcert", "-jarfile", path])
    r.check(EXPECTED_SIGNER in out, f"signed by {EXPECTED_SIGNER} (your upload key)", "signed by someone else:\n" + out[:300])
    ks, alias, pw = credentials()
    if ks and os.path.exists(ks):
        key_sha, _ = cert_sha256(["-list", "-v", "-keystore", ks, "-alias", alias, "-storepass:env", "CS_KS_PW"], env=dict(os.environ, CS_KS_PW=pw))
        r.check(aab_sha and aab_sha == key_sha, "certificate matches ~/castle_upload.keystore", "certificate does not match your upload keystore")
    code_v, name_v = version()
    man = proto_manifest_text(path)
    with zipfile.ZipFile(path) as z:
        raw = z.read("base/manifest/AndroidManifest.xml").decode("latin1")
        names = z.namelist()
        res = z.read("base/resources.pb").decode("latin1") if "base/resources.pb" in names else ""
        ids_txt = z.read("assetPackInstallTime/assets/ad_ids.cfg").decode() if "assetPackInstallTime/assets/ad_ids.cfg" in names else ""
    text = man or raw
    if man:
        m = re.search(r'versionCode.*?=(\d+)', man)
        vc = int(m.group(1)) if m else -1
        r.check(vc == code_v, f"version code {vc}", f"version code in bundle is {vc}, export_presets.cfg says {code_v}")
        r.check(f'"{name_v}"' in man, f"version name {name_v}", f"version name {name_v} not found in the bundle")
        r.check(not is_true(man, "debuggable"), "not debuggable", "bundle is debuggable (debug build?)")
        r.check(is_true(man, "allowBackup") and "dataExtractionRules" in man,
                "Android backup on (save file only)", "backup is off or the rules are missing", warn_only=True)
    else:
        r.warn("aapt2 not found: version checked by text only")
        r.check(name_v in raw, f"version name {name_v}", f"version name {name_v} not found")
    r.check(PACKAGE in text, "package " + PACKAGE, "wrong package name")
    r.check("com.android.vending.BILLING" in text, "billing permission", "billing permission missing")
    r.check("POST_NOTIFICATIONS" in text, "notification permission", "notification permission missing")
    app_id = admob_app_id()
    r.check(app_id and app_id in text and TEST_PUBLISHER not in app_id, "real AdMob App ID", "AdMob App ID missing or test")
    if man:
        # aapt2 prints each element as "E: activity" followed by its "A:" attributes; behind = 3
        # (follows the game's sensorLandscape; a fixed value would crash Android 8.0).
        blocks = [b for b in re.split(r"\n\s*E: ", man) if b.startswith("activity") and "ProxyBillingActivity" in b]
        locked = blocks and all(re.search(r"screenOrientation\([^)]*\)=3\b", b) for b in blocks)
    else:
        locked = text.count("ProxyBillingActivity") >= 2 and "behind" in text
    r.check(bool(locked), "payment screen follows the game (landscape)", "billing landscape lock missing (addons/castle_notify)")
    ids = ad_ids(ids_txt)
    r.check(len(ids) == 2 and all(TEST_PUBLISHER not in v and v.startswith("ca-app-pub-") for v in ids.values()),
            "real ad units inside the bundle", "real ad unit IDs missing from the bundle (ad_ids.cfg) - players would see test ads")
    r.check("google_app_id" in res, "Firebase config inside", "Firebase config missing (google-services.json)", warn_only=True)
    return r.end()


def cmd_aab(a=None):
    if not cmd_check():
        die("fix the problems above first")
    r = Report("Release bundle (AAB)")
    export("release", AAB)
    r.ok(f"built {os.path.relpath(AAB, ROOT)}")
    r.end()
    if not cmd_verify():
        return False
    # Keep every verified bundle: build/ is overwritten by the next build.
    code, name = version()
    os.makedirs(ARCHIVE, exist_ok=True)
    keep = os.path.join(ARCHIVE, f"stone_storm_{name}_code{code}.aab")
    shutil.copy(AAB, keep)
    print(f"  [ OK ] copy kept: {keep}")
    return True


def cmd_apk(a=None):
    r = Report("Debug APK (test ads, for friends)")
    export("debug", APK)
    aapt2 = build_tool("aapt2")
    if aapt2:
        _, out = run([aapt2, "dump", "badging", APK])
        m = re.search(r"versionCode='(\d+)' versionName='([^']*)'", out)
        r.check(m is not None, f"version {m.group(2)} (code {m.group(1)})" if m else "", "could not read the APK version")
        r.check("application-debuggable" in out, "debug build: uses Google TEST ads", "not a debug build")
    r.ok(f"{os.path.relpath(APK, ROOT)} ({os.path.getsize(APK) / 1e6:.0f} MB). Share it with friends who are not testers.")
    r.ok("It cannot be installed over the Play version (different signature). Purchases don't work in it.")
    return r.end()


# ------------------------------------------------------------------------------------ Play API
def play():
    if not os.path.exists(SERVICE_ACCOUNT):
        die(f"Play upload key not found: {SERVICE_ACCOUNT}\n      Do part 3 of docs/RELEASE_GUIDE.md, or upload build/stone_storm.aab by hand in Play Console.")
    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
    except ImportError:
        die("missing Python libraries: pip3 install google-api-python-client google-auth")
    creds = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def http_error_text(e):
    try:
        return json.loads(e.content.decode()).get("error", {}).get("message", str(e))
    except Exception:
        return str(e)


def commit_edit(svc, edit_id):
    from googleapiclient.errors import HttpError
    try:
        svc.edits().commit(packageName=PACKAGE, editId=edit_id).execute()
        return "sent"
    except HttpError as e:
        msg = http_error_text(e)
        if "changesNotSentForReview" in msg:
            svc.edits().commit(packageName=PACKAGE, editId=edit_id, changesNotSentForReview=True).execute()
            return "saved, NOT sent for review: open Play Console > Publishing overview > Send for review"
        raise


def release_body(code, notes, fraction, draft, priority=0):
    body = {"versionCodes": [str(code)], "releaseNotes": [{"language": "en-US", "text": notes}],
            "inAppUpdatePriority": int(priority)}
    if draft:
        body["status"] = "draft"
    elif fraction < 1.0:
        body["status"] = "inProgress"
        body["userFraction"] = fraction
    else:
        body["status"] = "completed"
    return body


def check_track_args(a, track_key="track"):
    t = getattr(a, track_key)
    if t not in TRACKS:
        die(f"unknown track '{t}'. Use one of: internal, closed, open, production")
    if TRACKS[t] == "production" and not a.confirm:
        die("production changes need --confirm (this reaches real players)")
    if hasattr(a, "rollout") and a.rollout is not None and not (0.0 < a.rollout <= 1.0):
        die("--rollout must be between 0.01 and 1.0 (for example 0.2 = 20% of players)")
    return TRACKS[t]


def notes_ok(notes):
    if len(notes) > NOTES_MAX:
        die(f"release notes are {len(notes)} characters, Play allows {NOTES_MAX}")
    return notes


def cmd_upload(a):
    track = check_track_args(a)
    notes = notes_ok(a.notes or "Bug fixes and improvements.")
    code, name = version()
    fraction = a.rollout if a.rollout else 1.0
    if not cmd_verify():
        die("the bundle did not pass verification")
    done = history_codes()
    if done and code <= max(done):
        die(f"version code {code} was already uploaded: run python3 tools/release.py version, then aab")
    r = Report(f"Upload {name} (code {code}) to {track}")
    if a.dry_run:
        r.ok(f"dry run: would upload {os.path.relpath(AAB, ROOT)} to '{track}' at {fraction:.0%}, update priority {a.priority}, notes: {notes}")
        r.check(os.path.exists(SERVICE_ACCOUNT), "Play upload key present", f"Play upload key missing: {SERVICE_ACCOUNT}", warn_only=True)
        return r.end()
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaFileUpload
    svc = play()
    try:
        edit_id = svc.edits().insert(packageName=PACKAGE, body={}).execute()["id"]
        media = MediaFileUpload(AAB, mimetype="application/octet-stream", resumable=True, chunksize=16 * 1024 * 1024)
        req = svc.edits().bundles().upload(packageName=PACKAGE, editId=edit_id, media_body=media)
        resp = None
        while resp is None:
            status, resp = req.next_chunk(num_retries=5)
            if status:
                print(f"  uploading... {int(status.progress() * 100)}%")
        r.ok(f"bundle uploaded (version code {resp.get('versionCode')})")
        draft = a.draft
        for attempt in (1, 2):
            try:
                svc.edits().tracks().update(packageName=PACKAGE, editId=edit_id, track=track,
                                            body={"track": track, "releases": with_live(svc, edit_id, track, release_body(code, notes, fraction, draft, a.priority))}).execute()
                break
            except HttpError as e:
                if attempt == 1 and "draft" in http_error_text(e).lower() and not draft:
                    draft = True  # app never published on this track yet: Play only accepts drafts
                    r.warn("Play only accepts a draft here; saving as draft")
                    continue
                raise
        result = commit_edit(svc, edit_id)
        r.ok(f"release on '{track}': {result}")
        if draft:
            r.warn("saved as DRAFT: Play Console > Test and release > this track > Edit release > Review > Start rollout")
        add_history(code, name, track, f"upload {'draft' if draft else f'{fraction:.0%}'}", notes)
        r.ok("recorded in docs/RELEASE_HISTORY.md")
    except HttpError as e:
        r.fail("Play said: " + http_error_text(e))
    return r.end()


def track_releases(svc, edit_id, track):
    from googleapiclient.errors import HttpError
    try:
        return svc.edits().tracks().get(packageName=PACKAGE, editId=edit_id, track=track).execute().get("releases", [])
    except HttpError:
        return []


def cmd_status(_a=None):
    r = Report("Google Play tracks")
    svc = play()
    edit_id = svc.edits().insert(packageName=PACKAGE, body={}).execute()["id"]
    for t in ("internal", "alpha", "beta", "production"):
        rel = track_releases(svc, edit_id, t)
        label = {"alpha": "closed (alpha)", "beta": "open (beta)"}.get(t, t)
        if not rel:
            print(f"  {label:16s} empty")
        for x in rel:
            frac = f" {x['userFraction']:.0%}" if "userFraction" in x else ""
            print(f"  {label:16s} codes {','.join(x.get('versionCodes', []))}  {x.get('name', '')}  {x.get('status')}{frac}")
    svc.edits().delete(packageName=PACKAGE, editId=edit_id).execute()
    return r.end()


def with_live(svc, edit_id, track, new):
    """Release list for a track update. A staged (inProgress) release keeps the current completed
    release live for everyone else; a completed one replaces it."""
    if new.get("status") != "inProgress":
        return [new]
    keep = [x for x in track_releases(svc, edit_id, track) if x.get("status") == "completed"]
    return [new] + keep[:1]


def latest(rel):
    live = [x for x in rel if x.get("versionCodes") and x.get("status") in ("completed", "inProgress", "draft")]
    return max(live, key=lambda x: max(int(c) for c in x["versionCodes"])) if live else None


def cmd_promote(a):
    src = check_track_args(a, "from_track")
    a.track = a.to_track
    dst = check_track_args(a, "to_track")
    fraction = a.rollout if a.rollout else 1.0
    r = Report(f"Promote {src} -> {dst}")
    from googleapiclient.errors import HttpError
    svc = play()
    try:
        edit_id = svc.edits().insert(packageName=PACKAGE, body={}).execute()["id"]
        rel = latest(track_releases(svc, edit_id, src))
        if not rel:
            die(f"nothing on '{src}' to promote")
        code = max(int(c) for c in rel["versionCodes"])
        notes = notes_ok(a.notes or next((n["text"] for n in rel.get("releaseNotes", []) if n.get("language") == "en-US"), "Bug fixes and improvements."))
        svc.edits().tracks().update(packageName=PACKAGE, editId=edit_id, track=dst,
                                    body={"track": dst, "releases": with_live(svc, edit_id, dst, release_body(code, notes, fraction, a.draft, a.priority))}).execute()
        r.ok(f"code {code} on '{dst}' at {fraction:.0%}: {commit_edit(svc, edit_id)}")
        add_history(code, rel.get("name", ""), dst, f"promote from {src} {fraction:.0%}", notes)
    except HttpError as e:
        r.fail("Play said: " + http_error_text(e))
    return r.end()


def change_rollout(a, status):
    track = check_track_args(a)
    r = Report(f"{'Halt' if status == 'halted' else 'Rollout'} on {track}")
    from googleapiclient.errors import HttpError
    svc = play()
    try:
        edit_id = svc.edits().insert(packageName=PACKAGE, body={}).execute()["id"]
        rels = track_releases(svc, edit_id, track)
        rel = next((x for x in rels if x.get("status") in ("inProgress", "halted")), None) \
            or next((x for x in rels if x.get("status") == "completed"), None)
        if not rel:
            die(f"no release on '{track}'")
        others = [x for x in rels if x is not rel and x.get("status") == "completed"]
        rel = dict(rel)
        if status == "halted":
            rel["status"] = "halted"
        elif a.fraction >= 1.0:
            rel["status"] = "completed"
            rel.pop("userFraction", None)
        else:
            rel["status"] = "inProgress"
            rel["userFraction"] = a.fraction
        send = [rel] if rel["status"] == "completed" else [rel] + others[:1]
        svc.edits().tracks().update(packageName=PACKAGE, editId=edit_id, track=track, body={"track": track, "releases": send}).execute()
        what = "halted" if status == "halted" else f"{min(a.fraction, 1.0):.0%}"
        r.ok(f"code {','.join(rel['versionCodes'])} on '{track}': {what}, {commit_edit(svc, edit_id)}")
        add_history(max(int(c) for c in rel["versionCodes"]), rel.get("name", ""), track, what, "")
    except HttpError as e:
        r.fail("Play said: " + http_error_text(e))
    return r.end()


def cmd_rollout(a):
    if not (0.0 < a.fraction <= 1.0):
        die("--fraction must be between 0.01 and 1.0")
    return change_rollout(a, "inProgress")


def cmd_halt(a):
    return change_rollout(a, "halted")


# ------------------------------------------------------------------------------------ all in one
def cmd_release(a):
    print("Full release: check -> version -> test -> AAB -> debug APK -> git commit + tag" + (" -> upload" if a.track else ""))
    if a.track:
        check_track_args(a)
    if not cmd_check():
        die("fix the problems above first")
    if not a.no_bump:
        a.keep_code, a.code = False, None
        cmd_version(a)
    if not a.skip_tests and not cmd_test():
        die("tests failed: nothing was built")
    if not cmd_aab():
        die("bundle verification failed")
    cmd_apk()
    code, name = version()
    files = [f for f in ("export_presets.cfg", "project.godot", "docs/RELEASE_HISTORY.md") if os.path.exists(os.path.join(ROOT, f))]
    git("add", *files)
    c, out = git("commit", "-m", f"Release {name} (code {code})", "--", *files)
    tag = f"v{name}-{code}"
    git("tag", "-f", tag)
    print(f"  git: committed version files and tagged {tag}")
    if a.track:
        a.dry_run = False
        if not cmd_upload(a):
            die("upload failed; the AAB is ready in build/ for a manual upload")
    if a.push:
        c, out = git("push", "origin", "HEAD", "--tags")
        print("  git push:", "done" if c == 0 else out[-300:])
    print(f"\n=== Release {name} (code {code}): OK ===")
    print(f"  AAB for Play:   {os.path.relpath(AAB, ROOT)}")
    print(f"  APK for friends: {os.path.relpath(APK, ROOT)}")
    return True


# ------------------------------------------------------------------------------------ phone, backup, web
def cmd_phone(_a=None):
    r = Report("USB phone")
    code, out = run([ADB, "devices"])
    devs = [l.split()[0] for l in out.splitlines()[1:] if l.strip().endswith("device")]
    if not r.check(devs, f"phone connected ({', '.join(devs)})", "no phone: plug in USB, unlock it, allow USB debugging"):
        return r.end()
    _, out = run([ADB, "shell", "dumpsys", "package", PACKAGE])
    vc = re.search(r"versionCode=(\d+)", out)
    vn = re.search(r"versionName=(\S+)", out)
    inst = re.search(r"installerPackageName=(\S+)", out)
    if not vc:
        r.warn("Stone Storm is not installed")
        return r.end()
    src = {"com.android.vending": "Google Play"}.get(inst.group(1) if inst else "", "USB / file (debug or sideloaded)")
    r.ok(f"installed: {vn.group(1) if vn else '?'} (code {vc.group(1)}), from {src}")
    perm = re.search(r"POST_NOTIFICATIONS: granted=(\w+)", out)
    r.ok(f"notifications allowed: {perm.group(1) if perm else 'not asked yet'}")
    if src == "Google Play":
        r.ok("keep it: update it from the Play Store. Don't install the debug APK over it (it would need an uninstall).")
    return r.end()


def cmd_logs(_a=None):
    print("Game log from the phone. Ctrl+C to stop.")
    os.execv(ADB, [ADB, "logcat", "-s", "godot:V"])


def cmd_backup(a):
    r = Report("Back up secret files")
    dest = os.path.expanduser(a.to)
    if not os.path.isdir(dest):
        die(f"folder not found: {dest}")
    ks, _, _ = credentials()
    files = {"castle_upload.keystore": ks, "export_credentials.cfg": CREDS, "ad_ids.cfg": AD_IDS,
             "google-services.json": GS_ROOT, "play-service-account.json": SERVICE_ACCOUNT}
    out = os.path.join(dest, f"castle_secrets_{datetime.date.today().isoformat()}.zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for arc, path in files.items():
            if path and os.path.exists(path):
                z.write(path, arc)
                r.ok(f"added {arc}")
            else:
                r.warn(f"not found, skipped: {arc}")
        z.writestr("README.txt", "Stone Storm secret files. Restore: docs/RELEASE_GUIDE.md part 2.\n"
                   "export_credentials.cfg contains the keystore password: keep this zip private.\n")
    r.ok(f"saved {out}. Keep a second copy somewhere else (Google Drive, another USB).")
    return r.end()


def cmd_web(_a=None):
    r = Report("Website deploy")
    for f in glob.glob(os.path.join(ROOT, "web", "**", "*.import"), recursive=True):
        os.remove(f)
    code, out = run(["npx", "-y", "wrangler@latest", "pages", "deploy", "web", "--project-name", "stonestorm",
                     "--branch", "main", "--commit-dirty=true"], timeout=600)
    r.check(code == 0 and "Deployment complete" in out, "deployed to https://stonestorm.pages.dev",
            "deploy failed (first time on this Mac: npx wrangler login):\n" + out[-400:])
    return r.end()


# ------------------------------------------------------------------------------------ main
def main():
    p = argparse.ArgumentParser(description="Stone Storm release tool (docs/RELEASE_GUIDE.md)")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check", help="is everything ready for a release build?")
    v = sub.add_parser("version", help="+1 version code and a new version name")
    v.add_argument("--name", help="version name like 1.0.0 (default: last number +1)")
    v.add_argument("--code", type=int, help="exact version code (default: +1)")
    v.add_argument("--keep-code", action="store_true", help="only change the name")
    sub.add_parser("test", help="import + all tests")
    sub.add_parser("aab", help="signed release bundle for Play, then verify")
    sub.add_parser("apk", help="debug APK with test ads, for friends")
    sub.add_parser("verify", help="check build/stone_storm.aab")

    def track_opts(sp, notes=True):
        sp.add_argument("--rollout", type=float, help="share of players, 0.01-1.0 (production only; default 1.0)")
        sp.add_argument("--confirm", action="store_true", help="required for production")
        sp.add_argument("--draft", action="store_true", help="save as draft, start it in Play Console")
        sp.add_argument("--priority", type=int, default=0, choices=range(0, 6), metavar="0-5",
                        help="in-app update priority: 0-3 = game offers a background update, 4-5 = blocking 'update now' screen (critical fixes only)")
        if notes:
            sp.add_argument("--notes", help=f"What's new text, max {NOTES_MAX} characters")

    u = sub.add_parser("upload", help="send the AAB to a Play track")
    u.add_argument("--track", required=True, help="internal | closed | open | production")
    u.add_argument("--dry-run", action="store_true", help="check everything, upload nothing")
    track_opts(u)
    sub.add_parser("status", help="what is on each Play track")
    pr = sub.add_parser("promote", help="copy the latest release from one track to another")
    pr.add_argument("--from", dest="from_track", required=True)
    pr.add_argument("--to", dest="to_track", required=True)
    track_opts(pr)
    ro = sub.add_parser("rollout", help="change the share of players getting a staged release")
    ro.add_argument("--track", default="production")
    ro.add_argument("--fraction", type=float, required=True, help="0.01-1.0 (1.0 = everyone)")
    ro.add_argument("--confirm", action="store_true")
    ha = sub.add_parser("halt", help="stop a staged rollout (players who have it keep it)")
    ha.add_argument("--track", default="production")
    ha.add_argument("--confirm", action="store_true")
    rl = sub.add_parser("release", help="check, version, test, AAB, APK, git tag (+ upload with --track)")
    rl.add_argument("--track", help="also upload: internal | closed | open | production")
    rl.add_argument("--name", help="version name like 1.0.0")
    rl.add_argument("--no-bump", action="store_true", help="keep the current version")
    rl.add_argument("--skip-tests", action="store_true", help="only for a rebuild of something already tested")
    rl.add_argument("--push", action="store_true", help="git push the commit and tag")
    track_opts(rl)
    sub.add_parser("phone", help="what is installed on the USB phone")
    sub.add_parser("logs", help="game log from the USB phone")
    b = sub.add_parser("backup-secrets", help="zip the keystore and config files into a folder")
    b.add_argument("--to", required=True, help="folder, for example /Volumes/MyUSB")
    sub.add_parser("web", help="deploy the website")
    a = p.parse_args()
    fn = {"check": cmd_check, "version": cmd_version, "test": cmd_test, "aab": cmd_aab, "apk": cmd_apk,
          "verify": cmd_verify, "upload": cmd_upload, "status": cmd_status, "promote": cmd_promote,
          "rollout": cmd_rollout, "halt": cmd_halt, "release": cmd_release, "phone": cmd_phone, "logs": cmd_logs,
          "backup-secrets": cmd_backup, "web": cmd_web}[a.cmd]
    try:
        ok = fn(a)
    except KeyboardInterrupt:
        die("stopped")
    except Exception as e:  # login and network problems with the Play API, explained in plain words
        name = type(e).__name__
        if name in ("RefreshError", "TransportError", "DefaultCredentialsError") or "invalid_grant" in str(e):
            die("could not log in to Google Play with the upload key (" + str(e)[:160] + ").\n"
                "      Check part 3 of docs/RELEASE_GUIDE.md: right JSON file, API enabled, service account invited in Play Console.")
        if name == "HttpError":
            die("Google Play refused: " + http_error_text(e) + "\n      Usually a missing permission for the service account (guide part 3.4).")
        if name in ("ServerNotFoundError", "ConnectionError", "TimeoutError", "gaierror"):
            die("no internet connection to Google Play")
        raise
    sys.exit(0 if ok in (True, None) else 1)


if __name__ == "__main__":
    main()
