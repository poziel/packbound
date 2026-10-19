# Current Delver runtime audit

Inspected 2026-10-17. This describes current code, not a promise that the proposed JSON schema is supported.

## Data sources and consumers

No runtime references to per-Delver `character.json` or `workspace/docs/art/characters/catalog.json` were found in scripts, scenes or components. `PackCatalog.classes()` in `scripts/pack_catalog.gd` defines class name, HP, icon item, mechanic label/detail, starter IDs and Vector2i placements. `PackRun.reset()` in `scripts/run_state.gd` reads those definitions, starts at full HP and adds exactly three starter items. A future loader must remove that fixed count assumption.

`delver_tooltip.gd`, `class_selection.gd`, `delver_tile.gd`, `run_selection.gd`, `menu_flow.gd`, `run_inventory_preview.gd`, `main.gd` and character preview components consume the class dictionary. Save validation in `run_saves.gd` checks class IDs against it. Stable IDs must survive migration. Identity names, biographies and palettes in existing profile JSON are not currently consumed by these systems.

`PackArt.character_head()` in `scripts/pack_art.gd` loads portraits by class ID from `assets/characters/<id>/art/portrait.png`; character art paths also require review during migration. Changing JSON paths alone will not relocate runtime art.

## Resources and mechanics

Base mana is 1; base stamina is 3; Mage adds 3 mana capacity. `starting_resources()` adds equipped mana/stamina/Block, shield adjacency bonuses and mirror contributions. `round_resources()` also adds per-round resource contributions; `_refill_round_resources()` restores mana/stamina to those budgets each round. `start_combat()` initializes Block from the loadout. Spent Block does not automatically refill each round. Intrinsic protection and item totals must remain distinct in JSON.

Class-specific branches implement Assassin invisibility on turns 1,4,7; Ranger ranged repeats every third turn; Warrior retaliation for 4 plus plating after a fully defended action; Necromancer starts with one thrall, caps at three, and each contributes 2 damage per round. Companion persistence and raising are code rules. Generic JSON abilities do not execute these branches today.

## Minimum migration work

Load/validate versioned records and adapt them to class selection, run initialization, art resolution and save validation. Transfer HP, icon, mechanic display, starter IDs and placements first. Separate display name from class name. Replace base-resource constants and class-specific bonuses deliberately. Parameterize existing mechanics before enabling arbitrary new abilities, intrinsic damage, shield values or permanent Block floors. Add meaningful compatibility/error checks and verify current classes retain their behavior. Keep README design prose and production provenance outside the runtime record.

The skill update supplies examples and a schema only. It does not change gameplay or load JSON.
