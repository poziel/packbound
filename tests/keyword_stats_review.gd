extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1200, 760)
	var background := ColorRect.new()
	background.color = Color("17141b")
	background.size = Vector2(1200, 760)
	root.add_child(background)
	var examples: Array[Dictionary] = []
	for key: String in ["rusty_knife", "ember_tome", "iron_charm"]:
		var item: Dictionary = PackCatalog.item(key)
		examples.append({"key": key, "title": item["name"], "body": PackKeywords.item_description(item), "icon": PackArt.item(key), "keyword_list": PackKeywords.item_stats(item)})
	var shield: Dictionary = PackCatalog.item("cracked_shield")
	examples.append({"key": "boosted_shield", "title": shield["name"], "body": "+3 block from Iron Charm.", "icon": PackArt.item(shield["key"]), "keyword_list": PackKeywords.item_stats(shield, 3)})
	for index in examples.size():
		var window: PackInspectWindow = load("res://scenes/shared/inspect_window.tscn").instantiate()
		root.add_child(window)
		window.setup(examples[index])
		window.position = Vector2(24 + (index % 2) * 580, 24 + (index / 2) * 355)
		window.size.x = 550
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var folder: String = "res://workspace/docs/art/reviews/keyword-stats"
	DirAccess.make_dir_recursive_absolute(folder)
	var error: Error = root.get_texture().get_image().save_png(folder + "/tooltip-preview.png")
	print("Keyword stats preview: ", error_string(error))
	quit(error)
