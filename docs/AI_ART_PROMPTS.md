# AI Art Prompts

The owner generates these images with their image tool and drops them in `assets/art/ai/`
using the **file name** shown. Then run `python3 tools/cutout.py --preview`: originals move to
`art_source/ai/`, refined cut-outs go to `assets/art/ai/cut/`, and the game uses them
automatically. Until an image exists the game uses the SVG version.

**Received (2026-10-29):** all characters except `hero_fire_hit`, `hero_bomb_hit`, `hero_cyclone_hit`,
plus all 5 backgrounds. Still wanted: the three `_hit` poses, `icon_1024.png`, `feature_graphic.png`.

## Rules for every prompt
- Keep the **style block** below at the start of every prompt so all images match.
- Characters: **one character per image, centred, full body, plain flat pure white background
  (#FFFFFF)**, no shadow on the ground, no text. Plain white makes cutting out reliable.
- Square 1:1, at least 1024×1024.
- Generate 3–4 variants and keep the best. Same seed/reference image for all poses of one character
  if the tool supports it ("character reference" / "image prompt").
- Do not ask for "Angry Birds" in the prompt. It may copy their characters, which we can't ship.
- Check your tool's licence allows commercial use. Note the tool name in `docs/CREDITS.md`.

### Style block (paste first)
> Stylized 3D cartoon render for a mobile game, soft rounded shapes, glossy subsurface-like
> materials, big expressive eyes, warm saturated colours, soft studio lighting from the top left,
> subtle rim light, clean smooth surfaces, no outlines, cute and funny, high detail, Pixar-like
> mobile game character art

### Negative (if the tool supports it)
> text, watermark, logo, bird, beak, pig, slingshot, outline, black lines, background scenery,
> ground shadow, cropped, multiple characters, realistic, scary, blood

## Characters (priority 1)
| File | Prompt (after style block) |
|---|---|
| `hero_stone_idle.png` | A round grey boulder character named Rocky, perfectly spherical stone body with subtle cracks and a small tuft of green moss on top, thick heavy stone eyebrows, grumpy determined eyes, small frowning mouth, tiny stubby stone arms crossed, no legs, front three-quarter view, plain white background |
| `hero_fire_hit.png` / `hero_bomb_hit.png` / `hero_cyclone_hit.png` | Same character as its idle image, eyes squeezed shut, dizzy, small stars around head, plain white background |
| `hero_stone_hit.png` | Same Rocky boulder character, eyes squeezed shut, cheeks puffed, dizzy expression, small stars around head, plain white background |
| `hero_fire_idle.png` | A round orange clay pot character named Blaze, glossy terracotta body with a cream band around the middle, bright flames rising from the open top like wild hair, fierce excited eyes, open grinning mouth, tiny arms in fists, front three-quarter view, plain white background |
| `hero_bomb_idle.png` | A round navy-black cast-iron bomb character named Boomer, shiny metal surface with a gold band, short curly fuse on top with a sparkling lit tip, huge happy toothy grin, wide eager eyes, tiny arms raised cheerfully, front three-quarter view, plain white background |
| `hero_cyclone_idle.png` | A small whirlwind character named Twister, pale teal and white swirling spiral body shaped like a soft tornado, two green leaves orbiting it, dizzy happy spiral-ish eyes, giggling open mouth, cute, front view, plain white background |
| `soldier_idle.png` | A short round chubby medieval soldier, blue tunic with gold trim, round steel kettle helmet with gold rim, small round blue shield with gold star, rosy cheeks, brave smile, big eyes, tiny legs and boots, standing, facing right, three-quarter view, plain white background |
| `soldier_cheer.png` | Same chubby blue medieval soldier jumping with joy, both arms up, shield raised, eyes closed happily, open mouth cheering, facing right, plain white background |
| `soldier_ko.png` | Same chubby blue medieval soldier sitting on the ground dazed, helmet tilted over one eye, swirly dizzy eyes, little stars circling head, comic and not hurt, plain white background |
| `archer_idle.png` | A short round chubby enemy archer, red pointed hood with a feather, maroon tunic, brown leather quiver with arrows on back, holding a small wooden bow, mischievous squinting eyes, smug grin, tiny legs, standing, facing left, three-quarter view, plain white background |
| `archer_shoot.png` | Same chubby red-hooded archer drawing his bow fully, arrow nocked, one eye closed aiming, tongue out in concentration, facing left, plain white background |
| `archer_ko.png` | Same chubby red-hooded archer flat on his back, bow broken, swirly dizzy eyes, little stars over head, comic, plain white background |

## Backgrounds (priority 2)
Landscape **16:9 or wider (e.g. 2752×1536)**. **No characters, no buildings in the middle-left
ground area**, empty flat grassy ground across the bottom 20% (the game draws the ground and
fortress itself).

| File | Prompt (after style block, replace "character" wording) |
|---|---|
| `bg_emerald_valley.png` | Wide panoramic mobile game background, sunny green valley with rolling hills, pine trees, distant snowy mountains, bright blue sky with fluffy white clouds, soft atmospheric haze, a small cream castle with red roofs far away on a hill on the left, flat empty grass meadow across the bottom, no characters, no text |
| `bg_golden_riverlands.png` | Wide panoramic mobile game background, golden late-afternoon river valley, wheat fields, wooden windmills on hills, warm orange-pink sky, flat empty grass across the bottom, no characters, no text |
| `bg_stormy_crags.png` | Wide panoramic mobile game background, dramatic grey rocky cliffs with waterfalls, dark stormy clouds, distant lightning, cool blue-grey light, flat empty rocky grass ground across the bottom, no characters, no text |
| `bg_scarlet_highlands.png` | Wide panoramic mobile game background, autumn highlands with red and orange trees, old stone ruins, warm hazy sunlight, flat empty grass across the bottom, no characters, no text |
| `bg_iron_citadel.png` | Wide panoramic mobile game background, dark volcanic land with a huge iron fortress far in the distance, glowing lava rivers, smoky orange sky, red banners, flat empty dark ground across the bottom, no characters, no text |

## Branding (priority 3)
| File | Prompt |
|---|---|l
| `icon_1024.png` | (style block) App icon, square, close-up of the round blue-helmeted chubby soldier character grinning next to a round grumpy grey boulder character, bright blue sky background, bold and readable at small size, centred, no text |
| `logo_title.png` | (style block) Game title logo reading "CASTLE SMASHERS", chunky rounded 3D letters, golden-yellow with orange gradient and thick dark brown 3D extrusion, a small cracked stone tower behind the text, plain white background |
| `feature_graphic.png` | (style block) Wide 1024×500 banner: a wooden wheeled catapult launching a grumpy round boulder character toward a crumbling cartoon fortress with red-hooded archers falling off, chubby blue soldiers cheering on the left, sunny green valley, no text |

Note: AI tools often misspell words. If the logo text is wrong, generate it without text and we
lay out the title in-engine with Lilita One.

---

# Stage art for the 50-level campaign (added 2026-10-29)

The five old realm backgrounds above are replaced by five new realms that match the owner's
reference screenshots (Desert Ruins, Sky Islands, Pirate Harbor, Crystal Mines, Moonlit Twin
Towers, Desert Fort). The old files stay in the repo until the new ones arrive.

## How a level scene is assembled (read this before generating)
Each level is built from **separate images**, never one big painting. Code puts them together and
places the physics on top, so the images must follow the rules exactly.

```
 ┌──────────────────────────────────────────────────────────────┐
 │  BACKGROUND (bg_*)  far scenery, blurred + hazed by the game  │
 │                                                              │
 │  [LEDGE]                                  [BASE]   [BASE]    │  ← flat tops = where things stand
 │  catapult                 GAP             fortress fortress  │
 │  ███████        water / chasm / sky       ███████  ████      │
 │FG ███████                                 ███████  ████   FG │  ← foreground corners, blurred
 └──────────────────────────────────────────────────────────────┘
```

| Piece | File name | What it is | Background of the image |
|---|---|---|---|
| Background | `bg_<realm>_<variant>.png` | Far scenery with an open gap area in the lower part. **Sharp.** The game blurs and hazes it (tunable) | Full painting |
| Catapult ledge | `stage_ledge_<realm>.png` | The raised ground our catapult and soldiers stand on (left side) | **Plain white #FFFFFF** |
| Fortress base, wide | `stage_base_<realm>_wide.png` | Big piece of land the main fortress stands on | **Plain white #FFFFFF** |
| Fortress base, small | `stage_base_<realm>_small.png` | Smaller piece for a second or third building | **Plain white #FFFFFF** |
| Foreground left | `fg_<realm>_left.png` | Dark close-up frame for the bottom-left corner | **Plain white #FFFFFF** |
| Foreground right | `fg_<realm>_right.png` | Dark close-up frame for the bottom-right corner | **Plain white #FFFFFF** |

The game draws these itself, so **do not** put them in any image: the catapult, soldiers, archers,
fortress blocks, rope bridges, ladders, lanterns, banners, water in the gap (animated), UI and text.

## Hard rules (the code depends on them)
1. **Pieces on white:** one object, centred, with at least 5% white margin on every side. Nothing
   touches the image edge. No white, cream or very pale grey on the object itself (the cutout tool
   removes white from the border inward). No ground shadow, no reflections, no water around it.
2. **Flat tops:** ledges and bases must have **one straight, perfectly horizontal top edge** across
   at least 80% of their width. Grass, sand and moss may hang **down** over the edge but must not
   stick **up** more than a few pixels. Blocks are placed on this line.
3. **Pure side view** (orthographic, like a 2D platformer). No perspective, no top surface visible,
   no three-quarter angle.
4. **Light from the upper left** on every piece, neutral daylight. The game tints pieces to match
   night, sunset or cave light, so don't paint the time of day into the pieces.
5. **Backgrounds:** the widest size your tool allows, at least **2048 px wide, 2.4:1 to 2.7:1**
   (like the last batch, 2056×765). Horizon at **45–55% of the height**. The **lower 35% is the open
   gap** (water, canyon floor, sea, lava, clouds) with **no cliffs, platforms or buildings in the
   lower-left 30% or the lower-right 55%**. Big landmarks go in the upper half only. The
   background must look good blurred, so prefer large clear shapes over tiny detail.
6. **No text, logos, UI, characters, people, animals in the foreground, catapults or weapons.**
7. Generate 3–4 variants and keep the one that follows the rules best. **Generate realm 1
   (Blossom Valley) first.** I'll wire it up and check it in game before you make the rest.

## Environment style block (paste first in every prompt below)
> Stylized hand-painted 3D cartoon environment art for a premium mobile game, glossy rounded
> shapes, chunky readable forms, warm saturated colours, soft global illumination, gentle rim
> light, crisp clean edges, rich but not noisy detail, cosy fantasy medieval world, high quality

### Negative (if supported)
> text, letters, logo, watermark, UI, people, characters, soldiers, animals in foreground, catapult,
> slingshot, bird, pig, perspective view, top-down, isometric, photo, realistic, dark muddy colours,
> blurry, cropped, frame, border

---

## Realm 1: Blossom Valley (levels 1–10), reference: Moonlit Twin Towers

| File | Prompt (after the style block) |
|---|---|
| `bg_blossom_night.png` | Ultra-wide side-view panoramic background, moonlit Japanese-inspired valley at night, a huge glowing full moon in the upper middle, deep blue starry sky with soft clouds, a multi-roof pagoda castle with warm lit windows on a distant hill in the upper left, paper lanterns glowing along winding paths far away, pink cherry blossom trees in the middle distance, a calm river winding through the lower third with moonlight reflections, the lower third is open water and soft riverbank with no cliffs or buildings in the lower left and lower right, horizon at mid height, no characters, no text |
| `bg_blossom_dawn.png` | Same composition: ultra-wide side-view panoramic background, the same Japanese-inspired valley at sunrise, soft pink and gold sky, mist in the valley, pagoda castle on a distant hill in the upper left, rows of pink cherry blossom trees, paper lanterns on far paths, a calm river across the lower third catching the sunrise, lower third open water with no cliffs or buildings in the lower left and lower right, horizon at mid height, no characters, no text |
| `stage_ledge_blossom.png` | Isolated game asset, pure side view, a wide raised ground platform made of mossy grey stone retaining wall with fitted blocks, a thick strip of bright green grass on top with a few small pink flowers and fallen cherry petals, perfectly flat horizontal top edge, the stone wall continues down and ends in a rough broken rocky bottom, wide shape about 2.5 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow |
| `stage_base_blossom_wide.png` | Isolated game asset, pure side view, a wide rocky cliff block for a fortress to stand on, grey and blue-grey rounded rocks with moss, thick bright green grass on top, perfectly flat horizontal top edge across the whole width, rugged rock sides narrowing slightly toward a rough bottom, about 2.5 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow |
| `stage_base_blossom_small.png` | Isolated game asset, pure side view, a small narrow rock pillar with green grass on top, grey mossy rounded rocks, perfectly flat horizontal top edge, about as wide as tall, single object centred with white margin, plain flat pure white background, no shadow |
| `fg_blossom_left.png` | Isolated game asset, close-up foreground framing element for the bottom-left corner of a game screen, a dark wooden fence section with a rope and a cluster of pink cherry blossom branches and leaves, slightly darker and more saturated than the scene, shapes fill the lower-left and leave the upper-right of the image empty, plain flat pure white background |
| `fg_blossom_right.png` | Isolated game asset, close-up foreground framing element for the bottom-right corner of a game screen, a dense cluster of pink cherry blossom branches with dark green leaves and a mossy rock, shapes fill the lower-right and leave the upper-left of the image empty, plain flat pure white background |

## Realm 2: Desert Ruins (levels 11–20), references: Desert Fort, Desert Ruins

| File | Prompt (after the style block) |
|---|---|
| `bg_desert_day.png` | Ultra-wide side-view panoramic background, sunny desert canyon, tall red-orange sandstone mesas and a huge natural rock arch in the upper middle, tall waterfalls falling from the cliffs in the middle distance, a sand-coloured castle with red roofs on a far cliff in the upper left, palm trees and a windmill far away, bright blue sky with fluffy clouds, a turquoise river across the lower third, lower third open water and sandy riverbed with no cliffs or buildings in the lower left and lower right, horizon at mid height, no characters, no text |
| `bg_desert_sunset.png` | Ultra-wide side-view panoramic background, ancient desert ruins at golden sunset, crumbling stone aqueducts with tall arches and ruined towers on rock pillars in the middle distance, the sun low on the horizon in the centre, warm orange and violet sky, small waterfalls, palm trees, a turquoise river with sunlight sparkles across the lower third, lower third open water with no cliffs or buildings in the lower left and lower right, horizon at mid height, no characters, no text |
| `stage_ledge_desert.png` | Isolated game asset, pure side view, a wide raised ruin platform made of large weathered sandstone blocks with green vines and small cracks, a dusty sand and dry grass strip on top, perfectly flat horizontal top edge, the stone continues down into a rough broken bottom, about 2.5 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow |
| `stage_base_desert_wide.png` | Isolated game asset, pure side view, a wide red sandstone rock plateau for a fortress to stand on, layered orange and red rock strata, a few tufts of green desert grass and small cactus hanging over the edge, perfectly flat horizontal top edge across the whole width, rugged sides, rough bottom, about 2.5 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow |
| `stage_base_desert_small.png` | Isolated game asset, pure side view, a narrow sandstone rock pillar with a small ruined stone arch carved in its side, green vines, perfectly flat horizontal top edge, about as wide as tall, single object centred with white margin, plain flat pure white background, no shadow |
| `fg_desert_left.png` | Isolated game asset, close-up foreground framing element for the bottom-left corner, two green saguaro cactus with small pink flowers, a dark weathered wooden fence post, dry grass, shapes fill the lower-left and leave the upper-right empty, plain flat pure white background |
| `fg_desert_right.png` | Isolated game asset, close-up foreground framing element for the bottom-right corner, large dark green palm leaves and a round cactus with flowers, shapes fill the lower-right and leave the upper-left empty, plain flat pure white background |

## Realm 3: Pirate Harbor (levels 21–30), reference: Pirate Harbor

| File | Prompt (after the style block) |
|---|---|
| `bg_harbor_sunset.png` | Ultra-wide side-view panoramic background, tropical pirate harbor at sunset, a tall stone lighthouse on a rocky jungle island with waterfalls in the upper left, distant pirate ships with cream sails on the horizon, palm-covered islands, the sun setting in the centre with orange and pink sky, seagulls far away, calm sparkling sea across the lower third with sunset reflections, lower third open sea with no rocks, docks or ships in the lower left and lower right, horizon at mid height, no characters, no text |
| `bg_harbor_storm.png` | Same composition: ultra-wide side-view panoramic background, the same pirate harbor at dusk under a dramatic storm, dark teal and purple clouds with a bright break of light, the lighthouse beam shining, distant ships with sails, choppy blue sea across the lower third, lower third open sea with nothing in the lower left and lower right, horizon at mid height, no characters, no text |
| `stage_ledge_harbor.png` | Isolated game asset, pure side view, a wide wooden pier deck standing on thick round wooden posts, planks with iron nails, coiled rope around the posts, perfectly flat horizontal top edge made of deck planks, posts going down and ending at a cut line at the bottom, about 2.5 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow, no water |
| `stage_base_harbor_wide.png` | Isolated game asset, pure side view, the wooden hull of a large pirate ship without masts, sails or cabins, dark brown curved planks with iron bands, a row of closed square gunports, a skull carving on the bow on the left, a perfectly flat horizontal top deck edge across the whole width, about 3 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow, no water |
| `stage_base_harbor_small.png` | Isolated game asset, pure side view, a small square wooden dock platform on four thick posts with barnacles and seaweed on the lower part, flat horizontal top edge, about as wide as tall, single object centred with white margin, plain flat pure white background, no shadow, no water |
| `fg_harbor_left.png` | Isolated game asset, close-up foreground framing element for the bottom-left corner, thick dark wooden pier posts tied with rope, a burning torch on a post, a barrel, shapes fill the lower-left and leave the upper-right empty, plain flat pure white background |
| `fg_harbor_right.png` | Isolated game asset, close-up foreground framing element for the bottom-right corner, dark tropical leaves and two wooden pier posts with rope, shapes fill the lower-right and leave the upper-left empty, plain flat pure white background |

## Realm 4: Crystal Mines (levels 31–40), reference: Crystal Mines

| File | Prompt (after the style block) |
|---|---|
| `bg_mines_crystal.png` | Ultra-wide side-view panoramic background, a huge underground cave, tall dark blue-grey rock walls with openings showing blue light, glowing blue crystal clusters, distant wooden mine scaffolds, a wooden mining village with warm lit windows high on a ledge in the upper middle, a waterfall pouring into a glowing turquoise underground lake, cool blue cave light mixed with warm lantern glow, the lower third is the open dark lake and chasm with no ledges or buildings in the lower left and lower right, horizon at mid height, no characters, no text |
| `bg_mines_lava.png` | Same composition: ultra-wide side-view panoramic background, a deep volcanic mine cavern, dark rock walls lit orange from below, rivers of glowing lava, distant iron foundry chimneys and wooden cranes in the upper middle, smoke and floating embers, the lower third is an open glowing lava chasm with no ledges or buildings in the lower left and lower right, horizon at mid height, no characters, no text |
| `stage_ledge_mines.png` | Isolated game asset, pure side view, a wide rocky cave ledge, dark grey-brown rock with a wooden mine support beam frame in front, a short section of mine rail lying flat on top, a small cluster of glowing blue crystals at one end, perfectly flat horizontal top edge, rough rocky bottom, about 2.5 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow |
| `stage_base_mines_wide.png` | Isolated game asset, pure side view, a wide dark rock plateau with thin glowing orange lava cracks in its sides and small blue crystals, perfectly flat horizontal top edge across the whole width, rugged sides, rough bottom, about 2.5 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow |
| `stage_base_mines_small.png` | Isolated game asset, pure side view, a narrow dark rock pillar held together with wooden mine beams and iron brackets, flat horizontal top edge, about as wide as tall, single object centred with white margin, plain flat pure white background, no shadow |
| `fg_mines_left.png` | Isolated game asset, close-up foreground framing element for the bottom-left corner, a wooden mine cart full of glowing blue crystals on a short rail, dark rocks, i shapes fill the lower-left and leave the upper-right empty, plain flat pure white background |
| `fg_mines_right.png` | Isolated game asset, close-up foreground framing element for the bottom-right corner, dark jagged cave rocks with a big glowing blue crystal cluster, shapes fill the lower-right and leave the upper-left empty, plain flat pure white background |

## Realm 5: Sky Islands (levels 41–50), reference: Sky Islands

| File | Prompt (after the style block) |
|---|---|
| `bg_sky_day.png` | Ultra-wide side-view panoramic background, a bright fantasy sky world, many floating rock islands with grass, trees and waterfalls pouring off their edges, a fairy-tale castle with many red-roofed towers on a big floating island in the upper right, red and white striped hot air balloons and a small wooden airship in the distance, blue sky, the lower third is a soft sea of white clouds with no islands in the lower left and lower right, horizon at mid height, no characters, no text |
| `bg_sky_golden.png` | Same composition: ultra-wide side-view panoramic background, the same floating sky islands at golden hour, warm gold and pink light, long soft cloud shadows, distant balloons and a dark iron airship fortress far away in the upper middle, waterfalls glowing in the sun, lower third a sea of golden clouds with nothing in the lower left and lower right, horizon at mid height, no characters, no text |
| `stage_ledge_sky.png` | Isolated game asset, pure side view, a wide grassy cliff top with small white and yellow flowers and a short rope fence on wooden posts at the back, perfectly flat horizontal top edge, brown and grey rock below that ends in a rough bottom, about 2.5 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow |
| `stage_base_sky_wide.png` | Isolated game asset, pure side view, a wide floating rock island, thick bright green grass on top, a few small bushes on the edges, a jagged rocky underside tapering to points with a few hanging roots, perfectly flat horizontal top edge across the whole width, about 2 times wider than tall, single object centred with white margin, plain flat pure white background, no shadow |
| `stage_base_sky_small.png` | Isolated game asset, pure side view, a small floating rock island with grass on top and a jagged pointed rocky underside, flat horizontal top edge, about as wide as tall, single object centred with white margin, plain flat pure white background, no shadow |
| `fg_sky_left.png` | Isolated game asset, close-up foreground framing element for the bottom-left corner, thick wooden fence posts with a sagging rope, green grass and small white daisies, shapes fill the lower-left and leave the upper-right empty, plain flat pure white background |
| `fg_sky_right.png` | Isolated game asset, close-up foreground framing element for the bottom-right corner, a leafy green tree branch and a wooden post with rope, shapes fill the lower-right and leave the upper-left empty, plain flat pure white background |

## Boss pieces (after the realm sets)
| File | Prompt (after the style block) |
|---|---|
| `boss_siege_wheels.png` | Isolated game asset, pure side view, a long heavy wooden siege tower chassis with four big iron-rimmed wooden wheels, no tower on top, perfectly flat horizontal top deck, about 3 times wider than tall, plain flat pure white background, no shadow |
| `boss_airship_balloon.png` | Isolated game asset, pure side view, a huge dark iron-and-red striped airship balloon envelope with riveted metal bands and ropes hanging down, no gondola, plain flat pure white background, no shadow |
| `boss_airship_deck.png` | Isolated game asset, pure side view, a long wooden airship gondola hull with iron plating, small propellers at the back, perfectly flat horizontal top deck, about 3 times wider than tall, plain flat pure white background, no shadow |

## Checklist before dropping files in
- File names exactly as in the tables above (lowercase, `.png`).
- Pieces: white background, nothing touching the edges, flat top, side view.
- Backgrounds: open lower third, horizon around the middle, at least 2048 px wide.
- Then run `python3 tools/cutout.py --preview` (it handles `stage_`, `fg_` and `boss_` images
  once Phase A is done) and list the tool used in `docs/CREDITS.md`.

## Redo list after the first stage-art drop (2026-10-30)
`tools/cutout.py` skips stage/fg/boss pieces that are not on a plain white background.

| File | Problem / status | Prompt |
|---|---|---|
| `fg_blossom_left.png` | Painted full scene, no white background: skipped | Same prompt as above, and add:  Isolated game asset, close-up foreground framing element for the bottom-left corner of a game screen, a dark wooden fence section with a rope and a cluster of pink cherry blossom branches and leaves, slightly darker and more saturated than the scene, shapes fill the lower-left and leave the upper-right of the image empty, plain flat pure white background |"isolated on a plain flat pure white background, nothing behind the plants, no sky, no scenery" |
| `fg_sky_right.png` | Painted full scene, no white background: skipped | Isolated game asset, close-up foreground framing element for the bottom-right corner, a leafy green tree branch and a wooden post with rope, shapes fill the lower-right and leave the upper-left empty, plain flat pure white background | |
| `boss_galleon_hull.png` | New (levels 23, 26, 30 use a placeholder) | Isolated game asset, pure side view, a heavy pirate galleon hull with dark wood planks, gold trim and a row of cannon ports, no masts, no sails, perfectly flat horizontal top deck, about 2.6 times wider than tall, plain flat pure white background, no shadow |
| `boss_mine_cart.png` | New (levels 33, 37, 40 use a placeholder) | Isolated game asset, pure side view, a long iron mine cart with riveted plates, glowing orange seams and four small iron wheels, perfectly flat horizontal top, about 3.5 times wider than tall, plain flat pure white background, no shadow |

## Phase C optional art (added after Phase C)
These pieces work today as SVG. AI versions are optional. `tools/cutout.py` only handles `stage_`,
`fg_` and `boss_` pieces so far, so a drop of these files also needs the pipeline and sizing code
extended (ask before generating a batch). Use the environment style block first, then the prompt.
All on a plain flat pure white background, pure side view, no shadow, nothing touching the edges.

| File | Prompt (after the style block) |
|---|---|
| `mechanism_crusher.png` | Isolated game asset, pure side view, a heavy iron crusher weight block with riveted plates, a yellow-black hazard stripe and a row of steel spikes along the bottom edge, flat top with an iron ring, about 1.6 times wider than tall |
| `mechanism_geyser.png` | Isolated game asset, a tall straight vertical column of rushing white-blue water spray with foam at the top, soft edges, about 5 times taller than wide, no ground, no rocks |
| `mechanism_hook.png` | Isolated game asset, pure side view, a small black iron crane hook with a short chain link on top |
| `mechanism_frame.png` | Isolated game asset, pure side view, a wooden crane gantry: two straight upright posts and a straight horizontal top beam with iron brackets, open in the middle, about 1.2 times taller than wide |
| `block_boulder.png` | Isolated game asset, a round grey granite boulder with moss patches and small cracks, perfectly round outline |
| `block_crystal_block.png` | Isolated game asset, pure side view, a square block of glowing teal-violet crystal with faceted shards, straight square outline |
| `block_crystal_pillar.png` | Isolated game asset, pure side view, a tall straight rectangular pillar of glowing teal-violet crystal, about 4 times taller than wide |
| `block_iron_block.png` | Isolated game asset, pure side view, a square riveted dark iron block with bolted corner plates, straight square outline |
| `block_iron_beam.png` | Isolated game asset, pure side view, a long straight riveted dark iron girder beam, about 6 times wider than tall |
| `boss_crown.png` | Isolated game asset, a small chunky gold crown with three points and red, blue and green gems |

### Boss characters (optional, same rules as the archer images)
Each boss is the archer character in a bigger, richer outfit. Same pose set as the archer
(`_idle`, `_shoot`, `_ko`), full body, feet visible, facing left, on white.

| File | Outfit |
|---|---|
| `boss_warlord_idle.png` | Siege Warlord: red armour with a black fur cape and a big double-curved bow |
| `boss_sultan_idle.png` | Sandstone Sultan: sand-gold robes, a turban with a red gem, a curved gold bow |
| `boss_ironhook_idle.png` | Captain Ironhook: pirate coat, tricorn hat, an iron hook hand and a crossbow |
| `boss_forgemaster_idle.png` | The Forgemaster: leather apron, soot, goggles, a glowing orange iron crossbow |
| `boss_baron_idle.png` | The Iron Baron: dark steel plate armour, a tall plumed helm, a heavy iron longbow |

**Update (Phase D start):** `tools/cutout.py` now accepts `block_` and `mechanism_` pieces (and
`boss_crown`). They are drawn at the SVG's size, so trim nothing off and keep the outline filling
the image: a block image must be the block's exact shape. One image covers all damage stages; the
game darkens it as it breaks. Run `python3 tools/cutout.py --preview` after the drop.


## Phase D materials (optional art)
Same rules as the other block images: isolated, pure side view, exact block shape filling the image,
thin dark-brown outline `#3a2212`, glossy cartoon, on white. One image covers every damage stage.

| File | Prompt |
|---|---|
| `block_ice_block.png` | Isolated game asset, pure side view, a square block of clear pale-blue ice with a frosty white top edge, small trapped bubbles and glints, straight square outline |
| `block_ice_slab.png` | Same ice style, a wide flat slab of ice about 4.5 times wider than tall |
| `block_ice_pillar.png` | Same ice style, a tall ice pillar about 3.5 times taller than wide |
| `block_rune_crystal.png` | Isolated game asset, pure side view, a square violet stone socket with small silver rune marks in the corners, holding a big glowing purple faceted gem in the centre, straight square outline |
| `block_iron_beam_bent.png` | Isolated game asset, pure side view, a riveted dark iron girder bent in the middle into a shallow V (each half tilted 16 degrees down to a bolt at the bend) |


## Phase D mechanisms (optional art)
Same rules: isolated, pure side view, thin dark-brown outline `#3a2212`, glossy cartoon, on white,
filling the image at the SVG's proportions.

| File | Prompt |
|---|---|
| `mechanism_lever_base.png` | Isolated game asset, a small carved grey stone block with a dark slot on top and a brass ring around the slot, wider than tall |
| `mechanism_lever_handle.png` | Isolated game asset, a wooden lever stick with an iron collar at the bottom and a round glossy red knob on top, vertical |
| `mechanism_windmill_arm.png` | Isolated game asset, one windmill sail: a wooden spar with a cream canvas sail on a wooden lattice, horizontal, the bare spar end on the left |
| `mechanism_windmill_hub.png` | Isolated game asset, a round riveted iron gear hub with ten teeth and a glowing orange cracked core in the middle, front view |
| `mechanism_shield_plate.png` | Isolated game asset, a long riveted dark iron shield plate with rounded ends and a red painted band in the middle, horizontal |
| `mechanism_rune_switch.png` | Isolated game asset, a round carved stone disc with a glowing cyan rune (a vertical line crossed by an X) and a pale centre stone, front view |
| `mechanism_trapdoor.png` | Isolated game asset, a flat wooden trap door of planks with two iron bands and an iron ring pull, very wide and thin |


## Phase D boss rig (optional art)
| File | Prompt |
|---|---|
| `block_power_core.png` | Isolated game asset, pure side view, a square riveted iron cage block with three vertical bars over a glowing bright-blue magic orb, straight square outline |
| `block_cannon_turret.png` | Isolated game asset, pure side view, a dark iron cannon on a small wooden carriage with two wheels, barrel pointing left, wider than tall |
| `cannonball.png` | Isolated game asset, a round dark iron cannonball with a soft highlight |
| `engineer_hat.png` | Isolated game asset, a yellow cartoon hard hat seen from the side |
| `engineer_hammer.png` | Isolated game asset, a small iron hammer with a wooden handle, vertical |


## Phase D modes (optional art)
| File | Prompt |
|---|---|
| `block_treasure_chest.png` | Isolated game asset, pure side view, a red wooden treasure chest with gold bands, a gold lock and a rounded lid, wider than tall |
| `icon_mode_heist.png` … `icon_mode_daily.png` | Glossy cartoon UI icons, 1:1, thick dark-brown outline: a treasure chest; an hourglass; a target with an arrow; a blue shield with waves; a ship with a red arrow; a gold crown; a calendar with a green tick |


## Phase D meta screens (optional art)
Glossy cartoon UI icons, 1:1, thick dark-brown outline `#3a2212`, on white, no text. They replace the
vector icons in `assets/art/svg/` of the same name (run through `tools/cutout.py`).

| File | Prompt |
|---|---|
| `icon_spin.png` | A small prize wheel with gold, purple and blue wedges and a red pointer on top |
| `icon_daily.png` | A desk calendar with red rings on top and a big green tick on the page |
| `icon_shop.png` | A red treasure chest with gold bands, lid half open, gold coins inside |
| `icon_achievements.png` | A gold trophy cup with two handles and a star on the front |
| `icon_challenges.png` | Two crossed steel swords with gold hilts |
| `icon_events.png` | A red banner flag with a gold star, hanging from a short pole |
| `icon_upgrades.png` | A blacksmith hammer with a green up arrow beside it |
| `icon_skins.png` | A painter's palette with red, blue, yellow and green paint blobs |
| `icon_trail.png` | A small glowing gold comet with a sparkly tail going up-right |
| `icon_mail.png` | A cream envelope with a red wax seal |
| `icon_secret.png` | A rolled old map scroll tied with a red ribbon, a gold X on the open edge |
| `icon_crown.png` | A gold crown with three points and red and blue jewels |
| `icon_weapon_catapult.png` / `_ballista.png` / `_trebuchet.png` | Side-view wooden siege engines: a wheeled catapult with a bucket arm; a wheeled giant crossbow; a tall trebuchet with a counterweight box |
| `gem.png` | A faceted purple gem with a white highlight |
| `blueprint.png` | A rolled-open parchment with a red catapult sketch |
| `chest_open.png` | A red treasure chest with the lid wide open, gold light and coins spilling out |


# Skins and siege engines, higher-detail versions (added 2026-10-31)
The game already ships generated overlays (`skin_<id>_base` / `skin_<id>_arm`, built by
`tools/gen_art.py`) that change each skin's silhouette. These prompts are for painted versions.
Each skin needs **two separate images**: the base (frame + wheels) and the throwing arm with cup,
in the same pose as `assets/art/svg/catapult_base.svg` / `catapult_arm.svg`: side view facing
right, arm resting at about 45° up-left, flat even lighting, plain white background, no shadow on
the ground, thin dark-brown `#3a2212` outline. Files go to `assets/art/ai/skin_<id>_base.png` and
`skin_<id>_arm.png`, then run `python3 tools/cutout.py --preview`.

Style block (paste first): *"2D mobile game asset, glossy cartoon style like a premium casual
strategy game, chunky readable shapes, soft cel shading with one highlight, thin dark brown
outline, side view, isolated on pure white background, no text, no ground shadow"*

| Skin id | Prompt (after the style block) |
|---|---|
| `sakura` (Sakura Shrine) | "shrine catapult in red-lacquered wood with black iron, small pagoda roof over the frame, cherry-blossom branches wrapped round the arm, paper lantern hanging from the arm, cup shaped like a temple bell" |
| `desert_gold` (Sunforged) | "sun-temple catapult in sandstone and polished gold, sun-disc emblem on the front, scarab ornaments, cup shaped like a golden lotus" |
| `pirate` (Dread Corsair) | "pirate catapult built from ship parts, barrel-hoop wheels, rope rigging, small black skull flag, anchor counterweight, cup shaped like a rowboat" |
| `forge` (Magma Foundry) | "foundry catapult in blackened iron with glowing orange magma cracks, bellows at the back, chimney with a puff of smoke, cup shaped like a crucible" |
| `royal` (King's Parade) | "royal parade catapult, white and gold with royal-blue cloth banners, crown finial on the arm tip, gold-rimmed wheels, velvet-lined cup" |
| `sky` (Stormwing) | "sky-island catapult in white enamel and brass, feathered wing fins on the frame, small propeller, lightning-bolt trim, cloud-shaped wheel caps" |
| `shadow` (Night Wraith) | "haunted catapult in dark purple-black wood, ghostly teal glow in the seams, tattered cloth flags, bone accents, skull-shaped cup" |

Siege engines (same rules, files `weapon_<id>_base.png` / `weapon_<id>_arm.png` /
`weapon_<id>_cup.png`):
- **Ballista**: "heavy wooden ballista on a four-wheel carriage, giant crossbow limbs with iron
  caps, taut rope bowstring, crank winch at the back, bolt groove on top"
- **Trebuchet**: "tall counterweight trebuchet on a wide wheeled frame, iron-banded stone
  counterweight box, long throwing arm with a rope sling and leather pouch"
