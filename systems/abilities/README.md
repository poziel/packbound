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

Existing collectible bonuses now use the concrete paths below. These are explicit
coded execution contracts, not a universal ability interpreter.

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
Conditional and scaled bonuses now use the shared scaling and condition contracts
described below.

## Remaining collectible bonus migration

All 50 expansion relic bonuses now execute concrete effects. The final 44 rules
use `bonus_ability.tres` and `bonus_effect.tres`; `CombatScalingDefinition` owns the
metric and cap. `GrantDamageEffectDefinition` keeps physical/magical damage explicit,
and `GrantResourceEffectDefinition` supplies pre-activation mana/stamina budgets.
`CombatMetricConditionDefinition` and `ClassConditionDefinition` replace the former
condition-name switch. Conditions inspect a single pre-relic snapshot; one bonus
cannot enable another in the same pass. Health fractions use integer cross-products.

Item adjacency, extra arrows and Momentum bonuses have owned abilities/effects too.
`CollectibleTargetConditionDefinition` selects categories or the permanent quiver;
the packing system enforces contact and eligibility. `GrantItemBonusEffectDefinition`
distinguishes primary damage/block grants from grants to all activation stats, so
existing bonuses are not counted twice. `ItemMomentumEffectDefinition` owns gain and
damage per Momentum spent. Runtime dictionaries are derived views for current UI,
combat and saves; they are not a second authored source. Resume rebuilds these views
without re-executing an already committed action.

`CollectibleMechanicEffectDefinition` supplies typed parameters for diagonal/wrapped
links, mirrors, repeats, conversions, revival and status-decay prevention. Periodic
abilities use authored turn conditions. `CollectibleMechanics` only looks up active
records; existing combat phases still execute each distinct mechanic. Plague Seal
references the affected status directly instead of being named by Poison's rule.

`QuiverVolleyEffectDefinition` owns base arrows/interval, selected-arrow stats,
upgrade stats, explosion bonuses and upgrade caps. The quiver runtime reads those
records and computes per-arrow/flat contributions; loot reads the same caps.
Metadata for the options also comes from their definitions.

| Trigger | Execution contract |
| --- | --- |
| `item_activation` | Opponent status contributions after successful activation payment. |
| `item_adjacency` / `item_quiver` | Target-filtered packing or Volley bonus views. |
| `item_momentum` | Affordable activation gain and damage scaling. |
| `relic_stats` | Conditional/scaled combat contributions on the pre-relic snapshot. |
| `relic_resources` | Round resource budget before payments. |
| `item_mechanic` / `relic_mechanic` | Existing phase-specific mechanic with optional turn condition. |
| `quiver_loadout` | Base Volley, selected arrows or purchased upgrades. |

Remaining `CatalogRuleEffectDefinition` records contain compatibility/presentation
metadata and initialization fields. They no longer author these collectible bonuses.
Characters, monster behavior and status tick handlers retain their own migration
boundaries. Adding an unknown effect or trigger still requires coded support.

## Character and monster capabilities

`CharacterMechanicEffectDefinition` declares the class capability and configurable
Momentum gain, Shadowstep period and starting/capacity/damage of bone thralls.
`PackRun` reads those definitions instead of using class-name gates or tuning
constants. Special-purpose algorithms (reactions, Volley, shield cadence) stay
in their owning systems.

`AttackEffectDefinition` supplies ordered monster damage and hit counts.
`MonsterTraitEffectDefinition` supplies intent and response/shield traits.
Current monster responses support physical damage only; validation rejects other
damage types rather than silently accepting unsupported authoring. All existing
class and enemy parameter wrappers have been replaced by these concrete records.
