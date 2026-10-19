# Combatant and action definitions

These editor-authored Resources are data contracts, not the running combat model.
CombatantDefinition is abstract; CharacterDefinition and MonsterDefinition inherit
identity, log name, description, icon, tags, enum-keyed base stats/resource capacities
and innate AbilityDefinition references. Empty log_name means use display_name.
Definitions remain read-only during play; live health, statuses, resource amounts,
behavior cursors and cooldowns belong to future runtime state.

Health capacity uses ResourceType.HEALTH. Capacities do not prescribe refill or
starting policies: mana/stamina refill, health persistence and Momentum rules remain
code. Signed base stats are permitted; capacities and action costs are nonnegative.
Existing enum values have not changed.

CharacterDefinition references a CharacterClassDefinition by stable class_id.
Class definitions own class identity and shared abilities. Character baselines are
explicit: no implicit stat/default merging or inheritance is implemented.
StartingEquipmentDefinition describes one physical item with item_id, grid position
and clockwise quarter-turn rotation. Repeat entries for multiple items. Backpack
dimensions default to 8 by 7. Intrinsic validation checks origins; the future loader
must check item existence, footprints, rotation permissions, overlaps and eligibility.

ActionDefinition defines a chosen action with target selector ID, costs, all-of
conditions and ordered effects. AbilityDefinition remains a triggered capability.
Both reuse the same ConditionDefinition and EffectDefinition contracts.
MonsterBehaviorDefinition describes an ordered action cycle; repeated references
allow repeated turns. repeat_cycle=false means wait after its end. The intended
executor skips unavailable actions and waits if none is available. No AI executor
is introduced. MonsterDefinition adds species/role IDs, required behavior and an
optional reward pool ID. Encounter floors and difficulty scaling belong elsewhere.

Character files live in systems/characters; monster files in systems/enemies;
shared combat contracts live here. Validation checks intrinsic/nested records only.
Cross-domain IDs and targeting/trigger support require a future authoritative loader.
No JSON migration, catalog registration, combat execution, reward behavior or save
format changes are included.

Run: ./tests/run_tests.ps1 -Suite systems -Test combatant_definitions
