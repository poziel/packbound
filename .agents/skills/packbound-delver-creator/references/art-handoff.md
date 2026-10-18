# Delver / character-art handoff

## Select the mode

- Full new Delver: generate missing art by invoking `packbound-character-art`, unless the user requests design/data only.
- Profile/gameplay-only edit: reuse existing art and retain its verified references. Do not invoke generation simply because a new canonical filename is absent in a legacy folder.
- Requested visual revision: invoke the art skill for the affected outputs, reusing unchanged files. Archive the prior Delver folder before replacement.
- Explicit no-art request: complete README/JSON without generation. Keep existing valid paths, otherwise null. Report the missing art as deferred; do not claim an art-complete delivery.

## Request sent to the art skill

Supply Delver ID, README design brief, supplied `concept/` references, output/staging directory, requested changes, assets to preserve and this contract. This is a skill invocation by the same agent, not a requirement to spawn another agent. The art skill controls pixel authoring, layers, intermediate documents, rendering and visual validation.

For a complete newly generated art set, require these exact files directly under `assets/characters/<id>/art/`:

| File | Purpose |
| --- | --- |
| full-body.sprite.json | Layered editable spritex full-body source |
| full-body.png | Transparent full-body export |
| full-body.svg | Matching integer-grid export |
| portrait.sprite.json | Layered editable portrait source |
| portrait.png | Detailed matching 64 × 64 portrait |
| portrait.svg | Matching portrait SVG |
| provenance.json | Source/reference origins, transforms, editability and validation records |
| art-manifest.json | Machine-readable return of output paths and verification results |

Additional working files, generated concepts, animation sources/exports and compatibility documents are welcome. `concept.png` is not a required deliverable when no concept was generated. Supplied references remain in `concept/`; generated concept art remains in `art/`. Do not impose arbitrary restrictions on extra files.

## Return from the art skill

Use [art-manifest.example.json](art-manifest.example.json) as the return shape, replacing example paths and marking checks true only after performing them. Paths are project-relative final destinations; verify staged files before promotion and final destinations afterward. For a partial revision, the manifest describes the resulting whole set, including reused files, rather than pretending unchanged sources were newly authored. Record legacy omissions honestly; never fabricate a layered source for flattened art.

The Delver creator reads the returned manifest, verifies the Delver ID, path containment, file existence and reported checks, and then fills `character.json.visual.assets`:

| JSON slot | Manifest output | Required new canonical filename |
| --- | --- | --- |
| spritePng | spritePng | full-body.png |
| spriteSvg | spriteSvg | full-body.svg |
| portraitPng | portraitPng | portrait.png |

Editable sources, portrait SVG and provenance stay in the manifest/art folder; they are production records, not additional runtime JSON slots. Keep the existing fixed character schema. Fill only real verified paths; a failed or incomplete generation must not replace valid existing references. A complete art handoff requires all eight files and passing technical checks, with visual review recorded separately. Acceptance/runtime installation is a separate existing authorization boundary.

Before generation, drafting JSON with null assets is valid. After a full generation request, missing required outputs mean the art task is incomplete. Reuse mode can retain older verified paths without reorganizing or redrawing accepted art; apply the new filename contract when generating/migrating a set, not retroactively as a reason to redraw.
