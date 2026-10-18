extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("141722")
	background.size = Vector2(600, 240)
	viewport.add_child(background)
	for index in range(2):
		var player = load("res://scenes/game/character/player.tscn").instantiate()
		viewport.add_child(player)
		player.position.y = index * 120
		var hp = player.get_node("HpBar")
		hp.badge_icon = null
		hp.accent_color = PackKeywords.color("shield" if index == 0 else "health")
		if index == 0:
			var grey: float = hp.accent_color.get_luminance()
			hp.accent_color = Color(grey, grey, grey)
		hp.set_protected_amount(40 if index == 0 else 25, 40, 12 if index == 0 else 0)
		var mana = player.get_node("ManaBar")
		mana.accent_color = PackKeywords.color("mana")
		mana.set_amount(1 if index == 0 else 4, 1 if index == 0 else 4)
		var stamina = player.get_node("StaminaBar")
		stamina.accent_color = PackKeywords.color("stamina")
		stamina.set_amount(index, 3)
	await process_frame
	await process_frame
	for player in viewport.get_children():
		if player.has_node("ManaBar"):
			var bar = player.get_node("ManaBar")
			print("MANA GEOMETRY: width=", bar.size.x, " required=", bar.resource_width(), " capacity=", bar.max_value)
			assert(bar.size.x == bar.resource_width())
			assert(bar.bar_height == player.get_node("HpBar").bar_height)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://tests/output/character-resource-bars.png")
	print("RESOURCE BAR PREVIEW: saved")
	quit()
