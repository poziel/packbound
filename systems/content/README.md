# Content system

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
| `ItemDefinition` | Backpack item with role, footprint, rotation permission, activation costs and damage/element enums. |
| `RelicDefinition` | Relic identity, restrictions, categories, stats and abilities without backpack requirements. |
| `CollectibleCategoryDefinition` | Category ID/name/description and optional parent category ID. |
| `CollectibleCatalogDefinition` | Typed authored arrays of collectibles and categories; validates the complete category graph. |

Categories apply equally to items and relics. Each category has at most one parent;
collectibles may list multiple category IDs. Empty parent ID means root. Prefer
listing specific child categories; explicit ancestor membership is redundant but
valid. The future category matcher should include ancestors and count each
collectible once. Tags remain independent flat traits. Categories do not grant
abilities automatically, and no category-matching runtime is introduced here.

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
either list matches, without stacking class and character matches. These fields
are authored metadata only: current reward selection does not consume them yet.

`gameplay_types.gd` defines `GameplayTypes`, the shared enum authority used by
typed definitions and the existing catalog vocabularies:

| Enum | Members |
| --- | --- |
| `Stat` | DAMAGE, BLOCK, HEALING, VAMPIRISM, PLATING, WARD, POISON, BURN, MANA, STAMINA, CURSE, THORNS, CLEANSE, SLOW, PIERCE, DOOM, SPARK, PHYSICAL_RESISTANCE, MAGICAL_RESISTANCE |
| `ResourceType` | MANA, STAMINA, HEALTH, MOMENTUM |
| `DamageType` | PHYSICAL, MAGICAL |
| `Element` | NONE, FIRE, FROST, LIGHTNING, VOID, VENOM |
| `Rarity` | COMMON, UNCOMMON, RARE, EPIC, LEGENDARY |

The stat set follows the existing collectible combat stats. Resources follow
the committed activation-cost records, including health substitution and
Momentum; listing a resource does not add a new payment mechanic. Adding enum
members does not by itself implement their behavior.

All enum values have explicit integer assignments, which are serialized in native
Resource files. Never renumber/reuse values or reorder their corresponding ID
tables; append new values deliberately. `Element.NONE` maps to the existing empty
element string. Reaction-element lists exclude NONE.

`stat_id`/`stat_from_id`, `resource_id`/`resource_from_id`,
`damage_type_id`/`damage_type_from_id`, `element_id`/`element_from_id`, and
`rarity_id`/`rarity_from_id` convert between enums and stable text IDs. Unknown
IDs return `INVALID_VALUE` (-1); invalid numbers return `INVALID_ID` (`<invalid>`),
distinct from the valid empty no-element ID. IDs are strict and case sensitive.
Validate conversions instead of silently treating unknown values as a real enum.

Existing dictionary catalogs, combat records and saves retain their text keys.
Their stat/rarity/element lists reference this authority. Rarity presentation and
damage-type resolution accept either legacy text or enum input. Typed
ItemDefinition fields use enum-backed scalar properties and enum-keyed maps;
validation rejects unknown integer values even when assigned outside the editor.
JSON conversion remains a separate future loader; JSON should retain readable
IDs and explicitly convert them, rather than serialize enum positions as text.

No accepted production ItemDefinition `.tres` records existed when these fields
were converted. Earlier task-generated string-based test Resources remain
historical artifacts and are not auto-migrated. Do not load those artifacts as
new enum definitions without explicit conversion.

## Eligibility

Item and relic definitions may declare `classes` and `characters` arrays.
Use stable roster IDs from `PackCatalog.classes()` and `assets/characters/<id>/character.json`:

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
