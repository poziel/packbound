extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")

func _run() -> void:
	for element: String in ["fire", "frost", "lightning", "void", "venom"]:
		check(PackKeywords.has_icon(element), element + " has a shared icon")
	check(PackKeywords.icon_path("fire") == PackKeywords.icon_path("burn"), "Contract: PackKeywords.icon_path(\"fire\") == PackKeywords.icon_path(\"burn\")")
	check(PackKeywords.icon_path("frost") == PackKeywords.icon_path("slow"), "Contract: PackKeywords.icon_path(\"frost\") == PackKeywords.icon_path(\"slow\")")
	var window = load("res://scenes/shared/inspect_window/inspect_window.tscn").instantiate()
	root.add_child(window)
	window.setup({"key": "test_ember", "title": "Ember Grimoire", "recipe_item": "ember_tome"})
	check(window.element_icon.visible and window.item_element == "fire", "Contract: window.element_icon.visible and window.item_element == \"fire\"")
	check(window.element_icon.get_index() < window.get_node("Content/Header/Title").get_index(), "Contract: window.element_icon.get_index() < window.get_node(\"Content/Header/Title\").get_index()")
	window.setup({"key": "test_plain", "title": "Plain weapon"})
	check(not window.element_icon.visible, "Contract: not window.element_icon.visible")
	window.free()
	var game = load("res://scenes/main.gd").new()
	game.run.reset(123, "mage")
	game.run.elemental_traces = {GameplayTypes.Element.FIRE: [2, 1], GameplayTypes.Element.FROST: [1]}
	var traces: Dictionary = game._enemy_trace_inspection()
	check(not traces.is_empty(), "Contract: not traces.is_empty()")
	check(traces.body.contains("Fire ×2") and traces.body.contains("Frost ×1"), "Contract: traces.body.contains(\"Fire \u00d72\") and traces.body.contains(\"Frost \u00d71\")")
	check(traces.body.contains("2 rounds, 1 round"), "Contract: traces.body.contains(\"2 rounds, 1 round\")")
	game.run.class_key = "warrior"
	check(game._enemy_trace_inspection().is_empty(), "Contract: game._enemy_trace_inspection().is_empty()")
	game.run.class_key = "mage"
	game.run.elemental_traces.clear()
	check(game._enemy_trace_inspection().is_empty(), "Contract: game._enemy_trace_inspection().is_empty()")
	game.free()
	var live = load("res://scenes/main.tscn").instantiate()
	root.add_child(live)
	await process_frame
	live.run.reset(123, "mage")
	live.run.elemental_traces = {GameplayTypes.Element.FIRE: [2]}
	live._update_status_rows()
	await process_frame
	check(live.enemy_trace_indicator.visible, "Contract: live.enemy_trace_indicator.visible")
	check(live.enemy_trace_indicator.global_position.x >= live.enemy_bar.global_position.x + live.enemy_bar.size.x, "Contract: live.enemy_trace_indicator.global_position.x >= live.enemy_bar.global_position.x + live.enemy_bar.size.x")
	live.combat.show()
	live.enemy_vitals.show()
	var candidate: Dictionary = live.inspector._candidate(live.enemy_trace_indicator)
	check(candidate.data.key == "enemy_elemental_traces", "Contract: candidate.data.key == \"enemy_elemental_traces\"")
	check(not live.enemy_vitals.get_node("Statuses/Content").text.contains("Fire"), "Contract: not live.enemy_vitals.get_node(\"Statuses/Content\").text.contains(\"Fire\")")
	live.run.class_key = "warrior"
	live._update_status_rows()
	check(not live.enemy_trace_indicator.visible, "Contract: not live.enemy_trace_indicator.visible")
	live.free()
	report("element_presentation")
	quit()
