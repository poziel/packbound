---
name: delver-creator
description: Create or modify Packbound Delvers, including identity, biography, appearance, class gameplay, structured character records, and coordinated pixel artwork. Use for complete Delver development or profile changes; standalone sprite work uses delver-art-creator.
---

# Delver Creator

Develop a complete Delver, not just a sprite. Use the game's term **Delver** in prose; retain `assets/characters` and `character.json` as technical names. Keep a stable lowercase kebab-case ID independent of name, title or class.

## Understand and develop

Start with the design brief and supplied references. New designs do not require pre-existing code. For existing Delvers, inspect data and implementation only when reconciling game-facing values; keep code citations and implementation notes out of the README. Distinguish intrinsic powers from starting-item effects and signature visual equipment. Legacy `armor`, shield protection, plating and Block are not interchangeable.

For a new Delver, develop name, title, familiar class archetype, role, specialty, biography, motivation, personality, detailed appearance and a coherent gameplay loop. Define strengths, weaknesses and the requirements and outcomes of their signature mechanics. Include starting HP, mana, stamina, capacities, innate damage/protection, starter items and spells or other powers. Specify timing, costs, targets, limits, reset rules and interactions rather than merely naming a power. A spell is optional; do not give every class magic.

Preserve supplied decisions. Resolve routine details with a coherent proposal; ask only for missing decisions that materially block the work. Label new or undecided mechanics as proposed or unresolved, never implemented. A design request does not automatically request combat code changes.

Read [references/character-contract.md](references/character-contract.md) for the record and README contract. Every new character.json must copy [the complete example](references/character.example.json) and conform to [the fixed schema](references/character.schema.json), keeping identical object keys/nesting and typed collection entries. Read [the current runtime audit](references/runtime-character-audit.md) when assessing integration; do not assume JSON is loaded. Write the README first as an independent design and art brief, then derive game-facing character.json data. The files serve different purposes and must not replicate each other; keep overlapping identity and ability facts consistent. Explicit zero means none; null means unknown or undecided. Never silently turn an unknown value into zero.

## Canonical folder

```text
assets/characters/<id>/
  README.md
  character.json
  concept/
    ...supplied visual reference images
  art/
    concept.png                 # optional generated concept
    full-body.sprite.json
    full-body.png
    full-body.svg
    portrait.sprite.json
    portrait.png
    portrait.svg
    provenance.json
    art-manifest.json
    ...additional requested animation sources/exports
workspace/archives/characters/<id>-<UTC timestamp>-<unique suffix>.zip
```

Keep one current set in `art/`, with stable descriptive names and no `v2`, `v3` or revision subfolders. Include generated concepts, native sources, exports and provenance there; compatibility outputs are optional. Record approval separately from profile completeness. Do not migrate unrelated characters or erase legacy provenance as a side effect of using this skill.

## Reference images and examples

Preserve supplied inspiration images in `concept/`, alongside `art/`, with source/attribution when known. Link existing concept images from the README and explain which features inform the design, which to adapt and which to avoid. Do not invent reference files or copy production art merely to fill the folder. Generated artwork stays in `art/`.

Read the [assassin](references/examples/assassin.md), [mage](references/examples/mage.md) or [necromancer](references/examples/necromancer.md) examples for biography, powers and appearance detail. These are design briefs, without code references, production specifications or generated-art links.

## Artwork

Read [the art handoff contract](references/art-handoff.md) before selecting generate, revise, reuse or no-art mode. It defines the exact required files for generated sets, allows additional art files, and specifies the art skill’s manifest return and mapping into character.json. Missing art triggers the art skill during full creation; profile-only edits reuse art. An explicit no-art request skips generation and reports missing assets as deferred.

By default a full Delver creation includes artwork: invoke [delver-art-creator](../delver-art-creator/SKILL.md), which uses [spritex](D:/Dev/5-tools/spritex/skills/spritex/SKILL.md). Create the README before artwork and supply it together with concept references as the identity, appearance and equipment brief. Use the current project density, layered numeric JSON, transparent PNG/integer-grid SVG and separate detailed 64 × 64 portrait contract. Route requested item, UI or keyword art to their corresponding project skills.

For profile-only edits, preserve existing art. For visual changes, redraw only affected assets, preserving identity unless the request changes it. Stage work in a separate temporary directory so a failed generation cannot damage current files. Inspect native/UI-size pixels and provenance as well as technical validation; never call self-reviewed art accepted. Runtime installation requires existing authorization for that installation or explicit acceptance.

## Modify and archive

Before the first mutation to an existing Delver folder, create a verified ZIP snapshot of the **entire folder**, including README, JSON, hidden files, concept references, art and provenance:

```powershell
python .agents/skills/delver-creator/scripts/archive_delver.py --root . --id warrior
```

The helper creates a timestamped archive under `workspace/archives/characters`, hashes and verifies every file, and maintains `workspace/.gdignore`. It never deletes or changes the original folder. Stop on failure; never overwrite without a verified snapshot. Compression savings vary, especially for PNG and other compressed files.

Prepare and validate the updated folder separately, then update the canonical folder. Historical-only art/version directories belong in the verified ZIP, not beside current art. Remove superseded active files only after verifying they exist byte-for-byte in the archive and that no runtime/catalog/source references still require them. Preserve accepted artwork bytes when merely reorganizing. Keep legacy runtime copies until their callers are deliberately migrated. For shared files outside the Delver folder, separately preserve their prior state before changing them; the ZIP helper does not capture them.

## Deliver and verify

Check JSON parsing, ID uniqueness, relative asset links, starter item IDs, supported versus proposed mechanics, agreement of overlapping README/JSON facts, native source validation and rendered art. Inspect catalog consumers before updating them. The existing `.agents/skills/delver-art-creator/scripts/build-character-catalog.cjs` supports the five legacy v1 profiles and writes only `workspace/docs/art/characters/catalog.json`; design READMEs remain independently authored. Do not run it blindly over v2 records or claim it registers a new Delver. The acceptance registry lives at `workspace/docs/art/characters/accepted.json`, outside the character asset root.

Report the Delver folder, changes, archive path, verification performed, proposal/approval state and whether the game actually consumes the new data. File creation alone does not add a playable class.
