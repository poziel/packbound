# Packbound content migration walkthrough

This document explains the work from introducing typed content definitions through the loot-selection and Poison-runtime migrations. It describes the code as inspected on October 20, 2026. It is a reading guide and change summary, rather than a commit-by-commit history or the larger upcoming implementation plan.

## 1. The overall change

We separated three responsibilities that were previously more closely mixed:

| Responsibility | What it contains | Current examples |
| --- | --- | --- |
| **Definition** | Shared, authored structure and values. | Item name, footprint, base damage, abilities, restrictions. |
| **Runtime state** | Values belonging to a particular run or combatant. | Item position, current health, Poison stacks and remaining duration. |
| **Rules and services** | Code that interprets definitions and changes runtime state. | Crafting, loot selection, status resolution, combat commits. |

In C# terms, a definition class is similar to a typed data model, and a `.tres` file is one serialized record of that model. A runtime instance represents an individual use of that definition. Services apply the game's rules.

Godot `Resource` is the base for authored definitions. It supports Inspector editing, serialization, references to other Resources and shared loading. `.tres` is Godot's text Resource format: it can be edited in a text editor as well as in Godot.

Definitions are treated as read-only during play because multiple consumers can share the same loaded Resource. Mutable run values must not be written back into the shared definition.

## 2. Shared vocabulary and enum types

We added [GameplayTypes](gameplay_types.gd) as the common vocabulary for:

- Stats, such as damage, block, Poison, Ward and resistance.
- Activation resources: mana, stamina, health and Momentum.
- Damage types: physical and magical.
- Elements: none, fire, frost, lightning, void and venom.
- Rarity: common through legendary.

Definitions use enum-backed fields and typed dictionaries for stats and costs. Existing dictionary consumers still use readable string IDs; conversion helpers connect the two representations.

**Why:** authors and scripts should agree on valid values instead of independently spelling strings. Explicit enum numbers also provide stable serialized values. Adding an enum member does not implement its gameplay behavior.

## 3. Items and relics now share a parent definition

The hierarchy is:

```text
CollectibleDefinition (abstract Resource)
├── ItemDefinition
└── RelicDefinition
```

[CollectibleDefinition](collectible_definition.gd) holds identity, description, lore, rarity, tags, category IDs, icon, base stats, abilities, eligibility restrictions and offer preferences.

[ItemDefinition](../items/item_definition.gd) adds backpack-specific data, including footprint, rotation permission, activation costs, damage type and element. [RelicDefinition](../relics/relic_definition.gd) uses the shared collectible fields without backpack requirements.

**Why:** items and relics need consistent identity, restrictions and ability data without duplicating their shared contract. Their live inventory and ownership state remain separate from these shared records.

### Restrictions and preferences have different jobs

`allowed_class_ids` and `allowed_character_ids` are hard eligibility rules. Entries within a list are alternatives; if both lists are populated, both must match. Restrictions are applied to grants, crafting results, rewards and relic choices. Ineligible items already in an inventory remain inactive.

Restriction tooltips place linked class or character names beneath the cost, such as **Only Warrior**. Character names and biographies come from their character records rather than being embedded in item descriptions.

`preferred_class_ids` and `preferred_character_ids` are soft loot affinities. A matching preference increases selection weight through the loot progression's multiplier. It never makes a restricted collectible eligible, and matching both lists does not apply the bonus twice.

**Why:** hard restrictions express who can use something; preferences help balance who is offered otherwise eligible content.

## 4. Categories replaced the separate item-role classification

[CollectibleCategoryDefinition](collectible_category_definition.gd) describes a category with an optional parent. Categories apply to both items and relics, and a collectible can belong to multiple categories.

For example, a specific weapon category can sit beneath melee weapons and weapons. Consumers resolve ancestor membership, so an item in the child category also matches its parents. The separate item `role` field is no longer the classification authority.

[CollectibleCatalogDefinition](collectible_catalog_definition.gd) validates category references, duplicate IDs and parent cycles. Runtime category matching is exposed through the existing catalog.

**Why:** one category graph supports broad and specific queries without maintaining conflicting role and category values. Categories classify content; they do not automatically grant abilities.

## 5. Abilities, conditions and effects became reusable definitions

| Class | Responsibility |
| --- | --- |
| [AbilityDefinition](../abilities/ability_definition.gd) | A named triggered capability, with conditions and ordered effects. |
| [ConditionDefinition](../abilities/condition_definition.gd) | The shared condition contract for more specific condition types. |
| [EffectDefinition](../abilities/effect_definition.gd) | The shared effect contract for more specific effect types. |
| [CatalogRuleEffectDefinition](../abilities/catalog_rule_effect_definition.gd) | A compatibility binding containing a coded rule ID and its parameters. |

Items, relics and combatants can reference ability Resources instead of each inventing their own ability structure. Nested Resources allow the same model to describe abilities with conditions and multiple effects.

**Why:** this gives us typed boundaries for reusable mechanics and future concrete effect classes.

**Current boundary:** we have not built a universal ability/condition/effect interpreter. Existing special mechanics still run through coded handlers. `runtime_content.gd` adapts catalog-rule parameters for those consumers, and the Poison resolver explicitly handles its supported rule. Merely creating a Resource with a new rule ID does not implement a mechanic.

## 6. Crafting recipes became authored records

[RecipeDefinition](../crafting/recipe_definition.gd) holds the recipe identity, ingredient requirements, result item ID and result quantity.

[RecipeIngredientDefinition](../crafting/recipe_ingredient_definition.gd) represents one requirement: a quantity plus a list of acceptable item IDs. For example, one requirement could accept either a sword or a dagger. Multiple units can be satisfied by a mixture of accepted IDs.

[runtime_content.gd](runtime_content.gd) translates these records into the shape expected by [PackCrafting](../crafting/pack_crafting.gd). Crafting consumes authored alternatives and quantities while retaining existing adjacency, locking and combat-start commit rules.

**Why:** alternative ingredients no longer require duplicating a whole recipe, and recipe data no longer needs a separate hardcoded numerical authority.

## 7. Characters and monsters gained a shared combatant model

```text
CombatantDefinition (abstract Resource)
├── CharacterDefinition
└── MonsterDefinition
```

| Class | What it adds or describes |
| --- | --- |
| [CombatantDefinition](../combat/combatant_definition.gd) | Shared identity, log name, description, icon, tags, stats, resource capacities and innate abilities. |
| [CharacterDefinition](../characters/character_definition.gd) | Character-specific data, class association and starting equipment. |
| [CharacterClassDefinition](../characters/character_class_definition.gd) | Class identity and shared class ability references. |
| [StartingEquipmentDefinition](../characters/starting_equipment_definition.gd) | An item ID, initial grid position and rotation. Repeat entries for multiple physical items. |
| [MonsterDefinition](../enemies/monster_definition.gd) | Monster-specific classification, behavior reference and optional reward-pool association. |
| [ActionDefinition](../combat/action_definition.gd) | An action's target, costs, conditions and ordered effects. |
| [MonsterBehaviorDefinition](../enemies/monster_behavior_definition.gd) | An authored sequence of action references and cycle policy. |

We kept base stats and resource capacities as enum-keyed dictionaries rather than adding a separate object for each stat or resource pool.

Character identity, health, mana/stamina capacities and starting equipment now come from character Resources. Class presentation comes from class Resources. Monster baselines and ordered attack values come from monster/action Resources.

**Why:** characters and monsters share a clear contract while retaining their different responsibilities. Resource capacity is data; refill timing, health persistence and Momentum behavior remain game rules. A generic action executor or full monster AI interpreter has not been introduced.

## 8. We created actual `.tres` content records

The model classes were followed by serialized records for existing content: items, relics, characters/classes, monsters and their actions, categories, recipes, statuses and loot configuration.

Production records live with their content under `assets/`. Canonical filenames include:

```text
assets/items/<id>/item.tres
assets/relics/<id>/relic.tres
assets/characters/<id>/character.tres
assets/enemies/<id>/monster.tres
assets/status_effects/<id>/status_effect.tres
assets/categories/*.tres
assets/recipes/*.tres
assets/loot/pools/*.tres
assets/loot/progressions/*.tres
```

Supporting Resources use descriptive filenames such as `rule_ability.tres`, `rule_effect.tres` and `behavior.tres`. Readable `resource_name` values make records easier to distinguish in the Inspector even when their filenames match.

**Why:** adding model classes alone would leave actual game values in the old sources. These records supply the authored values the application now loads. Older JSON/design documents are not a parallel numerical gameplay authority, although editable art JSON and other documentation can still have separate purposes.

### Registration and Inspector refresh

[game_content.tres](../../assets/game_content.tres) is the root content graph. [GameContentDefinition](game_content_definition.gd) exposes typed collections and cross-reference validation. It also has an Inspector refresh button to discover content folders.

[collectible_discovery.gd](collectible_discovery.gd) discovers canonical item/relic files and categories. [collectibles.tres](../../assets/collectibles.tres) is a generated Inspector/export dependency snapshot with its own refresh button, rather than a manually maintained runtime registration list.

Refresh validates candidate content before publishing it. Existing recipe priority is retained. The [catalog rebuild tool](tools/rebuild_collectible_catalog.gd) can regenerate the collectible snapshot. The [content refresh tool](tools/create_content_resources.gd) refreshes snapshots; it does not recreate individual records from old JSON.

**Why:** folder discovery reduces manual registration mistakes while validation catches broken references. Exports limited to selected dependencies still need current snapshots or a configuration that includes all required Resources; discovery alone does not prove a packaged export contains every file.

## 9. Existing consumers now receive Resource-backed data through adapters

The main data path is:

```text
Authored .tres records
    → GameContentDefinition / discovery and validation
    → runtime_content.gd
    → PackCatalog compatibility records
    → existing combat, inventory, UI and crafting consumers
```

[runtime_content.gd](runtime_content.gd) loads and caches validated content, looks up definitions and produces independent dictionary records. [PackCatalog](pack_catalog.gd) remains a compatibility facade for consumers that expect dictionaries. [PackArt](../art/pack_art.gd) reads definition icons.

**Why:** this made Resources the authored source without requiring every UI and combat script to be rewritten simultaneously. Copying mutable arrays and dictionaries keeps one run's changes from altering shared definitions or another run.

The application is therefore partly object-oriented and partly adapted to its existing runtime model. Items, relics, characters and monsters have typed definitions, but their live gameplay data has not all become typed instance classes.

## 10. Loot configuration and selection moved into their own model and service

[LootPoolDefinition](../loot/loot_pool_definition.gd) describes candidate collectible IDs and relative weights, offer count and duplicate policy. [LootProgressionDefinition](../loot/loot_progression_definition.gd) connects pools to floor-based rarity distributions and a preference multiplier. Their `.tres` records contain the actual tuning.

[loot_selection.gd](../loot/loot_selection.gd) now owns filtering, weighting and sampling from those registered definitions. It handles eligibility, floor availability, rarity weights, preferences and pool duplicate policy. It also supports the existing Archer reward configuration.

Selection uses the supplied run RNG. Inspection does not consume RNG. Saved-offer repair preserves legal offers and replaces ineligible ones deterministically without advancing RNG.

[PackRun](../runs/run_state.gd) still owns reward queues, claims, progression and when state is saved.

**Why:** reward balance can now be adjusted in authored pools/progressions, while selection has one shared implementation. Registering an item does not automatically make it loot: it must also belong to an appropriate pool.

## 11. Status definitions gained runtime instances and a resolver

[StatusEffectDefinition](../combat/status_effect_definition.gd) defines stack policy, stack cap, duration, refresh behavior, decay, cleansing policy, tick trigger and effects. We created records for Poison, Burn, Slow, Spark and Doom.

[StatusEffectInstance](../combat/status_effect_instance.gd) is a `RefCounted` runtime object holding a shared definition reference, current stacks and remaining rounds. Each owner gets separate mutable state.

[StatusResolver](../combat/status_resolver.gd) handles application, stack policies/caps, cleansing, tick calculation, decay, expiration, copies and plain-data snapshots.

**Why:** the definition says how a status works; the instance says how much of it this combatant currently has; the resolver applies the rules. A shared definition no longer needs to hold mutable counters.

### Poison is the first migrated status

Both player and enemy Poison now use instances and the resolver. Combat previews resolve on copies. `PackRun` retains control of phase timing, health changes and Ward allocation. Plague Seal's enemy-decay exception, enemy cleansing and incoming contact Poison are preserved.

The public numeric `player_poison` and `enemy_poison` properties remain compatibility accessors into the instances, so existing consumers can continue reading those values.

[PackRunSaves](../runs/run_saves.gd) stores plain definition IDs, stacks and remaining rounds rather than serializing runtime objects. Pending-turn checkpoints carry the corresponding state, and older numeric-only saves remain supported.

**Current boundary:** Burn, Slow, Spark and Doom still execute through their existing counters and handlers. Their definitions exist, but they have not yet been individually migrated into this resolver. Elemental traces and other independent combat mechanics are also separate.

## 12. Validation and verification added along the way

Definition validation checks required identity, enum values, nested records, quantities and other intrinsic constraints. Catalog validation adds cross-record checks such as duplicate IDs, category cycles and referenced content.

Focused tests cover definition contracts, resource registration, restrictions, crafting, loot selection, status instances, resolver policies and Poison save/runtime behavior. Tests run through the isolated [test runner](../../tests/README.md), with diagnostics in `workspace/`.

For the Poison migration, an 80-scenario comparison found no changes in the previously existing outcome fields or combat logs. The final targeted verification reported ten passing tests and a successful Godot import. Four broader tests failed on roster, progression and Burn-tooltip expectations; that verification did not establish a fully green application suite or visual acceptance.

## Suggested script-reading order

1. [CollectibleDefinition](collectible_definition.gd), then [ItemDefinition](../items/item_definition.gd): understand the authored model.
2. One [actual item record](../../assets/items/): see how the model is serialized and references supporting Resources.
3. [GameContentDefinition](game_content_definition.gd) and [runtime_content.gd](runtime_content.gd): follow registration, validation and adaptation.
4. [PackCatalog](pack_catalog.gd): see how existing callers obtain Resource-backed records.
5. [PackCrafting](../crafting/pack_crafting.gd) and [loot_selection.gd](../loot/loot_selection.gd): follow two consumers of authored relationships and balance data.
6. [StatusEffectInstance](../combat/status_effect_instance.gd), [StatusResolver](../combat/status_resolver.gd), then [PackRun](../runs/run_state.gd): follow the first typed status runtime through preview and commit.
7. [PackRunSaves](../runs/run_saves.gd): see how mutable state survives a reload without saving shared definition objects.

This gives us a typed, validated content foundation and working Resource-backed consumers. The next planning exercise can build on the remaining boundaries identified here rather than assuming every declared model already has a complete runtime executor.
