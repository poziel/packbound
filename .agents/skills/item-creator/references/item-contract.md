# Item record contract — version 1

Use `item.json` for both `kind: item` and `kind: relic`. Keep the top-level keys in the linked [example](item.example.json). This is an initial authoring contract, not a runtime loader schema. Extend typed effect parameters when the design requires them; do not force every mechanic into a generic damage field.

| Field | Meaning |
| --- | --- |
| schemaVersion | Integer 1 for this authoring contract. |
| id | Stable snake_case definition ID, unique across items and relics. |
| kind | `item` or `relic`, selected by equipment behavior. |
| identity | Name, category, rarity, tags, short description, full description and lore. |
| status | Design: `proposed` or `accepted`; runtime: `not-integrated`, `partial` or `integrated`. Acceptance requires user evidence. |
| placement | `backpack` or `relic-slot`; inventory mask rows of equal width using #/., cellPixels=32 and rotatable boolean. Relics have mask=null and cellPixels=null; do not impose a backpack footprint. |
| startingStats | Numeric keyword/stat map using current game keys. Include relevant base stats only; omitted means not applicable, null means undecided. |
| activation | Trigger, priority, typed costs, cooldown, limits and reset conditions. Time and probability values declare units. |
| effects | Each has a unique local ID, description, trigger, target, condition, numeric parameters and implementation state (`supported`, `proposed`, `unresolved`). |
| empowerment | Bonuses this definition supplies to other items, with target IDs/tags, geometry, stacking, trigger, numeric bonuses, conditions and implementation state. |
| synergies | Named partners by definition ID or tag, rationale, any extra numeric rules and their implementation state. Mere strategic synergy adds no implicit bonus. |
| acquisition | Sources and any proposed prices/drop probabilities; explicit units/currency and numeric values. |
| crafting | Recipes producing this definition and outgoing merges using it. Each recipe uses ingredient entries with id, quantity, consumed and referenceState; result has id, quantity and referenceState. Include conditions and numerical parameters. |
| visual | Design brief, materials, palette intentions, defining features and actual art references. |
| unresolved | Specific unanswered design decisions; do not hide them in prose or resolve them to zero. |

Collections are arrays; an empty array means none currently designed. Numeric maps contain numbers or null, never numeric strings. Costs use nonnegative amounts and explicit resource names; UI signs are presentation. Numeric parameters that represent time, chance or distance include a unit in their name or alongside the value, e.g. durationRounds or probability with unit=fraction. Probabilities as fractions range from 0 to 1. Conditions must define their subject, timing and scope; a description alone does not establish implementation support.

Recipe IDs are independent of result IDs. `referenceState` is `existing` or `proposed`; verify existing references against authored records and catalogs. Repeated ingredients use a quantity rather than duplicate entries. Include the current definition among inputs for outgoing merges. Keep one authoritative recipe object per recipe ID; other records may refer to it by ID rather than diverging copies. `mergeTargets` lists result IDs from outgoing merges, not arbitrary desirable future upgrades.

Current crafting must be rechecked before integration: `scripts/pack_crafting.gd` presently uses catalog keys, repeated ingredient keys, connected orthogonal occupied-cell contact and ordered recipes. Conditions/quantities in this authoring format require explicit translation. Do not claim catalysts, relic-slot crafting, arbitrary probabilities or multi-output recipes already work.

Existing IDs do not necessarily match names: `longsword` currently displays Iron Dagger and `tower_shield` displays Shield Relic. Preserve keys and inspect behavior instead of renaming or inferring kind. Legacy `armor` means shield protection; `plating` and `block` have distinct rules. Resolve keyword aliases through the shared mapping.

## Recipe entry example

This hypothetical outgoing merge is a structural illustration, not a recipe to add automatically. An empty recipes/merges array remains correct when no recipe is designed.

```json
{
  "id": "temper_twin_needles",
  "implementation": "proposed",
  "ingredients": [
    {"id": "tempered_needle", "quantity": 2, "consumed": true, "referenceState": "proposed"}
  ],
  "result": {"id": "twin_needle", "quantity": 1, "referenceState": "proposed"},
  "conditions": ["Inventory editing is available.", "Ingredient masks form one orthogonally connected group."],
  "parameters": {"goldCost": 0},
  "trigger": "craft-confirmation",
  "failureBehavior": "Consume nothing if requirements cannot be satisfied.",
  "description": "Merge two Tempered Needles into one Twin Needle."
}
```

For this example, outgoing `mergeTargets` is `["twin_needle"]`. A catalyst would have consumed=false; support must be implemented explicitly. The proposed confirmation trigger must not be confused with current automatic crafting behavior. Define output-placement/full-inventory behavior in recipe conditions or failureBehavior after checking current code.
