extends Control

func _ready() -> void:
	for key: String in PackCatalog.classes():
		var portrait: Control = get_node("Row/" + key)
		portrait.texture = PackArt.character_head(key)
		var data: Dictionary = PackCatalog.classes()[key]
		portrait.tooltip_text = data["name"] + " / " + data["mechanic"]
