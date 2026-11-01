#!/usr/bin/env python3
"""Records gameplay clips with sound for the Play Store video, and a rough montage.

    python3 tools/record_trailer.py              # all clips + montage
    python3 tools/record_trailer.py l48 hellfire # only these clips (montage rebuilt from what exists)
    python3 tools/record_trailer.py --search 35 3 14   # headless search for good autoshot values

Uses Godot's Movie Maker (frame-perfect, game audio included) at 1920x1080 / 60 fps and ffmpeg
(from `pip3 install imageio-ffmpeg`) to make H.264 + AAC MP4 files in store_listing/video/.
A temporary override.cfg sets the window size while recording and is always removed.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "/Users/sumit/Downloads/Godot.app/Contents/MacOS/Godot")
OUT = os.path.join(ROOT, "store_listing", "video")
TMP = os.path.join(ROOT, "build", "tmp", "video")
FPS = 60
COMMON = ["--no-plan", "--no-intro", "--no-popups", "--sharp-bg"]

# name: (seconds, game args, montage start s, montage length s)
CLIPS = {
    "l48":       (18, ["--level=48", "--autoshot=40,0.86,0.9;36,0.9,0.8;44,0.84,1.0"], 0.8, 13.0),
    "hellfire":  (17, ["--level=27", "--hellfire=1.0"], 4.0, 12.0),
    "boss50":    (14, ["--level=50", "--autoshot=45,0.88,1.1;24,0.70,0.7"], 0.6, 11.0),
    "wheel35":   (12, ["--level=35", "--autoshot=24,0.88,1.1"], 0.6, 9.0),
    "flood21":   (12, ["--level=21", "--autoshot=33,0.70,1.1;24,0.70,1.1"], 0.6, 9.0),
    "logs11":    (15, ["--level=11", "--autoshot=24,0.70,0.7;30,0.94,1.1;33,1.00,1.1"], 0.6, 12.0),
    "wrecking39": (12, ["--level=39", "--autoshot=24,1.00,1.1;27,0.70,1.1"], 0.6, 9.0),
    "blossom3":  (11, ["--level=3", "--autoshot=24,0.70,0.7;39,0.76,1.1"], 0.6, 8.0),
}
ORDER = ["l48", "wheel35", "flood21", "logs11", "wrecking39", "blossom3", "boss50", "hellfire"]


def ffmpeg():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        sys.exit("ffmpeg missing: pip3 install imageio-ffmpeg")


def record(name, ff):
    secs, args, _, _ = CLIPS[name]
    avi = os.path.join(TMP, name + ".avi")
    override = os.path.join(ROOT, "override.cfg")
    if os.path.exists(override):
        sys.exit("override.cfg already exists; move it away first")
    with open(override, "w") as fh:
        fh.write("[display]\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n")
    try:
        print(f"recording {name} ({secs} s)...")
        subprocess.run([GODOT, "--path", ROOT, "--write-movie", avi, "--fixed-fps", str(FPS),
                        "--quit-after", str(secs * FPS), "--", *args, *COMMON],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1800)
    finally:
        os.remove(override)
    mp4 = os.path.join(OUT, f"clip_{name}.mp4")
    subprocess.run([ff, "-v", "error", "-y", "-i", avi, "-c:v", "libx264", "-preset", "slow", "-crf", "16",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", mp4], check=True)
    os.remove(avi)
    print("  ->", os.path.relpath(mp4, ROOT))


def montage(ff):
    parts = [n for n in ORDER if os.path.exists(os.path.join(OUT, f"clip_{n}.mp4"))]
    if not parts:
        return
    inputs, filters = [], []
    for i, n in enumerate(parts):
        _, _, start, length = CLIPS[n]
        inputs += ["-ss", str(start), "-t", str(length), "-i", os.path.join(OUT, f"clip_{n}.mp4")]
        f = 0.3
        filters.append(f"[{i}:v]fade=t=in:st=0:d={f},fade=t=out:st={length - f}:d={f},setpts=PTS-STARTPTS[v{i}];"
                       f"[{i}:a]afade=t=in:st=0:d={f},afade=t=out:st={length - f}:d={f},asetpts=PTS-STARTPTS[a{i}]")
    chain = "".join(f"[v{i}][a{i}]" for i in range(len(parts)))
    graph = ";".join(filters) + f";{chain}concat=n={len(parts)}:v=1:a=1[v][a]"
    out = os.path.join(OUT, "castle_smashers_montage.mp4")
    subprocess.run([ff, "-v", "error", "-y", *inputs, "-filter_complex", graph, "-map", "[v]", "-map", "[a]",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-r", str(FPS),
                    "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", out], check=True)
    print("montage ->", os.path.relpath(out, ROOT), "(" + ", ".join(parts) + ")")


def search(level, shots, secs, powers=True, fast=False, rapid=False):
    """Greedy headless search: best shot 1, then best shot 2 after it, ... Prints the autoshot string."""
    from concurrent.futures import ThreadPoolExecutor
    import re
    chosen = []

    def run(seq):
        r = subprocess.run([GODOT, "--headless", "--path", ROOT, "--fixed-fps", str(FPS), "--quit-after",
                            str(secs * FPS), "--", f"--level={level}", *COMMON[:3], *(["--autoshot-rapid"] if rapid else []),
                            "--autoshot=" + ";".join(seq)],
                           capture_output=True, text=True, timeout=300)
        m = re.search(r"AUTOSHOT_RESULT score=(\d+) blocks=(\d+)/(\d+) guards=(\d+) won=(\w+).*", r.stdout)
        if not m:
            return (-1, seq, "no result")
        score, guards, won = int(m[1]), int(m[4]), m[5] == "true"
        return (score + (100000 if won else 0) - guards * 5000, seq, m[0])

    for n in range(shots):
        # --fast: a coarse grid (24 shots instead of 132) for quick "can it be won" checks.
        angles, powers_, delays = (range(24, 58, 6), range(70, 101, 10), (1.0,)) if fast else \
            (range(24, 58, 3), range(70, 101, 6), (0.7, 1.1))
        cands = [chosen + [f"{a},{p / 100:.2f}" + (f",{d}" if powers else "")] for a in angles
                 for p in powers_ for d in (delays if powers else (0,))]
        with ThreadPoolExecutor(max_workers=7) as ex:
            res = sorted(ex.map(run, cands), key=lambda t: t[0], reverse=True)
        chosen = res[0][1]
        print(f"shot {n + 1}: {res[0][2]}  ->  --autoshot=\"{';'.join(chosen)}\"", flush=True)
        if "won=true" in res[0][2]:
            break


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--search":
        # python3 tools/record_trailer.py --search LEVEL [SHOTS] [SECONDS] [--no-powers]
        a = [x for x in sys.argv[2:] if not x.startswith("--")]
        search(int(a[0]), int(a[1]) if len(a) > 1 else 3, int(a[2]) if len(a) > 2 else 14, "--no-powers" not in sys.argv,
               "--fast" in sys.argv, "--rapid" in sys.argv)
        return
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    ff = ffmpeg()
    names = sys.argv[1:] or ORDER
    for n in names:
        if n not in CLIPS:
            sys.exit(f"unknown clip {n}; choose from {', '.join(CLIPS)}")
        record(n, ff)
    montage(ff)


if __name__ == "__main__":
    main()
