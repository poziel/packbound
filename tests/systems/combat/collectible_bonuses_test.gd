extends "res://tests/support/test_case.gd"
const DATA = preload("res://systems/content/runtime_content.gd")
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")
func _run() -> void:
	var legacy: Array[String] = []
	for owner: CollectibleDefinition in DATA.content().collectibles.collectibles:
		var rules: Dictionary = DATA.rules(owner.abilities)
		for key: String in ["rule", "adjacency_bonus", "quiver_bonus", "momentum_gain", "momentum_damage"]:
			if rules.has(key): legacy.append(str(owner.id) + ": " + key)
	check_equal(legacy, [], "Gameplay bonuses no longer live in compatibility parameter dictionaries")
	var run := PackRun.new()
	run.reset(1729, "warrior")
	run.items.clear()
	var gem: Dictionary = run.add_item("blood_gem", Vector2i.ZERO)
	var blade: Dictionary = run.add_item("rusty_knife", Vector2i(1, 0))
	check_equal(run.bonus(gem, blade), 2, "Blood Gem authored adjacency bonus reaches combat")
	check_equal(run.supplied_bonus(gem, blade).get(GameplayTypes.Stat.DAMAGE, 0), 2, "Adjacency preview uses same authored bonus")
	run.relics.assign(["rust_psalm"])
	check_equal(run.effects()[GameplayTypes.Stat.PIERCE], 1, "Rust Psalm scales piercing by weapon count")
	check(preload("res://systems/relics/relic_abilities.gd").description(PackCatalog.relic("siege_heart")).begins_with("Momentum Affinity\n"), "Typed class condition retains its tooltip keyword")
	var scaling: GrantCombatStatEffectDefinition = CATEGORIES.definition_for_key("rust_psalm").abilities[-1].effects[0]
	var saved_amount: int = scaling.amount
	scaling.amount = 3
	check_equal(run.effects()[GameplayTypes.Stat.PIERCE], 3, "Runtime reads the authored scaled bonus amount")
	scaling.amount = saved_amount
	var target: CollectibleTargetConditionDefinition = CATEGORIES.definition_for_key("blood_gem").abilities[-1].conditions[0]
	target.category_ids.append(&"missing_bonus_category")
	check(not DATA.content().validation_errors().is_empty(), "Unknown authored bonus category is rejected")
	target.category_ids.pop_back()
	var saved_threshold: int = 0
	var periodic: CombatMetricConditionDefinition = CATEGORIES.definition_for_key("echo_clock").abilities[-1].conditions[0]
	saved_threshold = periodic.modulo
	run.relics.assign(["echo_clock"])
	run.turn = 3
	var repeats: int = run.effects().repeats
	periodic.modulo = 2
	check_equal(run.effects().repeats, 0, "Authored periodic condition controls Echo Clock")
	periodic.modulo = saved_threshold
	check_equal(run.effects().repeats, repeats, "Restoring authored period restores the bonus")
	var quiver_run := PackRun.new()
	quiver_run.reset(1729, "ranger")
	quiver_run.items.clear()
	var quiver: Dictionary = quiver_run.add_item("magnificent_quiver", Vector2i.ZERO)
	quiver.arrow_type = "venom"
	var cup: Dictionary = quiver_run.add_item("tin_arrow_cup", Vector2i(1, 0))
	check_equal(quiver_run.supplied_bonus(cup, quiver), {}, "Extra-arrow preview does not treat arrows as an enum stat")
	check_equal(quiver_run.volley_stats().arrows, 3, "Authored adjacent extra-arrow bonus reaches Volley")
	var mechanism: QuiverVolleyEffectDefinition = PackRun.QUIVER.effect("quiver_mechanism")
	quiver.upgrades = {"quiver_mechanism": 1}
	var old_damage: int = int(mechanism.per_arrow_stats[GameplayTypes.Stat.DAMAGE])
	var normal: int = PackRun.QUIVER.stats(quiver)[GameplayTypes.Stat.DAMAGE]
	mechanism.per_arrow_stats[GameplayTypes.Stat.DAMAGE] = old_damage + 2
	check_equal(PackRun.QUIVER.stats(quiver)[GameplayTypes.Stat.DAMAGE] - normal, 4, "Volley upgrade reads its concrete per-arrow bonus")
	mechanism.per_arrow_stats[GameplayTypes.Stat.DAMAGE] = old_damage
	var cap: int = mechanism.cap
	mechanism.cap = 1
	check(not PackRun.QUIVER.available(quiver).has("quiver_mechanism"), "Loot eligibility reads the authored upgrade cap")
	mechanism.cap = cap
	var snapshot_path: String = artifact_path("scaled_bonus.tres")
	check_equal(ResourceSaver.save(scaling, snapshot_path), OK, "Scaled effect serializes")
	var restored: GrantCombatStatEffectDefinition = ResourceLoader.load(snapshot_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check_equal(restored.scaling.cap, scaling.scaling.cap, "Serialization preserves the authored cap")
	check_equal(restored.scaling.metric, scaling.scaling.metric, "Serialization preserves the scaling metric")
	var before: Dictionary = run.status_state()
	var rng_before: int = run.rng.state
	check_equal(run.effects(), run.effects(), "Bonus previews are deterministic")
	check_equal(run.status_state(), before, "Bonus preview preserves statuses")
	check_equal(run.rng.state, rng_before, "Bonus preview preserves RNG")
	report("COLLECTIBLE BONUSES")
	quit(1 if failures else 0)
