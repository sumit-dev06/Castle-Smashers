#!/usr/bin/env python3
"""Build the Stone Storm HTML5 playable ad from the real game data and art.

Reads data/levels (6 and 39), data/materials.json, data/projectiles.json, balance gaps and the
shipped art, then inlines everything (Matter.js physics, game code, images, sounds, font) into
single self-contained HTML files, one per ad network:

  build/playable/stone_storm_preview.html     open in a browser to test (no ad SDK)
  build/playable/stone_storm_mraid.html       AppLovin, Unity Ads, ironSource/LevelPlay, Mintegral, Liftoff (MRAID 2/3)
  build/playable/stone_storm_meta.html        Meta Audience Network / Facebook (FbPlayableAd)
  build/playable/stone_storm_google.zip       Google Ads App campaigns (HTML5, ExitApi)

Usage: python3 tools/build_playable.py
See docs/PLAYABLE_ADS.md.
"""
import base64, io, json, os, struct, wave, zipfile
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "playable")
SRC = os.path.join(ROOT, "playable")
PACKAGE = "com.castlesmashers.game"
STORE_URL = "https://play.google.com/store/apps/details?id=" + PACKAGE
LEVEL_IDS = [6, 39]
CUT = "assets/art/ai/cut/"
SVG = "assets/art/svg/"

# name -> (path, max width) for raster art, re-encoded as WebP
RASTER = {
    "bg_1": (CUT + "bg_blossom_dawn.png", 1100),
    "bg_4": (CUT + "bg_mines_crystal.png", 1100),
    "ledge_1": (CUT + "stage_ledge_blossom.png", 900),
    "base_wide_1": (CUT + "stage_base_blossom_wide.png", 900),
    "ledge_4": (CUT + "stage_ledge_mines.png", 900),
    "base_wide_4": (CUT + "stage_base_mines_wide.png", 900),
    "base_small_4": (CUT + "stage_base_mines_small.png", 300),
    "fg_1": (CUT + "fg_blossom_right.png", 420),
    "fg_4": (CUT + "fg_mines_right.png", 420),
    "hero_stone": (CUT + "hero_stone.png", 120),
    "hero_bomb": (CUT + "hero_bomb.png", 120),
    "hero_fire": (CUT + "hero_fire.png", 120),
    "hero_cyclone": (CUT + "hero_cyclone.png", 120),
    "archer_idle": (CUT + "archer_idle.png", 110),
    "archer_shoot": (CUT + "archer_shoot.png", 110),
    "archer_ko": (CUT + "archer_ko.png", 110),
    "soldier_idle": (CUT + "soldier_idle.png", 110),
    "soldier_cheer": (CUT + "soldier_cheer.png", 110),
    "logo": (CUT + "logo_mark.png", 220),
}
BLOCKS = ["stone_block", "plank_long", "post", "roof_tile", "iron_ball", "barrel", "crate"]
VECTOR = ["catapult_base", "catapult_arm", "catapult_cup", "wizard_idle", "flag", "arrow"]
SFX = ["launch_0", "wood_hit_0", "wood_break_0", "stone_hit_0", "stone_break_0", "explosion_0",
       "enemy_ko_0", "rope_snap_0", "win_0", "lose_0", "fire_0", "whoosh_0", "star_0", "ui_tap_0",
       "splash_0", "stretch_loop", "ability_0", "collapse_m_0"]
SFX_RATE = 16000


def rel(p):
    return os.path.join(ROOT, p)


def webp_uri(path, max_w):
    im = Image.open(rel(path)).convert("RGBA")
    if im.width > max_w:
        im = im.resize((max_w, round(im.height * max_w / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    opaque = path.split("/")[-1].startswith("bg_")
    im.save(buf, "WEBP", quality=58 if opaque else 78, method=6)
    return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode(), im.size


def svg_uri(path):
    data = open(rel(path), "rb").read()
    return "data:image/svg+xml;base64," + base64.b64encode(data).decode()


def wav_uri(path):
    """Mono 16 kHz 16-bit WAV (WebAudio decodes it everywhere, no encoder needed)."""
    with wave.open(rel(path)) as w:
        ch, sw, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    assert sw == 2, path
    samples = struct.unpack("<%dh" % (len(raw) // 2), raw)
    mono = [(samples[i] + samples[i + 1]) // 2 for i in range(0, len(samples) - 1, 2)] if ch == 2 else list(samples)
    step = rate / SFX_RATE
    out = [mono[int(i * step)] for i in range(int(len(mono) / step))]
    buf = io.BytesIO()
    with wave.open(buf, "wb") as o:
        o.setnchannels(1); o.setsampwidth(2); o.setframerate(SFX_RATE)
        o.writeframes(struct.pack("<%dh" % len(out), *out))
    return "data:audio/wav;base64," + base64.b64encode(buf.getvalue()).decode()


def load_data():
    mats = json.load(open(rel("data/materials.json")))
    proj = json.load(open(rel("data/projectiles.json")))
    bal = json.load(open(rel("data/balance.json")))
    levels = []
    for lid in LEVEL_IDS:
        lv = json.load(open(rel("data/levels/level_%03d.json" % lid)))
        for k in ("cinematic",):
            lv.pop(k, None)
        realm = next(r for r in bal["realms"] if r["id"] == lv["realm"])
        lv["gap"] = bal["gaps"][realm["gap"]]
        lv["realm_name"] = realm["name"]
        levels.append(lv)
    shapes = {k: mats["shapes"][k] for k in BLOCKS}
    used = {s["material"] for s in shapes.values()}
    materials = {k: v for k, v in mats["materials"].items() if k in used}
    heroes = {k: proj[k] for k in ("stone", "bomb", "fire", "cyclone")}
    meta = json.load(open(rel(CUT + "meta.json")))
    art_meta = {k: meta[v[0].split("/")[-1][:-4]] for k, v in RASTER.items() if v[0].split("/")[-1][:-4] in meta}
    return {"levels": levels, "shapes": shapes, "materials": materials, "heroes": heroes,
            "catapult": bal["siege_weapons"]["catapult"]["art"], "launch": bal["catapult"],
            "meta": art_meta, "store_url": STORE_URL}


def build():
    os.makedirs(OUT, exist_ok=True)
    assets, sizes = {}, {}
    for name, (path, w) in RASTER.items():
        assets[name], sizes[name] = webp_uri(path, w)
    for b in BLOCKS:
        for d in range(3):
            assets["block_%s_%d" % (b, d)] = svg_uri(SVG + "block_%s_%d.svg" % (b, d))
    for v in VECTOR:
        assets[v] = svg_uri(SVG + v + ".svg")
    sounds = {}
    for s in SFX:
        p = "assets/audio/sfx/%s.wav" % s
        if os.path.exists(rel(p)):
            sounds[s.rsplit("_", 1)[0] if s[-2] == "_" else s] = wav_uri(p)
    data = load_data()
    data["sizes"] = sizes
    font = base64.b64encode(open(rel("assets/fonts/lilita-one-latin.woff2"), "rb").read()).decode()
    body_font = base64.b64encode(open(rel("assets/fonts/fredoka-latin.woff2"), "rb").read()).decode()
    matter = open(os.path.join(SRC, "vendor", "matter.min.js")).read()
    game = open(os.path.join(SRC, "game.js")).read()
    tpl = open(os.path.join(SRC, "template.html")).read()

    def page(network, head_extra):
        html = tpl.replace("%HEAD_EXTRA%", head_extra).replace("%NETWORK%", network)
        html = html.replace("%FONT_TITLE%", font).replace("%FONT_BODY%", body_font)
        payload = ("window.SS_DATA=" + json.dumps(data, separators=(",", ":")) + ";\n" +
                   "window.SS_ART=" + json.dumps(assets, separators=(",", ":")) + ";\n" +
                   "window.SS_SFX=" + json.dumps(sounds, separators=(",", ":")) + ";\n")
        # Inline scripts last so the HTML stays readable at the top.
        return html.replace("%SCRIPTS%", "<script>" + matter + "</script>\n<script>" + payload + "</script>\n<script>" + game + "</script>")

    outs = {
        "stone_storm_preview.html": page("preview", ""),
        "stone_storm_mraid.html": page("mraid", '<script src="mraid.js"></script>'),
        "stone_storm_meta.html": page("meta", ""),
    }
    google = page("google", '<meta name="ad.size" content="width=320,height=480">\n'
                  '<meta name="ad.orientation" content="portrait,landscape">\n'
                  '<script type="text/javascript" src="https://tpc.googlesyndication.com/pagead/gadgets/html5/api/exitapi.js"></script>')
    for name, html in outs.items():
        open(os.path.join(OUT, name), "w").write(html)
    zpath = os.path.join(OUT, "stone_storm_google.zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("index.html", google)
    for name in list(outs) + ["stone_storm_google.zip"]:
        size = os.path.getsize(os.path.join(OUT, name))
        print("%-32s %6.0f KB" % (name, size / 1024))


if __name__ == "__main__":
    build()
