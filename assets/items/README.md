# Inventory item art

## Folder organization

Current assets live under `<type>/<item>/`: weapons, armor, spells, relics,
charms, healing, ammunition, traps and utility. Each item folder has a
`metadata.json` identifying its stable gameplay key, role, footprint and runtime
texture or atlas region. Run relics have their own metadata and explicitly reuse
the appropriate inventory item icon. `manifest.json` indexes all item metadata.

Keep the SVG, PNG, footprint metadata and editable `sources/*.pxo` together.
Current filenames have no revision suffix; sizes such as `32px`, `64px` and
`128px` distinguish functional base, selection and detail variants.

Shared runtime fallback atlases and their Pixelorama source live in `atlases/`.
Do not remove or rescale these while items still use their regions. Atlas source
hashes, pixel validation and historical slot names remain in `atlases/manifest.json`.
Unused drafts and superseded standalone exports live under `archive/`, grouped
by type, item and revision. `.gdignore` excludes archives from Godot import.
The project-wide `../organization-manifest.json` maps original paths to new paths.
Concepts, prompts and historical review boards remain under `workspace/docs/art/` with
their original names and provenance.


## Current 32 px items

`PackArt.item()` loads these individual SVGs at their native 32 x 32 source size.
Each occupies one cell. Venom Dagger has an individual 64 x 64 sprite for its
three-cell inverted L. Other items continue to use the earlier atlas.

The three one-cell items also have individual `-64px` selection and
`-128px` detail SVG/PNG exports with matching Pixelorama sources. These contain
finer detail from their larger reference artwork; they are not enlarged copies
of the 32 px sprites. Their generation/preparation provenance is under
`workspace/docs/art/concepts/<item>-large-v1/`.

`PackArt.item(key)` returns the backpack sprite; `PackArt.item(key, 64)` and
`PackArt.item(key, 128)` request a whole-image view size. Selection cards request
64 px. The 128 px export is ready for a larger detail view; the existing compact
tooltip retains its small icon. Items without new variants keep their existing
atlas artwork.

For irregular items, base dimensions are 32 multiplied by the footprint's width
and height. An L already has a 64 x 64 base, and a 4 x 4 item already has a
128 x 128 base. Reuse these when they meet the view size; do not generate redundant
selection/detail copies. Additional detail is optional, not a requirement caused
by enlarging the UI.

| Item | SVG/PNG stem | Pixelorama source |
| --- | --- | --- |
| Rusty Knife | `weapons/rusty-knife/rusty-knife-32px` | `weapons/rusty-knife/sources/rusty-knife-32px.pxo` |
| Cracked Shield | `armor/cracked-shield/cracked-shield-32px` | `armor/cracked-shield/sources/cracked-shield-32px.pxo` |
| Iron Charm | `charms/iron-charm/iron-charm-32px` | `charms/iron-charm/sources/iron-charm-32px.pxo` |
| Venom Dagger (`##/.#`) | `weapons/venom-dagger/venom-dagger-64px` | `weapons/venom-dagger/sources/venom-dagger-64px.pxo` |

Venom Dagger uses 32 source pixels per cell on a 64 x 64 canvas. Its swept,
poison-coated blade occupies the upper row and its grip occupies the lower-right
cell. The lower-left cell is fully transparent. Its 24-color image-generated
concept, exact prompt and preparation script are preserved under
`workspace/docs/art/concepts/venom-dagger-64px-v1/`. The native sprite was imported into
Pixelorama and exported unchanged; its single pixel layer and SVG color runs
are editable. The base also serves the 64 px selection view without a duplicate
variant. Its existing gameplay footprint and mechanics are unchanged.

The shield and charm were drawn directly in Pixelorama on a 32 px grid, with
separate editable layers. Their PNG exports are converted without resizing or
recoloring to native SVG pixel paths by the project skill's `item-grid.cjs` helper.
Both use 15 opaque colors and hard transparency. The Rusty Knife retains its
approved 16-color image-generation-derived design and Pixelorama source.

Per-item art briefs, layer pixel plans, provenance and footprint metadata are
preserved under `workspace/docs/art/concepts/<stem>/`. The three-item review is at
`workspace/docs/art/reviews/pixelorama-items-32px-v1/review.png`.

Keep the individual `.pxo` files as editable art sources and the SVG/PNG files as
per-item exports. A runtime sprite sheet can be generated from those exports
later if profiling warrants it; do not make manual atlas positions the source
of truth. Godot's normal SVG Texture2D import rasterizes these at their declared
32 x 32 size. The game uses nearest-neighbor filtering.

## Earlier 96 px atlas

Eight one-cell items recreated on 2026-10-15 by three delegated image-generation
agents using the approved warrior/ranger style references. Each generated PNG and
its exact prompt/provenance remain in `workspace/docs/art/concepts/items-2026-10-15/`.

## Historical atlas slots (not current filenames)

The earlier atlas is `assets/items/atlases/basic-items.svg`: 768 x 96, eight 96 x 96 cells, in the
same order expected by the atlas fallback in `PackArt.item()`. The remaining fallback items keep standalone SVG/PNG exports in their type/item
folders; superseded standalone exports are archived. `atlases/basic-items.png` is the equivalent raster atlas.

| Slot | File stem | Visual | Internal key | Backpack cells |
| --- | --- | --- | --- | --- |
| 1 | 01-dagger | Rusty Knife | rusty_knife | 1 x 1 |
| 2 | 02-shield | Cracked shield | cracked_shield | 1 x 1 |
| 3 | 03-ruby | Ruby | blood_gem | 1 x 1 |
| 4 | 04-bandage | Bandage roll | bandage | 1 x 1 |
| 5 | 05-dagger | Iron dagger | longsword | 1 x 1 |
| 6 | 06-shield-relic | Shield relic | tower_shield | 1 x 1 |
| 7 | 07-cursed-idol | Cursed idol | cursed_idol | 1 x 1 |
| 8 | 08-pendant | Pendant | iron_charm | 1 x 1 |

The legacy `longsword` and `tower_shield` keys retain their effects and references.
Their displayed names are now Iron Dagger and Shield Relic, and their masks each
contain one occupied cell. Other basic items already had one-cell masks. Damage,
block, healing, adjacency bonuses and curse behavior have not been retuned; the
two smaller footprints intentionally change space efficiency.

## Pixel editing and provenance

- `atlases/sources/basic-items.pxo` is the editable Pixelorama atlas, at native size.
- SVGs contain named item groups and color-grouped horizontal pixel runs, with
  integer coordinates and `shape-rendering="crispEdges"`. There are no embedded
  raster images. These are raster-derived native pixel paths, not hand-traced
  anatomical/vector illustrations.
- Each icon has at most 32 opaque colors, alpha values 0/255, and at least eight
  pixels of transparent cell padding. Palette reduction uses deterministic color
  clustering without dithering. Geometry resizing uses nearest neighbor.
- `atlases/manifest.json` records source hashes, measured bounds, palette counts and
  exact SVG/PNG pixel equivalence.
- `archive/2026-10-15-before-redraw/` preserves the original atlas and catalog,
  with SHA-256 hashes, excluded from Godot import.

Inventory icon framing is independent of world-art size: the ruby and pendant
are smaller inside their cells, and weapons are enlarged for recognition. A held
dagger still targets 32 source pixels along its length under AGENTS.md. These
inventory depictions do not change the 128-pixel character contract.

## Rebuild

Run `node systems/art/tools/build_item_atlas.cjs` from the project root with `sharp`
available to Node. The Codex bundled dependency directory can be supplied through
`NODE_PATH`; the script does not install packages or call an image API.

Rebuilding stages the historical SVG/PNG outputs, atlas and manifest in
`tests/output/item-atlas-rebuild/`, then checks pixel equivalence and
grid/alpha/padding constraints. Review those files before promoting any to
current item folders; the rebuild does not overwrite current artwork. Preserve
any subsequent manual pixel edits as new source versions before rebuilding.
After an atlas change, refresh the Pixelorama project from the new raster export.

The review board at `workspace/docs/art/reviews/items-2026-10-15/items-review.png` shows a 3x
view, native 96-pixel icons, and 52/42-pixel backpack/tray previews. Atlas framing
has been inspected at those sizes; exact game rendering is checked separately.
