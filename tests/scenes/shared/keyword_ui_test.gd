extends "res://tests/support/test_case.gd"

var game: Control
const OUTPUT: String = "res://workspace/docs/art/reviews/semantic-icons-v2"

func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func snapshot(name_text: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + name_text + ".png")

func _run() -> void:
	create_timer(40.0).timeout.connect(func() -> void: quit(2))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.start_run("mage", 42)
	game._close_modal()
	await settle()
	check(game.hp_bar.badge_icon == PackKeywords.icon("health", true), "Player health uses the baseline-aligned heart")
	check(game.enemy_bar.badge_icon == PackKeywords.icon("health", true), "Enemy health uses the same heart")
	check(game.hp_label.text == "%d / %d" % [game.run.hp, game.run.max_hp], "Badge icon preserves numeric health text")
	for key: String in ["mana", "block"]:
		var caption: RichTextLabel = game.board.get_parent().get_node("Player/%sCaption" % key.to_pascal_case())
		check(caption.text.contains("[img "), "HUD caption has icon: " + key)
		check(caption.get_content_width() <= caption.size.x, "HUD caption fits: " + key)
		var meter: PixelStatBar = game.mana_bar if key == "mana" else game.block_bar
		check(not caption.get_global_rect().intersects(meter.value_label.get_global_rect()), "HUD caption does not overlap its amount: " + key)
	await snapshot("backpack")
	game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.combat.get_node("CharacterPanel/Tabs/Statistics"))
	await settle()
	for key: String in game.values:
		var label: RichTextLabel = game.values[key].get_parent().get_node(key.to_pascal_case() + "Label")
		check(label.text.contains("[img ") == PackKeywords.has_icon(key), "Statistic displays correct icon availability: " + key)
		check(game.values[key].get_theme_color("font_color") == PackKeywords.color(key), "Statistic amount matches keyword color: " + key)
		check(not label.text.contains("[url="), "Statistic has no inert link: " + key)
	check(game.values.has("slow"), "Slow is available in statistics and search")
	await snapshot("statistics")
	game.run.log_line("Gain 3 mana, 2 block and 4 healing. Poison and burn deal damage; ward absorbs curse and thorns retaliate.")
	game._refresh_history()
	check(game.history_view.text.count("[img ") >= 8 and not game.history_view.text.contains("[url="), "Combat logs include icons without inert links")
	var inspect: PackInspectWindow = load("res://scenes/shared/inspect_window/inspect_window.tscn").instantiate()
	root.add_child(inspect)
	for key: String in PackKeywords.registry()["keywords"]:
		if not PackKeywordLinks.ENTRIES.has(key):
			continue
		inspect.setup(PackKeywordLinks.entry(key))
		await settle()
		check(inspect.get_node("Content/Header/Title").text.contains("[img "), "Glossary heading decorates " + key)
		check(not inspect.body.text.contains("[url=" + key + "]"), "Self definition avoids cyclic link: " + key)
		check(inspect.size.y < 600, "Definition fits viewport: " + key)
	inspect.setup({"key":"mixed", "title":"Effects", "body":"Health, mana, block, plating, slow, healing, vampirism, ward, poison, burn, curse and thorns. Gain 3 mana and 5 block."})
	inspect.position = Vector2(650,100)
	await snapshot("mixed-inspection")
	var plain_before: String = inspect.body.get_parsed_text()
	inspect.set_locked(true)
	inspect.focus_body()
	await settle()
	check(inspect.body.has_focus(), "Keyboard inspection retains native rich-text focus")
	check(inspect.body.get_parsed_text() == plain_before and inspect.body.text.count("[img ") == 14, "Keyboard highlighting preserves every icon and word")
	var pressed: Array[String] = []
	inspect.keyword_link_pressed.connect(func(key: String) -> void: pressed.append(key))
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	inspect._input(enter)
	check(pressed == ["health"], "Keyboard activates the selected keyword link")
	inspect.free()
	# Verify rich text also reaches passive item and roster tooltip consumers.
	var tip: Control = load("res://scenes/shared/item_tooltip/item_tooltip.tscn").instantiate()
	root.add_child(tip)
	for key: String in PackCatalog.ROSTER:
		game._close_modal()
		game.run.phase = PackRun.Phase.FIGHT
		game.run.offers.assign([key, key, key])
		game.run.item_rewards.assign([{ "floor": 1, "offers": [key, key, key]}])
		game._open_reward(false)
		await settle()
		for index in range(3):
			check(game.choice_details[index].get_content_height() <= game.choice_details[index].size.y, "Reward copy fits: %s/%d" % [key,index])
			check(not game.choice_details[index].text.contains("[url="), "Reward copy has no inert links: %s/%d" % [key,index])
		var item: Dictionary = game.run.add_item(key)
		tip.set_item(item)
		await settle()
		if key == "ember_tome":
			tip.position = Vector2(30,30)
			await snapshot("ember-tooltip")
		check(tip.get_node("Description").text == PackKeywordLinks.rich(PackKeywords.item_description(item), "", false), "Item-specific rules retain formatted copy: " + key)
		check(tip.size.y < 500 and tip.size.x < 400, "Item tooltip fits: %s %s" % [key, tip.size])
	tip.free()
	game._close_modal()
	game.show_menu()
	game.front.show_classes()
	await settle()
	var selection: Control = game.front.get_node("ClassSelection")
	selection.set_process(false)
	selection.inspector.set_process(false)
	for key: String in PackCatalog.classes():
		selection.inspector.clear()
		selection.inspector._spawn(selection._character_inspection(key), selection.buttons[key].get_global_rect(), -1)
		await settle()
		var body: RichTextLabel = selection.inspector.windows[0].body
		check(body.text.count("[img ") >= 2, "Roster health/mana icons: " + key)
		check(body.get_content_height() <= body.size.y, "Roster ability copy is visible: " + key)
	selection.inspector.clear()
	selection.inspector._spawn(selection._character_inspection("mage"), selection.buttons["mage"].get_global_rect(), -1)
	await settle()
	await snapshot("delver-tooltip")
	game.free()
	await settle()
	report("KEYWORD UI RESULT")
	quit(1 if failures else 0)
