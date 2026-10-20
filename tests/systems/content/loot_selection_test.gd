extends "res://tests/support/test_case.gd"
const DATA = preload("res://systems/content/runtime_content.gd")
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")

func _run() -> void:
	var path: String = "res://systems/loot/loot_selection.gd"
	if not FileAccess.file_exists(path):
		check(false, "Resource-driven loot selector exists")
		report("LOOT SELECTION")
		quit(1)
		return
	var selector: Script = load(path)
	var content: GameContentDefinition = DATA.content()
	var pool := LootPoolDefinition.new()
	pool.id = &"test_pool"
	pool.display_name = "Test pool"
	pool.collectible_weights = {&"rusty_knife": 1.0, &"bandage": 1.0}
	pool.candidate_order.assign([&"rusty_knife", &"bandage"])
	var progression := LootProgressionDefinition.new()
	progression.id = &"test_progression"
	progression.pool_ids.assign([pool.id])
	progression.rarity_weights_by_floor = {1: {GameplayTypes.Rarity.COMMON: 1.0}}
	content.loot_pools.append(pool)
	content.loot_progressions.append(progression)
	check_equal(DATA.rebuild_indexes(), PackedStringArray(), "Test loot membership validates before rebuilding indexes")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1729
	var state: int = rng.state
	var rows: Array = selector.candidates("test_progression", "test_pool", "warrior", 1)
	check_equal(rows.size(), 2, "Pool exposes both eligible candidates")
	check_equal(rng.state, state, "Candidate inspection consumes no RNG")
	pool.collectible_weights[&"rusty_knife"] = 9.0
	var favored: int = 0
	for draw: int in range(1000):
		if selector.roll("test_progression", "warrior", 1, rng)[0] == "rusty_knife": favored += 1
	check(favored > 840 and favored < 960, "Actual weighted draws follow the authored 9:1 distribution")
	pool.collectible_weights = {&"rusty_knife": 1.0e300, &"bandage": 2.0e-300, &"antidote": 1.0e-300}
	pool.candidate_order.assign([&"rusty_knife", &"bandage", &"antidote"])
	pool.offer_count = 2
	var bandages: int = 0
	for draw: int in range(1000):
		var selected: Array = selector.roll("test_progression", "warrior", 1, rng)
		if selected[1] == "bandage": bandages += 1
	check(bandages > 600 and bandages < 740, "Tiny relative weights recover correctly after a dominant candidate is removed")
	pool.collectible_weights = {&"rusty_knife": 1.0, &"bandage": 1.0}
	pool.candidate_order.assign([&"rusty_knife", &"bandage"])
	pool.offer_count = 1
	pool.collectible_weights[&"rusty_knife"] = 0.0
	check_equal(selector.roll("test_progression", "warrior", 1, rng), ["bandage"], "Zero weights remove candidates before selection")
	pool.collectible_weights[&"rusty_knife"] = 1.0
	pool.offer_count = 5
	check_equal(selector.roll("test_progression", "warrior", 1, rng).size(), 2, "Distinct offers stop when the pool is exhausted")
	pool.allow_duplicates = true
	check_equal(selector.roll("test_progression", "warrior", 1, rng).size(), 5, "Pool duplicate policy permits repeated offers")
	pool.allow_duplicates = false
	pool.minimum_floors = {&"bandage": 5}
	check_equal(selector.available("test_progression", "warrior", 4), ["rusty_knife"], "Unlock floors filter before drawing")
	pool.minimum_floors.clear()
	pool.collectible_weights = {&"rusty_knife": 1.0, &"ember_tome": 1.0}
	pool.candidate_order.assign([&"rusty_knife", &"ember_tome"])
	progression.rarity_weights_by_floor[5] = {GameplayTypes.Rarity.RARE: 1.0}
	check_equal(selector.available("test_progression", "mage", 4), ["rusty_knife"], "Early rarity distribution applies")
	check_equal(selector.available("test_progression", "mage", 7), ["ember_tome"], "Latest earlier checkpoint replaces the whole distribution")
	pool.collectible_weights = {&"rusty_knife": 1.0, &"bandage": 1.0, &"boiler_hammer": 100.0}
	pool.candidate_order.assign([&"rusty_knife", &"bandage", &"boiler_hammer"])
	progression.rarity_weights_by_floor[1] = {0: 1.0, 1: 1.0}
	check(not selector.available("test_progression", "ranger", 1).has("boiler_hammer"), "Weight never bypasses class restrictions")
	check_equal(selector.available("test_progression", "ranger", 1, ["rusty_knife"]), ["bandage"], "Explicit exclusions are respected")
	var item: ItemDefinition = CATEGORIES.definition_for_key("rusty_knife")
	var classes: Array[StringName] = item.preferred_class_ids.duplicate()
	var characters: Array[StringName] = item.preferred_character_ids.duplicate()
	item.preferred_class_ids.assign([&"warrior"])
	item.preferred_character_ids.assign([&"warrior"])
	progression.preferred_weight_multiplier = 3.0
	rows = selector.candidates("test_progression", "test_pool", "warrior", 1, ["boiler_hammer"])
	check(is_equal_approx(float(rows[0].weight) / float(rows[1].weight), 3.0), "Class and character preferences apply once rather than stacking")
	item.preferred_class_ids.assign(classes)
	item.preferred_character_ids.assign(characters)
	content.loot_pools.pop_back()
	content.loot_progressions.pop_back()
	check_equal(DATA.rebuild_indexes(), PackedStringArray(), "Restored loot membership rebuilds valid indexes")
	# Changing the actual authored pool must affect the normal PackRun entry point.
	var offense: LootPoolDefinition
	for candidate: LootPoolDefinition in content.loot_pools:
		if candidate.id == &"offense_warrior": offense = candidate
	var weights: Dictionary = offense.collectible_weights.duplicate()
	var order: Array[StringName] = offense.candidate_order.duplicate()
	var floors: Dictionary = offense.minimum_floors.duplicate()
	offense.collectible_weights = {&"bandage": 1.0}
	offense.candidate_order.assign([&"bandage"])
	offense.minimum_floors.clear()
	var run := PackRun.new()
	run.reset(1729)
	run.roll_loot()
	check_equal(run.offers[0], "bandage", "Normal item rewards read authored pool changes")
	offense.collectible_weights.assign(weights)
	offense.candidate_order.assign(order)
	offense.minimum_floors.assign(floors)
	_check_relics(selector)
	_check_quiver(selector)
	check_equal(content.validation_errors(), PackedStringArray(), "Selection leaves authored content intact")
	report("LOOT SELECTION")
	quit(1 if failures else 0)

func _check_relics(selector: Script) -> void:
	for character_id: String in PackCatalog.classes():
		var run := PackRun.new()
		run.reset(1729, character_id)
		run.relics.assign(["diagonal_thread"])
		run.room_relic_offers.assign(["blood_pact"])
		run.relic_offers.clear()
		run.relic_rewards.assign([1])
		run.rng.seed = 12345
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		var available: Array[String] = []
		for id: String in PackCatalog.RELICS:
			if not run.relics.has(id) and not run.room_relic_offers.has(id) and run.item_enabled(PackCatalog.relic(id)): available.append(id)
		var expected: Array[String] = []
		for draw: int in range(3): expected.append(available.pop_at(rng.randi_range(0, available.size() - 1)))
		run.roll_relics()
		check_equal(run.relic_offers, expected, "Relic selection preserves seeded offers and ownership exclusions: " + character_id)
		check_equal(run.rng.state, rng.state, "Relic selection preserves RNG consumption")
		var state: int = run.rng.state
		check(not run.available_room_relics().has(run.relic_offers[0]), "Room rewards exclude deferred relic offers")
		check_equal(run.rng.state, state, "Available room relic inspection consumes no RNG")
	var source: LootPoolDefinition = selector.pool("relics")
	var count: int = source.offer_count
	source.offer_count = 1
	var run := PackRun.new()
	run.reset(1729)
	run.relic_rewards.assign([1])
	run.relic_offers.clear()
	run.roll_relics()
	check_equal(run.relic_offers.size(), 1, "Deferred relic offer count reads the Resource")
	run.room_relic_offers.clear()
	run._roll_room_relics()
	check_equal(run.room_relic_offers.size(), 1, "Room relic offer count reads the same Resource")
	source.offer_count = count

func _check_quiver(selector: Script) -> void:
	var source: LootPoolDefinition = selector.pool("quiver_initial")
	var count: int = source.offer_count
	source.offer_count = 2
	var run := PackRun.new()
	run.reset(1729, "ranger")
	check_equal(run.offers.size(), 2, "Starting arrow choices read the Resource offer count")
	source.offer_count = count
	var definition: ItemDefinition = CATEGORIES.definition_for_key("quiver_capacity")
	var upgrades: Array[QuiverVolleyEffectDefinition] = []
	for ability: AbilityDefinition in definition.abilities:
		for candidate: EffectDefinition in ability.effects:
			if candidate is QuiverVolleyEffectDefinition and candidate.kind == QuiverVolleyEffectDefinition.Kind.UPGRADE:
				upgrades.append(candidate)
	check_equal(upgrades.size(), 1, "Expanded Quiver owns one concrete Volley upgrade effect")
	if upgrades.size() != 1:
		return
	var effect: QuiverVolleyEffectDefinition = upgrades[0]
	var cap: int = effect.cap
	check(PackRun.QUIVER.available(run.quiver()).has("quiver_capacity"), "Expanded Quiver starts below its authored upgrade cap")
	run.quiver().upgrades["quiver_capacity"] = 1
	effect.cap = 1
	check(not PackRun.QUIVER.available(run.quiver()).has("quiver_capacity"), "Upgrade availability reads the authored cap")
	effect.cap = cap
	check(PackRun.QUIVER.available(run.quiver()).has("quiver_capacity"), "Restoring authored cap makes the partially upgraded quiver eligible again")
	run.quiver().upgrades.erase("quiver_capacity")
	var before: int = run.rng.state
	var repaired: Array[String] = selector.repair(["boiler_hammer", "bandage"], "items_mage", "mage", 1)
	check(repaired.has("bandage") and not repaired.has("boiler_hammer"), "Saved-offer repair preserves legal rolls and replaces class-ineligible offers")
	check_equal(run.rng.state, before, "Saved-offer repair consumes no RNG")
