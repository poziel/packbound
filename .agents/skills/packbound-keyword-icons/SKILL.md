---
name: packbound-keyword-icons
description: Create Packbound's small inline stat, status-effect, and tooltip pixel icons with shared keyword colors, readable keyword-and-icon pairs, and distinct armor, shield, and block identities. Use for keyword icon catalogs and their text/color integration; menu and action buttons use packbound-ui-icons.
---

# Packbound keyword icons

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

Create compact symbols that explain mechanics beside their words. A clear shape,
consistent meaning and matched text/icon color take priority over ornament. Work
relative to the Packbound project root. Creating assets does not by itself change
game mechanics or enable a runtime tooltip feature.

Combat keywords (keywords for short) are named stats, damage types, status effects
and mechanics with shared labels, aliases, icons and colors.

## Meaning and references

Read [references/keyword-catalog.md](references/keyword-catalog.md) before choosing
IDs, glyphs, colors or aliases. It contains the starter catalog, current-code
terminology caveat and a proposed shared registry contract. Check the current
`scripts/keyword_links.gd` and relevant `scripts/run_state.gd`/catalog definitions
when integrating or extending meanings; code may have changed since this skill.

Inspect the user's [tooltip reference](../../../workspace/docs/art/references/ui-icons/tooltip-reference.png)
for compact word/stat associations. Its colors, low contrast and exact glyphs
are examples, not accepted production targets. The accepted character/item art
informs the fantasy setting and deliberate pixel clusters, not miniature armor
textures or the source dimensions of these symbols.

Block uses a **shield motif at the user's request**. Preserve Block and the
legacy Shield as distinct keyword/mechanic IDs; the motif does not merge them.
Keep worn armor/equipment visually separate. In current code the glossary
key `armor` actually means Shield; `plating` is a separate per-strike reduction.
Use the catalog's explicit legacy adapter rather than inventing another armor
pool or silently assigning plating's meaning to the armor glyph.

## Native grid and drawing

- Start with a **16 x 16 source-pixel cell**, transparent outside the glyph and
  usually 1 px of breathing room. Fit each silhouette optically; equal boxes do
  not require equal ink area. Use 1-2 px structural thickness and open counters.
- The user's current family contract fixes every glyph's visible envelope to
  **14 x 14 at [1,1,15,15]** inside that 16px source. Deliberately redraw to fit;
  never add orphan extremity pixels just to satisfy the bounds. Record a shared
  renderer baseline correction separately from the centered master artwork.
- Inspect the consuming font's actual glyph height and line box first. A compact
  **12 x 12** family can accompany smaller text; author it deliberately rather
  than shrinking away necessary gaps. A **24 x 24** authored family is appropriate
  for larger text when 16 px looks undersized. Keep each context's family uniform.
  The current themes include 16 px tooltips and 24 px rich text, so no one size
  should be stretched indiscriminately to fit both. Font size is not cap height.
- These are keyword UI glyphs, independent of 32 px inventory footprints and
  256 px character bodies. Prefer integer display scale and nearest filtering;
  choose a fitting native variant instead of fractional enlargement.
- Draw a **single opaque ink mask** with transparent negative space. Favor a
  strong silhouette and one identifying cutout. No gradients, glows, antialiased
  curves, stray texture pixels, tiny runes, lettering or baked-in button frames.
- SVG uses integer stepped geometry, `shape-rendering="crispEdges"`, and one SVG
  unit per source pixel. PNG pixels have alpha 0 or 255. Maintain editable paths
  or pixel layers, not an SVG wrapper around an embedded raster image.

## Shared color and text behavior

Use one keyword registry to resolve **label + aliases + icon + color token**.
The same resolved color tints a **keyword link** span and its icon. A tooltip's
**keyword stats** (icon-and-value pairs) instead use the consuming label's default
color for both icon and value, without underlines at rest or on hover. Both
keyword links and keyword stats darken their icon and text on hover and restore
on exit. Keep surrounding prose neutral; a tooltip containing health, poison
and block must not be tinted entirely one color.

Item tooltips use **keyword lists** instead of compact keyword stats: one entry
per line, ordered signed value, icon, keyword name. Icons and names use keyword
colors; numbers and signs use the default font color. Positive values show a +
sign; negatives and costs show a minus sign. Keep no underlines and darker hover
feedback. Remove duplicate numeric item sentences;
retain explicit booster/special rules and identify adjacency bonus sources on
affected items. Relic tooltips retain compact keyword stats.

The user-selected reading order is **icon, gap, keyword**: `[heart] health` or
`[droplet] poison`. Keep the pair together on wrapping, align the icon optically
with the text's cap-height center and record a per-size baseline offset. The
runtime uses a nonbreaking space after the icon. Do not let the icon
collide with descenders. Compact numeric HUD rows can use a documented icon/value
layout rather than repeating a word. Preserve the readable word or an accessible
label; the glyph must not be the only explanation of an unfamiliar mechanic.

Resolve aliases on text tokens, case-insensitively and longest phrase first;
avoid substring replacement, markup corruption, repeated icon injection and
icons inside image paths/IDs. Punctuation follows the complete pair. Do not
automatically append a second glyph to a span that is already decorated.

For web/preview SVGs, `currentColor` can inherit the same keyword text color.
For Godot, do not assume SVG import inherits a Label color: export a white mask
with explicit fill and tint it through the consuming node or supported inline
image tint, or generate a resolved-color PNG from the shared registry. Verify the
actual renderer. A white mask avoids multiplying an already colored texture by
another color. Exported colored variants are derived artifacts, never separately
maintained palettes. Optional combat FX use the same keyword tokens as a color
cue; adding this skill does not implement FX or new status effects.

## Creation and review

1. Establish the mechanic ID, actual text size/background, native family size and
   deliverable scope. Reuse the registry before proposing a new symbol or color.
   Use [references/generation-prompt.md](references/generation-prompt.md) for
   image-generation requests. Use the built-in image-generation tool for original
   concepts; use native pixel editing when that is explicitly requested. Generated
   large images are concepts, not proof of a precise 16 px source grid.
2. Resolve the selected design onto the exact native grid. Simplify before adding
   pixels. Preserve the original concept, prompt/references and edit history.
   Save spritex authoring JSON, validate it, and export PNG/SVG through the CLI.
   Keep JSON and output paths separate across concurrent tasks.
3. Review at **1x beside real words and numbers**, plus 4x nearest-neighbor for
   pixel inspection. Compare armor/block/shield, poison/burn, and health/healing
   as a set. Shapes must remain distinguishable in monochrome and grayscale.
   Review on all actual tooltip backgrounds, including hover and selected states.
   Aim for at least 4.5:1 keyword-text contrast and 3:1 essential-glyph contrast;
   measure against the actual adjacent background and record the result. These
   are review targets, not a claim that a proposed palette is already validated.
4. Deliver spritex authoring JSON, CLI-generated native SVG and transparent
   white-mask PNG, a labeled preview
   showing keyword-color matches, and registry entries with dimensions/baselines,
   source provenance and review status. Use a versioned directory under
   `workspace/docs/art/concepts/keyword-icons/` for candidates. Mark acceptance only from
   the user's actual selection; numeric checks do not establish visual approval.
5. If integration is requested, connect the keyword link formatter and each consumer
   to the same registry/adapter. Some current tooltip descriptions use plain
   `Label`, so adding files alone cannot insert inline images. Preserve text,
   keyword links, amounts and mechanics; test mixed terms, aliases, repeated
   calls, wrapping, readable scaling and runtime tinting. Do not claim integration
   from an exported PNG or a standalone preview.

Menu tabs, reward choices and action buttons use
[packbound-ui-icons](../packbound-ui-icons/SKILL.md). A button such as `action.block`
may share a recognizable motif with `stat.block`, but its action meaning, size
and state treatment remain distinct. Do not downsample detailed inventory item
art to stand in for keyword glyphs.
