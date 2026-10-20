extends "res://tests/support/test_case.gd"
const DATA = preload("res://systems/content/runtime_content.gd")
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")
const K = CharacterMechanicEffectDefinition.Mechanic
func _run() -> void:
	var content: GameContentDefinition = DATA.content()
	check(content == DATA.content(), "Runtime content is published once per process")
	for owner: CollectibleDefinition in content.collectibles.collectibles:
		check(CATEGORIES.definition_for_key(str(owner.id)) == owner, "Category and game registries share the same definition: " + str(owner.id))
	for domain: StringName in [&"recipes", &"status_effects", &"loot_pools", &"loot_progressions"]:
		for value: Resource in content.get(domain):
			check(DATA.definition(domain, value.id) == value, "Indexed resource shares validated authority: " + str(value.id))
	for value: ApplyStatusEffectDefinition in content.status_applications:
		check(DATA.status_application(value.status.id) == value, "Status application resolves by status ID")
	for owner: CharacterDefinition in content.characters:
		check(DATA.character(str(owner.id)) == owner, "Character ID resolves to original definition")
		check(DATA.character_class(owner.class_id).id == owner.class_id, "Character class ID resolves")
		for ability: AbilityDefinition in DATA.character_class(owner.class_id).abilities:
			for effect: EffectDefinition in ability.effects:
				check(effect is CharacterMechanicEffectDefinition, "Class mechanics use concrete effects")
	for owner: MonsterDefinition in content.monsters:
		check(DATA.monster_definition(str(owner.id)) == owner, "Monster ID resolves to original definition")
		for action: ActionDefinition in owner.behavior.actions:
			for effect: EffectDefinition in action.effects:
				check(effect is AttackEffectDefinition, "All monster attacks use concrete effects")
	check(DATA.character("missing") == null and DATA.monster_definition("missing") == null, "Unknown definition IDs do not alias another entry")
	var original_monster_count: int = content.monsters.size()
	content.monsters.append(content.monsters[0])
	check(not DATA.rebuild_indexes().is_empty(), "Duplicate IDs reject structural index refresh")
	check(DATA.monster_definition(str(content.monsters[0].id)) == content.monsters[0], "Rejected refresh preserves existing lookups")
	content.monsters.resize(original_monster_count)
	check_equal(DATA.rebuild_indexes(), PackedStringArray(), "Valid explicit index refresh succeeds")
	var original_collectible: CollectibleDefinition = content.collectibles.collectibles[0]
	var replacement: CollectibleDefinition = original_collectible.duplicate()
	content.collectibles.collectibles[0] = replacement
	check_equal(DATA.rebuild_indexes(), PackedStringArray(), "Valid structural replacement can be published explicitly")
	check(CATEGORIES.definition_for_key(str(replacement.id)) == replacement, "Category index follows explicit graph revision")
	content.collectibles.collectibles[0] = original_collectible
	check_equal(DATA.rebuild_indexes(), PackedStringArray(), "Shared catalog fixture restores its authority")
	var run := PackRun.new()
	run.reset(1729, "warrior")
	var momentum: CharacterMechanicEffectDefinition = DATA.character_mechanic("warrior", K.MOMENTUM)
	var original: int = momentum.momentum_per_response
	momentum.momentum_per_response = 4
	check_equal(run.momentum_gain(), 4, "Momentum reads authored amount without duplicated tuning")
	momentum.momentum_per_response = original
	run.reset(1729, "necromancer")
	var companions: CharacterMechanicEffectDefinition = DATA.character_mechanic("necromancer", K.RAISE_DEAD)
	original = companions.companion_damage
	companions.companion_damage = 7
	check_equal(run.effects().companion_damage, 7, "Companion damage reads authored definition")
	companions.companion_damage = original
	original = companions.companion_capacity
	companions.companion_capacity = 8
	check_equal(run.companion_capacity(), 8, "Companion cap reads authored definition")
	companions.companion_capacity = original
	run.reset(1729, "assassin")
	var shadow: CharacterMechanicEffectDefinition = DATA.character_mechanic("assassin", K.SHADOWSTEP)
	original = shadow.invisibility_period
	shadow.invisibility_period = 2
	run.turn = 3
	check(run.is_invisible(), "Shadowstep follows authored period")
	run.turn = 2
	check(not run.is_invisible(), "Shadowstep respects other rounds")
	check_equal(run.shadowstep_remaining(), 1, "Shadowstep countdown follows authored period")
	shadow.invisibility_period = original
	var monster: MonsterDefinition = DATA.monster_definition("ash_rat")
	var attack: AttackEffectDefinition = monster.behavior.actions[0].effects[0]
	original = attack.damage
	attack.damage = 37
	check_equal(DATA.monster(monster).attacks[0], 37, "Monster attacks read typed amount")
	attack.damage = original
	attack.hits = 0
	check(not attack.validation_errors().is_empty(), "Invalid hit counts are rejected")
	attack.hits = 1
	run.reset(1729, "warrior")
	run.items.clear()
	var gem: Dictionary = run.add_item("blood_gem", Vector2i.ZERO)
	var blade: Dictionary = run.add_item("rusty_knife", Vector2i(1, 0))
	var adjacent: Dictionary = run.effects()
	blade.cell = Vector2i(6, 5)
	var distant: Dictionary = run.effects()
	check(int(adjacent[GameplayTypes.Stat.DAMAGE]) > int(distant[GameplayTypes.Stat.DAMAGE]), "In-place inventory moves invalidate evaluation memoization")
	blade.cell = Vector2i(1, 0)
	check_equal(run.effects(), adjacent, "Returning an item restores the exact pure preview")
	var before_rng: int = run.rng.state
	var preview: Dictionary = run.effects()
	run.outcome(preview)
	check_equal(run.rng.state, before_rng, "Repeated previews preserve gameplay RNG")
	preview[GameplayTypes.Stat.DAMAGE] = 999
	check_equal(run.effects(), adjacent, "Caller mutation cannot corrupt later preview results")
	gem.cell = Vector2i(6, 4)
	check(not run.touches(gem, blade), "Adjacency reads state outside an evaluation")
	report("COMBATANT RESOURCE RUNTIME")
	quit(1 if failures else 0)
