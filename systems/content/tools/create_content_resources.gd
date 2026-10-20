extends SceneTree
## Refresh existing authored catalogs. The initial JSON conversion is complete;
## never regenerate individual definitions from legacy tables or overwrite edits.
func _initialize() -> void:
	var content: GameContentDefinition = load("res://assets/game_content.tres")
	var errors: PackedStringArray = content.refresh_from_folders()
	if not errors.is_empty():
		for error: String in errors:
			printerr(error)
		quit(1)
		return
	var result: Error = ResourceSaver.save(content.collectibles, "res://assets/collectibles.tres")
	if result == OK:
		result = ResourceSaver.save(content, "res://assets/game_content.tres")
	print("CONTENT CATALOG REFRESH: " + error_string(result))
	quit(0 if result == OK else 1)
