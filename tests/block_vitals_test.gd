extends SceneTree

var failures := 0
var checks := 0
var game
var view: SubViewport

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	game.run.enemy["armor"] = 6
	game.run.enemy_shield_spent = 2
	game.run.player_poison = 3
	game.run.enemy_poison = 2
	game.run.enemy_burn = 4
	game._refresh()
	await process_frame
	await process_frame
	check(not game.enemy_shield_bar.visible, "Enemy uses one visible meter")
	check(game.enemy_bar.protection_amount == 4 and game.enemy_bar.protection_pattern, "Enemy Block shares health badge and pattern")
	check(game.enemy_bar.value == game.run.enemy["hp"] and game.enemy_bar.max_value == game.run.enemy["max_hp"], "Block does not change health fill or maximum")
	check(game.hp_bar.protection_pattern and game.hp_bar.accent_color == game.enemy_bar.accent_color, "Player and enemy protection styling matches")
	check(game.enemy_bar.badge_icon == game.hp_bar.badge_icon, "Both combined meters share badge structure")
	check(game.enemy_bar.bar_height == game.hp_bar.bar_height and game.enemy_bar.number_size == game.hp_bar.number_size, "Enemy and player meters use the same dimensions and type size")
	var enemy_status: RichTextLabel = game.enemy_vitals.get_node("Statuses")
	check(enemy_status.visible and enemy_status.get_parsed_text().contains("Poison") and enemy_status.get_parsed_text().contains("Burn"), "Enemy statuses show active stacks")
	check(enemy_status.get_global_rect().end.y <= game.enemy_bar.global_position.y, "Enemy statuses appear above meter")
	var player = game.character_tabs.get_node("Backpack/Player")
	var statuses: RichTextLabel = game.character_tabs.get_node("Backpack/Statuses")
	check(statuses.get_parsed_text().contains("Poison") and statuses.size.y >= 24, "Player status row reserves room for actual effects")
	check(player.get_global_rect().end.y <= statuses.global_position.y and statuses.get_global_rect().end.y <= game.board.global_position.y, "Player statuses sit between vitals and inventory")
	check(player.get_node("Portrait").size == Vector2(88, 88), "Portrait is slightly smaller")
	check(game.mana_bar.position.y - game.hp_bar.get_rect().end.y == 8, "Resource bars have tighter health spacing")
	check(game.stamina_bar.position.y == game.mana_bar.position.y, "Mana and stamina share a row")
	check(PackKeywords.resolve("armor") == "block" and not PackKeywords.registry().keywords.has("shield"), "One Block combat keyword with legacy armor adapter")
	check(PackKeywordLinks.entry("shield").kind == "meta", "Shield explains equipment rather than a protection effect")
	var data: Dictionary = game.run_saves.capture(game.run, 0)
	var restored := PackRun.new()
	game.run_saves.restore(restored, data)
	check(restored.enemy_block() == 4, "Legacy save fields retain remaining enemy Block")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://tests/output/ui-polish/block-vitals.png")
	game.run.enemy_shield_spent = 6
	game.run.enemy_poison = 0
	game.run.enemy_burn = 0
	game.run.player_poison = 0
	game._refresh()
	check(not game.enemy_bar.protection_pattern and game.enemy_bar.protection_amount == 0, "Spent Block returns to normal health bar")
	check(not enemy_status.visible and statuses.text.is_empty() and statuses.size.y >= 24, "No placeholder statuses; player row stays reserved")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		view.size = dimensions
		view.size_2d_override = Vector2i(1280, 720)
		view.size_2d_override_stretch = true
		await process_frame
		await process_frame
		check(game.board.get_global_rect().end.y <= view.get_visible_rect().size.y, "Inventory fits scaled 16:9 canvas at %s" % dimensions)
	print("BLOCK VITALS RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, view)
	quit(1 if failures else 0)
