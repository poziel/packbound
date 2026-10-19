# Crafting system

`PackCrafting` currently matches and executes the existing dictionary recipes.
`RecipeDefinition` and `RecipeIngredientDefinition` establish the separate typed
authoring contract for future catalog integration. Both extend Godot Resource,
support Inspector editing and save as `.tres`; neither performs crafting or loads
JSON. A future JSON converter can build the same typed objects.

## Recipe structure

`RecipeDefinition` holds a stable recipe `id`, a typed `ingredients` array,
`result_item_id` and positive `result_quantity` (default 1).

Each `RecipeIngredientDefinition` is one requirement with `accepted_item_ids`
and positive `quantity` (default 1). It is an authored value object, not an owned
item or a separate catalog entity, so it needs no global ID or display name.

```text
Example recipe (illustrative IDs)
  [small_sword OR bulky_dagger] × 1
  [ruby_crystal] × 1
  [glowing_mote] × 1
  -> enchanted_blade × 1
```

Every requirement must be satisfied. Any accepted ID may contribute, and a
quantity greater than one may mix those alternatives. The future matching
algorithm must allocate each owned item at most once, including when different
requirements have overlapping alternatives. Alternative order is not a matching
priority contract. Prefer one quantified requirement for interchangeable copies.

## Validation and integration boundary

Validation is pure: recipe/result IDs must not be blank, lists must be populated,
child Resources must not be null and quantities must be positive. Accepted IDs
must be nonblank and unique within one requirement. Overlapping IDs across
different requirements are allowed. Child errors carry indexed paths. Inspector
range hints do not replace validation, and positive quantities above 999 remain
valid. Cross-record existence checks and recipe graph cycles need a catalog.

Keep one authoritative record per recipe ID. Save accepted recipe records with
their owning content; do not create independent conflicting copies in every
ingredient item. Loaded definitions are shared data, not changing inventory state.

The current runtime has not been migrated to these models. Alternative matching
and multiple-output crafting are authored intent here, not newly implemented
gameplay. Automatic crafting timing, precedence, occupied-cell connectivity,
consumption and output placement remain owned by `PackCrafting`. Catalysts,
tag-based requirements and other condition forms are not modeled yet.

```powershell
./tests/run_tests.ps1 -Suite systems -Test recipe_definition
```
