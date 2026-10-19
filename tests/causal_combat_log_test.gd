extends "res://tests/prototype_test.gd"

func _run() -> void:
	var state: PackRun = fixture("mage")
	state.items.clear()
	var fire: Dictionary = state.add_item("ember_tome", Vector2i.ZERO)
	var frost: Dictionary = state.add_item("frost_wand", Vector2i(3, 0))
	frost["priority"] = 1
	state.add_item("spark_ring", Vector2i(5, 0))
	state.enemy["hp"] = 1000
	var stats: Dictionary = state.effects()
	var lines: String = "\n".join(state.outcome(stats)["player_events"])
	check(lines.find("Spark Ring") >= 0 and lines.find("Spark Ring") < lines.find("cost:"), "Resource sources precede paid activations")
	check(lines.find("Frost Wand[/url] activation") < lines.find("Ember Grimoire[/url] activation"), "Activation log follows priority before reading order")
	check(lines.contains("activation (cost: 2 mana)"), "Costs identify the activated item")
	check(not lines.contains("Round 1:") and not lines.contains("0 stamina"), "Refill logs omit round narration and zero resources")
	check(lines.contains("[indent]– Contributes") and not lines.contains("[/url] contributes"), "Item effects are indented without repeating their source")
	check(lines.find("Fire trace") < lines.find("cause Thermal Shock"), "Traces appear before the reaction consuming them")
	check(lines.contains("1 fire + 1 frost cause Thermal Shock"), "Reaction names exact consumed quantities")
	check(not lines.contains("mana on items"), "Aggregate spending does not duplicate individual costs")
	frost["priority"] = 0
	var reading_lines: String = "\n".join(state.outcome(state.effects())["player_events"])
	check(reading_lines.find("Ember Grimoire[/url] activation") < reading_lines.find("Frost Wand[/url] activation"), "Equal priorities use backpack reading order")
	frost["priority"] = 1
	for recipe: Dictionary in preload("res://scripts/elemental_combat.gd").REACTIONS:
		check(not PackKeywordLinks.entry("reaction_" + str(recipe["id"])).get("body", "").is_empty(), "Reaction definition exists: " + str(recipe["name"]))
	state.items.erase(fire)
	check(state.effects()["reactions"].is_empty(), "A single element cannot react without a matching enemy trace")
	var prior: int = state.history.size()
	state.roll_loot()
	state.choose_loot(state.offers[0])
	check(state.history.size() == prior, "Reward choices do not pollute combat history")
	check(not PackKeywordLinks.entry("catalog_item_ember_tome").is_empty(), "Log item links have catalog tooltips")
	check(PackKeywordLinks.rich("Thermal Shock applies burn").contains("url=reaction_thermal_shock"), "Reactions and conditions are hoverable")
	state.items.assign([frost])
	state.elemental_traces = {"fire": [2]}
	check(state.effects()["reactions"] == ["thermal_shock"], "A surviving enemy trace reacts with the next cast")
	state.elemental_traces = {"fire": [1]}
	check(state.effects()["reactions"].is_empty(), "Expired traces cannot trigger reactions")
	_shield_bonus_checks()
	await _ui_checks(state)
	print("Causal combat log: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _shield_bonus_checks() -> void:
	var state: PackRun = fixture()
	state.items.clear()
	state.add_item("cracked_shield", Vector2i.ZERO)
	state.add_item("iron_charm", Vector2i.RIGHT)
	var lines: String = "\n".join(state.outcome(state.effects())["player_events"])
	check(lines.contains("Cracked Shield[/url] activation"), "Starting shield grant has an item heading")
	check(lines.contains("[indent]– Receives +3 block from touching [url=catalog_item_iron_charm]"), "Shield grant identifies the booster")
	check(lines.find("Receives +3 block") < lines.find("Granted 8 block at combat start"), "Bonus precedes the boosted shield total")
	check(lines.contains("[indent]– Granted 1 stamina at combat start"), "Passive resource grants use the same grouped format")

func _ui_checks(state: PackRun) -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run = state
	game.front.hide()
	game.combat.show()
	game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.history_view.get_parent())
	state.elemental_traces = {"fire": [2]}
	state.log_action(state.outcome(state.effects())["player_events"])
	game._refresh_history()
	check(game.history_view.text.contains("url=catalog_item_frost_wand"), "Rendered history keeps item links")
	for key: String in ["burn", "reaction_hellfire", "catalog_item_frost_wand"]:
		game.history_view.meta_hover_started.emit(key)
		var candidate: Dictionary = game.inspector._candidate(game.history_view)
		check(candidate.get("data", {}).get("key") == key, "History hover resolves " + key)
		game._refresh_history()
		game.history_view.meta_hover_ended.emit(key)
	game._show_result_log()
	game._process(0)
	check(game.inspector.enabled, "Inspection remains enabled in the end-of-run log")
	var result_history: RichTextLabel = game.result_log.get_node("History")
	result_history.meta_hover_started.emit("reaction_blackout")
	check(game.inspector._candidate(result_history).get("data", {}).get("title") == "Blackout", "Result log shares reaction tooltips")
	if DisplayServer.get_name() != "headless":
		game.modal.hide()
		game.inspector.set_process(false)
		game.inspector._spawn(PackKeywordLinks.entry("reaction_blackout"), Rect2(550, 180, 20, 20), -1)
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Dev/2-games/packbound/workspace/logs/causal-log-review.png")
	game.queue_free()
	await process_frame
