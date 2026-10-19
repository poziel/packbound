# Ability definitions

These Resource classes describe shared authored abilities. They support native
`.tres` authoring in Godot; a future JSON converter can construct the same objects.
They do not execute abilities or migrate the current combat/catalog dictionaries.

| Class | Contract |
| --- | --- |
| `AbilityDefinition` | Stable ID, name, description, trigger ID, typed conditions and ordered effects. |
| `ConditionDefinition` | Abstract Resource with `validation_errors() -> PackedStringArray`; concrete subclasses declare typed condition parameters. |
| `EffectDefinition` | Abstract Resource with the same validation contract; concrete subclasses declare typed effect parameters. |

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
