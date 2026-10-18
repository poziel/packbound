extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var presenter: RefCounted = load("res://scripts/combat_keywords.gd").new()
	check(presenter.has_method("item_stats"), "Structured item keyword stats are available")
	if failures > 0:
		quit(1)
		return
	var fang: Dictionary = PackCatalog.item("vampire_fang")
	var stats: Array = presenter.call("item_stats", fang, 0)
	check(stats.size() == 2, "Fang exposes damage and vampirism only")
	check(stats[0]["value"] == 5 and stats[1]["value"] == 2, "Values come from item data")
	var boosted: Array = presenter.call("item_stats", fang, 3)
	check(boosted[0]["value"] == 8, "Adjacency changes displayed damage")
	check(fang["damage"] == 5, "Presentation never mutates base stats")
	var spell: Array = presenter.call("item_stats", PackCatalog.item("ember_tome"), 0)
	var costs: Array[Dictionary] = PackKeywords.item_resource_costs(PackCatalog.item("ember_tome"))
	check(costs.back()["key"] == "mana" and costs.back()["value"] == 3 and spell.back()["key"] != "mana", "Mana cost is separate from the keyword list and maximum mana bonuses")
	var markup: String = presenter.call("stats_markup", stats)
	check(markup.contains("href=damage underline=never") and markup.contains("href=vampirism underline=never"), "Keyword stats keep definition links without underlines")
	check(not markup.contains("[color=") and not markup.contains(PackKeywords.color("vampirism").to_html(false)), "Stats omit keyword colors")
	check(markup.count("[img ") == 2 and not markup.contains("Vampirism"), "Stat row uses icons and values")
	check(presenter.call("stats_markup", []) == "", "Empty stats omit the row")
	check(presenter.call("item_stats", PackCatalog.item("blood_gem"), 0).is_empty(), "Conditional boosters do not claim unconditional damage")
	var relic_stats: Array = presenter.call("relic_stats", PackCatalog.relic("last_thread"))
	check(relic_stats.size() == 1 and relic_stats[0]["value"] == 8 and relic_stats[0]["qualifier"] == "once, on lethal damage", "Relic value retains its activation condition")
	var window: Control = load("res://scenes/shared/inspect_window.tscn").instantiate()
	root.add_child(window)
	window.setup({"key": "test_fang", "title": "Fang", "body": "Damage restores health.", "keyword_stats": stats})
	check(window.body.text.begins_with(markup + "\n\n"), "Keyword stats precede description")
	check(window.body.text.contains("[url=health]"), "Description retains keyword links")
	var idle_text: String = window.body.text
	window._on_keyword_link_entered("vampirism")
	check(window.body.text != idle_text and window.body.text.contains("underline=never"), "Stat hover darkens without adding an underline")
	window._on_keyword_link_exited("vampirism")
	await process_frame
	check(window.body.text == idle_text, "Leaving a stat restores its normal appearance")
	window._on_keyword_link_entered("health")
	check(window.body.text != idle_text and window.body.text.contains("[url=health]"), "Keyword link hover darkens while retaining its definition link")
	window._on_keyword_link_exited("health")
	await process_frame
	window.set_locked(true)
	window.focus_body()
	await process_frame
	var pressed: Array[String] = []
	window.keyword_link_pressed.connect(func(key: String) -> void: pressed.append(key))
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	window._input(enter)
	check(pressed == ["damage"], "Keyboard activates the first keyword stat definition")
	window.setup({"key": "test_plain", "title": "Plain", "body": "Nothing."})
	check(window.body.text == "Nothing.", "Reusing tooltip clears previous stats")
	window.queue_free()
	await process_frame
	var inspector: PackInspector = load("res://scenes/shared/inspect_manager.tscn").instantiate()
	root.add_child(inspector)
	inspector._spawn({"key": "root", "title": "Fang", "body": "Damage", "keyword_stats": stats}, Rect2(20, 20, 20, 20), -1)
	inspector.windows[0].set_locked(true)
	inspector._open_keyword_link("damage", 0, true)
	check(inspector.windows.size() == 2 and inspector.windows[1].key == "damage", "Keyword stat opens a nested definition")
	inspector._open_keyword_link("armor", 1, true)
	check(inspector.windows.size() == 3, "Keyword links in definitions keep nesting")
	inspector._open_keyword_link("damage", 2, true)
	check(inspector.windows.size() == 2, "Circular keyword links reuse the existing definition")
	inspector.queue_free()
	await process_frame
	print("KEYWORD STATS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
