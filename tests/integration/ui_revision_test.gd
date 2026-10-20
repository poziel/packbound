extends "res://tests/support/test_case.gd"

var viewport: SubViewport
var game: Control

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	var required: Array[String] = ["Combat/ActionFrame/Action", "Combat/BattleArea/Vitals/EnemyShieldBar", "Combat/CharacterPanel/Tabs/Statistics/Search"]
	for path in required:
		check(game.has_node(path), "Saved UI exists: " + path)
	if failures:
		_finish()
		return
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	await process_frame
	await process_frame
	for entry in game.inspector.sources:
		check(is_instance_valid(entry["target"]), "Tooltip registration has a live target")
	check(not game.combat.has_node("Forecast") and not game.combat.has_node("PhaseLabel"), "Removed labels stay removed")
	var enemy_info: Dictionary = game._enemy_inspection()
	check(enemy_info["title"] == game.run.enemy["name"] and enemy_info["body"].contains("incoming"), "Enemy tooltip reads combat data without deleted labels")
	_motion(game.storage_button.get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(game.inspector.windows.is_empty() and not game.storage_button.tooltip_text.is_empty(), "Storage hover uses a simple native tooltip")
	_motion(Vector2(640, 90))
	game.inspector.clear()
	var shield: PixelStatBar = game.get_node(required[1])
	check(not shield.visible, "Zero-armor enemy hides shield")
	var health_without_shield: float = game.enemy_bar.global_position.y
	game.run.enemy["armor"] = 3
	game._refresh()
	await process_frame
	await process_frame
	check(shield.visible and shield.value == 3, "Armored enemy shows its current shield amount")
	check(shield.get_global_rect().end.y <= game.enemy_bar.global_position.y, "Enemy shield sits above health")
	check(game.enemy_bar.global_position.y > health_without_shield, "Health closes the gap when shield is absent")
	check(game.run.outcome(game.board.preview_effects())["dealt"] == maxi(0, game.board.preview_effects()[GameplayTypes.Stat.DAMAGE] - 3), "Combined outcome accounts for enemy armor")
	await _snapshot("ui-revision-shield")
	game.run.enemy["armor"] = 0
	game._refresh()
	await process_frame
	check(not shield.visible, "Shield hides again when protection ends")
	check(PackRun.GRID == Vector2i(8, 7), "Backpack has 56 usable slots")
	var item: Dictionary = game.run.add_item("antidote")
	game.board.begin_drag(item, Vector2.ZERO)
	game.board.drop_at(BackpackBoard.ORIGIN + Vector2(PackRun.GRID - Vector2i.ONE) * BackpackBoard.STEP + game.board.grab)
	check(item["cell"] == PackRun.GRID - Vector2i.ONE, "Drag/drop reaches the new bottom-right slot")
	check(not game.run.can_place(item, PackRun.GRID), "Placement still rejects cells beyond the expanded grid")
	check(game.combat.get_node("CharacterPanel").get_global_rect().encloses(game.board.get_global_rect()), "Expanded inventory fits its panel")
	check(not game.combat.get_node("ActionFrame").has_node("DamagePreview") and not game.has_method("_forecast_inspection"), "Changing inventory does not restore the removed forecast")
	for state in ["tab_unselected", "tab_hovered"]:
		var style: StyleBox = game.character_tabs.get_theme_stylebox(state)
		check(style.get_content_margin(SIDE_BOTTOM) == 12, "Inactive and hovered tabs retain the authored vertical padding")
	var header: Control = game.combat.get_node("CharacterPanel/Header")
	check(header.get_global_rect().encloses(game.timer_label.get_global_rect()) and header.get_global_rect().encloses(game.encounter_label.get_global_rect()), "Gray header continues behind the run counters")
	await _snapshot("ui-revision-backpack")
	game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.character_tabs.get_node("Statistics"))
	await process_frame
	var search: PixelSearchField = game.get_node(required[2])
	var rows: VBoxContainer = game.get_node("Combat/CharacterPanel/Tabs/Statistics/Scroll/Rows")
	check(search.get_global_rect().end.y < rows.global_position.y, "Search is above the statistics list")
	search.set_query("PoIs")
	await process_frame
	var visible_count: int = 0
	for row: Control in rows.get_children():
		visible_count += int(row.visible)
	check(visible_count == 1 and rows.get_node("Poison").visible, "Statistics search filters whole rows with partial case-insensitive text")
	check(not game.values["damage"].is_visible_in_tree(), "Filtering hides each stat's label and value together")
	search.set_query("no matching stat")
	await process_frame
	check(game.get_node("Combat/CharacterPanel/Tabs/Statistics/EmptyState").visible, "No matches provides an empty state")
	search.set_query("")
	await process_frame
	check(game.values["damage"].is_visible_in_tree(), "Clearing search restores statistics")
	for stat in game.values:
		check(game.values[stat].text == str(game.run.effects()[GameplayTypes.stat_from_id(StringName(stat)) if GameplayTypes.stat_from_id(StringName(stat)) != GameplayTypes.INVALID_VALUE else stat]), "Filtered stats retain their current values: " + stat)
	await _snapshot("ui-revision-stats")
	search.set_query("block")
	await process_frame
	await _snapshot("ui-revision-stats-filtered")
	_finish()

func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	viewport.push_input(event, true)

func _snapshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("%s.png") % filename)

func _finish() -> void:
	report("UI REVISION RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, viewport)
	quit(1 if failures else 0)
