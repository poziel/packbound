extends SceneTree
## Actual framebuffer QA, using real champion/monster checkpoints and bottom control.

const OUTPUT: String = "res://tests/output/combat-ui-refinement/render"
var checks: int = 0
var failures: int = 0
var viewport: SubViewport
var game: Control
var pause_after_monster: bool = false
var pause_after_failed_spell: bool = false


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func capture(label: String, dimensions: Vector2i) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	check(image.get_size() == dimensions, "Rendered dimensions for " + label + str(dimensions))
	image.save_png(OUTPUT + "/%s-%dx%d.png" % [label, dimensions.x, dimensions.y])
	return image


func press_bottom() -> void:
	# Exercise the same connected Button signal as mouse, keyboard or accessibility.
	check(not game.action.disabled, "Bottom combat control is enabled")
	game.action.pressed.emit()


func _run() -> void:
	check(DisplayServer.get_name() != "headless", "Framebuffer QA uses a graphics renderer")
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	create_timer(40.0).timeout.connect(func() -> void: printerr("Combat refinement render timeout"); quit(2))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var native_resume: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/icons/combat-v1/resume.png"))
	var svg_resume: Image = load("res://assets/ui/icons/combat-v1/resume.svg").get_image()
	check(native_resume.get_size() == Vector2i(32, 32) and svg_resume.get_size() == Vector2i(32, 32), "Native PNG and runtime SVG resume glyphs use the same 32px canvas")
	var glyphs_match: bool = native_resume.get_size() == svg_resume.get_size()
	if glyphs_match:
		for y: int in range(32):
			for x: int in range(32):
				var native_pixel: Color = native_resume.get_pixel(x, y)
				var svg_pixel: Color = svg_resume.get_pixel(x, y)
				glyphs_match = glyphs_match and is_equal_approx(native_pixel.a, svg_pixel.a) and (is_zero_approx(native_pixel.a) or native_pixel.is_equal_approx(svg_pixel))
	check(glyphs_match, "Runtime SVG has the exact visible pixels and alpha of the native Pixelorama PNG export")
	viewport = SubViewport.new()
	viewport.size_2d_override = Vector2i(1280, 800)
	viewport.size_2d_override_stretch = true
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame
	game.playback.monster_resolved.connect(func(_result: Dictionary) -> void:
		if pause_after_monster:
			pause_after_monster = false
			press_bottom())
	game.playback.player_resolved.connect(func(result: Dictionary) -> void:
		if pause_after_failed_spell and not result.get("dormant_ids", []).is_empty():
			pause_after_failed_spell = false
			press_bottom())
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(800, 500)]:
		viewport.size = dimensions
		game.start_run("mage", 42)
		game.front.settings["combat_speed"] = 4
		game.front.settings["flash"] = true
		game.front.settings["sound"] = false
		game.run.relics.clear()
		game.run.items.clear()
		game.run.add_item("spark_ring", Vector2i(0, 0))["mana"] = 3
		var spell: Dictionary = game.run.add_item("ember_tome", Vector2i(1, 0))
		spell["cost"] = 4
		game.run.add_item("buckler", Vector2i(4, 0))["block"] = 8
		var finisher: Dictionary = game.run.add_item("rusty_knife", Vector2i(0, 3))
		finisher["damage"] = 0
		game.run.enemy["hp"] = 1000
		game.run.enemy["max_hp"] = 1000
		game.run.enemy["attacks"] = [4]
		game.run.enemy["hits"] = 1
		game.run.enemy["shield"] = 0
		game._refresh()
		check(game.action.text.is_empty() and game.action.accessibility_name == "Attack" and game.action.icon != null, "Preparation uses an accessible Attack glyph")
		check(game.action.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER and game.action.tooltip_text.is_empty() and game.action.accessibility_name == "Attack", "Attack glyph is centered with a accessible name without a tooltip")
		game.action.grab_focus()
		check(game.action.focus_mode == Control.FOCUS_ALL and game.action.has_focus(), "Icon-only combat control retains keyboard focus")
		check(game.mana_bar.value_label.text == "6 / 6" and game.block_bar.value_label.text == "8 / 8", "Preparation shows real mana/block capacities")
		await capture("preparation", dimensions)
		pause_after_monster = true
		press_bottom()
		while not game.playback.paused:
			await process_frame
		check(game.mana_bar.value_label.text == "2 / 6" and game.block_bar.value_label.text == "4 / 8", "Real spell and enemy strike deplete finite pools")
		check(is_equal_approx(game.mana_bar.ratio, 1.0 / 3.0) and is_equal_approx(game.block_bar.ratio, 0.5), "Rendered meters receive proportional remaining fractions")
		check(game.action.accessibility_name == "Resume combat" and game.action.icon != null, "Paused bottom control shows Resume")
		check(game.action.tooltip_text.is_empty() and game.action.accessibility_name == "Resume combat" and game.action.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Resume glyph stays centered and named")
		var original: Array = game.run.items.duplicate(true)
		game.board.begin_drag(spell, game.board.item_rect(spell).get_center())
		game.board.rotate_held()
		game.board.drop_at(Vector2.ZERO)
		check(game.board.dragging.is_empty() and game.run.items == original, "Paused inventory rejects moving, rotating and dropping items")
		var resting: Image = await capture("spent-paused", dimensions)
		pause_after_failed_spell = true
		press_bottom()
		check(not game.playback.paused and game.action.accessibility_name == "Pause combat", "Bottom Resume immediately restores the Pause control")
		check(game.action.tooltip_text.is_empty() and game.action.accessibility_name == "Pause combat" and game.action.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Pause glyph stays centered and named")
		await capture("resumed", dimensions)
		while not game.playback.paused:
			await process_frame
		check(game.board.failed_activations.has(spell["id"]) and game.run.turn >= 2, "Actual next champion checkpoint flashes the mana-starved spell")
		var pulse_remaining: float = game.board.failed_activations.get(spell["id"], 0.0)
		var pulsing: Image = await capture("failed-spell-paused", dimensions)
		var ratio: float = dimensions.x / 1280.0
		var item_area: Rect2 = game.board.item_rect(spell)
		item_area.position += game.board.global_position
		item_area = Rect2(item_area.position * ratio, item_area.size * ratio)
		var red_pixels: int = 0
		for y: int in range(int(item_area.position.y), int(item_area.end.y)):
			for x: int in range(int(item_area.position.x), int(item_area.end.x)):
				var before: Color = resting.get_pixel(x, y)
				var after: Color = pulsing.get_pixel(x, y)
				if after.r > before.r + 0.12 and after.r > after.g + 0.12:
					red_pixels += 1
		check(red_pixels > 100, "Actual failed activation adds visible red pixels to the item: %d" % red_pixels)
		await create_timer(0.2).timeout
		check(is_equal_approx(game.board.failed_activations.get(spell["id"], 0.0), pulse_remaining), "Pause freezes failed-item feedback for inspection")
		# Arrange a deterministic terminal hit through the test fixture only.
		finisher["damage"] = 10000
		game.run.enemy["hp"] = 1
		press_bottom()
		while game.playback.active or game.busy or game.gameplay_background.transitioning:
			await process_frame
		check(game.run.fight == 1 and game.run.combat_state == PackRun.CombatState.PREPARING, "Victory automatically reaches next-room preparation")
		check(game.action.accessibility_name == "Attack" and not game.action.disabled and game.action.icon != null, "Next room restores enabled Attack glyph")
		check(game.board.failed_activations.is_empty(), "Room transition clears failed-item pulse")
		await capture("next-room", dimensions)
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, viewport)
	print("COMBAT REFINEMENT RENDER TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
