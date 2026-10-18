extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Roster capture requires a rendering display driver")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1320, 1560)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("142327")
	background.size = Vector2(1320, 1560)
	viewport.add_child(background)
	var enemies := PackCatalog.enemies()
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		var origin := Vector2((i % 5) * 264, (i / 5) * 390)
		var label := Label.new()
		label.text = enemy["name"]
		label.position = origin + Vector2(12, 8)
		label.add_theme_font_size_override("font_size", 17)
		viewport.add_child(label)
		var card: Control = load("res://scenes/game/enemy_card.tscn").instantiate()
		card.position = origin + Vector2(0, 32)
		viewport.add_child(card)
		card.get_node("EnemyArt").texture = PackArt.enemy(enemy["key"])
		card.get_node("Vitals/EnemyBar").set_amount(enemy["hp"], enemy["hp"])
		var shield: int = maxi(enemy["armor"], enemy["opening_armor"])
		card.get_node("Vitals/EnemyShieldBar").visible = shield > 0
		card.get_node("Vitals/EnemyShieldBar").set_amount(shield, shield)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://workspace/docs/art/concepts/monsters/roster-v1/godot-battle-cards.png"
	var result := viewport.get_texture().get_image().save_png(path)
	print("MONSTER CAPTURE: ", result, " ", path)
	viewport.queue_free()
	await process_frame
	quit(result)
