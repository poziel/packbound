extends "res://tests/prototype_test.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run.reset(42, "ranger")
	game.run.choose_loot("arrow_venom")
	game.run.quiver()["upgrades"]["quiver_explosive"] = 1
	game.run.add_item("spark_ring", Vector2i(5, 0))
	game.run.add_item("tower_shield", Vector2i(6, 0))
	game.run.player_poison = 9
	game._refresh()
	var data: Dictionary = game._character_inspection()
	check(data.get("keyword_stats", []).size() >= 3, "Delver tooltip shows innate keyword stats")
	var innate: Dictionary = {}
	for stat: Dictionary in data.get("keyword_stats", []):
		innate[stat["key"]] = stat["value"]
	check(innate == {"health": 32, "mana": 1, "stamina": 3}, "Archer innate values exclude equipment and zero debuffs")
	check(not data["body"].contains("Poison") and not data["body"].contains("Block 13"), "Delver description excludes current debuffs and equipment totals")
	var badge: Label = game.character_portrait.get_node_or_null("VolleyCountdown")
	check(badge != null and badge.visible and badge.text == "3", "Archer portrait corner displays countdown")
	check(not game.character_tabs.get_node("Backpack/Statuses").text.contains("Volley"), "Volley text is removed from below portrait")
	var bonuses: Array = game._describe_item(game.run.items[0], Rect2())["bonuses"]
	check(not bonuses[0].get("tooltip", true), "Simple source bonus has no redundant outer tooltip")
	game.inspector.set_process(false)
	game.inspector._spawn(game._describe_item(game.run.quiver(), Rect2()), Rect2(800, 200, 40, 40), -1)
	await process_frame
	var window: PackInspectWindow = game.inspector.windows[0]
	check(window.body.text.contains("[u]") and window.body.text.contains("Venom") and window.body.text.contains("Arrows") and window.body.text.contains("[u]Explosive Mechanism[/u]"), "Named bonuses with definitions are underlined")
	game.inspector.clear()
	game.inspector._spawn(game._describe_item(game.run.items[0], Rect2()), Rect2(800, 200, 40, 40), -1)
	await process_frame
	window = game.inspector.windows[0]
	check(window.bonus_definitions.has("catalog_item_magnificent_quiver"), "Source item name links to catalog definition")
	var natural: Dictionary = window.bonus_definitions.get("catalog_item_magnificent_quiver", {})
	check(natural.get("bonuses", []).is_empty() and natural["keyword_stats"][0]["value"] == 6, "Source definition shows base quiver without selected arrows or upgrades")
	check(not window.bonus_definitions.has(bonuses[0]["key"]), "Simple bonus is not registered as a separate definition")
	window.set_locked(true)
	game.inspector._open_keyword_link("catalog_item_magnificent_quiver", 0, true)
	check(game.inspector.windows.size() == 2 and game.inspector.windows[1].key == "catalog_item_magnificent_quiver", "Only source item name opens the natural item tooltip")
	game.run.volley_remaining = 1
	game._refresh()
	check(badge.text == "1", "Portrait countdown follows combat state")
	game.run.reset(42, "mage")
	game._refresh()
	check(not badge.visible, "Countdown stays hidden for other Delvers")
	check(PackCatalog.innate_stats("mage")[1]["value"] == 6 and game.run.starting_resources()["stamina"] == 0, "Elementalist has six innate mana and zero stamina")
	if DisplayServer.get_name() != "headless":
		await _review()
	game.queue_free()
	await process_frame
	print("DELVER PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _review() -> void:
	game.run.reset(42, "ranger")
	game.run.choose_loot("arrow_venom")
	game.run.quiver()["upgrades"]["quiver_explosive"] = 1
	game.front.hide()
	game.combat.show()
	game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.board.get_parent())
	game.character_portrait.texture = PackArt.character_head("ranger")
	game._refresh()
	game.inspector.clear()
	game.inspector._spawn(game._describe_item(game.run.items[0], Rect2()), Rect2(1000, 250, 40, 40), -1)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Dev/2-games/packbound/workspace/logs/bonus-keyword-links.png")
	game.inspector.clear()
	game.inspector._spawn(game._character_inspection(), Rect2(1100, 130, 40, 40), -1)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Dev/2-games/packbound/workspace/logs/delver-innate-stats.png")
