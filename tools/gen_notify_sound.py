"""Notification tone for Android reminders: a soft two-note glockenspiel chime (~1.1 s).

Rising major sixth (G5 -> E6), bell-like partials, fast attack, gentle exponential decay, low level
(peak -6 dBFS) so it is noticeable but never harsh. Mono, 44.1 kHz Ogg Vorbis.
Output: tools/android_plugins/notify/src/main/res/raw/castle_chime.ogg (packed into castle_notify.aar;
Android plays it through the notification channel "castle_reminders_v2").
Run: python3 tools/gen_notify_sound.py
"""
import os

import numpy as np

import audio_dsp as A

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "android_plugins", "notify", "src", "main", "res", "raw", "castle_chime.ogg")


def bell(freq, dur, amp):
    t = np.arange(int(SR * dur)) / SR
    # Glockenspiel-like partials (slightly inharmonic) with shorter decays for higher partials.
    parts = [(1.0, 1.0, 2.2), (2.76, 0.32, 4.5), (5.40, 0.12, 7.0), (8.93, 0.05, 10.0)]
    y = np.zeros_like(t)
    for ratio, a, decay in parts:
        y += a * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-decay * t)
    attack = np.minimum(1.0, t / 0.004)
    return amp * y * attack


def main():
    total = 1.15
    y = np.zeros(int(SR * total))
    for start, f, amp in [(0.0, 783.99, 0.8), (0.16, 1318.51, 0.65)]:  # G5, E6
        n = bell(f, total - start, amp)
        i = int(SR * start)
        y[i:i + len(n)] += n[: len(y) - i]
    # Short fade-out so the file ends in silence.
    fade = int(SR * 0.12)
    y[-fade:] *= np.linspace(1.0, 0.0, fade)
    y = y / np.max(np.abs(y)) * 0.5  # peak -6 dBFS
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    A.write_ogg(OUT, y.astype(np.float32), SR, 5)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
