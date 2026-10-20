extends RefCounted
## Content uses class IDs in classes and authored character IDs in characters.
## Both constraints apply when both lists are present; empty lists are unrestricted.
static var _catalog_restrictions: Dictionary = {}

static func character(key: String) -> Dictionary:
	var value: CharacterDefinition = preload("res://systems/content/runtime_content.gd").character(key)
	if value == null:
		return {}
	return {"id": str(value.id), "name": value.display_name, "class": str(value.class_id),
		"bio": {"summary": value.biography}, "description": value.description}

static func definition(content: Dictionary) -> Dictionary:
	var key: String = str(content.get("key", ""))
	if key.is_empty():
		return content
	# Old saves may lack restrictions. Cache immutable catalog constraints rather
	# than rebuilding the catalog during every combat eligibility check.
	if not _catalog_restrictions.has(key):
		var authored: Dictionary = {}
		if key in PackCatalog.ROSTER:
			authored = PackCatalog.item(key)
		elif key in PackCatalog.RELICS:
			authored = PackCatalog.relic(key)
		_catalog_restrictions[key] = {"classes": authored.get("classes", []), "characters": authored.get("characters", [])}
	var current: Dictionary = _catalog_restrictions[key].duplicate()
	current.merge(content, true)
	return current

static func allows(content: Dictionary, class_key: String) -> bool:
	# Eligibility is hot during drag previews. Read only the two constraint lists;
	# do not copy and merge the entire item record for every source/target pair.
	var key: String = str(content.get("key", ""))
	if (not content.has("classes") or not content.has("characters")) and not key.is_empty() and not _catalog_restrictions.has(key):
		definition(content)
	var authored: Dictionary = _catalog_restrictions.get(key, {})
	var classes: Array = content.get("classes", authored.get("classes", []))
	var characters: Array = content.get("characters", authored.get("characters", []))
	return (classes.is_empty() or class_key in classes) and (characters.is_empty() or class_key in characters)

static func markup(content: Dictionary, links: bool = true) -> String:
	var data: Dictionary = definition(content)
	var lines: PackedStringArray = []
	for kind: String in ["classes", "characters"]:
		var names: PackedStringArray = []
		for id: String in data.get(kind, []):
			var record: Dictionary = character(id)
			var label: String = str(record.get("name", id.capitalize())) if kind == "characters" else id.capitalize()
			var key: String = "restriction_%s_%s" % ["character" if kind == "characters" else "class", id]
			names.append("[url=%s][u]%s[/u][/url]" % [key, label] if links else label)
		if not names.is_empty():
			lines.append("Only " + " or ".join(names))
	return "\n".join(lines)

static func description(text: String) -> String:
	# Legacy definitions embed restrictions in prose. The footer owns that text now.
	var sentence := RegEx.new()
	sentence.compile("(?i)Only [^.\\n]+ can equip this (?:item|relic)\\.")
	return sentence.sub(text, "", true).strip_edges()
