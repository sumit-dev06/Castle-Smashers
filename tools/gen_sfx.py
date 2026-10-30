#!/usr/bin/env python3
"""Synthesises placeholder sound effects and a music loop (owned by the project).

Output: assets/audio/sfx/<name>_<n>.wav (variants). Music: tools/gen_music.py, ambience: tools/gen_ambience.py
Run:    python3 tools/gen_sfx.py
"""
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter

import audio_dsp as D

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC = os.path.join(ROOT, "assets", "audio", "music")
rng = np.random.default_rng(7)

# Peak ceilings keep short synthetic transients comfortable on phone speakers. The RMS target
# provides a consistent starting point, while the peak ceiling preserves impact dynamics.
MASTERING = {
    "ui_tap": (-14.0, -25.0), "pop": (-12.0, -24.0),
    "star": (-9.0, -21.0), "win": (-7.0, -20.0), "lose": (-8.0, -21.0),
    "soldier_hit": (-10.0, -21.0), "soldier_ko": (-10.0, -21.0),
    "enemy_ko": (-10.0, -21.0), "enemy_laugh": (-12.0, -23.0),
    "arrow_shoot": (-11.0, -24.0), "arrow_hit": (-9.0, -22.0),
    "fire": (-10.0, -24.0), "wind": (-12.0, -25.0),
    "wood_hit": (-7.0, -20.0), "stone_hit": (-7.0, -20.0),
    "wood_break": (-6.0, -19.0), "stone_break": (-6.0, -19.0),
    "straw_break": (-10.0, -23.0), "launch": (-7.0, -21.0),
    "whoosh": (-11.0, -24.0), "slam": (-6.0, -19.0), "explosion": (-4.0, -17.0),
    "quake": (-5.0, -18.0), "weak_point": (-9.0, -22.0),
    "chain": (-11.0, -24.0), "gate_drop": (-6.0, -19.0),
    "hazard_hit": (-8.0, -21.0), "cage_break": (-7.0, -20.0),
    "rescue": (-8.0, -21.0), "splash": (-7.0, -20.0),
    "crystal_break": (-8.0, -21.0), "metal_hit": (-8.0, -21.0), "rope_snap": (-8.0, -22.0),
    "geyser": (-9.0, -22.0), "boss_roar": (-6.0, -19.0), "upgrade": (-9.0, -21.0),
    "ice_break": (-8.0, -21.0), "ice_hit": (-8.0, -21.0), "metal_bend": (-7.0, -20.0), "sizzle": (-12.0, -25.0),
    "rune_charge": (-11.0, -24.0), "rune_beam": (-7.0, -20.0),
    "coin_tink": (-13.0, -26.0), "gem_tink": (-13.0, -26.0), "purchase": (-8.0, -20.0),
    "chest_open": (-7.0, -20.0), "wheel_tick": (-15.0, -28.0), "anvil": (-8.0, -21.0),
    "lever": (-9.0, -22.0), "gears": (-11.0, -24.0), "trapdoor": (-7.0, -20.0),
    "switch_click": (-11.0, -24.0), "cannon": (-5.0, -18.0), "repair": (-10.0, -23.0),
    "swoosh_ui": (-15.0, -27.0), "reveal": (-8.0, -20.0),
    "combo": (-10.0, -22.0), "slowmo": (-8.0, -21.0), "slowmo_out": (-11.0, -24.0), "ui_back": (-14.0, -26.0),
    "tab": (-14.0, -27.0), "popup_open": (-13.0, -25.0), "popup_close": (-14.0, -26.0), "locked": (-12.0, -24.0),
    "deny": (-12.0, -24.0), "count_tick": (-16.0, -29.0), "toast": (-12.0, -24.0), "map_select": (-11.0, -23.0),
    "play_press": (-9.0, -21.0), "aim_grab": (-9.0, -21.0), "ability": (-11.0, -23.0),
    "ratchet": (-8.0, -20.0), "bell": (-6.0, -19.0), "creak": (-9.0, -21.0),
    "screen_whoosh": (-14.0, -26.0), "wallet_land": (-12.0, -24.0),
    "talk_hero": (-12.0, -23.0), "talk_enemy": (-12.0, -23.0), "talk_high": (-12.0, -23.0),
}

# Short room per sound family (decay s, wet): gives synthetic sounds a body instead of a dry click.
# UI stays nearly dry so it never smears; the realm reverb on the SFX bus adds the surroundings.
ROOM = {"ui": (0.18, 0.04), "voice": (0.3, 0.1), "impact": (0.45, 0.12), "big": (0.9, 0.16)}
UI_SOUNDS = {"ui_tap", "pop", "ui_back", "tab", "popup_open", "popup_close", "locked", "deny", "count_tick",
             "toast", "map_select", "swoosh_ui", "wheel_tick", "coin_tink", "gem_tink", "screen_whoosh",
             "wallet_land", "combo", "star", "purchase", "upgrade", "play_press"}
BIG_SOUNDS = {"bell", "explosion", "quake", "cannon", "boss_roar", "gate_drop", "slam", "reveal", "chest_open"}
VOICE_SOUNDS = {"talk_hero", "talk_enemy", "talk_high", "soldier_hit", "soldier_ko", "enemy_ko", "enemy_laugh"}


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.005, decay=0.2, curve=1.0):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4)) ** curve
    return a * d


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def filt(x, kind, freq, order=2):
    nyq = SR / 2
    if kind == "band":
        lo, hi = freq
        b, a = butter(order, [max(lo, 20) / nyq, min(hi, nyq * 0.95) / nyq], btype="band")
    else:
        b, a = butter(order, min(freq, nyq * 0.95) / nyq, btype=kind)
    return lfilter(b, a, x)


def sweep_filter(x, f0, f1, kind="low", chunks=40):
    out = np.zeros_like(x)
    n = len(x)
    edges = np.linspace(0, n, chunks + 1).astype(int)
    for i in range(chunks):
        f = f0 * (f1 / f0) ** (i / max(chunks - 1, 1))
        seg = x[max(0, edges[i] - 2000):edges[i + 1]]
        y = filt(seg, kind, f)
        out[edges[i]:edges[i + 1]] = y[-(edges[i + 1] - edges[i]):]
    return out


def sine(freq, dur, phase=0.0):
    t = t_axis(dur)
    if callable(freq):
        ph = 2 * np.pi * np.cumsum(freq(t)) / SR
        return np.sin(ph + phase)
    return np.sin(2 * np.pi * freq * t + phase)


def pad(x, dur):
    n = int(SR * dur)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, offset, total):
    out = np.zeros(int(SR * total))
    s = int(SR * offset)
    e = min(len(out), s + len(x))
    out[s:e] += x[:e - s]
    return out


def polish(name, x):
    """Smoothing chain shared by every sound: rumble cut, gentle top roll-off, short room, soft knee."""
    fam = "ui" if name in UI_SOUNDS else "big" if name in BIG_SOUNDS else "voice" if name in VOICE_SOUNDS else "impact"
    decay, wet = ROOM[fam]
    D.set_rate(SR, seed=len(name))
    x = filt(np.asarray(x, dtype=float), "high", 40)
    x = filt(x, "low", 9500 if fam == "ui" else 8500)
    x = D.tail_trim(D.reverb(x, decay, wet, 6000, 0.008), -62)
    return D.softclip(x / (np.max(np.abs(x)) or 1.0), 1.25)


def save(path, x, peak_db=-6.0, rms_db=-20.0):
    x = np.asarray(x, dtype=float)
    x -= np.mean(x)
    rms = np.sqrt(np.mean(x * x)) or 1.0
    x *= 10 ** (rms_db / 20.0) / rms
    ceiling = 10 ** (peak_db / 20.0)
    peak = np.max(np.abs(x)) or 1.0
    if peak > ceiling:
        x *= ceiling / peak
    fade = min(len(x) // 2, int(SR * 0.008))
    if fade > 0:
        ramp = np.sin(np.linspace(0.0, np.pi * 0.5, fade)) ** 2
        x[:fade] *= ramp
        x[-fade:] *= ramp[::-1]
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def sfx(name, variants, fn):
    peak_db, rms_db = MASTERING.get(name, (-8.0, -21.0))
    for i in range(variants):
        save(os.path.join(SFX, f"{name}_{i}.wav"), polish(name, fn(i)), peak_db, rms_db)


# ----------------------------------------------------------------------------- impacts








def straw_break(i):
    d = 0.45
    rustle = filt(noise(d), "band", (700, 5200)) * env(d, 0.018, 0.14)
    rustle *= 0.55 + 0.35 * np.abs(sine(17 + i * 4, d))
    return filt(rustle, "low", 4800)




# ----------------------------------------------------------------------------- catapult / flight
def creak(i):
    d = 0.35
    f0 = 85 + i * 15
    t = t_axis(d)
    saw = ((t * (f0 + 30 * np.sin(2 * np.pi * 3 * t))) % 1.0) * 2 - 1
    x = filt(saw * (0.6 + 0.4 * np.sin(2 * np.pi * 37 * t)), "band", (300, 2200))
    return x * env(d, 0.05, 0.25)






def slam(i):
    d = 0.5
    return mix(whoosh(1) * 0.5, at(stone_hit(0) * 1.2, 0.0, d))


def fire(i):
    d = 0.9
    roar = filt(noise(d), "band", (140, 1200)) * env(d, 0.025, 0.45)
    out = roar * 0.78
    for k in range(18):
        c = filt(noise(0.025), "band", (1200, 4800)) * env(0.025, 0.001, 0.006)
        out += at(c * rng.uniform(0.12, 0.38), rng.uniform(0.02, d - 0.04), d)
    whomp = sweep_filter(noise(d), 260, 1600, "low") * env(d, 0.012, 0.16)
    return filt(mix(out, whomp), "low", 5200)


def wind(i):
    d = 1.6
    t = t_axis(d)
    x = sweep_filter(noise(d), 300, 1400, "band" if False else "low") * (0.5 + 0.5 * np.sin(2 * np.pi * 2.2 * t))
    whistle = sine(lambda t: 700 + 250 * np.sin(2 * np.pi * 1.3 * t), d) * 0.08
    return (x + whistle) * np.sin(np.pi * t / d)


# ----------------------------------------------------------------------------- castle mechanics

def quake(i):
    d = 1.45
    rumble = sweep_filter(noise(d), 900, 90, "low") * env(d, 0.01, 0.55) * 0.9
    sub = sine(lambda t: 58 * np.exp(-t * 1.2) + 30, d) * env(d, 0.006, 0.5) * 1.25
    cracks = np.zeros(int(SR * d))
    for k in range(7):
        chip = filt(noise(0.09), "band", (350, 2600)) * env(0.09, 0.001, 0.018)
        cracks += at(chip * rng.uniform(0.18, 0.42), 0.1 + k * 0.11 + rng.uniform(0, 0.04), d)
    return filt(mix(rumble, sub, cracks), "low", 4500)


def weak_point(i):
    d = 0.55
    crack = filt(noise(0.11), "band", (450, 3200)) * env(0.11, 0.001, 0.018)
    cue = bell(620 + i * 35, d, 0.22) * 0.24
    return filt(mix(crack, cue), "low", 5200)


def chain(i):
    d = 0.85
    out = np.zeros(int(SR * d))
    for k in range(6):
        ring = bell(420 + 75 * ((k + i) % 3), 0.22, 0.08)
        out += at(ring * (0.24 - k * 0.018), 0.04 + k * 0.11, d)
    return filt(out, "low", 5600)


def gate_drop(i):
    d = 0.9
    wood = pad(wood_hit(i % 3), d) * 0.65
    thud = sine(lambda t: 82 * np.exp(-t * 8) + 40, d) * env(d, 0.003, 0.2)
    grit = filt(noise(d), "band", (220, 1800)) * env(d, 0.01, 0.16) * 0.25
    return filt(mix(wood, thud, grit), "low", 4200)


def hazard_hit(i):
    d = 0.45
    clang = bell(310 + i * 35, d, 0.13) * 0.45
    hit = filt(noise(0.08), "band", (600, 3800)) * env(0.08, 0.001, 0.015)
    return filt(mix(clang, hit), "low", 5200)


def cage_break(i):
    d = 0.85
    timber = pad(wood_break(i % 3), d) * 0.55
    metal = pad(chain(i), d) * 0.45
    return filt(mix(timber, metal), "low", 5000)


def rescue(i):
    d = 1.15
    out = np.zeros(int(SR * d))
    for f, off in [(523, 0.0), (659, 0.16), (784, 0.32)]:
        out += at(bell(f, 0.7, 0.25) * 0.45, off, d)
    return filt(out, "low", 6000)


def splash(i):
    """Body falling into the water gap: low plop, noisy spray, then trickling droplets."""
    d = 0.9
    plop = sine(lambda t: (210 + 40 * i) * np.exp(-t * 9) + 70, d) * env(d, 0.002, 0.07) * 0.9
    spray = sweep_filter(noise(d), 4500, 700, "low") * env(d, 0.006, 0.2) * 0.8
    out = mix(plop, spray)
    for k in range(10):
        drop = sine(rng.uniform(900, 2200), 0.04) * env(0.04, 0.001, 0.012)
        out += at(drop * rng.uniform(0.08, 0.22), rng.uniform(0.15, d - 0.05), d)
    return filt(out, "low", 7000)


def crystal_break(i):
    """Glassy shatter: bright inharmonic pings over a noisy crack."""
    d = 0.9
    out = filt(noise(0.12), "high", 3000) * env(0.12, 0.0005, 0.03)
    out = pad(out, d)
    for k in range(9):
        f0 = rng.uniform(2200, 5200)
        out += at(sine(f0, 0.35) * env(0.35, 0.001, 0.09) * rng.uniform(0.15, 0.4), rng.uniform(0.0, 0.35), d)
    return filt(out, "high", 500)


def metal_hit(i):
    d = 0.7
    clang = sum(sine(f * (1 + 0.04 * i), d) * env(d, 0.001, 0.25 / (1 + k)) * g
                for k, (f, g) in enumerate([(420, 1.0), (1130, 0.6), (2350, 0.3), (3900, 0.15)]))
    return mix(clang * 0.6, stone_hit(i) * 0.6)


def rope_snap(i):
    d = 0.45
    crack = filt(noise(0.03), "band", (1500, 7000)) * env(0.03, 0.0003, 0.008)
    twang = sine(lambda t: (260 + 50 * i) * np.exp(-t * 4) + 90, d) * env(d, 0.001, 0.12) * 0.6
    return mix(crack, at(twang, 0.01, d), at(whoosh(0) * 0.3, 0.02, d))


def geyser(i):
    d = 1.3
    t = t_axis(d)
    hiss = filt(noise(d), "band", (600, 5000)) * np.sin(np.pi * t / d) ** 0.7
    rumble = filt(noise(d), "low", 220) * env(d, 0.05, 0.6)
    return mix(hiss * 0.7, rumble * 0.8)


def boss_roar(i):
    d = 1.4
    t = t_axis(d)
    growl = sine(lambda t: 85 + 25 * np.sin(2 * np.pi * 7 * t) + 40 * np.exp(-t * 2), d)
    growl = filt(growl + 0.4 * filt(noise(d), "band", (200, 1400)), "low", 1800)
    return growl * env(d, 0.06, 0.6) + at(slam(0) * 0.5, 0.0, d)


def upgrade(i):
    d = 1.0
    out = np.zeros(int(SR * d))
    for f, off in [(523, 0.0), (659, 0.09), (784, 0.18), (1047, 0.27)]:
        out += at(bell(f, 0.6, 0.3) * 0.4, off, d)
    return filt(out, "low", 7000)


def ice_break(i):
    """Ice shatter: a hard crack, falling glassy tinkles and a crunchy slide."""
    d = 1.0
    out = filt(noise(0.06), "band", (1800, 9000)) * env(0.06, 0.0003, 0.015) * 1.2
    out = pad(out, d)
    out += at(filt(noise(0.4), "band", (2500, 8000)) * env(0.4, 0.01, 0.12) * 0.35, 0.02, d)
    for k in range(14):
        f0 = rng.uniform(3000, 7500)
        out += at(sine(f0, 0.12) * env(0.12, 0.0005, 0.03) * rng.uniform(0.1, 0.3), rng.uniform(0.03, 0.6), d)
    return filt(out, "high", 900)


def ice_hit(i):
    d = 0.35
    knock = filt(noise(0.04), "band", (900, 4000)) * env(0.04, 0.0005, 0.012)
    ring = sine(2600 + 300 * i, d) * env(d, 0.001, 0.06) * 0.25
    return mix(pad(knock, d), ring)


def metal_bend(i):
    """Iron giving way: a deep groan sliding down, then a clank."""
    d = 0.9
    groan = sine(lambda t: 220 * np.exp(-t * 1.4) + 70 + 12 * np.sin(2 * np.pi * 23 * t), d)
    groan = filt(groan + 0.3 * filt(noise(d), "band", (300, 1500)), "low", 2200) * env(d, 0.02, 0.4)
    return mix(groan * 0.8, at(metal_hit(i) * 0.7, 0.35, d))


def sizzle(i):
    """Red-hot iron or melting ice: hissing steam."""
    d = 0.8
    t = t_axis(d)
    hiss = filt(noise(d), "band", (2500, 9000)) * env(d, 0.01, 0.35)
    crackle = filt(noise(d), "high", 6000) * (np.random.default_rng(i).random(len(t)) > 0.985) * 0.6
    return mix(hiss * 0.7, crackle)


def rune_charge(i):
    d = 0.4
    tone = sine(lambda t: 400 + 1600 * t / d, d) * env(d, 0.05, 0.3) * 0.5
    shimmer = sine(lambda t: 2400 + 2400 * t / d, d) * env(d, 0.1, 0.3) * 0.15
    return mix(tone, shimmer)


def rune_beam(i):
    """Crystal beam: a bright zap with a falling hum tail."""
    d = 0.9
    zap = sine(lambda t: 1800 * np.exp(-t * 6) + 300, d) * env(d, 0.001, 0.35) * 0.6
    buzz = filt(noise(d), "band", (800, 5000)) * env(d, 0.002, 0.2) * 0.35
    hum = sine(lambda t: 110 + 8 * np.sin(2 * np.pi * 30 * t), d) * env(d, 0.01, 0.5) * 0.4
    return mix(zap, buzz, hum)


# ----------------------------------------------------------------------------- arrows
def pluck(freq, dur, damp=0.996):
    n = int(SR * dur)
    period = int(SR / freq)
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for k in range(n):
        v = buf[k % period]
        out[k] = v
        buf[k % period] = damp * 0.5 * (v + buf[(k + 1) % period])
    return out


def arrow_shoot(i):
    d = 0.4
    twang = pluck(150 + 18 * i, d, 0.9945) * env(d, 0.003, 0.17)
    air = filt(whoosh(0), "low", 4200) * 0.22
    return filt(mix(twang, at(air, 0.025, d)), "low", 4600)


def arrow_hit(i):
    d = 0.25
    thunk = sine(lambda t: 260 * np.exp(-t * 20) + 120, d) * env(d, 0.0008, 0.035)
    wobble = sine(320 + 30 * i, d) * env(d, 0.002, 0.08) * (0.5 + 0.5 * np.sin(2 * np.pi * 28 * t_axis(d))) * 0.4
    return mix(thunk, wobble, filt(noise(d), "band", (1000, 5000)) * env(d, 0.0005, 0.01) * 0.5)


# ----------------------------------------------------------------------------- voices (comic grunts)
def vowel(f0_fn, dur, formants, breath=0.08):
    t = t_axis(dur)
    ph = np.cumsum(f0_fn(t)) / SR
    pulse = ((ph % 1.0) < 0.5).astype(float) * 2 - 1
    src = filt(pulse, "low", 3000) + noise(dur) * breath
    out = np.zeros_like(t)
    for (f, bw, g) in formants:
        out += filt(src, "band", (f - bw, f + bw)) * g
    return out


def oof(base, i, dur=0.45):
    f0 = lambda t: base * (1.25 - 0.5 * t / dur) * (1 + 0.03 * np.sin(2 * np.pi * 7 * t))
    v = vowel(f0, dur, [(500, 120, 1.0), (900, 150, 0.6), (2400, 200, 0.15)])
    return v * env(dur, 0.02, dur * 0.45)


def soldier_hit(i):
    return oof(210 + 20 * i, i, 0.3)


def soldier_ko(i):
    return oof(190, i, 0.6)


def enemy_ko(i):
    d = 0.7
    f0 = lambda t: (330 + 30 * i) * (1.3 - 0.7 * t / d)
    return vowel(f0, d, [(700, 140, 1.0), (1150, 160, 0.6), (2600, 200, 0.2)]) * env(d, 0.01, 0.3)


def enemy_laugh(i):
    d = 0.8
    out = np.zeros(int(SR * d))
    for k in range(4):
        hd = 0.12
        f0 = lambda t, k=k: (300 + 15 * i) * (1.05 - 0.15 * k / 4)
        h = vowel(f0, hd, [(750, 130, 1.0), (1200, 150, 0.6)], 0.25) * env(hd, 0.005, 0.05)
        out += at(h, k * 0.16, d)
    return out


# ----------------------------------------------------------------------------- ui + jingles
def bell(freq, dur, decay=0.4):
    return sum(sine(freq * h, dur) * env(dur, 0.002, decay / (1 + k)) * g
               for k, (h, g) in enumerate([(1, 1.0), (2.01, 0.5), (3.0, 0.25), (4.2, 0.12)]))








def brass(freq, dur):
    t = t_axis(dur)
    saw = sum(np.sin(2 * np.pi * freq * h * t) / h for h in range(1, 9))
    e = env(dur, 0.02, dur * 0.6)
    return filt(saw, "low", 1800 + 1500 * float(np.mean(e))) * e


def win(i):
    seq = [(523, 0.0, 0.18), (659, 0.15, 0.18), (784, 0.3, 0.18), (1047, 0.45, 0.6)]
    d = 1.3
    out = np.zeros(int(SR * d))
    for f, o, l in seq:
        out += at(brass(f, l) + 0.4 * bell(f * 2, l, 0.3), o, d)
        out += at(brass(f * 0.5, l) * 0.4, o, d)
    return out


def lose(i):
    seq = [(392, 0.0, 0.32), (370, 0.33, 0.32), (349, 0.66, 0.32), (330, 0.99, 0.9)]
    d = 2.0
    out = np.zeros(int(SR * d))
    for f, o, l in seq:
        tone = brass(f, l) * (1 + 0.3 * np.sin(2 * np.pi * 5 * t_axis(l)))
        out += at(tone, o, d)
    return out


# ----------------------------------------------------------------------------- meta UI + mechanisms


def gem_tink(i):
    d = 0.45
    shimmer = sine(lambda t: 2637 + 300 * np.sin(2 * np.pi * 18 * t), d) * env(d, 0.002, 0.15) * 0.3
    return mix(bell(1760 + 90 * i, d, 0.2) * 0.5, shimmer)


def purchase(i):
    """Cash-register sparkle + rising arpeggio."""
    d = 1.1
    out = at(filt(noise(0.05), "band", (2000, 7000)) * env(0.05, 0.0005, 0.02) * 0.6, 0.0, d)
    for f, off in [(784, 0.02), (988, 0.1), (1175, 0.18), (1568, 0.26)]:
        out += at(bell(f, 0.7, 0.28) * 0.35, off, d)
    out += at(brass(523, 0.5) * 0.25, 0.26, d)
    return filt(out, "low", 9000)


def chest_open(i):
    """Wooden creak, latch clack, then a magical whoosh-chord."""
    d = 1.4
    out = at(creak(1) * 0.5, 0.0, d)
    out += at(filt(noise(0.04), "band", (800, 3000)) * env(0.04, 0.0005, 0.015), 0.32, d)
    sw = filt(noise(0.8), "band", (1500, 6000)) * env(0.8, 0.15, 0.4) * 0.3
    out += at(sw, 0.35, d)
    for f in [523, 659, 784, 1047]:
        out += at(bell(f, 0.9, 0.5) * 0.25, 0.4, d)
    return out


def wheel_tick(i):
    d = 0.06
    return filt(noise(d), "band", (1500, 5000)) * env(d, 0.0003, 0.01) + sine(1100, d) * env(d, 0.0005, 0.012) * 0.3


def anvil(i):
    d = 0.9
    ring = bell(880 + 40 * i, d, 0.35) * 0.5 + bell(1320, d, 0.2) * 0.3
    clank = filt(noise(0.03), "band", (1000, 6000)) * env(0.03, 0.0002, 0.01)
    return mix(pad(clank, d), ring)


def lever(i):
    d = 0.5
    ratchet = np.zeros(int(SR * d))
    for k in range(5):
        ratchet += at(filt(noise(0.02), "band", (1200, 4000)) * env(0.02, 0.0002, 0.006) * 0.5, k * 0.045, d)
    thunk = sine(lambda t: 140 * np.exp(-t * 20) + 70, 0.2) * env(0.2, 0.001, 0.06)
    return mix(ratchet, at(thunk, 0.25, d))


def gears(i):
    d = 1.2
    t = t_axis(d)
    teeth = filt(noise(d), "band", (400, 2500)) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (16 + 4 * i) * t)))
    hum = sine(lambda t: 95 + 5 * np.sin(2 * np.pi * 3 * t), d) * 0.3
    return (teeth * 0.4 + hum) * env(d, 0.08, 0.6)


def trapdoor(i):
    d = 0.8
    latch = filt(noise(0.03), "band", (1000, 5000)) * env(0.03, 0.0003, 0.01)
    swing = creak(i) * 0.4
    bang = slam(0) * 0.8
    return mix(pad(latch, d), at(swing, 0.03, d), at(bang, 0.3, d))


def switch_click(i):
    d = 0.3
    click = filt(noise(0.015), "high", 3000) * env(0.015, 0.0002, 0.004)
    glow = sine(lambda t: 660 + 660 * t / d, d) * env(d, 0.01, 0.12) * 0.3
    return mix(pad(click, d), glow)


def cannon(i):
    d = 1.3
    boom = sine(lambda t: 110 * np.exp(-t * 6) + 40, d) * env(d, 0.001, 0.4)
    blast = filt(noise(d), "low", 1800 - 300 * i) * env(d, 0.001, 0.25) * 0.8
    return mix(boom, blast)


def repair(i):
    d = 0.35
    tap = bell(1400 + 100 * i, d, 0.08) * 0.4
    knock = filt(noise(0.03), "band", (500, 2500)) * env(0.03, 0.0003, 0.01)
    return mix(pad(knock, d), tap)


def swoosh_ui(i):
    d = 0.25
    return filt(sweep_filter(noise(d), 600, 4000, "low"), "high", 400) * env(d, 0.04, 0.1) * 0.5


def reveal(i):
    d = 2.0
    out = filt(sweep_filter(noise(d), 300, 6000, "low"), "high", 200) * env(d, 0.6, 0.6) * 0.25
    for f, off in [(392, 0.6), (523, 0.6), (659, 0.6), (784, 0.75), (1047, 0.9)]:
        out += at(brass(f, 0.9) * 0.2 + bell(f * 2, 0.9, 0.5) * 0.15, off, d)
    return out


# ----------------------------------------------------------------------------- music


# ----------------------------------------------------------------------------- v2 core sounds
# Rebuilt for smoothness: rounded attacks (1-3 ms), a low "body" layer under every impact,
# filtered noise instead of raw white noise, and a short room on everything (see save()).
def _knock(f0, d, q=1.0, i=0):
    """Hollow wooden knock: a few resonant modes with soft mallet contact."""
    modes = [(1.0, 0.11), (2.31, 0.07), (3.9, 0.045), (5.6, 0.03), (0.52, 0.16)]
    t = t_axis(d)
    out = np.zeros_like(t)
    for k, (r, dec) in enumerate(modes):
        out += sine(f0 * r * (1 + 0.01 * i), d) * np.exp(-t / (dec * q)) / (1 + 0.7 * k)
    contact = filt(D.pink(0.012), "band", (500, 3200)) * env(0.012, 0.001, 0.004) * 0.5
    return mix(out * env(d, 0.0015, 1e4), contact)


def wood_hit(i):
    d = 0.4
    body = _knock(165 + 22 * i, d, 1.0, i)
    thump = sine(lambda t: 95 * np.exp(-t * 18) + 60, d) * env(d, 0.002, 0.06) * 0.6
    return filt(mix(body, thump), "low", 6500)


def wood_break(i):
    d = 0.9
    out = np.zeros(int(SR * d))
    out += pad(wood_hit(i) * 0.9, d)
    for k in range(10 + 2 * i):
        off = 0.01 + rng.uniform(0, 0.32) * (k / 12)
        f = rng.uniform(900, 2400)
        splinter = filt(D.pink(0.05), "band", (f, f * 2.8)) * env(0.05, 0.001, 0.012)
        out += at(splinter * rng.uniform(0.25, 0.7), off, d)
    for k in range(3):  # pieces tumbling after the break
        out += at(_knock(rng.uniform(220, 380), 0.2, 0.6) * rng.uniform(0.15, 0.3), 0.18 + k * rng.uniform(0.08, 0.14), d)
    groan = filt(sine(lambda t: 120 - 50 * t, d), "low", 800) * env(d, 0.01, 0.12) * 0.35
    return filt(mix(out, groan), "low", 6500)


def stone_hit(i):
    d = 0.5
    thud = sine(lambda t: 70 + 70 * np.exp(-t * 28) + 8 * i, d) * env(d, 0.0015, 0.09)
    body = filt(D.pink(d), "band", (180, 900)) * env(d, 0.002, 0.05) * 0.6
    grit = filt(D.pink(d), "band", (1400, 5500)) * env(d, 0.001, 0.025) * 0.25
    return filt(mix(thud, body, grit), "low", 6000)


def stone_break(i):
    d = 1.1
    out = pad(stone_hit(i) * 1.0, d)
    rubble = filt(D.pink(d), "band", (200, 2200)) * env(d, 0.004, 0.25) * 0.45
    out = mix(out, rubble)
    for k in range(14):
        f = rng.uniform(1200, 4200)
        chip = filt(D.pink(0.05), "band", (f, f * 1.8)) * env(0.05, 0.001, 0.01)
        out += at(chip * rng.uniform(0.15, 0.45), rng.uniform(0.02, 0.7) ** 1.4, d)
    for k in range(4):
        out += at(stone_hit(k % 3)[: int(SR * 0.25)] * rng.uniform(0.12, 0.25), 0.2 + k * rng.uniform(0.1, 0.16), d)
    return filt(out, "low", 6000)


def explosion(i):
    d = 2.2
    t = t_axis(d)
    sub = sine(lambda t: 38 + 60 * np.exp(-t * 7), d) * env(d, 0.003, 0.45) * 1.3
    boom = D.sweep_lp(D.pink(d), 2600, 110) * env(d, 0.004, 0.5)
    crack = filt(D.pink(0.08), "band", (700, 5000)) * env(0.08, 0.001, 0.02) * 0.9
    debris = np.zeros_like(t)
    for k in range(18):
        f = rng.uniform(800, 3500)
        c = filt(D.pink(0.04), "band", (f, f * 2)) * env(0.04, 0.001, 0.01)
        debris += at(c * rng.uniform(0.05, 0.2), 0.15 + rng.uniform(0, 1.0) ** 1.5, d)
    x = mix(sub, boom, crack, debris)
    return D.softclip(filt(x, "low", 7000) * 1.2, 1.4)


def launch(i):
    d = 0.9
    thunk = mix(_knock(110 + 15 * i, 0.4, 1.4) * 0.8, sine(lambda t: 62 + 50 * np.exp(-t * 20), 0.4) * env(0.4, 0.002, 0.08))
    twang = D.pluck(98 + 8 * i, 0.5, 0.35, 0.18, 0.25) * 0.35
    air = whoosh(1) * 0.7
    return filt(mix(thunk, at(twang, 0.005, d), at(air, 0.03, d)), "low", 7000)


def whoosh(i):
    d = 0.55
    t = t_axis(d)
    shape = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2.2
    x = D.sweep_lp(D.pink(d), 500 + 200 * i, 3200) * shape
    x += filt(D.pink(d), "band", (250, 900)) * shape * 0.5
    return filt(x, "high", 150)


def ui_tap(i):
    """Soft wooden button: a short knock plus a faint pitched tick, no harsh click."""
    d = 0.14
    knock = _knock(520, d, 0.25)
    tone = sine(1250, d) * env(d, 0.001, 0.025) * 0.25
    return filt(mix(knock, tone), "low", 6000)


def pop(i):
    d = 0.2
    bubble = sine(lambda t: 280 + 900 * (t / d) ** 0.6, d) * env(d, 0.003, 0.045)
    return filt(bubble, "low", 5000)


def star(i):
    base = [784, 988, 1175][i % 3]
    d = 1.2
    chord = D.bell(base, d, 0.9, 0.5) * 0.6 + D.bell(base * 1.5, d, 0.6, 0.4) * 0.25
    sparkle = np.zeros(int(SR * d))
    for k in range(5):
        sparkle += at(D.bell(base * 2 * (1 + 0.12 * k), 0.4, 0.15, 0.3) * 0.08, 0.04 + k * 0.035, d)
    return mix(chord, sparkle)


def coin_tink(i):
    d = 0.45
    a = D.bell(1976 + 90 * i, d, 0.18, 0.3) * 0.5
    b = D.bell(2637 + 110 * i, d, 0.14, 0.3) * 0.35
    return filt(mix(a, at(b, 0.045, d)), "high", 700)


# ----------------------------------------------------------------------------- v2 new action sounds
def combo(i):
    """Chain-counter blip: Sound raises the pitch per step, so this is one clean bright note."""
    d = 0.35
    return mix(D.bell(880, d, 0.22, 0.4) * 0.5, D.pluck(1760, d, 0.7, 0.12) * 0.3)


def slowmo(i):
    d = 1.0
    t = t_axis(d)
    x = D.sweep_lp(D.pink(d), 4000, 250) * env(d, 0.02, 0.5)
    sub = sine(lambda t: 160 * np.exp(-t * 2.5) + 45, d) * env(d, 0.01, 0.4) * 0.6
    return mix(x * 0.6, sub)


def slowmo_out(i):
    d = 0.6
    t = t_axis(d)
    x = D.sweep_lp(D.pink(d), 250, 5000) * np.sin(np.pi * t / d) ** 2
    return x * 0.6


def ui_back(i):
    d = 0.16
    return filt(mix(_knock(400, d, 0.25), sine(900, d) * env(d, 0.001, 0.03) * 0.2), "low", 5000)


def tab(i):
    d = 0.12
    return filt(mix(_knock(700, d, 0.2), filt(D.pink(0.03), "band", (2000, 6000)) * env(0.03, 0.001, 0.006) * 0.15), "low", 7000)


def popup_open(i):
    d = 0.4
    t = t_axis(d)
    air = D.sweep_lp(D.pink(d), 600, 4500) * np.sin(np.pi * t / d) ** 2 * 0.35
    chime = at(D.bell(1047, 0.3, 0.2, 0.3) * 0.25, 0.12, d)
    return mix(air, chime)


def popup_close(i):
    d = 0.3
    t = t_axis(d)
    return D.sweep_lp(D.pink(d), 4000, 500) * np.sin(np.pi * t / d) ** 2 * 0.4


def locked(i):
    d = 0.3
    thud = _knock(180, d, 0.4)
    rattle = at(_knock(260, 0.12, 0.2) * 0.4, 0.07, d)
    return filt(mix(thud, rattle), "low", 3500)


def deny(i):
    d = 0.35
    a = D.reed(196, 0.14, 0.6, 0.4)
    b = D.reed(185, 0.18, 0.6, 0.4)
    return filt(mix(a, at(b, 0.15, d)), "low", 3000)


def count_tick(i):
    d = 0.05
    return mix(sine(2200, d) * env(d, 0.0008, 0.008) * 0.6, filt(D.pink(d), "band", (3000, 7000)) * env(d, 0.0005, 0.004) * 0.2)


def toast(i):
    d = 0.6
    return mix(D.bell(1319, d, 0.3, 0.3) * 0.4, at(D.bell(1760, d, 0.3, 0.3) * 0.3, 0.08, d))


def map_select(i):
    d = 0.5
    out = _knock(300, d, 0.6) * 0.6
    for k, f in enumerate((659, 988)):
        out = mix(out, at(D.pluck(f, 0.4, 0.6, 0.25) * 0.35, 0.03 + k * 0.06, d))
    return out


def play_press(i):
    """The big PLAY plank: a deep wooden thump, a drum and a rising sparkle."""
    d = 0.9
    out = mix(_knock(140, d, 1.2), D.kick(0.5, 110, 45, 0.6))
    for k, f in enumerate((523, 659, 784, 1047)):
        out = mix(out, at(D.bell(f, 0.6, 0.35, 0.4) * 0.15, 0.05 + k * 0.05, d))
    return out


def aim_grab(i):
    d = 0.25
    rope = filt(D.pink(d), "band", (300, 1500)) * env(d, 0.01, 0.06) * 0.5
    return mix(rope, _knock(240, d, 0.3) * 0.5)


def bell_hit(i):
    """Big bronze bell struck: a low inharmonic bell over a hard metal knock."""
    d = 2.4
    f0 = 196 * (1 + 0.06 * i)
    tone = mix(D.bell(f0, d, 2.0, 0.55) * 0.8, D.bell(f0 * 2.01, d * 0.6, 1.1, 0.5) * 0.35, D.bell(f0 * 2.76, d * 0.4, 0.7, 0.6) * 0.2)
    knock = _knock(420, 0.2, 0.25) * 0.5
    return mix(tone, knock)


def ratchet(i):
    """One tooth of the catapult's winch ratchet: a short, dry wooden click with a tiny metal pawl."""
    d = 0.12
    click = _knock(520 + 60 * i, d, 0.18, i) * 0.9
    pawl = filt(noise(0.02), "band", (2500, 6500)) * env(0.02, 0.0005, 0.004) * 0.35
    return mix(click, pawl)


def stretch_loop():
    """Seamless 1.2 s loop: twisted rope fibres under tension (stick-slip crackle) over a low wooden
    groan. Played continuously while aiming; the game raises its pitch and volume with the pull."""
    d, loop = 1.6, 1.2
    t = t_axis(d)
    D.set_rate(SR, seed=31)
    groan_f = 72 + 6 * np.sin(2 * np.pi * t / loop * 2)
    saw = ((np.cumsum(groan_f) / SR) % 1.0) * 2 - 1
    groan = filt(saw, "band", (180, 1100)) * (0.55 + 0.45 * np.abs(np.sin(2 * np.pi * 9.0 * t)))
    fibres = filt(D.pink(d), "band", (900, 4200)) * 0.5
    slips = np.zeros_like(t)
    for k in range(int(d * 34)):
        s = int(SR * (k / 34.0 + rng.uniform(0, 0.012)))
        g = rng.uniform(0.25, 1.0)
        burst = filt(noise(0.008), "band", (1200, 5200)) * env(0.008, 0.0004, 0.002) * g
        slips[s:s + len(burst)] += burst[: len(slips) - s]
    x = mix(groan * 0.55, fibres * 0.35, slips * 0.8)
    x = filt(filt(x, "high", 90), "low", 7500)
    return D.loop_crossfade(x, int(SR * loop), 0.35)


def ability(i):
    """Hero power trigger: a bright magical swell under the hero's own effect sound."""
    d = 0.6
    t = t_axis(d)
    swell = D.sweep_lp(D.pink(d), 800, 7000) * np.sin(np.pi * t / d) ** 2 * 0.25
    tones = sum(at(D.bell(f, 0.5, 0.25, 0.4) * 0.12, 0.02 * k, d) for k, f in enumerate((784, 1175, 1568)))
    return mix(swell, tones)


def screen_whoosh(i):
    d = 0.45
    t = t_axis(d)
    return filt(D.sweep_lp(D.pink(d), 400, 3000) * np.sin(np.pi * t / d) ** 2.5, "high", 200) * 0.5


def wallet_land(i):
    d = 0.5
    out = np.zeros(int(SR * d))
    for k in range(4):
        out += at(D.bell(rng.uniform(1800, 2900), 0.3, 0.12, 0.3) * rng.uniform(0.15, 0.3), k * 0.03, d)
    return mix(out, _knock(600, 0.2, 0.2) * 0.3)


def _babble(f0, i, formant_sets, syll=4, rate=0.085):
    """Gibberish cartoon voice: short voiced syllables with moving formants (no real words)."""
    r = np.random.default_rng(500 + i + int(f0))
    d = syll * rate + 0.15
    out = np.zeros(int(SR * d))
    for k in range(syll):
        ln = rate * r.uniform(0.8, 1.2)
        fs = formant_sets[r.integers(0, len(formant_sets))]
        f = f0 * r.uniform(0.9, 1.15) * (1.08 if k == syll - 1 and r.random() > 0.5 else 1.0)
        v = vowel(lambda t, f=f, ln=ln: f * (1 + 0.08 * np.sin(np.pi * t / ln)), ln, fs, 0.03)
        out += at(v * D.env(ln, 0.01, 1e4, 1.0, ln * 0.4), k * rate, d)
    return filt(out, "low", 4500)


VOWELS = [[(700, 120, 1.0), (1200, 150, 0.5)], [(400, 100, 1.0), (2000, 200, 0.35)],
          [(550, 110, 1.0), (900, 140, 0.6)], [(300, 90, 1.0), (2300, 200, 0.3)]]


def talk_hero(i):
    return _babble(240 + 25 * i, i, VOWELS, 3 + i % 3)


def talk_enemy(i):
    return _babble(170 + 20 * i, i, VOWELS, 3 + i % 2, 0.1)


def talk_high(i):
    return _babble(380 + 30 * i, i, VOWELS, 4, 0.07)


SOUNDS = [
    ("wood_hit", 3, wood_hit), ("wood_break", 3, wood_break), ("stone_hit", 3, stone_hit),
    ("stone_break", 2, stone_break), ("straw_break", 2, straw_break), ("explosion", 2, explosion),
    ("creak", 3, creak), ("launch", 2, launch), ("whoosh", 2, whoosh), ("slam", 1, slam),
    ("fire", 2, fire), ("wind", 1, wind), ("arrow_shoot", 3, arrow_shoot), ("arrow_hit", 3, arrow_hit),
    ("soldier_hit", 3, soldier_hit), ("soldier_ko", 2, soldier_ko), ("enemy_ko", 3, enemy_ko),
    ("enemy_laugh", 2, enemy_laugh), ("ui_tap", 1, ui_tap), ("pop", 1, pop), ("star", 3, star),
    ("win", 1, win), ("lose", 1, lose), ("quake", 2, quake),
    ("weak_point", 2, weak_point), ("chain", 3, chain), ("gate_drop", 2, gate_drop),
    ("hazard_hit", 2, hazard_hit), ("cage_break", 2, cage_break), ("rescue", 1, rescue),
    ("splash", 3, splash), ("crystal_break", 3, crystal_break), ("metal_hit", 3, metal_hit),
    ("rope_snap", 2, rope_snap), ("geyser", 2, geyser), ("boss_roar", 1, boss_roar), ("upgrade", 1, upgrade),
    ("ice_break", 3, ice_break), ("ice_hit", 3, ice_hit), ("metal_bend", 2, metal_bend), ("sizzle", 2, sizzle),
    ("rune_charge", 1, rune_charge), ("rune_beam", 2, rune_beam),
    ("coin_tink", 3, coin_tink), ("gem_tink", 2, gem_tink), ("purchase", 1, purchase),
    ("chest_open", 1, chest_open), ("wheel_tick", 1, wheel_tick), ("anvil", 2, anvil),
    ("lever", 1, lever), ("gears", 2, gears), ("trapdoor", 2, trapdoor),
    ("switch_click", 1, switch_click), ("cannon", 2, cannon), ("repair", 3, repair),
    ("swoosh_ui", 2, swoosh_ui), ("reveal", 1, reveal),
    ("combo", 1, combo), ("slowmo", 1, slowmo), ("slowmo_out", 1, slowmo_out), ("ui_back", 1, ui_back),
    ("tab", 1, tab), ("popup_open", 1, popup_open), ("popup_close", 1, popup_close), ("locked", 1, locked),
    ("deny", 1, deny), ("count_tick", 1, count_tick), ("toast", 1, toast), ("map_select", 1, map_select),
    ("play_press", 1, play_press), ("aim_grab", 2, aim_grab), ("ability", 2, ability), ("ratchet", 3, ratchet), ("bell", 2, bell_hit),
    ("screen_whoosh", 2, screen_whoosh), ("wallet_land", 2, wallet_land),
    ("talk_hero", 4, talk_hero), ("talk_enemy", 4, talk_enemy), ("talk_high", 3, talk_high),
]

if __name__ == "__main__":
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(MUSIC, exist_ok=True)
    for name, n, fn in SOUNDS:
        sfx(name, n, fn)
    # Looping sounds skip polish() (its room tail would break the loop) and carry a WAV loop point.
    D.write_wav(os.path.join(SFX, "stretch_loop.wav"), D.master(stretch_loop(), -19.0, -7.0), loop=True, sr=SR)
    print("sfx:", len([f for f in os.listdir(SFX) if f.endswith(".wav")]), "files (music: tools/gen_music.py)")
