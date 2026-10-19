---
name: monster-art-creator
description: Create or explicitly redraw Packbound whole-body monsters, enemies and bosses as detailed fantasy pixel art with readable creature anatomy, layered spritex JSON sources and transparent CLI exports. Use for creature concepts, production sprites and variants; character portraits and inventory items use their respective Packbound skills.
---

# Monster Art Creator

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

Create an original enemy whose complete silhouette, species and threat read at
the actual battle display size. Deliver the whole creature; a portrait is not
part of the default monster workflow. Work from the game's repository root.

## Shared rendering direction

Read the character skill's [current visual references](../delver-art-creator/references/visual-direction.md)
and inspect the relevant actual images. The accepted
[warrior](../../../workspace/docs/art/concepts/characters/warrior-v2/full-body@4x.png) and
[ranger](../../../workspace/docs/art/concepts/characters/ranger-v2/full-body@4x.png) establish
material volume, controlled pixel clusters and intentional anatomy. Their older
128-pixel bodies are style references, not the new monster resolution requirement.
Use the [acceptance registry](../../../workspace/docs/art/characters/accepted.json) to distinguish
accepted work from candidates. The old monster placeholders and rejected first
character roster do not establish the desired art quality.

Carry those rendering principles into the creature's own anatomy. A rat should
have a convincing rodent silhouette, weight-bearing paws, muzzle and tail; a
winged creature needs believable wing attachments and a readable wing pose.
Do not force human proportions, anime human faces or a humanoid standing pose
onto a different species. Humanoid enemies can use the character references for
armor, visible faces, concealed heads and convincing equipment grips.

Use broad material shading, clear value separation and stepped contours. Give
the creature one or two strong identifying features before adding smaller detail.
Show thickness where it matters: shell edges, horns, claws, teeth or armor plates.
Group fur, scales and feathers into purposeful masses rather than scattered
texture pixels. Avoid thick uniform outlines, incidental speckles and muddy
overlapping details. Preserve detail that describes structure; do not reduce the
design to generic flat polygons. Magical light, colored rim light and effects
belong only where the brief supports them.

## Body scale and framing

Use **256 source pixels as the maximum visible body extent in either axis**:
body width and body height must each be at most 256 px. This is a ceiling, not
a target for every monster. Choose smaller dimensions for physically small
creatures such as rats and slimes; preserve their size relative to larger enemies.
As provisional art budgets, try a 48–96 px longest body edge for small creatures,
96–192 px for medium creatures, and up to 256 px for large creatures. These bands
are starting choices, not fixed species rules; record the chosen size in the brief.

- For a maximum-height grounded humanoid, a **384 x 320** transparent cell can use body top
  `y = 32`, feet on baseline `y = 288`, center near `x = 192`. The visible body
  occupies 256 rows, `y = 32` through `287`.
- Measure the body from its topmost anatomical/headwear feature to its lowest
  body pixel. Attached horns, wings and tails are anatomy; held weapons,
  detached effects and transparent padding are excluded. Record an additional
  torso/standing height when large appendages make overall height misleading.
- For a rat, serpent, flying creature or other nonhumanoid, preserve natural
  proportions and choose an appropriate canvas. Measure the complete anatomical
  bounding box, including attached horns, wings and tails: its longest edge must
  not exceed 256 px. Long or wide anatomy may therefore need a lower body height.
  Do not stretch or crop anatomy to satisfy the limit. Padding, equipment and
  detached effects may make the canvas larger than 256 px.
- Record canvas size, body bounds, body width and height, complete silhouette bounds,
  baseline or airborne anchor, and intended display bounds. Keep registration
  stable across animation frames; size the canvas for the largest required pose.
- Fit the complete creature proportionally inside its battle area. Keep ears,
  wings, horns and tail clear of health bars and frame edges. Decide ordinary
  enemy/boss scale from the encounter, rather than enlarging every body to fill
  the entire slot. Use a consistent display scale across the roster so small
  creatures remain visibly smaller; do not auto-fit each cropped image to the
  same display box. Inspect at actual UI scale before committing the dimensions.

Separate source resolution from display scaling. Prefer nearest-neighbor filtering
and integer enlargement for pixel art. If a display needs substantial reduction,
review a prepared smaller export for lost features; do not assume adding source
pixels improves the result. Preserve older artwork when adopting this new budget.

## Brief and generation

Record species/body plan, enemy role, build, pose and facing, head/eye treatment,
material palette, defining features, equipment, optional effects and encounter
scale. Variants should differ through silhouette and anatomy as well as color.
For an existing named enemy, preserve its established identity.

Use [the generation prompt](references/generation-prompt.md) when preparing a
concept. Generate one complete creature with the built-in image-generation tool
and true transparency. Supply inspected references with explicit roles. An
enlarged pixel-style concept does not establish a sprite at the chosen native size:
adapt and inspect the actual source grid before calling it production artwork.
Keep the original concept as provenance rather than overwriting it during cleanup.

## Editable production and delivery

Use spritex JSON for editable production and CLI rendering. Use useful named
layers such as torso, head, near/far limbs, wings,
tail, armor and effects, chosen for the creature's anatomy. Record whether layers
contain only visible surfaces; do not imply hidden anatomy has been reconstructed.
A single flattened pixel grid is not a reconstruction of separate parts.

Deliver layered spritex JSON and CLI-generated transparent PNG and native SVG on an
integer **1 SVG unit = 1 source pixel** grid with `shape-rendering="crispEdges"`.
Use stepped silhouettes and integer geometry; avoid fractional or antialiased
curves. Separate optional spells/aura from anatomy so effects can be adjusted
without changing the body. Reuse the same design for an optional UI thumbnail;
make a simplified variant only when small-scale readability requires it.

Save each version under `workspace/docs/art/concepts/monsters/<enemy>-vN/` with the exact
brief/prompt, original concept, reference paths/hashes, tools used, production
dimensions/anchor, editable source, exports and review status. Preserve prior
versions. Record adjustments made between the generated concept and final art.
Update acceptance or game integration only within the user's requested scope;
a new concept is not automatically an accepted replacement.

Each task owns its own output directory and JSON document. Independent briefs,
concept work and file validation can run concurrently when agents are assigned.
Keep CLI output stems and JSON paths separate; never overwrite another task's files.
This skill does not require spawning agents for an ordinary single-creature task.

## Review

Review the render at native size, intended battle size and enlarged. First check
the complete silhouette, weight, anatomy and pose; then facial/eye readability,
appendage attachments, material planes and any hand-to-handle contact. Check
that the health bar and frame leave the whole creature legible. Compare with
accepted characters for rendering quality, while allowing species-specific shapes.

Validate canvas dimensions, measured body bounds (both axes at most 256 px),
relative creature size, padding, anchor, transparency,
named layers and matching PNG/SVG appearance. Verify that effect layers are
excluded from the reported body measurements. Report artistic judgment
separately from numeric checks: technical correctness and self-review are not
user acceptance. Fix unclear or awkward designs even when their grid is correct.
