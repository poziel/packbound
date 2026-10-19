extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	_mana_priority_checks()
	_echo_checks()
	_mirror_tie_checks()
	_starting_resources_checks()
	_finite_resource_checks()
	_lifecycle_checks()
	_terminal_checks()
	_catalog_checks()
	_mechanics_checks()
	_progression_checks()
	report("RESULT")
	quit(1 if failures else 0)

func _starting_resources_checks() -> void:
	var state: PackRun = fixture("warrior")
	state.items.clear()
	for index in range(4):
		state.add_item("spark_ring", Vector2i(index, 0))["mana"] = 6
	check(state.has_method("starting_resources"), "Starting resources API exists")
	if not state.has_method("starting_resources"):
		return
	check(state.call("starting_resources")["mana"] == 25, "Starting mana adds equipment to the base pool without a cap")
	var before: Array = [state.hp, state.mana, state.block, state.history.duplicate(), state.stage_history.duplicate(true)]
	for index in range(100):
		state.outcome(state.effects())
	check(before == [state.hp, state.mana, state.block, state.history, state.stage_history], "100 preparation previews mutate no health, resources or logs")
	check(state.call("start_combat"), "First start succeeds")
	check(not state.call("start_combat") and state.mana == 25, "Duplicate start cannot refill")

func _mirror_tie_checks() -> void:
	var state: PackRun = fixture("warrior")
	state.items.clear()
	var early: Dictionary = state.add_item("rusty_knife", Vector2i(1, 0))
	early.merge({"damage": 8, "block": 0}, true)
	var mirror: Dictionary = state.add_item("mirror_shard", Vector2i(1, 1))
	var late: Dictionary = state.add_item("rusty_knife", Vector2i(0, 1))
	late.merge({"damage": 0, "block": 8}, true)
	check(state._mirror_target(mirror, state.packed())["id"] == early["id"], "Mirror equal-strength tie uses occupied-cell reading order")
	var resources: Dictionary = state.starting_resources()
	var effects: Dictionary = state.effects()
	state.items.reverse()
	check(state.starting_resources() == resources and state.effects() == effects, "Mirror tie resources and effects ignore storage order")
	early["cell"] = Vector2i(0, 2)
	late["cell"] = Vector2i(1, 0)
	check(state._mirror_target(mirror, state.packed())["id"] == late["id"], "Moving tied Mirror neighbor changes reading priority")

func _harmless_enemy(state: PackRun, damage: int = 0) -> void:
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [damage]
	for key in ["armor", "opening_armor", "cycle_armor", "parry", "enrage", "poison", "sunder", "pierce", "reflect", "regen", "drain"]:
		state.enemy[key] = 0
	state.enemy["hits"] = 1

func _finite_resource_checks() -> void:
	var state: PackRun = fixture("warrior")
	state.items.clear()
	state.add_item("cracked_shield", Vector2i.ZERO)
	_harmless_enemy(state, 3)
	var initial_hp: int = state.hp
	state.end_turn()
	check(state.block == 2 and state.hp == initial_hp, "Starting shield retains two after first three damage")
	state.end_turn()
	check(state.block == 0 and state.hp == initial_hp - 1, "Second strike spends remaining shield and loses one HP")
	state = fixture("warrior")
	state.items.clear()
	var ring: Dictionary = state.add_item("spark_ring", Vector2i.ZERO)
	ring["mana"] = 24
	ring["mana_per_round"] = 2
	ring["block_per_round"] = 1
	_harmless_enemy(state)
	state.end_turn()
	check(state.mana == 27 and state.block == 1, "Round one includes base, equipment and explicit regeneration")
	state.end_turn()
	check(state.mana == 27 and state.block == 2, "Round two refills mana without accumulation; block retains explicit gains")
	state = fixture("warrior")
	state.items.clear()
	state.add_item("spark_ring", Vector2i.ZERO)["mana"] = 3
	var spell: Dictionary = state.add_item("ember_tome", Vector2i(1, 0))
	_harmless_enemy(state)
	state.end_turn()
	check(state.mana == 4 and state.effects()["active_ids"].has(spell["id"]), "Mana refills so the spell can activate again next round")
	state.hp = 10
	state.phase = PackRun.Phase.LOOT
	state.advance_encounter()
	state.choose_destination("combat")
	check(state.hp == 10 and state.mana == 0 and state.block == 0, "Floor entry clears temporary resources without healing")
	if state.has_method("start_combat"):
		state.items[0]["mana"] = 7
		state.call("start_combat")
		check(state.mana == 8, "Next room derives starting resources from base and changed preparation")

func _lifecycle_checks() -> void:
	var state: PackRun = fixture("ranger")
	check(state.has_method("start_combat") and state.has_method("can_edit_inventory") and state.has_method("can_claim_rewards"), "Lifecycle APIs exist")
	if not state.has_method("start_combat"):
		return
	check(state.begin_turn().is_empty(), "Staged resolution requires running combat")
	check(state.call("can_edit_inventory") and state.call("can_claim_rewards"), "Preparation permits edits and rewards")
	state.call("start_combat")
	check(not state.call("can_edit_inventory") and not state.call("can_claim_rewards"), "Running locks edits and rewards between checkpoints")
	var original_cell: Variant = state.items[0]["cell"]
	check(state.add_item("spark_ring").is_empty() and not state.auto_place(state.items[0]) and state.items[0]["cell"] == original_cell, "Model inventory mutation entry points reject running edits")
	state.relic_rewards.append(5)
	state.relic_offers.assign(["echo_clock"])
	state.choose_relic("echo_clock")
	check(not state.relics.has("echo_clock"), "Running rejects relic selection")
	state.roll_loot()
	var count: int = state.items.size()
	state.choose_loot(state.offers[0])
	check(state.items.size() == count, "Running rejects reward selection")
	var checkpoint: Dictionary = state.begin_turn()
	check(not checkpoint.is_empty(), "Running commits player checkpoint")
	state.call("set_combat_paused", true)
	state.choose_loot(state.offers[0])
	check(state.items.size() == count and state.complete_turn().is_empty() and state.begin_turn().is_empty(), "Paused rejects rewards and both checkpoint commits")
	state.choose_relic("echo_clock")
	check(not state.relics.has("echo_clock") and not state.call("start_combat"), "Paused rejects relic selection and resource restart")
	state.call("set_combat_paused", false)
	check(not state.complete_turn().is_empty(), "Resume completes original checkpoint")
	state = fixture("warrior")
	state.hp = 1
	state.items.clear()
	state.add_item("longsword", Vector2i.ZERO)
	state.relics = ["last_thread"]
	_harmless_enemy(state, 100)
	var result: Dictionary = state.end_turn()
	check(result["revived"] and state.hp == 8 and state.items[0]["cell"] == null, "Last Thread explicitly unpacks during locked fight")
	check(not state.call("can_edit_inventory"), "Revival does not unlock user edits")

func _terminal_checks() -> void:
	var state: PackRun = fixture("warrior")
	state.items.clear()
	state.add_item("longsword", Vector2i.ZERO)
	state.add_item("cracked_shield", Vector2i(1, 0))
	state.enemy["hp"] = 1
	state.enemy["sunder"] = 100
	var result: Dictionary = state.end_turn()
	check(not result["has_response"] and state.block == 5, "Lethal champion action preserves block without enemy sunder")
	check(state.begin_turn().is_empty() and state.complete_turn().is_empty(), "Finished fight rejects further checkpoints")
	state.fight = 19
	state.floor_index = 19
	state.advance_encounter()
	var count: int = state.items.size()
	state.choose_loot(state.offers[0])
	check(state.items.size() == count + 1, "Final victory can claim banked reward")
	state.reset(42, "mage")
	check(state.items.size() == 3 and state.hp == 28 and state.mana == 0, "Reset from terminal state restores starter inventory")
	state.items.clear()
	state.hp = 1
	state.player_poison = 2
	state.add_item("cracked_shield", Vector2i.ZERO)
	result = state.end_turn()
	check(state.phase == PackRun.Phase.DEFEAT and not result["has_response"] and state.block == 5, "Lethal player status ends fight without spending block")
	state.reset(42, "ranger")
	check(state.items.size() == 3, "Reset from defeat restores starters")

func _mana_priority_checks() -> void:
	var state: PackRun = fixture("ranger")
	state.items.clear()
	state.add_item("spark_ring", Vector2i(5, 4))["mana"] = 6
	var first: Dictionary = state.add_item("ember_tome", Vector2i(0, 0))
	var second: Dictionary = state.add_item("ember_tome", Vector2i(3, 2))
	first["cost"] = 4
	second["cost"] = 4
	var stats: Dictionary = state.effects()
	check(stats["active_ids"].has(first["id"]) and stats["dormant_ids"].has(second["id"]), "Reading order receives scarce mana")
	check(stats["mana_after"] == 3 and stats["mana_spent"] == 4, "Whole cost only is paid")
	state.items.reverse()
	check(state.effects() == stats, "Storage order cannot change effects")
	first["cell"] = Vector2i(3, 2)
	second["cell"] = Vector2i.ZERO
	check(state.effects()["active_ids"].has(second["id"]), "Moving spells swaps priority")
	first["cost"] = 2
	second["cost"] = 3
	for item in state.items:
		if item["key"] == "spark_ring": item["mana"] = 1
	stats = state.effects()
	check(stats["active_ids"].has(first["id"]) and stats["dormant_ids"].has(second["id"]) and stats["mana_spent"] == 2, "Unaffordable earlier item is skipped without partial charge")
	state.relics.assign(["arcane_barter"])
	stats = state.effects()
	check(stats["blood_cost"] == 3 and stats["mana_spent"] == 2, "Barter aggregates total missing mana")

func _echo_checks() -> void:
	var state: PackRun = fixture("ranger")
	state.items.clear()
	state.turn = 3
	state.relics.assign(["echo_clock"])
	var early: Dictionary = state.add_item("rusty_knife", Vector2i.ZERO)
	early["damage"] = 10
	var strong: Dictionary = state.add_item("rusty_knife", Vector2i(3, 0))
	strong.merge({"damage": 8, "poison": 2, "burn": 3, "vampirism": 7}, true)
	state.add_item("cursed_idol", Vector2i(4, 0))
	var stats: Dictionary = state.effects()
	check(stats.get("echo_item_id", -1) == strong["id"] and stats["damage"] == 32, "Echo selects adjacency-enhanced strongest activation")
	check(stats["poison"] == 4 and stats["burn"] == 6 and stats["vampirism"] == 14 and stats["repeats"] == 1, "Echo copies attached effects exactly once")
	early["damage"] = 11
	check(state.effects().get("echo_item_id", -1) == early["id"], "Echo ties select reading order")
	state.items.reverse()
	check(state.effects().get("echo_item_id", -1) == early["id"], "Echo ties ignore storage order")
	var spell: Dictionary = state.add_item("ember_tome", Vector2i(0, 3))
	spell["damage"] = 100
	check(state.effects().get("echo_item_id", -1) == early["id"], "Dormant spell cannot win Echo")
	state.add_item("spark_ring", Vector2i(5, 4))["mana"] = 3
	check(state.effects().get("echo_item_id", -1) == spell["id"] and state.effects()["mana_spent"] == 3, "Eligible spell repeats without another mana cost")
	spell["cell"] = null
	early["role"] = "ranged"
	early["damage"] = 6
	stats = state.effects()
	check(stats.get("echo_item_id", -1) == strong["id"] and stats["damage"] == 28 and stats["repeats"] == 1, "Archer does not copy ranged weapons; Echo remains independent")
	state.class_key = "warrior"
	state.turn = 12
	early["role"] = "weapon"
	state.add_item("hourglass", Vector2i(0, 3))
	stats = state.effects()
	check(stats.get("echo_item_id", -1) == strong["id"] and stats["damage"] == 45 and stats["repeats"] == 3, "Hourglass and Echo add independent copies")
	state.turn = 2
	check(state.effects().get("echo_item_id", -1) == -1, "Unused Echo exposes minus-one identity")

