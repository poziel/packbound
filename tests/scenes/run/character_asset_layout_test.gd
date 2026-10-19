extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	if not require_isolation():
		return
	for key: String in PackCatalog.classes():
		var base := "res://assets/characters/%s/" % key
		for filename in ["full-body.sprite.json", "full-body.png", "full-body.svg", "portrait.sprite.json", "portrait.png", "portrait.svg", "provenance.json", "art-manifest.json"]:
			checks += 1
			if not FileAccess.file_exists(base + "art/" + filename):
				printerr("Missing art file: ", base, filename)
				failures += 1
		var head := PackArt.character_head(key)
		checks += 1
		if head.atlas.resource_path != base + "art/portrait.png" or head.region != Rect2(0, 0, 64, 64):
			printerr("Invalid portrait resolution/path: ", key)
			failures += 1
		for filename in ["full-body.png", "full-body.svg"]:
			var texture: Texture2D = load(base + "art/" + filename)
			checks += 1
			if texture == null or texture.get_size() != Vector2(384, 320):
				printerr("Invalid imported body: ", key, filename)
				failures += 1
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "character.json"))
		for field in ["runtime", "nativeSource", "portrait", "portraitNativeSource", "concept"]:
			checks += 1
			if not FileAccess.file_exists("res://" + profile["assetReferences"][field]):
				printerr("Invalid profile art reference: ", key, field)
				failures += 1
	var preview: PackedScene = load("res://components/characters/character_preview/character_preview.tscn")
	checks += 1
	if preview == null:
		failures += 1
	print("CHARACTER ASSET LAYOUT: %d checks, %d failures" % [checks, failures])
	report("character_asset_layout")
	quit(1 if failures else 0)
