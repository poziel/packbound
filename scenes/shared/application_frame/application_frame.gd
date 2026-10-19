@tool
extends Control
## Keep the frame's continuous outline registered to its editable settings slot.

@onready var border: Panel = $Border
@onready var dock: Control = $SettingsDock

func _ready() -> void:
	dock.visibility_changed.connect(_sync_outline)
	dock.resized.connect(_sync_outline)
	_sync_outline()

func _sync_outline() -> void:
	var style: StyleBox = border.get_theme_stylebox("panel")
	style.set("dock_size", Vector2i(dock.size.round()) if dock.is_visible_in_tree() else Vector2i.ZERO)
