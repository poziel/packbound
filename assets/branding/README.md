# Packbound brand assets

Selected direction: a plum skull-sealed satchel, warm gold adventure lettering,
and a violet curse wisp inside the O. The game uses a darker palette without a
gore or horror identity. The subtitle is **THE CURSED DESCENT**.

## Deliverables

| Asset | Editable SVG source grid | Transparent PNG | Use |
| --- | --- | --- | --- |
| `packbound-title` | 696 × 163 | 2784 × 652 | Title screen, banners, promotional layouts |
| `packbound-satchel-detailed` | 128 × 128 | 512 × 512 | Large emblem, artwork, prominent branding |
| `packbound-satchel-simple` | 32 × 32 | 256 × 256 | Window, taskbar and application icons |

Each name above has both `.svg` and `.png` files in this folder. The title
includes the subtitle but no satchel. All PNGs are rendered from the SVGs.

`exports/` contains simple icon PNGs at **16, 32, 48, 64, 128 and 256 px**.
The 16 px icon uses an optically adjusted drawing in
`sources/satchel-micro-16.svg`; it is not a reduction of the detailed image.
Use the dedicated 16 px export for a 16 px surface.

## Editing and pixel scale

- SVGs contain native integer-coordinate paths with `shape-rendering="crispEdges"`.
  They contain no embedded raster image, font dependency, filter or external URL.
- The title and detailed satchel are palette-limited vector traces of the
  generated isolated artwork, with named color groups. Their visible details can
  be edited as vector paths; they are not manually reconstructed object layers.
- The simple satchel is hand-authored with named handle, body, pocket, leather,
  strap, buckle and skull groups. The tiny 16 px drawing is also hand-authored.
- The title has a tight canvas. Satchels use square icon canvases with intentional
  transparent vertical space to preserve their shape. Do not stretch them.
- Use nearest-neighbor filtering. Prefer integer multiples of the source grid.
  The 48 px convenience export is sampled from the 32 px icon with nearest
  neighbor; 32/64/128/256 px retain uniform source-pixel blocks.
- The 128 px character-body contract is a separate rule; these assets are logos,
  not character sprites.

## Regenerate

From the project root, with Node.js and `sharp` available:

```powershell
node scripts/art/build-branding.cjs
```

This preserves SVG edits and rebuilds PNGs, the Windows ICO, and previews. The script can also find
`sharp` in the locally bundled Codex workspace runtime.

```powershell
node scripts/art/build-branding.cjs --trace
```

`--trace` rebuilds **and overwrites the title and detailed SVGs** from the preserved
isolated sources. It does not overwrite the hand-authored simple or micro SVG.
The trace uses a 55-color title palette and a 48-color detailed satchel palette;
the simple SVG uses 24 colors.

## Provenance and verification

The approved concept and unmodified isolated raster artwork are preserved under
`sources/`; see `sources/PROVENANCE.md` for the generation prompts and workflow.
The title and detailed sources were created with the built-in image generation
tool, then converted to native SVG pixel paths. PNG exports come from those SVGs.

`previews/asset-sheet.png` shows the three assets, actual small-icon sizes, and a
light-background check. `previews/icon-pixel-check.png` enlarges the 16 and 32 px
icons without smoothing. `previews/validation.json` records dimensions, rendered
bounds, palette counts, binary transparency, and the absence of raster embedding.

The main menu scene displays `packbound-title.png` at its 696 × 163 source-grid
size, including the subtitle, with nearest-neighbor filtering. `project.godot`
uses `packbound-satchel-simple.png` as the application icon and `packbound.ico`
as the Windows native icon. The ICO contains the six PNG icon sizes listed above.
