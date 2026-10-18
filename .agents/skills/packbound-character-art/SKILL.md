---
name: packbound-character-art
description: Create distinct Packbound pixel-art characters and matching portraits with cohesive fantasy proportions, convincing equipment grips, helmeted or concealed-face designs, and anime-inspired visible faces. Use for character concepts, layered spritex JSON sprites, roster variations and portraits; inventory items use packbound-item-art.
---

# Packbound character art

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

Create an original, recognizable character with a convincing complete silhouette.
The head must work in the game's portrait UI, whether it is an exposed face,
helmet, mask, skull or intentionally dark hood. Work from this game's root.

For an existing roster member, read `assets/characters/<class-id>/character.json`
and its Markdown profile before preparing the brief. These define the character's
name, role, identity, appearance, equipment and portrait framing. The full roster
is available in `workspace/docs/art/characters/catalog.json`. Preserve these identity details
unless the user requests a revision; read the current gameplay source before
changing any mechanic descriptions. Profile lore does not establish art approval.

## Current visual direction

Warrior v3 was redrawn at 256 px and directly installed at the user's request
on 2026-10-16. Inspect its [review and layered sources](../../../workspace/docs/art/concepts/characters/warrior-v3/README.md)
for the current warrior implementation. The accepted v2 originals below remain
historical style references and are preserved; direct installation does not
claim a separate visual approval of v3.

The user accepted [warrior v2](../../../workspace/docs/art/concepts/characters/warrior-v2/README.md)
as a game asset on 2026-10-15. Inspect its actual native sprite or enlarged preview
as the primary Packbound rendering/style anchor for new characters. Follow its
cohesive proportions, material volume and controlled pixels while preserving each
class's distinct identity, costume, face treatment and equipment. Acceptance is
recorded in [the asset registry](../../../workspace/docs/art/characters/accepted.json).

The user also accepted [ranger v2](../../../workspace/docs/art/concepts/characters/ranger-v2/README.md)
on 2026-10-15. Use it alongside the warrior for cloth/leather
rendering and an exposed anime-inspired face. Compare new classes with both accepted
sprites while retaining distinct identities; neither acceptance approves later classes.
These v2 originals use the older 128 px body height. Preserve them unchanged;
their rendering and identity guide new work, not their old resolution.

Read [the current reference guide](references/visual-direction.md) and inspect
the relevant actual images before designing. The user's eight new references
take precedence over conflicting older face, proportion and lighting guidance.
Use the armored/hooded figures for full-body design and the anime examples for
exposed faces and close-ups. Their backgrounds, poses and effects are not blanket
requirements. Create original characters rather than copying reference identities.

The earlier workspace/docs/art/references/warrior-approved.png and ranger-approved.png
remain secondary material/rendering references. The [Megaloot screenshot](references/megaloot-portrait-layout.png)
guides portrait presentation, not full-body anatomy. The user rejected
workspace/docs/art/concepts/characters/pixelorama-roster-v1/: never treat its sprites,
procedural body templates or enlarged crops as an approved style target.

## Proportions, pose and equipment

- Aim for cohesive stylized fantasy anatomy. Judge head/helmet mass against
  shoulders, torso, pelvis and legs as a whole. Fit armor around that structure.
  Avoid both oversized heads and undersized heads on stretched bodies, long thin
  necks, stilt-like legs, swollen boots and disconnected-looking joints. Do not
  interpret the old "small head, long legs" wording as independent adjustments.
- Default to the user's upright, relaxed, slight three-quarter right stance,
  grounded feet and subtle weight shift. Keep the torso and head angle coherent.
  Allow natural elbows and asymmetry appropriate to the equipment; avoid a rigid
  mirrored mannequin pose. Follow a requested alternative pose when supplied.
- Make the grip physically readable: the palm closes around the handle, the
  thumb/fingers overlap it, the wrist connects to the forearm, and the weapon's
  angle follows that grip. A sword's hand sits between pommel and guard, with the
  guard separating it from the blade. A hand merely touching a weapon edge fails.
  Check bow grips and shield handles/forearm straps with the same care.
- Keep gear clear of the portrait area. Preserve enough canvas for the complete
  silhouette, without using padding or equipment to meet the body-height rule.

## Head design and identity

Choose a head treatment in the brief: **visible anime-inspired face**, partial
mask, closed helmet, shadowed hood, or an appropriate nonhuman design. An exposed
human face is not mandatory. Do not remove a helmet, force two visible eyes through
a visor, or invent skin features inside an intentionally faceless hood.

For exposed faces, use the new anime references: deliberate eye/lid shapes,
coherent gaze and perspective, a simplified nose and mouth, a clear cheek/jaw
silhouette and structured hair clusters. Stylized expressive eyes are welcome;
keep them integrated with the head. Avoid muddled semi-realistic facial shading,
bulbous nose/mouth blobs, arbitrary eye pixels and accidental cross-eyed features.
Anime facial language does not imply a chibi body or the same youthful face for
every character. Age, build and presentation remain part of the identity brief.

Record role, life stage, build, head treatment, face shape/skin tone when visible,
eyes/brows, hair/headwear silhouette, expression, costume and equipment. For a
concealed face, distinguish the character through helmet shape, visor, crest,
hood opening, mask or restrained eye accents. For a roster, compare these briefs
before drawing: a costume recolor alone is not a new identity. Preserve a named
character's established features when making variants.

## Pixel treatment

Use deliberate connected clusters, stepped contours, sculpted material planes
and clear value separation. Armor should have weight and articulated plates;
cloth should have convincing volume and folds. Restrained detail means avoiding
noise, not flattening everything into a few generic geometric shapes. Use an
intentional material palette and selective highlights. Dark outlines or shadows
can describe structure; avoid a thick uniform border around every part.
Use the larger source grid for convincing anatomy, readable thickness, clean
facial features and material transitions. Broad shading and one or two defining
details per major part take precedence over scattered texture pixels. More
pixels do not justify adding scratches, trim or highlights everywhere.

Choose lighting appropriate to the design. Warm/cool accents and magical light
are options, not mandatory orange/cyan rims or glowing effects on every asset.
Keep surroundings transparent. Do not copy scenery, frames, ground shadows,
halos or spell effects from a reference unless the brief requests them.

## Workflow and editable sources

Use the [prompt template](references/generation-prompt.md) with the chosen head
treatment, relevant reference roles and grip description. For generated concepts,
use built-in image generation with true transparency. For editable production in
this project, author layered spritex JSON and compile it through the CLI.
Keep head, hands, clothing and equipment on useful named layers.
A flattened pixel grid is not a reconstruction of separate parts. Shape scripts
may assist drawing, but do not substitute them for visual design and iteration.

Save the source, exact brief/prompt, reference filenames/hashes, tool used and
review status in a new version under workspace/docs/art/concepts/characters/. Preserve
older artwork and original reference provenance. For a roster, create each asset
separately and compare them together. Complete the authorized batch; no per-image
approval is needed unless the user requested a concept-approval checkpoint.
Parallel agents can prepare separate briefs, concepts and version directories.
Each task owns its JSON and output paths; never overwrite another task's source
or exports. Independent files are safe to work on concurrently.

## Portraits and source scale

New or explicitly redrawn full-body characters default to **256 px visible body
height**, measured from head/headwear to soles, on a **384 x 320** transparent
cell: top y32, baseline y288, center near x192. Weapons, detached effects and
padding do not count toward body height. Measure nominal weapon length along its
axis, including hilt and pommel: round(body height x relative length), giving
128 px long sword (1/2), 85 px short sword (1/3), and 64 px dagger (1/4).
Keep registration consistent across a roster and animation frames. Native SVG
uses integer geometry, 1 unit per source pixel and crispEdges; deliver matching
CLI-generated PNG/SVG exports and layered spritex JSON. Do not automatically upscale or replace
accepted 128 px assets. Record the body/canvas target for every new version.

The default UI portrait is an independently prepared **64 x 64** image derived
from the **original generated concept or other detailed character source**.
Do not enlarge a 32/40 px face crop from a reduced full-body sprite and present
it as a detailed portrait. Keep the original concept intact and work on a new
derivative. Full-body and portrait resolutions are independent.

Center the face/head visually within the square, with balanced breathing room,
the complete hair/headwear silhouette, chin and enough neck/shoulder context.
For an asymmetric crest or hood, balance the visible head rather than centering
the bounding box of all stray pixels. Align comparable eye levels across the
roster where head treatments allow. Preserve the head angle, expression, facial
identity, hair, eyes, skin, headwear and costume; keep concealed faces concealed.

The head must be unobstructed in the final portrait. If a weapon or other
incidental element overlaps it, remove that element and reconstruct the hidden
head/hair/headwear; merely erasing the obstruction and leaving a hole fails.
Keep intentional helmets, masks and face concealment as identity features.

Prepare and clean this close-up deliberately: remove unrelated weapon tips,
spell fragments, awkward cloak slivers, detached pixels and resampling artifacts
that intrude from the full-body composition. Reconstruct the resulting portrait
edge and necessary shoulder context coherently. Retain intentional identifying
features. Built-in image editing can prepare the concept derivative; use
layered spritex JSON for the native portrait and pixel cleanup, then verify the
delivered 64 px grid. Prefer clean
eye/lid shapes and hair clusters to texture. Inspect at 1x and the intended UI
size; nearest-neighbor enlargement cannot create missing facial detail.

Record the portrait's relationship to its source accurately:

- **Exact crop:** unchanged RGBA pixels from a recorded source rectangle, without
  resizing, cleanup or redrawing.
- **Concept-derived matching portrait:** a resized, reframed or cleaned
  derivative; record source hash, crop/transform and cleanup performed. This is
  the default production portrait and must not be labeled an exact crop.
- **Separately drawn/generated matching portrait:** when the detailed source
  cannot support the required framing or expression, use it as the identity
  reference for a new close-up and label that provenance explicitly.

Use scripts/portrait.cjs with Node and sharp to produce the **64 x 64** derivative
from a visually chosen square in the original concept. The default mode resizes
to exactly 64 x 64 using nearest-neighbor sampling and rejects crops smaller than
64 px. The framing rectangle must center the head rather than nearby equipment.
Finish obstruction repair and pixel cleanup in a separate 64 x 64 spritex JSON
document, validate it, and export the final PNG/SVG through spritex. The helper's
PNG is an intermediate, not the final production rendering authority.

~~~powershell
node .agents/skills/packbound-character-art/scripts/portrait.cjs --source PATH/concept.png --rect X,Y,SIZE,SIZE --out PATH/portrait --stage concept
~~~

Use --stage concept for original generated concepts and --stage production for
384 x 320 sources (legacy 192 x 160 sources remain supported). Add `--mode exact`
only for an explicitly requested unchanged crop or intermediate extraction; that
mode retains its original dimensions and does not produce a standard portrait.
The helper records the source hash, framing, transform and output dimensions and
refuses existing outputs. It cannot detect head placement or repair obstructions.
Keep its metadata as an intermediate record and document subsequent cleanup.

Validate the actual production exports, not only the generation prompt:

~~~powershell
node .agents/skills/packbound-character-art/scripts/validate-character.cjs --sprite PATH/full-body.png --body PATH/body-without-gear-and-effects.png --portrait PATH/portrait.png
~~~

Export `--body` through spritex from a temporary copy of the same registered JSON
with held-equipment and detached-effect layers hidden; retain the original source.
The validator requires a 384 x 320 sprite/cell,
body bounds y32..287 (256 px), and a separate 64 x 64 portrait. It does not certify
anatomy, head centering, obstruction cleanup or user approval. Never obtain a new
256 px body by simply doubling the accepted 128 px pixels; adapt from detailed
source art and resolve features on the new native grid.

## Review before delivery

Compare the actual render with the selected references at native/display size
and enlarged. Check the complete silhouette and body balance first, then the
head treatment, facial readability, hand-to-handle contact, wrists and joints.
Also inspect the 64 x 64 portrait in its intended UI frame: centered head,
complete hair/headwear and chin, clear facial features, clean edges and no
irrelevant body/equipment fragments. Compare its identity with the full body
and original concept, not only an enlarged small sprite.
Revise distorted proportions, unclear grips or muddy faces even when all numeric
checks pass. Compare a roster for consistent rendering and distinct identities.

Report artistic review separately from technical checks (dimensions, alignment,
transparency, native layers and matching exports). Passing those checks does not
prove that the character looks good, and self-review is not user approval. Record
rejected work as rejected and use it only to understand the failure.


## Handoff when invoked by the Delver creator

When `packbound-delver-creator` requests art, read its [art handoff contract](../packbound-delver-creator/references/art-handoff.md). Use the supplied README, concept references, requested output directory and revision scope. Deliver the exact required canonical files plus any useful additional production files; preserve untouched outputs on partial revisions. Return `art-manifest.json` using the linked example, with actual project-relative paths, performed checks, reused outputs and honest approval status. The Delver skill uses that return to populate game-facing asset references. Do not edit gameplay JSON or regenerate unrelated art as part of the art handoff. This conditional contract does not migrate existing assets or change standalone art-request output locations.
