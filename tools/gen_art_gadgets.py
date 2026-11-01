"""Vector art for the round 4 gadgets (src/game/gadget.gd): portal, magnet, bounce pad, pressure
plate, relay board and lamp, gravity field and field ring. Writes only these files into
assets/art/svg/ (the rest of the art comes from tools/gen_art.py).

Run: python3 tools/gen_art_gadgets.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_art import Doc, OL, OUT, circle, ellipse, ol, path, rect, write  # noqa: E402


def iron(d):
    return d.lin([(0, "#dfe4e9"), (0.5, "#7d8792"), (1, "#343d47")], 0, 0, 1, 1)


def stone(d):
    return d.lin([(0, "#d9d2c4"), (0.5, "#a69c8c"), (1, "#6c6458")], 0, 0, 0, 1)


def portal():
    d = Doc("ptr")
    b = circle(64, 64, 58, "none", extra=f'stroke="{OL}" stroke-width="16"')
    b += circle(64, 64, 58, "none", extra=f'stroke="{stone(d)}" stroke-width="11"')
    for k in range(8):
        a = math.radians(k * 45)
        x, y = 64 + 58 * math.cos(a), 64 + 58 * math.sin(a)
        b += circle(x, y, 4.5, "#7ae8ff", extra=ol(1.4))
    b += path("M20 40 A50 50 0 0 1 60 10", stroke="#ffffff", sw=3, op=0.5)
    write("gadget_portal_ring", d.svg(128, 128, b))
    d = Doc("psw")
    b = circle(64, 64, 56, d.rad([(0, "#ffffff", 1), (0.35, "#ffffff", 0.85), (1, "#ffffff", 0.05)], 0.5, 0.5, 0.5))
    for k in range(5):
        a0 = k * 72
        pts = []
        for i in range(24):
            t = i / 23
            r = 6 + 48 * t
            a = math.radians(a0 + t * 300)
            pts.append(f"{64 + r * math.cos(a):.1f} {64 + r * math.sin(a):.1f}")
        b += path("M" + " L".join(pts), stroke="#ffffff", sw=5, op=0.75)
    write("gadget_portal_swirl", d.svg(128, 128, b))


def magnet():
    d = Doc("mag")
    red = d.lin([(0, "#ff9a8a"), (0.5, "#e2382a"), (1, "#8a1a12")], 0, 0, 1, 1)
    tip = d.lin([(0, "#ffffff"), (0.5, "#c9d1d9"), (1, "#6d7782")], 0, 0, 1, 1)
    b = rect(40, 4, 48, 18, 4, iron(d), extra=ol(2.4))
    b += path("M20 30 L20 70 A44 44 0 0 0 108 70 L108 30 L82 30 L82 70 A18 18 0 0 1 46 70 L46 30 Z", red, 1, OL, 3)
    b += rect(20, 22, 26, 16, 3, tip, extra=ol(2.4))
    b += rect(82, 22, 26, 16, 3, tip, extra=ol(2.4))
    b += path("M28 46 L28 70 A36 36 0 0 0 44 100", stroke="#ffffff", sw=3, op=0.55)
    write("gadget_magnet", d.svg(128, 128, b))
    d = Doc("fr")
    write("gadget_field_ring", d.svg(128, 128, circle(64, 64, 60, "none", extra='stroke="#ffffff" stroke-width="5" stroke-dasharray="14 10"')))


def bumper():
    d = Doc("bmp")
    cap = d.rad([(0, "#ffb3a6"), (0.45, "#ef3b2c"), (1, "#8e1710")], 0.38, 0.3, 0.75)
    b = path("M6 70 C6 20 42 4 64 4 C86 4 122 20 122 70 C100 80 28 80 6 70 Z", cap, 1, OL, 3.4)
    for cx, cy, r in ((40, 30, 9), (72, 20, 7), (96, 42, 10), (60, 50, 6), (24, 56, 5)):
        b += ellipse(cx, cy, r, r * 0.8, "#fff4e4", 0.95, extra=ol(1.4))
    b += path("M24 30 C34 16 48 12 60 11", stroke="#ffffff", sw=4, op=0.6)
    write("gadget_bumper", d.svg(128, 84, b))
    d = Doc("bst")
    stem = d.lin([(0, "#fff3dc"), (0.6, "#e8cfa4"), (1, "#a8865a")], 0, 0, 1, 0)
    write("gadget_bumper_stem", d.svg(40, 100, rect(4, 0, 32, 98, 12, stem, extra=ol(2.6))))


def plate():
    d = Doc("plb")
    b = rect(2, 2, 156, 22, 6, stone(d), extra=ol(2.6))
    b += path("M14 13 L146 13", stroke="#5c5448", sw=3)
    write("gadget_plate_base", d.svg(160, 26, b))
    d = Doc("plt")
    brass = d.lin([(0, "#fff3a0"), (0.5, "#d9a234"), (1, "#8a5a14")], 0, 0, 0, 1)
    b = rect(2, 1, 136, 10, 4, brass, extra=ol(2))
    b += path("M20 6 L120 6", stroke="#fff6c0", sw=2.4)
    write("gadget_plate_top", d.svg(140, 12, b))


def relay():
    d = Doc("rlb")
    wood = d.lin([(0, "#8a5a32"), (0.5, "#5e3a1e"), (1, "#3e2412")], 0, 0, 0, 1)
    b = rect(3, 3, 154, 50, 10, wood, extra=ol(3))
    for x, y in ((12, 12), (148, 12), (12, 44), (148, 44)):
        b += circle(x, y, 4, iron(d), extra=ol(1.2))
    write("gadget_relay_board", d.svg(160, 56, b))
    d = Doc("lmp")
    glass = d.rad([(0, "#ffffff"), (0.4, "#ffe680"), (1, "#c88a10")], 0.4, 0.35, 0.7)
    b = circle(32, 32, 27, glass, extra=ol(3))
    b += circle(32, 32, 27, "none", extra='stroke="#b98a3a" stroke-width="3"')
    b += ellipse(24, 22, 8, 5, "#ffffff", 0.75, -30)
    write("gadget_lamp", d.svg(64, 64, b))


def gravity_field():
    d = Doc("grv")
    fill = d.lin([(0, "#c9a6ff", 0.05), (0.5, "#b48cff", 0.45), (1, "#c9a6ff", 0.05)], 0, 0, 1, 0)
    b = rect(0, 0, 200, 300, 24, fill)
    b += rect(4, 4, 192, 292, 22, "none", extra='stroke="#e6d6ff" stroke-width="4" stroke-dasharray="18 12" opacity="0.8"')
    for x, y in ((40, 60), (150, 110), (90, 200), (60, 250), (160, 240), (110, 40)):
        b += circle(x, y, 4, "#ffffff", 0.8)
    write("gadget_gravity_field", d.svg(200, 300, b))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    portal()
    magnet()
    bumper()
    plate()
    relay()
    gravity_field()
    print("wrote gadget art to", OUT)
