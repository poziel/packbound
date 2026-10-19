---
name: item-creator
description: Create or modify game items and relics with stable IDs, design READMEs, structured numerical records, synergies, crafting and merge recipes, and coordinated Item Art Creator assets. Use for complete item development; standalone icon work uses item-art-creator.
---

# Item Creator

Develop complete items and relics: identity, mechanics, progression, lore, visual design and game-facing records. Read [the record contract](references/item-contract.md) and use [the example](references/item.example.json) as the initial record shape. It demonstrates a proposed item, not an existing catalog entry.

## Develop the item

Start from the user's brief. Inspect nearby entries in `scripts/pack_catalog.gd`, relevant effects in `scripts/run_state.gd`, the keyword mapping in `scripts/combat_keywords.gd`, and recipes in `scripts/pack_crafting.gd` when checking existing behavior. New design work may propose unsupported mechanics; label them as proposed rather than silently implementing them. Preserve existing IDs even when the display name changes. A name such as Shield Relic does not by itself establish that an object uses the relic equipment system.

Generate a stable lowercase snake_case ID for new content, matching current catalog keys. Check both item and relic catalogs, special definitions such as `scripts/archer_quiver.gd`, and authored item records for collisions. The definition ID is distinct from a run's numeric instance ID, icon key, display name and recipe ID. Never allocate a new ID just to revise an item.

Write the README first as an independent design and art brief. Cover identity/type, purpose, normal starting stats and costs, activation timing, targets, stacking, limits, duration/reset rules, strengths/tradeoffs, empowerment of other items, synergies, acquisition, crafting and merges, lore and detailed visual design. Explicitly say when there are no bonuses or recipes. Describe ingredients and quantities, consumed inputs, catalysts, output and quantity, placement/trigger conditions and failure behavior. Avoid claiming every item needs an upgrade or magic effect. Keep implementation notes out of the design prose.

Derive JSON from that brief. Put all mechanic-bearing numerical values in typed fields, including thresholds, probabilities, costs, durations, limits, bonus amounts and recipe quantities; prose describes their meaning rather than being their only storage location. Preserve descriptions and lore in JSON for game use. Use null for undecided values, zero for known zero, and empty arrays for known absence. Keep unresolved design decisions explicit. Do not invent numeric codes for named effects or IDs.

## Folder and assets

For new definitions use:

```text
assets/items/<id>/                 # kind=item
assets/relics/<id>/                # kind=relic
  README.md
  item.json
  concept/                        # supplied references, only when present
  icons/
    art/
      icon.sprite.json            # layered spritex authority
      icon.png
      icon.svg
      footprint.json              # inventory items
      provenance.json
      art-manifest.json
      ...optional concepts, authored variants and animation files
```

Keep an existing item's folder unless migration is requested. Do not reorganize the legacy category/revisions folders merely to create another definition. Use stable active filenames. Preserve original art/provenance; archive superseded material as a verified ZIP under `workspace/archives/items/` or `workspace/archives/relics/`, checking contents before removing originals. Working drafts and reviews belong under `workspace/`.

## Item Art Creator handoff

For full creation, use [Item Art Creator](../item-art-creator/SKILL.md) to produce missing art; design/data-only requests defer it. Existing-art or profile-only work reuses valid files. Supply the ID, kind, README, references, exact output folder, mask/orientation for inventory items, intended UI slots for relics and requested variants. Read [the handoff](references/art-handoff.md) for required return data. Item Art Creator owns source grids and image exports; Item Creator owns item.json and its references. Do not manufacture placeholder paths as completed assets.

Store asset links in JSON as project-relative paths without a leading slash; the consumer can convert them to `res://`. Use null for absent exports. Map only files actually returned and verified. Link available art from the README's visual-design section using paths relative to the README. Keep art approval separate from design completion and runtime integration.

## Runtime boundary and verification

This first-pass contract is an authoring format. The current game defines items/relics in `PackCatalog`, resolves mechanics in game scripts, registers art in `scripts/pack_art.gd` and recipes in `scripts/pack_crafting.gd`; creating item.json alone does not register content. Reinspect these consumers before integration. Only implement runtime changes when requested.

Check JSON parsing/types, ID uniqueness, record/README agreement, numerical coverage, keyword identities, recipe ingredient/output IDs and quantities, declared merge targets, relative paths and existence of delivered assets. Mark references to proposed future items explicitly. Check masks and rotation rules for inventory items. Art verification follows Item Art Creator and spritex, including UI-size visual inspection. For integration, run relevant catalog/combat/crafting/art checks and report what actually loads. Return the folder, ID/kind, design and art state, verification and remaining unresolved values without equating a new file with a usable runtime item.
