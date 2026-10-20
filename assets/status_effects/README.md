# Existing status records

Each condition owns status_effect.tres and rule_effect.tres. The five records are
Poison, Burn, Slow, Spark and Doom. They reuse the accepted keyword glyphs and
copy descriptions from the existing keyword definitions.

Poison, Burn and Slow lose one stack per round. Plague Seal suppresses enemy
Poison decay through its explicit rule binding. Spark deals two magical damage
per existing stack on a later damaging magical hit, then consumes one stack.
Doom detonates for two magical damage per stack after a three-round countdown;
new applications do not reset that countdown. Damage bypasses block and respects
the existing resistance/ward rules in the coded handlers.

These shared records contain authored policy only. Poison uses StatusResolver
and separate runtime instances for player and enemy; its record supplies stacking,
decay, cleansing and tick parameters. Combat owns phase timing and damage commits.
Burn, Slow, Spark and Doom retain their existing counters and handlers. Their
trigger/rule IDs name compatibility bindings for future migrations; registering them does
not make a generic effect interpreter available. Elemental traces, block,
Momentum and innate invisibility are separate mechanics rather than extra
instances of these five persistent conditions.
