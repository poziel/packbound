extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")

func _run() -> void:
	var presenter: RefCounted = load("res://systems/ui/keywords/combat_keywords.gd").new()
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
	var window: Control = load("res://scenes/shared/inspect_window/inspect_window.tscn").instantiate()
	root.add_child(window)
	window.setup({"key": "test_fang", "title": "Fang", "body": "Damage restores health.", "keyword_stats": stats})
	check(window.body.get_parsed_text().find("4") < window.body.get_parsed_text().find("Damage restores"), "Keyword stats precede description")
	check(window._link_keys.values().has("health"), "Description retains keyword links")
	var idle_text: String = window.body.text
	window._on_keyword_link_entered("vampirism")
	check(window._hover_effect.hovered == "vampirism" and window._rich_text.contains("underline=never"), "Stat hover activates tint without adding an underline")
	window._on_keyword_link_exited("vampirism")
	await process_frame
	check(window.body.text == idle_text, "Leaving a stat restores its normal appearance")
	window._on_keyword_link_entered("health")
	check(window._hover_effect.hovered == "health" and window._link_keys.values().has("health"), "Keyword hover keeps its definition link")
	window._on_keyword_link_exited("health")
	await process_frame
	window.set_locked(true)
	await process_frame
	check(window.body.focus_mode == Control.FOCUS_NONE, "Keyword stats never take keyboard focus")
	window.setup({"key": "test_plain", "title": "Plain", "body": "Nothing."})
	check(window.body.get_parsed_text() == "Nothing.", "Reusing tooltip clears previous stats")
	window.queue_free()
	await process_frame
	var inspector: PackInspector = load("res://scenes/shared/inspect_manager/inspect_manager.tscn").instantiate()
	root.add_child(inspector)
	inspector._spawn({"key": "root", "title": "Fang", "body": "Damage", "keyword_stats": stats}, Rect2(20, 20, 20, 20), -1)
	inspector.windows[0].set_locked(true)
	inspector._open_keyword_link("damage", 0, true)
	check(inspector.windows.size() == 2 and inspector.windows[1].key == "damage", "Keyword stat opens a nested definition")
	inspector.windows[1].set_locked(true)
	inspector._open_keyword_link("block", 1, true)
	check(inspector.windows.size() == 3, "Keyword links in definitions keep nesting")
	inspector.windows[2].set_locked(true)
	inspector._open_keyword_link("damage", 2, true)
	check(inspector.windows.size() == 4 and inspector.windows[3].key == "damage", "Repeated keyword opens a new descendant without collapsing ancestors")
	inspector.queue_free()
	await process_frame
	report("KEYWORD STATS RESULT")
	quit(1 if failures else 0)
