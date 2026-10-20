# Asset editing guidelines

Read the root [project guidelines](../AGENTS.md), then the [asset README](README.md) for folder ownership, content filenames, discovery and refresh behavior. Read the owning category/package README before editing it. Keep detailed folder maps and runtime explanations in those documents rather than repeating them here.

## Placement and preservation

- Keep production assets and authored content under their existing owner. Content-specific definitions, supporting effects, art and notes belong with that identity; shared assets are referenced rather than copied into consumers.
- Keep accepted editable sources, exports and provenance together. Preserve stable content IDs, resource UIDs, import settings, source registration and original artwork bytes during organization-only changes. Move paired sidecars and update static, dynamic and registry references.
- Items use flat `art/` folders: `item.png`, optional matching `item.pixloom.json`, and the image import sidecar. Keep the actual in-game image; archive superseded artwork and other source formats in a verified ZIP under `workspace/archives/items/`. Do not infer acceptance from revision numbers or fabricate missing sources.
- Temporary concepts, reviews, screenshots, scripts and diagnostics belong in `workspace/tasks/<task-name>/`; retained material follows the [workspace convention](../workspace/README.md). Archives belong in verified ZIPs under `workspace/archives/<category>/`, outside production assets.
- Audio audition clips in `audio/sfx/candidates/` remain candidates until assigned to an approved event. Do not turn the folder into a runtime effect pool. Preserve audio provenance and distinguish source recordings from playback conversions.
- Organization work does not authorize redrawing, rescaling, replacing accepted artwork or changing balance. Exploring or importing a candidate does not establish visual acceptance.

## Choose the creator skill

Read the applicable skill before creating or explicitly revising that content. Skills own detailed art dimensions, source formats and review workflows; use current task requirements to resolve conflicts rather than copying old specifications into this guide.

| Task | Required project guidance |
| --- | --- |
| Complete Delver identity or gameplay profile | [Delver Creator](../.agents/skills/delver-creator/SKILL.md). |
| Character sprite or matching portrait | [Delver Art Creator](../.agents/skills/delver-art-creator/SKILL.md). |
| Complete item/relic definition or design | [Item Creator](../.agents/skills/item-creator/SKILL.md). |
| Inventory item/relic artwork | [Item Art Creator](../.agents/skills/item-art-creator/SKILL.md). |
| Whole-body monster artwork | [Monster Art Creator](../.agents/skills/monster-art-creator/SKILL.md). |
| Navigation, action or control glyphs | [UI Icons Art Creator](../.agents/skills/ui-icons-art-creator/SKILL.md). |
| Inline stat, status or effect symbols | [Keyword Icon Art Creator](../.agents/skills/keyword-icon-art-creator/SKILL.md). |

## Author content and verify consumers

- Edit typed `.tres` definitions directly. Preserve stable IDs, footprints, restrictions, costs, recipe priority, category relationships and existing behavior unless the requested change intentionally modifies them. Design records and historical JSON must not become a competing gameplay authority.
- Follow the README's refresh procedure after adding or relocating definitions; save refreshed Resources. Do not hand-maintain the generated collectible snapshot as the registration authority. Registration, reward-pool membership and executable ability/status behavior are separate contracts.
- Keep ability/effect Resources with their owning content; inspect runtime adapters and handlers before adding rule IDs or changing parameters. Preserve save compatibility when changing serialized identifiers or gameplay fields.
- For icon changes, preserve the keyword registry's identities, aliases, colors and texture mappings. Review symbols in their actual consumers, not only enlarged previews.
- After moves, verify paths and perform a serial Godot import before relevant tests. For resource/editor behavior, follow [Godot authoring](../docs/godot-authoring.md). For any test changes, follow [test authoring](../tests/AGENTS.md).
- Verify content validation and affected gameplay consumers. Inspect new artwork at intended display size and audio in its intended event/bus/loop context. Technical validity does not establish visual quality or approval. Report the checks actually performed and remaining limits.
