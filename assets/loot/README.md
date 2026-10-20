# Existing loot records

pools/ contains five class-specific offensive pools, shared defense and utility
pools, the relic pool, starting arrow choices and quiver upgrades. progressions/
contains the five item-reward contexts and the three relic/quiver contexts.
GameContentDefinition registers both domains and validates their references.

All current candidate weights are one. Legacy candidates are available at floor
one even when their rarity is high. Progression and expansion equipment unlocks
by rarity: Common 1, Uncommon 5, Rare 9, Epic 13, Legendary 17. minimum_floors
captures those gates without changing the legacy exceptions. candidate_order
preserves the original seeded draw order because Godot sorts serialized dictionary
keys. Each normal item reward draws once from offense, defense and utility.

The rarity multipliers and preference multiplier remain neutral (one), matching
current code. Existing effective rarity probabilities come from the eligible
candidate set. These records do not invent a new rarity curve or affinity bonus.
The relic pool offers three distinct eligible relics; owned relics are excluded
by the existing runtime. Starting arrows offer all three choices. Every third
floor the Ranger's third normal offer is replaced by one available quiver upgrade;
its progression metadata preserves the interval and slot. Individual upgrade caps
remain on the already-authored item rule-effect records.

Pool membership never grants eligibility. Apply canonical class/character
restrictions and contextual availability before drawing. The permanent Bowmaster's
Quiver remains starter equipment and is deliberately absent from loot pools.

Runtime selection now uses systems/loot/loot_selection.gd. PackRun delegates item,
relic, room-relic and initial-arrow offers to this selector. The registration test
compares current seeded rewards for every class on floors 1 through 20, including
quiver substitution, and verifies equal RNG consumption. Upgrade availability
reads the item rule-effect caps. The quiver progression metadata specifies the
required class, interval, replacement slot and required item.

Candidate weight is pool weight times rarity checkpoint weight times one matching
preference multiplier. Both class and character preferences matching do not stack.
Restrictions, unlock floors, explicit exclusions and upgrade caps filter before
sampling. Duplicate policy applies within each pool. Sampling stops when a distinct
pool is exhausted. Uniform pools retain the old integer RNG draw; unequal weights
use normalized weighted sampling without overflowing finite authored factors.

Save restore preserves existing legal offers and consumes no RNG. If an old offer
violates current restrictions, deterministic repair now chooses from the current
floor's eligible progression candidates, preferring the same rarity. This replaces
the former full-catalog fallback, which could grant locked equipment. Capped deferred
quiver upgrades use the first eligible candidate from the final normal item pool;
the current authored order retains the previous Blood Gem fallback.
