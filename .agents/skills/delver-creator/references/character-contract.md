# Delver record and profile contract

The README is the independent design brief, written before art or code. `character.json` is a game-facing data record, not a serialized README. Keep overlapping facts consistent without duplicating the full narrative or appearance brief.

## character.json

Include only information intended for game consumption:

- Stable ID, schema version, display name, title and class/role identifiers; short display descriptions and a player-facing bio are appropriate.
- Starting HP, shield protection, Block, mana, stamina, capacities, innate effects, starter item IDs and structured abilities. Distinguish intrinsic values from equipment-derived totals.
- Ability IDs, triggers, requirements, costs, effects, targets, limits, duration and reset rules. Use supported engine IDs when integrating an existing class. New designs may define proposed data before code exists; do not claim those values execute automatically.
- Usable visual configuration such as material/part color palettes for hair, skin, buckler and clothes. Name palette groups and color roles consistently, for example `visual.palette.hair.base`. Include concise variant/species identifiers only when a consumer needs them.
- Asset IDs or paths when needed by the game and only once real assets exist. Do not invent paths before generation.

Do not include extensive physicalAppearance prose, personality lists, mannerisms, voice direction, art prompts, avoid lists, portrait framing, generation instructions, source-code citations or production/approval history. Those belong in the README or separate provenance metadata. A short bio intended for display is useful; a grumpy personality flag without a consuming feature is not.

Existing schemaVersion 1 profiles contain legacy narrative and production fields. This change establishes the future contract; do not bulk-rewrite existing JSON or change its consumers during a README/examples task. When a data migration is requested, inspect consumers, archive the prior record and introduce an explicit schema version for the changed structure. Preserve displaced design details in the README and provenance instead of losing them.

Explicit zero means none; null means unknown or undecided. Keep the fixed template slots; use null only for fields whose schema allows it, and record unsupported capability requirements outside import data. Record unresolved design/integration decisions outside game-import data unless a tooling consumer explicitly requires them.

## Fixed version 2 structure

Every new Delver must copy [character.example.json](character.example.json) and conform to [character.schema.json](character.schema.json). Keep exactly the same object keys and nesting; arrays may vary in length, but their entries use the defined shape. Keep empty arrays and nullable slots. Do not invent alternate keys or omit sections. Proposed import data does not imply runtime support. Do not convert existing v1 profiles unless migration is requested.

- `identity`: player-facing identity and short biography, without the full appearance/personality brief.
- `selection`: icon item and mechanic text for the roster/tooltip.
- `gameplay.health`: initial and maximum HP.
- `gameplay.resources`: intrinsic base capacities, class bonuses and refill timing. Equipment bonuses are calculated separately, never baked into these fields. Initial combat mana/stamina equal the resolved capacities; preparation-screen zero balances are runtime state, not character base values.
- `gameplay.protection`: intrinsic starting Block, regeneration/floor/retention, starting shield protection, plating and ward. These are separate concepts; defaults of zero must reflect a deliberate design decision.
- `gameplay.startingItems`: ordered item IDs, grid positions and rotation. These are definitions, not saved runtime instances.
- `gameplay.abilities`, `startingEffects`, `innateEffects` and `companions`: reusable effect records and explicit companion values. Ability costs use resource/amount; parameters use key/integer value for mechanics such as an interval or turn offset. A missing rule belongs in design notes until the shared schema is deliberately extended, not in arbitrary extra fields. `usesPerFight: null` means unlimited; unresolved numeric decisions must be resolved before presenting a finalized import record.
- `visual.palette`: fixed part/shadow/base/highlight entries; include as many material/body-part groups as useful. `visual.assets`: keep all slots null until assets exist; then use project-relative paths. README links to production art remain excluded.

The example is based on Garran's identity and the inspected Warrior defaults. Null assets intentionally demonstrate the pre-art workflow; it is not a migration of his installed profile. Starting Block is intrinsic zero; the shield and adjacency bonuses are calculated from his loadout. Never turn illustrated equipment into free stats. `startingShield`, permanent Block floors and generic ability/effect records are proposed future capabilities, not current engine configuration.

Read [runtime-character-audit.md](runtime-character-audit.md) before planning JSON integration. No loader is provided by this skill update.

## README.md

Write this first, before generating art. Lead with name, title, class and a brief introduction. Include who they are (bio, personality, motivation, mannerisms and voice), specialty and powers, and a substantial visual brief: body/silhouette/bearing, head and face, clothing/hands, weapons/equipment, palette, recognizable features, pose/effects, portrait framing and things to avoid. Explain gameplay intent and understandable ability requirements/outcomes in prose. Numbers are welcome when they clarify an ability, but implementation variables, internal IDs and code paths are not.

Do not reference existing or future code, link generated art/exports/native sources, include production dimensions/coordinates or CLI instructions, or present the README as generated from JSON. No runtime status or acceptance ledger belongs here. Production rules remain in the art skill; provenance remains beside the art.

When supplied inspiration exists, add a visual-reference section linking actual files under `concept/` using relative Markdown links, explaining what each contributes. These input references are the exception to the no-art-links rule. Do not add a reference section with broken or hypothetical links when none were supplied.

Use the [assassin](examples/assassin.md), [mage](examples/mage.md) and [necromancer](examples/necromancer.md) examples for tone and depth. Preserve manual prose when editing. Keep the README independent from JSON: it guides character development and art, while JSON supplies data for game consumers.

## Asset completion

Follow [art-handoff.md](art-handoff.md). Null asset slots support drafting and explicit no-art work. When generation is requested, require the canonical outputs, consume the art skill’s verified manifest and fill the three existing visual.assets slots with actual paths. Do not claim art completion with missing files. Profile-only edits preserve verified existing assets without generation.
