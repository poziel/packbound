extends RefCounted
## Canonical filenames are the registration contract, not every .tres in a folder.
## ResourceLoader preserves resource filenames when exports remap text Resources.

static func paths(root: String, filename: String) -> PackedStringArray:
	var result := PackedStringArray()
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		var entries: PackedStringArray = ResourceLoader.list_directory(directory)
		entries.sort()
		for entry: String in entries:
			if entry.ends_with("/"):
				if entry.trim_suffix("/") not in ["art", "icons", "revisions", "concept", "atlases"]:
					pending.append(directory.path_join(entry.trim_suffix("/")))
			elif entry == filename or (filename == "*.tres" and entry.ends_with(".tres")):
				result.append(directory.path_join(entry))
	result.sort()
	return result

static func discover(item_root: String = "res://assets/items", relic_root: String = "res://assets/relics", category_root: String = "res://assets/categories") -> Dictionary:
	var result: Dictionary = {"collectibles": [], "categories": [], "errors": PackedStringArray()}
	for spec: Array in [[item_root, "item.tres"], [relic_root, "relic.tres"], [category_root, "*.tres"]]:
		var found: PackedStringArray = paths(spec[0], spec[1])
		if found.is_empty():
			result.errors.append("No %s resources found under %s." % [spec[1], spec[0]])
		for path: String in found:
			var value: Resource = ResourceLoader.load(path)
			var valid: bool = value is ItemDefinition if spec[1] == "item.tres" else (value is RelicDefinition if spec[1] == "relic.tres" else value is CollectibleCategoryDefinition)
			if not valid:
				result.errors.append("%s has the wrong Resource type." % path)
				continue
			result["categories" if spec[1] == "*.tres" else "collectibles"].append(value)
	result.collectibles.sort_custom(func(a: CollectibleDefinition, b: CollectibleDefinition) -> bool:
		var compared: int = a.display_name.naturalnocasecmp_to(b.display_name)
		return str(a.id) < str(b.id) if compared == 0 else compared < 0)
	result.categories.sort_custom(func(a: CollectibleCategoryDefinition, b: CollectibleCategoryDefinition) -> bool: return str(a.id) < str(b.id))
	return result
