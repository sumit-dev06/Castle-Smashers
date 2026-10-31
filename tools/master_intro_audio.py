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


def master(x, sr):
    low = band(x, sr, 0, 180)
    drive = 1.0 / (np.abs(low).max() + 1e-9) * 3.0
    harm = band(np.tanh(low * drive) / drive, sr, 220, 3000)   # 2nd/3rd/4th harmonics of the bass
    y = x + HARMONIC_MIX * harm
    y = y - 0.5 * band(y, sr, 0, 45)                            # trim rumble the speaker only distorts on
    gain = 10 ** ((TARGET_DB - level_above(y, sr)) / 20)
    y = y * gain
    # Soft limiter: transparent below 0.7, rounds off peaks to PEAK.
    a = np.abs(y)
    knee = 0.7 * PEAK
    over = a > knee
    y[over] = np.sign(y[over]) * (knee + (PEAK - knee) * np.tanh((a[over] - knee) / (PEAK - knee)))
    return y, gain


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "assets/intro/intro.wav"
    dst = sys.argv[2] if len(sys.argv) > 2 else src
    x, sr = read(src)
    before = level_above(x, sr)
    y, gain = master(x, sr)
    write(dst, y, sr)
    print("intro audio: >300 Hz %.1f dB -> %.1f dB (gain %.1f dB), peak %.1f dBFS"
          % (before, level_above(y, sr), 20 * np.log10(gain), 20 * np.log10(np.abs(y).max())))
