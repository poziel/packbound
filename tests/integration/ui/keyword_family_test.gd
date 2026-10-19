extends "res://tests/support/test_case.gd"

const KEYS: Array[String] = ["health", "mana", "block", "plating", "slow", "healing", "vampirism", "ward", "poison", "burn", "curse", "thorns", "damage", "cleanse", "crit_chance", "critical_damage", "magical_attack", "total_attack", "physical_attack", "accuracy", "toughness", "luck", "doom"]

func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")


func _run() -> void:
	for key: String in KEYS:
		check(PackKeywords.has_icon(key), "Family includes " + key)
		if not PackKeywords.has_icon(key):
			continue
		var image: Image = PackKeywords.icon(key).get_image()
		check(image.get_size() == Vector2i(16,16), "Native canvas is 16x16: " + key)
		check(image.get_used_rect() == Rect2i(1,1,14,14), "Uniform centered 14x14 visible envelope: " + key)
		var inline: Image = PackKeywords.icon(key,true).get_image()
		check(inline.get_size() == Vector2i(16,16) and inline.get_used_rect() == Rect2i(1,2,14,14), "Inline baseline correction keeps a uniform 16px slot: " + key)
		var label: String = PackKeywords.registry()["keywords"][key]["label"]
		var markup: String = PackKeywordLinks.rich(label, "", false)
		check(markup.count("[img ") == 1 and markup.find("[/img]") < markup.rfind(label), "Icon before its label: " + key)
		check(PackKeywordLinks.rich(markup, "", false) == markup, "Stable formatting: " + key)
		if not PackKeywordLinks.ENTRIES.has(key):
			check(not PackKeywordLinks.rich(label).contains("[url="), "No keyword link for an undefined future mechanic: " + key)
	check(PackKeywords.resolve("armor") == "block", "Legacy armor resolves to current Block protection")
	check(PackKeywords.resolve("critical chance") == "crit_chance", "Critical chance alias resolves")
	check(PackKeywords.resolve("crit damage") == "critical_damage", "Critical damage alias resolves")
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.size = Vector2(200,100)
	rich.add_theme_font_override("normal_font",load("res://assets/fonts/ui_pixel.tres"))
	root.add_child(rich)
	for font_px: int in [16,24,32]:
		rich.add_theme_font_size_override("normal_font_size",font_px)
		var shared_height: int = -1
		for key: String in KEYS:
			rich.text = PackKeywords.image_markup(key) + "H"
			await process_frame
			var height: int = rich.get_line_height(0)
			if shared_height < 0:
				shared_height = height
			check(height == shared_height, "Equal line metrics across icons at font %d: %s" % [font_px,key])
	rich.free()
	print("KEYWORD FAMILY RESULT: %d checks, %d failures" % [checks,failures])
	report("keyword_family")
	quit(1 if failures else 0)
