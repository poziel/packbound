extends "res://tests/support/prototype_support.gd"

const PRESENTATION = preload("res://scenes/run/inventory/backpack/crafting_presentation.gd")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_logs/inventory-parity-saves")
	game.start_run("warrior", 42)
	game.run.items.clear()
	game.run.relics.clear()
	game.run.add_item("rusty_knife", Vector2i.ZERO)
	game.run.add_item("rusty_knife", Vector2i.RIGHT)
	game.run.add_item("cracked_shield", Vector2i(3, 0))
	game.run.add_item("spark_ring", Vector2i(5, 0))
	game._refresh()
	var expected_attempts: Array[Dictionary] = game.board.crafting_attempts().duplicate(true)
	check(not expected_attempts.is_empty(), "Fixture has a visible crafting opportunity")
	var expected_resources: Dictionary = game.board.preview_starting_resources()
	var expected_block: int = game.board.preview_effects().block
	for phase: int in [PackRun.Phase.SELECTOR, PackRun.Phase.ROOM, PackRun.Phase.ROOM_COMPLETE, PackRun.Phase.LOOT]:
		game.run.phase = phase
		game.run.combat_state = PackRun.CombatState.FINISHED
		# Completed-fight resources must not leak into preparation previews.
		game.run.block = 97
		game.run.mana = 0
		game.run.stamina = 0
		game.run.mana_capacity = 91
		game.run.stamina_capacity = 92
		game._update_preview()
		check(game.board.crafting_attempts() == expected_attempts, "Same crafting preview in editable phase %d" % phase)
		game.board._crafting_hover.clear()
		PRESENTATION.advance(game.board, 0.25)
		check(not game.board._crafting_hover.is_empty(), "Same crafting trails in editable phase %d" % phase)
		for resource: String in ["mana", "stamina", "block"]:
			check(game.values[resource].text == str(expected_resources[resource]), "Same %s preview in phase %d" % [resource, phase])
		check(game.mana_bar.max_value == expected_resources.mana and game.stamina_bar.max_value == expected_resources.stamina, "Resource bar capacities follow preparation in phase %d" % phase)
		check(game.board.preview_effects().block == expected_block, "Item-effect preview ignores previous fight's block in phase %d" % phase)
		var item: Dictionary = game.run.items[0]
		game.board._adjust_priority(item, 1)
		check(item.priority == 1, "Priority editing works in phase %d" % phase)
		game.board._adjust_priority(item, -1)
		check(PackRun.CRAFTING.toggle_lock(game.run, item) and item.has("craft_lock"), "Craft locks work in phase %d" % phase)
		PackRun.CRAFTING.toggle_lock(game.run, item)
		check(game.storage.quick_transfer(item) and item.cell == null, "Stash transfer works in phase %d" % phase)
		check(game.storage.quick_transfer(item) and item.cell != null, "Return from stash works in phase %d" % phase)
	game.run.phase = PackRun.Phase.FIGHT
	game.run.combat_state = PackRun.CombatState.RUNNING
	game._update_preview()
	check(game.values.block.text == "97", "Active combat retains live resources")
	check(game.board.crafting_attempts().is_empty() and not game.run.can_edit_inventory(), "Active combat still locks crafting and edits")
	report("INVENTORY ROOM PARITY")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)
