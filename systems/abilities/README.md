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
Player/enemy Poison and enemy Burn, Slow, Spark and Doom use this path. Individual
item/relic abilities still need migration from compatibility rules to concrete
effects; this bridge does not evaluate their triggers or conditions.
