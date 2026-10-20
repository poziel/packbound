extends "res://tests/support/battle_ui_support.gd"

func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		printerr("FAIL: Battle UI test timed out")
		quit(2))
	render = DisplayServer.get_name() != "headless"
	game = load("res://scenes/main.tscn").instantiate()
	# A separate viewport makes native rich-text cursor hit-testing deterministic
	# without moving the desktop pointer or intercepting the user's input.
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	test_viewport.add_child(game)
	await process_frame
	await process_frame
	game.start_run("warrior", 42)
	game._open_reward(true)
	_click(game.choice_buttons[0])
	await process_frame
	await process_frame
	var inspector: PackInspector = game.inspector
	var left: Control = game.combat.get_node("BattleArea")
	var right: Control = game.combat.get_node("CharacterPanel")
	check(absf(left.size.x - right.size.x) <= 16, "Battle keeps balanced halves while the character surface meets the outer frame")
	check(left.get_global_rect().end.x <= 640 and right.global_position.x >= 640, "Enemies left, character right")
	check(right.get_global_rect().encloses(game.board.get_global_rect()), "Backpack fits inside character half")
	check(game.action.global_position.y >= 700 and game.action.global_position.x < 640, "Action remains at bottom left")
	check(game.combat.get_node("ActionFrame").get_child_count() == 4, "Attack and its three menus share the action frame")
	check(game.character_tabs.position.y == 0, "Navigation tabs sit at top of character panel")
	check(game.character_tabs.get_tab_count() == 4, "Relics has a fourth tab")
	check(not game.combat.has_node("Status"), "No small status text beneath the action button")
	check(not right.has_node("Relics"), "No separate relic strip below the inventory")
	for index in range(4):
		check(game.character_tabs.get_tab_title(index).is_empty() and game.character_tabs.get_tab_icon(index) != null, "Tab uses an icon without text: %d" % index)
		check(not game.character_tabs.get_tab_tooltip(index).is_empty(), "Icon tab has a hover name: %d" % index)
	_check_character_header(true)
	check(game.hp_bar.size.y >= 24 and game.enemy_bar.size.y >= 24, "Health uses prominent framed bars")
	check(game.hp_label.text == "40 / 40", "Health displays current and maximum")
	check(game.hp_label.get_theme_font("font").get_font_name().contains("Pixel Operator"), "Fine pixel font is active")
	_motion(Vector2(640, 80))
	await _snapshot("reference-pack")
	var bar: TabBar = game.character_tabs.get_tab_bar()
	_click_tab(bar, _tab_index("Statistics"))
	await process_frame
	check(game.values["damage"].is_visible_in_tree() and not game.board.is_visible_in_tree(), "Statistics replaces backpack")
	for stat in game.values:
		check(game.values[stat].text == str(game.run.effects()[GameplayTypes.stat_from_id(StringName(stat)) if GameplayTypes.stat_from_id(StringName(stat)) != GameplayTypes.INVALID_VALUE else stat]), "Live stat: " + stat)
	check(not game.relic_slots[0].is_visible_in_tree(), "Relics are hidden on Statistics")
	_check_character_header(false)
	var stats_search: Control = game.combat.get_node("CharacterPanel/Tabs/Statistics/Search")
	check(game.values["damage"].global_position.y > stats_search.get_global_rect().end.y, "Statistics starts below the search field")
	await _snapshot("reference-stats")
	_click_tab(bar, _tab_index("Logs"))
	await process_frame
	check(game.history_view.is_visible_in_tree(), "Record tab opens battle history")
	check(not game.relic_slots[0].is_visible_in_tree(), "Relics are hidden on Record")
	_check_character_header(false)
	_click_tab(bar, _tab_index("Relics"))
	await process_frame
	check(game.relic_slots[0].is_visible_in_tree() and not game.board.is_visible_in_tree(), "Relics tab shows its bindings instead of the backpack")
	_check_character_header(false)
	var bound_relic: Dictionary = PackCatalog.relic(game.run.relics[0])
	check(game.relic_slots[0].get_node("Art").texture.atlas == PackArt.relic(bound_relic["key"]).atlas, "Relic slot shows its icon")
	check(game.relic_slots[1].get_node("Art").texture == null and game._relic_inspection(1).is_empty(), "Unfilled relic sockets stay empty without placeholder tooltips")
	_motion(game.relic_slots[0].get_global_rect().get_center())
	await create_timer(0.35).timeout
	check(inspector.windows.size() == 1 and inspector.windows[0].key == "relic_" + bound_relic["key"], "Relics still support hover inspection")
	inspector.clear()
	_motion(Vector2(640, 80))
	await _snapshot("reference-relics")
	_click(game.relic_slots[0])
	check(not game.modal.visible, "Clicking a relic does not open a dialog")
	_click_tab(bar, 0)
	await process_frame
	_check_character_header(true)
	bar.grab_focus()
	_key(KEY_RIGHT)
	check(game.character_tabs.current_tab == 1, "Icon tabs retain keyboard navigation")
	_key(KEY_LEFT)
	check(game.character_tabs.current_tab == 0, "Keyboard returns to the character page")
	check(game.action.text.is_empty() and game.action.accessibility_name == "Attack" and game.action.icon != null and game.run.phase == PackRun.Phase.FIGHT, "The first encounter starts ready to attack")
	var prediction: Dictionary = game.run.outcome(game.run.effects())
	_click(game.action)
	await game.playback.monster_resolved
	game.playback.set_paused(true)
	check(game.run.hp == prediction["hp_after"], "First automatic round keeps combat rules")
	_click_tab(bar, _tab_index("Logs"))
	await process_frame
	check(game.history_view.get_parsed_text().contains(game.run.history.back()), "Record includes latest turn")
	await _snapshot("reference-record")
	# Return to preparation for the existing pause-menu and drag inspection coverage.
	game.start_run("warrior", 42)
	_click_tab(bar, 0)
	await process_frame
	var item: Dictionary = game.run.items[0]
	var at: Vector2 = game.board.global_position + game.board.item_rect(item).position + Vector2(24, 24)
	_motion(at)
	await create_timer(0.35).timeout
	check(inspector.windows.size() == 1, "Actual item hover opens an inspect window")
	if inspector.windows.is_empty():
		quit(1)
		return
	check(not inspector.windows[0].locked, "Popup initially remains unlocked")
	check(inspector.windows[0].body.text.contains(PackKeywords.list_markup(PackKeywords.item_stats(item, game.run.item_bonus(item)))), "Tooltip contains the real item keyword list")
	check(is_equal_approx(inspector.lock_delay, 1.0), "Tooltip delay is one second")
	var initial_position: Vector2 = inspector.windows[0].position
	check(inspector.windows[0].timer.visible and inspector.windows[0].timer.progress > 0.0, "Circular countdown is visible before lock")
	check(not inspector.windows[0].has_node("Content/Terms") and not inspector.windows[0].has_node("Content/LockHint"), "No repeated keyword row or helper footer")
	check(not inspector.windows[0].has_node("Content/Header/Close") and not inspector.windows[0].has_node("Content/Progress"), "No close button or bottom progress bar")
	await _snapshot("tooltip-countdown")
	await create_timer(0.5).timeout
	check(not inspector.windows[0].locked, "Tooltip does not lock before its countdown finishes")
	await create_timer(0.55).timeout
	check(inspector.windows[0].locked, "Holding source for one second locks popup")
	check(not inspector.windows[0].timer.visible, "Circular countdown disappears on lock")
	check(inspector.windows[0].position.is_equal_approx(initial_position + Vector2(0, 4)), "Lock moves the tooltip down four pixels")
	await _snapshot("tooltip-locked")
	var first: PackInspectWindow = inspector.windows[0]
	_motion(first.global_position + Vector2(24, 20))
	await create_timer(0.25).timeout
	check(inspector.windows.size() == 1, "Pointer can enter locked window")
	# Hover the actual RichTextLabel URL, not a simulated metadata callback.
	_motion(first.body.global_position + Vector2(12, 12))
	await create_timer(0.35).timeout
	check(inspector.active_keyword_link == "damage", "Damage keyword stat receives real hover")
	check(inspector.windows.size() == 2, "Hovering linked text opens nested explanation")
	await create_timer(1.2).timeout
	check(inspector.windows.size() == 2 and inspector.windows[1].locked, "Nested popup also locks after one second")
	await _snapshot("reference-nested")
	if inspector.windows.size() >= 2:
		_motion(_keyword_link_at(inspector.windows[1], "armor"))
		await create_timer(0.35).timeout
		check(inspector.windows.size() == 3, "A second level of explanation opens")
		await create_timer(1.2).timeout
		check(inspector.windows.size() == 3 and inspector.windows[2].locked, "Second nested level locks")
		for window in inspector.windows:
			check(Rect2(Vector2.ZERO, Vector2(1280, 800)).encloses(window.get_global_rect()), "Nested window stays inside viewport")
		await _snapshot("reference-tooltip-chain")
		if inspector.windows.size() == 3:
			var link_at: Vector2 = _keyword_link_at(inspector.windows[2], "damage")
			_mouse(link_at, true)
			_mouse(link_at, false)
			check(inspector.windows.size() == 2, "Circular terms reuse existing window")
	_key(KEY_ESCAPE)
	check(inspector.windows.is_empty() and not game.modal.visible, "Esc closes tooltips before opening pause")
	_motion(Vector2(640, 90))
	await process_frame
	_key(KEY_ESCAPE)
	check(game.modal_kind == "pause", "Esc without tooltip opens pause")
	game._close_modal()
	await process_frame
	_motion(at)
	await create_timer(0.35).timeout
	_motion(Vector2(640, 90))
	await create_timer(0.2).timeout
	check(inspector.windows.is_empty(), "Leaving before lock dismisses tooltip")
	_motion(at)
	await create_timer(0.35).timeout
	_key(KEY_F1)
	check(not inspector.windows.is_empty() and inspector.windows[0].locked, "F1 locks immediately")
	_motion(Vector2(640, 90))
	_mouse(Vector2(640, 90), true)
	_mouse(Vector2(640, 90), false)
	check(inspector.windows.is_empty(), "Outside click closes chain")
	# Keyboard navigation uses the original inline terms, without duplicate buttons.
	game.block_bar.grab_focus()
	_key(KEY_F1)
	check(inspector.windows.size() == 1 and inspector.windows[0].locked, "F1 inspects a focused stat")
	await process_frame
	await process_frame
	check(inspector.windows[0].body.has_focus(), "Keyboard inspection focuses inline text")
	_key(KEY_ENTER)
	await process_frame
	check(inspector.windows.size() == 2 and inspector.windows[1].locked, "Keyboard can open nested definitions")
	_key(KEY_ESCAPE)
	_motion(at)
	await create_timer(0.35).timeout
	game.front.settings["tooltips"] = false
	game._settings_changed()
	await process_frame
	check(inspector.windows.is_empty(), "Tooltip preference closes current window")
	await create_timer(0.3).timeout
	check(inspector.windows.is_empty(), "Disabled tooltips stay suppressed")
	game.front.settings["tooltips"] = true
	game._settings_changed()
	await process_frame
	_motion(at)
	await create_timer(0.35).timeout
	game.board.begin_drag(item, at - game.board.global_position)
	await process_frame
	await process_frame
	check(inspector.windows.is_empty(), "Dragging suppresses inspection")
	game.character_tabs.current_tab = _tab_index("Statistics")
	check(game.board.dragging.is_empty(), "Changing tab cancels held item")
	game.character_tabs.current_tab = 0
	await process_frame
	item["cell"] = null
	game.board.refresh()
	_click(game.storage_button)
	await process_frame
	at = game.board.global_position + game.board.item_rect(item).get_center()
	_motion(at)
	await create_timer(0.35).timeout
	check(inspector.windows.size() == 1 and inspector.windows[0].body.get_parsed_text().contains("Unpacked"), "Unpacked items support inspection")
	inspector.clear()
	game._close_storage()
	# Hovered children do not lock themselves after the pointer leaves their term.
	_motion(game.block_bar.get_global_rect().get_center())
	await create_timer(0.35).timeout
	_key(KEY_F1)
	await process_frame
	await process_frame
	var block_window: PackInspectWindow = inspector.windows[0]
	_motion(_keyword_link_at(block_window, "slow"))
	await create_timer(0.35).timeout
	check(inspector.windows.size() == 2 and not inspector.windows[1].locked, "Nested hover initially remains unlocked")
	_motion(block_window.global_position + Vector2(20, 20))
	await create_timer(0.25).timeout
	check(inspector.windows.size() == 1, "Leaving a nested term before lock dismisses its child")
	# Cross the gap between the source and window without losing the locked chain.
	_motion(Vector2(640, 90))
	await create_timer(0.15).timeout
	_motion(block_window.global_position + Vector2(20, 20))
	await create_timer(0.2).timeout
	check(inspector.windows.size() == 1, "Grace interval permits crossing a gap")
	_motion(Vector2(640, 90))
	await create_timer(0.5).timeout
	check(inspector.windows.is_empty(), "Leaving the complete chain dismisses it")
	_motion(game.action.get_global_rect().get_center())
	await create_timer(0.35).timeout
	check(inspector.windows.is_empty(), "Attack has no hover explanation")
	inspector.clear()
	_motion(Vector2(640, 90))
	# All definition links resolve, and every catalog explanation fits its window.
	for key: String in PackKeywordLinks.ALIASES:
		check(PackKeywordLinks.ENTRIES.has(PackKeywordLinks.ALIASES[key]), "Linked term resolves: " + key)
	for key: String in PackKeywordLinks.ENTRIES:
		var entry: Dictionary = PackKeywordLinks.entry(key)
		check(not entry["body"].is_empty(), "Glossary entry: " + key)
	for key: String in PackCatalog.ROSTER:
		var data: Dictionary = PackCatalog.item(key)
		var window: PackInspectWindow = PackInspector.WINDOW.instantiate()
		root.add_child(window)
		window.setup({"key": "item", "title": data["name"], "body": data["detail"]})
		await process_frame
		await process_frame
		check(window.size.x <= 420 and window.size.y < 600, "Item inspection fits: " + key)
		window.free()
	# Full relic grids, including a consumed effect, must fit without overlapping.
	game.character_tabs.current_tab = _tab_index("Relics")
	for relic_key: String in PackCatalog.RELICS:
		game.run.relics.assign([relic_key, relic_key, relic_key, relic_key])
		game.run.last_thread_used = true
		game._refresh()
		await process_frame
		await process_frame
		for index in range(4):
			check(right.get_global_rect().encloses(game.relic_slots[index].get_global_rect()), "Relic slot fits its page: " + relic_key)
			if index < 3:
				check(game.relic_slots[index].get_global_rect().end.x <= game.relic_slots[index + 1].global_position.x, "Relic slots do not overlap: " + relic_key)
	for character in PackCatalog.classes():
		game.start_run(character, 42)
		game._open_reward(true)
		game._choose(0)
		await process_frame
		check(game._character_inspection()["title"].begins_with(PackCatalog.classes()[character]["name"]), "Selected class appears in portrait inspection: " + character)
		check(game.character_tabs.current_tab == 0, "New run opens Backpack")
	var original_enemy: Dictionary = game.run.enemy
	for enemy in PackCatalog.enemies():
		game.run.enemy = enemy.duplicate(true)
		game.run.enemy["max_hp"] = enemy["hp"]
		check(game._enemy_inspection()["title"] == enemy["name"], "Enemy tooltip keeps the name: " + enemy["name"])
	game.run.enemy = original_enemy
	game._refresh()
	var roster: HBoxContainer = game.combat.get_node("BattleArea/EnemyScroll/EnemyRoster")
	var second_enemy: Control = load("res://scenes/run/enemy_card/enemy_card.tscn").instantiate()
	roster.add_child(second_enemy)
	await process_frame
	await process_frame
	check(left.get_global_rect().encloses(second_enemy.get_global_rect()), "Second visual enemy fits battle area")
	second_enemy.queue_free()
	await process_frame
	game.reparent(root)
	test_viewport.queue_free()
	await process_frame
	await _resolution_checks()
	report("BATTLE UI RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)

