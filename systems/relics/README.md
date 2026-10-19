# Relic system

`RelicDefinition` extends the abstract `CollectibleDefinition` Resource alongside
`ItemDefinition`. Both share ID/name/description/lore, enum rarity, tags, category
IDs, class/character restrictions, icon, enum-keyed base stats and abilities.

A relic does not declare or require a backpack role, footprint, rotation,
ordinary item activation costs, damage type or element. Its concrete Resource
type distinguishes it from backpack equipment. Conditional/passive behavior is
described through abilities; this model does not add combat aggregation rules.

```gdscript
var definition := RelicDefinition.new()
definition.id = &"example_relic"
definition.display_name = "Example Relic"
definition.rarity = GameplayTypes.Rarity.RARE
definition.category_ids.assign([&"magic"])
definition.base_stats[GameplayTypes.Stat.WARD] = 2
var errors: PackedStringArray = definition.validation_errors()
```

Create the Resource through Godot's New Resource dialog and save accepted records
beside their owning relic under `assets/relics/<id>/`. An accepted category record
must exist in the future catalog for each referenced ID. Creating a Resource does
not accept artwork or register it in the running game.

Inherited validation checks intrinsic fields and nested abilities. Empty class
or character lists mean unrestricted; entries in a list are alternatives and both
lists must match if populated. Catalog-wide category validation is provided by
`CollectibleCatalogDefinition`. Several items and relics can reference the same
ability Resource; treat all authored definitions as read-only during gameplay.

The existing relic catalogs, rules, reward offers and saves retain their current
implementation. Native `.tres` serialization is supported; JSON construction and
runtime ownership/state will be integrated separately.

```powershell
./tests/run_tests.ps1 -Suite systems -Test collectible_definition
```
