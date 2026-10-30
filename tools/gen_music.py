#!/usr/bin/env python3
"""Composes and renders the adaptive music (owned by the project, no samples).

Each song has two stems of identical length that loop seamlessly and play in sync:
  <song>_base.wav    harmony, bass and the lead melody (always on: aiming, menus)
  <song>_action.wav  drums, ostinato and a melody double (faded in by Sound during flight and
                     destruction, see data/balance.json -> audio.music_states)
Stingers (win, lose, boss intro, siege start, reward) are one-shots.

Output: assets/audio/music/*.wav at 32 kHz (Godot imports them as QOA; loop points are written
into a WAV `smpl` chunk so they loop without import tweaks).
Run:    python3 tools/gen_music.py [song ...]
"""
import os
import sys

import numpy as np

import audio_dsp as A

RATE = 32000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "music")

CHORD = {"maj": (0, 4, 7), "min": (0, 3, 7), "sus2": (0, 2, 7), "sus4": (0, 5, 7), "maj7": (0, 4, 7, 11),
         "5": (0, 7), "dim": (0, 3, 6), "7": (0, 4, 7, 10)}


# ----------------------------------------------------------------------------- instruments
def _inst(name):
    f = {
        "koto": lambda hz, d, v: A.pluck(hz, max(d, 1.2), 0.78, 0.85, 0.11) * v,
        "shaku": lambda hz, d, v: A.flute(hz, d, v, 0.22),
        "flute": lambda hz, d, v: A.flute(hz, d, v, 0.1),
        "oud": lambda hz, d, v: A.pluck(hz, max(d, 0.9), 0.55, 0.6, 0.2, body=0.15) * v,
        "harp": lambda hz, d, v: A.pluck(hz, max(d, 1.6), 0.4, 1.5, 0.3) * v,
        "pizz": lambda hz, d, v: A.pluck(hz, 0.5, 0.42, 0.22, 0.22) * v,
        "banjo": lambda hz, d, v: A.pluck(hz, 0.6, 0.92, 0.32, 0.08) * v,
        "accordion": lambda hz, d, v: A.reed(hz, d, v, 0.6),
        "reed_drone": lambda hz, d, v: A.reed(hz, d, v, 0.25),
        "marimba": lambda hz, d, v: A.mallet(hz, max(d, 0.8), 0.45, 0.7) * v,
        "celesta": lambda hz, d, v: A.bell(hz, max(d, 1.4), 1.1, 0.4) * v,
        "bells": lambda hz, d, v: A.bell(hz, max(d, 2.0), 1.8, 0.7) * v,
        "brass": lambda hz, d, v: A.brass(hz, d, v, 0.75),
        "horn": lambda hz, d, v: A.brass(hz, d, v, 0.45),
        "tuba": lambda hz, d, v: A.tuba(hz, d, v),
        "strings": lambda hz, d, v: A.strings(hz, d, v, 0.3),
        "strings_short": lambda hz, d, v: A.strings(hz, d, v, 0.02, 2) * A.env(d, 0.01, 0.12, 0.2),
        "pad": lambda hz, d, v: A.pad(hz, d, v, 0.7, 0.15),
        "bass": lambda hz, d, v: A.bass(hz, d, v, 0.4),
        "bass_long": lambda hz, d, v: A.bass(hz, d, v, 1.2, 1.0),
    }
    return f[name]


KIT = {
    "K": lambda v: A.kick(0.4, 120, 46, v),
    "S": lambda v: A.snare(0.25, v),
    "H": lambda v: A.hat(0.06, v * 0.5),
    "O": lambda v: A.hat(0.25, v * 0.45, True),
    "s": lambda v: A.shaker(0.09, v * 0.6),
    "T": lambda v: A.taiko(0.9, v),
    "t": lambda v: A.tom(0.4, v, 140),
    "W": lambda v: A.woodblock(0.12, v * 0.7),
    "D": lambda v: A.doum(0.45, v),
    "k": lambda v: A.tek(0.1, v * 0.8),
    "J": lambda v: A.tambourine(0.18, v * 0.7),
    "C": lambda v: A.clap(0.2, v * 0.8),
    "A": lambda v: A.anvil(0.6, v * 0.5, 1320),
    "Y": lambda v: A.cymbal(1.8, v * 0.35),
}


# ----------------------------------------------------------------------------- songs
# Melodies: "degree:eighths", degrees index the scale (negative = below the root octave), r = rest.
# Bars are separated by |. A song is 16 bars: the 8-bar tune twice, the second time with `lead2`
# and the `ending` replacing its last two bars. Chords: (semitones above the key root, quality).
SONGS = {
    "menu": dict(
        bpm=112, meter=4, root=60, scale=(0, 2, 4, 5, 7, 9, 11), verb=(1.5, 0.2),
        melody="4:1 4:1 4:1 7:3 6:1 5:1 | 4:4 2:2 0:2 | 1:2 2:1 3:1 4:2 5:2 | 4:6 r:2 |"
               "4:1 4:1 4:1 7:3 8:1 9:1 | 8:4 7:2 6:2 | 5:2 6:1 5:1 4:2 1:2 | 0:6 r:2",
        ending="5:2 6:2 8:2 6:2 | 7:6 r:2",
        chords=[(0, "maj"), (0, "maj"), (5, "maj"), (7, "maj"), (0, "maj"), (7, "maj"), (2, "min"), (0, "maj")],
        end_chords=[(7, "maj"), (0, "maj")],
        parts=[
            dict(kind="melody", inst="horn", stem="base", gain=0.55, half=1),
            dict(kind="melody", inst="flute", stem="base", gain=0.5, oct=1, half=2),
            dict(kind="pad", inst="strings", stem="base", gain=0.22),
            dict(kind="bass", inst="pizz", stem="base", gain=0.7, pattern="1...5...", oct=-2),
            dict(kind="arp", inst="pizz", stem="base", gain=0.28, pattern=[0, 2, 1, 2, 0, 2, 1, 2], oct=0),
            dict(kind="melody", inst="brass", stem="action", gain=0.35, oct=0),
            dict(kind="stab", inst="strings_short", stem="action", gain=0.22, pattern="..x...x."),
            dict(kind="drums", stem="action", gain=0.8, lines={
                "K": "x.......x.......", "S": "....x.......x...", "H": "..o...o...o...o.",
                "s": "o.o.o.o.o.o.o.o."},
                fill={"S": "....x.....x.xxxx", "K": "x.......x......."}),
        ]),
    "blossom": dict(
        bpm=96, meter=4, root=62, scale=(0, 2, 5, 7, 9), verb=(1.8, 0.24),
        melody="4:2 3:1 4:1 5:4 | 4:2 3:2 2:2 1:2 | 2:3 1:1 0:2 1:2 | 2:6 r:2 |"
               "0:2 1:2 2:2 4:2 | 3:2 4:1 3:1 2:4 | 1:2 2:2 1:2 -1:2 | 0:6 r:2",
        ending="2:2 1:2 0:2 1:2 | 0:6 r:2",
        chords=[(0, "sus2"), (5, "maj"), (2, "min"), (7, "sus4"), (9, "min"), (5, "maj"), (7, "sus4"), (0, "sus2")],
        end_chords=[(7, "maj"), (0, "sus2")],
        parts=[
            dict(kind="melody", inst="koto", stem="base", gain=0.6, half=1),
            dict(kind="melody", inst="shaku", stem="base", gain=0.5, half=2),
            dict(kind="pad", inst="pad", stem="base", gain=0.2),
            dict(kind="bass", inst="bass", stem="base", gain=0.55, pattern="1.....5.", oct=-2),
            dict(kind="arp", inst="harp", stem="base", gain=0.2, pattern=[0, 1, 2, 1, 3, 1, 2, 1], oct=0),
            dict(kind="melody", inst="koto", stem="action", gain=0.28, oct=1),
            dict(kind="drums", stem="action", gain=0.8, lines={
                "T": "x.......x..o....", "W": "....x.......x.o.", "s": "o.o.o.o.o.o.o.o.",
                "K": "x.........x....."},
                fill={"T": "x.......x.o.x.xx"}),
        ]),
    "desert": dict(
        bpm=100, meter=4, root=62, scale=(0, 1, 4, 5, 7, 8, 10), verb=(1.5, 0.2),
        melody="0:1 1:1 2:2 3:2 4:2 | 5:2 4:1 3:1 4:4 | 4:1 5:1 4:1 3:1 2:2 1:2 | 2:2 1:2 0:4 |"
               "4:2 4:1 5:1 6:2 5:2 | 4:3 3:1 2:4 | 3:1 2:1 1:1 2:1 3:2 1:2 | 0:6 r:2",
        ending="3:1 4:1 5:1 6:1 7:2 5:2 | 7:6 r:2",
        chords=[(0, "maj"), (1, "maj"), (5, "min"), (0, "maj"), (5, "min"), (0, "maj"), (1, "maj"), (0, "maj")],
        end_chords=[(1, "maj"), (0, "maj")],
        parts=[
            dict(kind="melody", inst="oud", stem="base", gain=0.6, half=1),
            dict(kind="melody", inst="flute", stem="base", gain=0.45, half=2, oct=1),
            dict(kind="drone", inst="reed_drone", stem="base", gain=0.12),
            dict(kind="pad", inst="strings", stem="base", gain=0.13),
            dict(kind="bass", inst="bass", stem="base", gain=0.55, pattern="1..1..5.", oct=-2),
            dict(kind="arp", inst="oud", stem="action", gain=0.26, pattern=[0, 0, 2, 0, 1, 0, 2, 1], oct=-1),
            dict(kind="drums", stem="action", gain=0.85, lines={
                "D": "x.....x...x.....", "k": "...x.o..x..o.x.o", "J": "....x.......x...",
                "s": "o.o.o.o.o.o.o.o."},
                fill={"D": "x.....x...x.x.x.", "k": "...x.o..xoxoxoxo"}),
        ]),
    "harbor": dict(
        bpm=68, meter=6, root=62, scale=(0, 2, 3, 5, 7, 9, 10), verb=(1.1, 0.16),
        melody="4:2 2:1 4:2 5:1 | 4:2 0:1 2:2 4:1 | 3:2 1:1 3:2 4:1 | 3:2 -1:1 1:2 3:1 |"
               "4:2 4:1 4:2 5:1 | 6:2 7:1 6:2 4:1 | 3:2 1:1 -1:2 1:1 | 0:5 r:1",
        ending="3:1 4:1 5:1 6:2 5:1 | 7:5 r:1",
        chords=[(0, "min"), (0, "min"), (10, "maj"), (10, "maj"), (0, "min"), (0, "min"), (10, "maj"), (0, "min")],
        end_chords=[(10, "maj"), (0, "min")],
        parts=[
            dict(kind="melody", inst="accordion", stem="base", gain=0.42, half=1),
            dict(kind="melody", inst="flute", stem="base", gain=0.45, oct=1, half=2),
            dict(kind="bass", inst="tuba", stem="base", gain=0.5, pattern="1..5..", oct=-2, short=0.8),
            dict(kind="stab", inst="banjo", stem="base", gain=0.3, pattern=".xx.xx"),
            dict(kind="melody", inst="banjo", stem="action", gain=0.3, oct=1),
            dict(kind="drums", stem="action", gain=0.85, lines={
                "K": "x.....x.....", "C": "......x.....", "J": "..o.o...o.o.", "s": "o.o.o.o.o.o."},
                fill={"K": "x.....x.x.x.", "C": "......x...x."}),
        ]),
    "mines": dict(
        bpm=92, meter=4, root=69, scale=(0, 2, 3, 5, 7, 8, 10), verb=(2.6, 0.3),
        melody="0:2 2:2 4:2 2:2 | 3:2 2:1 1:1 2:4 | 0:2 2:2 4:2 5:2 | 4:6 r:2 |"
               "5:2 4:2 3:2 2:2 | 1:2 2:1 1:1 -1:4 | 0:2 -1:2 -2:2 -1:2 | 0:6 r:2",
        ending="2:2 3:2 4:2 6:2 | 7:6 r:2",
        chords=[(0, "min"), (5, "min"), (0, "min"), (7, "min"), (8, "maj"), (10, "maj"), (5, "min"), (0, "min")],
        end_chords=[(10, "maj"), (0, "min")],
        parts=[
            dict(kind="melody", inst="marimba", stem="base", gain=0.6, half=1),
            dict(kind="melody", inst="celesta", stem="base", gain=0.42, half=2),
            dict(kind="pad", inst="strings", stem="base", gain=0.16, oct=-1),
            dict(kind="bass", inst="bass_long", stem="base", gain=0.6, pattern="1.......", oct=-3),
            dict(kind="arp", inst="marimba", stem="action", gain=0.3, pattern=[0, 2, 0, 2, 0, 2, 1, 2], oct=-1),
            dict(kind="drums", stem="action", gain=0.85, lines={
                "K": "x.......x.x.....", "t": "....x.......x..o", "A": "........o.......",
                "s": "o.o.o.o.o.o.o.o."},
                fill={"t": "....x.....x.x.xx"}),
        ]),
    "sky": dict(
        bpm=104, meter=4, root=65, scale=(0, 2, 4, 6, 7, 9, 11), verb=(2.3, 0.28),
        melody="0:1 2:1 4:1 6:1 7:4 | 6:2 4:2 3:4 | 4:2 5:1 4:1 2:2 1:2 | 2:6 r:2 |"
               "0:1 2:1 4:1 6:1 8:4 | 7:2 6:2 5:4 | 4:2 3:2 1:2 2:2 | 0:6 r:2",
        ending="4:2 5:2 6:2 8:2 | 7:6 r:2",
        chords=[(0, "maj7"), (2, "maj"), (9, "min"), (0, "maj"), (0, "maj7"), (9, "min"), (2, "maj"), (0, "maj")],
        end_chords=[(2, "maj"), (0, "maj7")],
        parts=[
            dict(kind="melody", inst="celesta", stem="base", gain=0.5, half=1),
            dict(kind="melody", inst="flute", stem="base", gain=0.5, half=2),
            dict(kind="pad", inst="pad", stem="base", gain=0.22),
            dict(kind="bass", inst="bass", stem="base", gain=0.5, pattern="1...5...", oct=-2),
            dict(kind="arp", inst="harp", stem="base", gain=0.24, pattern=[0, 1, 2, 3, 2, 1, 2, 1], oct=0),
            dict(kind="melody", inst="bells", stem="action", gain=0.18, oct=1),
            dict(kind="drums", stem="action", gain=0.75, lines={
                "K": "x.......x.......", "C": "....x.......x...", "s": "o.o.o.o.o.o.o.o.",
                "H": "..o...o...o...o."},
                fill={"C": "....x.....x.x.x."}),
        ]),
    "boss": dict(
        bpm=128, meter=4, root=64, scale=(0, 2, 3, 5, 7, 8, 11), verb=(1.4, 0.18),
        melody="0:1 0:1 1:1 2:1 0:1 0:1 2:1 1:1 | 0:2 -1:2 -2:4 | 0:1 0:1 1:1 2:1 3:1 2:1 1:1 2:1 | 4:6 r:2 |"
               "5:2 4:2 3:2 2:2 | 3:2 2:2 1:2 -1:2 | 0:1 2:1 4:1 6:1 7:2 6:2 | 4:6 r:2",
        ending="7:1 6:1 5:1 4:1 3:1 2:1 1:1 -1:1 | 0:6 r:2",
        chords=[(0, "min"), (7, "maj"), (0, "min"), (7, "maj"), (8, "maj"), (5, "min"), (0, "min"), (7, "maj")],
        end_chords=[(7, "maj"), (0, "min")],
        parts=[
            dict(kind="melody", inst="horn", stem="base", gain=0.5, oct=-1, half=1),
            dict(kind="melody", inst="strings", stem="base", gain=0.42, half=2),
            dict(kind="arp", inst="strings_short", stem="base", gain=0.3, pattern=[0, 0, 2, 0, 1, 0, 2, 0], oct=-1),
            dict(kind="bass", inst="bass", stem="base", gain=0.6, pattern="11.111.1", oct=-2, short=0.5),
            dict(kind="melody", inst="brass", stem="action", gain=0.32),
            dict(kind="drums", stem="action", gain=0.9, lines={
                "T": "x.....x...x.....", "K": "x...x...x...x...", "S": "....x.......x...",
                "H": "o.o.o.o.o.o.o.o."},
                fill={"T": "x.....x...x.xxxx", "Y": "x..............."}),
        ]),
}


def parse_melody(text):
    bars = []
    for bar in text.split("|"):
        notes = []
        for tok in bar.split():
            d, n = tok.split(":")
            notes.append((None if d == "r" else int(d), int(n)))
        bars.append(notes)
    return bars


def degree_midi(song, deg):
    sc = song["scale"]
    return song["root"] + 12 * (deg // len(sc)) + sc[deg % len(sc)]


def chord_midis(song, chord, oct_=0):
    root, q = chord
    base = song["root"] + root + 12 * oct_
    if base > song["root"] + 7 + 12 * oct_:
        base -= 12
    return [base + i for i in CHORD[q]]


def render(name):
    song = SONGS[name]
    A.set_rate(RATE, seed=sum(map(ord, name)))
    meter = song["meter"]
    eighth = 30.0 / song["bpm"] if meter == 4 else 60.0 / song["bpm"] / 3.0
    bar_e = 8 if meter == 4 else 6
    bar_s = eighth * bar_e
    bars = 16
    loop_s = bars * bar_s
    total = loop_s + 4.0
    mel = parse_melody(song["melody"])
    end = parse_melody(song["ending"])
    for b in mel + end:
        assert sum(n for _, n in b) == bar_e, (name, b)
    chords = song["chords"] * 2
    chords[14:16] = song["end_chords"]
    stems = {"base": np.zeros(A.n_of(total)), "action": np.zeros(A.n_of(total))}
    rng = np.random.default_rng(5)

    def hum():
        return rng.uniform(0.0, 0.006)

    for part in song["parts"]:
        buf = stems[part["stem"]]
        g = part.get("gain", 0.5)
        k = part["kind"]
        oct_ = part.get("oct", 0)
        if k == "melody":
            fn = _inst(part["inst"])
            half = part.get("half", 0)
            for b in range(bars):
                if half == 1 and b >= 8 or half == 2 and b < 8:
                    continue
                notes = end[b - 14] if b >= 14 else mel[b % 8]
                pos = 0
                for deg, n in notes:
                    if deg is not None:
                        hz = A.midi(degree_midi(song, deg) + 12 * oct_)
                        dur = n * eighth * 0.94
                        vel = g * (1.0 if pos % 4 == 0 else 0.85) * rng.uniform(0.92, 1.0)
                        A.place(buf, fn(hz, dur, vel), b * bar_s + pos * eighth + hum())
                    pos += n
        elif k == "pad":
            fn = _inst(part["inst"])
            for b in range(bars):
                for m in chord_midis(song, chords[b], oct_):
                    A.place(buf, fn(A.midi(m), bar_s + 0.25, g * 0.6), b * bar_s)
        elif k == "drone":
            fn = _inst(part["inst"])
            for m in (song["root"] - 12, song["root"] - 5):
                A.place(buf, fn(A.midi(m), loop_s + 1.0, g), 0.0)
        elif k == "bass":
            fn = _inst(part["inst"])
            pat = part["pattern"]
            for b in range(bars):
                r = chord_midis(song, chords[b], 0)[0] + 12 * oct_
                for i, ch in enumerate(pat):
                    if ch == ".":
                        continue
                    m = r + {"1": 0, "3": CHORD[chords[b][1]][1], "5": 7, "8": 12}[ch]
                    span = 1
                    while i + span < len(pat) and pat[i + span] == ".":
                        span += 1
                    dur = span * eighth * part.get("short", 0.95)
                    A.place(buf, fn(A.midi(m), dur, g), b * bar_s + i * eighth + hum())
        elif k == "arp":
            fn = _inst(part["inst"])
            pat = part["pattern"]
            for b in range(bars):
                tones = chord_midis(song, chords[b], oct_)
                tones = tones + [tones[0] + 12]
                for i, idx in enumerate(pat[:bar_e]):
                    m = tones[idx % len(tones)]
                    vel = g * (1.0 if i % 2 == 0 else 0.75)
                    A.place(buf, fn(A.midi(m), eighth * 0.9, vel), b * bar_s + i * eighth + hum())
        elif k == "stab":
            fn = _inst(part["inst"])
            for b in range(bars):
                for i, ch in enumerate(part["pattern"]):
                    if ch != "x":
                        continue
                    for j, m in enumerate(chord_midis(song, chords[b], oct_)):
                        A.place(buf, fn(A.midi(m), eighth * 0.8, g * 0.5), b * bar_s + i * eighth + j * 0.012)
        elif k == "drums":
            step = eighth / 2
            for b in range(bars):
                lines = dict(part["lines"])
                if b % 8 == 7:
                    lines.update(part.get("fill", {}))
                for drum, line in lines.items():
                    for i, ch in enumerate(line):
                        if ch == ".":
                            continue
                        vel = g * (1.0 if ch == "x" else 0.55) * rng.uniform(0.9, 1.0)
                        A.place(buf, KIT[drum](vel), b * bar_s + i * step + hum())
    loop_n = A.n_of(loop_s)
    decay, wet = song["verb"]
    out = {}
    for key, buf in stems.items():
        y = A.hp(A.reverb(buf, decay, wet, 6000, 0.018), 35)
        out[key] = A.loop_wrap(y, loop_n)
    # One gain for both stems keeps their balance; the full mix sits at about -18 dB RMS.
    full = out["base"] + out["action"]
    gain = 10 ** (-18.0 / 20) / (np.sqrt(np.mean(full * full)) or 1.0)
    for key in out:
        y = A.softclip(out[key] * gain / 0.7, 1.1) * 0.7
        out[key] = y
    return out, loop_s


# ----------------------------------------------------------------------------- stingers
def stinger(name):
    A.set_rate(RATE, seed=17)
    m = A.midi
    if name == "win":
        d = 3.2
        buf = np.zeros(A.n_of(d))
        for i, (n, t0, ln) in enumerate([(67, 0.0, 0.16), (72, 0.14, 0.16), (76, 0.28, 0.16), (79, 0.42, 0.16),
                                         (84, 0.58, 1.6)]):
            A.place(buf, A.brass(m(n), ln, 0.6), t0)
            A.place(buf, A.bell(m(n + 12), 1.2, 1.0, 0.5) * 0.18, t0)
        for n in (60, 64, 67, 72):
            A.place(buf, A.strings(m(n), 1.8, 0.2, 0.08), 0.58)
        A.place(buf, A.kick(0.5, 120, 45, 0.8), 0.58)
        A.place(buf, A.cymbal(2.2, 0.5), 0.58)
        A.place(buf, A.roll(0.5, 0.35), 0.05)
        for i, n in enumerate((84, 88, 91, 96)):
            A.place(buf, A.bell(m(n), 1.0, 0.8, 0.6) * 0.12, 0.9 + i * 0.08)
        y = A.reverb(buf, 1.6, 0.22)
    elif name == "lose":
        d = 3.0
        buf = np.zeros(A.n_of(d))
        for i, (n, t0, ln) in enumerate([(67, 0.0, 0.32), (66, 0.36, 0.32), (65, 0.72, 0.32), (64, 1.08, 1.3)]):
            tone = A.brass(m(n), ln, 0.55, 0.4)
            if i == 3:  # the last note droops and wobbles: a gentle comic "aww"
                tt = A.t_axis(ln)
                tone *= (1 + 0.25 * np.sin(2 * np.pi * 6 * tt) * np.clip(tt / 0.3, 0, 1)) / 1.25
            A.place(buf, tone, t0)
        A.place(buf, A.pluck(m(40), 1.6, 0.4, 0.9) * 0.4, 1.08)
        A.place(buf, A.tom(0.5, 0.35, 90), 1.08)
        y = A.reverb(buf, 1.4, 0.2)
    elif name == "boss_intro":
        d = 3.2
        buf = np.zeros(A.n_of(d))
        A.place(buf, A.cymbal(1.1, 0.5, swell=True), 0.0)
        A.place(buf, A.roll(1.0, 0.5, 14, "taiko"), 0.0)
        A.place(buf, A.taiko(1.6, 1.0, 50), 1.1)
        for n in (40, 47, 52):
            A.place(buf, A.brass(m(n), 1.8, 0.5, 0.5), 1.1)
        for i, n in enumerate((52, 51, 52, 55)):
            A.place(buf, A.strings(m(n + 12), 0.25, 0.3, 0.02, 2), 1.15 + i * 0.22)
        y = A.reverb(buf, 1.8, 0.24)
    elif name == "siege_start":
        d = 2.2
        buf = np.zeros(A.n_of(d))
        A.place(buf, A.brass(m(55), 0.3, 0.5, 0.5), 0.0)
        A.place(buf, A.brass(m(62), 0.22, 0.55, 0.6), 0.32)
        A.place(buf, A.brass(m(67), 0.9, 0.6, 0.7), 0.56)
        A.place(buf, A.taiko(0.9, 0.7, 60), 0.56)
        A.place(buf, A.cymbal(1.5, 0.25), 0.56)
        y = A.reverb(buf, 1.8, 0.26)
    elif name == "reward":
        d = 2.0
        buf = np.zeros(A.n_of(d))
        for i, n in enumerate((72, 76, 79, 84, 88)):
            A.place(buf, A.bell(m(n), 1.2, 1.0, 0.5) * 0.5, i * 0.07)
            A.place(buf, A.pluck(m(n - 12), 0.8, 0.6, 0.5) * 0.3, i * 0.07)
        for n in (60, 64, 67):
            A.place(buf, A.pad(m(n), 1.2, 0.25, 0.05, 0.1), 0.0)
        y = A.reverb(buf, 1.6, 0.25)
    else:
        raise ValueError(name)
    y = A.tail_trim(y, -60)
    return A.master(y, -17.0, -3.0, 1.1, hp_hz=40)


def main():
    os.makedirs(OUT, exist_ok=True)
    want = sys.argv[1:]
    for name in SONGS:
        if want and name not in want:
            continue
        stems, loop_s = render(name)
        for key, y in stems.items():
            A.write_wav(os.path.join(OUT, f"{name}_{key}.wav"), y, loop=True, sr=RATE)
        print(f"music {name}: {loop_s:.1f}s loop")
    for name in ("win", "lose", "boss_intro", "siege_start", "reward"):
        if want and name not in want:
            continue
        A.set_rate(RATE)
        A.write_wav(os.path.join(OUT, f"sting_{name}.wav"), stinger(name), sr=RATE)
        print("stinger", name)


if __name__ == "__main__":
    main()
