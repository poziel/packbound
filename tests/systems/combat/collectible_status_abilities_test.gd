extends "res://tests/support/test_case.gd"
const DATA = preload("res://systems/content/runtime_content.gd")
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")

func _run() -> void:
	var content: GameContentDefinition = DATA.content()
	var item: CollectibleDefinition = CATEGORIES.definition_for_key("venom_dagger")
	var found: ApplyStatusEffectDefinition
	for ability: AbilityDefinition in item.abilities:
		for effect: EffectDefinition in ability.effects:
			if effect is ApplyStatusEffectDefinition: found = effect
	check(found != null, "Venom Dagger authors Poison through a concrete status effect")
	if found == null:
		report("COLLECTIBLE STATUS ABILITIES")
		quit(1)
		return
	check(not item.base_stats.has(GameplayTypes.Stat.POISON), "Poison has one authored owner")
	check_equal(PackCatalog.item("venom_dagger")[GameplayTypes.Stat.POISON], 3, "Authored effect reaches game item")
	var prior: int = found.stacks
	found.stacks = 7
	check_equal(PackCatalog.item("venom_dagger")[GameplayTypes.Stat.POISON], 7, "Game reads the concrete resource value")
	found.stacks = prior
	var saved_target: int = found.target
	found.target = ApplyStatusEffectDefinition.Target.SELF
	check(not item.validation_errors().is_empty(), "Unsupported self-target authoring is rejected before registration")
	found.target = saved_target
	item.base_stats[GameplayTypes.Stat.POISON] = 3
	check(not item.validation_errors().is_empty(), "Duplicate base-stat/status-effect authoring is rejected")
	item.base_stats.erase(GameplayTypes.Stat.POISON)
	var registered_status: StatusEffectDefinition = found.status
	found.status = registered_status.duplicate()
	check(not content.validation_errors().is_empty(), "Unregistered status reference is rejected even when its ID matches")
	found.status = registered_status
	var item_count: int = 0
	var relic_count: int = 0
	for definition: CollectibleDefinition in DATA.content().collectibles.collectibles:
		for ability: AbilityDefinition in definition.abilities:
			if ability.trigger_id not in [CollectibleAbilityResolver.ITEM_TRIGGER, CollectibleAbilityResolver.RELIC_TRIGGER]: continue
			check_equal(ability.validation_errors(), PackedStringArray(), "Concrete authored status ability validates: " + str(definition.id))
			if definition is ItemDefinition:
				item_count += 1
				for effect: ApplyStatusEffectDefinition in ability.effects:
					check(not definition.base_stats.has(GameplayTypes.stat_from_id(effect.status.id)), "Status grant is not duplicated in base stats: " + str(definition.id))
			else: relic_count += 1
	check_equal(item_count, 38, "All existing fixed item status grants migrated")
	check_equal(relic_count, 4, "All existing conditional relic status grants migrated")
	var run := PackRun.new()
	run.reset(42, "warrior")
	run.relics.assign(["mourning_volcano"])
	run.hp = run.max_hp
	var full: Dictionary = run.effects()
	run.hp = 1
	var low: Dictionary = run.effects()
	check_equal(int(low[GameplayTypes.Stat.BURN]) - int(full[GameplayTypes.Stat.BURN]), 6, "Relic low-health condition controls authored Burn")
	check(preload("res://systems/relics/relic_abilities.gd").description(PackCatalog.relic("mourning_volcano")).begins_with("Last Stand\n"), "Relic condition tooltip label survives typed migration")
	var weapon_run := PackRun.new()
	weapon_run.reset(42, "warrior")
	weapon_run.items.clear()
	weapon_run.relics.clear()
	weapon_run.add_item("venom_dagger", Vector2i.ZERO)
	var weapon_stats: Dictionary = weapon_run.effects()
	check_equal(weapon_stats[GameplayTypes.Stat.POISON], 3, "Paid item activation contributes authored Poison")
	check_equal(weapon_run.outcome(weapon_stats).enemy_poison_after, 2, "Authored item Poison reaches combat and decays normally")
	for key: String in ["horizon_engine", "thousand_arrow_funeral", "crown_of_the_unmade"]:
		var relic: CollectibleDefinition = CATEGORIES.definition_for_key(key)
		for amount: int in [0, 1, 4, 9]:
			var context: Dictionary = {"volley_damage": amount, "reaction_count": amount}
			var grants: Dictionary = CollectibleAbilityResolver.contributions(relic.abilities, CollectibleAbilityResolver.RELIC_TRIGGER, context)
			var stat: int = GameplayTypes.Stat.DOOM if key == "crown_of_the_unmade" else (GameplayTypes.Stat.BURN if key == "horizon_engine" else GameplayTypes.Stat.POISON)
			var expected: int = mini(4, amount) * 2 if key == "crown_of_the_unmade" else ((5 if key == "horizon_engine" else 9) if amount > 0 else 0)
			check_equal(int(grants.get(stat, 0)), expected, "Relic condition/scaling: " + key + " metric " + str(amount))
			check(not DATA.rules(relic.abilities).has("rule"), "Migrated relic has no duplicate compatibility rule")
	var saved_rng: int = run.rng.state
	var saved_status: Dictionary = run.status_state()
	check_equal(run.effects(), run.effects(), "Repeated previews return identical effects")
	check_equal(run.rng.state, saved_rng, "Ability evaluation does not consume RNG")
	check_equal(run.status_state(), saved_status, "Ability evaluation does not mutate live status stacks")
	report("COLLECTIBLE STATUS ABILITIES")
	quit(1 if failures else 0)

