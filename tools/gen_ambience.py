#!/usr/bin/env python3
"""Synthesises the per-realm ambience (owned by the project, no recordings).

Beds (seamless loops):   assets/audio/ambience/bed_<realm>.wav
Details (one-shots):     assets/audio/ambience/amb_<name>_<n>.wav
`Sound` (src/autoload/sound.gd) crossfades beds per realm and scatters the details at random times,
pitches and levels from data/balance.json -> audio.ambience, so the surroundings never loop audibly.
Run: python3 tools/gen_ambience.py
"""
import os

import numpy as np

import audio_dsp as A

RATE = 32000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "ambience")
BED_S = 24.0


def slow_am(dur, rate_hz, depth, seed):
    """Smooth random amplitude movement (gusts, swells)."""
    r = np.random.default_rng(seed)
    n = A.n_of(dur)
    k = max(4, int(dur * rate_hz) + 3)
    pts = r.uniform(1 - depth, 1, k)
    pts[-1] = pts[0]
    xs = np.linspace(0, n, k)
    return np.interp(np.arange(n), xs, pts) ** 2


def periodic_am(dur, period, depth, seed):
    """Swells whose period divides BED_S, so the loop is seamless."""
    t = A.t_axis(dur)
    r = np.random.default_rng(seed)
    x = 0.5 + 0.5 * np.sin(2 * np.pi * t / period + r.random() * 6)
    return (1 - depth) + depth * x ** 1.6


def bed(realm):
    d = BED_S + 2.0
    A.set_rate(RATE, seed=sum(map(ord, realm)))
    if realm == "blossom":
        breeze = A.lp(A.pink(d), 700) * slow_am(d, 0.15, 0.6, 1) * 0.5
        leaves = A.bp(A.pink(d), 1800, 6000) * slow_am(d, 0.35, 0.85, 2) * 0.12
        stream = A.bp(A.noise(d), 500, 2400) * (0.6 + 0.4 * slow_am(d, 9.0, 0.9, 3)) * 0.06
        t = A.t_axis(d)
        crick = np.sin(2 * np.pi * 4600 * t) * (np.sin(2 * np.pi * 28 * t) > 0.6) * \
            (0.5 + 0.5 * np.sin(2 * np.pi * t / 2.0)) ** 4 * 0.012
        x = breeze + leaves + stream + A.lp(crick, 6000)
    elif realm == "desert":
        wind = A.lp(A.pink(d), 520) * slow_am(d, 0.12, 0.7, 4) * 0.6
        whistle = A.bp(A.pink(d), 600, 1300) * slow_am(d, 0.2, 0.95, 5) * 0.18
        sand = A.hp(A.noise(d), 4500) * slow_am(d, 0.25, 0.9, 6) * 0.03
        x = wind + whistle + sand
    elif realm == "harbor":
        swell = periodic_am(d, BED_S / 3, 0.85, 7)
        waves = A.lp(A.brown(d), 600) * swell * 0.5
        wash = A.bp(A.pink(d), 700, 4200) * periodic_am(d, BED_S / 3, 0.95, 7) ** 2 * 0.12
        lap = A.bp(A.noise(d), 250, 900) * (0.4 + 0.6 * slow_am(d, 4.0, 0.95, 8)) * 0.07
        x = waves + wash + lap
    elif realm == "mines":
        room = A.lp(A.brown(d), 180) * 0.5
        t = A.t_axis(d)
        drone = (np.sin(2 * np.pi * 55 * t) + 0.4 * np.sin(2 * np.pi * 82.5 * t + 1)) * \
            (0.7 + 0.3 * np.sin(2 * np.pi * t / (BED_S / 2))) * 0.05
        rumble = A.lp(A.pink(d), 120) * slow_am(d, 0.1, 0.8, 9) * 0.3
        x = A.reverb(room + drone + rumble, 2.5, 0.3, 2000, extend=False)
    elif realm == "sky":
        wind = A.bp(A.pink(d), 350, 2200) * slow_am(d, 0.18, 0.8, 10) * 0.35
        high = A.bp(A.pink(d), 2500, 7000) * slow_am(d, 0.3, 0.95, 11) * 0.06
        low = A.lp(A.pink(d), 250) * 0.25
        x = wind + high + low
    else:
        raise ValueError(realm)
    # Filter before folding the loop: an IIR filter run on the loop itself would click at sample 0.
    x = A.lp(A.hp(x, 30), 11000)
    loop = A.loop_crossfade(x, A.n_of(BED_S), 1.8)
    return A.master(loop, -27.0, -12.0, 0)


# ----------------------------------------------------------------------------- details
def bird(i):
    r = np.random.default_rng(100 + i)
    d = 1.2
    buf = np.zeros(A.n_of(d))
    pos = 0.0
    base = r.uniform(2600, 4200)
    for k in range(r.integers(3, 7)):
        ln = r.uniform(0.04, 0.11)
        up = r.random() > 0.4
        f = (lambda tt, b=base, ln=ln, up=up: b * (1 + (0.35 if up else -0.3) * tt / ln) *
             (1 + 0.04 * np.sin(2 * np.pi * 60 * tt)))
        s = A.sine(f, ln) * A.env(ln, 0.006, ln * 0.6)
        A.place(buf, s * r.uniform(0.6, 1.0), pos)
        pos += ln + r.uniform(0.02, 0.09)
        base *= r.uniform(0.92, 1.1)
    return A.reverb(buf, 1.2, 0.25, 7000)


def dove(i):
    d = 1.4
    buf = np.zeros(A.n_of(d))
    for k, (f, t0, ln) in enumerate([(620, 0.0, 0.25), (520, 0.32, 0.45), (560, 0.85, 0.3)]):
        tt = A.t_axis(ln)
        s = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.04 * np.sin(np.pi * tt / ln))) / A.SR)
        s = A.lp(s + 0.3 * s ** 3, 1500) * A.env(ln, 0.05, 1e4, 1.0, ln * 0.5)
        A.place(buf, s * (0.8 + 0.1 * i), t0)
    return A.reverb(buf, 1.5, 0.3, 4000)


def gull(i):
    r = np.random.default_rng(200 + i)
    d = 1.3
    buf = np.zeros(A.n_of(d))
    pos = 0.0
    for k in range(r.integers(2, 4)):
        ln = r.uniform(0.18, 0.3)
        f0 = r.uniform(1300, 1700)
        tt = A.t_axis(ln)
        f = f0 * (1 + 0.25 * np.exp(-tt / 0.05)) * (1 - 0.25 * tt / ln)
        ph = 2 * np.pi * np.cumsum(f) / A.SR
        s = sum(np.sin(ph * h) / h for h in range(1, 6))
        s = A.bp(s, 900, 3500) * A.env(ln, 0.015, ln * 0.6)
        A.place(buf, s * r.uniform(0.7, 1.0), pos)
        pos += ln + r.uniform(0.05, 0.12)
    return A.reverb(buf, 1.6, 0.3, 5000)


def ship_bell(i):
    return A.reverb(A.bell(820 + 60 * i, 2.5, 1.8, 0.5), 2.0, 0.35, 4000)


def rope_creak(i):
    d = 0.7
    t = A.t_axis(d)
    f0 = 110 + 25 * i
    saw = ((np.cumsum(f0 * (1 + 0.3 * np.sin(2 * np.pi * 1.5 * t))) / A.SR) % 1.0) * 2 - 1
    x = A.bp(saw * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t)), 300, 1600) * A.env(d, 0.12, 0.3)
    return A.reverb(x, 0.8, 0.2, 3000)


def drip(i):
    d = 0.08
    f = lambda tt: 900 + 1800 * (tt / d) ** 0.7 + 150 * i
    x = A.sine(f, d) * A.env(d, 0.002, 0.02)
    return A.reverb(np.pad(x, (0, A.n_of(0.1))), 2.8, 0.55, 5000)


def lava_bubble(i):
    r = np.random.default_rng(300 + i)
    d = 0.6
    buf = np.zeros(A.n_of(d))
    for k in range(r.integers(1, 4)):
        ln = r.uniform(0.06, 0.12)
        f0 = r.uniform(110, 180)
        s = A.sine(lambda tt, f0=f0, ln=ln: f0 * (1 + 1.2 * tt / ln), ln) * A.env(ln, 0.005, ln * 0.5)
        s = s + A.lp(A.noise(ln), 600) * A.env(ln, 0.001, 0.02) * 0.4
        A.place(buf, s, r.uniform(0, 0.35))
    return A.reverb(buf, 1.6, 0.3, 2000)


def pick(i):
    x = A.mix(A.bell(1450 + 140 * i, 0.4, 0.15, 0.9), A.lp(A.noise(0.02), 4000) * 0.3)
    return A.reverb(np.pad(x, (0, A.n_of(0.2))) * 0.6, 3.0, 0.6, 3000)


def chime(i):
    r = np.random.default_rng(400 + i)
    d = 3.0
    buf = np.zeros(A.n_of(d))
    notes = [77, 79, 81, 84, 86, 89]
    for k in range(r.integers(3, 6)):
        A.place(buf, A.bell(A.midi(notes[r.integers(0, len(notes))]), 2.2, 1.6, 0.5) * r.uniform(0.4, 0.9),
                r.uniform(0, 0.8))
    return A.reverb(buf, 2.0, 0.3, 7000)


def hawk(i):
    d = 1.0
    tt = A.t_axis(d)
    f = (2600 + 200 * i) * (1 - 0.35 * tt / d) * (1 + 0.02 * np.sin(2 * np.pi * 30 * tt))
    ph = 2 * np.pi * np.cumsum(f) / A.SR
    x = (np.sin(ph) + 0.3 * np.sin(2 * ph)) * A.env(d, 0.04, 0.35)
    x += A.bp(A.noise(d), 2000, 5000) * A.env(d, 0.04, 0.3) * 0.25
    return A.reverb(A.lp(x, 6000), 2.2, 0.45, 4000)


def gust(i):
    d = 2.6
    x = A.pink(d)
    x = A.sweep_lp(x, 300 + 100 * i, 2200) * np.sin(np.pi * A.t_axis(d) / d) ** 2
    return A.hp(x, 120) * 0.6


DETAILS = {
    "bird": (bird, 4), "dove": (dove, 2), "gull": (gull, 3), "ship_bell": (ship_bell, 2),
    "rope_creak": (rope_creak, 2), "drip": (drip, 4), "lava_bubble": (lava_bubble, 3), "pick": (pick, 2),
    "chime": (chime, 3), "hawk": (hawk, 2), "gust": (gust, 3),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for realm in ("blossom", "desert", "harbor", "mines", "sky"):
        A.write_wav(os.path.join(OUT, f"bed_{realm}.wav"), bed(realm), loop=True, sr=RATE)
    for name, (fn, count) in DETAILS.items():
        for i in range(count):
            A.set_rate(RATE, seed=sum(map(ord, name)) + i)
            y = A.tail_trim(fn(i), -55)
            A.write_wav(os.path.join(OUT, f"amb_{name}_{i}.wav"), A.master(y, -24.0, -9.0, 0, hp_hz=60), sr=RATE)
    print("ambience:", len([f for f in os.listdir(OUT) if f.endswith(".wav")]), "files")


if __name__ == "__main__":
    main()
