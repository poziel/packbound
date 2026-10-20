# Existing status records

Each condition owns status_effect.tres, rule_effect.tres and apply_effect.tres. The five records are
Poison, Burn, Slow, Spark and Doom. They reuse the accepted keyword glyphs and
copy descriptions from the existing keyword definitions.

Poison, Burn and Slow lose one stack per round. Plague Seal suppresses enemy
Poison decay through its explicit rule binding. Spark deals two magical damage
per existing stack on a later damaging magical hit, then consumes one stack.
Doom detonates for two magical damage per stack after a three-round countdown;
new applications do not reset that countdown. Damage bypasses block and respects
the existing resistance/ward rules in the coded handlers.

These shared records contain authored policy only. All five conditions now execute
through StatusResolver and separate StatusEffectInstance state. Current combat uses
player/enemy Poison and enemy Burn, Slow, Spark and Doom, preserving the existing
targets. Combat owns health, Ward, phase timing and commit points; it previews with
copied instances. Resolver handlers read authored stacking, cap, duration, cleansing,
decay and supported tick parameters rather than separate combat tuning constants.

Spark resolves its old stacks before fresh applications by default. Slow's undecayed
instance reduces each strike, while the next-round snapshot decays only once. Doom
checks its fuse before round expiration; reapplication keeps a positive countdown
when refresh is disabled. Explicit legacy empty-countdown states remain preservable.

PackRun.status(owner, id) exposes the authoritative instance. Existing numeric status
properties are compatibility views, not independent counters. status_state snapshots
use plain definition IDs, stacks and remaining rounds, including player checkpoints
and pending results. Numeric-only saves and the earlier Poison-only snapshots remain
supported; loading restores recorded values without applying new stack caps.

The handlers are explicit coded bindings, not a generic effect interpreter.
Elemental traces, block, Momentum and innate invisibility remain separate mechanics.

`apply_effect.tres` references the status definition, applies one stack and targets
the opponent by default. `EffectResolver` applies authored effects to the selected
combatant; `StatusResolver` remains responsible for stacking and lifecycle policy.
Combat supplies the current aggregate application count and chooses the phase.
