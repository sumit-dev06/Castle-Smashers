# Store listing media pack

Everything here is for Play Console. Nothing in this folder ships in the game (`.gdignore`).

| Folder / file | What it is | Where it goes in Play Console |
|---|---|---|
| `listing.md` | App name, short and full description, category, contacts | Grow users → Store presence → Main store listing |
| `feature_graphic_1024x500.png` | Feature graphic | Main store listing → Graphics → Feature graphic |
| `screenshots_designed/01..08_*.png` | 8 designed screenshots, 1920×1080, with headlines | Main store listing → Phone screenshots, and also 7-inch and 10-inch tablet screenshots. Upload in number order (01 first). |
| `screenshots/` | The same kind of frames without headlines | Spare; use if you prefer clean shots |
| `product_icons/<product_id>.png` | 512×512 icon per in-app product | Monetize → Products → In-app products → (product) → Icon. The file name is the product ID. |
| `video/` | Gameplay clips with game sound, 1920×1080, 60 fps (see below) | Not uploaded directly. Edit, put on YouTube, paste the link. |

## Video clips (`video/`)

These files are large, so they are **not in git**. They live only on this Mac in
`store_listing/video/`. Re-create them any time with:

```sh
python3 tools/record_trailer.py              # all clips + montage (about 6 minutes)
python3 tools/record_trailer.py l48 hellfire # only some clips
```

| File | Moment |
|---|---|
| `clip_l48.mp4` | Level 48 "Twin Airships": three shots, long chain, 3 stars |
| `clip_wheel35.mp4` | Level 35 "Runaway Wheel": one cyclone shot clears the fort, 13-hit chain, 3 stars |
| `clip_flood21.mp4` | Level 21 "Dockside Shacks": water tank bursts and floods the ship |
| `clip_logs11.mp4` | Level 11 "Sandstone Ruins": logs roll down the ramp, the tower falls, 3 stars |
| `clip_wrecking39.mp4` | Level 39 "Wrecking Ball": the swinging ball and a cyclone defeat all guards |
| `clip_blossom3.mp4` | Level 3 "Lantern Pagodas": fire pots burn the pagodas down |
| `clip_boss50.mp4` | Level 50 boss "The Baron's Airship": shield, core destroyed, reinforcements, 3 stars |
| `clip_hellfire.mp4` | Level 27: the full Hellfire strike from "HELLFIRE!" to the results screen |
| `castle_smashers_montage.mp4` | All of the above cut together (83 s) as a rough first draft |

### Making the Play video
1. Open the clips in any editor (CapCut, iMovie, DaVinci Resolve). Keep the best 2 to 4 seconds of each.
   A good order: level 48 first (strongest opening), then wheel, flood, logs, wrecking ball, boss,
   and Hellfire last.
2. Target 30 to 60 seconds. Put the action in the first 5 seconds; Play autoplays the video muted,
   so it must look good without sound.
3. Optional: add the headlines from `screenshots_designed/` as text, and the game logo at the end.
4. Export 1920×1080 (landscape), upload to **YouTube** as **Public or Unlisted**. Do not make it
   private, do not mark it "made for kids" in a way that blocks embedding, and turn off ads on the
   video (monetisation off).
5. Play Console → Main store listing → Video → paste the YouTube URL (`https://www.youtube.com/watch?v=...`).

### Play rules for the video
- Real gameplay only; no misleading footage. All clips here are real game recordings.
- No age-restricted content, and no ads in or on the video.
- It must be embeddable (YouTube default).
