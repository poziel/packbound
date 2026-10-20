# Authored game Resources

Open `game_content.tres` in Godot to inspect the complete authored content graph.
It references `collectibles.tres`, five class/Delver pairs, all monster definitions
and the ordered crafting recipe list. Each accepted definition is beside its owner:

- Items: `item.tres`, including permanent quiver and quiver reward options.
- Relics: `relic.tres`. Shield Relic (`tower_shield`) remains a backpack item.
- Delvers: `character.tres`, `character_class.tres` and starting equipment records.
- Monsters: `monster.tres`, `behavior.tres` and ordered attack/effect Resources.
- Shared categories: `categories/*.tres`.
- Crafting: `recipes/*.tres`; ingredient requirements are owned subresources.
- Statuses: `status_effects/<id>/status_effect.tres` and referenced rule_effect.tres.
- Loot pools: `loot/pools/*.tres`, including candidate weights, unlock floors and order.
- Loot progressions: `loot/progressions/*.tres`, referencing registered pool IDs.

Supporting ability/effect files are referenced externally so each has one
authoritative copy. Textures reference existing accepted art; none was replaced.
Stable IDs, runtime stats, restrictions, costs, footprints, starter positions,
attack cycles and recipe priority were preserved from the current catalogs.
Existing structured records supply lore, tags, identity and biographies.
Character and collectible Resources now supply gameplay values directly; runtime
loading does not require the former per-content JSON records.

`CatalogRuleEffectDefinition` is an explicit migration binding to existing coded
owner rules. Its parameters preserve special fields not already represented by
typed definition properties. It does not execute arbitrary dictionaries. Ordinary
stats and costs are authoritative on their typed owner; monster base attack damage
is authoritative on the ordered action effects. Individual effect handlers can
replace these compatibility bindings as the runtime migrates.

Classification now uses the authored category graph: items have no role property,
and runtime catalog records expose category_ids. Combat, adjacency, relic bonuses,
reward grouping and UI query category ancestors. Numerical/combat execution uses resource adapters;
saves retain their existing instance dictionaries. Legacy saved role fields are ignored;
old adjacency target lists are translated for compatibility. Preference arrays are
neutral unless existing data declares them; no balancing values were invented.
Health capacities use ResourceType.HEALTH. The existing unbounded Momentum policy
is recorded as character metadata, without inventing a numeric capacity. Encounter
floor metadata preserves existing monster placement hints.

`systems/content/tools/create_content_resources.gd` now refreshes and saves only
the catalog snapshots. The original JSON conversion is complete; this command
does not recreate individual definitions or overwrite their authored values.
Edit the Resources directly.

Validate with:

```powershell
./tests/run_tests.ps1 -Suite systems -Test content_resources
```

## Automatic collectible discovery and editor labels

`game_content.tres` also has a top-level Refresh From Content Folders button.
It discovers collectibles/categories, character classes, characters, monsters and
recipes, validates the entire candidate graph, then updates its lists. Existing
recipe priority is preserved; new recipes append in filename order. The shared
external collectibles.tres reference is retained. Save affected Resources after
refreshing in the Inspector. Invalid discovery leaves the previous graph intact.

`game_content.tres` also has a top-level Refresh From Content Folders button.
It discovers collectibles/categories, character classes, characters, monsters and
recipes, validates the entire candidate graph, then updates its lists. Existing
recipe priority is preserved; new recipes append in filename order. The shared
external collectibles.tres reference is retained. Save affected Resources after
refreshing in the Inspector. Invalid discovery leaves the previous graph intact.

Items use item.tres and relics use relic.tres in their owning folders. Their
supporting files are rule_ability.tres and rule_effect.tres. Classes and monsters
use class_ability/class_effect and innate_ability/innate_effect respectively.
Every authored definition has a readable resource_name. Collectible labels track
display_name automatically, so catalog Inspector slots show actual item names.

At runtime collectible_discovery.gd recursively discovers canonical filenames
under assets/items and assets/relics, plus categories under assets/categories.
It uses ResourceLoader.list_directory, preserving Godot's exported resource
filename abstraction. Supporting Resources, artwork and other filenames are not
registered as collectibles. Entries are sorted by display name, then stable ID.
Type, duplicate ID, category and graph validation must pass before publication.
The runtime registry retains definitions and exposes definition_for_key.

assets/collectibles.tres is now a generated Inspector/export dependency snapshot,
not a hand-maintained registration list. Its Refresh From Item / Relic Folders
button refreshes it in the Inspector; save the resource afterward. The standalone
systems/content/tools/rebuild_collectible_catalog.gd command regenerates and saves
it directly. Runtime discovery does not depend on this snapshot being current.
Use an export preset that includes all resources, or refresh the snapshot before
an export restricted to selected scene dependencies. No export preset currently
exists in this project; a packaged export has not been verified for this change.

This registers authored definitions automatically. Runtime adapters read their
names, stats, costs, restrictions, footprints, icons and existing rule parameters.
Coded reward pools and ability handlers remain separate; discovery does not make
an unsupported ability executable or insert a new item into coded pools.

## Status and loot registration

GameContentDefinition discovers five status records, ten loot pools and eight
progressions. Refresh validates duplicate IDs and unknown collectible/pool references
before updating any collection. Status rule effects are external references from
their status definitions; existing item, relic and monster rule effects remain with
their respective owners. Runtime combat and reward rolling have not been replaced.
See status_effects/README.md and loot/README.md for the preserved current policies.
