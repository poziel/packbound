---
name: packbound-item-art
description: Create and redraw readable Packbound inventory item pixel art with clear silhouettes, convincing material thickness, restrained shading, and explicit 32 px cell footprints. Use for item concepts, native sprites, and optional larger UI variants; characters and monsters follow their own art skills.
---

# Packbound item art

## spritex authoring and exports

Use the [spritex skill](D:/Dev/5-tools/spritex/skills/spritex/SKILL.md) for
production alongside this art-direction skill. Read its schema reference before
authoring JSON; follow its executable discovery/local-build instructions.
Run `spritex --version` and verify compatibility before producing assets.

The editable source is **spritex authoring JSON**: exact RGBA palette entries,
full-canvas numeric pixel grids, meaningful named cels/layers, and explicit
frame timelines. Keep layers ordered bottom to top and preserve registration.
For animation, specify every frame duration and layer timeline entry; reuse a
cel with an explicit layer-local link only when shared edits are intended.
Do not embed unsupported fields or mistake the character identity catalog or
item footprint JSON for the sprite authoring document.

Validate the source, then generate production PNG and SVG through the CLI:

```sh
spritex validate sprite.json
spritex export sprite.json --output exports/sprite --formats png,svg
```

Create the output parent first; `--output` is an extensionless filename stem.
Use fresh versioned paths and only use `--force` for authorized replacements.
Deliver the authoring JSON with the CLI-generated exports. Optional native
`.pxo`/`.aseprite` builds are compatibility exports, not required sources.
No Pixelorama app, MCP connection, or Pixelorama availability approval is needed.

Built-in image generation may provide concepts/edits; preserve their provenance
and resolve the design into the exact JSON grid for production. A generated
image or automatically reduced grid does not establish good pixel art. For a
concept-only request, deliver the requested concept without claiming a finished
JSON production asset. Inspect a CLI-rendered PNG at native/UI scale and revise
the JSON before re-exporting. Do not independently hand-maintain final PNG/SVG
art that can drift from the JSON. Existing crop/footprint helpers may prepare
intermediates or validate exports; spritex owns final production rendering.

For animations, follow the spritex skill's frame selection, animated exports and
contact-sheet workflow; inspect all frames and timing. Report source/export
paths, actual visual checks, and any conversion limits. Preserve existing art
and legacy source provenance; do not silently flatten unsupported conversions.
Concurrent tasks use separate JSON/output paths rather than a shared editor.

Create items that look intentional beside Packbound's accepted character art:
clear silhouettes, readable thickness, broad material shading, and one or two
defining details. Resolve that design onto the actual source grid, then judge it
at the size players see. A generated concept is not yet a validated production
sprite. Work relative to this game's project root.

## Canvas and placement contract

- Each backpack cell is **32 x 32 source pixels**, with **zero artwork gap**.
  For a footprint bounding box W cells wide and H cells high, the PNG and SVG
  canvas are exactly `32 * W` by `32 * H`. Two cells high means **64 px**.
- Represent the footprint as equal-length strings: `#` occupied, `.` empty,
  rows from top to bottom, columns left to right. Remove wholly empty outer rows
  and columns when defining a new shape. Keep internal empty cells.
- The mask is the placement authority. Transparent gaps inside an occupied cell
  do not make it available to another item. Every empty cell must remain fully
  transparent, including highlights, particles and cast shadows. Show meaningful
  item structure in each occupied cell; a stray pixel is not a convincing reason
  to consume an extra cell.
- Adjacent occupied cells share an uninterrupted art surface. Do not draw grid
  borders, add gutters, or inset the artwork separately within each cell. Prefer
  1-2 px of breathing room along the silhouette's outside boundary when it helps
  readability, without adding canvas padding or shrinking every cell separately.
- Footprint is gameplay data, independent of apparent physical size. A small
  ruby may use one cell; a long staff may span four. Do not infer placement from
  a rectangular image's alpha bounds or invent a footprint from its decoration.
- Use one SVG unit per source pixel, integer stepped geometry, `crispEdges`,
  and opaque or transparent pixels (alpha 255 or 0). Display size and any future
  UI cell gaps are separate. Prefer integer enlargement and nearest filtering.
- Rotate art and its mask together in exact 90-degree steps if rotation is
  requested. Rebase to the rotated bounding box and validate again. Do not
  rotate only the art inside the original rectangle.

| Shape | Mask rows | Canvas | Occupied cells |
| --- | --- | --- | --- |
| Single | `#` | 32 x 32 | 1 |
| Two high | `# / #` | 32 x 64 | 2 |
| Two wide | `##` | 64 x 32 | 2 |
| Square | `## / ##` | 64 x 64 | 4 |
| L | `#. / ##` | 64 x 64 | 3 |
| Three high | `# / # / #` | 32 x 96 | 3 |
| Four high | `# / # / # / #` | 32 x 128 | 4 |
| U, open top | `#.# / ###` | 96 x 64 | 5 |
| Tall U, open top | `#.# / #.# / ###` | 96 x 96 | 7 |

These L and U orientations are examples, not defaults for every such request.
Confirm a missing orientation when it affects the design. A filled 2 x 2 square
and a three-cell L have the same canvas dimensions but different placement masks.

## View sizes and optional detail variants

The 32 px rule is **per backpack cell**, not the size of every complete item.
Compute the base canvas from the footprint before requesting extra artwork.

- A one-cell item has a 32 x 32 base canvas.
- An L with `#./##` already has a 64 x 64 base canvas; its top-right cell is empty.
- A 4 x 4 footprint already has a 128 x 128 base canvas.

Use 64 px as the usual selection-view image budget and 128 px as the usual larger
detail-view budget, measured along the complete canvas's longest edge. These are
view targets, not new per-cell densities. Reuse a base sprite that already meets
the target; do not create duplicate artwork just to label it "selection" or "detail".
For a narrow item, preserve its aspect ratio instead of stretching it into a square.
Nearest-neighbor integer enlargement is also valid when the same coarse pixel
treatment is desired. A genuinely more detailed variant is optional, and must
preserve identity, mask, orientation and relative framing while adding deliberate
detail at its own native grid; an enlarged copy contains no additional detail.

A reward card is a display context, not a reason to generate a larger asset.
Small items may grow there; large inventory items may shrink. Inspect the actual
image area and fit the whole item proportionally without cropping. Reuse the base
first. If a large item's reduced image loses its identity, author a simplified
thumbnail; if a small item's enlargement is too coarse, consider a more detailed
variant. Do not increase the whole inventory's density to repair one muddy icon.

When a higher-detail variant is needed, increase all footprint cells uniformly.
For example, a one-cell 128 px detail uses 128 px per cell, whereas an L-shaped
128 x 128 detail uses 64 px per cell. Backpack placement still uses the original
mask and 32 px base density. Keep the base source and every authored variant.

## Style anchors

Read `workspace/docs/art/PIXEL_ART_STYLE.md` and `workspace/docs/art/characters/accepted.json`. Inspect
the accepted warrior and ranger artwork identified there for broad material
planes, deliberate clusters and readable forms. Inspect the nearest relevant
item concept in `workspace/docs/art/concepts/items-2026-10-15/` and its review status, but
do not treat its presence as approval. The user's criticism of the muddy shield
supersedes treating that shield as a quality target. Use it only to preserve
identity or diagnose a redraw. Preserve original artwork. The item shading rules
below override reference images' colored light reflections; use a reviewed item
without those accents as an additional reference when available.
Their large PNG dimensions and the old 96 px icons do not establish the new grid.

Keep broad angular material planes, stepped silhouettes and a restrained value
ramp within each material's own colors. Iron uses neutral gray planes; rust uses
muted brown-red clusters; leather and cloth have quieter contrast; gems use a
few clear facets. Describe shape and material through connected shading clusters.
Do not add colored light reflections, cyan/blue rim pixels, orange edge lighting,
bright specular streaks or isolated glitter pixels. Those accents become stray
colored squares at inventory size. Blue cloth, blue gems or explicit magical
effects can still use blue as their own material/effect color when in the brief.
Avoid uniform black borders, noisy texture and indiscriminate glow.

Make thickness legible through a distinct side plane, bevel, rim or overlap,
appropriate to the object. Separate adjacent materials by value and shape; do
not rely on thin colored edge highlights to distinguish them. Reserve the
strongest material contrast for useful structure, such as a blade edge or the
bevel of a shield, rather than distributing equally bright marks everywhere.

At 32 px, prioritize the silhouette, broad light/shadow masses and **one or two
defining details**. A cracked shield might use a substantial rim and one readable
fracture, with calm interior planes; do not compete with dense scratches, studs
and surface mottling. A gem needs a few connected facets, not glitter noise.
Redesign small details into purposeful clusters; a blind shrink of the old icons
is not sufficient. Aim for 12-20 opaque colors for a one-cell item, with a default
ceiling of 32 across an entire item, not per cell.
Use an explicit different palette limit when the brief calls for it. Larger
footprints permit clearer structures, not a requirement for more decoration.

## Readability review

Compare the icon at native size and at the actual inventory/reward display size
on the game's panel background. An enlarged editor preview is for pixel cleanup,
not evidence of success in the UI. Check that the item reads immediately, its
materials and thickness remain understandable, and its defining detail survives
without competing with the silhouette. Review beside an accepted character crop
and another item to judge shared material language, not equal pixel counts.

When an icon looks weak, diagnose before changing its resolution:

- **Muddy:** merge scattered light/dark pixels into coherent planes and simplify
  competing details.
- **Flat or ambiguous:** repair the silhouette, thickness and material separation.
- **Clear but too coarse:** compare a deliberately authored higher-detail variant
  of the same design at the same displayed size. Adopt it only if it reads better.
- **Uneven pixel blocks or softness:** inspect source dimensions and UI filtering
  and scaling before redrawing the art.

Do not claim quality or acceptance from mask, palette or export checks alone.

## Work from a brief

Resolve: item name/key, function or tier, footprint rows and orientation,
materials/base colors, one or two defining features, intended display contexts,
and requested deliverable (concept, production files, or game integration).
Infer ordinary visual choices; ask only
for missing choices that materially affect footprint or identity. For an existing
item, read its current mask and mechanics in `scripts/pack_catalog.gd` first.
Do not change stats or occupied cells just to accommodate a generated image.

1. Derive the canvas and cell coordinates using the helper below. For irregular
   items, design a plausible object that follows the shape: a bent implement for
   an L, a forked trap for a U. Keep the opening readable and transparent. Do not
   generate a rectangular object and erase a limb or blade to force it into a mask.
2. Use the built-in image-generation tool for original artwork, following its
   available imagegen instructions. Use the fixed prompt in
   [references/generation-prompt.md](references/generation-prompt.md), filling in
   the subject and computed geometry. Render the shape guide to PNG if useful as
   a geometry reference; distinguish it from the style references. Request true
   transparency. No separate API-key workflow is needed.
   For direct native authoring in spritex JSON, draw on
   the native grid from the approved references instead. Use separate meaningful
   layers and preserve the exact pixel drawing plan and art brief. This mode
   does not need an image-generation pass.
3. Save the original generated PNG, exact prompt, reference paths/hashes, intended
   footprint and generation provenance under a versioned item concept directory.
   For direct JSON work, save the art brief, per-layer pixel plan and authoring JSON
   source instead of claiming that an image-generation prompt was used.
   Judge at native target size as well as enlarged. If concept review was requested,
   deliver the concept and stop there. If production or integration was already
   requested, continue without introducing another approval step.
4. Prepare the exact grids in spritex JSON and validate with the CLI. A nearest-neighbor
   reduction can provide a starting point; inspect and repair silhouette, handles,
   tips, eyes, facets and cell-boundary crossings. Use image-generation edits when
   the design itself needs changing. Save revisions separately; do not overwrite
   an approved original. Automatic shrink/quantization is not proof of good art.
5. Validate the final PNG against its mask. The helper rejects wrong dimensions,
   partial alpha, empty occupied cells, palette overflow and pixels in forbidden
   cells; it deliberately never silently clips or resizes a bad result. Inspect
   a native view and 4x nearest-neighbor preview on light and dark backgrounds.
   Show the footprint overlay in a separate review view, never baked into the art.
   Complete the readability review above; if integration was requested, verify
   the actual inventory and reward presentation as well as the isolated export.
6. Deliver layered spritex authoring JSON, CLI-generated transparent PNG and
   native-grid SVG, plus separate footprint JSON for production requests.
   Retain the prompt and original PNG alongside provenance. Explain that converted
   SVG pixels are editable color runs, not semantic parts such as blade or hilt.

For concurrent asset work, use a unique item key and versioned output directory.
Keep JSON and CLI output paths separate across tasks. Preserve other agents'
files and accepted originals.

## Helper

`scripts/item-grid.cjs` below means this skill's script, not the game's script folder.
From the project root use `.agents/skills/packbound-item-art/scripts/item-grid.cjs`.
`layout` requires Node only. `check` and the legacy `export` require `sharp`; use the
available bundled workspace runtime/dependencies instead of installing packages
or embedding a workstation-specific path in this skill.

```powershell
# Plan an L: writes a mask JSON and a transparent SVG geometry guide.
node .agents/skills/packbound-item-art/scripts/item-grid.cjs layout --shape '#./##' --out workspace/docs/art/concepts/bent-tool-v1/layout

# Check an already prepared native PNG. Does not modify it.
node .agents/skills/packbound-item-art/scripts/item-grid.cjs check --shape '#./##' --image workspace/docs/art/concepts/bent-tool-v1/native.png

# Final art exports come from the separately authored sprite JSON.
# Create the output parent first and use a fresh stem for revisions.
spritex validate workspace/docs/art/concepts/bent-tool-v1/sprite.json
spritex export workspace/docs/art/concepts/bent-tool-v1/sprite.json --output workspace/docs/art/concepts/bent-tool-v1/native --formats png,svg
```

Use `--palette-limit N` for an explicitly chosen palette exception. Do not loosen
validation merely to accept an unreviewed generated image. The JSON includes
occupied-cell coordinates, bounding dimensions, per-cell pixel counts and hashes.
Its mask is an art handoff, not automatic registration in the gameplay catalog.
The helper's legacy `export` command is retained for compatibility and diagnostic
use; do not use its PNG-to-SVG conversion as the final new-art export pipeline.

Use `--view-edge 64` or `--view-edge 128` to plan or validate an authored larger
variant. The helper derives source density from the whole footprint and reports
`reuseBase`: an L at a 64 px view and a 4 x 4 item at a 128 px view both reuse their
32-px-per-cell base. The option does not resize or generate artwork.

## Existing assets and integration

`PackArt.item()` in `scripts/pack_art.gd` has an `ITEM_TEXTURES` map for individual
native-size SVGs and uses the earlier fixed 96 px atlas regions as a fallback.
Rusty Knife, Cracked Shield and Iron Charm currently use their own 32 px SVGs.
Their larger one-cell examples have 64 px selection and 128 px detail SVGs in
`ITEM_VIEW_TEXTURES`. `PackArt.item(key, view_edge)` selects artwork for the whole
image, reusing a base whose longest edge already meets the view target. Reward
selection requests 64 px; the 128 px files are available for larger detail views.
Keep an individual spritex JSON source and CLI-generated SVG/PNG plus footprint
metadata per item. The old
`scripts/art/build_item_atlas.cjs` rebuilds that legacy set with fixed framing.
**Do not use it for this 32 px or irregular-footprint workflow.** Do not rescale
existing assets merely because this skill was added.

For authorized game integration, inspect current texture registration, footprint
rotation, item drawing and display scale before editing. Register a newly redrawn
item's native SVG in `ITEM_TEXTURES`; do not force a 32 x 64 image into a 96 x 96
atlas slot. Adapt any additional rendering needs, then verify placement, rotation and empty-cell
interlocking in game. Preserve unrelated items, mechanics and editable originals.
Character/monster body resolutions and held-weapon lengths follow their separate
skills; they do not set inventory cell density.
Earlier 16 px experiments and exports with colored reflection accents keep their
original dimensions and metadata until explicitly redrawn. The 32 px cell and
material-based shading rules apply to new or explicitly redrawn inventory art.
