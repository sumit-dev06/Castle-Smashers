"""Converts the studio intro (art_source/intro/intercore_studio_cinematic_intro.html) into
assets/intro/intro.ogv (video) + assets/intro/intro.wav (audio) for Godot, without changing it.

How it stays identical:
- The page's own canvas code renders every frame in Chrome. requestAnimationFrame and
  performance.now are driven by a virtual 60 Hz clock, so timing, the light sweep, dust motion
  (which advances per frame) and the 24 fps-style grain are exactly what a 60 Hz screen shows.
- The page's own AAAMinimalistAudioEngine renders the score through an OfflineAudioContext
  (same nodes, same numbers), saved as 48 kHz 16-bit stereo WAV with the full reverb tail.
- The "CLICK TO BEGIN" gate exists only because browsers block sound until a click; a game
  intro starts on its own, so we start from the click moment (the black gate's 1.1 s fade-out is
  kept) and drop the REPLAY button.

Viewport 1600x720 CSS px = the game's 20:9 design view, so letterboxing and the font clamps match
what the page shows on a wide screen.

Needs: python playwright, Google Chrome, imageio-ffmpeg (bundled ffmpeg with libtheora).
Run: python3 tools/capture_intro.py
"""
import base64
import math
import os
import shutil
import subprocess
import sys
import tempfile

from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_source", "intro", "intercore_studio_cinematic_intro.html")
OUT = os.path.join(ROOT, "assets", "intro")
W, H, FPS = 1600, 720, 60
DURATION = 10.5          # TOTAL_DURATION in the page
GATE_FADE = 1.1          # #start-gate opacity transition
AUDIO_SECONDS = 16.5     # last note at 6.88 s + 3.8 s decay + 5.2 s hall reverb

VIRTUAL_CLOCK = """
(() => {
  let vt = 0; let cbs = [];
  performance.now = () => vt;
  window.requestAnimationFrame = (cb) => { cbs.push(cb); return cbs.length; };
  window.__step = (t) => { vt = t; const list = cbs; cbs = []; for (const cb of list) cb(t); };
})();
"""

# Renders the page's own audio class offline: only `this.ctx` is swapped for an OfflineAudioContext.
RENDER_AUDIO = """
async (seconds) => {
  const sr = 48000;
  const off = new OfflineAudioContext(2, Math.ceil(sr * seconds), sr);
  const eng = new AAAMinimalistAudioEngine();
  const Real = window.AudioContext;
  window.AudioContext = function () { return off; };
  eng.init();
  window.AudioContext = Real;
  eng.playBootSequenceScore();
  const buf = await off.startRendering();
  const l = buf.getChannelData(0), r = buf.getChannelData(1);
  const pcm = new Int16Array(l.length * 2);
  for (let i = 0; i < l.length; i++) {
    pcm[2*i] = Math.max(-1, Math.min(1, l[i])) * 32767;
    pcm[2*i+1] = Math.max(-1, Math.min(1, r[i])) * 32767;
  }
  let s = ''; const u8 = new Uint8Array(pcm.buffer);
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return btoa(s);
}
"""


def bezier_opacity(t):
    """CSS cubic-bezier(0.22, 1, 0.36, 1) from opacity 1 to 0 over GATE_FADE seconds."""
    x = min(max(t / GATE_FADE, 0.0), 1.0)
    p1x, p1y, p2x, p2y = 0.22, 1.0, 0.36, 1.0
    lo, hi = 0.0, 1.0
    for _ in range(40):
        s = (lo + hi) / 2
        bx = 3 * (1 - s) ** 2 * s * p1x + 3 * (1 - s) * s * s * p2x + s ** 3
        lo, hi = (s, hi) if bx < x else (lo, s)
    s = (lo + hi) / 2
    y = 3 * (1 - s) ** 2 * s * p1y + 3 * (1 - s) * s * s * p2y + s ** 3
    return 1.0 - y


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="intro_")
    frames = int(round(DURATION * FPS))
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", headless=True, args=["--autoplay-policy=no-user-gesture-required"])
        page = browser.new_page(viewport={"width": W, "height": H}, device_scale_factor=1)
        page.add_init_script(VIRTUAL_CLOCK)
        page.goto("file://" + SRC, wait_until="networkidle")
        page.evaluate("document.fonts.ready")
        page.evaluate("() => { window.__step(0); window.__step(0); }")
        if not page.evaluate("fontsReady"):
            sys.exit("fonts did not load (Cinzel/Inter come from Google Fonts: needs network)")
        # Audio: the page's own engine, rendered offline.
        wav = base64.b64decode(page.evaluate(RENDER_AUDIO, AUDIO_SECONDS))
        write_wav(os.path.join(OUT, "intro.wav"), wav)
        # Video: exactly what the click handler does, minus starting the (live) audio.
        page.evaluate("""() => {
            const g = document.getElementById('start-gate');
            g.style.transition = 'none'; g.style.opacity = '1'; g.style.display = 'flex';
            g.querySelector('.start-label').style.visibility = 'hidden';
            audioEngine.playBootSequenceScore = () => {};
            triggerSequence();
        }""")
        for i in range(frames + 1):
            t = i / FPS
            page.evaluate("([t, o]) => { document.getElementById('start-gate').style.opacity = o; window.__step(t * 1000); }",
                          [t, bezier_opacity(t)])
            page.screenshot(path=os.path.join(tmp, "f%04d.png" % i))
            if i % 60 == 0:
                print("frame", i, "/", frames)
        browser.close()
    subprocess.check_call([ffmpeg(), "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(tmp, "f%04d.png"),
                           "-c:v", "libtheora", "-q:v", "10", "-pix_fmt", "yuv420p", os.path.join(OUT, "intro.ogv")])
    shutil.copy(os.path.join(tmp, "f%04d.png" % int(3.2 * FPS)), os.path.join(ROOT, "build", "intro_card1.png"))
    shutil.copy(os.path.join(tmp, "f%04d.png" % int(8.2 * FPS)), os.path.join(ROOT, "build", "intro_card2.png"))
    shutil.rmtree(tmp)
    # Phone speakers drop the sub-bass score: add its harmonics and match the menu music level.
    subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "master_intro_audio.py"), os.path.join(OUT, "intro.wav")])
    print("wrote", os.path.join(OUT, "intro.ogv"), "and intro.wav")


def write_wav(path, pcm):
    import struct
    sr, ch = 48000, 2
    with open(path, "wb") as fh:
        fh.write(b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt " +
                 struct.pack("<IHHIIHH", 16, 1, ch, sr, sr * ch * 2, ch * 2, 16) + b"data" + struct.pack("<I", len(pcm)))
        fh.write(pcm)


if __name__ == "__main__":
    main()
