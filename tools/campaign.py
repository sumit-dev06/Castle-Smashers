"""Campaign content for tools/gen_levels.py: 50 level builders, their animated story scenes, heroes,
weather and strategy tips. Each level adds one new idea, then remixes older ones.

Scene beats (played by src/game/cinematic.gd): T() title card, E() actor enters, S() speech bubble,
M() emote, F() camera focus + callout, D() ghost-shot demo, H() new hero reveal, B() boss reveal.
Targets: "fortress", "catapult", "top", "boss", "weak", "gap", "captive:0", "bolt:0", "@<mechanism type>".
"""


def T():
    return {"t": "title"}


def E(who, at="catapult", style="walk"):
    return {"t": "enter", "who": who, "at": at, "style": style}


def S(who, text):
    return {"t": "say", "who": who, "text": text}


def M(who, e):
    return {"t": "emote", "who": who, "e": e}


def F(target, label=""):
    return {"t": "focus", "target": target, "label": label}


def D(target, hero="stone"):
    return {"t": "demo", "target": target, "hero": hero}


def H(kind):
    return {"t": "hero", "kind": kind}


def B():
    return {"t": "boss"}


def MARCH():
    return {"t": "march"}


HULL = {"chassis": "boss_galleon_hull", "chassis_h": 175}
CART = {"chassis": "boss_mine_cart", "chassis_h": 80}
SHIP = {"chassis": "boss_airship_deck", "chassis_h": 100}


# =============================================================================== Realm 1: Blossom Valley
def L1(f):
    f.tower(1450, ["wood", "wood"], archers=[0, 1])
    f.stack(1260, ["crate", "crate"])


def L2(f):  # NEW: rope loads
    f.stack(1250, ["crate", "crate"], archer_on_top=True)
    top = f.tower(1500, ["wood", "wood"], archers=[0, 1])
    f.rope_load(1500, top - 100 - 40 - 90 - 100, 100, crane_x=1700)


def L3(f):  # NEW: Blaze, fire spreads through timber
    f.tower(1400, ["wood", "wood"], archers=[0, 1])
    f.tower(1640, ["narrow", "narrow", "narrow"], archers=[1, 2])
    f.tower(1860, ["wood"], archers=[0])


def L4(f):  # NEW: weak point drops a drawbridge on the guards
    f.tower(1400, ["block", "wood", "wood"], archers=[1, 2], inside=["barrel"])
    f.floor("hall", 1700, 0, banner=True)
    f.archer(1700, -146)
    f.b("crate", 1200, -32)
    f.weak_last("twin_bridge")
    f.mechanism("drawbridge", 1510, -168, [360, 36], "twin_bridge",
                start_angle=-68, end_angle=0, duration_s=0.85, counterweight_travel=92)
    f.tower(2000, ["block", "wood", "wood"], archers=[2], inside=["barrel"])


def L5(f):  # NEW: bolted balconies (joints)
    f.tower(1450, ["block", "wood", "wood"], archers=[1, 2], inside=["barrel"])
    f.balcony(f.tops[-3], -1)
    f.balcony(f.tops[-3], 1)
    f.tower(1900, ["wood", "wood"], archers=[1])
    f.balcony(f.tops[-2], -1)


def L6(f):  # NEW: Boomer, powder barrels
    f.tower(1500, ["block", "block", "wood"], archers=[1, 2], inside=["barrel"])
    f.stack(1300, ["barrel", "crate", "barrel"])
    f.stack(1700, ["barrel", "barrel"])
    f.tower(1900, ["wood", "wood"], archers=[0, 1], inside=["barrel"])


def L7(f):  # REMIX: terrace + rope load over the high tower
    f.tower(1350, ["block", "wood"], archers=[1, 0], inside=["barrel"])
    f.terrace(1600, 2100, 90)
    top = f.tower(1800, ["wood", "wood"], archers=[1, 0])
    f.rope_load(1800, top - 90 - 100 - 40 - 90 - 80, 80, crane_x=1990, crane_ground=-90)


def L8(f):  # NEW: rescue
    f.stack(1250, ["barrel", "barrel"])
    f.tower(1450, ["wood", "wood"], archers=[1], inside=["barrel"])
    f.stack(1640, ["crate", "barrel"])
    f.tower(1830, ["block", "wood"], archers=[1, 0], inside=["barrel"])
    f.stack(2020, ["barrel", "barrel", "barrel"])
    f.weak_last("free_scout")
    f.captive(2180, 0, "free_scout")


def L9(f):  # NEW: hanging platform (gondola) over the river
    def gondola():
        f.archer(1110, 0)
        f.archer(1250, 0)
        f.b("crate", 1180, -32)
    f.hanging(1180, -420, 200, 120, gondola)
    f.tower(1650, ["wood", "wood", "wood"], archers=[1, 2])
    f.stack(1840, ["crate", "barrel"])


def L10(f):  # BOSS: the Siege Warlord on his rolling tower (core = war drum, 1 cannon, 1 engineer)
    f.tower(1250, ["stone", "wood"], archers=[1])

    def tower():
        top = f.tower(1750, ["block", "stone", "wood"], archers=[1], inside=["power_core"], roof=False)
        f.cannon(1575, 0)
        f.engineer(1905, 0)
        f.boss_unit(1750, top, "Siege Warlord", 120,
                    [{"at": 0.6, "do": ["reinforce"]}, {"at": 0.3, "do": ["enrage", "charge"]}],
                    reinforce=[(1680, top), (1820, top)])
    f.deck(1750, 430, tower, chassis="boss_siege_wheels", chassis_h=110, travel_x=40, period_s=8.0)


# =============================================================================== Realm 2: Desert Ruins
def L11(f):  # NEW: stone ruins and pyramids
    f.pyramid(1350, 3)
    f.tower(1650, ["stone", "stone"], archers=[1, 2], roof=False)
    f.tower(1900, ["stone"], archers=[0, 1], roof=False)


def L12(f):  # NEW: Twister
    f.tower(1450, ["narrow", "narrow", "narrow"], archers=[2, 1])
    f.tower(1800, ["narrow", "narrow", "narrow"], archers=[2, 0])
    f.mechanism("moving_platform", 1625, -590, [240, 36], travel_x=90, travel_y=0, period_s=4.4, phase=0.0)


def L13(f):  # NEW: crushing gate (timed)
    f.stack(1280, ["stone_block", "stone_block"], archer_on_top=True)
    f.crusher(1450, -420, 360)
    f.tower(1700, ["stone", "stone", "wood"], archers=[0, 1, 2], banners=(2,))


def L14(f):  # REMIX: pyramid, spikes behind, a windmill turning in front of the keep
    f.pyramid(1450, 4)
    f.windmill(1625, -440, arms=3, arm_len=110, dps=40, mast_ground=0)
    f.tower(1800, ["stone", "wood"], archers=[1, 0])
    f.mechanism("spikes", 2010, -22, [180, 44])


def L15(f):  # REMIX: terraces + boulder on the highest ruin
    f.tower(1250, ["stone"], archers=[0, 1], roof=False)
    f.terrace(1500, 1850, 70)
    f.tower(1680, ["stone", "wood"], archers=[1])
    f.terrace(1950, 2300, 140)
    top = f.tower(2100, ["wood", "wood"], archers=[0, 1])
    f.rope_load(2100, top - 140 - 100 - 40 - 90 - 80, 80, crane_x=2260, crane_ground=-140)


def L16(f):  # NEW: weak point drops a crusher through a tower
    f.stack(1260, ["barrel", "barrel"])
    f.weak_last("drop_crusher")
    f.tower(1450, ["block", "wood"], archers=[1, 0], inside=["barrel"])
    top = f.tower(1720, ["block", "block", "wood"], archers=[2, 1], inside=["barrel"])
    f.crusher(1720, top - 100 - 120, -(top - 100 - 120) - 50, mode="trigger", trigger="drop_crusher", size=(240, 100))
    f.tower(1990, ["block", "wood"], archers=[1], inside=["barrel"])


def L17(f):  # REMIX: obelisk with bolted balconies
    f.tower(1650, ["stone", "stone", "stone", "wood"], archers=[1, 2, 3])
    f.balcony(f.tops[-4], -1)
    f.balcony(f.tops[-4], 1)
    f.wall(1380, 2, 2)


def L18(f):  # REMIX: rescue by drawbridge (a lever out front also lowers it)
    f.lever(1205, 0, ["well_span"])
    f.tower(1350, ["stone", "wood"], archers=[1])
    f.floor("hall", 1650, 0)
    f.weak_last("well_span")
    f.archer(1650, -146)
    f.mechanism("drawbridge", 1760, -165, [280, 36], "well_span",
                start_angle=-78, end_angle=0, duration_s=0.9, counterweight_travel=100)
    f.tower(1950, ["stone", "wood"], archers=[1, 0])
    f.captive(2180, 0, "well_span")


def L19(f):  # NEW: bolted bridge across two mesas
    f.tower(1300, ["narrow", "narrow"], archers=[1, 0])
    f.tower(1640, ["narrow", "narrow", "narrow"], archers=[2], roof=False)
    f.tower(1980, ["narrow", "narrow", "narrow"], archers=[1], roof=False)
    f.bridge(1810, 2, -438, archers=(0, 1))


def L20(f):  # BOSS: the Sandstone Sultan on a sliding keep behind a gate
    f.wall(1220, 2, 2)
    f.weak_last("citadel_gate")
    f.mechanism("gate", 1400, -60, [70, 118], "citadel_gate", travel_y=122, duration_s=0.46)
    f.tower(1520, ["block", "stone", "wood"], archers=[1, 2], inside=["barrel"])
    f.floor("hall", 1820, 0, banner=True)
    f.archer(1820, -146)

    def keep():  # gem core on the roof inside an orbiting stone armor ring
        top = f.tower(2120, ["block", "stone", "wood", "wood"], archers=[1, 2], inside=["barrel"], roof=False)
        f.core(2060, top)
        f.shield_ring(2060, top - 36, radius=100, plates=3, dps=55, plate_len=105)
        f.boss_unit(2180, top, "Sandstone Sultan", 140,
                    [{"at": 0.66, "do": ["shield"]}, {"at": 0.33, "do": ["reinforce", "enrage"]}])
    f.deck(2120, 430, keep, travel_x=28, period_s=7.5)
    f.markers.extend([{"x": 1740, "y": -146}, {"x": 1900, "y": -146}])


# =============================================================================== Realm 3: Pirate Harbor
def L21(f):  # NEW: the tide rises and falls
    f.tower(1350, ["wood", "wood"], archers=[1, 0])
    f.stack(1550, ["barrel", "barrel"])
    f.floor("hall", 1780, 0, banner=True)
    f.archer(1780, -146)
    f.archer(1704, 0)


def L22(f):  # NEW: Rumbler
    f.tower(1400, ["stone", "wood"], archers=[1])
    f.stack(1580, ["stone_block", "stone_block"])
    f.weak_last()
    f.tower(1760, ["stone", "stone", "wood"], archers=[1, 2])
    f.mechanism("spikes", 2050, -22, [180, 44])


def L23(f):  # REMIX: raft riding the tide
    f.tower(1300, ["stone", "wood"], archers=[1])
    f.deck(1750, 330, lambda: f.tower(1750, ["wood", "wood"], archers=[1, 0]), floating=True,
           travel_x=0, travel_y=12, period_s=6.0, **HULL)


def L24(f):  # REMIX: lighthouse with crow's-nest balconies
    f.tower(1700, ["block", "stone", "wood", "wood"], archers=[1, 2, 3])
    f.balcony(f.tops[-3], -1)
    f.balcony(f.tops[-3], 1)
    f.tower(1400, ["wood"], archers=[0])
    # Behind the lighthouse: guards on a trap door; the rune switch under the front stone opens it.
    for x in (1910, 2090):
        f.b("post", x, -60)
    f.trapdoor(2000, -142, 200, "light_trap")
    f.archer(1960, -142)
    f.archer(2040, -142)
    f.b("stone_block", 1250, -32)
    f.rune_switch(1250, -32, ["light_trap"])


def L25(f):  # NEW: water spout lifts shots to the high perch
    f.tower(1250, ["wood"], archers=[0])
    f.terrace(1600, 2000, 200)
    f.tower(1800, ["wood", "wood"], archers=[1, 0])
    f.geyser(1525, 560, period=4.0, burst=1.6)


def L26(f):  # REMIX: two ships on the swell
    f.deck(1350, 330, lambda: f.tower(1350, ["wood", "wood"], archers=[1, 0]), floating=True,
           travel_x=0, travel_y=10, period_s=5.5, **HULL)
    f.deck(1780, 330, lambda: f.tower(1780, ["block", "wood"], archers=[1, 0], inside=["barrel"]), floating=True,
           travel_x=0, travel_y=12, period_s=6.5, phase=2.0, **HULL)
    f.tower(2150, ["narrow"], archers=[0])


def L27(f):  # REMIX: harbor gate + boulder over the hall
    f.tower(1350, ["stone", "stone"], archers=[1], roof=False)
    f.floor("hall", 1650, 0, banner=True)
    f.archer(1650, -146)
    f.archer(1574, 0)
    f.b("stone_block", 1200, -32)
    f.weak_last("harbor_gate")
    f.mechanism("gate", 1100, -60, [70, 118], "harbor_gate", travel_y=122, duration_s=0.46)
    f.tower(1950, ["stone", "stone"], archers=[2], roof=False)
    f.rope_load(1650, -420, 80, crane_x=2150)


def L28(f):  # REMIX: captive in the brig
    f.stack(1250, ["barrel", "barrel"])
    f.tower(1450, ["stone", "wood"], archers=[1], inside=["barrel"])
    f.stack(1640, ["stone_block", "barrel"])
    f.tower(1830, ["block", "wood"], archers=[1, 0], inside=["barrel"])
    f.stack(2020, ["crate", "crate", "barrel"])
    f.weak_last("free_lookout")
    f.captive(2180, 0, "free_lookout")


def L29(f):  # NEW: storm wind
    f.tower(1400, ["stone", "wood"], archers=[1])
    f.tower(1760, ["stone", "stone", "wood"], archers=[1, 2])
    f.mechanism("swing", 1100, -540, trigger="", length=250, diameter=80, arc_deg=28, period_s=3.6)
    f.mechanism("spikes", 2050, -22, [180, 44])


def L30(f):  # BOSS: Captain Ironhook on the galleon
    f.tower(1250, ["stone", "wood"], archers=[1])

    def galleon():
        top1 = f.tower(1720, ["block", "wood", "wood"], archers=[1, 2], inside=["power_core"], roof=False)
        top2 = f.tower(1980, ["wood", "wood"], archers=[1], roof=False)
        f.cannon(1680, top1)
        f.engineer(1790, top1)
        f.engineer(1860, 0)
        f.cannon(1925, top2)
        f.boss_unit(2030, top2, "Captain Ironhook", 150,
                    [{"at": 0.7, "do": ["reinforce"]}, {"at": 0.4, "do": ["shield", "charge"]}, {"at": 0.15, "do": ["enrage"]}],
                    reinforce=[(1670, top1), (1770, top1)])
    f.deck(1850, 520, galleon, floating=True, travel_x=20, travel_y=10, period_s=7.0, chassis="boss_galleon_hull", chassis_h=190)


# =============================================================================== Realm 4: Crystal Mines
def L31(f):  # NEW: crystal shatters into its neighbours
    f.tower(1400, ["crystal", "wood"], archers=[1, 0])
    f.stack(1580, ["crystal_block", "rune_crystal"])
    f.tower(1750, ["crystal", "crystal"], archers=[1, 2], roof=False)


def L32(f):  # REMIX: ore buckets on cranes over two keeps
    t1 = f.tower(1450, ["block", "stone", "wood"], archers=[1, 2])
    f.rope_load(1450, t1 - 100 - 40 - 90 - 80, 80, crane_x=1675)
    t2 = f.tower(1900, ["block", "stone", "wood"], archers=[1, 2])
    f.rope_load(1900, t2 - 100 - 40 - 90 - 80, 80, crane_x=1675)


def L33(f):  # REMIX: mine cart on rails
    f.tower(1250, ["stone", "wood"], archers=[1])
    f.deck(1750, 430, lambda: f.tower(1750, ["crystal", "wood"], archers=[1, 0]), travel_x=90, period_s=8.0, **CART)


def L34(f):  # NEW: lava plume between the islands
    f.tower(1300, ["stone", "wood"], archers=[1])
    f.tower(1750, ["crystal", "wood"], archers=[1, 0])
    f.geyser(1525, 520, period=4.5, burst=1.5)
    f.mechanism("spikes", 1960, -22, [180, 44])


def L35(f):  # REMIX: gondola over the lava, lookout ledge, keep
    def gondola():
        f.archer(950, 0)
        f.archer(1090, 0)
    f.hanging(1020, -360, 200, 110, gondola)
    f.terrace(1150, 1450, 120)
    f.tower(1300, ["narrow", "narrow"], archers=[1, 2], roof=False)
    f.tower(1700, ["block", "block", "wood"], archers=[1, 2])


def L36(f):  # REMIX: powder magazine packed with crystal
    f.stack(1250, ["barrel", "barrel"])
    f.tower(1450, ["block", "block", "wood"], archers=[1, 2], inside=["barrel"])
    f.stack(1650, ["barrel", "crystal_block", "barrel"])
    f.tower(1850, ["crystal", "wood"], archers=[0, 1])
    f.stack(2030, ["barrel", "rune_crystal", "barrel"])


def L37(f):  # REMIX: two carts passing each other
    f.deck(1400, 330, lambda: f.tower(1400, ["wood", "wood"], archers=[1, 0]), travel_x=60, period_s=7.0, **CART)
    f.deck(1900, 330, lambda: f.tower(1900, ["narrow", "narrow", "narrow"], archers=[2, 1]),
           travel_x=60, period_s=7.0, phase=3.14159, **CART)


def L38(f):  # NEW: iron (only bombs and quakes really hurt it) + rescue
    f.tower(1450, ["iron", "wood"], archers=[1, 0])
    f.stack(1650, ["stone_block", "stone_block"])
    f.weak_last("free_miner")
    f.captive(1800, 0, "free_miner")
    f.tower(1980, ["iron", "wood"], archers=[1])


def L39(f):  # REMIX: drill pendulum, crystal hall, spikes
    f.floor("hall", 1500, 0)
    top = f.floor("hall", 1500, -146, banner=True)
    f.archer(1450, 0)
    f.archer(1550, -146)
    f.b("roof_tile", 1500, top - 50, flag=True)
    f.tower(1860, ["crystal", "wood"], archers=[1])
    f.mechanism("swing", 1160, -540, trigger="", length=250, diameter=80, arc_deg=30, period_s=3.0)
    f.mechanism("spikes", 2060, -22, [180, 44])


def L40(f):  # BOSS: the Forgemaster's foundry on rails
    f.wall(1150, 2, 2)
    f.archer(1182, -128)

    def foundry():
        top1 = f.tower(1680, ["iron", "stone", "wood"], archers=[1, 2], inside=["barrel"], roof=False)
        top2 = f.tower(1930, ["iron", "wood"], archers=[1], roof=False)
        f.core(1680, top1)
        f.shield_ring(1680, top1 - 36, radius=100, plates=2, dps=70, plate_len=120)
        f.engineer(1870, top2)
        f.boss_unit(1990, top2, "The Forgemaster", 170,
                    [{"at": 0.66, "do": ["charge", "reinforce"]}, {"at": 0.33, "do": ["shield", "enrage"]}],
                    reinforce=[(1630, top1), (1730, top1)])
    f.deck(1800, 520, foundry, travel_x=110, period_s=9.0, chassis="boss_mine_cart", chassis_h=90)


# =============================================================================== Realm 5: Sky Islands
def L41(f):  # NEW: steady sky wind
    f.tower(1400, ["wood", "wood"], archers=[1, 0])
    f.terrace(1700, 2000, 60)
    f.tower(1820, ["narrow", "narrow"], archers=[1])
    f.stack(1960, ["ice_block", "ice_block"], archer_on_top=True)


def L42(f):  # NEW: updraft between the islands
    f.tower(1300, ["narrow", "narrow"], archers=[1, 0])
    f.terrace(1550, 1800, 80)
    f.tower(1680, ["narrow", "narrow", "narrow"], archers=[2, 1])
    f.terrace(1880, 2150, 160)
    f.tower(2000, ["narrow", "narrow"], archers=[1])
    f.geyser(1490, 600, period=3.5, burst=1.5)


def L43(f):  # REMIX: small airship in the gusts
    f.deck(1500, 330, lambda: f.tower(1500, ["wood", "wood"], archers=[1, 0]), floating=True,
           travel_x=30, travel_y=16, period_s=6.0, chassis="boss_airship_deck", chassis_h=100,
           balloon="boss_airship_balloon", balloon_size=[380, 160], balloon_y=-530)
    f.tower(1950, ["stone", "wood"], archers=[1])


def L44(f):  # REMIX: updraft to the high perch
    f.tower(1300, ["wood"], archers=[0])
    f.terrace(1600, 2050, 150)
    f.tower(1800, ["block", "wood", "wood"], archers=[1, 2])
    f.geyser(1540, 640, period=4.0, burst=1.6)


def L45(f):  # REMIX: windmill hall with a swinging counterweight
    f.terrace(1250, 2100, 60)
    f.floor("hall", 1500, 0)
    top = f.floor("hall", 1500, -146, banner=True)
    f.archer(1450, 0)
    f.archer(1550, -146)
    f.b("roof_tile", 1500, top - 50, flag=True)
    f.tower(1860, ["wood", "wood"], archers=[1])
    f.mechanism("swing", 2160, -600, trigger="", length=250, diameter=76, arc_deg=30, period_s=3.4)


def L46(f):  # REMIX: cloud bridge + gondola
    f.terrace(1150, 2300, 80)
    f.tower(1400, ["block", "wood", "wood"], archers=[1, 2], inside=["barrel"])
    f.floor("hall", 1700, 0, banner=True)
    f.archer(1700, -146)
    f.b("crate", 1200, -32)
    f.weak_last("cloud_bridge")
    f.mechanism("drawbridge", 1510, -168, [360, 36], "cloud_bridge",
                start_angle=-68, end_angle=0, duration_s=0.85, counterweight_travel=92)
    f.tower(2000, ["block", "wood", "wood"], archers=[2], inside=["barrel"])


def L47(f):  # REMIX: cut the rope to lower the captive's cage
    f.terrace(1150, 2300, 70)
    f.stack(1250, ["barrel", "barrel"])
    f.tower(1450, ["wood", "wood"], archers=[1], inside=["barrel"])
    f.stack(1640, ["ice_block", "barrel"])
    f.tower(1830, ["block", "wood"], archers=[1, 0], inside=["barrel"])
    f.captive(2180, 0, "free_pilot")
    f.rope_load(2040, -480, 120, load="crate", releases="free_pilot", crane_x=2040 + 0.01, crane_ground=-70)


def L48(f):  # REMIX: twin airships drifting out of step
    for i, x in enumerate((1350, 1760)):
        f.deck(x, 330, lambda x=x, i=i: f.tower(x, ["wood", "wood"] if i == 0 else ["block", "wood"], archers=[1, 0]),
               floating=True, travel_x=24, travel_y=14, period_s=6.0 + i, phase=1.5 * i, **SHIP,
               balloon="boss_airship_balloon", balloon_size=[360, 150], balloon_y=-520)
    f.terrace(2000, 2300, 100)
    f.tower(2120, ["narrow", "narrow"], archers=[1])


def L49(f):  # REMIX: everything the Baron has left
    f.tower(1350, ["block", "stone", "wood"], archers=[1, 2])
    f.balcony(f.tops[-3], 1)
    f.tower(1700, ["crystal", "stone", "wood"], archers=[1, 2])
    f.terrace(1950, 2350, 100)
    f.tower(2150, ["wood", "wood"], archers=[1, 0])


def L50(f):  # BOSS: the Iron Baron's airship (2 cores, armor, 2 cannons, 2 engineers)
    top0 = f.tower(1250, ["stone", "wood"], archers=[1], roof=False)
    f.cannon(1250, top0)
    f.engineer(1390, 0)

    def airship():
        top1 = f.tower(1720, ["block", "stone", "wood"], archers=[1, 2], inside=["barrel"], roof=False)
        top2 = f.tower(1980, ["wood", "wood"], archers=[1], roof=False)
        f.core(1665, top1)
        f.cannon(1770, top1)
        f.core(1925, top2)
        f.shield_ring(1925, top2 - 36, radius=100, plates=3, dps=50, plate_len=105)
        f.engineer(1860, 0)
        f.boss_unit(2035, top2, "The Iron Baron", 200,
                    [{"at": 0.75, "do": ["reinforce"]}, {"at": 0.5, "do": ["shield", "charge"]},
                     {"at": 0.25, "do": ["enrage", "reinforce"]}],
                    reinforce=[(1670, top1), (1770, top1)])
    f.deck(1850, 520, airship, floating=True, travel_x=30, travel_y=18, period_s=7.0,
           chassis="boss_airship_deck", chassis_h=150,
           balloon="boss_airship_balloon", balloon_size=[620, 250], balloon_y=-760)


# =============================================================================== the table
STORM = {"strength": 260, "period_s": 7.0, "gust_s": 3.0, "dir": -1}
BREEZE = {"strength": 200, "period_s": 6.0, "gust_s": 3.0, "dir": 1}
GUSTY = {"strength": 240, "period_s": 6.5, "gust_s": 3.0, "dir": 1, "alternate": True}
TIDE = {"amp_px": 45, "period_s": 8.0}

# id: (name, realm, builder, heroes, extras, scene, strategy)
LEVELS = {
    1: ("Wooden Watchtower", 1, L1, ["stone"] * 4, {}, [
        T(), E("captain"), S("captain", "That watchtower blocks the valley road!"), M("captain", "point"),
        D("top", "stone"), S("captain", "Pull back, aim high, let go!"), MARCH()],
        "Learn the arc. One clean hit on the timber frame brings it down."),
    2: ("The Hanging Rock", 1, L2, ["stone"] * 4, {}, [
        T(), E("captain"), F("@rope_load", "CUT THE ROPE!"), S("captain", "A boulder on a rope, right over their heads!"),
        D("@rope_load", "stone"), M("captain", "cheer")],
        "Shoot through the rope: the boulder does the rest."),
    3: ("Lantern Pagodas", 1, L3, ["fire", "stone", "fire", "stone"], {}, [
        T(), E("wizard", "catapult", "smoke"), S("wizard", "Master Orin, at your service!"),
        F("fortress", "TIMBER BURNS!"), D("fortress", "fire")],
        "Fire spreads between touching timber. Light the front pagoda."),
    4: ("Petal Bridge", 1, L4, ["fire", "stone", "stone", "stone"], {}, [
        T(), E("captain"), F("weak", "WEAK POINT!"), S("captain", "Crack that glowing crate..."),
        F("@drawbridge", "BRIDGE DROPS!"), D("weak", "stone")],
        "Break the glowing crate: the bridge slams onto the guards."),
    5: ("Bolted Balconies", 1, L5, ["fire", "stone", "fire", "stone"], {}, [
        T(), E("enemy", "fortress", "drop"), S("enemy", "Our balconies are bolted on!"), M("enemy", "laugh"),
        F("bolt:0", "BOLTS!"), E("captain"), S("captain", "Hit them hard and the bolts pop.")],
        "Bolts break when a piece takes a beating or a blast."),
    6: ("Moonlit Storehouse", 1, L6, ["bomb", "fire", "stone", "stone"], {}, [
        T(), E("enemy", "fortress", "smoke"), S("enemy", "Nothing explosive in here. Honest!"), M("enemy", "laugh"),
        E("wizard", "catapult", "smoke"), D("fortress", "bomb")],
        "Chain the powder barrels with Boomer, then mop up with Rocky."),
    7: ("Hillside Terraces", 1, L7, ["bomb", "stone", "fire", "stone"], {}, [],
        "The high tower needs a steeper arc. Or cut its rope."),
    8: ("Captive Shrine", 1, L8, ["fire", "bomb", "stone", "fire"], {}, [
        T(), E("captive", "fortress", "smoke"), S("captive", "Help! Get me out of here!"), M("captive", "scared"),
        F("captive:0", "RESCUE!"), F("weak", "BREAK THIS"), E("captain"), M("captain", "cheer")],
        "Break the marked barrels before the last guard falls."),
    9: ("River Gondola", 1, L9, ["bomb", "fire", "stone", "stone"], {}, [
        T(), F("@hanging_platform", "CUT A ROPE!"), E("captain"), S("captain", "One rope and they tip into the river!"),
        D("@hanging_platform", "stone")],
        "Cut one gondola rope to tip the guards into the river."),
    10: ("The Siege Tower", 1, L10, ["bomb", "fire", "stone", "fire"], {}, [
        T(), E("baron", "boss", "smoke"), S("baron", "My siege tower will roll right over you!"), M("baron", "laugh"),
        F("core", "BREAK THE CORE!"), E("wizard", "catapult", "smoke"),
        S("wizard", "That war drum shields him. Smash it, then him!")],
        "Boss: the war drum in the base shields him. Break it, topple the cannon, stop the engineer."),
    11: ("Sandstone Ruins", 2, L11, ["bomb", "stone", "stone", "fire"], {}, [
        T(), E("captain"), S("captain", "Desert stone. Fire won't help here."), F("fortress", "STONE!"), M("captain", "point")],
        "Stone shrugs off fire. Save Boomer for the double ruin."),
    12: ("Twin Mesas", 2, L12, ["cyclone", "stone", "bomb", "stone"], {}, [
        T(), E("wizard", "catapult", "smoke"), F("@moving_platform", "MOVING!"), D("top", "cyclone")],
        "Release Twister among the thin towers to fling the guards off."),
    13: ("Crusher Gate", 2, L13, ["cyclone", "bomb", "stone", "stone"], {}, [
        T(), F("@crusher", "CRUSHER!"), E("captain"), S("captain", "Shoot between the slams!"), M("captain", "point")],
        "The crusher eats shots. Fire as it rises."),
    14: ("Spike Pyramid", 2, L14, ["cyclone", "bomb", "stone", "stone"], {}, [],
        "Shoot between the windmill sails, then knock the guards onto their spikes."),
    15: ("Ruin Terraces", 2, L15, ["cyclone", "bomb", "stone", "stone"], {}, [],
        "Work up the terraces. The top ruin has a boulder over it."),
    16: ("Powder Caravan", 2, L16, ["fire", "bomb", "cyclone", "stone"], {}, [
        T(), F("@crusher", "DROP THE CRUSHER!"), F("weak", "TRIGGER"), E("captain"), S("captain", "Blow the barrels, drop the stone!")],
        "The front barrels hold the crusher. Pop them and it falls through the keep."),
    17: ("Granite Obelisk", 2, L17, ["bomb", "cyclone", "stone", "stone"], {}, [],
        "Shake the bolted balconies loose, then break the base."),
    18: ("Prisoner Well", 2, L18, ["cyclone", "bomb", "stone", "stone"], {}, [
        T(), E("captive", "fortress", "drop"), S("captive", "The bridge winch opens my cage!"), F("weak", "BREAK THIS"),
        F("captive:0", "RESCUE!")],
        "Flip the lever or break the bridge support to free the captive."),
    19: ("Mesa Bridge", 2, L19, ["cyclone", "fire", "bomb", "stone"], {}, [
        T(), F("bolt:0", "BOLTED BRIDGE"), E("captain"), S("captain", "Break a tower and the bridge goes swimming!")],
        "The bridge only holds while both mesas stand."),
    20: ("Sandstone Citadel", 2, L20, ["bomb", "cyclone", "fire", "fire"], {}, [
        T(), E("baron", "boss", "smoke"), S("baron", "My keep slides. My shield holds!"), M("baron", "shake"),
        F("weak", "OPEN THE GATE"), F("core", "TIME THE ARMOR GAP!")],
        "Boss: the gem on his roof shields him. Shoot through the gap in its rotating armor."),
    21: ("Dockside Shacks", 3, L21, ["fire", "bomb", "stone", "stone"], {"tide": TIDE}, [
        T(), E("captain"), F("gap", "THE TIDE!"), S("captain", "The sea rises and falls. Mind the water!")],
        "Fire spreads along the timber piers. The tide moves the waterline."),
    22: ("Smugglers' Pier", 3, L22, ["quake", "stone", "fire", "stone"], {}, [
        T(), E("wizard", "catapult", "smoke"), S("wizard", "Drive Rumbler down and the ground breaks!"),
        D("weak", "quake")],
        "Earthbreak reaches every low foundation, including the weak stone."),
    23: ("Bobbing Raft", 3, L23, ["quake", "bomb", "stone", "stone"], {"tide": TIDE}, [],
        "The raft rides the tide. Push its tower into the sea."),
    24: ("Harbor Lighthouse", 3, L24, ["quake", "cyclone", "stone", "stone"], {}, [],
        "Twister clears the crow's nests. Knock the front stone off the rune switch, then hit it to drop the back guards."),
    25: ("Water Spout", 3, L25, ["quake", "fire", "stone", "stone"], {}, [
        T(), F("@geyser", "GEYSER!"), E("captain"), S("captain", "Ride the spout up to the high perch!"), D("@geyser", "stone")],
        "Shots through the erupting spout get thrown upward."),
    26: ("Two Ships", 3, L26, ["bomb", "cyclone", "stone", "stone"], {"tide": TIDE}, [],
        "Two ships, two rhythms. Knock the towers overboard."),
    27: ("Harbor Gate", 3, L27, ["quake", "fire", "stone", "fire"], {}, [],
        "Crack the weak stone for the gate, cut the rope for the hall."),
    28: ("Captive Brig", 3, L28, ["fire", "bomb", "cyclone", "stone"], {"tide": TIDE}, [
        T(), E("captive", "fortress", "smoke"), S("captive", "They threw me in the brig!"), F("captive:0", "RESCUE!")],
        "Break the marked stack to open the brig."),
    29: ("Storm Watch", 3, L29, ["quake", "bomb", "stone", "stone"], {"wind": STORM}, [
        T(), E("captain"), S("captain", "Storm wind! It pushes our shots back."), F("@swing", "WRECKING BALL")],
        "Gusts blow toward you. Aim further while the wind sign shows a gust."),
    30: ("The Iron Galleon", 3, L30, ["quake", "bomb", "fire", "stone"], {"tide": {"amp_px": 30, "period_s": 9.0}}, [
        T(), E("baron", "boss", "smoke"), S("baron", "Sink my galleon? Ha!"), M("baron", "laugh"),
        F("cannon", "CANNONS!"), E("wizard", "catapult", "smoke"), S("wizard", "Blow the powder core and stop his engineers!")],
        "Boss: two cannons hit twice. The powder core in the front keep holds his shield."),
    31: ("Crystal Cavern", 4, L31, ["stone", "cyclone", "bomb", "stone"], {}, [
        T(), E("captain"), S("captain", "Crystal! It shatters and cuts its neighbours."), F("fortress", "CRYSTAL SHATTERS!"),
        D("fortress", "stone")],
        "Break one crystal next to others: the shards do the rest. The rune crystal fires a beam."),
    32: ("Ore Buckets", 4, L32, ["quake", "bomb", "stone", "stone"], {}, [],
        "Two boulders hang over two keeps. Two ropes, two collapses."),
    33: ("Rail Cart", 4, L33, ["bomb", "cyclone", "fire", "stone"], {}, [],
        "Lead the cart: aim where it is going."),
    34: ("Lava Plume", 4, L34, ["quake", "fire", "stone", "fire"], {}, [
        T(), F("@geyser", "LAVA PLUME!"), E("captain"), S("captain", "It burns and it lifts. Use it!")],
        "The plume lifts shots and burns anything thrown into it."),
    35: ("Deep Shaft", 4, L35, ["cyclone", "quake", "stone", "stone"], {}, [],
        "Cut the gondola first: two guards straight into the lava."),
    36: ("Powder Magazine", 4, L36, ["fire", "bomb", "stone", "stone"], {}, [],
        "Barrels and crystals together. One spark, chain reaction."),
    37: ("Twin Carts", 4, L37, ["cyclone", "bomb", "fire", "stone"], {}, [],
        "The carts meet in the middle. That is your moment."),
    38: ("Iron Forge", 4, L38, ["bomb", "quake", "stone", "stone"], {}, [
        T(), E("captive", "fortress", "smoke"), S("captive", "They make me forge iron!"), F("fortress", "IRON! USE BOMBS"),
        F("captive:0", "RESCUE!")],
        "Iron laughs at Rocky and Blaze. Boomer and Rumbler bend it."),
    39: ("Pendulum Drill", 4, L39, ["bomb", "cyclone", "fire", "stone"], {}, [],
        "Fire just after the drill swings past."),
    40: ("The Foundry", 4, L40, ["quake", "bomb", "fire", "stone"], {}, [
        T(), E("baron", "boss", "smoke"), S("baron", "My foundry never stops moving!"), M("baron", "shake"),
        F("core", "THE FURNACE!"), E("wizard", "catapult", "smoke"), S("wizard", "Fast armor. Fire when the gap swings by!")],
        "Boss: break the furnace core behind its fast iron armor. The engineer rebuilds, knock him out."),
    41: ("First Island", 5, L41, ["cyclone", "bomb", "stone", "stone"], {"wind": BREEZE}, [
        T(), E("captain"), S("captain", "The sky wind carries our shots further."), F("fortress", "TAILWIND"),
        E("baron", "top", "smoke"), S("baron", "Climb all you like. You'll only fall further!")],
        "Tailwind gusts: aim a little shorter while they blow. Ice is slippery and shatters."),
    42: ("Island Hop", 5, L42, ["cyclone", "fire", "bomb", "stone"], {"wind": GUSTY}, [
        T(), F("@geyser", "UPDRAFT!"), E("captain"), S("captain", "Ride the updraft to the high islands!")],
        "The updraft between the islands throws shots upward."),
    43: ("Sky Raft", 5, L43, ["quake", "cyclone", "stone", "stone"], {"wind": BREEZE}, [],
        "Push the swaying tower off the airship deck."),
    44: ("High Perch", 5, L44, ["quake", "bomb", "stone", "stone"], {}, [],
        "Use the updraft or a very steep arc."),
    45: ("Windmill Isle", 5, L45, ["bomb", "cyclone", "fire", "stone"], {"wind": GUSTY}, [],
        "Gusts change direction. Wait for calm or use them."),
    46: ("Cloud Bridge", 5, L46, ["quake", "fire", "fire", "stone"], {}, [],
        "The glowing crate holds the bridge up."),
    47: ("Sky Captive", 5, L47, ["fire", "bomb", "cyclone", "stone"], {"wind": BREEZE}, [
        T(), E("captive", "fortress", "smoke"), S("captive", "Cut the rope and my cage opens!"), F("@rope_load", "CUT THE ROPE!")],
        "The rope holds the cage lock. Cut it."),
    48: ("Twin Airships", 5, L48, ["quake", "cyclone", "fire", "stone"], {"wind": GUSTY}, [],
        "Two airships drift out of step. Wait until they line up."),
    49: ("Baron's Approach", 5, L49, ["quake", "bomb", "stone", "stone"], {"wind": STORM}, [
        T(), E("baron", "top", "smoke"), S("baron", "You will never reach my airship!"), M("baron", "shake")],
        "Crystal, bolts and a storm. Choose your heroes carefully."),
    50: ("The Baron's Airship", 5, L50, ["quake", "bomb", "fire", "stone"], {"wind": GUSTY}, [
        T(), E("baron", "boss", "smoke"), S("baron", "My airship rules the sky!"), M("baron", "laugh"),
        F("core", "TWO BALLOON CORES"), E("wizard", "catapult", "smoke"), S("wizard", "Both cores, then the Baron!"), E("captain"),
        S("captain", "Vanguard! End this siege!"), MARCH()],
        "Final boss: two cores, armor, two cannons, two engineers. Disable the defences, then finish him."),
}


# =============================================================================== challenges
# Challenge levels (ids above 100, data/challenges/). Row: (name, realm, build, heroes, extras, mode, mode_cfg,
# rule). Heroes are fixed per challenge (no loadout screen). Modes: src/game/mode_rules.gd.
def C101(f):  # heist: three chests in two towers, one hangs over the edge of the island
    f.tower(1300, ["wood", "wood"], archers=[1], inside=["treasure_chest"])
    top = f.tower(1650, ["block", "wood"], archers=[1, 2], roof=False)
    f.b("treasure_chest", 1600, top - 28)
    f.stack(1860, ["crate", "treasure_chest"])


def C102(f):  # heist on the water: chests ride two rafts, knock them in and they are gone
    f.deck(1350, 330, lambda: f.tower(1350, ["wood", "wood"], archers=[1, 0], inside=["treasure_chest"]), floating=True,
           travel_x=0, travel_y=10, period_s=5.5, **HULL)
    f.tower(1800, ["block", "wood"], archers=[1, 0], inside=["treasure_chest"])
    f.stack(1990, ["treasure_chest"])


def C103(f):  # time attack: a sprawling wooden camp
    f.tower(1250, ["wood", "wood"], archers=[1, 0])
    f.tower(1550, ["narrow", "narrow"], archers=[2, 1], roof=False)
    f.tower(1850, ["wood", "wood", "wood"], archers=[1, 2], inside=["barrel"])


def C104(f):  # time attack in the forge: iron and crystal, a lever drops the crusher
    f.tower(1300, ["iron", "wood"], archers=[1, 0])
    f.crusher(1560, -470, 300, mode="trigger", trigger="forge_drop", size=(150, 120))
    f.tower(1560, ["wood"], archers=[0])
    f.lever(1700, 0, ["forge_drop"])
    f.tower(1900, ["crystal", "wood"], archers=[1, 0], inside=["barrel"])


def C105(f):  # one shot: a packed powder keep, one Boomer to bring it down
    f.tower(1450, ["block", "wood"], archers=[1, 0], inside=["barrel"])
    f.stack(1610, ["barrel", "barrel", "crystal_block"])
    f.tower(1780, ["crystal", "wood"], archers=[1], inside=["barrel"])
    f.stack(1940, ["barrel", "crate", "barrel"], archer_on_top=True)


def C106(f):  # survival: a gatehouse that guards keep dropping into
    f.tower(1350, ["block", "wood"], archers=[1])
    f.tower(1700, ["stone", "wood"], archers=[1, 0])
    f.windmill(1950, -330, arms=4, arm_len=170, dps=35, mast_ground=0)


def C107(f):  # reverse siege: two airships sail at you over the clouds
    for i, x in enumerate((1350, 1760)):
        f.deck(x, 330, lambda x=x, i=i: f.tower(x, ["wood", "wood"] if i == 0 else ["block", "wood"], archers=[1, 0]),
               floating=True, travel_x=0, travel_y=14, period_s=6.0 + i, phase=1.5 * i, approach={"speed": 16 + 4 * i},
               **SHIP, balloon="boss_airship_balloon", balloon_size=[360, 150], balloon_y=-520)
    f.terrace(2000, 2300, 100)
    f.tower(2120, ["narrow", "narrow"], archers=[1])


def C108(f):  # reverse siege: a war galleon and a raft cross the harbor
    f.deck(1380, 330, lambda: f.tower(1380, ["wood", "wood"], archers=[1, 0], inside=["barrel"]), floating=True,
           travel_x=0, travel_y=10, period_s=5.5, approach={"speed": 18}, **HULL)
    f.deck(1800, 330, lambda: f.tower(1800, ["block", "wood"], archers=[1, 0]), floating=True,
           travel_x=0, travel_y=12, period_s=6.5, phase=2.0, approach={"speed": 24}, **HULL)
    f.tower(2150, ["stone", "wood"], archers=[1])


CHALLENGES = {
    101: ("Gold Rush", 2, C101, ["bomb", "cyclone", "stone", "stone"], {}, "heist", {"need": 2},
          "Break open at least 2 of the 3 chests. A chest that falls off is lost."),
    102: ("Pirate Hoard", 3, C102, ["quake", "bomb", "stone", "stone"], {"tide": TIDE}, "heist", {"need": 2},
          "Open the chests before the sea takes them."),
    103: ("Beat the Clock", 1, C103, ["stone", "bomb", "fire", "stone"], {}, "time_attack",
          {"time_s": 40, "refill": ["stone", "bomb", "fire"], "star_time": [0, 10, 18]},
          "40 seconds. Heroes keep coming, fire fast."),
    104: ("Forge Sprint", 4, C104, ["bomb", "quake", "stone", "stone"], {}, "time_attack",
          {"time_s": 50, "refill": ["bomb", "quake", "stone"], "star_time": [0, 12, 22]},
          "Hit the lever to drop the crusher, then clear the forge in 50 seconds."),
    105: ("One Perfect Shot", 4, C105, ["bomb"], {}, "one_shot", {},
          "One Boomer. Start the chain reaction in the right barrel."),
    106: ("Hold the Line", 1, C106, ["stone", "bomb", "fire", "stone"], {}, "survival",
          {"waves": [{"archers": [[1350, -400], [1700, -300]], "heroes": ["bomb", "stone"]},
                     {"archers": [[1300, -300], [1700, -300], [1820, -150]], "heroes": ["fire", "bomb", "stone"]}]},
          "Three waves drop in. Keep your soldiers standing."),
    107: ("Sky Raiders", 5, C107, ["quake", "bomb", "cyclone", "stone"], {"wind": BREEZE}, "reverse_siege", {},
          "Two airships sail at you. Defeat each crew before it docks."),
    108: ("Harbor Assault", 3, C108, ["bomb", "fire", "quake", "stone"], {"tide": TIDE}, "reverse_siege", {},
          "Sink the galleon and the raft before they reach your shore."),
}


# =============================================================================== secret levels
# One per realm (ids 111-115), unlocked by the hidden map scroll (balance.json -> secrets). Same row
# format as CHALLENGES. They pay like challenges and are reached from a secret node on the map.
def S111(f):  # blossom grotto: a lantern hall with a rune switch and a trap door under the guards
    f.tower(1300, ["wood", "wood"], archers=[1])
    for x in (1560, 1740):
        f.b("post", x, -60)
    f.trapdoor(1650, -142, 200, "grotto_trap")
    f.archer(1610, -142)
    f.archer(1690, -142)
    f.b("stone_block", 1880, -32)
    f.rune_switch(1880, -32, ["grotto_trap"])
    f.tower(1880, ["stone"], archers=[1], roof=False)


def S112(f):  # desert vault: chests behind a windmill
    f.windmill(1350, -330, arms=3, arm_len=180, dps=50, mast_ground=0)
    f.tower(1650, ["block", "wood"], archers=[1, 0], inside=["treasure_chest"])
    f.stack(1860, ["treasure_chest", "crate"], archer_on_top=True)


def S113(f):  # smugglers' cove: a lever opens the sea gate onto a powder room
    f.tower(1300, ["wood", "wood"], archers=[1, 0], inside=["barrel"])
    f.lever(1480, 0, ["cove_gate"])
    f.mechanism("gate", 1580, -60, [70, 118], "cove_gate", travel_y=122, duration_s=0.46)
    f.tower(1780, ["block", "wood"], archers=[1, 0], inside=["barrel"])


def S114(f):  # rune forge: crystals, runes and bending iron
    f.tower(1300, ["iron", "wood"], archers=[1])
    f.b("rune_crystal", 1520, -32, dir=-30)
    f.tower(1750, ["crystal", "wood"], archers=[1, 0], inside=["barrel"])
    f.stack(1950, ["ice_block", "ice_block"], archer_on_top=True)


def S115(f):  # cloud sanctum: shielded tower under a turning ring
    f.tower(1400, ["narrow", "narrow"], archers=[2, 1], roof=False)
    f.tower(1750, ["stone", "wood"], archers=[1, 0], roof=False)
    f.shield_ring(1750, -400, radius=110, plates=3, dps=45, plate_len=110)


SECRETS = {
    111: ("Lantern Grotto", 1, S111, ["stone", "bomb", "fire", "stone"], {}, "", {},
          "Uncover the rune switch and spring the trap door."),
    112: ("Sultan's Vault", 2, S112, ["bomb", "cyclone", "stone", "stone"], {}, "heist", {"need": 2},
          "Get past the windmill and crack the vault chests."),
    113: ("Smugglers' Cove", 3, S113, ["stone", "bomb", "fire", "stone"], {"tide": TIDE}, "", {},
          "Hit the lever to open the sea gate."),
    114: ("Rune Forge", 4, S114, ["bomb", "quake", "fire", "stone"], {}, "", {},
          "Blast the rune crystal to fire its beam across the forge."),
    115: ("Cloud Sanctum", 5, S115, ["quake", "bomb", "cyclone", "stone"], {"wind": BREEZE}, "", {},
          "Shoot through the gaps in the orbiting shield."),
}
