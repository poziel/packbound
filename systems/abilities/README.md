# Ability definitions

These Resource classes describe shared authored abilities. They support native
`.tres` authoring in Godot; a future JSON converter can construct the same objects.
Definitions describe authored data. `EffectResolver` executes supported concrete
effects; it does not yet execute complete abilities, triggers or conditions.

| Class | Contract |
| --- | --- |
| `AbilityDefinition` | Stable ID, name, description, trigger ID, typed conditions and ordered effects. |
| `ConditionDefinition` | Abstract Resource with `validation_errors() -> PackedStringArray`; concrete subclasses declare typed condition parameters. |
| `EffectDefinition` | Abstract Resource with the same validation contract; concrete subclasses declare typed effect parameters. |
| `ApplyStatusEffectDefinition` | Status definition reference, positive stack count and SELF/OPPONENT target. |

Create `AbilityDefinition` in Godot's New Resource dialog. Abstract conditions and
effects require concrete subclasses before they can be assigned or created.
Subclasses intended for Inspector use should also use `@tool`. Keep their
validation pure and return an empty `PackedStringArray` when structurally valid.
There is no catch-all parameter dictionary, always-true condition or no-op effect.

An ability requires a nonblank ID, name and trigger and at least one effect.
Empty conditions means unconditional; otherwise all conditions must match.
Effects preserve their authored execution order. Null children and child
validation errors are reported with paths such as `effects[1]: amount ...`.
`ItemDefinition.abilities` provides typed references and propagates these errors.

Treat shared definitions as read-only during a run. Several owners may reference
the same ability Resource. Temporary charges, cooldowns and activation counters
will belong in runtime state. Per-owner parameter overrides are not defined yet.

The future catalog must validate known trigger IDs and references; the future
resolver must define timing, owner compatibility, evaluation context and effect
execution. Intrinsic validation does not certify that a mechanic is implemented.
Concrete Resources under `tests/systems/abilities/` are serialization/validation
fixtures, not registered production mechanics.

```powershell
./tests/run_tests.ps1 -Suite systems -Test ability_definition
```

## Status application runtime

`EffectResolver.resolve(effect, source, opponent, applications)` selects the acting
combatant or its opponent, validates the application, and delegates stacking and
duration policy to `StatusResolver`. Each combatant map contains its supported
`StatusEffectInstance` objects keyed by status ID. Missing or mismatched instances
and unsupported effect types return errors before mutation. Preview callers pass
copied instances; combat retains responsibility for timing and saving.

The content catalog registers one `apply_effect.tres` per status. Current combat
uses these one-stack records with its existing aggregate application counts.
Player/enemy Poison and enemy Burn, Slow, Spark and Doom use this path.

## Collectible status abilities

All 38 existing items with fixed status grants now reference `status_ability.tres`
and owned `apply_<status>.tres` effects. Those amounts are removed from
`base_stats`; the runtime adapter evaluates the authored `item_activation`
ability into the existing enum-keyed contribution view. Combat still controls
costs, adjacency, repeats and the combined attack's status application phases.

The four conditional status relics use `relic_stats` abilities, typed
`CombatMetricConditionDefinition` predicates and
`ScaledApplyStatusEffectDefinition` effects. Predicates inspect health percentage,
Volley damage or reaction count; reaction scaling preserves its authored cap.
`CollectibleAbilityResolver` evaluates them against the pre-relic snapshot without
mutating resources, statuses or RNG. Supported collectible status effects target
the opponent; unsupported targets/triggers fail content validation.

Other item/relic special mechanics still use their existing compatibility
bindings. This is a status-ability executor, not a universal ability interpreter.

## Combat stat grants

`GrantCombatStatEffectDefinition` supplies a positive amount and an enum stat for
per-round relic contributions. Tin Cricket's Ward and Pocket Hearth's conditional
Healing now use `stat_ability.tres` and `grant_stat.tres`; their former compatibility
rules are removed. `CollectibleAbilityResolver` evaluates these through `relic_stats`
on the same pre-relic snapshot as status grants. Block bonuses also update the
combat feedback budget. Definitions remain read-only; combat resolves actual healing,
absorption and round state through its existing commit path.

Damage, mana/stamina budgets and status stacks are deliberately outside this
stat-grant effect's supported stats. They require their corresponding mechanics.
Other conditional/scaled relic bonuses and special item mechanics still need
concrete effect migrations.
