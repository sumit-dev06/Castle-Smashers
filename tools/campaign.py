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
def L1(f):  # a lookout on a stone base, flanked by crate posts: topple it into them
    f.stack(1260, ["crate", "crate"], archer_on_top=True)
    f.tower(1450, ["stone", "wood"], archers=[0, 1])
    f.stack(1640, ["crate", "crate", "crate"], archer_on_top=True)


def L2(f):  # NEW: rope loads. A stone pillar shields the tower's ground floor: the rock is the way in
    f.stack(1250, ["crate", "crate"], archer_on_top=True)
    f.stack(1350, ["stone_block", "stone_block", "stone_block"])
    top = f.tower(1500, ["wood", "wood"], archers=[0, 1])
    f.rope_load(1500, top - 100 - 40 - 90 - 220, 220, crane_x=1700)  # long drop: it smashes the tower


def L3(f):  # NEW: Blaze, fire spreads through timber. The stone hut at the back needs Rocky
    f.tower(1400, ["wood", "wood"], archers=[1])
    f.tower(1620, ["narrow", "narrow", "narrow"], archers=[2])
    f.tower(1840, ["wood", "wood"], archers=[0, 1])
    f.tower(2070, ["block"], archers=[0])


def L4(f):  # NEW: weak point drops a drawbridge on the guards
    f.tower(1400, ["block", "wood", "wood"], archers=[1, 2], inside=["barrel"])
    f.floor("hall", 1700, 0, banner=True)
    f.archer(1700, -146)
    f.b("crate", 1200, -32)
    f.weak_last("twin_bridge")
    f.mechanism("drawbridge", 1510, -168, [360, 36], "twin_bridge",
                start_angle=-68, end_angle=0, duration_s=0.85, counterweight_travel=92)
    f.tower(2000, ["block", "wood", "wood"], archers=[1, 2], inside=["barrel"])


def L5(f):  # NEW: bolted balconies (joints) on a four-floor keep
    f.tower(1450, ["block", "wood", "wood", "wood"], archers=[1, 3], inside=["barrel"])
    f.balcony(f.tops[-4], -1)
    f.balcony(f.tops[-4], 1)
    f.balcony(f.tops[-2], 1)
    f.tower(1900, ["wood", "wood"], archers=[1])
    f.balcony(f.tops[-2], -1)


def L6(f):  # NEW: Boomer, powder barrels. Stone storehouses only fall to a blast
    f.stack(1280, ["crate", "crate"], archer_on_top=True)
    f.tower(1500, ["block", "block", "wood"], archers=[1, 2], inside=["barrel"])
    f.stack(1700, ["stone_block", "barrel"])
    f.tower(1900, ["block", "block"], archers=[0, 1], inside=["barrel"])


def L7(f):  # NEW: seesaw. Two guards balance on a pinned plank; knock a support stone out and they slide off
    f.tower(1250, ["wood"], archers=[0])
    f.seesaw(1600)
    f.tower(1950, ["wood", "wood"], archers=[1, 0])


def L8(f):  # NEW: rescue
    f.stack(1250, ["barrel", "barrel"])
    f.tower(1450, ["wood", "wood"], archers=[1], inside=["barrel"])
    f.stack(1640, ["crate", "barrel"])
    f.tower(1830, ["block", "wood"], archers=[1, 0], inside=["barrel"])
    # The captive stands in the open between the tower and the weak-point stack (the right screen
    # corner art used to hide it), and the camera shows a little more on the right.
    f.captive(2000, 0, "free_scout")
    f.stack(2140, ["barrel", "barrel", "barrel"])
    f.weak_last("free_scout")
    f.camera_extra = 160


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
def L11(f):  # NEW: rolling logs. Two logs wait on a dune above the stone ruins
    f.plateau(1100, 1280, 1560, 170, "rock")
    f.roller("log", 1150, 170, "ROLLING LOGS!")
    f.roller("log", 1236, 170, None)
    f.pyramid(1700, 3)
    f.tower(2000, ["stone", "stone"], archers=[1, 2], roof=False)
    f.tower(2250, ["stone"], archers=[0, 1], roof=False)


def L12(f):  # NEW: throwing beam. The guards on the high mesa hide in an iron strongroom; only the
    # powder keg the beam throws can blow it open (no Boomer in the loadout)
    f.tower(1430, ["wood", "wood"], archers=[1, 0])
    f.launch_seesaw(1150, payload="barrel", kick=(630.0, -1150.0))
    f.terrace(1700, 2150, 140)
    f.tower(1830, ["wood"], archers=[0])
    f.floor("iron", 2060, 0)
    f.archer(2060, 0)


def L13(f):  # NEW: crushing gate (timed)
    f.stack(1280, ["stone_block", "stone_block"], archer_on_top=True)
    f.crusher(1450, -420, 360)
    f.tower(1700, ["stone", "stone", "wood"], archers=[0, 1, 2], banners=(2,))


def L14(f):  # NEW: dominoes. Five standing slabs lead into the keep
    f.dominoes(1300, 5)
    f.tower(1900, ["stone", "wood"], archers=[1, 0])
    f.pyramid(2200, 3)


def L15(f):  # NEW: boulder run. A boulder rests on a ruin hilltop above a long slope
    f.plateau(1100, 1300, 1650, 220, "rock")
    f.roller("boulder", 1250, 220, "ROLL IT!")
    f.archer(1150, -220)
    f.tower(1800, ["wood", "wood"], archers=[1, 0])
    f.tower(2080, ["stone", "wood"], archers=[1])


def L16(f):  # NEW: weak point drops a crusher through a tower
    f.stack(1260, ["barrel", "barrel"])
    f.weak_last("drop_crusher")
    f.tower(1450, ["block", "wood"], archers=[1, 0], inside=["barrel"])
    top = f.tower(1720, ["block", "block", "wood"], archers=[2, 1], inside=["barrel"])
    f.crusher(1720, top - 100 - 120, -(top - 100 - 120) - 50, mode="trigger", trigger="drop_crusher", size=(240, 100))
    f.tower(1990, ["block", "wood"], archers=[1], inside=["barrel"])


def L17(f):  # NEW: boulder trap. A boulder is tied on the slope above the obelisk
    f.boulder_trap(1100, 1220, 1560, 260)
    f.wall(1700, 2, 2)
    f.tower(1950, ["stone", "stone", "stone", "wood"], archers=[1, 2, 3])
    f.balcony(f.tops[-4], -1)
    f.balcony(f.tops[-4], 1)


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


def L19(f):  # NEW: collapsing rope bridge. Cut either suspension rope and the guarded span tips
    f.tower(1280, ["narrow", "narrow", "narrow"], archers=[1], roof=False)

    def bridge_guard():
        f.archer(1635, 0)
        f.archer(1765, 0)
    f.rope_bridge(1700, 360, -560, bridge_guard, drop=120)
    f.tower(2120, ["narrow", "narrow", "narrow"], archers=[1, 2], roof=False)


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
def L21(f):  # NEW: sluice gate. The dock guards shelter in iron sheds; the flood washes them out
    f.flood(1280, reach=760, pool=250)
    f.floor("iron", 1500, 0)
    f.archer(1500, 0)
    f.floor("iron", 1730, 0)
    f.archer(1730, 0)
    f.tower(1960, ["wood", "wood"], archers=[0, 1])


def L22(f):  # NEW: Quaky + breakable ground. The smugglers' strongroom sits on a cracked rock shelf
    f.tower(1400, ["stone", "wood"], archers=[1])
    f.stack(1580, ["stone_block", "stone_block"])
    f.tower(1720, ["stone", "stone", "wood"], archers=[1, 2])
    f.b("stone_block", 1880, -32)
    f.weak_last("shelf")

    def strongroom():
        f.floor("iron", 2100, 0)
        f.archer(2100, 0)
        f.archer(2100, -154)
    f.ledge(1960, 300, strongroom, "shelf", style="timber")


def L23(f):  # NEW: harbor bell. A bronze bell hangs between two lookout towers
    f.tower(1440, ["wood", "wood", "wood"], archers=[1, 2])
    f.bell(1665, -470, rope=110)
    f.tower(1890, ["wood", "wood", "wood"], archers=[1, 2])


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


def L27(f):  # NEW: dockside crane. Knock the counterweight off and the arm drops its boulder
    f.tower(1250, ["stone", "wood"], archers=[1])
    f.crane(1700)


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


def L32(f):  # NEW: powder cart. Cut its brake rope and the bolted kegs roll into the crystal mine
    f.powder_cart(1100, 1380, 1700, 200, at=0.18, barrels=2)
    f.archer(1140, -200)
    f.tower(1850, ["crystal", "wood"], archers=[1, 0], inside=["barrel"])
    f.stack(1990, ["stone_block", "stone_block", "stone_block"])
    f.tower(2140, ["block", "crystal"], archers=[0, 1])


def L33(f):  # REMIX: mine cart on rails
    f.tower(1250, ["stone", "wood"], archers=[1])
    f.stack(1420, ["stone_block", "stone_block"], archer_on_top=True)
    f.deck(1750, 430, lambda: f.tower(1750, ["crystal", "wood"], archers=[1, 0], inside=["barrel"]), travel_x=90, period_s=8.0, **CART)


def L34(f):  # NEW: lava plume between the islands
    f.tower(1300, ["stone", "wood"], archers=[1])
    f.tower(1750, ["crystal", "wood"], archers=[1, 0])
    f.geyser(1525, 520, period=4.5, burst=1.5)
    f.mechanism("spikes", 1960, -22, [180, 44])
    f.tower(2160, ["block", "wood"], archers=[0, 1])


def L35(f):  # NEW: runaway wheel. A giant wheel on the mine hill
    f.plateau(1100, 1350, 1750, 260, "rock")
    f.roller("wheel", 1240, 260, "RUNAWAY WHEEL!")
    f.tower(1900, ["block", "stone", "wood"], archers=[1, 2])
    f.stack(2040, ["stone_block", "stone_block"])
    f.tower(2180, ["wood", "wood"], archers=[1, 0])


def L36(f):  # REMIX: powder magazine packed with crystal
    f.stack(1250, ["stone_block", "barrel"])
    f.tower(1450, ["block", "block", "wood"], archers=[1, 2], inside=["barrel"])
    f.stack(1650, ["crystal_block", "barrel", "crystal_block"])
    f.tower(1850, ["crystal", "wood"], archers=[0, 1])
    f.stack(2030, ["barrel", "rune_crystal", "stone_block"], archer_on_top=True)


def L37(f):  # NEW: hanging cages. Swing one into the towers, drop the other on the hut
    f.tower(1400, ["block", "stone", "wood"], archers=[1, 2])
    f.cage(1595, -580, rope=150)
    f.tower(1790, ["block", "stone", "wood"], archers=[1, 2])
    f.tower(2080, ["wood"], archers=[0, 1], roof=False)
    f.cage(2080, -440, rope=100, frame_x=2240)


def L38(f):  # NEW: mill wheel. The forge strongroom is iron (no Boomer here); free the jammed wheel and
    # its paddles batter the strongroom off the cliff
    f.tower(1200, ["stone", "wood"], archers=[1])
    f.stack(1350, ["stone_block", "stone_block", "crate"])
    f.weak_last("mill")
    f.note(1350, -250, "BREAK THE BRAKE!")
    f.water_wheel(1700, -250, "mill", radius=230, paddles=4, dps=-80)
    f.floor("iron", 2030, 0)
    f.archer(2030, 0)
    f.archer(2030, -154)


def L39(f):  # NEW: wrecking ball. An iron ball is tied back; cut the latch and it swings through the keep
    f.pendulum(1600, -640, 400, 58, 1120, -470)
    f.tower(1600, ["block", "wood"], archers=[1, 0])
    f.tower(1890, ["wood", "wood"], archers=[1, 0])


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
    f.tower(2000, ["narrow", "narrow"], archers=[1, 0])
    f.stack(2110, ["stone_block"], archer_on_top=True)
    f.geyser(1490, 600, period=3.5, burst=1.5)


def L43(f):  # NEW: spring trap. Guards stand on a sprung platform held down by a latch rope
    f.tower(1300, ["wood", "wood"], archers=[1, 0])
    f.spring_trap(1650, lean=-70.0)
    top = f.tower(2000, ["stone", "wood"], archers=[1, 0])
    f.rope_load(2000, top - 100 - 40 - 90 - 220, 220, crane_x=2200)


def L44(f):  # NEW: ice slide. A train of ice blocks waits on a frozen hilltop
    f.plateau(1100, 1400, 1700, 180, "ice")
    for x in (1200, 1264, 1328):
        f.b("ice_block", x, -212)
    f.archer(1264, -244)
    f.note(1264, -280, "ICE SLIDE!")
    f.tower(1850, ["narrow", "narrow", "narrow"], archers=[2, 1])
    f.tower(2100, ["block", "stone", "wood"], archers=[1, 2])


def L45(f):  # REMIX: windmill hall with a swinging counterweight
    f.terrace(1250, 2100, 60)
    f.floor("hall", 1500, 0)
    top = f.floor("hall", 1500, -146, banner=True)
    f.archer(1450, 0)
    f.archer(1550, -146)
    f.b("roof_tile", 1500, top - 50, flag=True)
    f.tower(1860, ["wood", "wood"], archers=[1])
    f.stack(2030, ["stone_block", "stone_block"], archer_on_top=True)
    f.mechanism("swing", 2160, -600, trigger="", length=250, diameter=76, arc_deg=30, period_s=3.4)


def L46(f):  # NEW: two seesaws over the clouds; the first rests on ice (fire melts it)
    f.tower(1150, ["stone", "wood"], archers=[1])
    f.seesaw(1500, support="ice_block")
    f.seesaw(1950, support="crate", side=-1)
    f.stack(2250, ["ice_block", "ice_block"], archer_on_top=True)


def L47(f):  # REMIX: cut the rope to lower the captive's cage
    f.terrace(1150, 2300, 70)
    f.stack(1250, ["stone_block", "barrel"])
    f.tower(1450, ["wood", "wood"], archers=[1], inside=["barrel"])
    f.stack(1640, ["ice_block", "stone_block"])
    f.tower(1830, ["block", "wood"], archers=[1, 0], inside=["barrel"])
    f.captive(2180, 0, "free_pilot")
    f.rope_load(2040, -480, 120, load="crate", releases="free_pilot", crane_x=2040 + 0.01, crane_ground=-70)


def L48(f):  # REMIX: twin airships drifting out of step
    for i, x in enumerate((1350, 1760)):
        f.deck(x, 330, lambda x=x, i=i: f.tower(x, ["stone", "wood"] if i == 0 else ["block", "wood"], archers=[1, 0]),
               floating=True, travel_x=24, travel_y=14, period_s=6.0 + i, phase=1.5 * i, **SHIP,
               balloon="boss_airship_balloon", balloon_size=[360, 150], balloon_y=-520)
    f.terrace(2000, 2300, 100)
    f.tower(2120, ["narrow", "narrow"], archers=[1, 0])


def L49(f):  # FINALE CONTRAPTION: cart → dominoes → keep
    f.plateau(1100, 1300, 1550, 180, "rail")
    f.b("cart", 1210, -215)
    f.archer(1130, -180)
    f.dominoes(1660, 4)
    f.tower(2160, ["stone", "wood"], archers=[1, 0])


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
        "Only two kegs this time. Blow the storehouse kegs with Boomer, then finish with Rocky."),
    7: ("Seesaw Watch", 1, L7, ["bomb", "stone", "fire", "stone"], {}, [],
        "Two guards stand on one end of the seesaw. Knock out the stone under them and they slide off."),
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
        "Stone shrugs off fire. Knock the logs off the dune: they roll down and ram the ruins."),
    12: ("Twin Mesas", 2, L12, ["cyclone", "stone", "stone", "stone"], {}, [
        T(), E("wizard", "catapult", "smoke"), F("note:SLAM IT!", "THROWING BEAM!"),
        S("wizard", "Slam the high end of that beam and it hurls the powder keg!"), D("note:SLAM IT!", "stone")],
        "The iron strongroom only breaks to a blast. Slam the beam to throw the keg onto it."),
    13: ("Crusher Gate", 2, L13, ["cyclone", "bomb", "stone", "stone"], {}, [
        T(), F("@crusher", "CRUSHER!"), E("captain"), S("captain", "Shoot between the slams!"), M("captain", "point")],
        "The crusher eats shots. Fire as it rises."),
    14: ("Domino Ruins", 2, L14, ["cyclone", "bomb", "stone", "stone"], {}, [],
        "Topple the first slab: the row falls into the keep."),
    15: ("Boulder Run", 2, L15, ["cyclone", "bomb", "stone", "stone"], {}, [],
        "Push the boulder off the hilltop. It rolls through both towers."),
    16: ("Powder Caravan", 2, L16, ["fire", "bomb", "cyclone", "stone"], {}, [
        T(), F("@crusher", "DROP THE CRUSHER!"), F("weak", "TRIGGER"), E("captain"), S("captain", "Blow the barrels, drop the stone!")],
        "The front barrels hold the crusher. Pop them and it falls through the keep."),
    17: ("Boulder Trap", 2, L17, ["bomb", "cyclone", "stone", "stone"], {}, [],
        "Cut the rope on the hill. The boulder rolls through the wall into the obelisk."),
    18: ("Prisoner Well", 2, L18, ["cyclone", "bomb", "stone", "stone"], {}, [
        T(), E("captive", "fortress", "drop"), S("captive", "The bridge winch opens my cage!"), F("weak", "BREAK THIS"),
        F("captive:0", "RESCUE!")],
        "Flip the lever or break the bridge support to free the captive."),
    19: ("Ropebridge Ambush", 2, L19, ["cyclone", "fire", "bomb", "stone"], {}, [
        T(), F("@hanging_platform", "CUT A ROPE!"), E("captain"), S("captain", "One cut tips the whole bridge into the canyon.")],
        "Cut either suspension rope. The bridge tips and throws its guards into the canyon."),
    20: ("Sandstone Citadel", 2, L20, ["bomb", "cyclone", "fire", "fire"], {}, [
        T(), E("baron", "boss", "smoke"), S("baron", "My keep slides. My shield holds!"), M("baron", "shake"),
        F("weak", "OPEN THE GATE"), F("core", "TIME THE ARMOR GAP!")],
        "Boss: the gem on his roof shields him. Shoot through the gap in its rotating armor."),
    21: ("Dockside Shacks", 3, L21, ["stone", "cyclone", "stone", "stone"], {"tide": TIDE}, [
        T(), E("captain"), F("@flood", "SLUICE GATE!"), S("captain", "Their sheds are iron. Smash the sluice gate and let the sea in!"),
        D("@flood", "stone")],
        "Stones bounce off iron. Hit the sluice gate: the flood drowns the guards in the sheds."),
    22: ("Smugglers' Pier", 3, L22, ["quake", "stone", "fire", "stone"], {}, [
        T(), E("wizard", "catapult", "smoke"), S("wizard", "Drive Quaky down and the ground breaks!"),
        F("@trapdoor", "CRACKED LEDGE!"), D("weak", "quake")],
        "The iron strongroom stands on a cracked shelf. Break the keystone and the shelf drops into the sea."),
    23: ("Harbor Bell", 3, L23, ["quake", "bomb", "stone", "stone"], {"tide": TIDE}, [],
        "Hit the bronze bell hard: it swings into the right tower."),
    24: ("Harbor Lighthouse", 3, L24, ["quake", "cyclone", "stone", "stone"], {}, [],
        "Twister clears the crow's nests. Knock the front stone off the rune switch, then hit it to drop the back guards."),
    25: ("Water Spout", 3, L25, ["quake", "fire", "stone", "stone"], {}, [
        T(), F("@geyser", "GEYSER!"), E("captain"), S("captain", "Ride the spout up to the high perch!"), D("@geyser", "stone")],
        "Shots through the erupting spout get thrown upward."),
    26: ("Two Ships", 3, L26, ["bomb", "cyclone", "stone", "stone"], {"tide": TIDE}, [],
        "Two ships, two rhythms. Knock the towers overboard."),
    27: ("Dockside Crane", 3, L27, ["quake", "fire", "stone", "fire"], {}, [],
        "Knock the counterweight stones off the crane arm, or cut its rope, to drop the boulder."),
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
    32: ("Powder Express", 4, L32, ["fire", "cyclone", "stone", "stone"], {}, [
        T(), F("note:CUT THE ROPE!", "POWDER CART!"), E("captain"), S("captain", "Cut the brake rope. Those kegs will do the smashing for us.")],
        "Cut the brake rope. The cart hits the keg in the crystal tower. The far keep hides behind stone."),
    33: ("Rail Cart", 4, L33, ["bomb", "cyclone", "fire", "stone"], {}, [],
        "Lead the cart: aim where it is going."),
    34: ("Lava Plume", 4, L34, ["quake", "fire", "stone", "fire"], {}, [
        T(), F("@geyser", "LAVA PLUME!"), E("captain"), S("captain", "It burns and it lifts. Use it!")],
        "The plume lifts shots and burns anything thrown into it."),
    35: ("Runaway Wheel", 4, L35, ["cyclone", "quake", "stone", "stone"], {}, [],
        "Hit the giant wheel with Rocky. It rolls down the hill and rams the stone keep."),
    36: ("Powder Magazine", 4, L36, ["fire", "bomb", "stone", "stone"], {}, [],
        "Barrels and crystals together. One spark, chain reaction."),
    37: ("Hanging Cages", 4, L37, ["cyclone", "bomb", "fire", "stone"], {}, [],
        "Hit a cage to swing it into the towers. Cut a rope to drop it."),
    38: ("Iron Forge", 4, L38, ["quake", "stone", "fire", "stone"], {}, [
        T(), E("captain"), F("fortress", "IRON STRONGROOM"), S("captain", "Stones won't dent that iron. But the mill wheel is only jammed..."),
        F("weak", "BREAK THE BRAKE!"), D("weak", "stone")],
        "Break the brake block: the freed mill wheel batters the iron strongroom off the cliff."),
    39: ("Wrecking Ball", 4, L39, ["bomb", "cyclone", "fire", "stone"], {}, [],
        "Cut the latch rope: the iron ball swings through the keep."),
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
    43: ("Spring Trap", 5, L43, ["quake", "cyclone", "stone", "stone"], {"wind": BREEZE}, [],
        "Cut the latch rope under the spring, then cut the rope holding the rock over the keep."),
    44: ("Ice Slide", 5, L44, ["quake", "bomb", "stone", "stone"], {}, [],
        "Hit the back of the ice train. It slides down the frozen slope into the towers."),
    45: ("Windmill Isle", 5, L45, ["bomb", "cyclone", "fire", "stone"], {"wind": GUSTY}, [],
        "Gusts change direction. Wait for calm or use them."),
    46: ("Sky Seesaws", 5, L46, ["quake", "fire", "fire", "stone"], {}, [],
        "Melt the ice under the first seesaw with Blaze. Smash the crate under the second."),
    47: ("Sky Captive", 5, L47, ["fire", "bomb", "cyclone", "stone"], {"wind": BREEZE}, [
        T(), E("captive", "fortress", "smoke"), S("captive", "Cut the rope and my cage opens!"), F("@rope_load", "CUT THE ROPE!")],
        "The rope holds the cage lock. Cut it."),
    48: ("Twin Airships", 5, L48, ["quake", "cyclone", "fire", "stone"], {"wind": GUSTY}, [],
        "Two airships drift out of step. Wait until they line up."),
    49: ("Baron's Contraption", 5, L49, ["quake", "bomb", "stone", "stone"], {"wind": STORM}, [
        T(), E("baron", "top", "smoke"), S("baron", "You will never reach my airship!"), M("baron", "shake")],
        "Push the cart: it knocks the dominoes into the keep."),
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


# Special Missions open one by one: each needs its campaign level cleared. Picked so every mission
# opens in its own realm, after the heroes it hands out have been introduced (cyclone L12, quake L22).
MISSION_UNLOCK = {103: 10, 106: 14, 101: 17, 108: 24, 102: 27, 104: 33, 105: 37, 107: 44}

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


# =============================================================================== Master Sieges
# Ten hard mechanic puzzles, unlocked together at 25 campaign stars. They use challenge storage and
# rewards, but stay out of the daily rotation. Each row keeps the normal challenge tuple shape.
def SP121(f):  # Flooded foundry: low guards are protected by iron, so the sluice is mandatory
    f.flood(1260, reach=900, pool=250, depth=85)
    for x in (1460, 1710):
        top = f.floor("iron", x, 0)
        f.archer(x, 0)
        f.archer(x, top)
    f.tower(2040, ["stone", "wood"], archers=[1, 0])


def SP122(f):  # Jammed mill: the wheel is the only practical answer to the iron room
    f.tower(1200, ["stone", "wood"], archers=[1])
    f.stack(1350, ["stone_block", "stone_block", "crate"])
    f.weak_last("master_mill")
    f.water_wheel(1700, -250, "master_mill", radius=230, paddles=6, dps=-92)
    top = f.floor("iron", 2030, 0)
    f.archer(2030, 0)
    f.archer(2030, top)


def SP123(f):  # Three guards depend on one suspended span
    f.tower(1240, ["narrow", "narrow", "narrow"], archers=[1, 2], roof=False)

    def bridge_crew():
        for x in (1580, 1700, 1820):
            f.archer(x, 0)
    f.rope_bridge(1700, 400, -590, bridge_crew, drop=130)
    f.tower(2160, ["stone", "wood", "wood"], archers=[1, 2])


def SP124(f):  # An iron vault stands on a single cracked cliff shelf
    f.tower(1280, ["stone", "stone", "wood"], archers=[1, 2])
    f.b("stone_block", 1580, -32)
    f.weak_last("faultline")

    def cliff_vault():
        top = f.floor("iron", 1900, 0)
        f.archer(1845, 0)
        f.archer(1955, 0)
        f.archer(1900, top)
    f.ledge(1660, 480, cliff_vault, "faultline", style="rock")


def SP125(f):  # Winch hall: flip the lever and the visible pulley/counterweight lowers the span
    f.tower(1240, ["stone", "wood"], archers=[1, 0])
    f.lever(1450, 0, ["master_span"], facing=-1)
    f.mechanism("drawbridge", 1570, -168, [380, 36], "master_span",
                start_angle=-82, end_angle=0, duration_s=0.95, counterweight_travel=115)
    f.tower(2070, ["iron", "wood", "wood"], archers=[1, 2], roof=False)


def SP126(f):  # Powder express: the locked cart carries the only explosives
    f.powder_cart(1080, 1370, 1730, 230, at=0.12, barrels=3)
    f.archer(1130, -230)
    f.tower(1900, ["crystal", "stone", "wood"], archers=[1, 2, 0])
    f.tower(2200, ["iron", "wood"], archers=[1, 0], roof=False)


def SP127(f):  # Siege pitcher: no Boomer; the beam must throw its keg into the iron vault
    f.tower(1430, ["wood", "stone"], archers=[1, 0])
    f.launch_seesaw(1150, payload="barrel", kick=(700.0, -1190.0))
    f.terrace(1720, 2220, 150)
    f.tower(1830, ["wood", "wood"], archers=[1, 0])
    top = f.floor("iron", 2110, 0)
    f.archer(2110, 0)
    f.archer(2110, top)


def SP128(f):  # One lever starts the mill and opens a second sluice
    f.lever(1180, 0, ["clockwork", "second_sluice"])
    f.tower(1300, ["stone", "wood"], archers=[1])
    f.water_wheel(1710, -245, "clockwork", radius=215, paddles=6, dps=-100)
    f.flood(2030, reach=520, pool=150, depth=85, trigger="second_sluice")
    top = f.floor("iron", 2250, 0)
    f.archer(2250, 0)
    f.archer(2250, top)
    f.tower(2500, ["wood", "wood"], archers=[1, 0])


def SP129(f):  # Cut bridge then break the cliff under the surviving vault
    f.tower(1210, ["narrow", "narrow"], archers=[1, 0], roof=False)

    def bridge_pair():
        f.archer(1530, 0)
        f.archer(1670, 0)
    f.rope_bridge(1600, 350, -535, bridge_pair, drop=115)
    f.b("stone_block", 2050, -32)
    f.weak_last("last_cliff")

    def last_vault():
        f.floor("iron", 2300, 0)
        f.archer(2300, 0)
        f.archer(2300, -154)
    f.ledge(2120, 360, last_vault, "last_cliff", style="rock")


def SP130(f):  # Finale: powder cart starts a domino chain while the launch beam attacks the high vault
    f.powder_cart(1060, 1300, 1570, 190, at=0.14, barrels=2)
    f.dominoes(1660, 4, gap=108)
    f.tower(2130, ["stone", "wood", "wood"], archers=[1, 2, 0], inside=["barrel"])
    f.launch_seesaw(2520, payload="boulder", kick=(760.0, -980.0))
    f.terrace(2800, 3200, 170)
    top = f.floor("iron", 2990, 0)
    f.archer(2990, 0)
    f.archer(2990, top)


SPECIALS = {
    121: ("Flooded Foundry", 3, SP121, ["stone", "cyclone", "quake", "stone"], {}, "", {},
          "Iron protects the low guards. Open the sluice, then clear the high keep."),
    122: ("Mill of Teeth", 4, SP122, ["quake", "stone", "cyclone", "stone"], {}, "", {},
          "Break the mill brake. The wheel must batter the iron room loose."),
    123: ("The Last Rope", 2, SP123, ["fire", "cyclone", "stone", "stone"], {}, "", {},
          "Cut one suspension rope to tip three guards into the canyon."),
    124: ("Faultline Vault", 3, SP124, ["quake", "stone", "fire", "stone"], {}, "", {},
          "Break the keystone. The iron vault and everyone in it must fall."),
    125: ("Counterweight Hall", 2, SP125, ["cyclone", "stone", "fire", "stone"], {}, "", {},
          "Hit the lever to run the pulley and lower the counterweighted span."),
    126: ("Powder Express II", 4, SP126, ["fire", "cyclone", "quake", "stone"], {}, "", {},
          "Cut the brake rope. The powder cart is your only bomb."),
    127: ("The Siege Pitcher", 5, SP127, ["quake", "stone", "cyclone", "stone"], {"wind": BREEZE}, "", {},
          "Slam the beam to throw its keg into the high iron vault."),
    128: ("Clockwork Deluge", 3, SP128, ["stone", "cyclone", "quake", "stone"], {"tide": TIDE}, "", {},
          "One lever starts the wheel and opens the sluice. Time the chain reaction."),
    129: ("Bridge at World's End", 5, SP129, ["fire", "quake", "cyclone", "stone"], {"wind": GUSTY}, "", {},
          "Collapse the rope bridge, then break the cliff beneath the last vault."),
    130: ("Master's Chain", 4, SP130, ["quake", "cyclone", "fire", "stone"], {}, "", {},
          "Release the powder cart, topple the dominoes, and fire the throwing beam."),
}

SPECIAL_REQUIRED = {
    121: ["flood"], 122: ["water_wheel"], 123: ["rope_bridge"], 124: ["breakable_ledge"],
    125: ["pulley"], 126: ["explosive_cart"], 127: ["launch_seesaw"],
    128: ["water_wheel", "flood"], 129: ["rope_bridge", "breakable_ledge"],
    130: ["explosive_cart", "launch_seesaw"],
}


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



# ----------------------------------------------------------------------------- training grounds
# A short practice range before the first level with a new hero: three copies of that hero and a
# small target that shows off the ability. Built into data/training/training_<hero>.json.
def T_STONE(f):  # stone tower: Rocky's slam dives straight through stone
    f.tower(1450, ["stone", "wood"], archers=[1])


def T_FIRE(f):  # wooden tower: fire spreads along timber
    f.tower(1450, ["wood", "wood"], archers=[1])


def T_BOMB(f):  # guards packed close together: one blast takes several
    f.stack(1400, ["crate", "crate"], archer_on_top=True)
    f.stack(1520, ["crate", "crate"], archer_on_top=True)
    f.stack(1640, ["crate"])


def T_CYCLONE(f):  # light planks and an exposed guard on a high ledge
    f.tower(1500, ["wood", "wood", "wood"], archers=[2], roof=False)


def T_QUAKE(f):  # a stone tower on thin wooden legs: the ground shock topples it
    f.tower(1500, ["wood", "stone"], archers=[1])


# hero: (name, realm, builder, before_level)
# before_level 0: only reachable from Master Orin's Workshop (level 1's tutorial teaches Rocky).
TRAINING = {
    "stone": ("Rocky Training", 1, T_STONE, 0),
    "fire": ("Blaze Training", 1, T_FIRE, 3),
    "bomb": ("Boomer Training", 1, T_BOMB, 6),
    "cyclone": ("Twister Training", 2, T_CYCLONE, 12),
    "quake": ("Quaky Training", 3, T_QUAKE, 22),
}


# =============================================================================== Expansion: levels 51-75
# Three new realms. Harder than 1-50: more guards, iron and stone shelters, fewer power heroes, and
# set pieces that must be used (gadgets in src/game/gadget.gd: portals, gravity, magnets, bounce pads,
# pressure plates, relays, repair crystals). Boss levels 60, 70, 75 have three or four phases.
WAGON = {"chassis": "boss_highland_wagon", "chassis_fallback": "boss_siege_wheels", "chassis_h": 110}
BARGE = {"chassis": "boss_storm_barge", "chassis_fallback": "boss_galleon_hull", "chassis_h": 170}
ENGINE = {"chassis": "boss_citadel_engine", "chassis_fallback": "boss_mine_cart", "chassis_h": 100}
SQUALL = {"strength": 280, "period_s": 6.0, "gust_s": 3.0, "dir": -1, "alternate": True}
SWELL = {"amp_px": 55, "period_s": 7.0}


# ---- Realm 6: Scarlet Highlands
def L51(f):  # NEW REALM: a powder chain through stone keeps. No Boomer: light the first keg
    f.tower(1300, ["wood", "wood"], archers=[1, 0], inside=["barrel"])
    f.b("barrel", 1480, -29)
    f.tower(1660, ["stone", "stone"], archers=[1, 2], roof=False)
    f.b("barrel", 1800, -29)
    f.b("barrel", 1880, -29)
    f.pyramid(2040, 3)
    f.tower(2260, ["stone"], archers=[0, 1], roof=False)


def L52(f):  # Chain gallery: a two-storey powder hall, a keg stack and an iron hut on the far edge
    f.terrace(1250, 2400, 40)
    s1 = f.floor("hall", 1500, 0)
    f.archer(1430, 0)
    f.b("barrel", 1570, -29)
    s2 = f.floor("hall", 1500, s1, banner=True)
    f.archer(1570, s1)
    f.b("barrel", 1430, s1 - 29)
    f.b("roof_tile", 1500, s2 - 50, flag=True)
    f.balcony(f.tops[-1], 1)
    f.stack(1760, ["barrel", "barrel", "barrel"])
    f.tower(1980, ["stone", "wood", "wood"], archers=[1, 2], inside=["barrel"])
    f.floor("iron", 2220, 0)
    f.archer(2190, -154)
    f.b("barrel", 2265, -154 - 29)


def L53(f):  # Hidden switch: a rune under the front stone drops the iron vault's floor into the river
    f.b("stone_block", 1230, -32)
    f.rune_switch(1230, -32, ["vault_floor"])
    f.wall(1360, 2, 3)
    f.archer(1392, -192)
    f.tower(1600, ["block", "stone", "wood"], archers=[1, 2], inside=["barrel"])
    for x in (1872, 2128):
        f.b("stone_pillar", x, -70)
    f.trapdoor(2000, -162, 300, "vault_floor", hinge=1)
    f.floor("iron", 2000, -162)
    f.archer(1977, -162)
    f.archer(2023, -162)
    f.archer(2000, -316)


def L54(f):  # NEW: pressure plate. Knock the stone off the high shelf onto the plate: the gate lifts
    f.tower(1300, ["stone", "wood"], archers=[1])
    f.pyramid(1560, 4, top_archer=False)
    f.plate(1790, 0, ["keep_gate"], mass=6.0, width=130)
    f.mechanism("gate", 1900, -85, [60, 170], "keep_gate", travel_y=175, duration_s=0.5)
    f.floor("iron", 2070, 0)
    f.archer(2047, 0)
    f.archer(2093, 0)
    f.archer(2070, -154)


def L55(f):  # NEW: relay. Two levers far apart must both flip within 4 s to drop the vault floor
    f.lever(1230, 0, ["lamp_a"])
    f.tower(1420, ["stone", "wood"], archers=[1])
    top = f.tower(1700, ["block", "stone"], archers=[1], roof=False)
    f.lever(1700, top, ["lamp_b"], facing=-1)
    f.relay(1880, -420, ["lamp_a", "lamp_b"], ["twin_floor"], window=4.0)
    for x in (1912, 2148):
        f.b("stone_pillar", x, -70)
    f.trapdoor(2030, -162, 280, "twin_floor", hinge=1)
    f.floor("iron", 2030, -162)
    f.archer(2007, -162)
    f.archer(2053, -162)
    f.archer(2030, -316)


def L56(f):  # Counterweight: cut the rope and the boulder slams the beam, which throws its keg into iron
    f.tower(1280, ["stone", "wood"], archers=[1])
    f.launch_seesaw(1640, payload="barrel", kick=(640.0, -1150.0))
    f.rope_load(1560, -520, 260, load="boulder", crane_x=1460)
    f.terrace(1900, 2440, 120)
    f.floor("iron", 2030, 0)
    f.archer(2030, 0)
    f.archer(2000, -154)
    f.floor("iron", 2260, 0)
    f.archer(2260, 0)


def L57(f):  # Turning shields: two orbiting plate rings guard the keeps; a lever stops the far one
    f.tower(1300, ["block", "wood"], archers=[1, 0])
    top1 = f.tower(1600, ["stone", "stone"], archers=[1, 2], roof=False)
    f.shield_ring(1600, top1 - 30, radius=125, plates=3, dps=60, plate_len=120)
    f.lever(1790, 0, ["far_ring"])
    top2 = f.tower(2000, ["block", "stone", "wood"], archers=[1, 2], roof=False)
    f.archer(2000, top2)
    f.shield_ring(2000, top2 - 40, radius=150, plates=4, dps=-70, plate_len=120, trigger="far_ring")


def L58(f):  # Hanging fortress: a gondola keep over the river; heavy loads hang over the shore guards
    f.tower(1280, ["stone", "wood"], archers=[1, 0])

    def gondola():
        f.archer(1560, 0)
        f.archer(1740, 0)
        f.stack(1650, ["crate", "barrel"], archer_on_top=True)
    f.hanging(1650, -640, 300, 140, gondola)
    top = f.tower(2100, ["block", "stone"], archers=[1, 2], roof=False)
    f.rope_load(2100, top - 340, 170, load="iron_ball", crane_x=2300)


def L59(f):  # Load-bearing: a stone keep on two wooden stilts and a vault on a cracked shelf
    f.tower(1280, ["wood", "wood"], archers=[1])
    f.stack(1460, ["stone_block", "stone_block"], archer_on_top=True)
    for dx in (-70, 70):
        f.b("post_tall", 1700 + dx, -100)
    f.b("plank_long", 1700, -213)
    f.weak_last()
    base = -226
    top = f.floor("stone", 1700, base)
    top = f.floor("stone", 1700, top)
    f.archer(1700, base)
    f.archer(1700, top)
    f.b("stone_block", 1900, -32)
    f.weak_last("shelf_59")

    def vault():
        f.floor("iron", 2120, 0)
        f.archer(2100, 0)
        f.archer(2120, -154)
    f.ledge(1980, 300, vault, "shelf_59", style="rock")


def L60(f):  # BOSS: Thane Brakk's war wagon. Outer gate, drum core behind a shield ring, two engineers
    f.wall(1180, 2, 2)
    f.weak_last("wagon_gate")
    f.mechanism("gate", 1340, -60, [70, 118], "wagon_gate", travel_y=122, duration_s=0.46)
    f.tower(1460, ["block", "stone", "wood"], archers=[1, 2], inside=["barrel"])

    def wagon():
        top1 = f.tower(1820, ["block", "stone", "wood"], archers=[1, 2], inside=["power_core"], roof=False)
        top2 = f.tower(2080, ["stone", "wood"], archers=[1], roof=False)
        f.cannon(1770, top1)
        f.core(2030, top2)
        f.shield_ring(2030, top2 - 36, radius=100, plates=3, dps=60, plate_len=105)
        f.engineer(1950, 0)
        f.engineer(1880, top1)
        f.boss_unit(2130, top2, "Thane Brakk", 190,
                    [{"at": 0.75, "do": ["reinforce"]}, {"at": 0.5, "do": ["shield", "charge"]},
                     {"at": 0.25, "do": ["enrage", "reinforce"]}],
                    reinforce=[(1780, top1), (1860, top1)])
    f.deck(1950, 500, wagon, travel_x=45, period_s=8.0, **WAGON)


# ---- Realm 7: Storm Crags
def L61(f):  # NEW REALM: three rafts on a heavy swell. Hit them when they line up
    f.tower(1280, ["stone", "wood"], archers=[1])
    for i, (x, fl) in enumerate(((1660, ["wood", "wood"]), (1960, ["block", "wood"]), (2260, ["narrow", "narrow"]))):
        f.deck(x, 240, lambda x=x, fl=fl: f.tower(x, fl, archers=[1, 0], inside=["barrel"] if fl[0] == "block" else None),
               floating=True, travel_x=0, travel_y=16, period_s=5.0 + i * 0.7, phase=1.2 * i, **HULL)


def L62(f):  # Two sluices: the low one floods the iron sheds, a lever opens the high one on the terrace
    f.flood(1260, reach=640, pool=230)
    f.floor("iron", 1480, 0)
    f.archer(1480, 0)
    f.floor("iron", 1700, 0)
    f.archer(1700, 0)
    f.lever(1370, 0, ["upper_sluice"])
    f.terrace(1990, 2600, 150)
    f.flood(2170, reach=420, pool=110, pool_h=130, trigger="upper_sluice")
    # Terrace shed: the lower guard needs the upper sluice (the lever); the roof guard stands on
    # stone, so it takes a hard, well-aimed shot (iron could not be broken at all).
    f.floor("stone", 2360, 0)
    f.archer(2360, 0)
    f.archer(2360, -154)


def L63(f):  # Fire spreads along a timber bridge to the far keep; the rope bridge burns too
    f.tower(1280, ["wood", "wood"], archers=[1, 0])
    f.bridge(1640, 2, -146, archers=(0, 1))
    for x in (1440, 1640, 1840):
        f.b("post", x, -60)
        f.b("plank_short", x, -133)

    def span():
        f.archer(2105, 0)
        f.archer(2235, 0)
    f.rope_bridge(2170, 300, -560, span, drop=120)


def L64(f):  # NEW: thaw. An iron vault rests on ice pillars; melt or shatter them and it drops
    f.tower(1300, ["stone", "wood"], archers=[1])
    for dx in (-80, 80):
        f.b("ice_pillar", 1650 + dx, -70)
    f.b("ice_slab", 1650, -160)
    f.floor("iron", 1650, -180)
    f.archer(1650, -180)
    f.archer(1650, -334)
    f.tower(1950, ["crystal", "stone"], archers=[1, 2], roof=False)
    f.stack(2140, ["ice_block", "ice_block", "ice_block"], archer_on_top=True)


def L65(f):  # NEW: magnet. Flip the lever: the lodestone tears the iron vault apart
    f.tower(1280, ["stone", "wood"], archers=[1])
    f.lever(1460, 0, ["lodestone"])
    f.floor("iron", 1700, 0)
    top = f.floor("iron", 1700, -154)
    f.archer(1700, 0)
    f.archer(1700, -154)
    f.archer(1700, top)
    f.magnet(1980, -520, radius=420, accel=3200, start_on=False, trigger="lodestone", post_ground=0.0)
    f.tower(2160, ["block", "wood"], archers=[1, 0])


def L66(f):  # NEW: gravity flip. A rune lifts the whole keep, then lets it fall from the sky
    f.tower(1280, ["stone", "wood"], archers=[1])
    f.b("stone_block", 1460, -32)
    f.rune_switch(1460, -32, ["flip"])
    f.gravity(1760, -380, 420, 760, g=(0, -760), start_on=False, trigger="flip", duration=2.6)
    f.tower(1760, ["iron", "stone", "wood"], archers=[1, 2])
    f.archer(1760, 0)
    f.tower(2130, ["block", "stone"], archers=[1, 2], roof=False)


def L67(f):  # NEW: portals. The keep is roofed in iron; the orange ring on the cliff leads inside
    f.tower(1280, ["stone", "wood"], archers=[1])
    f.portals((1450, -420), (1960, -135), dir_a=180, dir_b=90, radius=40)
    for dx in (-100, 100):
        f.b("iron_block", 1960 + dx, -32)
        f.b("iron_block", 1960 + dx, -96)
        f.b("iron_block", 1960 + dx, -160)
    f.archer(1918, 0)
    f.archer(2002, 0)
    f.b("iron_beam", 1960, -205)
    f.b("iron_block", 1960, -250)
    f.tower(2250, ["block", "wood"], archers=[1, 0])


def L68(f):  # NEW: bounce pads. A tall iron wall hides the courtyard; bank a shot off the mushroom
    f.tower(1280, ["wood", "wood"], archers=[1, 0])
    for r in range(5):
        f.b("iron_block", 1560, -32 - 64 * r)
    f.archer(1560, -320)
    f.bumper(1760, -560, radius=60, kick=700)
    f.tower(1820, ["stone", "wood"], archers=[1, 0])
    for r in range(4):
        f.b("iron_block", 2060, -32 - 64 * r)
    f.bumper(1120, 70, radius=70, kick=950)
    f.tower(2260, ["wood"], archers=[0, 1], roof=False)


def L69(f):  # Three lamps: lever, rune and plate must all fire within 6 s to open the storm vault
    f.lever(1230, 0, ["lamp_1"])
    top = f.tower(1420, ["tall", "tall"], archers=[1], roof=False, flag=False)
    f.b("stone_block", 1470, top - 32)
    f.plate(1590, 0, ["lamp_2"], mass=6.0)
    f.b("stone_block", 1760, -32)
    f.rune_switch(1760, -32, ["lamp_3"])
    f.relay(1990, -520, ["lamp_1", "lamp_2", "lamp_3"], ["storm_vault"], window=6.0)
    for x in (1912, 2148):
        f.b("stone_pillar", x, -70)
    f.trapdoor(2030, -162, 280, "storm_vault", hinge=1)
    f.floor("iron", 2030, -162)
    f.archer(2007, -162)
    f.archer(2053, -162)
    f.archer(2030, -316)


def L70(f):  # BOSS: Morwen the Storm Witch on a rune barge. A reverse-gravity ward guards her core;
    # break the rune stone under the ward to collapse it
    f.tower(1260, ["stone", "wood"], archers=[1])
    f.portals((1430, -460), (2280, -700), dir_a=180, dir_b=135, radius=58)

    def barge():
        top1 = f.tower(1800, ["block", "stone", "wood"], archers=[1, 2], inside=["power_core"], roof=False)
        top2 = f.tower(2060, ["stone", "wood"], archers=[1], roof=False)
        f.cannon(1750, top1)
        f.core(2010, top2)
        f.engineer(1930, 0)
        f.boss_unit(2110, top2, "Morwen the Storm Witch", 200,
                    [{"at": 0.7, "do": ["shield"]}, {"at": 0.45, "do": ["reinforce", "charge"]},
                     {"at": 0.2, "do": ["enrage"]}],
                    reinforce=[(1760, top1), (1840, top1)])
    f.deck(1930, 520, barge, floating=True, travel_x=20, travel_y=14, period_s=7.0, **BARGE)
    f.gravity(1930, -780, 560, 120, g=(0, -2600), trigger="ward")
    f.b("rune_crystal", 1470, -32)
    f.weak_last("ward")


# ---- Realm 8: Iron Citadel
def L71(f):  # NEW REALM: armoured bastion. Two hidden kegs behind iron; cracked weak points drop crushers
    f.tower(1260, ["iron", "stone"], archers=[1, 2], roof=False)
    f.b("barrel", 1450, -29)
    f.weak_last("crusher_a")
    top = f.tower(1650, ["iron", "iron", "wood"], archers=[1, 2])
    f.crusher(1650, top - 100 - 150, -(top - 100 - 150) - 60, mode="trigger", trigger="crusher_a", size=(230, 100))
    f.b("barrel", 1860, -29)
    f.weak_last("crusher_b")
    top2 = f.tower(2060, ["iron", "stone", "wood"], archers=[1, 2])
    f.crusher(2060, top2 - 100 - 150, -(top2 - 100 - 150) - 60, mode="trigger", trigger="crusher_b", size=(230, 100))


def L72(f):  # NEW: repair crystal. It rebuilds every broken block near it until you shatter it
    f.tower(1260, ["stone", "wood"], archers=[1])
    f.tower(1560, ["block", "stone", "wood"], archers=[1, 2], inside=["barrel"])
    f.b("crystal_pillar", 1760, -70)
    src = f._bi()
    f.repair(src, radius=420, delay=2.2)
    f.tower(1960, ["stone", "stone", "wood"], archers=[1, 2])
    f.stack(2160, ["stone_block", "stone_block", "stone_block"], archer_on_top=True)
    f.shield_ring(1760, -70, radius=110, plates=2, dps=80, plate_len=110)


def L73(f):  # Prison tower: two captives. One cage opens on the plate, the other when its rope is cut
    f.tower(1260, ["iron", "wood"], archers=[1])
    top = f.tower(1480, ["tall", "tall"], archers=[1], roof=False, flag=False)
    f.b("stone_block", 1540, top - 32)
    f.plate(1650, 0, ["cell_a"], mass=6.0)
    f.captive(1800, 0, "cell_a")
    top2 = f.tower(2020, ["stone", "stone", "wood"], archers=[1, 2])
    f.captive(2240, 0, "cell_b")
    f.rope_load(2240, -440, 230, load="crate", releases="cell_b", crane_x=2360)
    f.archer(2020, 0)


def L74(f):  # Forge trap: push the iron cart onto the plate to drop the crusher; a magnet repels iron
    f.plateau(1080, 1300, 1600, 160, "rail")
    f.b("cart", 1215, -195)
    f.archer(1110, -160)
    f.plate(1720, 0, ["forge_drop"], mass=8.0, width=170)
    top = f.tower(1950, ["iron", "iron", "wood"], archers=[1, 2])
    f.archer(1950, 0)
    f.crusher(1950, top - 100 - 150, -(top - 100 - 150) - 60, mode="trigger", trigger="forge_drop", size=(240, 100))
    f.mechanism("spikes", 2170, -22, [160, 44])
    f.tower(2360, ["iron"], archers=[0, 1], roof=False)


def L75(f):  # FINAL BOSS: the Iron Baron's citadel engine. Gate, repair crystal, shielded cores, magnet
    f.wall(1160, 2, 2)
    f.weak_last("citadel_outer")
    f.mechanism("gate", 1320, -60, [70, 118], "citadel_outer", travel_y=122, duration_s=0.46)
    f.tower(1440, ["iron", "stone", "wood"], archers=[1, 2], inside=["barrel"])
    f.b("crystal_pillar", 1600, -70)
    f.repair(f._bi(), radius=260, delay=2.5)

    def engine():
        # Stone base (was iron): the guard inside could not be reached at all.
        # The guard that sat beside the core was unreachable behind it; the core floor is now empty.
        top1 = f.tower(1900, ["stone", "stone", "wood"], archers=[2], inside=["power_core"], roof=False)
        top2 = f.tower(2160, ["iron", "wood"], archers=[1], roof=False)
        f.cannon(1850, top1)
        f.cannon(1950, top1)
        f.core(2110, top2)
        f.shield_ring(2110, top2 - 36, radius=100, plates=2, dps=60, plate_len=105)
        # Very hard but fair with 4 heroes: shield, charge and enrage phases, no extra guards.
        f.boss_unit(2210, top2, "The Iron Baron", 190,
                    [{"at": 0.7, "do": ["shield"]}, {"at": 0.4, "do": ["charge"]}, {"at": 0.2, "do": ["enrage", "shield"]}])
    f.deck(2030, 540, engine, travel_x=60, period_s=9.0, **ENGINE)


LEVELS.update({
    51: ("Powder Ridge", 6, L51, ["fire", "stone", "stone", "stone"], {}, [
        T(), E("captain"), S("captain", "The Highlands! Their keeps are stone, but look at all that powder."),
        F("fortress", "POWDER CHAIN!"), E("wizard", "catapult", "smoke"), S("wizard", "No Boomer today. One spark should do it."),
        D("fortress", "fire")],
        "No Boomer here. Light the first keg with Blaze: each blast sets off the next keg."),
    52: ("Chain Gallery", 6, L52, ["bomb", "fire", "stone", "stone"], {}, [],
        "Kegs on every floor. Start the chain low and the hall brings itself down; the iron hut needs its keg."),
    53: ("Hidden Switch", 6, L53, ["quake", "stone", "stone", "stone"], {}, [
        T(), E("enemy", "fortress", "drop"), S("enemy", "Our vault is iron. Iron!"), M("enemy", "laugh"),
        E("captain"), S("captain", "Then we drop the floor under it. Look under that front stone...")],
        "Knock the front stone off the rune, hit the rune: the vault floor opens."),
    54: ("Weight of Stone", 6, L54, ["cyclone", "stone", "stone", "stone"], {}, [
        T(), F("@@plate", "PRESSURE PLATE!"), E("captain"), S("captain", "Drop something heavy on that plate and the gate lifts!"),
        D("@@plate", "stone")],
        "Knock the stone off the tall shelf onto the plate. The gate rises: then hit the guards inside."),
    55: ("Twin Levers", 6, L55, ["bomb", "stone", "stone", "stone"], {}, [
        T(), F("@@relay", "BOTH IN TIME!"), E("wizard", "catapult", "smoke"),
        S("wizard", "Two levers, one lock. Flip both before the lamps go dark!")],
        "Flip the low lever, then the high one within 4 seconds. The iron vault drops into the river."),
    56: ("The Counterweight", 6, L56, ["cyclone", "stone", "stone", "stone"], {}, [],
        "Cut the rope: the boulder slams the beam and throws the keg onto the iron vaults."),
    57: ("Turning Shields", 6, L57, ["bomb", "cyclone", "stone", "stone"], {}, [
        T(), F("fortress", "SHIELD RINGS!"), E("captain"), S("captain", "Shoot through the gaps. The lever stops the far ring!")],
        "Fire through the gaps in the orbiting plates. The lever on the ground stops the big ring."),
    58: ("Hanging Fortress", 6, L58, ["fire", "cyclone", "stone", "stone"], {}, [],
        "Cut the gondola ropes to dump its guards, then drop the iron ball on the keep."),
    59: ("Load-Bearing", 6, L59, ["quake", "bomb", "stone", "stone"], {}, [],
        "Break the glowing plank under the stone keep, then the cracked stone that holds the cliff shelf."),
    60: ("Thane Brakk's Wagon", 6, L60, ["quake", "bomb", "fire", "stone"], {}, [
        T(), E("baron", "boss", "smoke"), S("baron", "Meet my champion. His wagon crushes castles!"), M("baron", "laugh"),
        F("weak", "OPEN THE GATE"), F("core", "BREAK THE CORES!"),
        E("wizard", "catapult", "smoke"), S("wizard", "Open the gate, break both cores, stop the engineers!")],
        "Boss: break the gate stone first, then both cores (one behind the ring) and knock out the engineers."),
    61: ("Raft Run", 7, L61, ["cyclone", "stone", "stone", "stone"], {"tide": SWELL, "wind": SQUALL}, [
        T(), E("captain"), S("captain", "Storm Crags. Wind, swell and witchcraft."), F("fortress", "THREE RAFTS"),
        E("baron", "top", "smoke"), S("baron", "My witch rules these waves!")],
        "Each raft rocks on its own beat and the wind turns. Wait for a calm, then knock them over."),
    62: ("Double Sluice", 7, L62, ["stone", "cyclone", "stone", "stone"], {"tide": TIDE}, [],
        "Smash the low sluice to flood the sheds. Flip the lever to open the upper sluice on the terrace."),
    63: ("Burning Bridge", 7, L63, ["fire", "fire", "stone", "stone"], {"wind": SQUALL}, [],
        "Fire runs along the timber bridge. Burn or cut a rope of the far bridge to tip its guards."),
    64: ("Frozen Stilts", 7, L64, ["fire", "quake", "stone", "stone"], {}, [
        T(), F("fortress", "ICE STILTS!"), E("captain"), S("captain", "That vault stands on ice. Warm it up!")],
        "Melt or shatter the ice pillars and the iron vault drops. Crystal shatters into its neighbours."),
    65: ("Lodestone", 7, L65, ["cyclone", "stone", "stone", "stone"], {"tide": TIDE}, [
        T(), F("@@magnet", "MAGNET!"), E("wizard", "catapult", "smoke"),
        S("wizard", "A lodestone! Flip that lever and it will rip their iron apart.")],
        "Hit the lever: the magnet tears the iron vault apart. Stones bounce off iron."),
    66: ("Upside Down", 7, L66, ["quake", "cyclone", "stone", "stone"], {}, [
        T(), F("@@gravity", "GRAVITY FIELD!"), E("wizard", "catapult", "smoke"),
        S("wizard", "Wake the rune and the keep floats up... then falls.")],
        "Uncover and hit the rune: the keep floats up, then crashes down. Finish what's left."),
    67: ("Portal Keep", 7, L67, ["bomb", "cyclone", "stone", "stone"], {"tide": TIDE}, [
        T(), F("@@portal", "PORTALS!"), E("wizard", "catapult", "smoke"),
        S("wizard", "Orange in, blue out. Through the ring and down into their keep!")],
        "The keep has an iron roof. Shoot into the orange ring: you come out of the blue one above the keep."),
    68: ("Bounce House", 7, L68, ["fire", "cyclone", "stone", "stone"], {}, [
        T(), F("@@bumper", "BOUNCE PAD!"), E("captain"), S("captain", "Bank a shot off the mushroom, over the iron wall!")],
        "Iron walls block straight shots. Bounce off the high mushroom into the courtyard."),
    69: ("Storm Vault", 7, L69, ["bomb", "cyclone", "stone", "stone"], {"tide": TIDE}, [],
        "Light all three lamps within 6 seconds: lever, plate (knock the stone down) and the rune."),
    70: ("Morwen's Barge", 7, L70, ["quake", "bomb", "fire", "stone"], {"tide": SWELL}, [
        T(), E("baron", "boss", "smoke"), S("baron", "My storm witch will hurl your shots back to the sky!"),
        F("@@gravity", "STORM WARD!"), E("wizard", "catapult", "smoke"),
        S("wizard", "Break the rune stone on the shore and her ward falls. The portal reaches her too!")],
        "Boss: the ward above the barge throws shots upward. Break the shore rune first, then the cores."),
    71: ("Armoured Bastion", 8, L71, ["bomb", "fire", "stone", "stone"], {}, [
        T(), E("captain"), S("captain", "The Iron Citadel. Everything's armoured."), F("weak", "HIDDEN KEGS!"),
        E("wizard", "catapult", "smoke"), S("wizard", "Those kegs hold up the crushers. Pop them!")],
        "Iron shrugs off stones. Blow the kegs at the foot of each keep: the crushers drop through the roofs."),
    72: ("Ever-Mending Wall", 8, L72, ["bomb", "cyclone", "stone", "stone"], {}, [
        T(), F("@@repair", "REPAIR CRYSTAL!"), E("wizard", "catapult", "smoke"),
        S("wizard", "That crystal mends their walls. Shatter it first, through its ring!")],
        "The crystal rebuilds broken blocks. Time a shot through its shield ring, then attack."),
    73: ("Prison Tower", 8, L73, ["cyclone", "fire", "stone", "stone"], {}, [
        T(), E("captive", "fortress", "smoke"), S("captive", "Two of us locked up! Plate and rope!"),
        F("captive:0", "RESCUE!"), F("captive:1", "RESCUE!")],
        "Knock the stone onto the plate to open the first cell; cut the rope to open the second."),
    74: ("Forge Trap", 8, L74, ["quake", "cyclone", "stone", "stone"], {}, [],
        "Push the cart off the rail hill onto the plate: the crusher drops through the iron keep."),
    75: ("The Iron Citadel", 8, L75, ["quake", "bomb", "fire", "stone"], {}, [
        T(), E("baron", "boss", "smoke"), S("baron", "You will never break MY citadel!"), M("baron", "laugh"),
        F("weak", "OPEN THE GATE"), F("@@repair", "STOP THE REPAIRS"), F("core", "BREAK THE CORES!"),
        E("wizard", "catapult", "smoke"), S("wizard", "Gate, crystal, cores, then the Baron himself!")],
        "Final boss: open the gate, shatter the repair crystal, break both cores and stop the engineers."),
})
