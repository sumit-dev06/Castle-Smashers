"""Shared DSP for tools/gen_sfx.py and tools/gen_music.py (numpy + scipy only, no recordings).

Everything works on mono float arrays at the module sample rate `SR` (set_rate() changes it).
Instruments are additive / modal models: plucked strings, mallets, bells, reeds, brass, flute,
pads and a small drum kit. `reverb()` is a synthetic convolution room, `loop_wrap()` folds a
rendered tail back onto the start so a loop is seamless, `write_wav()` can store loop points
in a `smpl` chunk (Godot's WAV importer reads them, so loops need no import tweaks).
"""
import struct
import wave

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
_rng = np.random.default_rng(11)


def set_rate(sr, seed=11):
    global SR, _rng
    SR = sr
    _rng = np.random.default_rng(seed)


def n_of(dur):
    return max(1, int(SR * dur))


def t_axis(dur):
    return np.arange(n_of(dur)) / SR


def noise(dur):
    return _rng.uniform(-1.0, 1.0, n_of(dur))


def pink(dur):
    """1/f noise via spectral shaping, normalised to unit RMS."""
    n = n_of(dur)
    spec = np.fft.rfft(_rng.normal(0, 1, n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1]
    spec /= np.sqrt(f)
    x = np.fft.irfft(spec, n)
    return x / (np.sqrt(np.mean(x * x)) or 1.0)


def brown(dur):
    x = np.cumsum(_rng.normal(0, 1, n_of(dur)))
    x = hp(x, 20)
    return x / (np.sqrt(np.mean(x * x)) or 1.0)


def _sos(kind, freq, order):
    nyq = SR / 2
    if kind == "band":
        lo, hi = freq
        return butter(order, [max(lo, 15) / nyq, min(hi, nyq * 0.95) / nyq], btype="band", output="sos")
    return butter(order, min(max(freq, 15), nyq * 0.95) / nyq, btype=kind, output="sos")


def lp(x, f, order=2):
    return sosfilt(_sos("low", f, order), x)


def hp(x, f, order=2):
    return sosfilt(_sos("high", f, order), x)


def bp(x, lo, hi, order=2):
    return sosfilt(_sos("band", (lo, hi), order), x)


def sweep_lp(x, f0, f1, chunks=48):
    """Low-pass whose cutoff glides from f0 to f1 (exponential) across the sound."""
    out = np.zeros_like(x)
    edges = np.linspace(0, len(x), chunks + 1).astype(int)
    for i in range(chunks):
        f = f0 * (f1 / f0) ** (i / max(chunks - 1, 1))
        a = max(0, edges[i] - 2048)
        y = lp(x[a:edges[i + 1]], f)
        out[edges[i]:edges[i + 1]] = y[-(edges[i + 1] - edges[i]):] if edges[i + 1] > edges[i] else []
    return out


def env(dur, attack=0.005, decay=0.2, sustain=0.0, release=None):
    """Attack, exponential decay towards `sustain`, optional linear release to 0 at the end."""
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    a = np.sin(a * np.pi / 2) ** 2
    d = sustain + (1 - sustain) * np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4))
    e = a * d
    if release:
        r = np.clip((dur - t) / release, 0, 1)
        e *= r
    return e


def fade(x, fin=0.004, fout=0.01):
    x = np.array(x, dtype=float)
    a, b = min(len(x) // 2, n_of(fin)), min(len(x) // 2, n_of(fout))
    if a > 0:
        x[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if b > 0:
        x[-b:] *= np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    return x


def sine(freq, dur, phase=0.0):
    t = t_axis(dur)
    if callable(freq):
        return np.sin(2 * np.pi * np.cumsum(freq(t)) / SR + phase)
    return np.sin(2 * np.pi * freq * t + phase)


def softclip(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, offset, total):
    out = np.zeros(n_of(total))
    s = int(SR * offset)
    if s >= len(out):
        return out
    e = min(len(out), s + len(x))
    out[s:e] += x[:e - s]
    return out


def place(buf, x, offset, gain=1.0):
    """Adds x into buf at offset seconds (in place)."""
    s = int(round(SR * offset))
    if s >= len(buf) or s + len(x) <= 0:
        return
    a = max(0, -s)
    e = min(len(buf), s + len(x))
    buf[max(s, 0):e] += x[a:a + e - max(s, 0)] * gain


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ----------------------------------------------------------------------------- space
_IR_CACHE = {}


def room_ir(decay_s, damp_hz=5000, predelay=0.012, early=6, seed=3):
    key = (SR, decay_s, damp_hz, predelay, early, seed)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    r = np.random.default_rng(seed)
    n = n_of(decay_s * 1.3 + predelay)
    t = np.arange(n) / SR
    tail = r.normal(0, 1, n) * np.exp(-6.9 * t / decay_s)
    # High frequencies die faster than lows, like a real room.
    tail = 0.6 * lp(tail, damp_hz) + 0.4 * lp(tail, damp_hz * 0.35) * np.exp(-3.0 * t / decay_s)
    tail[:n_of(predelay)] = 0
    ir = tail * 0.35
    for k in range(early):
        d = predelay * (0.3 + 0.7 * r.random()) + 0.004 * k
        ir[min(n - 1, n_of(d))] += (0.55 - 0.06 * k) * (1 if r.random() > 0.3 else -1)
    ir /= np.sqrt(np.sum(ir * ir)) or 1.0
    _IR_CACHE[key] = ir
    return ir


def reverb(x, decay_s=1.2, wet=0.2, damp_hz=5000, predelay=0.012, extend=True):
    ir = room_ir(decay_s, damp_hz, predelay)
    y = fftconvolve(x, ir)
    if not extend:
        y = y[:len(x)]
    out = np.zeros(len(y))
    out[:len(x)] += x * (1 - wet * 0.5)
    out += y * wet
    return out


def tail_trim(x, floor_db=-70.0):
    """Drops the silent end of a reverberated sound."""
    a = np.abs(x)
    thr = (np.max(a) or 1.0) * 10 ** (floor_db / 20)
    idx = np.nonzero(a > thr)[0]
    return x[: (idx[-1] + 1) if len(idx) else len(x)]


def loop_wrap(x, loop_n):
    """Folds everything after loop_n back onto the start: a seamless loop of exactly loop_n frames."""
    out = np.array(x[:loop_n], dtype=float)
    if len(out) < loop_n:
        out = np.pad(out, (0, loop_n - len(out)))
    rest = x[loop_n:]
    while len(rest):
        k = min(loop_n, len(rest))
        out[:k] += rest[:k]
        rest = rest[k:]
    return out


def loop_crossfade(x, loop_n, xfade_s=1.5):
    """For noise beds rendered longer than loop_n: equal-power crossfade of the overrun into the start."""
    f = min(n_of(xfade_s), len(x) - loop_n)
    out = np.array(x[:loop_n], dtype=float)
    if f > 0:
        w = np.linspace(0, np.pi / 2, f)
        out[:f] = out[:f] * np.sin(w) + x[loop_n:loop_n + f] * np.cos(w)
    return out


# ----------------------------------------------------------------------------- mastering
def master(x, rms_db=-20.0, peak_db=-3.0, drive=1.15, lp_hz=None, hp_hz=None):
    x = np.asarray(x, dtype=float)
    x = x - np.mean(x)
    if hp_hz:
        x = hp(x, hp_hz)
    if lp_hz:
        x = lp(x, lp_hz)
    rms = np.sqrt(np.mean(x * x)) or 1.0
    x = x * (10 ** (rms_db / 20.0) / rms)
    ceiling = 10 ** (peak_db / 20.0)
    # Soft-knee saturation instead of a hard limiter: transients round off smoothly.
    if drive:
        x = softclip(x / ceiling, drive) * ceiling
    peak = np.max(np.abs(x)) or 1.0
    if peak > ceiling:
        x *= ceiling / peak
    return x


def write_wav(path, x, loop=False, sr=None):
    sr = sr or SR
    data = (np.clip(np.asarray(x), -1.0, 1.0) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data)
    if loop:
        frames = len(data) // 2
        smpl = struct.pack("<9I", 0, 0, int(1e9 / sr), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
        chunk = b"smpl" + struct.pack("<I", len(smpl)) + smpl
        with open(path, "r+b") as f:
            f.seek(0, 2)
            f.write(chunk)
            size = f.tell() - 8
            f.seek(4)
            f.write(struct.pack("<I", size))


# ----------------------------------------------------------------------------- instruments
def pluck(f, dur, bright=0.6, decay=1.2, pick=0.18, inharm=0.0002, body=0.0):
    """Additive plucked string: per-harmonic decay, pick-position comb, slight stiffness."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    hmax = int(min(28, (SR * 0.42) / f))
    for h in range(1, hmax + 1):
        fh = f * h * np.sqrt(1 + inharm * h * h)
        amp = abs(np.sin(np.pi * h * pick)) / h ** (1.45 - 0.7 * bright)
        dk = decay / (1 + 0.45 * (h - 1) * (1.2 - bright))
        out += amp * np.sin(2 * np.pi * fh * t + _rng.random() * 0.3) * np.exp(-t / dk)
    click = lp(noise(0.006), 2500 + 5000 * bright) * 0.15
    out[:len(click)] += click
    if body:
        out += body * sine(f * 0.5, dur) * np.exp(-t / (decay * 0.6))
    return fade(out * env(dur, 0.0015, 1e4), 0.0005, min(0.05, dur * 0.3))


def mallet(f, dur, hard=0.5, decay=0.9, ratios=(1.0, 3.93, 9.2), gains=(1.0, 0.32, 0.1)):
    """Marimba/xylophone: a few inharmonic modes, the upper ones short."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k, (r, g) in enumerate(zip(ratios, gains)):
        if f * r > SR * 0.45:
            continue
        out += g * (0.4 + hard) * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (decay / (1 + 3.5 * k)))
    knock = lp(noise(0.004), 3000 + 4000 * hard) * 0.2 * hard
    out[:len(knock)] += knock
    return fade(out, 0.0008, min(0.04, dur * 0.3))


def bell(f, dur, decay=1.6, bright=0.6):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k, (r, g) in enumerate([(1.0, 1.0), (2.0, 0.55), (2.76, 0.35 * bright), (4.07, 0.2 * bright),
                                (5.43, 0.12 * bright), (0.5, 0.25)]):
        if f * r > SR * 0.45:
            continue
        out += g * np.sin(2 * np.pi * f * r * t + k) * np.exp(-t / (decay / (1 + 0.7 * k)))
    return fade(out * env(dur, 0.001, 1e4), 0.0005, min(0.06, dur * 0.3))


def _additive_saw(f_t, t, hmax, tilt=1.0):
    ph = 2 * np.pi * np.cumsum(f_t) / SR
    out = np.zeros_like(t)
    for h in range(1, hmax + 1):
        out += np.sin(ph * h) / h ** tilt
    return out


def reed(f, dur, vel=1.0, nasal=0.6):
    """Accordion/reed: two slightly detuned reeds with tremolo and a nasal formant."""
    t = t_axis(dur)
    hmax = int(min(14, SR * 0.4 / f))
    vib = 1 + 0.003 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.25, 0, 1)
    a = _additive_saw(f * vib, t, hmax, 0.9)
    b = _additive_saw(f * 1.0035 * vib, t, hmax, 0.9)
    x = (a + b) * 0.5
    x = lp(x, 2600) + nasal * bp(x, 900, 1800) * 0.6
    return fade(x * env(dur, 0.03, 1e4, 1.0, min(0.12, dur * 0.4)) * vel, 0.002, 0.02)


def brass(f, dur, vel=1.0, bright=0.7):
    t = t_axis(dur)
    hmax = int(min(18, SR * 0.4 / f))
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    scoop = 1 - 0.02 * np.exp(-t / 0.03)
    x = _additive_saw(f * vib * scoop, t, hmax, 1.0)
    e = env(dur, 0.035, 1e4, 1.0, min(0.15, dur * 0.4))
    # Brightness follows the attack (filter envelope), the soul of a brass sound.
    lo, hi = 700 * bright + f, 2600 * bright + 2 * f
    y = 0.55 * lp(x, lo) + 0.45 * lp(x, hi) * (0.3 + 0.7 * np.exp(-t / 0.18))
    return fade(y * e * vel, 0.002, 0.02)


def flute(f, dur, vel=1.0, breath=0.12):
    t = t_axis(dur)
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.18) / 0.3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    air = bp(noise(dur), f * 1.2, f * 3.5) * breath * (0.6 + 0.4 * np.exp(-t / 0.08))
    e = env(dur, 0.06, 1e4, 1.0, min(0.12, dur * 0.4))
    return fade((x + air) * e * vel, 0.003, 0.02)


def strings(f, dur, vel=1.0, attack=0.25, voices=3):
    """Section pad: detuned saws, slow bow attack, warm filter."""
    t = t_axis(dur)
    hmax = int(min(16, SR * 0.4 / f))
    x = np.zeros_like(t)
    for v in range(voices):
        det = 1 + (v - (voices - 1) / 2) * 0.004
        vib = 1 + 0.003 * np.sin(2 * np.pi * (4.8 + v * 0.4) * t + v)
        x += _additive_saw(f * det * vib, t, hmax, 1.15)
    x = lp(x / voices, 2200)
    return fade(x * env(dur, attack, 1e4, 1.0, min(0.3, dur * 0.4)) * vel, 0.005, 0.03)


def pad(f, dur, vel=1.0, attack=0.6, air=0.2):
    t = t_axis(dur)
    x = np.zeros_like(t)
    for k, det in enumerate((0.997, 1.0, 1.0032)):
        ph = 2 * np.pi * f * det * t + k
        x += np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    x /= 3
    if air:
        x += bp(noise(dur), f * 2, f * 6) * air * 0.4
    return fade(x * env(dur, attack, 1e4, 1.0, min(0.5, dur * 0.5)) * vel, 0.01, 0.05)


def bass(f, dur, vel=1.0, decay=0.45, round_=0.8):
    t = t_axis(dur)
    ph = 2 * np.pi * f * t
    x = np.sin(ph) + 0.35 * (1 - round_ * 0.5) * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    e = env(dur, 0.004, decay, 0.25, min(0.08, dur * 0.3))
    thump = lp(noise(0.01), 900) * 0.15
    x[:len(thump)] += thump
    return fade(x * e * vel, 0.001, 0.02)


def tuba(f, dur, vel=1.0):
    return brass(f, dur, vel, bright=0.35)


# ----------------------------------------------------------------------------- drums
def kick(dur=0.35, f0=130, f1=48, vel=1.0, click=0.3):
    t = t_axis(dur)
    x = sine(lambda tt: f1 + (f0 - f1) * np.exp(-tt / 0.035), dur) * np.exp(-t / 0.16)
    c = lp(noise(0.008), 4000) * click
    x[:len(c)] += c
    return fade(x * vel, 0.0005, 0.03)


def snare(dur=0.25, vel=1.0, tone=190, snap=0.8):
    t = t_axis(dur)
    body = sine(tone, dur) * np.exp(-t / 0.05) * 0.7
    wires = bp(noise(dur), 1500, 8000) * np.exp(-t / 0.09) * snap
    return fade((body + wires) * vel, 0.0005, 0.03)


def hat(dur=0.08, vel=1.0, open_=False):
    t = t_axis(dur)
    x = bp(noise(dur), 6000, 12000) * np.exp(-t / (0.12 if open_ else 0.022))
    return fade(x * vel, 0.0003, 0.01)


def shaker(dur=0.09, vel=1.0):
    t = t_axis(dur)
    x = bp(noise(dur), 3500, 9000) * env(dur, 0.012, 0.03)
    return fade(x * vel * 0.8, 0.002, 0.01)


def taiko(dur=0.9, vel=1.0, f=62):
    t = t_axis(dur)
    x = sine(lambda tt: f + 40 * np.exp(-tt / 0.03), dur) * np.exp(-t / 0.32)
    skin = lp(noise(dur), 900) * np.exp(-t / 0.05) * 0.6
    return fade((x + skin) * vel, 0.0005, 0.05)


def tom(dur=0.4, vel=1.0, f=120):
    t = t_axis(dur)
    x = sine(lambda tt: f + 50 * np.exp(-tt / 0.03), dur) * np.exp(-t / 0.15)
    return fade((x + lp(noise(dur), 1500) * np.exp(-t / 0.02) * 0.3) * vel, 0.0005, 0.03)


def doum(dur=0.4, vel=1.0):
    return tom(dur, vel, 82)


def tek(dur=0.1, vel=1.0):
    t = t_axis(dur)
    x = bp(noise(dur), 1800, 6000) * np.exp(-t / 0.018) + sine(520, dur) * np.exp(-t / 0.02) * 0.5
    return fade(x * vel, 0.0003, 0.01)


def woodblock(dur=0.12, vel=1.0, f=820):
    return mallet(f, dur, 0.8, 0.09, (1.0, 2.6), (1.0, 0.4)) * vel


def clap(dur=0.2, vel=1.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k in range(3):
        b = bp(noise(dur), 900, 4500) * np.exp(-np.maximum(t - 0.009 * k, 0) / (0.012 if k < 2 else 0.07))
        b[: n_of(0.009 * k)] = 0
        out += b
    return fade(out * vel, 0.0003, 0.02)


def tambourine(dur=0.18, vel=1.0):
    t = t_axis(dur)
    j = bp(noise(dur), 6000, 11000) * env(dur, 0.004, 0.06)
    ring = sum(sine(f, dur) * np.exp(-t / 0.05) for f in (5200, 6900, 8300)) * 0.06
    return fade((j + ring) * vel, 0.001, 0.01)


def anvil(dur=0.6, vel=1.0, f=880):
    return bell(f, dur, 0.5, 0.9) * vel


def cymbal(dur=2.0, vel=1.0, swell=False):
    t = t_axis(dur)
    x = hp(noise(dur), 3500) * 0.5 + bp(noise(dur), 5000, 11000) * 0.5
    e = np.clip(t / dur, 0, 1) ** 2 if swell else np.exp(-t / 0.7)
    return fade(lp(x, 12000) * e * vel, 0.002, 0.08)


def roll(dur=1.0, vel=1.0, rate=22, kind="snare"):
    out = np.zeros(n_of(dur + 0.3))
    k = 0
    while k / rate < dur:
        g = vel * (0.35 + 0.65 * (k / rate / dur))
        hit = snare(0.12, g, snap=0.9) if kind == "snare" else taiko(0.4, g * 0.6, 70)
        place(out, hit, k / rate)
        k += 1
    return out
