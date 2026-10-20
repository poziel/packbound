# Item system

`ItemDefinition` in `item_definition.gd` is the typed backpack-item contract.
It extends `CollectibleDefinition`, a Godot `Resource`, so it can be created in the
Inspector and saved as `.tres` files. A future explicit JSON converter can create
the same objects. This class does not load JSON or register catalog entries.

## Authoring

After Godot discovers the script, choose **New Resource → ItemDefinition** in the
FileSystem dock or a compatible Resource property. Fill in the grouped Inspector
fields and save the resource beside its owning item under `assets/items/<id>/`.
Creating a record does not accept artwork or make the item playable.

```gdscript
var definition := ItemDefinition.new()
definition.id = &"example_charm"
definition.display_name = "Example Charm"
definition.category_ids.assign([&"boosters"])
definition.footprint.assign([Vector2i.ZERO])
definition.base_stats[GameplayTypes.Stat.WARD] = 1
definition.activation_costs[GameplayTypes.ResourceType.MANA] = 0
definition.rarity = GameplayTypes.Rarity.UNCOMMON
definition.element = GameplayTypes.Element.NONE
var errors: PackedStringArray = definition.validation_errors()
```

| Field group | Meaning |
| --- | --- |
| Identity | Stable definition ID, display name, description and lore. |
| Classification | Shared enum rarity, tags and category IDs; IDs are separate from display text. |
| Eligibility | Allowed class and character IDs. Empty lists mean unrestricted. Entries in one list are alternatives; both lists must match when populated. |
| Presentation | Optional shared icon texture. |
| Equipment | Category IDs, unique occupied `Vector2i` cells in the unrotated footprint and rotation permission. Cells use nonnegative coordinates. |
| Base Values | Shared enum-keyed `GameplayTypes.Stat` map with integer amounts. Signed values and empty maps are valid. |
| Activation Costs | Item-specific `GameplayTypes.ResourceType` map with nonnegative integer amounts. Zero costs and empty maps are valid. |
| Damage Identity | `GameplayTypes.DamageType` and `GameplayTypes.Element`, with `NONE` meaning no element. |
| Abilities | Typed references to shared `AbilityDefinition` Resources, with an empty list meaning no abilities. |

`validation_errors()` checks intrinsic structure without changing the resource.
It reports blank required fields, invalid footprint cells, unknown enum values
or map keys, blank/duplicate category IDs and negative costs. The future loader/catalog must validate category references,
class, character and ability references; validation here does not certify
that referenced content exists or a mechanic is implemented.

Shared identity, classification, eligibility, presentation, stats and ability
properties are declared once in `systems/content/collectible_definition.gd`.
Item-specific validation calls the parent, then checks equipment and costs.
The item script path, UID and existing serialized property names are preserved;
pre-inheritance enum-based `.tres` records retain their values. The mixed authored
`CollectibleCatalogDefinition` checks category references for both items and relics.

`systems/content/gameplay_types.gd` owns the stat, activation-resource, damage,
element and rarity enums. Native `.tres` records serialize their integer values;
use the shared conversion helpers for text IDs at JSON or legacy boundaries.
Do not assign text keys directly into the enum-keyed maps. See the shared
[content vocabulary](../content/README.md#gameplay-types).

## Boundaries

Treat definitions as read-only during gameplay. Shared Resource references may
point to the same object. Instance IDs, inventory position, current rotation,
chosen activation priority, cooldowns and temporary effects belong in a future
`ItemInstance` rather than this shared definition.

`base_stats` and `activation_costs` describe ordinary values. They do not encode
adjacency conditions, per-round grants, Momentum mechanics or quiver behavior.
Typed ability, condition and effect contracts live in `systems/abilities/`.
`abilities` references those Resources and validation reports null entries or
nested errors with paths such as `abilities[0]: effects[1]: ...`. Execution and
per-owner ability state remain separate; there is no generic parameter payload.

The existing `PackCatalog`, inventory, combat, crafting and saves still use their
current dictionaries. This increment introduces the contract and its native
serialization checks; it does not convert or replace current item records.

Maintained regression coverage is registered as `item_definition`:

```powershell
./tests/run_tests.ps1 -Suite systems -Test item_definition
```
