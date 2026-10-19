extends "res://tests/support/prototype_support.gd"

const PRESENTATION = preload("res://systems/enemies/enemy_presentation.gd")

func _run() -> void:
	var state: PackRun = fixture()
	var data: Dictionary = PRESENTATION.inspection(state)
	check(data["keyword_stats"] == [{"key": "physical_attack", "value": 5}], "Single strike uses compact damage stat")
	check(data["body"].is_empty() and data["bonuses"].is_empty(), "Ordinary enemy has no redundant status prose")
	for enemy: Dictionary in PackCatalog.enemies():
		state.enemy = enemy.duplicate(true)
		state.enemy["max_hp"] = enemy["hp"]
		data = PRESENTATION.inspection(state)
		check(not data["keyword_stats"].is_empty(), "Attack stat for " + str(enemy["name"]))
		for stat: Dictionary in data["keyword_stats"]:
			check(stat["key"] not in ["health", "block", "poison", "burn", "doom", "spark", "slow"], "Applied conditions and current vitals stay out of inspection")
		if int(enemy["hits"]) > 1:
			check(data["keyword_stats"].any(func(stat: Dictionary) -> bool: return stat["key"] == "multi_attack" and stat["value"] == enemy["hits"]), "Multi-attack count matches the monster")
		for ability: Dictionary in data["bonuses"]:
			check(not ability["body"].is_empty() and ability["key"].begins_with("enemy_skill_"), "Reusable named ability: " + str(ability["label"]))
		if enemy["key"] == "hollow_monk":
			check(data["bonuses"][0]["label"] == "Regeneration" and data["bonuses"][0]["body"].contains("5 health"), "Hollow Monk exposes named regeneration with its exact strength")
	await _nested_checks(state)
	report("Enemy inspection")
	quit(1 if failures else 0)

func _nested_checks(state: PackRun) -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run = state
	game.run.enemy = PackCatalog.enemies()[10].duplicate(true)
	game.run.enemy["max_hp"] = game.run.enemy["hp"]
	game.front.hide()
	game.combat.show()
	game._refresh()
	game.inspector.set_process(false)
	game.inspector._spawn(game._enemy_inspection(), Rect2(400, 180, 40, 40), -1)
	var parent: PackInspectWindow = game.inspector.windows[0]
	check(parent.body.text.contains("Abilities") and parent.body.text.contains("[u]") and parent.body.text.contains("url href=enemy_skill_regeneration"), "Abilities are named, underlined hover targets")
	parent.set_locked(true)
	game.inspector._open_keyword_link("enemy_skill_regeneration", 0)
	check(game.inspector.windows.size() == 2 and game.inspector.windows[1].body.text.contains("5"), "Named skill opens a nested definition with this enemy's value")
	if DisplayServer.get_name() != "headless":
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_logs/enemy-inspection-review.png"))
	game.queue_free()
	await process_frame
