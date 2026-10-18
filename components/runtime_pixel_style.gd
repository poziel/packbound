@tool
extends StyleBoxTexture
## Cached pixels are rebuilt by their owning control, never saved into scenes.

func _validate_property(property: Dictionary) -> void:
	if property["name"] == "texture":
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_STORAGE
