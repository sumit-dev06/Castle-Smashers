#!/usr/bin/env python3
"""Builds the campaign levels (data/levels/level_NNN.json) from a few structure pieces.

Pieces stack exactly (centres computed from the block sizes in data/materials.json), so towers start
at rest. `tests/run_tests.gd` checks every level stands still for 10 s.

Run: python3 tools/gen_levels.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "levels")
MATS = json.load(open(os.path.join(ROOT, "data", "materials.json")))
SIZE = {k: v["size"] for k, v in MATS["shapes"].items()}
SCORE = {k: MATS["materials"][v["material"]]["score"] for k, v in MATS["shapes"].items()}
ARCHER_HALF_H = 29.5
ARCHER_W = 44
BAL = json.load(open(os.path.join(ROOT, "data", "balance.json")))
LEDGE_RIGHT = BAL["stage"]["ledge_right"]
# Stage layout: fortress bases are built under every grounded piece; pieces further apart than
# ISLAND_SPLIT stand on separate islands. The first base starts at least MIN_GAP after the ledge.
BASE_MARGIN = 50
ISLAND_SPLIT = 200
MIN_GAP = 260
CAPTIVE_W = 120


class Fort:
    def __init__(self):
        self.blocks = []
        self.archers = []
        self.mechanisms = []
        self.captives = []
        self.raises = []
        self.extra_spans = []
        self.bolts = []
        self.boss = None
        self.tops = []
        self.markers = []
        self._shift = 0.0

    def mechanism(self, kind, x, y, size=None, trigger="", **settings):
        d = {"type": kind, "x": round(x, 1), "y": round(y, 1)}
        if size is not None:
            d["size"] = size
        if trigger:
            d["trigger"] = trigger
        d.update(settings)
        self.mechanisms.append(d)

    def captive(self, x, y, trigger):
        self.captives.append({"x": round(x, 1), "y": round(y, 1), "trigger": trigger, "height": 92})

    def weak_last(self, trigger=""):
        self.blocks[-1]["weak_point"] = True
        if trigger:
            self.blocks[-1]["trigger"] = trigger

    def b(self, t, x, y, **decor):
        d = {"type": t, "x": round(x, 1), "y": round(y, 1)}
        d.update({k: v for k, v in decor.items() if v})
        self.blocks.append(d)

    def archer(self, x, surface):
        self.archers.append({"x": round(x, 1), "y": round(surface - ARCHER_HALF_H, 1)})

    # ---- floors: each returns the new top surface y. `base` is the surface it stands on.
    def floor(self, kind, x, base, banner=False):
        if kind == "wood":
            for dx in (-80, 80):
                self.b("post", x + dx, base - 60)
            self.b("plank_long", x, base - 133, banner=banner)
            self.tops.append(len(self.blocks) - 1)
            return base - 146
        if kind == "tall":
            for dx in (-80, 80):
                self.b("post_tall", x + dx, base - 100)
            self.b("plank_long", x, base - 213, banner=banner)
            self.tops.append(len(self.blocks) - 1)
            return base - 226
        if kind == "stone":
            for dx in (-70, 70):
                self.b("stone_pillar", x + dx, base - 70)
            self.b("stone_slab", x, base - 160)
            self.tops.append(len(self.blocks) - 1)
            return base - 180
        if kind == "block":
            for dx in (-78, 78):
                self.b("stone_block", x + dx, base - 32)
                self.b("stone_block", x + dx, base - 96)
            self.b("plank_long", x, base - 141, banner=banner)
            self.tops.append(len(self.blocks) - 1)
            return base - 154
        if kind == "crystal":
            for dx in (-70, 70):
                self.b("crystal_pillar", x + dx, base - 70)
            self.b("stone_slab", x, base - 160)
            self.tops.append(len(self.blocks) - 1)
            return base - 180
        if kind == "iron":
            for dx in (-78, 78):
                self.b("iron_block", x + dx, base - 32)
                self.b("iron_block", x + dx, base - 96)
            self.b("iron_beam", x, base - 141, banner=banner)
            self.tops.append(len(self.blocks) - 1)
            return base - 154
        if kind == "narrow":
            for dx in (-42, 42):
                self.b("post", x + dx, base - 60)
            self.b("plank_short", x, base - 133)
            self.tops.append(len(self.blocks) - 1)
            return base - 146
        if kind == "hall":
            for dx in (-152, 0, 152):
                self.b("post", x + dx, base - 60)
            self.b("plank_xl", x, base - 133, banner=banner)
            self.tops.append(len(self.blocks) - 1)
            return base - 146
        raise ValueError(kind)

    def tower(self, x, floors, archers=(), roof=True, flag=True, inside=None, banners=()):
        """archers: floor indices; archer i stands on the surface floor i is built on (0 = ground).
        An index equal to len(floors) puts an archer on the very top (not allowed with a roof)."""
        base = 0.0
        surfaces = []
        for i, kind in enumerate(floors):
            surfaces.append(base)
            base = self.floor(kind, x, base, banner=i in banners)
        surfaces.append(base)
        # Room inside the ground floor: stone-block floors are narrower than post floors.
        room = 46 if floors[0] == "block" else (67 if floors[0] in ("wood", "tall") else 50)
        for i in archers:
            ax = x
            if i == 0 and inside:
                ax = x - room + ARCHER_W / 2 + 1
            self.archer(ax, surfaces[i])
        if inside:
            for item in inside:
                bx = x + room - SIZE[item][0] / 2 - 1 if 0 in archers else x
                self.b(item, bx, -SIZE[item][1] / 2)
        if roof:
            assert len(floors) not in archers, "archer under the roof would be crushed"
            narrow = floors[-1] == "narrow"
            t = "roof" if narrow else "roof_tile"
            self.b(t, x, base - SIZE[t][1] / 2, flag=flag)
        return base

    def stack(self, x, items, archer_on_top=False):
        y = 0.0
        for it in items:
            h = SIZE[it][1]
            self.b(it, x, y - h / 2)
            y -= h
        if archer_on_top:
            self.archer(x, y)
        return y

    def wall(self, x0, count, rows=1):
        for r in range(rows):
            for i in range(count):
                self.b("stone_block", x0 + i * 64, -32 - 64 * r)

    # ---- stage helpers
    def terrace(self, x0, x1, dy):
        """Everything authored between x0 and x1 stands on an island raised by dy px."""
        self.raises.append((x0, x1, dy))

    def deck(self, x, w, build, floating=False, chassis="", chassis_h=0, balloon="", balloon_size=None,
             balloon_y=None, **motion):
        """Moving deck (boss chassis, raft, airship). `build()` places a fortress on y = 0; it is lifted onto
        the deck. Grounded decks ride on a chassis (wheels, cart) reaching the ground and get a base under
        their whole travel; floating decks hang over the gap."""
        b0, a0, m0, k0 = len(self.blocks), len(self.archers), len(self.markers), len(self.mechanisms)
        build()
        h = 50
        wheels = chassis_h - 6 if chassis and not floating else 0
        top = wheels + h
        for item in self.blocks[b0:] + self.archers[a0:] + self.markers[m0:]:
            item["y"] = round(item["y"] - top, 1)
            item["_deck"] = True
        riders = self.mechanisms[k0:]
        for m in riders:
            m["y"] = round(m["y"] - top, 1)
        settings = dict(motion)
        settings.setdefault("travel_y", 0)
        settings.setdefault("phase", 0.0)
        if chassis:
            settings["chassis"] = chassis
            settings["chassis_h"] = chassis_h
        if balloon:
            settings["balloon"] = balloon
            settings["balloon_size"] = balloon_size
            if balloon_y is not None:
                settings["balloon_y"] = balloon_y
        if floating:
            settings["floating"] = True
        self.mechanism("moving_platform", x, -wheels - h / 2, [w, h], **settings)
        for m in riders:
            m["_follow"] = self.mechanisms[-1]
        if not floating:
            reach = w / 2 + abs(motion.get("travel_x", 0))
            self.extra_spans.append((x - reach, x + reach))

    # ---- Phase C pieces
    def rope_load(self, x, hook_y, length, load="boulder", releases="", trigger="", crane_x=None, crane_ground=0.0):
        """Load hanging from a crane arm; cut the rope (shot, fire, blast) to drop it."""
        kw = {"length": length, "load": load}
        if releases:
            kw["releases"] = releases
        if crane_x is not None:
            self.extra_spans.append((crane_x - 20, crane_x + 20))
            kw["frame"] = {"posts": [crane_x], "top": hook_y - 14, "bottom": crane_ground,
                           "beam": [min(x, crane_x) - 12, max(x, crane_x) + 12]}
        self.mechanism("rope_load", x, hook_y, trigger=trigger, **kw)
        return len(self.mechanisms) - 1

    def hanging(self, x, hook_y, span, drop, build, releases="", post_bottom=260):
        """Deck hung from two ropes under a gantry; build() places its load on y = 0."""
        b0, a0 = len(self.blocks), len(self.archers)
        build()
        top = hook_y + drop - 15
        for item in self.blocks[b0:] + self.archers[a0:]:
            item["y"] = round(item["y"] + top, 1)
            item["_deck"] = True
        kw = {"span": span, "drop": drop, "frame": {"posts": [x - span / 2 - 24, x + span / 2 + 24], "top": hook_y - 14,
                                                    "bottom": post_bottom, "beam": [x - span / 2 - 40, x + span / 2 + 40]}}
        if releases:
            kw["releases"] = releases
        self.mechanism("hanging_platform", x, hook_y, [span + 40, 30], **kw)

    def crusher(self, x, y, travel, mode="cycle", trigger="", phase=0.0, size=(150, 120), hold_k=1.0, ground=0.0):
        """Crushing stone in a gantry. y = centre in its raised position; it falls travel px."""
        w, h = size
        self.extra_spans.append((x - w / 2 - 30, x + w / 2 + 30))
        self.mechanism("crusher", x, y, [w, h], trigger=trigger, travel_y=travel, mode=mode, phase=phase, hold_k=hold_k,
                       chain_px=60, frame={"posts": [x - w / 2 - 18, x + w / 2 + 18], "top": y - h / 2 - 70,
                                           "bottom": ground, "beam": [x - w / 2 - 34, x + w / 2 + 34]})

    def geyser(self, x, height, period=4.0, burst=1.4, phase=0.0):
        """Eruption from the gap surface (x must be over the gap)."""
        self.mechanism("geyser", x, 0, None, height=height, period_s=period, burst_s=burst, phase=phase, width=90)

    def bolt(self, a, b):
        self.bolts.append({"a": a, "b": b})

    # ---- Phase D mechanisms
    def lever(self, x, surface, triggers, facing=1):
        """Lever standing on `surface`; any shot, fast block or blast flips it and fires `triggers`."""
        self.mechanism("lever", x, surface, None, triggers=list(triggers), facing=facing)
        if surface == 0:
            self.extra_spans.append((x - 34, x + 34))
        return len(self.mechanisms) - 1

    def windmill(self, x, y, arms=4, arm_len=240, dps=40, hits_blocks=False, triggers=(), mast_ground=None):
        """Turning sails around a hub at (x, y). A hit on the hub jams it (and fires `triggers`)."""
        kw = {"arms": arms, "arm_len": arm_len, "dps": dps}
        if hits_blocks:
            kw["hits_blocks"] = True
        if triggers:
            kw["triggers"] = list(triggers)
        if mast_ground is not None:
            kw["frame"] = {"posts": [x], "top": y, "bottom": mast_ground}
        self.mechanism("windmill", x, y, None, **kw)
        return len(self.mechanisms) - 1

    def shield_ring(self, x, y, radius=150, plates=3, dps=45, plate_len=140, trigger=""):
        """Iron plates orbiting (x, y); they stop shots, not blocks. `trigger` stops the ring."""
        self.mechanism("shield_ring", x, y, None, trigger=trigger, radius=radius, plates=plates, dps=dps, plate_len=plate_len)
        return len(self.mechanisms) - 1

    def rune_switch(self, x, y, triggers):
        """Hidden switch at (x, y): put a block over it. Glows when uncovered; a hit fires `triggers`."""
        self.mechanism("rune_switch", x, y, None, triggers=list(triggers))
        return len(self.mechanisms) - 1

    def trapdoor(self, x, surface, width, trigger, hinge=-1):
        """Floor panel whose top is `surface`, centred on x. Archers/blocks on it drop when it opens."""
        self.mechanism("trapdoor", x, surface + 11, [width, 22], trigger=trigger, hinge=hinge)
        return len(self.mechanisms) - 1

    def balcony(self, plank_index, side, archer=True):
        """Cantilever plank bolted to the end of a floor plank, sticking out of the tower."""
        p = self.blocks[plank_index]
        w = SIZE[p["type"]][0]
        x = p["x"] + side * (w / 2 + 55)
        self.b("plank_short", x, p["y"])
        self.bolt(plank_index, len(self.blocks) - 1)
        if archer:
            self.archer(x, p["y"] - 13)

    def bridge(self, xc, n, surface, archers=()):
        """n long planks laid end to end on two supports at `surface`, bolted into one beam."""
        x0 = xc - n * 110 + 110
        first = len(self.blocks)
        for i in range(n):
            self.b("plank_long", x0 + i * 220, surface - 13)
            if i:
                self.bolt(first + i - 1, first + i)
        for k in archers:
            self.archer(x0 + k * 220, surface - 26)
        return surface - 26

    def pyramid(self, x, rows, kind="stone_block", top_archer=True):
        for r in range(rows):
            n = rows - r
            for i in range(n):
                self.b(kind, x + (i - (n - 1) / 2) * 64, -32 - 64 * r)
        if top_archer:
            self.archer(x, -64 * rows)
        return -64 * rows

    # ---- boss rig (src/game/boss_rig.gd)
    def core(self, x, surface):
        """Power core block standing on `surface`. While any core stands the boss is shielded."""
        self.b("power_core", x, surface - SIZE["power_core"][1] / 2)

    def cannon(self, x, surface):
        """Cannon turret standing on `surface`, firing at the soldiers."""
        self.b("cannon_turret", x, surface - SIZE["cannon_turret"][1] / 2)

    def engineer(self, x, surface):
        """Engineer who rebuilds broken blocks near him until knocked out."""
        self.archers.append({"x": round(x, 1), "y": round(surface - ARCHER_HALF_H, 1), "_engineer": True})

    def boss_unit(self, x, surface, name, hp, phases, reinforce=()):
        self.archers.append({"x": round(x, 1), "y": round(surface - ARCHER_HALF_H, 1), "_boss": True})
        self.boss = {"name": name, "hp": hp, "phases": phases}
        for px, py in reinforce:
            self.markers.append({"x": px, "y": py})

    def right_edge(self):
        xs = [b["x"] + SIZE[b["type"]][0] / 2 for b in self.blocks] + [a["x"] + ARCHER_W / 2 for a in self.archers]
        xs += [m["x"] + m.get("arm_len", m.get("radius", 0)) for m in self.mechanisms if m["type"] in ("windmill", "shield_ring")]
        xs += [m["x"] + m["size"][0] / 2 + abs(m.get("travel_x", 0)) for m in self.mechanisms if "size" in m]
        return max(xs)

    def top_edge(self):
        ys = [b["y"] - SIZE[b["type"]][1] / 2 for b in self.blocks] + [a["y"] - ARCHER_HALF_H for a in self.archers]
        for m in self.mechanisms:
            if "balloon" in m:
                bh = m["balloon_size"][1]
                by = m.get("balloon_y", -m["size"][1] / 2 - bh / 2 - 300)
                ys.append(m["y"] + by - bh / 2 - abs(m.get("travel_y", 0)))
            if m["type"] in ("swing", "rope_load", "hanging_platform"):
                ys.append(m["y"] - 30)
            if m["type"] == "windmill":
                ys.append(m["y"] - m["arm_len"] - 20)
            if m["type"] == "shield_ring":
                ys.append(m["y"] - m["radius"] - 20)
            if m["type"] == "crusher":
                ys.append(m["y"] - m["size"][1] / 2 - 80)
        return min(ys)


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from campaign import LEVELS, T, H, B  # noqa: E402

BOSS_LEVELS = {10, 20, 30, 40, 50}
BOSS_POWER_BUDGET = 9
POWER_BUDGET = 8
CALLOUT_LABELS = {"rope_load": "CUT THE ROPE!", "hanging_platform": "CUT A ROPE!", "crusher": "CRUSHER!",
                  "geyser": "GEYSER!", "drawbridge": "DRAWBRIDGE", "gate": "GATE", "moving_platform": "MOVING!",
                  "swing": "WRECKING BALL", "spikes": "SPIKES", "lever": "HIT THE LEVER!",
                  "windmill": "JAM THE HUB!", "shield_ring": "TIME THE GAP!", "rune_switch": "?",
                  "trapdoor": "TRAP DOOR"}
GEYSER_LABELS = {1: "GEYSER!", 2: "GEYSER!", 3: "WATER SPOUT!", 4: "LAVA PLUME!", 5: "UPDRAFT!"}


PROJ = json.load(open(os.path.join(ROOT, "data", "projectiles.json")))


def check_loadout(lid, heroes, budget):
    counts = {}
    for h in heroes:
        cfg = PROJ[h]
        assert cfg["unlock_level"] <= lid, f"level {lid}: {h} unlocks at {cfg['unlock_level']}"
        counts[h] = counts.get(h, 0) + 1
        assert counts[h] <= cfg["max_per_loadout"], f"level {lid}: too many {h}"
    cost = sum(PROJ[h]["power_cost"] for h in heroes)
    assert len(heroes) == 4 and cost <= budget, f"level {lid}: loadout cost {cost} > {budget}"


def _top(item):
    return item.get("_top", 0.0)


def grounded_spans(f):
    """[x0, x1, top] of everything standing on the ground: blocks, archers, captives, ground mechanisms,
    grounded deck chassis. Items on decks and floating platforms are not grounded."""
    spans = []
    for b in f.blocks:
        w, h = SIZE[b["type"]]
        if not b.get("_deck") and b["y"] + h / 2 > _top(b) - 2:
            spans.append((b["x"] - w / 2, b["x"] + w / 2, _top(b)))
    for a in f.archers:
        if not a.get("_deck") and a["y"] + ARCHER_HALF_H > _top(a) - 2:
            spans.append((a["x"] - ARCHER_W / 2, a["x"] + ARCHER_W / 2, _top(a)))
    for c in f.captives:
        spans.append((c["x"] - CAPTIVE_W / 2, c["x"] + CAPTIVE_W / 2, _top(c)))
    for m in f.mechanisms:
        if m.get("floating") or m.get("chassis") or m["type"] in ("lava", "rope_load", "hanging_platform", "crusher", "geyser",
                                                                   "lever", "windmill", "shield_ring", "rune_switch", "trapdoor") \
                or "size" not in m:
            continue
        if m["y"] + m["size"][1] / 2 > _top(m) - 4:
            reach = m["size"][0] / 2 + abs(m.get("travel_x", 0))
            spans.append((m["x"] - reach, m["x"] + reach, _top(m)))
    for a, b, top in f.extra_spans:
        spans.append((a, b, top))
    return sorted(spans)


def apply_terraces(f):
    """Lift everything inside a terrace and remember its ground top."""
    f.extra_spans = [(a, b, 0.0) for a, b in f.extra_spans]
    for x0, x1, dy in f.raises:
        for collection in (f.blocks, f.archers, f.mechanisms, f.captives, f.markers):
            for item in collection:
                if x0 <= item["x"] <= x1 and not item.get("floating"):
                    item["y"] = round(item["y"] - dy, 1)
                    item["_top"] = -dy
        f.extra_spans = [(a, b, -dy if x0 <= (a + b) / 2 <= x1 else t) for a, b, t in f.extra_spans]


def make_stage(f, lid):
    """Bases under the fortress (shifting it right if it crowds the ledge). Lava pools not on a base are
    dropped because the gap itself is now the hazard."""
    spans = grounded_spans(f)
    floats = [(m["x"] - m["size"][0] / 2 - abs(m.get("travel_x", 0)), m["x"] + m["size"][0] / 2 + abs(m.get("travel_x", 0)))
              for m in f.mechanisms if m.get("floating")]
    floats += [(m["x"] - m["span"] / 2 - 40, m["x"] + m["span"] / 2 + 40) for m in f.mechanisms if m["type"] == "hanging_platform"]
    floats += [(m["x"] - 50, m["x"] + 50) for m in f.mechanisms if m["type"] == "geyser"]
    first_x = min([s[0] for s in spans] + [a for a, _ in floats])
    shift = max(0.0, LEDGE_RIGHT + MIN_GAP - (first_x - BASE_MARGIN))
    f._shift = shift
    for m in f.mechanisms:
        if "approach" in m:
            m["approach"]["dock_x"] = LEDGE_RIGHT + 30
    if shift:
        for collection in (f.blocks, f.archers, f.mechanisms, f.captives, f.markers):
            for item in collection:
                item["x"] = round(item["x"] + shift, 1)
                _shift_frame(item, shift)
        spans = [(a + shift, b + shift, t) for a, b, t in spans]
        floats = [(a + shift, b + shift) for a, b in floats]
    islands = []
    for a, b, top in spans:
        if islands and a - islands[-1][1] < ISLAND_SPLIT:
            assert islands[-1][2] == top, f"level {lid}: one island with two heights near x={a:.0f}"
            islands[-1][1] = max(islands[-1][1], b)
        else:
            islands.append([a, b, top])
    bases = [{"x0": round(a - BASE_MARGIN), "x1": round(b + BASE_MARGIN), "top": top} for a, b, top in islands]
    for fa, fb in floats:
        for bs in bases:
            assert fb < bs["x0"] - 20 or fa > bs["x1"] + 20, f"level {lid}: floating deck overlaps a base"
    on_base = lambda x: any(bs["x0"] <= x <= bs["x1"] for bs in bases)
    f.mechanisms = [m for m in f.mechanisms if not (m["type"] == "lava" and not on_base(m["x"]))]
    return {"ledge_right": LEDGE_RIGHT, "bases": bases}


def _shift_frame(item, dx):
    fr = item.get("frame")
    if fr:
        fr["posts"] = [round(p + dx, 1) for p in fr.get("posts", [])]
        if "beam" in fr:
            fr["beam"] = [round(p + dx, 1) for p in fr["beam"]]


def strip_private(f):
    for collection in (f.blocks, f.archers, f.mechanisms, f.captives):
        for item in collection:
            item.pop("_top", None)
            item.pop("_deck", None)


def resolve_target(t, f):
    """Scene targets like "@crusher" become "mech:<index>" (index in the level's mechanism list)."""
    if t.startswith("@"):
        for i, m in enumerate(f.mechanisms):
            if m["type"] == t[1:]:
                return "mech:%d" % i
        raise ValueError("scene target %s: no such mechanism" % t)
    return t


def make_scene(lid, realm, scene, f, boss):
    beats = []
    for b in scene:
        b = dict(b)
        if "target" in b:
            b["target"] = resolve_target(b["target"], f)
        if b.get("at", "").startswith("@"):
            b["at"] = resolve_target(b["at"], f)
        beats.append(b)
    new_heroes = [k for k, v in PROJ.items() if isinstance(v, dict) and v.get("unlock_level") == lid and lid > 1]
    if (new_heroes or boss) and not beats:
        beats = [T()]
    insert = 1 if beats and beats[0]["t"] == "title" else 0
    if boss and not any(b["t"] == "boss" for b in beats):
        after_baron = next((i + 1 for i, b in enumerate(beats) if b["t"] == "say" and b["who"] == "baron"), insert)
        beats.insert(after_baron, B())
    for k in new_heroes:
        if not any(b["t"] == "hero" for b in beats):
            pos = next((i + 1 for i, b in enumerate(beats) if b["t"] in ("say", "enter") and b["who"] == "wizard"), len(beats))
            beats.insert(pos, H(k))
    return beats


def make_callouts(f, realm, cinematic):
    out = []
    seen = set()
    for i, m in enumerate(f.mechanisms):
        t = m["type"]
        if t in seen or t not in CALLOUT_LABELS:
            continue
        seen.add(t)
        label = GEYSER_LABELS[realm] if t == "geyser" else CALLOUT_LABELS[t]
        if t == "crusher" and m.get("mode") == "trigger":
            label = "DROP THE CRUSHER!"
        out.append({"target": "mech:%d" % i, "label": label})
    if any(b.get("weak_point") for b in f.blocks) and not any(c["label"] == "DRAWBRIDGE" for c in out):
        out.append({"target": "weak", "label": "WEAK POINT"})
    if f.captives:
        out.append({"target": "captive:0", "label": "RESCUE!"})
    if f.bolts:
        out.append({"target": "bolt:0", "label": "BOLTED"})
    return out[:1] if cinematic else out[:3]


def resolve_mode_cfg(mode, cfg, f):
    """Mode settings in final world coordinates (survival wave spots shift with the fortress)."""
    cfg = json.loads(json.dumps(cfg))
    if mode == "survival":
        for w in cfg.get("waves", []):
            w["archers"] = [[round(x - 400 + f._shift, 1), y] for x, y in w["archers"]]
    if mode == "heist":
        cfg.setdefault("need", sum(1 for b in f.blocks if b["type"] == "treasure_chest"))
    return cfg


def build(lid, entry=None):
    """Campaign level `lid`, or a challenge when `entry` is a CHALLENGES row."""
    challenge = entry is not None
    if challenge:
        name, realm, fn, heroes, extras, mode, mode_cfg, strategy = entry
        scene = []
    else:
        name, realm, fn, heroes, extras, scene, strategy = LEVELS[lid]
        mode, mode_cfg = extras.get("mode", ""), extras.get("mode_cfg", {})
    boss_level = lid in BOSS_LEVELS
    budget = BOSS_POWER_BUDGET if boss_level else POWER_BUDGET
    if not challenge and mode != "one_shot":
        check_loadout(lid, heroes, budget)
    f = Fort()
    fn(f)
    apply_terraces(f)
    # Bring the fortress closer and denser in frame, matching the Twin Towers target composition.
    for collection in (f.blocks, f.archers, f.mechanisms, f.captives, f.markers):
        for item in collection:
            item["x"] = round(item["x"] - 400, 1)
            _shift_frame(item, -400)
    f.extra_spans = [(a - 400, b - 400, t) for a, b, t in f.extra_spans]
    stage = make_stage(f, lid)
    if not challenge and lid in [int(v) for v in BAL["secrets"]["scroll_in"].values()]:
        crate = next((b for b in f.blocks if b["type"] == "crate"), None) or next(b for b in f.blocks if b["type"] in ("stone_block", "plank_short", "plank_long"))
        crate["scroll"] = True
    boss_unit = {}
    if f.boss:
        bi = next(i for i, a in enumerate(f.archers) if a.get("_boss"))
        ba = f.archers.pop(bi)
        boss_unit = dict(f.boss, x=ba["x"], y=ba["y"],
                         reinforce=[[m["x"], m["y"]] for m in f.markers])
    assert boss_level == bool(f.boss), f"level {lid}: boss levels must have a boss unit"
    engineers = [{"x": a["x"], "y": a["y"]} for a in f.archers if a.get("_engineer")]
    f.archers = [a for a in f.archers if not a.get("_engineer")]
    for m in f.mechanisms:
        if "_follow" in m:
            m["follow"] = f.mechanisms.index(m.pop("_follow"))
    strip_private(f)
    blocks_score = sum(SCORE[b["type"]] for b in f.blocks)
    base = len(f.archers) * 5000 + (BAL["boss"]["score"] if boss_unit else 0) \
        + len(engineers) * BAL["boss_rig"]["engineer_score"]
    s1 = base
    s2 = base + int(blocks_score * 0.3)
    # 3 stars expect some chain-reaction bonus (balance.json -> chain).
    s3 = base + int(blocks_score * 0.75) + 10000
    beats = make_scene(lid, realm, scene, f, boss_level) if not challenge else []
    d = {
        "id": lid, "name": name, "realm": realm, "heroes": heroes, "soldiers": 4,
        "power_budget": budget, "strategy": strategy, "cinematic": beats,
        "callouts": make_callouts(f, realm, bool(beats)),
        "boss": boss_level,
        "star_scores": [round(s1, -3), round(s2, -3), round(s3, -3)],
        "camera_right": int(round(max(f.right_edge() + 180, stage["bases"][-1]["x1"] + 60), -1)),
        "camera_top": int(round(min(0.0, f.top_edge() - 20), -1)),
        "bg_variant": (lid - 1) % 2, "stage": stage,
        "blocks": f.blocks, "archers": f.archers, "bolts": f.bolts,
        "mechanisms": f.mechanisms, "captives": f.captives,
    }
    if boss_unit:
        d["boss_unit"] = boss_unit
    if engineers:
        d["engineers"] = engineers
    if mode:
        d["mode"] = mode
        d["mode_cfg"] = resolve_mode_cfg(mode, mode_cfg, f)
        if mode == "heist":
            d["star_scores"] = [round(s1, -3), round(s1 + 3000, -3), round(s1 + 8000, -3)]
        if mode == "time_attack":
            d["star_scores"] = [0, 0, 0]
    if challenge:
        d["challenge"] = True
    for key in ("wind", "tide"):
        if key in extras:
            d[key] = extras[key]
    return d


def write_challenges():
    from campaign import CHALLENGES  # noqa: E402
    out = os.path.join(ROOT, "data", "challenges")
    os.makedirs(out, exist_ok=True)
    index = []
    for cid in sorted(CHALLENGES):
        e = CHALLENGES[cid]
        d = build(cid, e)
        with open(os.path.join(out, "challenge_%03d.json" % cid), "w") as fh:
            json.dump(d, fh, indent=1)
        index.append({"id": cid, "name": e[0], "realm": e[1], "mode": e[5], "rule": e[7], "heroes": e[3]})
        print(f"challenge {cid} {e[0]:20s} {e[5]:14s} b{len(d['blocks']):2d} a{len(d['archers'])}")
    from campaign import SECRETS  # noqa: E402
    for sid in sorted(SECRETS):
        e = SECRETS[sid]
        d = build(sid, e)
        d["secret"] = True
        with open(os.path.join(out, "challenge_%03d.json" % sid), "w") as fh:
            json.dump(d, fh, indent=1)
        print(f"secret    {sid} {e[0]:20s} {e[5] or 'siege':14s} b{len(d['blocks']):2d} a{len(d['archers'])}")
    with open(os.path.join(out, "index.json"), "w") as fh:
        json.dump({"challenges": index}, fh, indent=1)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    assert sorted(LEVELS) == list(range(1, len(LEVELS) + 1)), "level ids must be 1..N"
    assert len(LEVELS) == BAL["level_count"], "balance.json level_count must match LEVELS"
    for lid in sorted(LEVELS):
        d = build(lid)
        with open(os.path.join(OUT, "level_%03d.json" % d["id"]), "w") as fh:
            json.dump(d, fh, indent=1)
        tops = ",".join(str(b["top"]) for b in d["stage"]["bases"])
        kinds = ",".join(sorted({m["type"] for m in d["mechanisms"]}))
        print(f"level {d['id']:2d} {d['name']:20s} r{d['realm']} b{len(d['blocks']):2d} a{len(d['archers'])} "
              f"bolts {len(d['bolts'])} bases [{tops}] beats {len(d['cinematic']):2d} {kinds}")
    write_challenges()
