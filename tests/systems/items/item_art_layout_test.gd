extends "res://tests/support/test_case.gd"

func _run() -> void:
	var images: int = 0
	var sources: int = 0
	for folder: String in DirAccess.get_directories_at("res://assets/items"):
		var art: String = "res://assets/items/" + folder + "/art"
		if not DirAccess.dir_exists_absolute(art):
			continue
		check(DirAccess.get_directories_at(art).is_empty(), "Item art folder has no revision/source subfolders: " + folder)
		var files: PackedStringArray = DirAccess.get_files_at(art)
		for file: String in files:
			check(file in ["item.png", "item.png.import", "item.pixloom.json"], "Only current art files remain: " + folder + "/" + file)
		if files.has("item.png"):
			images += 1
			var texture: Texture2D = load(art + "/item.png")
			check(texture != null and texture.get_width() > 0 and texture.get_height() > 0, "Canonical image imports: " + folder)
		if files.has("item.pixloom.json"):
			sources += 1
			check(JSON.parse_string(FileAccess.get_file_as_string(art + "/item.pixloom.json")) is Dictionary, "Editable JSON remains valid: " + folder)
	check_equal(images, 131, "All current item images retained")
	check_equal(sources, 106, "Existing editable JSON sources retained")
	for key: String in PackCatalog.ROSTER:
		var texture: AtlasTexture = PackArt.item(key)
		check(texture != null and texture.atlas != null, "Runtime item texture resolves: " + key)
		if texture != null and texture.atlas != null:
			check_equal(texture.atlas.resource_path.get_file(), "item.png", "Runtime uses canonical current item image: " + key)
	var content: Resource = load("res://assets/game_content.tres")
	for definition: CollectibleDefinition in content.collectibles.collectibles:
		if definition is ItemDefinition:
			check(definition.icon is AtlasTexture and definition.icon.atlas.resource_path.ends_with("/art/item.png"), "Item definition references canonical art: " + str(definition.id))
	report("ITEM ART LAYOUT")
	quit(1 if failures else 0)
