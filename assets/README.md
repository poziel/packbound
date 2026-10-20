# Prototype Art

Original artwork created for this project. The eight basic item icons use
image-generated concepts with editable pixel sources; the original
concepts, prompts and provenance are preserved. Runtime art is bundled locally.

- `items/`: resource-named item folders with metadata, exports and editable sources.
  See [items/README.md](items/README.md). Shared fallback sheets live in `items/atlases/`.
- `backgrounds/main-menu/`: the current animated packing table, including its
  Pixelorama source and animation metadata; filenames have no revision suffix.
- `backgrounds/archive/`: older menu backgrounds and native source revisions.
- `themes/menu/`, `themes/gameplay/`: the two UI themes, supporting textures
  and editor showcase scenes. Delver/scrollbar styles live in these themes;
  custom rendering scripts remain with their components.
- `enemies/`: resource-named enemy folders with README, gameplay records and `art/`.
- `characters/`: five editable class sprites; earlier artwork lives in its archive.
- `branding/`: title, satchel marks, exports, approved sources and provenance.
- `icons/`: navigation, keyword, action, control and inventory icons; see [icons/README.md](icons/README.md).
- `audio/`: music, ambience, categorized sound effects and the shared bus layout.
- `fonts/`: bundled fonts, licenses and source notes.

Archives preserve unused or superseded artwork and are excluded from Godot import
with `.gdignore`. Native sources and useful view-size variants stay with their
current asset even when they are not loaded directly by gameplay. Historical
concept/review folders retain their original provenance names.

`PackArt` exposes the atlas regions as textures. Art uses transparent backgrounds.
The basic items share the approved warrior/ranger lighting and material treatment,
with 32 colors per icon and hard pixel edges for the backpack and loot view.

## Source pixel density

New or explicitly redrawn characters use a **128 px visible body height**,
measured from head/headwear to foot sole, excluding weapons, detached effects,
and transparent padding. Each character occupies a **192 × 160 px** source cell:
body top `y = 16`, shared foot baseline `y = 144`, centerline `x = 96`.
Animation frames retain this registration instead of being individually cropped.

Size related assets with `round(128 × relative_length)`. Nominal sword/dagger
length includes the hilt and pommel and is measured along the weapon, regardless
of pose: long sword **64 px** (1/2 body), short sword **43 px** (1/3), dagger
**32 px** (1/4). These ratios provide a consistent reference for future assets.

Editable native pixel art uses an integer pixel grid with
stepped silhouettes, and `shape-rendering="crispEdges"`. Render textures with
nearest-neighbor filtering; keep source density separate from UI display size
and prefer integer display scaling. Existing assets retain their current density
until an explicit redraw. The character files above use this density; the other
inventory dimensions describe the existing prototype artwork.

Each redrawn character keeps its headwear, clothing, hands and feet in editable
body layers. Held equipment has separate named groups so body
height can be measured without counting weapons or effects. The five classes
were redrawn by five dedicated sub-agents using the same registration and a
shared dark outline, muted fantasy palette and stepped highlight treatment.

Items, relics, enemies and characters use one folder per resource, with `README.md` and `art/`. Gameplay definitions remain at the resource root. SVG exports were removed from these four groups; accepted raster artwork and editable native sources were preserved.
