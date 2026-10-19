extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")

func _run() -> void:
	var presenter: RefCounted = load("res://systems/ui/keywords/combat_keywords.gd").new()
	check(presenter.has_method("list_markup"), "Keyword lists have their own presentation")
	if failures:
		quit(1)
		return
	var knife: Dictionary = PackCatalog.item("rusty_knife")
	check(knife["tooltip_detail"] == "", "Simple damage item omits its redundant sentence")
	var text: String = presenter.call("list_markup", PackKeywords.item_stats(knife))
	check(text.find("4") < text.find("[img ") and text.find("[/img]") < text.find("Damage"), "List order is value, icon, keyword")
	check(text.count("[img ") == 1 and text.contains("[color=#" + PackKeywords.color("damage").to_html(false)), "Keyword name and icon use their keyword color")
	check(text.find("+4") < text.find("[color="), "Positive damage has a plus sign outside the keyword color")
	var drawback: String = presenter.call("list_markup", [{"key": "health", "value": -3}])
	check(drawback.contains("-3") and not drawback.contains("+-3"), "Negative attributes keep one minus sign")
	var drawback_item: Dictionary = knife.duplicate(true)
	drawback_item["damage"] = -3
	check(PackKeywords.item_stats(drawback_item)[0]["value"] == -3, "Item data preserves negative attributes for list presentation")
	var cost: String = presenter.call("list_markup", [{"key": "mana", "value": 3, "qualifier": "cost"}])
	check(cost.contains("-3") and not cost.contains("+3"), "Costs keep their negative sign")
	var shield: String = presenter.call("list_markup", PackKeywords.item_stats(PackCatalog.item("cracked_shield")))
	check(shield.contains("+5") and shield.contains("Block"), "Block list entry has a positive sign")
	var fang: String = presenter.call("list_markup", PackKeywords.item_stats(PackCatalog.item("vampire_fang")))
	check(fang.contains("\n") and fang.contains("Damage") and fang.contains("Vampirism"), "Each item attribute gets its own line")
	check(PackCatalog.item("iron_charm")["tooltip_detail"] == PackCatalog.item("iron_charm")["detail"], "Adjacency booster retains explicit rules")
	check(PackKeywords.item_stats(PackCatalog.item("iron_charm"))[0]["key"] == "stamina", "Iron Charm reports its explicit maximum stamina bonus")
	var legacy: Dictionary = knife.duplicate(true)
	legacy.erase("tooltip_detail")
	check(PackKeywords.item_description(legacy) == "", "Saved items also lose redundant stat sentences")
	check(PackKeywords.item_description({"key": "custom_item", "detail": "A special custom rule."}) == "A special custom rule.", "Unrecognized item rules are preserved")
	var game = load("res://scenes/main.gd").new()
	var target: Dictionary = PackCatalog.item("cracked_shield")
	target.merge({"id": 1, "cell": Vector2i(0, 0)}, true)
	var booster: Dictionary = PackCatalog.item("iron_charm")
	booster.merge({"id": 2, "cell": Vector2i(1, 0)}, true)
	game.run.items.assign([target, booster])
	var inspection: Dictionary = game._describe_item(target, Rect2())
	check(inspection.has("keyword_list") and inspection.get("keyword_stats", []).is_empty(), "Live item inspection uses a list instead of compact stats")
	check(inspection.get("bonuses", []).size() == 1 and inspection["bonuses"][0]["label"] == "+3 block from Iron Charm", "Live inspection identifies the actual adjacent source")
	check(inspection["keyword_list"][0]["value"] == 8, "Live list includes the real adjacency bonus")
	game.free()
	var window: PackInspectWindow = load("res://scenes/shared/inspect_window/inspect_window.tscn").instantiate()
	root.add_child(window)
	window.setup({"key": "test_knife", "title": knife["name"], "body": knife["tooltip_detail"], "keyword_list": PackKeywords.item_stats(knife)})
	var expected := RichTextLabel.new()
	expected.bbcode_enabled = true
	expected.text = text
	check(window.body.get_parsed_text() == expected.get_parsed_text(), "Simple item tooltip is only the keyword list")
	expected.free()
	window.setup({"key": "test_boosted", "title": "Shield", "body": "+3 block from Iron Charm.", "keyword_list": PackKeywords.item_stats(PackCatalog.item("cracked_shield"), 3)})
	check(window.body.get_parsed_text().contains("+8") and window.body.get_parsed_text().contains("Iron Charm"), "Affected item shows adjusted value and bonus explanation")
	window.queue_free()
	await process_frame
	report("KEYWORD LIST RESULT")
	quit(1 if failures else 0)
