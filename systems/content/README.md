# Content system

The complete authored Resource graph is now available at
`res://assets/game_content.tres`. See [the Resource guide](../../assets/README.md#authored-content-resources)
for ownership, migration boundaries and verification. `GameContentDefinition`
validates cross-domain class, restriction, starter-item and recipe references.
Runtime classification discovers canonical item.tres and relic.tres files directly;
collectibles.tres is a generated Inspector/export snapshot. Its Refresh button
rebuilds the list without manual entries. Runtime values are adapted from these Resources into independent dictionaries
for existing combat, UI and save consumers. See the Resource guide for export packaging and naming.

## Collectible definitions

Collectible is the shared term for backpack items and relics. The abstract
`CollectibleDefinition` Resource owns identity, enum rarity, tags, category IDs,
class/character restrictions, icon, enum-keyed base stats and typed abilities.
`ItemDefinition` and `RelicDefinition` inherit these fields and their validation.
Keep shared definitions read-only during a run; positions, quantities and
cooldowns belong in future runtime instances.

| Resource | Responsibility |
| --- | --- |
| `CollectibleDefinition` | Abstract shared authored contract; cannot be created directly. |
| `ItemDefinition` | Backpack item with category IDs, footprint, rotation permission, activation costs and damage/element enums. |
| `RelicDefinition` | Relic identity, restrictions, categories, stats and abilities without backpack requirements. |
| `CollectibleCategoryDefinition` | Category ID/name/description and optional parent category ID. |
| `CollectibleCatalogDefinition` | Typed authored arrays of collectibles and categories; validates the complete category graph. |

Categories apply equally to items and relics. Each category has at most one parent;
collectibles may list multiple category IDs. Empty parent ID means root. Prefer
listing specific child categories; explicit ancestor membership is redundant but
valid. The category matcher includes ancestors and counts each
collectible once. Tags remain independent flat traits. Categories do not grant
abilities automatically, and the runtime category matcher resolves ancestors.

The category Resource validates required fields and direct self-parenting. The
catalog aggregates indexed child errors and checks nulls, duplicate collectible
IDs across items/relics, duplicate category IDs, unknown memberships/parents and
indirect cycles. Category and collectible IDs have separate namespaces. Graph
validation is iterative and does not mutate authored records.

The catalog is an authored data container, not a live inventory or singleton.
It does not replace the running `PackCatalog`, register records, execute abilities
or parse JSON. Store each accepted definition with its owning content; tests and
editor probes are not accepted gameplay content. Native `.tres` supports shared
Resource references; a future explicit JSON loader can construct the same types.

```powershell
./tests/run_tests.ps1 -Suite systems -Test 'collectible_*'
```

## Gameplay types

### Offer preferences

`CollectibleDefinition.preferred_class_ids` and `preferred_character_ids` are
optional arrays of stable IDs shared by items and relics. Empty arrays mean no
preference. Validation rejects blank and duplicate entries; roster reference
validation belongs to a future cross-domain catalog. Preferences never bypass
eligibility. The intended loot policy applies one centrally tuned bonus when
either list matches, without stacking class and character matches. `LootSelection` consumes these preferences using the selected progression's
`preferred_weight_multiplier`, after enforcing both class and character restrictions.

`gameplay_types.gd` defines `GameplayTypes`, the shared enum authority used by
typed definitions and the existing catalog vocabularies:

| Enum | Members |
| --- | --- |
| `Stat` | DAMAGE, BLOCK, HEALING, VAMPIRISM, PLATING, WARD, POISON, BURN, MANA, STAMINA, CURSE, THORNS, CLEANSE, SLOW, PIERCE, DOOM, SPARK, PHYSICAL_RESISTANCE, MAGICAL_RESISTANCE |
| `ResourceType` | MANA, STAMINA, HEALTH, MOMENTUM |
| `DamageType` | PHYSICAL, MAGICAL |
| `Element` | NONE, FIRE, FROST, LIGHTNING, VOID, VENOM |
| `Rarity` | COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, SIGNATURE |

The stat set follows the existing collectible combat stats. Resources follow
the committed activation-cost records, including health substitution and
Momentum; listing a resource does not add a new payment mechanic. Adding enum
members does not by itself implement their behavior.

All enum values have explicit integer assignments, which are serialized in native
Resource files. Never renumber/reuse values; append new values deliberately.
The enums are the sole vocabulary: duplicate ID tables and catalog aliases have
been removed. Consumers enumerate enum values directly. Text conversion at existing
dictionary, save and presentation boundaries derives lowercase enum names rather
than consulting a second list. Keep enum names stable while those persisted text
interfaces remain supported. `Element.NONE` maps to the existing empty
element string. Reaction-element lists exclude NONE.

`stat_id`/`stat_from_id`, `resource_id`/`resource_from_id`,
`damage_type_id`/`damage_type_from_id`, `element_id`/`element_from_id`, and
`rarity_id`/`rarity_from_id` convert between enums and stable text IDs. Unknown
IDs return `INVALID_VALUE` (-1); invalid numbers return `INVALID_ID` (`<invalid>`),
distinct from the valid empty no-element ID. IDs are strict and case sensitive.
Validate conversions instead of silently treating unknown values as a real enum.

Runtime item/relic/monster and combat stat maps now use `GameplayTypes.Stat` keys.
Item `activation_costs` is one enum-keyed `ResourceType` map; the old cost,
stamina_cost, health_cost and momentum_cost item fields are removed. Authored
Momentum costs live in ItemDefinition, with no compatibility-parameter duplicate.
Rarity, damage type and element values remain enums; elemental trace maps and
reaction inputs/outputs use Element keys and values. Keyword IDs, log labels and
inspection markup translate enums only at presentation boundaries.

Run scalar properties (such as hp/mana/stamina) and player-phase checkpoint field
names remain named properties, rather than stat dictionaries. Round combat budgets
use Stat.MANA/STAMINA/BLOCK; activation payment maps use ResourceType. Do not mix
the two enum domains even where their integer values happen to coincide.

Save version 3 records the enum representation. Versions 1 and 2 remain readable:
PackRunSaves.migrate_legacy_values converts old stat keys, item costs, damage types,
elements and traces, preserving saved instance values and authored missing defaults.
The same conversion normalizes saved combat playback results. Rarity is restored
from its current definition, as before. Shared Resources remain read-only.

JSON conversion remains a separate future loader; JSON should retain readable
IDs and explicitly convert them, rather than serialize enum positions as text.

No accepted production ItemDefinition `.tres` records existed when these fields
were converted. Earlier task-generated string-based test Resources remain
historical artifacts and are not auto-migrated. Do not load those artifacts as
new enum definitions without explicit conversion.

## Eligibility

Item and relic Resources declare `allowed_class_ids` and `allowed_character_ids`.
Their runtime adapters expose `classes` and `characters` arrays.
Use stable roster IDs from `PackCatalog.classes()` and `assets/characters/<id>/character.tres`:

```gdscript
"classes": ["warrior"] # Only Warrior
"characters": ["warrior"] # Only Garran Vale
```

Omit a field or use an empty array for no restriction. Multiple entries in one
array are alternatives; when both arrays are present, both must match. The
current roster has one character per class, using the same stable ID.

Restrictions apply to item grants, crafting results, item rewards and relic
choices. Saved runs replace ineligible pending offers while preserving valid
offers and existing inventory. Restricted inventory items remain inactive for
other characters.

Inspection shows each restriction beneath the cost with a linked class or
character name. Character labels and biographies come from their character
record. Keep restrictions in these fields rather than description sentences.

## Runtime definition loading

runtime_content.gd loads and validates game_content.tres, discovers canonical
content files and preserves the authored recipe order. PackCatalog is a compatibility
facade: its dictionaries now come from Resources, not numerical code tables or JSON.
Each returned record owns its mutable arrays and dictionaries. Existing saves keep
recorded instance values and receive missing defaults through the existing save path.

Character health, mana/stamina capacities, identity, biography and starting equipment
come from character.tres. Class presentation comes from character_class.tres. Original
selection order is retained with selection_order metadata. Base encounter order uses
progression_index metadata; expansion placement retains encounter_floor metadata.
PackArt reads the definition icons. Recipes use ingredient alternatives, quantities
and result quantities while retaining adjacency, locks and the combat-start commit.

Special rules still execute through their existing coded handlers using the
CatalogRuleEffectDefinition parameters. No generic condition/action interpreter has
been introduced. Loot membership, unlock floors, rarity weights and preferences now come from
registered loot definitions; add a collectible to a pool to offer it as loot.
The current board remains fixed at 8 by 7. Existing combat resource spending supports
mana, stamina and the established Momentum rules; arbitrary new action costs and
behavior conditions await concrete effect/action execution.

## Status and loot definitions

These Resources are registered in GameContentDefinition and discovered with its
Refresh button. All five existing statuses execute through StatusResolver. Reward selection now
reads the registered records through systems/loot/loot_selection.gd.

| Definition | Owner | Authored data |
| --- | --- | --- |
| StatusEffectDefinition | systems/combat/status_effect_definition.gd | Identity/icon, additive/replacement/highest-stack policy, stack cap, duration refresh, decay, cleansing and triggered tick effects. |
| LootPoolDefinition | systems/loot/loot_pool_definition.gd | Relative collectible-ID weights, offer count and duplicate policy; supports both items and relics. |
| LootProgressionDefinition | systems/loot/loot_progression_definition.gd | Referenced pool IDs, rarity-weight checkpoints by one-based floor and a preference multiplier. |
| CatalogRuleEffectDefinition | systems/abilities/catalog_rule_effect_definition.gd | Existing compatibility binding: rule ID and handler-owned parameters. |

Status stack caps and durations use zero for uncapped stacks and no timed expiry.
Stack policy applies to an incoming application; the cap applies afterward. Duration
refresh is independent of the stack policy. Tick effects require a trigger ID. Actual
stack counts, remaining lifetime, tick ordering and source tracking belong to the
StatusEffectInstance and StatusResolver, not this shared Resource.

Loot weights are relative, finite and nonnegative. Zero disables a candidate. Each
rarity checkpoint is a complete distribution: omitted enum rarities have zero weight.
loot_selection.gd uses the latest checkpoint at or below the current floor, without
interpolation. Floor 1 is required. Preference matching boosts weight once when either
class or character affinity matches; the neutral default is 1.0. It never grants
eligibility. Offer counts are targets; filtering may leave fewer eligible candidates.

Intrinsic validation rejects invalid values without mutation. The future content
registry must validate known collectible/pool/status/trigger/rule IDs. Catalog-rule
parameter names must be nonblank strings or valid Stat enums; enum stat values must
be integers. The rule handler validates its other parameters.
Concrete effect subclasses should gradually replace compatibility bindings, rather
than expanding the wrapper into an arbitrary behavior interpreter.

The existing statuses and loot tuning are now authored as .tres files, with typed
catalog collections and cross-reference validation. Loot selection now uses its registered resources. All five status lifecycles now use the resolver, with explicit combat phase commits
and compatibility loading for numeric-only and earlier Poison snapshots.

Verification: tests/run_tests.ps1 -Suite systems -Test reward_status_definitions.

## Runtime status instances

StatusEffectInstance (systems/combat/status_effect_instance.gd) is RefCounted
runtime state containing a shared StatusEffectDefinition reference, stacks and
remaining_rounds. Create one instance per status owner. Treat definitions as read-only;
mutating one instance's counters does not affect another instance or its definition.

Construction uses the definition duration unless an explicit remaining duration is
provided. Explicit zero is preserved: it represents no timed expiration for an untimed
definition, or an expired countdown for a timed one. Zero stacks are also valid to
hold. Validation reports missing/invalid definitions and negative counters without
modifying them. The constructor uses -1 only as its omitted-duration sentinel.

The instance does not apply stack policy/caps, tick, decay, expire itself, consume RNG,
or write saves. StatusResolver owns application, stacking, cleansing, ticking and
round advancement. All five existing statuses now use this resolver: player/enemy
Poison and enemy Burn, Slow, Spark and Doom. PackRun owns damage, Ward and phase
commits, and resolves previews on copied instances. Its numeric status properties
are compatibility accessors into the single owner/ID instance store.

Saves store definition IDs, stacks and exact remaining rounds in `statuses`, including
pending player checkpoints and final outcomes. Older numeric-only saves and earlier
Poison maps remain supported. Restoration preserves recorded stacks without applying
current caps. Spark consumption precedes fresh stacks, Slow reduces each strike but
decays once, and Doom retains its nonrefreshing fuse. Resolver creation starts empty
states with no timer; explicitly restored empty countdowns remain valid and elapse.

## Concrete status applications

`GameContentDefinition.status_applications` registers typed
`ApplyStatusEffectDefinition` records discovered from
`assets/status_effects/**/apply_effect.tres`. Refresh includes them in the export
snapshot. Validation requires exactly one application per registered status and
an exact reference to that registered status definition.

Combat now executes these records through `EffectResolver`, which delegates to
`StatusResolver`. This is the first concrete effect execution path; it does not
provide a generic ability trigger or condition interpreter.

Collectible status grants now have an execution path too: 38 items and four
conditional relics reference owned status abilities/effects. The item adapter
derives status contribution views from these Resources; relic evaluation uses a
pre-relic snapshot for typed health/Volley/reaction conditions and bounded scaling.
The complete content graph verifies that these effects reference registered status
definitions. Additional concrete collectible paths are described below.

Tin Cricket and Pocket Hearth additionally execute typed combat stat grants for
Ward and conditional Healing. Their `stat_ability.tres` records reference
`GrantCombatStatEffectDefinition`; their former `rule` dictionaries are removed.

## Complete collectible bonus execution

Remaining relic scaling, conditions, typed damage and round resource grants now
execute authored effect records. Item adjacency, quiver, Momentum and special
mechanic records also feed the runtime. Quiver base/upgrade tuning and caps are
owned by `QuiverVolleyEffectDefinition` resources. See the
[ability runtime guide](../abilities/README.md#remaining-collectible-bonus-migration)
for supported triggers and ownership. The former relic condition-name interpreter
and primary adjacency item-ID switch have been removed. Other domains may still
use compatibility effects; presentation/initialization metadata is still adapted.

## Runtime discovery and indexes

`runtime_content.gd` discovers and validates the complete canonical content graph
once per process. The category matcher shares that graph instead of discovering
collectibles a second time. Character, class, monster, recipe, status, application,
loot-pool and loot-progression ID lookups use indexes of the validated Resource
references. Returned run dictionaries remain independent mutable views.

IDs, collection membership and capability kinds are immutable for a game session;
scalar tuning stays on the referenced Resource. Inspector Refresh buttons rebuild
authoring catalogs explicitly. Restart the running game after structural edits; runtime hot reload is not
supported. Tools that deliberately edit indexed collections can call
`rebuild_indexes()` to validate and republish lookups without rescanning folders;
invalid graphs leave the existing lookup tables intact.

`PackRun.effects()` reuses adjacency and relic-mechanic queries only within its
synchronous evaluation. The memo tables clear before it returns, so direct item
moves, turn changes, relic edits and later definition tuning are observed by the
next preview. No persistent preview result or gameplay RNG is cached.
