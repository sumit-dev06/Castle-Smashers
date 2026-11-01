"""Masters assets/intro/intro.wav for phone speakers (run by capture_intro.py, or on its own).

The page's score is mostly sub-bass (about 80% of its energy is under 150 Hz). Phone speakers
cannot play that, so the intro sounded far quieter than the menu music. This adds harmonics of
the low end (what you hear of a bass note on a small speaker), lifts the 200 Hz - 4 kHz range to
the menu music's level, and limits peaks to -1 dBFS. Target: TARGET_DB above 300 Hz.

Run: python3 tools/master_intro_audio.py [in.wav] [out.wav]
"""
import sys
import wave

import numpy as np

TARGET_DB = -27.0      # level above 300 Hz; the home screen music measures about -25 dB
HARMONIC_MIX = 0.9     # how much of the saturated low band is added back
PEAK = 10 ** (-1.0 / 20)
RMS_CEIL = 0.30        # loudest a 250 ms stretch may get. The STUDIOS part (clean on phones) sits
                       # near 0.27; the INTERCORE hit was 0.63 and rattled small speakers.


def read(path):
    w = wave.open(path)
    sr, ch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype={2: np.int16, 4: np.int32}[sw]).astype(np.float64)
    return x.reshape(-1, ch) / (2 ** (8 * sw - 1)), sr


def write(path, x, sr):
    y = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    w = wave.open(path, "wb")
    w.setnchannels(x.shape[1])
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes(y.tobytes())
    w.close()


def band(x, sr, lo, hi):
    """Zero-phase band filter with soft 1-octave edges (FFT, whole file)."""
    F = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(x.shape[0], 1 / sr)[:, None]
    g = np.ones_like(f)
    if lo > 0:
        g *= np.clip(np.log2(np.maximum(f, 1e-3) / lo) + 1, 0, 1)
    if hi < sr / 2:
        g *= np.clip(1 - np.log2(np.maximum(f, 1e-3) / hi), 0, 1)
    return np.fft.irfft(F * g, n=x.shape[0], axis=0)


def level_above(x, sr, hz=300):
    F = np.abs(np.fft.rfft(x.mean(1))) ** 2
    f = np.fft.rfftfreq(x.shape[0], 1 / sr)
    return 10 * np.log10(F[f >= hz].sum() / x.shape[0] ** 2 * 2 + 1e-12)


def ride(y, sr, win_s=0.25, smooth_s=0.15):
    """Slow level riding: turns down any stretch louder than RMS_CEIL, with no waveshaping."""
    win = int(win_s * sr)
    p = np.convolve((y ** 2).mean(axis=1), np.ones(win) / win, mode="same")
    g = np.minimum(1.0, RMS_CEIL / (np.sqrt(p) + 1e-9))
    k = int(smooth_s * sr)
    g = np.convolve(np.pad(g, (k, k), mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="valid")
    return y * g[:, None]


def limit(y, sr, attack_s=0.005, release_s=0.12):
    need = np.minimum(1.0, PEAK / (np.abs(y).max(axis=1) + 1e-9))   # gain each sample needs
    la = max(1, int(attack_s * sr))
    # Look ahead: each sample takes the lowest gain needed in the next `la` samples.
    pad = np.concatenate([need, np.ones(la)])
    from numpy.lib.stride_tricks import sliding_window_view
    need = sliding_window_view(pad, la + 1).min(axis=1)[: len(need)]
    g = np.empty_like(need)
    cur = 1.0
    a = np.exp(-1.0 / la)
    r = np.exp(-1.0 / (release_s * sr))
    for i, n in enumerate(need):
        cur = a * cur + (1 - a) * n if n < cur else r * cur + (1 - r) * n
        g[i] = min(cur, n) if n < cur * 0.98 else cur
    return y * g[:, None]


def master(x, sr):
    low = band(x, sr, 0, 180)
    drive = 1.0 / (np.abs(low).max() + 1e-9) * 3.0
    harm = band(np.tanh(low * drive) / drive, sr, 220, 3000)   # 2nd/3rd/4th harmonics of the bass
    y = x + HARMONIC_MIX * harm
    y = y - 0.5 * band(y, sr, 0, 45)                            # trim rumble the speaker only distorts on
    gain = 10 ** ((TARGET_DB - level_above(y, sr)) / 20)
    y = y * gain
    # Look-ahead gain limiter: the gain moves smoothly (5 ms attack, 120 ms release), so loud parts
    # get quieter without the waveform itself being bent. The old per-sample tanh limiter sat on the
    # loud INTERCORE hit for 4 s and its waveshaping crackled on phone speakers.
    y = ride(y, sr)
    y = limit(y, sr)
    return y, gain


PLAIN_GAIN_DB = 3.0    # owner's choice: the page's own music, only a little louder


def plain(x, sr):
    """The original score untouched, +PLAIN_GAIN_DB, peaks held at -1 dBFS by the smooth gain limiter."""
    return limit(x * 10 ** (PLAIN_GAIN_DB / 20), sr), 10 ** (PLAIN_GAIN_DB / 20)


if __name__ == "__main__":
    full = "--full" in sys.argv          # old phone-speaker master (harmonics + level riding)
    sys.argv = [a for a in sys.argv if a != "--full"]
    src = sys.argv[1] if len(sys.argv) > 1 else "assets/intro/intro.wav"
    dst = sys.argv[2] if len(sys.argv) > 2 else src
    x, sr = read(src)
    before = level_above(x, sr)
    y, gain = master(x, sr) if full else plain(x, sr)
    write(dst, y, sr)
    print("intro audio: >300 Hz %.1f dB -> %.1f dB (gain %.1f dB), peak %.1f dBFS"
          % (before, level_above(y, sr), 20 * np.log10(gain), 20 * np.log10(np.abs(y).max())))
