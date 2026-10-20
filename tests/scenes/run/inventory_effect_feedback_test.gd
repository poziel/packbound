extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	var state: PackRun = fixture()
	state.items.clear()
	state.add_item("rusty_knife", Vector2i.ZERO)
	var effects: Dictionary = state.effects()
	check(effects.has("item_effects"), "Combat retains source item contributions")
	var herbs: Dictionary = state.add_item("healing_herbs", Vector2i(2, 0))
	state.hp = state.max_hp
	var resolved: Dictionary = state.outcome(state.effects())
	check(resolved["item_effects"].filter(func(e: Dictionary) -> bool: return e["id"] == herbs["id"] and e["key"] == "healing").is_empty(), "Full health suppresses unused healing")
	state.hp -= 1
	resolved = state.outcome(state.effects())
	var healing: Array = resolved["item_effects"].filter(func(e: Dictionary) -> bool: return e["key"] == "healing")
	check(healing.size() == 1 and healing[0]["amount"] == 1, "Healing displays restored HP rather than nominal strength")
	state.items.clear()
	state.add_item("thorn_mail", Vector2i.ZERO)
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [10]
	resolved = state.outcome(state.effects())
	check(resolved["item_effects"].filter(func(e: Dictionary) -> bool: return e["key"] in ["thorns", "plating", "slow"]).is_empty(), "Reactive defenses wait for monster checkpoint")
	check(not resolved["response_item_effects"].is_empty(), "Monster response retains defensive item sources")
	state.items.clear()
	var spell: Dictionary = state.add_item("ember_tome", Vector2i.ZERO)
	spell["activation_costs"][GameplayTypes.ResourceType.MANA] = 999
	resolved = state.outcome(state.effects())
	check(resolved["item_effects"].filter(func(e: Dictionary) -> bool: return e["id"] == spell["id"]).is_empty(), "Dormant items produce no activation popup")
	state.items.clear()
	state.add_item("rusty_knife", Vector2i.ZERO)
	effects = state.effects()
	var board: BackpackBoard = BackpackBoard.new()
	root.add_child(board)
	board.run = state
	check(board.has_method("show_item_effects"), "Inventory supports keyword popups")
	if board.has_method("show_item_effects"):
		board.show_item_effects(effects, 1.0)
		check(not board.effect_popups.is_empty(), "Attack produces a popup")
		board.set_activation_feedback_paused(true)
		board._process(0.3)
		check(board.effect_popups[0]["elapsed"] == 0.0, "Pause freezes popup animation")
		board.set_activation_feedback_paused(false)
		board._process(2.0)
		check(board.effect_popups.is_empty(), "Popup expires")
		board.show_item_effects(effects, 1.0)
		board.clear_activation_feedback()
		check(board.effect_popups.is_empty(), "Reset removes popup feedback")
		board.show_item_effects(effects, 4.0)
		board._process(0.25)
		check(not board.effect_popups.is_empty(), "Fast combat preserves popup reading time")
		check(board.effect_popups[0].has("duration"), "Popups have individual durations")
		board.clear_activation_feedback()
		var knife: Dictionary = state.items[0]
		var burst: Dictionary = {"item_effects": []}
		for key: String in ["physical_attack", "poison", "burn"]:
			burst["item_effects"].append({"id": knife["id"], "key": key, "amount": 3})
		board.show_item_effects(burst)
		check(board.effect_popups[0]["anchor"].distance_to(board.effect_popups[1]["anchor"]) >= 20, "Same-item effects use separated origins")
		check(board.effect_popups[0].get("height", 0) != board.effect_popups[1].get("height", 0), "Rise heights vary")
	var enemy_script: Script = load("res://scenes/run/enemy_card/enemy_card.gd")
	check(enemy_script.has_method("monster_effect_entries"), "Monster supports aggregate combat feedback")
	var aggregate: Array = enemy_script.monster_effect_entries({"direct_damage_actual": 40, "item_effects": [{"key": "poison", "amount": 1}, {"key": "poison", "amount": 2}]})
	check(aggregate.size() == 2 and aggregate[0]["amount"] == 40 and aggregate[1]["amount"] == 3, "Monster feedback combines forty damage and three poison")
	board.queue_free()
	if DisplayServer.get_name() != "headless":
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_godot/inventory-effect-test-saves")
		game.start_run("warrior", 42)
		game.run.items.clear()
		var weapon: Dictionary = game.run.add_item("rusty_knife", Vector2i(0, 1))
		weapon[GameplayTypes.Stat.POISON] = 3
		weapon[GameplayTypes.Stat.BURN] = 2
		game.run.add_item("healing_herbs", Vector2i(2, 1))
		game.run.add_item("cracked_shield", Vector2i(4, 1))
		game._refresh()
		game.board.show_item_effects(game.run.effects())
		game.board._process(0.3)
		game.board.set_activation_feedback_paused(true)
		game.enemy_card.show_combat_effects({"direct_damage_actual": 40, "item_effects": [{"key": "poison", "amount": 3}]})
		game.enemy_card._process(0.5)
		game.enemy_card.set_feedback_paused(true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_godot/inventory-effect-feedback.png"))
	report("INVENTORY FEEDBACK")
	quit(1 if failures else 0)
