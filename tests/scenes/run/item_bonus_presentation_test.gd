extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run.reset(42, "ranger")
	game.run.choose_loot("arrow_broadhead")
	var quiver: Dictionary = game.run.quiver()
	quiver["upgrades"]["quiver_explosive"] = 1
	var data: Dictionary = game._describe_item(quiver, Rect2())
	check(data["title"] == "Bowmaster's Quiver", "Quiver has concise display name")
	check(data["body"] == "Touching bows gain +2 damage", "Quiver body contains only inventory behavior")
	check(not data.get("keyword_stats", []).is_empty(), "Volley totals use compact keyword stats")
	check(data.get("bonuses", []).size() == 2, "Arrow selection and upgrades are named bonuses")
	game.inspector.set_process(false)
	game.inspector._spawn(data, Rect2(800, 200, 40, 40), -1)
	await process_frame
	await process_frame
	var window: PackInspectWindow = game.inspector.windows[0]
	check(not window.get_node("Content/Header/Icon").visible, "Item tooltip omits item artwork")
	var bound_icon: Control = window.get_node_or_null("Content/Header/BoundStatus")
	check(bound_icon != null and bound_icon.visible, "Bound equipment has a status icon before its title")
	check(window.body.text.contains("Bonuses\n") and window.bonus_definitions.size() == 2, "Bonuses appear in a dedicated bottom section")
	check(window.body.text.contains("• "), "Bonus entries have a small bullet")
	window.set_locked(true)
	game.inspector._open_keyword_link("backpack_locked", 0, true)
	check(game.inspector.windows.size() == 2 and game.inspector.windows[1].key == "backpack_locked", "Title status icon opens binding explanation")
	game.inspector._open_keyword_link("quiver_bonus_quiver_explosive", 0, true)
	await process_frame
	check(game.inspector.windows.size() == 2 and game.inspector.windows[1].body.text.contains("burn"), "Named explosive bonus opens its own definition")
	game.inspector.clear()
	var bow: Dictionary = game.run.items[0]
	data = game._describe_item(bow, Rect2())
	check(data.get("bonuses", []).size() == 1 and data["bonuses"][0]["label"] == "+2 damage from Bowmaster's Quiver", "Adjacent item gets source bonus without trailing punctuation")
	game.inspector._spawn(data, Rect2(800, 200, 40, 40), -1)
	await process_frame
	window = game.inspector.windows[0]
	check(window.body.text.find("Bonuses") < window.body.text.find("[table=2]"), "Resource costs and priority follow all bonuses")
	check(not window.get_node("Content/Header/Icon").visible, "Ordinary item tooltip also omits artwork")
	check(PackKeywordLinks.entry("backpack_locked")["title"] == "Bound equipment", "Backpack binding uses terminology distinct from crafting locks")
	game.inspector.clear()
	var knife: Dictionary = game.run.add_item("rusty_knife", Vector2i(6, 0))
	data = game._describe_item(knife, Rect2())
	check(not data["body"].contains("merge") and not data["body"].contains("→"), "Ordinary item description excludes recipe hints")
	check(data.get("bonuses", []).is_empty(), "Items without bonuses have no bonus section")
	game.run.relics.assign(["last_thread"])
	game.run.hp = 1
	game.run.enemy["hp"] = 1000
	game.run.enemy["attacks"] = [100]
	game.run.end_turn()
	check(quiver["name"] == "Bowmaster's Quiver" and quiver["cell"] != null, "Presentation changes preserve permanent equipment behavior")
	if DisplayServer.get_name() != "headless":
		await _render_review()
	game.queue_free()
	await process_frame
	report("ITEM PRESENTATION RESULT")
	quit(1 if failures else 0)

func _render_review() -> void:
	game.front.hide()
	game.combat.show()
	game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.board.get_parent())
	game.character_portrait.texture = PackArt.character_head("ranger")
	game._refresh()
	var data: Dictionary = game._describe_item(game.run.quiver(), Rect2(1050, 250, 40, 40))
	game.inspector._spawn(data, data["rect"], -1)
	await process_frame
	await process_frame
	game.inspector.windows[0].set_locked(true)
	game.inspector._open_keyword_link("quiver_bonus_quiver_explosive", 0, true)
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_logs/quiver-tooltip-bonuses.png"))
