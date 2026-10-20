# Loot selection

loot_selection.gd owns candidate filtering, weighting and sampling from registered
LootPoolDefinition and LootProgressionDefinition Resources. PackRun owns reward
queues, claims, progression and persistence; selection does not write saves.

- candidates() and available() inspect eligibility without consuming RNG.
- roll() draws using the supplied run RNG, obeying offer counts and per-pool duplicate policy.
- item_offers() combines normal item pools with configured quiver substitution.
- initial_options() lists authored starting arrows without a random draw.
- available_upgrades() reads the authored item rule caps; rolling additionally applies floor, weight and restriction filters.
- repair() preserves legal saved offers and deterministically replaces ineligible ones without advancing RNG.

Read assets/loot/README.md for current tuning, ordering and compatibility policies.
Definitions remain read-only. Selection returns newly allocated result records.
Changing registered weights, checkpoints, preferences, counts or unlock floors now
affects future rewards; valid offers already saved are preserved.

Status execution and concrete ability/effect handlers are outside this migration.
