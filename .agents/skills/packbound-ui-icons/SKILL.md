---
name: packbound-ui-icons
description: Create readable Packbound pixel icons for the UI.
---

# Packbound UI icons

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

Make the control's purpose recognizable before adding decoration. These are
isolated interface glyphs, not inventory illustrations or miniature character art.
Work from this game's project root. Read [the icon catalog](references/icon-catalog.md)
for the requested control, existing slot evidence, and supplied visual references.

## Scope and source sizes

- **Menu icons: 24 x 24 source pixels** by default. Current navigation tabs use
  a 24 px icon maximum. Keep roughly 2 px of outer breathing room, adapting
  optically for narrow shapes rather than stretching every silhouette equally.
- **Action and reward icons: 32 x 32 source pixels** when their slots allow it.
  Current item/relic reward controls use 32 px icons; the gameplay Button theme
  also allows 32 px. The larger canvas buys clearer shapes, not more texture.
- Check the actual scene, inherited theme, padding, and intended display size
  before finalizing a family. A slot's `icon_max_width` is a cap, not a guarantee
  that an image will render at that size. Author a 24 px variant when needed;
  do not shrink a 32 px glyph to 24 px and assume uneven pixels are acceptable.
- Keep one consistent native size within a given control family. Related 24/32 px
  versions retain their motif but are resolved on each native grid. Reuse one
  source for exact integer enlargements with nearest-neighbor filtering.
- These sizes are independent of inventory's 32 px cells, character bodies, and
  [inline keyword symbols](../packbound-keyword-icons/SKILL.md). Do not enlarge
  a tiny inline symbol to create a detailed action glyph automatically.

## Drawing language

Use bold stepped silhouettes, connected pixel clusters, and open negative space.
Start with a roughly 2 px structural weight at 24/32 px and compare the set
optically: a filled bag and an outlined chart need similar visual presence, not
identical pixel counts. Keep essential gaps at least 2 px where practical; use
single pixels only for purposeful terminal corrections, not sparkle or texture.
Use one unmistakable motif and at most one secondary cue. Menus need faster
recognition than inventory objects, so omit realistic material texture, scratches,
tiny runes, painted reflections, cast shadows, and ambient glow.

Default to an **opaque white glyph on transparency**, suitable for runtime tinting.
Use holes/negative space for structure rather than antialiasing. A multicolor
exception may use a small restrained palette when the brief requires it; record
whether runtime tinting should be applied. White masks work with Godot's icon
modulation; do not rely on CSS `currentColor` being resolved by SVG imports.

Export only the icon: no baked button, panel, frame, text, number, hotkey, badge,
or hover/pressed background. The supplied screenshots inform motif simplicity
and placement, not their low contrast or exact colors. Shared UI containers own
their borders, focus rings, press offsets, and notification markers.

Block, Spell, and Attack each get **one standalone glyph**. A crossed-blade motif
is one glyph; a composite button with a label, resource cost, and badge is not.
Keep action identity distinct from state: a spell icon should read as casting,
not specifically Burn unless the action actually means a fire spell.

## States and meaning

Use the same geometry across normal, hover, pressed, selected, and disabled
states. Let the theme tint the mask and the control surface show state. Inspect
light ink on dark panels and dark ink on bright primary buttons; a single fixed
ink can disappear on one of them. Keep unavailable glyphs recognizable. Do not
make disabled art look like a different action or enable a control while adding
its icon; the current manual Spell/Block controls are intentionally unavailable.

Provide a concise accessible name and tooltip for icon-only controls. Keep focus
visible and selected/available states distinguishable through shape, border,
marker, or placement as well as color. Icon dimensions are not hit-area dimensions;
retain comfortable existing button areas and keyboard behavior during integration.

Neutral navigation uses theme ink/state tokens. If a UI glyph communicates a
specific stat or effect, reuse the companion skill's
[keyword catalog](../packbound-keyword-icons/references/keyword-catalog.md)
instead of inventing another health/block/poison palette. A Block action key is
still separate from the inline block statistic; their motifs can share a family.
Reward navigation may retain its documented blue/plum control surfaces without
turning those colors into new gameplay meanings.

## Workflow and deliverables

1. Resolve stable icon key, control function, family/native size, target slot,
   tint behavior, label, and deliverable scope. Inspect existing navigation art
   and its consumers before replacing anything. The catalog gives starting
   metaphors; adapt only when the actual function makes another motif clearer.
2. For concept requests use the built-in image-generation tool and
   [generation prompt](references/generation-prompt.md). Save original output,
   exact prompt and reference provenance. Large generated images are concepts;
   stating "24 px" in a prompt does not establish an exact 24 px production grid.
   For direct native icon drawing, author spritex palette-index grids and render
   PNG/SVG with the CLI. Preserve the JSON as the editable source.
3. Resolve the design deliberately into exact spritex palette-index grids with
   alpha 0/255. Generate SVG through the CLI and verify its matching viewBox and
   crisp integer-grid rendering. Repair gaps, diagonal steps and optical balance
   in the JSON; automatic reduction is a starting point only. Do not hand-edit
   exported SVG paths as a second source of truth.
4. Review all requested icons together at 1x and actual control size, then at 4x
   nearest-neighbor for cleanup. Show isolated glyphs and a separate labeled
   context sheet on real panel/button colors. Check that backpack/reward item,
   relic/relic reward, and block/shield/armor are distinguishable without color.
   Do not bake the review labels or surfaces into exported art.
5. For production deliver layered spritex JSON, CLI-generated transparent PNG
   and integer-grid SVG, and a catalog/manifest
   of IDs, native size, alpha bounds, tint mode,
   label, variant relationship, reference/source provenance, and review status.
   Store new work in a versioned `workspace/docs/art/concepts/ui-icons/<set>-vN/` directory
   until integration is in scope. A suitable integrated destination is
   `assets/ui/icons/`; follow an existing equivalent if present rather than
   duplicating registries. Preserve existing `assets/navigation/` originals.
6. Validate actual PNG dimensions/transparency, SVG integer grid and matching
   rasterization, duplicates/missing catalog entries, and consistency of variant
   registration. If integration was requested, verify Godot import size/filtering,
   inherited icon tints, layout, tooltips, focus, and states in the actual UI.
   Visual review establishes readability; byte/grid checks alone do not.

Deliver only the scope requested. Concept review does not require automatic
integration, and already authorized production work does not need an invented
extra approval gate. Preserve manual assets and distinguish proposed, reviewed,
and explicitly accepted designs. For parallel work use unique output folders;
keep spritex JSON and export paths separate across tasks.
