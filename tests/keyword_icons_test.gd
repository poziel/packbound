extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var terms: Array[String] = ["health", "mana", "block", "plating", "slow", "healing", "vampirism", "ward", "poison", "burn", "curse", "thorns"]
	for key: String in terms:
		var result: String = PackKeywordLinks.rich(key)
		check(result.contains("[img "), "Inline image exists for " + key)
		check(result.find("[/img]") < result.rfind(key), "Icon precedes " + key)
		check(result.contains("[/img]\u2060\u00a0"), "Nonbreaking gap precedes " + key)
		check(result.contains("[url=" + key + "]"), "Glossary link retained for " + key)
		check(PackKeywordLinks.rich(result) == result, "Repeated formatting is stable for " + key)
	var mixed: String = PackKeywordLinks.rich("Gain 3 mana, 2 block and healing; HP remains capped.")
	check(mixed.count("[img ") == 4, "Mixed effects and health alias have one icon each")
	check(mixed.contains("Gain ") and mixed.contains(" remains capped."), "Surrounding prose survives")
	check(mixed.contains("]3 [img ") and mixed.contains("]2 [img "), "Effect values share keyword color")
	check(PackKeywordLinks.rich("burning blockade unhealthy").count("[img ") == 0, "Only whole terms match")
	var longest: String = PackKeywordLinks.rich("armor piercing and direct damage")
	check(longest.contains("[url=piercing]") and longest.contains("[url=damage]"), "Longest aliases resolve before shorter words")
	var existing: String = "[img]res://assets/health.png[/img] [url=health]health[/url]"
	check(PackKeywordLinks.rich(existing) == existing, "Existing images, paths and links are preserved")
	var excluded: String = PackKeywordLinks.rich("Health and mana", "health")
	check(excluded.count("[img ") == 2 and not excluded.contains("[url=health]"), "Self term keeps icon without cyclic self link")
	check(not PackKeywordLinks.rich("Health and mana", "", false).contains("[url="), "Passive text emits no dead keyword links")
	check(not PackKeywordLinks.rich("Shield armor").contains("[img "), "Legacy shield is not silently given block or plating art")
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = mixed
	root.add_child(label)
	await process_frame
	check(not label.get_parsed_text().contains("res://") and not label.get_parsed_text().contains("[img"), "Godot parses image markup without leaking paths")
	label.add_theme_font_override("normal_font", load("res://assets/fonts/ui_pixel.tres"))
	label.add_theme_font_size_override("normal_font_size", 24)
	label.size = Vector2(90, 200)
	label.text = PackKeywordLinks.rich("aaa Health", "", false)
	await process_frame
	var word_at: int = label.get_parsed_text().find("Health")
	check(label.get_character_line(word_at - 3) == label.get_character_line(word_at), "Image and keyword stay together at a line wrap")
	label.queue_free()
	print("KEYWORD ICONS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
