extends SceneTree

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var tooltip = load("res://scenes/shared/item_tooltip.tscn").instantiate()
	root.add_child(tooltip)
	var inspect = load("res://scenes/shared/inspect_window.tscn").instantiate()
	root.add_child(inspect)
	await process_frame
	for key: String in PackCatalog.CONTENT.ITEM_KEYS:
		var item: Dictionary = PackCatalog.item(key)
		tooltip.set_item(item)
		check(tooltip.get_node("Rarity").text == PackCatalog.RARITY.label(item), "Tooltip tier label: " + key)
		check(tooltip.get_node("Header/Name").get_theme_color("font_color") == PackCatalog.RARITY.color(item), "Tooltip name color: " + key)
		inspect.setup(preload("res://scripts/item_presentation.gd").catalog_inspection(key))
		check(inspect.body.text.contains(PackCatalog.RARITY.markup(item)), "Inspection tier label: " + key)
		var texture: AtlasTexture = PackArt.item(key)
		check(texture.region.size == Vector2(item["shape"]) * 32, "Native item art matches footprint: " + key)
	for key: String in PackCatalog.CONTENT.RELIC_KEYS:
		var relic: Dictionary = PackCatalog.relic(key)
		inspect.setup({"key": "relic_" + key, "title": relic["name"], "rarity": relic["rarity"], "body": relic["detail"], "keyword_stats": PackKeywords.relic_stats(relic)})
		check(inspect.body.text.contains(PackCatalog.RARITY.markup(relic)), "Relic inspection tier label: " + key)
		check(PackArt.relic(key).region.size == Vector2(32, 32), "Relic art uses intended slot: " + key)
	inspect.setup({"key": "plain_definition", "title": "Ordinary heading", "body": "Description"})
	check(not inspect.get_node("Content/Header/Title").has_theme_color_override("default_color"), "Reused inspection restores theme title color")
	check(not inspect.body.text.contains("Legendary"), "Reused inspection clears previous rarity")
	tooltip.queue_free()
	inspect.queue_free()
	await process_frame
	print("ITEM RARITY UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
