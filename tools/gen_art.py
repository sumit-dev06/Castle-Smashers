#!/usr/bin/env python3
"""Generates all vector art for Castle Smashers into assets/art/svg/.

Style rules (docs/ART_DIRECTION.md): soft 3D cartoon, gradients for volume, light from the
top-left, white highlight, no black outlines. SVG sizes are 1x world pixels; Godot imports
them at 2x (project.godot importer_defaults svg/scale).

Run:  python3 tools/gen_art.py
"""
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "art", "svg")


# --------------------------------------------------------------------------- helpers
class Doc:
    """Collects gradient defs with unique ids (prefix keeps composed files clash-free)."""

    def __init__(self, pfx="a"):
        self.defs = []
        self.n = 0
        self.pfx = pfx

    def _id(self):
        self.n += 1
        return f"{self.pfx}{self.n}"

    @staticmethod
    def _stops(stops):
        out = []
        for s in stops:
            o, c = s[0], s[1]
            a = s[2] if len(s) > 2 else 1
            out.append(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>')
        return "".join(out)

    def lin(self, stops, x1=0, y1=0, x2=0, y2=1):
        i = self._id()
        self.defs.append(f'<linearGradient id="{i}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
                         f'{self._stops(stops)}</linearGradient>')
        return f"url(#{i})"

    def rad(self, stops, cx=0.38, cy=0.32, r=0.72, fx=None, fy=None):
        i = self._id()
        fx = cx if fx is None else fx
        fy = cy if fy is None else fy
        self.defs.append(f'<radialGradient id="{i}" cx="{cx}" cy="{cy}" r="{r}" fx="{fx}" fy="{fy}">'
                         f'{self._stops(stops)}</radialGradient>')
        return f"url(#{i})"

    def svg(self, w, h, body):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
                f'viewBox="0 0 {w} {h}"><defs>{"".join(self.defs)}</defs>{body}</svg>')


def f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def rect(x, y, w, h, r=0, fill="#000", op=1, extra=""):
    return (f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="{f(r)}" '
            f'fill="{fill}" opacity="{op}" {extra}/>')


def circle(cx, cy, r, fill, op=1, extra=""):
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}" opacity="{op}" {extra}/>'


def ellipse(cx, cy, rx, ry, fill, op=1, rot=0, extra=""):
    t = f' transform="rotate({f(rot)} {f(cx)} {f(cy)})"' if rot else ""
    return (f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="{fill}" '
            f'opacity="{op}"{t} {extra}/>')


def path(d, fill="none", op=1, stroke=None, sw=1, extra=""):
    s = f' stroke="{stroke}" stroke-width="{f(sw)}" stroke-linecap="round" stroke-linejoin="round"' if stroke else ""
    return f'<path d="{d}" fill="{fill}" opacity="{op}"{s} {extra}/>'


def poly(pts, fill, op=1, extra=""):
    p = " ".join(f"{f(x)},{f(y)}" for x, y in pts)
    return f'<polygon points="{p}" fill="{fill}" opacity="{op}" {extra}/>'


def group(body, tx=0, ty=0, s=1, rot=0):
    return f'<g transform="translate({f(tx)} {f(ty)}) rotate({f(rot)}) scale({f(s)})">{body}</g>'


def write(name, content):
    with open(os.path.join(OUT, name + ".svg"), "w") as fh:
        fh.write(content)


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# --------------------------------------------------------------------------- faces
def eye(d, cx, cy, rx, ry, look=(0.3, 0.05), kind="open", lid=0.0):
    """Big cartoon eye. kind: open | closed | dizzy | squint."""
    if kind == "closed":
        return path(f"M{f(cx-rx)} {f(cy+1)} Q{f(cx)} {f(cy-ry*1.1)} {f(cx+rx)} {f(cy+1)}",
                    stroke="#2a1a14", sw=max(2.2, rx * 0.4))
    if kind == "dizzy":
        pts = []
        for i in range(40):
            t = i / 39 * math.pi * 4
            r = rx * 0.85 * (i / 39)
            pts.append(f"{f(cx + r*math.cos(t))} {f(cy + r*math.sin(t))}")
        white = ellipse(cx, cy, rx, ry, d.rad([(0, "#ffffff"), (0.75, "#f4f6fb"), (1, "#c9d3e2")], 0.4, 0.35, 0.7))
        return white + path("M" + " L".join(pts), stroke="#2a1a14", sw=1.8)
    out = ellipse(cx, cy, rx, ry, d.rad([(0, "#ffffff"), (0.7, "#f6f8fc"), (1, "#c3cedf")], 0.42, 0.35, 0.68))
    ir = min(rx, ry) * 0.62
    ix, iy = cx + look[0] * rx, cy + look[1] * ry
    out += circle(ix, iy, ir, d.rad([(0, "#9b6b3c"), (0.6, "#5a3418"), (1, "#2c170a")], 0.45, 0.6, 0.7))
    out += circle(ix, iy, ir * 0.52, "#140a05")
    out += circle(ix - ir * 0.35, iy - ir * 0.38, ir * 0.3, "#ffffff", 0.95)
    out += circle(ix + ir * 0.32, iy + ir * 0.3, ir * 0.13, "#ffffff", 0.8)
    if kind == "squint" or lid > 0:
        amount = 0.45 if kind == "squint" else lid
        top = cy - ry - 1
        cut = cy - ry + 2 * ry * amount
        out += path(f"M{f(cx-rx-1.5)} {f(top)} L{f(cx+rx+1.5)} {f(top)} L{f(cx+rx+1.5)} {f(cut-ry*0.2)} "
                    f"Q{f(cx)} {f(cut+ry*0.25)} {f(cx-rx-1.5)} {f(cut-ry*0.2)} Z", fill="{lidcolor}")
        out += path(f"M{f(cx-rx-1)} {f(cut-ry*0.2)} Q{f(cx)} {f(cut+ry*0.25)} {f(cx+rx+1)} {f(cut-ry*0.2)}",
                    stroke="#2a1a14", sw=1.6, op=0.8)
    return out


def ko_stars(cx, cy, spread=18):
    out = ""
    for i, (dx, dy, s) in enumerate([(-spread, 2, 5), (0, -5, 6), (spread, 1, 5)]):
        out += poly(star_points(cx + dx, cy + dy, s, s * 0.45), "#ffd84a")
        out += poly(star_points(cx + dx - 0.8, cy + dy - 0.8, s * 0.5, s * 0.22), "#fff8c8", 0.9)
    return out


# --------------------------------------------------------------------------- heroes
def hero_stone(d, kind="open"):
    W, H = 80, 80
    cx, cy, r = 40, 44, 30
    b = circle(cx, cy, r, d.rad([(0, "#eef1f5"), (0.4, "#b4bdc8"), (0.82, "#77828f"), (1, "#5a6470")], 0.36, 0.3, 0.78))
    b += path("M18 60 Q40 80 64 58", stroke="#c9d6e4", sw=2.5, op=0.35)
    rnd = random.Random(3)
    for _ in range(12):
        a = rnd.uniform(0, 6.28); rr = rnd.uniform(6, 26)
        b += circle(cx + rr * math.cos(a), cy + rr * math.sin(a), rnd.uniform(0.8, 2.0),
                    rnd.choice(["#6a7480", "#d5dbe2"]), 0.5)
    b += path("M60 28 L55 34 L58 38 L53 44", stroke="#5a6470", sw=1.6, op=0.8)
    b += path("M21 52 L26 55 L24 60", stroke="#5a6470", sw=1.4, op=0.7)
    b += poly([(57, 58), (63, 55), (62, 62)], "#d9dfe6", 0.7)
    moss = d.rad([(0, "#b8f06a"), (0.6, "#6cc23a"), (1, "#3f8a24")], 0.4, 0.3, 0.8)
    b += ellipse(34, 17, 9, 5.5, moss) + ellipse(44, 14.5, 8, 6, moss) + ellipse(50, 18, 6, 4.5, moss)
    b += ellipse(29, 30, 9, 5.5, "#ffffff", 0.45, -30)
    b += circle(23, 39, 2, "#ffffff", 0.45)
    look = (0.32, 0.08)
    b += eye(d, 31, 45, 7.5, 8.5, look, kind, lid=0.25).replace("{lidcolor}", "#98a3b0")
    b += eye(d, 50, 45, 7.5, 8.5, look, kind, lid=0.25).replace("{lidcolor}", "#98a3b0")
    b += path("M22 34 L38 38.5", stroke="#454d58", sw=6)
    b += path("M42 38.5 L58 33", stroke="#454d58", sw=6)
    if kind == "dizzy":
        b += path("M33 62 Q37 58 41 62 Q45 66 49 61", stroke="#3b2626", sw=2.6)
        b += ko_stars(40, 8)
    else:
        b += path("M33 62 Q41 57 49 62", stroke="#3b2626", sw=3)
    return W, H, b


def hero_quake(d, kind="open"):
    W, H, b = hero_stone(d, kind)
    glow = "#74e4ff"
    b += path("M18 48 L28 43 L34 51 L43 35 L50 47 L62 38", stroke="#18384a", sw=5.4, op=0.85)
    b += path("M18 48 L28 43 L34 51 L43 35 L50 47 L62 38", stroke=glow, sw=2.3, op=0.95)
    b += path("M30 67 L37 57 L43 63 L50 52", stroke=glow, sw=2.0, op=0.8)
    b += poly([(31, 17), (38, 3), (44, 18)], d.lin([(0, "#d6fbff"), (0.5, "#69d9f8"), (1, "#2b789e")]),
              extra='stroke="#29485a" stroke-width="1.6" stroke-linejoin="round"')
    b += ellipse(31, 33, 10, 5, "#ffffff", 0.32, -28)
    return W, H, b


def hero_fire(d, kind="open"):
    W, H = 80, 96
    cx, cy, r = 40, 60, 29
    flame = d.lin([(0, "#fff6b0"), (0.35, "#ffc23a"), (0.75, "#ff7a1f"), (1, "#f04a14")], 0, 0, 0, 1)
    inner = d.lin([(0, "#ffffff"), (0.5, "#fff2a0"), (1, "#ffb02e")], 0, 0, 0, 1)
    b = path("M40 36 C25 33 26 18 34 9 C34 16 38 18 40 6 C44 16 50 12 49 4 C58 16 56 32 40 36 Z", flame)
    b += path("M24 38 C16 32 18 24 22 18 C24 26 28 28 30 32 Z", flame, 0.9)
    b += path("M56 38 C64 32 62 23 58 17 C56 25 52 28 50 32 Z", flame, 0.9)
    b += path("M40 34 C33 31 34 24 38 17 C40 23 43 24 44 20 C48 26 46 32 40 34 Z", inner, 0.95)
    b += circle(cx, cy, r, d.rad([(0, "#ffd3a0"), (0.38, "#f58a48"), (0.82, "#c0501f"), (1, "#8e3512")], 0.36, 0.3, 0.78))
    band = d.lin([(0, "#fff4d8"), (1, "#e9c38a")], 0, 0, 0, 1)
    b += path("M12 66 Q40 78 68 66 L67 73 Q40 85 13 73 Z", band)
    b += path("M14 70 Q40 81 66 70", stroke="#c99a5a", sw=1.2, op=0.6)
    b += ellipse(40, 33, 16, 5, "#a8441c") + ellipse(40, 32.5, 12.5, 3.3, "#4a1c08")
    b += ellipse(36, 31.5, 6, 1.2, "#ffd28a", 0.6)
    b += ellipse(28, 46, 9, 5.5, "#ffffff", 0.45, -30)
    b += circle(22, 55, 2, "#ffffff", 0.45)
    look = (0.3, 0.05)
    b += eye(d, 31, 55, 7.5, 8.5, look, kind).replace("{lidcolor}", "#e07a3c")
    b += eye(d, 50, 55, 7.5, 8.5, look, kind).replace("{lidcolor}", "#e07a3c")
    b += path("M22 45 L37 49.5", stroke="#5a1e08", sw=5)
    b += path("M43 49.5 L58 44", stroke="#5a1e08", sw=5)
    b += path("M30 65 Q41 77 52 65 Q41 69 30 65 Z", "#5a1408")
    b += path("M31.5 65.6 Q41 69.2 50.5 65.6 L50 67 Q41 70.5 32 67 Z", "#ffffff")
    b += ellipse(41, 71.5, 4.5, 2, "#ff7a7a")
    return W, H, b


def hero_bomb(d, kind="open"):
    W, H = 80, 96
    cx, cy, r = 40, 59, 29
    b = path("M40 24 C41 14 50 14 52 6", stroke="#7a4a20", sw=3.6)
    b += path("M40 24 C41 14 50 14 52 6", stroke="#c08a50", sw=1.2, op=0.7)
    b += circle(52, 6, 7, d.rad([(0, "#ffffff", 1), (0.3, "#fff27a", 0.9), (1, "#ff8a1f", 0)], 0.5, 0.5, 0.5))
    b += poly(star_points(52, 6, 5.5, 2.2, 4, -45), "#fff6b0")
    b += circle(cx, cy, r, d.rad([(0, "#9aa9c8"), (0.3, "#56658a"), (0.78, "#252e48"), (1, "#141a2a")], 0.36, 0.3, 0.8))
    gold = d.lin([(0, "#fff0a0"), (0.5, "#ffc93a"), (1, "#c48a14")], 0, 0, 0, 1)
    b += rect(30, 24, 20, 10, 3, gold)
    b += ellipse(40, 24.5, 10, 2.5, "#fff6c0", 0.8)
    b += ellipse(27, 44, 10, 6.5, "#ffffff", 0.5, -32)
    b += circle(21, 54, 2.4, "#ffffff", 0.5)
    b += path("M16 72 Q40 92 64 70", stroke="#8fa0c8", sw=2.5, op=0.35)
    look = (0.3, 0.0)
    b += eye(d, 31, 53, 8, 9.5, look, kind).replace("{lidcolor}", "#3a4668")
    b += eye(d, 50, 53, 8, 9.5, look, kind).replace("{lidcolor}", "#3a4668")
    b += path("M23 41 Q30 37 37 41", stroke="#0b0f1a", sw=3.4)
    b += path("M43 41 Q50 37 57 41", stroke="#0b0f1a", sw=3.4)
    b += path("M26 65 Q41 86 56 65 Z", "#4a0e14")
    b += path("M27.5 65.4 Q41 70 54.5 65.4 L54 67.5 Q41 72.5 28 67.5 Z", "#ffffff")
    b += ellipse(41, 76, 6.5, 3, "#ff6f7f")
    return W, H, b


def hero_cyclone(d, kind="open"):
    W, H = 90, 92
    bands = [(45, 24, 33, 11), (45, 38, 28, 10.5), (46.5, 52, 22, 9.5), (48.5, 64, 15, 7.5),
             (51, 74, 9, 5.5), (53.5, 82, 4.5, 3.2)]
    cols = [("#e9fffc", "#9ce8e0", "#5cc9c2"), ("#dafbf6", "#86dcd4", "#4dbab3")]
    b = ""
    for i, (x, y, rx, ry) in enumerate(reversed(bands)):
        c = cols[i % 2]
        b += ellipse(x, y, rx, ry, d.rad([(0, c[0]), (0.6, c[1]), (1, c[2])], 0.38, 0.3, 0.8))
    for (x, y, rx, ry) in bands[:4]:
        b += path(f"M{f(x-rx*0.8)} {f(y+ry*0.1)} Q{f(x)} {f(y+ry*0.95)} {f(x+rx*0.75)} {f(y-ry*0.15)}",
                  stroke="#ffffff", sw=1.8, op=0.6)
    leaf = d.lin([(0, "#b6f36a"), (1, "#3f9a2a")], 0, 0, 1, 1)
    b += path("M6 30 Q12 18 24 22 Q16 34 6 30 Z", leaf) + path("M8 29 Q15 25 22 23", stroke="#2f7a1f", sw=1)
    b += path("M84 60 Q80 72 68 70 Q74 58 84 60 Z", leaf) + path("M82 61 Q76 66 70 69", stroke="#2f7a1f", sw=1)
    b += ellipse(32, 22, 10, 4, "#ffffff", 0.55, -12)
    look = (0.25, 0.1)
    b += eye(d, 36, 36, 6, 7, look, "closed" if kind == "open" else kind).replace("{lidcolor}", "#86dcd4")
    b += eye(d, 54, 36, 6, 7, look, "closed" if kind == "open" else kind).replace("{lidcolor}", "#86dcd4")
    b += path("M39 45 Q45.5 53 52 45 Z", "#2e6b70")
    b += ellipse(45.5, 49, 3, 1.6, "#ff8aa0")
    b += ellipse(30, 43, 3.5, 2, "#ff9fb0", 0.55) + ellipse(60, 43, 3.5, 2, "#ff9fb0", 0.55)
    return W, H, b


# --------------------------------------------------------------------------- story + rescue characters
def wizard(d):
    W, H = 110, 140
    robe = d.lin([(0, "#9b7cff"), (0.5, "#5d45b8"), (1, "#33256f")], 0, 0, 0, 1)
    skin = d.rad([(0, "#fff0df"), (0.7, "#e7b98f"), (1, "#bd815e")], 0.4, 0.3, 0.75)
    b = ellipse(55, 132, 37, 7, "#1b1530", 0.3)
    b += path("M30 68 Q18 102 12 132 L98 132 Q88 96 78 68 Z", robe, extra='stroke="#3a2212" stroke-width="2.4" stroke-linejoin="round"')
    b += path("M45 76 L55 89 L65 76 L61 132 L49 132 Z", "#ffc93a", 0.9)
    for x, y in [(29, 103), (76, 111), (52, 121)]:
        b += poly(star_points(x, y, 5, 2.2), "#ffe681", 0.85)
    b += ellipse(55, 61, 24, 22, skin, extra='stroke="#3a2212" stroke-width="2"')
    b += path("M34 66 Q40 108 55 118 Q70 108 77 66 Q68 78 55 77 Q42 78 34 66 Z", "#f4f1e8", extra='stroke="#706b72" stroke-width="1.6"')
    b += path("M26 50 Q30 17 56 13 Q80 17 86 50 Z", robe, extra='stroke="#3a2212" stroke-width="2.4"')
    b += path("M43 20 Q52 2 77 1 Q66 17 58 28 Z", robe, extra='stroke="#3a2212" stroke-width="2.4"')
    b += rect(23, 47, 66, 10, 5, "#ffc93a", extra='stroke="#3a2212" stroke-width="2"')
    b += poly(star_points(57, 16, 7, 3), "#fff3a0")
    b += eye(d, 47, 59, 5.5, 6.5, (0.2, 0.05)) + eye(d, 64, 59, 5.5, 6.5, (0.2, 0.05))
    b += ellipse(55, 67, 4, 3, "#c98664")
    b += path("M47 73 Q55 79 64 72", stroke="#7a3a32", sw=2.3)
    b += ellipse(41, 48, 9, 4, "#ffffff", 0.35, -25)
    return W, H, b


def captive(d):
    W, H = 84, 96
    skin = d.rad([(0, "#fff0df"), (0.7, "#efc39d"), (1, "#c98b67")], 0.4, 0.3, 0.75)
    tunic = d.lin([(0, "#f3d184"), (0.6, "#b98b43"), (1, "#785428")], 0, 0, 0, 1)
    b = ellipse(31, 91, 10, 5, "#50351f") + ellipse(53, 91, 10, 5, "#50351f")
    b += ellipse(42, 66, 28, 27, tunic, extra='stroke="#3a2212" stroke-width="2"')
    b += path("M17 68 L67 68", stroke="#6e4724", sw=6)
    b += ellipse(42, 43, 22, 20, skin, extra='stroke="#3a2212" stroke-width="2"')
    hair = d.lin([(0, "#8a542d"), (1, "#4b2b18")], 0, 0, 0, 1)
    b += path("M19 43 Q18 16 42 14 Q68 16 65 46 Q57 29 46 31 Q31 30 19 43 Z", hair, extra='stroke="#3a2212" stroke-width="2"')
    b += eye(d, 34, 44, 5.5, 6, (0.25, 0.05)) + eye(d, 51, 44, 5.5, 6, (0.25, 0.05))
    b += path("M34 57 Q42 62 51 56", stroke="#7a3a32", sw=2.4)
    b += circle(19, 70, 5, skin) + circle(66, 70, 5, skin)
    b += ellipse(33, 35, 8, 3, "#ffffff", 0.35, -25)
    return W, H, b


# --------------------------------------------------------------------------- soldiers + archers
def soldier(d, pose="idle"):
    W, H = 84, 96
    boot = d.rad([(0, "#9a6a40"), (1, "#4a2c14")], 0.4, 0.3, 0.8)
    b = ellipse(31, 90, 10, 5.5, boot) + ellipse(52, 90, 10, 5.5, boot)
    b += ellipse(41, 61, 30, 30, d.rad([(0, "#9cc4ff"), (0.4, "#4f8ee8"), (0.85, "#2a5cb4"), (1, "#1d478f")], 0.36, 0.3, 0.8))
    gold = d.lin([(0, "#fff0a0"), (0.5, "#ffc93a"), (1, "#c48a14")], 0, 0, 0, 1)
    b += path("M12 73 Q41 82 70 73 L69 79 Q41 88 13 79 Z", gold)
    b += rect(36, 76, 10, 8, 2, "#b07a14") + rect(38, 78, 6, 4, 1, "#ffe48a")
    skin = d.rad([(0, "#ffeedd"), (0.6, "#ffd2aa"), (1, "#eaa880")], 0.4, 0.35, 0.75)
    b += ellipse(42, 51, 22, 18, skin)
    steel = d.lin([(0, "#ffffff"), (0.35, "#cfd8e2"), (0.8, "#8794a4"), (1, "#66727f")], 0.2, 0, 0.8, 1)
    b += path("M13 44 Q13 15 41 13 Q69 15 69 44 Z", steel)
    b += rect(8, 40, 66, 9, 4.5, gold)
    b += ellipse(30, 22, 9, 4, "#ffffff", 0.6, -20)
    b += circle(41, 12, 3.5, gold)
    b += ellipse(26, 60, 4.5, 2.6, "#ff8a8a", 0.5) + ellipse(57, 60, 4.5, 2.6, "#ff8a8a", 0.5)
    if pose == "ko":
        b += eye(d, 35, 53, 5.5, 6.5, (0, 0), "dizzy") + eye(d, 50, 53, 5.5, 6.5, (0, 0), "dizzy")
        b += path("M36 64 Q40 61 44 64 Q48 67 51 63", stroke="#6a2a1a", sw=2.4)
        b += ko_stars(42, 6)
    elif pose == "cheer":
        b += eye(d, 35, 53, 5.5, 6.5, (0, 0), "closed") + eye(d, 50, 53, 5.5, 6.5, (0, 0), "closed")
        b += path("M34 61 Q43 74 52 61 Z", "#7a1f1a") + ellipse(43, 67, 4, 2, "#ff7a7a")
    else:
        b += eye(d, 35, 53, 5.5, 6.5, (0.35, 0.05)) + eye(d, 50, 53, 5.5, 6.5, (0.35, 0.05))
        b += path("M29 45.5 Q34 43.5 39 45.5", stroke="#5a3418", sw=2.2)
        b += path("M45 45.5 Q50 43.5 55 45.5", stroke="#5a3418", sw=2.2)
        b += path("M37 63 Q44 69 51 62", stroke="#6a2a1a", sw=2.6)
    b += ellipse(45, 58, 3, 2.4, "#eaa07a")
    shield = d.rad([(0, "#8ab8ff"), (0.6, "#3d7fe0"), (1, "#24509a")], 0.38, 0.32, 0.8)
    sy = 58 if pose == "cheer" else 70
    b += circle(69, sy, 15, gold) + circle(69, sy, 12, shield)
    b += poly(star_points(69, sy, 7, 3), "#ffd84a")
    b += ellipse(64, sy - 6, 4, 2, "#ffffff", 0.5, -30)
    return W, H, b


def archer(d, pose="idle"):
    W, H = 96, 96
    ox = 10
    boot = d.rad([(0, "#9a6a40"), (1, "#4a2c14")], 0.4, 0.3, 0.8)
    b = ellipse(ox + 30, 90, 9.5, 5.5, boot) + ellipse(ox + 50, 90, 9.5, 5.5, boot)
    leather = d.lin([(0, "#b07a4a"), (1, "#6a4224")], 0, 0, 1, 0)
    b += path(f"M{ox+56} 46 L{ox+74} 40 L{ox+80} 74 L{ox+64} 78 Z", leather)
    for i, x in enumerate([60, 66, 72]):
        b += path(f"M{ox+x} 44 L{ox+x+6} 26", stroke="#d8b080", sw=2)
        b += poly([(ox + x + 6, 26), (ox + x + 1, 22), (ox + x + 10, 20)], "#e04040" if i != 1 else "#ffffff")
    b += ellipse(ox + 40, 61, 28, 29, d.rad([(0, "#ff8a8a"), (0.4, "#d84050"), (0.85, "#8e1f2a"), (1, "#6a1520")], 0.36, 0.3, 0.8))
    b += path(f"M{ox+13} 74 Q{ox+40} 82 {ox+67} 74 L{ox+66} 79 Q{ox+40} 87 {ox+14} 79 Z", leather)
    hood = d.lin([(0, "#ff7a68"), (0.5, "#e04040"), (1, "#a82a2a")], 0.2, 0, 0.8, 1)
    b += path(f"M{ox+12} 58 Q{ox+7} 22 {ox+38} 15 Q{ox+60} 11 {ox+82} 3 Q{ox+72} 18 {ox+71} 33 "
              f"Q{ox+73} 48 {ox+68} 60 Z", hood)
    skin = d.rad([(0, "#ffeedd"), (0.6, "#ffd2aa"), (1, "#eaa880")], 0.4, 0.35, 0.75)
    b += ellipse(ox + 39, 53, 19, 15.5, skin)
    b += path(f"M{ox+19} 53 Q{ox+39} 30 {ox+59} 53", stroke="#b0302e", sw=4.5)
    b += ellipse(ox + 24, 24, 9, 3.5, "#ffffff", 0.45, -25)
    b += path(f"M{ox+64} 20 Q{ox+78} 12 {ox+88} 18 Q{ox+76} 22 {ox+64} 20 Z", "#d8f04a")
    b += ellipse(ox + 26, 61, 4, 2.4, "#ff8a8a", 0.45) + ellipse(ox + 52, 61, 4, 2.4, "#ff8a8a", 0.45)
    if pose == "ko":
        b += eye(d, ox + 32, 54, 5, 5.8, (0, 0), "dizzy") + eye(d, ox + 47, 54, 5, 5.8, (0, 0), "dizzy")
        b += path(f"M{ox+33} 65 Q{ox+37} 62 {ox+41} 65 Q{ox+45} 68 {ox+48} 64", stroke="#6a2a1a", sw=2.3)
        b += ko_stars(ox + 40, 6)
    else:
        lk = (-0.35, 0.05)
        right_kind = "closed" if pose == "shoot" else "squint"
        b += eye(d, ox + 32, 54, 5, 5.8, lk, "squint").replace("{lidcolor}", "#ffd2aa")
        b += eye(d, ox + 47, 54, 5, 5.8, lk, right_kind).replace("{lidcolor}", "#ffd2aa")
        b += path(f"M{ox+26} 45 L{ox+37} 47.5", stroke="#5a2a14", sw=2.4)
        b += path(f"M{ox+42} 46.5 Q{ox+48} 43 {ox+53} 45", stroke="#5a2a14", sw=2.4)
        if pose == "shoot":
            b += path(f"M{ox+31} 64 Q{ox+38} 67 {ox+44} 63", stroke="#6a2a1a", sw=2.3)
            b += ellipse(ox + 43, 65, 2.4, 1.6, "#ff6f7f")
        else:
            b += path(f"M{ox+31} 63 Q{ox+40} 68 {ox+47} 61", stroke="#6a2a1a", sw=2.4)
    b += ellipse(ox + 33, 59, 2.8, 2.2, "#eaa07a")
    wood = "#8a5226"
    if pose == "shoot":
        b += path(f"M{ox+2} 34 Q{ox-12} 62 {ox+2} 90", stroke=wood, sw=4.2)
        b += path(f"M{ox+2} 34 L{ox+22} 62 L{ox+2} 90", stroke="#f4e8d0", sw=1.2)
        b += path(f"M{ox+22} 62 L{ox-14} 62", stroke="#c8a070", sw=2.4)
        b += poly([(ox - 20, 62), (ox - 12, 58), (ox - 12, 66)], "#b8c4d0")
        b += circle(ox + 22, 62, 4.5, skin)
    elif pose == "idle":
        b += path(f"M{ox+4} 38 Q{ox-8} 62 {ox+4} 86", stroke=wood, sw=4.2)
        b += path(f"M{ox+4} 38 L{ox+4} 86", stroke="#f4e8d0", sw=1.2)
    b += circle(ox + 2, 64, 4.5, skin) if pose != "ko" else ""
    return W, H, b


# --------------------------------------------------------------------------- blocks
def crack_path(rnd, x, y, ang, length, seg=4):
    pts = [(x, y)]
    step = length / seg
    for _ in range(seg):
        ang += rnd.uniform(-0.7, 0.7)
        x += math.cos(ang) * step
        y += math.sin(ang) * step
        pts.append((x, y))
    return "M" + " L".join(f"{f(a)} {f(b)}" for a, b in pts)


def cracks(rnd, w, h, stage, dark, light):
    out = ""
    if stage == 0:
        return out
    count = 2 if stage == 1 else 5
    for i in range(count):
        side = rnd.choice(["t", "b", "l", "r"])
        if side == "t": x, y, a = rnd.uniform(w * 0.15, w * 0.85), 1, math.pi / 2
        elif side == "b": x, y, a = rnd.uniform(w * 0.15, w * 0.85), h - 1, -math.pi / 2
        elif side == "l": x, y, a = 1, rnd.uniform(h * 0.2, h * 0.8), 0
        else: x, y, a = w - 1, rnd.uniform(h * 0.2, h * 0.8), math.pi
        length = min(w, h) * rnd.uniform(0.5, 0.9) if min(w, h) > 40 else max(w, h) * rnd.uniform(0.18, 0.3)
        p = crack_path(rnd, x, y, a, length)
        out += path(p, stroke=light, sw=1.2, op=0.55, extra='transform="translate(0.9 0.9)"')
        out += path(p, stroke=dark, sw=1.8 if stage == 1 else 2.2, op=0.9)
    if stage == 2:
        for (cx, cy) in [(0, 0), (w, h)]:
            sx = 1 if cx == 0 else -1
            sy = 1 if cy == 0 else -1
            s = min(w, h) * 0.35
            out += poly([(cx, cy), (cx + sx * s, cy), (cx, cy + sy * s * 0.8)], dark, 0.35)
    return out


def wood_block(d, w, h, stage, rnd):
    horiz = w >= h
    r = min(7, min(w, h) * 0.3)
    stops = [(0, "#f6c27a"), (0.45, "#d48d48"), (1, "#9a5a2b")]
    base = d.lin(stops, 0, 0, 0, 1) if horiz else d.lin(stops, 0, 0, 1, 0)
    b = rect(0.5, 0.5, w - 1, h - 1, r, base)
    b += rect(1.2, 1.2, w - 2.4, h - 2.4, r, "none", 0.75, 'stroke="#8a4f24" stroke-width="1.6"')
    if horiz:
        b += rect(3, 2.5, w - 6, h * 0.26, r * 0.6, "#ffffff", 0.28)
    else:
        b += rect(2.5, 3, w * 0.26, h - 6, r * 0.6, "#ffffff", 0.28)
    L, T = (w, h) if horiz else (h, w)
    lines = max(2, int(T / 9))
    for i in range(lines):
        off = T * (i + 1) / (lines + 1) + rnd.uniform(-1.5, 1.5)
        pts = []
        for k in range(9):
            t = 6 + (L - 12) * k / 8
            o = off + math.sin(k * 1.3 + i) * 1.2
            pts.append((t, o) if horiz else (o, t))
        b += path("M" + " L".join(f"{f(x)} {f(y)}" for x, y in pts), stroke="#8a4f24", sw=1.1, op=0.35)
    kx, ky = (rnd.uniform(L * 0.3, L * 0.7), T * 0.55)
    if not horiz: kx, ky = ky, kx
    b += ellipse(kx, ky, 3.5 if horiz else 2.2, 2.2 if horiz else 3.5, "#7a4220", 0.5)
    nail = d.rad([(0, "#f2f4f6"), (1, "#7d8590")], 0.35, 0.3, 0.8)
    if horiz and w > 60:
        for x in (8, w - 8):
            b += circle(x, h / 2, 2.4, nail)
        b += path(f"M7 {f(h-4)} L{f(w-7)} {f(h-4)}", stroke="#623416", sw=2.2, op=0.45)
        for x in range(55, int(w), 55):
            b += path(f"M{x} 4 L{x-2} {f(h-4)}", stroke="#6d3819", sw=1.2, op=0.42)
        for x in (3, w - 11):
            b += rect(x, 4, 8, h - 8, 2.5, "#6f553f", 0.5, 'stroke="#3a2212" stroke-width="1"')
            b += circle(x + 4, h / 2, 1.5, "#d8dde2")
    elif not horiz and h > 60:
        for y in (8, h - 8):
            b += circle(w / 2, y, 2.4, nail)
        b += path(f"M{f(w-4)} 7 L{f(w-4)} {f(h-7)}", stroke="#623416", sw=2.2, op=0.45)
        for y in (10, h - 20):
            b += rect(3, y, w - 6, 10, 2.5, "#705640", 0.55, 'stroke="#3a2212" stroke-width="1"')
            b += circle(w / 2, y + 5, 1.6, "#d8dde2")
    b += cracks(rnd, w, h, stage, "#4a2610", "#ffd9a0")
    return b


def crate_block(d, w, h, stage, rnd):
    frame = d.lin([(0, "#f6c27a"), (0.5, "#d48d48"), (1, "#a8662f")], 0, 0, 0, 1)
    b = rect(0.5, 0.5, w - 1, h - 1, 7, frame)
    inset = 9
    b += rect(inset, inset, w - 2 * inset, h - 2 * inset, 3,
              d.lin([(0, "#8a4f24"), (1, "#b06c34")], 0, 0, 0, 1))
    for i in range(1, 3):
        y = inset + (h - 2 * inset) * i / 3
        b += path(f"M{inset} {f(y)} L{w-inset} {f(y)}", stroke="#6a3a18", sw=1.2, op=0.6)
    ang = math.degrees(math.atan2(h - 2 * inset, w - 2 * inset))
    diag = math.hypot(w - 2 * inset, h - 2 * inset)
    b += f'<g transform="translate({w/2} {h/2}) rotate({f(ang)})">' + \
         rect(-diag / 2, -5, diag, 10, 3, d.lin([(0, "#f2b870"), (1, "#c07a3c")], 0, 0, 0, 1)) + "</g>"
    b += rect(3, 2.5, w - 6, 4, 2, "#ffffff", 0.3)
    b += rect(1.2, 1.2, w - 2.4, h - 2.4, 7, "none", 0.7, 'stroke="#8a4f24" stroke-width="1.6"')
    nail = d.rad([(0, "#f2f4f6"), (1, "#7d8590")], 0.35, 0.3, 0.8)
    for x, y in [(5, 5), (w - 5, 5), (5, h - 5), (w - 5, h - 5)]:
        b += circle(x, y, 2.2, nail)
    b += cracks(rnd, w, h, stage, "#4a2610", "#ffd9a0")
    return b


def stone_block(d, w, h, stage, rnd):
    b = rect(0.5, 0.5, w - 1, h - 1, 8, d.lin([(0, "#7d8794"), (1, "#525b66")], 0, 0, 0, 1))
    rows = max(1, round(h / 32))
    rh = h / rows
    for ri in range(rows):
        cols = max(1, round(w / 60))
        bw = w / cols
        shift = (bw / 2) if (ri % 2 and cols > 1) else 0
        xs = []
        x = -shift
        while x < w - 0.1:
            xs.append((max(0, x), min(w, x + bw)))
            x += bw
        for (x0, x1) in xs:
            if x1 - x0 < 8:
                continue
            g = 2.2
            tint = rnd.choice([("#e8ecf0", "#b0bac6", "#8a95a2"), ("#dde3ea", "#a6b1be", "#7f8a98"),
                               ("#eef1f4", "#b8c1cc", "#909aa6")])
            fill = d.lin([(0, tint[0]), (0.5, tint[1]), (1, tint[2])], 0, 0, 0.3, 1)
            bx, by, bw2, bh2 = x0 + g, ri * rh + g, x1 - x0 - 2 * g, rh - 2 * g
            b += rect(bx, by, bw2, bh2, 5, fill, extra='stroke="#3d4048" stroke-width="1.8"')
            b += rect(bx + 2, by + 1.5, bw2 - 4, bh2 * 0.25, 3, "#ffffff", 0.35)
            if rnd.random() < 0.6:
                b += circle(bx + rnd.uniform(4, bw2 - 4), by + rnd.uniform(bh2 * 0.4, bh2 - 4),
                            rnd.uniform(1, 2), "#6f7b89", 0.5)
    b += path(f"M5 {f(h-4)} L{f(w-5)} {f(h-4)}", stroke="#424a54", sw=2.4, op=0.5)
    b += path(f"M{f(w-4)} 6 L{f(w-4)} {f(h-6)}", stroke="#424a54", sw=2.0, op=0.38)
    if w >= 60 and h >= 60 and stage == 0:
        b += path(f"M5 8 Q14 3 24 7 Q20 11 8 13 Z", "#6e9b43", 0.55)
        b += circle(13, 8, 2.2, "#b6d66c", 0.65)
    b += cracks(rnd, w, h, stage, "#333b45", "#f0f4f8")
    return b


def roof_block(d, w, h, stage, rnd):
    straw = d.lin([(0, "#ffe9a0"), (0.45, "#f0bf55"), (1, "#b47a26")], 0, 0, 0.4, 1)
    tri = f"M5 {h-1} L{w/2-4} 4 Q{w/2} 0 {w/2+4} 4 L{w-5} {h-1} Q{w-3} {h} {w-6} {h} L6 {h} Q3 {h} 5 {h-1} Z"
    b = path(tri, straw)
    for i in range(14):
        t = (i + 0.5) / 14
        x_b = 8 + (w - 16) * t
        b += path(f"M{f(w/2 + (x_b-w/2)*0.12)} {f(h*0.12)} L{f(x_b)} {f(h-3)}", stroke="#a8701e", sw=1.2, op=0.45)
    for i in range(3):
        y = h * (0.35 + i * 0.22)
        half = (w / 2 - 6) * (y / h)
        b += path(f"M{f(w/2-half)} {f(y)} Q{f(w/2)} {f(y+4)} {f(w/2+half)} {f(y)}", stroke="#c88a2a", sw=2.2, op=0.6)
    zz = " ".join(f"L{f(6 + i*(w-12)/16)} {f(h - (3 if i%2 else 0))}" for i in range(17))
    b += path(f"M6 {h} {zz}", stroke="#9a6418", sw=1.6, op=0.7)
    b += path(f"M{w/2-3} 8 L14 {h-6}", stroke="#ffffff", sw=3, op=0.3)
    if stage:
        for _ in range(2 if stage == 1 else 5):
            t = rnd.uniform(0.3, 0.85)
            x = w / 2 + rnd.uniform(-1, 1) * (w / 2 - 14) * t
            b += ellipse(x, h * t, rnd.uniform(4, 7), rnd.uniform(2.5, 4.5), "#5a3a12", 0.55)
    return b


def barrel_block(d, w, h, stage, rnd):
    body = d.lin([(0, "#7a1520"), (0.3, "#e04040"), (0.42, "#ff8a7a"), (0.7, "#c43030"), (1, "#6e1218")], 0, 0, 1, 0)
    b = path(f"M6 4 Q0 {h/2} 6 {h-4} Q{w/2} {h+2} {w-6} {h-4} Q{w} {h/2} {w-6} 4 Q{w/2} -2 6 4 Z", body)
    hoop = d.lin([(0, "#5a6470"), (0.4, "#c9d1da"), (1, "#3c444e")], 0, 0, 1, 0)
    for y in (12, h - 12):
        b += path(f"M3.2 {y} Q{w/2} {y+4} {w-3.2} {y} L{w-3} {y+4.5} Q{w/2} {y+8.5} 3 {y+4.5} Z", hoop)
    b += ellipse(w / 2, 4.5, w / 2 - 7, 3.5, "#5a1810")
    b += circle(w / 2, h / 2 + 1, 8.5, "#2a1410")
    b += path(f"M{w/2} {h/2-6} C{w/2-6} {h/2} {w/2-4} {h/2+6} {w/2} {h/2+6} C{w/2+4} {h/2+6} {w/2+6} {h/2} {w/2} {h/2-6} Z", "#ffc93a")
    b += path(f"M{w/2} {h/2-1} C{w/2-2.5} {h/2+2} {w/2-1.5} {h/2+5} {w/2} {h/2+5} C{w/2+1.5} {h/2+5} {w/2+2.5} {h/2+2} {w/2} {h/2-1} Z", "#fff3a0")
    b += rect(9, 8, 5, h - 18, 2.5, "#ffffff", 0.25)
    b += cracks(rnd, w, h, stage, "#3a0a0a", "#ffb0a0")
    return b




def crystal_block(d, w, h, stage, rnd):
    """Brittle glowing crystal: faceted shards, shatters into sharp debris (Crystal Mines)."""
    b = rect(0.5, 0.5, w - 1, h - 1, 6, d.lin([(0, "#3c2a6e"), (1, "#1c1438")], 0, 0, 0, 1))
    cols = max(2, round(w / 22))
    for i in range(cols):
        x0 = w * i / cols
        x1 = w * (i + 1) / cols
        top = rnd.uniform(2, h * 0.25)
        tint = rnd.choice([("#e9fbff", "#7fe6ff", "#2f7fd8"), ("#f4e8ff", "#c69cff", "#6a3fd0"),
                           ("#e8fff8", "#6ff0d0", "#1f8f9a")])
        fill = d.lin([(0, tint[0]), (0.45, tint[1]), (1, tint[2])], 0, 0, 0.6, 1)
        pts = [(x0 + 1.5, h - 2), (x0 + 1.5, top + 8), ((x0 + x1) / 2, top), (x1 - 1.5, top + 8), (x1 - 1.5, h - 2)]
        b += poly(pts, fill, 0.95, 'stroke="#2a1a50" stroke-width="1.6" stroke-linejoin="round"')
        b += path(f"M{f(x0 + 4)} {f(top + 10)} L{f(x0 + 4)} {f(h - 8)}", stroke="#ffffff", sw=2, op=0.55)
    b += ellipse(w * 0.3, h * 0.3, w * 0.18, h * 0.12, "#ffffff", 0.25, -20)
    b += cracks(rnd, w, h, stage, "#1a0f33", "#e0f8ff")
    return b


def iron_block(d, w, h, stage, rnd):
    """Riveted iron plate: heavy and tough, only bombs and quakes really dent it (Foundry)."""
    b = rect(0.5, 0.5, w - 1, h - 1, 5, d.lin([(0, "#b9c2cc"), (0.45, "#6c7783"), (1, "#353d47")], 0, 0, 0.3, 1))
    b += rect(4, 4, w - 8, h - 8, 3, "none", 0.7, 'stroke="#2a3038" stroke-width="1.6"')
    b += rect(5, 3, w - 10, min(6, h * 0.2), 2, "#ffffff", 0.3)
    step = 22 if max(w, h) > 80 else 16
    for x in range(8, int(w) - 4, step):
        for y in (7, h - 7):
            if 4 < y < h - 3:
                b += circle(x, y, 2.4, "#e3e8ee", extra='stroke="#2a3038" stroke-width="0.8"')
    if h > 40:
        for y in range(16, int(h) - 10, step):
            for x in (7, w - 7):
                b += circle(x, y, 2.4, "#e3e8ee", extra='stroke="#2a3038" stroke-width="0.8"')
    b += path(f"M6 {f(h*0.6)} L{f(w-6)} {f(h*0.6)}", stroke="#ff8a3a", sw=1.4, op=0.35)
    b += cracks(rnd, w, h, stage, "#1e242b", "#c9d1da")
    return b


def boulder_block(d, w, h, stage, rnd):
    """Round boulder hung from ropes; circle collider."""
    r = w / 2 - 1
    pts = []
    for k in range(14):
        a = k * math.tau / 14
        rr = r * rnd.uniform(0.9, 1.0)
        pts.append((w / 2 + rr * math.cos(a), h / 2 + rr * math.sin(a)))
    b = poly(pts, d.rad([(0, "#e4dccf"), (0.55, "#9b8f80"), (1, "#5a5046")], 0.35, 0.3, 0.8), extra=ol(2.6))
    for _ in range(5):
        x, y = rnd.uniform(w * 0.25, w * 0.75), rnd.uniform(h * 0.3, h * 0.8)
        b += ellipse(x, y, rnd.uniform(4, 9), rnd.uniform(3, 6), "#6a5f52", 0.45, rnd.uniform(0, 180))
    b += ellipse(w * 0.36, h * 0.3, w * 0.16, h * 0.08, "#ffffff", 0.35, -25)
    b += path(f"M{w*0.2} {h*0.62} Q{w*0.5} {h*0.5} {w*0.8} {h*0.6}", stroke="#cbd2da", sw=5, op=0.0)
    b += cracks(rnd, w, h, stage, "#3a3029", "#f4ece0")
    return b

def ice_block(d, w, h, stage, rnd):
    """Frozen ice: pale translucent blue, frosty top, trapped bubbles. Slippery, shatters into shards."""
    b = rect(0.5, 0.5, w - 1, h - 1, 6, d.lin([(0, "#f2fdff"), (0.35, "#b8ecff"), (1, "#5fb4e8")], 0, 0, 0.4, 1), 0.95)
    for _ in range(max(2, int(w * h / 900))):
        x0 = rnd.uniform(4, w - 10)
        y0 = rnd.uniform(6, h - 8)
        L = rnd.uniform(8, min(w, h) * 0.6 + 8)
        b += path(f"M{f(x0)} {f(y0)} L{f(x0 + L * 0.5)} {f(y0 + L * 0.35)}", stroke="#ffffff", sw=1.4, op=0.55)
    for _ in range(max(2, int(w * h / 1400))):
        b += circle(rnd.uniform(6, w - 6), rnd.uniform(8, h - 6), rnd.uniform(1.2, 3.0), "#ffffff", 0.5)
    b += rect(3, 2, w - 6, min(7, h * 0.22), 3, "#ffffff", 0.75)
    for x in range(6, int(w) - 4, 14):
        b += path(f"M{x} {f(min(7, h * 0.22) + 1)} q2 {f(rnd.uniform(3, 7))} 4 0", "#ffffff", 0.7)
    b += path(f"M5 {f(h - 5)} L{f(w * 0.45)} {f(h * 0.25)}", stroke="#ffffff", sw=3, op=0.3)
    b += cracks(rnd, w, h, stage, "#2a6a9a", "#ffffff")
    return b


def rune_block(d, w, h, stage, rnd):
    """Rune crystal: a violet stone socket holding a glowing gem. Absorbs blasts and fires a beam."""
    b = rect(0.5, 0.5, w - 1, h - 1, 9, d.lin([(0, "#7a6a9a"), (1, "#3a2c58")], 0, 0, 0, 1))
    b += rect(4, 4, w - 8, h - 8, 7, "none", 0.8, 'stroke="#2a1d40" stroke-width="1.5"')
    for (x, y) in [(9, 9), (w - 9, 9), (9, h - 9), (w - 9, h - 9)]:
        b += path(f"M{f(x - 3)} {f(y)} L{f(x)} {f(y - 3)} L{f(x + 3)} {f(y)} L{f(x)} {f(y + 3)} Z", "#c8a8ff", 0.8)
    cx, cy = w / 2, h / 2
    rx, ry = w * 0.3, h * 0.36
    b += circle(cx, cy, max(rx, ry) * 1.05, d.rad([(0, "#ffffff", 0.9), (0.4, "#c58bff", 0.6), (1, "#7a3cff", 0)], 0.5, 0.5, 0.5))
    gem = [(cx, cy - ry), (cx + rx, cy - ry * 0.3), (cx + rx * 0.7, cy + ry), (cx - rx * 0.7, cy + ry), (cx - rx, cy - ry * 0.3)]
    b += poly(gem, d.lin([(0, "#fbf2ff"), (0.4, "#d49bff"), (1, "#6a2fd8")], 0, 0, 0.5, 1), 1,
              f'stroke="{OL}" stroke-width="2" stroke-linejoin="round"')
    b += poly([(cx, cy - ry), (cx + rx * 0.35, cy - ry * 0.3), (cx, cy + ry), (cx - rx * 0.35, cy - ry * 0.3)], "#ffffff", 0.35)
    b += path(f"M{f(cx - rx)} {f(cy - ry * 0.3)} L{f(cx + rx)} {f(cy - ry * 0.3)}", stroke="#ffffff", sw=1.2, op=0.6)
    b += cracks(rnd, w, h, stage, "#1a0f33", "#e8d8ff")
    return b


def iron_bent_block(d, w, h, stage, rnd, angle=16):
    """Iron beam bent into a V by a hard hit. The SVG is centred on the beam's original centre.
    Each half is a riveted plate rotated around the middle joint (matches Block._make_v_collider)."""
    W, H, cw, ch = bent_box(w, h, angle)
    half = Doc(d.pfx + "h")
    plate = iron_block(half, w / 2, h, stage, rnd) + rect(1.1, 1.1, w / 2 - 2.2, h - 2.2, 6, "none", 1, ol(2.2))
    d.defs += half.defs
    a = w / 4 * math.cos(math.radians(angle))
    dd = w / 4 * math.sin(math.radians(angle))
    b = ""
    for sx, rot in [(-1, angle), (1, -angle)]:
        b += (f'<g transform="translate({f(W / 2 + sx * a)} {f(H / 2 + dd)}) rotate({f(rot)}) '
              f'translate({f(-w / 4)} {f(-h / 2)})">{plate}</g>')
    b += circle(W / 2, H / 2 + 2 * dd, h * 0.32, "#3c444e", 1, ol(1.6))
    b += circle(W / 2, H / 2 + 2 * dd, h * 0.14, "#c9d1da")
    return b


def bent_box(w, h, angle):
    """Canvas size of a bent beam, symmetric around its original centre."""
    t = math.radians(angle)
    W = w * math.cos(t) + h * math.sin(t) + 6
    reach = w / 2 * math.sin(t) + h / 2 * math.cos(t) + 4
    return math.ceil(W), math.ceil(reach * 2), W / 2, reach


def core_block(d, w, h, stage, rnd):
    """Power core: a glowing blue orb in an iron cage. While a core stands the boss is shielded."""
    iron = d.lin([(0, "#dfe4e9"), (0.5, "#7d8792"), (1, "#343d47")], 0, 0, 1, 1)
    b = rect(0.5, 0.5, w - 1, h - 1, 8, iron)
    b += rect(7, 7, w - 14, h - 14, 6, "#1c1430")
    glow = [(0, "#ffffff"), (0.35, "#9af6ff"), (0.75, "#2aa8ff"), (1, "#1a3a9a")] if stage < 2 else \
           [(0, "#e8f4ff"), (0.4, "#6ab0e0"), (1, "#1a2a6a")]
    b += circle(w / 2, h / 2, min(w, h) * 0.3, d.rad(glow, 0.5, 0.45, 0.6), extra=ol(2))
    for x in (w * 0.31, w * 0.5, w * 0.69):
        b += rect(x - 2, 5, 4, h - 10, 2, iron, extra=ol(1.2))
    for (x, y) in ((8, 8), (w - 8, 8), (8, h - 8), (w - 8, h - 8)):
        b += circle(x, y, 3.2, "#eef2f5", extra=ol(1))
    b += ellipse(w * 0.4, h * 0.38, 6, 3.5, "#ffffff", 0.8, -30)
    b += cracks(rnd, w, h, stage, "#0e1a3a", "#bff4ff")
    return b


def cannon_block(d, w, h, stage, rnd):
    """Cannon turret on a carriage, barrel pointing left at the player's soldiers."""
    wood = d.lin([(0, "#c88a4c"), (1, "#6e3e1c")])
    b = rect(w * 0.29, h * 0.5, w * 0.67, h * 0.37, 6, wood, extra=ol(2.6))
    for x in (w * 0.42, w * 0.8):
        b += circle(x, h * 0.83, h * 0.15, d.lin([(0, "#8a5a30"), (1, "#4a2c14")]), extra=ol(2))
    b += path(f"M{f(w*0.07)} {f(h*0.23)} L{f(w*0.69)} {f(h*0.13)} Q{f(w*0.87)} {f(h*0.13)} {f(w*0.89)} {f(h*0.37)} "
              f"Q{f(w*0.87)} {f(h*0.6)} {f(w*0.69)} {f(h*0.57)} L{f(w*0.07)} {f(h*0.47)} Z",
              d.lin([(0, "#7d8792"), (0.45, "#3e4650"), (1, "#20262c")], 0, 0, 0, 1), extra=ol(3))
    b += rect(1.5, h * 0.18, w * 0.11, h * 0.33, 3, "#2a3038", extra=ol(2))
    b += rect(w * 0.33, h * 0.15, 6, h * 0.4, 2, "#b0b8c0", extra=ol(1.4))
    b += path(f"M{f(w*0.16)} {f(h*0.25)} L{f(w*0.64)} {f(h*0.18)}", stroke="#ffffff", sw=2.4, op=0.45)
    b += cracks(rnd, w * 0.9, h * 0.55, stage, "#14181c", "#c9d1da")
    return b


def chest_block(d, w, h, stage, rnd):
    """Treasure chest: red wood, gold bands and lock, a glint of coins at the lid seam."""
    wood = d.lin([(0, "#e0603a"), (0.5, "#a82a1e"), (1, "#5e1410")])
    gold = d.lin([(0, "#fff3a0"), (0.5, "#ffc93a"), (1, "#b87a14")])
    b = rect(0.5, h * 0.36, w - 1, h * 0.64 - 0.5, 6, wood)
    b += path(f"M1 {f(h*0.4)} Q1 1 {f(w/2)} 1 Q{f(w-1)} 1 {f(w-1)} {f(h*0.4)} Z", wood, extra=ol(2.2))
    for x in (w * 0.18, w * 0.82):
        b += rect(x - 4, 2, 8, h - 3, 2, gold, extra=ol(1.4))
    b += rect(1, h * 0.36, w - 2, 6, 2, gold, extra=ol(1.4))
    b += rect(w / 2 - 7, h * 0.32, 14, 16, 3, gold, extra=ol(1.6)) + circle(w / 2, h * 0.32 + 9, 2.4, "#3a2212")
    b += ellipse(w * 0.35, h * 0.16, 9, 3, "#ffffff", 0.45, -10)
    b += cracks(rnd, w, h, stage, "#3a0e08", "#ffb08a")
    return b


def log_block(d, w, h, stage, rnd):
    """Log seen end-on (rolls): bark ring, pale wood face with growth rings. Also the giant wheel."""
    r = w / 2 - 1.5
    b = circle(w / 2, h / 2, r, d.rad([(0, "#8a5a30"), (1, "#4a2c14")], 0.4, 0.35, 0.8), extra=ol(2.6))
    b += circle(w / 2, h / 2, r * 0.82, d.rad([(0, "#f6d8a0"), (0.7, "#e0b070"), (1, "#c08850")], 0.4, 0.35, 0.8))
    for k in (0.62, 0.44, 0.26):
        b += circle(w / 2 + rnd.uniform(-1, 1), h / 2 + rnd.uniform(-1, 1), r * k, "none", 0.8, 'stroke="#a8743a" stroke-width="1.6"')
    b += circle(w / 2, h / 2, r * 0.08, "#8a5a30")
    b += ellipse(w * 0.36, h * 0.3, w * 0.12, h * 0.06, "#ffffff", 0.3, -25)
    b += cracks(rnd, w, h, stage, "#5a3214", "#fff0d0")
    return b


def wheel_block(d, w, h, stage, rnd):
    """Giant wooden wheel: iron tyre, spokes, hub."""
    cx, cy, r = w / 2, h / 2, w / 2 - 2
    b = circle(cx, cy, r, d.lin([(0, "#9aa4ae"), (1, "#4a5562")]), extra=ol(3))
    b += circle(cx, cy, r - 9, d.rad([(0, "#c88a4c"), (1, "#7a4220")], 0.4, 0.35, 0.8), extra=ol(2))
    b += circle(cx, cy, r - 24, "#3a2212", 0.85)
    for k in range(8):
        a = k * math.pi / 4
        x1, y1 = cx + (r - 12) * math.cos(a), cy + (r - 12) * math.sin(a)
        b += path(f"M{f(cx)} {f(cy)} L{f(x1)} {f(y1)}", stroke="#3a2212", sw=13) + path(f"M{f(cx)} {f(cy)} L{f(x1)} {f(y1)}", stroke="#d48d48", sw=8)
    b += circle(cx, cy, r * 0.18, d.rad([(0, "#e6ebf0"), (1, "#4a5562")], 0.35, 0.3, 0.8), extra=ol(2))
    b += cracks(rnd, w, h, stage, "#3a2212", "#ffe0b0")
    return b


def cart_block(d, w, h, stage, rnd):
    """Mine cart: iron tub with rivets, heaped ore, two small wheels."""
    iron = d.lin([(0, "#b8c2cc"), (0.5, "#6a7682"), (1, "#3a434e")], 0, 0, 0, 1)
    b = ""
    for x in (w * 0.24, w * 0.76):
        b += circle(x, h - 11, 10, "#2a3038", extra=ol(2)) + circle(x, h - 11, 4, "#c9d1da")
    b += poly([(4, h * 0.3), (w - 4, h * 0.3), (w - 14, h - 14), (14, h - 14)], iron, extra=ol(2.6))
    for x in range(14, int(w) - 10, 18):
        b += circle(x, h * 0.4, 2.2, "#e3e8ee", extra='stroke="#2a3038" stroke-width="0.7"')
    for _ in range(9):
        x = rnd.uniform(w * 0.15, w * 0.85)
        y = h * 0.3 - rnd.uniform(2, 14)
        b += circle(x, y, rnd.uniform(6, 10), rnd.choice(["#7a6a5a", "#9a8a78", "#ffd23a", "#6ad0ff"]), extra=ol(1.4))
    b += path(f"M8 {f(h*0.33)} L{f(w-8)} {f(h*0.33)}", stroke="#ffffff", sw=2.4, op=0.4)
    b += cracks(rnd, w, h * 0.8, stage, "#14181c", "#c9d1da")
    return b


def bell_block(d, w, h, stage, rnd):
    """Bronze bell: crown loop, flared lip, clapper."""
    bronze = d.lin([(0, "#ffe08a"), (0.45, "#d49a2a"), (1, "#7a4a10")], 0, 0, 1, 0.3)
    b = rect(w / 2 - 12, 1, 24, 16, 8, "none", 1, f'stroke="{OL}" stroke-width="7"') + rect(w / 2 - 12, 1, 24, 16, 8, "none", 1, 'stroke="#c88a2a" stroke-width="4"')
    b += path(f"M{f(w*0.3)} 14 Q{f(w*0.22)} {f(h*0.55)} 4 {f(h-10)} L{f(w-4)} {f(h-10)} Q{f(w*0.78)} {f(h*0.55)} {f(w*0.7)} 14 Q{f(w/2)} 6 {f(w*0.3)} 14 Z", bronze, extra=ol(2.6))
    b += rect(2, h - 14, w - 4, 10, 5, d.lin([(0, "#f0c060"), (1, "#8a5a14")]), extra=ol(2))
    b += circle(w / 2, h - 4, 7, "#5a3a10", extra=ol(1.6))
    b += path(f"M{f(w*0.36)} 22 Q{f(w*0.3)} {f(h*0.5)} {f(w*0.2)} {f(h*0.8)}", stroke="#ffffff", sw=4, op=0.35)
    b += cracks(rnd, w, h * 0.85, stage, "#4a2a08", "#fff0b0")
    return b


def cage_block(d, w, h, stage, rnd):
    """Iron cage packed with rubble: frame, bars, ring on top."""
    b = rect(2, 6, w - 4, h - 8, 6, "#3a2c22", 0.85, extra=ol(2.6))
    for _ in range(7):
        b += circle(rnd.uniform(16, w - 16), rnd.uniform(h * 0.45, h - 16), rnd.uniform(9, 14), rnd.choice(["#8a7a66", "#a69580", "#6a5c4c"]), extra=ol(1.2))
    for x in range(12, int(w) - 6, 15):
        b += rect(x - 2.5, 6, 5, h - 8, 2, d.lin([(0, "#c9d1da"), (1, "#4a5562")], 0, 0, 1, 0), extra=ol(1))
    for y in (6, h - 10):
        b += rect(2, y, w - 4, 8, 3, d.lin([(0, "#c9d1da"), (1, "#4a5562")]), extra=ol(1.6))
    b += circle(w / 2, 6, 6, "none", 1, f'stroke="{OL}" stroke-width="5"')
    b += cracks(rnd, w, h, stage, "#14181c", "#c9d1da")
    return b


def iron_ball_block(d, w, h, stage, rnd):
    """Wrecking ball: dark iron sphere, rivet band, eye on top."""
    r = w / 2 - 2
    b = circle(w / 2, h / 2, r, d.rad([(0, "#a8b2bc"), (0.5, "#4a5562"), (1, "#1e242b")], 0.35, 0.3, 0.8), extra=ol(3))
    b += path(f"M{f(w/2 - r)} {f(h/2)} Q{f(w/2)} {f(h/2 + r*0.35)} {f(w/2 + r)} {f(h/2)}", stroke="#2a3038", sw=7)
    for k in range(7):
        x = w / 2 - r * 0.8 + k * r * 0.27
        b += circle(x, h / 2 + r * 0.17 - abs(x - w / 2) * 0.12, 2.6, "#c9d1da")
    b += ellipse(w * 0.36, h * 0.3, w * 0.13, h * 0.07, "#ffffff", 0.45, -30)
    b += cracks(rnd, w, h, stage, "#0e1216", "#c9d1da")
    return b


BLOCK_DRAW = {"wood": wood_block, "crate": crate_block, "stone": stone_block, "straw": roof_block, "barrel": barrel_block,
              "tile": lambda *a: tile_roof_block(*a), "crystal": crystal_block, "iron": iron_block,
              "boulder": boulder_block, "ice": ice_block, "rune": rune_block, "iron_bent": iron_bent_block,
              "core": core_block, "cannon": cannon_block, "chest": chest_block, "log": log_block, "wheel": wheel_block,
              "cart": cart_block, "bell": bell_block, "cage": cage_block, "iron_ball": iron_ball_block}
SHAPES = {
    "plank_long": ("wood", 220, 26), "plank_short": ("wood", 110, 26), "post": ("wood", 26, 120),
    "post_tall": ("wood", 26, 200), "crate": ("crate", 64, 64), "stone_block": ("stone", 64, 64),
    "stone_slab": ("stone", 180, 40), "stone_pillar": ("stone", 40, 140), "roof": ("straw", 140, 70),
    "barrel": ("barrel", 46, 58), "roof_tile": ("tile", 250, 100), "plank_xl": ("wood", 330, 26),
    "crystal_block": ("crystal", 64, 64), "crystal_pillar": ("crystal", 40, 140), "iron_block": ("iron", 64, 64),
    "iron_beam": ("iron", 220, 26), "boulder": ("boulder", 90, 90),
    "ice_block": ("ice", 64, 64), "ice_slab": ("ice", 180, 40), "ice_pillar": ("ice", 40, 140),
    "rune_crystal": ("rune", 64, 64), "iron_beam_bent": ("iron_bent", 220, 26),
    "power_core": ("core", 72, 72), "cannon_turret": ("cannon", 90, 60),
    "treasure_chest": ("chest", 70, 56),
    "log": ("log", 84, 84), "wheel": ("wheel", 180, 180), "cart": ("cart", 130, 70), "bell": ("bell", 110, 120),
    "domino": ("stone", 36, 200), "cage": ("cage", 100, 100), "iron_ball": ("iron_ball", 110, 110),
}


def debris():
    rnd = random.Random(11)
    for i in range(3):
        d = Doc("w")
        L = 26 + i * 6
        pts = [(0, 3), (L * 0.3, 0), (L, 2 + i), (L * 0.8, 7), (L * 0.2, 8)]
        write(f"debris_wood_{i}", d.svg(L, 9, poly(pts, d.lin([(0, "#f2b870"), (1, "#9a5a2b")]))
                                    + path(f"M2 4 L{L-3} 4", stroke="#8a4f24", sw=1, op=0.5)))
        d = Doc("s")
        s = 16 + i * 4
        pts = [(s * 0.5 + s * 0.5 * math.cos(a) * rnd.uniform(0.7, 1.0), s * 0.5 + s * 0.5 * math.sin(a) * rnd.uniform(0.7, 1.0))
               for a in [k * 6.28 / 6 for k in range(6)]]
        write(f"debris_stone_{i}", d.svg(s, s, poly(pts, d.lin([(0, "#e2e7ed"), (1, "#7f8a98")], 0, 0, 0.4, 1))))
        d = Doc("c")
        pts = [(0, 6), (8 + i * 2, 0), (16 + i * 2, 4), (10, 12)]
        write(f"debris_clay_{i}", d.svg(18 + i * 2, 13, poly(pts, d.lin([(0, "#ffb070"), (1, "#a8441c")]))))
        d = Doc("y")
        L = 14 + i * 5
        write(f"debris_crystal_{i}", d.svg(L, L * 1.6, poly([(L / 2, 0), (L, L * 0.6), (L / 2, L * 1.6), (0, L * 0.6)],
                                     d.lin([(0, "#f0fcff"), (0.5, "#8fe8ff"), (1, "#7a4fe0")], 0, 0, 0.5, 1),
                                     extra='stroke="#2a1a50" stroke-width="1"')))
        d = Doc("r")
        L = 14 + i * 5
        write(f"debris_iron_{i}", d.svg(L + 4, L, poly([(0, 2), (L, 0), (L + 4, L * 0.7), (3, L)],
                                  d.lin([(0, "#c9d1da"), (1, "#3c444e")]), extra='stroke="#1e242b" stroke-width="1"')))
        d = Doc("e")
        L = 12 + i * 5
        write(f"debris_ice_{i}", d.svg(L, L * 1.3, poly([(L * 0.3, 0), (L, L * 0.4), (L * 0.7, L * 1.3), (0, L * 0.9)],
                                 d.lin([(0, "#ffffff"), (0.5, "#bfefff"), (1, "#5fb4e8")], 0, 0, 0.5, 1),
                                 extra='stroke="#2a6a9a" stroke-width="1"')))
        d = Doc("t")
        write(f"debris_straw_{i}", d.svg(24, 6, path(f"M1 3 Q12 {1+i} 23 3", stroke="#e8b44a", sw=2.4)))


# --------------------------------------------------------------------------- catapult, arrow, fx
def catapult():
    d = Doc("k")
    W, H = 240, 150
    wood = d.lin([(0, "#f2b870"), (0.5, "#c97f40"), (1, "#8a4f24")], 0, 0, 0, 1)
    woodv = d.lin([(0, "#f2b870"), (0.5, "#c97f40"), (1, "#8a4f24")], 0, 0, 1, 0)
    iron = d.rad([(0, "#e6ebf0"), (0.6, "#8a96a3"), (1, "#4a5562")], 0.35, 0.3, 0.8)
    b = rect(34, 52, 9, 50, 3, woodv)
    b += path("M43 54 L72 62 L43 72 Z", d.lin([(0, "#7fb2ff"), (1, "#2a5cb4")], 0, 0, 1, 0))
    b += poly(star_points(52, 63, 4.5, 2), "#ffd84a")

    def beam(x0, y0, x1, y1, t, fill):
        a = math.degrees(math.atan2(y1 - y0, x1 - x0))
        L = math.hypot(x1 - x0, y1 - y0)
        return f'<g transform="translate({f(x0)} {f(y0)}) rotate({f(a)})">' + rect(0, -t / 2, L, t, t / 2.4, fill, extra='stroke="#3a2212" stroke-width="2.2" stroke-linejoin="round"') + \
               rect(3, -t / 2 + 1.5, L - 6, t * 0.25, 2, "#ffffff", 0.25) + "</g>"
    b += beam(76, 101, 120, 65, 18, wood) + beam(166, 101, 120, 65, 18, wood)
    b += beam(88, 100, 154, 100, 11, wood)
    b += rect(16, 88, 208, 28, 10, wood, extra='stroke="#3a2212" stroke-width="2.6" stroke-linejoin="round"')
    b += rect(22, 91, 196, 6, 3, "#ffffff", 0.28)
    for x in (28, 212):
        b += circle(x, 102, 3.4, iron)
    b += circle(54, 86, 15, d.rad([(0, "#d48d48"), (1, "#7a4220")], 0.4, 0.35, 0.8), extra='stroke="#3a2212" stroke-width="2"')
    b += path("M42 82 Q54 76 66 82 M42 88 Q54 82 66 88 M43 94 Q54 88 65 94", stroke="#ead09d", sw=2.2, op=0.82)
    b += circle(120, 65, 15, iron, extra='stroke="#3a2212" stroke-width="2.2"') + circle(120, 65, 6, "#303944")
    b += poly([(103, 78), (120, 65), (137, 78), (132, 88), (108, 88)], "#68737e", 0.72, 'stroke="#3a2212" stroke-width="2"')
    for wx in (62, 178):
        b += circle(wx, 122, 27, d.rad([(0, "#a86a38"), (0.8, "#6a3a18"), (1, "#4a2610")], 0.4, 0.35, 0.75), extra='stroke="#3a2212" stroke-width="2.2" stroke-linejoin="round"')
        b += circle(wx, 122, 20, d.rad([(0, "#f2b870"), (1, "#b06c34")], 0.38, 0.32, 0.8))
        for k in range(6):
            a = k * math.pi / 3
            b += path(f"M{f(wx)} 122 L{f(wx + 18*math.cos(a))} {f(122 + 18*math.sin(a))}", stroke="#8a4f24", sw=3.2)
        b += circle(wx, 122, 6, iron)
        b += path(f"M{wx-19} 112 A 21 21 0 0 1 {wx+6} 101", stroke="#ffffff", sw=2, op=0.3)
    write("catapult_base", d.svg(W, H, b))

    d = Doc("m")
    wood = d.lin([(0, "#f6c27a"), (0.5, "#cf8644"), (1, "#8a4f24")], 0, 0, 0, 1)
    # Beam centre line y=10 (pivot at 14,10). Bucket hangs on the +y side and opens toward +y,
    # so when the arm is rotated ~190 deg (pointing left) the bucket opens upward.
    b = rect(2, 4, 168, 12, 6, wood, extra='stroke="#3a2212" stroke-width="2.2" stroke-linejoin="round"') + rect(6, 5.5, 160, 3, 1.5, "#ffffff", 0.3)
    for x in (30, 38, 46):
        b += rect(x, 2.5, 4, 15, 2, "#c8a878")
    # Bowl: centre x=172, opening (rim) at y=50, bottom at y=10. Big enough that a hero (radius ~20
    # arm units) sits inside it. The arm sprite carries the bowl's back and dark interior; the
    # separate catapult_cup sprite (outer wall + near rim) is drawn over the loaded hero.
    bowl = "M138 50 Q136 12 172 10 Q208 12 206 50 Z"
    wood_cup = d.lin([(0, "#8a4f24"), (0.55, "#c97f40"), (1, "#f0b468")], 0, 0, 0, 1)
    b += path(bowl, wood_cup, extra='stroke="#3a2212" stroke-width="2.4" stroke-linejoin="round"')
    b += ellipse(172, 50, 34, 7, "#5a3214", extra='stroke="#3a2212" stroke-width="2"') + ellipse(172, 49, 29, 4.6, "#2e180a")
    b += circle(14, 10, 7, d.rad([(0, "#e6ebf0"), (1, "#4a5562")], 0.35, 0.3, 0.8))
    write("catapult_arm", d.svg(210, 60, b))

    d = Doc("mc")
    wood_cup = d.lin([(0, "#8a4f24"), (0.55, "#c97f40"), (1, "#f0b468")], 0, 0, 0, 1)
    b = path(bowl, wood_cup, extra='stroke="#3a2212" stroke-width="2.4" stroke-linejoin="round"')
    # Near half of the rim (screen-lower half when the arm rests with the bowl open upward).
    b += path("M138 50 A34 7 0 0 0 206 50 L206 47 A34 6 0 0 1 138 47 Z", "#e8a860", extra='stroke="#3a2212" stroke-width="2" stroke-linejoin="round"')
    for y in (24, 36):
        b += path(f"M{140 + (50 - y) * 0.05} {y} Q172 {y + 4} {204 - (50 - y) * 0.05} {y}", stroke="#8a96a3", sw=3.2, op=0.95)
        b += path(f"M{141 + (50 - y) * 0.05} {y - 1} Q172 {y + 3} {203 - (50 - y) * 0.05} {y - 1}", stroke="#ffffff", sw=1, op=0.35)
    for x in (148, 196):
        b += circle(x, 30, 2.6, "#e3e8ee", extra='stroke="#2a3038" stroke-width="0.8"')
    b += path("M146 44 Q144 20 170 16", stroke="#ffffff", sw=2.4, op=0.22)
    write("catapult_cup", d.svg(210, 60, b))

    d = Doc("r")
    b = rect(8, 4.5, 42, 3, 1.5, d.lin([(0, "#e0b07a"), (1, "#8a5226")]))
    b += poly([(0, 1), (12, 4.5), (12, 7.5), (0, 11), (5, 6)], "#e04040")
    b += poly([(3, 3.5), (12, 5), (12, 7), (3, 8.5), (6, 6)], "#ffffff", 0.9)
    b += poly([(48, 2), (60, 6), (48, 10)], d.lin([(0, "#ffffff"), (1, "#7d8590")]))
    write("arrow", d.svg(60, 12, b))

    d = Doc("p")
    write("puff", d.svg(64, 64, circle(32, 32, 31, d.rad([(0, "#ffffff", 0.95), (0.55, "#ffffff", 0.7), (1, "#ffffff", 0)], 0.5, 0.5, 0.5))))
    d = Doc("x")
    write("flash", d.svg(128, 128, circle(64, 64, 63, d.rad([(0, "#ffffff", 1), (0.25, "#fff6b0", 0.95), (0.6, "#ffb02e", 0.6), (1, "#ff5a1f", 0)], 0.5, 0.5, 0.5))))
    d = Doc("f")
    flame = d.lin([(0, "#fff6b0"), (0.4, "#ffc23a"), (0.8, "#ff7a1f"), (1, "#f04a14", 0.9)], 0, 0, 0, 1)
    write("flame", d.svg(48, 72, path("M24 70 C6 66 4 46 14 32 C16 42 20 42 22 26 C24 14 30 8 30 0 C40 14 46 30 42 44 C46 42 46 38 46 34 C52 50 44 68 24 70 Z", flame)
                         + path("M24 66 C14 62 14 52 20 44 C22 50 26 48 26 40 C34 48 36 60 24 66 Z", "#fff6c0", 0.8)))
    d = Doc("k2")
    write("spark", d.svg(32, 32, poly(star_points(16, 16, 15, 4, 4, -90), "#fff6b0") + circle(16, 16, 4, "#ffffff")))
    d = Doc("t")
    write("dot", d.svg(20, 20, circle(10, 10, 9.5, d.rad([(0, "#ffffff", 1), (0.7, "#ffffff", 0.95), (1, "#ffffff", 0)], 0.5, 0.5, 0.5))))
    d = Doc("sh")
    write("shadow", d.svg(64, 16, ellipse(32, 8, 31, 7.5, d.rad([(0, "#1a2a10", 0.4), (1, "#1a2a10", 0)], 0.5, 0.5, 0.5))))


# --------------------------------------------------------------------------- environment
def periodic(W, base, terms):
    def y(x):
        return base + sum(a * math.sin(2 * math.pi * k * x / W + p) for (a, k, p) in terms)
    return y


def ground():
    d = Doc("g")
    W, H = 256, 330
    b = rect(0, 10, W, H - 10, 0, d.lin([(0, "#a8703c"), (0.25, "#8a5a2e"), (1, "#5a3a1e")], 0, 0, 0, 1))
    rnd = random.Random(5)
    for _ in range(26):
        x, y = rnd.uniform(6, W - 6), rnd.uniform(40, H - 10)
        r = rnd.uniform(2, 6)
        b += ellipse(x, y, r * 1.4, r, d.lin([(0, "#c49a6c"), (1, "#7a5230")], 0, 0, 0, 1), 0.8)
    yy = periodic(W, 22, [(3.5, 3, 0.4), (2, 5, 1.3), (1.2, 8, 2.1)])
    top = " ".join(f"L{f(x)} {f(yy(x))}" for x in range(0, W + 1, 8))
    b += path(f"M0 {f(yy(0))} {top} L{W} 40 L0 40 Z", d.lin([(0, "#2f6e1c"), (1, "#3f8424")], 0, 0, 0, 1))
    yy2 = periodic(W, 12, [(4, 4, 0.2), (2.4, 6, 1.0), (1.5, 11, 2.0)])
    top2 = " ".join(f"L{f(x)} {f(yy2(x))}" for x in range(0, W + 1, 4))
    b += path(f"M0 {f(yy2(0))} {top2} L{W} 30 Q{W*0.75} 36 {W/2} 31 Q{W/4} 36 0 30 Z",
              d.lin([(0, "#b6ee5a"), (0.5, "#7ccf3a"), (1, "#4f9e26")], 0, 0, 0, 1))
    for x in range(4, W, 11):
        h = rnd.uniform(4, 9)
        y0 = yy2(x) + 2
        b += path(f"M{f(x)} {f(y0)} Q{f(x+1)} {f(y0-h)} {f(x+3)} {f(y0-h-1)}", stroke="#c8f57a", sw=1.6, op=0.8)
    b += path(f"M0 {f(yy2(0)+3)} " + " ".join(f"L{f(x)} {f(yy2(x)+3)}" for x in range(0, W + 1, 4)),
              stroke="#e0ff9a", sw=2, op=0.55)
    write("ground", d.svg(W, H, b))


def mountains():
    d = Doc("m")
    W, H = 1280, 380
    out = ""
    for layer, (col, shade, base, peaks, seed) in enumerate([
        (("#cfe6fa", "#a4c9ec"), "#8db6e0", 300, 7, 2), (("#b4d6f5", "#7fb1e0"), "#6a9ccf", 330, 6, 8)]):
        rnd = random.Random(seed)
        xs = sorted(rnd.uniform(0, W) for _ in range(peaks))
        pts = []
        for x in xs:
            pts.append((x, base - rnd.uniform(150, 260) + layer * 30))
        body = d.lin([(0, col[0]), (1, col[1])], 0, 0, 0, 1)
        for dx in (-W, 0, W):
            for (px, py) in pts:
                hw = (base - py) * rnd.uniform(1.1, 1.5)
                x0, x1 = px + dx - hw, px + dx + hw
                if x1 < -50 or x0 > W + 50:
                    continue
                out += poly([(x0, H), (px + dx, py), (x1, H)], body)
                out += poly([(px + dx, py), (x1, H), (px + dx + hw * 0.15, H)], shade, 0.45)
                s = (base - py) * 0.28
                out += poly([(px + dx, py), (px + dx - s * 1.2, py + s), (px + dx - s * 0.4, py + s * 0.8),
                             (px + dx, py + s * 1.15), (px + dx + s * 0.5, py + s * 0.85), (px + dx + s * 1.2, py + s)],
                            d.lin([(0, "#ffffff"), (1, "#e2f1fc")], 0, 0, 0, 1))
    out += rect(0, H - 140, W, 140, 0, d.lin([(0, "#e4f7ff", 0), (1, "#e4f7ff", 0.9)], 0, 0, 0, 1))
    write("bg_mountains", d.svg(W, H, out))


def pine(d, x, y, h, cols):
    w = h * 0.5
    out = rect(x - h * 0.05, y - h * 0.18, h * 0.1, h * 0.2, 2, "#6a4224")
    for i in range(3):
        ty = y - h * (0.15 + i * 0.27)
        tw = w * (1 - i * 0.24)
        out += path(f"M{f(x-tw/2)} {f(ty)} Q{f(x)} {f(ty+h*0.06)} {f(x+tw/2)} {f(ty)} L{f(x+2)} {f(ty-h*0.36)} Q{f(x)} {f(ty-h*0.38)} {f(x-2)} {f(ty-h*0.36)} Z", cols)
    return out


def hills():
    d = Doc("h")
    W, H = 1280, 420
    out = ""
    yf = periodic(W, 150, [(30, 2, 0.5), (18, 3, 2.0), (8, 7, 1.0)])
    pts = " ".join(f"L{f(x)} {f(yf(x))}" for x in range(0, W + 1, 10))
    out += path(f"M0 {H} L0 {f(yf(0))} {pts} L{W} {H} Z", d.lin([(0, "#9fdc72"), (1, "#5aa83c")], 0, 0, 0, 1))
    rnd = random.Random(21)
    pcol = d.lin([(0, "#4f9e40"), (1, "#2a6a2c")], 0, 0, 1, 0)
    for _ in range(26):
        x = rnd.uniform(10, W - 10)
        out += pine(d, x, yf(x) + 14, rnd.uniform(50, 85), pcol)
    yn = periodic(W, 250, [(26, 2, 2.6), (14, 4, 0.3), (6, 9, 1.7)])
    pts = " ".join(f"L{f(x)} {f(yn(x))}" for x in range(0, W + 1, 10))
    out += path(f"M0 {H} L0 {f(yn(0))} {pts} L{W} {H} Z", d.lin([(0, "#8fd85a"), (0.4, "#62b532"), (1, "#3f8a24")], 0, 0, 0, 1))
    out += path(f"M0 {f(yn(0)+3)} " + " ".join(f"L{f(x)} {f(yn(x)+3)}" for x in range(0, W + 1, 10)),
                stroke="#c8f57a", sw=3, op=0.5)
    bush = d.rad([(0, "#a8e868"), (0.6, "#5aaa30"), (1, "#3a7a20")], 0.4, 0.3, 0.8)
    for _ in range(14):
        x = rnd.uniform(0, W)
        y = yn(x) + rnd.uniform(14, 40)
        for k in range(3):
            out += circle(x + (k - 1) * 16, y - (8 if k == 1 else 0), 15 if k == 1 else 12, bush)
    write("bg_hills", d.svg(W, H, out))


def clouds():
    for i, blobs in enumerate([
        [(70, 90, 46), (130, 70, 58), (200, 86, 48), (250, 100, 34), (40, 108, 30)],
        [(60, 80, 36), (110, 64, 46), (165, 78, 38), (205, 92, 26)],
    ]):
        d = Doc(f"c{i}")
        fill = d.lin([(0, "#ffffff"), (0.65, "#ffffff"), (1, "#d2e9fb")], 0, 0, 0, 1)
        W = 300 if i == 0 else 240
        b = rect(30, 92, W - 70, 40, 20, fill)
        for (x, y, r) in blobs:
            b += circle(x, y, r, fill)
        for (x, y, r) in blobs[:3]:
            b += ellipse(x - r * 0.25, y - r * 0.4, r * 0.45, r * 0.22, "#ffffff", 0.9)
        write(f"cloud_{i}", d.svg(W, 140, b))


def decor():
    d = Doc("p")
    b = pine(d, 50, 196, 190, d.lin([(0, "#7cc858"), (0.5, "#3f9a3a"), (1, "#24622a")], 0, 0, 1, 0.3))
    b += path("M40 60 L18 120", stroke="#ffffff", sw=4, op=0.18)
    write("tree_pine", d.svg(100, 200, b))
    d = Doc("b")
    bush = d.rad([(0, "#b8f078"), (0.55, "#62b532"), (1, "#356f1c")], 0.4, 0.3, 0.8)
    b = ""
    for (x, y, r) in [(40, 52, 26), (80, 40, 34), (122, 52, 26), (60, 58, 22), (104, 60, 22)]:
        b += circle(x, y, r, bush)
    for (x, y) in [(56, 34), (96, 26), (126, 42)]:
        b += ellipse(x, y, 8, 4, "#ffffff", 0.35, -25)
    for (x, y, c) in [(50, 50, "#ff8ab0"), (92, 46, "#fff27a"), (118, 60, "#ffffff")]:
        for k in range(5):
            a = k * 1.256
            b += circle(x + 3.6 * math.cos(a), y + 3.6 * math.sin(a), 2.6, c)
        b += circle(x, y, 2, "#ffb02e")
    write("bush", d.svg(160, 84, b))


# --------------------------------------------------------------------------- ui
def ui():
    d = Doc("s")
    pts = star_points(40, 42, 36, 16)
    b = poly(star_points(40, 45, 36, 16), "#c46a0a", extra='stroke="#c46a0a" stroke-width="7" stroke-linejoin="round"')
    b += poly(pts, d.lin([(0, "#fff7a8"), (0.5, "#ffcf3a"), (1, "#f29a12")], 0, 0, 0, 1),
              extra=f'stroke="#ffcf3a" stroke-width="7" stroke-linejoin="round"')
    b += poly(star_points(37, 36, 15, 7), "#ffffff", 0.45)
    write("star_full", d.svg(80, 84, b))
    d = Doc("e")
    b = poly(star_points(40, 45, 36, 16), "#1c1430", 0.4, 'stroke="#1c1430" stroke-opacity="0.4" stroke-width="7" stroke-linejoin="round"')
    b += poly(pts, "#4a3e66", 0.75, 'stroke="#4a3e66" stroke-opacity="0.75" stroke-width="7" stroke-linejoin="round"')
    write("star_empty", d.svg(80, 84, b))
    d = Doc("c")
    b = circle(24, 25, 22, "#b8780a")
    b += circle(24, 23, 22, d.lin([(0, "#fff3a0"), (0.5, "#ffc93a"), (1, "#e8960c")], 0, 0, 0, 1))
    b += circle(24, 23, 15, d.lin([(0, "#e8960c"), (1, "#ffd84a")], 0, 0, 0, 1))
    b += poly(star_points(24, 23, 9, 4), "#fff3a0")
    b += ellipse(16, 13, 6, 3, "#ffffff", 0.6, -30)
    write("coin", d.svg(48, 48, b))
    # gem: faceted violet jewel
    d = Doc("g")
    O = "#3a2212"
    b = poly([(10, 18), (17, 9), (31, 9), (38, 18), (24, 41)], "#5a1a8a", extra=f'stroke="{O}" stroke-width="2.5" stroke-linejoin="round"')
    b += poly([(10, 18), (17, 9), (31, 9), (38, 18), (24, 41)], d.lin([(0, "#f0b8ff"), (0.45, "#b452f0"), (1, "#6a1ea8")], 0, 0, 0, 1))
    b += poly([(10, 18), (38, 18), (24, 41)], "#8a2cd0", 0.85)
    b += poly([(17, 18), (31, 18), (24, 41)], "#a84ae8", 0.9)
    b += poly([(17, 9), (24, 18), (31, 9)], "#f6d2ff", 0.8)
    b += poly([(13, 17), (18, 11), (21, 17)], "#ffffff", 0.75)
    b += path("M10 18 L17 9 L31 9 L38 18 L24 41 Z", stroke=O, sw=2.5, extra='stroke-linejoin="round"')
    write("gem", d.svg(48, 48, b))
    # blueprint: rolled parchment scroll with a red catapult sketch
    d = Doc("p")
    b = rect(8, 10, 32, 28, 3, d.lin([(0, "#fff0c8"), (1, "#e8c486")], 0, 0, 0, 1), extra=f'stroke="{O}" stroke-width="2.5"')
    b += rect(5, 7, 38, 7, 3.5, d.lin([(0, "#f2d49a"), (1, "#b8823e")], 0, 0, 0, 1), extra=f'stroke="{O}" stroke-width="2.5"')
    b += rect(5, 34, 38, 7, 3.5, d.lin([(0, "#f2d49a"), (1, "#b8823e")], 0, 0, 0, 1), extra=f'stroke="{O}" stroke-width="2.5"')
    b += path("M14 30 L34 30 M17 30 L24 19 L31 30 M24 19 L33 15", stroke="#c8321e", sw=2.4, extra='stroke-linecap="round"')
    b += circle(34, 15, 2.6, "#c8321e")
    b += path("M13 24 L17 24 M30 24 L35 24", stroke="#c8321e", sw=1.6, extra='stroke-dasharray="2 2"')
    write("blueprint", d.svg(48, 48, b))
    # light rays behind rewards and purchases (additive, spun in code)
    d = Doc("r")
    rg = d.rad([(0, "#fff6c0", 0.95), (0.55, "#ffd24a", 0.45), (1, "#ffb020", 0.0)], 0.5, 0.5, 0.5)
    tris = []
    for k in range(12):
        a0 = math.radians(k * 30 - 6); a1 = math.radians(k * 30 + 6)
        tris.append(f"M128 128 L{f(128 + 128 * math.cos(a0))} {f(128 + 128 * math.sin(a0))} "
                    f"L{f(128 + 128 * math.cos(a1))} {f(128 + 128 * math.sin(a1))} Z")
    b = rect(0, 0, 256, 256, 0, "#000", 0)
    b += path(" ".join(tris), rg)
    b += circle(128, 128, 46, d.rad([(0, "#ffffff", 0.9), (1, "#ffd24a", 0.0)], 0.5, 0.5, 0.5))
    write("fx_rays", d.svg(256, 256, b))

    W = "#ffffff"
    icons = {
        "icon_pause": rect(12, 9, 9, 30, 3, W) + rect(27, 9, 9, 30, 3, W),
        "icon_play": path("M15 9 Q12 9 12 13 L12 35 Q12 39 15 38 L37 26 Q40 24 37 22 Z", W),
        "icon_next": path("M10 10 Q8 10 8 13 L8 35 Q8 38 11 37 L30 26 Q32 24 30 22 Z", W) + rect(32, 10, 8, 28, 3, W),
        "icon_restart": path("M36 26 A13 13 0 1 1 30 13", stroke=W, sw=7) + poly([(24, 4), (38, 12), (25, 21)], W),
        "icon_home": path("M24 6 L42 22 L37 22 L37 40 L28 40 L28 30 L20 30 L20 40 L11 40 L11 22 L6 22 Z", W,
                          extra='stroke="#ffffff" stroke-width="2" stroke-linejoin="round"'),
        "icon_levels": rect(8, 8, 14, 14, 4, W) + rect(26, 8, 14, 14, 4, W) + rect(8, 26, 14, 14, 4, W) + rect(26, 26, 14, 14, 4, W),
        "icon_lock": path("M16 22 L16 16 A8 8 0 0 1 32 16 L32 22", stroke=W, sw=5) + rect(10, 21, 28, 21, 5, W),
        "icon_music": path("M18 34 L18 10 L38 6 L38 30", stroke=W, sw=4.5) + ellipse(14, 35, 6, 5, W) + ellipse(34, 31, 6, 5, W),
        "icon_sound": path("M8 18 L16 18 L26 9 L26 39 L16 30 L8 30 Z", W) + path("M31 17 Q36 24 31 31 M35 12 Q43 24 35 36", stroke=W, sw=3.6),
        "icon_close": path("M13 13 L35 35 M35 13 L13 35", stroke=W, sw=7),
        "icon_noads": circle(24, 24, 16, "none", 1, 'stroke="#ffffff" stroke-width="5"') + path("M13 35 L35 13", stroke=W, sw=5)
                      + path("M15 28 L19 19 L23 28 M16.5 25 L21.5 25 M26 19 L26 28 L29 28 Q33 28 33 23.5 Q33 19 29 19 Z", stroke=W, sw=2.2),
    }
    for name, body in icons.items():
        write(name, Doc().svg(48, 48, body))


def blocks():
    for shape, (mat, w, h) in SHAPES.items():
        for stage in range(3):
            d = Doc("b")
            rnd = random.Random(hash(shape) % 1000 + stage * 31)
            rnd = random.Random(sum(map(ord, shape)) + stage * 31)
            body = BLOCK_DRAW[mat](d, w, h, stage, rnd) + block_outline(mat, w, h)
            cw, ch = (w, h) if mat != "iron_bent" else bent_box(w, h, 16)[:2]
            write(f"block_{shape}_{stage}", d.svg(cw, ch, body))


def characters():
    for name, fn in [("hero_stone", hero_stone), ("hero_quake", hero_quake), ("hero_fire", hero_fire), ("hero_bomb", hero_bomb),
                     ("hero_cyclone", hero_cyclone)]:
        for kind, suffix in [("open", ""), ("dizzy", "_hit")]:
            d = Doc("h")
            W, H, b = fn(d, kind)
            write(name + suffix, d.svg(W, H, b))
    for pose in ("idle", "cheer", "ko"):
        d = Doc("s")
        W, H, b = soldier(d, pose)
        write(f"soldier_{pose}", d.svg(W, H, b))
    for pose in ("idle", "shoot", "ko"):
        d = Doc("a")
        W, H, b = archer(d, pose)
        write(f"archer_{pose}", d.svg(W, H, b))
    d = Doc("wz")
    W, H, b = wizard(d)
    write("wizard_idle", d.svg(W, H, b))
    d = Doc("cp")
    W, H, b = captive(d)
    write("captive_idle", d.svg(W, H, b))


def app_icon():
    d = Doc("i")
    S = 512
    b = rect(0, 0, S, S, 0, d.lin([(0, "#2f9df4"), (0.6, "#8fd6ff"), (1, "#e4f7ff")], 0, 0, 0, 1))
    b += circle(400, 110, 70, d.rad([(0, "#fffbe0", 0.9), (1, "#fffbe0", 0)], 0.5, 0.5, 0.5))
    stone = Doc("is")
    w, h, sb = hero_stone(stone)
    sold = Doc("io")
    w2, h2, ob = soldier(sold, "idle")
    d.defs += stone.defs + sold.defs
    b += path("M0 400 Q130 350 260 380 Q390 410 512 360 L512 512 L0 512 Z", d.lin([(0, "#9be85a"), (1, "#3f8a24")], 0, 0, 0, 1))
    b += group(ob, 40, 150, 3.0)
    b += group(sb, 250, 150, 3.4)
    write("icon", d.svg(S, S, b))


# --------------------------------------------------------------------------- reference style pack
# Matches the owner's reference image (docs/reference/level_style_reference.png): warm wood with a dark
# brown outline, light grey outlined stones, terracotta tiled roofs with red flags, red banners,
# grassy cliff edge with boulders, leafy foreground framing, wooden sign UI.
OL = "#3a2212"


def ol(sw=2.2):
    return f'stroke="{OL}" stroke-width="{sw}" stroke-linejoin="round"'


def block_outline(mat, w, h):
    if mat == "straw":
        return path(f"M5 {h-1} L{w/2-4} 4 Q{w/2} 0 {w/2+4} 4 L{w-5} {h-1} Z", "none", 1, OL, 2.4)
    if mat == "tile":
        return ""
    if mat == "barrel":
        return path(f"M6 4 Q0 {h/2} 6 {h-4} Q{w/2} {h+2} {w-6} {h-4} Q{w} {h/2} {w-6} 4 Q{w/2} -2 6 4 Z", "none", 1, OL, 2.2)
    if mat in ("boulder", "iron_bent", "cannon", "chest", "log", "wheel", "cart", "bell", "cage", "iron_ball"):
        return ""
    r = 8 if mat == "stone" else (7 if mat == "crate" else min(7, min(w, h) * 0.3))
    return rect(1.1, 1.1, w - 2.2, h - 2.2, r, "none", 1, ol(2.2))


def tile_roof_block(d, w, h, stage, rnd):
    """Pitched roof with terracotta tiles on a wooden eave. Collider is a triangle (base = bottom)."""
    eave = 14
    tri = f"M2 {h-eave} L{w/2} 3 L{w-2} {h-eave} Z"
    b = path(tri, d.lin([(0, "#f29a58"), (0.5, "#d9672e"), (1, "#a8441c")], 0, 0, 0, 1), extra=ol(2.4))
    rows = 5
    for i in range(1, rows + 1):
        y = 3 + (h - eave - 3) * i / rows
        half = (w / 2 - 2) * (y - 3) / (h - eave - 3)
        n = max(2, int(half * 2 / 20))
        x0 = w / 2 - half
        scal = ""
        for k in range(n):
            xa = x0 + 2 * half * k / n
            xb = x0 + 2 * half * (k + 1) / n
            scal += f" Q{f((xa+xb)/2)} {f(y+5)} {f(xb)} {f(y)}"
        b += path(f"M{f(x0)} {f(y)}{scal}", "none", 0.85, "#7a2e10", 1.6)
        b += path(f"M{f(x0+3)} {f(y-3.5)} L{f(w-x0-3)} {f(y-3.5)}", "none", 0.25, "#ffffff", 1.4)
    b += path(f"M{w/2} 6 L16 {h-eave-4}", stroke="#ffd0a0", sw=3, op=0.35)
    b += rect(0, h - eave - 2, w, eave + 2, 5, d.lin([(0, "#e8a860"), (1, "#8a4f24")], 0, 0, 0, 1), extra=ol(2.2))
    b += rect(4, h - eave, w - 8, 3, 1.5, "#ffffff", 0.28)
    b += circle(w / 2, 5, 5, d.rad([(0, "#f6c27a"), (1, "#8a4f24")]), extra=ol(1.6))
    if stage:
        for _ in range(2 if stage == 1 else 5):
            t = rnd.uniform(0.35, 0.8)
            x = w / 2 + rnd.uniform(-0.8, 0.8) * (w / 2 - 20) * t
            b += path(f"M{f(x-7)} {f(h*t)} L{f(x)} {f(h*t-6)} L{f(x+8)} {f(h*t+1)} L{f(x+1)} {f(h*t+6)} Z", "#4a1a08", 0.75)
    return b


def flag():
    d = Doc("fl")
    b = rect(3, 4, 4, 76, 2, d.lin([(0, "#b0b8c2"), (1, "#5a6470")], 0, 0, 1, 0), extra=ol(1.6))
    b += circle(5, 4, 4, "#ffc93a", extra=ol(1.4))
    cloth = d.lin([(0, "#ff6a5a"), (0.6, "#e0302a"), (1, "#a81c1c")], 0, 0, 0, 1)
    b += path("M7 8 Q22 4 34 10 Q42 13 50 9 L44 20 L50 32 Q40 36 32 32 Q20 28 7 32 Z", cloth, extra=ol(1.8))
    b += path("M10 12 Q22 9 32 14", stroke="#ffffff", sw=2, op=0.35)
    write("flag", d.svg(54, 82, b))


def banner():
    d = Doc("bn")
    cloth = d.lin([(0, "#ff5a4a"), (0.5, "#d42a2a"), (1, "#9a1818")], 0, 0, 1, 0)
    b = rect(0, 0, 44, 8, 3, d.lin([(0, "#e8a860"), (1, "#8a4f24")], 0, 0, 0, 1), extra=ol(1.6))
    b += path("M4 7 L40 7 L40 74 L22 64 L4 74 Z", cloth, extra=ol(2))
    b += path("M7 10 L37 10 L37 68", stroke="#ffc93a", sw=1.6, op=0.9)
    gold = "#ffd23a"
    # simple lily emblem
    b += path("M22 22 C17 28 17 36 22 42 C27 36 27 28 22 22 Z", gold, extra='stroke="#9a5a0a" stroke-width="1"')
    b += path("M21 40 C14 40 11 34 13 29 C17 31 19 35 21 40 Z", gold, extra='stroke="#9a5a0a" stroke-width="1"')
    b += path("M23 40 C30 40 33 34 31 29 C27 31 25 35 23 40 Z", gold, extra='stroke="#9a5a0a" stroke-width="1"')
    b += rect(15, 41, 14, 4, 2, gold, extra='stroke="#9a5a0a" stroke-width="1"')
    b += path("M22 45 L22 52", stroke=gold, sw=3)
    write("banner", d.svg(44, 76, b))


def ground_cliff():
    """Tileable grassy cliff: a bright turf shelf over large, faceted natural rock."""
    d = Doc("gc")
    W, H = 512, 330
    rnd = random.Random(42)
    earth = d.lin([(0, "#7d674d"), (0.45, "#584735"), (1, "#30271f")], 0, 0, 0, 1)
    b = rect(0, 20, W, H - 20, 0, earth)

    # Large interlocking faces avoid the regular masonry pattern of the previous ground strip.
    faces = [
        ([(-18, 31), (69, 27), (112, 91), (62, 151), (-12, 126)], ("#d8c6a9", "#82715f")),
        ([(69, 27), (163, 34), (184, 111), (112, 91)], ("#cbb99e", "#746352")),
        ([(163, 34), (256, 26), (301, 95), (240, 153), (184, 111)], ("#ded0b9", "#887563")),
        ([(256, 26), (357, 32), (406, 106), (301, 95)], ("#c9b79d", "#716052")),
        ([(357, 32), (450, 26), (530, 39), (520, 132), (406, 106)], ("#dac7aa", "#806d59")),
        ([(-12, 126), (62, 151), (126, 223), (75, 330), (-12, 330)], ("#83715f", "#463a30")),
        ([(62, 151), (112, 91), (184, 111), (240, 153), (209, 250), (126, 223)], ("#a18d76", "#594a3c")),
        ([(240, 153), (301, 95), (406, 106), (423, 215), (337, 273), (209, 250)], ("#8f7c68", "#4b3e33")),
        ([(406, 106), (520, 132), (520, 330), (337, 273), (423, 215)], ("#796857", "#3d332a")),
    ]
    for i, (pts, colors) in enumerate(faces):
        fill = d.lin([(0, colors[0]), (1, colors[1])], 0, 0, 0.75, 1)
        b += poly(pts, fill, extra=ol(2.0))
        if i < 5:
            p0, p1 = pts[0], pts[1]
            b += path(f"M{f(p0[0]+8)} {f(p0[1]+7)} L{f(p1[0]-8)} {f(p1[1]+5)}", stroke="#fff1d2", sw=3, op=0.3)
    # Angular seams and small ledges add depth without reading as brick courses.
    for p in ["M112 91 L132 119 L118 145", "M301 95 L279 126 L289 151", "M406 106 L383 142 L397 169",
              "M126 223 L161 207 L181 224", "M337 273 L365 238 L394 235"]:
        b += path(p, "none", 0.65, "#30271f", 3.0)
    for x, y, rx, ry in [(45, 86, 20, 8), (220, 75, 26, 9), (346, 73, 22, 8), (468, 77, 20, 7)]:
        b += ellipse(x, y, rx, ry, "#fff4d8", 0.16, -12)

    top = periodic(W, 8, [(2.6, 6, 0.2), (1.7, 11, 1.0), (1.0, 17, 2.0)])
    lip = lambda x: 37 + 4 * math.sin(2 * math.pi * 5 * x / W) + 3 * math.sin(2 * math.pi * 13 * x / W + 1)
    grass = d.lin([(0, "#d2f878"), (0.34, "#8bd33f"), (0.72, "#519c27"), (1, "#2f6e1c")], 0, 0, 0, 1)
    up = " ".join(f"L{f(x)} {f(top(x))}" for x in range(0, W + 1, 4))
    dn = " ".join(f"L{f(x)} {f(lip(x))}" for x in range(W, -1, -4))
    b += path(f"M0 {f(top(0))} {up} {dn} Z", grass, extra='stroke="#3a6e20" stroke-width="1.5"')
    b += path("M0 %s %s" % (f(lip(0)), " ".join(f"L{f(x)} {f(lip(x))}" for x in range(0, W + 1, 4))), "none", 0.8, OL, 2.2)
    b += path(f"M0 {f(top(0)+2)} {up}", "none", 0.7, "#efffa8", 2.0)
    for x in range(4, W, 10):
        blade = rnd.uniform(5, 13)
        y0 = top(x) + 2
        b += path(f"M{f(x)} {f(y0)} Q{f(x+1)} {f(y0-blade)} {f(x+4)} {f(y0-blade-1)}", stroke="#d8ff8a", sw=1.6, op=0.8)
    # Hanging vines and tiny flowers break the cliff edge silhouette.
    for x in (38, 142, 278, 389, 480):
        y0 = lip(x)
        b += path(f"M{x} {f(y0-2)} Q{x-5} {f(y0+18)} {x+3} {f(y0+34)}", stroke="#397e22", sw=3.2, op=0.95)
        b += ellipse(x-3, y0+20, 6, 3, "#79c83d", 0.95, -25)
    for x, col in [(92, "#fff6dc"), (322, "#ffe56b"), (444, "#fff6dc")]:
        y = top(x) - 3
        for k in range(5):
            a = k * 2 * math.pi / 5
            b += circle(x + 3.5 * math.cos(a), y + 3.5 * math.sin(a), 2.2, col)
        b += circle(x, y, 1.8, "#f39a2d")
    write("ground_cliff", d.svg(W, H, b))


def leaf(cx, cy, s, rot, fill):
    return (f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(rot)}) scale({f(s)})">'
            + path("M0 0 Q14 -12 34 0 Q14 12 0 0 Z", fill, extra=ol(1.6 / max(s, 0.3)))
            + path("M2 0 L30 0", stroke="#2f6a1c", sw=1.2 / max(s, 0.3), op=0.6) + "</g>")


def foreground():
    d = Doc("fg")
    rnd = random.Random(8)
    W, H = 560, 330
    branch = d.lin([(0, "#9a6a40"), (1, "#5a3a1e")], 0, 0, 0, 1)
    b = path("M-10 70 Q120 40 260 90 Q330 115 420 100 L424 112 Q330 130 256 104 Q120 60 -10 92 Z", branch, extra=ol(2.4))
    b += path("M-10 10 Q60 20 120 0 L130 8 Q60 34 -10 30 Z", branch, extra=ol(2.2))
    fills = [d.lin([(0, "#a8e85a"), (1, "#4f9e26")], 0, 0, 1, 1), d.lin([(0, "#7cd040"), (1, "#2f7a1c")], 0, 0, 1, 1),
             d.lin([(0, "#c8f57a"), (1, "#62b532")], 0, 0, 1, 1)]
    for i in range(150):
        t = rnd.random()
        if rnd.random() < 0.65:
            x = -10 + 440 * t + rnd.uniform(-30, 30)
            y = 70 + 40 * math.sin(t * 3) + rnd.uniform(-70, 90) * (1 - t * 0.6)
        else:
            x = rnd.uniform(-20, 220)
            y = rnd.uniform(-20, 120)
        if y > H - 20:
            continue
        b += leaf(x, y, rnd.uniform(0.9, 1.6), rnd.uniform(0, 360), rnd.choice(fills))
    write("fg_leaves", d.svg(W, H, b))

    d = Doc("fe")
    W, H = 460, 220
    wood = d.lin([(0, "#e0a35c"), (0.5, "#b8733a"), (1, "#7e4a22")], 0, 0, 1, 0)
    woodh = d.lin([(0, "#e8b070"), (1, "#8a5226")], 0, 0, 0, 1)
    b = ""
    for (x0, y0, x1, y1) in [(0, 70, 460, 40), (0, 140, 460, 112)]:
        b += path(f"M{x0} {y0} L{x1} {y1} L{x1} {y1+24} L{x0} {y0+24} Z", woodh, extra=ol(2.4))
        b += path(f"M{x0+6} {y0+5} L{x1-6} {y1+5}", stroke="#ffffff", sw=2.4, op=0.25)
    for x in (30, 200, 380):
        y = 30 - x * 0.06
        b += path(f"M{x} {y+12} L{x+14} {y} L{x+30} {y+12} L{x+30} {H} L{x} {H} Z", wood, extra=ol(2.4))
        b += path(f"M{x+8} {y+18} L{x+8} {H-10}", stroke="#ffffff", sw=2.4, op=0.22)
        b += path(f"M{x+20} {y+40} Q{x+18} {y+70} {x+22} {y+100}", stroke="#6a3a18", sw=1.4, op=0.6)
    write("fg_fence", d.svg(W, H, b))

    d = Doc("fb")
    W, H = 420, 220
    bush = [d.rad([(0, "#b8f078"), (0.55, "#62b532"), (1, "#2f6a1c")], 0.4, 0.3, 0.8),
            d.rad([(0, "#9ee060"), (0.6, "#4f9e26"), (1, "#24561a")], 0.4, 0.3, 0.8)]
    b = ""
    for i, (x, y, r) in enumerate([(70, 150, 70), (170, 110, 90), (290, 120, 85), (370, 160, 64), (220, 175, 80), (110, 190, 60)]):
        b += circle(x, y, r, bush[i % 2], extra=ol(2.4))
        b += ellipse(x - r * 0.3, y - r * 0.5, r * 0.3, r * 0.14, "#ffffff", 0.3, -20)
    for i in range(36):
        b += leaf(rnd.uniform(20, 400), rnd.uniform(30, 200), rnd.uniform(0.8, 1.3), rnd.uniform(0, 360), bush[i % 2])
    for (x, y, c) in [(80, 120, "#ffffff"), (140, 170, "#fff27a"), (260, 90, "#ff9ab8"), (330, 150, "#ffffff"), (200, 140, "#fff27a")]:
        for k in range(5):
            a = k * 1.256
            b += circle(x + 5 * math.cos(a), y + 5 * math.sin(a), 4, c, extra='stroke="#8a6a20" stroke-width="0.8"')
        b += circle(x, y, 3, "#ffb02e")
    write("fg_bush", d.svg(W, H, b))


def ui_pack():
    # Wooden sign, used as a 9-patch (margins 22 px). 200x80.
    d = Doc("ws")
    W, H = 200, 80
    b = rect(2, 4, W - 4, H - 6, 14, "#3a2212")
    b += rect(4, 4, W - 8, H - 12, 12, d.lin([(0, "#c88a4a"), (0.5, "#9a5f30"), (1, "#7a4622")], 0, 0, 0, 1))
    for y in (24, 46):
        b += path(f"M14 {y} Q100 {y+3} {W-14} {y}", stroke="#5a3214", sw=1.4, op=0.5)
    b += rect(8, 7, W - 16, 6, 3, "#ffffff", 0.18)
    nail = d.rad([(0, "#f2f4f6"), (1, "#5d6570")], 0.35, 0.3, 0.8)
    for (x, y) in [(13, 13), (W - 13, 13), (13, H - 18), (W - 13, H - 18)]:
        b += circle(x, y, 3.2, nail, extra='stroke="#2a2a2a" stroke-width="0.8"')
    write("ui_sign", d.svg(W, H, b))

    # Dark slate chip (9-patch, margins 18), like the reference "Shots / Destruction" panels. 160x70
    d = Doc("dc")
    b = rect(1, 1, 158, 68, 14, "#3a2212")
    b += rect(4, 4, 152, 60, 11, d.lin([(0, "#5a5048"), (1, "#3a322c")], 0, 0, 0, 1))
    b += rect(7, 6, 146, 5, 2.5, "#ffffff", 0.12)
    write("ui_chip", d.svg(160, 70, b))

    # Hand pointer for the drag tutorial.
    d = Doc("hd")
    skin = d.lin([(0, "#ffffff"), (1, "#e2e6ee")], 0, 0, 0, 1)
    b = path("M30 8 Q36 4 40 10 L40 44 L44 30 Q50 26 54 32 L54 46 L58 36 Q64 32 67 39 L67 52 L70 46 Q76 44 78 51 "
             "L76 78 Q72 96 54 98 L44 98 Q32 96 26 84 L12 58 Q10 50 18 50 Q24 50 28 58 L30 62 Z", skin, extra=ol(3))
    b += path("M44 46 L44 66 M58 50 L58 68", stroke="#9aa2b0", sw=2)
    write("hand", d.svg(86, 104, b))

    # Curved arrow for the tutorial.
    d = Doc("ar")
    b = path("M10 70 Q40 10 110 18", stroke=OL, sw=20)
    b += path("M10 70 Q40 10 110 18", stroke="#ffffff", sw=13)
    b += poly([(104, 2), (134, 20), (104, 38)], "#ffffff", extra=ol(3))
    write("tutorial_arrow", d.svg(140, 80, b))

    # Map level nodes.
    for name, cols in [("map_node", ("#ffe27a", "#f2a62a", "#b8660c")), ("map_node_locked", ("#c9ccd2", "#8f949c", "#5d626b")),
                       ("map_node_done", ("#b8f078", "#5ccf3c", "#2f8a20"))]:
        d = Doc("mn")
        b = ellipse(60, 108, 40, 9, "#000000", 0.25)
        b += circle(60, 58, 50, "#3a2212")
        b += circle(60, 55, 48, d.lin([(0, "#e8b070"), (1, "#7a4622")], 0, 0, 0, 1))
        b += circle(60, 55, 38, d.rad([(0, cols[0]), (0.6, cols[1]), (1, cols[2])], 0.4, 0.3, 0.8), extra=ol(2.4))
        b += ellipse(46, 36, 14, 7, "#ffffff", 0.45, -25)
        write(name, d.svg(120, 120, b))

    # Small castle emblem for the logo.
    d = Doc("lg")
    stone = d.lin([(0, "#f2f4f6"), (1, "#a8b0ba")], 0, 0, 0, 1)
    roof = d.lin([(0, "#ff7a5a"), (1, "#b82a1c")], 0, 0, 0, 1)
    b = rect(14, 40, 72, 50, 4, stone, extra=ol(2.4))
    for x in (8, 66):
        b += rect(x, 26, 26, 64, 3, stone, extra=ol(2.4))
        b += poly([(x - 3, 28), (x + 13, 4), (x + 29, 28)], roof, extra=ol(2.4))
    b += path("M40 90 L40 64 Q50 54 60 64 L60 90 Z", d.lin([(0, "#9a5f30"), (1, "#5a3214")], 0, 0, 0, 1), extra=ol(2.2))
    b += rect(19, 2, 3, 12, 1, OL) + poly([(22, 2), (34, 6), (22, 10)], "#e0302a", extra=ol(1.4))
    write("logo_castle", d.svg(100, 94, b))


def mechanism_assets():
    # Exposed structural fault marker.
    d = Doc("wp")
    b = circle(32, 32, 26, d.rad([(0, "#fff3a0", 0.95), (0.45, "#ff9a32", 0.72), (1, "#e03a24", 0.08)]))
    b += path("M10 37 L25 27 L31 35 L40 18 L44 31 L55 24", stroke=OL, sw=5)
    b += path("M10 37 L25 27 L31 35 L40 18 L44 31 L55 24", stroke="#fff0a0", sw=2)
    write("weak_point", d.svg(64, 64, b))

    # Earthbreak shockwave ribbon.
    d = Doc("qw")
    b = ellipse(256, 42, 250, 31, d.rad([(0, "#e9fbff", 0.9), (0.45, "#75dcff", 0.55), (1, "#3d8fc4", 0)]))
    b += path("M8 42 Q70 8 128 42 Q194 76 256 42 Q318 8 382 42 Q448 76 504 42", "none", 0.9, "#d9f8ff", 5)
    write("shockwave", d.svg(512, 84, b))

    # Iron-bound gate.
    d = Doc("gt")
    wood = d.lin([(0, "#e0a35c"), (0.5, "#ad672f"), (1, "#70401d")], 0, 0, 1, 0)
    iron = d.lin([(0, "#dce2e8"), (0.5, "#7c8793"), (1, "#39434e")], 0, 0, 1, 0)
    b = rect(3, 3, 104, 174, 7, wood, extra=ol(3))
    for x in (20, 42, 64, 86):
        b += rect(x, 5, 8, 170, 3, d.lin([(0, "#f1bb73"), (1, "#78431e")], 0, 0, 1, 0), extra=ol(1.6))
    for y in (25, 88, 148):
        b += rect(1, y, 108, 13, 4, iron, extra=ol(2))
    for x in (11, 99):
        for y in (31, 94, 154):
            b += circle(x, y, 3, "#eef2f5", extra='stroke="#313943" stroke-width="1"')
    write("mechanism_gate", d.svg(110, 180, b))

    d = Doc("db")
    wood = d.lin([(0, "#f2bd77"), (0.5, "#c67c3b"), (1, "#78431e")], 0, 0, 0, 1)
    b = rect(2, 2, 236, 36, 7, wood, extra=ol(3))
    for x in range(18, 230, 34):
        b += path(f"M{x} 4 L{x} 36", stroke="#75411e", sw=1.5, op=0.55)
        b += circle(x, 10, 2.6, "#cbd2da", extra='stroke="#38414a" stroke-width="1"')
    b += rect(5, 5, 230, 5, 2, "#ffffff", 0.24)
    write("mechanism_drawbridge", d.svg(240, 40, b))

    d = Doc("pl")
    iron = d.rad([(0, "#e9edf1"), (0.5, "#8c97a2"), (1, "#39434e")], 0.36, 0.3, 0.8)
    b = circle(27, 27, 24, iron, extra=ol(2.4)) + circle(27, 27, 15, "#4a3425") + circle(27, 27, 6, "#dce2e8", extra=ol(1.4))
    b += path("M12 18 Q27 8 42 18", stroke="#ffffff", sw=2.4, op=0.35)
    write("mechanism_pulley", d.svg(54, 54, b))

    d = Doc("cw")
    iron = d.lin([(0, "#b8c1ca"), (0.5, "#67727e"), (1, "#303943")], 0, 0, 1, 1)
    b = path("M12 4 L48 4 L57 65 Q30 80 3 65 Z", iron, extra=ol(2.5))
    b += rect(19, 0, 22, 10, 4, "#9d7547", extra=ol(1.8))
    b += ellipse(22, 23, 9, 4, "#ffffff", 0.24, -25)
    write("mechanism_counterweight", d.svg(60, 76, b))

    d = Doc("mp")
    wood = d.lin([(0, "#f1ba72"), (0.5, "#c67b39"), (1, "#71401d")], 0, 0, 0, 1)
    b = rect(2, 2, 326, 36, 8, wood, extra=ol(3)) + rect(8, 5, 314, 5, 2, "#ffffff", 0.25)
    for x in (28, 165, 302):
        b += circle(x, 22, 5, "#87929e", extra=ol(1.4))
    write("mechanism_platform", d.svg(330, 40, b))

    d = Doc("sw")
    iron = d.rad([(0, "#dfe5ea"), (0.45, "#77828e"), (1, "#303943")], 0.35, 0.3, 0.8)
    pts = star_points(38, 38, 37, 27, 12)
    b = poly(pts, iron, extra=ol(2.5)) + circle(38, 38, 25, iron, extra=ol(2)) + ellipse(28, 25, 10, 5, "#ffffff", 0.28, -25)
    write("mechanism_swing", d.svg(76, 76, b))

    d = Doc("sp")
    iron = d.lin([(0, "#edf1f4"), (0.55, "#8d98a3"), (1, "#3d4650")], 0, 0, 0, 1)
    b = rect(2, 34, 176, 9, 3, "#5d4530", extra=ol(2))
    for i in range(9):
        x = 5 + i * 20
        b += poly([(x, 35), (x + 10, 2 + (i % 2) * 5), (x + 20, 35)], iron, extra=ol(1.8))
    write("mechanism_spikes", d.svg(180, 44, b))

    d = Doc("lv")
    lava = d.lin([(0, "#fff08a"), (0.35, "#ffad22"), (0.75, "#f24a1d"), (1, "#8f1718")], 0, 0, 0, 1)
    top = " ".join(f"L{x} {8 + 4 * math.sin(x * 0.11):.1f}" for x in range(0, 241, 12))
    b = path(f"M0 10 {top} L240 50 L0 50 Z", lava, extra=ol(2.2))
    for x in (35, 92, 156, 211):
        b += circle(x, 25 + (x % 3) * 4, 5 + x % 4, "#fff5a8", 0.65)
    write("mechanism_lava", d.svg(240, 50, b))

    d = Doc("cg")
    iron = d.lin([(0, "#dfe4e9"), (0.55, "#7d8792"), (1, "#343d47")], 0, 0, 1, 0)
    b = path("M8 138 L8 45 Q8 5 60 5 Q112 5 112 45 L112 138", "none", 1, OL, 12)
    for x in (16, 38, 60, 82, 104):
        b += rect(x - 4, 32, 8, 104, 4, iron, extra=ol(1.6))
    b += rect(4, 125, 112, 13, 5, iron, extra=ol(2))
    b += circle(60, 84, 10, "#ffc93a", extra=ol(2)) + rect(56, 83, 8, 17, 3, "#8b5b14")
    write("mechanism_cage", d.svg(120, 140, b))

    d = Doc("al")
    leaf_fill = d.lin([(0, "#d9f58b"), (1, "#4f9e26")], 0, 0, 1, 1)
    write("ambient_leaf", d.svg(40, 24, path("M2 12 Q18 -2 38 8 Q22 26 2 12 Z", leaf_fill, extra=ol(1.2)) + path("M5 12 L34 8", stroke="#36751f", sw=1)))
    d = Doc("as")
    write("ambient_streak", d.svg(12, 70, path("M8 2 L3 68", stroke="#d9efff", sw=4, op=0.75)))


# --------------------------------------------------------------------------- stage (placeholders)
# Ledge + fortress bases per realm. The walkable top is at y = STAGE_TOP in every file (the game
# reads the same number: Art.STAGE_SVG_TOP). AI images named stage_* replace these automatically.
STAGE_TOP = 24
STAGE_STYLE = {
    "blossom": {"body": ("#b9c0cc", "#6d7584", "#3c4250"), "top": ("#c8f57a", "#5fae2e", "#2f6e1c"),
                "kind": "masonry", "accent": "#ff9ac4"},
    "desert": {"body": ("#f2b36f", "#c56a37", "#7a3a20"), "top": ("#ffe3a0", "#e3b25e", "#b0782e"),
               "kind": "strata", "accent": "#7fc23a"},
    "harbor": {"body": ("#c98b4f", "#8a5228", "#4e2c14"), "top": ("#e9b878", "#b77a40", "#7a4a22"),
               "kind": "pier", "accent": "#d6ad72"},
    "mines": {"body": ("#6c6470", "#433d4a", "#221e28"), "top": ("#8a8290", "#5d5664", "#3a3440"),
              "kind": "lava_rock", "accent": "#7fe6ff"},
    "sky": {"body": ("#c9b9a0", "#8a775f", "#4d4033"), "top": ("#d2f878", "#7cc63a", "#3a7e22"),
            "kind": "floating", "accent": "#ffffff"},
}


def _rugged_side(rnd, x, y0, y1, out, steps=7):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        pts.append((x + out * rnd.uniform(-1.0, 1.0) * (0.4 + t), y0 + (y1 - y0) * t))
    return pts


def stage_piece(name, key, W, H, ledge=False):
    st = STAGE_STYLE[key]
    rnd = random.Random(sum(map(ord, name)))
    d = Doc("st" + str(abs(hash(name)) % 997))
    T = STAGE_TOP
    c0, c1, c2 = st["body"]
    body = d.lin([(0, c0), (0.45, c1), (1, c2)], 0, 0, 0.35, 1)
    kind = st["kind"]
    b = ""
    if kind == "pier":
        # Deck on round posts: open gaps between the posts let the water show through.
        n = max(3, int(W / 130))
        for i in range(n):
            x = 18 + i * (W - 56) / (n - 1)
            post = d.lin([(0, "#b77a40"), (0.5, "#7e4a22"), (1, "#4a2a12")], 0, 0, 1, 0)
            b += rect(x, T + 20, 26, H - T - 22, 6, post, extra=ol(2.4))
            for y in range(int(T + 60), H - 20, 70):
                b += path(f"M{f(x-2)} {y} Q{f(x+13)} {y+10} {f(x+28)} {y}", stroke="#d6ad72", sw=4)
        b += rect(4, T + 18, W - 8, 16, 4, d.lin([(0, "#8a5228"), (1, "#5a3214")]), extra=ol(2))
    else:
        bottom_inset = W * (0.32 if kind == "floating" else 0.06)
        left = _rugged_side(rnd, 6, T + 10, H - 8, 10)
        right = _rugged_side(rnd, W - 6, T + 10, H - 8, 10)
        if ledge:
            left = [(-4, T + 10), (-4, H)]
            right = [(p[0] - (p[1] - T) / H * 30, p[1]) for p in right]
        else:
            left = [(p[0] + (p[1] - T) / H * bottom_inset, p[1]) for p in left]
            right = [(p[0] - (p[1] - T) / H * bottom_inset, p[1]) for p in right]
        if kind == "floating" and not ledge:
            spikes = []
            x0, x1 = left[-1][0], right[-1][0]
            for i in range(1, 6):
                xx = x0 + (x1 - x0) * i / 6
                spikes.append((xx, H - 4 if i % 2 else H - 40))
            pts = left + spikes + right[::-1]
        else:
            pts = left + [(left[-1][0], H), (right[-1][0], H)] + right[::-1]
        b += poly(pts, body, extra=ol(2.6))
        if kind == "masonry":
            for row, y in enumerate(range(T + 30, H - 10, 46)):
                off = 0 if row % 2 else 38
                for x in range(-20 + off, W, 76):
                    b += rect(x + 3, y, 70, 40, 10, d.lin([(0, c0), (1, c1)], 0, 0, 0.4, 1), 0.9, ol(1.6))
                    b += path(f"M{x+12} {y+7} L{x+50} {y+6}", stroke="#ffffff", sw=2, op=0.25)
        elif kind == "strata":
            for y in range(T + 34, H - 10, 34):
                wav = " ".join(f"L{x} {f(y + 5 * math.sin(x * 0.03 + y))}" for x in range(0, W + 1, 20))
                b += path(f"M0 {y} {wav}", stroke=c2, sw=2.4, op=0.45)
                b += path(f"M0 {y+5} {wav}", stroke="#ffe0b0", sw=1.6, op=0.3)
            if not ledge and W > 300:
                ax = W * 0.5
                b += path(f"M{f(ax-46)} {H} L{f(ax-46)} {H-70} Q{f(ax)} {H-130} {f(ax+46)} {H-70} L{f(ax+46)} {H} Z",
                          "#5a2a14", 0.75, OL, 2.2)
        elif kind == "lava_rock":
            for _ in range(int(W / 70)):
                x = rnd.uniform(40, W - 40)
                y = rnd.uniform(T + 50, H - 30)
                crack = f"M{f(x)} {f(y)} L{f(x+rnd.uniform(-30,30))} {f(y+25)} L{f(x+rnd.uniform(-30,30))} {f(y+55)}"
                b += path(crack, stroke="#ff7a1f", sw=5, op=0.9) + path(crack, stroke="#fff08a", sw=1.8)
            for _ in range(2):
                x = rnd.uniform(60, W - 60)
                y = rnd.uniform(T + 40, T + 120)
                b += poly([(x - 12, y + 30), (x - 4, y - 18), (x + 6, y + 30)], st["accent"], 0.95, ol(1.6))
                b += poly([(x + 4, y + 30), (x + 14, y - 4), (x + 22, y + 30)], "#c6f6ff", 0.9, ol(1.4))
        else:  # floating
            for _ in range(int(W / 50)):
                x = rnd.uniform(30, W - 30)
                y = rnd.uniform(T + 40, H * 0.75)
                b += ellipse(x, y, rnd.uniform(14, 34), rnd.uniform(8, 16), c2, 0.3, rnd.uniform(-20, 20))
    # Walkable top strip (flat at y = T); grass/sand hangs down over the lip.
    t0, t1, t2 = st["top"]
    topfill = d.lin([(0, t0), (0.45, t1), (1, t2)], 0, 0, 0, 1)
    lip = " ".join(f"L{x} {f(T + 18 + 5 * math.sin(x * 0.07) + 3 * math.sin(x * 0.19))}" for x in range(W, -1, -10))
    if kind == "pier":
        b += rect(0, T, W, 20, 3, topfill, extra=ol(2.4))
        for x in range(0, W, 46):
            b += path(f"M{x} {T+1} L{x} {T+19}", stroke=OL, sw=1.6, op=0.7)
            b += circle(x + 8, T + 10, 1.8, "#cbd2da")
    else:
        b += path(f"M0 {T} L{W} {T} {lip} Z", topfill, extra=ol(2.4))
        b += path(f"M4 {T+2} L{W-4} {T+2}", stroke="#ffffff", sw=2.2, op=0.35)
        if kind in ("masonry", "floating", "strata"):
            for x in range(6, W - 4, 9):
                h = rnd.uniform(4, 10)
                b += path(f"M{x} {T+1} Q{x+1} {f(T-h)} {x+4} {f(T-h-1)}", stroke=t0, sw=1.6, op=0.85)
        if kind == "lava_rock" and ledge:
            b += rect(0, T - 10, W, 5, 2, "#7c8793", extra=ol(1.2))
            for x in range(10, W, 40):
                b += rect(x, T - 6, 22, 6, 1, "#6a4426", extra=ol(1))
    for _ in range(int(W / 120)):
        x = rnd.uniform(20, W - 20)
        if kind in ("masonry", "floating"):
            for k in range(5):
                a = k * 1.256
                b += circle(x + 3.5 * math.cos(a), T - 3 + 3.5 * math.sin(a), 2.2, st["accent"])
            b += circle(x, T - 3, 1.6, "#f39a2d")
    write(name, d.svg(W, H, b))


def gap_assets():
    d = Doc("gw")
    W, H = 256, 40
    crest = " ".join(f"L{x} {f(14 + 6 * math.sin(2 * math.pi * 2 * x / W) + 2 * math.sin(2 * math.pi * 5 * x / W))}"
                     for x in range(0, W + 1, 4))
    fill = d.lin([(0, "#ffffff", 0.95), (0.5, "#ffffff", 0.45), (1, "#ffffff", 0)])
    b = path(f"M0 {H} {crest} L{W} {H} Z", fill)
    b += path("M0 14 " + crest, stroke="#ffffff", sw=3, op=0.9)
    write("gap_wave", d.svg(W, H, b))
    d = Doc("gc")
    W, H = 256, 80
    fill = d.rad([(0, "#ffffff", 1), (0.7, "#ffffff", 0.95), (1, "#ffffff", 0)], 0.5, 0.45, 0.6)
    b = ""
    for x, y, r in [(0, 46, 34), (48, 36, 30), (96, 44, 36), (150, 34, 32), (204, 42, 34), (256, 46, 34)]:
        b += circle(x, y, r, fill)
    b += rect(0, 46, W, 34, 0, "#ffffff")
    write("gap_cloud", d.svg(W, H, b))


def stage_assets():
    for key in STAGE_STYLE:
        stage_piece(f"stage_ledge_{key}", key, 900, 440, ledge=True)
        stage_piece(f"stage_base_{key}_wide", key, 520, 300)
        stage_piece(f"stage_base_{key}_small", key, 240, 260)
    gap_assets()


def boss_assets():
    """Placeholder dressing for the moving boss castles (AI boss_* images replace them)."""
    wood = lambda d: d.lin([(0, "#e0a35c"), (0.5, "#a8642e"), (1, "#5e3517")], 0, 0, 0, 1)
    iron = lambda d: d.rad([(0, "#e9edf1"), (0.5, "#7c8793"), (1, "#343d47")], 0.36, 0.3, 0.8)
    # Siege tower chassis: beam frame on four wheels.
    d = Doc("bw")
    W, H = 480, 150
    b = rect(6, 4, W - 12, 46, 8, wood(d), extra=ol(3))
    for x in range(30, W - 20, 60):
        b += path(f"M{x} 8 L{x+40} 46", stroke="#5e3517", sw=4, op=0.6)
    for x in (70, 180, 300, 410):
        b += circle(x, 96, 50, wood(d), extra=ol(3)) + circle(x, 96, 42, "none", extra=f'stroke="#7c8793" stroke-width="7"')
        for k in range(6):
            a = k * math.pi / 3
            b += path(f"M{x} 96 L{f(x + 40 * math.cos(a))} {f(96 + 40 * math.sin(a))}", stroke="#5e3517", sw=5)
        b += circle(x, 96, 10, iron(d), extra=ol(2))
    write("boss_siege_wheels", d.svg(W, H, b))
    # Galleon hull.
    d = Doc("bg")
    W, H = 520, 200
    hull = d.lin([(0, "#b8743a"), (0.55, "#7a4220"), (1, "#3e200c")], 0, 0, 0, 1)
    b = path(f"M0 6 L{W} 6 Q{W-30} 150 {W-110} {H-6} L110 {H-6} Q20 150 0 6 Z", hull, extra=ol(3))
    for y in (40, 80, 120):
        b += path(f"M{f(8 + y*0.25)} {y} L{f(W - 8 - y*0.25)} {y}", stroke="#3e200c", sw=2.4, op=0.6)
    b += rect(0, 4, W, 18, 4, "#d9a441", extra=ol(2))
    for x in range(70, W - 60, 80):
        b += circle(x, 62, 13, "#2a1a10", extra=ol(2)) + circle(x, 62, 8, iron(d))
    write("boss_galleon_hull", d.svg(W, H, b))
    # Foundry mine cart on rails.
    d = Doc("bm")
    W, H = 480, 130
    b = path(f"M8 4 L{W-8} 4 L{W-40} 84 L40 84 Z", d.lin([(0, "#8c97a2"), (1, "#39434e")]), extra=ol(3))
    for x in range(40, W - 30, 70):
        b += circle(x, 20, 4, "#dce2e8", extra=ol(1))
    b += path("M60 44 L420 44", stroke="#ff7a1f", sw=4, op=0.8)
    for x in (90, 200, 290, 390):
        b += circle(x, 100, 26, iron(d), extra=ol(2.6)) + circle(x, 100, 8, "#2a1a10")
    write("boss_mine_cart", d.svg(W, H, b))
    # Airship gondola + balloon.
    d = Doc("bd")
    W, H = 500, 150
    b = path(f"M0 6 L{W} 6 Q{W-20} 110 {W-90} {H-8} L90 {H-8} Q20 110 0 6 Z", hull, extra=ol(3))
    b += rect(0, 4, W, 16, 4, "#9aa4ae", extra=ol(2))
    for x in range(60, W - 40, 70):
        b += circle(x, 40, 4, "#dce2e8", extra=ol(1))
    b += ellipse(W - 16, 70, 10, 34, iron(d), extra=ol(2))
    write("boss_airship_deck", d.svg(W, H, b))
    d = Doc("bb")
    W, H = 560, 230
    env = d.rad([(0, "#ff8a7a"), (0.55, "#b8302a"), (1, "#5a1210")], 0.4, 0.3, 0.8)
    b = ellipse(W / 2, 100, W / 2 - 6, 94, env, extra=ol(3))
    for x in (140, 280, 420):
        b += path(f"M{x} 8 Q{x + (x - 280) * 0.2} 100 {x} 192", stroke="#3a3a44", sw=8, op=0.8)
    for x in (120, 280, 440):
        b += path(f"M{x} 186 L{280 + (x - 280) * 0.7} 228", stroke="#5e3517", sw=3)
    b += ellipse(200, 50, 70, 18, "#ffffff", 0.3, -8)
    write("boss_airship_balloon", d.svg(W, H, b))


def phase_d_mechanisms():
    """Lever, windmill arm + hub, orbiting shield plate, hidden rune switch, trap door."""
    iron = lambda d: d.lin([(0, "#dfe4e9"), (0.5, "#7d8792"), (1, "#343d47")], 0, 0, 1, 1)
    wood = lambda d: d.lin([(0, "#e8ad66"), (0.5, "#b06a32"), (1, "#6e3e1c")], 0, 0, 0, 1)
    stone = lambda d: d.lin([(0, "#d9d2c4"), (0.5, "#a69c8c"), (1, "#6c6458")], 0, 0, 0, 1)
    # Lever base: a stone block with a dark slot and a brass ring.
    d = Doc("lvb")
    b = rect(4, 18, 72, 40, 8, stone(d), extra=ol(3))
    b += rect(30, 14, 20, 12, 4, "#3a2e26", extra=ol(2))
    b += ellipse(40, 18, 16, 6, d.lin([(0, "#fff3a0"), (1, "#b87a14")]), extra=ol(2))
    b += path("M12 36 L24 40 M52 46 L66 42", stroke="#5c5448", sw=2.4)
    b += ellipse(20, 26, 12, 3, "#ffffff", 0.35)
    write("mechanism_lever_base", d.svg(80, 60, b))
    # Lever handle: a wooden stick with an iron collar and a red knob (pivot at the bottom).
    d = Doc("lvh")
    b = rect(14, 22, 12, 82, 5, wood(d), extra=ol(2.6))
    b += rect(11, 86, 18, 12, 3, iron(d), extra=ol(2))
    b += circle(20, 18, 15, d.rad([(0, "#ffb0a0"), (0.5, "#e8402e"), (1, "#8a1a12")]), extra=ol(3))
    b += ellipse(15, 12, 5, 3, "#ffffff", 0.7, -30)
    write("mechanism_lever_handle", d.svg(40, 106, b))
    # Windmill arm: a wooden spar with a canvas sail lattice (drawn pointing right from the hub).
    d = Doc("wma")
    W, H = 300, 70
    b = rect(0, 29, W - 4, 12, 5, wood(d), extra=ol(2.6))
    b += rect(70, 4, W - 80, 62, 6, d.lin([(0, "#fff8e8"), (0.6, "#efdcb8"), (1, "#c8a878")], 0, 0, 0, 1), 0.95, ol(2.6))
    for x in range(100, W - 10, 40):
        b += path(f"M{x} 6 L{x} 64", stroke="#9a6538", sw=4)
    b += path(f"M72 35 L{W - 12} 35", stroke="#9a6538", sw=4)
    b += path(f"M80 12 L{W - 20} 12", stroke="#ffffff", sw=3, op=0.6)
    write("mechanism_windmill_arm", d.svg(W, H, b))
    # Windmill hub: iron gear with a glowing weak spot (hit it to jam the mill).
    d = Doc("wmh")
    teeth = []
    for k in range(10):
        teeth.append(rect(44 - 7, 2, 14, 16, 3, iron(d), extra=ol(2)).replace("<rect", f'<rect transform="rotate({k * 36} 44 44)"'))
    b = "".join(teeth)
    b += circle(44, 44, 32, iron(d), extra=ol(3))
    b += circle(44, 44, 17, d.rad([(0, "#fff3a0", 1), (0.5, "#ff9a32", 0.9), (1, "#e03a24", 0.6)], 0.5, 0.5, 0.5), extra=ol(2.4))
    b += path("M34 48 L42 40 L46 46 L54 36", stroke=OL, sw=3)
    for k in range(6):
        a0 = math.radians(k * 60 + 30)
        b += circle(44 + 25 * math.cos(a0), 44 + 25 * math.sin(a0), 3, "#eef2f5", extra=ol(1))
    write("mechanism_windmill_hub", d.svg(88, 88, b))
    # Orbiting shield plate: curved riveted iron plate (drawn flat, length along x).
    d = Doc("shp")
    W, H = 160, 34
    b = rect(2, 3, W - 4, H - 6, 8, iron(d), extra=ol(3))
    b += rect(8, 8, W - 16, 6, 3, "#ffffff", 0.35)
    for x in range(14, W - 6, 26):
        b += circle(x, H / 2 + 3, 3, "#eef2f5", extra=ol(1))
    b += rect(W / 2 - 14, 4, 28, H - 8, 4, "#c8321e", 0.85, ol(1.6))
    write("mechanism_shield_plate", d.svg(W, H, b))
    # Hidden rune switch: a carved stone disc; the rune glows when revealed (tinted in code).
    d = Doc("rsw")
    b = circle(36, 36, 32, stone(d), extra=ol(3))
    b += circle(36, 36, 24, "#5c5448", 0.6)
    b += path("M36 16 L36 56 M22 26 L50 46 M50 26 L22 46", stroke="#7ae8ff", sw=5)
    b += circle(36, 36, 8, "#c8f6ff", extra=ol(1.6))
    write("mechanism_rune_switch", d.svg(72, 72, b))
    # Trap door: planks with iron bands and a ring pull.
    d = Doc("trp")
    W, H = 220, 26
    b = rect(2, 2, W - 4, H - 4, 4, wood(d), extra=ol(2.6))
    for x in range(40, W - 10, 44):
        b += path(f"M{x} 3 L{x} {H - 3}", stroke="#6e3e1c", sw=2.4)
    for x in (24, W - 24):
        b += rect(x - 8, 1, 16, H - 2, 2, iron(d), extra=ol(1.6))
    b += circle(W / 2, H / 2, 6, "none", extra='stroke="#dce2e8" stroke-width="3"')
    write("mechanism_trapdoor", d.svg(W, H, b))


def boss_rig_assets():
    """Power core, cannon turret, cannonball, engineer hat + hammer, boss-bar status icons."""
    iron = lambda d: d.lin([(0, "#dfe4e9"), (0.5, "#7d8792"), (1, "#343d47")], 0, 0, 1, 1)
    d = Doc("pcg")
    b = circle(64, 64, 62, d.rad([(0, "#c8f8ff", 0.9), (0.4, "#6ad8ff", 0.45), (1, "#2a8aff", 0.0)], 0.5, 0.5, 0.5))
    write("core_glow", d.svg(128, 128, b))
    d = Doc("cb")
    b = circle(16, 16, 13, d.rad([(0, "#9aa4ae"), (0.5, "#3a424c"), (1, "#14181c")]), extra=ol(2.4))
    b += ellipse(11, 11, 4, 2.5, "#ffffff", 0.6, -30)
    write("cannonball", d.svg(32, 32, b))
    # Engineer overlays (drawn over the archer art): yellow hard hat and a hammer.
    d = Doc("eh")
    b = path("M4 26 Q6 4 28 4 Q50 4 52 26 Z", d.lin([(0, "#fff08a"), (0.5, "#ffc21a"), (1, "#c88a0a")]), extra=ol(2.6))
    b += rect(0, 22, 56, 8, 4, "#e8a80e", extra=ol(2.4))
    b += rect(25, 4, 6, 20, 3, "#fff6b8", 0.8)
    write("engineer_hat", d.svg(56, 32, b))
    d = Doc("ehm")
    b = rect(17, 14, 7, 44, 3, d.lin([(0, "#e0a35c"), (1, "#7a4420")], 0, 0, 1, 0), extra=ol(2.2))
    b += rect(4, 2, 34, 15, 4, iron(d), extra=ol(2.4))
    write("engineer_hammer", d.svg(42, 60, b))
    # Boss-bar status icons (48x48).
    icons = {
        "status_core": circle(24, 24, 15, d.rad([(0, "#ffffff"), (0.4, "#9af6ff"), (1, "#2a7aff")], 0.5, 0.45, 0.6), extra=ol(2.6))
                       + path("M24 4 L24 10 M24 38 L24 44 M4 24 L10 24 M38 24 L44 24", stroke="#9af6ff", sw=3),
        "status_cannon": path("M4 16 L34 12 Q44 12 44 22 Q44 32 34 32 L4 28 Z", "#4a525c", extra=ol(2.6)) + circle(18, 36, 7, "#8a5a30", extra=ol(2)),
        "status_engineer": path("M6 30 Q8 10 24 10 Q40 10 42 30 Z", "#ffc21a", extra=ol(2.6)) + rect(2, 28, 44, 7, 3, "#e8a80e", extra=ol(2.2)),
        "status_armor": path("M24 4 L42 10 L40 28 Q36 40 24 45 Q12 40 8 28 L6 10 Z", iron(d), extra=ol(2.6)) + rect(20, 10, 8, 30, 2, "#c8321e", 0.9),
    }
    for name, body in icons.items():
        write(name, d.svg(48, 48, body))


def mode_icons():
    """Gold coin debris and the mode icons (64x64) for HUD chips and challenge cards."""
    for i in range(3):
        d = Doc("gd")
        r = 7 + i
        b = circle(r + 1, r + 1, r, d.lin([(0, "#fff3a0"), (0.5, "#ffc93a"), (1, "#b87a14")]), extra=ol(1.4))
        b += ellipse(r - 1, r - 2, r * 0.4, r * 0.2, "#ffffff", 0.6)
        write(f"debris_gold_{i}", d.svg(2 * r + 2, 2 * r + 2, b))
    gold = lambda d: d.lin([(0, "#fff3a0"), (0.5, "#ffc93a"), (1, "#b87a14")])
    d = Doc("im1")
    b = rect(8, 28, 48, 30, 5, d.lin([(0, "#e0603a"), (1, "#7a1a12")]), extra=ol(3))
    b += path("M8 32 Q8 10 32 10 Q56 10 56 32 Z", d.lin([(0, "#e0603a"), (1, "#a82a1e")]), extra=ol(3))
    b += rect(28, 26, 8, 12, 2, gold(d), extra=ol(1.6)) + rect(8, 28, 48, 5, 2, gold(d), extra=ol(1.4))
    write("icon_mode_heist", d.svg(64, 64, b))
    d = Doc("im2")
    b = path("M14 6 L50 6 L50 12 Q50 26 36 32 Q50 38 50 52 L50 58 L14 58 L14 52 Q14 38 28 32 Q14 26 14 12 Z", "#fff6e0", 0.9, extra=ol(3))
    b += path("M20 14 L44 14 Q40 24 32 28 Q24 24 20 14 Z", "#ffc93a") + path("M22 52 Q32 40 42 52 Z", "#ffc93a")
    b += rect(10, 3, 44, 7, 3, d.lin([(0, "#c88a4c"), (1, "#6e3e1c")]), extra=ol(2)) + rect(10, 54, 44, 7, 3, d.lin([(0, "#c88a4c"), (1, "#6e3e1c")]), extra=ol(2))
    write("icon_mode_time", d.svg(64, 64, b))
    d = Doc("im3")
    b = circle(32, 32, 26, "#ffffff", extra=ol(3)) + circle(32, 32, 18, "#e8402e") + circle(32, 32, 11, "#ffffff") + circle(32, 32, 5, "#e8402e")
    b += path("M48 8 L34 30", stroke=OL, sw=5) + path("M48 8 L34 30", stroke="#ffd23a", sw=2.6) + poly([(44, 4), (56, 4), (52, 14)], "#4ac0ff", extra=ol(1.6))
    write("icon_mode_oneshot", d.svg(64, 64, b))
    d = Doc("im4")
    b = path("M32 4 L56 12 L54 34 Q48 52 32 60 Q16 52 10 34 L8 12 Z", d.lin([(0, "#7fc8ff"), (1, "#2a5ac8")]), extra=ol(3))
    b += path("M18 30 Q24 24 30 30 Q36 36 42 30 Q46 26 50 28", stroke="#ffffff", sw=4) + path("M16 40 Q22 34 28 40 Q34 46 40 40 Q44 36 48 38", stroke="#ffffff", sw=4, op=0.7)
    write("icon_mode_survival", d.svg(64, 64, b))
    d = Doc("im5")
    b = path("M4 40 L60 40 L52 54 L12 54 Z", d.lin([(0, "#c88a4c"), (1, "#6e3e1c")]), extra=ol(3))
    b += rect(30, 8, 4, 32, 1, "#6e3e1c", extra=ol(1.4)) + path("M34 10 L54 22 L34 34 Z", "#fff6e0", extra=ol(2.2))
    b += path("M2 58 Q12 52 22 58 Q32 64 42 58 Q52 52 62 58", stroke="#4ac0ff", sw=4) + poly([(4, 22), (16, 14), (16, 30)], "#e8402e", extra=ol(1.6))
    write("icon_mode_reverse", d.svg(64, 64, b))
    d = Doc("im6")
    b = path("M6 46 L10 14 L22 30 L32 8 L42 30 L54 14 L58 46 Z", gold(d), extra=ol(3))
    b += rect(6, 44, 52, 10, 3, gold(d), extra=ol(2.4))
    for x, c in [(20, "#e0302a"), (32, "#3a8ae0"), (44, "#e0302a")]:
        b += circle(x, 38, 4, c, extra=ol(1.2))
    b += path("M2 60 L62 60", stroke="#e8402e", sw=4)
    write("icon_mode_rush", d.svg(64, 64, b))
    d = Doc("im7")
    b = rect(6, 10, 52, 48, 7, "#ffffff", extra=ol(3)) + rect(6, 10, 52, 14, 6, "#e8402e", extra=ol(3))
    b += rect(16, 4, 6, 12, 3, "#7d8792", extra=ol(1.6)) + rect(42, 4, 6, 12, 3, "#7d8792", extra=ol(1.6))
    b += path("M20 40 L28 48 L44 32", stroke="#3aa63a", sw=6)
    write("icon_mode_daily", d.svg(64, 64, b))
    d = Doc("im8")
    b = path("M32 4 L54 12 Q56 40 32 60 Q8 40 10 12 Z", d.lin([(0, "#dfe4e9"), (1, "#5c6670")]), extra=ol(3))
    b += path("M22 20 L42 44 M42 20 L22 44", stroke="#3a2212", sw=5)
    write("icon_mode_siege", d.svg(64, 64, b))


def weapon_icons():
    """Siege weapon icons (72x64) for the loadout picker and the Workshop rail."""
    wood = lambda d: d.lin([(0, "#e8ad66"), (0.5, "#b06a32"), (1, "#6e3e1c")], 0, 0, 0, 1)
    iron = lambda d: d.lin([(0, "#dfe4e9"), (0.5, "#7d8792"), (1, "#343d47")], 0, 0, 1, 1)
    def wheels(d):
        return circle(18, 54, 8, wood(d), extra=ol(2.4)) + circle(54, 54, 8, wood(d), extra=ol(2.4))
    d = Doc("wc")
    b = rect(8, 40, 56, 10, 4, wood(d), extra=ol(2.6)) + path("M22 42 L36 18 L50 42", stroke=OL, sw=7) + path("M22 42 L36 18 L50 42", stroke="#c88a4c", sw=4)
    b += path("M36 30 L62 8", stroke=OL, sw=7) + path("M36 30 L62 8", stroke="#e0a35c", sw=4) + circle(62, 8, 7, "#9a9a9a", extra=ol(2))
    write("icon_weapon_catapult", d.svg(72, 64, b + wheels(d)))
    d = Doc("wb")
    b = rect(8, 40, 56, 10, 4, wood(d), extra=ol(2.6)) + rect(30, 26, 12, 16, 3, wood(d), extra=ol(2.2))
    b += path("M14 30 Q36 14 58 30", stroke=OL, sw=6) + path("M14 30 Q36 14 58 30", stroke="#c88a4c", sw=3)
    b += path("M10 24 L66 24", stroke=OL, sw=5) + path("M10 24 L66 24", stroke="#e0a35c", sw=2.6) + poly([(66, 18), (72, 24), (66, 30)], iron(d), extra=ol(1.6))
    b += path("M14 30 L36 24 L58 30", stroke="#f6e8c8", sw=1.6)
    write("icon_weapon_ballista", d.svg(72, 64, b + wheels(d)))
    d = Doc("wt")
    b = rect(6, 42, 60, 9, 4, wood(d), extra=ol(2.6)) + path("M14 44 L36 8 L58 44", stroke=OL, sw=7) + path("M14 44 L36 8 L58 44", stroke="#c88a4c", sw=4)
    b += path("M8 28 L64 4", stroke=OL, sw=6) + path("M8 28 L64 4", stroke="#e0a35c", sw=3) + rect(2, 26, 14, 14, 3, iron(d), extra=ol(2))
    b += path("M64 4 L66 18", stroke="#f6e8c8", sw=1.6) + circle(66, 20, 4, "#9a9a9a", extra=ol(1.6))
    write("icon_weapon_trebuchet", d.svg(72, 64, b + wheels(d)))


def meta_icons():
    """Meta-screen icon set (64x64, glossy, dark outline): rail tabs, home tiles, bottom bar, rewards."""
    gold = lambda d: d.lin([(0, "#fff3a0"), (0.5, "#ffc93a"), (1, "#b87a14")])
    wood = lambda d: d.lin([(0, "#e8ad66"), (0.5, "#b06a32"), (1, "#6e3e1c")], 0, 0, 0, 1)
    iron = lambda d: d.lin([(0, "#dfe4e9"), (0.5, "#7d8792"), (1, "#343d47")], 0, 0, 1, 1)
    red = lambda d: d.lin([(0, "#ff8070"), (0.5, "#d8302a"), (1, "#8a1a12")])
    out = {}
    # spin wheel
    d = Doc("mw")
    b = circle(32, 32, 28, wood(d), extra=ol(3))
    cols = ["#ffc93a", "#9a3ad8", "#3a8ae0", "#e8402e", "#ffc93a", "#9a3ad8", "#3a8ae0", "#7ae05a"]
    for k in range(8):
        a0, a1 = math.radians(k * 45 - 90), math.radians(k * 45 - 45)
        b += path(f"M32 32 L{f(32 + 23 * math.cos(a0))} {f(32 + 23 * math.sin(a0))} A23 23 0 0 1 {f(32 + 23 * math.cos(a1))} {f(32 + 23 * math.sin(a1))} Z", cols[k])
    b += circle(32, 32, 7, gold(d), extra=ol(2)) + poly([(26, 2), (38, 2), (32, 12)], "#e0302a", extra=ol(2))
    out["icon_spin"] = (d, b)
    # daily calendar
    d = Doc("md")
    b = rect(6, 12, 52, 46, 7, "#ffffff", extra=ol(3)) + rect(6, 12, 52, 14, 6, red(d), extra=ol(3))
    b += rect(16, 5, 6, 13, 3, iron(d), extra=ol(1.6)) + rect(42, 5, 6, 13, 3, iron(d), extra=ol(1.6))
    b += path("M20 40 L28 48 L44 32", stroke="#e8402e", sw=6)
    out["icon_daily"] = (d, b)
    # shop: chest with coins
    d = Doc("ms")
    b = rect(6, 30, 52, 28, 5, red(d), extra=ol(3)) + path("M6 32 Q6 12 32 12 Q58 12 58 32 Z", red(d), extra=ol(3))
    b += rect(6, 30, 52, 5, 2, gold(d), extra=ol(1.4)) + rect(27, 27, 10, 13, 2, gold(d), extra=ol(1.6))
    b += circle(16, 12, 7, gold(d), extra=ol(1.6)) + circle(48, 10, 6, gold(d), extra=ol(1.6))
    out["icon_shop"] = (d, b)
    # events: red ribbon banner with a star
    d = Doc("me")
    b = path("M14 4 L50 4 L50 56 L32 46 L14 56 Z", red(d), extra=ol(3)) + poly(star_points(32, 24, 12, 5), gold(d), extra=ol(1.6))
    out["icon_events"] = (d, b)
    # challenges: crossed swords
    d = Doc("mc")
    for flip in (1, -1):
        g = path("M10 10 L44 44", stroke=OL, sw=8) + path("M10 10 L44 44", stroke="#e8eef4", sw=4.5)
        g += path("M38 50 L50 38", stroke=OL, sw=7) + path("M38 50 L50 38", stroke="#ffc93a", sw=4)
        g += circle(52, 52, 5, "#8a5a30", extra=ol(1.6))
        b = b if flip == -1 else ""
        out.setdefault("_sw", []).append(g if flip == 1 else f'<g transform="translate(64 0) scale(-1 1)">{g}</g>')
    out["icon_challenges"] = (d, "".join(out.pop("_sw")))
    # achievements: trophy
    d = Doc("ma")
    b = path("M16 8 L48 8 L46 30 Q44 42 32 42 Q20 42 18 30 Z", gold(d), extra=ol(3))
    b += path("M16 12 Q4 12 6 22 Q8 30 18 30", stroke=OL, sw=6) + path("M48 12 Q60 12 58 22 Q56 30 46 30", stroke=OL, sw=6)
    b += path("M16 12 Q4 12 6 22 Q8 30 18 30", stroke="#ffc93a", sw=3) + path("M48 12 Q60 12 58 22 Q56 30 46 30", stroke="#ffc93a", sw=3)
    b += rect(28, 42, 8, 8, 1, gold(d), extra=ol(2)) + rect(18, 50, 28, 8, 3, wood(d), extra=ol(2.4)) + poly(star_points(32, 22, 8, 3.5), "#fff6c0")
    out["icon_achievements"] = (d, b)
    # settings: gear
    d = Doc("mg")
    teeth = "".join(f'<rect x="27" y="2" width="10" height="14" rx="3" fill="#a8b2bc" stroke="{OL}" stroke-width="2.4" transform="rotate({k * 45} 32 32)"/>' for k in range(8))
    b = teeth + circle(32, 32, 20, iron(d), extra=ol(3)) + circle(32, 32, 8, "#3a4048", extra=ol(2))
    out["icon_settings"] = (d, b)
    # mail
    d = Doc("mm")
    b = rect(6, 14, 52, 38, 5, "#fff6e0", extra=ol(3)) + path("M8 16 L32 36 L56 16", stroke=OL, sw=3) + circle(52, 14, 7, "#e8402e", extra=ol(2))
    out["icon_mail"] = (d, b)
    # armory/skins: paint palette
    d = Doc("mk")
    b = path("M32 6 Q58 6 58 30 Q58 44 46 44 Q38 44 40 52 Q40 58 30 58 Q6 58 6 32 Q6 6 32 6 Z", wood(d), extra=ol(3))
    for (x, y, c) in [(20, 22, "#e8402e"), (32, 16, "#ffc93a"), (44, 22, "#3a8ae0"), (18, 36, "#7ae05a"), (28, 46, "#9a3ad8")]:
        b += circle(x, y, 5, c, extra=ol(1.6))
    out["icon_skins"] = (d, b)
    # upgrades: hammer + up arrow
    d = Doc("mu")
    b = rect(28, 22, 8, 36, 3, wood(d), extra=ol(2.4)) + rect(12, 10, 40, 16, 4, iron(d), extra=ol(3))
    b += path("M50 58 L50 40 M42 46 L50 38 L58 46", stroke=OL, sw=7) + path("M50 58 L50 40 M42 46 L50 38 L58 46", stroke="#6fdc45", sw=4)
    out["icon_upgrades"] = (d, b)
    # units: helmet
    d = Doc("mh")
    b = path("M10 44 Q8 12 32 10 Q56 12 54 44 Z", iron(d), extra=ol(3)) + rect(28, 6, 8, 40, 2, gold(d), extra=ol(1.6))
    b += path("M18 30 L46 30", stroke=OL, sw=4) + path("M24 4 Q32 -2 40 4", stroke="#e8402e", sw=6)
    out["icon_units"] = (d, b)
    # castle
    d = Doc("mt")
    b = rect(10, 24, 44, 34, 3, d.lin([(0, "#d9d2c4"), (1, "#8c8478")]), extra=ol(3))
    for x in (10, 22, 34, 46):
        b += rect(x, 16, 8, 10, 1, "#c8c0b2", extra=ol(2))
    b += path("M26 58 L26 42 Q32 34 38 42 L38 58 Z", "#5a3a20", extra=ol(2)) + path("M32 16 L32 2 L44 6 L32 10", "#3a8ae0", extra=ol(1.6))
    out["icon_castle"] = (d, b)
    # crown
    d = Doc("mr")
    b = path("M6 48 L10 16 L22 32 L32 8 L42 32 L54 16 L58 48 Z", gold(d), extra=ol(3)) + rect(6, 46, 52, 10, 3, gold(d), extra=ol(2.4))
    for x, c in [(20, "#e0302a"), (32, "#3a8ae0"), (44, "#e0302a")]:
        b += circle(x, 40, 4, c, extra=ol(1.2))
    out["icon_crown"] = (d, b)
    # chest (reward chest, closed) + open variant
    for name, open_ in (("chest_closed", False), ("chest_open", True)):
        d = Doc("ch" + ("o" if open_ else "c"))
        b = rect(6, 30, 52, 28, 5, red(d), extra=ol(3))
        if open_:
            b += path("M8 30 L4 8 Q32 -2 60 8 L56 30 Z", red(d), extra=ol(3)) + ellipse(32, 30, 24, 6, "#fff6c0", 0.95)
            b += circle(24, 26, 5, gold(d), extra=ol(1.4)) + circle(36, 24, 5, gold(d), extra=ol(1.4)) + poly([(42, 28), (48, 18), (54, 28)], "#c46aff", extra=ol(1.4))
        else:
            b += path("M6 32 Q6 12 32 12 Q58 12 58 32 Z", red(d), extra=ol(3))
        b += rect(14, 12 if not open_ else 30, 6, 46 if not open_ else 28, 2, gold(d), extra=ol(1.4)) + rect(44, 12 if not open_ else 30, 6, 46 if not open_ else 28, 2, gold(d), extra=ol(1.4))
        b += rect(6, 30, 52, 5, 2, gold(d), extra=ol(1.4)) + rect(27, 27, 10, 13, 2, gold(d), extra=ol(1.6))
        out[name] = (d, b)
    # video (watch ad)
    d = Doc("mv")
    b = rect(4, 14, 42, 36, 7, "#ffffff", extra=ol(3)) + poly([(46, 26), (60, 16), (60, 48), (46, 38)], "#ffffff", extra=ol(3))
    b += poly([(20, 22), (34, 32), (20, 42)], "#e8402e")
    out["icon_video"] = (d, b)
    # info "i"
    d = Doc("mi")
    b = circle(32, 32, 26, d.lin([(0, "#7fc8ff"), (1, "#2a5ac8")]), extra=ol(3)) + circle(32, 18, 5, "#ffffff") + rect(27, 27, 10, 24, 4, "#ffffff")
    out["icon_info"] = (d, b)
    # check + plus
    d = Doc("mk2")
    b = path("M10 34 L26 50 L56 16", stroke=OL, sw=12) + path("M10 34 L26 50 L56 16", stroke="#6fdc45", sw=7)
    out["icon_check"] = (d, b)
    # map scroll (secret)
    d = Doc("msc")
    b = rect(12, 10, 40, 44, 4, d.lin([(0, "#fff0c8"), (1, "#e8c486")]), extra=ol(3))
    b += rect(6, 6, 52, 9, 4, wood(d), extra=ol(2.4)) + rect(6, 50, 52, 9, 4, wood(d), extra=ol(2.4))
    b += path("M18 40 Q26 22 34 32 Q40 40 46 22", stroke="#c8321e", sw=3, extra='stroke-dasharray="4 3"') + path("M42 18 L50 26 M50 18 L42 26", stroke="#c8321e", sw=3)
    out["icon_secret"] = (d, b)
    # hammer (upgrade material)
    d = Doc("mhm")
    b = rect(28, 24, 9, 34, 3, wood(d), extra=ol(2.4)) + rect(10, 8, 44, 18, 4, iron(d), extra=ol(3))
    out["icon_hammer"] = (d, b)
    # trail icon (comet)
    d = Doc("mtr")
    b = path("M6 52 Q24 40 40 26", stroke="#ffc93a", sw=8, op=0.5) + path("M10 44 Q26 34 40 26", stroke="#ffffff", sw=4, op=0.7)
    b += circle(44, 22, 12, d.rad([(0, "#ffffff"), (0.6, "#ffd23a"), (1, "#e8902a")]), extra=ol(2.6))
    out["icon_trail"] = (d, b)
    # flag
    d = Doc("mfl")
    b = rect(12, 4, 6, 56, 2, wood(d), extra=ol(2)) + path("M18 8 Q34 2 44 10 Q52 16 58 10 L58 34 Q50 40 42 34 Q32 26 18 32 Z", "#3a8ae0", extra=ol(3))
    b += poly(star_points(36, 20, 7, 3), gold(d), extra=ol(1.2))
    out["icon_flag"] = (d, b)
    for name, (dd, body) in out.items():
        write(name, dd.svg(64, 64, body))
    # wheel slice dividers / pointer art for the spin wheel
    d = Doc("wp2")
    b = path("M24 2 L44 2 Q46 2 46 6 L36 40 Q34 44 32 40 L22 6 Q22 2 24 2 Z", d.lin([(0, "#ff8070"), (0.5, "#d8302a"), (1, "#7a1010")]), extra=ol(3))
    b += ellipse(30, 10, 5, 3, "#ffffff", 0.7)
    write("wheel_pointer", d.svg(68, 46, b))


def phase_c_assets():
    """Rope anchors, crusher, geyser, bolt, boss crown/shield, UI icons for Phase C mechanics."""
    iron = lambda d: d.lin([(0, "#dfe4e9"), (0.5, "#7d8792"), (1, "#343d47")], 0, 0, 1, 1)
    d = Doc("hk")
    b = rect(4, 4, 56, 18, 6, d.lin([(0, "#e0a35c"), (1, "#7a4420")], 0, 0, 0, 1), extra=ol(2.4))
    b += path("M32 22 L32 40 Q32 54 20 52 Q12 50 14 42", "none", 1, OL, 7) + path("M32 22 L32 40 Q32 54 20 52 Q12 50 14 42", "none", 1, "#cfd6de", 4)
    for x in (12, 52):
        b += circle(x, 13, 3, "#dce2e8", extra=ol(1))
    write("mechanism_hook", d.svg(64, 60, b))
    # Crusher: heavy iron-bound stone with spikes underneath.
    d = Doc("cr")
    W, H = 160, 130
    b = rect(4, 4, W - 8, H - 34, 10, d.lin([(0, "#c7ccd2"), (0.5, "#7b858f"), (1, "#3f4750")], 0, 0, 0.3, 1), extra=ol(3))
    for x in range(16, W - 10, 32):
        b += circle(x, 14, 3.5, "#eef2f5", extra=ol(1)) + circle(x, H - 44, 3.5, "#eef2f5", extra=ol(1))
    b += rect(10, 40, W - 20, 14, 4, "#ffb02e", 0.85, ol(1.6))
    for i in range(7):
        x = 8 + i * (W - 16) / 7
        b += poly([(x, H - 32), (x + (W - 16) / 14, H - 3), (x + (W - 16) / 7, H - 32)], iron(d), extra=ol(2))
    b += ellipse(44, 24, 24, 7, "#ffffff", 0.3, -6)
    write("mechanism_crusher", d.svg(W, H, b))
    # Geyser column (tinted per gap kind in game) + vent.
    d = Doc("gy")
    W, H = 90, 400
    col = d.lin([(0, "#ffffff", 0.95), (0.5, "#ffffff", 0.7), (1, "#ffffff", 0.15)], 0, 0, 0, 1)
    b = path(f"M30 {H} Q18 200 10 60 Q45 -10 80 60 Q72 200 60 {H} Z", col)
    for y in range(40, H, 46):
        b += ellipse(45 + 10 * math.sin(y), y, 26, 10, "#ffffff", 0.45)
    write("mechanism_geyser", d.svg(W, H, b))
    d = Doc("gv")
    b = path("M2 30 Q10 6 40 6 Q70 6 78 30 Z", d.lin([(0, "#8a8290"), (1, "#3a3440")]), extra=ol(2.4))
    b += ellipse(40, 12, 22, 5, "#1a1418", 0.9)
    write("mechanism_vent", d.svg(80, 32, b))
    # Bolt plate (joints).
    d = Doc("bt")
    b = rect(2, 2, 28, 28, 6, iron(d), extra=ol(2)) + circle(16, 16, 6, "#eef2f5", extra=ol(1.4))
    b += path("M12 16 L20 16", stroke=OL, sw=2)
    write("bolt", d.svg(32, 32, b))
    # Boss crown + shield bubble.
    d = Doc("bc")
    gold = d.lin([(0, "#fff3a0"), (0.5, "#ffc93a"), (1, "#b87a14")], 0, 0, 0, 1)
    b = path("M4 40 L8 10 L22 26 L32 4 L42 26 L56 10 L60 40 Z", gold, extra=ol(2.4))
    for x, c in [(18, "#e0302a"), (32, "#3a8ae0"), (46, "#e0302a")]:
        b += circle(x, 33, 4, c, extra=ol(1))
    write("boss_crown", d.svg(64, 44, b))
    d = Doc("bs")
    b = circle(80, 80, 76, d.rad([(0, "#bff4ff", 0.05), (0.75, "#7fd8ff", 0.25), (1, "#e9fbff", 0.85)], 0.5, 0.5, 0.5))
    b += path("M30 50 Q50 22 86 20", stroke="#ffffff", sw=6, op=0.7)
    write("boss_shield", d.svg(160, 160, b))
    # UI icons.
    d = Doc("iw")
    b = path("M6 22 L44 22 L44 10 L68 32 L44 54 L44 42 L6 42 Z", d.lin([(0, "#ffffff"), (1, "#bfe6ff")]), extra=ol(3))
    write("icon_wind", d.svg(74, 64, b))
    d = Doc("iws")
    b = rect(26, 30, 12, 34, 4, d.lin([(0, "#e0a35c"), (1, "#7a4420")]), extra=ol(2.4))
    b += path("M8 18 Q32 2 56 18 L52 32 L12 32 Z", iron(d), extra=ol(2.6))
    b += poly(star_points(50, 8, 7, 3), "#ffd84a", extra=ol(1.2))
    write("icon_workshop", d.svg(64, 66, b))
    d = Doc("cs")
    b = circle(40, 40, 34, "none", extra='stroke="#ffe27a" stroke-width="7"')
    b += circle(40, 40, 34, "none", extra=f'stroke="{OL}" stroke-width="2" opacity="0.6"')
    write("callout_ring", d.svg(80, 80, b))
    d = Doc("ca")
    b = path("M20 2 L20 30 L6 30 L30 58 L54 30 L40 30 L40 2 Z", d.lin([(0, "#fff3a0"), (1, "#ffb02e")]), extra=ol(3))
    write("callout_arrow", d.svg(60, 60, b))
    d = Doc("sp")
    b = ""
    for k in range(4):
        a = k * math.pi / 2
        b += poly([(32, 32), (32 + 30 * math.cos(a - 0.18), 32 + 30 * math.sin(a - 0.18)), (32 + 30 * math.cos(a), 32 + 30 * math.sin(a)) ,
                   (32 + 30 * math.cos(a + 0.18), 32 + 30 * math.sin(a + 0.18))], "#fff6c0")
    b += circle(32, 32, 9, "#ffffff")
    write("sparkle", d.svg(64, 64, b))


def reference_pack():
    flag()
    banner()
    ground_cliff()
    foreground()
    ui_pack()


# ------------------------------------------------------------------------------------ Phase D icons
def phase_d_icons():
    """Colour icons (128x128, thin dark outline) for HUD chips and menus, plus white button glyphs."""
    W = "#ffffff"
    # White 48x48 glyphs for round buttons.
    glyphs = {
        "icon_replay": path("M12 26 A13 13 0 1 0 17 14", stroke=W, sw=6) + poly([(8, 6), (22, 10), (12, 20)], W)
                       + path("M21 18 L33 25 L21 32 Z", W, extra='stroke="#ffffff" stroke-width="2" stroke-linejoin="round"'),
    }
    for name, body in glyphs.items():
        write(name, Doc().svg(48, 48, body))

    # Chain links: two interlocked gold links with a spark.
    d = Doc("ch")
    gold = d.lin([(0, "#fff3a0"), (0.45, "#ffc93a"), (1, "#c4780a")], 0, 0, 0, 1)
    dark = d.lin([(0, "#e8960c"), (1, "#8a4a06")], 0, 0, 0, 1)
    b = ""
    for (cx, cy, rot, fill) in [(46, 70, -35, dark), (82, 58, -35, gold)]:
        b += (f'<g transform="rotate({rot} {cx} {cy})">'
              + rect(cx - 30, cy - 17, 60, 34, 17, "none", 1, f'stroke="{OL}" stroke-width="18"')
              + rect(cx - 30, cy - 17, 60, 34, 17, "none", 1, f'stroke="{fill}" stroke-width="11"')
              + rect(cx - 24, cy - 15, 40, 4, 2, "#ffffff", 0.5) + "</g>")
    b += poly(star_points(104, 26, 16, 6), "#fff7c8", 1, f'stroke="{OL}" stroke-width="2.5" stroke-linejoin="round"')
    write("icon_chain", d.svg(128, 128, b))

    # Rune arrow: shown on rune crystals, points where the beam goes (rotated in game). Points right.
    d = Doc("ra")
    glow = d.rad([(0, "#ffffff", 0.9), (0.5, "#d9b0ff", 0.5), (1, "#a060ff", 0)], 0.5, 0.5, 0.5)
    b = ellipse(40, 24, 38, 20, glow)
    arrow = "M6 18 L42 18 L42 8 L74 24 L42 40 L42 30 L6 30 Z"
    b += path(arrow, "#ffffff", 1, OL, 3)
    b += path(arrow, d.lin([(0, "#fff6ff"), (1, "#c58bff")], 0, 0, 1, 0), 1)
    write("rune_arrow", d.svg(80, 48, b))
    # Heat glow: soft orange blob laid over red-hot iron.
    d = Doc("hg")
    write("heat_glow", d.svg(64, 64, circle(32, 32, 32, d.rad([(0, "#ffd080", 0.95), (0.55, "#ff6a1a", 0.6), (1, "#ff3a00", 0)], 0.5, 0.5, 0.5))))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    characters()
    blocks()
    debris()
    catapult()
    ground()
    mountains()
    hills()
    clouds()
    decor()
    ui()
    app_icon()
    mechanism_assets()
    reference_pack()
    stage_assets()
    boss_assets()
    phase_c_assets()
    phase_d_icons()
    phase_d_mechanisms()
    boss_rig_assets()
    mode_icons()
    weapon_icons()
    meta_icons()
    print("wrote", len([n for n in os.listdir(OUT) if n.endswith(".svg")]), "svg files to", OUT)
