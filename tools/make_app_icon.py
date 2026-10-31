"""Builds every app-icon file from the owner's icon art (art_source/brand/app_icon_source.png).

The source is a rounded-square painting on a black margin. Android needs:
- adaptive icon layers (432x432, 108 dp): the launcher masks them to its own shape (circle,
  squircle, rounded square) and shows only the centre 72 dp (288 px), moving the rest for parallax.
  The painting goes on the background layer, scaled so the boulder and catapult stay inside the
  visible area under every mask; outside that, the painting is extended (soft, blurred) so
  parallax never reveals an edge. The foreground layer is empty.
- a legacy 192 px icon (Android 7.0-7.1): the rounded square itself, transparent corners.
- the project icon and the Play Store hi-res icon (512, full-bleed square; Play rounds it).

Run: python3 tools/make_app_icon.py   (writes assets/art/brand/*, previews in build/shots/)
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_source", "brand", "app_icon_source.png")
OUT = os.path.join(ROOT, "assets", "art", "brand")
SHOTS = os.path.join(ROOT, "build", "shots")
# Size of the painting inside the 432 px adaptive layer. 288 px is visible; a little larger keeps
# the painted frame edge out of view while the boulder (upper right) survives a circle mask.
ART_IN_LAYER = 292
BLACK = 60          # summed RGB below this is the black margin
ERODE = 7           # px of the anti-aliased margin edge also treated as margin


def load_art():
    im = Image.open(SRC).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    # Margin = dark pixels connected to the image edge (the boulder's dark cracks are not margin).
    dark = Image.fromarray(((a.sum(2) <= BLACK) * 255).astype(np.uint8)).copy()  # writable
    w, h = dark.size
    for seed in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if dark.getpixel(seed) == 255:
            ImageDraw.floodfill(dark, seed, 128)
    inside = np.asarray(dark) != 128
    ys, xs = np.where(inside)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    side = min(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
    art = im.crop(box)
    m = Image.fromarray((inside * 255).astype(np.uint8)).crop(box)
    m = m.filter(ImageFilter.MinFilter(2 * ERODE + 1))
    return art, m


def fill_margin(art, mask):
    """Paints the black corners with the surrounding colours (normalised blur, coarse to fine)."""
    a = np.asarray(art).astype(np.float32)
    m = np.asarray(mask).astype(np.float32)[..., None] / 255.0
    out = a.copy()
    have = m.copy()
    first = True
    for r in (160, 80, 40, 20, 10):
        num = Image.fromarray(np.clip(a * m, 0, 255).astype(np.uint8))
        num = np.asarray(num.filter(ImageFilter.GaussianBlur(r))).astype(np.float32)
        den = Image.fromarray((m[..., 0] * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))
        den = np.asarray(den).astype(np.float32)[..., None] / 255.0
        est = num / np.maximum(den, 1e-3)
        if first:
            out = est   # widest blur covers every corner pixel; finer passes add detail near the art
            have = np.zeros_like(have)
            first = False
            continue
        w = np.clip(den * 3.0, 0, 1) * (1 - have)
        out = out * (1 - w) + est * w
        have = np.clip(have + w, 0, 1)
    out = a * m + out * (1 - m)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def reflect_corners(full, mask):
    """Rounded corners of the painting: each missing pixel takes the colour mirrored across the
    corner arc, so wood grain and sky continue sharply instead of a blur."""
    a = np.asarray(full).astype(np.float32)
    m = np.asarray(mask) > 127
    n = m.shape[0]
    t0 = next(t for t in range(n // 2) if m[t, t])
    R = t0 / (1 - 1 / np.sqrt(2))
    out = a.copy()
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    for cx, cy in ((R, R), (n - 1 - R, R), (R, n - 1 - R), (n - 1 - R, n - 1 - R)):
        dx, dy = xx - cx, yy - cy
        quad = (np.sign(dx) == np.sign(n / 2 - cx) * -1) & (np.sign(dy) == np.sign(n / 2 - cy) * -1)
        d = np.sqrt(dx * dx + dy * dy) + 1e-6
        sel = quad & ~m & (d > R - 2)
        rr = np.maximum(2 * R - d, 0) / d
        qx = np.clip(cx + dx * rr, 0, n - 1).astype(int)
        qy = np.clip(cy + dy * rr, 0, n - 1).astype(int)
        out[sel] = a[qy[sel], qx[sel]]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def rounded_mask(size, radius_frac):
    s = 4
    m = Image.new("L", (size * s, size * s), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * s - 1, size * s - 1], int(size * s * radius_frac), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def sharpen(im, px):
    return im.filter(ImageFilter.UnsharpMask(radius=max(0.6, px / 256.0), percent=60, threshold=2))


def main():
    os.makedirs(OUT, exist_ok=True)
    art, mask = load_art()
    full = reflect_corners(fill_margin(art, mask), mask)   # full-bleed square painting

    # Adaptive background: painting at ART_IN_LAYER, an enlarged blurred copy behind it.
    L = 432
    core = sharpen(full.resize((ART_IN_LAYER, ART_IN_LAYER), Image.LANCZOS), ART_IN_LAYER)
    o = (L - ART_IN_LAYER) // 2
    # Outside the painting: a mirror of its edge (seamless, only seen during launcher parallax),
    # softened with distance so the reflection never reads as a second image.
    c = np.asarray(core).astype(np.float32)
    ext = np.pad(c, ((o, L - ART_IN_LAYER - o), (o, L - ART_IN_LAYER - o), (0, 0)), mode="reflect")
    soft = np.asarray(Image.fromarray(ext.astype(np.uint8)).filter(ImageFilter.GaussianBlur(8))).astype(np.float32)
    yy, xx = np.mgrid[0:L, 0:L]
    dist = np.maximum(np.maximum(o - xx, xx - (o + ART_IN_LAYER - 1)), np.maximum(o - yy, yy - (o + ART_IN_LAYER - 1)))
    k = np.clip(dist / 24.0, 0, 1)[..., None]
    bg = Image.fromarray(np.clip(ext * (1 - k) + soft * k, 0, 255).astype(np.uint8))
    bg.save(os.path.join(OUT, "app_icon_bg.png"))
    Image.new("RGBA", (L, L), (0, 0, 0, 0)).save(os.path.join(OUT, "app_icon_fg.png"))

    # Legacy launcher icon and the project icon: rounded square, transparent corners.
    for size, name in ((192, "app_icon_192.png"), (512, "app_icon.png")):
        im = sharpen(full.resize((size, size), Image.LANCZOS), size).convert("RGBA")
        im.putalpha(rounded_mask(size, 0.22))
        im.save(os.path.join(OUT, name))
    # Play Store hi-res icon: full square, Play applies its own rounding and shadow.
    sharpen(full.resize((512, 512), Image.LANCZOS), 512).save(os.path.join(OUT, "play_store_icon_512.png"))

    # Previews: the adaptive icon under the common launcher masks, large and at phone size.
    os.makedirs(SHOTS, exist_ok=True)
    view = bg.crop((72, 72, 360, 360))
    masks = {
        "circle": Image.new("L", (288, 288), 0),
        "squircle": rounded_mask(288, 0.36),
        "rounded": rounded_mask(288, 0.18),
        "teardrop": Image.new("L", (288, 288), 0),
    }
    ImageDraw.Draw(masks["circle"]).ellipse([0, 0, 287, 287], fill=255)
    td = ImageDraw.Draw(masks["teardrop"])
    td.ellipse([0, 0, 287, 287], fill=255)
    td.rectangle([144, 144, 287, 287], fill=255)
    sheet = Image.new("RGB", (4 * 300 + 10, 300 + 120), (40, 44, 60))
    for i, (k, m) in enumerate(masks.items()):
        t = view.convert("RGBA")
        t.putalpha(m)
        sheet.paste(t, (10 + i * 300, 6), t)
        small = t.resize((72, 72), Image.LANCZOS)   # 48 dp at 480 dpi = 144 px; 72 = half of that
        sheet.paste(small, (10 + i * 300 + 108, 310), small)
    sheet.save(os.path.join(SHOTS, "app_icon_masks.png"))
    print("app icon: wrote app_icon_bg/fg (432), app_icon_192, app_icon (512), play_store_icon_512")


if __name__ == "__main__":
    main()
