extends SceneTree
## Regenerates the Inspector/export dependency snapshot. Runtime discovery is automatic.

func _initialize() -> void:
	var catalog: Resource = preload("res://systems/content/collectible_catalog_definition.gd").new()
	var errors: PackedStringArray = catalog.refresh_from_folders()
	if not errors.is_empty():
		for error: String in errors:
			printerr(error)
		quit(1)
		return
	var result: Error = ResourceSaver.save(catalog, "res://assets/collectibles.tres")
	print("CATALOG: %d collectibles, %d categories; save=%s" % [catalog.collectibles.size(), catalog.categories.size(), error_string(result)])
	quit(0 if result == OK else 1)
