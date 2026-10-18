extends SceneTree

const BAR: PackedScene = preload("res://components/pixel_stat_bar/pixel_stat_bar.tscn")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var bar: PixelStatBar = BAR.instantiate()
	check(bar.has_node("ValueLabel"), "Value label is authored in the reusable scene")
	root.add_child(bar)
	await process_frame
	bar.set_amount(21, 28)
	check(bar.value_label.text == "21 / 28", "Numbers follow the public amount API")
	check(is_equal_approx(bar.ratio, 0.75), "Fill represents current divided by capacity")
	var label_rect: Rect2 = bar.value_label.get_rect()
	check(absf(label_rect.get_center().x - bar.size.x * 0.5) <= bar.pixel_size, "Badge is centered on the pixel grid")
	bar.value = 9
	check(bar.value_label.text == "9 / 28", "Direct Range changes update the label")
	check(bar.value_label.get_rect() == label_rect, "Digit changes keep the badge in place")
	bar.value = -5
	check(bar.value == 0 and bar.value_label.text == "0 / 28", "Negative values clamp to empty")
	bar.value = 100
	check(bar.value == 28 and bar.value_label.text == "28 / 28", "Over-capacity values clamp to full")
	bar.max_value = 12
	check(bar.value == 12 and bar.value_label.text == "12 / 12", "Shrinking capacity clamps both numbers and fill")
	bar.set_amount(8, 0)
	check(bar.value_label.text == "0 / 0" and bar._fill_ratio() == 0, "Zero capacity has no fill or division by zero")
	bar.set_amount(3, -10)
	check(bar.value_label.text == "0 / 0", "Negative capacity is normalized")
	bar.set_amount(21, 28)
	check(bar.ratio == 0.75, "A meter recovers after zero capacity")
	bar.number_mode = PixelStatBar.NumberMode.PERCENTAGE
	check(bar.value_label.text == "75%", "Percentage mode")
	bar.number_mode = PixelStatBar.NumberMode.VALUE
	check(bar.value_label.text == "21", "Current-only mode")
	bar.number_mode = PixelStatBar.NumberMode.HIDDEN
	check(not bar.value_label.visible and bar.get_minimum_size().y == 28, "Hidden numbers release the label space")
	bar.number_mode = PixelStatBar.NumberMode.FRACTION
	bar.step = 0.01
	bar.decimal_places = 2
	bar.set_amount(2.5, 10)
	check(bar.value_label.text == "2.50 / 10.00", "Fractional resources respect precision")
	bar.min_value = -10
	bar.value = -5
	check(bar.value_label.text == "-5.00 / 10.00" and bar.ratio == 0.25, "Nonzero and signed Range minima work")
	bar.decimal_places = 0
	bar.set_amount(99999, 100000)
	await process_frame
	check(Rect2(Vector2.ZERO, bar.size).encloses(bar.value_label.get_rect()), "Large values stay inside the component")
	bar.size = Vector2(640, 60)
	await process_frame
	check(absf(bar.value_label.get_rect().get_center().x - 320) <= bar.pixel_size, "Resizing re-centers the badge")
	check(bar.value_label.position.x == floorf(bar.value_label.position.x), "Label sits on integer coordinates")
	var other: PixelStatBar = BAR.instantiate()
	root.add_child(other)
	other.set_amount(9, 9)
	other.accent_color = Color("8fc4da")
	check(bar.accent_color != other.accent_color and bar.value != other.value, "Instances keep independent colors and values")
	check(other.value_label.get_theme_color("font_color") == other.accent_color, "Number color follows the accent")
	bar.queue_free()
	other.queue_free()
	await process_frame

	var demo: Control = load("res://components/pixel_stat_bar/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	demo.get_node("Amount").value = 0
	check(demo.get_node("Health").value == 0 and demo.get_node("Experience").value_label.text == "0%", "Demo slider drives empty state")
	demo.get_node("Recover").pressed.emit()
	check(demo.get_node("Amount").value == 10, "Recover button changes the slider")
	demo.get_node("Damage").pressed.emit()
	check(demo.get_node("Amount").value == 0, "Damage button changes the slider")
	demo.get_node("Amount").value = 100
	check(demo.get_node("Health").value == 28 and demo.get_node("Shield").value == 12, "Demo slider drives full state")
	demo.get_node("Reset").pressed.emit()
	check(demo.get_node("Health").value_label.text == "21 / 28", "Reset restores demo values")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.save_png("res://tests/output/pixel-stat-bar-demo.png")
	demo.queue_free()
	await process_frame
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	await process_frame
	check(game.hp_bar is PixelStatBar and game.enemy_bar is PixelStatBar, "Both combat health displays use the reusable component")
	check(game.mana_bar is PixelStatBar and game.block_bar is PixelStatBar, "Mana and generated block use the same reusable scene")
	check(game.hp_label.text == "40 / 40", "Player health initializes from combat state")
	check(game.enemy_hp.text == "%d / %d" % [game.run.enemy["hp"], game.run.enemy["max_hp"]], "Enemy health initializes from combat state")
	check(game.mana_bar.value_label.text == "0 / 0", "Mana preparation starts empty without a fake capacity")
	check(game.block_bar.value == game.board.preview_effects()["block"], "Block shows generated combat block")
	check(game.block_bar.number_mode == PixelStatBar.NumberMode.FRACTION, "Block displays its finite pool capacity")
	var registered: int = 0
	for source: Dictionary in game.inspector.sources:
		if source["target"] in [game.hp_bar, game.enemy_bar, game.mana_bar, game.block_bar]:
			registered += 1
	check(registered == 4, "All four complete stat bars retain inspection")
	for resource_bar: PixelStatBar in [game.mana_bar, game.block_bar]:
		check(resource_bar.focus_mode == Control.FOCUS_ALL, "Resource bars support keyboard inspection")
		check(not resource_bar.get_global_rect().intersects(game.hp_bar.get_global_rect()), "Resource bars do not overlap health")
		check(not resource_bar.get_global_rect().intersects(game.board.get_global_rect()), "Resource bars do not overlap the inventory")
		var caption: RichTextLabel = resource_bar.get_parent().get_node("ManaCaption" if resource_bar == game.mana_bar else "BlockCaption")
		check(not caption.get_global_rect().intersects(resource_bar.value_label.get_global_rect()), "Resource caption stays clear of its number")
	game.run.combat_state = PackRun.CombatState.RUNNING
	game.run.mana_capacity = 12
	game.run.mana = 6
	game._update_preview()
	check(game.mana_bar.value_label.text == "6 / 12" and game.mana_bar.value == 6, "Remaining mana displays its current value")
	game.run.mana = 12
	game._update_preview()
	check(game.mana_bar.ratio == 1, "Mana reaches a full bar at its real cap")
	game.run.combat_state = PackRun.CombatState.PREPARING
	game.run.items.clear()
	game.run.carry_block = 0
	game._update_preview()
	check(game.block_bar.value_label.text == "0 / 0" and game.block_bar._fill_ratio() == 0, "Removing defense items empties the block bar")
	game.run.combat_state = PackRun.CombatState.RUNNING
	game.run.block_capacity = 7
	game.run.block = 7
	game._update_preview()
	check(game.block_bar.value_label.text == "7 / 7" and game.block_bar.ratio == 1, "Retained block participates in the live block display")
	for character: String in ["warrior", "ranger", "mage", "assassin", "necromancer"]:
		game.start_run(character, 42)
		game._open_reward(true)
		game._choose(0)
		game._act()
		while game.busy:
			await process_frame
		check(game.hp_bar.value == game.run.hp and game.enemy_bar.value == game.run.enemy["hp"], character + ": health bars follow resolved combat")
		check(game.mana_bar.value == (game.run.starting_resources()["mana"] if game.run.combat_state == PackRun.CombatState.PREPARING else game.run.mana), character + ": mana follows preparation or remaining pool")
		check(game.block_bar.value == (game.run.starting_resources()["block"] if game.run.combat_state == PackRun.CombatState.PREPARING else game.run.block), character + ": block follows preparation or live pool")
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/output/pixel-stat-bar-combat.png")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	print("PIXEL STAT BAR RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
