# Logo artwork provenance

Prepared 2026-10-15 for Packbound: The Cursed Descent.

## Preserved original files

- `approved-concept.png`: the concept explicitly accepted in this conversation,
  with purple skull satchel, gold title and purple curse wisp in the O.
  Original generation identifier: `exec-82fbfa45-31af-4b8c-8555-176feec1c6d2`.
- `title-isolated.png`: unmodified transparent title artwork generated from the
  approved concept. Identifier: `exec-66834589-23c8-420f-ae24-5fc327dcb830`.
- `satchel-isolated.png`: unmodified transparent detailed satchel artwork generated
  from the approved concept. Identifier: `exec-988382de-5c01-4885-b75c-363717222bc0`.
- `trace-manifest.json`: source bounds, grids and actual palette sizes from the
  conversion into editable SVG paths.
- `satchel-micro-16.svg`: original hand-authored 16 px icon adjustment.

Both isolations used the built-in `image_gen` tool with
`transparent_background: true` and the approved concept as their only reference.
The source PNGs remain intact. They are references rather than the final matching
SVG/PNG deliverables. Their image-generated edges are normalized to integer-grid,
binary-alpha artwork during vector conversion, with no dithering.

## Title generation prompt

> Extract and faithfully reproduce ONLY the title logo from this approved PACKBOUND concept sheet as a standalone asset on a genuinely TRANSPARENT background. Take the large primary title on the right: exact gold chunky pixel lettering PACKBOUND with purple curse wisp inside the O, gold separator line, subtitle THE CURSED DESCENT and its short end bars. NO backpack, NO skull icon, NO presentation labels, NO other duplicate logos, NO background or checkerboard. Preserve the approved letter shapes, large P and D, warm yellow gold faces, ochre lower shading, dark outlines, subtle block pixel textures, squared gold O framing the muted violet flame, and exact subtitle. No eye, buckle rivets or central pin. This is production asset extraction, not a redesign. Arrange in a wide landscape transparent canvas with the title occupying nearly all of it. Sharply stepped coherent pixel grid, clean crisp edges, flat color clusters, no smooth curves or glow. Preserve every letter correctly: P A C K B O U N D; THE CURSED DESCENT.

## Detailed satchel generation prompt

> Extract and faithfully reproduce ONLY the detailed plum SKULL SATCHEL emblem from the left of this approved PACKBOUND concept sheet, as one standalone icon on a genuinely TRANSPARENT background. Preserve the front-facing compact shape, wide rounded stepped leather body, purple/plum flap and panels, warm brown leather top handle, paired vertical brown straps and square gold buckles, small side pouches and gold fittings. Preserve the large ivory skull clasp centered prominently on the purple front, with compact round black eye sockets, little nose and short even teeth. This skull feels like an adventurer's relic, not gore or horror. Keep the original's attractive pixel texture, stepped highlights and dark outlines. No eye symbol, no rune, no curse flames on the satchel. No title, no text, no labels, no second icon, no background panel or floor or shadow cast outside the object. This is production asset extraction preserving the approved shape and colors, not a redesign. Center the emblem with little empty space on a square transparent canvas. Clearly visible pixel art with coherent stepped grid, hard-edged color clusters, no blurry pixels, no smooth illustration or 3D render.

## Native SVG work

The title and detailed emblem were sampled onto 696 × 163 and 128 × 92 visible
pixel grids respectively, then palette-quantized into horizontal run paths. The
detailed emblem is centered on a 128 × 128 canvas. SVGs contain editable native
paths, not base64 images. Rendering those SVGs with nearest-neighbor enlargement
produces their corresponding delivery PNGs.

The simple satchel was drawn directly as grouped native SVG paths on a 32 × 32
grid, preserving the selected skull, plum leather, brown straps and brass details.
Its small-size palette and larger flat clusters are intentional. A separate
16 × 16 drawing preserves paired eye sockets when fewer pixels are available.
