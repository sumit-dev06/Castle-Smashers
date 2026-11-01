#!/usr/bin/env python3
"""Turns raw AI images into game-ready art.

Input : new PNG/JPG files dropped in assets/art/ai/ or assets/art/ai/incoming/ are first MOVED to
        art_source/ai/ (kept forever, never shipped: the folder has a .gdignore).
Output: assets/art/ai/cut/<name>.png  +  assets/art/ai/cut/meta.json

Characters (plain white background):
  1. background removal by flood fill from the border (interior whites such as eyes stay)
  2. soft anti-aliased edge + colour decontamination (no white halo)
  3. speck removal, light colour grade, trim
  4. one pixel scale per character family (all poses of the archer share a scale)
  5. dark-brown outline so they read on busy backgrounds (matches the reference look)
  6. light sharpening after downscale
  7. archers are mirrored so they face left (toward our catapult)
Backgrounds: colour grade, resize to BG_HEIGHT (sharp; the game softens them).
Stage pieces (stage_*, fg_*, boss_* on a white background): cutout, light grade, trim, no outline,
  capped to PIECE_MAX px. stage_* also gets top_y = the flat walkable top line (first row that is
  opaque across most of the width), which the game puts on the ground line.

Run: python3 tools/cutout.py         (add --preview to write build/cutout_preview.png)
"""
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DROP_DIRS = [os.path.join(ROOT, "assets", "art", "ai"), os.path.join(ROOT, "assets", "art", "ai", "incoming")]
SRC = os.path.join(ROOT, "art_source", "ai")
OUT = os.path.join(ROOT, "assets", "art", "ai", "cut")

BG_HEIGHT = 900
# Pieces on white. block_ and mechanism_ images replace the SVG at its world size (Art.is_fit),
# so trim them tight: their outline must fill the image.
PIECE_PREFIXES = ("stage_", "fg_", "boss_", "block_", "mechanism_", "gadget_")
PIECE_MAX = {"stage_": 1400, "fg_": 900, "boss_": 1200, "block_": 512, "mechanism_": 700, "gadget_": 512}
UI_PREFIXES = ("icon_", "logo_", "gem", "blueprint", "cannonball", "engineer_", "chest_")
UI_MAX = 512
TOP_ROW_FILL = 0.6
# Units stand partway into the painted top surface (grass, sand, deck) instead of on its back edge:
# walk_y = top_y + WALK_FRAC * piece height.
WALK_FRAC = 0.06
# Pieces must be on a plain white background (border median at least this bright in every channel).
WHITE_MIN = 230
OUTLINE_RGB = (52, 30, 16)

# family -> output size rule. unit families: idle content height in px. hero: body radius in px.
FAMILIES = {
    "soldier": {"kind": "unit", "idle": "soldier_idle", "height": 300, "outline": 5, "flip": False},
    "archer": {"kind": "unit", "idle": "archer_idle", "height": 300, "outline": 5, "flip": True},
    "hero": {"kind": "hero", "radius": 120, "outline": 5, "flip": False},
}
# Boss characters are unit families too (one pixel scale per boss across idle/shoot/ko).
for _boss in ("warlord", "sultan", "ironhook", "forgemaster", "baron"):
    FAMILIES["boss_" + _boss] = {"kind": "unit", "idle": f"boss_{_boss}_idle", "height": 300, "outline": 5, "flip": True}
# Per-image tweaks. tol = how far from the background colour still counts as background.
OVERRIDES = {
    "hero_cyclone_idle": {"tol": 16, "fit": "bbox"},
    "hero_stone_idle": {"tol": 22},
    "hero_stone_hit": {"tol": 22},
}
# Output names match the SVG names the game already uses.
RENAME = {"hero_stone_idle": "hero_stone", "hero_fire_idle": "hero_fire", "hero_bomb_idle": "hero_bomb",
          "hero_cyclone_idle": "hero_cyclone"}


def family_of(name):
    for f in FAMILIES:
        if name.startswith(f):
            return f
    return None


def collect_drops():
    os.makedirs(SRC, exist_ok=True)
    moved = []
    for d in DROP_DIRS:
        if not os.path.isdir(d):
            continue
        for fn in os.listdir(d):
            if fn.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                shutil.move(os.path.join(d, fn), os.path.join(SRC, fn))
                imp = os.path.join(d, fn + ".import")
                if os.path.exists(imp):
                    os.remove(imp)
                moved.append(fn)
    return moved


# ----------------------------------------------------------------------------------- cutout
def remove_background(rgb, tol=28.0, lo=6.0, hi=70.0, band=3):
    h, w, _ = rgb.shape
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bgc = np.median(border, axis=0)
    diff = np.abs(rgb - bgc).max(axis=2)
    near = diff < tol
    lab, n = ndimage.label(near)
    edge_labels = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    edge_labels = edge_labels[edge_labels > 0]
    bg = np.isin(lab, edge_labels)
    # Enclosed background pockets (e.g. between a bow and its string): large, flat, background-coloured.
    # Small pockets such as eye whites and teeth stay.
    if n:
        areas = ndimage.sum(near, lab, range(1, n + 1))
        means = ndimage.mean(diff, lab, range(1, n + 1))
        pockets = [i + 1 for i in range(n) if areas[i] > h * w * 0.006 and means[i] < 10 and (i + 1) not in edge_labels]
        if pockets:
            bg |= np.isin(lab, pockets)
    alpha = np.where(bg, 0.0, 1.0)
    # Soft edge in a thin band either side of the boundary.
    edge = ndimage.binary_dilation(bg, iterations=band) & ndimage.binary_dilation(~bg, iterations=band)
    soft = np.clip((diff - lo) / (hi - lo), 0.0, 1.0)
    alpha[edge] = soft[edge]
    alpha[bg & ~edge] = 0.0
    # Decontaminate: remove the background colour mixed into semi-transparent pixels.
    a = alpha[..., None]
    with np.errstate(divide="ignore", invalid="ignore"):
        fg = np.where(a > 0.02, (rgb - (1.0 - a) * bgc) / np.maximum(a, 1e-3), rgb)
    fg = np.clip(fg, 0, 255)
    # Drop specks: keep components bigger than 0.2% of the main body.
    solid = alpha > 0.5
    lab2, n2 = ndimage.label(solid)
    if n2 > 1:
        sizes = ndimage.sum(solid, lab2, range(1, n2 + 1))
        keep = np.isin(lab2, 1 + np.where(sizes >= sizes.max() * 0.002)[0])
        grown = ndimage.binary_dilation(keep, iterations=band + 1)
        alpha = np.where(grown, alpha, 0.0)
    alpha = ndimage.gaussian_filter(alpha, 0.5)
    return fg, np.clip(alpha, 0, 1)


def to_image(fg, alpha):
    arr = np.dstack([fg, alpha * 255.0]).round().astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def grade(img, sat=1.07, contrast=1.04):
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(sat)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def resize_rgba(img, size):
    return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def add_outline(img, px):
    a = np.asarray(img.getchannel("A")).astype(float) / 255.0
    solid = a > 0.5
    dist = ndimage.distance_transform_edt(~solid)
    ring = np.clip(px + 0.5 - dist, 0.0, 1.0)
    rgba = np.asarray(img).astype(float)
    out = np.zeros_like(rgba)
    out[..., :3] = OUTLINE_RGB
    out[..., 3] = ring * 255.0
    # alpha-composite the character over the outline
    fa = rgba[..., 3:4] / 255.0
    ba = out[..., 3:4] / 255.0
    oa = fa + ba * (1 - fa)
    with np.errstate(divide="ignore", invalid="ignore"):
        col = np.where(oa > 0, (rgba[..., :3] * fa + out[..., :3] * ba * (1 - fa)) / np.maximum(oa, 1e-6), 0)
    res = np.dstack([col, oa * 255.0]).round().clip(0, 255).astype(np.uint8)
    return Image.fromarray(res, "RGBA")


def sharpen(img):
    rgb = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.2, percent=55, threshold=2))
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def trim(img, pad):
    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    img = img.crop(bbox)
    canvas = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), (0, 0, 0, 0))
    canvas.paste(img, (pad, pad))
    return canvas


def measure(img, fit):
    a = np.asarray(img.getchannel("A")) > 128
    ys, xs = np.nonzero(a)
    m = {"w": img.width, "h": img.height,
         "top": int(ys.min()), "bottom": int(ys.max()), "left": int(xs.min()), "right": int(xs.max())}
    base = ys > ys.max() - (ys.max() - ys.min()) * 0.25
    m["feet_x"] = float(xs[base].mean())
    m["feet_y"] = float(ys.max())
    if fit == "bbox":
        r = 0.5 * min(xs.max() - xs.min(), ys.max() - ys.min()) * 0.72
        cy = ys.min() + (ys.max() - ys.min()) * 0.42
        m["body_c"] = [float((xs.min() + xs.max()) / 2), float(cy)]
        m["body_r"] = float(r)
    else:
        dist = ndimage.distance_transform_edt(a)
        cy, cx = np.unravel_index(np.argmax(dist), dist.shape)
        m["body_c"] = [float(cx), float(cy)]
        m["body_r"] = float(dist.max())
    return m


def process_character(name, path, scale_for):
    o = OVERRIDES.get(name, {})
    fam = family_of(name)
    cfg = FAMILIES[fam]
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(float)
    fg, alpha = remove_background(rgb, tol=o.get("tol", 28.0))
    img = grade(to_image(fg, alpha))
    if cfg["flip"]:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    img = trim(img, 2)
    fit = o.get("fit", "inscribed")
    if cfg["kind"] == "hero":
        m0 = measure(img, fit)
        s = cfg["radius"] / m0["body_r"]
    else:
        s = scale_for[fam]
    pad = cfg["outline"] + 3
    img = resize_rgba(img, (max(1, round(img.width * s)), max(1, round(img.height * s))))
    canvas = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), (0, 0, 0, 0))
    canvas.paste(img, (pad, pad))
    img = sharpen(add_outline(canvas, cfg["outline"]))
    meta = measure(img, fit)
    meta["family"] = fam
    if cfg["kind"] == "unit":
        meta["unit_h"] = cfg["height"]
    return img, meta


def family_scales(sources):
    """Pixel scale per unit family, from the idle pose's trimmed height."""
    scales = {}
    for fam, cfg in FAMILIES.items():
        if cfg["kind"] != "unit":
            continue
        src = sources.get(cfg["idle"])
        if not src:
            continue
        rgb = np.asarray(Image.open(src).convert("RGB")).astype(float)
        _, alpha = remove_background(rgb, tol=OVERRIDES.get(cfg["idle"], {}).get("tol", 28.0))
        ys = np.nonzero(alpha > 0.5)[0]
        scales[fam] = cfg["height"] / float(ys.max() - ys.min() + 1)
    return scales


def process_background(path):
    img = Image.open(path).convert("RGB")
    img = ImageEnhance.Color(img).enhance(1.05)
    w = round(img.width * BG_HEIGHT / img.height)
    img = img.resize((w, BG_HEIGHT), Image.LANCZOS)
    return img, {"w": w, "h": BG_HEIGHT, "kind": "background"}


def flat_top(img):
    a = np.asarray(img.getchannel("A")) > 128
    cols = a.any(axis=0)
    width = max(1, int(cols.sum()))
    rows = np.nonzero(a.sum(axis=1) >= width * TOP_ROW_FILL)[0]
    return int(rows[0]) if len(rows) else 0


def process_piece(name, path):
    pfx = next(p for p in PIECE_PREFIXES if name.startswith(p))
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(float)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    if np.median(border, axis=0).min() < WHITE_MIN:
        return None, None
    fg, alpha = remove_background(rgb, tol=OVERRIDES.get(name, {}).get("tol", 28.0))
    img = trim(grade(to_image(fg, alpha)), 0)
    k = min(1.0, PIECE_MAX[pfx] / max(img.width, img.height))
    if k < 1.0:
        img = sharpen(resize_rgba(img, (round(img.width * k), round(img.height * k))))
    m = {"w": img.width, "h": img.height, "kind": pfx.rstrip("_")}
    if pfx == "stage_":
        m["top_y"] = flat_top(img)
        m["walk_y"] = m["top_y"] + round(WALK_FRAC * img.height)
    return img, m




def process_ui_piece(name, path):
    src = Image.open(path).convert("RGBA")
    alpha = np.asarray(src.getchannel("A"))
    if alpha.min() < 245:
        img = src
    else:
        rgb = np.asarray(src.convert("RGB")).astype(float)
        border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
        if np.median(border, axis=0).min() < WHITE_MIN:
            return None, None
        fg, cut_alpha = remove_background(rgb, tol=OVERRIDES.get(name, {}).get("tol", 28.0))
        img = to_image(fg, cut_alpha)
    img = trim(grade(img), 4)
    k = min(1.0, UI_MAX / max(img.width, img.height))
    if k < 1.0:
        img = sharpen(resize_rgba(img, (round(img.width * k), round(img.height * k))))
    return img, {"w": img.width, "h": img.height, "kind": "ui"}
def preview(names):
    tiles = []
    for n in names:
        im = Image.open(os.path.join(OUT, n + ".png"))
        if im.mode != "RGBA":
            continue
        im.thumbnail((260, 260))
        bg = Image.new("RGBA", (270, 270), (120, 190, 90, 255))
        for y in range(0, 270, 30):
            for x in range(0, 270, 30):
                if (x + y) // 30 % 2:
                    bg.paste((140, 205, 110, 255), (x, y, x + 30, y + 30))
        bg.alpha_composite(im, ((270 - im.width) // 2, (270 - im.height) // 2))
        tiles.append(bg)
    cols = 6
    sheet = Image.new("RGBA", (270 * cols, 270 * ((len(tiles) + cols - 1) // cols)), (0, 0, 0, 255))
    for i, t in enumerate(tiles):
        sheet.paste(t, (270 * (i % cols), 270 * (i // cols)))
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    sheet.convert("RGB").save(os.path.join(ROOT, "build", "cutout_preview.png"))


LOSSY_PREFIXES = ("bg_", "stage_", "fg_", "boss_")
LOSSY_QUALITY = 0.82


def lossy_imports():
    """Big painted images ship as lossy WebP (Godot import compress/mode=1); characters stay lossless.
    Godot writes the .import file on first import, so run this again after a new drop is imported."""
    changed = 0
    for fn in sorted(os.listdir(OUT)):
        if not (fn.endswith(".png.import") and fn.startswith(LOSSY_PREFIXES)):
            continue
        path = os.path.join(OUT, fn)
        with open(path) as fh:
            txt = fh.read()
        new = txt.replace("compress/mode=0", "compress/mode=1")
        new = "\n".join(f"compress/lossy_quality={LOSSY_QUALITY}" if ln.startswith("compress/lossy_quality=") else ln
                        for ln in new.split("\n"))
        if new != txt:
            with open(path, "w") as fh:
                fh.write(new)
            changed += 1
    print("lossy import settings updated:", changed)


def main():
    if "--imports" in sys.argv:
        lossy_imports()
        return
    moved = collect_drops()
    if moved:
        print("moved to art_source/ai:", ", ".join(moved))
    os.makedirs(OUT, exist_ok=True)
    sources = {}
    for fn in sorted(os.listdir(SRC)):
        if fn.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
            sources[os.path.splitext(fn)[0]] = os.path.join(SRC, fn)
    scales = family_scales(sources)
    meta = {}
    chars = []
    for name, path in sources.items():
        out_name = RENAME.get(name, name)
        if name.startswith("bg_"):
            img, m = process_background(path)
            img.save(os.path.join(OUT, out_name + ".png"), optimize=True)
        elif family_of(name):
            img, m = process_character(name, path, scales)
            img.save(os.path.join(OUT, out_name + ".png"), optimize=True)
            chars.append(out_name)
        elif name.startswith(PIECE_PREFIXES):
            img, m = process_piece(name, path)
            if img is None:
                print("skip (not on a white background, regenerate it):", name)
                stale = os.path.join(OUT, out_name + ".png")
                if os.path.exists(stale):
                    os.remove(stale)
                continue
            img.save(os.path.join(OUT, out_name + ".png"), optimize=True)
            chars.append(out_name)
        elif name.startswith(UI_PREFIXES):
            img, m = process_ui_piece(name, path)
            if img is None:
                print("skip (UI art needs transparency or a white background):", name)
                continue
            img.save(os.path.join(OUT, out_name + ".png"), optimize=True)
            chars.append(out_name)
        elif family_of(name):
            img, m = process_character(name, path, scales)
            img.save(os.path.join(OUT, out_name + ".png"), optimize=True)
            chars.append(out_name)
        else:
            print("skip (unknown type):", name)
            continue
        meta[out_name] = m
        print(f"  {out_name:24s} {m['w']}x{m['h']}")
    with open(os.path.join(OUT, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)
    if "--preview" in sys.argv:
        preview(chars)
    print("wrote", len(meta), "images to", OUT)
    lossy_imports()


if __name__ == "__main__":
    main()
