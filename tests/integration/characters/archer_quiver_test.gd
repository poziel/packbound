extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	var state := PackRun.new()
	state.reset(42, "ranger")
	check(PackCatalog.classes()["ranger"]["name"] == "Bowmaster", "Public class name is Bowmaster; save key stays compatible")
	check(state.quiver().get("key") == "magnificent_quiver", "Bowmaster starts with permanent quiver")
	check(not state.start_combat(), "Starting arrow choice is required")
	state.choose_loot("arrow_bodkin")
	check(state.quiver()["arrow_type"] == "bodkin" and state.item_rewards.is_empty(), "First choice configures quiver without adding an item")
	check(state.placement_plan(state.items[0], Vector2i(2, 0)).is_empty(), "Other items cannot displace permanent quiver into stash")
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [0]
	state.start_combat()
	for round_index in range(3):
		var result: Dictionary = state.end_turn()
		check(int(result["volley_damage"]) == (6 if round_index == 2 else 0), "Volley fires only on countdown expiry")
	check(state.volley_remaining == 3, "Volley reloads automatically")
	state.combat_state = PackRun.CombatState.PREPARING
	state.fight = 2
	state.roll_loot()
	check(state.offers.any(func(key: String) -> bool: return key.begins_with("quiver_")), "Quiver upgrade competes with normal item rewards")
	state.offers.assign(["quiver_capacity"])
	state.item_rewards[0]["offers"] = state.offers.duplicate()
	state.choose_loot("quiver_capacity")
	check(state.quiver()["upgrades"].get("quiver_capacity") == 1 and state.items.size() == 3, "Capacity upgrades existing quiver without consuming backpack space")
	state.volley_remaining = 1
	check(state.effects()["volley_damage"] == 9 and state.effects()[GameplayTypes.Stat.PIERCE] >= 6, "Capacity adds arrows and scales their piercing effect")
	var before: int = state.volley_remaining
	for index in range(10):
		state.outcome(state.effects())
	check(state.volley_remaining == before, "Previews never advance countdown")
	var saved := PackRunSaves.new().capture(state, 0)
	var restored := PackRun.new()
	PackRunSaves.new().restore(restored, saved)
	check(restored.quiver() == state.quiver() and restored.volley_remaining == before, "Save roundtrip retains arrows upgrades and countdown")
	state.prepare_enemy()
	check(state.volley_remaining == 3 and state.quiver()["upgrades"]["quiver_capacity"] == 1, "New fight reloads while upgrades persist")
	_upgrade_checks()
	await _ui_checks()
	report("RESULT")
	quit(1 if failures else 0)

func _upgrade_checks() -> void:
	var state: PackRun = fixture("ranger")
	for key: String in PackCatalog.QUIVER.OPTIONS:
		if not key.begins_with("quiver_"):
			continue
		state.item_rewards.assign([{"floor": 3, "offers": [key]}])
		state.offers.assign([key])
		state.choose_loot(key)
		check(state.quiver()["upgrades"].get(key, 0) == 1, "Upgrade is claimable: " + key)
	var values: Dictionary = PackCatalog.QUIVER.stats(state.quiver())
	check(values["arrows"] == 3 and values[GameplayTypes.Stat.DAMAGE] == 18 and values[GameplayTypes.Stat.POISON] == 3 and values[GameplayTypes.Stat.BURN] == 4 and values["interval"] == 2, "All upgrade mechanisms compose")
	state.quiver()["upgrades"]["quiver_capacity"] = 3
	check(not PackCatalog.QUIVER.available(state.quiver()).has("quiver_capacity"), "Capped upgrades leave offer pool")
	check(state.add_item("magnificent_quiver").is_empty(), "Permanent quiver cannot be duplicated")
	state.quiver()["upgrades"].clear()
	state.quiver()["cell"] = Vector2i(2, 0)
	state.add_item("blood_gem", Vector2i(1, 0))
	state.volley_remaining = 1
	check(state.effects()["volley_damage"] == 10, "Touching booster adds damage to Volley")
	state.relics.assign(["echo_clock"])
	state.turn = 3
	check(state.effects()["volley_damage"] == 10, "Echo does not duplicate Volley")
	state.enemy["hp"] = 1000
	state.enemy["attacks"] = [0]
	state.start_combat()
	state.begin_turn()
	var saves := PackRunSaves.new()
	var restored := PackRun.new()
	saves.restore(restored, saves.capture(state, 0))
	var remaining: int = restored.volley_remaining
	restored.complete_turn()
	check(restored.volley_remaining == remaining, "Restoring enemy-response checkpoint does not advance countdown twice")
	var old_save: Dictionary = saves.capture(state, 0)
	old_save["state"].erase("volley_remaining")
	old_save["state"]["items"][1] = PackCatalog.item("quiver")
	old_save["state"]["items"][1].merge({"id": 1, "cell": Vector2i(2, 0)}, true)
	saves.restore(restored, old_save)
	check(restored.quiver()["arrow_type"] == "broadhead" and restored.quiver()["cell"] == Vector2i(2, 0), "Legacy Ranger keeps quiver placement and gains default arrows")
	saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_logs/archer-test-saves")
	check(saves.write("quiver", saves.capture(restored, 0)) and not saves.read("quiver").is_empty(), "Save-file validation accepts permanent quiver")
	saves.remove("quiver")
	state = fixture("ranger")
	state.quiver()["upgrades"]["quiver_capacity"] = 2
	state.item_rewards.assign([{"floor": 3, "offers": ["quiver_capacity"]}, {"floor": 6, "offers": ["quiver_capacity"]}])
	state.offers.assign(["quiver_capacity"])
	state.choose_loot("quiver_capacity")
	check(state.offers == ["blood_gem"], "Deferred capped upgrade becomes ordinary reward")
	state = fixture("ranger")
	state.relics.assign(["last_thread"])
	state.hp = 1
	state.enemy["hp"] = 1000
	state.enemy["attacks"] = [100]
	state.quiver()["mask"].assign([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)])
	state.end_turn()
	check(state.last_thread_used and state.quiver()["cell"] != null, "Last Thread never unpacks permanent quiver")
	state = fixture("ranger")
	state.quiver()["arrow_type"] = "venom"
	state.quiver()["upgrades"]["quiver_fire"] = 1
	state.volley_remaining = 1
	state.enemy["hp"] = 1000
	state.enemy["attacks"] = [0]
	var resolved: Dictionary = state.end_turn()
	check(resolved["poison_tick"] == 2 and resolved["burn_tick"] == 2, "Volley applies arrow poison and upgraded fire through combat resolution")
	state = fixture("ranger")
	state.items.clear()
	for y in range(PackRun.GRID.y):
		for x in range(PackRun.GRID.x):
			state.add_item("rusty_knife", Vector2i(x, y))
	old_save = saves.capture(state, 0)
	old_save["state"].erase("volley_remaining")
	saves.restore(restored, old_save)
	check(restored.items.size() == 57 and restored.quiver()["cell"] != null and restored.can_place(restored.quiver(), restored.quiver()["cell"]), "Full legacy backpack makes room for quiver without deleting items")

func _ui_checks() -> void:
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.active_run_id = ""
	game.run.reset(42, "ranger")
	game.front.hide()
	game.combat.show()
	game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.board.get_parent())
	game._refresh()
	game._show_phase_modal()
	check(game.modal.visible and game.reward_title.text == "CHOOSE YOUR ARROWS", "New Bowmaster opens starting arrow chooser")
	await _review("starting-arrows")
	game._choose(1)
	check(game.run.quiver()["arrow_type"] == "bodkin" and not game.modal.visible, "Arrow reward card configures permanent quiver")
	var special: Dictionary = game.run.quiver()
	check(not game.storage.quick_transfer(special) and special["cell"] != null, "Quick-transfer cannot stash quiver")
	game.board.begin_drag(special, game.board.item_rect(special).get_center())
	game.board.stash_held()
	check(game.board.dragging.is_empty() and special["cell"] != null, "Dragging quiver to stash returns it to backpack")
	game.run.fight = 2
	game.run.roll_loot()
	game._open_reward(false)
	check(game.modal.visible and game.reward_title.text == "CHOOSE A REWARD / 03", "Mixed item and upgrade chooser renders")
	check(game.character_portrait.get_node("VolleyCountdown").visible and game.character_portrait.get_node("VolleyCountdown").text == "3", "Countdown is visible in portrait during preparation")
	await _review("quiver-upgrade")
	game.modal.hide()
	await _review("backpack")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)

func _review(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_logs/archer-") + label + ".png")
